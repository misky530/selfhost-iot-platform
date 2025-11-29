# RKE2 Kubernetes 集群部署

## 集群信息
- **部署方式**: RKE2 (离线安装)
- **节点数量**: 1 Master + 3 Workers
- **网络模式**: NAT
- **容器运行时**: containerd

## 节点列表
| 角色 | 主机名 | IP 地址 | 操作系统 |
|------|--------|---------|----------|
| Master | master01 | 192.168.226.140 | Ubuntu Server 22.04 |
| Worker | worker1  | 192.168.226.141 | Ubuntu Server 22.04 |
| Worker | worker2  | 192.168.226.142 | Ubuntu Server 22.04 |
| Worker | worker3  | 192.168.226.143 | Ubuntu Server 22.04 |

## 宿主机信息
- **IP**: 10.0.73.30
- **OS**: Windows 10
- **虚拟化**: VMware

## 目录结构
```
kubernetes/
├── rke2/
│   ├── offline-packages/     # RKE2 离线安装包
│   ├── master/
│   │   └── config/           # Master 节点配置文件
│   ├── worker/
│   │   └── config/           # Worker 节点配置文件
│   ├── scripts/              # 安装和管理脚本
│   └── docs/                 # 部署文档
└── manifests/
    ├── apps/                 # 应用部署清单
    └── infrastructure/       # 基础设施清单
```

## 部署阶段
- [x] 阶段 0: 配置仓库创建
- [ ] 阶段 1: 离线包下载
- [ ] 阶段 2: 虚拟机模板准备
- [ ] 阶段 3: Master 节点部署
- [ ] 阶段 4: Worker 节点加入
- [ ] 阶段 5: 集群验证

## 外部依赖服务 (物理机)
- TimescaleDB: 10.0.73.30:5432
- Kafka: 10.0.73.30:9092
- Harbor: http://10.0.73.30

---
更新时间: $(date '+%Y-%m-%d %H:%M:%S')
