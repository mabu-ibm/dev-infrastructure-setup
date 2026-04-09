# Concert-Bob Automatisierte Sicherheits-Feedback-Schleife

## Übersicht

Dieses Dokument beschreibt, wie IBM Concert-Ergebnisse automatisch an Bob AI zurückgegeben werden, damit Bob den Code automatisch reparieren kann.

## 🔄 Automatisierter Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│           Automatisierte Sicherheits-Feedback-Schleife          │
└─────────────────────────────────────────────────────────────────┘

1. Developer pusht Code
   └─> Gitea Repository
       │
       ▼
2. CI/CD Pipeline startet
   ├─> Build Docker Image
   ├─> Generate SBOM (Syft)
   └─> Upload SBOM zu Concert
       │
       ▼
3. Concert analysiert SBOM
   ├─> Scannt nach Vulnerabilities
   ├─> Berechnet Risk Scores
   └─> Generiert Remediation-Empfehlungen
       │
       ▼
4. Automatischer Abruf (Gitea Actions)
   ├─> fetch-concert-vulnerabilities.py
   ├─> Erstellt Vulnerability Report (JSON)
   └─> Generiert Bob AI Prompt (Markdown)
       │
       ▼
5. Automatische Benachrichtigung
   ├─> GitHub Issue erstellt
   ├─> Commit Comment hinzugefügt
   └─> Pull Request Draft erstellt
       │
       ▼
6. Bob AI Remediation
   ├─> Liest Vulnerability Report
   ├─> Analysiert CVEs und Risk Scores
   ├─> Generiert Fixes automatisch
   │   ├─> Update Dependencies (requirements.txt, package.json, go.mod)
   │   ├─> Apply Code Patches
   │   └─> Update Configurations
   └─> Committed Fixes zu Branch
       │
       ▼
7. Pull Request für Review
   ├─> Developer reviewed Fixes
   ├─> Tests laufen automatisch
   └─> Merge nach Approval
       │
       ▼
8. CI/CD re-runs
   ├─> Build mit Fixes
   ├─> Generate neues SBOM
   └─> Upload zu Concert
       │
       ▼
9. Concert verifiziert
   └─> Bestätigt: Vulnerabilities behoben ✅
```

## 📦 Komponenten

### 1. Python Script: `fetch-concert-vulnerabilities.py`

**Zweck**: Ruft Vulnerability-Daten von Concert API ab

**Features**:
- Verbindet zu Concert API mit Credentials
- Ruft alle Vulnerabilities für eine Application ab
- Kategorisiert nach Severity (Critical, High, Medium, Low)
- Holt detaillierte CVE Assessments
- Generiert strukturierten Report (JSON)
- Erstellt Bob AI Prompt (Markdown)

**Verwendung**:
```bash
# Manuell ausführen
python3 scripts/fetch-concert-vulnerabilities.py \
  --app-id "your-app-id" \
  --api-key "your-api-key" \
  --instance-id "your-instance-id" \
  --output concert-vulnerabilities.json \
  --bob-prompt bob-remediation-prompt.md

# Mit Umgebungsvariablen
export CONCERT_API_KEY="your-api-key"
export CONCERT_INSTANCE_ID="your-instance-id"

python3 scripts/fetch-concert-vulnerabilities.py \
  --app-id "your-app-id"
```

**Output**:
- `concert-vulnerabilities.json`: Vollständiger Vulnerability Report
- `bob-remediation-prompt.md`: Prompt für Bob AI mit Remediation-Anweisungen

### 2. Gitea Actions Workflow: `concert-security-feedback.yaml`

**Zweck**: Automatisiert den Abruf und die Benachrichtigung

**Trigger**:
- Nach jedem SBOM-Upload (workflow_run)
- Täglich um 2 Uhr morgens (schedule)
- Manuell (workflow_dispatch)

**Jobs**:

#### Job 1: `fetch-vulnerabilities`
1. Checkout Code
2. Setup Python
3. Fetch Vulnerabilities von Concert
4. Check für Critical/High Vulnerabilities
5. Upload Report als Artifact
6. Erstelle GitHub Issue für Bob AI
7. Kommentiere auf letztem Commit
8. Sende Benachrichtigung (optional)

#### Job 2: `trigger-bob-remediation`
1. Download Vulnerability Report
2. Setup Bob AI Environment
3. Erstelle Remediation Branch
4. Push Branch zu Repository
5. Erstelle Draft Pull Request
6. Füge Labels hinzu (security, bob-ai, concert)

**Konfiguration in Gitea**:
```bash
# Secrets in Gitea Repository Settings hinzufügen:
CONCERT_API_KEY=your_concert_api_key
CONCERT_INSTANCE_ID=your_instance_id
CONCERT_APP_ID=your_application_id
```

### 3. Bob AI Skill: `auto-remediate-concert-vulnerabilities.sh`

**Zweck**: Automatische Remediation von Vulnerabilities

**Features**:
- Liest Vulnerability Report (JSON)
- Analysiert Critical und High Vulnerabilities
- Erkennt Projekt-Typ (Python, Node.js, Go)
- Updated Dependencies automatisch
- Erstellt Remediation Log
- Committed Fixes zu Branch

**Unterstützte Dependency-Updates**:
- **Python**: `requirements.txt`
- **Node.js**: `package.json`
- **Go**: `go.mod`

**Verwendung**:
```bash
# Automatisch durch Gitea Actions
# Oder manuell:
./bob-skill/auto-remediate-concert-vulnerabilities.sh \
  .bob-workspace/concert-vulnerabilities.json \
  .bob-workspace/bob-remediation-prompt.md
