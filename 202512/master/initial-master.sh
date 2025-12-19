#!/bin/bash

# 1. 设置主机名
echo ">>> 设置主机名为 k8s-master"
sudo hostnamectl set-hostname k8s-master

# 2. 备份并替换为阿里云 Apt 源 (加速安装)
echo ">>> 配置阿里云 Apt 源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat <<EOF | sudo tee /etc/apt/sources.list
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

# 3. 更新并安装 KubeKey 所需依赖
echo ">>> 安装基础依赖 (conntrack, socat, curl)..."
sudo apt-get update
sudo apt-get install -y socat conntrack ebtables ipset curl openssh-server git

# 4. 关闭 Swap (K8s 必须)
echo ">>> 关闭 Swap..."
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# 5. 关闭防火墙
echo ">>> 关闭 UFW 防火墙..."
sudo ufw disable

# 6. 配置内核参数 (允许 iptables 检查桥接流量)
echo ">>> 配置内核参数..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 7. 配置时区
echo ">>> 设置时区为 Asia/Shanghai..."
sudo timedatectl set-timezone Asia/Shanghai

echo ">>> Master 初始化完成! 请重启一次以确保所有配置生效: sudo reboot"