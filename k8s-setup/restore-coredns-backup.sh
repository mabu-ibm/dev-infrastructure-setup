#!/bin/bash
################################################################################
# CoreDNS Backup Restoration Script
# Purpose: Restore CoreDNS configuration from backup
# Usage: sudo ./restore-coredns-backup.sh [backup-file]
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

log_info "CoreDNS Backup Restoration Script"
log_info "=================================="
echo ""

# Step 1: Check if kubectl is available
log_step "1. Checking kubectl availability..."
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

log_info "✓ kubectl is available and connected to cluster"
echo ""

# Step 2: Find or specify backup file
log_step "2. Locating backup files..."

if [ $# -eq 1 ]; then
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
else
    # List available backups
    log_info "Available CoreDNS backups in /tmp:"
    BACKUPS=$(ls -1t /tmp/coredns-backup-*.yaml 2>/dev/null || true)
    
    if [ -z "$BACKUPS" ]; then
        log_error "No backup files found in /tmp"
        log_info "Usage: $0 [backup-file-path]"
        exit 1
    fi
    
    echo "$BACKUPS" | nl
    echo ""
    
    read -p "Enter backup number to restore (or 'q' to quit): " CHOICE
    
    if [ "$CHOICE" = "q" ]; then
        log_info "Exiting without changes"
        exit 0
    fi
    
    BACKUP_FILE=$(echo "$BACKUPS" | sed -n "${CHOICE}p")
    
    if [ -z "$BACKUP_FILE" ]; then
        log_error "Invalid selection"
        exit 1
    fi
fi

log_info "Selected backup: $BACKUP_FILE"
echo ""

# Step 3: Show backup details
log_step "3. Backup file details..."
log_info "File: $BACKUP_FILE"
log_info "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
log_info "Date: $(stat -c %y "$BACKUP_FILE" 2>/dev/null || stat -f %Sm "$BACKUP_FILE" 2>/dev/null)"
echo ""

# Show a preview of the Corefile
log_info "Corefile preview from backup:"
echo "---"
kubectl get -f "$BACKUP_FILE" -o jsonpath='{.data.Corefile}' 2>/dev/null | head -20
echo "---"
echo ""

# Step 4: Confirm restoration
log_warn "This will restore CoreDNS configuration from the backup"
log_warn "Current configuration will be replaced!"
echo ""
read -p "Continue with restoration? (yes/NO): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_info "Restoration cancelled"
    exit 0
fi

# Step 5: Create a backup of current state before restoring
log_step "4. Creating backup of current state..."
CURRENT_BACKUP="/tmp/coredns-before-restore-$(date +%Y%m%d-%H%M%S).yaml"
kubectl get configmap coredns -n kube-system -o yaml > "$CURRENT_BACKUP"
log_info "✓ Current state backed up to: $CURRENT_BACKUP"
echo ""

# Step 6: Restore the backup
log_step "5. Restoring CoreDNS ConfigMap..."
if kubectl apply -f "$BACKUP_FILE"; then
    log_info "✓ ConfigMap restored successfully"
else
    log_error "Failed to restore ConfigMap"
    log_info "Current state backup available at: $CURRENT_BACKUP"
    exit 1
fi
echo ""

# Step 7: Check for deployment backup
DEPLOYMENT_BACKUP="${BACKUP_FILE/coredns-backup/coredns-deployment-backup}"
if [ -f "$DEPLOYMENT_BACKUP" ]; then
    log_step "6. Restoring CoreDNS Deployment..."
    read -p "Deployment backup found. Restore it too? (y/N): " RESTORE_DEPLOY
    
    if [[ "$RESTORE_DEPLOY" =~ ^[Yy]$ ]]; then
        if kubectl apply -f "$DEPLOYMENT_BACKUP"; then
            log_info "✓ Deployment restored successfully"
        else
            log_warn "Failed to restore deployment"
        fi
    fi
    echo ""
fi

# Step 8: Restart CoreDNS
log_step "7. Restarting CoreDNS pods..."
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=60s
log_info "✓ CoreDNS pods restarted"
echo ""

# Step 9: Verify restoration
log_step "8. Verifying restoration..."
sleep 5

COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers | wc -l)

if [ "$COREDNS_PODS" -eq "$RUNNING_PODS" ]; then
    log_info "✓ All CoreDNS pods are running ($RUNNING_PODS/$COREDNS_PODS)"
else
    log_warn "Some CoreDNS pods are not running ($RUNNING_PODS/$COREDNS_PODS)"
    log_info "Check logs: kubectl logs -n kube-system -l k8s-app=kube-dns"
fi

echo ""
log_info "Recent CoreDNS logs:"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10 --prefix=true

echo ""
log_info "============================================"
log_info "CoreDNS Restoration Complete!"
log_info "============================================"
echo ""
log_info "Restoration Summary:"
log_info "  Restored from: $BACKUP_FILE"
log_info "  Pre-restore backup: $CURRENT_BACKUP"
echo ""
log_info "Current CoreDNS configuration:"
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | head -20
echo ""
echo ""
log_info "To verify DNS resolution:"
log_info "  kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default"
echo ""
log_info "============================================"

# Made with Bob