# WordPress on Kubernetes - 版本 1.0 基础可用版

## 🎯 学习目标

通过部署一个最简单但完整的WordPress系统，学习Kubernetes的核心概念：

- ✅ **Namespace**: 资源隔离
- ✅ **Deployment**: 无状态应用部署
- ✅ **Service**: 服务发现与负载均衡
- ✅ **ConfigMap & Secret**: 配置管理
- ✅ **PersistentVolumeClaim**: 数据持久化
- ✅ **Pod生命周期**: 理解Pod的创建、运行、重启
- ✅ **基础故障排查**: 使用kubectl调试问题

## 📊 架构图

```
┌─────────────────────────────────────┐
│      浏览器 (你的电脑)              │
└──────────────┬──────────────────────┘
               │ http://192.168.226.131:30080
               ▼
┌─────────────────────────────────────┐
│      Kubernetes 集群                │
│  ┌───────────────────────────────┐  │
│  │  WordPress Service (NodePort) │  │
│  │  Port: 80 → NodePort: 30080  │  │
│  └─────────────┬─────────────────┘  │
│                ▼                     │
│  ┌───────────────────────────────┐  │
│  │  WordPress Pod                │  │
│  │  - Image: wordpress:6.4       │  │
│  │  - Port: 80                   │  │
│  │  - Volume: wordpress-pvc      │  │
│  └─────────────┬─────────────────┘  │
│                │ mysql:3306          │
│                ▼                     │
│  ┌───────────────────────────────┐  │
│  │  MySQL Service (ClusterIP)    │  │
│  │  Port: 3306                   │  │
│  └─────────────┬─────────────────┘  │
│                ▼                     │
│  ┌───────────────────────────────┐  │
│  │  MySQL Pod                    │  │
│  │  - Image: mysql:8.0           │  │
│  │  - Port: 3306                 │  │
│  │  - Volume: mysql-pvc          │  │
│  └───────────────────────────────┘  │
│                                      │
│  存储层 (local-path StorageClass)   │
│  ┌──────────────┐ ┌──────────────┐ │
│  │ mysql-pvc    │ │wordpress-pvc │ │
│  │ 5Gi          │ │ 10Gi         │ │
│  └──────────────┘ └──────────────┘ │
└─────────────────────────────────────┘
```

## 📁 文件说明

```
version-1.0-basic/
├── 00-namespace.yaml           # 创建wordpress命名空间
├── 01-mysql-secret.yaml        # MySQL密码和配置
├── 02-mysql-pvc.yaml           # MySQL数据持久化
├── 03-mysql-deployment.yaml    # 部署MySQL数据库
├── 04-mysql-service.yaml       # MySQL内部服务
├── 05-wordpress-pvc.yaml       # WordPress文件持久化
├── 06-wordpress-deployment.yaml # 部署WordPress应用
├── 07-wordpress-service.yaml   # WordPress对外服务(NodePort)
├── deploy.sh                   # 一键部署脚本
├── verify.sh                   # 验证脚本
└── README.md                   # 本文件
```

## 🚀 快速开始

### 方法一：使用一键部署脚本（推荐）

```bash
# 进入目录
cd version-1.0-basic

# 运行部署脚本
./deploy.sh

# 验证部署
./verify.sh
```

### 方法二：手动逐步部署

```bash
# 1. 创建Namespace
kubectl apply -f 00-namespace.yaml

# 2. 创建Secret（包含MySQL密码）
kubectl apply -f 01-mysql-secret.yaml

# 3. 创建MySQL存储
kubectl apply -f 02-mysql-pvc.yaml

# 4. 部署MySQL
kubectl apply -f 03-mysql-deployment.yaml
kubectl apply -f 04-mysql-service.yaml

# 等待MySQL启动（重要！）
kubectl wait --for=condition=ready pod -l app=mysql -n wordpress --timeout=180s

# 5. 创建WordPress存储
kubectl apply -f 05-wordpress-pvc.yaml

# 6. 部署WordPress
kubectl apply -f 06-wordpress-deployment.yaml
kubectl apply -f 07-wordpress-service.yaml

# 等待WordPress启动
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=180s
```

