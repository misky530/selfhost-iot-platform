# WordPress on Kubernetes - 完整学习项目

## 项目目标
通过部署一个完整的WordPress博客系统，系统学习Kubernetes的核心特性和最佳实践。

## 学习路线图

### 版本 1.0 - 基础可用版（第1天）
**目标**: 让WordPress运行起来
**架构**: WordPress Pod → MySQL Pod
**学习内容**:
- Namespace资源隔离
- Deployment工作负载
- Service服务发现
- ConfigMap配置管理
- Secret密钥管理
- PersistentVolumeClaim持久化存储
- 基础故障排查

### 版本 2.0 - 生产就绪版（第2天）
**目标**: 生产级配置
**架构**: Ingress → WordPress Pods(3) → MySQL
**学习内容**:
- 多副本部署
- Liveness/Readiness探针
- Resource Request/Limit
- Ingress域名路由
- HPA自动扩缩容
- 滚动更新与回滚

### 版本 3.0 - 高可用版（第3-4天）
**目标**: 高可用架构
**架构**: WordPress Pods(2-10) + Redis + MySQL主从
**学习内容**:
- StatefulSet有状态应用
- Headless Service
- Pod Affinity/Anti-affinity
- Redis缓存层
- MySQL主从复制
- 跨节点分布策略

### 版本 4.0 - 企业级（第5-7天）
**目标**: 企业级运维能力
**新增组件**: Prometheus + Grafana + NetworkPolicy + Backup
**学习内容**:
- 完整监控体系
- 日志收集方案
- NetworkPolicy网络隔离
- RBAC权限控制
- 定期备份策略
- 灾难恢复演练

## 环境信息

**集群配置**:
- Kubernetes版本: v1.26.5
- 节点数: 3 (1 master + 2 worker)
- CNI: Calico
- StorageClass: local-path (默认)
- Container Runtime: containerd 1.6.4

**节点列表**:
- k8s-master: 192.168.226.131 (control-plane)
- k8s-node1: 192.168.226.132 (worker)
- k8s-node2: 192.168.226.133 (worker)

## 项目文件结构

```
wordpress-k8s-project/
├── PROJECT-OVERVIEW.md          # 本文件
├── SETUP-INGRESS.md             # Ingress Controller安装指南
├── version-1.0-basic/           # 版本1.0
│   ├── 00-namespace.yaml
│   ├── 01-mysql-secret.yaml
│   ├── 02-mysql-pvc.yaml
│   ├── 03-mysql-deployment.yaml
│   ├── 04-mysql-service.yaml
│   ├── 05-wordpress-pvc.yaml
│   ├── 06-wordpress-deployment.yaml
│   ├── 07-wordpress-service.yaml
│   ├── deploy.sh                # 一键部署脚本
│   ├── verify.sh                # 验证脚本
│   └── README.md                # 详细说明
├── version-2.0-production/      # 版本2.0
├── version-3.0-ha/              # 版本3.0
├── version-4.0-enterprise/      # 版本4.0
└── troubleshooting-scenarios/   # 故障演练场景
```

## 开始学习

1. 先安装Ingress Controller: `cat SETUP-INGRESS.md`
2. 从版本1.0开始: `cd version-1.0-basic && cat README.md`
3. 每个版本都有详细的README和部署脚本
4. 建议边部署边做笔记，记录遇到的问题

## 学习建议

1. **不要跳过版本**: 每个版本都是递进的，跳过会错过重要知识点
2. **主动制造故障**: 删除Pod、修改配置、模拟节点故障等
3. **查看日志和事件**: 使用kubectl logs、describe、get events
4. **理解而不是记忆**: 理解为什么这样配置，而不是死记YAML
5. **做好笔记**: 记录每个字段的作用和你的理解

## 常用命令速查

```bash
# 查看资源
kubectl get pods -n wordpress
kubectl get all -n wordpress
kubectl describe pod <pod-name> -n wordpress

# 查看日志
kubectl logs <pod-name> -n wordpress
kubectl logs <pod-name> -n wordpress --previous  # 查看上一个容器的日志

# 进入容器
kubectl exec -it <pod-name> -n wordpress -- bash

# 查看事件
kubectl get events -n wordpress --sort-by='.lastTimestamp'

# 删除资源
kubectl delete -f <file.yaml>
kubectl delete pod <pod-name> -n wordpress --force --grace-period=0

# 端口转发（本地测试）
kubectl port-forward svc/wordpress 8080:80 -n wordpress
```

## 问题反馈

在学习过程中遇到问题，可以：
1. 查看对应版本的README中的"常见问题"部分
2. 查看troubleshooting-scenarios中的故障场景
3. 使用kubectl describe和logs命令排查
4. 记录问题到学习笔记中

祝学习顺利！🚀
