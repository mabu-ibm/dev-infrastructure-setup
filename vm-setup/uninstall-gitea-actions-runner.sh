#!/bin/bash
################################################################################
# Gitea Actions Runner Uninstall Script
# Purpose: Completely remove Gitea Actions runner (container-based installation)
# Usage: sudo ./uninstall-gitea-actions-runner.sh
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

log_info "Gitea Actions Runner Uninstall Script"
log_info "======================================"
echo ""

# Configuration (matching the setup script)
RUNNER_CONTAINER="gitea-runner"
RUNNER_DATA_DIR="/var/lib/gitea-runner"
SERVICE_NAME="gitea-runner.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

# Ask for confirmation
log_warn "This will completely remove the Gitea Actions runner:"
log_warn "  - Stop and remove the Docker container"
log_warn "  - Remove the systemd service"
log_warn "  - Delete runner data directory: ${RUNNER_DATA_DIR}"
log_warn "  - Remove runner configuration"
echo ""
read -p "Are you sure you want to continue? (yes/NO): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Uninstall cancelled by user"
    exit 0
fi

echo ""
log_info "Starting uninstall process..."
echo ""

# Step 1: Stop and disable systemd service
log_step "1. Stopping and disabling systemd service..."
if systemctl is-active --quiet ${SERVICE_NAME}; then
    log_info "Stopping ${SERVICE_NAME}..."
    systemctl stop ${SERVICE_NAME}
    log_info "✓ Service stopped"
else
    log_info "Service is not running"
fi

if systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
    log_info "Disabling ${SERVICE_NAME}..."
    systemctl disable ${SERVICE_NAME}
    log_info "✓ Service disabled"
else
    log_info "Service is not enabled"
fi

# Step 2: Remove systemd service file
log_step "2. Removing systemd service file..."
if [ -f "${SERVICE_FILE}" ]; then
    rm -f "${SERVICE_FILE}"
    systemctl daemon-reload
    log_info "✓ Service file removed: ${SERVICE_FILE}"
else
    log_info "Service file not found: ${SERVICE_FILE}"
fi

# Step 3: Stop and remove Docker container
log_step "3. Stopping and removing Docker container..."
if docker ps -a --format '{{.Names}}' | grep -q "^${RUNNER_CONTAINER}$"; then
    log_info "Stopping container: ${RUNNER_CONTAINER}..."
    docker stop ${RUNNER_CONTAINER} 2>/dev/null || true
    
    log_info "Removing container: ${RUNNER_CONTAINER}..."
    docker rm ${RUNNER_CONTAINER} 2>/dev/null || true
    
    log_info "✓ Container removed"
else
    log_info "Container not found: ${RUNNER_CONTAINER}"
fi

# Step 4: Remove Docker image (optional)
log_step "4. Checking for Gitea runner Docker image..."
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "gitea/act_runner"; then
    echo ""
    read -p "Do you want to remove the Gitea runner Docker image? (y/N): " REMOVE_IMAGE
    if [[ "$REMOVE_IMAGE" =~ ^[Yy]$ ]]; then
        log_info "Removing Docker image..."
        docker rmi gitea/act_runner:latest 2>/dev/null || true
        log_info "✓ Docker image removed"
    else
        log_info "Keeping Docker image"
    fi
else
    log_info "Docker image not found"
fi

# Step 5: Backup and remove data directory
log_step "5. Handling runner data directory..."
if [ -d "${RUNNER_DATA_DIR}" ]; then
    echo ""
    log_warn "Runner data directory exists: ${RUNNER_DATA_DIR}"
    read -p "Do you want to backup the data before removing? (Y/n): " BACKUP_DATA
    
    if [[ ! "$BACKUP_DATA" =~ ^[Nn]$ ]]; then
        BACKUP_FILE="/tmp/gitea-runner-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        log_info "Creating backup: ${BACKUP_FILE}..."
        tar -czf "${BACKUP_FILE}" -C "$(dirname ${RUNNER_DATA_DIR})" "$(basename ${RUNNER_DATA_DIR})" 2>/dev/null || true
        
        if [ -f "${BACKUP_FILE}" ]; then
            log_info "✓ Backup created: ${BACKUP_FILE}"
        else
            log_warn "Backup creation failed"
        fi
    fi
    
    echo ""
    read -p "Remove data directory ${RUNNER_DATA_DIR}? (y/N): " REMOVE_DATA
    if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
        log_info "Removing data directory..."
        rm -rf "${RUNNER_DATA_DIR}"
        log_info "✓ Data directory removed"
    else
        log_info "Data directory preserved: ${RUNNER_DATA_DIR}"
    fi
