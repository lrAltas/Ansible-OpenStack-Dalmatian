#!/bin/bash
# 脚本功能：按顺序执行 OpenStack 网络配置、实例类型创建及主机发现任务
# 使用前请确保已加载 OpenStack 环境变量（如 admin-openrc.sh）

set -e  # 遇到错误立即退出

echo "=========================================="
echo "开始执行 OpenStack 网络配置任务"
echo "=========================================="

# ---------- 11.2 创建路由器 ----------
echo -e "\n>>> 11.2 创建路由器：Ext-Router"
openstack router create Ext-Router

# ---------- 11.3 创建 VxLAN 网络 ----------
echo -e "\n>>> 11.3 创建 VxLAN 网络：Intnal"
openstack network create --provider-network-type vxlan Intnal

echo -e "\n>>> 11.3 创建 VxLAN 子网：Intsubnal (192.168.1.0/24)"
openstack subnet create Intsubnal \
    --network Intnal \
    --subnet-range 192.168.1.0/24 \
    --gateway 192.168.1.1 \
    --dns-nameserver 223.5.5.5

# ---------- 11.4 将内部网络添加到路由器 ----------
echo -e "\n>>> 11.4 将子网 Intsubnal 添加到路由器 Ext-Router"
openstack router add subnet Ext-Router Intsubnal

# ---------- 11.5 创建 Flat 网络 ----------
echo -e "\n>>> 11.5 创建 Flat 外部网络：Extnal"
openstack network create \
    --provider-physical-network physnet1 \
    --provider-network-type flat \
    --external \
    Extnal

echo -e "\n>>> 11.5 创建 Flat 子网：Extsubnal (10.1.20.0/24)"
openstack subnet create Extsubnal \
    --network Extnal \
    --subnet-range 10.1.20.0/24 \
    --allocation-pool start=10.1.20.30,end=10.1.20.200 \
    --gateway 10.1.20.1 \
    --dns-nameserver 223.5.5.5 \
    --no-dhcp

# ---------- 11.6 设置路由器网关接口 ----------
echo -e "\n>>> 11.6 设置路由器 Ext-Router 的外部网关为 Extnal"
openstack router set Ext-Router --external-gateway Extnal

# ---------- 11.7 开放安全组 ----------
echo -e "\n>>> 11.7 开放 ICMP 协议（默认安全组）"
openstack security group rule create --proto icmp default

echo -e "\n>>> 11.7 开放 SSH 端口 22（默认安全组）"
openstack security group rule create --proto tcp --dst-port 22:22 default

echo -e "\n>>> 11.7 查看当前安全组规则"
openstack security group rule list

# ---------- 创建实例类型（1核512M内存1G磁盘） ----------
echo -e "\n>>> 创建实例类型：m1.nano (1 vCPU, 512MB RAM, 1GB Disk)"
openstack flavor create --vcpus 1 --ram 512 --disk 1 m1.nano

# ---------- 发现新计算主机 ----------
echo -e "\n>>> 执行 nova 发现主机操作 (nova-manage cell_v2 discover_hosts)"
nova-manage cell_v2 discover_hosts --verbose

echo -e "\n=========================================="
echo "✅ 所有任务执行完成。"
echo "当前可用的计算节点列表："
openstack compute service list --service nova-compute
echo "=========================================="