```

**Output**:
- Updated dependency files
- `.bob-workspace/remediation-log.md`: Detailliertes Log aller Fixes
- Git commit mit allen Änderungen

## 🚀 Setup-Anleitung

### Schritt 1: Concert API Credentials konfigurieren

```bash
# In Gitea Repository Settings → Secrets
CONCERT_API_KEY=your_api_key_here
CONCERT_INSTANCE_ID=your_instance_id_here
CONCERT_APP_ID=your_application_id_here
```

### Schritt 2: Workflow-Dateien hinzufügen

```bash
# Kopiere Workflow zu deinem Projekt
cp .gitea/workflows/concert-security-feedback.yaml \
   your-project/.gitea/workflows/

# Kopiere Scripts
cp scripts/fetch-concert-vulnerabilities.py \
   your-project/scripts/

cp bob-skill/auto-remediate-concert-vulnerabilities.sh \
   your-project/bob-skill/
```

### Schritt 3: Executable Permissions setzen

```bash
chmod +x scripts/fetch-concert-vulnerabilities.py
chmod +x bob-skill/auto-remediate-concert-vulnerabilities.sh
```

### Schritt 4: Ersten Test durchführen

```bash
# Manuell Vulnerabilities abrufen
python3 scripts/fetch-concert-vulnerabilities.py \
  --app-id "$CONCERT_APP_ID"

# Bob AI Remediation testen
./bob-skill/auto-remediate-concert-vulnerabilities.sh
```

## 📋 Workflow-Beispiel

### Szenario: Neue Vulnerability entdeckt

1. **Tag 1, 10:00**: Developer pusht Code
   ```bash
   git add .
   git commit -m "feat: Add new feature"
   git push origin main
   ```

2. **Tag 1, 10:05**: CI/CD Pipeline läuft
   - Build Docker Image
   - Generate SBOM
   - Upload zu Concert

3. **Tag 1, 10:10**: Concert analysiert SBOM
   - Findet 3 Critical CVEs
   - Berechnet Risk Scores
   - Generiert Remediation-Empfehlungen

4. **Tag 1, 10:15**: Automatischer Abruf startet
   - `fetch-concert-vulnerabilities.py` läuft
   - Erstellt Vulnerability Report
   - Generiert Bob AI Prompt

5. **Tag 1, 10:20**: Benachrichtigungen
   - GitHub Issue erstellt: "🔒 Security: 3 Critical Vulnerabilities"
   - Commit Comment: "⚠️ IMMEDIATE ACTION REQUIRED"
   - Draft PR erstellt: "security/concert-auto-fix-20260331-1020"

6. **Tag 1, 10:25**: Bob AI Remediation
   - Liest Vulnerability Report
   - Updated `requirements.txt`:
     ```diff
     - flask==2.0.1  # CVE-2024-XXXXX (Risk: 9.5)
     + flask==2.3.2  # Fixed CVE-2024-XXXXX
     ```
   - Committed Fixes zu Branch

7. **Tag 1, 11:00**: Developer Review
   - Reviewed Bob's Fixes
   - Runs Tests lokal
   - Approved Pull Request

8. **Tag 1, 11:30**: Merge und Verify
   - PR merged zu main
   - CI/CD re-runs
   - Neues SBOM zu Concert
   - Concert bestätigt: ✅ Alle CVEs behoben

## 🔧 Konfigurationsoptionen

### Environment Variables

```bash
# Concert API
CONCERT_API_KEY=your_api_key
CONCERT_INSTANCE_ID=your_instance_id
CONCERT_APP_ID=your_application_id
CONCERT_BASE_URL=https://91431.us-south-8.concert.saas.ibm.com

