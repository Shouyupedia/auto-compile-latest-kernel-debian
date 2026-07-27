# Debian stable kernel auto-build

该项目每周检查 Linux stable 的最新正式版本：

- 上游源码版本没有变化时，工作流会在配置同步后跳过依赖安装和编译，也不会重复创建 Release。
- 每次运行都会从 Debian Kernel Team 的 `debian/latest` 分支获取并校验最新的 `config.cloud` 和 `config.cloud-amd64`；有变化时自动提交回仓库。
- 新内核使用 `-shouyu` 本地版本后缀，例如 `7.1.4-shouyu`。
- Release 只发布启动所需的内核镜像和配套头文件，不会替换系统的 `linux-libc-dev`。

## 安装

运行 `install-latest-kernel.sh` 会安装最新 Release，并删除本项目安装的旧第三方内核。当前正在运行的内核始终保留，Debian/Ubuntu 官方内核也不会被删除。

重启进入新内核后，如果安装时保留了正在运行的旧内核，可再次运行脚本完成清理。
