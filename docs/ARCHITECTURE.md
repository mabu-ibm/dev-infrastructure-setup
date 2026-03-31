# Infrastructure Architecture

## Overview

This infrastructure consists of two AlmaLinux 10 hosts providing a complete CI/CD pipeline with container orchestration.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Development Infrastructure                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐
│   Developer Workstation  │
│      (MacBook Pro)       │
│                          │
│  ┌────────────────────┐  │
│  │    IBM Bob AI      │  │
│  │                    │  │
│  │  - Code Assistant  │  │
│  │  - Chat Interface  │  │
│  │  - Code Generation │  │
│  │  - Documentation   │  │
│  └─────────┬──────────┘  │
│            │              │
│  ┌─────────▼──────────┐  │
│  │   VS Code / IDE    │  │
│  │                    │  │
│  │  - Source Code     │  │
│  │  - Bob Chat Sync   │  │
│  │  - Git Integration │  │
│  └─────────┬──────────┘  │
│            │              │
└────────────┼──────────────┘
             │ git push
             │ (code + chat history)
             ▼
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
│  │      Gitea         │◄─┼─────────┼──│    Runtime         │  │
│  │                    │  │  Webhook│  └────────────────────┘  │
│  │  - Git Repos       │  │  Trigger│           │              │
│  │  - Container       │  │         │  ┌────────▼───────────┐  │
│  │    Registry        │  │         │  │   Deployments      │  │
│  │  - SQLite/MySQL    │  │         │  │                    │  │
│  │  - Web UI :3000    │  │         │  │  - Applications    │  │
│  │  - SSH :2222       │  │         │  │  - Services        │  │
│  │  - Chat History    │  │         │  │  - Ingress         │  │
│  └────────┬───────────┘  │         │  └────────▲───────────┘  │
│           │ webhook      │         │           │              │
│  ┌────────▼───────────┐  │         │           │              │
│  │  Gitea Actions     │  │         │           │              │
│  │     Runner         │  │         │           │              │
│  │                    │  │         │           │              │
│  │  1. Checkout Code  │  │         │           │              │
│  │  2. Build Image    │  │         │           │              │
│  │  3. Run Tests      │  │         │           │              │
│  │  4. Push to        │  │         │           │              │
│  │     Registry       │  │         │           │              │
│  │  5. Deploy to K8s  │──┼─────────┼───────────┘              │
│  └────────────────────┘  │         │    kubectl rollout       │
│                          │         │    restart deployment    │
└──────────────────────────┘         └──────────────────────────┘
```

## Complete Development Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Development Workflow                          │
└─────────────────────────────────────────────────────────────────┘

1. Developer + Bob AI
   ┌──────────────────────────────────────────────────────────┐
   │ Developer: "I need to add a new feature"                 │
   │ Bob: Generates code, documentation, tests                │
   │ Developer: Reviews and refines with Bob                  │
   │ Bob: Updates code based on feedback                      │
   │ Chat history automatically synced to repository          │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
2. Git Commit & Push
   ┌──────────────────────────────────────────────────────────┐
   │ git add .                                                │
   │ git commit -m "feat: Add new feature (developed with Bob)"│
   │ git push origin main                                     │
   │                                                          │
   │ Includes:                                                │
   │ - Source code                                            │
   │ - Bob chat history (docs/CHAT_HISTORY.md)               │
   │ - Documentation updates                                  │
   │ - Tests                                                  │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
3. Gitea Webhook Trigger
   ┌──────────────────────────────────────────────────────────┐
   │ Gitea detects push to main branch                       │
   │ Triggers Gitea Actions workflow                         │
   │ Webhook sent to Actions Runner                          │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
4. CI/CD Pipeline (Actions Runner)
   ┌──────────────────────────────────────────────────────────┐
   │ Step 1: Checkout code from Gitea                        │
   │ Step 2: Build Docker image                              │
   │         docker build -t app:${COMMIT_SHA} .             │
   │ Step 3: Run automated tests                             │
   │         docker run app:${COMMIT_SHA} npm test           │
   │ Step 4: Push image to Gitea registry                    │
   │         docker push almabuild:3000/user/app:latest      │
   │ Step 5: Deploy to Kubernetes                            │
   │         kubectl set image deployment/app                │
   │         kubectl rollout restart deployment/app          │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
5. Kubernetes Deployment
   ┌──────────────────────────────────────────────────────────┐
   │ K3s pulls new image from Gitea registry                 │
   │ Creates new pods with updated image                     │
   │ Performs rolling update (zero downtime)                 │
   │ Old pods terminated after new pods ready                │
   │ Service routes traffic to new pods                      │
   └──────────────────────────────────────────────────────────┘
                              │
                              ▼
6. Application Running
   ┌──────────────────────────────────────────────────────────┐
   │ Application accessible via ingress                       │
   │ Monitoring and logging active                           │
   │ Ready for next development cycle                        │
   └──────────────────────────────────────────────────────────┘
```

