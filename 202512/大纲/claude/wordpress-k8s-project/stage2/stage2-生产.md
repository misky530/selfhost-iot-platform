你好 Anthony！欢迎继续 WordPress on Kubernetes 学习项目！

看到你版本 1.0 已经成功运行，现在让我们系统地进入**版本 2.0 - 生产就绪版**的学习。

## 📋 版本 2.0 学习规划

### **核心改进目标**
1. **高可用性** - WordPress 多副本 + MySQL 主从（简化版先用单实例）
2. **健康检查** - Liveness & Readiness Probes
3. **Ingress 域名访问** - 替代 NodePort
4. **资源管理** - requests/limits
5. **自动扩缩容** - HPA（Horizontal Pod Autoscaler）

---

## 🎯 第一步：准备工作（镜像预拉取）

版本 2.0 会用到新的镜像，让我们先拉取：

```bash
# 1. WordPress 镜像（与 v1.0 相同，确认已有）
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 \
  ctr -n k8s.io image pull docker.io/library/wordpress:6.2-apache

# 2. MySQL 镜像（与 v1.0 相同，确认已有）
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 \
  ctr -n k8s.io image pull docker.io/library/mysql:8.0

# 3. Metrics Server 镜像（用于 HPA）
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 \
  ctr -n k8s.io image pull registry.k8s.io/metrics-server/metrics-server:v0.6.3

# 在所有节点上执行（master, node1, node2）
```

---

## 📝 学习路径（小步前进）

我建议分 **5 个阶段** 完成版本 2.0：

### **阶段 1：健康检查（今天先做这个）**
- 为 WordPress 添加 Liveness 和 Readiness Probes
- 验证 Pod 自动重启和流量控制
- **学习收获**：理解健康检查机制

### **阶段 2：资源管理**
- 配置 CPU/Memory requests 和 limits
- 观察资源调度行为
- **学习收获**：资源配额和 QoS

### **阶段 3：Ingress 域名访问**
- 配置 Ingress 规则
- 本地 hosts 模拟域名
- **学习收获**：七层负载均衡

### **阶段 4：WordPress 多副本**
- 扩展到 3 副本
- 处理会话持久化（暂时接受限制）
- **学习收获**：无状态应用扩容

### **阶段 5：HPA 自动扩缩容**
- 安装 Metrics Server
- 配置基于 CPU 的自动扩缩容
- 压测验证
- **学习收获**：弹性伸缩

---

## 🚀 开始阶段 1：健康检查

### **理论说明**

**Liveness Probe（存活探针）**：
- 检查容器是否"活着"
- 失败 → Kubelet 重启容器
- 用途：检测死锁、无响应状态

**Readiness Probe（就绪探针）**：
- 检查容器是否"准备好接收流量"
- 失败 → Service 不转发流量到该 Pod
- 用途：启动慢、临时不可用场景

**检查方式**：
- **HTTP GET**：最常用，检查 HTTP 端点
- **TCP Socket**：检查端口是否开放
- **Exec**：执行命令判断

---

### **WordPress 配置文件**

创建 `v2.0-wordpress-with-probes.yaml`：

```yaml
# ==================================================
# WordPress v2.0 - 添加健康检查
# 学习目标：理解 Liveness 和 Readiness Probes
# ==================================================
apiVersion: v1
kind: Namespace
metadata:
  name: wordpress-v2
  labels:
    version: "2.0"
---
# MySQL Secret（与 v1.0 相同）
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: wordpress-v2
type: Opaque
data:
  # root 密码: MyR00tP@ss (Base64)
  mysql-root-password: TXlSMDB0UEBzcw==
  # WordPress 数据库密码: WPP@ssw0rd (Base64)
  mysql-password: V1BQQHNzdzByZA==
---
# MySQL PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: wordpress-v2
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
---
# MySQL Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: wordpress-v2
spec:
  replicas: 1  # v2.0 暂时单实例
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        - name: MYSQL_DATABASE
          value: wordpress
        - name: MYSQL_USER
          value: wpuser
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        # ===== 新增：MySQL 健康检查 =====
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 30  # 启动后 30 秒开始检查
          periodSeconds: 10        # 每 10 秒检查一次
          timeoutSeconds: 5        # 5 秒超时
          failureThreshold: 3      # 连续失败 3 次才重启
        readinessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 10  # 启动后 10 秒开始检查
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
---
# MySQL Service
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: wordpress-v2
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  clusterIP: None  # Headless Service
---
# WordPress PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
  namespace: wordpress-v2
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
---
# WordPress Deployment（重点：健康检查）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress-v2
spec:
  replicas: 1  # 阶段 1 先用单副本
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.2-apache
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql:3306
        - name: WORDPRESS_DB_USER
          value: wpuser
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        - name: WORDPRESS_DB_NAME
          value: wordpress
        ports:
        - containerPort: 80
          name: http
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
        # ===== 新增：WordPress 健康检查 =====
        livenessProbe:
          httpGet:
            path: /wp-admin/install.php  # 检查 WordPress 安装页面
            port: 80
            httpHeaders:
            - name: Host
              value: localhost
          initialDelaySeconds: 60   # WordPress 启动较慢，60 秒后检查
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /wp-login.php      # 检查登录页面（更轻量）
            port: 80
            httpHeaders:
            - name: Host
              value: localhost
          initialDelaySeconds: 30   # 30 秒后检查就绪
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1       # 成功 1 次即标记就绪
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
# WordPress Service（NodePort 保持，后续阶段改 ClusterIP）
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wordpress-v2
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081  # 与 v1.0 区分，使用 30081
```

