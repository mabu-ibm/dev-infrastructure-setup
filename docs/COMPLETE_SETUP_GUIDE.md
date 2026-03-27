# Complete Development Infrastructure Setup Guide

## 🎯 Overview

This guide walks you through setting up a complete development infrastructure with:
- **Gitea** (Git hosting + Container Registry + CI/CD)
- **K3s** (Lightweight Kubernetes)
- **Flux CD** (GitOps deployment)
- **Chat Sync** (Claude Code + IBM Bob conversation persistence)
- **Project Automation** (Bob skill for instant project scaffolding)

## 📋 Prerequisites

### Hardware Requirements
- **Build VM**: AlmaLinux 10, 4GB+ RAM, 20GB+ disk
- **K3s VM**: AlmaLinux 10, 4GB+ RAM, 30GB+ disk
- **MacBook**: Development machine with SSH access to VMs

### Software Requirements
- SSH access from MacBook to both VMs (passwordless recommended)
- Git installed on MacBook
- Docker Desktop on MacBook (optional, for local testing)

## 🚀 Installation Steps

### Phase 1: Build VM Setup (Gitea + Docker)

#### 1.1 SSH into Build VM
```bash
ssh root@<build-vm-ip>
```

#### 1.2 Install Gitea
```bash
# Copy installation script to VM
scp vm-setup/install-gitea-almalinux.sh root@<build-vm-ip>:/root/

# On the VM
chmod +x /root/install-gitea-almalinux.sh
./install-gitea-almalinux.sh
```

**Expected Output:**
- Gitea running on port 3000
- SSH on port 2222
- Web interface accessible

#### 1.3 Complete Gitea Initial Setup
1. Open browser: `http://<build-vm-ip>:3000`
2. Complete installation wizard:
   - Database: SQLite (default)
   - Create admin account
   - Set domain/URL
3. Enable Container Registry:
   - Settings → Packages → Enable Container Registry
4. Create access token:
   - User Settings → Applications → Generate New Token
   - Save token securely

#### 1.4 Install Gitea Actions Runner
```bash
# Copy runner setup script
scp vm-setup/setup-gitea-actions-runner.sh root@<build-vm-ip>:/root/

# On the VM
chmod +x /root/setup-gitea-actions-runner.sh
./setup-gitea-actions-runner.sh
```

#### 1.5 Register Actions Runner
```bash
# In Gitea web UI:
# Admin → Actions → Runners → Create new Runner
# Copy registration token

# On the VM
sudo -u gitea-runner act_runner register \
  --instance http://<build-vm-ip>:3000 \
  --token <registration-token> \
  --name build-runner-1 \
  --labels ubuntu-latest,almalinux-latest

# Start runner service
systemctl enable gitea-runner
systemctl start gitea-runner
systemctl status gitea-runner
```

### Phase 2: K3s VM Setup

#### 2.1 SSH into K3s VM
```bash
ssh root@<k3s-vm-ip>
```

#### 2.2 Install K3s
```bash
# Copy installation script
scp k8s-setup/install-k3s-almalinux.sh root@<k3s-vm-ip>:/root/

# On the VM
chmod +x /root/install-k3s-almalinux.sh
./install-k3s-almalinux.sh
```

**Expected Output:**
- K3s cluster running
- kubectl configured
- Kubeconfig available at `/root/k3s-remote-kubeconfig.yaml`

#### 2.3 Copy Kubeconfig to MacBook
```bash
# On MacBook
scp root@<k3s-vm-ip>:/root/k3s-remote-kubeconfig.yaml ~/.kube/k3s-config

# Test connection
export KUBECONFIG=~/.kube/k3s-config
kubectl get nodes
kubectl get pods -A
```

#### 2.4 Install Flux CD
```bash
# Copy Flux installation script
scp k8s-setup/install-flux-cd.sh root@<k3s-vm-ip>:/root/

# On the VM
chmod +x /root/install-flux-cd.sh
./install-flux-cd.sh http://<build-vm-ip>:3000 <gitea-token>
```

**Expected Output:**
- Flux CD installed in `flux-system` namespace
- GitRepository and Kustomization CRDs available
- Example configurations created

### Phase 3: MacBook Setup