# Workflow Optionen
CONCERT_SCAN_SCHEDULE="0 2 * * *"  # Daily at 2 AM
CONCERT_AUTO_REMEDIATE=true         # Enable auto-remediation
CONCERT_CREATE_ISSUES=true          # Create GitHub issues
CONCERT_NOTIFY_SLACK=false          # Slack notifications (optional)
```

### Workflow Customization

```yaml
# .gitea/workflows/concert-security-feedback.yaml

# Ändere Schedule
schedule:
  - cron: '0 */6 * * *'  # Every 6 hours

# Ändere Severity Threshold
if: steps.check_critical.outputs.critical > 0 || steps.check_critical.outputs.high > 5

# Füge Slack Notification hinzu
- name: Send Slack notification
  if: steps.check_critical.outputs.action_required == 'true'
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "🚨 Security Alert: ${{ steps.check_critical.outputs.critical }} critical vulnerabilities"
      }
```

## 📊 Monitoring und Reporting

### Vulnerability Trends

```bash
# Zeige Vulnerability History
git log --all --grep="Concert" --oneline

# Zeige alle Security Fixes
git log --all --grep="fix: Apply automated security fixes" --oneline

# Count Fixed CVEs
git log --all --grep="CVE-" | grep -c "CVE-"
```

### Dashboard Metriken

- **Total Vulnerabilities**: Anzahl aller gefundenen CVEs
- **Critical/High**: Anzahl kritischer Vulnerabilities
- **Fixes Applied**: Anzahl automatisch behobener CVEs
- **Manual Review Required**: Anzahl CVEs die manuelle Intervention brauchen
- **Average Fix Time**: Durchschnittliche Zeit von Detection bis Fix
- **Fix Success Rate**: Prozentsatz erfolgreich behobener CVEs

## 🔐 Sicherheits-Best-Practices

### 1. API Key Management
- ✅ Speichere API Keys nur in Gitea Secrets
- ✅ Rotiere Keys regelmäßig (alle 90 Tage)
- ✅ Verwende separate Keys für Dev/Prod
- ❌ Committe niemals API Keys zu Git

### 2. Automated Remediation
- ✅ Teste Fixes in Staging vor Production
- ✅ Review Bob's Fixes vor Merge
- ✅ Run Tests nach jedem Fix
- ❌ Merge nicht blind ohne Review

### 3. Vulnerability Response
- ✅ Critical CVEs: Fix innerhalb 24 Stunden
- ✅ High CVEs: Fix innerhalb 7 Tagen
- ✅ Medium CVEs: Fix innerhalb 30 Tagen
- ✅ Dokumentiere alle Fixes

### 4. Monitoring
- ✅ Check Concert Dashboard täglich
- ✅ Review Vulnerability Reports wöchentlich
- ✅ Audit Security Fixes monatlich
- ✅ Update Security Policies quartalsweise

## 🐛 Troubleshooting

### Problem: Script findet keine Vulnerabilities

```bash
# Check Concert API Connection
curl -H "C_API_KEY: $CONCERT_API_KEY" \
     -H "InstanceID: $CONCERT_INSTANCE_ID" \
     https://91431.us-south-8.concert.saas.ibm.com/core/api/v1/applications

# Check Application ID
python3 scripts/fetch-concert-vulnerabilities.py \
  --app-id "wrong-id"  # Should show error
```

### Problem: Bob AI erstellt keine Fixes

```bash
# Check Vulnerability Report
cat .bob-workspace/concert-vulnerabilities.json | jq '.summary'

# Check Bob Prompt
cat .bob-workspace/bob-remediation-prompt.md

# Run Bob Script manuell
./bob-skill/auto-remediate-concert-vulnerabilities.sh
```

### Problem: Workflow läuft nicht automatisch

```bash
# Check Gitea Actions Status
# In Gitea UI: Repository → Actions → Workflows

# Check Secrets
# In Gitea UI: Repository → Settings → Secrets

# Trigger manuell
# In Gitea UI: Actions → concert-security-feedback → Run workflow
```

## 📚 Weitere Ressourcen

- [Concert API Documentation](https://www.ibm.com/docs/concert)
- [SBOM Generation Guide](SBOM_GENERATION_GUIDE.md)
- [Architecture Overview](ARCHITECTURE.md)
- [Security Hardening Guide](SECURITY_HARDENING_GUIDE.md)

## 🤝 Support

Bei Fragen oder Problemen:
1. Check diese Dokumentation
2. Review Workflow Logs in Gitea Actions
3. Check Concert Dashboard für API Status
4. Erstelle Issue im Repository

---

**Erstellt von Bob AI** - Automatisierte Sicherheits-Feedback-Schleife
**Powered by IBM Concert**