# zzfrp 管理脚本 by RY-zzcn

这是一个便捷的 Bash 脚本，用于在 Linux 系统上安装、更新、管理和卸载 `frps` (服务端) 和 `frpc` (客户端) 服务，并支持对多个 `frpc` 客户端实例进行独立管理。

**frp 版本作者：fatedier** ([fatedier/frp](https://github.com/fatedier/frp))
**本脚本作者：RY-zzcn**
**脚本仓库地址：[https://github.com/RY-zzcn/zzfrp](https://github.com/RY-zzcn/zzfrp)**

## 功能特性

* **美观易用**: 彩色的菜单界面，操作直观。
* **智能依赖处理**: 自动检测并提示/尝试安装缺失的依赖工具 (`curl`, `wget`, `tar`, `nano`, `coreutils`)。
* **frps (服务端) 全方位管理**:
    * 安装或更新最新版本的 `frps`。
    * 首次安装时支持交互式配置 `bind_port`, `dashboard_port` 及 Dashboard 用户名/密码。
    * 管理 `frps` systemd 服务 (启动、停止、重启、查看状态、查看日志)。
    * 便捷编辑 `frps.ini` 配置文件。
    * 彻底卸载 `frps` (包括服务、二进制文件，并可选移除配置文件)。
* **frpc (客户端) 二进制文件管理**:
    * 安装或更新最新版本的 `frpc` 二进制文件。
    * 显示当前安装的 `frpc` 版本。
    * 卸载 `frpc` 二进制文件 (在所有 `frpc` 实例被删除后，可选删除 systemd 模板和空配置目录)。
* **frpc (客户端) 多实例管理**:
    * 支持创建和管理多个独立的 `frpc` 客户端实例。
    * **添加实例**: 引导式创建，自动生成配置文件和 systemd 服务。
    * **删除实例**: 安全移除指定实例及其相关文件和服务。
    * **管理指定实例**: 对选定实例进行独立操作 (启停、重载、状态、日志、编辑配置)。
    * **查看所有实例状态**: 快速概览所有 `frpc` 实例的运行情况。
* **系统集成**:
    * 通过 systemd 实现服务的开机自启动和进程守护 (失败后自动重启)。
    * 首次运行时尝试自动将脚本设置为全局快捷命令 `sudo zzfrp`。
* **全局概览**:
    * 一键查看所有 `zzfrp` 相关服务 (frps 和所有 frpc 实例) 的当前状态。

## 如何使用

### 1. 一键安装/运行 (推荐首次使用)

使用以下命令之一，可以直接下载并以 root 权限运行脚本。脚本首次运行会尝试自动设置快捷启动命令 `sudo zzfrp`。

* **使用 `curl`**:
    ```bash
    curl -fsSL https://raw.githubusercontent.com/RY-zzcn/zzfrp/main/zzfrp.sh -o zzfrp.sh && chmod +x zzfrp.sh && sudo ./zzfrp.sh
    ```
* **使用 `wget`**:
    ```bash
    wget -q https://raw.githubusercontent.com/RY-zzcn/zzfrp/main/zzfrp.sh -O zzfrp.sh && chmod +x zzfrp.sh && sudo ./zzfrp.sh
    ```

    之后，如果快捷命令设置成功，您可以直接使用 `sudo zzfrp` 启动脚本。

### 2. 手动下载和运行

1.  **下载脚本**:
    ```bash
    wget https://raw.githubusercontent.com/RY-zzcn/zzfrp/main/zzfrp.sh
    # 或者使用 curl:
    # curl -O https://raw.githubusercontent.com/RY-zzcn/zzfrp/main/zzfrp.sh
    ```
2.  **给予执行权限**:
    ```bash
    chmod +x zzfrp.sh
    ```
3.  **运行脚本**:
    ```bash
    sudo ./zzfrp.sh
    ```
    脚本将引导您完成后续操作。

### 3. 设置为全局命令 `zzfrp` (如果自动设置未成功或您想手动配置)

脚本在首次运行时会尝试自动将自身复制到 `/usr/local/bin/zzfrp`。如果此操作因故失败，您可以手动执行以下步骤：

1.  确保脚本 (`zzfrp_manager.sh`) 已下载并具有执行权限。
2.  执行移动和重命名命令：
    ```bash
    sudo mv zzfrp.sh /usr/local/bin/zzfrp
    ```
3.  之后，您就可以在系统的任何路径下使用 `sudo zzfrp` 来运行此管理脚本了。

## 依赖项

脚本运行需要以下工具：

* `curl`
* `wget`
* `tar`
* `systemctl` (systemd 环境核心组件)
* `nano` (用于编辑配置文件，您也可以在脚本中修改为您偏好的编辑器)
* `coreutils` (提供 `readlink` 等基础命令)

脚本内置了对这些工具（`systemctl` 除外）的检测机制，并在缺失时尝试使用系统的包管理器 (`apt-get`, `yum`, `dnf`) 自动安装（会请求您的确认）。`systemctl` 是脚本运行的基础，如果缺失则表示系统环境不兼容。


## 贡献

如果您有任何改进建议、功能需求或发现 Bug，欢迎通过本仓库的 Issues 或 Pull Requests 提出。

## 免责声明

请用户自行承担使用此脚本可能带来的所有风险。强烈建议在非生产环境中充分测试脚本的各项功能，确保其行为符合您的预期，然后再在生产环境中使用。作者不对因使用此脚本可能造成的任何直接或间接损失负责。