## ✅ 验证部署

### 1. 检查所有资源

```bash
# 查看所有资源
kubectl get all -n wordpress

# 应该看到:
# - 2个Deployments (mysql, wordpress)
# - 2个Services (mysql, wordpress)
# - 2个Pods (mysql-xxx, wordpress-xxx)
# - 2个ReplicaSets
```

### 2. 检查Pod状态

```bash
kubectl get pods -n wordpress

# 期望输出:
# NAME                         READY   STATUS    RESTARTS   AGE
# mysql-xxxxxxxxxx-xxxxx       1/1     Running   0          2m
# wordpress-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

### 3. 检查PVC状态

```bash
kubectl get pvc -n wordpress

# 期望输出:
# NAME            STATUS   VOLUME                                     CAPACITY
# mysql-pvc       Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   5Gi
# wordpress-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi
```

### 4. 检查Service

```bash
kubectl get svc -n wordpress

# 期望输出:
# NAME        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# mysql       ClusterIP   10.233.x.x      <none>        3306/TCP       2m
# wordpress   NodePort    10.233.x.x      <none>        80:30080/TCP   1m
```

## 🌐 访问WordPress

### 获取访问地址

```bash
# 获取节点IP和端口
kubectl get nodes -o wide
kubectl get svc wordpress -n wordpress

# 访问地址（使用任意节点IP）:
# http://192.168.226.131:30080
# http://192.168.226.132:30080
# http://192.168.226.133:30080
```

### 完成WordPress安装

1. 浏览器访问 `http://节点IP:30080`
2. 选择语言 → 简体中文
3. 填写站点信息:
   - 站点标题: `My K8s Blog`
   - 用户名: `admin`
   - 密码: 设置一个强密码
   - 电子邮箱: 你的邮箱
4. 点击"安装WordPress"
5. 登录后台: `http://节点IP:30080/wp-admin`

## 🔍 学习要点

### 1. Namespace的作用

```bash
# 查看所有namespace
kubectl get namespaces

# 为什么要创建独立的namespace？
# - 资源隔离（不同项目互不干扰）
# - 权限控制（RBAC基于namespace）
# - 资源配额（ResourceQuota）
# - 逻辑分组（便于管理）
```

### 2. Secret vs ConfigMap

```bash
# 查看Secret（数据被base64编码）
kubectl get secret mysql-secret -n wordpress -o yaml

# 为什么使用Secret存储密码？
# - 与代码分离
# - 支持加密存储（etcd encryption）
# - 权限控制（RBAC）
# - 便于更新（不需要重新构建镜像）

# ConfigMap用于非敏感配置
# Secret用于敏感信息（密码、证书、Token）
```

### 3. PVC的生命周期

```bash
# 查看PVC详情
kubectl describe pvc mysql-pvc -n wordpress

# PVC生命周期:
# 1. Pending: PVC创建，等待绑定PV
# 2. Bound: PVC绑定到PV
# 3. Released: Pod删除，PVC保留
# 4. 删除PVC时，根据StorageClass的reclaimPolicy决定PV命运

# local-path的特点:
# - 自动创建PV（动态供给）
# - 数据存储在节点本地
# - ReclaimPolicy: Delete（PVC删除时PV也删除）
```

### 4. Service的DNS解析

```bash
# 进入WordPress容器测试
kubectl exec -it deployment/wordpress -n wordpress -- bash

# 在容器内测试DNS
ping mysql
# 可以ping通！自动解析为mysql Service的ClusterIP

# DNS完整格式:
# <service-name>.<namespace>.svc.cluster.local
# mysql.wordpress.svc.cluster.local

# 同namespace可以直接用service名
# 跨namespace必须带namespace
```

