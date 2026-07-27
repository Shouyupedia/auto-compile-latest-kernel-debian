#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPO="Shouyupedia/auto-compile-latest-kernel-debian"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo ">>> 安装所需工具..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl jq

echo ">>> 获取最新 Release 信息..."
release_json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")"
tag="$(jq -er '.tag_name | select(type == "string" and length > 0)' <<< "$release_json")"
echo ">>> 最新版本：$tag"

# 只安装启动内核和配套头文件，不替换系统的 linux-libc-dev。
mapfile -t urls < <(
    jq -r '
        .assets[]
        | select(.name | test("^linux-(image|headers)-.*\\.deb$"))
        | .browser_download_url
    ' <<< "$release_json"
)

if ((${#urls[@]} == 0)); then
    echo "错误：Release 中未找到内核镜像或头文件包。" >&2
    exit 1
fi

echo ">>> 下载内核包到临时目录..."
for url in "${urls[@]}"; do
    filename="${url##*/}"
    echo "  - $filename"
    curl -fsSL -o "$tmp_dir/$filename" "$url"
done

shopt -s nullglob
debs=("$tmp_dir"/*.deb)
if ((${#debs[@]} == 0)); then
    echo "错误：没有成功下载任何 .deb 包。" >&2
    exit 1
fi

declare -A new_packages=()
has_image=false
for deb in "${debs[@]}"; do
    package="$(dpkg-deb -f "$deb" Package)"
    if [[ ! "$package" =~ ^linux-(image|headers)-[a-zA-Z0-9.+~-]+$ ]]; then
        echo "错误：Release 中包含非预期软件包：$package" >&2
        exit 1
    fi
    new_packages["$package"]=1
    [[ "$package" == linux-image-* ]] && has_image=true
done

if [[ "$has_image" != true ]]; then
    echo "错误：Release 中缺少 linux-image 软件包。" >&2
    exit 1
fi

echo ">>> 安装新内核..."
sudo apt-get install -y "${debs[@]}"

# 清理本项目以前安装的内核。旧版本没有后缀，新版本使用 -shouyu；
# Debian/Ubuntu 官方内核含发行版 ABI 后缀，不会匹配这里的规则。
running_release="$(uname -r)"
declare -a old_packages=()
kept_running_kernel=false

while IFS=$'\t' read -r package status; do
    [[ "$status" == "ii " ]] || continue
    [[ ${new_packages["$package"]+present} ]] && continue

    kernel_release="${package#linux-image-}"
    if [[ "$kernel_release" == "$package" ]]; then
        kernel_release="${package#linux-headers-}"
    fi

    if [[ ! "$kernel_release" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-(shouyu|cloud))?$ ]]; then
        continue
    fi

    if [[ "$kernel_release" == "$running_release" ]]; then
        kept_running_kernel=true
        echo ">>> 保留当前正在运行的内核包：$package"
        continue
    fi

    old_packages+=("$package")
done < <(dpkg-query -W -f='${Package}\t${db:Status-Abbrev}\n')

if ((${#old_packages[@]} > 0)); then
    echo ">>> 删除旧的第三方内核包..."
    printf '  - %s\n' "${old_packages[@]}"
    sudo apt-get purge -y "${old_packages[@]}"
else
    echo ">>> 没有需要删除的旧第三方内核包。"
fi

echo ">>> 更新 GRUB..."
sudo update-grub

echo ">>> 完成：内核 $tag 已安装，重启后生效。"
if [[ "$kept_running_kernel" == true ]]; then
    echo ">>> 当前运行的旧内核已安全保留；重启进入新内核后，再运行一次脚本即可清理。"
fi
echo "    运行 'sudo reboot' 重启系统。"
