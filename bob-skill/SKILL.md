# Bob Skill: Deploy Secure Application

Automated skill to create, build, and deploy secure applications with enterprise-grade security.

## 🎯 What This Skill Does

This skill automates the entire process of deploying a secure application:

1. **Creates Gitea repository** (if it doesn't exist)
2. **Generates application** from secure template
3. **Initializes git** and pushes code
4. **Triggers CI/CD pipeline** automatically
5. **Deploys to K3s** with full security features

**Time:** 3-5 minutes (fully automated)  
**Manual Steps:** Zero (just run the command)

## 🚀 Quick Start

### Prerequisites

1. **Gitea Personal Access Token**
   ```bash
   # Create in Gitea: User Settings → Applications → Generate New Token
   # Permissions needed: write:repository, write:package
   ```

2. **Environment Variables**
   ```bash
   export GITEA_USER="your-username"
   export GITEA_TOKEN="your-personal-access-token"
   export GITEA_URL="http://almabuild:3000"  # Optional, defaults to this
   ```

3. **Repository Secrets** (one-time setup per repository)
   - `REGISTRY_TOKEN` - Gitea PAT for pushing images
   - `KUBECONFIG` - Base64-encoded kubeconfig for K3s

### Usage

```bash
# Deploy a Python application
./bob-skill/deploy-secure-app.sh my-app python

# Deploy a Node.js application (when template available)
./bob-skill/deploy-secure-app.sh my-app nodejs

# Deploy a Go application (when template available)
./bob-skill/deploy-secure-app.sh my-app go
```

## 📋 Complete Example

### Step 1: Setup Environment

```bash
# Set your Gitea credentials
export GITEA_USER="manfred"
export GITEA_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Optional: Set Gitea URL (defaults to http://almabuild:3000)
export GITEA_URL="http://almabuild:3000"
```

### Step 2: Run the Skill

```bash
cd ~/dev-infrastructure-setup
./bob-skill/deploy-secure-app.sh my-secure-app python
```

### Step 3: Watch the Magic

The skill will:
```
✓ Check if repository exists
✓ Create repository (if needed)
✓ Generate application from template
✓ Customize application
✓ Initialize git repository
✓ Push code to Gitea
✓ Trigger CI/CD pipeline
✓ Deploy to K3s with security
```

### Step 4: Monitor Deployment

```bash
# Watch pipeline in Gitea
# Go to: http://almabuild:3000/manfred/my-secure-app/actions

# Check deployment status
kubectl get pods -l app=my-secure-app

# View logs
kubectl logs -l app=my-secure-app -f

# Access application
kubectl port-forward service/my-secure-app 8080:80
curl http://localhost:8080/
```

## 🔐 Security Features

### Automated Security

The skill automatically creates applications with:

**Container Security:**
- ✅ Hardened Dockerfile.secure
- ✅ Non-root user (UID 1000)
- ✅ Security updates installed
- ✅ Read-only app directory
- ✅ Minimal attack surface

**Kubernetes Security:**
- ✅ Pod security contexts
- ✅ Read-only root filesystem
- ✅ Dropped ALL capabilities
- ✅ Service account (dedicated)
- ✅ Network policies
- ✅ Resource limits
- ✅ Health probes

**Pipeline Security:**
- ✅ Trivy vulnerability scanning (optional)
- ✅ Automated security verification
- ✅ Security context validation
- ✅ Complete audit trail

## 📊 What Gets Created

### Repository Structure

```
my-secure-app/
├── app.py                          # Application code
├── requirements.txt                # Dependencies
├── Dockerfile                      # Basic Dockerfile
├── Dockerfile.secure              # Hardened Dockerfile
├── README.md                       # Documentation
├── .gitea/
│   └── workflows/
│       └── build-push-deploy.yaml # CI/CD pipeline
└── k8s/
    ├── deployment.yaml            # Basic deployment
    ├── deployment-secure.yaml     # Secure deployment
    ├── network-policy.yaml        # Network isolation
    └── ingress-secure.yaml        # HTTPS/TLS config
```

### CI/CD Pipeline

```
Push Code → Gitea
    ↓
Job 1: Test (~30s)
    ├─ Run application tests
    └─ Verify code quality
    ↓
Job 2: Build Secure Image (~2-3min)
    ├─ Build with Dockerfile.secure
    ├─ Push to Gitea registry
    └─ Scan with Trivy (optional)
    ↓
Job 3: Deploy Secure (~1-2min)
    ├─ Apply secure deployment
    ├─ Apply network policy
    └─ Verify security
    ↓
✅ Application Running Securely
```

### Kubernetes Resources

```
Deployment:  my-secure-app (2 replicas)
Service:     my-secure-app (ClusterIP)
ServiceAccount: my-secure-app
ConfigMap:   my-secure-app-config
Secret:      my-secure-app-secrets
NetworkPolicy: my-secure-app-netpol
```

## 🔧 Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| GITEA_USER | Yes | - | Gitea username |
| GITEA_TOKEN | Yes | - | Gitea Personal Access Token |
| GITEA_URL | No | http://almabuild:3000 | Gitea server URL |

### Command Arguments

```bash
./deploy-secure-app.sh <app-name> [app-type]
```

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| app-name | Yes | - | Name of the application |
| app-type | No | python | Type: python, nodejs, go |

## 🎓 Advanced Usage

### Deploy Multiple Applications

```bash
# Deploy different applications
./bob-skill/deploy-secure-app.sh frontend python
./bob-skill/deploy-secure-app.sh backend python
./bob-skill/deploy-secure-app.sh api python
```

### Custom Configuration

```bash
# Use different Gitea instance
export GITEA_URL="https://git.example.com"
./bob-skill/deploy-secure-app.sh my-app python

# Deploy to different namespace (modify k8s manifests after creation)
./bob-skill/deploy-secure-app.sh my-app python
# Then edit k8s/*.yaml to change namespace
```

### Reuse Existing Repository

```bash
# If repository exists, skill will ask:
./bob-skill/deploy-secure-app.sh existing-app python

# Output:
# Repository already exists: manfred/existing-app
# Do you want to use existing repository? (y/n)
```

## 🐛 Troubleshooting

### Issue: Repository Creation Failed

**Error:**
```
✗ Failed to create repository
{"message":"repository already exists"}
```

**Solution:**
- Repository name already taken
- Choose a different name
- Or use existing repository (answer 'y' when prompted)

### Issue: Secrets Not Found

**Warning:**
```
⚠ REGISTRY_TOKEN secret not found
⚠ KUBECONFIG secret not found
```

**Solution:**
1. Go to Gitea: `http://almabuild:3000/USERNAME/REPO/settings/actions/secrets`
2. Add `REGISTRY_TOKEN`:
   - Generate PAT in User Settings → Applications
   - Permissions: `write:package`, `read:package`
3. Add `KUBECONFIG`:
   - Get kubeconfig: `cat ~/.kube/config | base64 -w 0`
   - Paste base64 output

### Issue: Pipeline Fails

**Check:**
```bash
# View pipeline logs in Gitea
# Go to: http://almabuild:3000/USERNAME/REPO/actions

# Check deployment
kubectl get pods -l app=APP_NAME
kubectl describe pod -l app=APP_NAME
kubectl logs -l app=APP_NAME
```

### Issue: Can't Access Application

**Solution:**
```bash
# Check service
kubectl get service APP_NAME

# Port-forward
kubectl port-forward service/APP_NAME 8080:80

# Test
curl http://localhost:8080/
```

## 📚 Related Documentation

- **Pipeline Guide:** [SECURE_CICD_PIPELINE.md](../project-templates/hello-world-python/SECURE_CICD_PIPELINE.md)
- **Security Setup:** [SECURITY_SETUP.md](../project-templates/hello-world-python/SECURITY_SETUP.md)
- **Deployment Guide:** [DEPLOY_ON_ALMAK3S.md](../project-templates/hello-world-python/DEPLOY_ON_ALMAK3S.md)
- **Security Hardening:** [docs/SECURITY_HARDENING_GUIDE.md](../docs/SECURITY_HARDENING_GUIDE.md)

## 🎯 Benefits

### Before (Manual Process)
- ❌ 30+ minutes manual work
- ❌ Multiple manual steps
- ❌ Easy to forget security
- ❌ Inconsistent deployments

### After (Bob Skill)
- ✅ 3-5 minutes automated
- ✅ Single command
- ✅ Security by default
- ✅ Consistent deployments

## ✅ Checklist

Before using the skill:
- [ ] Gitea is running
- [ ] K3s is running
- [ ] GITEA_USER is set
- [ ] GITEA_TOKEN is set
- [ ] kubectl is configured
- [ ] Registry secret exists in K3s

After running the skill:
- [ ] Repository created in Gitea
- [ ] Code pushed successfully
- [ ] Pipeline triggered
- [ ] Deployment successful
- [ ] Application accessible

## 🚀 Quick Reference

```bash
# Setup (one time)
export GITEA_USER="your-username"
export GITEA_TOKEN="your-token"

# Deploy application
./bob-skill/deploy-secure-app.sh my-app python

# Watch deployment
kubectl get pods -l app=my-app -w

# Access application
kubectl port-forward service/my-app 8080:80
curl http://localhost:8080/

# View logs
kubectl logs -l app=my-app -f

# Delete application
kubectl delete deployment,service,networkpolicy -l app=my-app
```

---

**Created with IBM Bob AI** 🤖

**Deploy secure applications with a single command!** 🚀