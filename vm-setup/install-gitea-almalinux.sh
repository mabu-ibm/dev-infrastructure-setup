#!/bin/bash
################################################################################
# Gitea Installation Script for AlmaLinux 10
# Purpose: Install Gitea with Docker, Container Registry, and Actions Runner
# Usage: sudo ./install-gitea-almalinux.sh
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

log_info "Starting Gitea installation on AlmaLinux 10..."

# Configuration
GITEA_VERSION="1.21.5"
GITEA_USER="git"
GITEA_HOME="/var/lib/gitea"
GITEA_CUSTOM="${GITEA_HOME}/custom"
GITEA_DATA="${GITEA_HOME}/data"
GITEA_LOG="/var/log/gitea"
GITEA_PORT="3000"
SSH_PORT="2222"

# Database Configuration
DB_TYPE="sqlite3"  # Default to SQLite
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="gitea"
DB_USER="gitea"
DB_PASSWORD=""

# Step 1: Database Selection
log_step "Step 1: Database Selection"
echo ""
echo "Choose database type for Gitea:"
echo "1) SQLite (default, simple, no setup required)"
echo "2) MySQL (recommended for production)"
echo ""
read -p "Enter choice [1-2] (default: 1): " db_choice
db_choice=${db_choice:-1}

if [[ "$db_choice" == "2" ]]; then
    DB_TYPE="mysql"
    log_info "MySQL selected"
    echo ""
    read -p "MySQL Host (default: localhost): " input_host
    DB_HOST=${input_host:-localhost}
    
    read -p "MySQL Port (default: 3306): " input_port
    DB_PORT=${input_port:-3306}
    
    read -p "Database Name (default: gitea): " input_dbname
    DB_NAME=${input_dbname:-gitea}
    
    read -p "Database User (default: gitea): " input_user
    DB_USER=${input_user:-gitea}
    
    read -sp "Database Password: " DB_PASSWORD
    echo ""
    
    if [[ -z "$DB_PASSWORD" ]]; then
        log_error "Database password cannot be empty for MySQL"
        exit 1
    fi
    
    log_info "MySQL Configuration:"
    log_info "  Host: ${DB_HOST}"
    log_info "  Port: ${DB_PORT}"
    log_info "  Database: ${DB_NAME}"
    log_info "  User: ${DB_USER}"
else
    DB_TYPE="sqlite3"
    log_info "SQLite selected (default)"
fi

# Step 2: Update system
log_step "Step 2: Updating system packages..."
dnf update -y
dnf install -y git wget curl tar

# Step 3: Install MySQL client if needed
if [[ "$DB_TYPE" == "mysql" ]]; then
    log_step "Step 3: Installing MySQL client..."
    dnf install -y mysql
    
    # Test MySQL connection
    log_info "Testing MySQL connection..."
    if mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1;" > /dev/null 2>&1; then
        log_info "✓ MySQL connection successful"
    else
        log_error "✗ Cannot connect to MySQL server"
        log_error "Please verify MySQL is running and credentials are correct"
        exit 1
    fi
    
    # Create database if it doesn't exist
    log_info "Creating database ${DB_NAME} if not exists..."
    mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || {
        log_error "Failed to create database"
        exit 1
    }
    log_info "✓ Database ready"
else
    log_step "Step 3: Skipping MySQL installation (SQLite selected)"
fi

# Step 4: Install required kernel modules
log_step "Step 4: Installing kernel modules..."
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

# Step 5: Install Docker
log_step "Step 5: Installing Docker..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker daemon for AlmaLinux 10
log_info "Configuring Docker daemon..."
mkdir -p /etc/docker
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

log_info "✓ Docker daemon configured"

# Step 6: Configure firewall for Docker
log_step "Step 6: Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    log_info "Restarting firewalld..."
    systemctl restart firewalld
    
    log_info "Removing docker0 from trusted zone (if exists)..."
    firewall-cmd --permanent --zone=trusted --remove-interface=docker0 2>/dev/null || true
    firewall-cmd --reload
    
    log_info "Adding Gitea ports to firewall..."
    firewall-cmd --permanent --add-port=${GITEA_PORT}/tcp
    firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
    firewall-cmd --reload
    
    log_info "✓ Firewall configured"
else
    log_warn "firewalld not found, skipping firewall configuration"
