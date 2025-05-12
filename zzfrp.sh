#!/bin/bash

set -e

# 全局设置
FRP_INSTALL_DIR="/usr/local/frp" # FRP 二进制文件和 frps 配置的基础目录
FRPC_CLIENTS_DIR="${FRP_INSTALL_DIR}/clients" # frpc 实例配置目录
FRP_ARCH="amd64" # 默认架构
FRP_VERSION_TO_INSTALL="" # 将由用户选择或自动确定要安装的版本
ZZFRP_COMMAND_PATH="/usr/local/bin/zzfrp" # 快捷指令路径
SHORTCUT_SETUP_FLAG_FILE="${FRP_INSTALL_DIR}/.zzfrp_shortcut_setup_done" # 标记文件，表示已尝试设置快捷方式
SCRIPT_REPO_URL="https://github.com/RY-zzcn/zzfrp" # 脚本仓库地址

# --- Color Definitions ---
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_UNDERLINE='\033[4m'

# Basic Colors
C_BLACK='\033[0;30m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[0;37m'

# Light/Bright Colors
C_LIGHT_RED='\033[1;31m'
C_LIGHT_GREEN='\033[1;32m'
C_LIGHT_YELLOW='\033[1;33m'
C_LIGHT_BLUE='\033[1;34m'
C_LIGHT_MAGENTA='\033[1;35m'
C_LIGHT_CYAN='\033[1;36m'
C_LIGHT_WHITE='\033[1;37m'
C_DARK_GRAY='\033[1;30m' # Also known as Light Black

# Semantic Colors for UI Elements
C_MAIN_TITLE="${C_BOLD}${C_LIGHT_MAGENTA}"
C_SUB_MENU_TITLE="${C_BOLD}${C_LIGHT_CYAN}"
C_SECTION_HEADER="${C_BOLD}${C_LIGHT_YELLOW}"

C_MENU_OPTION_NUM="${C_LIGHT_YELLOW}"
C_MENU_OPTION_TEXT="${C_WHITE}"
C_MENU_PROMPT="${C_LIGHT_BLUE}"
C_INPUT_EXAMPLE="${C_DARK_GRAY}"
C_CONFIRM_PROMPT="${C_LIGHT_YELLOW}" # For [y/N] parts

C_MSG_INFO_PREFIX="${C_BOLD}${C_LIGHT_GREEN}"
C_MSG_INFO_TEXT="${C_GREEN}"
C_MSG_WARN_PREFIX="${C_BOLD}${C_LIGHT_YELLOW}"
C_MSG_WARN_TEXT="${C_YELLOW}"
C_MSG_ERROR_PREFIX="${C_BOLD}${C_LIGHT_RED}"
C_MSG_ERROR_TEXT="${C_RED}"
C_MSG_SUCCESS_TEXT="${C_LIGHT_GREEN}"
C_MSG_ACTION_TEXT="${C_LIGHT_CYAN}" # For "正在下载..." etc.

C_SEPARATOR="${C_DARK_GRAY}"
C_PATH_INFO="${C_BLUE}"
C_HINT_TEXT="${C_DARK_GRAY}"
C_STATUS_ACTIVE="${C_LIGHT_GREEN}"
C_STATUS_INACTIVE="${C_LIGHT_RED}"
C_STATUS_NOT_FOUND="${C_LIGHT_YELLOW}"


# --- 助手函数 ---
info() { echo -e "${C_MSG_INFO_PREFIX}[INFO]${C_RESET} ${C_MSG_INFO_TEXT}$1${C_RESET}"; }
error() { echo -e "${C_MSG_ERROR_PREFIX}[ERROR]${C_RESET} ${C_MSG_ERROR_TEXT}$1${C_RESET}"; exit 1; }
warn() { echo -e "${C_MSG_WARN_PREFIX}[WARN]${C_RESET} ${C_MSG_WARN_TEXT}$1${C_RESET}"; }
press_enter_to_continue() { read -p "$(echo -e "${C_MENU_PROMPT}按 Enter键 继续...${C_RESET}")"; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    error "此脚本需要以 root 权限运行。请使用 sudo 执行。"
  fi
}

check_tools() {
  info "开始检查必要的工具..."
  local tools_to_check_map 
  declare -A tools_to_check_map=(
    ["curl"]="curl"
    ["wget"]="wget"
    ["tar"]="tar"
    ["nano"]="nano"
    ["readlink"]="coreutils" 
    ["grep"]="grep" 
    ["awk"]="gawk"  
    ["openssl"]="openssl" 
  )

  local pmg="" 
  local apt_updated=false 

  if command -v apt-get &> /dev/null; then
    pmg="apt-get"
  elif command -v yum &> /dev/null; then
    pmg="yum"
  elif command -v dnf &> /dev/null; then
    pmg="dnf"
  fi

  for cmd in "${!tools_to_check_map[@]}"; do
    local pkg="${tools_to_check_map[$cmd]}"
    if ! command -v "$cmd" &> /dev/null; then
      warn "命令 '${C_BOLD}${cmd}${C_RESET}' 未找到。"
      if [ -n "$pmg" ]; then
        read -p "$(echo -e "${C_MENU_PROMPT}是否尝试自动安装软件包 '${C_BOLD}${pkg}${C_RESET}${C_MENU_PROMPT}'? [${C_CONFIRM_PROMPT}Y/n${C_MENU_PROMPT}]: ${C_RESET}")" install_confirm
        if [[ "$install_confirm" =~ ^[Yy]*$ ]]; then 
          echo -e "${C_MSG_ACTION_TEXT}正在尝试安装 '${C_BOLD}${pkg}${C_RESET}${C_MSG_ACTION_TEXT}'...${C_RESET}"
          case "$pmg" in
            "apt-get")
              if ! $apt_updated ; then
                info "首次使用 apt-get 安装，正在执行 ${C_BOLD}sudo apt-get update${C_RESET}..."
                sudo apt-get update || warn "apt-get update 失败，但仍会尝试安装。"
                apt_updated=true
              fi
              sudo apt-get install -y "$pkg"
              ;;
            "yum")
              sudo yum install -y "$pkg"
              ;;
            "dnf")
              sudo dnf install -y "$pkg"
              ;;
          esac
          if ! command -v "$cmd" &> /dev/null; then
            error "自动安装软件包 '${C_BOLD}${pkg}${C_RESET}' 后，命令 '${C_BOLD}${cmd}${C_RESET}' 仍然未找到。请手动安装后重试。"
          else
            info "命令 '${C_BOLD}${cmd}${C_RESET}' (软件包 '${C_BOLD}${pkg}${C_RESET}') 已成功安装。"
          fi
        else
          error "必需的命令 '${C_BOLD}${cmd}${C_RESET}' 未安装。请手动安装后重试。"
        fi
      else
        error "未检测到支持的包管理器 (apt-get, yum, dnf)。请手动安装命令 '${C_BOLD}${cmd}${C_RESET}' (通常在软件包 '${C_BOLD}${pkg}${C_RESET}' 中)。"
      fi
    else
      info "命令 '${C_BOLD}${cmd}${C_RESET}' 已存在。"
    fi
  done

  if ! command -v systemctl &> /dev/null; then
    error "关键命令 '${C_BOLD}systemctl${C_RESET}' 未找到。此脚本严重依赖 systemd 环境。"
  else
    info "命令 '${C_BOLD}systemctl${C_RESET}' 已存在。"
  fi
  info "工具检查完成。"
}

# 修改此函数以允许用户选择版本
determine_frp_version_to_install() {
    info "正在获取 GitHub 上最新的 FRP 版本号..."
    local latest_github_version
    latest_github_version=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    if [ -z "$latest_github_version" ]; then
      error "从 GitHub 获取 FRP 最新版本失败。请检查网络或 API 状态。"
    fi
    info "GitHub 上最新的 FRP 版本是：${C_LIGHT_WHITE}${latest_github_version}${C_RESET}"

    echo -e "${C_MENU_PROMPT}请选择要安装的 FRP 版本:${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} 安装最新版本 (${C_LIGHT_WHITE}${latest_github_version}${C_RESET}) ${C_HINT_TEXT}(默认)${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} 安装自定义版本 (例如: v0.51.3)${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}0)${C_MENU_OPTION_TEXT} 取消安装/更新${C_RESET}"
    read -p "$(echo -e "${C_MENU_PROMPT}请输入选项 [0-2] (默认为 1): ${C_RESET}")" version_choice

    case "$version_choice" in
        2)
            read -p "$(echo -e "${C_MENU_PROMPT}请输入您想安装的 FRP 版本号 (例如: ${C_INPUT_EXAMPLE}v0.51.3${C_MENU_PROMPT}) \n${C_HINT_TEXT}(请确保版本号存在于 ${C_UNDERLINE}${C_BLUE}https://github.com/fatedier/frp/releases${C_RESET}${C_HINT_TEXT})${C_MENU_PROMPT}: ${C_RESET}")" custom_version
            if [[ ! "$custom_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.].*)?$ ]]; then # 简单格式校验
                error "输入的版本号 '${C_BOLD}${custom_version}${C_RESET}' 格式不正确。应为 'vX.Y.Z' 格式。"
            fi
            FRP_VERSION_TO_INSTALL="$custom_version"
            info "将尝试安装自定义版本: ${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}"
            ;;
        0)
            info "已取消安装/更新操作。"
            return 1 # 返回失败码，以便调用函数知道中止
            ;;
        *) # 包括空输入或选项1
            FRP_VERSION_TO_INSTALL="$latest_github_version"
            info "将安装最新版本: ${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}"
            ;;
    esac
    return 0 # 返回成功码
}


