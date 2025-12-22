# Ingress Controller 安装指南

## 为什么需要Ingress Controller？

在Kubernetes中，Service只能提供四层（TCP/UDP）负载均衡，而Ingress Controller提供七层（HTTP/HTTPS）路由功能：
- 基于域名的路由
- 基于路径的路由
- SSL/TLS终止
- 负载均衡

## 选择：Nginx Ingress Controller

我们使用官方的Nginx Ingress Controller，它是最流行和稳定的选择。

## 安装步骤

### 方式一：使用官方YAML（推荐用于学习）

```bash
# 1. 下载部署清单
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

# 2. 等待Ingress Controller启动
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 3. 验证安装
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 方式二：使用KubeKey内置（如果支持）

如果你的KubeKey配置中已包含Ingress组件，可以查看：

```bash
# 查看是否已有ingress相关资源
kubectl get all -n ingress-nginx
```

## 验证安装成功

### 1. 检查Pod状态

```bash
kubectl get pods -n ingress-nginx
```

应该看到类似输出：
```
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

### 2. 检查Service

```bash
kubectl get svc -n ingress-nginx
```

应该看到：
```
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
ingress-nginx-controller             NodePort    10.233.x.x      <none>        80:30080/TCP,443:30443/TCP
ingress-nginx-controller-admission   ClusterIP   10.233.x.x      <none>        443/TCP
```

注意：NodePort类型的Service会映射到每个节点的30080（HTTP）和30443（HTTPS）端口。

### 3. 测试访问

```bash
# 通过NodePort访问（使用任意节点IP）
curl http://192.168.226.131:30080
curl http://192.168.226.132:30080
curl http://192.168.226.133:30080
```

应该返回404（这是正常的，因为还没有配置Ingress规则）：
```
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<center>nginx</center>
</body>
</html>
```

## 配置hosts文件（本地测试）

由于我们没有真实域名，需要在本地配置hosts文件来模拟域名解析。

### Linux/Mac

```bash
# 编辑hosts文件
sudo vim /etc/hosts

# 添加以下行（使用你的任意节点IP）
192.168.226.131 wordpress.local
192.168.226.131 blog.local
```

### Windows

```
# 编辑文件: C:\Windows\System32\drivers\etc\hosts
# 添加：
192.168.226.131 wordpress.local
192.168.226.131 blog.local
```

## IngressClass配置

查看可用的IngressClass：

```bash
kubectl get ingressclass
```

应该看到：
```
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       1m
```

## 常见问题

### Q1: Pod一直处于Pending状态？

**原因**: 可能是master节点有污点，不允许调度普通Pod。

**解决**:
```bash
# 查看节点污点
kubectl describe node k8s-master | grep Taints

# 如果看到NoSchedule污点，可以临时允许调度到master（仅学习环境）
kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule-
```

### Q2: 镜像拉取失败？

**原因**: 网络问题或需要科学上网。

**解决**:
```bash
# 方式1: 使用国内镜像（如果有）
# 修改deploy.yaml中的镜像地址

# 方式2: 提前下载镜像
# 在每个节点上执行
ctr -n k8s.io image pull registry.k8s.io/ingress-nginx/controller:v1.8.1
```

### Q3: Service没有分配NodePort？

**原因**: 配置问题。

**解决**: 确认Service类型为NodePort，端口范围在30000-32767之间。

## 卸载（如果需要重新安装）

```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
```

## 下一步

安装完成后，继续版本1.0的部署：
```bash
cd version-1.0-basic
cat README.md
```

## 参考资料

- [Nginx Ingress Controller官方文档](https://kubernetes.github.io/ingress-nginx/)
- [Bare-metal集群部署指南](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)
