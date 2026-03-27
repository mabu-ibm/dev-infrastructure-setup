# SSH Passwordless Login Setup Guide

Complete guide for setting up SSH key-based authentication to AlmaLinux hosts (almak3s and almabuild).

## Overview

This guide covers:
- Automated SSH key generation and distribution
- Manual SSH key setup (if needed)
- Troubleshooting common issues
- Security best practices

## Quick Start

### Automated Setup (Recommended)

```bash
# Run the automated setup script
cd vm-setup
chmod +x setup-ssh-passwordless.sh
./setup-ssh-passwordless.sh
```

The script will:
1. ✅ Check prerequisites (ssh, ssh-keygen, ssh-copy-id)
2. ✅ Create SSH directory with proper permissions
3. ✅ Generate ED25519 SSH key pair (if not exists)
4. ✅ Configure SSH client settings
5. ✅ Copy public key to remote hosts
6. ✅ Test passwordless connections
7. ✅ Display summary and verification

### What You'll Need

- Password for root user on almak3s and almabuild
- Network connectivity to both hosts
- OpenSSH client installed on your MacBook

## Manual Setup

If you prefer manual setup or the automated script fails:

### Step 1: Generate SSH Key Pair

```bash
# Generate ED25519 key (recommended - more secure and faster)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "$(whoami)@$(hostname)-$(date +%Y%m%d)"

# Or generate RSA key (traditional, widely compatible)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "$(whoami)@$(hostname)-$(date +%Y%m%d)"
```

**Options explained:**
- `-t ed25519`: Key type (ED25519 is modern and secure)
- `-f ~/.ssh/id_ed25519`: Output file path
- `-C "comment"`: Comment to identify the key
- `-N ""`: Empty passphrase (optional, add for extra security)

### Step 2: Copy Public Key to Remote Hosts

#### Method 1: Using ssh-copy-id (Easiest)

```bash
# Copy to almak3s
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@almak3s

# Copy to almabuild
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@almabuild
```

#### Method 2: Manual Copy

```bash
# Display your public key
cat ~/.ssh/id_ed25519.pub

# SSH to remote host and add the key
ssh root@almak3s
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo 'YOUR_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

#### Method 3: One-liner

```bash
# For almak3s
cat ~/.ssh/id_ed25519.pub | ssh root@almak3s 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'

# For almabuild
cat ~/.ssh/id_ed25519.pub | ssh root@almabuild 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

### Step 3: Configure SSH Client

Create or edit `~/.ssh/config`:

```bash
# almak3s - K3s Kubernetes cluster
Host almak3s
    HostName almak3s
    User root
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new

# almabuild - Gitea build server
Host almabuild
    HostName almabuild
    User root
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new
```

**Configuration options explained:**
- `HostName`: Actual hostname or IP address
- `User`: Remote username (root for system administration)
- `IdentityFile`: Path to private key
- `IdentitiesOnly yes`: Only use specified identity file
- `ServerAliveInterval 60`: Send keepalive every 60 seconds
- `ServerAliveCountMax 3`: Disconnect after 3 failed keepalives
- `StrictHostKeyChecking accept-new`: Accept new host keys automatically

Set proper permissions:

```bash
chmod 600 ~/.ssh/config
```

### Step 4: Test Connections

```bash
# Test almak3s
ssh almak3s 'hostname && whoami'

# Test almabuild
ssh almabuild 'hostname && whoami'

# Should connect without password prompt
```

## Verification

### Check SSH Key Fingerprint

```bash
# View your public key fingerprint
ssh-keygen -lf ~/.ssh/id_ed25519

# View remote authorized keys
ssh almak3s 'ssh-keygen -lf ~/.ssh/authorized_keys'
```

### Test Connection with Verbose Output

```bash
# Debug connection issues
ssh -v almak3s

# More verbose
ssh -vv almak3s

# Maximum verbosity
ssh -vvv almak3s
```

### Verify Permissions

