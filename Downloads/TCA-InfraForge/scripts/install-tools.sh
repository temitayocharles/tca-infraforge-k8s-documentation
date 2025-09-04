#!/bin/bash
set -euo pipefail

# Enterprise DevOps Lab - Automated Tool Installation
# This script installs all required tools for the lab

echo "🚀 Starting Enterprise DevOps Lab Tool Installation..."

# Create directories
mkdir -p ~/bin
mkdir -p ~/.kube

# Add ~/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/bin"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    export PATH="$HOME/bin:$PATH"
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install KIND (Kubernetes in Docker)
echo "🎯 Installing KIND..."
if ! command -v kind &> /dev/null; then
    # For Mac with Intel processor
    curl -Lo ~/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
    chmod +x ~/bin/kind
fi

# Install Helm
echo "⚓ Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install Istio CLI
echo "🌐 Installing Istio CLI..."
if ! command -v istioctl &> /dev/null; then
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
    sudo mv istio-*/bin/istioctl /usr/local/bin/
    rm -rf istio-*
fi

# Install ArgoCD CLI
echo "🔄 Installing ArgoCD CLI..."
if ! command -v argocd &> /dev/null; then
    curl -sSL -o ~/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
    chmod +x ~/bin/argocd
fi

# Install Vault CLI
echo "🔐 Installing Vault CLI..."
if ! command -v vault &> /dev/null; then
    brew install hashicorp/tap/vault
fi

# Install SOPS for secrets encryption
echo "🔒 Installing SOPS..."
if ! command -v sops &> /dev/null; then
    brew install sops
fi

# Install jq for JSON processing
echo "📝 Installing jq..."
if ! command -v jq &> /dev/null; then
    brew install jq
fi

# Install yq for YAML processing
echo "📄 Installing yq..."
if ! command -v yq &> /dev/null; then
    brew install yq
fi

echo "✅ All tools installed successfully!"
echo "🔄 Please run 'source ~/.zshrc' or restart your terminal to use new tools"
