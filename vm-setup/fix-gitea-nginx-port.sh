#!/bin/bash
################################################################################
# Fix Gitea Nginx Port Configuration
# Purpose: Change Nginx from port 3001 to port 443 (HTTPS)
# Usage: sudo ./fix-gitea-nginx-port.sh
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

log_info "Fixing Gitea Nginx Port Configuration"
log_info "======================================"
echo ""

# Step 1: Find Nginx config
log_step "1. Finding Nginx configuration..."
NGINX_CONF=""
if [ -f /etc/nginx/conf.d/gitea.conf ]; then
    NGINX_CONF="/etc/nginx/conf.d/gitea.conf"
elif [ -f /etc/nginx/sites-enabled/gitea ]; then
    NGINX_CONF="/etc/nginx/sites-enabled/gitea"
elif [ -f /etc/nginx/nginx.conf ]; then
    NGINX_CONF="/etc/nginx/nginx.conf"
fi

if [ -z "$NGINX_CONF" ]; then
    log_error "Nginx configuration not found"
    exit 1
fi

log_info "✓ Found Nginx config: $NGINX_CONF"
echo ""

# Step 2: Backup current config
log_step "2. Backing up current configuration..."
BACKUP="${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$NGINX_CONF" "$BACKUP"
log_info "✓ Backup created: $BACKUP"
echo ""

# Step 3: Show current configuration
log_step "3. Current configuration:"
grep -E "listen.*3001|listen.*443" "$NGINX_CONF" || log_info "No listen directives found"
echo ""

# Step 4: Fix the port
log_step "4. Changing port from 3001 to 443..."
sed -i 's/listen 3001/listen 443/g' "$NGINX_CONF"
sed -i 's/listen \[::]:3001/listen [::]:443/g' "$NGINX_CONF"
log_info "✓ Port changed to 443"
echo ""

# Step 5: Show new configuration
log_step "5. New configuration:"
grep -E "listen.*443" "$NGINX_CONF"
echo ""

# Step 6: Test Nginx configuration
log_step "6. Testing Nginx configuration..."
if nginx -t; then
    log_info "✓ Nginx configuration is valid"
else
    log_error "Nginx configuration test failed"
    log_info "Restoring backup..."
    cp "$BACKUP" "$NGINX_CONF"
    exit 1
fi
echo ""

# Step 7: Restart Nginx
log_step "7. Restarting Nginx..."
systemctl restart nginx
sleep 3

if systemctl is-active --quiet nginx; then
    log_info "✓ Nginx restarted successfully"
else
    log_error "Nginx failed to restart"
    systemctl status nginx --no-pager
    exit 1
fi
echo ""

# Step 8: Verify port 443 is listening
log_step "8. Verifying port 443..."
sleep 2
if ss -tlnp | grep -q ":443"; then
    log_info "✓ Nginx is now listening on port 443"
    ss -tlnp | grep ":443"
else
    log_error "Port 443 is not listening"
fi
echo ""

# Step 9: Test HTTPS access
log_step "9. Testing HTTPS access..."
DOMAIN=$(grep "server_name" "$NGINX_CONF" | head -1 | awk '{print $2}' | tr -d ';')
if [ -n "$DOMAIN" ]; then
    log_info "Testing https://$DOMAIN..."
    if curl -k -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
        log_info "✓ HTTPS is working!"
    else
        log_warn "HTTPS test returned unexpected status"
    fi
fi
echo ""

log_info "============================================"
log_info "Nginx Port Fix Complete!"
log_info "============================================"
echo ""
log_info "Changes made:"
log_info "  ✓ Port changed from 3001 to 443"
log_info "  ✓ Nginx restarted"
log_info "  ✓ Configuration backed up to: $BACKUP"
echo ""
log_info "Access Gitea:"
log_info "  HTTPS: https://almabuild3.lab.allwaysbeginner.com"
log_info "  HTTP will redirect to HTTPS"
echo ""
log_info "Verify:"
log_info "  ss -tlnp | grep 443"
log_info "  curl -k https://almabuild3.lab.allwaysbeginner.com"
echo ""
log_info "============================================"

# Made with Bob