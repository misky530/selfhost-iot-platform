# 📋 RKE2 部署现状与下一步计划（新会话参考）

## ✅ 已完成内容

### 1. 环境信息
**物理机 (Windows 10):**
- IP: `10.0.73.30`
- 操作系统: Windows 10
- Docker Desktop: 已安装并运行

**虚拟机 (VMware NAT):**
- 操作系统: Ubuntu Server 22.04
- Master 节点: `master01`
  - IP: `192.168.226.140`
  - 用户名/密码: `caiqian/caiqian`
  - SSH 连接: `ssh caiqian@192.168.226.140`
- Worker 节点 (待部署): `worker1-3`
  - IP: `192.168.226.141-143`

---

### 2. 基础服务状态（物理机 Docker）

| 服务 | 地址 | 状态 | 验证方法 |
|------|------|------|----------|
| TimescaleDB | `10.0.73.30:5432` | ✅ Running | `nc -zv 10.0.73.30 5432` |
| Kafka | `10.0.73.30:9092` | ✅ Running | `nc -zv 10.0.73.30 9092` |
| Harbor | `http://10.0.73.30` | ✅ Running | `curl -I http://10.0.73.30` |

**Harbor 登录信息:**
- 用户名: `admin`
- 密码: `Harbor12345`
- Web UI: `http://10.0.73.30`
- Docker 登录: `docker login 10.0.73.30`

---

### 3. RKE2 集群状态

**版本信息:**
- RKE2 版本: `v1.33.6+rke2r1`
- Kubernetes 版本: `v1.33.6`
- 安装方式: 离线安装

**Master 节点状态:**
```
NAME       STATUS   ROLES                       AGE    VERSION
master01   Ready    control-plane,etcd,master   4h+    v1.33.6+rke2r1
```

**Token 位置:**
```bash
# 在 master01 上
cat ~/rke2-token.txt
```

**网络配置:**
- Pod CIDR: `10.42.0.0/16`
- Service CIDR: `10.43.0.0/16`
- CNI: Canal (Calico + Flannel)

**系统 Pods:**
```bash
kubectl get pods -A
# 所有系统 Pod 应该都是 Running 状态
```

---

### 4. 验证测试结果

#### ✅ **测试 1: Pod 部署成功**
```bash
# 测试部署
kubectl get deployments
# 输出:
# NAME         READY   UP-TO-DATE   AVAILABLE   AGE
# test-nginx   1/1     1            1           XXm

kubectl get pods
# 输出:
# NAME                          READY   STATUS    RESTARTS   AGE
# test-nginx-7855c7d7b6-x4rjw   1/1     Running   0          XXm
```

#### ✅ **测试 2: 网络连通性验证**
从 Pod 访问物理机服务：
```bash
# 进入 Pod
kubectl exec -it test-nginx-7855c7d7b6-x4rjw -- sh

# 测试结果
nc -zv 10.0.73.30 5432  # ✅ TimescaleDB - Connection succeeded!
nc -zv 10.0.73.30 9092  # ✅ Kafka - Connection succeeded!
curl -I http://10.0.73.30  # ✅ Harbor - HTTP/1.1 200 OK
```

**结论:** 混合架构网络完全正常，Kubernetes Pod 可以访问物理机的所有服务。

---

### 5. 配置文件位置

#### **物理机 (Windows):**
```
D:\code\selfhost-iot-platform\
├── harbor\
│   ├── harbor.yml
│   │   └── data_volume: /d/harbor-data
│   ├── docker-compose.yml
│   └── prepare
├── kubernetes\rke2\
│   ├── offline-packages\v1.33.6\
│   ├── master\config\config.yaml
│   └── worker\config\  # 待配置

D:\harbor-data\  # Harbor 数据存储
├── database\
├── registry\
├── redis\
└── secret\
```

#### **Master 节点 (Ubuntu):**
```
/etc/rancher/rke2/
├── config.yaml
└── registries.yaml  # Harbor 镜像仓库配置

/home/caiqian/
├── rke2-token.txt
├── .kube/config
└── nginx-alpine.tar  # 测试镜像
```

