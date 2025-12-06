# HomeCloud Lab

## Overview

This repository contains the configuration files and scripts used to set up and manage a home lab environment using various tools and technologies. The home lab is designed to provide a platform for learning, experimentation, and development in a controlled environment.

The inspiration for this home lab comes from the desire to have an environment where I have full control over the data and infrastructure, allowing me to explore different technologies and solutions without relying on third-party cloud providers and political influences. It is also a way to enhance my skills and knowledge in the field of Infrastructure Security.

## Architecture

The home lab is built using a combination of physical and virtual infrastructure. The core technologies used in the home lab include:

- [MaaS (Metal as a Service)](https://maas.io/): for bare-metal server provisioning and management.
- [Apache CloudStack](https://cloudstack.apache.org/): for cloud infrastructure management and orchestration.
- [Kubernetes](https://kubernetes.io/): for container orchestration and management.
- [knative](https://knative.dev/): for serverless workloads on Kubernetes.
- [ArgoCD](https://argo-cd.readthedocs.io/en/stable/): for continuous delivery and GitOps.
- [Cilium](https://cilium.io/): for networking and security in Kubernetes.
- [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/): for monitoring and visualization.
- [Terraform](https://www.terraform.io/): for infrastructure as code.

**TODO**: insert architecture diagram here

## Tooling Setup Instructions

### Requirements

- [Git](https://git-scm.com/downloads)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Python](https://www.python.org/downloads/)
- [Terraform](https://www.terraform.io/downloads.html)
- [Docker](https://docs.docker.com/get-docker/)
- [ArgoCD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Apache CloudStack CLI](https://cloudstack.apache.org/downloads#cloudmonkey-releases)

### Dependencies

#### macOS

- [Homebrew](https://brew.sh/)

````bash
# Variables
export PYTHON_VERSION=3.11.7
export TERRAFORM_VERSION=1.11.4
export TERRAGRUNT_VERSION=0.93.3

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install pyenv awscli kubernetes-cli helm argocd uv pipenv go vim nvim tmux aws-cdk aws-sso-cli powerlevel10k tfenv tgenv krew cilium-cli knative/client/kn knative-extensions/kn-plugins/func cri-tools etcd mise clusterctl yq bash-completion kind
brew install --cask visual-studio-code tunnelblick pgadmin4 insomnia istat-menus maccy 1password 1password-cli whatsapp ticktick spotify docker tailscale-app multipass windows-app nordvpn
kubectl krew install konfig

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
echo "source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme" >> .zshrc
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# Set the following in “~/.zshrc”, `plugins=(git zsh-syntax-highlighting zsh-autosuggestions)`

# Configure aliases for quick access
echo 'alias k="kubectl"' >> ~/.zshrc
echo 'alias kx="kubectl exec -it"' >> ~/.zshrc
echo 'alias h="helm"' >> ~/.zshrc

# Set up auto-completion
echo "autoload -U +X bashcompinit && bashcompinit" >> ~/.zshrc
echo "source <(k completion zsh)" >> ~/.zshrc
echo "source <(h completion zsh)" >> ~/.zshrc
echo "source <(cilium completion zsh)" >> ~/.zshrc
echo "source <(op completion zsh)" >> ~/.zshrc
echo "source <(kind completion zsh)" >> ~/.zshrc
echo "source <(clusterctl completion zsh)" >> ~/.zshrc

# Install Python
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init - zsh)"' >> ~/.zshrc

pyenv install $PYTHON_VERSION
pyenv global $PYTHON_VERSION

# Install Terraform
tfenv install $TERRAFORM_VERSION
tfenv use $TERRAFORM_VERSION

# Install Terragrunt
tgenv install $TERRAGRUNT_VERSION
tgenv use $TERRAGRUNT_VERSION
```bash

#### Proxmox Server

This is a Proxmox server running on a bare metal machine. It is used to host the VMs and containers for the home lab. It is configured manually based on the Proxmox documentation.

Note: The Proxmox server is not included in the repository. You will need to set it up manually. Also, only a single Proxmox server is used in this home lab, the Proxmox server is not a cluster.
````
