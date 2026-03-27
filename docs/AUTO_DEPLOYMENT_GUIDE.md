# Automatisches Deployment bei neuem Docker Image

Anleitung für automatische Pod-Updates wenn ein neues Docker Image über Gitea Actions gebaut wurde.

## Übersicht

Es gibt mehrere Strategien, um Pods automatisch neu zu starten wenn ein neues Image verfügbar ist:

1. **Image Tag mit Commit SHA** (Empfohlen für Produktion)
2. **kubectl rollout restart** (Einfachste Lösung)
3. **ImagePullPolicy: Always** (Für Development)
4. **Webhook-basiertes Deployment** (Fortgeschritten)

## Strategie 1: Image Tag mit Commit SHA (Empfohlen)

### Vorteile
- ✅ Jedes Build hat eindeutigen Tag
- ✅ Rollback möglich
- ✅ Nachvollziehbare Deployments
- ✅ Keine Race Conditions

### Gitea Workflow

`.gitea/workflows/build-and-deploy.yaml`:
```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set image tag
        id: vars
        run: |
          echo "IMAGE_TAG=${GITHUB_SHA:0:7}" >> $GITHUB_OUTPUT
          echo "IMAGE_NAME=almabuild:3000/${{ github.repository }}" >> $GITHUB_OUTPUT
      
      - name: Build Docker image
        run: |
          docker build -t ${{ steps.vars.outputs.IMAGE_NAME }}:${{ steps.vars.outputs.IMAGE_TAG }} .
          docker tag ${{ steps.vars.outputs.IMAGE_NAME }}:${{ steps.vars.outputs.IMAGE_TAG }} \
                     ${{ steps.vars.outputs.IMAGE_NAME }}:latest
      
      - name: Login to Gitea Registry
        run: |
          echo "${{ secrets.GITEA_PASSWORD }}" | docker login almabuild:3000 \
            -u "${{ secrets.GITEA_USERNAME }}" --password-stdin
      
      - name: Push images
        run: |
          docker push ${{ steps.vars.outputs.IMAGE_NAME }}:${{ steps.vars.outputs.IMAGE_TAG }}
          docker push ${{ steps.vars.outputs.IMAGE_NAME }}:latest
      
      - name: Deploy to K3s
        run: |
          # Install kubectl if not available
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          
          # Configure kubectl (kubeconfig als Secret hinterlegen)
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config
          
          # Update deployment with new image
          ./kubectl set image deployment/my-app \
            my-app=${{ steps.vars.outputs.IMAGE_NAME }}:${{ steps.vars.outputs.IMAGE_TAG }} \
            -n default
          
          # Wait for rollout
          ./kubectl rollout status deployment/my-app -n default
```

### Secrets in Gitea einrichten

1. Gehe zu Repository → Settings → Secrets
2. Füge folgende Secrets hinzu:
   - `GITEA_USERNAME`: Dein Gitea Username
   - `GITEA_PASSWORD`: Dein Gitea Password oder Token
   - `KUBECONFIG`: Inhalt von `/etc/rancher/k3s/k3s.yaml` (von almak3s)

### Kubeconfig für Remote-Zugriff vorbereiten

Auf almak3s:
```bash
# Kubeconfig kopieren und Server-URL anpassen
sudo cat /etc/rancher/k3s/k3s.yaml | \
  sed 's/127.0.0.1/almak3s/g' > kubeconfig-remote.yaml

# Inhalt anzeigen (für Secret)
cat kubeconfig-remote.yaml
```

## Strategie 2: kubectl rollout restart (Einfachste Lösung)

### Vorteile
- ✅ Sehr einfach
- ✅ Funktioniert mit `latest` Tag
- ✅ Keine Änderung am Deployment nötig

### Nachteile
- ⚠️ Kein Rollback möglich
- ⚠️ Nicht nachvollziehbar welche Version läuft

### Gitea Workflow

`.gitea/workflows/build-and-restart.yaml`:
```yaml
name: Build and Restart
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push image
        run: |
          docker build -t almabuild:3000/${{ github.repository }}:latest .
          echo "${{ secrets.GITEA_PASSWORD }}" | docker login almabuild:3000 \
            -u "${{ secrets.GITEA_USERNAME }}" --password-stdin
          docker push almabuild:3000/${{ github.repository }}:latest
      
      - name: Restart pods on K3s
        run: |
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config
          
          # Restart deployment - zieht automatisch neues Image
          ./kubectl rollout restart deployment/my-app -n default
          ./kubectl rollout status deployment/my-app -n default
```

### K8s Deployment mit imagePullPolicy

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      imagePullSecrets:
      - name: gitea-registry
      containers:
      - name: my-app
        image: almabuild:3000/username/my-app:latest
        imagePullPolicy: Always  # Wichtig!
        ports:
        - containerPort: 8080
