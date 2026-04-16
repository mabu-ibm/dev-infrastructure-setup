#!/bin/bash
################################################################################
# Fix Gitea Actions Runner Docker Socket Issue
# Purpose: Clean up and fix Docker configuration after uninstall
# Usage: sudo ./fix-gitea-runner-docker.sh
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Fixing Gitea Runner Docker Configuration"
log_info "========================================="
echo ""

# Step 1: Stop and remove any existing runner containers
log_step "1. Cleaning up existing runner containers..."
if docker ps -a --format '{{.Names}}' | grep -q "gitea-runner"; then
    log_info "Stopping gitea-runner containers..."
    docker stop $(docker ps -a --format '{{.Names}}' | grep gitea-runner) 2>/dev/null || true
    log_info "Removing gitea-runner containers..."
    docker rm $(docker ps -a --format '{{.Names}}' | grep gitea-runner) 2>/dev/null || true
    log_info "✓ Containers cleaned up"
else
    log_info "No existing containers found"
fi
echo ""

# Step 2: Stop gitea-runner service if exists
log_step "2. Stopping gitea-runner service..."
if systemctl list-units --full -all | grep -q gitea-runner.service; then
    systemctl stop gitea-runner 2>/dev/null || true
    systemctl disable gitea-runner 2>/dev/null || true
    log_info "✓ Service stopped and disabled"
else
    log_info "Service not found (OK)"
fi
echo ""

# Step 3: Remove old service file
log_step "3. Removing old service file..."
if [ -f /etc/systemd/system/gitea-runner.service ]; then
    rm -f /etc/systemd/system/gitea-runner.service
    systemctl daemon-reload
    log_info "✓ Service file removed"
else
    log_info "No service file found (OK)"
fi
echo ""

# Step 4: Clean up runner data directory
log_step "4. Cleaning runner data directory..."
RUNNER_DATA_DIR="/var/lib/gitea-runner"
if [ -d "$RUNNER_DATA_DIR" ]; then
    log_warn "Found existing data directory: $RUNNER_DATA_DIR"
    read -p "Remove it? (y/N): " REMOVE_DATA
    if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
        rm -rf "$RUNNER_DATA_DIR"
        log_info "✓ Data directory removed"
    else
        log_info "Keeping existing data directory"
    fi
else
    log_info "No data directory found (OK)"
fi
echo ""

# Step 5: Verify Docker is working
log_step "5. Verifying Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed!"
    log_info "Install Docker first:"
    log_info "  sudo dnf install -y docker"
    log_info "  sudo systemctl enable --now docker"
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_warn "Docker service is not running. Starting..."
    systemctl start docker
    sleep 3
fi

if systemctl is-active --quiet docker; then
    log_info "✓ Docker service is running"
else
    log_error "Docker service failed to start"
    systemctl status docker --no-pager
    exit 1
fi
echo ""

# Step 6: Test Docker socket
log_step "6. Testing Docker socket..."
if [ -S /var/run/docker.sock ]; then
    log_info "✓ Docker socket exists: /var/run/docker.sock"
    ls -la /var/run/docker.sock
else
    log_error "Docker socket not found!"
    exit 1
fi

if docker ps &> /dev/null; then
    log_info "✓ Docker socket is accessible"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | head -5
else
    log_error "Cannot access Docker socket"
    log_info "Checking permissions..."
    ls -la /var/run/docker.sock
    exit 1
fi
echo ""

# Step 7: Test Docker with a simple container
log_step "7. Testing Docker functionality..."
if docker run --rm hello-world &> /dev/null; then
    log_info "✓ Docker is working correctly"
else
    log_error "Docker test failed"
    docker run --rm hello-world
    exit 1
fi
echo ""

# Step 8: Pull Gitea runner image
log_step "8. Pulling Gitea runner image..."
RUNNER_IMAGE="gitea/act_runner:latest"
if docker pull ${RUNNER_IMAGE}; then
    log_info "✓ Runner image pulled successfully"
    docker images ${RUNNER_IMAGE}
else
    log_error "Failed to pull runner image"
    exit 1
fi
echo ""

# Step 9: Test runner image
log_step "9. Testing runner image..."
if docker run --rm ${RUNNER_IMAGE} --version 2>&1 | grep -q "act_runner"; then
    log_info "✓ Runner image is working"
    docker run --rm ${RUNNER_IMAGE} --version
else
    log_warn "Could not verify runner version (may be OK)"
fi
echo ""

log_info "============================================"
log_info "Docker Configuration Fixed!"
log_info "============================================"
echo ""
log_info "Docker Status:"
systemctl status docker --no-pager | head -10
echo ""
log_info "Docker Socket:"
ls -la /var/run/docker.sock
echo ""
log_info "Docker Info:"
docker info | grep -E "Server Version|Storage Driver|Logging Driver|Cgroup Driver|Kernel Version"
echo ""
log_info "✅ Docker is ready for Gitea runner installation"
echo ""
log_info "Next Steps:"
log_info "1. Run the setup script again:"
log_info "   sudo ./setup-gitea-actions-runner.sh"
echo ""
log_info "2. Or use the complete setup script:"
log_info "   sudo ./setup-gitea-actions-runner-complete.sh"
echo ""
log_info "============================================"

# Made with Bob