#!/bin/bash
################################################################################
# Configure Docker for HTTP Registry on Runner Host
# Purpose: Allow Docker to use insecure (HTTP) registries
# Usage: sudo ./configure-docker-http-registry.sh <registry-url>
# Example: sudo ./configure-docker-http-registry.sh gitea.example.com:3000
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

# Get registry URL
if [ -z "${1:-}" ]; then
    log_error "Registry URL is required"
    echo ""
    echo "Usage: sudo $0 <registry-url>"
    echo ""
    echo "Examples:"
    echo "  sudo $0 gitea.example.com:3000"
    echo "  sudo $0 localhost:5000"
    echo "  sudo $0 registry.lab.local:5000"
    exit 1
fi

REGISTRY="$1"

log_info "Configuring Docker for HTTP Registry"
log_info "====================================="
log_info "Registry: $REGISTRY"
echo ""

# Step 1: Backup existing config
log_step "1. Backing up existing Docker configuration..."
DAEMON_JSON="/etc/docker/daemon.json"

if [ -f "$DAEMON_JSON" ]; then
    BACKUP="${DAEMON_JSON}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$DAEMON_JSON" "$BACKUP"
    log_info "✓ Backup created: $BACKUP"
else
    log_info "No existing configuration found"
fi
echo ""

# Step 2: Create/update daemon.json
log_step "2. Creating Docker daemon configuration..."
mkdir -p /etc/docker

# Check if file exists and has insecure-registries
if [ -f "$DAEMON_JSON" ]; then
    log_info "Updating existing daemon.json..."
    
    # Check if registry already configured
    if grep -q "\"$REGISTRY\"" "$DAEMON_JSON" 2>/dev/null; then
        log_info "✓ Registry already configured in daemon.json"
    else
        log_warn "Registry not found in existing config"
        log_info "Please manually add to $DAEMON_JSON:"
        echo '  "insecure-registries": ["'$REGISTRY'"]'
    fi
else
    log_info "Creating new daemon.json..."
    cat > "$DAEMON_JSON" <<EOF
{
  "insecure-registries": ["$REGISTRY"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    log_info "✓ Configuration file created"
fi
echo ""

# Step 3: Display configuration
log_step "3. Current Docker daemon configuration:"
cat "$DAEMON_JSON"
echo ""

# Step 4: Restart Docker
log_step "4. Restarting Docker daemon..."
if command -v systemctl &> /dev/null; then
    systemctl restart docker
    sleep 3
    
    if systemctl is-active --quiet docker; then
        log_info "✓ Docker restarted successfully"
    else
        log_error "Docker failed to start"
        systemctl status docker --no-pager
        exit 1
    fi
else
    log_warn "systemctl not available, please restart Docker manually"
fi
echo ""

# Step 5: Verify configuration
log_step "5. Verifying Docker configuration..."
if docker info 2>/dev/null | grep -q "Insecure Registries"; then
    log_info "Docker insecure registries:"
    docker info 2>/dev/null | grep -A 5 "Insecure Registries"
else
    log_warn "Could not verify insecure registries configuration"
fi
echo ""

# Step 6: Test registry access
log_step "6. Testing registry access..."
log_info "Testing connection to $REGISTRY..."

if timeout 5 bash -c "echo > /dev/tcp/${REGISTRY%:*}/${REGISTRY##*:}" 2>/dev/null; then
    log_info "✓ Registry is reachable"
else
    log_warn "Could not connect to registry (may be normal if registry is not running)"
fi
echo ""

log_info "============================================"
log_info "Docker HTTP Registry Configuration Complete!"
log_info "============================================"
echo ""
log_info "Configuration Summary:"
log_info "  Registry: $REGISTRY"
log_info "  Config file: $DAEMON_JSON"
log_info "  Docker status: $(systemctl is-active docker 2>/dev/null || echo 'unknown')"
echo ""
log_info "Next Steps:"
log_info "1. Test Docker login:"
log_info "   docker login $REGISTRY"
echo ""
log_info "2. If using Gitea Actions runner, restart the runner:"
log_info "   sudo systemctl restart gitea-runner"
echo ""
log_info "3. Test pushing an image:"
log_info "   docker tag hello-world $REGISTRY/test:latest"
log_info "   docker push $REGISTRY/test:latest"
echo ""
log_info "============================================"

# Made with Bob