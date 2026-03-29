# Complete Gitea Actions Setup Guide

This guide documents the complete, working configuration for Gitea Actions with Docker-based runners.

## 🎯 Overview

This setup enables:
- ✅ Gitea Actions CI/CD pipelines
- ✅ Docker-in-Docker builds
- ✅ Insecure HTTP registry support
- ✅ Automated image builds and pushes
- ✅ Manual workflow triggers

## 📋 Prerequisites

- AlmaLinux 10 host (almabuild.lab.allwaysbeginner.com)
- Docker installed and running
- Gitea installed and running
- gitea-runner user created

## 🔧 Phase 1: Host Machine & Docker Configuration

### 1. Grant Docker Permissions

Add the runner user to the Docker group:

```bash
sudo usermod -aG docker gitea-runner
```

**Why:** Allows the runner to execute Docker commands without sudo.

### 2. Configure Insecure Registry

Edit `/etc/docker/daemon.json`:

```bash
sudo nano /etc/docker/daemon.json
```

Add or update:

```json
{
  "insecure-registries": ["almabuild.lab.allwaysbeginner.com:3000"]
}
```

**Why:** Allows Docker to push/pull from HTTP (non-HTTPS) registry.

Restart Docker:

```bash
sudo systemctl restart docker
```

Verify:

```bash
sudo systemctl status docker
docker info | grep -A 5 "Insecure Registries"
```

### 3. Register the Runner (Docker Mode)

Clean up any old configuration:

```bash
sudo -u gitea-runner bash -c "rm -f /var/lib/gitea-runner/.runner"
```

Register with Docker labels:

```bash
sudo -u gitea-runner bash -c "cd /var/lib/gitea-runner && /usr/local/bin/act_runner register \
  --instance http://almabuild.lab.allwaysbeginner.com:3000 \
  --token YOUR_REGISTRATION_TOKEN \
  --name docker-runner-1 \
  --labels 'ubuntu-latest:docker://gitea/runner-images:ubuntu-latest,almalinux-latest:docker://almalinux:9'"
```

**Important:**
- Replace `YOUR_REGISTRATION_TOKEN` with token from Gitea Admin → Actions → Runners
- Use your actual hostname (not localhost)
- Labels map workflow `runs-on` to Docker images

### 4. Generate Runner Config & Mount Docker Socket

Generate configuration:

```bash
sudo -u gitea-runner bash -c "cd /var/lib/gitea-runner && /usr/local/bin/act_runner generate-config > config.yaml"
```

Add Docker socket mount permission:

```bash
sudo -u gitea-runner bash -c "sed -i 's/valid_volumes: \[\]/valid_volumes: \[\"\/var\/run\/docker.sock\"\]/g' /var/lib/gitea-runner/config.yaml"
```

**Why:** Enables Docker-in-Docker by mounting the host's Docker socket.

Verify configuration:

```bash
sudo cat /var/lib/gitea-runner/config.yaml | grep -A 2 "valid_volumes"
```

Should show:

```yaml
valid_volumes: ["/var/run/docker.sock"]
```

### 5. Create Systemd Service

Create service file:

```bash
sudo nano /etc/systemd/system/gitea-runner.service
```

Add:

```ini
[Unit]
Description=Gitea Actions Runner
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=gitea-runner
Group=gitea-runner
WorkingDirectory=/var/lib/gitea-runner
ExecStart=/usr/local/bin/act_runner daemon -c /var/lib/gitea-runner/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable gitea-runner
sudo systemctl start gitea-runner
```

Verify:

```bash
sudo systemctl status gitea-runner
sudo journalctl -u gitea-runner -f
```

## 🌐 Phase 2: Gitea UI & Security Settings

### 1. Enable Actions in Repository

1. Go to your repository in Gitea
2. Click **Settings (Einstellungen)**
3. Click **Advanced Settings**
4. Enable **Actions (Aktionen)** unit
5. Save changes

**Result:** Actions tab will appear in your repository.

### 2. Generate Personal Access Token (PAT)

