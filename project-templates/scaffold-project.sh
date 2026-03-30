#!/bin/bash
################################################################################
# Project Scaffolding Script
# Purpose: Create new project with complete infrastructure setup
# Usage: ./scaffold-project.sh <project-name> <stack-type>
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

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <project-name> <stack-type>"
    echo ""
    echo "Available stack types:"
    echo "  python      - Python application (FastAPI/Flask)"
    echo "  node        - Node.js application (Express/NestJS)"
    echo "  go          - Go application"
    echo "  java        - Java application (Spring Boot)"
    echo "  rust        - Rust application"
    echo ""
    echo "Example: $0 my-api python"
    exit 1
fi

PROJECT_NAME="$1"
STACK_TYPE="$2"
PROJECTS_DIR="${HOME}/projects"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"

# Validate stack type
case "${STACK_TYPE}" in
    python|node|go|java|rust)
        ;;
    *)
        log_error "Invalid stack type: ${STACK_TYPE}"
        log_error "Valid types: python, node, go, java, rust"
        exit 1
        ;;
esac

log_info "Creating new project: ${PROJECT_NAME} (${STACK_TYPE})"

# Check if project already exists
if [ -d "${PROJECT_DIR}" ]; then
    log_error "Project directory already exists: ${PROJECT_DIR}"
    exit 1
fi

# Create project directory
mkdir -p "${PROJECT_DIR}"
cd "${PROJECT_DIR}"

log_step "Creating project structure..."

# Initialize git repository
git init
git config user.name "${GIT_USER_NAME:-Developer}"
git config user.email "${GIT_USER_EMAIL:-dev@example.com}"

# Create base directory structure
mkdir -p src k8s scripts .github/workflows

# Create README.md
cat > README.md <<EOF
# ${PROJECT_NAME}

${STACK_TYPE^} application with automated CI/CD pipeline.

## Quick Start