download_and_extract_frp() {
  local frp_version_to_download=$1 # 使用传入的特定版本
  local arch=$2
  local binary_to_check=$3

  echo -e "${C_MSG_ACTION_TEXT}⬇️ 正在下载 FRP 版本 ${C_BOLD}${frp_version_to_download}${C_RESET}${C_MSG_ACTION_TEXT} (架构 ${arch})...${C_RESET}"
  cd /tmp
  local frp_file="frp_${frp_version_to_download#v}_linux_${arch}.tar.gz"
  local download_url="https://github.com/fatedier/frp/releases/download/${frp_version_to_download}/${frp_file}"

  wget -q --show-progress -O "${frp_file}" "${download_url}"
  if [ $? -ne 0 ]; then # 检查wget的退出状态
      error "下载 FRP (${frp_file}) 失败。请检查版本号 '${C_BOLD}${frp_version_to_download}${C_RESET}' 是否存在，或网络连接。"
  fi


  echo -e "${C_MSG_ACTION_TEXT}📦 正在解压 FRP...${C_RESET}"
  rm -rf "frp_${frp_version_to_download#v}_linux_${arch}"
  tar -xzf "${frp_file}" || { rm -f "${frp_file}"; error "解压 FRP 失败。"; }
  cd "frp_${frp_version_to_download#v}_linux_${arch}"

  if [ ! -f "${binary_to_check}" ]; then
      error "下载的 FRP 存档中未找到预期的二进制文件 ${C_BOLD}${binary_to_check}${C_RESET}。"
      cleanup_temp_files "$frp_version_to_download" "$arch" # 使用正确的版本号清理
      exit 1
  fi
}

cleanup_temp_files() {
  local frp_version_to_cleanup=$1 # 使用传入的特定版本
  local arch=$2
  echo -e "${C_MSG_ACTION_TEXT}🧹 清理临时文件...${C_RESET}"
  cd /tmp
  rm -f "frp_${frp_version_to_cleanup#v}_linux_${arch}.tar.gz"
  rm -rf "frp_${frp_version_to_cleanup#v}_linux_${arch}"
}

_manage_service() {
    local action="$1"
    local service_name="$2"
    local display_name="$3"
    display_name=${display_name:-$service_name}

    case "$action" in
        start|restart|reload) 
            echo -e "${C_MSG_ACTION_TEXT}正在 ${action} 服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_ACTION_TEXT}...${C_RESET}"
            if sudo systemctl "${action}" "${service_name}"; then
                echo -e "${C_MSG_SUCCESS_TEXT}✅ 服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_SUCCESS_TEXT} ${action} 操作成功。${C_RESET}"
                if sudo systemctl is-active --quiet "${service_name}"; then
                    info "服务 ${C_BOLD}${display_name}${C_RESET} 当前状态: ${C_STATUS_ACTIVE}active (running)${C_RESET}"
                else
                    info "服务 ${C_BOLD}${display_name}${C_RESET} 当前状态: ${C_STATUS_INACTIVE}inactive (dead) 或其他${C_RESET}"
                fi
            else
                warn "服务 ${C_BOLD}${display_name}${C_RESET} ${action} 操作失败。"
                sudo systemctl status "${service_name}" --no-pager 
            fi
            ;;
        stop)
            echo -e "${C_MSG_ACTION_TEXT}正在停止服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_ACTION_TEXT}...${C_RESET}"
            local stop_cmd_success=true
            sudo systemctl stop "${service_name}" || stop_cmd_success=false

            if ! $stop_cmd_success; then
                warn "发送停止命令给服务 ${C_BOLD}${display_name}${C_RESET} 失败。"
                sudo systemctl status "${service_name}" --no-pager 
                return 1 
            fi

            echo -e "${C_MSG_SUCCESS_TEXT}✅ 服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_SUCCESS_TEXT} 停止命令已发送。${C_RESET}"
            
            local countdown=10 
            echo -e "${C_MSG_ACTION_TEXT}等待服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_ACTION_TEXT} 完全停止...${C_RESET}"
            while systemctl is-active --quiet "${service_name}" && [ "$countdown" -gt 0 ]; do
                echo -e "${C_HINT_TEXT}  等待中... (${countdown}s)${C_RESET}"
                sleep 1
                countdown=$((countdown - 1))
            done

            if systemctl is-active --quiet "${service_name}"; then
                warn "服务 ${C_BOLD}${display_name}${C_RESET} 在等待后仍处于活动状态。可能未能完全停止。"
                sudo systemctl status "${service_name}" --no-pager
                return 1 
            else
                info "服务 ${C_BOLD}${display_name}${C_RESET} 已成功停止。"
                return 0 
            fi
            ;;
        status)
            echo -e "${C_MSG_ACTION_TEXT}正在获取服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_ACTION_TEXT} 的状态...${C_RESET}"
            sudo systemctl status "${service_name}" --no-pager 
            if sudo systemctl is-active --quiet "${service_name}"; then
                info "服务 ${C_BOLD}${display_name}${C_RESET} 当前状态总结: ${C_STATUS_ACTIVE}active (running)${C_RESET}"
            elif systemctl list-units --full -all | grep -qF "$service_name"; then
                if sudo systemctl status "${service_name}" --no-pager | grep -qE "activating \(auto-restart\)|failed \(Result: exit-code\)"; then
                    warn "服务 ${C_BOLD}${display_name}${C_RESET} 当前状态总结: ${C_STATUS_INACTIVE}failed or in restart loop${C_RESET}"
                else
                    info "服务 ${C_BOLD}${display_name}${C_RESET} 当前状态总结: ${C_STATUS_INACTIVE}inactive (dead) 或其他${C_RESET}"
                fi
            else
                info "服务 ${C_BOLD}${display_name}${C_RESET} (${C_BOLD}${service_name}${C_RESET}) ${C_STATUS_NOT_FOUND}未找到或未加载${C_RESET}。"
            fi
            ;;
        enable|disable)
            echo -e "${C_MSG_ACTION_TEXT}正在 ${action} 服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_ACTION_TEXT} 开机自启...${C_RESET}"
            if sudo systemctl "${action}" "${service_name}"; then
                echo -e "${C_MSG_SUCCESS_TEXT}✅ 服务 ${C_BOLD}${display_name}${C_RESET}${C_MSG_SUCCESS_TEXT} ${action} 开机自启操作成功。${C_RESET}"
            else
                warn "服务 ${C_BOLD}${display_name}${C_RESET} ${action} 开机自启操作失败。"
            fi
            ;;
        edit_config)
            local config_file="$4"
            if [ -z "$config_file" ]; then
                warn "未提供配置文件路径给 ${C_BOLD}${display_name}${C_RESET}。"
                return
            fi
            echo -e "${C_MSG_ACTION_TEXT}即将使用 nano 编辑 ${C_BOLD}${display_name}${C_RESET}${C_MSG_ACTION_TEXT} 的配置文件: ${C_PATH_INFO}${config_file}${C_RESET}"
            info "编辑后请保存并退出。如果服务正在运行，您可能需要重启或重载服务以应用更改。"
            press_enter_to_continue
            sudo nano "${config_file}"
            info "配置文件编辑完成。"
            ;;
        *)
            warn "未知的服务操作: $action"
            ;;
    esac
}

