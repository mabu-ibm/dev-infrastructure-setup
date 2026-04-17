#!/bin/bash
################################################################################
# Gitea Installation Diagnostics
# Purpose: Diagnose why Gitea is not reachable
# Usage: sudo ./diagnose-gitea-installation.sh
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

log_info "Gitea Installation Diagnostics"
log_info "==============================="
echo ""

# Step 1: Check if Gitea service is running
log_step "1. Checking Gitea service status..."
if systemctl is-active --quiet gitea; then
    log_info "✓ Gitea service is running"
    systemctl status gitea --no-pager | head -15
else
    log_error "✗ Gitea service is NOT running"
    systemctl status gitea --no-pager | head -15
    echo ""
    log_info "Recent Gitea logs:"
    journalctl -u gitea -n 50 --no-pager
fi
echo ""

# Step 2: Check if Gitea binary exists and is executable
log_step "2. Checking Gitea binary..."
if [ -f /usr/local/bin/gitea ]; then
    log_info "✓ Gitea binary exists"
    ls -lZ /usr/local/bin/gitea 2>/dev/null || ls -l /usr/local/bin/gitea
    
    if [ -x /usr/local/bin/gitea ]; then
        log_info "✓ Gitea binary is executable"
    else
        log_error "✗ Gitea binary is NOT executable"
        log_info "Fix: sudo chmod +x /usr/local/bin/gitea"
    fi
else
    log_error "✗ Gitea binary NOT found at /usr/local/bin/gitea"
fi
echo ""

# Step 3: Check if Gitea is listening on ports
log_step "3. Checking listening ports..."
log_info "Checking for Gitea on port 3000..."
if ss -tlnp | grep -q ":3000"; then
    log_info "✓ Something is listening on port 3000"
    ss -tlnp | grep ":3000"
else
    log_warn "✗ Nothing listening on port 3000"
fi

log_info "Checking for Gitea on port 3001..."
if ss -tlnp | grep -q ":3001"; then
    log_info "✓ Something is listening on port 3001"
    ss -tlnp | grep ":3001"
else
    log_warn "✗ Nothing listening on port 3001"
fi

log_info "Checking for HTTPS on port 443..."
if ss -tlnp | grep -q ":443"; then
    log_info "✓ Something is listening on port 443"
    ss -tlnp | grep ":443"
else
    log_warn "✗ Nothing listening on port 443"
fi
echo ""

# Step 4: Check Nginx/Caddy status
log_step "4. Checking reverse proxy..."
if systemctl list-units --full -all | grep -q nginx.service; then
    log_info "Nginx service found"
    if systemctl is-active --quiet nginx; then
        log_info "✓ Nginx is running"
        systemctl status nginx --no-pager | head -10
    else
        log_error "✗ Nginx is NOT running"
        systemctl status nginx --no-pager | head -10
    fi
elif systemctl list-units --full -all | grep -q caddy.service; then
    log_info "Caddy service found"
    if systemctl is-active --quiet caddy; then
        log_info "✓ Caddy is running"
        systemctl status caddy --no-pager | head -10
    else
        log_error "✗ Caddy is NOT running"
        systemctl status caddy --no-pager | head -10
    fi
else
    log_warn "No reverse proxy (Nginx/Caddy) found"
fi
echo ""

# Step 5: Check Gitea configuration
log_step "5. Checking Gitea configuration..."
if [ -f /etc/gitea/app.ini ]; then
    log_info "✓ Gitea config exists: /etc/gitea/app.ini"
    echo ""
    log_info "Server configuration:"
    grep -A 10 "^\[server\]" /etc/gitea/app.ini | head -15
else
    log_error "✗ Gitea config NOT found at /etc/gitea/app.ini"
fi
echo ""

# Step 6: Check firewall
log_step "6. Checking firewall..."
if command -v firewall-cmd &> /dev/null; then
    log_info "Firewall status:"
    firewall-cmd --list-all | grep -E "services|ports"
    echo ""
    log_info "Checking specific ports:"
    if firewall-cmd --list-ports | grep -q "3000"; then
        log_info "✓ Port 3000 is open"
    else
        log_warn "✗ Port 3000 is NOT open in firewall"
    fi
    if firewall-cmd --list-services | grep -q "http"; then
        log_info "✓ HTTP (port 80) is open"
    else
        log_warn "✗ HTTP is NOT open in firewall"
    fi
    if firewall-cmd --list-services | grep -q "https"; then
        log_info "✓ HTTPS (port 443) is open"
    else
        log_warn "✗ HTTPS is NOT open in firewall"
    fi
else
    log_warn "firewalld not found"
fi
echo ""

# Step 7: Check SELinux
log_step "7. Checking SELinux..."
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    log_info "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        log_info "Checking Gitea binary context:"
        ls -Z /usr/local/bin/gitea 2>/dev/null || log_warn "Could not check SELinux context"
        
        log_info "Checking for SELinux denials:"
        ausearch -m avc -ts recent 2>/dev/null | grep gitea | tail -5 || log_info "No recent SELinux denials for gitea"
    fi
else
    log_info "SELinux not installed"
fi
echo ""

# Step 8: Test local connectivity
log_step "8. Testing local connectivity..."
log_info "Testing localhost:3000..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null | grep -q "200\|301\|302"; then
    log_info "✓ Gitea responds on localhost:3000"
else
    log_error "✗ Gitea does NOT respond on localhost:3000"
fi

log_info "Testing localhost:3001..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3001 2>/dev/null | grep -q "200\|301\|302"; then
    log_info "✓ Gitea responds on localhost:3001"
else
    log_warn "✗ Gitea does NOT respond on localhost:3001"
fi
echo ""

# Step 9: Check Gitea logs
log_step "9. Recent Gitea logs..."
if [ -f /var/lib/gitea/log/gitea.log ]; then
    log_info "Last 20 lines of Gitea log:"
    tail -20 /var/lib/gitea/log/gitea.log
else
    log_warn "Gitea log file not found at /var/lib/gitea/log/gitea.log"
    log_info "Checking systemd journal:"
    journalctl -u gitea -n 20 --no-pager
fi
echo ""

# Step 10: Summary and recommendations
log_info "============================================"
log_info "Diagnostic Summary"
log_info "============================================"
echo ""

log_info "Quick Fixes:"
echo ""
log_info "1. If Gitea service is not running:"
echo "   sudo systemctl start gitea"
echo "   sudo journalctl -u gitea -f"
echo ""
log_info "2. If port 3000 is not listening:"
echo "   Check /etc/gitea/app.ini for correct HTTP_PORT"
echo "   sudo systemctl restart gitea"
echo ""
log_info "3. If firewall is blocking:"
echo "   sudo firewall-cmd --permanent --add-port=3000/tcp"
echo "   sudo firewall-cmd --permanent --add-service=http"
echo "   sudo firewall-cmd --permanent --add-service=https"
echo "   sudo firewall-cmd --reload"
echo ""
log_info "4. If SELinux is blocking:"
echo "   sudo chcon -t bin_t /usr/local/bin/gitea"
echo "   sudo restorecon -v /usr/local/bin/gitea"
echo "   sudo systemctl restart gitea"
echo ""
log_info "5. If reverse proxy (Nginx/Caddy) is not running:"
echo "   sudo systemctl start nginx  # or caddy"
echo "   sudo systemctl status nginx"
echo ""
log_info "6. Test direct access:"
echo "   curl http://localhost:3000"
echo "   curl https://your-domain.com"
echo ""
log_info "============================================"

# Made with Bob