## Bob AI Integration Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│              Bob AI Development Cycle                            │
└─────────────────────────────────────────────────────────────────┘

Developer Workstation (MacBook Pro)
│
├─ IBM Bob AI Assistant
│  │
│  ├─ Code Generation
│  │  └─ Creates: Source code, tests, documentation
│  │
│  ├─ Code Review
│  │  └─ Analyzes: Code quality, best practices, security
│  │
│  ├─ Documentation
│  │  └─ Generates: README, API docs, architecture diagrams
│  │
│  └─ Chat History
│     └─ Syncs to: docs/CHAT_HISTORY.md
│
├─ VS Code / IDE
│  │
│  ├─ Source Code
│  │  └─ Files: *.js, *.py, *.go, etc.
│  │
│  ├─ Bob Chat Sync
│  │  └─ Auto-saves: Conversation history
│  │
│  └─ Git Integration
│     └─ Commits: Code + Chat history
│
└─ Git Push
   │
   └─ Pushes to Gitea
      │
      ├─ Source code
      ├─ Bob chat history
      ├─ Documentation
      └─ Tests
      
      ▼
      
   Triggers CI/CD Pipeline
      │
      ├─ Build Docker image
      ├─ Run tests
      ├─ Push to registry
      └─ Deploy to K8s
      
      ▼
      
   Application Running on K8s
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

## IBM Concert Security Integration

### Overview

The infrastructure integrates with IBM Concert for comprehensive security scanning, vulnerability assessment, and automated remediation. This creates a continuous security feedback loop where vulnerabilities are detected, assessed, and automatically fixed.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              IBM Concert Security Integration Workflow                      │
└─────────────────────────────────────────────────────────────────────────────┘