#### 3.1 Install Chat Sync Automation
```bash
# On MacBook
cd dev-infrastructure-setup/chat-sync

# Install cron-based sync (runs every 30 minutes)
./setup-cron-sync.sh

# Verify cron job
crontab -l | grep chat-sync
```

#### 3.2 Configure Environment
```bash
# Create environment file
cat > ~/.dev-infrastructure.env <<EOF
# Gitea Configuration
GITEA_URL=http://<build-vm-ip>:3000
GITEA_TOKEN=<your-gitea-token>
GITEA_USERNAME=<your-username>
GITEA_REGISTRY=<build-vm-ip>:3000

# K3s Configuration
K3S_URL=https://<k3s-vm-ip>:6443
KUBECONFIG=~/.kube/k3s-config

# Projects
PROJECTS_DIR=~/projects

# Git Configuration
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="your.email@example.com"
EOF

# Source in your shell profile
echo 'source ~/.dev-infrastructure.env' >> ~/.zshrc
source ~/.zshrc
```

#### 3.3 Install Bob Skill
```bash
# Copy Bob skill to Bob's skills directory
# Adjust path based on your Bob installation
cp -r dev-infrastructure-setup/bob-skill ~/.bob/skills/project-init

# Make scripts executable
chmod +x ~/.bob/skills/project-init/skill-handler.sh
```

### Phase 4: Verification & Testing

#### 4.1 Test Complete Pipeline
```bash
# Create test project using Bob skill
# In Bob chat: "Create a new Python project called test-api"
# Or manually:
cd dev-infrastructure-setup/project-templates
./scaffold-project.sh test-api python

# Navigate to project
cd ~/projects/test-api

# Review generated files
ls -la
cat QUICKSTART.md
```

#### 4.2 Test Local Build
```bash
cd ~/projects/test-api

# Build Docker image
docker build -t test-api:local .

# Run locally
docker run -p 8000:8000 test-api:local

# Test in another terminal
curl http://localhost:8000/health
```

#### 4.3 Push to Gitea
```bash
# Create repository in Gitea web UI
# Then push
git remote add origin http://<build-vm-ip>:3000/<username>/test-api.git
git push -u origin main

# Watch Gitea Actions
# Open: http://<build-vm-ip>:3000/<username>/test-api/actions
```

#### 4.4 Verify Deployment
```bash
# Check Flux CD
export KUBECONFIG=~/.kube/k3s-config
flux get sources git -A
flux get kustomizations -A

# Check pods
kubectl get pods -n apps -l app=test-api

# Port forward to test
kubectl port-forward -n apps svc/test-api 8080:80

# Test in another terminal
curl http://localhost:8080/health
```

## 🔧 Configuration Details

### Gitea Configuration

**Web Interface**: `http://<build-vm-ip>:3000`
**SSH Port**: `2222`
**Container Registry**: `<build-vm-ip>:3000/<username>/<image>`

**Important Settings**:
- Enable Container Registry in Settings
- Enable Actions in Settings
- Configure webhooks for CI/CD triggers

### K3s Configuration

**API Server**: `https://<k3s-vm-ip>:6443`
**Kubeconfig**: `~/.kube/k3s-config`

**Default Namespaces**:
- `flux-system`: Flux CD components
- `apps`: Application deployments
- `monitoring`: Monitoring stack (optional)

### Flux CD Configuration

**GitRepository Source**: Points to Gitea repository
**Kustomization**: Applies manifests from `k8s/` directory
**Image Automation**: Watches Gitea registry for new images

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ MacBook (Development)                                    │
│  ├─ Claude Code → .claude-chats/                        │
│  ├─ IBM Bob → .bob-chats/                               │
│  ├─ Git push → Gitea                                    │
│  └─ kubectl → K3s                                       │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ Build VM (AlmaLinux 10)                                 │
│  ├─ Gitea (port 3000)                                   │
│  │  ├─ Git repositories                                 │
│  │  ├─ Container registry                               │
│  │  └─ Actions (CI/CD)                                  │
│  ├─ Docker (image builds)                               │
│  └─ Gitea Actions Runner                                │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ K3s VM (AlmaLinux 10)                                   │
│  ├─ K3s (Kubernetes)                                    │
│  ├─ Flux CD (GitOps)                                    │
│  │  ├─ Watches Gitea repos                             │
│  │  ├─ Watches container registry                       │
│  │  └─ Auto-deploys changes                             │
│  └─ Application Pods                                    │
└─────────────────────────────────────────────────────────┘
```

## 🔄 Development Workflow

### Standard Workflow
1. **Create Project**: Use Bob skill or scaffold script
2. **Develop**: Write code, test locally
3. **Commit**: Git commit triggers chat sync
4. **Push**: Push to Gitea
5. **Build**: Gitea Actions builds Docker image
6. **Deploy**: Flux CD deploys to K3s
7. **Monitor**: Check logs and metrics

### Chat Sync Workflow
1. **Automatic**: Post-commit hook syncs after each commit
2. **Scheduled**: Cron job syncs every 30 minutes
3. **Manual**: Run `sync-chats.sh` anytime
4. **Storage**: Chats stored in `.claude-chats/` and `.bob-chats/`

## 🆘 Troubleshooting

### Gitea Issues

**Problem**: Gitea not accessible
```bash
# Check service
systemctl status gitea

