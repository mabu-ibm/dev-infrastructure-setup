#!/bin/bash
################################################################################
# MacBook Environment Configuration
# Purpose: Configure environment variables and settings
# Usage: ./configure-environment.sh
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

log_info "Configuring development environment..."

# Configuration file
ENV_FILE="${HOME}/.dev-infrastructure.env"

# Detect shell
SHELL_RC=""
if [ -n "${ZSH_VERSION:-}" ]; then
    SHELL_RC="${HOME}/.zshrc"
elif [ -n "${BASH_VERSION:-}" ]; then
    SHELL_RC="${HOME}/.bashrc"
else
    log_warn "Unknown shell, defaulting to .zshrc"
    SHELL_RC="${HOME}/.zshrc"
fi

log_info "Using shell configuration: ${SHELL_RC}"

# Collect configuration
log_step "Collecting configuration..."

echo ""
echo "Please provide the following information:"
echo ""

# Build VM (Gitea)
read -p "Build VM IP address: " BUILD_VM_IP
read -p "Gitea username: " GITEA_USERNAME
read -p "Gitea access token: " GITEA_TOKEN

# K3s VM
read -p "K3s VM IP address: " K3S_VM_IP

# Projects directory
PROJECTS_DIR="${HOME}/projects"
read -p "Projects directory [${PROJECTS_DIR}]: " input_projects_dir
PROJECTS_DIR="${input_projects_dir:-$PROJECTS_DIR}"

# Git configuration
GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")

if [ -z "${GIT_USER_NAME}" ]; then
    read -p "Git user name: " GIT_USER_NAME
    git config --global user.name "${GIT_USER_NAME}"
fi

if [ -z "${GIT_USER_EMAIL}" ]; then
    read -p "Git user email: " GIT_USER_EMAIL
    git config --global user.email "${GIT_USER_EMAIL}"
fi

# Create environment file
log_step "Creating environment file..."

cat > "${ENV_FILE}" <<EOF
################################################################################
# Development Infrastructure Environment Configuration
# Generated: $(date)
################################################################################

# Gitea Configuration
export GITEA_URL="http://${BUILD_VM_IP}:3000"
export GITEA_TOKEN="${GITEA_TOKEN}"
export GITEA_USERNAME="${GITEA_USERNAME}"
export GITEA_REGISTRY="${BUILD_VM_IP}:3000"

# K3s Configuration
export K3S_URL="https://${K3S_VM_IP}:6443"
export KUBECONFIG="${HOME}/.kube/k3s-config"

# VM Access
export BUILD_VM_IP="${BUILD_VM_IP}"
export K3S_VM_IP="${K3S_VM_IP}"

# Projects
export PROJECTS_DIR="${PROJECTS_DIR}"

# Git Configuration
export GIT_USER_NAME="${GIT_USER_NAME}"
export GIT_USER_EMAIL="${GIT_USER_EMAIL}"

# Aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kga='kubectl get all -A'
alias klogs='kubectl logs -f'
alias kdesc='kubectl describe'

alias flux-status='flux get all -A'
alias flux-logs='flux logs --all-namespaces --follow'
alias flux-sync='flux reconcile source git'

alias gitea-ssh='ssh root@${BUILD_VM_IP}'
alias k3s-ssh='ssh root@${K3S_VM_IP}'

alias projects='cd ${PROJECTS_DIR}'

# Functions
gitea-create-repo() {
    local repo_name=\$1
    if [ -z "\${repo_name}" ]; then
        echo "Usage: gitea-create-repo <repo-name>"
        return 1
    fi
    
    curl -X POST "\${GITEA_URL}/api/v1/user/repos" \\
        -H "Authorization: token \${GITEA_TOKEN}" \\
        -H "Content-Type: application/json" \\
        -d "{\"name\":\"\${repo_name}\",\"private\":false}"
}

k3s-kubeconfig() {
    scp root@${K3S_VM_IP}:/root/k3s-remote-kubeconfig.yaml ~/.kube/k3s-config
    echo "Kubeconfig updated. Test with: kubectl get nodes"
}

sync-project-chats() {
    local project_dir=\${1:-\$(pwd)}
    ~/dev-infrastructure-setup/chat-sync/sync-chats.sh "\${project_dir}"
}

