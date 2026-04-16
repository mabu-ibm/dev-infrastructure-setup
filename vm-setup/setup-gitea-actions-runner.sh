#!/bin/bash
################################################################################
# Gitea Actions Runner Setup Script for AlmaLinux 10 (Container Mode)
# Purpose: Install and configure Gitea Actions runner running in Docker container
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

log_info "Setting up Gitea Actions Runner (Container Mode)..."

# Configuration
RUNNER_IMAGE="gitea/act_runner:latest"
RUNNER_CONTAINER="gitea-runner"
RUNNER_DATA_DIR="/var/lib/gitea-runner"

# Step 1: Check Docker is installed and running
log_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_error "Docker service is not running. Starting Docker..."
    systemctl start docker
fi

log_info "✓ Docker is installed and running"

# Step 2: Create runner data directory
log_info "Creating runner data directory..."
mkdir -p ${RUNNER_DATA_DIR}
log_info "✓ Runner data directory created: ${RUNNER_DATA_DIR}"

# Step 3: Get Gitea configuration
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
log_info "  Runner data: ${RUNNER_DATA_DIR}"
log_info "  Container: ${RUNNER_CONTAINER}"
log_info ""

# Step 4: Stop and remove existing container if it exists
log_info "Checking for existing runner container..."
if docker ps -a --format '{{.Names}}' | grep -q "^${RUNNER_CONTAINER}$"; then
    log_warn "Existing container found. Removing..."
    docker stop ${RUNNER_CONTAINER} 2>/dev/null || true
    docker rm ${RUNNER_CONTAINER} 2>/dev/null || true
    log_info "✓ Old container removed"
fi

# Step 5: Pull the latest runner image
log_info "Pulling Gitea runner image..."
docker pull ${RUNNER_IMAGE}
log_info "✓ Runner image pulled"

# Step 6: Register the runner using a temporary container
log_info "Registering runner with Gitea..."
docker run --rm \
  -v ${RUNNER_DATA_DIR}:/data \
  -e GITEA_INSTANCE_URL="${GITEA_URL}" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="${GITEA_TOKEN}" \
  -e GITEA_RUNNER_NAME="${RUNNER_NAME}" \
  -e GITEA_RUNNER_LABELS="ubuntu-latest:docker://node:16-bullseye,ubuntu-22.04:docker://node:16-bullseye,ubuntu-20.04:docker://node:16-bullseye" \
  ${RUNNER_IMAGE} register --no-interactive

if [ $? -ne 0 ]; then
    log_error "Runner registration failed!"
    exit 1
fi

log_info "✓ Runner registered successfully"

# Step 7: Create systemd service for the container
log_info "Creating systemd service for container..."
cat > /etc/systemd/system/gitea-runner.service <<EOF
[Unit]
Description=Gitea Actions Runner (Container)
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
TimeoutStartSec=0
ExecStartPre=-/usr/bin/docker stop ${RUNNER_CONTAINER}
ExecStartPre=-/usr/bin/docker rm ${RUNNER_CONTAINER}
ExecStart=/usr/bin/docker run --rm \\
  --name ${RUNNER_CONTAINER} \\
  -v ${RUNNER_DATA_DIR}:/data \\
  -v /var/run/docker.sock:/var/run/docker.sock \\
  -e GITEA_INSTANCE_URL="${GITEA_URL}" \\
  -e GITEA_RUNNER_NAME="${RUNNER_NAME}" \\
  ${RUNNER_IMAGE}
ExecStop=/usr/bin/docker stop ${RUNNER_CONTAINER}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log_info "✓ Systemd service created"

# Step 8: Enable and start the service
log_info "Enabling and starting gitea-runner service..."
systemctl enable gitea-runner
systemctl start gitea-runner

sleep 5

if systemctl is-active --quiet gitea-runner; then
    log_info "✓ Service started successfully"
else
    log_error "Service failed to start"
    log_info "Checking logs..."
    journalctl -u gitea-runner -n 30 --no-pager
    exit 1
fi

# Step 9: Verify container is running
log_info "Verifying container status..."
if docker ps --format '{{.Names}}' | grep -q "^${RUNNER_CONTAINER}$"; then
    log_info "✓ Container is running"
else
    log_error "Container is not running"
    docker logs ${RUNNER_CONTAINER} 2>&1 | tail -20
    exit 1
fi

log_info ""
log_info "============================================"
log_info "Gitea Actions Runner Setup Complete!"
log_info "============================================"
log_info ""
log_info "Configuration Summary:"
log_info "  Mode: Container-based runner"
log_info "  Gitea URL: ${GITEA_URL}"
log_info "  Runner name: ${RUNNER_NAME}"
log_info "  Container: ${RUNNER_CONTAINER}"
log_info "  Data directory: ${RUNNER_DATA_DIR}"
log_info "  Image: ${RUNNER_IMAGE}"
log_info "  Service: gitea-runner.service"
log_info ""
log_info "Service Status:"
systemctl status gitea-runner --no-pager | head -15
log_info ""
log_info "Container Status:"
docker ps --filter "name=${RUNNER_CONTAINER}" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
log_info ""
log_info "Useful Commands:"
log_info "  Check service:    systemctl status gitea-runner"
log_info "  View logs:        journalctl -u gitea-runner -f"
log_info "  Container logs:   docker logs -f ${RUNNER_CONTAINER}"
log_info "  Restart service:  systemctl restart gitea-runner"
log_info "  Stop container:   docker stop ${RUNNER_CONTAINER}"
log_info ""
log_info "Check the runner in Gitea UI:"
log_info "  ${GITEA_URL}/admin/actions/runners"
log_info ""
log_info "The runner should appear as 'Idle' and ready to accept jobs!"
log_info "============================================"

# Made with Bob
