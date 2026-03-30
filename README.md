# Development Infrastructure Setup

Complete development infrastructure with automated CI/CD, GitOps, and SBOM generation for secure application development.

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone <your-repo-url>
cd dev-infrastructure-setup

# 2. Configure environment
cp .env.template ~/.dev-infrastructure.env
# Edit ~/.dev-infrastructure.env with your settings

# 3. Source environment
source ~/.dev-infrastructure.env

# 4. Create new project
./project-templates/scaffold-project.sh my-app python
```

## 📋 Features

### Core Infrastructure
- **Build VM**: AlmaLinux 10 with Gitea + Docker registry
- **K8s Cluster**: K3s for container orchestration
- **GitOps**: Flux CD for automated deployments
- **CI/CD**: Gitea Actions for build automation

### Security & Observability
- **SBOM Generation**: Automatic Software Bill of Materials with Syft (always generated)
- **Concert Integration**: Optional SBOM upload to IBM Concert for vulnerability tracking
- **Security Scanning**: Container image vulnerability analysis
- **Compliance Tracking**: Automated compliance monitoring

### Developer Experience
- **Project Templates**: Python, Node.js, Go, Java, Rust
- **AI Assistant Integration**: Claude Code and IBM Bob context files
- **Chat Sync**: Automatic conversation history tracking
- **Multi-stage Builds**: Optimized Docker images

## 📚 Documentation

### Getting Started
- [Quick Start Guide](docs/QUICKSTART.md) - Get up and running in minutes
- [Complete Setup Guide](docs/COMPLETE_SETUP_GUIDE.md) - Detailed infrastructure setup
- [Architecture Overview](docs/ARCHITECTURE.md) - System design and components

### Infrastructure Setup
- [AlmaBuild VM Setup](docs/ALMABUILD_SETUP.md) - Build server configuration
- [AlmaK3s VM Setup](docs/ALMAK3S_SETUP.md) - Kubernetes cluster setup
- [SSH Passwordless Setup](docs/SSH_PASSWORDLESS_SETUP.md) - Secure VM access

### Development Workflows
- [Git Repository Setup](docs/GIT_REPOSITORY_SETUP.md) - Repository configuration
- [GitHub Setup](docs/GITHUB_SETUP.md) - GitHub integration
- [Auto Deployment Guide](docs/AUTO_DEPLOYMENT_GUIDE.md) - Automated deployments

### Security & SBOM
- **[SBOM Generation Guide](docs/SBOM_GENERATION_GUIDE.md)** - Complete SBOM workflow
- [Security Hardening](docs/SECURITY_HARDENING_GUIDE.md) - Security best practices

### GitOps
- [GitOps Decision Guide](docs/GITOPS_DECISION_GUIDE.md) - Choose your GitOps tool
- [ArgoCD vs Flux Comparison](docs/ARGOCD_VS_FLUX_COMPARISON.md) - Detailed comparison

## 🔧 SBOM Generation

### Generate SBOM Locally

```bash
# From Docker image
./scripts/generate-sbom.sh myapp:latest

# From source code
./scripts/generate-sbom.sh

# Generate and upload to Concert
./scripts/generate-sbom.sh myapp:latest --upload
```

### Configure Concert Integration

```bash
# Add to ~/.dev-infrastructure.env
export CONCERT_URL="https://YOUR_INSTANCE.concert.saas.ibm.com"
export CONCERT_API_KEY="YOUR_API_KEY"
export CONCERT_INSTANCE_ID="YOUR_INSTANCE_ID"
export CONCERT_APPLICATION_ID="YOUR_APP_ID"
export SBOM_ENABLED="true"
```

### CI/CD SBOM Generation

**SBOMs are automatically generated on every build** and stored as artifacts.

**Concert upload is optional** and happens when:
1. `CONCERT_URL` secret is configured in Gitea
2. Other Concert credentials are set (API key, instance ID)

See [SBOM Generation Guide](docs/SBOM_GENERATION_GUIDE.md) for complete details.

## 🏗️ Project Structure

```
dev-infrastructure-setup/
├── scripts/                    # Utility scripts
│   ├── generate-sbom.sh       # SBOM generation with Syft
│   └── upload-sbom-to-concert.py  # Concert upload script
├── project-templates/          # Project scaffolding
│   ├── scaffold-project.sh    # Create new projects
│   └── hello-world-python/    # Python template with SBOM
├── vm-setup/                   # VM configuration scripts
├── k8s-setup/                  # Kubernetes setup scripts
├── macbook-setup/              # Local development setup
├── chat-sync/                  # AI chat history sync
├── bob-skill/                  # IBM Bob skill integration
└── docs/                       # Documentation
```

## 🎯 Supported Stacks

- **Python**: FastAPI/Flask with pip
- **Node.js**: Express/NestJS with npm
- **Go**: Standard library with modules
- **Java**: Spring Boot with Maven (planned)
- **Rust**: Actix/Rocket with Cargo (planned)

## 🔐 Security Features

### SBOM Generation
- Automatic dependency inventory
- Multiple format support (SPDX, CycloneDX, Syft)
- Container image scanning
- Source code analysis

### Concert Integration
- Vulnerability tracking
- Risk scoring and prioritization
- Compliance monitoring
- Automated alerting

### Container Security
- Multi-stage builds
- Non-root users
- Minimal base images
- Security scanning

## 🚢 Deployment Pipeline

```
Developer → Gitea → Actions Runner → Docker Build → SBOM Generation
                                          ↓
                                    Gitea Registry
                                          ↓
                                    Concert Upload
                                          ↓
                                      Flux CD
                                          ↓
                                    K3s Deployment
