#!/bin/sh

sudo dnf update -y
sudo dnf install -y git wget curl bash-completion

# Add the Docker repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker engine and CLI
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl enable --now docker

# Optional: Add your user to the docker group to avoid using 'sudo'
sudo usermod -aG docker $USER

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Load bash-completion
source /usr/share/bash-completion/bash_completion

# Add completions to your bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'source <(kind completion bash)' >> ~/.bashrc
echo 'source <(helm completion bash)' >> ~/.bashrc

echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

# Apply changes
source ~/.bashrc