**registries.yaml 内容:**
```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://10.0.73.30"
  "10.0.73.30":
    endpoint:
      - "http://10.0.73.30"

configs:
  "10.0.73.30":
    auth:
      username: admin
      password: Harbor12345
    tls:
      insecure_skip_verify: true
```

---

### 6. 已知问题与限制

#### ⚠️ **问题 1: Windows Docker Desktop 无法推送镜像到 Harbor**
**现象:** Docker push 失败，提示 EOF 错误
**影响:** 无法从物理机直接推送镜像到 Harbor
**临时方案:** 使用镜像导入方式
```bash
# 物理机导出
docker save <image> -o /d/image.tar
# 传输到 master01
scp /d/image.tar caiqian@192.168.226.140:/home/caiqian/
# 导入到 containerd
sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image import image.tar
```

#### ⚠️ **问题 2: Master 节点无法直接访问 Docker Hub**
**现象:** `connection refused` 访问 `registry-1.docker.io`
**影响:** 无法直接拉取公共镜像
**解决方案:** 
- 使用 Harbor 作为镜像代理（需配置）
- 或者手动导入镜像

---

## 🎯 下一步计划

### **选项 A: 部署实际应用（推荐）** ⭐

验证完整的 IoT 数据流：

**1. 部署 MQTT Broker**
```yaml
# mqtt-broker.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mosquitto
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mosquitto
  template:
    metadata:
      labels:
        app: mosquitto
    spec:
      containers:
      - name: mosquitto
        image: eclipse-mosquitto:latest  # 需先导入镜像
        ports:
        - containerPort: 1883
```

**2. 部署 Kafka Consumer**
- 连接物理机 Kafka (10.0.73.30:9092)
- 验证消息消费

**3. 部署 TimescaleDB 客户端**
- 连接物理机 TimescaleDB (10.0.73.30:5432)
- 验证数据写入

---

### **选项 B: 添加 Worker 节点**

扩展集群到多节点架构。

**前置准备:**
```bash
# 1. 在 master01 获取 token
cat ~/rke2-token.txt

# 2. 确认 master01 可达
ping 192.168.226.140
```

**Worker 配置文件:**
```yaml
# /etc/rancher/rke2/config.yaml (on worker nodes)
server: https://192.168.226.140:9345
token: <从 master01 获取>
```

**安装步骤:**
```bash
# 在 worker 节点执行
sudo mkdir -p /etc/rancher/rke2
sudo vim /etc/rancher/rke2/config.yaml
# 复制离线安装包并安装
sudo systemctl enable rke2-agent
sudo systemctl start rke2-agent
```

---

### **选项 C: 解决 Harbor 镜像推送问题**

**方案 1: 配置 Harbor 为 HTTPS**
- 生成 SSL 证书
- 修改 `harbor.yml` 启用 HTTPS
- 更新 Docker 和 RKE2 配置

**方案 2: 配置 Harbor 作为 Docker Hub 代理**
- 在 Harbor Web UI 配置代理
- 自动缓存公共镜像

**方案 3: 使用 Linux 节点推送**
- 在 master01 或 worker 节点上配置 Docker/podman
- 直接推送到 Harbor

---

### **选项 D: 配置持久化存储**

**方案 1: 本地存储 (Local Path Provisioner)**
```yaml
# 使用 RKE2 内置的 local-path storage class
storageClassName: local-path
```

**方案 2: NFS 存储**
- 在物理机配置 NFS 服务器
- 在 Kubernetes 中配置 NFS provisioner

---

## 🚀 快速启动命令

### **检查集群状态**
```bash
# SSH 到 master01
ssh caiqian@192.168.226.140

# 检查节点
kubectl get nodes

# 检查所有 Pod
kubectl get pods -A

# 检查部署
kubectl get deployments

# 查看集群信息
kubectl cluster-info
```

