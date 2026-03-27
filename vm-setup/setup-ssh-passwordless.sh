#!/bin/bash

################################################################################
# SSH Passwordless Login Setup Script
# Purpose: Configure SSH key-based authentication to AlmaLinux hosts
# Usage: ./setup-ssh-passwordless.sh
# Hosts: almak3s, almabuild
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

# Configuration
TARGET_HOSTS=("almak3s" "almabuild")
SSH_KEY_TYPE="ed25519"
SSH_KEY_PATH="${HOME}/.ssh/id_${SSH_KEY_TYPE}"
SSH_KEY_COMMENT="$(whoami)@$(hostname)-$(date +%Y%m%d)"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test SSH connection
test_ssh_connection() {
    local host=$1
    local user=$2
    
    log_info "Testing SSH connection to ${user}@${host}..."
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host}" exit 2>/dev/null; then
        log_info "✓ Passwordless SSH to ${user}@${host} is working!"
        return 0
    else
        log_warn "✗ Passwordless SSH to ${user}@${host} not configured yet"
        return 1
    fi
}

# Function to copy SSH key to remote host
copy_ssh_key() {
    local host=$1
    local user=$2
    
    log_info "Copying SSH key to ${user}@${host}..."
    
    if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${user}@${host}" 2>/dev/null; then
        log_info "✓ SSH key copied successfully to ${user}@${host}"
        return 0
    else
        log_error "✗ Failed to copy SSH key to ${user}@${host}"
        log_info "You may need to enter the password manually"
        return 1
    fi
}

# Main script
log_info "============================================"
log_info "SSH Passwordless Login Setup"
log_info "============================================"
log_info "Target hosts: ${TARGET_HOSTS[*]}"
log_info "SSH key type: ${SSH_KEY_TYPE}"
log_info ""

# Step 1: Check prerequisites
log_step "Checking prerequisites..."

if ! command_exists ssh; then
    log_error "ssh command not found. Please install OpenSSH client."
    exit 1
fi

if ! command_exists ssh-keygen; then
    log_error "ssh-keygen command not found. Please install OpenSSH client."
    exit 1
fi

if ! command_exists ssh-copy-id; then
    log_error "ssh-copy-id command not found. Please install OpenSSH client."
    exit 1
fi

log_info "✓ All prerequisites met"

# Step 2: Create .ssh directory if it doesn't exist
log_step "Setting up SSH directory..."
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
log_info "✓ SSH directory configured"

# Step 3: Generate SSH key if it doesn't exist
log_step "Checking for existing SSH key..."

if [ -f "${SSH_KEY_PATH}" ]; then
    log_info "✓ SSH key already exists at ${SSH_KEY_PATH}"
    log_info "Key fingerprint:"
    ssh-keygen -lf "${SSH_KEY_PATH}"
    echo ""
    
    read -p "Do you want to use this existing key? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Generating new SSH key..."
        ssh-keygen -t "${SSH_KEY_TYPE}" -f "${SSH_KEY_PATH}" -C "${SSH_KEY_COMMENT}" -N ""
        log_info "✓ New SSH key generated"
    fi
else
    log_info "Generating new SSH key..."
    ssh-keygen -t "${SSH_KEY_TYPE}" -f "${SSH_KEY_PATH}" -C "${SSH_KEY_COMMENT}" -N ""
    log_info "✓ SSH key generated at ${SSH_KEY_PATH}"
    log_info "Key fingerprint:"
    ssh-keygen -lf "${SSH_KEY_PATH}"
    echo ""
fi

# Step 4: Configure SSH config file
log_step "Configuring SSH client..."

SSH_CONFIG="${HOME}/.ssh/config"
touch "${SSH_CONFIG}"
chmod 600 "${SSH_CONFIG}"

# Backup existing config
if [ -s "${SSH_CONFIG}" ]; then
    cp "${SSH_CONFIG}" "${SSH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "✓ Backed up existing SSH config"
fi

# Add host configurations if they don't exist
for host in "${TARGET_HOSTS[@]}"; do
    if ! grep -q "Host ${host}" "${SSH_CONFIG}"; then
        log_info "Adding ${host} to SSH config..."
        cat >> "${SSH_CONFIG}" <<EOF

# ${host} - AlmaLinux host
Host ${host}
    HostName ${host}
    User root
    IdentityFile ${SSH_KEY_PATH}
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new
    
EOF
        log_info "✓ Added ${host} to SSH config"
    else
        log_info "✓ ${host} already in SSH config"
    fi
done

# Step 5: Display public key
log_step "Your SSH public key:"
echo ""
cat "${SSH_KEY_PATH}.pub"
echo ""

# Step 6: Prompt for username
log_step "Configuring passwordless access..."
echo ""
read -p "Enter the username for remote hosts (default: root): " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-root}

# Step 7: Copy SSH keys to remote hosts
echo ""
log_info "Now we'll copy your SSH key to each host."
log_info "You'll need to enter the password for each host."
echo ""

for host in "${TARGET_HOSTS[@]}"; do
    echo ""
    log_step "Configuring ${host}..."
    
    # Test if already configured
    if test_ssh_connection "${host}" "${REMOTE_USER}"; then
        continue
    fi
    
    # Try to copy the key
    echo ""
    log_info "Please enter the password for ${REMOTE_USER}@${host}"
    if copy_ssh_key "${host}" "${REMOTE_USER}"; then
        # Test the connection
        sleep 1
        test_ssh_connection "${host}" "${REMOTE_USER}"
    fi
done

# Step 8: Final verification
echo ""
log_step "Final verification..."
echo ""

all_success=true
for host in "${TARGET_HOSTS[@]}"; do
    if test_ssh_connection "${host}" "${REMOTE_USER}"; then
        log_info "✓ ${host}: SUCCESS"
    else
        log_error "✗ ${host}: FAILED"
        all_success=false
    fi
done

# Step 9: Display summary
echo ""
log_info "============================================"
log_info "Setup Summary"
log_info "============================================"
log_info "SSH Key: ${SSH_KEY_PATH}"
log_info "SSH Config: ${SSH_CONFIG}"
log_info "Remote User: ${REMOTE_USER}"
log_info "Target Hosts: ${TARGET_HOSTS[*]}"
echo ""

if [ "$all_success" = true ]; then
    log_info "✓ All hosts configured successfully!"
    echo ""
    log_info "You can now connect without password:"
    for host in "${TARGET_HOSTS[@]}"; do
        log_info "  ssh ${host}"
    done
else
    log_warn "⚠ Some hosts failed to configure"
    echo ""
    log_info "Manual setup instructions:"
    log_info "1. Copy your public key:"
    log_info "   cat ${SSH_KEY_PATH}.pub"
    log_info ""
    log_info "2. On each remote host, add it to authorized_keys:"
    log_info "   mkdir -p ~/.ssh"
    log_info "   chmod 700 ~/.ssh"
    log_info "   echo 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
    log_info "   chmod 600 ~/.ssh/authorized_keys"
fi

echo ""
log_info "Additional Tips:"
log_info "  - Test connection: ssh ${TARGET_HOSTS[0]} 'hostname'"
log_info "  - View SSH config: cat ${SSH_CONFIG}"
log_info "  - Debug connection: ssh -v ${TARGET_HOSTS[0]}"
log_info "  - Remove host key: ssh-keygen -R hostname"
log_info "============================================"

# Made with Bob