Developer Workstation (MacBook Pro)
│
├─ IBM Bob AI Assistant
│  │
│  ├─ Code Generation
│  │  └─ Creates: Source code, tests, documentation
│  │
│  ├─ Security-Aware Development
│  │  └─ Implements: Secure coding patterns, best practices
│  │
│  └─ Automated Remediation
│     └─ Receives: CVE fixes from Concert
│     └─ Recreates: Secure code based on Concert recommendations
│
└─ Git Push
   │
   └─ Pushes to Gitea
      │
      ├─ Source code
      ├─ Dockerfile
      └─ Dependencies (requirements.txt, package.json, etc.)
      
      ▼
      
   CI/CD Pipeline (Gitea Actions)
      │
      ├─ Step 1: Build Docker Image
      │  └─ docker build -t app:${COMMIT_SHA} .
      │
      ├─ Step 2: Generate SBOM (Software Bill of Materials)
      │  └─ syft app:${COMMIT_SHA} -o cyclonedx-json > sbom.json
      │
      ├─ Step 3: Upload SBOM to IBM Concert
      │  └─ POST /core/api/v1/applications/{id}/sbom
      │     Headers:
      │       - C_API_KEY: ${CONCERT_API_KEY}
      │       - InstanceID: ${CONCERT_INSTANCE_ID}
      │     Body: sbom.json (CycloneDX format)
      │
      └─ Step 4: Deploy to K8s
         └─ kubectl set image deployment/app
      
      ▼
      
   IBM Concert Security Platform
      │
      ├─ SBOM Analysis
      │  └─ Parses: Components, dependencies, versions
      │
      ├─ Vulnerability Scanning
      │  └─ Checks: CVE databases, security advisories
      │
      ├─ Risk Assessment
      │  │
      │  ├─ Risk Scoring
      │  │  └─ Calculates: CVSS scores, priority levels
      │  │
      │  ├─ Impact Analysis
      │  │  └─ Evaluates: Business impact, data risk
      │  │
      │  └─ Prioritization
      │     └─ Ranks: Critical, High, Medium, Low
      │
      ├─ Remediation Recommendations
      │  │
      │  ├─ Version Updates
      │  │  └─ Suggests: Safe dependency versions
      │  │
      │  ├─ Code Patches
      │  │  └─ Provides: Security patches, fixes
      │  │
      │  └─ Configuration Changes
      │     └─ Recommends: Secure configurations
      │
      └─ API Response
         └─ Returns: CVE details, fixes, recommendations
      
      ▼
      
   Bob AI Retrieves Concert Data
      │
      ├─ GET /core/api/v1/applications/{id}/vulnerability_details
      │  └─ Retrieves: All vulnerabilities for application
      │
      ├─ GET /core/api/v1/applications/{id}/cves/{cve_id}/assessments
      │  └─ Retrieves: Detailed CVE assessment and fixes
      │
      └─ GET /core/api/v1/applications/{id}/build_artifacts/{artifact_id}/cves
         └─ Retrieves: CVEs for specific build artifacts
      
      ▼
      
   Bob AI Automated Remediation
      │
      ├─ Analyze Vulnerabilities
      │  └─ Reviews: CVE details, risk scores, priorities
      │
      ├─ Generate Fixes
      │  │
      │  ├─ Update Dependencies
      │  │  └─ Modifies: requirements.txt, package.json, go.mod
      │  │
      │  ├─ Patch Code
      │  │  └─ Applies: Security patches to source code
      │  │
      │  └─ Update Configurations
      │     └─ Secures: Dockerfile, K8s manifests, configs
      │
      ├─ Create Pull Request
      │  └─ Commits: Security fixes with CVE references
      │
      └─ Notify Developer
         └─ Reports: Fixed vulnerabilities, remaining issues
      
      ▼
      
   Developer Reviews & Merges
      │
      └─ Approves: Bob's security fixes
         └─ Merges: Pull request to main branch
      
      ▼
      
   CI/CD Pipeline Re-runs
      │
      └─ Builds: New image with security fixes
         └─ Uploads: New SBOM to Concert
            └─ Verifies: Vulnerabilities resolved
```

### Concert API Integration Points

#### 1. SBOM Upload (CI/CD Pipeline)

**Endpoint**: `POST /core/api/v1/applications/{id}/sbom`

**Purpose**: Upload Software Bill of Materials after each build

**Workflow**:
```yaml
# .gitea/workflows/build-with-sbom.yaml
name: Build with SBOM and Concert Upload
on:
  push:
    branches: [main]

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t ${{ secrets.REGISTRY }}/app:${{ github.sha }} .
      
      - name: Generate SBOM
        run: |
          # Install Syft for SBOM generation
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
          
          # Generate SBOM in CycloneDX JSON format
          syft ${{ secrets.REGISTRY }}/app:${{ github.sha }} \
            -o cyclonedx-json \
            > sbom.json
      
      - name: Upload SBOM to Concert
        run: |
          python3 scripts/upload-sbom-to-concert.py \
            --sbom sbom.json \
            --app-id ${{ secrets.CONCERT_APP_ID }} \
            --api-key ${{ secrets.CONCERT_API_KEY }} \
            --instance-id ${{ secrets.CONCERT_INSTANCE_ID }}
      
      - name: Push image to registry
        run: docker push ${{ secrets.REGISTRY }}/app:${{ github.sha }}
      
      - name: Deploy to K8s
        run: kubectl set image deployment/app app=${{ secrets.REGISTRY }}/app:${{ github.sha }}
