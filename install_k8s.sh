#基础配置
systemctl stop firewalld
sed -i 's/enforcing/disabled/' /etc/selinux/config
cat >/etc/sysctl.d/k8s.config<<EOF
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
EOF
sysctl --system
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/ipv4/ip_forward
yum install ntpdate -y
ntpdate time.windows.com
#安装docker
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum clean all
yum makecache
yum -y install docker-ce-19.03.11
systemctl enable docker && systemctl start docker
rm -f /etc/docker/daemon.json
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://b9pmyelo.mirror.aliyuncs.com"]
}
EOF
sed -i '1 a\"exec-opts\": [\"native.cgroupdriver=systemd\"],' /etc/docker/daemon.json
systemctl daemon-reload
systemctl restart docker
#添加yum源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
#安装k8s
yum install -y kubelet-1.23.6 kubeadm-1.23.6 kubectl-1.23.6
systemctl enable kubelet
#需要修改此处的kubeadm join命令
kubeadm join 172.17.84.101:6443 --token z6puc1.i2yutfkrmy3054ix \
        --discovery-token-ca-cert-hash sha256:e459224f042e1d9c684d21188436d7af50ec1fa4d165b25956bd3d08323c12e8


#提前拉取calico组件
docker pull registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:cni
docker pull registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:pod2daemon-flexvol
docker pull registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:kube-controllers
docker pull registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:node

docker images | grep node| awk '{print "docker tag "$3" docker.io/calico/node:v3.18.6"}'|bash
docker images | grep cni| awk '{print "docker tag "$3" docker.io/calico/cni:v3.18.6"}'|bash
docker images | grep pod2daemon-flexvol| awk '{print "docker tag "$3" docker.io/calico/pod2daemon-flexvol:v3.18.6"}'|bash
docker images | grep kube-controllers| awk '{print "docker tag "$3" docker.io/calico/kube-controllers:v3.18.6"}'|bash

docker rmi registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:cni
docker rmi registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:pod2daemon-flexvol
docker rmi registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:kube-controllers
docker rmi registry.cn-shanghai.aliyuncs.com/cmhtest/kubernete:node
