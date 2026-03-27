# Development Infrastructure Setup

Complete infrastructure setup for CI/CD pipeline with Gitea and Kubernetes on AlmaLinux 10.

## 🚀 Quick Start

Get your infrastructure running in 30 minutes:

```bash
# On almabuild host
sudo ./vm-setup/fix-docker-almalinux.sh
sudo ./vm-setup/install-gitea-almalinux.sh
sudo ./vm-setup/setup-gitea-actions-runner.sh

# On almak3s host
sudo ./k8s-setup/install-k3s-almalinux.sh
```

📖 **[Read the Quick Start Guide](docs/QUICKSTART.md)**

## 📋 Overview

This project provides automated setup scripts for a complete development infrastructure:

### almabuild (Build Host)
- **Docker** - Container runtime
- **Gitea** - Git hosting and container registry
- **Gitea Actions Runner** - CI/CD automation

### almak3s (Kubernetes Host)
- **K3s** - Lightweight Kubernetes distribution
- **Traefik** - Ingress controller
- **Local-path** - Storage provisioner

## 🏗️ Architecture

```
┌──────────────────────────┐         ┌──────────────────────────┐
│   almabuild              │         │  almak3s                 │
│                          │         │                          │
│  ┌────────────────────┐  │         │  ┌────────────────────┐  │
│  │      Docker        │  │         │  │       K3s          │  │
│  └────────┬───────────┘  │         │  │  (Kubernetes)      │  │
│           │              │         │  └────────┬───────────┘  │
│  ┌────────▼───────────┐  │         │           │              │
│  │      Gitea         │  │         │  ┌────────▼───────────┐  │
│  │  - Git Repos       │  │         │  │   Deployments      │  │
│  │  - Registry        │  │         │  │  - Applications    │  │
│  │  - Actions         │  │         │  │  - Services        │  │
│  └────────┬───────────┘  │         │  └────────────────────┘  │
│           │              │         │                          │
│  ┌────────▼───────────┐  │         │                          │
│  │  Actions Runner    │  │         │                          │
│  │  - Build & Test    │◄─┼─────────┼──────────────────────────┤
│  │  - Push Images     │  │         │      Auto Deploy         │
│  └────────────────────┘  │         │                          │
└──────────────────────────┘         └──────────────────────────┘
```

📖 **[View Full Architecture](docs/ARCHITECTURE.md)**

## 📚 Documentation

### Getting Started
- **[Quick Start Guide](docs/QUICKSTART.md)** - 30-minute setup
- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design and components

### Host Setup Guides
- **[almabuild Setup](docs/ALMABUILD_SETUP.md)** - Docker, Gitea, Actions Runner
- **[almak3s Setup](docs/ALMAK3S_SETUP.md)** - K3s Kubernetes cluster

### Advanced Topics
- **[Auto Deployment Guide](docs/AUTO_DEPLOYMENT_GUIDE.md)** - Automatic pod updates on new images
- **[SSH Passwordless Setup](docs/SSH_PASSWORDLESS_SETUP.md)** - SSH key configuration
- **[Complete Setup Guide](docs/COMPLETE_SETUP_GUIDE.md)** - Detailed walkthrough

## 🛠️ Installation Scripts

### almabuild Host

| Script | Purpose | Time |
|--------|---------|------|
| `vm-setup/fix-docker-almalinux.sh` | Install and configure Docker | 3 min |
| `vm-setup/install-gitea-almalinux.sh` | Install Gitea with SQLite/MySQL | 5 min |
| `vm-setup/setup-gitea-actions-runner.sh` | Setup CI/CD runner | 7 min |

### almak3s Host

| Script | Purpose | Time |
|--------|---------|------|
| `k8s-setup/install-k3s-almalinux.sh` | Install K3s cluster | 10 min |

### Utility Scripts

| Script | Purpose |
|--------|---------|
| `vm-setup/setup-ssh-passwordless.sh` | Configure SSH keys |
| `k8s-setup/troubleshoot-k3s.sh` | K3s diagnostics |
| `k8s-setup/fix-k3s-network.sh` | Fix network issues |
| `k8s-setup/complete-k3s-reinstall.sh` | Clean reinstall |

## ✨ Features

### Gitea
- ✅ Git repository hosting
- ✅ Container registry (packages)
- ✅ CI/CD with Gitea Actions
- ✅ Web UI on port 3000
- ✅ SSH access on port 2222
- ✅ SQLite or MySQL database
- ✅ LFS support for large files

### Gitea Actions Runner
- ✅ Automated builds on git push
- ✅ Docker image building
- ✅ Multi-platform support (ubuntu, almalinux)
- ✅ Parallel job execution
- ✅ Integration with Gitea registry

### K3s Kubernetes
- ✅ Lightweight Kubernetes
- ✅ Built-in ingress (Traefik)
- ✅ Built-in load balancer (ServiceLB)
- ✅ Local storage provisioner
- ✅ Easy scaling and management
- ✅ Production-ready

## 🎯 Use Cases

### Development Workflow
1. Push code to Gitea repository
2. Gitea Actions automatically builds Docker image
3. Image pushed to Gitea registry
4. K3s pulls and deploys new image
5. Application accessible via ingress

### CI/CD Pipeline
- Automated testing on every commit
- Container image building and scanning
- Automated deployment to Kubernetes
- Rollback capabilities
- Environment-specific deployments (dev/staging/prod)

### Container Management
- Private container registry
- Image versioning and tagging
- Automated image cleanup
- Security scanning integration

## 🔧 System Requirements

### Minimum (Development)
- **almabuild**: 2 CPU, 4 GB RAM, 50 GB disk
- **almak3s**: 2 CPU, 2 GB RAM, 20 GB disk