# Check logs
journalctl -u gitea -n 50

# Check firewall
firewall-cmd --list-ports
```

**Problem**: Actions runner not working
```bash
# Check runner status
systemctl status gitea-runner

# Check runner logs
journalctl -u gitea-runner -f

# Re-register runner
sudo -u gitea-runner act_runner register --instance <url> --token <token>
```

### K3s Issues

**Problem**: K3s not starting
```bash
# Check service
systemctl status k3s

# Check logs
journalctl -u k3s -n 100

# Check node status
kubectl get nodes
kubectl describe node
```

**Problem**: Pods not starting
```bash
# Check pod status
kubectl get pods -A

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Flux CD Issues

**Problem**: Flux not syncing
```bash
# Check Flux status
flux get all -A

# Check source
flux get sources git -A

# Reconcile manually
flux reconcile source git <source-name>

# Check logs
flux logs --all-namespaces --follow
```

### Chat Sync Issues

**Problem**: Chats not syncing
```bash
# Check cron job
crontab -l | grep chat-sync

# Check sync log
tail -f ~/.chat-sync-cron.log

# Manual sync
~/dev-infrastructure-setup/chat-sync/sync-chats.sh ~/projects/<project>

# Check git hooks
ls -la ~/projects/<project>/.git/hooks/post-commit
```

## 📚 Additional Resources

### Scripts Reference
- `vm-setup/install-gitea-almalinux.sh`: Gitea installation
- `vm-setup/setup-gitea-actions-runner.sh`: Actions runner setup
- `k8s-setup/install-k3s-almalinux.sh`: K3s installation
- `k8s-setup/install-flux-cd.sh`: Flux CD installation
- `chat-sync/sync-chats.sh`: Manual chat sync
- `chat-sync/install-git-hooks.sh`: Install git hooks
- `chat-sync/setup-cron-sync.sh`: Setup cron job
- `project-templates/scaffold-project.sh`: Create new project
- `bob-skill/skill-handler.sh`: Bob skill handler

### Configuration Files
- `~/.dev-infrastructure.env`: Environment variables
- `~/.kube/k3s-config`: K3s kubeconfig
- `/etc/systemd/system/gitea.service`: Gitea service
- `/etc/systemd/system/k3s.service`: K3s service
- `/etc/systemd/system/gitea-runner.service`: Runner service

### Useful Commands
```bash
# Gitea
systemctl status gitea
journalctl -u gitea -f

# K3s
kubectl get all -A
kubectl logs -n apps -l app=<app-name>

# Flux CD
flux get all -A
flux logs --all-namespaces

# Chat Sync
tail -f ~/.chat-sync-cron.log
crontab -l

# Docker
docker ps
docker logs <container-id>
```

## 🎓 Next Steps

1. **Customize**: Adjust configurations for your needs
2. **Secure**: Add TLS, authentication, network policies
3. **Monitor**: Set up Prometheus, Grafana, Instana
4. **Scale**: Add more K3s nodes, configure HA
5. **Backup**: Implement backup strategies for Gitea and K3s
6. **Document**: Keep CLAUDE.md and BOB.md updated

## 🤝 Support

For issues or questions:
1. Check troubleshooting section
2. Review logs for specific components
3. Consult individual script documentation
4. Ask Claude Code or IBM Bob for assistance

---
**Version**: 1.0.0  
**Last Updated**: 2026-03-26  
**Maintained By**: Development Team