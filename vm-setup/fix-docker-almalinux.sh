#!/bin/bash
################################################################################
# Docker Installation and Fix Script for AlmaLinux 10
# Purpose: Install Docker (if needed) and fix Docker startup issues
# Usage: sudo ./fix-docker-almalinux.sh
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Docker Installation and Fix for AlmaLinux 10"
log_info "============================================="
echo ""

# Step 0: Check and install Docker if needed
log_step "Step 0: Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_warn "Docker not found. Installing Docker..."
    
    # Remove any old Docker packages
    log_info "Removing old Docker packages (if any)..."
    dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc 2>/dev/null || true
    
    # Install required packages
    log_info "Installing required packages..."
    dnf install -y dnf-plugins-core
    
    # Add Docker repository
    log_info "Adding Docker CE repository..."
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    log_info "Installing Docker CE..."
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_info "✓ Docker installed successfully"
else
    log_info "✓ Docker is already installed"
    docker --version
fi
echo ""

# Step 1: Install required kernel modules
log_step "Step 1: Installing kernel modules..."
log_info "Installing kernel-modules-extra..."
dnf install -y kernel-modules-extra-$(uname -r)

log_info "Loading required kernel modules..."
modprobe xt_addrtype
modprobe br_netfilter
modprobe overlay

# Make modules persistent
cat > /etc/modules-load.d/docker.conf <<EOF
xt_addrtype
br_netfilter
overlay
EOF

log_info "✓ Kernel modules loaded and configured"
echo ""

# Step 2: Configure Docker daemon
log_step "Step 2: Configuring Docker daemon..."
mkdir -p /etc/docker

if [ -f /etc/docker/daemon.json ]; then
    log_info "Backing up existing daemon.json..."
    cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
fi

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

log_info "✓ Docker daemon configured for AlmaLinux 10"
echo ""

# Step 3: Configure firewall
log_step "Step 3: Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    log_info "Restarting firewalld..."
    systemctl restart firewalld
    
    log_info "Removing docker0 from trusted zone (if exists)..."
    firewall-cmd --permanent --zone=trusted --remove-interface=docker0 2>/dev/null || true
    firewall-cmd --reload
    
    log_info "✓ Firewall configured"
else
    log_warn "firewalld not found"
fi
echo ""

# Step 4: Add dev user to docker group
log_step "Step 4: Configuring user permissions..."
if id "dev" &>/dev/null; then
    log_info "Adding 'dev' user to docker group..."
    usermod -aG docker dev
    log_info "✓ User 'dev' added to docker group"
    log_info "Note: User needs to log out and back in for group changes to take effect"
else
    log_warn "User 'dev' not found - skipping user configuration"
fi
echo ""

# Step 5: Stop Docker
log_step "Step 5: Stopping Docker services..."
systemctl stop docker 2>/dev/null || log_info "Docker was not running"
systemctl stop docker.socket 2>/dev/null || true
echo ""

# Step 6: Reload systemd and start Docker
log_step "Step 6: Starting Docker..."
systemctl daemon-reload
systemctl start docker

log_info "Waiting for Docker to start..."
sleep 5

if systemctl is-active --quiet docker; then
    log_info "✓ Docker is running!"
else
    log_error "✗ Docker failed to start"
    log_info "Checking logs..."
    journalctl -u docker -n 30 --no-pager
    exit 1
fi
echo ""

# Step 7: Test Docker
log_step "Step 7: Testing Docker..."
log_info "Running hello-world container..."
if docker run --rm hello-world > /dev/null 2>&1; then
    log_info "✓ Docker is working correctly!"
else
    log_warn "Docker test had issues, but service is running"
fi
echo ""

# Step 8: Display Docker info
log_step "Step 8: Docker information..."
docker version | head -15
echo ""
docker info | head -20
echo ""

log_info "============================================"
log_info "Docker Installation and Fix Complete!"
log_info "============================================"
log_info ""
log_info "Docker Status:"
systemctl status docker --no-pager | head -10
echo ""
log_info "Configuration Applied:"
log_info "  ✓ Docker CE: Installed (if needed)"
log_info "  ✓ User 'dev': Added to docker group"
log_info "  ✓ Kernel modules: xt_addrtype, br_netfilter, overlay"
log_info "  ✓ Storage driver: overlay2"
log_info "  ✓ Cgroup driver: systemd"
log_info "  ✓ Firewall: Configured"
echo ""
log_info "IMPORTANT: User 'dev' must log out and back in for docker group to take effect!"
echo ""
log_info "Useful Commands:"
log_info "  Status:  systemctl status docker"
log_info "  Logs:    journalctl -u docker -f"
log_info "  Restart: systemctl restart docker"
log_info "  Test (as dev): docker run hello-world"
log_info "============================================"

# Made with Bob