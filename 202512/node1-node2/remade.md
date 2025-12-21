恭喜，`kk` 工具已经准备就绪！

在正式开始安装 K8s 集群之前，我们需要完成**至关重要的一步**：**准备好另外两台节点（Node1 和 Node2），并生成集群配置文件。**

因为 KubeKey 是通过 SSH 同时连接 3 台机器进行安装的，所以我们不能只在 Master 上操作，必须让 3 台机器都“在线”。

请按照以下步骤操作：

### 第一步：克隆并配置 Node1 和 Node2

为了节省时间，不要重新安装系统，直接利用 VMware 的**克隆**功能。

1.  **关闭 Master 虚拟机** (`sudo poweroff`)。
2.  **克隆 Node1 (16G 内存)**:
    *   右键 Master -> 管理 -> 克隆 -> **“创建完整克隆”**。
    *   命名为 `k8s-node1`，调整内存为 **16GB**。
3.  **克隆 Node2 (8G 内存)**:
    *   同上，命名为 `k8s-node2`，内存 **8GB**。
4.  **修改身份信息 (非常重要，否则集群网络会冲突)**:
    启动 Node1 和 Node2，分别执行以下操作：

    **针对 Node1:**
    ```bash
    # 1. 修改主机名
    sudo hostnamectl set-hostname k8s-node1

    # 2. 修改 IP (假设用 132)
    sudo nano /etc/netplan/00-installer-config.yaml
    # 将 addresses: [192.168.226.131/24] 改为 132
    sudo netplan apply

    # 3. 重置 Machine-ID (这是 Ubuntu 克隆的大坑，不重置会导致 IP 分配冲突)
    sudo rm /etc/machine-id
    sudo systemd-machine-id-setup
    sudo reboot
    ```

    **针对 Node2:**
    *   主机名设为 `k8s-node2`。
    *   IP 设为 `192.168.226.133` (假设)。
    *   同样执行重置 Machine-ID 并重启。

5.  **验证互通**:
    启动所有 3 台机器。在 **Master** 上 Ping 另外两台：
    ```bash
    ping 192.168.226.132
    ping 192.168.226.133
    ```
    *如果都能通，就可以进入下一步。*

---

### 第二步：生成并编辑配置文件

回到 **Master** 节点，我们将生成安装配置。由于你担心下载慢，我们会配置国内源。

1.  **生成默认配置**:
    ```bash
    export KKZONE=cn
    ./kk create config --with-kubesphere v3.4.1 --with-kubernetes v1.26.5
    ```
    *注：这里选 K8s v1.26.5 是因为它是目前最稳定且支持 KubeSphere 3.4 的版本。*

2.  **编辑 `config-sample.yaml`**:
    这是最关键的一步。请使用 `vim config-sample.yaml`，并参照下表修改。
    *假设你的 3 台机器密码都是 `123456`（如果是其他密码请自行替换）。*

    **你需要修改/确认的重点区域：**

    ```yaml
    apiVersion: kubekey.kubesphere.io/v1alpha2
    kind: Cluster
    metadata:
      name: sample-cluster
    spec:
      hosts:
      - {name: k8s-master, address: 192.168.226.131, internalAddress: 192.168.226.131, user: root, password: "你的密码"}
      - {name: k8s-node1,  address: 192.168.226.132, internalAddress: 192.168.226.132, user: root, password: "你的密码"}
      - {name: k8s-node2,  address: 192.168.226.133, internalAddress: 192.168.226.133, user: root, password: "你的密码"}
      
      roleGroups:
        etcd:
        - k8s-master
        control-plane: 
        - k8s-master
        worker:
        - k8s-node1
        - k8s-node2

      controlPlaneEndpoint:
        domain: lb.kubesphere.local
        address: ""  # 单 Master 留空即可，或者填 Master IP
        port: 6443

      kubernetes:
        version: v1.26.5
        clusterName: cluster.local
        autoRenewCerts: true
        containerManager: containerd

      network:
        plugin: calico # 推荐使用 calico
        kubePodsCIDR: 10.233.64.0/18
        kubeServiceCIDR: 10.233.0.0/18

      registry:
        # 这一步非常重要！配置国内镜像加速，解决下载慢的问题
        registryMirrors:
        - https://docker.m.daocloud.io
        - https://huecker.io
        - https://mirror.baidubce.com

      addons:
      - name: kubesphere
        version: v3.4.1
      # ！！！这里一定要把 devops 加上，否则后面要手动开启很麻烦！！！
      - name: devops 
        version: enabled 
    ```

    **注意**: 配置文件里的 `user` 必须是有 `sudo` 权限的用户。如果你用的是普通用户（如 ubuntu），记得填 `user: ubuntu`。如果是 `root` 直接填 root。

---

### 第三步：开始安装

确认配置文件无误后，执行最终命令：

```bash
export KKZONE=cn
./kk create cluster -f config-sample.yaml
```

**接下来会发生什么：**
1.  **环境检查**: KK 会检查 3 台机器的时间、防火墙、依赖。
2.  **下载二进制**: 如果本地没有，它会去下载 K8s、Docker 等文件（因为加了 `KKZONE=cn`，会走国内 CDN）。
3.  **安装 Master**: 初始化控制平面。
4.  **加入 Nodes**: 自动将 Node1 和 Node2 加入集群。
5.  **安装 KubeSphere**: