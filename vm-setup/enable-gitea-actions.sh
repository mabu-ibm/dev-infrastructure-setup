#!/bin/bash
################################################################################
# Enable Gitea Actions
# Purpose: Enable Actions feature in Gitea configuration
# Usage: sudo ./enable-gitea-actions.sh
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Enabling Gitea Actions..."

# Configuration file location
GITEA_CONFIG="/var/lib/gitea/custom/conf/app.ini"
GITEA_CUSTOM_DIR="/var/lib/gitea/custom/conf"

# Create custom config directory if it doesn't exist
if [ ! -d "$GITEA_CUSTOM_DIR" ]; then
    log_info "Creating custom config directory..."
    mkdir -p "$GITEA_CUSTOM_DIR"
    chown -R gitea:gitea /var/lib/gitea/custom
fi

# Check if config file exists
if [ ! -f "$GITEA_CONFIG" ]; then
    log_info "Creating new app.ini configuration file..."
    touch "$GITEA_CONFIG"
    chown gitea:gitea "$GITEA_CONFIG"
fi

# Check if Actions is already enabled
if grep -q "^\[actions\]" "$GITEA_CONFIG"; then
    log_warn "Actions section already exists in configuration"
    
    # Check if ENABLED = true
    if grep -A 1 "^\[actions\]" "$GITEA_CONFIG" | grep -q "ENABLED.*=.*true"; then
        log_info "✓ Actions is already enabled"
        
        # Ask if user wants to continue
        read -p "Do you want to restart Gitea anyway? (y/N): " RESTART
        if [[ "$RESTART" =~ ^[Yy]$ ]]; then
            log_info "Restarting Gitea..."
            systemctl restart gitea
            log_info "✓ Gitea restarted"
        fi
        exit 0
    else
        log_warn "Actions section exists but ENABLED is not set to true"
        log_info "Updating configuration..."
        
        # Update ENABLED to true
        sed -i '/^\[actions\]/,/^\[/ s/ENABLED.*=.*/ENABLED = true/' "$GITEA_CONFIG"
    fi
else
    log_info "Adding Actions configuration..."
    
    # Add Actions section to config
    cat >> "$GITEA_CONFIG" <<'EOF'

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://github.com

EOF
    
    log_info "✓ Actions configuration added"
fi

# Ensure proper ownership
chown gitea:gitea "$GITEA_CONFIG"

# Restart Gitea
log_info "Restarting Gitea to apply changes..."
systemctl restart gitea

# Wait for Gitea to start
log_info "Waiting for Gitea to start..."
sleep 5

# Check if Gitea is running
if systemctl is-active --quiet gitea; then
    log_info "✓ Gitea is running"
else
    log_error "Gitea failed to start"
    log_info "Check logs: journalctl -u gitea -n 50"
    exit 1
fi

# Display success message
log_info "============================================"
log_info "Gitea Actions Enabled Successfully!"
log_info "============================================"
log_info ""
log_info "Next steps:"
log_info "1. Log into Gitea web interface"
log_info "2. Go to Site Administration (admin user)"
log_info "3. You should now see 'Actions' in the menu"
log_info "4. Go to Actions → Runners to verify your runner"
log_info "5. Create a repository and push code with .gitea/workflows/"
log_info "6. The Actions tab will appear in your repository"
log_info ""
log_info "Configuration file: $GITEA_CONFIG"
log_info "Gitea status: systemctl status gitea"
log_info "Gitea logs: journalctl -u gitea -f"
log_info "============================================"

# Show current Actions configuration
log_info ""
log_info "Current Actions configuration:"
grep -A 2 "^\[actions\]" "$GITEA_CONFIG" || log_warn "Could not read configuration"

# Made with Bob