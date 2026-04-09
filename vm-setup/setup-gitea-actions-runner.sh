#!/bin/bash
################################################################################
# Gitea Actions Runner Setup Script for AlmaLinux 10
# Purpose: Install and configure Gitea Actions runner for CI/CD
# Usage: sudo ./setup-gitea-actions-runner.sh
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Setting up Gitea Actions Runner..."

# Configuration
RUNNER_VERSION="0.2.6"
RUNNER_USER="gitea-runner"
RUNNER_HOME="/var/lib/gitea-runner"
RUNNER_CONFIG="${RUNNER_HOME}/config.yaml"

# Step 1: Create runner user
log_info "Creating runner user..."
if ! id -u ${RUNNER_USER} > /dev/null 2>&1; then
    useradd --system --shell /bin/bash --create-home --home ${RUNNER_HOME} ${RUNNER_USER}
    usermod -aG docker ${RUNNER_USER}
    log_info "User ${RUNNER_USER} created and added to docker group"
else
    log_warn "User ${RUNNER_USER} already exists"
    usermod -aG docker ${RUNNER_USER}
fi

# Step 2: Download act_runner binary
log_info "Downloading act_runner ${RUNNER_VERSION}..."
wget -O /usr/local/bin/act_runner https://dl.gitea.com/act_runner/${RUNNER_VERSION}/act_runner-${RUNNER_VERSION}-linux-amd64
chmod +x /usr/local/bin/act_runner
log_info "act_runner binary installed"

# Step 3: Create runner home directory
log_info "Creating runner home directory..."
mkdir -p ${RUNNER_HOME}
chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}
log_info "✓ Runner home directory created: ${RUNNER_HOME}"

# Step 4: Get Gitea configuration
log_info ""
log_info "Gitea Configuration"
log_info "==================="
read -p "Enter your Gitea hostname (e.g., almabuild2.lab.allwaysbeginner.com): " GITEA_HOST
read -p "Enter Gitea port [3000]: " GITEA_PORT
GITEA_PORT=${GITEA_PORT:-3000}
GITEA_URL="http://${GITEA_HOST}:${GITEA_PORT}"

log_info ""
log_info "Please get the registration token from Gitea:"
log_info "1. Log into Gitea as admin"
log_info "2. Go to: Site Administration → Actions → Runners"
log_info "3. Click 'Create new Runner'"
log_info "4. Copy the registration token"
log_info ""
read -p "Enter the registration token: " GITEA_TOKEN

if [ -z "$GITEA_TOKEN" ]; then
    log_error "Registration token is required!"
    exit 1
fi

read -p "Enter runner name [build-runner-$(hostname)]: " RUNNER_NAME
RUNNER_NAME=${RUNNER_NAME:-build-runner-$(hostname)}

log_info ""
log_info "Configuration Summary:"
log_info "  Gitea URL: ${GITEA_URL}"
log_info "  Runner name: ${RUNNER_NAME}"
log_info "  Runner home: ${RUNNER_HOME}"
log_info ""

# Step 5: Register the runner
log_info "Registering runner with Gitea..."
sudo -u ${RUNNER_USER} bash -c "cd ${RUNNER_HOME} && /usr/local/bin/act_runner register \
  --instance ${GITEA_URL} \
  --token ${GITEA_TOKEN} \
  --name ${RUNNER_NAME} \
  --labels ubuntu-latest,almalinux-latest"

if [ $? -ne 0 ]; then
    log_error "Runner registration failed!"
    exit 1
fi

log_info "✓ Runner registered successfully"

# Step 6: Generate configuration
log_info "Generating runner configuration..."
sudo -u ${RUNNER_USER} bash -c "cd ${RUNNER_HOME} && /usr/local/bin/act_runner generate-config > ${RUNNER_CONFIG}"

if [ ! -f "${RUNNER_CONFIG}" ]; then
    log_error "Failed to generate config file!"
    exit 1
fi

chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_CONFIG}
log_info "✓ Configuration generated: ${RUNNER_CONFIG}"

# Step 7: Create systemd service
log_info "Creating systemd service..."
cat > /etc/systemd/system/gitea-runner.service <<EOF
[Unit]
Description=Gitea Actions Runner
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=${RUNNER_HOME}
ExecStart=/usr/local/bin/act_runner daemon -c ${RUNNER_CONFIG}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log_info "✓ Systemd service created"

# Step 8: Enable and start the service
log_info "Enabling and starting gitea-runner service..."
systemctl enable gitea-runner
systemctl start gitea-runner

sleep 3

if systemctl is-active --quiet gitea-runner; then
    log_info "✓ Service started successfully"
else
    log_error "Service failed to start"
    log_info "Checking logs..."
    journalctl -u gitea-runner -n 20 --no-pager
    exit 1
fi

log_info ""
log_info "============================================"
log_info "Gitea Actions Runner Setup Complete!"
log_info "============================================"
log_info ""
log_info "Configuration Summary:"
log_info "  Gitea URL: ${GITEA_URL}"
log_info "  Runner name: ${RUNNER_NAME}"
log_info "  Runner home: ${RUNNER_HOME}"
log_info "  Config file: ${RUNNER_CONFIG}"
log_info "  Service: gitea-runner.service"
log_info ""
log_info "Service Status:"
systemctl status gitea-runner --no-pager | head -15
log_info ""
log_info "Useful Commands:"
log_info "  Check status: systemctl status gitea-runner"
log_info "  View logs:    journalctl -u gitea-runner -f"
log_info "  Restart:      systemctl restart gitea-runner"
log_info ""
log_info "Check the runner in Gitea UI:"
log_info "  ${GITEA_URL}/admin/actions/runners"
log_info ""
log_info "The runner should appear as 'Idle' and ready to accept jobs!"
log_info "============================================"

# Made with Bob
