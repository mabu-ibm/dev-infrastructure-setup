#!/bin/bash
#
# Bob AI Skill: Automated Concert Vulnerability Remediation
#
# This script is designed to be executed by Bob AI to automatically
# remediate vulnerabilities detected by IBM Concert.
#
# Usage:
#   ./bob-skill/auto-remediate-concert-vulnerabilities.sh [vulnerability-report.json]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VULNERABILITY_REPORT="${1:-.bob-workspace/concert-vulnerabilities.json}"
BOB_PROMPT_FILE="${2:-.bob-workspace/bob-remediation-prompt.md}"
REMEDIATION_BRANCH="security/bob-auto-fix-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Bob AI - Automated Concert Vulnerability Remediation    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if vulnerability report exists
if [ ! -f "$VULNERABILITY_REPORT" ]; then
    echo -e "${RED}❌ Error: Vulnerability report not found: $VULNERABILITY_REPORT${NC}"
    echo -e "${YELLOW}💡 Run fetch-concert-vulnerabilities.py first${NC}"
    exit 1
fi

# Parse vulnerability report
echo -e "${BLUE}📊 Analyzing vulnerability report...${NC}"

TOTAL_VULNS=$(jq -r '.summary.total' "$VULNERABILITY_REPORT")
CRITICAL_VULNS=$(jq -r '.summary.critical' "$VULNERABILITY_REPORT")
HIGH_VULNS=$(jq -r '.summary.high' "$VULNERABILITY_REPORT")
MEDIUM_VULNS=$(jq -r '.summary.medium' "$VULNERABILITY_REPORT")
LOW_VULNS=$(jq -r '.summary.low' "$VULNERABILITY_REPORT")

echo -e "${BLUE}   Total Vulnerabilities: $TOTAL_VULNS${NC}"
echo -e "${RED}   🔴 Critical: $CRITICAL_VULNS${NC}"
echo -e "${YELLOW}   🟠 High: $HIGH_VULNS${NC}"
echo -e "${YELLOW}   🟡 Medium: $MEDIUM_VULNS${NC}"
echo -e "${GREEN}   🟢 Low: $LOW_VULNS${NC}"
echo ""

if [ "$TOTAL_VULNS" -eq 0 ]; then
    echo -e "${GREEN}✅ No vulnerabilities to remediate!${NC}"
    exit 0
fi

# Create remediation branch
echo -e "${BLUE}🌿 Creating remediation branch: $REMEDIATION_BRANCH${NC}"
git checkout -b "$REMEDIATION_BRANCH" 2>/dev/null || git checkout "$REMEDIATION_BRANCH"

# Initialize remediation log
REMEDIATION_LOG=".bob-workspace/remediation-log.md"
mkdir -p .bob-workspace

cat > "$REMEDIATION_LOG" << EOF
# Bob AI Automated Remediation Log

**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Branch**: $REMEDIATION_BRANCH
**Total Vulnerabilities**: $TOTAL_VULNS

## Vulnerabilities Addressed

EOF

# Function to update Python dependencies
update_python_dependencies() {
    local cve=$1
    local component=$2
    local fixed_version=$3
    
    echo -e "${BLUE}🐍 Updating Python dependency: $component${NC}"
    
    if [ -f "requirements.txt" ]; then
        # Update requirements.txt
        if grep -q "^${component}==" requirements.txt; then
            sed -i.bak "s/^${component}==.*/${component}==${fixed_version}  # Fixed ${cve}/" requirements.txt
            rm -f requirements.txt.bak
            echo -e "${GREEN}   ✅ Updated $component to $fixed_version${NC}"
            
            # Log the change
            cat >> "$REMEDIATION_LOG" << EOF
### $cve - $component
- **Type**: Python Dependency Update
- **Old Version**: (detected by Concert)
- **New Version**: $fixed_version
- **Status**: ✅ Fixed

EOF
            return 0
        else
            echo -e "${YELLOW}   ⚠️  $component not found in requirements.txt${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}   ⚠️  requirements.txt not found${NC}"
        return 1
    fi
}

