# Gitea Actions Runner Troubleshooting Guide

## Common Issue: Runner Not Starting After Registration

### Problem
After registering the Gitea Actions runner, the service fails to start with errors like:
- "Failed to find runner file"
- "Configuration file not found"
- Service status shows "failed" or "inactive"

### Root Cause
The runner registration creates the `.runner` file in `/var/lib/act_runner/`, but the systemd service expects it in `/var/lib/gitea-runner/`. This mismatch causes the service to fail.

### Solution: Automated Fix Script

We've created an automated fix script that handles this issue. After registering your runner, simply run:

```bash
sudo /usr/local/bin/fix-gitea-runner.sh
```

This script will:
1. ✅ Move `.runner` file to correct location (`/var/lib/gitea-runner/`)
2. ✅ Regenerate configuration in the correct directory
3. ✅ Set proper ownership for all files
4. ✅ Restart the gitea-runner service
5. ✅ Display service status

### Manual Fix (If Needed)

If you need to fix this manually, follow these steps:

```bash
# 1. Create the runner home directory
sudo mkdir -p /var/lib/gitea-runner

# 2. Move the .runner file to correct location
sudo mv /var/lib/act_runner/.runner /var/lib/gitea-runner/

# 3. Regenerate configuration in correct location
sudo -u gitea-runner /usr/local/bin/act_runner generate-config | sudo tee /var/lib/gitea-runner/config.yaml > /dev/null

# 4. Set proper ownership
sudo chown -R gitea-runner:gitea-runner /var/lib/gitea-runner

# 5. Restart the service
sudo systemctl restart gitea-runner

# 6. Check status
sudo systemctl status gitea-runner
```

## Complete Registration and Setup Process

### Step 1: Install Runner
```bash
cd vm-setup
sudo ./setup-gitea-actions-runner.sh
```

### Step 2: Register Runner

1. Log into Gitea as admin
2. Go to **Site Administration** → **Actions** → **Runners**
3. Click **"Create new Runner"**
4. Copy the registration token
5. Register the runner:

```bash
cd /var/lib/act_runner
sudo -u gitea-runner /usr/local/bin/act_runner register \
  --instance http://almabuild:3000 \
  --token YOUR_REGISTRATION_TOKEN \
  --name build-runner-1 \
  --labels ubuntu-latest,almalinux-latest
```

### Step 3: Fix Configuration (CRITICAL)

```bash
sudo /usr/local/bin/fix-gitea-runner.sh
```

**Expected Output:**
```
[INFO] Fixing Gitea Runner configuration...
[INFO] Moving .runner file to /var/lib/gitea-runner...
[INFO] Regenerating configuration...
[INFO] Setting ownership...
[INFO] Restarting gitea-runner service...
[SUCCESS] Gitea Runner configuration fixed!
[INFO] Checking status...
● gitea-runner.service - Gitea Actions Runner
     Loaded: loaded (/etc/systemd/system/gitea-runner.service; enabled; preset: disabled)
     Active: active (running) since...
```

### Step 4: Enable Service

```bash
sudo systemctl enable gitea-runner
```

### Step 5: Verify

```bash
# Check service status
sudo systemctl status gitea-runner

# View live logs
sudo journalctl -u gitea-runner -f

# Check runner registration
sudo cat /var/lib/gitea-runner/.runner
```

## Verification Checklist

✅ **Service Running:**
```bash
sudo systemctl status gitea-runner
# Should show: Active: active (running)
```

✅ **Runner Registered:**
```bash
sudo cat /var/lib/gitea-runner/.runner
# Should show runner configuration with UUID
```

✅ **Configuration Present:**
```bash
sudo cat /var/lib/gitea-runner/config.yaml
# Should show runner configuration
```

✅ **Proper Ownership:**
```bash
ls -la /var/lib/gitea-runner/
# All files should be owned by gitea-runner:gitea-runner
```

✅ **Runner Visible in Gitea:**
- Go to Gitea → Site Administration → Actions → Runners
- Your runner should appear with status "idle" (green)

## Common Errors and Solutions

### Error: "Failed to find runner file"

**Cause:** `.runner` file is in wrong location

**Solution:**
```bash
sudo /usr/local/bin/fix-gitea-runner.sh
```

### Error: "Permission denied"

**Cause:** Incorrect file ownership