else
    log_info "Data directory not found: ${RUNNER_DATA_DIR}"
fi

# Step 6: Clean up any remaining runner processes
log_step "6. Checking for remaining runner processes..."
RUNNER_PIDS=$(pgrep -f "act_runner" || true)
if [ -n "$RUNNER_PIDS" ]; then
    log_warn "Found running runner processes: $RUNNER_PIDS"
    read -p "Kill these processes? (y/N): " KILL_PROCS
    if [[ "$KILL_PROCS" =~ ^[Yy]$ ]]; then
        echo "$RUNNER_PIDS" | xargs kill -9 2>/dev/null || true
        log_info "✓ Processes terminated"
    fi
else
    log_info "No runner processes found"
fi

# Step 7: Verify uninstall
log_step "7. Verifying uninstall..."
echo ""

ISSUES_FOUND=0

# Check service
if systemctl list-unit-files | grep -q "${SERVICE_NAME}"; then
    log_warn "⚠️  Service file still exists in systemd"
    ISSUES_FOUND=1
else
    log_info "✓ Service removed from systemd"
fi

# Check container
if docker ps -a --format '{{.Names}}' | grep -q "^${RUNNER_CONTAINER}$"; then
    log_warn "⚠️  Container still exists"
    ISSUES_FOUND=1
else
    log_info "✓ Container removed"
fi

# Check data directory
if [ -d "${RUNNER_DATA_DIR}" ]; then
    log_warn "⚠️  Data directory still exists: ${RUNNER_DATA_DIR}"
else
    log_info "✓ Data directory removed"
fi

# Check processes
if pgrep -f "act_runner" > /dev/null; then
    log_warn "⚠️  Runner processes still running"
    ISSUES_FOUND=1
else
    log_info "✓ No runner processes found"
fi

echo ""
log_info "============================================"
if [ $ISSUES_FOUND -eq 0 ]; then
    log_info "✅ Gitea Actions Runner Uninstalled Successfully!"
else
    log_warn "⚠️  Uninstall completed with warnings"
    log_info "Some components may still exist (see above)"
fi
log_info "============================================"
echo ""

# Show what was removed
log_info "Removed Components:"
log_info "  ✓ Systemd service: ${SERVICE_NAME}"
log_info "  ✓ Service file: ${SERVICE_FILE}"
log_info "  ✓ Docker container: ${RUNNER_CONTAINER}"
if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    log_info "  ✓ Data directory: ${RUNNER_DATA_DIR}"
fi
if [[ "$REMOVE_IMAGE" =~ ^[Yy]$ ]]; then
    log_info "  ✓ Docker image: gitea/act_runner:latest"
fi
echo ""

# Show what was preserved
if [ -f "${BACKUP_FILE}" ]; then
    log_info "Backup Created:"
    log_info "  📦 ${BACKUP_FILE}"
    echo ""
fi

if [ -d "${RUNNER_DATA_DIR}" ]; then
    log_info "Preserved:"
    log_info "  📁 Data directory: ${RUNNER_DATA_DIR}"
    echo ""
fi

# Additional cleanup suggestions
log_info "Additional Cleanup (optional):"
echo ""
log_info "1. Remove runner from Gitea UI:"
echo "   - Go to: Site Administration → Actions → Runners"
echo "   - Find and delete the runner entry"
echo ""
log_info "2. Clean up Docker resources:"
echo "   docker system prune -a --volumes"
echo ""
log_info "3. Remove backup file (if created):"
if [ -f "${BACKUP_FILE}" ]; then
    echo "   rm ${BACKUP_FILE}"
fi
echo ""

log_info "To reinstall the runner, use:"
echo "   sudo ./vm-setup/setup-gitea-actions-runner.sh"
echo ""
log_info "============================================"

# Made with Bob