```

**SBOM Upload Script** (`scripts/upload-sbom-to-concert.py`):
```python
#!/usr/bin/env python3
import requests
import json
import argparse
import sys

def upload_sbom_to_concert(sbom_file, app_id, api_key, instance_id):
    """Upload SBOM to IBM Concert for vulnerability scanning."""
    
    # Concert API configuration
    base_url = "https://91431.us-south-8.concert.saas.ibm.com"
    endpoint = f"/core/api/v1/applications/{app_id}/sbom"
    
    # Read SBOM file
    with open(sbom_file, 'r') as f:
        sbom_data = json.load(f)
    
    # Prepare request
    headers = {
        "C_API_KEY": api_key,
        "InstanceID": instance_id,
        "Content-Type": "application/json"
    }
    
    # Upload SBOM
    response = requests.post(
        f"{base_url}{endpoint}",
        headers=headers,
        json=sbom_data,
        timeout=30
    )
    
    if response.status_code == 200:
        print(f"✅ SBOM uploaded successfully to Concert")
        print(f"   Application ID: {app_id}")
        return True
    else:
        print(f"❌ Failed to upload SBOM: {response.status_code}")
        print(f"   Response: {response.text}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Upload SBOM to IBM Concert")
    parser.add_argument("--sbom", required=True, help="Path to SBOM file")
    parser.add_argument("--app-id", required=True, help="Concert Application ID")
    parser.add_argument("--api-key", required=True, help="Concert API Key")
    parser.add_argument("--instance-id", required=True, help="Concert Instance ID")
    
    args = parser.parse_args()
    
    success = upload_sbom_to_concert(
        args.sbom,
        args.app_id,
        args.api_key,
        args.instance_id
    )
    
    sys.exit(0 if success else 1)
```

#### 2. Vulnerability Retrieval (Bob AI)

**Endpoints Used**:
- `GET /core/api/v1/applications/{id}/vulnerability_details`
- `GET /core/api/v1/applications/{id}/cves/{cve_id}/assessments`
- `GET /core/api/v1/applications/{id}/build_artifacts/{artifact_id}/cves`

**Bob AI Workflow**:
```python
# Bob AI retrieves vulnerabilities from Concert
def get_vulnerabilities_from_concert(app_id):
    """Retrieve vulnerability details from Concert."""
    
    base_url = "https://91431.us-south-8.concert.saas.ibm.com"
    headers = {
        "C_API_KEY": os.getenv("CONCERT_API_KEY"),
        "InstanceID": os.getenv("CONCERT_INSTANCE_ID")
    }
    
    # Get all vulnerabilities for application
    response = requests.get(
        f"{base_url}/core/api/v1/applications/{app_id}/vulnerability_details",
        headers=headers
    )
    
    vulnerabilities = response.json().get("vulnerability_details", [])
    
    # Sort by risk score (highest first)
    vulnerabilities.sort(
        key=lambda x: x.get("highest_finding_risk_score", 0),
        reverse=True
    )
    
    return vulnerabilities