```

## 📦 Creating New Projects

```bash
# Create Python project with SBOM support
./project-templates/scaffold-project.sh my-api python

# Project includes:
# - Multi-stage Dockerfile
# - Kubernetes manifests
# - Gitea Actions with SBOM generation
# - SBOM upload scripts
# - AI assistant context files
# - Chat sync automation
```

## 🔄 CI/CD Workflow

1. **Code Push**: Developer pushes to Gitea
2. **Build**: Gitea Actions builds Docker image
3. **SBOM**: Syft generates Software Bill of Materials
4. **Upload**: SBOM uploaded to Concert (if configured)
5. **Registry**: Image pushed to Gitea registry
6. **Deploy**: Flux CD detects and deploys to K3s

## 🛠️ Available Scripts

### SBOM Scripts
- [`generate-sbom.sh`](scripts/generate-sbom.sh) - Generate SBOM with Syft
- [`upload-sbom-to-concert.py`](scripts/upload-sbom-to-concert.py) - Upload to Concert

### Project Management
- [`scaffold-project.sh`](project-templates/scaffold-project.sh) - Create new project
- [`init-git-repo.sh`](init-git-repo.sh) - Initialize git repository
- [`push-to-git.sh`](push-to-git.sh) - Push to remote repository

### Infrastructure
- [`install-k3s-almalinux.sh`](k8s-setup/install-k3s-almalinux.sh) - K3s installation
- [`install-gitea-almalinux.sh`](vm-setup/install-gitea-almalinux.sh) - Gitea setup
- [`setup-gitea-actions-runner.sh`](vm-setup/setup-gitea-actions-runner.sh) - Actions runner

### Chat Sync
- [`sync-chats.sh`](chat-sync/sync-chats.sh) - Sync AI conversations
- [`install-git-hooks.sh`](chat-sync/install-git-hooks.sh) - Install sync hooks

## 🌐 Environment Variables

See [`.env.template`](.env.template) for complete configuration options:

- **Gitea**: URL, token, registry
- **K3s**: Cluster URL, kubeconfig
- **VMs**: Build and K3s VM IPs
- **Concert**: URL, API key, instance ID, application ID
- **SBOM**: Format, enabled flag

## 📖 Additional Resources

### External Documentation
- [Syft Documentation](https://github.com/anchore/syft)
- [SPDX Specification](https://spdx.dev/)
- [CycloneDX Specification](https://cyclonedx.org/)
- [IBM Concert Documentation](https://www.ibm.com/docs/concert)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)

### Internal Guides
- [Complete Infrastructure Guide](docs/COMPLETE_INFRASTRUCTURE_GUIDE.md)
- [Gitea Actions Setup](docs/GITEA_ACTIONS_COMPLETE_SETUP.md)
- [Gitea Runner Troubleshooting](docs/GITEA_RUNNER_TROUBLESHOOTING.md)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Syft** by Anchore for SBOM generation
- **IBM Concert** for security observability
- **Flux CD** for GitOps automation
- **K3s** for lightweight Kubernetes
- **Gitea** for self-hosted Git service

## 📧 Support

For issues or questions:
1. Check documentation in [`docs/`](docs/)
2. Review [SBOM Generation Guide](docs/SBOM_GENERATION_GUIDE.md)
3. Check [Troubleshooting](docs/SBOM_GENERATION_GUIDE.md#troubleshooting)
4. Open an issue on GitHub

---

**Built with ❤️ for secure, automated application development**