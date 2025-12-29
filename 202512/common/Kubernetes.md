# label
```shell
# ❌ 错误（你之前的命令）：添加新标签不影响匹配
kubectl label pods -n wordpress-v2 -l app=wordpress temp=notready --overwrite

# ✅ 正确：移除 Service 匹配的标签
kubectl label pods -n wordpress-v2 -l app=wordpress app-

# 验证 Endpoints（应该为空）
kubectl get endpoints -n wordpress-v2 wordpress

# 恢复标签
kubectl label pods -n wordpress-v2 -l app=wordpress app=wordpress --overwrite

# 查看标签
kubectl get pods -n wordpress-v2 -l app=wordpress --show-labels
```