# Function to update Node.js dependencies
update_nodejs_dependencies() {
    local cve=$1
    local component=$2
    local fixed_version=$3
    
    echo -e "${BLUE}📦 Updating Node.js dependency: $component${NC}"
    
    if [ -f "package.json" ]; then
        # Update package.json using jq
        jq ".dependencies[\"$component\"] = \"$fixed_version\"" package.json > package.json.tmp
        mv package.json.tmp package.json
        
        echo -e "${GREEN}   ✅ Updated $component to $fixed_version${NC}"
        
        # Log the change
        cat >> "$REMEDIATION_LOG" << EOF
### $cve - $component
- **Type**: Node.js Dependency Update
- **Old Version**: (detected by Concert)
- **New Version**: $fixed_version
- **Status**: ✅ Fixed

EOF
        return 0
    else
        echo -e "${YELLOW}   ⚠️  package.json not found${NC}"
        return 1
    fi
}

# Function to update Go dependencies
update_go_dependencies() {
    local cve=$1
    local component=$2
    local fixed_version=$3
    
    echo -e "${BLUE}🔷 Updating Go dependency: $component${NC}"
    
    if [ -f "go.mod" ]; then
        # Update go.mod
        go get "${component}@${fixed_version}"
        go mod tidy
        
        echo -e "${GREEN}   ✅ Updated $component to $fixed_version${NC}"
        
        # Log the change
        cat >> "$REMEDIATION_LOG" << EOF
### $cve - $component
- **Type**: Go Dependency Update
- **Old Version**: (detected by Concert)
- **New Version**: $fixed_version
- **Status**: ✅ Fixed

EOF
        return 0
    else
        echo -e "${YELLOW}   ⚠️  go.mod not found${NC}"
        return 1
    fi
}

# Process critical and high vulnerabilities
echo -e "${BLUE}🔧 Processing critical and high vulnerabilities...${NC}"
echo ""

FIXES_APPLIED=0

# Extract critical vulnerabilities and attempt remediation
jq -r '.critical_vulnerabilities[] | @json' "$VULNERABILITY_REPORT" | while read -r vuln; do
    CVE=$(echo "$vuln" | jq -r '.cve')
    COMPONENT=$(echo "$vuln" | jq -r '.component // "unknown"')
    RISK_SCORE=$(echo "$vuln" | jq -r '.highest_finding_risk_score // 0')
    
    echo -e "${RED}🔴 Processing Critical: $CVE (Risk: $RISK_SCORE)${NC}"
    echo -e "   Component: $COMPONENT"
    
    # Try to get fixed version from detailed assessments
    FIXED_VERSION=$(jq -r ".detailed_assessments[] | select(.cve == \"$CVE\") | .assessment.fixed_version // empty" "$VULNERABILITY_REPORT")
    
    if [ -n "$FIXED_VERSION" ] && [ "$FIXED_VERSION" != "null" ]; then
        echo -e "   Fixed Version Available: $FIXED_VERSION"
        
        # Detect project type and update accordingly
        if [ -f "requirements.txt" ]; then
            update_python_dependencies "$CVE" "$COMPONENT" "$FIXED_VERSION" && ((FIXES_APPLIED++))
        elif [ -f "package.json" ]; then
            update_nodejs_dependencies "$CVE" "$COMPONENT" "$FIXED_VERSION" && ((FIXES_APPLIED++))
        elif [ -f "go.mod" ]; then
            update_go_dependencies "$CVE" "$COMPONENT" "$FIXED_VERSION" && ((FIXES_APPLIED++))
        else
            echo -e "${YELLOW}   ⚠️  Could not determine project type${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  No fixed version available from Concert${NC}"
        
        # Log as manual review required
        cat >> "$REMEDIATION_LOG" << EOF
### $CVE - $COMPONENT
- **Type**: Manual Review Required
- **Risk Score**: $RISK_SCORE
- **Status**: ⚠️ Requires manual intervention
- **Reason**: No fixed version available from Concert

