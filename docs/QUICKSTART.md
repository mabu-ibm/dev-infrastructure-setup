# Quick Start Guide

Get your development infrastructure up and running in minutes!

## Overview

This guide will help you set up a complete CI/CD infrastructure with two AlmaLinux 10 hosts:
- **almabuild**: Git hosting, CI/CD, and container registry
- **almak3s**: Kubernetes cluster for deployments

## Prerequisites

- 2 AlmaLinux 10 virtual machines or physical servers
- Root/sudo access on both hosts
- Internet connectivity
- Basic knowledge of Linux, Git, and Docker

## 30-Minute Setup

### Part 1: almabuild Setup (15 minutes)

#### 1. Install Docker (3 minutes)
```bash
cd /path/to/dev-infrastructure-setup
sudo ./vm-setup/fix-docker-almalinux.sh
```

Wait for completion, then verify:
```bash
docker run hello-world
```

#### 2. Install Gitea (5 minutes)
```bash
sudo ./vm-setup/install-gitea-almalinux.sh
```

When prompted:
- Choose **1** for SQLite (simplest option)
- Press Enter to accept defaults

Access Gitea:
```
http://almabuild:3000
```

Complete web setup:
1. Keep default settings
2. Create admin account
3. Click "Install Gitea"

#### 3. Install Actions Runner (7 minutes)
```bash
sudo ./vm-setup/setup-gitea-actions-runner.sh
```

Register the runner:
1. Log into Gitea as admin
2. Go to: **Site Administration → Actions → Runners**
3. Click **"Create new Runner"**
4. Copy the token
5. Run:
```bash
cd /var/lib/act_runner
sudo -u gitea-runner /usr/local/bin/act_runner register \
  --instance http://localhost:3000 \
  --token YOUR_TOKEN \
  --name build-runner-almabuild \
  --labels ubuntu-latest,almalinux-latest
```

6. Start the service:
```bash
sudo systemctl enable gitea-runner
sudo systemctl start gitea-runner
```

7. Verify in Gitea UI - runner should show as "Idle"

### Part 2: almak3s Setup (15 minutes)

#### 1. Install K3s (10 minutes)
```bash
cd /path/to/dev-infrastructure-setup
sudo ./k8s-setup/install-k3s-almalinux.sh
```

Wait for installation to complete.

#### 2. Configure kubectl (2 minutes)
```bash
# For non-root user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Add to shell
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Verify Installation (3 minutes)
```bash
# Check node
kubectl get nodes

# Check pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

Expected output:
```
NAME      STATUS   ROLES                  AGE   VERSION
almak3s   Ready    control-plane,master   1m    v1.28.x+k3s1
```

## First Deployment Test

### 1. Create Test Repository in Gitea

1. Log into Gitea: `http://almabuild:3000`
2. Click **"+"** → **"New Repository"**
3. Name: `hello-world`
4. Click **"Create Repository"**

### 2. Add Workflow File

Clone the repository:
```bash
git clone http://almabuild:3000/your-username/hello-world.git
cd hello-world
```

Create workflow directory and file:
```bash
mkdir -p .gitea/workflows
cat > .gitea/workflows/build.yaml <<'EOF'
name: Build and Push
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build info
        run: |
          echo "Building application..."
          date
          uname -a
          
      - name: Create simple app
        run: |
          mkdir -p app
          echo "Hello from Gitea Actions!" > app/index.html
          
      - name: Show files
        run: ls -la app/
EOF
```

### 3. Push and Watch

```bash
git add .gitea/
git commit -m "Add CI workflow"
git push origin main
```

Watch the build:
1. Go to repository in Gitea
2. Click **"Actions"** tab
3. See your workflow running
4. Click on the run to see logs

### 4. Deploy to K3s

Create a simple deployment:
```bash
# On almak3s host
kubectl create deployment hello --image=nginx:latest
kubectl expose deployment hello --port=80 --type=NodePort
kubectl get svc hello
```

Access the application:
```bash
# Get the NodePort
PORT=$(kubectl get svc hello -o jsonpath='{.spec.ports[0].nodePort}')
curl http://almak3s:$PORT
```

## What's Next?

### Learn More
- [Architecture Overview](ARCHITECTURE.md)
- [almabuild Detailed Setup](ALMABUILD_SETUP.md)
- [almak3s Detailed Setup](ALMAK3S_SETUP.md)
- [Complete Setup Guide](COMPLETE_SETUP_GUIDE.md)

### Common Next Steps

1. **Build Docker Images**
   - Add Dockerfile to your repository
   - Update workflow to build and push images
   - Deploy images to K3s

2. **Set Up Container Registry**
   - Enable packages in Gitea
   - Configure image pull secrets in K3s
   - Push images to Gitea registry

3. **Configure Ingress**
   - Set up domain names
   - Configure Traefik ingress
   - Add TLS certificates

4. **Add Monitoring**
   - Install Prometheus
   - Set up Grafana dashboards
   - Configure alerts

5. **Implement GitOps**
   - Store K8s manifests in Git
   - Automate deployments from CI/CD
   - Use Kustomize or Helm

## Troubleshooting Quick Fixes

### Gitea Issues
```bash
# Check service
sudo systemctl status gitea

# View logs
sudo journalctl -u gitea -f

# Restart
sudo systemctl restart gitea
```

### Actions Runner Issues
```bash
# Check service
sudo systemctl status gitea-runner

# View logs
sudo journalctl -u gitea-runner -f

# Restart
sudo systemctl restart gitea-runner
```

### K3s Issues
```bash
# Check service
sudo systemctl status k3s

# View logs
sudo journalctl -u k3s -f

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -A
```

### Docker Issues
```bash
# Check service
sudo systemctl status docker

# View logs
sudo journalctl -u docker -f

# Restart
sudo systemctl restart docker
```

## Quick Reference

### Gitea
- **Web UI**: http://almabuild:3000
- **SSH**: ssh://git@almabuild:2222
- **Config**: /var/lib/gitea/custom/conf/app.ini
- **Logs**: /var/log/gitea/

### K3s
- **API**: https://almak3s:6443
- **Kubeconfig**: /etc/rancher/k3s/k3s.yaml
- **Data**: /var/lib/rancher/k3s/

### Useful Commands

**Gitea:**
```bash
sudo systemctl status gitea
sudo journalctl -u gitea -f
```

**Actions Runner:**
```bash
sudo systemctl status gitea-runner
sudo journalctl -u gitea-runner -f
```

**K3s:**
```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
kubectl logs <pod-name>
```

**Docker:**
```bash
docker ps
docker images
docker logs <container-id>
```

## Support

If you encounter issues:

1. Check the detailed guides:
   - [almabuild Setup](ALMABUILD_SETUP.md)
   - [almak3s Setup](ALMAK3S_SETUP.md)

2. Review logs:
   ```bash
   sudo journalctl -u gitea -n 100
   sudo journalctl -u gitea-runner -n 100
   sudo journalctl -u k3s -n 100
   ```

3. Verify services:
   ```bash
   systemctl status gitea
   systemctl status gitea-runner
   systemctl status k3s
   ```

4. Check network connectivity:
   ```bash
   ping almabuild
   ping almak3s
   curl http://almabuild:3000
   ```

## Success Checklist

- [ ] Docker running on almabuild
- [ ] Gitea accessible at http://almabuild:3000
- [ ] Gitea admin account created
- [ ] Actions runner registered and idle
- [ ] K3s running on almak3s
- [ ] kubectl working
- [ ] Test workflow executed successfully
- [ ] Test deployment running on K3s

Congratulations! Your infrastructure is ready for development! 🎉