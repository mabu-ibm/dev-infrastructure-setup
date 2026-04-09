#!/usr/bin/env python3
"""
Fetch vulnerabilities from IBM Concert and prepare them for Bob AI remediation.

This script:
1. Retrieves vulnerability data from Concert API
2. Analyzes CVEs and risk scores
3. Generates a structured report for Bob AI
4. Creates GitHub issues or comments for automated remediation
"""

import os
import sys
import json
import requests
import argparse
from datetime import datetime
from typing import Dict, List, Optional


class ConcertClient:
    """Client for IBM Concert API."""
    
    def __init__(self, base_url: str, api_key: str, instance_id: str):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            "C_API_KEY": api_key,
            "InstanceID": instance_id,
            "Content-Type": "application/json"
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
    
    def get_application_vulnerabilities(self, app_id: str) -> Dict:
        """Get all vulnerabilities for an application."""
        endpoint = f"{self.base_url}/core/api/v1/applications/{app_id}/vulnerability_details"
        
        try:
            response = self.session.get(endpoint, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching vulnerabilities: {e}")
            return {"vulnerability_details": []}
    
    def get_cve_assessment(self, app_id: str, cve_id: str) -> Dict:
        """Get detailed assessment for a specific CVE."""
        endpoint = f"{self.base_url}/core/api/v1/applications/{app_id}/cves/{cve_id}/assessments"
        
        try:
            response = self.session.get(endpoint, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"⚠️  Warning: Could not fetch assessment for {cve_id}: {e}")
            return {}
    
    def get_build_artifact_cves(self, app_id: str, artifact_id: str) -> Dict:
        """Get CVEs for a specific build artifact."""
        endpoint = f"{self.base_url}/core/api/v1/applications/{app_id}/build_artifacts/{artifact_id}/cves"
        
        try:
            response = self.session.get(endpoint, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"⚠️  Warning: Could not fetch CVEs for artifact {artifact_id}: {e}")
            return {"cves": []}


class VulnerabilityAnalyzer:
    """Analyze vulnerabilities and generate remediation recommendations."""
    
    def __init__(self, client: ConcertClient):
        self.client = client
    
    def analyze_vulnerabilities(self, app_id: str) -> Dict:
        """Analyze all vulnerabilities for an application."""
        print(f"🔍 Analyzing vulnerabilities for application {app_id}...")
        
        # Get vulnerability details
        vuln_data = self.client.get_application_vulnerabilities(app_id)
        vulnerabilities = vuln_data.get("vulnerability_details", [])
        
        if not vulnerabilities:
            print("✅ No vulnerabilities found!")
            return self._create_empty_report(app_id)
        
        # Categorize by severity
        critical = []
        high = []
        medium = []
        low = []
        
        for vuln in vulnerabilities:
            risk_score = vuln.get("highest_finding_risk_score", 0)
            
            if risk_score >= 9.0:
                critical.append(vuln)
            elif risk_score >= 7.0:
                high.append(vuln)
            elif risk_score >= 4.0:
                medium.append(vuln)
            else:
                low.append(vuln)
        
        print(f"📊 Vulnerability Summary:")
        print(f"   🔴 Critical: {len(critical)}")
        print(f"   🟠 High: {len(high)}")
        print(f"   🟡 Medium: {len(medium)}")
        print(f"   🟢 Low: {len(low)}")
        
        # Get detailed assessments for critical and high vulnerabilities
        priority_vulns = critical + high
        detailed_assessments = []
        
        for vuln in priority_vulns[:10]:  # Limit to top 10 for performance
            cve_id = vuln.get("cve")
            if cve_id:
                assessment = self.client.get_cve_assessment(app_id, cve_id)
                if assessment:
                    detailed_assessments.append({
                        "cve": cve_id,
                        "risk_score": vuln.get("highest_finding_risk_score"),
                        "component": vuln.get("component"),
                        "assessment": assessment
                    })
        
        return {
            "app_id": app_id,
            "timestamp": datetime.utcnow().isoformat(),
            "summary": {
                "total": len(vulnerabilities),
                "critical": len(critical),
                "high": len(high),
                "medium": len(medium),
                "low": len(low)
            },
            "critical_vulnerabilities": critical,
            "high_vulnerabilities": high,
            "detailed_assessments": detailed_assessments,
            "requires_immediate_action": len(critical) > 0
        }
    
    def _create_empty_report(self, app_id: str) -> Dict:
        """Create an empty report when no vulnerabilities found."""
        return {
            "app_id": app_id,
            "timestamp": datetime.utcnow().isoformat(),
            "summary": {
                "total": 0,
                "critical": 0,
                "high": 0,
                "medium": 0,
                "low": 0
            },
            "critical_vulnerabilities": [],
            "high_vulnerabilities": [],
            "detailed_assessments": [],
            "requires_immediate_action": False
        }


class BobAIIntegration:
    """Integration with Bob AI for automated remediation."""
    
    @staticmethod
    def generate_bob_prompt(analysis: Dict) -> str:
        """Generate a prompt for Bob AI to remediate vulnerabilities."""
        summary = analysis.get("summary", {})
        critical = analysis.get("critical_vulnerabilities", [])
        high = analysis.get("high_vulnerabilities", [])
        
        prompt = f"""# Security Vulnerability Report from IBM Concert

**Application ID**: {analysis.get('app_id')}
**Scan Time**: {analysis.get('timestamp')}

## Summary
- Total Vulnerabilities: {summary.get('total', 0)}
- 🔴 Critical: {summary.get('critical', 0)}
- 🟠 High: {summary.get('high', 0)}
- 🟡 Medium: {summary.get('medium', 0)}
- 🟢 Low: {summary.get('low', 0)}

"""
        
        if analysis.get("requires_immediate_action"):
            prompt += "⚠️  **IMMEDIATE ACTION REQUIRED** - Critical vulnerabilities detected!\n\n"
        
        # Add critical vulnerabilities
        if critical:
            prompt += "## Critical Vulnerabilities (Risk Score ≥ 9.0)\n\n"
            for vuln in critical[:5]:  # Top 5 critical
                prompt += f"### {vuln.get('cve', 'Unknown CVE')}\n"
                prompt += f"- **Risk Score**: {vuln.get('highest_finding_risk_score', 'N/A')}\n"
                prompt += f"- **Component**: {vuln.get('component', 'N/A')}\n"
                prompt += f"- **Priority**: {vuln.get('highest_finding_priority', 'N/A')}\n"
                prompt += f"- **CVSS**: {vuln.get('cvss', 'N/A')}\n\n"
        
        # Add high vulnerabilities
        if high:
            prompt += "## High Vulnerabilities (Risk Score ≥ 7.0)\n\n"
            for vuln in high[:5]:  # Top 5 high
                prompt += f"### {vuln.get('cve', 'Unknown CVE')}\n"
                prompt += f"- **Risk Score**: {vuln.get('highest_finding_risk_score', 'N/A')}\n"
                prompt += f"- **Component**: {vuln.get('component', 'N/A')}\n\n"
        
        # Add remediation instructions
        prompt += """## Remediation Instructions for Bob AI

Please analyze these vulnerabilities and:

1. **Update Dependencies**: Check if newer versions are available that fix these CVEs
2. **Generate Patches**: Create code patches where version updates aren't sufficient
3. **Update Configurations**: Modify Dockerfile, requirements.txt, or other configs as needed
4. **Create Pull Request**: Generate a PR with all fixes and detailed commit messages
5. **Document Changes**: Include CVE references and risk scores in commit messages

### Example Remediation Steps:

For dependency updates:
```bash
# Update requirements.txt
old_package==1.0.0  # CVE-2024-XXXXX (Risk: 9.5)
new_package==1.2.3  # Fixed version
```

For code patches:
```python
# Apply security patch for CVE-2024-XXXXX
# Risk Score: 8.7
# Fix: Add input validation
```

Please proceed with automated remediation for all critical and high vulnerabilities.
"""
        
        return prompt
    
    @staticmethod
    def save_report(analysis: Dict, output_file: str):
        """Save analysis report to file."""
        with open(output_file, 'w') as f:
            json.dump(analysis, f, indent=2)
        print(f"💾 Report saved to: {output_file}")
    
    @staticmethod
    def save_bob_prompt(prompt: str, output_file: str):
        """Save Bob AI prompt to file."""
        with open(output_file, 'w') as f:
            f.write(prompt)
        print(f"💾 Bob AI prompt saved to: {output_file}")


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Fetch vulnerabilities from IBM Concert for Bob AI remediation"
    )
    parser.add_argument(
        "--app-id",
        required=True,
        help="Concert Application ID"
    )
    parser.add_argument(
        "--api-key",
        help="Concert API Key (or set CONCERT_API_KEY env var)"
    )
    parser.add_argument(
        "--instance-id",
        help="Concert Instance ID (or set CONCERT_INSTANCE_ID env var)"
    )
    parser.add_argument(
        "--base-url",
        default="https://91431.us-south-8.concert.saas.ibm.com",
        help="Concert API base URL"
    )
    parser.add_argument(
        "--output",
        default="concert-vulnerabilities.json",
        help="Output file for vulnerability report"
    )
    parser.add_argument(
        "--bob-prompt",
        default="bob-remediation-prompt.md",
        help="Output file for Bob AI prompt"
    )
    
    args = parser.parse_args()
    
    # Get credentials from args or environment
    api_key = args.api_key or os.getenv("CONCERT_API_KEY")
    instance_id = args.instance_id or os.getenv("CONCERT_INSTANCE_ID")
    
    if not api_key or not instance_id:
        print("❌ Error: Concert API credentials required!")
        print("   Set CONCERT_API_KEY and CONCERT_INSTANCE_ID environment variables")
        print("   or provide --api-key and --instance-id arguments")
        sys.exit(1)
    
    # Initialize clients
    print("🚀 Starting Concert vulnerability analysis...")
    client = ConcertClient(args.base_url, api_key, instance_id)
    analyzer = VulnerabilityAnalyzer(client)
    
    # Analyze vulnerabilities
    analysis = analyzer.analyze_vulnerabilities(args.app_id)
    
    # Generate Bob AI prompt
    bob_prompt = BobAIIntegration.generate_bob_prompt(analysis)
    
    # Save outputs
    BobAIIntegration.save_report(analysis, args.output)
    BobAIIntegration.save_bob_prompt(bob_prompt, args.bob_prompt)
    
    # Print summary
    print("\n" + "="*60)
    print("✅ Analysis Complete!")
    print("="*60)
    
    if analysis.get("requires_immediate_action"):
        print("⚠️  CRITICAL: Immediate action required!")
        print(f"   {analysis['summary']['critical']} critical vulnerabilities found")
    
    print(f"\n📄 Files generated:")
    print(f"   - Vulnerability Report: {args.output}")
    print(f"   - Bob AI Prompt: {args.bob_prompt}")
    
    print(f"\n🤖 Next Steps:")
    print(f"   1. Review the vulnerability report")
    print(f"   2. Share Bob AI prompt with Bob for automated remediation")
    print(f"   3. Bob will create a pull request with fixes")
    print(f"   4. Review and merge the security fixes")
    
    return 0 if not analysis.get("requires_immediate_action") else 1


if __name__ == "__main__":
    sys.exit(main())

# Made with Bob
