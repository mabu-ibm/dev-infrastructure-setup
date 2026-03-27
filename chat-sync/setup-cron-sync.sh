#!/bin/bash
################################################################################
# Cron-based Chat Sync Setup
# Purpose: Install cron job to sync AI chats every 30 minutes
# Usage: ./setup-cron-sync.sh
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

log_info "Setting up cron-based chat sync..."

# Get the absolute path to sync-chats.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/sync-chats.sh"

if [ ! -f "${SYNC_SCRIPT}" ]; then
    log_error "sync-chats.sh not found at: ${SYNC_SCRIPT}"
    exit 1
fi

# Configuration
PROJECTS_DIR="${HOME}/projects"
CRON_LOG="${HOME}/.chat-sync-cron.log"
CRON_SCRIPT="${HOME}/.chat-sync-all.sh"

# Create wrapper script that syncs all projects
log_info "Creating sync-all wrapper script..."

cat > "${CRON_SCRIPT}" <<EOF
#!/bin/bash
################################################################################
# Sync all project chats - Called by cron
################################################################################

PROJECTS_DIR="${PROJECTS_DIR}"
SYNC_SCRIPT="${SYNC_SCRIPT}"
LOG_FILE="${CRON_LOG}"

echo "=== Chat Sync Started: \$(date) ===" >> "\${LOG_FILE}"

# Find all git repositories under projects directory
if [ -d "\${PROJECTS_DIR}" ]; then
    find "\${PROJECTS_DIR}" -type d -name ".git" 2>/dev/null | while read -r git_dir; do
        project_dir="\$(dirname "\${git_dir}")"
        echo "Syncing: \${project_dir}" >> "\${LOG_FILE}"
        "\${SYNC_SCRIPT}" "\${project_dir}" >> "\${LOG_FILE}" 2>&1 || true
    done
else
    echo "Projects directory not found: \${PROJECTS_DIR}" >> "\${LOG_FILE}"
fi

echo "=== Chat Sync Completed: \$(date) ===" >> "\${LOG_FILE}"
echo "" >> "\${LOG_FILE}"
EOF

chmod +x "${CRON_SCRIPT}"
log_info "✓ Wrapper script created: ${CRON_SCRIPT}"

# Create projects directory if it doesn't exist
if [ ! -d "${PROJECTS_DIR}" ]; then
    mkdir -p "${PROJECTS_DIR}"
    log_info "✓ Created projects directory: ${PROJECTS_DIR}"
fi

# Add cron job
log_info "Installing cron job..."

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "${CRON_SCRIPT}"; then
    log_warn "Cron job already exists, updating..."
    # Remove old entry
    crontab -l 2>/dev/null | grep -v "${CRON_SCRIPT}" | crontab -
fi

# Add new cron job (every 30 minutes)
(crontab -l 2>/dev/null; echo "*/30 * * * * ${CRON_SCRIPT}") | crontab -

log_info "✓ Cron job installed"

# Verify cron job
log_info "Verifying cron job..."
if crontab -l | grep -q "${CRON_SCRIPT}"; then
    log_info "✓ Cron job verified"
else
    log_error "Failed to install cron job"
    exit 1
fi

# Create initial log file
touch "${CRON_LOG}"

log_info "============================================"
log_info "Cron-based Chat Sync Setup Complete!"
log_info "============================================"
log_info "Sync script:     ${SYNC_SCRIPT}"
log_info "Wrapper script:  ${CRON_SCRIPT}"
log_info "Projects dir:    ${PROJECTS_DIR}"
log_info "Log file:        ${CRON_LOG}"
log_info ""
log_info "Schedule: Every 30 minutes"
log_info ""
log_info "Cron job installed:"
crontab -l | grep "${CRON_SCRIPT}"
log_info ""
log_info "Useful Commands:"
log_info "  View cron jobs:  crontab -l"
log_info "  Edit cron jobs:  crontab -e"
log_info "  Remove cron job: crontab -l | grep -v chat-sync | crontab -"
log_info "  View sync log:   tail -f ${CRON_LOG}"
log_info "  Manual sync:     ${CRON_SCRIPT}"
log_info ""
log_info "Test the sync now:"
log_info "  ${CRON_SCRIPT}"
log_info "============================================"

# Made with Bob
