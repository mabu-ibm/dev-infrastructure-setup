#!/bin/bash
################################################################################
# Bob Skill Handler - Project Initialization
# Purpose: Handle project initialization requests from IBM Bob
# Called by: IBM Bob when skill is triggered
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Parse arguments from Bob
PROJECT_NAME="${1:-}"
STACK_TYPE="${2:-python}"
ADDITIONAL_CONTEXT="${3:-}"

# Validate inputs
if [ -z "${PROJECT_NAME}" ]; then
    log_error "Project name is required"
    echo "Usage: $0 <project-name> [stack-type] [additional-context]"
    echo "Example: $0 my-api python 'FastAPI with PostgreSQL'"
    exit 1
fi

# Sanitize project name (remove spaces, special chars)
PROJECT_NAME=$(echo "${PROJECT_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

log_info "IBM Bob Project Initialization Skill"
log_info "Project: ${PROJECT_NAME}"
log_info "Stack: ${STACK_TYPE}"
if [ -n "${ADDITIONAL_CONTEXT}" ]; then
    log_info "Context: ${ADDITIONAL_CONTEXT}"
fi

# Find scaffold script
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAFFOLD_SCRIPT="${SKILL_DIR}/../project-templates/scaffold-project.sh"

if [ ! -f "${SCAFFOLD_SCRIPT}" ]; then
    log_error "Scaffold script not found: ${SCAFFOLD_SCRIPT}"
    exit 1
fi

# Execute scaffold script
log_step "Executing project scaffold..."
"${SCAFFOLD_SCRIPT}" "${PROJECT_NAME}" "${STACK_TYPE}"

# Get project directory
PROJECTS_DIR="${HOME}/projects"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

# Enhance BOB.md with additional context if provided
if [ -n "${ADDITIONAL_CONTEXT}" ] && [ -f "${PROJECT_DIR}/BOB.md" ]; then
    log_step "Adding context to BOB.md..."
    cat >> "${PROJECT_DIR}/BOB.md" <<EOF

## Additional Context from Bob Session
${ADDITIONAL_CONTEXT}

## Recommended Next Steps
1. Review and customize the generated code
2. Configure environment variables
3. Set up Gitea repository
4. Configure CI/CD secrets in Gitea
5. Test local build: \`docker build -t ${PROJECT_NAME}:test .\`
6. Push to Gitea and verify pipeline
7. Monitor Flux CD deployment
EOF

    cd "${PROJECT_DIR}"
    git add BOB.md
    git commit -m "docs: add Bob session context to BOB.md" --no-verify
fi

# Create quick reference card
cat > "${PROJECT_DIR}/QUICKSTART.md" <<EOF
# ${PROJECT_NAME} - Quick Start

## 🚀 Immediate Next Steps

### 1. Review Project Structure
\`\`\`bash
cd ${PROJECT_DIR}
tree -L 2
\`\`\`

### 2. Set Up Development Environment
\`\`\`bash
./scripts/dev-setup.sh
\`\`\`

### 3. Test Locally
\`\`\`bash
# Build Docker image
docker build -t ${PROJECT_NAME}:test .

# Run container
docker run -p 8000:8000 ${PROJECT_NAME}:test

# Test endpoint
curl http://localhost:8000/health
\`\`\`

### 4. Create Gitea Repository
\`\`\`bash
# In Gitea web UI:
# 1. Create new repository: ${PROJECT_NAME}
# 2. Copy the repository URL

# Add remote and push
git remote add origin <gitea-url>/${PROJECT_NAME}.git
git push -u origin main
\`\`\`

### 5. Configure CI/CD Secrets
In Gitea repository settings → Secrets, add:
- \`GITEA_REGISTRY\`: Your Gitea registry URL
- \`GITEA_USERNAME\`: Your Gitea username
- \`GITEA_TOKEN\`: Your Gitea access token

### 6. Monitor Deployment
\`\`\`bash
# Watch Gitea Actions
# Go to: <gitea-url>/${PROJECT_NAME}/actions

# Watch Flux CD
kubectl get gitrepositories -n flux-system
kubectl get kustomizations -n flux-system
kubectl get pods -n apps -l app=${PROJECT_NAME}
\`\`\`

## 📁 Key Files

| File | Purpose |
|------|---------|
| \`CLAUDE.md\` | Claude Code context and session notes |
| \`BOB.md\` | IBM Bob context and infrastructure notes |
| \`Dockerfile\` | Multi-stage container build |
| \`k8s/\` | Kubernetes deployment manifests |
| \`.gitea/workflows/\` | CI/CD pipeline configuration |
| \`.claude-chats/\` | Claude Code conversation history |
| \`.bob-chats/\` | IBM Bob conversation history |

## 🔧 Development Commands

\`\`\`bash
# Run locally (stack-specific)
./scripts/dev-setup.sh

# Build Docker image
docker build -t ${PROJECT_NAME}:latest .

# Test Kubernetes manifests
kubectl apply -k k8s/ --dry-run=client

# View logs
kubectl logs -n apps -l app=${PROJECT_NAME} -f
\`\`\`

## 🔄 Deployment Pipeline

\`\`\`
Code Change → Git Push → Gitea Actions → Docker Build → 
Registry Push → Flux CD Detect → K8s Deploy
\`\`\`

## 📊 Monitoring

\`\`\`bash
# Check application health
kubectl get pods -n apps -l app=${PROJECT_NAME}

# View application logs
kubectl logs -n apps -l app=${PROJECT_NAME} --tail=100

# Check service
kubectl get svc -n apps ${PROJECT_NAME}

# Port forward for local testing
kubectl port-forward -n apps svc/${PROJECT_NAME} 8080:80
\`\`\`

## 🆘 Troubleshooting

### Build fails
\`\`\`bash
# Check Gitea Actions logs
# View in Gitea UI: Repository → Actions → Latest run

# Test build locally
docker build -t ${PROJECT_NAME}:test .
\`\`\`

### Deployment fails
\`\`\`bash
# Check Flux CD status
flux get all -n flux-system

# Check pod status
kubectl describe pod -n apps -l app=${PROJECT_NAME}

# View events
kubectl get events -n apps --sort-by='.lastTimestamp'
\`\`\`

### Chat sync not working
\`\`\`bash
# Manual sync
${SKILL_DIR}/../chat-sync/sync-chats.sh ${PROJECT_DIR}

# Check git hooks
ls -la ${PROJECT_DIR}/.git/hooks/post-commit

# View sync logs
tail -f ~/.chat-sync-cron.log
\`\`\`

## 📚 Documentation

- Full setup guide: \`README.md\`
- Claude Code context: \`CLAUDE.md\`
- IBM Bob context: \`BOB.md\`
- Infrastructure docs: \`../dev-infrastructure-setup/docs/\`

## 🎯 Project Goals

${ADDITIONAL_CONTEXT:-Add your project goals here}

---
Generated by IBM Bob Project Initialization Skill
EOF

cd "${PROJECT_DIR}"
git add QUICKSTART.md
git commit -m "docs: add quick start guide" --no-verify

log_info "============================================"
log_info "✅ Project Initialization Complete!"
log_info "============================================"
log_info "Project: ${PROJECT_NAME}"
log_info "Location: ${PROJECT_DIR}"
log_info "Stack: ${STACK_TYPE}"
log_info ""
log_info "📖 Quick Start Guide: ${PROJECT_DIR}/QUICKSTART.md"
log_info ""
log_info "Next: cd ${PROJECT_DIR} && cat QUICKSTART.md"
log_info "============================================"

# Return project directory for Bob to use
echo "${PROJECT_DIR}"

# Made with Bob