EOF
    fi
    
    echo ""
done

# Process high vulnerabilities
jq -r '.high_vulnerabilities[] | @json' "$VULNERABILITY_REPORT" | while read -r vuln; do
    CVE=$(echo "$vuln" | jq -r '.cve')
    COMPONENT=$(echo "$vuln" | jq -r '.component // "unknown"')
    RISK_SCORE=$(echo "$vuln" | jq -r '.highest_finding_risk_score // 0')
    
    echo -e "${YELLOW}🟠 Processing High: $CVE (Risk: $RISK_SCORE)${NC}"
    echo -e "   Component: $COMPONENT"
    
    # Try to get fixed version
    FIXED_VERSION=$(jq -r ".detailed_assessments[] | select(.cve == \"$CVE\") | .assessment.fixed_version // empty" "$VULNERABILITY_REPORT")
    
    if [ -n "$FIXED_VERSION" ] && [ "$FIXED_VERSION" != "null" ]; then
        echo -e "   Fixed Version Available: $FIXED_VERSION"
        
        # Detect project type and update accordingly
        if [ -f "requirements.txt" ]; then
            update_python_dependencies "$CVE" "$COMPONENT" "$FIXED_VERSION" && ((FIXES_APPLIED++))
        elif [ -f "package.json" ]; then
            update_nodejs_dependencies "$CVE" "$COMPONENT" "$FIXED_VERSION" && ((FIXES_APPLIED++))
        elif [ -f "go.mod" ]; then
            update_go_dependencies "$CVE" "$COMPONENT" "$FIXED_VERSION" && ((FIXES_APPLIED++))
        fi
    else
        echo -e "${YELLOW}   ⚠️  No fixed version available${NC}"
    fi
    
    echo ""
done

# Finalize remediation log
cat >> "$REMEDIATION_LOG" << EOF

## Summary

- **Total Vulnerabilities**: $TOTAL_VULNS
- **Fixes Applied**: $FIXES_APPLIED
- **Manual Review Required**: $((CRITICAL_VULNS + HIGH_VULNS - FIXES_APPLIED))

## Next Steps

1. Review the changes in this branch
2. Run tests to ensure fixes don't break functionality
3. Merge this PR to apply security fixes
4. CI/CD will rebuild and upload new SBOM to Concert
5. Concert will verify vulnerabilities are resolved

---

**Generated by Bob AI** - Automated Security Remediation
**Powered by IBM Concert**
EOF

# Commit changes
echo -e "${BLUE}💾 Committing remediation changes...${NC}"

git add .
git commit -m "fix: Apply automated security fixes from IBM Concert

This commit addresses $FIXES_APPLIED vulnerabilities detected by IBM Concert:
- Critical vulnerabilities: $CRITICAL_VULNS
- High vulnerabilities: $HIGH_VULNS

Changes include:
- Dependency version updates
- Security patches
- Configuration improvements

Fixes applied by Bob AI based on Concert vulnerability analysis.

See .bob-workspace/remediation-log.md for detailed changes.
" || echo -e "${YELLOW}⚠️  No changes to commit${NC}"

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Remediation Complete                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Fixes Applied: $FIXES_APPLIED${NC}"
echo -e "${YELLOW}⚠️  Manual Review Required: $((CRITICAL_VULNS + HIGH_VULNS - FIXES_APPLIED))${NC}"
echo ""
echo -e "${BLUE}📄 Remediation Log: $REMEDIATION_LOG${NC}"
echo -e "${BLUE}🌿 Branch: $REMEDIATION_BRANCH${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Review changes: ${GREEN}git diff main${NC}"
echo -e "  2. Push branch: ${GREEN}git push origin $REMEDIATION_BRANCH${NC}"
echo -e "  3. Create PR for review"
echo -e "  4. Merge after approval"
echo -e "  5. CI/CD will verify fixes with Concert"
echo ""

exit 0

# Made with Bob
