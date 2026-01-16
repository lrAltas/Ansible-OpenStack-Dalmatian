---

> <font style="color:#DF2A3F;">这里是新问云图工作室的 OpenStack_Dalmatian 版本学习测试部署仓库的介绍文档，仅做学习测试使用，旨在快速部署一个可用的OpenStack私有云示例平台。
</font><font style="color:#DF2A3F;">严正声明：本剧本内容仅提供了快速部署的剧本的基本框架，想要实际部署的人有两个选择：一个是完全按照示例内容小幅度更改，另一个就是根据实际情况自己更改后 debug，然后再测试，再改，直至成功。我给的只是一个基础示例框架，并非一个万能剧本。</font>
>

## 文档版本
| 版本号 | 修订日期 | 编辑人 | 修改内容 | 仓库链接 |
| --- | --- | --- | --- | --- |
| 1.0 | 2025/08/25 | LRAltas | 完成编写主要 Playbook 框架，测试了基础 Roles（13 个 Roles）的功能在示例架构（1C2Co）上的运行情况 | [https://github.com/lrAltas/Ansible-OpenStack-Dalmatian](https://github.com/lrAltas/Ansible-OpenStack-Dalmatian) |
| 1.1 | 2025/11/10 | LRALtas | 更改主要发行版本为 2024.02（即新版 Dalmatian 版），Playbook的内容基于 Yoga 仓库；对项目进行重构，重新编写整个项目，加强了文本格式的规范性；增加了单个模块执行的幂等性，现在单个模块执行完成后可以重复执行，并不会造成影响（并不能保证百分百正确） | [https://github.com/lrAltas/Ansible-OpenStack-Dalmatian](https://github.com/lrAltas/Ansible-OpenStack-Dalmatian) |


### 编辑说明：
1. **版本号规则**：采用 `**主版本号.次版本号**`（如 1.0、1.1），主版本号大版本更新（如发行版升级），次版本号用于迭代优化或修复。
2. **修订日期**：统一格式为 `**YYYY/MM/DD**`，便于按时间排序和检索。
3. **编辑人**：记录修改人。
4. **修改内容**：简要描述本次版本的核心变更，重点突出关键调整（如发行版升级、重构、功能新增等）。

如果需要扩展（如增加“影响范围”“关联 issue/GitHub 链接”等字段），可以后续在表格中追加列。

---

## 仓库简介
该仓库是以roles为基础的一个Ansible剧本仓库，目前已完成如以下内容的编写。

- [x] init_env（环境初始化部分）
- [x] db_server（OpenStack数据库部署）
- [x] Memcache（分布式内存缓存系统）
- [x] RabbitMQ（消息队列）
- [x] Keystone（认证服务）
- [x] Glance（镜像服务）
- [x] Placement（资源放置服务）
- [x] Nova（计算服务）
- [x] Neutron（网络服务）
- [ ] Dashboard（旧版仪表盘）
- [x] Skyline（新一代仪表盘）
- [ ] Cinder（卷服务）
- [ ] Ceph（后端存储）

该仓库是为了工作室内部成员学习，测试，和体验`OpenStack`开源云平台所创建的仓库，目前该仓库归属于新问云图工作室，由LRAltas创建并且进行持续开发维护。截止至2025年8月25日，该剧本目前已经完成固定架构下的基本功能的自动化部署剧本的编写，经过测试，当前平台自动化部署的各项功能基本正常，平台搭建起来之后能够正常实现虚拟机的创建，挂起删除，拍摄快照的功能，虚拟机能够正常获取子网IP，也能够绑定浮动IP，外界能Ping通内部的实例。目前，该仓库仍在正常更新中。

## 部署架构介绍
### 示例架构一
此示例结构是在`ESXI`平台是进行，对应的物理网络结构是单网段，对于需要双网段（一管理一业务）的情况我们采用虚拟网关的形式来做

<!-- 这是一张图片，ocr 内容为：VM ANSIBLE-CONTROLLER ENS33 192.168.1.150/24 ENS34 10.1.X/24 ENS33网卡均为VM网络 ONS34均为LAN网络 192.168.1.0/24 管理网络 VM MANAGER NETWORK COMPUTE02 CONTROLLER COMPUTE01 这里是主干物理网络 VM VM ENS33 192.168.1.212/24 ENS33 192.168.1.211/24 ENS33 192.168.1.210/24 INTERNET ENS34 OVS BRIDGE ENS34 OVS BRIDGE ENS34 OVS BRIDGE VM VM VM 10.11.0/24 10.1.0/24 10.1.0/24 业务网络 业务网络 业务网络 CEPH年群 LAN VIRTUAL NETWROK 此虚拟交换机是提供端口组的 本身不连接任何上行链路 VM VIRTUAL GATEWAY ENS33  192.168.1X/24 CINDER服务是位于两个计算节点上 ENS34 10.1.1.1/24 DHCP_ENABLED 因为本身物理网络上没有分配额外的物理路由器 所以这里就使用虚拟网关专门分隔网段,提供浮动IP 可以看做是一个NAT,但是不一样,主要作为模拟公网IP -->
![](https://cdn.nlark.com/yuque/0/2026/png/44875752/1768541136779-ee36b856-703d-43a1-b6c2-61a9d41cc0ac.png)

该示例结构的网络分为两部分

1. 管理网络：在上述架构图中为`**192.168.1.0/24**`的网段
2. 业务网络：在上述架构图中为`**10.1.1.0/24**`的网段（该网段上最好不要有虚拟机或者是其他机器以避免IP冲突）

在本示例中，`**ansible-controller**`节点与各个节点之间通过管理网段进行相互连接。

### 示例架构二
<!-- 这是一张图片，ocr 内容为：此端口开放两个VLAN直接下放两个DHCP到下层交换机 以为内之前实验发现在个三层交换机上制三型入周个口始路由型的两个口 此接作可避免晒来争口放程交进宽上工服务干兆的服制 主路由下发两条VTAN CEPH 集群的管理网络和集群网络的都用管理网络的网段就行 由于设备带宽受限所以没必要单独切封开 VTAN300 10.20.10.0/24 VLAN301 10.20.20.0/24 华为S5700 10.20.20.0 进行操作之前一定要先保存原先的交换机配置 GE04 GE03 集群系统选择:CENEOS-STREAM OPENSTACK发行版选型:2024.02 DALMATIAN 新加入的机架 二层交换机 ZTE二层 VLAN300 10.20.10.0/24 物理网卡 物理网卡 VLAN300 10.20.10.0/24 VSWITCH 02 VSWITCH 01 这个虚拟交换机是用来接入测试部著的管理网络的 这个虚拟交换机是用来接入业务网络的 PXE服务器可以使用传统的PXE部岩 如果目标系统是UBUNTU也可以尝试使用MAAS进行部等 MAAS常爱注意 VM 对于CENTOS的版本支持为默认7-8 NOVA SERVERS & SKYLINE NODE CONTROLLER.ANSIBLE DEPLOY NODE.PXE 对于UBUNTU的版本支持到最新 以虚拟机的形式部岩在服务器上 并且需要注意MAAS只对部分具有外带的机器或者是虚拟机支持电源管理 CONTROLLER NODE  增强可靠性,可以随时更改配,方使即著调整 CEPH  GLUSTERS CEPH NODE配置详情 SKYLINE NODE配置详情 NOYA SERVER配置详情 VM VM 内存:4G(可以更离) 内存:4G(可以更高) 内存:8G(可以更高) 双磁盘配置:SATA.NWME 双磁盘配置:SATA.RIVME ANSIBLE DEPLOY NODE 单网卡 单网卡 IP可以不因定 PXESERVER 需要先对受控机器进行免密 用户交互时直接访问SKYINE NODE的IP:999出口即可访问平台WEBUI ANSIBLE节点上的执行环境为PYTHON环境 SKYLINE节点测试时期保用PODMANLYLINE节点测试 版本控制尽量控制在3.10-3.13 可使用MINICONDA或者是直接安装对应的PYTHON3.LX-PIP来创建虚拟环境 -->
![](https://cdn.nlark.com/yuque/0/2026/png/44875752/1768541140827-2bb60815-fba9-49a3-9400-b0e52b257ae0.png)

简化结构为这样

<!-- 这是一张图片，ocr 内容为：网脂规划 运营商/光猫 供应商网络/深动IP网络 管理网络 (PROVIDER NETWORK/FLOATING NETUWORK/EXTERMAL (MANAGEMENT NETWORK): NETWORK) VLAN  80:1.10.0/24 VAN 90:10.1.20.0/24 用户 家庭路由器 企业路由器 刘览器访问:HORZION           HORZION   IP/DASHBOARD即可访问云平合仪表 桥接 浏览器访问:CEPH01_IP:8080即可访问CEPH存保仪表盘 虚拟化集群网络 企业三层交换机 企业二层可管理交换 物理拓展设备网络 TRUNK 端口 ACCESS靖口 携带VLAN 10.20 ACCESS出口 VLAN ID 10 VLAN ID 10 NOVA计算节点 ACCESSIN口 CEPH集群 VTAN ID 10 虚拟化服务器 LINUX(CENTOS STREAM 9)+KVM TRUNK 进口 TRUNK 端口 携带VLAN 10.20 浅带VLAN 10.20 CEPH节点 集群内部网络 双卡网卡NOVA节 单网卡NVA节点 CEPH节点 CEPH节点 OPENSTACK盛拟化集群 测试OPENSTACK计算节 OPENSTACK服务管理节点 -->
![](https://cdn.nlark.com/yuque/0/2026/png/44875752/1768541144818-01d557f6-11a8-4f7a-8329-bca89872b48b.png)

该示例架构是基于当前工作室网络环境进行的

1. 管理网络：在上述架构中为`**10.1.10.0/24**`网段，节点之间的管理通信通过此节点
2. 浮动IP网络：在上述架构中为`**10.1.20.0/24**`网段，该网段主要是给虚拟机提供浮动IP

:::info
**Tips**：你不用完全按照这个结构图来，其本质就是Controller节点+Skyline节点+Nova节点，只不过我们有了更高级的路由器之后不需要做虚拟网关了，示例结构为理想状态的完全体，感兴趣的同学可以参照这个尝试自行部署。

:::

## 剧本使用样例
:::info
<font style="color:rgb(222, 60, 54);">请注意，当前仓库仅支持</font>`**<font style="color:rgb(222, 60, 54);">CentOS 9</font>**`<font style="color:rgb(222, 60, 54);">系统上的部署（RockyLinux并不行，可能会出现SSL版本低的报错）</font>

:::

假定当前存在以下网络结构的机器

| `**<font style="color:#000;">Hosts</font>**` | `**<font style="color:#000;">FQDN</font>**` | `**<font style="color:#000;">NIC1/IP</font>**` | `**<font style="color:#000;">NIC2/IP</font>**` |
| :--- | :--- | :--- | :--- |
| `<font style="color:#000;">controller</font>` | `<font style="color:#000;">controller.openstack.suying</font>` | `<font style="color:#000;">ens33:10.1.10.200（此IP需要进行固定，更改为静态IP）</font>` | `<font style="color:#000;">ens34:10.1.20.0/24（IP不需要进行固定，故此处不写具体的，你也不用在意这个网卡的IP）</font>` |
| `<font style="color:#000;">compute01</font>`<br/> | `<font style="color:#000;">compute01.openstack.suying</font>` | `<font style="color:#000;">ens33:10.1.10.201（此IP需要进行固定，更改为静态IP）</font>` | `<font style="color:#000;">ens34:10.1.20.0/24（IP不需要进行固定，故此处不写具体的，你也不用在意这个网卡的IP）</font>` |
| `<font style="color:#000;">compute02</font>`<br/><font style="color:#000;"></font> | `<font style="color:#000;">compute02.openstack.suying</font>` | `<font style="color:#000;">ens33:10.1.10.202（此IP需要进行固定，更改为静态IP）</font>` | `<font style="color:#000;">ens34:10.1.20.0/24（IP不需要进行固定，故此处不写具体的，你也不用在意这个网卡的IP）</font>` |
| `<font style="color:#000;">skyline</font>`<br/> | `<font style="color:#000;">skyline.openstack.suying</font>` | `<font style="color:#000;">ens33:10.1.10.199（此IP需要进行固定，更改为静态IP）</font>` | <font style="color:#000;">无</font> |
| <font style="color:#000;">Ansible-Controller</font><br/><font style="color:#000;"></font> | <font style="color:#000;"></font> | `<font style="color:#000;">ens33:10.1.10.198（此IP需要进行固定，更改为静态IP）</font>` | |


在进行操作之前，你需要确保以下内容

1. 每个机器的`**管理网段的IP均为静态IP**`，且相互之间不冲突，能相互通讯并且能连接外网。这个不是本地部署包，需要联网下载各项软件包。
2. `**Ansible-Controller**`，也就是执行剧本的机器要对其他机器在SSH上免密

### 开始操作
:::info
以下操作在`**Ansible-Controller**`节点上操作

:::

下载Git软件包

```bash
sudo dnf install git -y
#Ubuntu用户的操作是
sudo apt install git -y
```

创建并进入指定的项目文件夹

```bash
mkdir /root/project/ && cd /root/project/
```

克隆指定仓库

```bash
git clone https://github.com/lrAltas/Ansible-OpenStack-Dalmatian.git
#如果无法访问GitHub，则可以使用以下命令
git clone https://githubfast.com/lrAltas/Ansible-OpenStack-Dalmatian.git
```

进入项目文件夹中

```bash
cd Ansible-OpenStack-Dalmatian
```

修改`**ansible.cfg**`文件

```bash
vim ansible.cfg
#内容应该是这样的
#You need to configure the following contents according to the actual situation of your controlled host
[defaults]
inventory = /home/lraltas/project/code_project/Ansible-OpenStack-Yoga-rebuild/inventory
collections_path = /home/lraltas/project/code_project/Ansible-OpenStack-Yoga-rebuild/collections
roles_path = /home/lraltas/project/code_project/Ansible-OpenStack-Yoga-rebuild/roles
remote_user = root
hosts_key_checking = false
timeout = 10

[privilege_escalation]
become = true
become_method = sudo
become_user = root
become_ask_pass = false

#你需要将以下内容更换为你的实际的项目路径，在当前示例中应为以下情况
inventory = /home/lraltas/project/code_project/Ansible-OpenStack-Yoga-rebuild/inventory
#更改为
inventory = /root/project/Ansible-OpenStack-Dalmatian/inventory
####################################################################################
collections_path = /home/lraltas/project/code_project/Ansible-OpenStack-Yoga-rebuild/collections
#更改为
collections_path = /root/project/Ansible-OpenStack-Dalmatian/collections
####################################################################################
roles_path = /home/lraltas/project/code_project/Ansible-OpenStack-Yoga-rebuild/roles
#更改为
roles_path = /root/project/Ansible-OpenStack-Dalmatian/roles
```

配置`**inventory**`文件

```bash
vim inventory
#内容应该是这样的
[controller]
ctl57 ansible_host=10.1.10.50
[compute]
com57-01 ansible_host=10.1.10.51
com57-02 ansible_host=10.1.10.52
[skyline]
sky57 ansible_host=10.1.10.49

#你要将其改为你自己实际情况的内容，按照当前样例，你可以这么写
[controller]
controller ansible_host=10.1.10.200
[compute]
compute01 ansible_host=10.1.10.201
compute02 ansible_host=10.1.10.202
[skyline]
sky ansible_host=10.1.10.199
```

更改部分指定的剧本参数

:::info
以下操作在`**Ansible-Controller**`节点上操作

:::

请注意，如果你并不清楚/熟悉OpenStack的各项配置，那么你最好不要动除了我给到的需要修改的参数以外的内容

```yaml
vim roles/neutron/vars/main.yml
#找到位于该变量文件最下方的neutron_ovs_conf变量字典
neutron_ovs_conf:
  nic_name: enp2s0
  bridge_port_name: br-ex

#你需要将其中的nic_name的值改为你的机器上的那个浮动IP网卡，也就是那个桥连网卡的网卡名，在此样例中，你需要改为以下内容之后保存退出
neutron_ovs_conf:
  nic_name: ens34
  bridge_port_name: br-ex
```

当以上与前置操作完成之后，你就可以执行角色了

项目文件夹中给定了一个示例`allinone`的调用剧本`allinone.yml`

内容应该是这样的

```yaml
vim allinone.yml

#如果没问题则应该是这样的
---
- name: Init env
  hosts: all
  serial: 1
  roles:
    - env_init

- name: Configure controller node
  hosts: controller
  serial: 2
  roles:
    - db_install
    - rabbitmq
    - memcache
    - keystone
    - glance
    - placement
    - nova
    - neutron

- name: Configrue Compute node
  hosts: compute
  serial: 3
  roles:
    - nova
    - neutron

- name: Configure skyline controller node
  hosts: controller
  serial: 4
  roles:
    - skyline

- name: Configure Skyline Node
  hosts: skyline
  serial: 5
  roles:
    - skyline
```

确认内容没问题就可以执行命令了（`ansible-navigator`需要提前部署，其署教程就不在这里赘述了）

```bash
ansible-navigator run -m stdout allinone.yml
```

等待剧本执行完成之后，去到浏览器，访问`**Skyline**`节点的IP:9999即可进入`**skyline**`的仪表盘

## 当前存在的问题
### 关于`Skyline`的问题
#### `Skyline` 仪表盘与 `OpenStack SDK` 版本冲突解决方案
##### 问题概述
**Skyline 仪表盘**需要 OpenStack SDK 4.8 版本，但 CentOS 9 系统自带 Python 3.9，只能支持 OpenStack SDK 4.5 版本，造成版本不兼容问题。

##### 冲突表现
+ 前端组件无法正常获取数据
+ 创建实例后无法获取实例列表
+ 其他依赖高版本 SDK 的功能异常

#### 解决方案对比
##### 方案A：使用老版本 `Skyline`
**可行性**：❌ 不可行
**原因**：

+ 老版本已被官方更新替换
+ 官方未留存历史版本
+ 老版本存在较多硬性缺陷

##### 方案B：升级到 `CentOS Stream 10`
**可行性**：❌ 不可行
**原因**：

+ `CentOS 10` 自带 `Python 3.12`（符合要求）
+ `RDO` 仓库仅支持到 `EL9` 版本
+ 缺少 openstack-release 包支持

##### 方案C：弃用 `Skyline`，回归 `Dashboard`
**可行性**：✅ 稳定可行
**状态**：待考虑
**特点**：

+ 传统 `Horizon` 仪表盘
+ 稳定可靠，兼容性好
+ 功能相对基础

##### 方案D：切换到 `Ubuntu 24.04 LTS`
**可行性**：✅ 当前采用方案
**优势**：

+ 系统自带 `Python 3.12`（满足 `SDK 4.8` 要求）
+ `OpenStack` 对 `Ubuntu` 支持完善
+ 长期支持版本`(LTS)`
+ 社区支持活跃

