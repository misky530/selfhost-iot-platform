# IoT 数据平台项目

## 📋 项目概述

**项目名称**: IoT MQTT-Kafka 数据处理平台   
**目标**: 构建一个完整的 IoT 数据采集、存储和可视化平台  

---

## 🎯 项目目标

### 原始需求
1. ✅ MQTT 数据采集（订阅通配符 topic）, mqtt Broker: hats.hcs.cn:1883, topic: mtic/msg/client/realtime/#
2. ✅ 提取 tenantId 和 projectId
3. ✅ 数据可靠传输（不丢失任何一条数据）
4. ✅ Kafka 消息队列缓冲
5. ⚠️ 持久化存储（influxdb）
6. ⚠️ Grafana 可视化展示
7. ✅ 3天数据保留策略

# IoT 混合架构完整部署方案文档

## 目录
- [架构概述](#架构概述)
- [资源规划](#资源规划)
- [网络规划](#网络规划)
- [部署时间表](#部署时间表)
- [Windows 物理机配置](#windows-物理机配置)
- [VMware 虚拟机配置](#vmware-虚拟机配置)
- [RKE2 集群配置](#rke2-集群配置)
- [应用部署策略](#应用部署策略)
- [监控与运维](#监控与运维)
- [故障演练计划](#故障演练计划)
- [学习路径建议](#学习路径建议)

---

## 架构概述

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│  外部 MQTT Broker                                            │
│  hats.hcs.cn:1883                                           │
└─────────────────────────────────────────────────────────────┘
                        ↓ MQTT Subscribe
┌─────────────────────────────────────────────────────────────┐
│  RKE2 Kubernetes 集群 (VMware 虚拟机)                       │
│  ├─ Master Node: 6GB / 4vCPU                                │
│  ├─ Worker Node 1: 4GB / 2vCPU                              │
│  └─ Worker Node 2: 4GB / 2vCPU                              │
│                                                              │
│  应用 Pods (无亲和性,动态调度):                             │
│  ├─ MQTT 订阅客户端 (Deployment × 3 副本)                   │
│  ├─ 数据处理服务 (Deployment × 3 副本)                      │
│  ├─ Kafka Producer (Deployment × 2 副本)                    │
│  ├─ Kafka Consumer (Deployment × 2 副本)                    │
│  ├─ Grafana (StatefulSet × 2 副本)                         │
│  ├─ 前端应用 (Deployment × 2 副本)                          │
│  └─ ArgoCD (Deployment × 1)                                 │
└─────────────────────────────────────────────────────────────┘
                ↓ 网络连接 (桥接/NAT)
┌─────────────────────────────────────────────────────────────┐
│  Windows 物理机 (Docker Desktop)                             │
│  ├─ Harbor 私有镜像仓库: 3GB                                │
│  ├─ Kafka (KRaft 模式): 4GB                                 │
│  ├─ TimescaleDB: 4GB                                        │
│  └─ Prometheus (可选): 2GB                                  │
└─────────────────────────────────────────────────────────────┘

数据流向:
外部 MQTT → K8s MQTT Pods → 物理机 Kafka → K8s Consumer Pods 
  → 物理机 TimescaleDB → K8s Grafana → 前端可视化
```

### 核心设计理念

**为什么采用混合架构?**

1. **有状态服务外置到物理机**
   - **Harbor 私有镜像仓库**: 解决国内镜像拉取问题,避免依赖 docker.io/gcr.io/quay.io
   - **Kafka**: 高 I/O 需求,物理机磁盘性能更好,无虚拟化损耗
   - **TimescaleDB**: 数据持久化关键,避免容器迁移带来的风险
   - **资源隔离**: 重型服务故障不影响 K8s 集群

2. **无状态服务运行在 K8s**
   - **MQTT 订阅客户端**: 多副本,自动调度到不同节点
   - **数据处理服务**: 支持 HPA 弹性扩缩容
   - **前端应用**: 滚动更新,零停机部署
   - **充分体现 K8s 价值**: 动态调度、自愈、负载均衡

3. **符合企业真实实践**
   - 大厂架构: 数据层独立部署,应用层容器化
   - 降低复杂度: 避免 StatefulSet 的运维成本
   - 易于演进: 后期可平滑迁移到云端 RDS/MSK

**架构价值体现:**
- ✅ 资源优化: 32GB 内存可用
- ✅ 学习全面: K8s 调度 + 中间件运维
- ✅ 务实选型: 技术决策的权衡思维
- ✅ 易于扩展: 可迁移到云或增加节点
- ✅ 面试友好: 技术广度+深度+架构思维

---

## 资源规划

### 总资源分配表

| 层级 | 组件 | 内存 | CPU | 存储 | 说明 |
|------|------|------|-----|------|------|
| **物理机** | Windows 系统 | 5GB | - | 50GB | 系统保留 |
| | Docker Desktop | 2GB | - | 20GB | 容器运行时 |
| | **Harbor** | **3GB** | **2 Core** | **200GB** | **私有镜像仓库** |
| | Kafka (KRaft) | 4GB | 2 Core | 50GB | 消息队列 |
| | TimescaleDB | 4GB | 2 Core | 100GB | 时序数据库 |
| | Prometheus(可选) | 2GB | 1 Core | 50GB | 监控存储 |
| **物理机小计** | | **20GB** | **7 Core** | **470GB** | |
| | | | | | |
| **虚拟机** | RKE2 Master | 6GB | 4 vCPU | 40GB | 控制平面+etcd |
| | RKE2 Worker1 | 4GB | 2 vCPU | 40GB | 工作节点 |
| | RKE2 Worker2 | 4GB | 2 vCPU | 40GB | 工作节点 |
| | (Worker3 可选) | (4GB) | (2 vCPU) | (40GB) | 可选扩展 |
| **虚拟机小计** | | **14GB** | **8 vCPU** | **120GB** | |
| | | | | | |
| **总计** | | **34GB** | **15 Core** | **590GB** | |

**资源优化策略:**
- Worker 节点从原计划的 5GB 降为 4GB 以容纳 Harbor
- 如果仍超出 32GB 限制:
  - 方案1: 暂不部署 Prometheus(后期手动添加)
  - 方案2: 只部署 2 个 Worker 节点
  - 方案3: 将 MinIO 从计划中移除

### K8s 应用资源配置

| 应用 | 类型 | 副本数 | CPU Request/Limit | Memory Request/Limit | 说明 |
|------|------|--------|-------------------|----------------------|------|
| MQTT 订阅客户端 | Deployment | 3 | 100m / 200m | 128Mi / 256Mi | 订阅外部 MQTT |
| 数据处理服务 | Deployment | 3 | 200m / 500m | 256Mi / 512Mi | 数据清洗转换 |
| Kafka Producer | Deployment | 2 | 100m / 200m | 128Mi / 256Mi | 发送到物理机 Kafka |
| Kafka Consumer | Deployment | 2 | 200m / 500m | 256Mi / 512Mi | 消费并写入 DB |
| Grafana | StatefulSet | 2 | 200m / 500m | 256Mi / 512Mi | 可视化 Dashboard |
| 前端应用 | Deployment | 2 | 100m / 200m | 128Mi / 256Mi | React/Vue 前端 |
| ArgoCD | Deployment | 1 | 500m / 1000m | 512Mi / 1Gi | GitOps 管理 |
| Nginx Ingress | DaemonSet | 自动 | 100m / 200m | 128Mi / 256Mi | 流量入口 |

**资源需求分析:**
- CPU Request 总计: ~4.5 Core
- CPU Limit 总计: ~9 Core
- Memory Request 总计: ~3.5GB
- Memory Limit 总计: ~6.5GB
- **结论**: 14GB 虚拟机资源完全满足需求

---

## 网络规划

### IP 地址分配

| 主机/虚拟机 | IP 地址 | 主机名 | 角色 | 说明 |
|-------------|---------|--------|------|------|
| Windows 物理机 | 192.168.1.100 | windows-host | 基础设施 | Harbor/Kafka/TimescaleDB |
| RKE2 Master | 192.168.1.101 | rke2-master | 控制平面 | K8s API Server + etcd |
| RKE2 Worker1 | 192.168.1.102 | rke2-worker1 | 工作节点 | 运行应用 Pod |
| RKE2 Worker2 | 192.168.1.103 | rke2-worker2 | 工作节点 | 运行应用 Pod |
| RKE2 Worker3(可选) | 192.168.1.104 | rke2-worker3 | 工作节点 | 可选扩展 |

**IP 地址段建议:**
- 使用固定 IP,避免 DHCP 变动
- 预留 192.168.1.105-110 用于后续扩展
- DNS 服务器: 8.8.8.8, 114.114.114.114

### 端口分配清单

**Windows 物理机暴露的服务:**

| 服务 | 端口 | 协议 | 访问方式 | 用途 |
|------|------|------|----------|------|
| Harbor Web UI | 8080 | HTTP | http://192.168.1.100:8080 | 镜像仓库管理界面 |
| Harbor Registry | 8080 | HTTP | docker pull 时访问 | 镜像拉取 |
| Kafka Broker | 9092 | TCP | 192.168.1.100:9092 | Kafka 生产/消费 |
| TimescaleDB | 5432 | TCP | 192.168.1.100:5432 | PostgreSQL 连接 |
| Prometheus | 9090 | HTTP | http://192.168.1.100:9090 | 监控数据查询 |

**RKE2 集群必需端口:**

| 用途 | 端口 | 协议 | 方向 | 说明 |
|------|------|------|------|------|
| Kubernetes API | 6443 | TCP | Master | kubectl/应用访问 |
| RKE2 Supervisor | 9345 | TCP | Master | Worker 节点注册 |
| Kubelet API | 10250 | TCP | 双向 | 节点间通信 |
| etcd Client | 2379 | TCP | Master | etcd 客户端访问 |
| etcd Peer | 2380 | TCP | Master | etcd 集群通信 |
| NodePort 范围 | 30000-32767 | TCP/UDP | Worker | Service 对外暴露 |

### 网络模式选择

**VMware 网络配置对比:**

| 模式 | 优点 | 缺点 | 适用场景 | 推荐度 |
|------|------|------|----------|--------|
| **桥接(Bridged)** | VM 独立 IP,与物理机同网段 | 需要路由器 DHCP | 家庭/办公室网络 | ⭐⭐⭐⭐⭐ |
| **NAT** | 不需要路由器配置 | 需要配置端口转发 | 受限网络环境 | ⭐⭐⭐ |
| **Host-Only** | 完全隔离,安全 | VM 无外网访问 | 纯内网实验 | ⭐⭐ |

**推荐配置: 桥接模式**
- 原因: 简化网络配置,VM 与物理机直接通信
- 注意: 确保路由器有足够的 IP 地址池

### 防火墙配置要点

**Windows 防火墙规则:**
- 允许入站: 8080(Harbor), 9092(Kafka), 5432(TimescaleDB)
- 允许出站: 所有 K8s 集群 IP

**Ubuntu 防火墙(ufw):**
- Master 节点: 开放 6443, 9345, 2379-2380, 10250
- Worker 节点: 开放 10250, 30000-32767
- 所有节点: 允许集群内网段互通

---

## 部署时间表

### 分阶段部署计划

| 阶段 | 任务 | 预计时间 | 关键产出 | 前置依赖 |
|------|------|----------|----------|----------|
| **Week 1** | **基础设施搭建** | | | |
| | Windows Docker Desktop 安装配置 | 0.5天 | Docker 环境就绪 | - |
| | Harbor 离线安装包下载 | 0.5天 | harbor-offline-installer.tgz | 外网机器 |
| | Harbor 部署与配置 | 1天 | Harbor Web UI 可访问 | Docker Desktop |
| | 同步 RKE2 系统镜像到 Harbor | 1天 | 所有必需镜像就绪 | Harbor + 外网 |
| | Kafka + TimescaleDB 部署 | 0.5天 | 消息队列与数据库运行 | Docker Desktop |
| | VMware 虚拟机创建 | 0.5天 | 3 个虚拟机就绪 | VMware 安装 |
| | **Week 1 验收**: Harbor 可访问,镜像已同步,VM 已创建 | | | |
| | | | | |
| **Week 2** | **RKE2 集群部署** | | | |
| | Ubuntu 系统安装与初始配置 | 0.5天 | 系统就绪,网络通 | 虚拟机 |
| | RKE2 Master 节点安装 | 0.5天 | K8s API 可访问 | Harbor 镜像 |
| | RKE2 Worker 节点加入 | 0.5天 | 集群就绪 | Master 节点 |
| | Longhorn 存储插件部署 | 0.5天 | 持久化存储可用 | RKE2 集群 |
| | Nginx Ingress 控制器部署 | 0.5天 | HTTP 路由可用 | RKE2 集群 |
| | 网络连通性全面测试 | 0.5天 | Pod 可访问物理机服务 | 全部组件 |
| | **Week 2 验收**: K8s 集群运行正常,存储和网络可用 | | | |
| | | | | |
| **Week 3** | **数据流应用部署** | | | |
| | MQTT 订阅客户端开发 | 1天 | 可订阅外部 MQTT | - |
| | Kafka Producer 开发 | 0.5天 | 数据发送到 Kafka | MQTT 客户端 |
| | Kafka Consumer 开发 | 0.5天 | 消费并写入 DB | Producer |
| | 数据流端到端测试 | 1天 | 完整链路通畅 | 全部应用 |
| | **Week 3 验收**: 数据从 MQTT → Kafka → TimescaleDB 流通 | | | |
| | | | | |
| **Week 4** | **数据存储与优化** | | | |
| | TimescaleDB Schema 设计 | 0.5天 | Hypertable 创建 | - |
| | 数据写入性能测试 | 0.5天 | 确认吞吐量 | Consumer |
| | TimescaleDB 调优 | 1天 | 查询性能优化 | 测试数据 |
| | 数据压缩与保留策略 | 0.5天 | 自动压缩配置 | Schema |
| | **Week 4 验收**: 数据库稳定运行,性能达标 | | | |
| | | | | |
| **Week 5** | **可视化层开发** | | | |
| | Grafana 部署到 K8s | 0.5天 | Grafana 可访问 | RKE2 集群 |
| | TimescaleDB 数据源配置 | 0.5天 | 连接数据库 | Grafana |
| | Dashboard 设计与开发 | 1天 | 实时监控面板 | 数据源 |
| | 前端应用开发(可选) | 1.5天 | 自定义可视化 | - |
| | **Week 5 验收**: 可视化面板展示实时 IoT 数据 | | | |
| | | | | |
| **Week 6-7** | **GitOps 实施** | | | |
| | ArgoCD 部署到 K8s | 0.5天 | ArgoCD UI 可访问 | RKE2 集群 |
| | Git 仓库结构设计 | 0.5天 | 仓库创建 | - |
| | 应用 YAML 清单编写 | 1天 | 所有应用声明式配置 | 现有应用 |
| | 应用迁移到 GitOps 管理 | 2天 | ArgoCD 自动同步 | Git 仓库 |
| | **Week 6-7 验收**: 所有应用通过 Git 管理,自动部署 | | | |
| | | | | |
| **Week 8+** | **优化与演练** | | | |
| | HPA 配置与测试 | 1天 | 自动扩缩容 | 应用运行 |
| | 故障场景演练 | 1天 | 验证高可用性 | 全部组件 |
| | 监控告警完善 | 1天 | Prometheus 告警规则 | Prometheus |
| | 文档整理与总结 | 1天 | 完整技术文档 | 全部工作 |
| | **Week 8+ 验收**: 生产级特性就绪,文档完善 | | | |

**里程碑节点:**
- ✅ M1(Week 1末): 基础设施就绪
- ✅ M2(Week 2末): K8s 集群运行
- ✅ M3(Week 3末): 数据流打通
- ✅ M4(Week 5末): 可视化完成
- ✅ M5(Week 7末): GitOps 实施
- ✅ M6(Week 8末): 生产级就绪

---

## Windows 物理机配置

### 组件部署概览

**物理机承载的服务及职责:**

| 服务 | 版本 | 职责 | 为什么在物理机 |
|------|------|------|----------------|
| **Harbor** | v2.9.0 | 私有镜像仓库 | 解决国内镜像源问题,集中管理所有镜像 |
| **Kafka** | 3.6 (KRaft) | 消息队列 | 高 I/O 需求,物理机磁盘性能更好 |
| **TimescaleDB** | PG15 + TSB 2.13 | 时序数据库 | 数据持久化关键,避免容器迁移风险 |
| **Prometheus** | latest | 监控存储(可选) | 集中存储所有监控数据 |

### Harbor 部署要点

**Harbor 核心功能:**
- 私有 Docker Registry: 存储所有镜像
- 镜像复制与同步: 从公网同步到私有仓库
- RBAC 权限控制: Robot 账号管理
- 镜像扫描(可选): Trivy 漏洞扫描
- 镜像签名(可选): Notary 内容信任

**部署关键步骤:**
1. **下载离线安装包**
   - 官方 GitHub Releases 或使用国内镜像加速
   - 如果完全离线,需要在有外网的机器下载后拷贝

2. **配置 harbor.yml**
   - hostname: 设置为物理机 IP (192.168.1.100)
   - port: HTTP 端口 8080 (避免与其他服务冲突)
   - harbor_admin_password: 设置管理员密码
   - data_volume: 镜像存储路径 (至少 200GB 空间)

3. **执行安装脚本**
   - 运行 install.sh (Linux) 或 install.ps1 (Windows)
   - 可选组件: Trivy 扫描器, ChartMuseum

4. **创建项目与 Robot 账号**
   - 项目名称: rke2 (私有项目)
   - Robot 账号: rke2-puller (只读权限)
   - 保存 Robot Token: 供 RKE2 集群使用

**镜像同步策略:**

**方案 A: 在线同步(有外网环境)**
- 编写镜像列表清单
- 使用脚本批量拉取并推送到 Harbor
- 适用于有外网的开发机器

**方案 B: 离线同步(完全内网)**
- 在外网机器导出镜像为 tar 文件
- 拷贝到内网机器导入
- 适用于生产环境或安全隔离环境

**必需镜像清单:**
- RKE2 系统组件: rke2-runtime, hardened-kubernetes, etcd, coredns
- CNI 插件: Cilium 或 Calico
- Ingress 控制器: Nginx Ingress
- 存储插件: Longhorn
- 监控组件: Metrics Server
- 应用组件: Grafana, ArgoCD, Redis
- 基础镜像: Python, Node.js, Nginx

**Harbor 运维要点:**
- 定期执行垃圾回收(GC): 清理未引用的 blob
- 监控存储空间使用: 避免磁盘满
- 备份 Harbor 数据库: PostgreSQL 定期备份
- 镜像标签管理: 建立版本命名规范

### Kafka 部署要点

**为什么使用 KRaft 模式:**
- 不需要 ZooKeeper: 节省 4GB 内存
- 架构简化: 减少组件依赖
- Kafka 3.0+ 官方推荐: 未来趋势

**关键配置参数:**
- JVM Heap: 设置为 3GB (适配 4GB 内存限制)
- Log Retention: 7 天保留(168 hours)
- Partitions: 默认 3 个分区(适配小规模)
- Replication Factor: 1 (单节点)

**Kafka 连接配置:**
- Advertised Listeners: 必须配置为物理机 IP
- 原因: K8s Pod 需要通过外部 IP 访问

**监控关键指标:**
- 消息积压(Lag): Consumer 是否跟得上
- 吞吐量: Messages/sec
- 磁盘使用: Log 目录大小

### TimescaleDB 部署要点

**TimescaleDB 核心特性:**
- PostgreSQL 扩展: 完全兼容 SQL
- Hypertable: 自动分区时序数据
- 压缩: 自动压缩历史数据(节省 80-90% 空间)
- 连续聚合: 自动生成汇总表

**初始化配置:**
- 创建 Hypertable: 将普通表转换为时序表
- 设置 Chunk 间隔: 按天或按周分区
- 启用压缩策略: 7 天后自动压缩
- 设置保留策略: 90 天后自动删除

**性能调优工具:**
- timescaledb-tune: 自动根据硬件生成配置
- 推荐配置: shared_buffers=1GB, effective_cache_size=3GB

**备份策略:**
- pg_dump: 定期全量备份
- WAL 归档: 增量备份(可选)
- 快照: Docker volume 备份

### 网络互通配置

**K8s 访问物理机服务的方法:**

**方法 1: ExternalName Service(推荐)**
- 创建 Service 类型为 ExternalName
- externalName 指向物理机 IP
- 应用通过 Service DNS 访问

**方法 2: Endpoints + Service**
- 手动创建 Endpoints 指向外部 IP
- 创建无 Selector 的 Service
- 更灵活但配置复杂

**方法 3: 直接使用 IP**
- 应用中硬编码物理机 IP
- 简单但不够优雅

**防火墙注意事项:**
- Windows 防火墙: 允许 K8s 网段访问相关端口
- 测试连通性: 在 Pod 中 telnet 测试端口

---

## VMware 虚拟机配置

### 虚拟机创建规范

**Master 节点配置:**
- CPU: 4 vCPU
- 内存: 6GB
- 磁盘: 40GB (精简配置)
- 网络: 桥接模式
- 操作系统: Ubuntu 22.04 Server

**Worker 节点配置:**
- CPU: 2 vCPU
- 内存: 4GB
- 磁盘: 40GB (精简配置)
- 网络: 桥接模式
- 操作系统: Ubuntu 22.04 Server

**虚拟机优化建议:**
- 禁用 3D 图形加速
- 使用精简磁盘(节省宿主机空间)
- 启用虚拟化嵌套(如果需要运行嵌套虚拟化)

### Ubuntu 系统配置

**网络配置要点:**
- 使用静态 IP: 避免 DHCP 变化
- 配置文件: /etc/netplan/00-installer-config.yaml
- 网关: 指向路由器
- DNS: 8.8.8.8, 114.114.114.14
- 测试: ping 通物理机和外网

**系统初始化:**
- 更新软件包: apt update && apt upgrade
- 安装必要工具: curl, wget, vim, net-tools
- 关闭 swap: RKE2 要求
- 配置主机名: /etc/hostname 和 /etc/hosts
- 配置 SSH: 允许 root 登录(可选)

**时间同步:**
- 安装 chrony 或 systemd-timesyncd
- 确保集群时间一致: 对 etcd 很重要

**防火墙配置:**
- 安装 ufw
- Master 节点: 开放 6443, 9345, 2379-2380, 10250
- Worker 节点: 开放 10250, 30000-32767
- 允许集群内网段: ufw allow from 192.168.1.0/24

---

## RKE2 集群配置

### RKE2 vs 其他 K8s 发行版

**为什么选择 RKE2:**
- 安全加固: 符合 CIS 标准,开箱即用
- 接近原生: 学习价值高于 K3s
- 企业级特性: 双栈网络,高级 Pod Security
- Rancher 官方支持: 文档完善,社区活跃

**对比其他方案:**
- vs K3s: RKE2 更接近生产 K8s,学习价值更高
- vs Kubeadm: RKE2 安装更简单,维护成本更低
- vs Managed K8s(EKS/GKE): RKE2 完全自主控制

### RKE2 核心配置

**Master 节点配置文件: /etc/rancher/rke2/config.yaml**

关键配置项:
- write-kubeconfig-mode: 设置 kubeconfig 权限
- tls-san: 添加额外的 API Server SAN(IP/域名)
- system-default-registry: 指向 Harbor 地址
- cni: 选择 CNI 插件(Cilium 或 Calico)
- disable: 禁用不需要的组件

**Worker 节点配置文件: /etc/rancher/rke2/config.yaml**

关键配置项:
- server: Master 节点 API 地址
- token: 从 Master 获取的 join token
- 路径: /var/lib/rancher/rke2/server/node-token

**镜像仓库配置: /etc/rancher/rke2/registries.yaml**

核心功能:
- mirrors: 镜像源重定向规则
- configs: 镜像仓库认证信息
- 将所有镜像请求重定向到 Harbor
- 使用 Robot 账号认证

**配置示例逻辑:**
- 原始: docker.io/library/nginx:latest
- 重写: 192.168.1.100:8080/rke2/nginx:latest
- RKE2 自动处理重写和认证

### 存储插件选择

**Longhorn(推荐):**
- 云原生分布式块存储
- Web UI 管理界面
- 支持快照、备份、恢复
- 自动多副本(至少 3 个节点)

**Local PV(简化方案):**
- 使用本地磁盘
- 性能最好
- 但数据绑定到节点(不可迁移)

**NFS(如果有 NAS):**
- 共享存储
- 数据集中管理
- 需要外部 NFS 服务器

**推荐策略:**
- 学习阶段: Local PV(简单快速)
- 生产模拟: Longhorn(完整特性)

### 网络插件选择

**Cilium(推荐):**
- 基于 eBPF: 性能优秀
- 强大的网络策略
- 内置负载均衡
- 可观测性好

**Calico:**
- 成熟稳定
- 丰富的网络策略
- 社区大

**Flannel:**
- 简单轻量
- 功能较少
- K3s 默认

**推荐: Cilium**
- 原因: 性能+功能+学习价值

---

## 应用部署策略

### 应用架构设计

**数据流全景:**
```
外部 MQTT (hats.hcs.cn:1883)
  ↓
[K8s] MQTT 订阅 Pods × 3
  ↓
[物理机] Kafka
  ↓
[K8s] Kafka Consumer Pods × 2
  ↓
[物理机] TimescaleDB
  ↓
[K8s] Grafana × 2
  ↓
[K8s] 前端应用 × 2
```

### 无状态服务部署原则

**充分体现 K8s 调度价值:**

**反亲和性配置:**
- 目标: Pod 尽量分散到不同节点
- 实现: podAntiAffinity 配置
- 好处: 提高可用性,避免单点故障

**HPA 自动扩缩容:**
- 目标: 根据负载自动调整副本数
- 指标: CPU 利用率或自定义 metric
- 好处: 资源利用率最大化

**滚动更新策略:**
- maxSurge: 更新时额外启动的 Pod 数
- maxUnavailable: 更新时允许不可用的 Pod 数
- 好处: 零停机部署

**资源限制(QoS):**
- Guaranteed: request=limit (高优先级)
- Burstable: request<limit (中优先级)
- BestEffort: 无 request/limit (低优先级)

### MQTT 订阅客户端

**技术选型:**
- Python + Paho-MQTT: 轻量,易于开发
- Node-RED: 可视化编排,你有经验
- Go + Eclipse Paho: 性能最好

**推荐: Python(快速实现)**

**核心功能:**
- 订阅外部 MQTT Topic
- 数据解析与验证
- 发送到 Kafka
- 失败重试机制

**部署配置:**
- Deployment: 3 副本
- 反亲和性: 分散到不同节点
- Conf