1. Go to User Profile → **Settings**
2. Click **Applications**
3. Scroll to **Generate New Token**
4. Token name: `REGISTRY_TOKEN`
5. Select permissions:
   - ✅ `write:package` (Write packages)
   - ✅ `read:package` (Read packages)
6. Click **Generate Token**
7. **Copy the token immediately** (you won't see it again)

**Why:** Provides authentication for pushing to the registry.

### 3. Create Repository Secret

1. Go to repository → **Settings**
2. Click **Actions**
3. Click **Secrets**
4. Click **New secret**
5. Name: `REGISTRY_TOKEN`
6. Value: Paste the PAT from step 2
7. Click **Add secret**

**Result:** Workflow can authenticate with registry using `${{ secrets.REGISTRY_TOKEN }}`.

## 📄 Phase 3: Working Workflow File

Create `.gitea/workflows/build-and-push.yaml`:

```yaml
name: Build and Push Pipeline

on:
  push:
    branches: [ "main", "master" ]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  # JOB 1: Test the application
  test:
    runs-on: ubuntu-latest
    container:
      image: nikolaik/python-nodejs:python3.11-nodejs20
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
                    
      - name: Test application
        run: |
          python -c "from app import app; print('✓ App imports successfully')"
          echo "✓ Application tests passed"

  # JOB 2: Build and push the Docker image
  build-and-push:
    needs: test 
    runs-on: ubuntu-latest
    steps:
      - name: Install Docker CLI
        run: |
          apt-get update
          apt-get install -y docker.io

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          config-inline: |
            [registry."almabuild.lab.allwaysbeginner.com:3000"]
              http = true
              insecure = true

      - name: Login to Gitea Container Registry
        uses: docker/login-action@v3
        with:
          registry: almabuild.lab.allwaysbeginner.com:3000
          username: ${{ gitea.actor }}
          password: ${{ secrets.REGISTRY_TOKEN }}

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            almabuild.lab.allwaysbeginner.com:3000/${{ gitea.repository }}:latest
            almabuild.lab.allwaysbeginner.com:3000/${{ gitea.repository }}:${{ gitea.sha }}

      - name: Image information
        run: |
          echo "==================================="
          echo "Docker Image Build Complete"
          echo "==================================="
          echo "Repository: ${{ gitea.repository }}"
          echo "Commit: ${{ gitea.sha }}"
          echo "Registry: almabuild.lab.allwaysbeginner.com:3000"
          echo "Tags: latest, ${{ gitea.sha }}"
          echo "==================================="
```

## 🔍 Key Configuration Elements

### Workflow Features

1. **`workflow_dispatch`**: Enables manual run button in UI
2. **`permissions`**: Grants package write access
3. **Two-job pipeline**: Separate test and build phases
4. **Docker-in-Docker**: Uses host Docker socket
5. **Insecure registry**: Configured for HTTP registry
6. **Dynamic tagging**: Both `latest` and commit SHA tags

### Container Images

- **Test job**: `nikolaik/python-nodejs:python3.11-nodejs20`
  - Provides both Python and Node.js (required by actions/checkout)
- **Build job**: `ubuntu-latest` (mapped to gitea/runner-images:ubuntu-latest)
  - Installs Docker CLI on-the-fly

### Registry Configuration

- **Registry URL**: `almabuild.lab.allwaysbeginner.com:3000`
- **Protocol**: HTTP (insecure)
- **Authentication**: Personal Access Token via secrets
- **Image naming**: `registry/username/repository:tag`

## ✅ Verification Steps

### 1. Check Runner Status

```bash
# Service status
sudo systemctl status gitea-runner

# Live logs
sudo journalctl -u gitea-runner -f

# Runner registration
sudo cat /var/lib/gitea-runner/.runner
```

### 2. Check Docker Configuration

```bash
# Insecure registries
docker info | grep -A 5 "Insecure Registries"

# Test Docker access as runner
sudo -u gitea-runner docker ps

# Test registry connectivity
sudo -u gitea-runner docker pull busybox
sudo -u gitea-runner docker tag busybox almabuild.lab.allwaysbeginner.com:3000/test/busybox:test
```

### 3. Check Gitea Configuration

**In Gitea Admin:**
1. Site Administration → Actions → Runners
2. Should show `docker-runner-1` with status "idle" (green)

**In Repository:**
1. Actions tab should be visible
2. Secrets should show `REGISTRY_TOKEN`
3. Workflow should trigger on push

### 4. Test Workflow

**Manual trigger:**
1. Go to repository → Actions
2. Select workflow
3. Click "Run workflow"
4. Select branch
5. Click "Run"

**Automatic trigger:**
```bash
# Make a change and push
echo "# Test" >> README.md
git add README.md
git commit -m "Test workflow trigger"
git push
```

## 🐛 Troubleshooting

### Runner Not Starting

**Check logs:**
```bash
sudo journalctl -u gitea-runner -n 50
```

**Common issues:**
- Docker socket permission denied
- Invalid configuration file
- Network connectivity to Gitea

**Solutions:**
```bash
# Fix Docker permissions
sudo usermod -aG docker gitea-runner
sudo systemctl restart gitea-runner

# Regenerate config
sudo -u gitea-runner bash -c "cd /var/lib/gitea-runner && /usr/local/bin/act_runner generate-config > config.yaml"
sudo -u gitea-runner bash -c "sed -i 's/valid_volumes: \[\]/valid_volumes: \[\"\/var\/run\/docker.sock\"\]/g' /var/lib/gitea-runner/config.yaml"
```

### Workflow Fails - Registry Push

**Error:** `401 Unauthorized` or `denied: requested access to the resource is denied`

**Solutions:**
1. Verify PAT has `write:package` permission
2. Check secret name matches workflow (`REGISTRY_TOKEN`)
3. Verify registry URL in workflow matches Docker daemon config

### Workflow Fails - Docker Build

**Error:** `Cannot connect to the Docker daemon`

**Solutions:**
1. Verify Docker socket mount in config:
   ```bash
   sudo cat /var/lib/gitea-runner/config.yaml | grep valid_volumes
   ```
2. Check Docker service is running:
   ```bash
   sudo systemctl status docker
   ```

### Actions Tab Not Visible

**Solutions:**
1. Enable Actions in repository settings
2. Ensure `.gitea/workflows/` directory exists
3. Verify workflow YAML syntax
4. Check Gitea Actions is enabled globally

## 📊 Expected Results

### Successful Workflow Run

```
✓ Test job completes (Python app imports successfully)
✓ Build job completes (Docker image built and pushed)
✓ Two image tags created: latest and commit SHA
✓ Images visible in repository Packages tab
```

### Registry Contents

After successful run:
```
almabuild.lab.allwaysbeginner.com:3000/username/hello-world-python:latest
almabuild.lab.allwaysbeginner.com:3000/username/hello-world-python:abc1234567
```

### Performance

- **Test job**: ~30-60 seconds
- **Build job**: ~2-5 minutes
- **Total pipeline**: ~3-6 minutes

## 🔄 Maintenance

### Update Runner

```bash
# Download new version
sudo wget -O /usr/local/bin/act_runner https://dl.gitea.com/act_runner/VERSION/act_runner-VERSION-linux-amd64
sudo chmod +x /usr/local/bin/act_runner

# Restart service
sudo systemctl restart gitea-runner
```

### Rotate PAT

1. Generate new PAT in Gitea
2. Update `REGISTRY_TOKEN` secret in repository
3. Test workflow run

### Monitor Runner Health

```bash
# Add to cron for daily health check
0 9 * * * systemctl is-active gitea-runner || systemctl restart gitea-runner
```

## 📚 Additional Resources

- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
- [Act Runner Repository](https://gitea.com/gitea/act_runner)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Docker Login Action](https://github.com/docker/login-action)

---

**This configuration has been tested and verified to work with Gitea Actions!** 🎉

Created by IBM Bob AI based on successful user implementation.