### Recommended (Production)
- **almabuild**: 4 CPU, 8 GB RAM, 100 GB SSD
- **almak3s**: 4 CPU, 4 GB RAM, 50 GB SSD

### Prerequisites
- AlmaLinux 10 (both hosts)
- Root/sudo access
- Internet connectivity
- Network connectivity between hosts

## 🚦 Quick Commands

### Check Status
```bash
# almabuild
systemctl status docker
systemctl status gitea
systemctl status gitea-runner

# almak3s
systemctl status k3s
kubectl get nodes
kubectl get pods -A
```

### View Logs
```bash
# almabuild
journalctl -u gitea -f
journalctl -u gitea-runner -f

# almak3s
journalctl -u k3s -f
kubectl logs -l app=myapp -f
```

### Access Services
```bash
# Gitea Web UI
http://almabuild:3000

# Gitea SSH
ssh://git@almabuild:2222

# K3s API
https://almak3s:6443

# Application (via ingress)
http://almak3s
```

## 🔄 Automatic Deployment

When a new Docker image is built, automatically update pods in Kubernetes:

```yaml
# .gitea/workflows/deploy.yaml
name: Build and Deploy
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and push
        run: |
          docker build -t almabuild:3000/user/app:latest .
          docker push almabuild:3000/user/app:latest
      - name: Restart pods
        run: |
          kubectl rollout restart deployment/my-app
```

📖 **[Full Auto Deployment Guide](docs/AUTO_DEPLOYMENT_GUIDE.md)**

## 🐛 Troubleshooting

### Common Issues

**Docker won't start:**
```bash
sudo journalctl -u docker -n 100
sudo systemctl restart docker
```

**Gitea not accessible:**
```bash
sudo systemctl status gitea
sudo firewall-cmd --list-ports
curl http://localhost:3000
```

**Actions runner not picking up jobs:**
```bash
sudo systemctl status gitea-runner
sudo journalctl -u gitea-runner -f
```

**K3s pods not starting:**
```bash
kubectl get pods -A
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

## 📦 Project Structure

```
dev-infrastructure-setup/
├── docs/                          # Documentation
│   ├── QUICKSTART.md             # Quick start guide
│   ├── ARCHITECTURE.md           # Architecture overview
│   ├── ALMABUILD_SETUP.md        # Build host setup
│   ├── ALMAK3S_SETUP.md          # K8s host setup
│   ├── AUTO_DEPLOYMENT_GUIDE.md  # Auto deployment
│   ├── SSH_PASSWORDLESS_SETUP.md # SSH configuration
│   └── COMPLETE_SETUP_GUIDE.md   # Detailed guide
├── vm-setup/                      # Build host scripts
│   ├── fix-docker-almalinux.sh   # Docker installation
│   ├── install-gitea-almalinux.sh # Gitea installation
│   ├── setup-gitea-actions-runner.sh # Runner setup
│   └── setup-ssh-passwordless.sh # SSH key setup
├── k8s-setup/                     # K8s host scripts
│   ├── install-k3s-almalinux.sh  # K3s installation
│   ├── troubleshoot-k3s.sh       # Diagnostics
│   ├── fix-k3s-network.sh        # Network fixes
│   └── complete-k3s-reinstall.sh # Clean reinstall
└── README.md                      # This file
```

## 🔐 Security

### Best Practices
- Use strong passwords for Gitea admin
- Enable 2FA for admin accounts
- Regular backups of repositories and databases
- Keep systems updated with security patches
- Use SSH keys instead of passwords
- Restrict firewall to necessary ports only
- Regular security audits
- Monitor logs for suspicious activity

### Firewall Configuration
```bash
# almabuild
firewall-cmd --permanent --add-port=3000/tcp  # Gitea web
firewall-cmd --permanent --add-port=2222/tcp  # Gitea SSH

# almak3s
firewall-cmd --permanent --add-port=6443/tcp  # K8s API
firewall-cmd --permanent --add-port=80/tcp    # HTTP
firewall-cmd --permanent --add-port=443/tcp   # HTTPS
```

## 🔄 Updates

### Update Gitea
```bash
sudo systemctl stop gitea
sudo wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/NEW_VERSION/gitea-NEW_VERSION-linux-amd64
sudo chmod +x /usr/local/bin/gitea
sudo systemctl start gitea
```

### Update K3s
```bash
curl -sfL https://get.k3s.io | sh -
```

### Update System
```bash
sudo dnf update -y
sudo reboot
```

## 📊 Monitoring

### Recommended Tools
- **Prometheus** - Metrics collection
- **Grafana** - Visualization
- **Loki** - Log aggregation
- **AlertManager** - Alerting

### Basic Monitoring
```bash
# Resource usage
kubectl top nodes
kubectl top pods -A

# System metrics
htop
df -h
free -h
```

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## 📝 License

This project is provided as-is for educational and development purposes.

## 🆘 Support

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: Review troubleshooting sections in guides
- **Logs**: Use `journalctl` and `kubectl logs` for debugging

## 🎓 Learning Resources

- [Gitea Documentation](https://docs.gitea.io/)
- [Gitea Actions](https://docs.gitea.io/en-us/usage/actions/overview/)
- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

## ✅ Success Checklist

- [ ] Docker running on almabuild
- [ ] Gitea accessible at http://almabuild:3000
- [ ] Gitea admin account created
- [ ] Actions runner registered and idle
- [ ] K3s running on almak3s
- [ ] kubectl working
- [ ] Test workflow executed successfully
- [ ] Test deployment running on K3s
- [ ] Automatic deployment configured

---

**Made with ❤️ for DevOps automation**

*Last updated: 2026-03-27*