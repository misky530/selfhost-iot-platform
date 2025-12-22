#!/bin/bash

# WordPress on Kubernetes - 版本1.0 验证脚本
# 此脚本会验证所有资源是否正常运行

set -e

echo "=========================================="
echo "WordPress on Kubernetes - 健康检查"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查Namespace
echo -e "${YELLOW}检查 Namespace...${NC}"
if kubectl get namespace wordpress &> /dev/null; then
    echo -e "${GREEN}✓ Namespace 'wordpress' 存在${NC}"
else
    echo -e "${RED}✗ Namespace 'wordpress' 不存在${NC}"
    exit 1
fi
echo ""

# 检查Secret
echo -e "${YELLOW}检查 Secret...${NC}"
if kubectl get secret mysql-secret -n wordpress &> /dev/null; then
    echo -e "${GREEN}✓ Secret 'mysql-secret' 存在${NC}"
else
    echo -e "${RED}✗ Secret 'mysql-secret' 不存在${NC}"
    exit 1
fi
echo ""

# 检查PVC
echo -e "${YELLOW}检查 PersistentVolumeClaims...${NC}"
kubectl get pvc -n wordpress
PVC_STATUS=$(kubectl get pvc -n wordpress -o jsonpath='{.items[*].status.phase}')
if [[ $PVC_STATUS == *"Pending"* ]]; then
    echo -e "${YELLOW}⚠ 有PVC处于Pending状态（等待Pod使用）${NC}"
elif [[ $PVC_STATUS == *"Bound"* ]]; then
    echo -e "${GREEN}✓ 所有PVC已绑定${NC}"
fi
echo ""

# 检查MySQL Deployment
echo -e "${YELLOW}检查 MySQL Deployment...${NC}"
MYSQL_READY=$(kubectl get deployment mysql -n wordpress -o jsonpath='{.status.readyReplicas}')
MYSQL_DESIRED=$(kubectl get deployment mysql -n wordpress -o jsonpath='{.spec.replicas}')
if [ "$MYSQL_READY" == "$MYSQL_DESIRED" ]; then
    echo -e "${GREEN}✓ MySQL Deployment 正常 ($MYSQL_READY/$MYSQL_DESIRED)${NC}"
else
    echo -e "${RED}✗ MySQL Deployment 异常 ($MYSQL_READY/$MYSQL_DESIRED)${NC}"
    kubectl get pods -l app=mysql -n wordpress
    exit 1
fi
echo ""

# 检查WordPress Deployment
echo -e "${YELLOW}检查 WordPress Deployment...${NC}"
WP_READY=$(kubectl get deployment wordpress -n wordpress -o jsonpath='{.status.readyReplicas}')
WP_DESIRED=$(kubectl get deployment wordpress -n wordpress -o jsonpath='{.spec.replicas}')
if [ "$WP_READY" == "$WP_DESIRED" ]; then
    echo -e "${GREEN}✓ WordPress Deployment 正常 ($WP_READY/$WP_DESIRED)${NC}"
else
    echo -e "${RED}✗ WordPress Deployment 异常 ($WP_READY/$WP_DESIRED)${NC}"
    kubectl get pods -l app=wordpress -n wordpress
    exit 1
fi
echo ""

# 检查Services
echo -e "${YELLOW}检查 Services...${NC}"
kubectl get svc -n wordpress
echo -e "${GREEN}✓ Services已创建${NC}"
echo ""

# 检查Pod状态
echo -e "${YELLOW}检查 Pod详细状态...${NC}"
kubectl get pods -n wordpress -o wide
echo ""

# 测试MySQL连接
echo -e "${YELLOW}测试 MySQL 连接...${NC}"
MYSQL_POD=$(kubectl get pod -l app=mysql -n wordpress -o jsonpath='{.items[0].metadata.name}')
if kubectl exec $MYSQL_POD -n wordpress -- mysql -u root -pMyWordPress123! -e "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}✓ MySQL 连接正常${NC}"
else
    echo -e "${RED}✗ MySQL 连接失败${NC}"
fi
echo ""

# 测试WordPress HTTP
echo -e "${YELLOW}测试 WordPress HTTP响应...${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl get svc wordpress -n wordpress -o jsonpath='{.spec.ports[0].nodePort}')

if curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP:$NODE_PORT | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ WordPress HTTP响应正常${NC}"
    echo -e "${GREEN}访问地址: http://$NODE_IP:$NODE_PORT${NC}"
else
    echo -e "${YELLOW}⚠ WordPress可能还在启动中，请稍后再试${NC}"
fi
echo ""

# 显示最近事件
echo -e "${YELLOW}最近的事件:${NC}"
kubectl get events -n wordpress --sort-by='.lastTimestamp' | tail -10
echo ""

echo "=========================================="
echo -e "${GREEN}健康检查完成！${NC}"
echo "=========================================="