def get_cve_remediation(app_id, cve_id):
    """Get detailed remediation steps for a specific CVE."""
    
    base_url = "https://91431.us-south-8.concert.saas.ibm.com"
    headers = {
        "C_API_KEY": os.getenv("CONCERT_API_KEY"),
        "InstanceID": os.getenv("CONCERT_INSTANCE_ID")
    }
    
    # Get CVE assessment with remediation details
    response = requests.get(
        f"{base_url}/core/api/v1/applications/{app_id}/cves/{cve_id}/assessments",
        headers=headers
    )
    
    assessment = response.json()
    
    return {
        "cve": cve_id,
        "risk_score": assessment.get("risk_score"),
        "remediation": assessment.get("remediation_steps"),
        "fixed_version": assessment.get("fixed_version"),
        "patch_available": assessment.get("patch_available")
    }
```

#### 3. Automated Code Remediation (Bob AI)

**Bob AI Remediation Process**:

```python
def remediate_vulnerabilities(app_id, repo_path):
    """Automatically remediate vulnerabilities based on Concert data."""
    
    # Step 1: Get vulnerabilities from Concert
    vulnerabilities = get_vulnerabilities_from_concert(app_id)
    
    # Step 2: Filter critical and high priority CVEs
    critical_cves = [
        v for v in vulnerabilities
        if v.get("highest_finding_risk_score", 0) >= 7.0
    ]
    
    print(f"Found {len(critical_cves)} critical/high vulnerabilities")
    
    # Step 3: Generate fixes for each CVE
    fixes_applied = []
    
    for cve_data in critical_cves:
        cve_id = cve_data.get("cve")
        
        # Get detailed remediation steps
        remediation = get_cve_remediation(app_id, cve_id)
        
        # Apply fix based on vulnerability type
        if remediation.get("fixed_version"):
            # Update dependency version
            fix_result = update_dependency_version(
                repo_path,
                cve_data.get("component"),
                remediation.get("fixed_version")
            )
            fixes_applied.append({
                "cve": cve_id,
                "type": "dependency_update",
                "result": fix_result
            })
        
        elif remediation.get("patch_available"):
            # Apply code patch
            fix_result = apply_code_patch(
                repo_path,
                cve_id,
                remediation.get("patch_content")
            )
            fixes_applied.append({
                "cve": cve_id,
                "type": "code_patch",
                "result": fix_result
            })
    
    # Step 4: Create pull request with fixes
    create_security_pr(repo_path, fixes_applied)
    
    return fixes_applied

def update_dependency_version(repo_path, component, fixed_version):
    """Update dependency to fixed version."""
    
    # Detect dependency file type
    if os.path.exists(f"{repo_path}/requirements.txt"):
        # Python dependencies
        update_requirements_txt(repo_path, component, fixed_version)
    
    elif os.path.exists(f"{repo_path}/package.json"):
        # Node.js dependencies
        update_package_json(repo_path, component, fixed_version)
    
    elif os.path.exists(f"{repo_path}/go.mod"):
        # Go dependencies
        update_go_mod(repo_path, component, fixed_version)
    
    return f"Updated {component} to {fixed_version}"

def create_security_pr(repo_path, fixes_applied):
    """Create pull request with security fixes."""
    
    # Create new branch
    branch_name = f"security/concert-fixes-{datetime.now().strftime('%Y%m%d')}"
    os.system(f"cd {repo_path} && git checkout -b {branch_name}")
    
    # Commit changes
    commit_message = "fix: Apply security fixes from IBM Concert\n\n"
    commit_message += "Fixes applied:\n"
    
    for fix in fixes_applied:
        commit_message += f"- {fix['cve']}: {fix['result']}\n"
    
    os.system(f"cd {repo_path} && git add .")
    os.system(f"cd {repo_path} && git commit -m '{commit_message}'")
    os.system(f"cd {repo_path} && git push origin {branch_name}")
    
    print(f"✅ Created pull request: {branch_name}")
    print(f"   Fixed {len(fixes_applied)} vulnerabilities")
```

### Security Feedback Loop

```
┌─────────────────────────────────────────────────────────────────┐
│              Continuous Security Feedback Loop                   │
└─────────────────────────────────────────────────────────────────┘

1. Developer writes code with Bob AI
   └─ Bob implements secure coding patterns
   