get_public_ip() {
    echo -e "${C_MSG_ACTION_TEXT}正在尝试获取公网IP地址...${C_RESET}"
    local ip
    ip=$(curl -s --connect-timeout 5 https://api.ipify.org) || \
    ip=$(curl -s --connect-timeout 5 https://ipinfo.io/ip) || \
    ip=$(curl -s --connect-timeout 5 https://icanhazip.com) || \
    ip=$(curl -s --connect-timeout 5 https://checkip.amazonaws.com)
    
    if [ -n "$ip" ]; then
        echo -e "${C_MSG_SUCCESS_TEXT}检测到公网IP: ${C_LIGHT_WHITE}${ip}${C_RESET}"
        echo "$ip" 
    else
        warn "无法自动获取公网IP地址。请手动确认。"
        echo "未知" 
    fi
}

check_firewall_rule_for_port() {
    local port=$1
    local protocol=${2:-tcp} 
    local port_allowed=false
    local firewall_checked="none"

    echo -e "${C_MSG_ACTION_TEXT}正在检查防火墙规则 (端口 ${C_BOLD}${port}/${protocol}${C_RESET})...${C_RESET}"
    echo -e "${C_HINT_TEXT}(这仅为基础检查，可能无法覆盖所有防火墙配置或云安全组规则)${C_RESET}"

    if command -v ufw &> /dev/null && sudo ufw status | grep -qw "Status: active"; then
        firewall_checked="ufw"
        if sudo ufw status verbose | grep -qw "${port}/${protocol}" | grep -qwi "ALLOW"; then
            port_allowed=true
            info "UFW: 端口 ${C_BOLD}${port}/${protocol}${C_RESET} 状态为 ${C_STATUS_ACTIVE}ALLOW${C_RESET}."
        else
            warn "UFW: 端口 ${C_BOLD}${port}/${protocol}${C_RESET} ${C_STATUS_INACTIVE}未明确允许 (或被拒绝)${C_RESET}。您可能需要执行: ${C_LIGHT_WHITE}sudo ufw allow ${port}/${protocol}${C_RESET}"
        fi
    fi

    if ! $port_allowed && command -v firewall-cmd &> /dev/null && sudo systemctl is-active --quiet firewalld; then
        firewall_checked="firewalld"
        local active_zones
        active_zones=$(sudo firewall-cmd --get-active-zones | grep -v "interfaces:" | awk '{print $1}')
        if [ -z "$active_zones" ]; then 
             active_zones=$(sudo firewall-cmd --get-default-zone)
        fi

        local found_in_firewalld=false
        for zone in $active_zones; do
            if sudo firewall-cmd --zone="$zone" --query-port="${port}/${protocol}" &>/dev/null; then
                port_allowed=true
                found_in_firewalld=true
                info "Firewalld: 端口 ${C_BOLD}${port}/${protocol}${C_RESET} 在区域 '${C_BOLD}${zone}${C_RESET}' 中状态为 ${C_STATUS_ACTIVE}允许${C_RESET}."
                break 
            fi
        done
        if ! $found_in_firewalld; then
             warn "Firewalld: 端口 ${C_BOLD}${port}/${protocol}${C_RESET} 在活动区域中 ${C_STATUS_INACTIVE}未明确允许${C_RESET}。您可能需要执行 (例如添加到public区域): ${C_LIGHT_WHITE}sudo firewall-cmd --permanent --add-port=${port}/${protocol} && sudo firewall-cmd --reload${C_RESET}"
        fi
    fi
    
    if [ "$firewall_checked" == "none" ]; then
        info "未检测到活动的 UFW 或 Firewalld。请根据您使用的防火墙手动检查端口 ${C_BOLD}${port}/${protocol}${C_RESET}。"
    fi
}


FRPS_SERVICE_NAME="frps.service"
FRPS_CONFIG_FILE="${FRP_INSTALL_DIR}/frps.ini"
FRPS_SYSTEMD_FILE="/etc/systemd/system/${FRPS_SERVICE_NAME}"
FRPS_BINARY_PATH="${FRP_INSTALL_DIR}/frps"

display_frps_connection_info() {
    echo -e "${C_SUB_MENU_TITLE}--- frps (服务端) 连接信息 ---${C_RESET}"
    if [ ! -f "$FRPS_CONFIG_FILE" ]; then
        warn "frps 配置文件 (${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_RESET}) 未找到。请先安装frps。"
        return
    fi

    local public_ip
    public_ip=$(get_public_ip) 

    local bind_addr_val=$(grep -E "^\s*bind_addr\s*=" "$FRPS_CONFIG_FILE" | cut -d '=' -f2 | tr -d ' ')
    local bind_port=$(grep -E "^\s*bind_port\s*=" "$FRPS_CONFIG_FILE" | cut -d '=' -f2 | tr -d ' ')
    local dashboard_port=$(grep -E "^\s*dashboard_port\s*=" "$FRPS_CONFIG_FILE" | cut -d '=' -f2 | tr -d ' ')
    local token_line=$(grep -E "^\s*token\s*=" "$FRPS_CONFIG_FILE") 
    local token_value=""
    local token_status="${C_LIGHT_WHITE}未配置 (或已注释)${C_RESET}"

    if [[ -n "$token_line" && ! "$token_line" =~ ^\s*# ]]; then 
        token_value=$(echo "$token_line" | cut -d '=' -f2 | tr -d ' ')
        if [ -n "$token_value" ]; then
            token_status="${C_BOLD}${C_LIGHT_GREEN}${token_value}${C_RESET}"
        fi
    fi


    echo -e "${C_WHITE}公网 IP 地址 (参考): ${C_BOLD}${C_LIGHT_WHITE}${public_ip}${C_RESET}"
    echo -e "${C_WHITE}服务端绑定地址 (bind_addr): ${C_BOLD}${C_LIGHT_WHITE}${bind_addr_val:-0.0.0.0 (frps默认)}${C_RESET}"
    echo -e "${C_WHITE}frpc 连接端口 (bind_port): ${C_BOLD}${C_LIGHT_WHITE}${bind_port:-未配置}${C_RESET}"
    if [ -n "$bind_port" ]; then
        check_firewall_rule_for_port "$bind_port" "tcp"
    fi
    echo -e "${C_WHITE}Dashboard 端口 (dashboard_port): ${C_BOLD}${C_LIGHT_WHITE}${dashboard_port:-未配置}${C_RESET}"
    if [ -n "$dashboard_port" ]; then
        check_firewall_rule_for_port "$dashboard_port" "tcp"
    fi
    echo -e "${C_WHITE}Token 认证: ${token_status}"
    
    echo -e "${C_HINT_TEXT}---"
    echo -e "${C_HINT_TEXT}frpc 客户端连接时应配置:${C_RESET}"
    echo -e "${C_HINT_TEXT}  server_addr = ${public_ip} (或您的frps服务器实际可访问IP)${C_RESET}"
    echo -e "${C_HINT_TEXT}  server_port = ${bind_port:-<frps_bind_port>}${C_RESET}"
    if [[ -n "$token_line" && ! "$token_line" =~ ^\s*# && -n "$token_value" ]]; then
        echo -e "${C_HINT_TEXT}  token = ${token_value}${C_RESET}"
    fi
    echo -e "${C_HINT_TEXT}请确保上述端口在您的服务器防火墙和云平台安全组中已正确开放。${C_RESET}"
}

generate_random_token() {
    if command -v openssl &> /dev/null; then
        openssl rand -hex 16 
    else
        date +%s%N | md5sum | head -c 32
    fi
}

install_or_update_frps() {
  echo -e "${C_SUB_MENU_TITLE}--- 安装/更新 frps (服务端) ---${C_RESET}"
  if ! determine_frp_version_to_install; then # 如果用户选择取消，则函数返回1
    return # 中止安装/更新
  fi
  # FRP_VERSION_TO_INSTALL 现在包含了用户选择的版本
  local version_to_install_no_v="${FRP_VERSION_TO_INSTALL#v}" 
  local force_reconfigure=false
  local proceed_with_binary_install=true

  if [ -f "$FRPS_BINARY_PATH" ]; then 
    local local_version=$("$FRPS_BINARY_PATH" --version 2>/dev/null)
    if [ -n "$local_version" ]; then
      info "当前已安装 frps 版本: ${C_LIGHT_WHITE}${local_version}${C_RESET}"
      if [ "$local_version" == "$version_to_install_no_v" ]; then # 与选定版本比较
        info "您选择安装的版本 (${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}) 已是当前安装版本。"
        read -p "$(echo -e "${C_MENU_PROMPT}是否仍要重新安装二进制文件? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]: ${C_RESET}")" reinstall_confirm
        if [[ ! "$reinstall_confirm" =~ ^[Yy]$ ]]; then
          info "取消重新安装二进制文件。"
          proceed_with_binary_install=false
        fi
      elif [[ "$local_version" > "$version_to_install_no_v" ]]; then 
        warn "当前安装版本 (${C_LIGHT_WHITE}${local_version}${C_RESET}) 高于您选择的版本 (${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET})。"
        read -p "$(echo -e "${C_MENU_PROMPT}是否仍要用选定版本覆盖安装二进制文件? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]: ${C_RESET}")" reinstall_confirm
        if [[ ! "$reinstall_confirm" =~ ^[Yy]$ ]]; then
          info "取消覆盖安装。"
          proceed_with_binary_install=false
        fi
      else
         info "准备从版本 ${local_version} 更新到 ${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}..."
      fi
    else
      warn "无法获取当前 frps 版本信息，将尝试安装/更新至 ${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}。"
    fi
    
    if [ -f "$FRPS_CONFIG_FILE" ]; then
        read -p "$(echo -e "${C_MENU_PROMPT}检测到现有配置，是否要重新配置frps (监听地址、端口、Dashboard、Token等)? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]: ${C_RESET}")" reconfigure_confirm
        if [[ "$reconfigure_confirm" =~ ^[Yy]$ ]]; then
            force_reconfigure=true
        else
            info "保留现有配置。"
        fi
    fi
    if ! $proceed_with_binary_install && ! $force_reconfigure; then
        display_frps_connection_info
        return
    fi
  fi 

  if $proceed_with_binary_install ; then
    if systemctl is-active --quiet "$FRPS_SERVICE_NAME"; then
        info "检测到 frps 服务正在运行，正在尝试停止它以便更新二进制文件..."
        if ! _manage_service "stop" "$FRPS_SERVICE_NAME" "frps"; then
            error "无法停止正在运行的 frps 服务 (${FRPS_SERVICE_NAME})。请手动停止后重试。"
        fi
    fi
    download_and_extract_frp "$FRP_VERSION_TO_INSTALL" "$FRP_ARCH" "frps" 
    echo -e "${C_MSG_ACTION_TEXT}⚙️ 正在安装 frps 到 ${C_PATH_INFO}${FRP_INSTALL_DIR}${C_MSG_ACTION_TEXT}...${C_RESET}"
    sudo mkdir -p "$FRP_INSTALL_DIR"
    sudo chmod +x "frps"
    sudo cp "frps" "${FRPS_BINARY_PATH}"
    cleanup_temp_files "$FRP_VERSION_TO_INSTALL" "$FRP_ARCH"
  fi
  
  if [ ! -f "$FRPS_CONFIG_FILE" ] || $force_reconfigure ; then 
    if $force_reconfigure && [ -f "$FRPS_CONFIG_FILE" ]; then
        info "准备重新配置，将移除现有配置文件: ${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_RESET}"
        sudo rm -f "$FRPS_CONFIG_FILE"
    fi
    echo -e "${C_MSG_ACTION_TEXT}📝 正在创建/重新配置 frps 配置文件 ${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_MSG_ACTION_TEXT}...${C_RESET}"
    
    local frps_bind_addr frps_bind_port frps_dashboard_port frps_dashboard_user frps_dashboard_pwd frps_token_choice frps_token_value
    
    echo -e "${C_MENU_PROMPT}请选择 frps 服务端绑定监听的地址类型:${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} 仅 IPv4 (${C_LIGHT_WHITE}0.0.0.0${C_RESET}) - 监听所有可用IPv4地址 ${C_HINT_TEXT}(默认)${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} 仅 IPv6 (${C_LIGHT_WHITE}::${C_RESET}) - 监听所有可用IPv6地址${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}3)${C_MENU_OPTION_TEXT} IPv4 和 IPv6 (${C_LIGHT_WHITE}::${C_RESET}) - 监听所有IPv6, 并可能接受IPv4 ${C_HINT_TEXT}(取决于系统 net.ipv6.bindv6only=0 设置)${C_RESET}"
    read -p "$(echo -e "${C_MENU_PROMPT}请输入选项 [1-3] (默认为 1): ${C_RESET}")" bind_addr_choice
    case "$bind_addr_choice" in
        2) frps_bind_addr="::" ;;
        3) frps_bind_addr="::" ;; 
        *) frps_bind_addr="0.0.0.0" ;; 
    esac
    info "bind_addr 将设置为: ${C_LIGHT_WHITE}${frps_bind_addr}${C_RESET}"

    read -p "$(echo -e "${C_MENU_PROMPT}请输入 frps 服务端监听端口 (bind_port) ${C_INPUT_EXAMPLE}(默认为 6000)${C_MENU_PROMPT}: ${C_RESET}")" frps_bind_port
    frps_bind_port=${frps_bind_port:-6000}
    
    read -p "$(echo -e "${C_MENU_PROMPT}请输入 frps Dashboard 访问端口 (dashboard_port) ${C_INPUT_EXAMPLE}(默认为 6050)${C_MENU_PROMPT}: ${C_RESET}")" frps_dashboard_port
    frps_dashboard_port=${frps_dashboard_port:-6050}

    read -p "$(echo -e "${C_MENU_PROMPT}请输入 frps Dashboard 用户名 (dashboard_user) ${C_INPUT_EXAMPLE}(默认为 admin)${C_MENU_PROMPT}: ${C_RESET}")" frps_dashboard_user
    frps_dashboard_user=${frps_dashboard_user:-admin}

    read -p "$(echo -e "${C_MENU_PROMPT}请输入 frps Dashboard 密码 (dashboard_pwd) ${C_INPUT_EXAMPLE}(默认为 admin, ${C_BOLD}${C_LIGHT_RED}强烈建议修改！${C_RESET}${C_INPUT_EXAMPLE})${C_MENU_PROMPT}: ${C_RESET}")" frps_dashboard_pwd
    frps_dashboard_pwd=${frps_dashboard_pwd:-admin}

    read -p "$(echo -e "${C_MENU_PROMPT}是否为 frps 配置 token 认证 (增强安全性)? [${C_CONFIRM_PROMPT}Y/n${C_MENU_PROMPT}]: ${C_RESET}")" frps_token_choice
    local token_config_line="# token = YOUR_VERY_SECRET_TOKEN" 
    if [[ "$frps_token_choice" =~ ^[Yy]$ ]]; then
        frps_token_value=$(generate_random_token)
        info "已生成随机 Token: ${C_LIGHT_WHITE}${frps_token_value}${C_RESET}"
        token_config_line="token = ${frps_token_value}"
    else
        info "未配置 Token 认证。"
    fi

    sudo tee "${FRPS_CONFIG_FILE}" > /dev/null <<EOF
[common]
bind_addr = ${frps_bind_addr}
bind_port = ${frps_bind_port}
dashboard_port = ${frps_dashboard_port}
dashboard_user = ${frps_dashboard_user}
dashboard_pwd = ${frps_dashboard_pwd}
${token_config_line}
# log_file = /var/log/frps.log 
# log_level = info 
# log_max_days = 3 
EOF
    echo -e "${C_MSG_SUCCESS_TEXT}✅ frps 配置文件已根据您的输入创建/更新。${C_RESET}"
  else
    info "保留现有 frps 配置文件: ${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_RESET}。"
  fi

  if [ ! -f "${FRPS_SYSTEMD_FILE}" ]; then
    echo -e "${C_MSG_ACTION_TEXT}🛠️ 正在创建 systemd 服务 ${C_BOLD}${FRPS_SERVICE_NAME}${C_MSG_ACTION_TEXT}...${C_RESET}"
    sudo tee "${FRPS_SYSTEMD_FILE}" > /dev/null <<EOF
[Unit]
Description=FRP Server Service
Documentation=https://gofrp.org/docs/
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=nobody
Group=nogroup
Restart=on-failure
RestartSec=5s
ExecStart=${FRPS_BINARY_PATH} -c ${FRPS_CONFIG_FILE}
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    _manage_service "enable" "$FRPS_SERVICE_NAME" "frps"
  fi
  _manage_service "restart" "$FRPS_SERVICE_NAME" "frps"
  
  display_frps_connection_info 
  echo -e "${C_MSG_SUCCESS_TEXT}🎉 frps 安装/更新完成！${C_RESET}"
}

uninstall_frps() {
    echo -e "${C_SUB_MENU_TITLE}--- 卸载 frps (服务端) ---${C_RESET}"
    if [ ! -f "$FRPS_BINARY_PATH" ] && [ ! -f "$FRPS_SYSTEMD_FILE" ] && ! systemctl list-units --full -all | grep -qF "${FRPS_SERVICE_NAME}"; then
        warn "frps 似乎未安装或已被移除。"
        return
    fi

    read -p "$(echo -e "${C_MENU_PROMPT}确认要卸载 frps 吗? 这将移除服务、二进制文件，并可选移除配置文件。[${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]?: ${C_RESET}")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "卸载操作已取消。"
        return
    fi

    if systemctl list-units --full -all | grep -qF "${FRPS_SERVICE_NAME}"; then
        _manage_service "stop" "$FRPS_SERVICE_NAME" "frps"
        _manage_service "disable" "$FRPS_SERVICE_NAME" "frps"
    fi
    
    if [ -f "$FRPS_SYSTEMD_FILE" ]; then
        echo -e "${C_MSG_ACTION_TEXT}正在移除 systemd 服务文件: ${C_PATH_INFO}${FRPS_SYSTEMD_FILE}${C_RESET}"
        sudo rm -f "$FRPS_SYSTEMD_FILE"
        sudo systemctl daemon-reload
    else
        info "frps systemd 服务文件未找到，跳过服务文件移除。"
    fi

    if [ -f "$FRPS_BINARY_PATH" ]; then
        echo -e "${C_MSG_ACTION_TEXT}正在移除 frps 二进制文件: ${C_PATH_INFO}${FRPS_BINARY_PATH}${C_RESET}"
        sudo rm -f "$FRPS_BINARY_PATH"
    else
        info "frps 二进制文件未找到，跳过二进制文件移除。"
    fi

    if [ -f "$FRPS_CONFIG_FILE" ]; then
        read -p "$(echo -e "${C_MENU_PROMPT}是否删除 frps 配置文件 (${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_MENU_PROMPT})? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]?: ${C_RESET}")" del_config
        if [[ "$del_config" =~ ^[Yy]$ ]]; then
            echo -e "${C_MSG_ACTION_TEXT}正在删除 frps 配置文件: ${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_RESET}"
            sudo rm -f "$FRPS_CONFIG_FILE"
        else
            info "保留 frps 配置文件: ${C_PATH_INFO}${FRPS_CONFIG_FILE}${C_RESET}"
        fi
    fi
    
    echo -e "${C_MSG_SUCCESS_TEXT}🎉 frps 卸载完成。${C_RESET}"
}

manage_frps_menu() {
  while true; do
    clear
    echo -e "${C_SUB_MENU_TITLE}\n--- frps (服务端) 管理 ---${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} 安装/更新 frps${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} 启动 frps 服务${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}3)${C_MENU_OPTION_TEXT} 停止 frps 服务${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}4)${C_MENU_OPTION_TEXT} 重启 frps 服务${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}5)${C_MENU_OPTION_TEXT} 查看 frps 服务状态${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}6)${C_MENU_OPTION_TEXT} ${C_LIGHT_BLUE}查看 frps 连接信息 (IP/端口/防火墙检查)${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}7)${C_MENU_OPTION_TEXT} 查看 frps 日志 ${C_HINT_TEXT}(实时, Ctrl+C 退出)${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}8)${C_MENU_OPTION_TEXT} 编辑 frps 配置文件${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}9)${C_MENU_OPTION_TEXT} ${C_LIGHT_RED}卸载 frps${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}0)${C_MENU_OPTION_TEXT} 返回主菜单${C_RESET}"
    echo -e "${C_SEPARATOR}----------------------------------------------------${C_RESET}"
    read -p "$(echo -e "${C_MENU_PROMPT}请输入选项: ${C_RESET}")" choice

    case $choice in
      1) install_or_update_frps ;;
      2) _manage_service "start" "$FRPS_SERVICE_NAME" "frps" ;;
      3) _manage_service "stop" "$FRPS_SERVICE_NAME" "frps" ;;
      4) _manage_service "restart" "$FRPS_SERVICE_NAME" "frps" ;;
      5) _manage_service "status" "$FRPS_SERVICE_NAME" "frps" ;;
      6) display_frps_connection_info ;;
      7) echo -e "${C_MSG_ACTION_TEXT}正在显示服务 frps 的最新日志 (按 Ctrl+C 退出)...${C_RESET}"; sudo journalctl -u "${FRPS_SERVICE_NAME}" -n 100 -f --no-pager ;;
      8) _manage_service "edit_config" "$FRPS_SERVICE_NAME" "frps" "$FRPS_CONFIG_FILE" ;;
      9) uninstall_frps ;;
      0) break ;;
      *) warn "无效选项。" ;;
    esac
    [[ "$choice" != "0" ]] && press_enter_to_continue
  done
}

