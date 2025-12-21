# 1 ubuntu设置静态Ip
```shell
uname -a
Linux ubuntu-server 6.8.0-88-generic #89-Ubuntu SMP PREEMPT_DYNAMIC Sat Oct 11 01:02:46 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux


sudo nano /etc/netplan/50-cloud-init.yaml
# 原始
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true

# 设置ip
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: false
      addresses:
        - 192.168.226.133/24   
      routes:
        - to: default
          via: 192.168.226.2   # 这是根据你 'ip r' 第一行识别出的正确网关
      nameservers:
        addresses: [114.114.114.114, 8.8.8.8]
        
 # 再应用
 sudo netplan apply
```