### 5. Deployment的自愈能力

```bash
# 实验：删除一个Pod
kubectl delete pod -l app=mysql -n wordpress

# 立即查看
kubectl get pods -n wordpress -w

# 观察:
# 1. Pod被终止（Terminating）
# 2. Deployment立即创建新Pod
# 3. 新Pod启动（ContainerCreating → Running）
# 4. 这就是Kubernetes的自愈能力！

# Deployment确保副本数始终等于spec.replicas
```

## 🐛 故障排查指南

### Pod无法启动

```bash
# 1. 查看Pod状态
kubectl get pods -n wordpress

# 2. 查看Pod详情
kubectl describe pod <pod-name> -n wordpress

# 常见问题:
# - ImagePullBackOff: 镜像拉取失败
# - CrashLoopBackOff: 容器启动后崩溃
# - Pending: 无法调度（资源不足、PVC无法绑定等）
```

### 查看日志

```bash
# WordPress日志
kubectl logs deployment/wordpress -n wordpress

# MySQL日志
kubectl logs deployment/mysql -n wordpress

# 查看之前容器的日志（如果容器重启了）
kubectl logs deployment/wordpress -n wordpress --previous
```

### 进入容器调试

```bash
# 进入WordPress容器
kubectl exec -it deployment/wordpress -n wordpress -- bash

# 测试MySQL连接
ping mysql
nc -zv mysql 3306

# 查看WordPress配置
cat /var/www/html/wp-config.php

# 进入MySQL容器
kubectl exec -it deployment/mysql -n wordpress -- bash

# 连接MySQL
mysql -u root -p
# 密码: MyWordPress123!

# 查看数据库
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
```

### 数据库连接失败

**问题**: WordPress显示"Error establishing database connection"

**排查步骤**:

```bash
# 1. 检查MySQL Pod是否运行
kubectl get pods -l app=mysql -n wordpress

# 2. 检查MySQL日志
kubectl logs deployment/mysql -n wordpress

# 3. 检查Service
kubectl get svc mysql -n wordpress
kubectl describe svc mysql -n wordpress

# 4. 测试连接
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -n wordpress \
  -- mysql -h mysql -u wordpress -pMyWordPress123! -e "SELECT 1;"

# 5. 检查Secret
kubectl get secret mysql-secret -n wordpress -o yaml
```

### PVC一直Pending

**问题**: PVC无法绑定

```bash
# 查看PVC事件
kubectl describe pvc mysql-pvc -n wordpress

# 常见原因:
# 1. StorageClass不存在
kubectl get storageclass

# 2. 没有可用的PV（动态供给应该自动创建）
kubectl get pv

# 3. VolumeBindingMode是WaitForFirstConsumer
# 这是正常的！PVC会等到有Pod使用时才绑定
```

## 🧪 实验练习

### 练习1：观察Pod重启

```bash
# 1. 删除MySQL Pod
kubectl delete pod -l app=mysql -n wordpress

# 2. 持续观察
kubectl get pods -n wordpress -w

# 3. 检查新Pod是否使用相同的PVC
kubectl describe pod -l app=mysql -n wordpress | grep Volume -A 5

# 思考：数据是否还在？
```

### 练习2：修改副本数

```bash
# 1. 扩展WordPress到2个副本
kubectl scale deployment wordpress --replicas=2 -n wordpress

# 2. 观察变化
kubectl get pods -n wordpress -w

# 3. 访问测试（刷新页面，观察是否负载均衡）

# 4. 缩回1个副本
kubectl scale deployment wordpress --replicas=1 -n wordpress

# 思考：为什么MySQL不能简单扩容到多副本？
```

### 练习3：查看事件

```bash
# 查看namespace中的所有事件
kubectl get events -n wordpress --sort-by='.lastTimestamp'

# 过滤警告事件
kubectl get events -n wordpress --field-selector type=Warning

# 持续监控事件
kubectl get events -n wordpress -w
```

