#!/bin/bash
# RKE2 Master 节点安装脚本
set -e

echo "=== RKE2 Master 安装开始 ==="

# 1. 创建配置目录
echo "[1/6] 创建配置目录..."
sudo mkdir -p /etc/rancher/rke2

# 2. 复制配置文件
echo "[2/6] 复制配置文件..."
sudo cp ../master/config/config.yaml /etc/rancher/rke2/

# 3. 创建离线安装目录
echo "[3/6] 准备离线包..."
sudo mkdir -p /var/lib/rancher/rke2/agent/images/

# 4. 复制镜像包
echo "[4/6] 复制镜像文件..."
sudo cp ../offline-packages/rke2-images.linux-amd64.tar.zst \
    /var/lib/rancher/rke2/agent/images/

# 5. 安装 RKE2
echo "[5/6] 安装 RKE2..."
cd ../offline-packages
sudo tar -xzf rke2.linux-amd64.tar.gz -C /usr/local
cd -

# 6. 启动服务
echo "[6/6] 启动 RKE2 Server..."
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

echo ""
echo "✅ 安装完成！等待服务启动..."
echo ""
echo "查看日志: sudo journalctl -u rke2-server -f"
echo "查看 token: sudo cat /var/lib/rancher/rke2/server/token"