2. Code pushed to Gitea
   └─ Triggers CI/CD pipeline
   
3. CI/CD builds image and generates SBOM
   └─ SBOM uploaded to Concert
   
4. Concert analyzes SBOM
   ├─ Scans for vulnerabilities
   ├─ Calculates risk scores
   └─ Generates remediation recommendations
   
5. Bob AI retrieves Concert data
   ├─ Gets vulnerability details
   ├─ Gets CVE assessments
   └─ Gets remediation steps
   
6. Bob AI generates fixes
   ├─ Updates dependencies
   ├─ Applies code patches
   └─ Updates configurations
   
7. Bob AI creates pull request
   └─ Developer reviews and merges
   
8. CI/CD re-runs with fixes
   └─ New SBOM uploaded to Concert
   
9. Concert verifies fixes
   └─ Confirms vulnerabilities resolved
   
10. Cycle repeats for continuous security
```

### Concert Dashboard Integration

The infrastructure also includes a Concert Security Dashboard for visualization:

**Dashboard Features**:
- **Application Security Overview**: View all applications and their security status
- **Vulnerability Details**: Drill down into specific CVEs and risk scores
- **Certificate Management**: Track SSL/TLS certificate expiration
- **Drill-Through Analysis**: Interactive exploration from apps → artifacts → CVEs
- **Real-time Monitoring**: Live updates from Concert API

**Dashboard Access**:
- URL: `http://localhost:8050` (when running locally)
- Authentication: Concert API key required
- Data Source: Concert API endpoints

### Configuration Requirements

**Environment Variables** (`.env`):
```bash
# Concert API Configuration
CONCERT_API_KEY=your_concert_api_key_here
CONCERT_INSTANCE_ID=your_instance_id_here
CONCERT_BASE_URL=https://91431.us-south-8.concert.saas.ibm.com

# Application Configuration
CONCERT_APPLICATION_ID=your_app_id_here
CONCERT_APPLICATION_NAME=YourAppName

# Optional: Dashboard Configuration
DASHBOARD_PORT=8050
DASHBOARD_DEBUG=false
```

**Gitea Secrets** (for CI/CD):
```bash
# Add secrets to Gitea repository settings
CONCERT_API_KEY=your_concert_api_key_here
CONCERT_INSTANCE_ID=your_instance_id_here
CONCERT_APP_ID=your_app_id_here
```

### Benefits of Concert Integration

1. **Automated Vulnerability Detection**
   - Continuous scanning of all dependencies
   - Real-time CVE database updates
   - Comprehensive SBOM analysis

2. **Risk-Based Prioritization**
   - CVSS scoring for all vulnerabilities
   - Business impact assessment
   - Priority-based remediation workflow

3. **Automated Remediation**
   - Bob AI generates fixes automatically
   - Dependency version updates
   - Code patches and security improvements

4. **Continuous Compliance**
   - Audit trail of all security fixes
   - Compliance reporting
   - Certificate lifecycle management

5. **Developer Productivity**
   - Reduced manual security work
   - Automated pull requests
   - Clear remediation guidance

6. **Enterprise Visibility**
   - Centralized security dashboard
   - Portfolio-wide vulnerability tracking
   - Executive reporting and metrics

### Security Best Practices

1. **API Key Management**
   - Store Concert API keys in Gitea secrets
   - Never commit API keys to repository
   - Rotate keys regularly

2. **SBOM Generation**
   - Generate SBOM for every build
   - Use CycloneDX format for compatibility
   - Include all dependencies and versions

3. **Vulnerability Response**
   - Address critical vulnerabilities within 24 hours
   - Review Bob AI's fixes before merging
   - Test fixes in staging before production

4. **Monitoring**
   - Monitor Concert dashboard daily
   - Set up alerts for critical CVEs
   - Track remediation metrics

5. **Documentation**
   - Document all security fixes
   - Maintain CVE fix history
   - Update security policies regularly