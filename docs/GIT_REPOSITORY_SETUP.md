# Git Repository Setup Guide

Guide to create and initialize a Git repository for your infrastructure setup.

## Quick Setup

```bash
cd /Users/manfred/Documents/IBM-BOB/dev-infrastructure-setup

# Initialize Git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Complete infrastructure setup

- Docker installation for AlmaLinux 10
- Gitea with SQLite/MySQL support
- Gitea Actions Runner setup
- K3s Kubernetes installation
- Comprehensive documentation
- Auto-deployment guides
- Architecture diagrams"

# Add remote (replace with your repository URL)
git remote add origin https://almabuild:3000/your-username/dev-infrastructure-setup.git

# Push to remote
git push -u origin main
```

## Repository Structure

Your repository will include:

```
dev-infrastructure-setup/
├── .gitignore                     # Git ignore file
├── README.md                      # Main documentation
├── LICENSE                        # License file (optional)
├── docs/                          # Documentation
│   ├── QUICKSTART.md             # Quick start guide
│   ├── ARCHITECTURE.md           # Architecture overview
│   ├── ALMABUILD_SETUP.md        # Build host setup
│   ├── ALMAK3S_SETUP.md          # K8s host setup
│   ├── AUTO_DEPLOYMENT_GUIDE.md  # Auto deployment
│   ├── SSH_PASSWORDLESS_SETUP.md # SSH configuration
│   ├── COMPLETE_SETUP_GUIDE.md   # Detailed guide
│   ├── GIT_REPOSITORY_SETUP.md   # This file
│   └── CHAT_HISTORY.md           # Conversation history
├── vm-setup/                      # Build host scripts
│   ├── fix-docker-almalinux.sh
│   ├── install-gitea-almalinux.sh
│   ├── setup-gitea-actions-runner.sh
│   └── setup-ssh-passwordless.sh
├── k8s-setup/                     # K8s host scripts
│   ├── install-k3s-almalinux.sh
│   ├── troubleshoot-k3s.sh
│   ├── fix-k3s-network.sh
│   └── complete-k3s-reinstall.sh
├── chat-sync/                     # Chat synchronization
│   ├── sync-chats.sh
│   ├── install-git-hooks.sh
│   └── setup-cron-sync.sh
├── bob-skill/                     # Bob skill integration
│   ├── SKILL.md
│   └── skill-handler.sh
├── macbook-setup/                 # MacBook setup scripts
│   ├── install-prerequisites.sh
│   └── configure-environment.sh
└── project-templates/             # Project templates
    └── scaffold-project.sh
```

## Step-by-Step Setup

### 1. Create .gitignore

```bash
cat > .gitignore <<'EOF'
# Environment files
.env
*.env.local

# Logs
*.log
logs/

# Temporary files
*.tmp
*.temp
.DS_Store

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Backup files
*.backup
*.bak

# Sensitive data
**/secrets/
**/credentials/
kubeconfig*
*.key
*.pem

# Build artifacts
*.tar.gz
*.zip
EOF
```

### 2. Create LICENSE (Optional)

```bash
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Manfred

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

### 3. Initialize Git Repository

```bash
# Navigate to project directory
cd /Users/manfred/Documents/IBM-BOB/dev-infrastructure-setup

# Initialize Git
git init

# Configure Git (if not already done)
git config user.name "Manfred"
git config user.email "your-email@example.com"

# Check status
git status
```

### 4. Add Files to Repository

```bash
# Add all files
git add .

# Or add selectively
git add README.md
git add docs/
git add vm-setup/
git add k8s-setup/
git add .gitignore

# Check what will be committed
git status
```

### 5. Create Initial Commit

```bash
git commit -m "Initial commit: Complete infrastructure setup

Features:
- Docker installation for AlmaLinux 10
- Gitea with SQLite/MySQL database support
- Gitea Actions Runner for CI/CD
- K3s Kubernetes cluster setup
- Comprehensive documentation (2,800+ lines)
- Auto-deployment strategies
- Architecture diagrams and guides
- Troubleshooting documentation

