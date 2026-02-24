# 新问云图工作室 OpenStack Dalmatian 版本学习测试部署仓库

> [!WARNING]
> **重要声明**
> 这里是新问云图工作室的 OpenStack Dalmatian (2024.2) 版本学习测试部署仓库，仅供学习和测试使用。
> 本仓库提供自动化部署框架，实际使用时**必须根据你的网络环境进行调整**。作者仅提供基础示例，不承担生产环境使用风险。

## 文档版本

| 版本号 | 修订日期   | 编辑人   | 修改内容                                           | 仓库链接 |
|--------|------------|----------|----------------------------------------------------|----------|
| 1.0    | 2025/08/25 | LRAltas  | 完成主要 Playbook 框架，测试基础 Roles             | [链接](https://github.com/lrAltas/Ansible-OpenStack-Dalmatian) |
| 1.1    | 2025/11/10 | LRAltas  | 升级至 Dalmatian 版本，重构项目，加强幂等性       | [链接](https://github.com/lrAltas/Ansible-OpenStack-Dalmatian) |
| 2.0    | 2026/02/12 | LRAltas  | 完善 Cinder、Dashboard、Placement 等功能          | [链接](https://github.com/lrAltas/Ansible-OpenStack-Dalmatian) |
| 2.3    | 2026/02/24 | LRAltas  | 实时更新 roles 目录列表；完成 Ceph 对接；优化三步部署文档 | [链接](https://github.com/lrAltas/Ansible-OpenStack-Dalmatian) |

## 已完成角色列表（实时读取仓库 roles/ 目录）

- [x] env_init（环境初始化）
- [x] db_install（数据库部署）
- [x] memcache（分布式内存缓存）
- [x] rabbitmq（消息队列）
- [x] keystone（认证服务）
- [x] glance（镜像服务）
- [x] placement（资源放置服务）
- [x] nova（计算服务）
- [x] neutron（网络服务）
- [x] dashboard（旧版仪表盘，已修复）
- [x] skyline（新一代仪表盘）
- [x] cinder（卷服务，已基本可用）
- [x] **ceph**（Ceph 对接 Role，已完全完成，可对接 Ceph RBD 后端）
- [x] dns_server（DNS 服务）
- [x] ntp_server（NTP 服务）

**Ceph 集群部署** 已独立到另一个仓库：
**[ansible-ceph-reef](https://github.com/lrAltas/ansible-ceph-reef)**（基于 cephadm 一键部署）。

截至 2026/02/24，**OpenStack 全栈 + Ceph RBD 后端完整对接** 已实现，功能稳定可用。

## 部署架构（推荐示例二：双 VLAN）

- **管理网络**：10.1.10.0/24
- **浮动 IP 网络**：10.1.20.0/24

## 主机规划表（请严格按此修改 inventory）

### 1. OpenStack 节点

| FQDN                        | Mgnt NIC | Mgnt IP / Netmask / Gateway         | Floating IP / Netmask / Gateway      | Role       |
|-----------------------------|----------|-------------------------------------|--------------------------------------|------------|
| controller.openstack.suying | ens160   | 10.1.10.10/255.255.255.0/10.1.10.1 | None/255.255.255.0/10.1.20.1         | controller |
| compute01.openstack.suying  | ens160   | 10.1.10.11/255.255.255.0/10.1.10.1 | None/255.255.255.0/10.1.20.1         | compute    |
| compute02.openstack.suying  | ens160   | 10.1.10.12/255.255.255.0/10.1.10.1 | None/255.255.255.0/10.1.20.1         | compute    |
| dns.openstack.suying        | ens160   | 10.1.10.2/255.255.255.0/10.1.10.1  | -                                    | DNS_NTP    |

### 2. Ceph 集群节点（ansible-ceph-reef 部署）

| FQDN                        | Mgnt NIC | Mgnt IP / Netmask / Gateway         | Role    |
|-----------------------------|----------|-------------------------------------|---------|
| cephadm01.openstack.suying  | ens160   | 10.1.10.50/255.255.255.0/10.1.10.1 | cephadm |
| cephadm02.openstack.suying  | ens160   | 10.1.10.51/255.255.255.0/10.1.10.1 | cephadm |
| cephadm03.openstack.suying  | ens160   | 10.1.10.52/255.255.255.0/10.1.10.1 | cephadm |

## 使用方法（严格三步走）

### 步骤 1：准备 OpenStack 部署环境
```bash
git clone https://github.com/lrAltas/Ansible-OpenStack-Dalmatian.git
cd Ansible-OpenStack-Dalmatian

vim ansible.cfg      # 配置 inventory 路径、用户等
vim inventory        # 按上面主机规划表填写
```

### 步骤 2：修改 Neutron 网卡配置（必须）
```bash
vim roles/neutron/vars/main.yml
```
把 `nic_name` 改成你实际的物理网卡名称：
```yaml
neutron_ovs_conf:
  nic_name: "ens160"     # ←←← 改成你的实际网卡（常见 ens160 或 enp2s0）
```

### 步骤 3：按顺序执行部署
1. **部署 OpenStack 核心服务**
   ```bash
   ansible-playbook -i inventory allinone_test.yml
   ```

2. **部署 Ceph 集群**
   ```bash
   git clone https://github.com/lrAltas/ansible-ceph-reef.git
   cd ansible-ceph-reef
   # 按照该仓库 README 执行 cephadm 部署（推荐 3 节点）
   ```

3. **执行 Ceph 对接 OpenStack**
   ```bash
   cd ../Ansible-OpenStack-Dalmatian
   ansible-playbook -i inventory ceph_test.yml
   ```

**部署完成后访问**：
- Skyline 新仪表盘：`http://<controller_ip>:9999`
- Horizon 旧仪表盘：`http://<controller_ip>/horizon`

**强烈推荐操作系统**：Ubuntu 24.04 LTS（Skyline SDK 兼容性最佳）

---

**仓库持续维护中**，欢迎提交 Issue / PR，一起把项目做得更好！🚀
新问云图工作室 —— 让 OpenStack 部署更简单！
