#!/bin/bash
################################################################################
# MacBook Prerequisites Installation
# Purpose: Install required tools on MacBook for development workflow
# Usage: ./install-prerequisites.sh
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

log_info "Installing prerequisites on MacBook..."

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is for macOS only"
    exit 1
fi

# Step 1: Install Homebrew if not present
log_step "Checking Homebrew..."
if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    log_info "✓ Homebrew already installed"
    brew update
fi

# Step 2: Install Git
log_step "Checking Git..."
if ! command -v git &> /dev/null; then
    log_info "Installing Git..."
    brew install git
else
    log_info "✓ Git already installed ($(git --version))"
fi

# Step 3: Install kubectl
log_step "Checking kubectl..."
if ! command -v kubectl &> /dev/null; then
    log_info "Installing kubectl..."
    brew install kubectl
else
    log_info "✓ kubectl already installed ($(kubectl version --client --short 2>/dev/null || echo 'version check failed'))"
fi

# Step 4: Install Flux CLI
log_step "Checking Flux CLI..."
if ! command -v flux &> /dev/null; then
    log_info "Installing Flux CLI..."
    brew install fluxcd/tap/flux
else
    log_info "✓ Flux CLI already installed ($(flux --version))"
fi

# Step 5: Install Helm
log_step "Checking Helm..."
if ! command -v helm &> /dev/null; then
    log_info "Installing Helm..."
    brew install helm
else
    log_info "✓ Helm already installed ($(helm version --short))"
fi

# Step 6: Install Docker Desktop (optional)
log_step "Checking Docker..."
if ! command -v docker &> /dev/null; then
    log_warn "Docker not found. Install Docker Desktop manually from:"
    log_warn "https://www.docker.com/products/docker-desktop"
else
    log_info "✓ Docker already installed ($(docker --version))"
fi

# Step 7: Install useful CLI tools
log_step "Installing additional tools..."

# jq for JSON processing
if ! command -v jq &> /dev/null; then
    log_info "Installing jq..."
    brew install jq
else
    log_info "✓ jq already installed"
fi

# yq for YAML processing
if ! command -v yq &> /dev/null; then
    log_info "Installing yq..."
    brew install yq
else
    log_info "✓ yq already installed"
fi

# tree for directory visualization
if ! command -v tree &> /dev/null; then
    log_info "Installing tree..."
    brew install tree
else
    log_info "✓ tree already installed"
fi

# watch for monitoring commands
if ! command -v watch &> /dev/null; then
    log_info "Installing watch..."
    brew install watch
else
    log_info "✓ watch already installed"
fi

# Step 8: Configure Git
log_step "Configuring Git..."
if [ -z "$(git config --global user.name)" ]; then
    read -p "Enter your Git name: " git_name
    git config --global user.name "$git_name"
fi

if [ -z "$(git config --global user.email)" ]; then
    read -p "Enter your Git email: " git_email
    git config --global user.email "$git_email"
fi

log_info "Git configured:"
log_info "  Name: $(git config --global user.name)"
log_info "  Email: $(git config --global user.email)"

# Step 9: Create projects directory
log_step "Setting up projects directory..."
PROJECTS_DIR="${HOME}/projects"
if [ ! -d "${PROJECTS_DIR}" ]; then
    mkdir -p "${PROJECTS_DIR}"
    log_info "✓ Created projects directory: ${PROJECTS_DIR}"
else
    log_info "✓ Projects directory exists: ${PROJECTS_DIR}"
fi

# Step 10: Create .kube directory
log_step "Setting up kubectl configuration..."
KUBE_DIR="${HOME}/.kube"
if [ ! -d "${KUBE_DIR}" ]; then
    mkdir -p "${KUBE_DIR}"
    log_info "✓ Created .kube directory: ${KUBE_DIR}"
else
    log_info "✓ .kube directory exists: ${KUBE_DIR}"
fi

# Step 11: Summary
log_info "============================================"
log_info "✅ Prerequisites Installation Complete!"
log_info "============================================"
log_info "Installed Tools:"
log_info "  ✓ Homebrew: $(brew --version | head -n1)"
log_info "  ✓ Git: $(git --version)"
log_info "  ✓ kubectl: $(kubectl version --client --short 2>/dev/null | head -n1 || echo 'installed')"
log_info "  ✓ Flux CLI: $(flux --version)"
log_info "  ✓ Helm: $(helm version --short)"
log_info "  ✓ jq: $(jq --version)"
log_info "  ✓ yq: $(yq --version)"
log_info "  ✓ tree: installed"
log_info "  ✓ watch: installed"
if command -v docker &> /dev/null; then
    log_info "  ✓ Docker: $(docker --version)"
else
    log_warn "  ⚠ Docker: Not installed (optional)"
fi
log_info ""
log_info "Directories:"
log_info "  ✓ Projects: ${PROJECTS_DIR}"
log_info "  ✓ Kubectl config: ${KUBE_DIR}"
log_info ""
log_info "Next Steps:"
log_info "1. Run: ./configure-environment.sh"
log_info "2. Set up SSH keys for VMs"
log_info "3. Configure kubeconfig for K3s cluster"
log_info "============================================"

# Made with Bob