**Solution:**
```bash
sudo chown -R gitea-runner:gitea-runner /var/lib/gitea-runner
sudo systemctl restart gitea-runner
```

### Error: "Cannot connect to Docker daemon"

**Cause:** gitea-runner user not in docker group

**Solution:**
```bash
sudo usermod -aG docker gitea-runner
sudo systemctl restart gitea-runner
```

### Error: "Runner not appearing in Gitea"

**Cause:** Registration token expired or incorrect

**Solution:**
1. Generate new token in Gitea
2. Re-register runner
3. Run fix script

### Error: "Workflow jobs not starting"

**Cause:** Runner labels don't match workflow requirements

**Solution:**
Check workflow file uses correct labels:
```yaml
runs-on: ubuntu-latest  # or almalinux-latest
```

## Logs and Debugging

### View Service Logs
```bash
# Live logs
sudo journalctl -u gitea-runner -f

# Last 50 lines
sudo journalctl -u gitea-runner -n 50

# Logs since boot
sudo journalctl -u gitea-runner -b
```

### Check Runner Status
```bash
# Service status
sudo systemctl status gitea-runner

# Is service enabled?
sudo systemctl is-enabled gitea-runner

# Is service active?
sudo systemctl is-active gitea-runner
```

### Test Docker Access
```bash
# Test as runner user
sudo -u gitea-runner docker ps

# Should list running containers without errors
```

### Check Configuration Files
```bash
# Runner registration
sudo cat /var/lib/gitea-runner/.runner

# Runner config
sudo cat /var/lib/gitea-runner/config.yaml

# Systemd service
sudo cat /etc/systemd/system/gitea-runner.service
```

## File Locations Reference

| File/Directory | Purpose | Owner |
|----------------|---------|-------|
| `/usr/local/bin/act_runner` | Runner binary | root |
| `/usr/local/bin/fix-gitea-runner.sh` | Fix script | root |
| `/var/lib/gitea-runner/` | Runner home directory | gitea-runner |
| `/var/lib/gitea-runner/.runner` | Registration file | gitea-runner |
| `/var/lib/gitea-runner/config.yaml` | Configuration | gitea-runner |
| `/var/lib/act_runner/` | Working directory | gitea-runner |
| `/etc/systemd/system/gitea-runner.service` | Service file | root |

## Best Practices

1. **Always run fix script after registration**
   ```bash
   sudo /usr/local/bin/fix-gitea-runner.sh
   ```

2. **Enable service for auto-start**
   ```bash
   sudo systemctl enable gitea-runner
   ```

3. **Monitor logs during first workflow**
   ```bash
   sudo journalctl -u gitea-runner -f
   ```

4. **Keep runner updated**
   ```bash
   # Check current version
   /usr/local/bin/act_runner --version
   
   # Update if needed (download new version)
   sudo wget -O /usr/local/bin/act_runner https://dl.gitea.com/act_runner/VERSION/act_runner-VERSION-linux-amd64
   sudo chmod +x /usr/local/bin/act_runner
   sudo systemctl restart gitea-runner
   ```

5. **Regular health checks**
   ```bash
   # Add to cron for daily checks
   0 9 * * * systemctl is-active gitea-runner || systemctl restart gitea-runner
   ```

## Quick Reference Commands

```bash
# Installation
sudo ./vm-setup/setup-gitea-actions-runner.sh

# Registration
cd /var/lib/act_runner && sudo -u gitea-runner /usr/local/bin/act_runner register --instance http://almabuild:3000 --token TOKEN --name build-runner-1 --labels ubuntu-latest,almalinux-latest

# Fix configuration
sudo /usr/local/bin/fix-gitea-runner.sh

# Enable service
sudo systemctl enable gitea-runner

# Service management
sudo systemctl start gitea-runner
sudo systemctl stop gitea-runner
sudo systemctl restart gitea-runner
sudo systemctl status gitea-runner

# Logs
sudo journalctl -u gitea-runner -f

# Verify
sudo cat /var/lib/gitea-runner/.runner
sudo systemctl is-active gitea-runner
```

## Support

If you continue to experience issues:

1. Check all verification steps above
2. Review service logs for specific errors
3. Ensure Gitea Actions is enabled in Gitea configuration
4. Verify Docker is running and accessible
5. Check network connectivity between runner and Gitea

For more help, see:
- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
- [Act Runner Repository](https://gitea.com/gitea/act_runner)

---

**Made with ❤️ by Bob**