Components:
- almabuild: Docker + Gitea + Actions Runner
- almak3s: K3s Kubernetes cluster

Documentation:
- Quick Start Guide (30-minute setup)
- Architecture Overview
- Detailed setup guides for both hosts
- Auto-deployment guide with 4 strategies
- SSH configuration guide
- Complete troubleshooting sections

Scripts:
- Automated installation scripts
- Network troubleshooting tools
- K3s reinstallation utilities
- SSH passwordless setup

Tested on AlmaLinux 10"
```

### 6. Create Repository on Gitea

**Option A: Via Web UI**
1. Log into Gitea: `http://almabuild:3000`
2. Click "+" → "New Repository"
3. Repository name: `dev-infrastructure-setup`
4. Description: "Complete CI/CD infrastructure setup for AlmaLinux 10"
5. Visibility: Choose Public or Private
6. **Do NOT** initialize with README (we already have one)
7. Click "Create Repository"

**Option B: Via API**
```bash
curl -X POST "http://almabuild:3000/api/v1/user/repos" \
  -H "Authorization: token YOUR_GITEA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dev-infrastructure-setup",
    "description": "Complete CI/CD infrastructure setup for AlmaLinux 10",
    "private": false,
    "auto_init": false
  }'
```

### 7. Add Remote and Push

```bash
# Add remote (replace with your actual URL)
git remote add origin http://almabuild:3000/your-username/dev-infrastructure-setup.git

# Or use SSH
git remote add origin ssh://git@almabuild:2222/your-username/dev-infrastructure-setup.git

# Verify remote
git remote -v

# Push to remote
git push -u origin main

# If main branch doesn't exist, create it
git branch -M main
git push -u origin main
```

### 8. Verify Repository

```bash
# Check remote status
git remote show origin

# View commit history
git log --oneline

# Check branch
git branch -a
```

## Including Chat History

### Create Chat History Document

The chat history has been saved in `docs/CHAT_HISTORY.md` with:
- Complete conversation
- All questions and answers
- Technical decisions made
- Problem-solving steps
- Implementation details

### Add to Repository

```bash
# Add chat history
git add docs/CHAT_HISTORY.md

# Commit
git commit -m "Add chat history and development notes"

# Push
git push origin main
```

## Repository Management

### Creating Branches

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ... edit files ...

# Commit changes
git add .
git commit -m "Add new feature"

# Push branch
git push -u origin feature/new-feature
```

### Tagging Releases

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0

- Initial stable release
- Complete documentation
- Tested on AlmaLinux 10
- All scripts working"

# Push tag
git push origin v1.0.0

# List tags
git tag -l
```

### Updating Repository

```bash
# Pull latest changes
git pull origin main

# Make changes
# ... edit files ...

# Stage changes
git add .

# Commit with descriptive message
git commit -m "Update: Description of changes"

# Push changes
git push origin main
```

## Gitea-Specific Features

### Enable Actions

1. Go to repository settings
2. Navigate to "Actions" tab
3. Enable Actions
4. Configure runner labels

### Add Webhooks

1. Go to repository settings
2. Navigate to "Webhooks" tab
3. Add webhook URL
4. Configure events (push, pull request, etc.)

### Configure Branch Protection

1. Go to repository settings
2. Navigate to "Branches" tab
3. Add branch protection rule for `main`
4. Require pull request reviews
5. Require status checks

### Add Collaborators

1. Go to repository settings
2. Navigate to "Collaborators" tab
3. Add users or teams
4. Set permissions (Read, Write, Admin)

## Best Practices

### Commit Messages

Use conventional commit format:
```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/tooling changes

Example:
```bash
git commit -m "feat(gitea): Add MySQL database support

- Add interactive database selection
- Support both SQLite and MySQL
- Automatic database creation
- Connection validation

