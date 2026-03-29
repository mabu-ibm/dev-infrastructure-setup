# Development Infrastructure Setup

Complete CI/CD infrastructure setup with Gitea, Docker, K3s, and automated deployments on AlmaLinux 10.

## 🚀 Quick Start

**New to this project?** Start here:

1. **[Complete Infrastructure Guide](docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)** - Step-by-step setup from scratch (⭐ **START HERE**)
2. **[Architecture Overview](docs/ARCHITECTURE.md)** - Understand the system design
3. **[Quick Start Guide](docs/QUICKSTART.md)** - Fast setup for experienced users

## 📚 Documentation Index

### Getting Started
- **[Complete Infrastructure Guide](docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)** - Master guide with everything you need
- [Architecture Overview](docs/ARCHITECTURE.md) - System design and data flow
- [Quick Start Guide](docs/QUICKSTART.md) - Fast setup for experienced users

### Host Setup
- [almabuild Setup](docs/ALMABUILD_SETUP.md) - Build server with Gitea, Docker, and CI/CD runner
- [almak3s Setup](docs/ALMAK3S_SETUP.md) - Kubernetes cluster setup
- [SSH Passwordless Setup](docs/SSH_PASSWORDLESS_SETUP.md) - Configure SSH keys

### CI/CD and Deployment
- [Gitea Actions Complete Setup](docs/GITEA_ACTIONS_COMPLETE_SETUP.md) - CI/CD pipeline configuration
- [Gitea Runner Troubleshooting](docs/GITEA_RUNNER_TROUBLESHOOTING.md) - Fix common runner issues
- [Auto Deployment Guide](docs/AUTO_DEPLOYMENT_GUIDE.md) - Automated deployment workflows
- [Git Repository Setup](docs/GIT_REPOSITORY_SETUP.md) - Repository configuration

### Application Deployment
- [Hello World Python Deployment](project-templates/hello-world-python/DEPLOYMENT_GUIDE.md) - Complete example application

### Reference
- [GitOps Decision Guide](docs/GITOPS_DECISION_GUIDE.md) - Choose the right GitOps tool
- [ArgoCD vs Flux Comparison](docs/ARGOCD_VS_FLUX_COMPARISON.md) - Detailed comparison

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     almabuild (Build Host)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Gitea     │  │    Docker    │  │ Gitea Runner │      │
│  │  + Registry  │  │              │  │   + kubectl  │      │
│  │  Port 3000   │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             │ Remote kubectl (6443)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                     almak3s (K3s Host)                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    K3s Cluster                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │   Pod 1    │  │   Pod 2    │  │  Service   │     │   │
│  │  │  App:8080  │  │  App:8080  │  │ NodePort   │     │   │
│  │  └────────────┘  └────────────┘  │  :30xxx    │     │   │
│  │                                   └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
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

## 🎯 What This Project Provides

### Infrastructure Components

✅ **Gitea** - Self-hosted Git service with integrated container registry  
✅ **Gitea Actions** - CI/CD automation (GitHub Actions compatible)  
✅ **Docker** - Container runtime and image building  
✅ **K3s** - Lightweight Kubernetes for application deployment  
✅ **Automated Pipeline** - Push code → Build → Test → Deploy  

### Automation Scripts

#### VM Setup (`vm-setup/`)
- `install-gitea-almalinux.sh` - Install Gitea with SQLite/MySQL
- `setup-gitea-actions-runner.sh` - Install and configure CI/CD runner
- `fix-docker-almalinux.sh` - Fix Docker installation issues
- `setup-ssh-passwordless.sh` - Configure SSH keys

#### K8s Setup (`k8s-setup/`)
- `install-k3s-almalinux.sh` - Install K3s cluster
- `install-argocd-gitea.sh` - Install ArgoCD (optional)
- `install-flux-cd.sh` - Install Flux CD (optional)

#### Project Templates (`project-templates/`)
- `hello-world-python/` - Complete Python Flask example with CI/CD
- `scaffold-project.sh` - Create new projects from templates

#### MacBook Setup (`macbook-setup/`)
- `install-prerequisites.sh` - Install development tools
- `configure-environment.sh` - Setup environment variables

## 📋 Prerequisites

### Hardware Requirements

**almabuild (Build Host):**
- CPU: 2+ cores
- RAM: 4GB minimum, 8GB recommended
- Disk: 50GB+ free space
- OS: AlmaLinux 10

**almak3s (K3s Host):**
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

## 🚦 Setup Process

### Phase 1: almabuild Setup (30-45 minutes)

1. Install Docker
2. Install Gitea with SQLite/MySQL
3. Enable Gitea Actions
4. Install and configure Gitea Actions Runner
5. Setup kubectl for remote K3s access

**Guide:** [almabuild Setup](docs/ALMABUILD_SETUP.md)

### Phase 2: almak3s Setup (15-20 minutes)

1. Install K3s
2. Configure firewall
3. Setup insecure registry
4. Create registry secret

**Guide:** [almak3s Setup](docs/ALMAK3S_SETUP.md)

### Phase 3: Deploy Application (10-15 minutes)

1. Create repository in Gitea
2. Configure secrets
3. Push application code
4. Watch automated deployment