```bash
# Local permissions
ls -la ~/.ssh/

# Should show:
# drwx------  .ssh/           (700)
# -rw-------  id_ed25519      (600)
# -rw-r--r--  id_ed25519.pub  (644)
# -rw-------  config          (600)

# Remote permissions
ssh almak3s 'ls -la ~/.ssh/'

# Should show:
# drwx------  .ssh/              (700)
# -rw-------  authorized_keys    (600)
```

## Troubleshooting

### Issue: "Permission denied (publickey)"

**Causes:**
1. Wrong permissions on files/directories
2. Public key not in authorized_keys
3. SELinux blocking access
4. Wrong username

**Solutions:**

```bash
# Fix local permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/config

# Fix remote permissions
ssh root@almak3s 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# Check SELinux context (on remote host)
ssh root@almak3s 'restorecon -R -v ~/.ssh'

# Verify public key is present
ssh root@almak3s 'cat ~/.ssh/authorized_keys'
```

### Issue: "Host key verification failed"

**Cause:** Host key changed (reinstalled OS, etc.)

**Solution:**

```bash
# Remove old host key
ssh-keygen -R almak3s
ssh-keygen -R almabuild

# Or remove specific IP
ssh-keygen -R 192.168.1.100

# Then reconnect (will add new key)
ssh almak3s
```

### Issue: "Connection timed out"

**Causes:**
1. Host is down
2. Firewall blocking SSH port
3. Wrong hostname/IP

**Solutions:**

```bash
# Test connectivity
ping almak3s

# Check if SSH port is open
nc -zv almak3s 22

# Try with IP address instead
ssh root@192.168.1.100

# Check firewall on remote host
ssh root@almak3s 'firewall-cmd --list-all'
```

### Issue: Still asks for password

**Causes:**
1. Public key not in authorized_keys
2. SSH server not configured for key auth
3. Using wrong key

**Solutions:**

```bash
# Verify key is copied
ssh root@almak3s 'grep "$(cat ~/.ssh/id_ed25519.pub)" ~/.ssh/authorized_keys'

# Check SSH server config
ssh root@almak3s 'grep -E "PubkeyAuthentication|PasswordAuthentication" /etc/ssh/sshd_config'

# Should show:
# PubkeyAuthentication yes
# PasswordAuthentication yes (can be no after setup)

# Force use of specific key
ssh -i ~/.ssh/id_ed25519 root@almak3s
```

### Issue: "Too many authentication failures"

**Cause:** SSH trying multiple keys before the correct one

**Solution:**

```bash
# Use IdentitiesOnly in config (already in our setup)
# Or specify key explicitly
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@almak3s
```

## Security Best Practices

### 1. Use Strong Key Types

```bash
# Recommended: ED25519 (modern, secure, fast)
ssh-keygen -t ed25519

# Alternative: RSA 4096-bit (widely compatible)
ssh-keygen -t rsa -b 4096
```

### 2. Add Passphrase to Private Key

```bash
# Add passphrase to existing key
ssh-keygen -p -f ~/.ssh/id_ed25519

# Use ssh-agent to avoid typing passphrase repeatedly
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 3. Restrict SSH Access on Remote Hosts

Edit `/etc/ssh/sshd_config` on remote hosts:

```bash
# Disable password authentication (after key setup works)
PasswordAuthentication no

# Disable root login with password
PermitRootLogin prohibit-password

# Allow only specific users
AllowUsers root manfred

# Restart SSH service
systemctl restart sshd
```

### 4. Use SSH Agent Forwarding Carefully

```bash
# In ~/.ssh/config (only for trusted hosts)
Host almak3s
    ForwardAgent yes
```

⚠️ **Warning:** Only enable agent forwarding for hosts you fully trust.

### 5. Regular Key Rotation

```bash
# Generate new key annually
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_2026

# Update authorized_keys on all hosts
# Remove old keys after verification
```

## Advanced Configuration

### Multiple Keys for Different Hosts

```bash
# Generate separate keys
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k3s
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_build

# Configure in ~/.ssh/config
Host almak3s
    IdentityFile ~/.ssh/id_ed25519_k3s

Host almabuild
    IdentityFile ~/.ssh/id_ed25519_build
```

### Jump Host Configuration

```bash
# If hosts are behind a bastion
Host almak3s
    ProxyJump bastion.example.com
    