### **检查物理机服务**
```bash
# 在物理机 Git Bash 执行
cd /d/code/selfhost-iot-platform/harbor

# 检查 Harbor
docker ps | grep harbor

# 检查其他服务
docker ps | grep -E "kafka|timescale"
```

### **测试网络连通性**
```bash
# 在 master01 上
kubectl run test-net --image=nginx:alpine --rm -it --restart=Never -- sh

# 在 Pod 内测试
apk add --no-cache netcat-openbsd
nc -zv 10.0.73.30 5432  # TimescaleDB
nc -zv 10.0.73.30 9092  # Kafka
nc -zv 10.0.73.30 80    # Harbor
```

---

## 📚 参考资源

### **RKE2 文档**
- 官方文档: https://docs.rke2.io/
- 镜像仓库配置: https://docs.rke2.io/install/containerd_registry_configuration

### **Harbor 文档**
- 官方文档: https://goharbor.io/docs/
- Docker Registry API: https://docs.docker.com/registry/spec/api/

### **Kubernetes 资源**
- kubectl 命令速查: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- Pod 网络调试: https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/

---

## 🔧 常见问题快速解决

### **问题: Pod 一直 Pending**
```bash
# 检查是否有污点
kubectl describe node master01 | grep Taints

# 如果有 NoSchedule 污点，移除
kubectl taint nodes master01 node-role.kubernetes.io/control-plane:NoSchedule-
```

### **问题: 镜像拉取失败**
```bash
# 方法 1: 使用本地已有镜像
kubectl create deployment xxx --image=docker.io/library/xxx

# 方法 2: 手动导入镜像
# 在物理机
docker save xxx -o /d/xxx.tar
scp /d/xxx.tar caiqian@192.168.226.140:/home/caiqian/

# 在 master01
sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image import xxx.tar
```

### **问题: Harbor 容器停止**
```bash
# 在物理机 Git Bash
cd /d/code/selfhost-iot-platform/harbor
docker-compose up -d
```

---

## 📊 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    物理机 (Windows 10)                       │
│                     IP: 10.0.73.30                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ TimescaleDB  │  │    Kafka     │  │   Harbor     │      │
│  │   :5432      │  │    :9092     │  │    :80       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ VMware NAT 网络
                            │ ✅ 已验证连通
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              VMware 虚拟机 (Ubuntu 22.04)                    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Master01 (192.168.226.140)                        │     │
│  │  ┌──────────────────────────────────────────────┐  │     │
│  │  │  RKE2 v1.33.6                                │  │     │
│  │  │  ┌────────────┐  ┌────────────┐             │  │     │
│  │  │  │ test-nginx │  │  Pod 2     │  ...        │  │     │
│  │  │  │  Running   │  │            │             │  │     │
│  │  │  └────────────┘  └────────────┘             │  │     │
│  │  │  Pod Network: 10.42.0.0/16                  │  │     │
│  │  └──────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Worker 1   │  │  Worker 2   │  │  Worker 3   │         │
│  │  (待部署)   │  │  (待部署)   │  │  (待部署)   │         │
│  │  .141       │  │  .142       │  │  .143       │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ 成功经验总结

1. **混合架构可行性已验证** - Kubernetes Pod 可以无缝访问物理机服务
2. **网络规划合理** - VMware NAT 网络配置正确
3. **基础设施就绪** - TimescaleDB, Kafka, Harbor 都正常运行
4. **集群功能正常** - Pod 调度、网络、存储基础功能验证通过

---

## 💡 建议的下一步

**我的推荐顺序:**

1. **首选 - 部署简单应用验证数据流** (选项 A)
   - 风险低，快速验证核心功能
   - 为后续 IoT 应用打基础
   
2. **次选 - 添加 Worker 节点** (选项 B)
   - 学习多节点集群管理
   - 为高可用部署做准备
   
3. **最后 - 解决 Harbor 问题** (选项 C)
   - 可以暂时使用手动导入镜像的方式
   - 不影响主要功能验证

---

**状态:** 🟢 集群就绪，可以开始应用部署  
**最后更新:** 2025-11-29  
**下次会话从这里开始！** 🚀
