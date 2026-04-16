# CoreDNS Configuration Guide

## Understanding the Script Behavior

### Does it change CoreDNS? ✅ YES
The `configure-coredns-hosts.sh` script **DOES** modify CoreDNS configuration:

1. **Updates CoreDNS ConfigMap** (lines 166-169)
   - Adds the `hosts` plugin to the Corefile
   - Configures it to read from `/etc/coredns/hosts`

2. **Patches CoreDNS Deployment** (lines 182-204)
   - Mounts the `coredns-hosts` ConfigMap as a volume
   - Makes it available at `/etc/coredns/hosts` inside CoreDNS pods

3. **Restarts CoreDNS** (line 212)
   - Triggers a rollout restart to apply changes
   - New pods pick up the updated configuration

### Is it persistent after reboot? ✅ YES
The changes **ARE persistent** because:

- **ConfigMaps are stored in etcd** (Kubernetes database)
- **Deployment specs are stored in etcd**
- **etcd survives node reboots**
- When K3s restarts, it reads from etcd and recreates resources

## Common Issues and Solutions

### Issue 1: Script Appears to Do Nothing

**Symptom:** Script runs but DNS resolution doesn't work

**Cause:** The script may be reading from an empty or incorrect `/etc/hosts` file

**Solution:** Explicitly provide DNS entries when prompted

```bash
sudo ./k8s-setup/configure-coredns-hosts.sh
# When prompted, enter your DNS entries:
192.168.1.100 hello.lab.allwaysbeginner.com
192.168.1.101 gitea.lab.allwaysbeginner.com
# Press Ctrl+D when done
```

### Issue 2: Changes Not Taking Effect

**Verification Steps:**

1. **Check if CoreDNS ConfigMap was updated:**
```bash
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep hosts
```
Expected output should contain:
```
hosts /etc/coredns/hosts {
    fallthrough
}
```

2. **Check if hosts ConfigMap exists:**
```bash
kubectl get configmap coredns-hosts -n kube-system -o jsonpath='{.data.hosts}'
```
Should show your DNS entries.

3. **Check if volume is mounted:**
```bash
kubectl get deployment coredns -n kube-system -o yaml | grep -A 5 "coredns-hosts"
```
Should show volume and volumeMount configuration.

4. **Check CoreDNS pod logs:**
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```
Look for errors related to hosts file.

### Issue 3: DNS Resolution Still Fails

**Test DNS resolution from inside a pod:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup hello.lab.allwaysbeginner.com
```

**If it fails, check:**

1. **CoreDNS is running:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

2. **CoreDNS service is accessible:**
```bash
kubectl get svc -n kube-system kube-dns
```

3. **Pod DNS configuration:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- cat /etc/resolv.conf
```
Should show `nameserver 10.43.0.10` (or similar cluster DNS IP).

## Manual Configuration Method

If the script doesn't work, configure manually:

### Step 1: Create hosts ConfigMap
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-hosts
  namespace: kube-system
data:
  hosts: |
    192.168.1.100 hello.lab.allwaysbeginner.com
    192.168.1.101 gitea.lab.allwaysbeginner.com
EOF
```

### Step 2: Update CoreDNS ConfigMap
```bash
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        
        # Custom hosts from /etc/hosts
        hosts /etc/coredns/hosts {
            fallthrough
        }
        
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF
```

### Step 3: Patch CoreDNS Deployment
```bash
kubectl patch deployment coredns -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "hosts",
      "configMap": {
        "name": "coredns-hosts",
        "items": [{"key": "hosts", "path": "hosts"}]
      }
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {
      "name": "hosts",
      "mountPath": "/etc/coredns/hosts",
      "subPath": "hosts",
      "readOnly": true
    }
  }
]'
```

### Step 4: Restart CoreDNS
```bash
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system
```

## Updating DNS Entries

To add or modify DNS entries after initial configuration:

### Method 1: Edit ConfigMap directly
```bash
kubectl edit configmap coredns-hosts -n kube-system
# Add/modify entries in the 'hosts' data field
# Save and exit

# Restart CoreDNS to pick up changes
kubectl rollout restart deployment coredns -n kube-system
```

### Method 2: Replace ConfigMap
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-hosts
  namespace: kube-system
data:
  hosts: |
    192.168.1.100 hello.lab.allwaysbeginner.com
    192.168.1.101 gitea.lab.allwaysbeginner.com
    192.168.1.102 registry.lab.allwaysbeginner.com
EOF

kubectl rollout restart deployment coredns -n kube-system
```

## Persistence Verification

To verify changes persist after reboot:

1. **Before reboot:**
```bash
kubectl get configmap coredns-hosts -n kube-system -o yaml > /tmp/before-reboot.yaml
```

2. **Reboot the node:**
```bash
sudo reboot
```

3. **After reboot:**
```bash
kubectl get configmap coredns-hosts -n kube-system -o yaml > /tmp/after-reboot.yaml
diff /tmp/before-reboot.yaml /tmp/after-reboot.yaml
```
Should show no differences (except timestamps).

4. **Test DNS resolution:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup hello.lab.allwaysbeginner.com
```

## Troubleshooting Checklist

- [ ] CoreDNS ConfigMap contains `hosts /etc/coredns/hosts` plugin
- [ ] coredns-hosts ConfigMap exists with correct entries
- [ ] CoreDNS deployment has volume and volumeMount for hosts file
- [ ] CoreDNS pods are running (not CrashLoopBackOff)
- [ ] CoreDNS logs show no errors
- [ ] DNS resolution works from inside pods
- [ ] Changes persist after node reboot

## Restoration

If something goes wrong, restore from backup:

```bash
# The script creates backups in /tmp/
ls -lt /tmp/coredns-backup-*.yaml | head -1

# Restore ConfigMap
kubectl apply -f /tmp/coredns-backup-YYYYMMDD-HHMMSS.yaml

# Restore Deployment
kubectl apply -f /tmp/coredns-deployment-backup-YYYYMMDD-HHMMSS.yaml

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

Or use the restore script:
```bash
./k8s-setup/restore-coredns-backup.sh /tmp/coredns-backup-YYYYMMDD-HHMMSS.yaml
```

## Best Practices

1. **Always backup before changes:**
   - The script automatically creates backups
   - Keep backups in a safe location

2. **Test DNS resolution after changes:**
   - Use `nslookup` from inside a pod
   - Verify all configured hostnames resolve

3. **Monitor CoreDNS logs:**
   - Check for errors after configuration changes
   - Watch for DNS query patterns

4. **Document your DNS entries:**
   - Keep a list of all custom DNS entries
   - Include purpose and owner information

5. **Use version control:**
   - Store ConfigMap YAML files in git
   - Track changes over time

## Summary

✅ **The script DOES change CoreDNS** - it updates ConfigMaps and Deployment
✅ **Changes ARE persistent** - stored in Kubernetes etcd database
⚠️ **Potential issue** - script may read empty /etc/hosts if not populated
💡 **Solution** - Explicitly provide DNS entries when prompted by the script