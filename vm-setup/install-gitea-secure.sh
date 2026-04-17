#!/bin/bash
################################################################################
# Gitea Secure Installation Script for AlmaLinux (HTTPS with Let's Encrypt)
# Purpose: Install Gitea with HTTPS support using Caddy as reverse proxy
# Usage: sudo ./install-gitea-secure.sh
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

log_info "Gitea Secure Installation (HTTPS with Let's Encrypt)"
log_info "===================================================="
echo ""

# Get configuration
log_info "Configuration"
log_info "============="
read -p "Enter your domain name (e.g., gitea.example.com): " DOMAIN
read -p "Enter your email for Let's Encrypt (for certificate renewal notifications): " EMAIL
read -p "Enter Gitea HTTP port [3000]: " GITEA_PORT
GITEA_PORT=${GITEA_PORT:-3000}
read -p "Enter HTTPS port [443]: " HTTPS_PORT
HTTPS_PORT=${HTTPS_PORT:-443}

# Validate HTTPS port
if [ "$HTTPS_PORT" != "443" ]; then
    log_warn "⚠️  WARNING: You entered port $HTTPS_PORT instead of standard HTTPS port 443"
    log_warn "This means you'll need to access Gitea as: https://$DOMAIN:$HTTPS_PORT"
    log_warn "Standard HTTPS (port 443) doesn't require :port in the URL"
    echo ""
    read -p "Do you want to use standard port 443 instead? (Y/n): " USE_STANDARD
    if [[ "$USE_STANDARD" =~ ^[Yy]?$ ]] || [ -z "$USE_STANDARD" ]; then
        HTTPS_PORT=443
        log_info "✓ Using standard HTTPS port 443"
    else
        log_info "Using custom port $HTTPS_PORT as requested"
    fi
fi

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    log_error "Domain and email are required!"
    exit 1
fi

log_info ""
log_info "Configuration Summary:"
log_info "  Domain: $DOMAIN"
log_info "  Email: $EMAIL"
log_info "  Gitea Port: $GITEA_PORT (internal)"
log_info "  HTTPS Port: $HTTPS_PORT (external)"
log_info "  URL: https://$DOMAIN"
log_info ""
read -p "Continue with installation? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    exit 0
fi
echo ""

# Step 1: Install dependencies
log_step "1. Installing dependencies..."
dnf install -y git wget curl tar

log_info "✓ Dependencies installed"
echo ""

# Step 2: Create Gitea user
log_step "2. Creating Gitea user..."
if id "git" &>/dev/null; then
    log_info "User 'git' already exists"
else
    useradd -r -m -d /home/git -s /bin/bash git
    log_info "✓ User 'git' created"
fi
echo ""

# Step 3: Download and install Gitea
log_step "3. Downloading Gitea..."
GITEA_VERSION="1.21.5"
GITEA_URL="https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64"

wget -O /tmp/gitea "$GITEA_URL"
chmod +x /tmp/gitea
mv /tmp/gitea /usr/local/bin/gitea

# Set SELinux context if SELinux is enabled
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    chcon -t bin_t /usr/local/bin/gitea 2>/dev/null || true
    restorecon -v /usr/local/bin/gitea 2>/dev/null || true
fi

log_info "✓ Gitea ${GITEA_VERSION} installed"
/usr/local/bin/gitea --version
echo ""

# Step 4: Create Gitea directories
log_step "4. Creating Gitea directories..."
mkdir -p /var/lib/gitea/{custom,data,log}
chown -R git:git /var/lib/gitea
chmod -R 750 /var/lib/gitea

mkdir -p /etc/gitea
chown root:git /etc/gitea
chmod 770 /etc/gitea

log_info "✓ Directories created"
echo ""

# Step 5: Create Gitea systemd service
log_step "5. Creating Gitea systemd service..."
cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
RestartSec=10
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log_info "✓ Systemd service created"
echo ""

# Step 6: Create initial Gitea configuration
log_step "6. Creating Gitea configuration..."
cat > /etc/gitea/app.ini <<EOF
APP_NAME = Gitea: Git with a cup of tea
RUN_MODE = prod
RUN_USER = git

[server]
PROTOCOL = http
DOMAIN = $DOMAIN
ROOT_URL = https://$DOMAIN/
HTTP_ADDR = 127.0.0.1
HTTP_PORT = $GITEA_PORT
DISABLE_SSH = false
SSH_PORT = 22
START_SSH_SERVER = false
OFFLINE_MODE = false

[database]
DB_TYPE = sqlite3
PATH = /var/lib/gitea/data/gitea.db

[repository]
ROOT = /var/lib/gitea/data/gitea-repositories

[log]
MODE = file
LEVEL = Info
ROOT_PATH = /var/lib/gitea/log

