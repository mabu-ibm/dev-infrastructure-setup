#!/bin/bash
################################################################################
# Emergency CoreDNS Rollback Script
# Purpose: Quickly restore CoreDNS to working state
# Usage: sudo ./emergency-coredns-rollback.sh
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Emergency CoreDNS Rollback"
log_info "=========================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Find the most recent backup
log_info "Looking for backup files..."
BACKUP_CONFIGMAP=$(ls -t /tmp/coredns-backup-*/coredns-configmap.yaml 2>/dev/null | head -1)
BACKUP_DEPLOYMENT=$(ls -t /tmp/coredns-deployment-backup-*.yaml 2>/dev/null | head -1)

if [ -z "$BACKUP_CONFIGMAP" ] && [ -z "$BACKUP_DEPLOYMENT" ]; then
    BACKUP_CONFIGMAP=$(ls -t /tmp/coredns-backup-*.yaml 2>/dev/null | head -1)
fi

if [ -n "$BACKUP_CONFIGMAP" ]; then
    log_info "Found backup: $BACKUP_CONFIGMAP"
    log_info "Restoring ConfigMap..."
    kubectl apply -f "$BACKUP_CONFIGMAP"
else
    log_warn "No ConfigMap backup found, creating default configuration..."
    
    cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF
fi

if [ -n "$BACKUP_DEPLOYMENT" ]; then
    log_info "Found deployment backup: $BACKUP_DEPLOYMENT"
    log_info "Restoring Deployment..."
    kubectl apply -f "$BACKUP_DEPLOYMENT"
else
    log_warn "No Deployment backup found, removing custom volumes..."
    
    # Remove the problematic volume mounts
    kubectl get deployment coredns -n kube-system -o json | \
        jq 'del(.spec.template.spec.volumes[] | select(.name == "hosts" or .name == "custom-hosts"))' | \
        jq 'del(.spec.template.spec.containers[0].volumeMounts[] | select(.name == "hosts" or .name == "custom-hosts"))' | \
        kubectl apply -f - 2>/dev/null || true
fi

# Delete the custom hosts ConfigMap if it exists
log_info "Cleaning up custom hosts ConfigMaps..."
kubectl delete configmap coredns-hosts -n kube-system 2>/dev/null || true
kubectl delete configmap coredns-custom-hosts -n kube-system 2>/dev/null || true

# Force restart CoreDNS
log_info "Restarting CoreDNS..."
kubectl rollout restart deployment coredns -n kube-system

log_info "Waiting for CoreDNS to become ready..."
sleep 5

# Wait for rollout
if kubectl rollout status deployment coredns -n kube-system --timeout=60s; then
    log_info "✓ CoreDNS rollout successful"
else
    log_error "CoreDNS rollout failed"
    log_info "Checking pod status..."
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    kubectl describe pods -n kube-system -l k8s-app=kube-dns | tail -50
    exit 1
fi

# Verify pods are running
RUNNING_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers | wc -l)

if [ "$RUNNING_PODS" -gt 0 ]; then
    log_info "✓ CoreDNS is running ($RUNNING_PODS pods)"
    echo ""
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo ""
    log_info "✅ CoreDNS has been restored to working state!"
else
    log_error "CoreDNS pods are still not running"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
    exit 1
fi

# Made with Bob