**Guide:** [Complete Infrastructure Guide](docs/COMPLETE_INFRASTRUCTURE_GUIDE.md#phase-3-deploy-test-application)

## 🔧 Usage Examples

### Deploy New Application

```bash
# 1. Create repository in Gitea
# 2. Clone template
cd project-templates/hello-world-python
cp -r . ~/my-new-app

# 3. Initialize git
cd ~/my-new-app
git init
git branch -M main

# 4. Add remote and push
git remote add origin http://almabuild:3000/username/my-new-app.git
git add .
git commit -m "Initial commit"
git push -u origin main

# 5. Watch automatic deployment in Gitea Actions tab
```

### Update Existing Application

```bash
# Make changes
nano app.py

# Commit and push
git add .
git commit -m "Update feature"
git push

# Automatic: Build → Test → Deploy
```

### Check Deployment Status

```bash
# On almak3s or almabuild (with kubectl)
kubectl get deployments
kubectl get pods
kubectl get services

# View logs
kubectl logs -l app=my-app -f

# Access application
curl http://almak3s:30xxx/
```

## 🐛 Troubleshooting

### Common Issues

**Gitea Actions not visible:**
```bash
sudo nano /var/lib/gitea/custom/conf/app.ini
# Add: [actions] ENABLED = true
sudo systemctl restart gitea
```

**Runner not starting:**
```bash
sudo /usr/local/bin/fix-gitea-runner.sh
sudo systemctl restart gitea-runner
```

**ImagePullBackOff in K3s:**
```bash
# Check registry config
sudo cat /etc/rancher/k3s/registries.yaml
sudo systemctl restart k3s
```

**kubectl connection refused:**
```bash
# Check firewall
sudo firewall-cmd --list-ports
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --reload
```

**Full troubleshooting guide:** [Gitea Runner Troubleshooting](docs/GITEA_RUNNER_TROUBLESHOOTING.md)

## 📊 Project Structure

```
dev-infrastructure-setup/
├── README.md                          # This file
├── .env.template                      # Environment variables template
├── docs/                              # Documentation
│   ├── COMPLETE_INFRASTRUCTURE_GUIDE.md  # ⭐ Master setup guide
│   ├── ARCHITECTURE.md                # System architecture
│   ├── QUICKSTART.md                  # Quick setup guide
│   ├── ALMABUILD_SETUP.md            # Build host setup
│   ├── ALMAK3S_SETUP.md              # K3s host setup
│   ├── GITEA_ACTIONS_COMPLETE_SETUP.md  # CI/CD setup
│   ├── GITEA_RUNNER_TROUBLESHOOTING.md  # Runner issues
│   └── ...                            # Additional guides
├── vm-setup/                          # VM setup scripts
│   ├── install-gitea-almalinux.sh    # Gitea installation
│   ├── setup-gitea-actions-runner.sh # Runner setup
│   ├── fix-docker-almalinux.sh       # Docker fixes
│   └── setup-ssh-passwordless.sh     # SSH configuration
├── k8s-setup/                         # Kubernetes setup
│   ├── install-k3s-almalinux.sh      # K3s installation
│   ├── install-argocd-gitea.sh       # ArgoCD (optional)
│   └── install-flux-cd.sh            # Flux CD (optional)
├── project-templates/                 # Application templates
│   └── hello-world-python/           # Python Flask example
│       ├── app.py                    # Application code
│       ├── Dockerfile                # Container image
│       ├── requirements.txt          # Python dependencies
│       ├── .gitea/workflows/         # CI/CD workflows
│       ├── k8s/                      # Kubernetes manifests
│       └── DEPLOYMENT_GUIDE.md       # Deployment guide
├── macbook-setup/                     # Development machine setup
│   ├── install-prerequisites.sh      # Install tools
│   └── configure-environment.sh      # Environment setup
└── bob-skill/                         # IBM Bob AI integration
    ├── skill-handler.sh              # Skill handler
    └── SKILL.md                      # Skill documentation
```

## 🔐 Security Considerations

### Production Recommendations

1. **Use HTTPS for Gitea**
   - Setup reverse proxy (Nginx/Traefik)
   - Configure Let's Encrypt certificates

2. **Secure Registry**
   - Enable TLS for container registry
   - Use strong authentication

3. **Network Security**
   - Configure firewall rules
   - Use VPN for remote access
   - Implement network policies in K3s

4. **Secrets Management**
   - Use Kubernetes secrets
   - Consider external secret management (Vault)
   - Rotate credentials regularly

5. **Access Control**
   - Enable RBAC in K3s
   - Use least privilege principle
   - Audit access logs

## 🔄 Maintenance

### Regular Tasks

**Daily:**
- Monitor service health
- Check disk space
- Review logs for errors

**Weekly:**
- Update Docker images
- Review security alerts
- Backup Gitea data

**Monthly:**
- Update system packages
- Update K3s version
- Review and rotate secrets

**Backup Strategy:**
```bash
# Gitea backup
sudo systemctl stop gitea
sudo tar czf gitea-backup-$(date +%Y%m%d).tar.gz /var/lib/gitea
sudo systemctl start gitea

# K3s backup
sudo k3s etcd-snapshot save
```

## 🎓 Learning Resources

### Official Documentation
- [Gitea Documentation](https://docs.gitea.com/)
- [Gitea Actions](https://docs.gitea.com/usage/actions/overview)
- [K3s Documentation](https://docs.k3s.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Tutorials
- [Complete Infrastructure Guide](docs/COMPLETE_INFRASTRUCTURE_GUIDE.md) - This project's master guide
- [Hello World Python Example](project-templates/hello-world-python/DEPLOYMENT_GUIDE.md) - Working example

## 🤝 Contributing

This is a personal infrastructure setup project. Feel free to fork and adapt for your needs.

## 📝 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- AlmaLinux Project
- Gitea Project
- K3s/Rancher
- Docker
- Kubernetes Community

---

## 📞 Support

For issues and questions:
1. Check [Troubleshooting Guide](docs/GITEA_RUNNER_TROUBLESHOOTING.md)
2. Review [Complete Infrastructure Guide](docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)
3. Check service logs: `sudo journalctl -u SERVICE_NAME -n 50`

---

**Created with IBM Bob AI** 🤖

**Happy Building!** 🚀