new-project() {
    local project_name=\$1
    local stack_type=\${2:-python}
    
    if [ -z "\${project_name}" ]; then
        echo "Usage: new-project <name> [stack-type]"
        echo "Stack types: python, node, go, java, rust"
        return 1
    fi
    
    ~/dev-infrastructure-setup/project-templates/scaffold-project.sh "\${project_name}" "\${stack_type}"
}

EOF

chmod 600 "${ENV_FILE}"
log_info "✓ Environment file created: ${ENV_FILE}"

# Add to shell RC if not already present
log_step "Updating shell configuration..."

if ! grep -q "dev-infrastructure.env" "${SHELL_RC}" 2>/dev/null; then
    cat >> "${SHELL_RC}" <<EOF

# Development Infrastructure Environment
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
EOF
    log_info "✓ Added to ${SHELL_RC}"
else
    log_info "✓ Already configured in ${SHELL_RC}"
fi

# Create SSH config for easy VM access
log_step "Configuring SSH..."

SSH_CONFIG="${HOME}/.ssh/config"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

# Backup existing config
if [ -f "${SSH_CONFIG}" ]; then
    cp "${SSH_CONFIG}" "${SSH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Add VM entries if not present
if ! grep -q "Host build-vm" "${SSH_CONFIG}" 2>/dev/null; then
    cat >> "${SSH_CONFIG}" <<EOF

# Development Infrastructure VMs
Host build-vm
    HostName ${BUILD_VM_IP}
    User root
    ForwardAgent yes

Host k3s-vm
    HostName ${K3S_VM_IP}
    User root
    ForwardAgent yes
EOF
    log_info "✓ SSH config updated: ${SSH_CONFIG}"
else
    log_info "✓ SSH config already contains VM entries"
fi

# Create helper script for SSH key setup
cat > "${HOME}/setup-ssh-keys.sh" <<'EOF'
#!/bin/bash
# Helper script to set up SSH keys for VMs

echo "Setting up SSH keys for passwordless access..."

if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_rsa -N ""
fi

echo ""
echo "Copy SSH key to build VM:"
read -p "Build VM IP: " BUILD_VM_IP
ssh-copy-id root@${BUILD_VM_IP}

echo ""
echo "Copy SSH key to K3s VM:"
read -p "K3s VM IP: " K3S_VM_IP
ssh-copy-id root@${K3S_VM_IP}

echo ""
echo "✓ SSH keys configured!"
echo "Test with: ssh build-vm"
EOF

chmod +x "${HOME}/setup-ssh-keys.sh"
log_info "✓ SSH key setup helper created: ${HOME}/setup-ssh-keys.sh"

# Source the environment in current shell
source "${ENV_FILE}"

log_info "============================================"
log_info "✅ Environment Configuration Complete!"
log_info "============================================"
log_info "Configuration file: ${ENV_FILE}"
log_info "Shell configuration: ${SHELL_RC}"
log_info "SSH configuration: ${SSH_CONFIG}"
log_info ""
log_info "Environment Variables Set:"
log_info "  GITEA_URL: ${GITEA_URL}"
log_info "  GITEA_USERNAME: ${GITEA_USERNAME}"
log_info "  K3S_URL: ${K3S_URL}"
log_info "  PROJECTS_DIR: ${PROJECTS_DIR}"
log_info ""
log_info "Useful Aliases:"
log_info "  k                  - kubectl"
log_info "  kgp                - kubectl get pods"
log_info "  flux-status        - flux get all -A"
log_info "  gitea-ssh          - ssh to build VM"
log_info "  k3s-ssh            - ssh to K3s VM"
log_info "  projects           - cd to projects directory"
log_info ""
log_info "Useful Functions:"
log_info "  new-project <name> [stack]     - Create new project"
log_info "  gitea-create-repo <name>       - Create Gitea repository"
log_info "  k3s-kubeconfig                 - Update kubeconfig from K3s"
log_info "  sync-project-chats [dir]       - Sync AI chats manually"
log_info ""
log_info "Next Steps:"
log_info "1. Reload shell: source ${SHELL_RC}"
log_info "2. Set up SSH keys: ${HOME}/setup-ssh-keys.sh"
log_info "3. Get kubeconfig: k3s-kubeconfig"
log_info "4. Test connection: kubectl get nodes"
log_info "5. Create first project: new-project my-api python"
log_info "============================================"

# Made with Bob
