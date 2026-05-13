#!/bin/bash
set -euo pipefail

sudo apt update && sudo apt install -y curl jq

# === 配置 ===
REPO="Shouyupedia/auto-compile-latest-kernel-debian"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo ">>> 获取最新 release 信息..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')
echo ">>> 最新版本: $TAG"

# 筛选 .deb 文件的下载链接
URLS=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url')

if [ -z "$URLS" ]; then
    echo "错误: 未找到 .deb 文件" >&2
    exit 1
fi

echo ">>> 下载 .deb 包到 $TMPDIR ..."
for url in $URLS; do
    echo "  - $(basename "$url")"
    curl -fsSL -o "$TMPDIR/$(basename "$url")" "$url"
done

echo ">>> 安装内核包..."
sudo dpkg -i "$TMPDIR"/*.deb

echo ">>> 更新 GRUB..."
sudo update-grub

echo ">>> 完成！内核 $TAG 已安装，重启后生效。"
echo "    运行 'sudo reboot' 重启系统。"
