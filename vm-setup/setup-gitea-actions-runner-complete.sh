#!/bin/bash
################################################################################
# Complete Gitea Actions Runner Setup Script for AlmaLinux 10
# Purpose: Install and configure Gitea Actions runner with Docker-in-Docker
# Based on: Verified working configuration
# Usage: sudo ./setup-gitea-actions-runner-complete.sh
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
log_info "Gitea Actions Runner Complete Setup"
log_info "=========================================="
echo ""

# Configuration
RUNNER_VERSION="0.2.6"
RUNNER_USER="gitea-runner"
RUNNER_HOME="/var/lib/gitea-runner"
RUNNER_BINARY="/usr/local/bin/act_runner"

# Get configuration from user
log_step "Configuration"
read -p "Enter your Gitea hostname (e.g., almabuild.lab.allwaysbeginner.com): " GITEA_HOST
read -p "Enter Gitea port [3000]: " GITEA_PORT
GITEA_PORT=${GITEA_PORT:-3000}
GITEA_URL="http://${GITEA_HOST}:${GITEA_PORT}"

echo ""
log_info "Configuration:"
log_info "  Gitea URL: ${GITEA_URL}"
log_info "  Runner user: ${RUNNER_USER}"
log_info "  Runner home: ${RUNNER_HOME}"
echo ""

# Step 1: Create runner user
log_step "Step 1: Creating runner user..."
if ! id -u ${RUNNER_USER} > /dev/null 2>&1; then
    useradd --system --shell /bin/bash --create-home --home ${RUNNER_HOME} ${RUNNER_USER}
    log_info "✓ User ${RUNNER_USER} created"
else
    log_warn "User ${RUNNER_USER} already exists"
fi

# Step 2: Add runner to docker group
log_step "Step 2: Adding runner to docker group..."
usermod -aG docker ${RUNNER_USER}
log_info "✓ User ${RUNNER_USER} added to docker group"

# Step 3: Configure Docker for insecure registry
log_step "Step 3: Configuring Docker for insecure registry..."
DOCKER_CONFIG="/etc/docker/daemon.json"

if [ ! -f "$DOCKER_CONFIG" ]; then
    log_info "Creating Docker daemon configuration..."
    cat > "$DOCKER_CONFIG" <<EOF
{
  "insecure-registries": ["${GITEA_HOST}:${GITEA_PORT}"]
}
EOF
else
    log_info "Updating existing Docker daemon configuration..."
    # Backup existing config
    cp "$DOCKER_CONFIG" "${DOCKER_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add insecure registry if not present
    if ! grep -q "insecure-registries" "$DOCKER_CONFIG"; then
        # Add insecure-registries section
        python3 -c "
import json
with open('$DOCKER_CONFIG', 'r') as f:
    config = json.load(f)
config['insecure-registries'] = ['${GITEA_HOST}:${GITEA_PORT}']
with open('$DOCKER_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"
    else
        log_warn "insecure-registries already configured"
    fi
fi

log_info "✓ Docker configured for insecure registry: ${GITEA_HOST}:${GITEA_PORT}"

# Restart Docker
log_info "Restarting Docker service..."
systemctl restart docker
sleep 3

if systemctl is-active --quiet docker; then
    log_info "✓ Docker service restarted successfully"
else
    log_error "Docker service failed to restart"
    exit 1
fi

# Step 4: Download act_runner binary
log_step "Step 4: Downloading act_runner ${RUNNER_VERSION}..."
if [ -f "$RUNNER_BINARY" ]; then
    log_warn "act_runner binary already exists, backing up..."
    mv "$RUNNER_BINARY" "${RUNNER_BINARY}.backup.$(date +%Y%m%d_%H%M%S)"
fi

wget -O "$RUNNER_BINARY" "https://dl.gitea.com/act_runner/${RUNNER_VERSION}/act_runner-${RUNNER_VERSION}-linux-amd64"
chmod +x "$RUNNER_BINARY"
log_info "✓ act_runner binary installed at $RUNNER_BINARY"

# Step 5: Create runner home directory
log_step "Step 5: Setting up runner home directory..."
mkdir -p ${RUNNER_HOME}
chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}
log_info "✓ Runner home directory created: ${RUNNER_HOME}"

# Step 6: Create systemd service
log_step "Step 6: Creating systemd service..."
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
ExecStart=${RUNNER_BINARY} daemon -c ${RUNNER_HOME}/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log_info "✓ Systemd service created"

# Step 7: Display registration instructions
log_info ""
log_info "=========================================="
log_info "Installation Complete!"
log_info "=========================================="
log_info ""
log_warn "IMPORTANT: Complete these steps to finish setup:"
log_info ""
log_info "1. Get Registration Token from Gitea:"
log_info "   - Log into Gitea as admin"
log_info "   - Go to Site Administration → Actions → Runners"
log_info "   - Click 'Create new Runner'"
log_info "   - Copy the registration token"
log_info ""
log_info "2. Register the runner:"
log_info ""
echo -e "${BLUE}sudo -u ${RUNNER_USER} bash -c \"cd ${RUNNER_HOME} && ${RUNNER_BINARY} register \\
  --instance ${GITEA_URL} \\
  --token YOUR_REGISTRATION_TOKEN \\
  --name docker-runner-1 \\
  --labels 'ubuntu-latest:docker://gitea/runner-images:ubuntu-latest,almalinux-latest:docker://almalinux:9'\"${NC}"
log_info ""
log_info "3. Generate configuration:"
log_info ""
echo -e "${BLUE}sudo -u ${RUNNER_USER} bash -c \"cd ${RUNNER_HOME} && ${RUNNER_BINARY} generate-config > config.yaml\"${NC}"
log_info ""
log_info "4. Enable Docker socket mount:"
log_info ""
echo -e "${BLUE}sudo -u ${RUNNER_USER} bash -c \"sed -i 's/valid_volumes: \[\]/valid_volumes: \[\\\"\/var\/run\/docker.sock\\\"\]/g' ${RUNNER_HOME}/config.yaml\"${NC}"
log_info ""
log_info "5. Enable and start the service:"
log_info ""
echo -e "${BLUE}sudo systemctl enable gitea-runner
sudo systemctl start gitea-runner${NC}"
log_info ""
log_info "6. Verify runner status:"
log_info ""
echo -e "${BLUE}sudo systemctl status gitea-runner
sudo journalctl -u gitea-runner -f${NC}"
log_info ""
log_info "=========================================="
log_info "Configuration Summary"
log_info "=========================================="
log_info "Gitea URL: ${GITEA_URL}"
log_info "Runner user: ${RUNNER_USER}"
log_info "Runner home: ${RUNNER_HOME}"
log_info "Runner binary: ${RUNNER_BINARY}"
log_info "Docker insecure registry: ${GITEA_HOST}:${GITEA_PORT}"
log_info "Service: gitea-runner.service"
log_info ""
log_info "Documentation:"
log_info "  - Complete setup: docs/GITEA_ACTIONS_COMPLETE_SETUP.md"
log_info "  - Troubleshooting: docs/GITEA_RUNNER_TROUBLESHOOTING.md"
log_info "=========================================="

# Made with Bob