### 练习4：修改Service类型

```bash
# 1. 编辑Service
kubectl edit svc wordpress -n wordpress

# 2. 将type从NodePort改为ClusterIP
# 保存退出

# 3. 观察变化
kubectl get svc wordpress -n wordpress

# 4. 尝试访问（应该无法从集群外访问）

# 5. 改回NodePort
kubectl edit svc wordpress -n wordpress
```

## 📚 知识点总结

### 本版本学到的概念

| 概念 | 作用 | 关键点 |
|------|------|--------|
| Namespace | 资源隔离 | 逻辑分组，权限边界 |
| Deployment | 应用部署 | 副本管理，滚动更新，自愈 |
| Service | 服务发现 | 负载均衡，稳定端点，DNS |
| ConfigMap | 配置管理 | 非敏感配置外部化 |
| Secret | 密钥管理 | 敏感信息保护 |
| PVC | 数据持久化 | 存储抽象，生命周期管理 |
| NodePort | 外部访问 | 集群外访问的简单方式 |

### kubectl核心命令

```bash
# 查看资源
kubectl get <resource> -n <namespace>
kubectl get all -n wordpress

# 查看详情
kubectl describe <resource> <name> -n <namespace>

# 查看日志
kubectl logs <pod> -n <namespace>
kubectl logs deployment/<name> -n <namespace>

# 执行命令
kubectl exec -it <pod> -n <namespace> -- <command>

# 应用配置
kubectl apply -f <file.yaml>

# 删除资源
kubectl delete -f <file.yaml>
kubectl delete <resource> <name> -n <namespace>

# 编辑资源
kubectl edit <resource> <name> -n <namespace>

# 扩缩容
kubectl scale deployment <name> --replicas=<number> -n <namespace>
```

## 🔄 下一步

完成版本1.0后，你应该掌握了：
- ✅ 基本的Kubernetes资源类型
- ✅ 使用kubectl管理资源
- ✅ 基础的故障排查方法
- ✅ Pod、Service、Deployment的关系

**准备好了吗？** 继续学习 [版本2.0 - 生产就绪版](../version-2.0-production/README.md)

版本2.0将教你：
- 多副本部署和负载均衡
- 健康检查（Liveness/Readiness Probe）
- 资源限制和QoS
- Ingress域名访问
- 自动扩缩容（HPA）

## 🗑️ 清理资源

```bash
# 删除整个namespace（会删除所有资源）
kubectl delete namespace wordpress

# 如果需要保留数据，单独删除Deployment和Service
kubectl delete deployment mysql wordpress -n wordpress
kubectl delete svc mysql wordpress -n wordpress

# PVC和数据会保留
kubectl get pvc -n wordpress
```

## ❓ 常见问题FAQ

**Q: 为什么WordPress启动很慢？**

A: 首次启动需要：
1. 拉取镜像（如果本地没有）
2. 初始化WordPress文件
3. 等待MySQL就绪
4. 建立数据库连接

**Q: 数据会丢失吗？**

A: 使用PVC持久化，数据不会丢失。但注意：
- local-path存储在节点本地
- Pod重启调度到其他节点，数据会丢失
- 生产环境建议使用网络存储或StatefulSet

**Q: 如何更换MySQL密码？**

A: 
```bash
# 1. 修改Secret
kubectl edit secret mysql-secret -n wordpress

# 2. 重启MySQL Pod
kubectl delete pod -l app=mysql -n wordpress

# 3. 更新WordPress配置（如果已安装）
```

**Q: 可以在生产环境使用这个配置吗？**

A: **不推荐！** 版本1.0只是学习版，缺少：
- 健康检查
- 资源限制
- 多副本高可用
- 监控告警
- 备份恢复
- 安全加固

生产环境请看版本4.0。
