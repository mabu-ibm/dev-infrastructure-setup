# almak3s Host Setup Guide

Complete setup guide for the Kubernetes host running K3s for container orchestration and application deployment.

## Table of Contents
- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Verification](#verification)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- AlmaLinux 10 installed and updated
- Root or sudo access
- Internet connectivity
- Hostname configured as `almak3s`
- Network connectivity to almabuild host (for pulling images)

## System Requirements

### Minimum
- CPU: 2 cores
- RAM: 2 GB
- Disk: 20 GB
- Network: 1 Gbps

### Recommended
- CPU: 4+ cores
- RAM: 4+ GB
- Disk: 50+ GB SSD
- Network: 1 Gbps

### For Production
- CPU: 8+ cores
- RAM: 16+ GB
- Disk: 100+ GB SSD
- Network: 10 Gbps

## Installation Steps

### Step 1: Prepare System

Update system and install prerequisites:

```bash
# Update system
sudo dnf update -y

# Install required packages
sudo dnf install -y curl wget git

# Set hostname (if not already set)
sudo hostnamectl set-hostname almak3s

# Disable swap (required for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verify swap is disabled
free -h
```

### Step 2: Install K3s

Run the K3s installation script:

```bash
cd /path/to/dev-infrastructure-setup
sudo ./k8s-setup/install-k3s-almalinux.sh
```

**What this script does:**
- Installs required kernel modules
- Configures system parameters for Kubernetes
- Downloads and installs K3s
- Configures K3s with:
  - Embedded etcd (for HA-ready setup)
  - Flannel CNI for networking
  - Local-path storage provisioner
  - Traefik ingress controller
  - ServiceLB load balancer
- Creates kubeconfig for kubectl access
- Starts and enables K3s service

**Installation Output:**
```
[INFO] Installing K3s on AlmaLinux 10...
[INFO] Configuring system parameters...
[INFO] Downloading K3s...
[INFO] Starting K3s...
[INFO] K3s installation complete!

Access Information:
- Kubeconfig: /etc/rancher/k3s/k3s.yaml
- API Server: https://almak3s:6443
- Token: /var/lib/rancher/k3s/server/node-token
```

### Step 3: Configure kubectl Access

**For root user:**
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

**For non-root user:**
```bash
# Copy kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Set permissions
chmod 600 ~/.kube/config

# Test access
kubectl get nodes
```

**Add to shell profile:**
```bash
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

### Step 4: Verify Installation

```bash
# Check K3s service
systemctl status k3s

# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info

# Check K3s version
k3s --version
```

Expected output:
```
NAME      STATUS   ROLES                  AGE   VERSION
almak3s   Ready    control-plane,master   1m    v1.28.x+k3s1
```

## Configuration

### K3s Configuration File

Main configuration: `/etc/rancher/k3s/config.yaml`

**Example configuration:**
```yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "almak3s"
  - "192.168.1.100"  # Your IP
cluster-init: true
disable:
  - traefik  # Disable if using custom ingress
  - servicelb  # Disable if using MetalLB
```

**Apply changes:**
```bash
sudo systemctl restart k3s
```

### Firewall Configuration

**Required Ports:**
```bash
# K3s API Server
sudo firewall-cmd --permanent --add-port=6443/tcp

# Kubelet metrics
sudo firewall-cmd --permanent --add-port=10250/tcp

# NodePort Services (if used)
sudo firewall-cmd --permanent --add-port=30000-32767/tcp

# Flannel VXLAN
sudo firewall-cmd --permanent --add-port=8472/udp

# HTTP/HTTPS for Ingress
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp

# Reload firewall
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

### Storage Configuration

K3s includes local-path-provisioner by default.

**Check storage class:**
```bash
kubectl get storageclass
```

**Create PVC example:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
```

### Ingress Configuration

K3s includes Traefik ingress controller by default.

**Check Traefik:**
```bash
kubectl get pods -n kube-system | grep traefik
kubectl get svc -n kube-system traefik
```

**Example Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: myapp.almak3s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Verification

### Complete System Check

```bash
# 1. Check K3s service
systemctl status k3s

# 2. Check node status
kubectl get nodes -o wide

# 3. Check all pods
kubectl get pods -A

# 4. Check system components
kubectl get componentstatuses

# 5. Check cluster resources
kubectl top nodes
kubectl top pods -A

# 6. Check storage
kubectl get pv
kubectl get pvc -A

# 7. Check ingress
kubectl get ingress -A

# 8. Check services
kubectl get svc -A

# 9. Check logs
sudo journalctl -u k3s -n 100

# 10. Check disk usage
df -h /var/lib/rancher/k3s
```

### Network Connectivity Test

```bash
# Create test pod
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600

# Check pod
kubectl get pod test-pod

# Test DNS
kubectl exec test-pod -- nslookup kubernetes.default

# Test internet
kubectl exec test-pod -- wget -O- https://www.google.com

# Cleanup
kubectl delete pod test-pod
```

## Usage

### Deploying Applications

**Method 1: kubectl apply**
```bash
# Create deployment
kubectl create deployment nginx --image=nginx:latest

# Expose as service
kubectl expose deployment nginx --port=80 --type=NodePort

# Check status
kubectl get deployments
kubectl get pods
kubectl get svc

# Access application
curl http://almak3s:$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
```

**Method 2: YAML manifests**

Create `deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: almabuild:3000/username/my-app:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

Apply:
```bash
kubectl apply -f deployment.yaml
kubectl get all
```

### Pulling Images from Gitea Registry

**Create registry secret:**
```bash
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild:3000 \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@example.com
```

**Use in deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      imagePullSecrets:
      - name: gitea-registry
      containers:
      - name: my-app
        image: almabuild:3000/username/my-app:latest
```

### Managing Deployments

```bash
# Scale deployment
kubectl scale deployment my-app --replicas=5

# Update image
kubectl set image deployment/my-app my-app=almabuild:3000/username/my-app:v2

# Rollout status
kubectl rollout status deployment/my-app

# Rollout history
kubectl rollout history deployment/my-app

# Rollback
kubectl rollout undo deployment/my-app

# Delete deployment
kubectl delete deployment my-app
```

### Viewing Logs

```bash
# Pod logs
kubectl logs pod-name

# Follow logs
kubectl logs -f pod-name

# Previous container logs
kubectl logs pod-name --previous

# All pods in deployment
kubectl logs -l app=my-app

# Logs from specific container
kubectl logs pod-name -c container-name
```

### Executing Commands

```bash
# Execute command
kubectl exec pod-name -- ls /app

# Interactive shell
kubectl exec -it pod-name -- /bin/bash

# Execute in specific container
kubectl exec -it pod-name -c container-name -- /bin/sh
```

## Troubleshooting

### K3s Service Issues

**Problem:** K3s fails to start
```bash
# Check logs
sudo journalctl -u k3s -n 100 --no-pager

# Check system requirements
free -h  # Ensure swap is off
df -h    # Check disk space

# Check for port conflicts
sudo ss -tlnp | grep -E '6443|10250'

# Restart service
sudo systemctl restart k3s

# Check status
sudo systemctl status k3s
```

**Problem:** Node shows NotReady
```bash
# Check node conditions
kubectl describe node almak3s

# Check kubelet logs
sudo journalctl -u k3s -f

# Check system resources
kubectl top node almak3s

# Restart K3s
sudo systemctl restart k3s
```

### Pod Issues

**Problem:** Pod stuck in Pending
```bash
# Check pod events
kubectl describe pod pod-name

# Common causes:
# - Insufficient resources
kubectl top nodes

# - Image pull errors
kubectl get events --sort-by='.lastTimestamp'

# - PVC not bound
kubectl get pvc
```

**Problem:** Pod stuck in CrashLoopBackOff
```bash
# Check logs
kubectl logs pod-name
kubectl logs pod-name --previous

# Check pod details
kubectl describe pod pod-name

# Check resource limits
kubectl get pod pod-name -o yaml | grep -A 5 resources
```

**Problem:** Cannot pull image
```bash
# Check image name
kubectl describe pod pod-name | grep Image

# Test image pull manually
docker pull almabuild:3000/username/my-app:latest

# Check registry secret
kubectl get secret gitea-registry -o yaml

# Recreate secret
kubectl delete secret gitea-registry
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild:3000 \
  --docker-username=username \
  --docker-password=password
```

### Network Issues

**Problem:** Cannot access services
```bash
# Check service
kubectl get svc service-name

# Check endpoints
kubectl get endpoints service-name

# Check pod labels
kubectl get pods --show-labels

# Test from within cluster
kubectl run test --image=busybox --restart=Never -- wget -O- http://service-name

# Check firewall
sudo firewall-cmd --list-all
```

**Problem:** DNS not working
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS
kubectl run test --image=busybox --restart=Never -- nslookup kubernetes.default

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

### Storage Issues

**Problem:** PVC stuck in Pending
```bash
# Check PVC
kubectl describe pvc pvc-name

# Check storage class
kubectl get storageclass

# Check provisioner
kubectl get pods -n kube-system | grep local-path

# Check available space
df -h /var/lib/rancher/k3s/storage
```

### Performance Issues

**Problem:** High resource usage
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -A

# Check specific pod
kubectl describe pod pod-name | grep -A 5 Limits

# Check system load
top
htop
```

**Problem:** Slow pod startup
```bash
# Check image pull time
kubectl describe pod pod-name | grep -A 10 Events

# Check node conditions
kubectl describe node almak3s

# Check disk I/O
iostat -x 1

# Check network
ping almabuild
```

## Maintenance

### Daily Tasks
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Review logs
sudo journalctl -u k3s --since "1 hour ago"
```

### Weekly Tasks
```bash
# Clean up completed pods
kubectl delete pods --field-selector=status.phase==Succeeded -A
kubectl delete pods --field-selector=status.phase==Failed -A

# Check for updates
sudo dnf check-update

# Review resource usage trends
kubectl top nodes
df -h
```

### Monthly Tasks
```bash
# Update system packages
sudo dnf update -y

# Backup K3s data
sudo tar -czf k3s-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/rancher/k3s/server \
  /etc/rancher/k3s

# Clean old images
sudo k3s crictl rmi --prune

# Review and clean old logs
sudo journalctl --vacuum-time=30d
```

### Backup and Restore

**Backup:**
```bash
# Backup etcd snapshot
sudo k3s etcd-snapshot save --name backup-$(date +%Y%m%d)

# List snapshots
sudo k3s etcd-snapshot ls

# Backup location
ls -lh /var/lib/rancher/k3s/server/db/snapshots/
```

**Restore:**
```bash
# Stop K3s
sudo systemctl stop k3s

# Restore from snapshot
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/backup-20260327

# Start K3s
sudo systemctl start k3s
```

### Upgrading K3s

**Check current version:**
```bash
k3s --version
```

**Upgrade to specific version:**
```bash
# Download new version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.5+k3s1 sh -

# Or use upgrade script
curl -sfL https://get.k3s.io | sh -s - server --cluster-init

# Verify upgrade
k3s --version
kubectl get nodes
```

**Upgrade using script:**
```bash
# Re-run installation script
sudo ./k8s-setup/install-k3s-almalinux.sh
```

## Advanced Configuration

### High Availability Setup

For production, deploy K3s in HA mode with multiple servers:

```bash
# First server (already installed)
# Note the token: cat /var/lib/rancher/k3s/server/node-token

# Additional servers
curl -sfL https://get.k3s.io | K3S_TOKEN=<token> sh -s - server \
  --server https://almak3s:6443 \
  --cluster-init
```

### Adding Worker Nodes

```bash
# On worker node
curl -sfL https://get.k3s.io | K3S_URL=https://almak3s:6443 \
  K3S_TOKEN=<token> sh -

# Verify on master
kubectl get nodes
```

### Custom CNI

To use a different CNI (e.g., Calico):

```bash
# Install K3s without Flannel
curl -sfL https://get.k3s.io | sh -s - --flannel-backend=none

# Install Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### Monitoring Setup

**Install metrics-server:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Install Prometheus (optional):**
```bash
# Add Helm repo
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

## Security Best Practices

1. **Keep K3s updated** with latest security patches
2. **Use RBAC** for access control
3. **Enable Pod Security Standards**
4. **Use Network Policies** to restrict pod communication
5. **Scan images** for vulnerabilities before deployment
6. **Use secrets** for sensitive data, not ConfigMaps
7. **Enable audit logging** for compliance
8. **Regular backups** of etcd data
9. **Monitor cluster** for suspicious activity
10. **Restrict API access** with firewall rules

## Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Rancher Documentation](https://rancher.com/docs/)
- [AlmaLinux Documentation](https://wiki.almalinux.org/)