fi

# Step 7: Start Docker
log_step "Step 7: Starting Docker..."
systemctl daemon-reload
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
log_info "Waiting for Docker to be ready..."
sleep 5

if systemctl is-active --quiet docker; then
    log_info "✓ Docker is running"
else
    log_error "✗ Docker failed to start"
    log_info "Checking logs..."
    journalctl -u docker -n 30 --no-pager
    exit 1
fi

# Test Docker
log_info "Testing Docker..."
if docker run --rm hello-world > /dev/null 2>&1; then
    log_info "✓ Docker is working correctly"
else
    log_warn "Docker test had issues, but continuing..."
fi

# Step 8: Create Gitea user
log_step "Step 8: Creating Gitea user..."
if ! id -u ${GITEA_USER} > /dev/null 2>&1; then
    useradd --system --shell /bin/bash --comment 'Git Version Control' --create-home --home ${GITEA_HOME} ${GITEA_USER}
    log_info "✓ User ${GITEA_USER} created"
else
    log_warn "User ${GITEA_USER} already exists"
fi

# Step 9: Create directory structure
log_step "Step 9: Creating directory structure..."
mkdir -p ${GITEA_CUSTOM} ${GITEA_DATA} ${GITEA_LOG}
mkdir -p ${GITEA_CUSTOM}/conf
mkdir -p ${GITEA_DATA}/gitea-repositories
mkdir -p ${GITEA_DATA}/lfs
mkdir -p ${GITEA_DATA}/packages
chown -R ${GITEA_USER}:${GITEA_USER} ${GITEA_HOME} ${GITEA_LOG}
log_info "✓ Directory structure created"

# Step 10: Download Gitea binary
log_step "Step 10: Downloading Gitea ${GITEA_VERSION}..."
wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64
chmod +x /usr/local/bin/gitea
log_info "✓ Gitea binary installed"

# Step 11: Create Gitea configuration
log_step "Step 11: Creating Gitea configuration..."

# Generate database configuration based on type
if [[ "$DB_TYPE" == "mysql" ]]; then
    DB_CONFIG="[database]
DB_TYPE  = mysql
HOST     = ${DB_HOST}:${DB_PORT}
NAME     = ${DB_NAME}
USER     = ${DB_USER}
PASSWD   = ${DB_PASSWORD}
CHARSET  = utf8mb4
LOG_SQL  = false"
else
    DB_CONFIG="[database]
DB_TYPE  = sqlite3
PATH     = ${GITEA_DATA}/gitea.db
LOG_SQL  = false"
fi

cat > ${GITEA_CUSTOM}/conf/app.ini <<EOF
APP_NAME = Gitea: Git with a cup of tea
RUN_MODE = prod
RUN_USER = ${GITEA_USER}

[server]
PROTOCOL         = http
DOMAIN           = localhost
ROOT_URL         = http://localhost:${GITEA_PORT}/
HTTP_PORT        = ${GITEA_PORT}
DISABLE_SSH      = false
SSH_PORT         = ${SSH_PORT}
START_SSH_SERVER = true
LFS_START_SERVER = true
OFFLINE_MODE     = false

${DB_CONFIG}

[repository]
ROOT = ${GITEA_DATA}/gitea-repositories
DEFAULT_BRANCH = main

[repository.upload]
ENABLED = true

[lfs]
PATH = ${GITEA_DATA}/lfs

[packages]
ENABLED = true
STORAGE_TYPE = local
MINIO_BASE_PATH = packages/

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://github.com

[security]
INSTALL_LOCK   = false
SECRET_KEY     = 
INTERNAL_TOKEN = 

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW  = false
ENABLE_NOTIFY_MAIL   = false

[log]
MODE      = file
LEVEL     = Info
ROOT_PATH = ${GITEA_LOG}

[session]
PROVIDER = file

[picture]
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = true