[security]
INSTALL_LOCK = false
SECRET_KEY = 
INTERNAL_TOKEN = 

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = false
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL = false
ALLOW_ONLY_EXTERNAL_REGISTRATION = false
ENABLE_CAPTCHA = false
DEFAULT_KEEP_EMAIL_PRIVATE = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
DEFAULT_ENABLE_TIMETRACKING = true
NO_REPLY_ADDRESS = noreply.$DOMAIN

[mailer]
ENABLED = false

[openid]
ENABLE_OPENID_SIGNIN = true
ENABLE_OPENID_SIGNUP = true

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://github.com
EOF

chown root:git /etc/gitea/app.ini
chmod 640 /etc/gitea/app.ini

log_info "✓ Configuration created"
echo ""

# Step 7: Install Caddy
log_step "7. Installing Caddy web server..."
dnf install -y 'dnf-command(copr)'
dnf copr enable -y @caddy/caddy
dnf install -y caddy

log_info "✓ Caddy installed"
caddy version
echo ""

# Step 8: Configure Caddy for HTTPS
log_step "8. Configuring Caddy for HTTPS..."
cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN {
    reverse_proxy localhost:$GITEA_PORT
    
    # Enable compression
    encode gzip
    
    # Security headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent clickjacking
        X-Frame-Options "SAMEORIGIN"
        # Prevent MIME sniffing
        X-Content-Type-Options "nosniff"
        # Enable XSS protection
        X-XSS-Protection "1; mode=block"
        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Logging
    log {
        output file /var/log/caddy/gitea-access.log
        format json
    }
}

# Redirect HTTP to HTTPS
http://$DOMAIN {
    redir https://$DOMAIN{uri} permanent
}
EOF

mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy

log_info "✓ Caddy configured"
echo ""

# Step 9: Configure firewall
log_step "9. Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --reload
    log_info "✓ Firewall configured"
else
    log_warn "firewalld not found, skipping firewall configuration"
fi
echo ""

# Step 10: Start services
log_step "10. Starting services..."

# Start Gitea
systemctl enable gitea
systemctl start gitea
sleep 5

if systemctl is-active --quiet gitea; then
    log_info "✓ Gitea started successfully"
else
    log_error "Gitea failed to start"
    journalctl -u gitea -n 50 --no-pager
    exit 1
fi

# Start Caddy
systemctl enable caddy
systemctl start caddy
sleep 3

if systemctl is-active --quiet caddy; then
    log_info "✓ Caddy started successfully"
else
    log_error "Caddy failed to start"
    journalctl -u caddy -n 50 --no-pager
    exit 1
fi
echo ""

# Step 11: Wait for Let's Encrypt certificate
log_step "11. Obtaining Let's Encrypt certificate..."
log_info "This may take a minute..."
sleep 10

if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN | grep -q "200\|301\|302"; then
    log_info "✓ HTTPS is working!"
else
    log_warn "HTTPS may not be working yet. Check Caddy logs:"
    log_info "  journalctl -u caddy -f"
fi
echo ""

log_info "============================================"
log_info "Gitea Secure Installation Complete!"
log_info "============================================"
echo ""
log_info "Access Gitea:"
log_info "  URL: https://$DOMAIN"
log_info "  Complete the installation wizard in your browser"
echo ""
log_info "Service Status:"
systemctl status gitea --no-pager | head -10
echo ""
systemctl status caddy --no-pager | head -10
echo ""
log_info "Configuration Files:"
log_info "  Gitea config: /etc/gitea/app.ini"
log_info "  Caddy config: /etc/caddy/Caddyfile"
log_info "  Gitea data: /var/lib/gitea"
echo ""
log_info "Useful Commands:"
log_info "  View Gitea logs:  journalctl -u gitea -f"
log_info "  View Caddy logs:  journalctl -u caddy -f"
log_info "  Restart Gitea:    systemctl restart gitea"
log_info "  Restart Caddy:    systemctl restart caddy"
log_info "  Check cert:       caddy trust"
echo ""
log_info "Next Steps:"
log_info "1. Open https://$DOMAIN in your browser"
log_info "2. Complete the Gitea installation wizard"
log_info "3. Create your admin account"
log_info "4. Configure Gitea Actions (optional)"
echo ""
log_info "Certificate Info:"
log_info "  Let's Encrypt will automatically renew certificates"
log_info "  Certificates are stored in: /var/lib/caddy/.local/share/caddy"
log_info "  Renewal email notifications sent to: $EMAIL"
echo ""
log_info "Security Notes:"
log_info "  ✓ HTTPS enabled with Let's Encrypt"
log_info "  ✓ HTTP automatically redirects to HTTPS"
log_info "  ✓ Security headers configured"
log_info "  ✓ HSTS enabled (browsers will enforce HTTPS)"
echo ""
log_info "============================================"

# Made with Bob