Host almabuild
    ProxyJump bastion.example.com
```

### SSH Multiplexing (Faster Connections)

```bash
# Add to ~/.ssh/config
Host almak3s almabuild
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

# Create sockets directory
mkdir -p ~/.ssh/sockets
```

## Useful Commands

### Connection Management

```bash
# Connect to host
ssh almak3s

# Execute single command
ssh almak3s 'uptime'

# Execute multiple commands
ssh almak3s 'hostname && uptime && df -h'

# Copy files (using SCP)
scp file.txt almak3s:/tmp/

# Copy files (using rsync)
rsync -avz /local/path/ almak3s:/remote/path/

# Port forwarding
ssh -L 8080:localhost:80 almak3s
```

### Key Management

```bash
# List keys in ssh-agent
ssh-add -l

# Add key to ssh-agent
ssh-add ~/.ssh/id_ed25519

# Remove all keys from ssh-agent
ssh-add -D

# View public key
cat ~/.ssh/id_ed25519.pub

# View private key fingerprint
ssh-keygen -lf ~/.ssh/id_ed25519
```

### Remote Host Management

```bash
# View authorized keys
ssh almak3s 'cat ~/.ssh/authorized_keys'

# Add new key to authorized_keys
cat new_key.pub | ssh almak3s 'cat >> ~/.ssh/authorized_keys'

# Remove specific key
ssh almak3s 'grep -v "key_to_remove" ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys'

# Backup authorized_keys
ssh almak3s 'cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.backup'
```

## Integration with Other Tools

### Git over SSH

```bash
# Clone repository from Gitea on almabuild
git clone ssh://git@almabuild:2222/username/repo.git

# Configure in ~/.ssh/config
Host almabuild-git
    HostName almabuild
    User git
    Port 2222
    IdentityFile ~/.ssh/id_ed25519

# Then use
git clone ssh://almabuild-git/username/repo.git
```

### Ansible

```bash
# Use SSH config in Ansible inventory
[k3s]
almak3s

[build]
almabuild

# Ansible will use ~/.ssh/config automatically
ansible all -m ping
```

### kubectl (K3s Remote Access)

```bash
# Copy kubeconfig from almak3s
scp almak3s:/root/k3s-remote-kubeconfig.yaml ~/.kube/k3s-config

# Use it
export KUBECONFIG=~/.kube/k3s-config
kubectl get nodes
```

## Quick Reference

### File Locations

| File | Purpose | Permissions |
|------|---------|-------------|
| `~/.ssh/id_ed25519` | Private key | 600 |
| `~/.ssh/id_ed25519.pub` | Public key | 644 |
| `~/.ssh/config` | SSH client config | 600 |
| `~/.ssh/known_hosts` | Host fingerprints | 644 |
| `~/.ssh/authorized_keys` | Allowed public keys (remote) | 600 |

### Common SSH Options

| Option | Description |
|--------|-------------|
| `-v` | Verbose output (debug) |
| `-i keyfile` | Specify identity file |
| `-p port` | Specify port |
| `-L local:remote` | Local port forwarding |
| `-R remote:local` | Remote port forwarding |
| `-N` | No command (port forwarding only) |
| `-f` | Background mode |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Generic error |
| 255 | SSH error |

## Next Steps

After setting up passwordless SSH:

1. ✅ **Install K3s**: Run `k8s-setup/install-k3s-almalinux.sh` on almak3s
2. ✅ **Install Gitea**: Run `vm-setup/install-gitea-almalinux.sh` on almabuild
3. ✅ **Configure Flux CD**: Run `k8s-setup/install-flux-cd.sh`
4. ✅ **Set up automation**: Configure CI/CD pipelines

## Support

If you encounter issues:

1. Check this troubleshooting guide
2. Review SSH logs: `ssh -vvv hostname`
3. Check remote logs: `ssh hostname 'journalctl -u sshd -n 50'`
4. Verify network connectivity: `ping hostname`
5. Test with password first: `ssh -o PubkeyAuthentication=no hostname`

---

**Made with Bob** 🤖