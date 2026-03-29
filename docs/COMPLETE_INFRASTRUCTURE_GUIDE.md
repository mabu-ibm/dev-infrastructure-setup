# Complete Infrastructure Setup and Deployment Guide

Complete guide for setting up a CI/CD infrastructure with Gitea, Docker, K3s, and automated deployments.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Phase 1: almabuild Setup](#phase-1-almabuild-setup)
5. [Phase 2: almak3s Setup](#phase-2-almak3s-setup)
6. [Phase 3: Deploy Test Application](#phase-3-deploy-test-application)
7. [Phase 4: Verify and Test](#phase-4-verify-and-test)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance](#maintenance)

---

## Overview

This guide walks you through setting up a complete CI/CD infrastructure from scratch.

### What You'll Build

- **almabuild**: Build server with Gitea, Docker, and CI/CD runner
- **almak3s**: Kubernetes cluster for application deployment
- **Automated pipeline**: Push code → Build → Test → Deploy

### Time Required

- **almabuild setup**: 30-45 minutes
- **almak3s setup**: 15-20 minutes
- **Application deployment**: 10-15 minutes
- **Total**: ~1-2 hours

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     almabuild (Build Host)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Gitea     │  │    Docker    │  │ Gitea Runner │      │
│  │  + Registry  │  │              │  │   + kubectl  │      │
│  │  Port 3000   │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            │                                 │
│                            │ Remote kubectl                  │
│                            ▼                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                             │ Network (6443)
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                     almak3s (K3s Host)                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    K3s Cluster                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │   Pod 1    │  │   Pod 2    │  │  Service   │     │   │
│  │  │  App:8080  │  │  App:8080  │  │ NodePort   │     │   │
│  │  └────────────┘  └────────────┘  │  :30xxx    │     │   │
│  │                                   └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Developer (MacBook)
    ↓ git push
Gitea (almabuild)
    ↓ webhook
Gitea Actions Runner (almabuild)
    ↓ build & test
Docker Image → Gitea Registry
    ↓ kubectl apply
K3s Cluster (almak3s)
    ↓ pull image
Running Application
```

---

## Prerequisites

### Hardware Requirements

**almabuild:**
- CPU: 2+ cores
- RAM: 4GB minimum, 8GB recommended
- Disk: 50GB+ free space
- OS: AlmaLinux 10

**almak3s:**
- CPU: 2+ cores
- RAM: 2GB minimum, 4GB recommended
- Disk: 20GB+ free space
- OS: AlmaLinux 10

### Network Requirements

- Both hosts on same network
- Hostnames resolvable (DNS or /etc/hosts)
- Ports open:
  - almabuild: 3000 (Gitea), 22 (SSH)
  - almak3s: 6443 (K3s API), 22 (SSH), 30000-32767 (NodePorts)

### Software Requirements

- Root/sudo access on both hosts
- Internet connectivity for downloads
- Git installed on development machine

---

## Phase 1: almabuild Setup

### Step 1.1: Install Docker

```bash
# On almabuild
sudo dnf install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker

# Verify
docker --version
```

### Step 1.2: Install Gitea

```bash
# Download installation script
cd ~/dev-infrastructure-setup/vm-setup
chmod +x install-gitea-almalinux.sh

# Run installation
sudo ./install-gitea-almalinux.sh
```

**Configuration during install:**
- Database: SQLite (default) or MySQL
- Domain: almabuild.lab.allwaysbeginner.com
- Port: 3000
- Admin user: Create during first web access

**First-time setup:**
1. Open browser: `http://almabuild:3000`
2. Click "Register" or configure admin account
3. Complete initial setup wizard

### Step 1.3: Enable Gitea Actions

```bash
# Edit Gitea configuration
sudo nano /var/lib/gitea/custom/conf/app.ini

# Add this section:
[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://github.com

# Save and restart
sudo systemctl restart gitea
```

**Verify:**
- Log into Gitea as admin
- Go to Site Administration
- See "Actions" in menu
- Go to Actions → Runners

### Step 1.4: Install Gitea Actions Runner

```bash
# Run installation script
cd ~/dev-infrastructure-setup/vm-setup
chmod +x setup-gitea-actions-runner.sh
sudo ./setup-gitea-actions-runner.sh
```

**Register runner:**
1. In Gitea: Site Administration → Actions → Runners
2. Click "Create new Runner"
3. Copy registration token
4. Run registration:

```bash
cd /var/lib/act_runner
sudo -u gitea-runner /usr/local/bin/act_runner register \
  --instance http://almabuild:3000 \
  --token YOUR_REGISTRATION_TOKEN \
  --name docker-runner-1 \
  --labels 'ubuntu-latest:docker://gitea/runner-images:ubuntu-latest,almalinux-latest:docker://almalinux:9'
```

**Fix runner configuration:**
```bash
sudo /usr/local/bin/fix-gitea-runner.sh
```

**Start runner:**
```bash
sudo systemctl enable gitea-runner
sudo systemctl start gitea-runner
sudo systemctl status gitea-runner
```

### Step 1.5: Configure Docker for Insecure Registry

```bash
# Edit Docker daemon config
sudo nano /etc/docker/daemon.json

# Add:
{
  "insecure-registries": ["almabuild.lab.allwaysbeginner.com:3000"]
}

# Restart Docker
sudo systemctl restart docker
```

### Step 1.6: Setup kubectl for Remote K3s Access

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Create symlink for sudo
sudo ln -s /usr/local/bin/kubectl /usr/bin/kubectl

# Get kubeconfig from almak3s (do this after almak3s setup)
# On almak3s:
sudo cat /etc/rancher/k3s/k3s.yaml

# On almabuild:
mkdir -p ~/.kube
nano ~/.kube/config
# Paste kubeconfig and change server to: https://almak3s:6443

# Setup for gitea-runner
sudo mkdir -p /var/lib/gitea-runner/.kube
sudo cp ~/.kube/config /var/lib/gitea-runner/.kube/config
sudo chown -R gitea-runner:gitea-runner /var/lib/gitea-runner/.kube
sudo chmod 600 /var/lib/gitea-runner/.kube/config

# Verify
kubectl get nodes
sudo -u gitea-runner kubectl get nodes
```

---

## Phase 2: almak3s Setup

### Step 2.1: Install K3s

```bash
# On almak3s
cd ~/dev-infrastructure-setup/k8s-setup
chmod +x install-k3s-almalinux.sh
sudo ./install-k3s-almalinux.sh
```

**Verify installation:**
```bash
sudo systemctl status k3s
sudo kubectl get nodes
```

### Step 2.2: Configure Firewall

```bash
# Open K3s API port
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

### Step 2.3: Configure for Insecure Registry

```bash
# Create registries configuration
sudo mkdir -p /etc/rancher/k3s

sudo tee /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  almabuild.lab.allwaysbeginner.com:3000:
    endpoint:
      - "http://almabuild.lab.allwaysbeginner.com:3000"
configs:
  "almabuild.lab.allwaysbeginner.com:3000":
    tls:
      insecure_skip_verify: true
EOF

# Restart K3s
sudo systemctl restart k3s

# Verify
sudo systemctl status k3s
```

### Step 2.4: Create Registry Secret

```bash
# Create Docker registry secret
sudo kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=YOUR_GITEA_USERNAME \
  --docker-password=YOUR_GITEA_PASSWORD \
  --docker-email=your-email@example.com \
  --namespace=default

# Verify
sudo kubectl get secret gitea-registry
```

---

## Phase 3: Deploy Test Application

### Step 3.1: Create Repository in Gitea

1. Log into Gitea: `http://almabuild:3000`
2. Click "+" → "New Repository"
3. Name: `hello-world-python`
4. Click "Create Repository"

### Step 3.2: Configure Repository Secrets

1. Go to repository → Settings → Actions → Secrets
2. Add secret: `REGISTRY_TOKEN`
   - Generate PAT: User Settings → Applications → Generate New Token
   - Permissions: `write:package`, `read:package`
   - Copy token value
3. Add secret: `KUBECONFIG`
   - On almabuild: `cat ~/.kube/config | base64 -w 0`
   - Copy base64 output

### Step 3.3: Push Application Code

```bash
# On your development machine (MacBook)
cd ~/dev-infrastructure-setup/project-templates/hello-world-python

# Initialize git
git init
git branch -M main

# Add files
git add .

# Commit
git commit -m "Initial commit: Hello World Python with CI/CD"

# Add remote
git remote add origin http://almabuild:3000/YOUR_USERNAME/hello-world-python.git

# Push
git push -u origin main
```

### Step 3.4: Watch Workflow Execute

1. Go to Gitea → Repository → Actions tab
2. See workflow running
3. Watch three jobs:
   - Test (Python tests)
   - Build-and-push (Docker image)
   - Deploy (K3s deployment)

**Expected duration:** 3-5 minutes

---

## Phase 4: Verify and Test

### Step 4.1: Check Deployment

```bash
# On almak3s or almabuild (with kubectl configured)
sudo kubectl get deployments
sudo kubectl get pods -l app=hello-world-python
sudo kubectl get service hello-world-python
```

**Expected output:**
```
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
hello-world-python   2/2     2            2           5m

NAME                                  READY   STATUS    RESTARTS   AGE
hello-world-python-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
hello-world-python-xxxxxxxxxx-xxxxx   1/1     Running   0          5m

NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
hello-world-python   LoadBalancer   10.43.211.112   <pending>     80:30348/TCP   5m
```

### Step 4.2: Test Application

**Option 1: ClusterIP (from almak3s)**
```bash
curl http://10.43.211.112/
curl http://10.43.211.112/health
```

**Option 2: NodePort (from network)**
```bash
curl http://almak3s:30348/
curl http://almak3s.lab.allwaysbeginner.com:30348/
```

**Option 3: Port-forward**
```bash
sudo kubectl port-forward service/hello-world-python 8080:80
curl http://localhost:8080/
```

**Expected response:**
```json
{
  "message": "Hello World from Python Flask!",
  "version": "1.0.0",
  "timestamp": "2026-03-29T09:00:00.000000",
  "status": "running"
}
```

### Step 4.3: Test CI/CD Pipeline

```bash
# On development machine
cd hello-world-python

# Make a change
nano app.py
# Change message to "Hello from CI/CD!"

# Commit and push
git add app.py
git commit -m "Update message"
git push

# Watch in Gitea Actions
# Application updates automatically!

# Verify update
curl http://almak3s:30348/
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Gitea Actions Not Visible

**Problem:** No Actions tab in repository

**Solution:**
```bash
# Enable Actions in Gitea
sudo nano /var/lib/gitea/custom/conf/app.ini
# Add: [actions] ENABLED = true
sudo systemctl restart gitea
```

#### 2. Runner Not Starting

**Problem:** gitea-runner service fails

**Solution:**
```bash
sudo /usr/local/bin/fix-gitea-runner.sh
sudo systemctl restart gitea-runner
sudo journalctl -u gitea-runner -n 50
```

#### 3. ImagePullBackOff in K3s

**Problem:** Pods can't pull image

**Solutions:**
```bash
# Check registry secret
sudo kubectl get secret gitea-registry

# Recreate if needed
sudo kubectl delete secret gitea-registry
sudo kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild.lab.allwaysbeginner.com:3000 \
  --docker-username=USERNAME \
  --docker-password=PASSWORD

# Check K3s registry config
sudo cat /etc/rancher/k3s/registries.yaml

# Restart K3s
sudo systemctl restart k3s
```

#### 4. kubectl Connection Refused

**Problem:** Can't connect to K3s from almabuild

**Solutions:**
```bash
# Check firewall on almak3s
sudo firewall-cmd --list-ports

# Open port if needed
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --reload

# Test connectivity
curl -k https://almak3s:6443

# Check kubeconfig
cat ~/.kube/config | grep server:
# Should show: https://almak3s:6443
```

#### 5. Certificate Errors

**Problem:** TLS certificate verification failed

**Solution:**
```bash
# Use short hostname in kubeconfig
sed -i 's/almak3s.lab.allwaysbeginner.com/almak3s/g' ~/.kube/config

# Or skip TLS verification (less secure)
# Add to kubeconfig:
# insecure-skip-tls-verify: true
```

---

## Maintenance

### Regular Tasks

#### Update Gitea
```bash
# Backup first
sudo systemctl stop gitea
sudo cp -r /var/lib/gitea /var/lib/gitea.backup

# Download new version
# Follow Gitea upgrade guide

# Restart
sudo systemctl start gitea
```

#### Update K3s
```bash
# On almak3s
curl -sfL https://get.k3s.io | sh -

# Verify
sudo kubectl version
```

#### Update Runner
```bash
# On almabuild
sudo systemctl stop gitea-runner

# Download new version
sudo wget -O /usr/local/bin/act_runner \
  https://dl.gitea.com/act_runner/VERSION/act_runner-VERSION-linux-amd64
sudo chmod +x /usr/local/bin/act_runner

# Restart
sudo systemctl start gitea-runner
```

### Monitoring

#### Check Services
```bash
# On almabuild
sudo systemctl status gitea
sudo systemctl status gitea-runner
sudo systemctl status docker

# On almak3s
sudo systemctl status k3s
```

#### Check Logs
```bash
# Gitea
sudo journalctl -u gitea -f

# Runner
sudo journalctl -u gitea-runner -f

# K3s
sudo journalctl -u k3s -f

# Application
sudo kubectl logs -l app=hello-world-python -f
```

#### Check Resources
```bash
# Disk space
df -h

# Memory
free -h

# Docker images
docker images

# K3s resources
sudo kubectl top nodes
sudo kubectl top pods
```

### Backup Strategy

#### Gitea Backup
```bash
# Backup script
sudo systemctl stop gitea
sudo tar czf gitea-backup-$(date +%Y%m%d).tar.gz /var/lib/gitea
sudo systemctl start gitea
```

#### K3s Backup
```bash
# Backup etcd
sudo k3s etcd-snapshot save

# List snapshots
sudo k3s etcd-snapshot ls
```

---

## Summary

### What You've Built

✅ **Complete CI/CD Infrastructure**
- Gitea for Git hosting and container registry
- Gitea Actions for CI/CD automation
- Docker for containerization
- K3s for Kubernetes orchestration
- Automated deployment pipeline

✅ **Automated Workflow**
- Push code → Automatic build → Test → Deploy
- Zero manual intervention
- Production-ready setup

### Key Files and Locations

**almabuild:**
- Gitea: `/var/lib/gitea`
- Runner: `/var/lib/gitea-runner`
- Docker: `/var/lib/docker`
- kubectl config: `~/.kube/config`

**almak3s:**
- K3s: `/var/lib/rancher/k3s`
- Kubeconfig: `/etc/rancher/k3s/k3s.yaml`
- Registry config: `/etc/rancher/k3s/registries.yaml`

### Next Steps

1. **Add more applications** - Follow same pattern
2. **Setup monitoring** - Prometheus + Grafana
3. **Add ingress** - Traefik or Nginx
4. **Implement HTTPS** - Let's Encrypt certificates
5. **Add staging environment** - Separate namespace
6. **Setup backups** - Automated backup scripts

---

## Additional Resources

- [Gitea Documentation](https://docs.gitea.com/)
- [Gitea Actions](https://docs.gitea.com/usage/actions/overview)
- [K3s Documentation](https://docs.k3s.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Created with IBM Bob AI** 🤖

**Infrastructure Setup Complete!** 🎉