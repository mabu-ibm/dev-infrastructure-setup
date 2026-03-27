# GitHub Repository Setup Guide

Complete guide to push your dev-infrastructure-setup project to GitHub.

## Quick Setup for GitHub

```bash
cd /Users/manfred/Documents/IBM-BOB/dev-infrastructure-setup

# Initialize Git (if not already done)
git init
git branch -M main

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Complete infrastructure setup for AlmaLinux 10"

# Add GitHub remote
git remote add origin https://github.com/YOUR_USERNAME/dev-infrastructure-setup.git

# Push to GitHub
git push -u origin main
```

## Step-by-Step Guide

### 1. Create GitHub Repository

**Option A: Via GitHub Web UI**

1. Go to https://github.com
2. Click the **"+"** icon in top right → **"New repository"**
3. Fill in details:
   - **Repository name**: `dev-infrastructure-setup`
   - **Description**: `Complete CI/CD infrastructure setup with Gitea and K3s on AlmaLinux 10`
   - **Visibility**: Choose Public or Private
   - **DO NOT** check "Initialize this repository with a README" (we already have one)
   - **DO NOT** add .gitignore or license (we already have them)
4. Click **"Create repository"**

**Option B: Via GitHub CLI**

```bash
# Install GitHub CLI if not installed
brew install gh

# Login to GitHub
gh auth login

# Create repository
gh repo create dev-infrastructure-setup \
  --public \
  --description "Complete CI/CD infrastructure setup with Gitea and K3s on AlmaLinux 10" \
  --source=. \
  --remote=origin \
  --push
```

### 2. Initialize Local Repository

```bash
# Navigate to project directory
cd /Users/manfred/Documents/IBM-BOB/dev-infrastructure-setup

# Initialize Git (if not already done)
git init

# Set default branch to main
git branch -M main

# Configure Git user (if not already done)
git config user.name "Your Name"
git config user.email "your-email@example.com"
```

### 3. Add Files and Commit

```bash
# Check what will be added
git status

# Add all files
git add .

# Verify staged files
git status

# Create initial commit
git commit -m "Initial commit: Complete infrastructure setup

Features:
- Docker installation for AlmaLinux 10
- Gitea with SQLite/MySQL database support
- Gitea Actions Runner for CI/CD
- K3s Kubernetes cluster setup
- Comprehensive documentation (3,400+ lines)
- Auto-deployment strategies
- Architecture diagrams and guides

Components:
- almabuild: Docker + Gitea + Actions Runner
- almak3s: K3s Kubernetes cluster

Documentation:
- Quick Start Guide (30-minute setup)
- Architecture Overview
- Detailed setup guides for both hosts
- Auto-deployment guide with 4 strategies
- Git repository setup guide
- Complete troubleshooting sections

Scripts:
- Automated installation scripts
- Network troubleshooting tools
- K3s reinstallation utilities

Tested on AlmaLinux 10"
```

### 4. Add GitHub Remote

Replace `YOUR_USERNAME` with your actual GitHub username:

```bash
# HTTPS (recommended for most users)
git remote add origin https://github.com/YOUR_USERNAME/dev-infrastructure-setup.git

# Or SSH (if you have SSH keys set up)
git remote add origin git@github.com:YOUR_USERNAME/dev-infrastructure-setup.git

# Verify remote
git remote -v
```

### 5. Push to GitHub

```bash
# Push to GitHub
git push -u origin main

# If you get authentication errors, see troubleshooting below
```

### 6. Verify on GitHub

1. Go to https://github.com/YOUR_USERNAME/dev-infrastructure-setup
2. Verify all files are present
3. Check README.md is displayed
4. Review commit history

## Authentication Setup

### HTTPS Authentication (Recommended)

GitHub no longer accepts passwords for HTTPS. You need a Personal Access Token (PAT).