\`\`\`bash
# Development
./scripts/dev-setup.sh

# Build
docker build -t ${PROJECT_NAME}:latest .

# Deploy
kubectl apply -k k8s/
\`\`\`

## Architecture

- **Stack**: ${STACK_TYPE^}
- **Container Registry**: Gitea
- **CI/CD**: Gitea Actions
- **Deployment**: Kubernetes via Flux CD

## Development

See [CLAUDE.md](CLAUDE.md) and [BOB.md](BOB.md) for AI assistant context.

## Chat History

- Claude Code conversations: \`.claude-chats/\`
- IBM Bob conversations: \`.bob-chats/\`
EOF

# Create CLAUDE.md
cat > CLAUDE.md <<EOF
# Claude Code Context: ${PROJECT_NAME}

## Project Overview
**Name**: ${PROJECT_NAME}
**Stack**: ${STACK_TYPE^}
**Created**: $(date +"%Y-%m-%d")

## Architecture
- **Language/Framework**: ${STACK_TYPE^}
- **Container**: Docker multi-stage build
- **Registry**: Gitea container registry
- **CI/CD**: Gitea Actions
- **Deployment**: Kubernetes (K3s) via Flux CD
- **Monitoring**: Instana (planned)

## Development Workflow
1. Code changes pushed to Gitea
2. Gitea Actions builds Docker image
3. Image pushed to Gitea registry
4. Flux CD detects new image
5. Automatic deployment to K8s

## Key Files
- \`Dockerfile\`: Multi-stage container build
- \`k8s/\`: Kubernetes manifests
- \`.gitea/workflows/\`: CI/CD pipeline
- \`scripts/\`: Development and deployment scripts

## Previous Sessions
<!-- Claude Code will add session notes here -->

## Current Tasks
- [ ] Initial project setup
- [ ] Implement core functionality
- [ ] Add tests
- [ ] Configure monitoring
EOF

# Create BOB.md
cat > BOB.md <<EOF
# IBM Bob Context: ${PROJECT_NAME}

## Project Overview
**Name**: ${PROJECT_NAME}
**Stack**: ${STACK_TYPE^}
**Created**: $(date +"%Y-%m-%d")

## Infrastructure
- **Build VM**: AlmaLinux 10 with Gitea + Docker
- **K8s Cluster**: K3s on AlmaLinux 10
- **GitOps**: Flux CD
- **Registry**: Gitea container registry

## Deployment Pipeline
\`\`\`
MacBook → Gitea → Actions Runner → Docker Build → Registry → Flux CD → K3s
\`\`\`

## Security & Observability
- **Vulnerability Scanning**: Planned
- **Monitoring**: Instana integration
- **Logging**: Centralized logging (planned)

## Previous Sessions
<!-- IBM Bob will add session notes here -->

## Current Focus
- [ ] Infrastructure setup
- [ ] CI/CD pipeline configuration
- [ ] Security hardening
- [ ] Observability integration
EOF

# Create project environment template
log_step "Creating project environment template..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/project.env.template" ]; then
    cp "${SCRIPT_DIR}/project.env.template" .env.template
    # Substitute project name
    sed -i.bak "s/\${PROJECT_NAME}/${PROJECT_NAME}/g" .env.template
    sed -i.bak "s/\${GITEA_REGISTRY}/${GITEA_REGISTRY:-gitea.local}/g" .env.template
    rm -f .env.template.bak
    log_info "✓ Project .env.template created"
else
    log_warn "Project .env.template not found, creating basic version"
    cat > .env.template <<EOF
# Project Environment Configuration
CONCERT_URL=https://YOUR_INSTANCE.concert.saas.ibm.com
CONCERT_API_KEY=YOUR_CONCERT_API_KEY
CONCERT_INSTANCE_ID=YOUR_INSTANCE_ID
CONCERT_APPLICATION_ID=YOUR_APPLICATION_ID
SBOM_FORMAT=spdx-json
SBOM_DIR=./sbom
APP_NAME=${PROJECT_NAME}
EOF
fi

# Create .gitignore
cat > .gitignore <<EOF
# AI Chat History (synced automatically)
# Uncomment to exclude from git:
# .claude-chats/
# .bob-chats/

# Environment variables
.env
.env.local

# SBOM output directory
sbom/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Dependencies (stack-specific will be added)
EOF

# Stack-specific setup
log_step "Setting up ${STACK_TYPE} stack..."

case "${STACK_TYPE}" in
    python)
        # Python-specific files
        cat >> .gitignore <<EOF

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
EOF

        cat > src/main.py <<EOF
"""
${PROJECT_NAME} - Main application
"""
from fastapi import FastAPI

app = FastAPI(title="${PROJECT_NAME}")

@app.get("/")
async def root():
    return {"message": "Hello from ${PROJECT_NAME}"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

        cat > requirements.txt <<EOF
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.3
EOF

        cat > Dockerfile <<EOF
# Multi-stage build for Python application
FROM python:3.11-slim as builder

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Final stage
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appuser src/ ./src/

# Set PATH for user-installed packages
ENV PATH=/home/appuser/.local/bin:\$PATH

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["python", "src/main.py"]
EOF
        ;;

    node)
        # Node.js-specific files
        cat >> .gitignore <<EOF

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.yarn
dist/
build/
EOF

        cat > src/index.js <<EOF
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.json({ message: 'Hello from ${PROJECT_NAME}' });
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(\`Server running on port \${PORT}\`);
});
EOF

        cat > package.json <<EOF
{
  "name": "${PROJECT_NAME}",
  "version": "1.0.0",
  "description": "${PROJECT_NAME} application",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
EOF

        cat > Dockerfile <<EOF
# Multi-stage build for Node.js application
FROM node:20-alpine as builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Final stage
FROM node:20-alpine

# Create non-root user
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy dependencies and source
COPY --from=builder --chown=appuser:appuser /app/node_modules ./node_modules
COPY --chown=appuser:appuser package*.json ./
COPY --chown=appuser:appuser src/ ./src/

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["npm", "start"]
EOF
        ;;

    go)
        # Go-specific files
        cat >> .gitignore <<EOF

# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
go.work
vendor/
EOF

        cat > src/main.go <<EOF
package main

import (
    "encoding/json"
    "log"
    "net/http"
)

func main() {
    http.HandleFunc("/", rootHandler)
    http.HandleFunc("/health", healthHandler)

    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Hello from ${PROJECT_NAME}",
    })
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "status": "healthy",
    })
}
EOF

        cat > go.mod <<EOF
module ${PROJECT_NAME}

go 1.21
EOF

        cat > Dockerfile <<EOF
# Multi-stage build for Go application
FROM golang:1.21-alpine as builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source
COPY src/ ./src/

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./src/main.go

# Final stage
FROM alpine:latest

# Create non-root user
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy binary
COPY --from=builder --chown=appuser:appuser /app/main .

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["./main"]
EOF
        ;;
esac

# Create Kubernetes manifests
log_step "Creating Kubernetes manifests..."

cat > k8s/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${PROJECT_NAME}
  namespace: apps
  labels:
    app: ${PROJECT_NAME}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${PROJECT_NAME}
  template:
    metadata:
      labels:
        app: ${PROJECT_NAME}
    spec:
      containers:
      - name: ${PROJECT_NAME}
        image: gitea.local/${PROJECT_NAME}:latest # {"$imagepolicy": "flux-system:${PROJECT_NAME}"}
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: PORT
          value: "8000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

cat > k8s/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${PROJECT_NAME}
  namespace: apps
  labels:
    app: ${PROJECT_NAME}
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: ${PROJECT_NAME}
EOF

cat > k8s/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: apps

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: ${PROJECT_NAME}
  managed-by: flux
EOF

# Create Gitea Actions workflow
log_step "Creating CI/CD pipeline..."

mkdir -p .gitea/workflows

cat > .gitea/workflows/build-deploy.yaml <<EOF
name: Build and Deploy

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Gitea Registry
        uses: docker/login-action@v3
        with:
          registry: \${{ secrets.GIT_REGISTRY }}
          username: \${{ secrets.GIT_USERNAME }}
          password: \${{ secrets.GIT_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: \${{ secrets.GIT_REGISTRY }}/${PROJECT_NAME}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: \${{ github.event_name != 'pull_request' }}
          tags: \${{ steps.meta.outputs.tags }}
          labels: \${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Install Syft
        if: github.event_name != 'pull_request'
        run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

      - name: Generate SBOM (Always)
        if: github.event_name != 'pull_request'
        run: |
          IMAGE_TAG=\$(echo "\${{ steps.meta.outputs.tags }}" | head -n1)
          syft "\${IMAGE_TAG}" --output spdx-json=sbom.json
          echo "✓ SBOM generated successfully"

      - name: Upload SBOM to Concert (Optional)
        if: github.event_name != 'pull_request' && secrets.CONCERT_URL != ''
        env:
          CONCERT_URL: \${{ secrets.CONCERT_URL }}
          CONCERT_API_KEY: \${{ secrets.CONCERT_API_KEY }}
          CONCERT_INSTANCE_ID: \${{ secrets.CONCERT_INSTANCE_ID }}
          CONCERT_APPLICATION_ID: \${{ secrets.CONCERT_APPLICATION_ID }}
        run: |
          pip install requests
          python scripts/upload-sbom-to-concert.py sbom.json --application-id "\${CONCERT_APPLICATION_ID}"

      - name: Upload SBOM artifacts
        if: github.event_name != 'pull_request'
        uses: actions/upload-artifact@v4
        with:
          name: sbom-files
          path: sbom.json
          retention-days: 90

      - name: Update deployment
        if: github.ref == 'refs/heads/main'
        run: |
          echo "Image built and pushed successfully"
          echo "SBOM generated and uploaded"
          echo "Flux CD will automatically deploy the new image"
EOF

# Create development setup script
cat > scripts/dev-setup.sh <<EOF
#!/bin/bash
set -e

echo "Setting up development environment for ${PROJECT_NAME}..."

# Stack-specific setup
case "${STACK_TYPE}" in
    python)
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        echo "Run: source venv/bin/activate && python src/main.py"
        ;;
    node)
        npm install
        echo "Run: npm run dev"
        ;;
    go)
        go mod download
        echo "Run: go run src/main.go"
        ;;
esac

echo "Development environment ready!"
EOF

chmod +x scripts/dev-setup.sh

# Copy SBOM generation scripts
log_step "Adding SBOM generation scripts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
if [ -f "${SCRIPT_DIR}/scripts/generate-sbom.sh" ]; then
    cp "${SCRIPT_DIR}/scripts/generate-sbom.sh" scripts/
    chmod +x scripts/generate-sbom.sh
    log_info "✓ SBOM generation script added"
fi

if [ -f "${SCRIPT_DIR}/scripts/upload-sbom-to-concert.py" ]; then
    cp "${SCRIPT_DIR}/scripts/upload-sbom-to-concert.py" scripts/
    chmod +x scripts/upload-sbom-to-concert.py
    log_info "✓ Concert upload script added"
fi

# Install git hooks for chat sync
log_step "Installing git hooks..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
if [ -f "${SCRIPT_DIR}/chat-sync/install-git-hooks.sh" ]; then
    "${SCRIPT_DIR}/chat-sync/install-git-hooks.sh" "${PROJECT_DIR}"
else
    log_warn "Git hooks installer not found, skipping"
fi

# Initial commit
log_step "Creating initial commit..."
git add .
git commit -m "chore: initial project setup

- ${STACK_TYPE^} application structure
- Docker multi-stage build
- Kubernetes manifests
- Gitea Actions CI/CD pipeline with SBOM generation
- AI assistant context files (CLAUDE.md, BOB.md)
- Chat sync automation
- SBOM generation and Concert integration"

log_info "============================================"
log_info "Project Created Successfully!"
log_info "============================================"
log_info "Project: ${PROJECT_NAME}"
log_info "Stack: ${STACK_TYPE^}"
log_info "Location: ${PROJECT_DIR}"
log_info ""
log_info "Next Steps:"
log_info "1. cd ${PROJECT_DIR}"
log_info "2. Review CLAUDE.md and BOB.md"
log_info "3. Run: ./scripts/dev-setup.sh"
log_info "4. Create Gitea repository and push:"
log_info "   git remote add origin <gitea-url>/${PROJECT_NAME}.git"
log_info "   git push -u origin main"
log_info ""
log_info "Files created:"
log_info "  ✓ README.md, CLAUDE.md, BOB.md"
log_info "  ✓ Dockerfile (multi-stage)"
log_info "  ✓ k8s/ (Kubernetes manifests)"
log_info "  ✓ .gitea/workflows/ (CI/CD pipeline)"
log_info "  ✓ Git hooks (chat sync)"
log_info ""
log_info "Chat sync: Enabled (auto-commit after each commit)"
log_info "============================================"

# Made with Bob
