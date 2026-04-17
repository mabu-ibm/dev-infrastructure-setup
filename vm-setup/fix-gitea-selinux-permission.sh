#!/bin/bash
################################################################################
# Fix Gitea SELinux Permission Denied Error
# Purpose: Fix "Failed to execute /usr/local/bin/gitea: Permission denied"
# Usage: sudo ./fix-gitea-selinux-permission.sh
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

log_info "=========================================="
log_info "Fixing Gitea SELinux Permission Issue"
log_info "=========================================="
echo ""

# Configuration
GITEA_BINARY="/usr/local/bin/gitea"
GITEA_USER="git"
GITEA_HOME="/var/lib/gitea"

log_step "Step 1: Checking current status..."
if systemctl is-active --quiet gitea; then
    log_info "Gitea is currently running"
    log_info "Stopping Gitea..."
    systemctl stop gitea
else
    log_warn "Gitea is not running"
fi
echo ""

log_step "Step 2: Checking SELinux status..."
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    log_info "SELinux status: $SELINUX_STATUS"
    
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        log_warn "SELinux is in Enforcing mode - this is causing the permission issue"
    fi
else
    log_warn "SELinux tools not found"
fi
echo ""

log_step "Step 3: Fixing file permissions..."
log_info "Setting ownership..."
chown ${GITEA_USER}:${GITEA_USER} ${GITEA_BINARY}
log_info "Setting execute permissions..."
chmod 755 ${GITEA_BINARY}
log_info "✓ File permissions set"
echo ""

log_step "Step 4: Fixing SELinux context..."
if command -v chcon &> /dev/null; then
    log_info "Setting SELinux context for Gitea binary..."
    chcon -t bin_t ${GITEA_BINARY}
    log_info "✓ SELinux context set to bin_t"
    
    log_info "Restoring SELinux context..."
    restorecon -v ${GITEA_BINARY}
    log_info "✓ SELinux context restored"
else
    log_warn "SELinux tools not available, skipping context fix"
fi
echo ""

log_step "Step 5: Alternative - Set SELinux to Permissive (if needed)..."
echo "If the issue persists, you can temporarily set SELinux to permissive mode:"
echo "  sudo setenforce 0"
echo ""
echo "To make it permanent, edit /etc/selinux/config:"
echo "  SELINUX=permissive"
echo ""
read -p "Set SELinux to Permissive mode now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Setting SELinux to Permissive mode..."
    setenforce 0
    log_info "✓ SELinux set to Permissive"
    
    log_info "Making change permanent..."
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    log_info "✓ SELinux configuration updated"
else
    log_info "Skipping SELinux mode change"
fi
echo ""

log_step "Step 6: Fixing directory permissions..."
log_info "Setting ownership for Gitea directories..."
chown -R ${GITEA_USER}:${GITEA_USER} ${GITEA_HOME}
chown -R ${GITEA_USER}:${GITEA_USER} /var/log/gitea
log_info "✓ Directory permissions set"
echo ""

log_step "Step 7: Reloading systemd..."
systemctl daemon-reload
log_info "✓ Systemd reloaded"
echo ""

log_step "Step 8: Starting Gitea service..."
systemctl start gitea
sleep 5
echo ""

log_step "Step 9: Checking service status..."
if systemctl is-active --quiet gitea; then
    log_info "✓ SUCCESS! Gitea is now running!"
    echo ""
    systemctl status gitea --no-pager -l
else
    log_error "✗ Gitea still failed to start"
    echo ""
    log_info "Checking recent logs..."
    journalctl -u gitea -n 30 --no-pager
    echo ""
    log_info "Additional troubleshooting steps:"
    echo "1. Check binary permissions: ls -lZ ${GITEA_BINARY}"
    echo "2. Check SELinux denials: ausearch -m avc -ts recent"
    echo "3. Try running manually: sudo -u ${GITEA_USER} ${GITEA_BINARY} web"
    exit 1
fi
echo ""

log_info "=========================================="
log_info "Fix Complete!"
log_info "=========================================="
NODE_IP=$(hostname -I | awk '{print $1}')
log_info "Gitea is now accessible at: http://${NODE_IP}:3000"
log_info ""
log_info "If you still have issues, check:"
log_info "1. SELinux audit log: ausearch -m avc -ts recent"
log_info "2. Gitea logs: journalctl -u gitea -f"
log_info "3. Binary context: ls -lZ ${GITEA_BINARY}"
echo ""

# Made with Bob
