# Infrastructure Architecture

## Overview

This infrastructure consists of two AlmaLinux 10 hosts providing a complete CI/CD pipeline with container orchestration.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Development Infrastructure                   │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐         ┌──────────────────────────┐
│   almabuild (Build Host) │         │  almak3s (K8s Host)      │
│                          │         │                          │
│  ┌────────────────────┐  │         │  ┌────────────────────┐  │
│  │      Docker        │  │         │  │       K3s          │  │
│  │   (Container       │  │         │  │  (Kubernetes)      │  │
│  │    Runtime)        │  │         │  │                    │  │
│  └────────────────────┘  │         │  │  - Control Plane   │  │
│           │              │         │  │  - Worker Node     │  │
│  ┌────────▼───────────┐  │         │  │  - Container       │  │
│  │      Gitea         │  │         │  │    Runtime         │  │
│  │                    │  │         │  └────────────────────┘  │
│  │  - Git Repos       │  │         │           │              │
│  │  - Container       │  │         │  ┌────────▼───────────┐  │
│  │    Registry        │  │         │  │   Deployments      │  │
│  │  - SQLite/MySQL    │  │         │  │                    │  │
│  │  - Web UI :3000    │  │         │  │  - Applications    │  │
│  │  - SSH :2222       │  │         │  │  - Services        │  │
│  └────────────────────┘  │         │  │  - Ingress         │  │
│           │              │         │  └────────────────────┘  │
│  ┌────────▼───────────┐  │         │                          │
│  │  Gitea Actions     │  │         │                          │
│  │     Runner         │  │         │                          │
│  │                    │  │         │                          │
│  │  - CI/CD Pipeline  │  │         │                          │
│  │  - Build Jobs      │  │         │                          │
│  │  - Docker Build    │  │         │                          │
│  │  - Image Push      │◄─┼─────────┼──────────────────────────┤
│  └────────────────────┘  │         │      Deploy Trigger      │
│                          │         │                          │
└──────────────────────────┘         └──────────────────────────┘
         │                                      ▲
         │                                      │
         └──────────────────────────────────────┘
                    Git Push / Image Push
```

## Components

### almabuild (Build Host)

**Purpose**: Source code management, CI/CD automation, and container image building

**Components**:
1. **Docker Engine**
   - Container runtime for building images
   - Runs Gitea Actions Runner containers
   - Storage driver: overlay2
   - Cgroup driver: systemd

2. **Gitea**
   - Git repository hosting
   - Container registry (packages)
   - Web interface on port 3000
   - SSH access on port 2222
   - Database: SQLite (default) or MySQL
   - LFS support for large files

3. **Gitea Actions Runner**
   - CI/CD automation
   - Executes workflows on git push
   - Builds container images
   - Pushes images to Gitea registry
   - Supports multiple labels:
     - ubuntu-latest
     - ubuntu-22.04
     - ubuntu-20.04
     - almalinux-latest

**Directories**:
- `/var/lib/gitea` - Gitea home and data
- `/var/lib/gitea-runner` - Runner configuration
- `/var/lib/act_runner` - Runner working directory
- `/var/log/gitea` - Gitea logs

### almak3s (Kubernetes Host)

**Purpose**: Container orchestration and application deployment

**Components**:
1. **K3s (Lightweight Kubernetes)**
   - Single-node cluster (can be expanded)
   - Built-in container runtime (containerd)
   - Integrated load balancer (ServiceLB)
   - Integrated ingress controller (Traefik)
   - Local storage provisioner

**Features**:
- Automatic deployment of containerized applications
- Service discovery and load balancing
- Rolling updates and rollbacks
- Resource management and scaling
- Network policies and security

**Directories**:
- `/etc/rancher/k3s` - K3s configuration
- `/var/lib/rancher/k3s` - K3s data and state

## Workflow

### 1. Development Workflow
```
Developer → Git Push → Gitea → Webhook → Actions Runner
                                              │
                                              ▼
                                         Build Image
                                              │
                                              ▼
                                    Push to Gitea Registry
                                              │
                                              ▼
                                    Trigger K8s Deployment
                                              │
                                              ▼
                                         almak3s pulls
                                         and deploys
