#!/bin/bash

# swapoff off
swapoff -a && \
free 
echo "vm.swappiness = 0">> /etc/sysctl.conf 
setenforce 0
systemctl stop firewalld.service
systemctl disable firewalld.service
# ipvsadm install
yum install ipset ipvsadm wget -y
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4

# install docker 
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install docker-ce docker-ce-cli containerd.io -y

systemctl enable docker.service 
systemctl start docker.service
# sys
touch /etc/sysctl.d/k8s.conf
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
cat /proc/sys/net/ipv4/ip_forward
cat /proc/sys/net/bridge/bridge-nf-call-iptables


# install k8s
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum makecache fast
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet.service


# k8s image
# kubeadm config print-default > kubeadm.conf 
# sed -i "s/imageRepository: .*/imageRepository: registry.aliyuncs.com\/google_containers/g" kubeadm.conf
# sed -i "s/kubernetesVersion: .*/kubernetesVersion: v1.13.4/g" kubeadm.conf
K8S_VERSERION=v1.13.4
pause_VERSION=3.1
etcd_VERSION=3.2.24
coredns_VERSION=1.2.6
docker pull registry.aliyuncs.com/google_containers/kube-apiserver-amd64:${K8S_VERSERION}
docker pull registry.aliyuncs.com/google_containers/kube-controller-manager-amd64:${K8S_VERSERION}
docker pull registry.aliyuncs.com/google_containers/kube-scheduler-amd64:${K8S_VERSERION}
docker pull registry.aliyuncs.com/google_containers/kube-proxy-amd64:${K8S_VERSERION}
docker pull registry.aliyuncs.com/google_containers/pause:${pause_VERSION}
docker pull registry.aliyuncs.com/google_containers/etcd-amd64:${etcd_VERSION}
docker pull registry.aliyuncs.com/google_containers/coredns:${coredns_VERSION}

docker tag docker.io/registry.aliyuncs.com/google_containers/kube-proxy-amd64:${K8S_VERSERION} k8s.gcr.io/kube-proxy:${K8S_VERSERION}
docker tag docker.io/registry.aliyuncs.com/google_containers/kube-scheduler-amd64:${K8S_VERSERION} k8s.gcr.io/kube-scheduler:${K8S_VERSERION}
docker tag docker.io/registry.aliyuncs.com/google_containers/kube-apiserver-amd64:${K8S_VERSERION} k8s.gcr.io/kube-apiserver:${K8S_VERSERION}
docker tag docker.io/registry.aliyuncs.com/google_containers/kube-controller-manager-amd64:${K8S_VERSERION} k8s.gcr.io/kube-controller-manager:${K8S_VERSERION}
docker tag docker.io/registry.aliyuncs.com/google_containers/etcd-amd64:${etcd_VERSION}  k8s.gcr.io/etcd:${etcd_VERSION}
docker tag docker.io/registry.aliyuncs.com/google_containers/pause:${pause_VERSION}  k8s.gcr.io/pause:${pause_VERSION}
docker tag docker.io/registry.aliyuncs.com/google_containers/coredns:${coredns_VERSION}  k8s.gcr.io/coredns:${coredns_VERSION}

