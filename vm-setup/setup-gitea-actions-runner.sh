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
RUNNER_WORK_DIR="/var/lib/act_runner"
RUNNER_CONFIG="${RUNNER_HOME}/config.yaml"

# Step 1: Create runner user
log_info "Creating runner user..."
if ! id -u ${RUNNER_USER} > /dev/null 2>&1; then
    useradd --system --shell /bin/bash --create-home --home ${RUNNER_HOME} ${RUNNER_USER}
    usermod -aG docker ${RUNNER_USER}
    log_info "User ${RUNNER_USER} created and added to docker group"
else
    log_warn "User ${RUNNER_USER} already exists"
fi

# Step 2: Download act_runner binary
log_info "Downloading act_runner ${RUNNER_VERSION}..."
wget -O /usr/local/bin/act_runner https://dl.gitea.com/act_runner/${RUNNER_VERSION}/act_runner-${RUNNER_VERSION}-linux-amd64
chmod +x /usr/local/bin/act_runner
log_info "act_runner binary installed"

# Step 3: Create working directory for act_runner
log_info "Creating act_runner working directory..."
mkdir -p ${RUNNER_WORK_DIR}
chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_WORK_DIR}
log_info "✓ Working directory ${RUNNER_WORK_DIR} created"

# Step 4: Generate runner configuration
log_info "Generating runner configuration..."
mkdir -p ${RUNNER_HOME}
cd ${RUNNER_HOME}

# Generate default config
sudo -u ${RUNNER_USER} /usr/local/bin/act_runner generate-config > ${RUNNER_CONFIG}

# Customize configuration
cat > ${RUNNER_CONFIG} <<'EOF'
log:
  level: info

runner:
  file: .runner
  capacity: 2
  envs:
    A_TEST_ENV_NAME_1: a_test_env_value_1
    A_TEST_ENV_NAME_2: a_test_env_value_2
  env_file: .env
  timeout: 3h
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  labels:
    - "ubuntu-latest:docker://node:16-bullseye"
    - "ubuntu-22.04:docker://node:16-bullseye"
    - "ubuntu-20.04:docker://node:16-bullseye"
    - "almalinux-latest:docker://almalinux:9"

cache:
  enabled: true
  dir: ""
  host: ""
  port: 0
  external_server: ""

container:
  network: ""
  privileged: false
  options: ""
  workdir_parent: ""
  valid_volumes: []
  docker_host: ""
  force_pull: false

host:
  workdir_parent: ""
EOF

chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_CONFIG}

# Step 5: Create systemd service
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
WorkingDirectory=${RUNNER_WORK_DIR}
ExecStart=/usr/local/bin/act_runner daemon --config ${RUNNER_CONFIG}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Step 6: Post-registration fix function
log_info "Creating post-registration fix script..."
cat > /usr/local/bin/fix-gitea-runner.sh <<'FIXEOF'
#!/bin/bash
# Fix Gitea Runner configuration after registration
# This moves the .runner file to the correct location and regenerates config

set -euo pipefail

RUNNER_USER="gitea-runner"
RUNNER_HOME="/var/lib/gitea-runner"
RUNNER_WORK_DIR="/var/lib/act_runner"

echo "[INFO] Fixing Gitea Runner configuration..."

# Check if .runner file exists in work directory
if [ -f "${RUNNER_WORK_DIR}/.runner" ]; then
    echo "[INFO] Moving .runner file to ${RUNNER_HOME}..."
    sudo mkdir -p ${RUNNER_HOME}
    sudo mv ${RUNNER_WORK_DIR}/.runner ${RUNNER_HOME}/
    
    # Regenerate config in the correct location
    echo "[INFO] Regenerating configuration..."
    sudo -u ${RUNNER_USER} /usr/local/bin/act_runner generate-config | sudo tee ${RUNNER_HOME}/config.yaml > /dev/null
    
    # Set proper ownership
    echo "[INFO] Setting ownership..."
    sudo chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}
    
    # Restart service
    echo "[INFO] Restarting gitea-runner service..."
    sudo systemctl restart gitea-runner
    
    echo "[SUCCESS] Gitea Runner configuration fixed!"
    echo "[INFO] Checking status..."
    sudo systemctl status gitea-runner --no-pager
else
    echo "[ERROR] .runner file not found in ${RUNNER_WORK_DIR}"
    echo "[INFO] Please register the runner first"
    exit 1
fi
FIXEOF

chmod +x /usr/local/bin/fix-gitea-runner.sh
log_info "✓ Post-registration fix script created at /usr/local/bin/fix-gitea-runner.sh"

# Step 7: Display registration instructions
log_info "============================================"
log_info "Gitea Actions Runner Setup Complete!"
log_info "============================================"
log_info ""
log_info "IMPORTANT: You must register the runner before starting it!"
log_info ""
log_info "Registration Steps:"
log_info "1. Log into your Gitea instance as admin"
log_info "2. Go to Site Administration → Actions → Runners"
log_info "3. Click 'Create new Runner'"
log_info "4. Copy the registration token"
log_info "5. Run these commands to register:"
log_info ""
log_info "   cd ${RUNNER_WORK_DIR}"
log_info "   sudo -u ${RUNNER_USER} /usr/local/bin/act_runner register \\"
log_info "     --instance http://YOUR_GITEA_URL:3000 \\"
log_info "     --token YOUR_REGISTRATION_TOKEN \\"
log_info "     --name build-runner-1 \\"
log_info "     --labels ubuntu-latest,almalinux-latest"
log_info ""
log_info "   Or use this one-liner:"
log_info "   cd ${RUNNER_WORK_DIR} && sudo -u ${RUNNER_USER} /usr/local/bin/act_runner register --instance http://YOUR_GITEA_URL:3000 --token YOUR_TOKEN --name build-runner-1 --labels ubuntu-latest,almalinux-latest"
log_info ""
log_info "6. IMPORTANT: After registration, run the fix script:"
log_info "   ${GREEN}sudo /usr/local/bin/fix-gitea-runner.sh${NC}"
log_info ""
log_info "   This will:"
log_info "   - Move .runner file to correct location (${RUNNER_HOME})"
log_info "   - Regenerate configuration"
log_info "   - Set proper ownership"
log_info "   - Restart the service"
log_info ""
log_info "7. Then enable and verify the service:"
log_info "   systemctl enable gitea-runner"
log_info "   systemctl status gitea-runner"
log_info ""
log_info "Check status: systemctl status gitea-runner"
log_info "View logs:    journalctl -u gitea-runner -f"
log_info "============================================"

# Made with Bob
