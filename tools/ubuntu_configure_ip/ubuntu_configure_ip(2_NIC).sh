#!/bin/bash

# 网络配置脚本
# 用法: sudo ./network_config.sh [-f] <配置文件路径>

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
FORCE_MODE=false
CONFIG_FILE=""
NETPLAN_DIR="/etc/netplan"
BACKUP_DIR="/etc/netplan/backups"
CURRENT_NETPLAN_FILE=""
BACKUP_FILE=""
ORIGINAL_CONFIG=""

# 显示带颜色的消息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示用法
show_usage() {
    echo "用法: $0 [-f] <配置文件路径>"
    echo "选项:"
    echo "  -f    强制模式，即使网络测试失败也不回退配置"
    echo "示例:"
    echo "  $0 network.conf"
    echo "  $0 -f /path/to/network.conf"
    exit 1
}

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用sudo或以root权限运行此脚本"
        exit 1
    fi
}

# 解析命令行参数
parse_args() {
    while getopts "f" opt; do
        case $opt in
            f)
                FORCE_MODE=true
                ;;
            *)
                show_usage
                ;;
        esac
    done

    shift $((OPTIND-1))

    if [ $# -ne 1 ]; then
        show_usage
    fi

    CONFIG_FILE="$1"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
}

# 停止并禁用cloud-init网络服务
disable_cloud_init() {
    log_info "检查并禁用cloud-init网络配置..."

    # 检查cloud-init是否安装
    if systemctl list-unit-files | grep -q cloud-init; then
        # 禁用cloud-init的network配置
        if [ -f /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg ]; then
            log_info "cloud-init网络配置已禁用"
        else
            echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
            log_success "已禁用cloud-init网络配置"
        fi

        # 停止cloud-init服务
        systemctl stop cloud-init 2>/dev/null || true
        systemctl disable cloud-init 2>/dev/null || true
        systemctl stop cloud-init-local 2>/dev/null || true
        systemctl disable cloud-init-local 2>/dev/null || true
    else
        log_info "cloud-init未安装，跳过禁用步骤"
    fi

    # 清理cloud-init缓存
    if [ -d /var/lib/cloud ]; then
        rm -rf /var/lib/cloud/instance/*
        rm -rf /var/lib/cloud/instances/*
    fi
}

# 备份当前的netplan配置
backup_current_config() {
    log_info "备份当前的netplan配置..."

    # 创建备份目录
    mkdir -p "$BACKUP_DIR"

    # 查找当前的netplan配置文件
    CURRENT_NETPLAN_FILE=$(ls -1 "$NETPLAN_DIR"/*.yaml 2>/dev/null | head -n 1)

    if [ -n "$CURRENT_NETPLAN_FILE" ] && [ -f "$CURRENT_NETPLAN_FILE" ]; then
        BACKUP_FILE="$BACKUP_DIR/$(basename "$CURRENT_NETPLAN_FILE").backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CURRENT_NETPLAN_FILE" "$BACKUP_FILE"
        ORIGINAL_CONFIG="$CURRENT_NETPLAN_FILE"
        log_success "已备份当前配置到: $BACKUP_FILE"
    else
        log_warning "未找到现有的netplan配置文件"
        ORIGINAL_CONFIG="$NETPLAN_DIR/01-network-manager-all.yaml"
    fi
}

# 解析配置文件
parse_config() {
    log_info "解析配置文件: $CONFIG_FILE"

    local current_interface=""
    declare -A interface_config

    while IFS='=' read -r key value; do
        # 去除首尾空格
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # 跳过空行和注释
        if [[ -z "$key" || "$key" =~ ^\[.*\]$ ]]; then
            # 处理接口定义
            if [[ "$key" =~ ^\[(.*)\]$ ]]; then
                current_interface="${BASH_REMATCH[1]}"
                interface_config["$current_interface.exists"]="true"
            fi
            continue
        fi

        if [ -n "$current_interface" ]; then
            interface_config["$current_interface.$key"]="$value"
        fi
    done < "$CONFIG_FILE"

    # 返回接口配置数组
    declare -p interface_config
}

# 生成netplan配置
generate_netplan_config() {
    log_info "生成netplan配置文件..."

    eval "$1"  # 导入interface_config数组

    local output_file="${2:-$NETPLAN_DIR/01-netcfg.yaml}"

    # 开始生成YAML
    cat > "$output_file" << EOF
# 网络配置 - 由脚本自动生成
# 生成时间: $(date)
network:
  version: 2
  ethernets:
EOF

    # 获取所有网络接口
    local all_interfaces=$(ls /sys/class/net | grep -E '^(ens|eth|enp|eno)' | sort)

    # 为每个接口生成配置
    for iface in $all_interfaces; do
        echo "    $iface:" >> "$output_file"

        # 检查是否有配置
        if [[ ${interface_config["$iface.exists"]} == "true" ]]; then
            local dhcp4=$(echo "${interface_config["$iface.dhcp4"]:-false}" | tr '[:upper:]' '[:lower:]')

            if [[ "$dhcp4" == "true" ]]; then
                echo "      dhcp4: true" >> "$output_file"
            else
                echo "      dhcp4: false" >> "$output_file"

                local address="${interface_config["$iface.address"]}"
                if [ -n "$address" ]; then
                    # 确保地址格式正确
                    if [[ ! "$address" =~ /[0-9]+$ ]]; then
                        address="$address/24"
                    fi
                    echo "      addresses: [$address]" >> "$output_file"
                fi

                local gateway="${interface_config["$iface.gateway"]}"
                if [ -n "$gateway" ]; then
                    echo "      routes:" >> "$output_file"
                    echo "        - to: default" >> "$output_file"
                    echo "          via: $gateway" >> "$output_file"
                fi

                local dns="${interface_config["$iface.dns"]}"
                if [ -n "$dns" ]; then
                    # 处理DNS服务器，支持逗号或空格分隔
                    dns=$(echo "$dns" | tr ',' ' ' | xargs)
                    echo "      nameservers:" >> "$output_file"
                    echo "        addresses: [$dns]" >> "$output_file"
                fi
            fi
        else
            # 没有配置的接口，设置为不分配IP但启用
            echo "      dhcp4: false" >> "$output_file"
            echo "      optional: true" >> "$output_file"
        fi

        # 添加空行分隔
        echo "" >> "$output_file"
    done

    log_success "已生成netplan配置文件: $output_file"
}

# 应用网络配置
apply_network_config() {
    log_info "应用网络配置..."

    # 使用netplan生成配置
    netplan generate

    # 应用配置
    if netplan apply; then
        log_success "网络配置应用成功"
        sleep 3  # 等待网络服务稳定
        return 0
    else
        log_error "应用网络配置失败"
        return 1
    fi
}

# 测试网络连通性
test_network() {
    log_info "测试网络连通性..."

    local test_count=0
    local success_count=0

    # 测试DNS解析
    log_info "测试DNS解析..."
    if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
        log_success "DNS服务器可达"
        success_count=$((success_count + 1))
    else
        log_warning "DNS服务器不可达"
    fi
    test_count=$((test_count + 1))

    # 测试外部网络连接
    log_info "测试外部网络连接..."
    if ping -c 2 -W 2 baidu.com > /dev/null 2>&1; then
        log_success "外部网络连接正常"
        success_count=$((success_count + 1))
    else
        log_warning "外部网络连接失败"
    fi
    test_count=$((test_count + 1))

    # 测试网关连通性
    log_info "检查网关连通性..."

    # 获取默认网关
    local default_gateway=$(ip route | grep default | awk '{print $3}' | head -n1)

    if [ -n "$default_gateway" ]; then
        if ping -c 2 -W 2 "$default_gateway" > /dev/null 2>&1; then
            log_success "网关 $default_gateway 可达"
            success_count=$((success_count + 1))
        else
            log_warning "网关 $default_gateway 不可达"
        fi
        test_count=$((test_count + 1))
    fi

    # 显示测试结果
    echo ""
    log_info "网络测试完成: $success_count/$test_count 项测试通过"

    if [ $success_count -ge 2 ]; then
        log_success "网络连通性测试基本通过"
        return 0
    else
        log_error "网络连通性测试失败"
        return 1
    fi
}

# 回退配置
rollback_config() {
    log_info "正在回退网络配置..."

    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$ORIGINAL_CONFIG"
        netplan apply
        log_success "已回退到之前的配置"
    else
        # 如果没有备份，尝试恢复默认配置
        cat > "$ORIGINAL_CONFIG" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
EOF
        netplan apply
        log_warning "已恢复为DHCP默认配置"
    fi

    log_info "等待网络恢复..."
    sleep 5
}

# 显示最终的网络配置
show_final_config() {
    log_info "当前网络配置:"
    echo "========================================"
    ip addr show
    echo "----------------------------------------"
    ip route show
    echo "----------------------------------------"
    cat /etc/resolv.conf | grep nameserver
    echo "========================================"
}

# 主函数
main() {
    echo "========================================"
    echo "     Ubuntu网络配置脚本"
    echo "========================================"

    # 检查root权限
    check_root

    # 解析参数
    parse_args "$@"

    # 显示当前模式
    if [ "$FORCE_MODE" = true ]; then
        log_warning "运行在强制模式，网络测试失败将不会回退"
    fi

    # 备份当前配置
    backup_current_config

    # 禁用cloud-init
    disable_cloud_init

    # 解析配置文件
    local interface_config_str=$(parse_config)

    # 生成netplan配置
    local new_config_file="$NETPLAN_DIR/01-netcfg-$(date +%Y%m%d_%H%M%S).yaml"
    generate_netplan_config "$interface_config_str" "$new_config_file"

    # 显示生成的配置
    log_info "生成的配置文件内容:"
    echo "----------------------------------------"
    cat "$new_config_file"
    echo "----------------------------------------"

    # 询问用户是否继续
    read -p "是否应用此配置? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "用户取消操作"
        exit 0
    fi

    # 应用配置
    if ! apply_network_config; then
        log_error "应用配置失败"
        exit 1
    fi

    # 测试网络
    if test_network; then
        log_success "网络配置成功!"

        # 删除旧的配置文件（只保留新的）
        find "$NETPLAN_DIR" -name "*.yaml" -not -name "$(basename "$new_config_file")" -delete 2>/dev/null || true

        # 重命名为标准名称
        mv "$new_config_file" "$ORIGINAL_CONFIG"

        show_final_config
    else
        log_error "网络测试失败"

        if [ "$FORCE_MODE" = false ]; then
            log_info "正在尝试回退配置..."
            rollback_config

            # 再次测试回退后的网络
            if test_network; then
                log_success "已成功回退到之前的配置"
            else
                log_error "回退后网络仍然不可用，请手动检查"
            fi
        else
            log_warning "强制模式已启用，配置将保留"
            log_info "当前配置保存在: $new_config_file"
        fi

        show_final_config
        exit 1
    fi
}

# 运行主函数
main "$@"