**Create Personal Access Token:**

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Give it a name: `dev-infrastructure-setup`
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
5. Click **"Generate token"**
6. **COPY THE TOKEN** (you won't see it again!)

**Use Token for Authentication:**

```bash
# When prompted for password, use your token instead
git push -u origin main
Username: YOUR_USERNAME
Password: YOUR_PERSONAL_ACCESS_TOKEN

# Or configure credential helper to store token
git config --global credential.helper store
git push -u origin main
# Enter username and token once, it will be saved
```

**Or embed token in URL (less secure):**

```bash
git remote set-url origin https://YOUR_USERNAME:YOUR_TOKEN@github.com/YOUR_USERNAME/dev-infrastructure-setup.git
git push -u origin main
```

### SSH Authentication (More Secure)

**Generate SSH Key:**

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Press Enter to accept default location
# Enter passphrase (optional but recommended)

# Start SSH agent
eval "$(ssh-agent -s)"

# Add SSH key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard
cat ~/.ssh/id_ed25519.pub | pbcopy
# Or manually copy the output
```

**Add SSH Key to GitHub:**

1. Go to GitHub Settings → SSH and GPG keys
2. Click **"New SSH key"**
3. Title: `MacBook Pro` (or your computer name)
4. Paste the public key
5. Click **"Add SSH key"**

**Test SSH Connection:**

```bash
ssh -T git@github.com
# Should see: "Hi USERNAME! You've successfully authenticated..."
```

**Use SSH Remote:**

```bash
# If you used HTTPS, change to SSH
git remote set-url origin git@github.com:YOUR_USERNAME/dev-infrastructure-setup.git

# Push
git push -u origin main
```

## Repository Configuration

### Add Topics/Tags

1. Go to your repository on GitHub
2. Click the gear icon next to "About"
3. Add topics:
   - `almalinux`
   - `gitea`
   - `kubernetes`
   - `k3s`
   - `ci-cd`
   - `docker`
   - `devops`
   - `infrastructure`
   - `automation`

### Create Release

```bash
# Create and push tag
git tag -a v1.0.0 -m "Release version 1.0.0

- Initial stable release
- Complete documentation
- Tested on AlmaLinux 10
- All scripts working"

git push origin v1.0.0
```

Then on GitHub:
1. Go to **Releases** → **"Create a new release"**
2. Choose tag: `v1.0.0`
3. Release title: `v1.0.0 - Initial Release`
4. Description:
   ```markdown
   ## 🎉 Initial Release
   
   Complete CI/CD infrastructure setup for AlmaLinux 10.
   
   ### Features
   - ✅ Docker installation and configuration
   - ✅ Gitea with SQLite/MySQL support
   - ✅ Gitea Actions Runner for CI/CD
   - ✅ K3s Kubernetes cluster
   - ✅ Comprehensive documentation (3,400+ lines)
   - ✅ Auto-deployment strategies
   
   ### Components
   - **almabuild**: Docker + Gitea + Actions Runner
   - **almak3s**: K3s Kubernetes cluster
   
   ### Documentation
   - [Quick Start Guide](docs/QUICKSTART.md)
   - [Architecture Overview](docs/ARCHITECTURE.md)
   - [Auto Deployment Guide](docs/AUTO_DEPLOYMENT_GUIDE.md)
   
   ### Installation
   See [README.md](README.md) for complete setup instructions.
   ```
5. Click **"Publish release"**

### Add README Badges

Add these badges to the top of your README.md:

```markdown
# Development Infrastructure Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![AlmaLinux](https://img.shields.io/badge/AlmaLinux-10-blue.svg)](https://almalinux.org/)
[![Gitea](https://img.shields.io/badge/Gitea-1.21.5-green.svg)](https://gitea.io/)
[![K3s](https://img.shields.io/badge/K3s-latest-blue.svg)](https://k3s.io/)
[![Documentation](https://img.shields.io/badge/docs-3400%2B%20lines-brightgreen.svg)](docs/)

Complete infrastructure setup for CI/CD pipeline with Gitea and Kubernetes on AlmaLinux 10.
```

### Enable GitHub Features

**GitHub Actions (Optional):**
1. Go to repository **Settings** → **Actions** → **General**
2. Enable Actions if you want to use GitHub Actions

**GitHub Pages (Optional):**
1. Go to repository **Settings** → **Pages**
2. Source: Deploy from a branch
3. Branch: `main` / `docs` folder
4. Your documentation will be available at: `https://YOUR_USERNAME.github.io/dev-infrastructure-setup/`

**Branch Protection:**
1. Go to repository **Settings** → **Branches**
2. Add rule for `main` branch:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date

## Updating Repository

### Making Changes

```bash
# Make changes to files
# ... edit files ...

# Check status
git status

# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: Add new feature"

# Push to GitHub
git push origin main
```

### Syncing with GitHub

```bash
# Pull latest changes from GitHub
git pull origin main

# Or fetch and merge separately
git fetch origin
git merge origin/main
```

## Multiple Remotes (GitHub + Gitea)

You can push to both GitHub and Gitea:

```bash
# Add Gitea as second remote
git remote add gitea http://almabuild:3000/your-username/dev-infrastructure-setup.git

# View all remotes
git remote -v

# Push to both
git push origin main      # GitHub
git push gitea main       # Gitea

# Or push to all remotes at once
git remote set-url --add --push origin https://github.com/YOUR_USERNAME/dev-infrastructure-setup.git
git remote set-url --add --push origin http://almabuild:3000/your-username/dev-infrastructure-setup.git

# Now 'git push origin main' pushes to both
```

## Troubleshooting

### Authentication Failed

**Problem:** `remote: Support for password authentication was removed`

**Solution:** Use Personal Access Token instead of password (see Authentication Setup above)

### Permission Denied (publickey)

**Problem:** SSH authentication fails

**Solution:**
```bash
# Check SSH key is added
ssh-add -l

# If not, add it
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Repository Not Found

**Problem:** `fatal: repository 'https://github.com/...' not found`

**Solution:**
- Verify repository exists on GitHub
- Check repository name spelling
- Verify you have access to the repository
- Check remote URL: `git remote -v`

### Large Files

**Problem:** `remote: error: File is too large`

**Solution:** Use Git LFS for large files
```bash
# Install Git LFS
brew install git-lfs
git lfs install

# Track large files
git lfs track "*.iso"
git lfs track "*.tar.gz"

# Add .gitattributes
git add .gitattributes

# Commit and push
git commit -m "Add Git LFS tracking"
git push origin main
```

### Push Rejected

**Problem:** `! [rejected] main -> main (fetch first)`

**Solution:**
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

## Best Practices

### Commit Messages

Use conventional commit format:
```
type(scope): subject

body

footer
```

Examples:
```bash
git commit -m "feat(gitea): Add MySQL database support"
git commit -m "fix(k3s): Resolve network connectivity issue"
git commit -m "docs: Update installation guide"
git commit -m "chore: Update dependencies"
```

### Branch Strategy

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "feat: Add new feature"

# Push feature branch
git push origin feature/new-feature

# Create pull request on GitHub
# After merge, delete branch
git checkout main
git pull origin main
git branch -d feature/new-feature
```

### Regular Backups

```bash
# Clone to another location as backup
git clone https://github.com/YOUR_USERNAME/dev-infrastructure-setup.git ~/backups/dev-infra-backup

# Or create bundle
git bundle create dev-infra-backup.bundle --all
```

## GitHub CLI Commands

```bash
# View repository
gh repo view

# Create issue
gh issue create --title "Bug: Description" --body "Details"

# Create pull request
gh pr create --title "Feature: Description" --body "Details"

# View pull requests
gh pr list

# Clone repository
gh repo clone YOUR_USERNAME/dev-infrastructure-setup
```

## Summary

Your repository is now on GitHub with:
- ✅ Complete source code
- ✅ Comprehensive documentation
- ✅ Version control
- ✅ Public/Private visibility
- ✅ Collaboration features
- ✅ Release management
- ✅ Issue tracking
- ✅ Pull requests
- ✅ GitHub Actions (optional)
- ✅ GitHub Pages (optional)

## Next Steps

1. ✅ Push to GitHub
2. ✅ Add topics/tags
3. ✅ Create first release
4. ✅ Add README badges
5. ✅ Configure branch protection
6. ✅ Enable GitHub features
7. ✅ Share with community
8. ✅ Star your own repository! ⭐

## Quick Reference

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/dev-infrastructure-setup.git

# Status
git status

# Add files
git add .

# Commit
git commit -m "message"

# Push
git push origin main

# Pull
git pull origin main

# View remotes
git remote -v

# View log
git log --oneline

# Create branch
git checkout -b feature/name

# Switch branch
git checkout main

# Merge branch
git merge feature/name

# Delete branch
git branch -d feature/name

# Tag
git tag -a v1.0.0 -m "Release"
git push origin v1.0.0
```

---

**Repository URL:** https://github.com/YOUR_USERNAME/dev-infrastructure-setup

**Made with ❤️ for the DevOps community**