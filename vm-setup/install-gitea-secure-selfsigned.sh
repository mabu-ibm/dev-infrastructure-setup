#!/bin/bash
################################################################################
# Gitea Secure Installation Script for Local Domains (Self-Signed Certificate)
# Purpose: Install Gitea with HTTPS using self-signed certificates
# Usage: sudo ./install-gitea-secure-selfsigned.sh
# Note: Browser will show security warnings (expected for self-signed certs)
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

log_info "Gitea Secure Installation (Self-Signed Certificate)"
log_info "===================================================="
echo ""

# Get configuration
log_info "Configuration"
log_info "============="
read -p "Enter your domain name (e.g., gitea.lab.allwaysbeginner.com): " DOMAIN
read -p "Enter Gitea HTTP port [3000]: " GITEA_PORT
GITEA_PORT=${GITEA_PORT:-3000}
read -p "Enter HTTPS port [443]: " HTTPS_PORT
HTTPS_PORT=${HTTPS_PORT:-443}
read -p "Certificate validity in days [3650 = 10 years]: " CERT_DAYS
CERT_DAYS=${CERT_DAYS:-3650}

if [ -z "$DOMAIN" ]; then
    log_error "Domain is required!"
    exit 1
fi

log_info ""
log_info "Configuration Summary:"
log_info "  Domain: $DOMAIN"
log_info "  Gitea Port: $GITEA_PORT (internal)"
log_info "  HTTPS Port: $HTTPS_PORT (external)"
log_info "  Certificate Validity: $CERT_DAYS days"
log_info "  URL: https://$DOMAIN"
log_info ""
log_warn "Note: Self-signed certificates will show browser warnings"
log_info "This is normal and expected for local/lab environments"
echo ""
read -p "Continue with installation? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    exit 0
fi
echo ""

# Step 1: Install dependencies
log_step "1. Installing dependencies..."
dnf install -y git wget curl tar openssl nginx

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

# Step 7: Generate self-signed SSL certificate
log_step "7. Generating self-signed SSL certificate..."
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

# Generate private key
openssl genrsa -out gitea.key 4096

# Generate certificate signing request
openssl req -new -key gitea.key -out gitea.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$DOMAIN"

# Generate self-signed certificate
openssl x509 -req -days $CERT_DAYS -in gitea.csr -signkey gitea.key -out gitea.crt

# Set permissions
chmod 600 gitea.key
chmod 644 gitea.crt

log_info "✓ Self-signed certificate generated"
log_info "  Certificate: /etc/nginx/ssl/gitea.crt"
log_info "  Private Key: /etc/nginx/ssl/gitea.key"
log_info "  Valid for: $CERT_DAYS days"
echo ""

# Step 8: Configure Nginx as reverse proxy
log_step "8. Configuring Nginx for HTTPS..."
cat > /etc/nginx/conf.d/gitea.conf <<EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen $HTTPS_PORT ssl http2;
    listen [::]:$HTTPS_PORT ssl http2;
    server_name $DOMAIN;
    
    # SSL certificate
    ssl_certificate /etc/nginx/ssl/gitea.crt;
    ssl_certificate_key /etc/nginx/ssl/gitea.key;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log /var/log/nginx/gitea-access.log;
    error_log /var/log/nginx/gitea-error.log;
    
    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:$GITEA_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Increase max body size for large repos
    client_max_body_size 512M;
}
EOF

# Test Nginx configuration
if nginx -t; then
    log_info "✓ Nginx configuration valid"
else
    log_error "Nginx configuration test failed"
    exit 1
fi
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

# Step 10: Configure SELinux (if enabled)
log_step "10. Configuring SELinux..."
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    setsebool -P httpd_can_network_connect 1
    log_info "✓ SELinux configured"
else
    log_info "SELinux not enabled or not installed"
fi
echo ""

# Step 11: Start services
log_step "11. Starting services..."

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

# Start Nginx
systemctl enable nginx
systemctl start nginx
sleep 3

if systemctl is-active --quiet nginx; then
    log_info "✓ Nginx started successfully"
else
    log_error "Nginx failed to start"
    journalctl -u nginx -n 50 --no-pager
    exit 1
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
log_warn "⚠️  IMPORTANT: Browser Security Warning"
log_warn "Your browser will show a security warning because this is a self-signed certificate."
log_warn "This is NORMAL and EXPECTED for local/lab environments."
echo ""
log_info "To bypass the warning:"
log_info "  Chrome/Edge: Click 'Advanced' → 'Proceed to $DOMAIN (unsafe)'"
log_info "  Firefox: Click 'Advanced' → 'Accept the Risk and Continue'"
log_info "  Safari: Click 'Show Details' → 'visit this website'"
echo ""
log_info "Service Status:"
systemctl status gitea --no-pager | head -10
echo ""
systemctl status nginx --no-pager | head -10
echo ""
log_info "Configuration Files:"
log_info "  Gitea config: /etc/gitea/app.ini"
log_info "  Nginx config: /etc/nginx/conf.d/gitea.conf"
log_info "  SSL certificate: /etc/nginx/ssl/gitea.crt"
log_info "  SSL private key: /etc/nginx/ssl/gitea.key"
log_info "  Gitea data: /var/lib/gitea"
echo ""
log_info "Useful Commands:"
log_info "  View Gitea logs:  journalctl -u gitea -f"
log_info "  View Nginx logs:  tail -f /var/log/nginx/gitea-*.log"
log_info "  Restart Gitea:    systemctl restart gitea"
log_info "  Restart Nginx:    systemctl restart nginx"
log_info "  Test Nginx:       nginx -t"
echo ""
log_info "Certificate Information:"
log_info "  Type: Self-Signed"
log_info "  Valid for: $CERT_DAYS days ($(date -d "+$CERT_DAYS days" +%Y-%m-%d))"
log_info "  Domain: $DOMAIN"
log_info "  Algorithm: RSA 4096-bit"
echo ""
log_info "To trust the certificate on client machines:"
log_info "  1. Download: curl -k https://$DOMAIN/ssl/gitea.crt > gitea.crt"
log_info "  2. Import into browser or system trust store"
log_info "  3. Or use: curl -k https://$DOMAIN (bypass verification)"
echo ""
log_info "Next Steps:"
log_info "1. Open https://$DOMAIN in your browser"
log_info "2. Accept the security warning (expected for self-signed)"
log_info "3. Complete the Gitea installation wizard"
log_info "4. Create your admin account"
log_info "5. Configure Gitea Actions (optional)"
echo ""
log_info "Security Notes:"
log_info "  ✓ HTTPS enabled with self-signed certificate"
log_info "  ✓ HTTP automatically redirects to HTTPS"
log_info "  ✓ Security headers configured"
log_info "  ✓ TLS 1.2 and 1.3 enabled"
log_info "  ⚠️  Browser warnings are normal for self-signed certs"
echo ""
log_info "============================================"

# Made with Bob