```

### 2. CI/CD Pipeline
1. **Code Commit**: Developer pushes code to Gitea repository
2. **Trigger**: Gitea webhook triggers Actions Runner
3. **Build**: Runner builds Docker image using Dockerfile
4. **Test**: Runner executes tests (if configured)
5. **Push**: Runner pushes image to Gitea container registry
6. **Deploy**: K8s pulls image and updates deployment

### 3. Deployment Flow
1. **Image Available**: Container image in Gitea registry
2. **K8s Pull**: K3s pulls image from registry
3. **Pod Creation**: K8s creates pods with new image
4. **Service Update**: K8s updates service endpoints
5. **Traffic Routing**: Ingress routes traffic to new pods

## Network Configuration

### almabuild
- **Web UI**: http://almabuild:3000
- **SSH**: ssh://git@almabuild:2222
- **Registry**: almabuild:3000/user/repo

### almak3s
- **API Server**: https://almak3s:6443
- **Ingress**: http://almak3s (port 80/443)
- **Services**: Exposed via NodePort or LoadBalancer

## Security

### almabuild
- Firewall configured for ports 3000, 2222
- Docker socket access restricted to gitea-runner user
- Gitea admin access required for registry
- SSH key authentication for git operations

### almak3s
- K3s API server with TLS
- RBAC enabled by default
- Network policies for pod isolation
- Service accounts for workload identity

## Scalability

### Current Setup (Single Node)
- almabuild: Single host for all build operations
- almak3s: Single node K3s cluster

### Future Expansion Options
1. **Multiple Build Runners**: Add more runners to almabuild
2. **K3s Cluster**: Add worker nodes to almak3s
3. **High Availability**: Deploy K3s in HA mode (3+ servers)
4. **External Database**: Move Gitea to MySQL for better performance
5. **Distributed Storage**: Add persistent volume solutions

## Backup Strategy

### almabuild
- Gitea repositories: `/var/lib/gitea/data/gitea-repositories`
- Gitea database: `/var/lib/gitea/data/gitea.db` (SQLite)
- Container registry: `/var/lib/gitea/data/packages`

### almak3s
- K3s state: `/var/lib/rancher/k3s/server/db`
- Persistent volumes: `/var/lib/rancher/k3s/storage`
- Cluster configuration: `/etc/rancher/k3s/k3s.yaml`

## Monitoring

### Recommended Tools
- **Gitea**: Built-in dashboard and logs
- **K3s**: kubectl commands and logs
- **System**: systemctl status, journalctl
- **Docker**: docker stats, docker logs

### Key Metrics
- Build success/failure rate
- Build duration
- Image size and count
- K8s pod status and restarts
- Resource utilization (CPU, memory, disk)

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check runner logs: `journalctl -u gitea-runner -f`
   - Verify Docker is running: `systemctl status docker`
   - Check disk space: `df -h`

2. **Deployment Issues**
   - Check K3s status: `systemctl status k3s`
   - View pod logs: `kubectl logs <pod-name>`
   - Check events: `kubectl get events`

3. **Network Problems**
   - Verify firewall rules: `firewall-cmd --list-all`
   - Test connectivity: `ping`, `curl`, `telnet`
   - Check DNS resolution: `nslookup`

## Maintenance

### Regular Tasks
- **Daily**: Monitor build logs and deployment status
- **Weekly**: Review disk usage and clean old images
- **Monthly**: Update system packages and restart services
- **Quarterly**: Review and update security configurations

### Updates
- **Gitea**: Download new binary and restart service
- **K3s**: Use k3s upgrade script or manual update
- **Docker**: Update via dnf package manager
- **Actions Runner**: Download new binary and restart service