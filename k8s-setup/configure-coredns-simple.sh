#!/bin/bash
################################################################################
# CoreDNS Simple Configuration Script
# Purpose: Add custom DNS entries to CoreDNS ConfigMap (no deployment changes)
# Usage: sudo ./configure-coredns-simple.sh
# Approach: Inline hosts in Corefile (no volume mounts needed)
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

log_info "CoreDNS Simple Configuration Script"
log_info "===================================="
echo ""

# Step 1: Check kubectl
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

# Step 2: Backup current CoreDNS ConfigMap
log_step "2. Backing up current CoreDNS ConfigMap..."
BACKUP_FILE="/tmp/coredns-backup-$(date +%Y%m%d-%H%M%S).yaml"
kubectl get configmap coredns -n kube-system -o yaml > "$BACKUP_FILE"

log_info "✓ Backup saved to: $BACKUP_FILE"
echo ""

# Rollback function
rollback() {
    log_error "Configuration failed! Rolling back..."
    kubectl apply -f "$BACKUP_FILE"
    kubectl rollout restart deployment coredns -n kube-system
    log_warn "Rollback complete. Original configuration restored."
    exit 1
}

trap rollback ERR

# Step 3: Get current CoreDNS configuration
log_step "3. Retrieving current CoreDNS configuration..."
CURRENT_CONFIG=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')

# Check if hosts plugin is already configured
if echo "$CURRENT_CONFIG" | grep -q "hosts {"; then
    log_warn "CoreDNS already has hosts configuration"
    echo ""
    log_info "Current configuration:"
    echo "$CURRENT_CONFIG"
    echo ""
    read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
    if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
        log_info "Exiting without changes"
        trap - ERR
        exit 0
    fi
fi

# Step 4: Read entries from /etc/hosts
log_step "4. Reading DNS entries from /etc/hosts..."
HOSTS_ENTRIES=$(grep -v '^#' /etc/hosts | grep -v '^$' | grep -v '127.0.0.1\|::1\|127.0.1.1' | awk '{print $1, $2}' || true)

if [ -z "$HOSTS_ENTRIES" ]; then
    log_warn "No custom entries found in /etc/hosts"
    log_info "Please add entries to /etc/hosts first, example:"
    echo "192.168.1.100 hello.lab.allwaysbeginner.com"
    echo "192.168.1.101 gitea.lab.allwaysbeginner.com"
    trap - ERR
    exit 1
fi

log_info "Found entries in /etc/hosts:"
echo "---"
echo "$HOSTS_ENTRIES"
echo "---"
echo ""

read -p "Use these entries? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_info "Cancelled by user"
    trap - ERR
    exit 0
fi

# Step 5: Create new CoreDNS configuration with inline hosts
log_step "5. Creating new CoreDNS configuration..."

# Build hosts block with proper indentation
HOSTS_BLOCK=""
while IFS= read -r line; do
    if [ -n "$line" ]; then
        HOSTS_BLOCK="${HOSTS_BLOCK}        $line"$'\n'
    fi
done <<< "$HOSTS_ENTRIES"

# Create new Corefile with inline hosts
cat > /tmp/coredns-new-config.txt <<EOF
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    
    # Custom DNS entries from /etc/hosts
    hosts {
${HOSTS_BLOCK}        fallthrough
    }
    
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

log_info "✓ New configuration created"
echo ""

# Step 6: Show the new configuration
log_info "New CoreDNS configuration:"
echo "---"
cat /tmp/coredns-new-config.txt
echo "---"
echo ""

read -p "Apply this configuration? (y/N): " APPLY
if [[ ! "$APPLY" =~ ^[Yy]$ ]]; then
    log_info "Configuration not applied. Exiting."
    trap - ERR
    exit 0
fi

# Step 7: Update CoreDNS ConfigMap
log_step "6. Updating CoreDNS ConfigMap..."
kubectl create configmap coredns \
    --from-file=Corefile=/tmp/coredns-new-config.txt \
    -n kube-system \
    --dry-run=client -o yaml | kubectl apply -f -

log_info "✓ CoreDNS ConfigMap updated"
echo ""

# Step 8: Restart CoreDNS pods
log_step "7. Restarting CoreDNS pods..."
kubectl rollout restart deployment coredns -n kube-system

log_info "Waiting for CoreDNS to restart..."
if kubectl rollout status deployment coredns -n kube-system --timeout=60s; then
    log_info "✓ CoreDNS restarted successfully"
else
    log_error "CoreDNS restart failed or timed out"
    rollback
fi

echo ""

# Step 9: Verify configuration
log_step "8. Verifying CoreDNS pods..."
sleep 5

COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers | wc -l)

if [ "$COREDNS_PODS" -eq "$RUNNING_PODS" ] && [ "$RUNNING_PODS" -gt 0 ]; then
    log_info "✓ All CoreDNS pods are running ($RUNNING_PODS/$COREDNS_PODS)"
else
    log_error "CoreDNS pods are not running properly ($RUNNING_PODS/$COREDNS_PODS)"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo ""
    kubectl describe pods -n kube-system -l k8s-app=kube-dns | tail -30
    rollback
fi

# Check logs for errors
log_info "Checking CoreDNS logs..."
if kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20 2>&1 | grep -i "error\|fatal\|panic"; then
    log_warn "Errors detected in CoreDNS logs"
    kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
    read -p "Continue despite errors? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        rollback
    fi
fi

# Disable error trap - we succeeded
trap - ERR

echo ""
log_info "============================================"
log_info "CoreDNS Configuration Complete!"
log_info "============================================"
echo ""
log_info "Configuration Summary:"
log_info "  Backup File: $BACKUP_FILE"
log_info "  Configuration: Inline hosts in CoreDNS ConfigMap"
log_info "  No deployment changes made"
echo ""

log_info "Configured DNS entries:"
echo "---"
echo "$HOSTS_ENTRIES"
echo "---"
echo ""

log_info "📋 Test DNS resolution:"
echo "   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <hostname>"
echo ""
log_info "   Example:"
FIRST_HOST=$(echo "$HOSTS_ENTRIES" | head -1 | awk '{print $2}')
if [ -n "$FIRST_HOST" ]; then
    echo "   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup $FIRST_HOST"
fi
echo ""

log_info "📝 To update DNS entries:"
echo "   1. Edit /etc/hosts on this machine"
echo "   2. Run this script again"
echo ""

log_info "🔄 To restore original configuration:"
echo "   kubectl apply -f $BACKUP_FILE"
echo "   kubectl rollout restart deployment coredns -n kube-system"
echo ""

log_info "✅ Configuration successful!"
echo ""
log_info "Note: Changes persist across reboots (stored in Kubernetes etcd)"

# Cleanup
rm -f /tmp/coredns-new-config.txt

# Made with Bob
