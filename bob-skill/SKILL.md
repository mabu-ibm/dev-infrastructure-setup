# Project Initialization Skill

**Trigger Keywords**: new project, init project, create project, scaffold project, setup project, start project, initialize project, neues projekt, projekt erstellen, projekt initialisieren

**Description**: Automatically scaffolds a complete project with infrastructure, CI/CD, Kubernetes manifests, and AI chat sync. Creates production-ready structure with Docker, Gitea Actions, Flux CD integration, and automated chat history persistence.

**When to Use**:
- Starting any new software project
- Need complete DevOps setup from scratch
- Want automated CI/CD pipeline
- Require Kubernetes deployment configuration
- Need AI chat history tracking in git

**What It Does**:
1. Creates project directory structure
2. Initializes git repository
3. Generates stack-specific application code
4. Creates multi-stage Dockerfile
5. Generates Kubernetes manifests (deployment, service, kustomization)
6. Sets up Gitea Actions CI/CD pipeline
7. Creates CLAUDE.md and BOB.md context files
8. Installs git hooks for automatic chat sync
9. Creates development setup scripts
10. Makes initial git commit

**Supported Stacks**:
- Python (FastAPI/Flask)
- Node.js (Express/NestJS)
- Go
- Java (Spring Boot)
- Rust

**Output Structure**:
```
project-name/
├── .git/
├── .gitignore
├── README.md
├── CLAUDE.md              # Claude Code context
├── BOB.md                 # IBM Bob context
├── Dockerfile             # Multi-stage build
├── src/                   # Application code
├── k8s/                   # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── .gitea/workflows/      # CI/CD pipeline
│   └── build-deploy.yaml
├── scripts/
│   └── dev-setup.sh
└── .git/hooks/
    └── post-commit        # Auto chat sync
```

**Integration Points**:
- Gitea (git hosting + container registry)
- Gitea Actions (CI/CD)
- Flux CD (GitOps deployment)
- K3s (Kubernetes cluster)
- Chat sync automation (Claude + Bob)

**Usage Examples**:
- "Create a new Python FastAPI project called user-service"
- "Initialize a Node.js project for order-api"
- "Start a new Go microservice named payment-gateway"
- "Scaffold a Java Spring Boot project called inventory-service"

**Prerequisites**:
- scaffold-project.sh script available
- Git configured
- Projects directory exists (~/projects)
- Chat sync scripts installed

**Post-Creation Steps**:
1. Review CLAUDE.md and BOB.md
2. Run development setup: `./scripts/dev-setup.sh`
3. Create Gitea repository
4. Push to Gitea: `git push -u origin main`
5. Configure Gitea Actions secrets
6. Flux CD will auto-deploy on image push

**Features**:
- ✅ Production-ready Dockerfile (multi-stage, non-root)
- ✅ Kubernetes manifests with health checks
- ✅ Automated CI/CD pipeline
- ✅ GitOps deployment ready
- ✅ AI chat history persistence
- ✅ Stack-specific best practices
- ✅ Security hardening (non-root containers)
- ✅ Resource limits and requests
- ✅ Liveness and readiness probes

**Customization**:
After creation, you can customize:
- Application code in `src/`
- Kubernetes resources in `k8s/`
- CI/CD pipeline in `.gitea/workflows/`
- Docker build in `Dockerfile`
- Context for AI assistants in `CLAUDE.md` and `BOB.md`