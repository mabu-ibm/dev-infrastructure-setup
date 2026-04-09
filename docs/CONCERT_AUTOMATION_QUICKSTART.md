# Concert-Bob Automation Quick Start

## 🚀 Schnellstart: Automatisierte Sicherheits-Feedback-Schleife

Diese Anleitung zeigt, wie Sie die automatisierte Concert-Bob Integration in 5 Minuten einrichten.

## Voraussetzungen

- ✅ IBM Concert Account mit API-Zugang
- ✅ Gitea Repository mit Actions aktiviert
- ✅ IBM Winning Products AI installiert (optional, aber empfohlen)

## Installation

### Schritt 1: IBM Winning Products AI installieren (Optional)

```bash
# Installiere IBM Winning Products AI für erweiterte Funktionen
./scripts/install-ibm-winning-products-ai.sh

# Oder direkt:
curl -fsSL https://w3.ibm.com/software/winning-products-ai/install.sh | bash
```

### Schritt 2: Scripts ausführbar machen

```bash
chmod +x scripts/fetch-concert-vulnerabilities.py
chmod +x scripts/install-ibm-winning-products-ai.sh
chmod +x bob-skill/auto-remediate-concert-vulnerabilities.sh
```

### Schritt 3: Concert API Credentials konfigurieren

```bash
# In Gitea: Repository → Settings → Secrets
# Füge folgende Secrets hinzu:

CONCERT_API_KEY=your_concert_api_key_here
CONCERT_INSTANCE_ID=your_instance_id_here
CONCERT_APP_ID=your_application_id_here
```

### Schritt 4: Workflow aktivieren

```bash
# Kopiere Workflow zu deinem Projekt
cp .gitea/workflows/concert-security-feedback.yaml \
   your-project/.gitea/workflows/

# Commit und push
cd your-project
git add .gitea/workflows/concert-security-feedback.yaml
git commit -m "feat: Add Concert-Bob automation"
git push origin main
```

## 🎯 Verwendung

### Automatischer Modus (Empfohlen)

Der Workflow läuft automatisch:
- ✅ Nach jedem SBOM-Upload
- ✅ Täglich um 2 Uhr morgens
- ✅ Bei manueller Auslösung

**Keine weitere Aktion erforderlich!**

### Manueller Modus

#### 1. Vulnerabilities abrufen

```bash
# Mit Umgebungsvariablen
export CONCERT_API_KEY="your-api-key"
export CONCERT_INSTANCE_ID="your-instance-id"

python3 scripts/fetch-concert-vulnerabilities.py \
  --app-id "your-app-id"

# Output:
# - concert-vulnerabilities.json
# - bob-remediation-prompt.md
```

#### 2. Bob AI Remediation ausführen

```bash
# Automatische Fixes generieren
./bob-skill/auto-remediate-concert-vulnerabilities.sh

# Bob AI wird:
# ✅ Vulnerabilities analysieren
# ✅ Dependencies updaten
# ✅ Fixes committen
# ✅ Branch erstellen
```

#### 3. Pull Request erstellen

```bash
# Push remediation branch
git push origin security/bob-auto-fix-*

# Erstelle PR in Gitea UI
# Review und merge
```

## 📊 Was passiert automatisch?

### 1. Nach Code Push

```
Developer pusht Code
    ↓
CI/CD Build + SBOM
    ↓
Upload zu Concert
    ↓
Concert analysiert
    ↓
Workflow startet automatisch
    ↓
Vulnerabilities abgerufen
    ↓
GitHub Issue erstellt
    ↓
Draft PR erstellt
    ↓
Bob AI benachrichtigt
```

### 2. Bob AI Remediation

```
Bob liest Vulnerability Report
    ↓
Analysiert CVEs
    ↓
Generiert Fixes:
  - requirements.txt updated
  - package.json updated
  - go.mod updated
    ↓
Committed zu Branch
    ↓
PR ready für Review
```

### 3. Developer Review & Merge

```
Developer reviewed Fixes
    ↓
Tests laufen
    ↓
Merge PR
    ↓
CI/CD re-runs
    ↓
Neues SBOM zu Concert
    ↓
Concert verifiziert: ✅ Fixed
```

## 🔔 Benachrichtigungen

### GitHub Issue

Automatisch erstellt bei Critical/High Vulnerabilities:

```markdown
🔒 Security: Vulnerabilities detected by Concert

## Summary
- Total: 15
- 🔴 Critical: 3
- 🟠 High: 5

⚠️ IMMEDIATE ACTION REQUIRED

[Detailed vulnerability list...]
```

### Commit Comment

Auf letztem Commit:

```markdown
## 🔒 Concert Security Scan Results

Vulnerabilities Detected: 15
- 🔴 Critical: 3
- 🟠 High: 5

📄 Detailed Report: Check workflow artifacts
🤖 Bob AI: Issue created for automated remediation
```

### Draft Pull Request

Automatisch erstellt mit:
- Vulnerability Report
- Bob AI Prompt
- Remediation Instructions
- Labels: security, bob-ai, concert

