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

# IoT 混合架构完整部署方案

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

**采用混合架构**

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

