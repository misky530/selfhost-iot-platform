#!/bin/bash

# WordPress on Kubernetes - 版本1.0 部署脚本
# 此脚本会按顺序部署所有资源

set -e  # 遇到错误立即退出

echo "=========================================="
echo "WordPress on Kubernetes - 版本1.0 部署"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查kubectl命令
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: kubectl命令未找到，请先安装kubectl${NC}"
    exit 1
fi

# 检查集群连接
echo -e "${YELLOW}检查Kubernetes集群连接...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}错误: 无法连接到Kubernetes集群${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 集群连接正常${NC}"
echo ""

# 步骤1: 创建Namespace
echo -e "${YELLOW}步骤1: 创建Namespace...${NC}"
kubectl apply -f 00-namespace.yaml
echo -e "${GREEN}✓ Namespace创建完成${NC}"
echo ""

# 步骤2: 创建Secret
echo -e "${YELLOW}步骤2: 创建MySQL Secret...${NC}"
kubectl apply -f 01-mysql-secret.yaml
echo -e "${GREEN}✓ Secret创建完成${NC}"
echo ""

# 步骤3: 创建MySQL PVC
echo -e "${YELLOW}步骤3: 创建MySQL PVC...${NC}"
kubectl apply -f 02-mysql-pvc.yaml
echo -e "${GREEN}✓ MySQL PVC创建完成${NC}"
echo ""

# 步骤4: 部署MySQL
echo -e "${YELLOW}步骤4: 部署MySQL...${NC}"
kubectl apply -f 03-mysql-deployment.yaml
kubectl apply -f 04-mysql-service.yaml
echo -e "${GREEN}✓ MySQL部署完成${NC}"
echo ""

# 等待MySQL就绪
echo -e "${YELLOW}等待MySQL Pod启动...${NC}"
kubectl wait --for=condition=ready pod -l app=mysql -n wordpress --timeout=180s
echo -e "${GREEN}✓ MySQL已就绪${NC}"
echo ""

# 步骤5: 创建WordPress PVC
echo -e "${YELLOW}步骤5: 创建WordPress PVC...${NC}"
kubectl apply -f 05-wordpress-pvc.yaml
echo -e "${GREEN}✓ WordPress PVC创建完成${NC}"
echo ""

# 步骤6: 部署WordPress
echo -e "${YELLOW}步骤6: 部署WordPress...${NC}"
kubectl apply -f 06-wordpress-deployment.yaml
kubectl apply -f 07-wordpress-service.yaml
echo -e "${GREEN}✓ WordPress部署完成${NC}"
echo ""

# 等待WordPress就绪
echo -e "${YELLOW}等待WordPress Pod启动...${NC}"
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=180s
echo -e "${GREEN}✓ WordPress已就绪${NC}"
echo ""

# 显示部署状态
echo "=========================================="
echo -e "${GREEN}部署完成！${NC}"
echo "=========================================="
echo ""

echo "查看所有资源:"
kubectl get all -n wordpress
echo ""

echo "查看PVC状态:"
kubectl get pvc -n wordpress
echo ""

# 获取访问信息
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl get svc wordpress -n wordpress -o jsonpath='{.spec.ports[0].nodePort}')

echo "=========================================="
echo -e "${GREEN}访问WordPress:${NC}"
echo "=========================================="
echo ""
echo "通过NodePort访问:"
echo -e "${GREEN}http://${NODE_IP}:${NODE_PORT}${NC}"
echo ""
echo "或使用任意节点IP:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,IP:.status.addresses[0].address --no-headers | while read name ip; do
    echo -e "  ${GREEN}http://${ip}:${NODE_PORT}${NC}"
done
echo ""

echo "首次访问会进入WordPress安装向导"
echo "建议使用的安装信息:"
echo "  - 站点标题: My K8s Blog"
echo "  - 用户名: admin"
echo "  - 密码: 设置一个强密码"
echo "  - 邮箱: 你的邮箱"
echo ""

echo "=========================================="
echo "常用管理命令:"
echo "=========================================="
echo "查看Pod日志:"
echo "  kubectl logs -f deployment/mysql -n wordpress"
echo "  kubectl logs -f deployment/wordpress -n wordpress"
echo ""
echo "查看Pod详情:"
echo "  kubectl describe pod -l app=mysql -n wordpress"
echo "  kubectl describe pod -l app=wordpress -n wordpress"
echo ""
echo "进入容器:"
echo "  kubectl exec -it deployment/mysql -n wordpress -- bash"
echo "  kubectl exec -it deployment/wordpress -n wordpress -- bash"
echo ""
echo "查看事件:"
echo "  kubectl get events -n wordpress --sort-by='.lastTimestamp'"
echo ""
echo "删除所有资源:"
echo "  kubectl delete namespace wordpress"
echo "=========================================="
