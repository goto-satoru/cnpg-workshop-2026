#!/bin/sh
# CNPG Cluster hands-on setup

sudo dnf update -y
sudo dnf install -y git wget curl bash-completion

# Install Docker engine and CLI
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# install kubectl-cnp plugin
# https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/kubectl-plugin/#status
curl -L https://github.com/EnterpriseDB/kubectl-cnp/releases/download/v1.28.1/kubectl-cnp_1.28.1_linux_x86_64.rpm \
  --output kube-plugin.rpm
sudo yum --disablerepo=* localinstall kube-plugin.rpm

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# bash-completion
echo 'source /usr/share/bash-completion/bash_completion' >> ~/.bashrc
echo 'source <(kind completion bash)' >> ~/.bashrc
echo 'source <(helm completion bash)' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
echo "#------------------------------------------------" >> ~/.bashrc

echo ""
echo "K8s/CNPG Tools installed in /usr/local/bin:"
ls -l /usr/local/bin
