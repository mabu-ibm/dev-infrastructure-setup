#!/bin/bash
################################################################################
# Git Repository Initialization Script
# Purpose: Initialize and push the dev-infrastructure-setup repository
# Usage: ./init-git-repo.sh
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

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "vm-setup" ]; then
    log_error "Please run this script from the dev-infrastructure-setup directory"
    exit 1
fi

log_info "Git Repository Initialization for dev-infrastructure-setup"
echo ""

# Step 1: Check if Git is installed
log_step "Step 1: Checking Git installation..."
if ! command -v git &> /dev/null; then
    log_error "Git is not installed. Please install Git first."
    exit 1
fi
log_info "✓ Git is installed: $(git --version)"

# Step 2: Check if already a Git repository
if [ -d ".git" ]; then
    log_warn "This directory is already a Git repository"
    read -p "Do you want to reinitialize? (y/N): " reinit
    if [[ ! "$reinit" =~ ^[Yy]$ ]]; then
        log_info "Keeping existing repository"
        exit 0
    fi
    log_info "Removing existing .git directory..."
    rm -rf .git
fi

# Step 3: Configure Git user (if not configured)
log_step "Step 2: Configuring Git user..."
if ! git config user.name &> /dev/null; then
    read -p "Enter your Git username: " git_username
    git config user.name "$git_username"
fi
if ! git config user.email &> /dev/null; then
    read -p "Enter your Git email: " git_email
    git config user.email "$git_email"
fi
log_info "✓ Git user: $(git config user.name) <$(git config user.email)>"

# Step 4: Initialize Git repository
log_step "Step 3: Initializing Git repository..."
git init
git branch -M main
log_info "✓ Git repository initialized with 'main' branch"

# Step 5: Add files
log_step "Step 4: Adding files to repository..."
git add .
log_info "✓ Files staged for commit"

# Show what will be committed
echo ""
log_info "Files to be committed:"
git status --short | head -20
file_count=$(git status --short | wc -l)
if [ "$file_count" -gt 20 ]; then
    log_info "... and $((file_count - 20)) more files"
fi
echo ""

# Step 6: Create initial commit
log_step "Step 5: Creating initial commit..."
git commit -m "Initial commit: Complete infrastructure setup

Features:
- Docker installation for AlmaLinux 10
- Gitea with SQLite/MySQL database support
- Gitea Actions Runner for CI/CD
- K3s Kubernetes cluster setup
- Comprehensive documentation (3,400+ lines)
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
- Git repository setup guide
- SSH configuration guide
- Complete troubleshooting sections

Scripts:
- Automated installation scripts
- Network troubleshooting tools
- K3s reinstallation utilities
- SSH passwordless setup

Tested on AlmaLinux 10
Includes complete chat history and development notes"

log_info "✓ Initial commit created"

# Step 7: Configure remote
log_step "Step 6: Configuring remote repository..."
echo ""
log_info "Remote repository options:"
echo "1) Gitea (http://almabuild:3000)"
echo "2) Gitea SSH (ssh://git@almabuild:2222)"
echo "3) Custom URL"
echo "4) Skip (configure later)"
echo ""
read -p "Choose option [1-4]: " remote_option

case $remote_option in
    1)
        read -p "Enter your Gitea username: " gitea_user
        read -p "Enter repository name [dev-infrastructure-setup]: " repo_name
        repo_name=${repo_name:-dev-infrastructure-setup}
        remote_url="http://almabuild:3000/${gitea_user}/${repo_name}.git"
        ;;
    2)
        read -p "Enter your Gitea username: " gitea_user
        read -p "Enter repository name [dev-infrastructure-setup]: " repo_name
        repo_name=${repo_name:-dev-infrastructure-setup}
        remote_url="ssh://git@almabuild:2222/${gitea_user}/${repo_name}.git"
        ;;
    3)
        read -p "Enter remote URL: " remote_url
        ;;
    4)
        log_info "Skipping remote configuration"
        remote_url=""
        ;;
    *)
        log_error "Invalid option"
        exit 1
        ;;
esac

if [ -n "$remote_url" ]; then
    git remote add origin "$remote_url"
    log_info "✓ Remote 'origin' configured: $remote_url"
    
    # Step 8: Push to remote
    log_step "Step 7: Pushing to remote..."
    echo ""
    log_warn "Make sure the repository exists on Gitea before pushing!"
    log_info "Create it at: http://almabuild:3000/repo/create"
    echo ""
    read -p "Repository created? Ready to push? (y/N): " ready_push
    
    if [[ "$ready_push" =~ ^[Yy]$ ]]; then
        log_info "Pushing to remote..."
        if git push -u origin main; then
            log_info "✓ Successfully pushed to remote"
        else
            log_error "Failed to push to remote"
            log_info "You can push later with: git push -u origin main"
        fi
    else
        log_info "Skipping push. You can push later with: git push -u origin main"
    fi
fi

# Step 9: Create first tag
log_step "Step 8: Creating release tag..."
echo ""
read -p "Create v1.0.0 tag? (y/N): " create_tag

if [[ "$create_tag" =~ ^[Yy]$ ]]; then
    git tag -a v1.0.0 -m "Release version 1.0.0

- Initial stable release
- Complete documentation
- Tested on AlmaLinux 10
- All scripts working
- Auto-deployment guides included"
    
    log_info "✓ Tag v1.0.0 created"
    
    if [ -n "$remote_url" ]; then
        read -p "Push tag to remote? (y/N): " push_tag
        if [[ "$push_tag" =~ ^[Yy]$ ]]; then
            git push origin v1.0.0
            log_info "✓ Tag pushed to remote"
        fi
    fi
fi

# Summary
echo ""
log_info "============================================"
log_info "Git Repository Setup Complete!"
log_info "============================================"
log_info "Repository: $(pwd)"
log_info "Branch: main"
if [ -n "$remote_url" ]; then
    log_info "Remote: $remote_url"
fi
log_info ""
log_info "Useful Commands:"
log_info "  Status:  git status"
log_info "  Log:     git log --oneline"
log_info "  Remote:  git remote -v"
if [ -n "$remote_url" ]; then
    log_info "  Push:    git push origin main"
fi
log_info ""
log_info "Next Steps:"
log_info "1. Verify repository on Gitea web UI"
log_info "2. Configure branch protection (optional)"
log_info "3. Add collaborators (optional)"
log_info "4. Set up webhooks (optional)"
log_info "============================================"

# Save repository info
cat > .git-repo-info.txt <<EOF
Git Repository Information
==========================
Created: $(date)
Directory: $(pwd)
Branch: main
Remote: ${remote_url:-Not configured}

Initial Commit:
$(git log -1 --pretty=format:"%H - %s (%an, %ar)")

Files: $(git ls-files | wc -l) tracked files
Size: $(du -sh .git | cut -f1) (.git directory)

Commands:
- View status: git status
- View log: git log --oneline
- View remote: git remote -v
- Push changes: git push origin main
- Pull changes: git pull origin main
- Create branch: git checkout -b feature/name
- Tag release: git tag -a v1.0.1 -m "Description"

Documentation:
- See docs/GIT_REPOSITORY_SETUP.md for detailed guide
- See README.md for project overview
EOF

log_info "Repository info saved to .git-repo-info.txt"

# Made with Bob
