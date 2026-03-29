#!/bin/bash

# Setup Prerequisites on almak3s
# This script installs kubectl and clones the repository

set -e

echo "=========================================="
echo "almak3s Prerequisites Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

echo "Step 1: Installing kubectl..."
if command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}kubectl already installed${NC}"
    kubectl version --client
else
    echo "Downloading kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    echo "Installing kubectl..."
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Create symlink for sudo
    ln -sf /usr/local/bin/kubectl /usr/bin/kubectl
    
    echo -e "${GREEN}✓ kubectl installed${NC}"
    kubectl version --client
fi

echo ""
echo "Step 2: Setting up kubeconfig..."
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    # Setup for root user
    mkdir -p /root/.kube
    cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
    chmod 600 /root/.kube/config
    echo -e "${GREEN}✓ kubeconfig configured for root${NC}"
    
    # Setup for regular user if exists
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
        mkdir -p "$USER_HOME/.kube"
        cp /etc/rancher/k3s/k3s.yaml "$USER_HOME/.kube/config"
        chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.kube"
        chmod 600 "$USER_HOME/.kube/config"
        echo -e "${GREEN}✓ kubeconfig configured for $SUDO_USER${NC}"
    fi
else
    echo -e "${RED}Error: K3s not found. Please install K3s first.${NC}"
    exit 1
fi

echo ""
echo "Step 3: Testing kubectl access..."
if kubectl get nodes &> /dev/null; then
    echo -e "${GREEN}✓ kubectl working${NC}"
    kubectl get nodes
else
    echo -e "${RED}✗ kubectl not working${NC}"
    exit 1
fi

echo ""
echo "Step 4: Installing git (if needed)..."
if command -v git &> /dev/null; then
    echo -e "${YELLOW}git already installed${NC}"
else
    dnf install -y git
    echo -e "${GREEN}✓ git installed${NC}"
fi

echo ""
echo "Step 5: Cloning repository..."
REPO_DIR="/root/dev-infrastructure-setup"
if [ -d "$REPO_DIR" ]; then
    echo -e "${YELLOW}Repository already exists at $REPO_DIR${NC}"
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$REPO_DIR"
        git pull
        echo -e "${GREEN}✓ Repository updated${NC}"
    fi
else
    echo "Cloning from Gitea..."
    read -p "Enter Gitea URL (e.g., http://almabuild:3000/username/dev-infrastructure-setup.git): " GITEA_URL
    
    if [ -z "$GITEA_URL" ]; then
        echo -e "${YELLOW}No URL provided. You can clone manually later:${NC}"
        echo "  git clone YOUR_GITEA_URL /root/dev-infrastructure-setup"
    else
        git clone "$GITEA_URL" "$REPO_DIR"
        echo -e "${GREEN}✓ Repository cloned to $REPO_DIR${NC}"
    fi
fi

echo ""
echo "Step 6: Setting up directory structure..."
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    
    # Make scripts executable
    if [ -d "k8s-setup" ]; then
        chmod +x k8s-setup/*.sh 2>/dev/null || true
    fi
    
    if [ -d "project-templates/hello-world-python/k8s" ]; then
        chmod +x project-templates/hello-world-python/k8s/*.sh 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Scripts made executable${NC}"
fi

echo ""
echo "=========================================="
echo "Prerequisites Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Deploy secure application:"
echo "   cd $REPO_DIR/project-templates/hello-world-python/k8s"
echo "   sudo ./setup-secure-deployment.sh"
echo ""
echo "2. Or deploy manually:"
echo "   kubectl apply -f $REPO_DIR/project-templates/hello-world-python/k8s/deployment-secure.yaml"
echo "   kubectl apply -f $REPO_DIR/project-templates/hello-world-python/k8s/network-policy.yaml"
echo ""
echo "3. Verify deployment:"
echo "   kubectl get pods -l app=hello-world-python"
echo "   kubectl get service hello-world-python"
echo ""
echo -e "${GREEN}Setup complete!${NC}"

# Made with Bob