---

## 🧪 部署和验证

### **1. 部署版本 2.0**

```bash
# 应用配置
kubectl apply -f v2.0-wordpress-with-probes.yaml

# 观察 Pod 启动过程（重点看 READY 状态变化）
watch -n 2 'kubectl get pods -n wordpress-v2 -o wide'
```

**预期输出**：
```
NAME                        READY   STATUS    RESTARTS   AGE
mysql-xxxxx                 0/1     Running   0          10s   # 初期 Not Ready
mysql-xxxxx                 1/1     Running   0          45s   # Readiness 通过
wordpress-xxxxx             0/1     Running   0          10s   # 初期 Not Ready
wordpress-xxxxx             1/1     Running   0          95s   # Readiness 通过（较慢）
```

### **2. 检查健康检查配置**

```bash
# 查看 WordPress Pod 的详细探针配置
kubectl describe pod -n wordpress-v2 -l app=wordpress | grep -A 10 "Liveness\|Readiness"
```

### **3. 访问测试**

```bash
# 获取 NodePort
kubectl get svc -n wordpress-v2 wordpress

# 浏览器访问
http://192.168.226.131:30081
```

---

## 🔬 验证健康检查机制

### **实验 1：模拟 Liveness 失败（容器会重启）**

```bash
# 进入 WordPress 容器
kubectl exec -it -n wordpress-v2 deploy/wordpress -- bash

# 删除 Apache 进程（模拟服务崩溃）
pkill apache2

# 退出容器
exit

# 观察 Pod 状态（应该会看到 RESTARTS 计数增加）
kubectl get pods -n wordpress-v2 -w
```

**预期行为**：
- Liveness Probe 连续失败 3 次（约 30 秒）
- Kubelet 自动重启容器
- RESTARTS 列数值 +1

### **实验 2：观察 Readiness 控制流量**

```bash
# 查看 Endpoints（就绪的 Pod IP）
kubectl get endpoints -n wordpress-v2 wordpress

# 手动标记 Pod 为 Not Ready（修改标签触发）
# 实际生产中是探针失败，这里用标签模拟
kubectl label pods -n wordpress-v2 -l app=wordpress temp=notready --overwrite

# 再次查看 Endpoints（IP 应该消失）
kubectl get endpoints -n wordpress-v2 wordpress

# 恢复
kubectl label pods -n wordpress-v2 -l app=wordpress temp-
```

---

## 📊 学习总结（阶段 1）

### **你已经掌握**：
1. ✅ **Liveness Probe**：保护容器僵死状态，自动重启
2. ✅ **Readiness Probe**：控制流量路由，防止请求到未就绪 Pod
3. ✅ **探针参数**：
    - `initialDelaySeconds`：首次检查延迟
    - `periodSeconds`：检查间隔
    - `failureThreshold`：失败阈值

### **配置建议**：
- **Web 应用**：用 `httpGet` 检查关键路径
- **数据库**：用 `exec` 执行健康检查命令
- **initialDelaySeconds**：根据应用启动时间调整（WordPress 60s，MySQL 30s）

---

## 🎯 下一步

完成阶段 1 验证后，告诉我结果，我们继续：
- **阶段 2**：资源管理（requests/limits）
- 还是先暂停，你想深入实验健康检查？

---

## 💡 Anthony 的学习风格匹配

✅ **小步前进**：先做健康检查，验证后再继续  
✅ **完整项目**：基于 v1.0 迭代升级  
✅ **提前解决**：镜像已提前拉取  
✅ **详细注释**：YAML 每个探针参数都有说明

准备好开始了吗？先执行部署和验证步骤，遇到任何问题随时告诉我！ 🚀