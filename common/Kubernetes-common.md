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