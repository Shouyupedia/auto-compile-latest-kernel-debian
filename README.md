# Debian/Ubuntu VPS 最新稳定内核

该项目每天检查 Linux stable 的最新正式版本，为 amd64 VPS 构建带 `-shouyu` 后缀的 Debian 内核包。

- 上游内核源码版本没有变化时，只同步 Debian 配置并整理现有 Release，不安装构建依赖、不编译，也不重复创建 Release。
- 配置严格按照 Debian 当前 `cloud-amd64` 的四层顺序生成，再叠加本项目的 `config.vps`。
- 保留 KVM/QEMU、Xen、Hyper-V、VMware、NVMe，以及 AWS、Google Cloud、Azure 常见虚拟网卡。
- 保留 Docker 所需的 cgroup、namespace、OverlayFS、iptables/nftables 和常见容器网络功能。
- 移除桌面、声音、无线、蓝牙、媒体、RDMA、旧协议和重型内核调试功能，模块使用 Zstandard 压缩。
- 同时提供 BBRv1（`bbr`）和 BBRv3（`bbr3`）；默认使用 BBRv1 与 FQ，BBRv3 作为可选模块。
- Release 只发布内核镜像与匹配头文件，页面正文只显示版本和 UTC 构建时间。

## 安装

支持 Debian/Ubuntu amd64、GRUB、未开启 Secure Boot 的 VPS。LXC、OpenVZ、Docker 等容器不能替换宿主机内核，安装器会直接拒绝。

```bash
sudo bash install-latest-kernel.sh
```

如果已经是 root，可直接运行：

```bash
bash install-latest-kernel.sh
```

安装器会校验 Release 标签、架构、软件包元数据、文件大小和 GitHub SHA-256。新内核镜像、模块、initramfs 与 GRUB 启动项全部验证成功后，才会删除本项目安装的旧内核；正在运行的内核、被 hold 的内核和 Debian/Ubuntu 官方内核始终保留。安装器不会根据名称猜测并删除 XanMod、Liquorix 等其他项目的内核。

## BBRv3

查看可用算法：

```bash
sudo modprobe tcp_bbr3
sysctl net.ipv4.tcp_available_congestion_control
```

临时切换到 BBRv3：

```bash
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr3
```

持久启用 BBRv3：

```bash
printf '%s\n' 'tcp_bbr3' \
  | sudo tee /etc/modules-load.d/bbr3.conf
printf '%s\n' 'net.core.default_qdisc=fq' \
  'net.ipv4.tcp_congestion_control=bbr3' \
  | sudo tee /etc/sysctl.d/99-bbr3.conf
sudo sysctl --system
```

切回默认的 BBRv1：

```bash
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
```

## 兼容性边界

- 目标是常见云 VPS，不包含桌面、本地无线/音频设备、RDMA/HPC 或裸机 RAID 的完整驱动集合。
- 内核和模块未签名，因此不支持 Secure Boot/Trusted Launch。
- 内核保留普通 BPF 与 Docker 支持，但为缩小体积关闭了调试信息和 BTF；依赖 BPF CO-RE/BTF 的工具不在兼容范围内。
- 最大支持 256 个逻辑 CPU。
