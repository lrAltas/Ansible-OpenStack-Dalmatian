# 新问云图工作室 OpenStack Dalmatian 版本学习测试部署仓库

> [!WARNING]
> **重要声明**
> 这里是新问云图工作室的 OpenStack Dalmatian (2024.2) 版本学习测试部署仓库的介绍文档，仅供学习和测试使用，旨在快速部署一个可用的 OpenStack 私有云示例平台。
>
> **严正声明**：本仓库仅提供快速部署脚本的基本框架，并非万能脚本。实际部署有两种选择：
> 1. 严格按照示例小幅度修改后直接使用；
> 2. 根据实际情况自行修改、调试、测试，直至成功。
> 作者仅提供基础示例框架，不保证适用于所有环境。

## 文档版本

| 版本号 | 修订日期   | 编辑人   | 修改内容                                                                                     | 仓库链接                                                         |
|--------|------------|----------|----------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| 1.0    | 2025/08/25 | LRAltas  | 完成主要 Playbook 框架，测试基础 Roles（13 个）在示例架构（1C2Co）上的运行情况               | https://github.com/lrAltas/Ansible-OpenStack-Dalmatian          |
| 1.1    | 2025/11/10 | LRAltas  | 升级至 2024.02（Dalmatian）版本，重构项目，加强格式规范性，增强单个模块执行的幂等性         | https://github.com/lrAltas/Ansible-OpenStack-Dalmatian          |
| 2.0    | 2026/02/12 | LRAltas  | 完成基本部署功能完善（包括 Cinder 修复、Dashboard 问题修复、Placement 配置优化）；添加 policy 文件复制逻辑；格式全面规范化；支持卷服务基本功能 | https://github.com/lrAltas/Ansible-OpenStack-Dalmatian          |

### 编辑说明
- **版本号规则**：主版本号.次版本号，主版本用于大版本升级，次版本用于迭代优化或修复。
- **修订日期**：统一为 `YYYY/MM/DD` 格式。
- **编辑人**：记录修改人。
- **修改内容**：简要描述核心变更。

后续可根据需要扩展表格字段（如“关联 commit”等）。

## 仓库简介

本仓库基于 Ansible Roles 实现，目前已完成以下模块的编写与测试：

- [x] init_env（环境初始化）
- [x] db_server（数据库部署）
- [x] Memcache（分布式内存缓存）
- [x] RabbitMQ（消息队列）
- [x] Keystone（认证服务）
- [x] Glance（镜像服务）
- [x] Placement（资源放置服务）
- [x] Nova（计算服务）
- [x] Neutron（网络服务）
- [x] Dashboard（旧版仪表盘，已修复原有问题）
- [x] Skyline（新一代仪表盘）
- [x] Cinder（卷服务，已基本可用）
- [ ] Ceph（后端存储，部分支持/测试中）

仓库由新问云图工作室维护，主要用于内部成员学习、测试和体验 OpenStack 开源云平台。截至 2026/02/12，脚本已在固定架构下实现完整自动化部署，平台基本功能稳定（虚拟机创建/管理、快照、网络、浮动 IP、卷挂载等）。仓库持续更新中，最近重点完善了部署稳定性与兼容性。

## 部署架构介绍

### 示例架构一（单网段 + 虚拟网关）

![示例架构一：1 Controller + 2 Compute + 虚拟网关](https://cdn.nlark.com/yuque/0/2026/png/44875752/1768541136779-ee36b856-703d-43a1-b6c2-61a9d41cc0ac.png)

网络划分：
1. **管理网络**：`192.168.1.0/24`
2. **业务网络**：`10.1.1.0/24`（建议该网段不放置其他设备，避免 IP 冲突）

### 示例架构二（双 VLAN 真实网络环境）

![示例架构二：真实网络环境下的完整部署](https://cdn.nlark.com/yuque/0/2026/png/44875752/1768541140827-2bb60815-fba9-49a3-9400-b0e52b257ae0.png)

![示例架构二简化网络规划](https://cdn.nlark.com/yuque/0/2026/png/44875752/1768541144818-01d557f6-11a8-4f7a-8329-bca89872b48b.png)

网络划分：
1. **管理网络**：`10.1.10.0/24`
2. **浮动 IP 网络**：`10.1.20.0/24`

> [!NOTE]
> **Tips**：无需完全复制此架构。本质只需 Controller + Skyline/Dashboard + Nova 节点（可选 Cinder）。示例架构二是理想状态，可作为参考自行部署。

## 剧本使用样例

> [!WARNING]
> 当前仓库主要测试于 **CentOS 9 Stream**，但为解决 Skyline SDK 兼容性问题，**推荐使用 Ubuntu 24.04 LTS**（已验证稳定）。

### 主机示例（请根据实际情况修改）

| Hosts       | FQDN                          | NIC1/IP                       | NIC2/IP                          |
|-------------|-------------------------------|-------------------------------|----------------------------------|
| controller  | controller.openstack.suying   | ens33: 10.1.10.200（静态）    | ens34: 10.1.20.0/24（动态）      |
| compute01   | compute01.openstack.suying    | ens33: 10.1.10.201（静态）    | ens34: 10.1.20.0/24（动态）      |
| compute02   | compute02.openstack.suying    | ens33: 10.1.10.202（静态）    | ens34: 10.1.20.0/24（动态）      |
| skyline     | skyline.openstack.suying      | ens33: 10.1.10.199（静态）    | 无                               |
| Ansible-Controller | -                        | ens33: 10.1.10.198（静态）    | -                                |

### 前置要求
1. 所有节点的管理网段 IP 必须为**静态**，互不冲突，可相互通信并能访问外网。
2. Ansible-Controller 对其他节点配置 SSH 免密登录。

### 操作步骤（在 Ansible-Controller 节点执行）
（步骤同之前优化版，保持不变：git clone → 修改 ansible.cfg/inventory → 修改 Neutron OVS 配置 → 执行 allinone.yml）

部署完成后，浏览器访问 Skyline（`:9999`）或 Dashboard（默认 `:80/horizon`）即可。

## 当前存在的问题与解决方案

### Skyline 仪表盘与 OpenStack SDK 版本冲突
（问题描述同旧版）

#### 推荐解决方案
- **首选**：切换到 **Ubuntu 24.04 LTS**（自带 Python 3.12，已验证解决兼容性问题，支持完整 Skyline 功能）。
- **备选**：使用传统 Dashboard（现已修复，原有问题已解决，稳定可靠）。

如果 Ceph 完全集成后有新问题，会继续更新。