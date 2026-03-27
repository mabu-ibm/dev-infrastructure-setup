# almabuild Host Setup Guide

Complete setup guide for the build and CI/CD host running Docker, Gitea, and Gitea Actions Runner.

## Table of Contents
- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Verification](#verification)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- AlmaLinux 10 installed and updated
- Root or sudo access
- Internet connectivity
- Hostname configured as `almabuild`

## System Requirements

### Minimum
- CPU: 2 cores
- RAM: 4 GB
- Disk: 50 GB
- Network: 1 Gbps

### Recommended
- CPU: 4+ cores
- RAM: 8+ GB
- Disk: 100+ GB SSD
- Network: 1 Gbps

## Installation Steps

### Step 1: Install Docker

Run the Docker installation script:

```bash
cd /path/to/dev-infrastructure-setup
sudo ./vm-setup/fix-docker-almalinux.sh
```

**What this script does:**
- Installs required kernel modules (xt_addrtype, br_netfilter, overlay)
- Installs Docker CE from official repository
- Configures Docker daemon with:
  - Storage driver: overlay2
  - Cgroup driver: systemd
  - Log rotation (10MB max, 3 files)
- Configures firewall for Docker
- Starts and enables Docker service

**Verification:**
```bash
# Check Docker status
systemctl status docker

# Test Docker
docker run hello-world

# Verify kernel modules
lsmod | grep -E 'xt_addrtype|br_netfilter|overlay'
```

### Step 2: Install Gitea

Run the Gitea installation script:

```bash
cd /path/to/dev-infrastructure-setup
sudo ./vm-setup/install-gitea-almalinux.sh
```

**Interactive Prompts:**

1. **Database Selection:**
   ```
   Choose database type for Gitea:
   1) SQLite (default, simple, no setup required)
   2) MySQL (recommended for production)
   
   Enter choice [1-2] (default: 1):
   ```

2. **For SQLite (Option 1):**
   - Just press Enter
   - No additional configuration needed

3. **For MySQL (Option 2):**
   ```
   MySQL Host (default: localhost): [Enter host]
   MySQL Port (default: 3306): [Enter port]
   Database Name (default: gitea): [Enter database name]
   Database User (default: gitea): [Enter username]
   Database Password: [Enter password]
   ```

**What this script does:**
- Creates `git` system user
- Downloads Gitea binary (version 1.21.5)
- Creates directory structure:
  - `/var/lib/gitea` - Home directory
  - `/var/lib/gitea/data` - Data and repositories
  - `/var/log/gitea` - Log files
- Configures Gitea with:
  - Web UI on port 3000
  - SSH on port 2222
  - SQLite or MySQL database
  - LFS support enabled
  - Container registry (packages) enabled
  - Actions enabled
- Creates systemd service
- Configures firewall (ports 3000, 2222)

**Post-Installation:**

1. Access web interface:
   ```
   http://almabuild:3000
   ```

2. Complete initial setup:
   - Create admin user
   - Configure site settings
   - Enable container registry (if needed)

3. Verify installation:
   ```bash
   # Check service status
   systemctl status gitea
   
   # View logs
   journalctl -u gitea -f
   
   # Check ports
   ss -tlnp | grep -E '3000|2222'
   ```

### Step 3: Install Gitea Actions Runner

Run the Actions Runner setup script:

```bash
cd /path/to/dev-infrastructure-setup
sudo ./vm-setup/setup-gitea-actions-runner.sh
```

**What this script does:**
- Creates `gitea-runner` system user
- Adds user to docker group
- Downloads act_runner binary (version 0.2.6)
- Creates directories:
  - `/var/lib/gitea-runner` - Configuration
  - `/var/lib/act_runner` - Working directory
- Generates default configuration
- Creates systemd service
- Displays registration instructions

**Registration Steps:**

1. Log into Gitea as admin
2. Navigate to: **Site Administration → Actions → Runners**
3. Click **"Create new Runner"**
4. Copy the registration token
5. Register the runner:

   ```bash
   cd /var/lib/act_runner
   sudo -u gitea-runner /usr/local/bin/act_runner register \
     --instance http://localhost:3000 \
     --token YOUR_REGISTRATION_TOKEN \
     --name build-runner-almabuild \
     --labels ubuntu-latest,almalinux-latest
   ```

6. Start the service:
   ```bash
   systemctl enable gitea-runner
   systemctl start gitea-runner
   ```

7. Verify:
   ```bash
   # Check service status
   systemctl status gitea-runner
   
   # View logs
   journalctl -u gitea-runner -f
   
   # Check in Gitea UI
   # Site Administration → Actions → Runners
   # Should show runner as "Idle"
   ```

## Configuration

### Gitea Configuration

Main configuration file: `/var/lib/gitea/custom/conf/app.ini`

**Key Settings:**

```ini
[server]
HTTP_PORT = 3000
SSH_PORT = 2222
DOMAIN = almabuild

[database]
# SQLite
DB_TYPE = sqlite3
PATH = /var/lib/gitea/data/gitea.db

# OR MySQL
DB_TYPE = mysql
HOST = localhost:3306
NAME = gitea
USER = gitea
PASSWD = your_password

[repository]
ROOT = /var/lib/gitea/data/gitea-repositories

[actions]
ENABLED = true

[packages]
ENABLED = true
```

**Restart after changes:**
```bash
systemctl restart gitea
```

### Actions Runner Configuration

Configuration file: `/var/lib/gitea-runner/config.yaml`

**Key Settings:**

```yaml
runner:
  capacity: 2  # Number of concurrent jobs
  labels:
    - "ubuntu-latest:docker://node:16-bullseye"
    - "ubuntu-22.04:docker://node:16-bullseye"
    - "ubuntu-20.04:docker://node:16-bullseye"
    - "almalinux-latest:docker://almalinux:9"

container:
  network: ""
  privileged: false  # Set to true if needed
```

**Restart after changes:**
```bash
systemctl restart gitea-runner
```

### Firewall Configuration

**Open Ports:**
```bash
# Gitea web interface
firewall-cmd --permanent --add-port=3000/tcp

# Gitea SSH
firewall-cmd --permanent --add-port=2222/tcp

# Reload firewall
firewall-cmd --reload

# Verify
firewall-cmd --list-ports
```

## Verification

### Complete System Check

```bash
# 1. Check all services
systemctl status docker
systemctl status gitea
systemctl status gitea-runner

# 2. Check Docker
docker ps
docker images

# 3. Check Gitea
curl http://localhost:3000

# 4. Check SSH
ssh -p 2222 git@localhost

# 5. Check logs
journalctl -u docker -n 50
journalctl -u gitea -n 50
journalctl -u gitea-runner -n 50

# 6. Check disk usage
df -h
du -sh /var/lib/gitea
du -sh /var/lib/docker

# 7. Check network
ss -tlnp | grep -E '3000|2222'
```

### Test CI/CD Pipeline

1. **Create Test Repository:**
   - Log into Gitea
   - Create new repository: `test-actions`
   - Enable Actions in repository settings

2. **Add Workflow File:**
   
   Create `.gitea/workflows/test.yaml`:
   ```yaml
   name: Test Build
   on: [push]
   
   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Run test
           run: |
             echo "Hello from Gitea Actions!"
             date
             uname -a
   ```

3. **Push and Verify:**
   ```bash
   git add .gitea/workflows/test.yaml
   git commit -m "Add test workflow"
   git push
   ```

4. **Check Results:**
   - Go to repository → Actions tab
   - Should see workflow running
   - Check runner logs: `journalctl -u gitea-runner -f`

## Usage

### Creating Repositories

```bash
# Via Web UI
1. Click "+" → "New Repository"
2. Enter repository name
3. Choose visibility (public/private)
4. Initialize with README (optional)
5. Click "Create Repository"

# Via CLI
git clone ssh://git@almabuild:2222/username/repo.git
cd repo
# ... make changes ...
git add .
git commit -m "Initial commit"
git push origin main
```

### Using Container Registry

```bash
# Login to registry
docker login almabuild:3000

# Tag image
docker tag myapp:latest almabuild:3000/username/myapp:latest

# Push image
docker push almabuild:3000/username/myapp:latest

# Pull image
docker pull almabuild:3000/username/myapp:latest
```

### Managing Actions

```bash
# View runner status
systemctl status gitea-runner

# View runner logs
journalctl -u gitea-runner -f

# Restart runner
systemctl restart gitea-runner

# Check runner in Gitea
# Site Administration → Actions → Runners
```

## Troubleshooting

### Docker Issues

**Problem:** Docker fails to start
```bash
# Check logs
journalctl -u docker -n 100

# Check kernel modules
lsmod | grep -E 'xt_addrtype|br_netfilter|overlay'

# Reload modules
modprobe xt_addrtype
modprobe br_netfilter
modprobe overlay

# Restart Docker
systemctl restart docker
```

**Problem:** Permission denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Re-login or use
newgrp docker
```

### Gitea Issues

**Problem:** Gitea won't start
```bash
# Check logs
journalctl -u gitea -n 100

# Check configuration
cat /var/lib/gitea/custom/conf/app.ini

# Check permissions
ls -la /var/lib/gitea
sudo chown -R git:git /var/lib/gitea

# Restart service
systemctl restart gitea
```

**Problem:** Can't access web interface
```bash
# Check if service is running
systemctl status gitea

# Check port
ss -tlnp | grep 3000

# Check firewall
firewall-cmd --list-ports

# Test locally
curl http://localhost:3000
```

### Actions Runner Issues

**Problem:** Runner not registering
```bash
# Check working directory
cd /var/lib/act_runner
ls -la

# Check permissions
sudo chown -R gitea-runner:gitea-runner /var/lib/act_runner

# Try registration again
cd /var/lib/act_runner
sudo -u gitea-runner /usr/local/bin/act_runner register \
  --instance http://localhost:3000 \
  --token YOUR_TOKEN \
  --name build-runner-almabuild \
  --labels ubuntu-latest,almalinux-latest
```

**Problem:** Runner not picking up jobs
```bash
# Check runner status
systemctl status gitea-runner

# Check logs
journalctl -u gitea-runner -f

# Verify runner in Gitea UI
# Should show as "Idle" not "Offline"

# Check Docker access
sudo -u gitea-runner docker ps

# Restart runner
systemctl restart gitea-runner
```

**Problem:** Build fails with permission errors
```bash
# Ensure runner user is in docker group
sudo usermod -aG docker gitea-runner

# Restart runner service
systemctl restart gitea-runner

# Verify group membership
groups gitea-runner
```

### Database Issues

**SQLite:**
```bash
# Check database file
ls -lh /var/lib/gitea/data/gitea.db

# Check permissions
sudo chown git:git /var/lib/gitea/data/gitea.db

# Backup database
sudo cp /var/lib/gitea/data/gitea.db /var/lib/gitea/data/gitea.db.backup
```

**MySQL:**
```bash
# Test connection
mysql -h localhost -u gitea -p gitea

# Check Gitea can connect
sudo -u git mysql -h localhost -u gitea -p gitea

# View Gitea logs for database errors
journalctl -u gitea | grep -i database
```

### Network Issues

```bash
# Check all listening ports
ss -tlnp

# Check firewall rules
firewall-cmd --list-all

# Test connectivity
curl http://localhost:3000
ssh -p 2222 git@localhost

# Check DNS resolution
nslookup almabuild
```

## Maintenance

### Daily Tasks
- Monitor service status
- Check disk space
- Review build logs

### Weekly Tasks
```bash
# Clean old Docker images
docker image prune -a

# Clean Docker build cache
docker builder prune

# Check log sizes
du -sh /var/log/gitea
du -sh /var/lib/docker
```

### Monthly Tasks
```bash
# Update system packages
sudo dnf update -y

# Backup Gitea data
sudo tar -czf gitea-backup-$(date +%Y%m%d).tar.gz /var/lib/gitea/data

# Backup database
sudo cp /var/lib/gitea/data/gitea.db /backup/gitea-$(date +%Y%m%d).db

# Review and rotate logs
sudo journalctl --vacuum-time=30d
```

### Updates

**Update Gitea:**
```bash
# Download new version
sudo wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/NEW_VERSION/gitea-NEW_VERSION-linux-amd64

# Stop service
sudo systemctl stop gitea

# Backup old binary
sudo cp /usr/local/bin/gitea /usr/local/bin/gitea.old

# Set permissions
sudo chmod +x /usr/local/bin/gitea

# Start service
sudo systemctl start gitea

# Verify
/usr/local/bin/gitea --version
```

**Update Actions Runner:**
```bash
# Download new version
sudo wget -O /usr/local/bin/act_runner https://dl.gitea.com/act_runner/NEW_VERSION/act_runner-NEW_VERSION-linux-amd64

# Stop service
sudo systemctl stop gitea-runner

# Set permissions
sudo chmod +x /usr/local/bin/act_runner

# Start service
sudo systemctl start gitea-runner

# Verify
/usr/local/bin/act_runner --version
```

## Security Best Practices

1. **Use strong passwords** for Gitea admin and database
2. **Enable 2FA** for admin accounts
3. **Regular backups** of repositories and database
4. **Keep system updated** with security patches
5. **Monitor logs** for suspicious activity
6. **Use SSH keys** instead of passwords for git operations
7. **Restrict firewall** to only necessary ports
8. **Regular security audits** of configurations

## Additional Resources

- [Gitea Documentation](https://docs.gitea.io/)
- [Gitea Actions Documentation](https://docs.gitea.io/en-us/usage/actions/overview/)
- [Docker Documentation](https://docs.docker.com/)
- [AlmaLinux Documentation](https://wiki.almalinux.org/)