[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false

[webhook]
ALLOWED_HOST_LIST = *

[mailer]
ENABLED = false

[cache]
ADAPTER = memory

[indexer]
ISSUE_INDEXER_TYPE = bleve
REPO_INDEXER_ENABLED = true
EOF

chown ${GITEA_USER}:${GITEA_USER} ${GITEA_CUSTOM}/conf/app.ini
chmod 640 ${GITEA_CUSTOM}/conf/app.ini
log_info "✓ Gitea configuration created"

# Step 12: Create systemd service
log_step "Step 12: Creating systemd service..."
cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
After=docker.service

[Service]
Type=simple
User=${GITEA_USER}
Group=${GITEA_USER}
WorkingDirectory=${GITEA_HOME}
ExecStart=/usr/local/bin/gitea web --config ${GITEA_CUSTOM}/conf/app.ini
Restart=always
Environment=USER=${GITEA_USER} HOME=${GITEA_HOME} GITEA_WORK_DIR=${GITEA_HOME}

[Install]
WantedBy=multi-user.target
EOF

log_info "✓ Systemd service created"

# Step 13: Start Gitea service
log_step "Step 13: Starting Gitea service..."
systemctl daemon-reload
systemctl enable gitea
systemctl start gitea

# Wait for Gitea to start
log_info "Waiting for Gitea to start..."
sleep 10

# Step 14: Check service status
if systemctl is-active --quiet gitea; then
    log_info "✓ Gitea is running successfully!"
else
    log_error "✗ Gitea failed to start"
    log_info "Checking logs..."
    journalctl -u gitea -n 50 --no-pager
    exit 1
fi

# Step 15: Display information
NODE_IP=$(hostname -I | awk '{print $1}')

log_info "============================================"
log_info "Gitea Installation Complete!"
log_info "============================================"
log_info "Web Interface: http://${NODE_IP}:${GITEA_PORT}"
log_info "SSH Port: ${SSH_PORT}"
log_info "Database Type: ${DB_TYPE}"
if [[ "$DB_TYPE" == "mysql" ]]; then
    log_info "Database Host: ${DB_HOST}:${DB_PORT}"
    log_info "Database Name: ${DB_NAME}"
    log_info "Database User: ${DB_USER}"
fi
log_info "Data Directory: ${GITEA_DATA}"
log_info "Log Directory: ${GITEA_LOG}"
log_info ""
log_info "Next Steps:"
log_info "1. Open web interface and complete initial setup"
log_info "2. Create admin user"
log_info "3. Enable Container Registry in Settings"
log_info "4. Configure Gitea Actions runner: ./setup-gitea-actions-runner.sh"
log_info ""
log_info "Useful Commands:"
log_info "  Status:  systemctl status gitea"
log_info "  Logs:    journalctl -u gitea -f"
log_info "  Restart: systemctl restart gitea"
log_info "  Docker:  systemctl status docker"
log_info "============================================"

# Save installation info
DB_INFO="Database Configuration:
- Type: ${DB_TYPE}"

if [[ "$DB_TYPE" == "mysql" ]]; then
    DB_INFO="${DB_INFO}
- Host: ${DB_HOST}:${DB_PORT}
- Database: ${DB_NAME}
- User: ${DB_USER}
- Connection: mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p ${DB_NAME}"
else
    DB_INFO="${DB_INFO}
- Path: ${GITEA_DATA}/gitea.db"
fi

cat > /root/gitea-install-info.txt <<EOF
Gitea Installation Information
===============================
Installation Date: $(date)
Gitea Version: ${GITEA_VERSION}
Node IP: ${NODE_IP}

Access Information:
- Web Interface: http://${NODE_IP}:${GITEA_PORT}
- SSH Port: ${SSH_PORT}
- SSH Clone: git clone ssh://git@${NODE_IP}:${SSH_PORT}/username/repo.git

${DB_INFO}

Directories:
- Home: ${GITEA_HOME}
- Data: ${GITEA_DATA}
- Logs: ${GITEA_LOG}
- Config: ${GITEA_CUSTOM}/conf/app.ini

Docker Configuration:
- Kernel Modules: xt_addrtype, br_netfilter, overlay
- Storage Driver: overlay2
- Cgroup Driver: systemd

Useful Commands:
- Gitea Status: systemctl status gitea
- Gitea Logs: journalctl -u gitea -f
- Docker Status: systemctl status docker
- Docker Logs: journalctl -u docker -f

Next Steps:
1. Complete web setup at http://${NODE_IP}:${GITEA_PORT}
2. Create admin user
3. Enable Container Registry
4. Setup Actions Runner: ./setup-gitea-actions-runner.sh
EOF

log_info "Installation info saved to /root/gitea-install-info.txt"

# Made with Bob
