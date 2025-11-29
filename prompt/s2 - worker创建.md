# 📋 RKE2 部署总结（新会话参考）

## ✅ 已完成内容

### 1. 环境信息
- **物理机**: Windows 10, IP: 10.0.73.30
- **虚拟机**: Ubuntu Server 22.04, VMware NAT
- **Master 节点**: master01, IP: 192.168.226.140, 用户/密码: caiqian/caiqian
- **Worker 节点**: worker1-3 (192.168.226.141-143) - 待部署

### 2. 基础服务（物理机 Docker）
- TimescaleDB: 10.0.73.30:5432
- Kafka: 10.0.73.30:9092
- Harbor: http://10.0.73.30

### 3. RKE2 集群状态
- **版本**: v1.33.6+rke2r1 (Kubernetes v1.33.6)
- **安装方式**: 离线安装
- **Master 状态**: ✅ Ready
- **Token**: 已保存在 `~/rke2-token.txt`
- **网络**: Pod CIDR: 10.42.0.0/16, Service CIDR: 10.43.0.0/16
- **CNI**: Canal (Calico + Flannel)

### 4. 配置文件位置
**物理机**：
```
D:\code\selfhost-iot-platform\kubernetes\
├── rke2\
│   ├── offline-packages\     # v1.33.6 离线包
│   ├── master\config\config.yaml
│   └── scripts\install-master.sh
```

**Master 节点**：
```
/home/caiqian/rke2/
/etc/rancher/rke2/config.yaml
~/.kube/config (kubectl 已配置)
```

### 5. 关键经验教训
1. ❌ **版本必须匹配**: 离线包和二进制版本要一致
2. ❌ **磁盘空间**: 需要至少 2GB 可用（已扩展到 18GB）
3. ✅ **配置简化**: 移除了 `node-label`（K8s 1.30+ 不支持）
4. ✅ **污点处理**: 单节点需要移除 `NoSchedule` 污点

## 🎯 下一步选项

**A. 添加 Worker 节点**
- 需要 master01 的 token: `cat ~/rke2-token.txt`
- 配置文件在: `rke2/worker/config/`

**B. 测试部署应用**
- 注意：需要配置镜像仓库或手动导入镜像
- Docker Hub 无法直接访问

**C. 配置持久化存储**
- 连接物理机的 TimescaleDB/Kafka

## 📌 快速恢复命令
```bash
# SSH 到 master01
ssh caiqian@192.168.226.140

# 查看集群状态
kubectl get nodes
kubectl get pods -A

# 查看 token
cat ~/rke2-token.txt
```

---
**状态**: Master 节点完全就绪，可以开始部署 Worker 或应用 🎉
