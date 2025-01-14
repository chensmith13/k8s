一、基础环境
1.关闭防火墙（为了内网操作方便）
systemctl stop firewalld
2.关闭selinux
swap off -a   #临时

setenforce 0 #临时关闭
sed -i 's/enforcing/disabled/' /etc/selinux/config   #永久 关闭完需要重启虚拟机
3.设置主机名
hostnamectl set-hostname master
4.在master添加hosts
cat >> /etc/host<<EOF
101.132.99.159 k8s-master
110.42.249.211 k8s-slave1
121.36.201.68 k8s-slave2
EOF

安装ansible
yum install ansible

5.将ipv4流量桥接到iptables
cat >/etc/sysctl.d/k8s.config<<EOF
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
EOF
sysctl --system#生效所有配置文件
sysctl -p /etc/sysctl.d/k8s.conf  # 单独指定配置文件加载

6.时间同步
yum install ntpdate -y
ntpdate time.windows.com

二、安装docker
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum clean all
yum makecache
yum -y install docker-ce-19.03.11
systemctl enable docker && systemctl start docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://b9pmyelo.mirror.aliyuncs.com"]
}
EOF
sed -i '1 a\"exec-opts\": [\"native.cgroupdriver=systemd\"],' /etc/docker/daemon.json
systemctl daemon-reload
systemctl restart docker
三、添加yum源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

四、安装k8s

4.1可选（如果跨不同云平台需要组vpc网络）
https://accesshub.kf5.com/hc/kb/article/1147121/


yum install -y kubelet-1.23.6 kubeadm-1.23.6 kubectl-1.23.6
systemctl enable kubelet


master初始化
kubeadm init \
  --apiserver-advertise-address=172.17.84.101 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.23.6 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16

查看日志：journalctl -xefu kubelet

说明：
--apiserver-advertise-address=172.16.3.181 #master的ip地址
--image-repository registry.aliyuncs.com/google_containers #指定从什么位置拉取镜像
--kubernetes-version=v1.18.19 #指定k8s版本，根据具体版本进行修改
--service-cidr=10.96.0.0/16 #指定service网络的范围
--pod-network-cidr=10.244.0.0/16 #指定pod网络的范围
由于默认拉取镜像地址k8s.gcr.io国内无法访问，这里指定阿里云镜像仓库地址。


node节点加入:
kubeadm join 172.17.84.101:6443 --token z6puc1.i2yutfkrmy3054ix \
        --discovery-token-ca-cert-hash sha256:e459224f042e1d9c684d21188436d7af50ec1fa4d165b25956bd3d08323c12e8 
重新生成token:
kubeadm token create --print-join-command

部署cni插件
sudo wget https://docs.projectcalico.org/v3.18/manifests/calico.yaml

修改其中的
CALICO_IPV4POOL_CIDR为pod-network-cidr
kubectl apply -f calico.yaml

拉取镜像文件