```

## Strategie 3: SSH-basiertes Deployment

### Vorteile
- ✅ Keine Kubeconfig in Gitea nötig
- ✅ Sicherer durch SSH-Keys
- ✅ Einfache Einrichtung

### Setup auf almak3s

```bash
# SSH-Key für Gitea Runner erstellen
ssh-keygen -t ed25519 -f ~/.ssh/gitea-deploy -N ""

# Public Key zu authorized_keys hinzufügen
cat ~/.ssh/gitea-deploy.pub >> ~/.ssh/authorized_keys

# Private Key anzeigen (für Gitea Secret)
cat ~/.ssh/gitea-deploy
```

### Gitea Workflow mit SSH

`.gitea/workflows/build-and-deploy-ssh.yaml`:
```yaml
name: Build and Deploy via SSH
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push image
        run: |
          docker build -t almabuild:3000/${{ github.repository }}:latest .
          echo "${{ secrets.GITEA_PASSWORD }}" | docker login almabuild:3000 \
            -u "${{ secrets.GITEA_USERNAME }}" --password-stdin
          docker push almabuild:3000/${{ github.repository }}:latest
      
      - name: Deploy via SSH
        run: |
          # SSH Key einrichten
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          
          # SSH Config
          cat > ~/.ssh/config <<EOF
          Host almak3s
            HostName almak3s
            User your-username
            IdentityFile ~/.ssh/deploy_key
            StrictHostKeyChecking no
          EOF
          
          # Deployment via SSH
          ssh almak3s "kubectl rollout restart deployment/my-app -n default"
          ssh almak3s "kubectl rollout status deployment/my-app -n default"
```

### Secrets einrichten
- `SSH_PRIVATE_KEY`: Inhalt von `~/.ssh/gitea-deploy` (private key)

## Strategie 4: Webhook-basiertes Deployment

### Vorteile
- ✅ Sehr flexibel
- ✅ Kann komplexe Logik enthalten
- ✅ Unabhängig von CI/CD

### Setup: Webhook-Server auf almak3s

Erstelle `/opt/deploy-webhook/webhook.sh`:
```bash
#!/bin/bash
set -e

# Webhook Secret validieren
if [ "$1" != "$WEBHOOK_SECRET" ]; then
    echo "Invalid secret"
    exit 1
fi

DEPLOYMENT_NAME="$2"
NAMESPACE="${3:-default}"

echo "Restarting deployment: $DEPLOYMENT_NAME in namespace: $NAMESPACE"

# Deployment neu starten
kubectl rollout restart deployment/$DEPLOYMENT_NAME -n $NAMESPACE
kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE

echo "Deployment restarted successfully"
```

Erstelle `/etc/systemd/system/deploy-webhook.service`:
```ini
[Unit]
Description=Deployment Webhook Server
After=network.target

[Service]
Type=simple
User=your-username
Environment="WEBHOOK_SECRET=your-secret-here"
ExecStart=/usr/bin/python3 /opt/deploy-webhook/server.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Erstelle `/opt/deploy-webhook/server.py`:
```python
#!/usr/bin/env python3
import os
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'changeme')

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data)
            secret = data.get('secret')
            deployment = data.get('deployment')
            namespace = data.get('namespace', 'default')
            
            if secret != WEBHOOK_SECRET:
                self.send_response(401)
                self.end_headers()
                self.wfile.write(b'Unauthorized')
                return
            
            # Deployment neu starten
            result = subprocess.run(
                ['kubectl', 'rollout', 'restart', 
                 f'deployment/{deployment}', '-n', namespace],
                capture_output=True, text=True
            )
            
            if result.returncode == 0:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'Deployment restarted')
            else:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(result.stderr.encode())
                
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), WebhookHandler)
    print('Webhook server running on port 8080')
    server.serve_forever()
```

Starten:
```bash
sudo chmod +x /opt/deploy-webhook/webhook.sh
sudo chmod +x /opt/deploy-webhook/server.py
sudo systemctl enable deploy-webhook
sudo systemctl start deploy-webhook
```

### Gitea Workflow mit Webhook

```yaml
name: Build and Deploy via Webhook
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push image
        run: |
          docker build -t almabuild:3000/${{ github.repository }}:latest .
          echo "${{ secrets.GITEA_PASSWORD }}" | docker login almabuild:3000 \
            -u "${{ secrets.GITEA_USERNAME }}" --password-stdin
          docker push almabuild:3000/${{ github.repository }}:latest
      
      - name: Trigger deployment
        run: |
          curl -X POST http://almak3s:8080 \
            -H "Content-Type: application/json" \
            -d '{
              "secret": "${{ secrets.WEBHOOK_SECRET }}",
              "deployment": "my-app",
              "namespace": "default"
            }'
```

## Empfohlene Lösung für verschiedene Szenarien

### Development
**Strategie 2 oder 3** - Einfach und schnell
- Verwende `latest` Tag
- `kubectl rollout restart` nach jedem Build
- Schnelle Iteration