## 📁 Generierte Dateien

```
.bob-workspace/
├── concert-vulnerabilities.json    # Vollständiger Report
├── bob-remediation-prompt.md       # Bob AI Anweisungen
└── remediation-log.md              # Fix History

# Workflow Artifacts (in Gitea Actions)
├── concert-vulnerability-report/
│   ├── concert-vulnerabilities.json
│   └── bob-remediation-prompt.md
```

## 🔧 Konfiguration

### Workflow Schedule ändern

```yaml
# .gitea/workflows/concert-security-feedback.yaml
schedule:
  - cron: '0 */6 * * *'  # Alle 6 Stunden statt täglich
```

### Severity Threshold anpassen

```yaml
# Nur bei Critical Vulnerabilities reagieren
if: steps.check_critical.outputs.critical > 0
```

### Slack Notifications hinzufügen

```yaml
- name: Send Slack notification
  if: steps.check_critical.outputs.action_required == 'true'
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
      -H 'Content-Type: application/json' \
      -d '{"text":"🚨 Security Alert: Critical vulnerabilities found"}'
```

## 📈 Monitoring

### Workflow Status prüfen

```bash
# In Gitea UI
Repository → Actions → Workflows → concert-security-feedback

# Zeige letzte Runs
# Zeige Artifacts
# Zeige Logs
```

### Vulnerability Trends

```bash
# Zeige alle Security Fixes
git log --all --grep="Concert" --oneline

# Count Fixed CVEs
git log --all --grep="CVE-" | grep -c "CVE-"

# Zeige Remediation History
cat .bob-workspace/remediation-log.md
```

## 🐛 Troubleshooting

### Problem: Workflow läuft nicht

```bash
# Check Secrets
# Gitea: Repository → Settings → Secrets
# Verify: CONCERT_API_KEY, CONCERT_INSTANCE_ID, CONCERT_APP_ID

# Trigger manuell
# Gitea: Actions → concert-security-feedback → Run workflow
```

### Problem: Keine Vulnerabilities gefunden

```bash
# Test Concert API Connection
curl -H "C_API_KEY: $CONCERT_API_KEY" \
     -H "InstanceID: $CONCERT_INSTANCE_ID" \
     https://91431.us-south-8.concert.saas.ibm.com/core/api/v1/applications

# Check Application ID
python3 scripts/fetch-concert-vulnerabilities.py \
  --app-id "$CONCERT_APP_ID"
```

### Problem: Bob AI erstellt keine Fixes

```bash
# Check Vulnerability Report
cat .bob-workspace/concert-vulnerabilities.json | jq '.summary'

# Run Bob Script manuell mit Debug
bash -x ./bob-skill/auto-remediate-concert-vulnerabilities.sh

# Check Dependency Files
ls -la requirements.txt package.json go.mod
```

## 📚 Weitere Dokumentation

- **Vollständige Anleitung**: [CONCERT_BOB_AUTOMATION.md](CONCERT_BOB_AUTOMATION.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **SBOM Guide**: [SBOM_GENERATION_GUIDE.md](SBOM_GENERATION_GUIDE.md)

## 🎓 Beispiel-Workflow

### Komplettes Beispiel: Python Projekt

```bash
# 1. Setup
cd my-python-app
cp ../dev-infrastructure-setup/.gitea/workflows/concert-security-feedback.yaml \
   .gitea/workflows/

# 2. Configure Secrets in Gitea
# CONCERT_API_KEY, CONCERT_INSTANCE_ID, CONCERT_APP_ID

# 3. Push Code
git add .
git commit -m "feat: Add new feature"
git push origin main

# 4. Warte auf Workflow (automatisch)
# - Build läuft
# - SBOM generiert
# - Upload zu Concert
# - Vulnerabilities abgerufen
# - Issue erstellt
# - PR erstellt

# 5. Bob AI Remediation (automatisch)
# - Liest Vulnerability Report
# - Updated requirements.txt
# - Committed Fixes

# 6. Review & Merge
# - Check PR in Gitea
# - Review Fixes
# - Run Tests
# - Merge PR

# 7. Verify
# - CI/CD re-runs
# - Neues SBOM zu Concert
# - Concert bestätigt: ✅ Fixed
```

## ✅ Checkliste

- [ ] IBM Winning Products AI installiert
- [ ] Scripts ausführbar gemacht
- [ ] Concert API Credentials konfiguriert
- [ ] Workflow zu Projekt kopiert
- [ ] Ersten Test durchgeführt
- [ ] Benachrichtigungen funktionieren
- [ ] Bob AI Remediation getestet
- [ ] Dokumentation gelesen

## 🎉 Fertig!

Ihre automatisierte Concert-Bob Sicherheits-Feedback-Schleife ist jetzt aktiv!

**Nächste Schritte:**
1. Push Code und beobachte den automatischen Workflow
2. Review Bob's automatische Fixes
3. Merge Security PRs
4. Monitor Concert Dashboard

---

**Powered by IBM Concert & Bob AI**