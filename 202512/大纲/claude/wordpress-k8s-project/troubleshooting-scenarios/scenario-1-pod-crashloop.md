# 故障场景1：Pod CrashLoopBackOff

## 场景描述

WordPress Pod无法启动，一直处于CrashLoopBackOff状态。

## 模拟故障

```bash
# 方法：故意提供错误的MySQL连接信息

# 1. 创建错误的Secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: wordpress
type: Opaque
stringData:
  mysql-root-password: wrong-password
  mysql-password: wrong-password
  mysql-database: wordpress
  mysql-user: wordpress
EOF

# 2. 重启WordPress Pod
kubectl delete pod -l app=wordpress -n wordpress

# 3. 观察Pod状态
kubectl get pods -n wordpress -w
```

## 故障现象

```bash
$ kubectl get pods -n wordpress
NAME                         READY   STATUS             RESTARTS   AGE
mysql-xxx-xxx                1/1     Running            0          5m
wordpress-xxx-xxx            0/1     CrashLoopBackOff   5          3m
```

## 排查步骤

### 步骤1：查看Pod状态

```bash
kubectl get pods -n wordpress
kubectl describe pod -l app=wordpress -n wordpress
```

**关键信息**:
- State: Waiting
- Reason: CrashLoopBackOff
- Last State: Terminated (Exit Code: 1)

### 步骤2：查看Pod日志

```bash
kubectl logs -l app=wordpress -n wordpress
kubectl logs -l app=wordpress -n wordpress --previous
```

**可能看到的错误**:
```
Warning: mysqli::__construct(): (HY000/1045): Access denied for user 'wordpress'@'xxx' (using password: YES)
WordPress database error: Access denied for user 'wordpress'@'xxx' (using password: YES)
```

### 步骤3：检查配置

```bash
# 查看WordPress使用的环境变量
kubectl exec deployment/wordpress -n wordpress -- env | grep WORDPRESS

# 进入容器检查（如果容器还在运行）
kubectl exec -it deployment/wordpress -n wordpress -- bash
```

### 步骤4：验证MySQL连接

```bash
# 在MySQL容器中验证用户
kubectl exec -it deployment/mysql -n wordpress -- mysql -u root -pMyWordPress123!

# 在MySQL中执行
SHOW DATABASES;
SELECT user,host FROM mysql.user;

# 尝试用wordpress用户连接
kubectl exec -it deployment/mysql -n wordpress -- mysql -u wordpress -pwrong-password
```

### 步骤5：检查Secret

```bash
# 查看Secret内容
kubectl get secret mysql-secret -n wordpress -o yaml

# 解码查看密码
kubectl get secret mysql-secret -n wordpress -o jsonpath='{.data.mysql-password}' | base64 -d
```

## 解决方案

### 方案1：修复Secret

```bash
# 恢复正确的Secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: wordpress
type: Opaque
stringData:
  mysql-root-password: MyWordPress123!
  mysql-password: MyWordPress123!
  mysql-database: wordpress
  mysql-user: wordpress
EOF

# 重启WordPress Pod使新Secret生效
kubectl delete pod -l app=wordpress -n wordpress

# 等待Pod恢复
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=120s
```

### 方案2：重新创建WordPress部署

```bash
# 删除Deployment
kubectl delete deployment wordpress -n wordpress

# 重新创建（使用正确的Secret）
kubectl apply -f 06-wordpress-deployment.yaml

# 验证
kubectl get pods -n wordpress
```

## 学习要点

### CrashLoopBackOff是什么？

- Pod启动后立即退出
- Kubernetes尝试重启
- 重启间隔逐渐增加（10s, 20s, 40s...最多5分钟）
- 陷入"启动-崩溃-重启"循环

### 常见原因

1. **配置错误**（本场景）
   - 数据库连接信息错误
   - 环境变量错误
   - 配置文件格式错误

2. **应用代码错误**
   - 启动脚本错误
   - 必要的依赖缺失
   - 端口冲突

3. **资源不足**
   - OOM（内存不足）
   - 磁盘空间不足

4. **权限问题**
   - 文件权限不足
   - SecurityContext限制

### 排查工具

```bash
# 查看Pod事件
kubectl describe pod <pod> -n wordpress

# 查看日志（当前容器）
kubectl logs <pod> -n wordpress

# 查看日志（上一个容器）
kubectl logs <pod> -n wordpress --previous

# 查看日志（持续输出）
kubectl logs -f <pod> -n wordpress

# 进入容器（如果还在运行）
kubectl exec -it <pod> -n wordpress -- bash

# 查看Deployment事件
kubectl describe deployment wordpress -n wordpress
```

## 预防措施

1. **使用健康检查**（版本2.0会学习）
   - Liveness Probe：检测容器是否存活
   - Readiness Probe：检测容器是否就绪
   - Startup Probe：处理慢启动应用

2. **配置验证**
   - 部署前验证Secret内容
   - 使用ConfigMap验证器
   - CI/CD中加入配置检查

3. **监控告警**
   - 监控Pod重启次数
   - 告警异常状态Pod
   - 日志聚合分析

4. **优雅错误处理**
   - 应用层重试机制
   - 明确的错误日志
   - 健康检查端点

## 扩展阅读

- [Pod生命周期](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [应用自检](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