### Staging
**Strategie 1** - Mit Commit SHA Tags
- Nachvollziehbare Deployments
- Rollback möglich
- Automatisierte Tests vor Deployment

### Production
**Strategie 1** - Mit Semantic Versioning
- Tags wie `v1.2.3`
- Manuelle Freigabe
- Rollback-Strategie
- Monitoring und Alerts

## Vollständiges Beispiel: Production-Ready Workflow

`.gitea/workflows/production.yaml`:
```yaml
name: Production Deployment
on:
  push:
    tags:
      - 'v*'

jobs:
  build-test-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Extract version
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          echo "VERSION=$VERSION" >> $GITHUB_OUTPUT
          echo "IMAGE=almabuild:3000/${{ github.repository }}" >> $GITHUB_OUTPUT
      
      - name: Build image
        run: |
          docker build -t ${{ steps.version.outputs.IMAGE }}:${{ steps.version.outputs.VERSION }} .
          docker tag ${{ steps.version.outputs.IMAGE }}:${{ steps.version.outputs.VERSION }} \
                     ${{ steps.version.outputs.IMAGE }}:latest
      
      - name: Run tests
        run: |
          docker run --rm ${{ steps.version.outputs.IMAGE }}:${{ steps.version.outputs.VERSION }} \
            npm test
      
      - name: Push images
        run: |
          echo "${{ secrets.GITEA_PASSWORD }}" | docker login almabuild:3000 \
            -u "${{ secrets.GITEA_USERNAME }}" --password-stdin
          docker push ${{ steps.version.outputs.IMAGE }}:${{ steps.version.outputs.VERSION }}
          docker push ${{ steps.version.outputs.IMAGE }}:latest
      
      - name: Deploy to K3s
        run: |
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config
          
          # Update deployment
          ./kubectl set image deployment/my-app \
            my-app=${{ steps.version.outputs.IMAGE }}:${{ steps.version.outputs.VERSION }} \
            -n production
          
          # Wait for rollout
          ./kubectl rollout status deployment/my-app -n production --timeout=5m
          
          # Verify deployment
          ./kubectl get pods -n production -l app=my-app
      
      - name: Notify on failure
        if: failure()
        run: |
          echo "Deployment failed for version ${{ steps.version.outputs.VERSION }}"
          # Hier könnte man Slack/Email Benachrichtigung hinzufügen
```

## Deployment auslösen

```bash
# Development: Push zu main
git push origin main

# Production: Tag erstellen
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Monitoring und Rollback

### Deployment Status prüfen
```bash
kubectl rollout status deployment/my-app
kubectl get pods -l app=my-app
kubectl describe deployment my-app
```

### Rollback durchführen
```bash
# Zum vorherigen Deployment
kubectl rollout undo deployment/my-app

# Zu spezifischer Revision
kubectl rollout history deployment/my-app
kubectl rollout undo deployment/my-app --to-revision=2
```

### Logs anzeigen
```bash
kubectl logs -l app=my-app --tail=100 -f
```

## Troubleshooting

### Image wird nicht aktualisiert
```bash
# Prüfe imagePullPolicy
kubectl get deployment my-app -o yaml | grep imagePullPolicy

# Sollte "Always" sein für latest Tag
kubectl patch deployment my-app -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"my-app","imagePullPolicy":"Always"}]}}}}'
```

### Pods starten nicht
```bash
# Events prüfen
kubectl get events --sort-by='.lastTimestamp'

# Pod Details
kubectl describe pod <pod-name>

# Logs
kubectl logs <pod-name>
```

### Registry Authentication Fehler
```bash
# Secret prüfen
kubectl get secret gitea-registry -o yaml

# Secret neu erstellen
kubectl delete secret gitea-registry
kubectl create secret docker-registry gitea-registry \
  --docker-server=almabuild:3000 \
  --docker-username=username \
  --docker-password=password
```

## Best Practices

1. **Verwende spezifische Tags** statt `latest` in Production
2. **Implementiere Health Checks** in deinen Deployments
3. **Setze Resource Limits** für Pods
4. **Verwende Readiness/Liveness Probes**
5. **Implementiere Rollback-Strategie**
6. **Monitore Deployments** mit Prometheus/Grafana
7. **Teste in Staging** vor Production Deployment
8. **Dokumentiere Deployment-Prozess**
9. **Verwende Secrets** für sensitive Daten
10. **Implementiere Backup-Strategie**

## Zusammenfassung

Die beste Lösung hängt von deinen Anforderungen ab:

- **Schnell & Einfach**: Strategie 2 (rollout restart)
- **Production-Ready**: Strategie 1 (SHA/Version Tags)
- **Sicher**: Strategie 3 (SSH-basiert)
- **Flexibel**: Strategie 4 (Webhook)

Für die meisten Fälle empfehle ich **Strategie 1** mit Commit SHA Tags, da sie die beste Balance zwischen Einfachheit und Production-Readiness bietet.