FRPC_BINARY_PATH="${FRP_INSTALL_DIR}/frpc"
FRPC_SYSTEMD_TEMPLATE_FILE="/etc/systemd/system/frpc@.service"

install_or_update_frpc_binary() {
  echo -e "${C_SUB_MENU_TITLE}--- 安装/更新 frpc 客户端二进制文件 ---${C_RESET}"
  if ! determine_frp_version_to_install; then
    return
  fi
  local version_to_install_no_v="${FRP_VERSION_TO_INSTALL#v}"

  if [ -f "$FRPC_BINARY_PATH" ]; then
    local local_version=$("$FRPC_BINARY_PATH" --version 2>/dev/null)
    if [ -n "$local_version" ]; then
      info "当前已安装 frpc 版本: ${C_LIGHT_WHITE}${local_version}${C_RESET}"
      if [ "$local_version" == "$version_to_install_no_v" ]; then
        info "您选择安装的版本 (${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}) 已是当前安装版本。"
        read -p "$(echo -e "${C_MENU_PROMPT}是否仍要重新安装? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]: ${C_RESET}")" reinstall_confirm
        if [[ ! "$reinstall_confirm" =~ ^[Yy]$ ]]; then
          info "取消重新安装。"
          return
        fi
      elif [[ "$local_version" > "$version_to_install_no_v" ]]; then
        warn "当前安装版本 (${C_LIGHT_WHITE}${local_version}${C_RESET}) 高于您选择的版本 (${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET})。"
        read -p "$(echo -e "${C_MENU_PROMPT}是否仍要用选定版本覆盖安装? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]: ${C_RESET}")" reinstall_confirm
        if [[ ! "$reinstall_confirm" =~ ^[Yy]$ ]]; then
          info "取消覆盖安装。"
          return
        fi
      else
        info "准备从版本 ${local_version} 更新到 ${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}..."
      fi
    else
      warn "无法获取当前 frpc 版本信息，将尝试安装/更新至 ${C_LIGHT_WHITE}${FRP_VERSION_TO_INSTALL}${C_RESET}。"
    fi
  fi

  if [ -d "$FRPC_CLIENTS_DIR" ] && [ -n "$(ls -A ${FRPC_CLIENTS_DIR}/*.ini 2>/dev/null)" ]; then
    info "检测到 frpc 实例配置，正在尝试停止相关服务以便更新 frpc 二进制文件..."
    local all_stopped_successfully=true
    for conf_file_loop in ${FRPC_CLIENTS_DIR}/*.ini; do
        local instance_name_loop=$(basename "$conf_file_loop" .ini)
        local service_name_loop="frpc@${instance_name_loop}.service"
        if systemctl is-active --quiet "$service_name_loop"; then
            if ! _manage_service "stop" "$service_name_loop" "frpc 实例 [${instance_name_loop}]"; then
                all_stopped_successfully=false
            fi
        fi
    done
    if ! $all_stopped_successfully ; then
        error "并非所有活动的 frpc 实例都已成功停止。请手动检查并停止相关服务后重试。"
    else
        info "所有检测到的 frpc 实例服务已停止或处于非活动状态。"
    fi
  fi
  
  download_and_extract_frp "$FRP_VERSION_TO_INSTALL" "$FRP_ARCH" "frpc"

  echo -e "${C_MSG_ACTION_TEXT}⚙️ 正在安装 frpc 二进制文件到 ${C_PATH_INFO}${FRP_INSTALL_DIR}${C_MSG_ACTION_TEXT}...${C_RESET}"
  sudo mkdir -p "$FRP_INSTALL_DIR"
  sudo chmod +x "frpc"
  sudo cp "frpc" "${FRPC_BINARY_PATH}"
  
  cleanup_temp_files "$FRP_VERSION_TO_INSTALL" "$FRP_ARCH"
  
  if [ -f "${FRPC_BINARY_PATH}" ]; then
    echo -e "${C_MSG_SUCCESS_TEXT}✅ frpc 二进制文件已成功安装到 ${C_PATH_INFO}${FRPC_BINARY_PATH}${C_RESET}"
    "${FRPC_BINARY_PATH}" --version
    info "请注意：如果之前有正在运行的 frpc 实例，您可能需要手动启动它们，或通过'管理指定frpc实例'菜单启动。"
  else
    error "frpc 二进制文件安装失败。"
  fi
}

uninstall_frpc_binary() {
    echo -e "${C_SUB_MENU_TITLE}--- 卸载 frpc 客户端二进制文件 ---${C_RESET}"
    if [ ! -f "$FRPC_BINARY_PATH" ] && [ ! -f "$FRPC_SYSTEMD_TEMPLATE_FILE" ]; then
        warn "frpc 二进制文件和模板文件均未找到，可能已被移除。"
    fi

    if [ -d "$FRPC_CLIENTS_DIR" ] && [ -n "$(ls -A ${FRPC_CLIENTS_DIR}/*.ini 2>/dev/null)" ]; then
        warn "检测到活动的 frpc 客户端实例配置。请先从 'frpc (客户端) 实例管理' 菜单中删除所有实例，然后再卸载 frpc 二进制文件。"
        return
    fi

    read -p "$(echo -e "${C_MENU_PROMPT}确认要卸载 frpc 二进制文件吗? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]?: ${C_RESET}")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "卸载操作已取消。"
        return
    fi

    if [ -f "$FRPC_BINARY_PATH" ]; then
        echo -e "${C_MSG_ACTION_TEXT}正在移除 frpc 二进制文件: ${C_PATH_INFO}${FRPC_BINARY_PATH}${C_RESET}"
        sudo rm -f "$FRPC_BINARY_PATH"
    else
        info "frpc 二进制文件 (${C_PATH_INFO}${FRPC_BINARY_PATH}${C_RESET}) 未找到，跳过移除。"
    fi

    if [ -f "$FRPC_SYSTEMD_TEMPLATE_FILE" ]; then
        read -p "$(echo -e "${C_MENU_PROMPT}是否删除 frpc systemd 模板文件 (${C_PATH_INFO}${FRPC_SYSTEMD_TEMPLATE_FILE}${C_MENU_PROMPT})? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]?: ${C_RESET}")" del_template
        if [[ "$del_template" =~ ^[Yy]$ ]]; then
            echo -e "${C_MSG_ACTION_TEXT}正在删除 frpc systemd 模板文件: ${C_PATH_INFO}${FRPC_SYSTEMD_TEMPLATE_FILE}${C_RESET}"
            sudo rm -f "$FRPC_SYSTEMD_TEMPLATE_FILE"
            sudo systemctl daemon-reload
        else
            info "保留 frpc systemd 模板文件。"
        fi
    else
        info "frpc systemd 模板文件未找到，跳过移除。"
    fi

    if [ -d "$FRPC_CLIENTS_DIR" ] && [ -z "$(ls -A ${FRPC_CLIENTS_DIR} 2>/dev/null)" ]; then 
        read -p "$(echo -e "${C_MENU_PROMPT}frpc 客户端配置目录 (${C_PATH_INFO}${FRPC_CLIENTS_DIR}${C_MENU_PROMPT}) 为空，是否删除? [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]?: ${C_RESET}")" del_clients_dir
        if [[ "$del_clients_dir" =~ ^[Yy]$ ]]; then
            echo -e "${C_MSG_ACTION_TEXT}正在删除 frpc 客户端配置目录: ${C_PATH_INFO}${FRPC_CLIENTS_DIR}${C_RESET}"
            sudo rm -rf "$FRPC_CLIENTS_DIR" 
        else
            info "保留 frpc 客户端配置目录。"
        fi
    elif [ -d "$FRPC_CLIENTS_DIR" ]; then 
         info "frpc 客户端配置目录 (${C_PATH_INFO}${FRPC_CLIENTS_DIR}${C_RESET}) 不为空 (可能包含实例配置)，将予以保留。"
    fi

    echo -e "${C_MSG_SUCCESS_TEXT}🎉 frpc 二进制文件相关卸载操作完成。${C_RESET}"
}

manage_frpc_binary_menu() {
    while true; do
        clear
        echo -e "${C_SUB_MENU_TITLE}\n--- frpc (客户端) 二进制文件管理 ---${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} 安装/更新 frpc 二进制文件${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} 显示当前 frpc 版本 ${C_HINT_TEXT}(如果已安装)${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}3)${C_MENU_OPTION_TEXT} ${C_LIGHT_RED}卸载 frpc 二进制文件${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}4)${C_MENU_OPTION_TEXT} 返回主菜单${C_RESET}"
        echo -e "${C_SEPARATOR}------------------------------------------${C_RESET}"
        read -p "$(echo -e "${C_MENU_PROMPT}请输入选项: ${C_RESET}")" choice
        case $choice in
            1) install_or_update_frpc_binary ;;
            2) 
                if [ -f "${FRPC_BINARY_PATH}" ]; then
                    "${FRPC_BINARY_PATH}" --version
                else
                    warn "frpc 二进制文件未安装。"
                fi
                ;;
            3) uninstall_frpc_binary ;;
            4) break ;;
            *) warn "无效选项。" ;;
        esac
        [[ "$choice" != "4" ]] && press_enter_to_continue
    done
}

FRPC_SYSTEMD_TEMPLATE_NAME="frpc@.service" 

create_frpc_systemd_template_if_not_exists() {
  if [ ! -f "$FRPC_SYSTEMD_TEMPLATE_FILE" ]; then
    echo -e "${C_MSG_ACTION_TEXT}🛠️ 正在创建 frpc systemd 模板文件: ${C_PATH_INFO}${FRPC_SYSTEMD_TEMPLATE_FILE}${C_MSG_ACTION_TEXT}...${C_RESET}"
    sudo tee "$FRPC_SYSTEMD_TEMPLATE_FILE" > /dev/null <<EOF
[Unit]
Description=FRP Client Service for %I
Documentation=https://gofrp.org/docs/
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=nobody
Group=nogroup
Restart=on-failure
RestartSec=5s
ExecStart=${FRPC_BINARY_PATH} -c ${FRPC_CLIENTS_DIR}/%i.ini
ExecReload=${FRPC_BINARY_PATH} reload -c ${FRPC_CLIENTS_DIR}/%i.ini --uc
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    echo -e "${C_MSG_SUCCESS_TEXT}✅ frpc systemd 模板文件已创建。${C_RESET}"
  fi
}

add_frpc_instance() {
  echo -e "${C_SUB_MENU_TITLE}--- 添加新的 frpc 客户端实例 ---${C_RESET}"
  if [ ! -f "${FRPC_BINARY_PATH}" ]; then
    warn "frpc 二进制文件未找到。请先从 'frpc 二进制文件管理' 菜单安装。"
    return
  fi
  create_frpc_systemd_template_if_not_exists 
  sudo mkdir -p "$FRPC_CLIENTS_DIR" 

  local instance_name
  while true; do
    read -p "$(echo -e "${C_MENU_PROMPT}请输入此 frpc 实例的唯一名称 ${C_INPUT_EXAMPLE}(例如: server_A, 只能用字母数字下划线)${C_MENU_PROMPT}: ${C_RESET}")" instance_name
    instance_name=$(echo "$instance_name" | tr -dc '[:alnum:]_') 
    if [ -z "$instance_name" ]; then
      warn "实例名称不能为空。"
    elif [ -f "${FRPC_CLIENTS_DIR}/${instance_name}.ini" ]; then 
      warn "实例名称 '${C_BOLD}${instance_name}${C_RESET}' 已存在。请选择其他名称。"
    else
      break
    fi
  done
  
  local conf_file_path="${FRPC_CLIENTS_DIR}/${instance_name}.ini"
  local service_name="frpc@${instance_name}.service" 

  read -p "$(echo -e "${C_MENU_PROMPT}请输入此实例连接的 FRP 服务端公网 IP 地址或域名: ${C_RESET}")" server_addr
  while [[ -z "$server_addr" ]]; do read -p "$(echo -e "${C_MENU_PROMPT}服务端地址不能为空，请重新输入: ${C_RESET}")" server_addr; done
  
  read -p "$(echo -e "${C_MENU_PROMPT}请输入 FRP 服务端端口 ${C_INPUT_EXAMPLE}(默认为 6000)${C_MENU_PROMPT}: ${C_RESET}")" server_port; server_port=${server_port:-6000}

  local admin_port_default=$((7401 + $(ls -1qA ${FRPC_CLIENTS_DIR}/*.ini 2>/dev/null | wc -l)))
  read -p "$(echo -e "${C_MENU_PROMPT}请输入此 frpc 实例的本地管理端口 ${C_INPUT_EXAMPLE}(用于热重载, 默认为 ${admin_port_default}, 确保唯一)${C_MENU_PROMPT}: ${C_RESET}")" admin_port; admin_port=${admin_port:-$admin_port_default}
  
  local frpc_token_value
  read -p "$(echo -e "${C_MENU_PROMPT}请输入 frpc 连接到服务端的 token ${C_INPUT_EXAMPLE}(如果 frps 服务端未配置 token，请直接回车)${C_MENU_PROMPT}: ${C_RESET}")" frpc_token_value
  local frpc_token_config_line="# token = YOUR_VERY_SECRET_TOKEN" 
  if [ -n "$frpc_token_value" ]; then
      frpc_token_config_line="token = ${frpc_token_value}"
      info "frpc token 将设置为: ${C_LIGHT_WHITE}${frpc_token_value}${C_RESET}"
  else
      info "frpc 将不配置 token (或使用注释掉的默认值)。"
  fi


  echo -e "${C_MSG_ACTION_TEXT}📝 正在创建配置文件 ${C_PATH_INFO}${conf_file_path}${C_MSG_ACTION_TEXT}...${C_RESET}"
  sudo tee "${conf_file_path}" > /dev/null <<EOF
[common]
server_addr = ${server_addr}
server_port = ${server_port}
${frpc_token_config_line}

admin_addr = 127.0.0.1
admin_port = ${admin_port}
# log_file = /var/log/frpc_${instance_name}.log 
# log_level = info

[ssh_example_for_${instance_name}] 
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6022 
EOF
  echo -e "${C_MSG_SUCCESS_TEXT}✅ 配置文件 ${C_PATH_INFO}${conf_file_path}${C_MSG_SUCCESS_TEXT} 已创建。${C_RESET}"
  info "   请编辑此文件添加您需要的代理配置，例如将 [ssh_example_for_${instance_name}] 的 remote_port 修改为合适的值。"

  _manage_service "enable" "$service_name" "frpc 实例 [${instance_name}]"
  _manage_service "restart" "$service_name" "frpc 实例 [${instance_name}]"
  echo -e "${C_MSG_INFO_TEXT}👉 如需修改此实例的代理配置, 请编辑 ${C_PATH_INFO}${conf_file_path}${C_MSG_INFO_TEXT} 然后使用 '管理指定 frpc 实例' 菜单中的 '重载配置' 选项。${C_RESET}"
}

declare -g selected_instance_name="" 
declare -g selected_instance_service_name=""
declare -g selected_instance_config_file=""

select_frpc_instance() {
    selected_instance_name="" 
    echo -e "${C_SUB_MENU_TITLE}--- frpc 客户端实例列表 ---${C_RESET}"
    if [ ! -d "$FRPC_CLIENTS_DIR" ] || [ -z "$(ls -A ${FRPC_CLIENTS_DIR}/*.ini 2>/dev/null)" ]; then
        info "没有找到任何 frpc 客户端实例的配置文件。"
        return 1 
    fi
  
    local i=0
    declare -a instance_options=() 
    for conf_file in ${FRPC_CLIENTS_DIR}/*.ini; do
        local instance_name_from_file=$(basename "$conf_file" .ini)
        instance_options+=("$instance_name_from_file")
        local status_color="${C_STATUS_INACTIVE}(inactive/not found)${C_RESET}"
        if sudo systemctl is-active --quiet "frpc@${instance_name_from_file}.service"; then
            status_color="${C_STATUS_ACTIVE}(active)${C_RESET}"
        elif ! systemctl list-units --full -all | grep -qF "frpc@${instance_name_from_file}.service"; then
            status_color="${C_STATUS_NOT_FOUND}(service unit not found)${C_RESET}"
        fi
        echo -e "  ${C_MENU_OPTION_NUM}$((i+1)))${C_MENU_OPTION_TEXT} ${instance_name_from_file} ${status_color}"
        i=$((i+1))
    done
    echo -e "  ${C_MENU_OPTION_NUM}0)${C_MENU_OPTION_TEXT} 取消${C_RESET}"

    read -p "$(echo -e "${C_MENU_PROMPT}请选择一个 frpc 实例进行操作: ${C_RESET}")" choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ]; then
        info "操作已取消。"
        return 1
    fi
  
    local index=$((choice-1))
    if [ -z "${instance_options[$index]}" ]; then
        warn "无效的选择。"
        return 1
    fi

    selected_instance_name="${instance_options[$index]}"
    selected_instance_service_name="frpc@${selected_instance_name}.service"
    selected_instance_config_file="${FRPC_CLIENTS_DIR}/${selected_instance_name}.ini"
    info "已选择实例: ${C_BOLD}${selected_instance_name}${C_RESET}"
    return 0 
}

delete_frpc_instance() {
  echo -e "${C_SUB_MENU_TITLE}--- 删除 frpc 客户端实例 ---${C_RESET}"
  if ! select_frpc_instance; then return; fi 
  
  read -p "$(echo -e "${C_MENU_PROMPT}确认删除 frpc 实例 '${C_BOLD}${selected_instance_name}${C_RESET}${C_MENU_PROMPT}' 吗? ${C_HINT_TEXT}(配置文件和服务将被移除)${C_MENU_PROMPT} [${C_CONFIRM_PROMPT}y/N${C_MENU_PROMPT}]?: ${C_RESET}")" confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    _manage_service "stop" "$selected_instance_service_name" "frpc 实例 [${selected_instance_name}]"
    _manage_service "disable" "$selected_instance_service_name" "frpc 实例 [${selected_instance_name}]"
    
    echo -e "${C_MSG_ACTION_TEXT}正在删除配置文件 ${C_PATH_INFO}${selected_instance_config_file}${C_MSG_ACTION_TEXT}...${C_RESET}"
    sudo rm -f "${selected_instance_config_file}"
    
    sudo systemctl daemon-reload 
    echo -e "${C_MSG_SUCCESS_TEXT}✅ frpc 实例 '${C_BOLD}${selected_instance_name}${C_RESET}${C_MSG_SUCCESS_TEXT}' 已删除。${C_RESET}"
  else
    info "删除操作已取消。"
  fi
}

display_frpc_instance_connection_info() {
    if [ -z "$selected_instance_name" ]; then
        warn "错误：没有选定的 frpc 实例。"
        return
    fi
    if [ ! -f "$selected_instance_config_file" ]; then
        warn "frpc 实例配置文件 (${C_PATH_INFO}${selected_instance_config_file}${C_RESET}) 未找到。"
        return
    fi

    echo -e "${C_SUB_MENU_TITLE}--- frpc 实例 [${C_BOLD}${selected_instance_name}${C_SUB_MENU_TITLE}] 连接配置详情 ---${C_RESET}"
    
    local server_addr=$(grep -E "^\s*server_addr\s*=" "$selected_instance_config_file" | cut -d '=' -f2 | tr -d ' ')
    local server_port=$(grep -E "^\s*server_port\s*=" "$selected_instance_config_file" | cut -d '=' -f2 | tr -d ' ')
    local token_line=$(grep -E "^\s*token\s*=" "$selected_instance_config_file")
    local token_value=""
    local token_status="${C_LIGHT_WHITE}未配置 (或已注释)${C_RESET}"

    if [[ -n "$token_line" && ! "$token_line" =~ ^\s*# ]]; then
        token_value=$(echo "$token_line" | cut -d '=' -f2 | tr -d ' ')
        if [ -n "$token_value" ]; then
            token_status="${C_BOLD}${C_LIGHT_GREEN}${token_value}${C_RESET}"
        fi
    fi

    local admin_addr=$(grep -E "^\s*admin_addr\s*=" "$selected_instance_config_file" | cut -d '=' -f2 | tr -d ' ')
    local admin_port=$(grep -E "^\s*admin_port\s*=" "$selected_instance_config_file" | cut -d '=' -f2 | tr -d ' ')

    echo -e "${C_WHITE}连接到服务端 (server_addr): ${C_BOLD}${C_LIGHT_WHITE}${server_addr:-未配置}${C_RESET}"
    echo -e "${C_WHITE}服务端端口 (server_port): ${C_BOLD}${C_LIGHT_WHITE}${server_port:-未配置}${C_RESET}"
    echo -e "${C_WHITE}Token 认证: ${token_status}"
    echo -e "${C_WHITE}本地管理地址 (admin_addr): ${C_BOLD}${C_LIGHT_WHITE}${admin_addr:-未配置}${C_RESET}"
    echo -e "${C_WHITE}本地管理端口 (admin_port): ${C_BOLD}${C_LIGHT_WHITE}${admin_port:-未配置}${C_RESET}"
    
    echo -e "\n${C_SECTION_HEADER}此实例配置的代理 (Proxies):${C_RESET}"
    local proxy_config
    proxy_config=$(awk '/^\[common\]/,/^\[/{next} /^\[.*\]/{p=1;print;next} p' "$selected_instance_config_file")

    if [ -n "$proxy_config" ]; then
        echo -e "${C_WHITE}${proxy_config}${C_RESET}"
    else
        info "此实例当前未配置任何代理 (除了 [common] 部分)。"
    fi
    echo -e "${C_HINT_TEXT}---"
    echo -e "${C_HINT_TEXT}请确保服务端 (${server_addr}:${server_port}) 正在运行且网络可达。${C_RESET}"
    echo -e "${C_HINT_TEXT}如果服务端配置了token，请确保此处的token与之匹配。${C_RESET}"
}


manage_single_frpc_instance_menu() {
    if [ -z "$selected_instance_name" ]; then 
        warn "错误：没有选定的 frpc 实例。"
        return
    fi
    local display_name="frpc 实例 [${selected_instance_name}]" 
    while true; do
        clear
        echo -e "${C_SUB_MENU_TITLE}\n--- 管理 frpc 实例: ${C_BOLD}${selected_instance_name}${C_SUB_MENU_TITLE} ---${C_RESET}"
        echo -e "${C_WHITE}  服务名: ${C_PATH_INFO}${selected_instance_service_name}${C_RESET}"
        echo -e "${C_WHITE}  配置文件: ${C_PATH_INFO}${selected_instance_config_file}${C_RESET}"
        echo -e "${C_SEPARATOR}------------------------------------------${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} 启动此实例服务${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} 停止此实例服务${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}3)${C_MENU_OPTION_TEXT} 重启此实例服务${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}4)${C_MENU_OPTION_TEXT} 重载此实例配置 ${C_HINT_TEXT}(reload)${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}5)${C_MENU_OPTION_TEXT} 查看此实例服务状态${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}6)${C_MENU_OPTION_TEXT} ${C_LIGHT_BLUE}查看此实例连接配置详情${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}7)${C_MENU_OPTION_TEXT} 查看此实例日志 ${C_HINT_TEXT}(实时, Ctrl+C 退出)${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}8)${C_MENU_OPTION_TEXT} 编辑此实例配置文件${C_RESET}"
        echo -e "  ${C_MENU_OPTION_NUM}9)${C_MENU_OPTION_TEXT} 返回上一级菜单${C_RESET}"
        echo -e "${C_SEPARATOR}------------------------------------------${C_RESET}"
        read -p "$(echo -e "${C_MENU_PROMPT}请输入选项: ${C_RESET}")" choice

        case $choice in
            1) _manage_service "start" "$selected_instance_service_name" "$display_name" ;;
            2) _manage_service "stop" "$selected_instance_service_name" "$display_name" ;;
            3) _manage_service "restart" "$selected_instance_service_name" "$display_name" ;;
            4) _manage_service "reload" "$selected_instance_service_name" "$display_name" ;;
            5) _manage_service "status" "$selected_instance_service_name" "$display_name" ;;
            6) display_frpc_instance_connection_info ;;
            7) echo -e "${C_MSG_ACTION_TEXT}正在显示服务 ${display_name} 的最新日志 (按 Ctrl+C 退出)...${C_RESET}"; sudo journalctl -u "${selected_instance_service_name}" -n 100 -f --no-pager ;;
            8) _manage_service "edit_config" "$selected_instance_service_name" "$display_name" "$selected_instance_config_file" ;;
            9) break ;;
            *) warn "无效选项。" ;;
        esac
        [[ "$choice" != "9" ]] && press_enter_to_continue
    done
}

list_all_frpc_instances_status() {
    echo -e "${C_SUB_MENU_TITLE}--- 所有 frpc 客户端实例状态 ---${C_RESET}"
    if [ ! -d "$FRPC_CLIENTS_DIR" ] || [ -z "$(ls -A ${FRPC_CLIENTS_DIR}/*.ini 2>/dev/null)" ]; then
        info "没有找到任何 frpc 客户端实例的配置文件。"
        return
    fi
    
    printf "${C_BOLD}${C_WHITE}%-25s | %-35s | %s${C_RESET}\n" "实例名称" "服务单元名" "当前状态"
    echo -e "${C_SEPARATOR}-----------------------------------------------------------------------------${C_RESET}"

    for conf_file_loop in ${FRPC_CLIENTS_DIR}/*.ini; do 
        local instance_name_loop=$(basename "$conf_file_loop" .ini)
        local service_name_loop="frpc@${instance_name_loop}.service"
        local status_text
        if sudo systemctl is-active --quiet "$service_name_loop"; then
            status_text="${C_STATUS_ACTIVE}active (running)${C_RESET}"
        else
            if systemctl list-units --full -all | grep -qF "$service_name_loop"; then
                 status_text="${C_STATUS_INACTIVE}inactive (dead)${C_RESET}"
            else
                 status_text="${C_STATUS_NOT_FOUND}(service unit not found)${C_RESET}" 
            fi
        fi
        printf "${C_WHITE}%-25s ${C_SEPARATOR}|${C_RESET} ${C_PATH_INFO}%-35s ${C_SEPARATOR}|${C_RESET} %s\n" "$instance_name_loop" "$service_name_loop" "$status_text"
    done
}

manage_frpc_main_menu() {
  while true; do
    clear
    echo -e "${C_SUB_MENU_TITLE}\n--- frpc (客户端) 实例管理 ---${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} 添加新的 frpc 客户端实例${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} ${C_LIGHT_RED}删除 frpc 客户端实例${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}3)${C_MENU_OPTION_TEXT} 管理指定的 frpc 实例 ${C_HINT_TEXT}(启停/配置/日志等)${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}4)${C_MENU_OPTION_TEXT} 查看所有 frpc 实例状态${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}5)${C_MENU_OPTION_TEXT} 返回主菜单${C_RESET}"
    echo -e "${C_SEPARATOR}-------------------------------------------------${C_RESET}"
    read -p "$(echo -e "${C_MENU_PROMPT}请输入选项: ${C_RESET}")" sub_choice

    case $sub_choice in
      1) add_frpc_instance ;;
      2) delete_frpc_instance ;;
      3) 
        if select_frpc_instance; then 
            manage_single_frpc_instance_menu 
        fi
        ;;
      4) list_all_frpc_instances_status ;;
      5) break ;;
      *) warn "无效选项。" ;;
    esac
    [[ "$sub_choice" != "5" ]] && press_enter_to_continue
  done
}

show_all_frp_services_status() {
    clear
    echo -e "${C_MAIN_TITLE}--- 所有 FRP 服务状态概览 ---${C_RESET}"
    
    echo -e "\n${C_SECTION_HEADER}[服务端 frps]${C_RESET}"
    if systemctl list-units --full -all | grep -qF "${FRPS_SERVICE_NAME}"; then 
        _manage_service "status" "$FRPS_SERVICE_NAME" "frps"
    else
        info "frps 服务 (${C_BOLD}${FRPS_SERVICE_NAME}${C_RESET}) 未安装或 systemd 单元文件不存在。"
    fi

    echo -e "\n${C_SECTION_HEADER}[客户端 frpc 实例]${C_RESET}"
    list_all_frpc_instances_status 
}

setup_zzfrp_shortcut_if_needed() {
    if [ -p /dev/stdin ]; then
        info "脚本正通过管道执行 (例如: curl ... | sudo bash)。"
        warn "在此模式下，无法自动设置 '${C_BOLD}zzfrp${C_RESET}' 快捷指令。"
        info "要启用快捷指令，请先将脚本下载到本地文件 (例如 zzfrp.sh)，"
        info "然后通过 '${C_BOLD}sudo ./zzfrp.sh${C_RESET}' 运行它，脚本会自动尝试设置快捷方式。"
        return
    fi

    if [ -f "$SHORTCUT_SETUP_FLAG_FILE" ]; then
        return 
    fi
    
    if ! sudo mkdir -p "$FRP_INSTALL_DIR"; then
        warn "无法创建目录 ${C_PATH_INFO}${FRP_INSTALL_DIR}${C_RESET}，快捷指令设置的标记文件可能无法创建。"
    fi

    local current_script_path
    current_script_path=$(readlink -f "$0") 

    echo -e "${C_MSG_ACTION_TEXT}正在检查/设置快捷指令 '${C_BOLD}zzfrp${C_RESET}${C_MSG_ACTION_TEXT}'...${C_RESET}"
    if [ -f "$ZZFRP_COMMAND_PATH" ] && [ "$(readlink -f "$ZZFRP_COMMAND_PATH")" != "$current_script_path" ]; then
        warn "检测到 ${C_PATH_INFO}${ZZFRP_COMMAND_PATH}${C_RESET} 已存在且指向其他程序。"
        warn "自动设置快捷指令 '${C_BOLD}zzfrp${C_RESET}' 失败。您可以手动将其链接到: ${C_PATH_INFO}${current_script_path}${C_RESET}"
    else
        local existing_zzfrp_path=""
        if command -v zzfrp >/dev/null; then
            existing_zzfrp_path=$(readlink -f "$(command -v zzfrp)")
        fi

        if [ "$existing_zzfrp_path" != "$current_script_path" ]; then
            echo -e "${C_MSG_ACTION_TEXT}正在尝试将当前脚本复制到 ${C_PATH_INFO}${ZZFRP_COMMAND_PATH}${C_MSG_ACTION_TEXT}...${C_RESET}"
            if sudo cp "$current_script_path" "$ZZFRP_COMMAND_PATH" && sudo chmod +x "$ZZFRP_COMMAND_PATH"; then
                echo -e "${C_MSG_SUCCESS_TEXT}✅ 快捷指令 '${C_BOLD}zzfrp${C_RESET}${C_MSG_SUCCESS_TEXT}' 已成功设置为指向当前脚本。${C_RESET}"
                info "下次可直接使用 '${C_BOLD}sudo zzfrp${C_RESET}' 运行此脚本。"
            else
                warn "设置快捷指令 '${C_BOLD}zzfrp${C_RESET}' 到 ${C_PATH_INFO}${ZZFRP_COMMAND_PATH}${C_RESET} 失败。请检查权限或手动设置。"
            fi
        else
             info "快捷指令 '${C_BOLD}zzfrp${C_RESET}' 已正确配置为指向当前脚本。"
        fi
    fi
    
    if sudo touch "$SHORTCUT_SETUP_FLAG_FILE"; then
        info "已标记快捷指令设置尝试完成。"
    else
        warn "无法创建标记文件 ${C_PATH_INFO}${SHORTCUT_SETUP_FLAG_FILE}${C_RESET}。"
    fi
    press_enter_to_continue
}

main_menu() {
  check_root    
  check_tools   
  setup_zzfrp_shortcut_if_needed

  local shortcut_hint=""
  if ! [ -p /dev/stdin ] && command -v zzfrp &>/dev/null && [ -x "$ZZFRP_COMMAND_PATH" ]; then
      local resolved_zzfrp_path
      resolved_zzfrp_path=$(readlink -f "$(command -v zzfrp)")
      local current_script_real_path=$(readlink -f "$0")
      if [ "$resolved_zzfrp_path" == "$ZZFRP_COMMAND_PATH" ] && [ "$ZZFRP_COMMAND_PATH" == "$current_script_real_path" ]; then
          shortcut_hint="  快捷启动: ${C_BOLD}sudo zzfrp${C_RESET}"
      elif [ "$resolved_zzfrp_path" == "$current_script_real_path" ]; then 
           shortcut_hint="  快捷启动: ${C_BOLD}sudo zzfrp${C_RESET}"
      fi
  fi
  
  while true; do
    clear
    echo -e "${C_MAIN_TITLE}\n========== zzfrp 管理脚本 by:RY-zzcn ==========${C_RESET}" 
    echo -e "${C_WHITE}  frp版本：by:fatedier ${C_RESET}"
    if [ -n "$shortcut_hint" ]; then
        echo -e "${C_HINT_TEXT}${shortcut_hint}${C_RESET}"
    fi
    echo -e "${C_WHITE}  脚本地址: ${C_UNDERLINE}${C_BLUE}${SCRIPT_REPO_URL}${C_RESET}"
    echo -e "${C_WHITE}  FRP 安装目录: ${C_PATH_INFO}${FRP_INSTALL_DIR}${C_RESET}"
    echo -e "${C_WHITE}  frpc 实例配置: ${C_PATH_INFO}${FRPC_CLIENTS_DIR}${C_RESET}"
    echo -e "${C_SEPARATOR}----------------------------------------------${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}1)${C_MENU_OPTION_TEXT} frps (服务端) 管理${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}2)${C_MENU_OPTION_TEXT} frpc (客户端) 二进制文件管理${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}3)${C_MENU_OPTION_TEXT} frpc (客户端) 实例管理${C_RESET}"
    echo -e "  ${C_MENU_OPTION_NUM}4)${C_MENU_OPTION_TEXT} 查看所有 zzfrp 服务状态${C_RESET}" 
    echo -e "  ${C_MENU_OPTION_NUM}5)${C_MENU_OPTION_TEXT} ${C_LIGHT_RED}退出脚本${C_RESET}"
    echo -e "${C_SEPARATOR}----------------------------------------------${C_RESET}"
    read -p "$(echo -e "${C_MENU_PROMPT}请输入选项 [1-5]: ${C_RESET}")" main_choice

    case $main_choice in
      1) manage_frps_menu ;;
      2) manage_frpc_binary_menu ;;
      3) manage_frpc_main_menu ;;
      4) show_all_frp_services_status ;; 
      5) echo -e "${C_MAIN_TITLE}脚本退出。感谢使用 zzfrp 管理脚本 by:RY-zzcn！${C_RESET}"; exit 0 ;; 
      *) warn "无效选项。" ;;
    esac
    [[ "$main_choice" != "5" ]] && press_enter_to_continue
  done
}

main_menu
