#!/bin/bash
################################################################################
# K3s Installation Script for AlmaLinux
# Purpose: Clean K3s installation that works reliably
# Usage: sudo ./install-k3s-almalinux.sh
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

log_info "=== Starte saubere K3s Installation ==="
echo ""

# Step 1: Stop old services and clean network interfaces
log_step "[1/5] Stoppe alte Dienste und räume Netzwerk-Schnittstellen auf..."
systemctl stop k3s 2>/dev/null || log_info "Kein K3s-Dienst gefunden (normal bei Erstinstallation)"
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || log_info "Kein K3s zum Deinstallieren gefunden"

# Clean up network interfaces
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true

log_info "✓ Alte Dienste gestoppt und Netzwerk bereinigt"

# Step 2: Delete old caches and configurations
log_step "[2/5] Lösche alte Konfigurationsdateien..."
rm -rf /var/lib/cni/
rm -rf /run/flannel/
rm -rf /var/lib/rancher/
rm -rf /etc/rancher/
rm -rf /root/.kube/

# Clean user kube config if sudo user exists
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(eval echo ~${SUDO_USER})
    rm -rf ${USER_HOME}/.kube/
    log_info "✓ Benutzer-Konfiguration für ${SUDO_USER} gelöscht"
fi

log_info "✓ Alte Konfigurationen gelöscht"

# Step 3: Install K3s
log_step "[3/5] Lade K3s herunter und installiere..."
curl -sfL https://get.k3s.io | sh -

log_info "✓ K3s heruntergeladen und installiert"

# Step 4: Set permissions for current user
log_step "[4/5] Setze Berechtigungen für kubectl..."

# Root user
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config
log_info "✓ kubectl für root konfiguriert"

# Regular user (if script was run with sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(eval echo ~${SUDO_USER})
    mkdir -p ${USER_HOME}/.kube
    cp /etc/rancher/k3s/k3s.yaml ${USER_HOME}/.kube/config
    chown -R ${SUDO_USER}:${SUDO_USER} ${USER_HOME}/.kube
    chmod 600 ${USER_HOME}/.kube/config
    log_info "✓ kubectl für Benutzer ${SUDO_USER} konfiguriert"
fi

# Step 5: Enable and start K3s service
log_step "[5/5] Aktiviere K3s-Dienst..."
systemctl enable --now k3s

log_info "✓ K3s-Dienst aktiviert und gestartet"

# Wait for Flannel network to come up
echo ""
log_info "=== Installation abgeschlossen! ==="
log_info "Warte 15 Sekunden, bis das Flannel-Netzwerk hochgefahren ist..."
sleep 15

# Check status
echo ""
log_info "Aktueller Status der Pods:"
kubectl get pods -A

echo ""
log_info "Node-Status:"
kubectl get nodes

# Additional setup
echo ""
log_step "Zusätzliche Konfiguration..."

# Install Helm
if ! command -v helm &> /dev/null; then
    log_info "Installiere Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_info "✓ Helm installiert"
else
    log_info "✓ Helm bereits installiert"
fi

# Create default namespaces
log_info "Erstelle Standard-Namespaces..."
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
log_info "✓ Namespaces erstellt"

# Create remote kubeconfig
NODE_IP=$(hostname -I | awk '{print $1}')
REMOTE_KUBECONFIG="/root/k3s-remote-kubeconfig.yaml"
cp /etc/rancher/k3s/k3s.yaml ${REMOTE_KUBECONFIG}
sed -i "s/127.0.0.1/${NODE_IP}/g" ${REMOTE_KUBECONFIG}
chmod 644 ${REMOTE_KUBECONFIG}
log_info "✓ Remote-Kubeconfig erstellt: ${REMOTE_KUBECONFIG}"

# Save cluster info
cat > /root/k3s-cluster-info.txt <<EOF
K3s Cluster Information
=======================
Installation Date: $(date)
Node IP: ${NODE_IP}
K3s Version: $(k3s --version | head -1)

Kubeconfig Locations:
- Local: /etc/rancher/k3s/k3s.yaml
- Root: /root/.kube/config
$(if [ -n "${SUDO_USER:-}" ]; then echo "- User ${SUDO_USER}: $(eval echo ~${SUDO_USER})/.kube/config"; fi)
- Remote: ${REMOTE_KUBECONFIG}

Remote Access Command:
scp root@${NODE_IP}:${REMOTE_KUBECONFIG} ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config
kubectl get nodes

Useful Commands:
- Status:         systemctl status k3s
- Logs:           journalctl -u k3s -f
- Pods:           kubectl get pods -A
- Restart:        systemctl restart k3s
- Uninstall:      /usr/local/bin/k3s-uninstall.sh

Next Steps:
1. Verify all pods are running: kubectl get pods -A
2. Install ArgoCD: ./install-argocd-gitea.sh
3. Configure Gitea integration
EOF

echo ""
log_info "============================================"
log_info "K3s Installation erfolgreich abgeschlossen!"
log_info "============================================"
log_info ""
log_info "Cluster-Informationen:"
log_info "  Node IP:        ${NODE_IP}"
log_info "  Kubeconfig:     /etc/rancher/k3s/k3s.yaml"
log_info "  Remote Config:  ${REMOTE_KUBECONFIG}"
log_info ""
log_info "Nützliche Befehle:"
log_info "  Status:         systemctl status k3s"
log_info "  Logs:           journalctl -u k3s -f"
log_info "  Pods:           kubectl get pods -A"
log_info "  Restart:        systemctl restart k3s"
log_info ""
log_info "Remote-Zugriff vom MacBook:"
log_info "  scp root@${NODE_IP}:${REMOTE_KUBECONFIG} ~/.kube/k3s-config"
log_info "  export KUBECONFIG=~/.kube/k3s-config"
log_info "  kubectl get nodes"
log_info ""
log_info "Nächste Schritte:"
log_info "  1. Alle Pods prüfen: kubectl get pods -A"
log_info "  2. ArgoCD installieren: ./install-argocd-gitea.sh"
log_info "  3. Gitea-Integration konfigurieren"
log_info "============================================"
log_info ""
log_info "Cluster-Info gespeichert in: /root/k3s-cluster-info.txt"

# Made with Bob
