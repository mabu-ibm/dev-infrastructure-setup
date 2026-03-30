# SBOM Generation and Concert Integration Guide

## Overview

This guide explains how to generate Software Bill of Materials (SBOM) for your applications. SBOMs are **always generated** during the build process and can be **optionally uploaded** to IBM Concert for vulnerability tracking and compliance monitoring when Concert is configured.

## Table of Contents

- [What is SBOM?](#what-is-sbom)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage Methods](#usage-methods)
- [CI/CD Integration](#cicd-integration)
- [Concert Integration](#concert-integration)
- [Troubleshooting](#troubleshooting)

## What is SBOM?

A Software Bill of Materials (SBOM) is a comprehensive inventory of all components, libraries, and dependencies in your application. It helps with:

- **Security**: Track vulnerabilities in dependencies
- **Compliance**: Meet regulatory requirements
- **Supply Chain**: Understand your software supply chain
- **Risk Management**: Identify and mitigate security risks

## Quick Start

### 1. Generate SBOM Locally

```bash
# Generate SBOM from Docker image
./scripts/generate-sbom.sh my-app:latest

# Generate SBOM from source code
./scripts/generate-sbom.sh

# Generate and upload to Concert
./scripts/generate-sbom.sh my-app:latest --upload
```

### 2. View SBOM

```bash
# Pretty print SBOM
cat sbom/sbom-*.json | jq .

# Count packages
cat sbom/sbom-*.json | jq '.packages | length'

# List package names
cat sbom/sbom-*.json | jq '.packages[].name'
```

## Configuration

### Environment Variables

Add to your `~/.dev-infrastructure.env`:

```bash
# IBM Concert Configuration
export CONCERT_URL="https://YOUR_INSTANCE.concert.saas.ibm.com"
export CONCERT_API_KEY="YOUR_CONCERT_API_KEY"
export CONCERT_INSTANCE_ID="YOUR_INSTANCE_ID"
export CONCERT_APPLICATION_ID="YOUR_APPLICATION_ID"  # Optional

# SBOM Configuration
export SBOM_ENABLED="true"
export SBOM_FORMAT="spdx-json"  # Options: spdx-json, cyclonedx-json, syft-json
```

### Getting Concert Credentials

1. **Concert URL**: Your Concert instance URL (e.g., `https://12345.us-south-8.concert.saas.ibm.com`)
2. **API Key**: Generate in Concert UI → Settings → API Keys
3. **Instance ID**: Found in Concert UI → Settings → Instance Information
4. **Application ID**: Optional, found in Concert UI → Applications → Select App → Copy ID

### Gitea Secrets (for CI/CD - Optional)

**SBOM generation happens automatically on every build.** To enable Concert upload, add these secrets to your Gitea repository:

```bash
# Navigate to: Repository → Settings → Secrets

CONCERT_URL=https://YOUR_INSTANCE.concert.saas.ibm.com
CONCERT_API_KEY=your_api_key_here
CONCERT_INSTANCE_ID=your_instance_id
CONCERT_APPLICATION_ID=your_app_id  # Optional
```

**Note**: If `CONCERT_URL` secret is not set, SBOM will still be generated but won't be uploaded to Concert.

## Usage Methods

### Method 1: Standalone Script

Generate SBOM using the standalone script:

```bash
# Install Syft (first time only)
# macOS
brew install syft

# Linux
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generate SBOM from Docker image
./scripts/generate-sbom.sh myapp:latest

# Generate SBOM from current directory
./scripts/generate-sbom.sh

# Upload to Concert
./scripts/generate-sbom.sh myapp:latest --upload
```

### Method 2: Python Upload Script

Upload existing SBOM to Concert:

```bash
# Install dependencies
pip install requests

# Upload SBOM
python scripts/upload-sbom-to-concert.py sbom.json

# Upload with application context
python scripts/upload-sbom-to-concert.py sbom.json --application-id app-123
```

### Method 3: Docker Build with SBOM

Build Docker image with embedded SBOM:

```bash
# Use Dockerfile.sbom
docker build -f Dockerfile.sbom -t myapp:latest .

# Extract SBOM from image
docker run --rm myapp:latest cat /app/sbom.json > sbom.json

# Upload to Concert
python scripts/upload-sbom-to-concert.py sbom.json
```

### Method 4: CI/CD Pipeline

Automatic SBOM generation on every build:

```yaml
# Use .gitea/workflows/build-with-sbom.yaml
# SBOM is automatically generated and uploaded when:
# - Code is pushed to main branch
# - CONCERT_ENABLED variable is set to 'true'
# - Concert credentials are configured
```

## CI/CD Integration

### Gitea Actions Workflow

The `build-with-sbom.yaml` workflow:

1. **Builds** Docker image
2. **Generates** SBOM using Syft (always)
3. **Uploads** SBOM to Concert (only if `CONCERT_URL` secret is set)
4. **Stores** SBOM as artifact (90-day retention, always)

```yaml
# .gitea/workflows/build-with-sbom.yaml
name: Build with SBOM

on:
  push:
    branches: [main]

jobs:
  build:
    steps:
      - name: Build and push
        # ... build steps ...
      
      - name: Generate SBOM (Always)
        run: syft $IMAGE --output spdx-json=sbom.json
      
      - name: Upload to Concert (Optional)
        if: secrets.CONCERT_URL != ''
        run: python scripts/upload-sbom-to-concert.py sbom.json
```

### Enable SBOM in CI/CD

1. **Copy upload script to project**:
   ```bash
   cp scripts/upload-sbom-to-concert.py your-project/scripts/
   ```

2. **Use SBOM workflow**:
   ```bash
   cp project-templates/hello-world-python/.gitea/workflows/build-with-sbom.yaml \
      your-project/.gitea/workflows/
   ```

3. **Configure Concert secrets** in Gitea repository settings (optional)

4. **SBOM generation is automatic** - Concert upload happens only when secrets are configured

## Concert Integration

### What Gets Uploaded

When uploading to Concert, the following information is sent:

- **SBOM Data**: Complete package inventory
- **Format**: SPDX JSON, CycloneDX JSON, or Syft JSON
- **Timestamp**: Generation time
- **Application Context**: Associated application ID (if provided)
- **Build Artifact**: Linked to specific build (if application ID provided)

### Concert Features

Once uploaded, Concert provides:

1. **Vulnerability Scanning**: Automatic CVE detection
2. **Risk Scoring**: Priority-based vulnerability assessment
3. **Compliance Tracking**: Regulatory compliance monitoring
4. **Dependency Analysis**: Component relationship mapping
5. **Trend Analysis**: Historical vulnerability trends
6. **Alerting**: Notifications for new vulnerabilities

### Viewing SBOMs in Concert

1. Navigate to **Applications** → Select your application
2. Go to **Build Artifacts** tab
3. Select a build artifact
4. View **SBOM** and **Vulnerabilities** tabs

## SBOM Formats

### SPDX JSON (Recommended)

```json
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "myapp",
  "packages": [
    {
      "SPDXID": "SPDXRef-Package-flask",
      "name": "flask",
      "versionInfo": "3.0.0",
      "licenseConcluded": "BSD-3-Clause"
    }
  ]
}
```

### CycloneDX JSON

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "components": [
    {
      "type": "library",
      "name": "flask",
      "version": "3.0.0",
      "purl": "pkg:pypi/flask@3.0.0"
    }
  ]
}
```

## Troubleshooting

### Syft Not Found

```bash
# macOS
brew install syft

# Linux
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Verify installation
syft version
```

### Concert Upload Fails

**Check credentials**:
```bash
# Verify environment variables
echo $CONCERT_URL
echo $CONCERT_API_KEY
echo $CONCERT_INSTANCE_ID

# Test API connectivity
curl -H "C_API_KEY: $CONCERT_API_KEY" \
     -H "InstanceID: $CONCERT_INSTANCE_ID" \
     "$CONCERT_URL/core/api/v1/applications"
```

**Common issues**:
- Invalid API key → Regenerate in Concert UI
- Wrong instance ID → Check Concert settings
- Network issues → Verify firewall/proxy settings
- Missing application ID → Provide via `--application-id` flag

### SBOM Generation Fails

**Docker image not found**:
```bash
# Pull image first
docker pull myapp:latest

# Or build locally
docker build -t myapp:latest .

# Then generate SBOM
./scripts/generate-sbom.sh myapp:latest
```

**Permission denied**:
```bash
# Make scripts executable
chmod +x scripts/generate-sbom.sh
chmod +x scripts/upload-sbom-to-concert.py
```

### CI/CD Pipeline Issues

**Secrets not available**:
1. Check repository settings → Secrets
2. Verify secret names match workflow
3. Ensure secrets are not expired

**CONCERT_ENABLED not working**:
1. Check repository settings → Variables
2. Set `CONCERT_ENABLED=true`
3. Restart workflow

**Python dependencies missing**:
```yaml
# Add to workflow before upload step
- name: Install dependencies
  run: pip install requests
```

## Best Practices

### 1. Generate SBOM for Every Build

```yaml
# Always generate SBOM in CI/CD
- name: Generate SBOM
  run: syft $IMAGE --output spdx-json=sbom.json
```

### 2. Store SBOMs as Artifacts

```yaml
# Keep SBOMs for audit trail
- name: Upload SBOM artifacts
  uses: actions/upload-artifact@v4
  with:
    name: sbom-files
    retention-days: 90
```

### 3. Version Your SBOMs

```bash
# Include version/commit in filename
SBOM_FILE="sbom-${APP_NAME}-${VERSION}-${COMMIT_SHA}.json"
```

### 4. Automate Concert Upload

```bash
# Upload automatically in CI/CD when configured
if [ "$CONCERT_ENABLED" == "true" ]; then
  python scripts/upload-sbom-to-concert.py sbom.json
fi
```

### 5. Monitor SBOM Changes

```bash
# Compare SBOMs between versions
diff sbom-v1.json sbom-v2.json | grep "name"
```

## Advanced Usage

### Custom SBOM Formats

```bash
# Generate multiple formats
syft myapp:latest \
  --output spdx-json=sbom-spdx.json \
  --output cyclonedx-json=sbom-cyclonedx.json \
  --output syft-json=sbom-syft.json
```

### Filter SBOM by Package Type

```bash
# Only Python packages
syft myapp:latest --scope all-layers \
  --output spdx-json=sbom.json \
  | jq '.packages[] | select(.name | contains("python"))'
```

### SBOM Diff Between Versions

```bash
# Generate SBOMs for two versions
syft myapp:v1.0 --output json=sbom-v1.json
syft myapp:v2.0 --output json=sbom-v2.json

# Compare packages
diff <(jq -r '.artifacts[].name' sbom-v1.json | sort) \
     <(jq -r '.artifacts[].name' sbom-v2.json | sort)
```

### Scheduled SBOM Generation

```bash
# Add to crontab for daily SBOM generation
0 2 * * * cd /path/to/project && ./scripts/generate-sbom.sh myapp:latest --upload
```

## Resources

- **Syft Documentation**: https://github.com/anchore/syft
- **SPDX Specification**: https://spdx.dev/
- **CycloneDX Specification**: https://cyclonedx.org/
- **IBM Concert Documentation**: https://www.ibm.com/docs/concert
- **SBOM Best Practices**: https://www.cisa.gov/sbom

## Support

For issues or questions:

1. Check this documentation
2. Review troubleshooting section
3. Check Syft GitHub issues
4. Contact IBM Concert support
5. Review project README and other docs

---

**Last Updated**: 2026-03-30  
**Version**: 1.0.0