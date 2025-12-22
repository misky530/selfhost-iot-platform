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

# 解决代理问题
提前解决方案：先拉取所有需要的镜像
第一步：查看需要哪些镜像
bash# 下载部署文件查看
wget -O /tmp/ingress-deploy.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

# 查看需要的镜像
grep "image:" /tmp/ingress-deploy.yaml | grep -v "#" | sort -u
```

应该会看到类似：
```
registry.k8s.io/ingress-nginx/controller:v1.8.1
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407

## 第二步：在所有节点上提前拉取镜像， 手动设置代理环境变量
```shell
# 临时设置代理环境变量后拉取
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 ctr -n k8s.io image pull registry.k8s.io/ingress-nginx/controller:v1.8.1


# 拉取第二个镜像
sudo HTTP_PROXY=http://10.0.73.30:7897 HTTPS_PROXY=http://10.0.73.30:7897 ctr -n k8s.io image pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407
```

验证master节点的镜像
```shell
sudo ctr -n k8s.io image ls | grep ingress
```

应该能看到两个镜像。