Closes #123"
```

### Branch Strategy

**Main Branch:**
- Always stable
- Protected from direct pushes
- Requires pull requests

**Feature Branches:**
- `feature/feature-name`
- Created from main
- Merged via pull request

**Hotfix Branches:**
- `hotfix/issue-description`
- For urgent fixes
- Merged to main and develop

### Documentation Updates

Always update documentation when:
- Adding new features
- Changing configurations
- Fixing bugs
- Updating dependencies

### Version Control

Use semantic versioning:
- `MAJOR.MINOR.PATCH`
- Example: `1.2.3`

Increment:
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## Backup Strategy

### Local Backup

```bash
# Create backup
tar -czf dev-infrastructure-setup-backup-$(date +%Y%m%d).tar.gz \
  /Users/manfred/Documents/IBM-BOB/dev-infrastructure-setup

# Verify backup
tar -tzf dev-infrastructure-setup-backup-*.tar.gz | head
```

### Remote Backup

```bash
# Add additional remote (e.g., GitHub)
git remote add github https://github.com/username/dev-infrastructure-setup.git

# Push to multiple remotes
git push origin main
git push github main
```

### Automated Backup

Create cron job:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /Users/manfred/Documents/IBM-BOB/dev-infrastructure-setup && \
  git push origin main && \
  tar -czf ~/backups/dev-infra-$(date +\%Y\%m\%d).tar.gz .
```

## Collaboration Workflow

### For Contributors

1. **Fork repository** (if external contributor)
2. **Clone repository**
   ```bash
   git clone http://almabuild:3000/your-username/dev-infrastructure-setup.git
   cd dev-infrastructure-setup
   ```

3. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

4. **Make changes and commit**
   ```bash
   git add .
   git commit -m "feat: Add my feature"
   ```

5. **Push branch**
   ```bash
   git push origin feature/my-feature
   ```

6. **Create pull request** via Gitea UI

### For Maintainers

1. **Review pull request**
2. **Test changes locally**
   ```bash
   git fetch origin
   git checkout feature/my-feature
   # Test changes
   ```

3. **Merge pull request** via Gitea UI or:
   ```bash
   git checkout main
   git merge feature/my-feature
   git push origin main
   ```

4. **Delete feature branch**
   ```bash
   git branch -d feature/my-feature
   git push origin --delete feature/my-feature
   ```

## Troubleshooting

### Authentication Issues

**HTTPS:**
```bash
# Store credentials
git config credential.helper store

# Or use token
git remote set-url origin http://username:token@almabuild:3000/user/repo.git
```

**SSH:**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add to Gitea
cat ~/.ssh/id_ed25519.pub
# Copy and add in Gitea Settings → SSH Keys

# Test connection
ssh -T git@almabuild -p 2222
```

### Push Rejected

```bash
# Pull latest changes first
git pull origin main --rebase

# Resolve conflicts if any
# ... edit files ...
git add .
git rebase --continue

# Push again
git push origin main
```

### Large Files

```bash
# Use Git LFS for large files
git lfs install
git lfs track "*.iso"
git lfs track "*.tar.gz"
git add .gitattributes
git commit -m "Add Git LFS tracking"
```

## Next Steps

1. ✅ Initialize Git repository
2. ✅ Create .gitignore and LICENSE
3. ✅ Make initial commit
4. ✅ Create repository on Gitea
5. ✅ Push to remote
6. ✅ Add chat history
7. ✅ Configure branch protection
8. ✅ Set up webhooks (optional)
9. ✅ Add collaborators (optional)
10. ✅ Create first release tag

## Summary

Your repository is now ready with:
- ✅ Complete infrastructure setup scripts
- ✅ Comprehensive documentation (2,800+ lines)
- ✅ Chat history and development notes
- ✅ Version control with Git
- ✅ Hosted on your Gitea instance
- ✅ Ready for collaboration
- ✅ Backup strategy in place

The repository serves as:
- 📚 Documentation hub
- 🛠️ Script repository
- 📝 Knowledge base
- 🔄 Version control
- 🤝 Collaboration platform