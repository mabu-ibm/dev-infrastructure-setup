#!/usr/bin/env python3
"""
IBM Concert SBOM Upload Script
Purpose: Upload Software Bill of Materials to IBM Concert
Usage: python upload-sbom-to-concert.py <sbom-file> [--application-id <id>]
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

import requests


class ConcertSBOMUploader:
    """Upload SBOM to IBM Concert"""
    
    def __init__(
        self,
        concert_url: str,
        api_key: str,
        instance_id: str,
        application_id: Optional[str] = None
    ):
        self.concert_url = concert_url.rstrip('/')
        self.api_key = api_key
        self.instance_id = instance_id
        self.application_id = application_id
        
        self.session = requests.Session()
        self.session.headers.update({
            'C_API_KEY': self.api_key,
            'InstanceID': self.instance_id,
            'Content-Type': 'application/json'
        })
    
    def validate_sbom(self, sbom_path: Path) -> Dict:
        """Validate and load SBOM file"""
        if not sbom_path.exists():
            raise FileNotFoundError(f"SBOM file not found: {sbom_path}")
        
        try:
            with open(sbom_path, 'r') as f:
                sbom_data = json.load(f)
            
            # Validate SBOM format
            if 'spdxVersion' in sbom_data:
                sbom_format = 'spdx-json'
            elif 'bomFormat' in sbom_data:
                sbom_format = 'cyclonedx-json'
            elif 'artifacts' in sbom_data:
                sbom_format = 'syft-json'
            else:
                raise ValueError("Unknown SBOM format")
            
            print(f"✓ SBOM format detected: {sbom_format}")
            
            # Extract package count
            if sbom_format == 'spdx-json':
                package_count = len(sbom_data.get('packages', []))
            elif sbom_format == 'cyclonedx-json':
                package_count = len(sbom_data.get('components', []))
            else:
                package_count = len(sbom_data.get('artifacts', []))
            
            print(f"✓ Packages found: {package_count}")
            
            return {
                'data': sbom_data,
                'format': sbom_format,
                'package_count': package_count
            }
            
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in SBOM file: {e}")
    
    def create_build_artifact(self, sbom_info: Dict) -> Optional[str]:
        """Create or get build artifact in Concert"""
        if not self.application_id:
            print("⚠ No application ID provided, skipping build artifact creation")
            return None
        
        # Extract artifact information from SBOM
        sbom_data = sbom_info['data']
        
        # Try to extract image name/version from SBOM
        artifact_name = "unknown"
        artifact_version = "latest"
        
        if sbom_info['format'] == 'spdx-json':
            artifact_name = sbom_data.get('name', 'unknown')
            artifact_version = sbom_data.get('spdxVersion', 'latest')
        elif sbom_info['format'] == 'cyclonedx-json':
            metadata = sbom_data.get('metadata', {})
            component = metadata.get('component', {})
            artifact_name = component.get('name', 'unknown')
            artifact_version = component.get('version', 'latest')
        
        # Create build artifact
        endpoint = f"{self.concert_url}/core/api/v1/applications/{self.application_id}/build_artifacts"
        
        payload = {
            "name": artifact_name,
            "version": artifact_version,
            "image_tag": artifact_version,
            "created_on": int(datetime.utcnow().timestamp())
        }
        
        try:
            response = self.session.post(endpoint, json=payload)
            
            if response.status_code in [200, 201]:
                artifact_data = response.json()
                artifact_id = artifact_data.get('id')
                print(f"✓ Build artifact created: {artifact_id}")
                return artifact_id
            elif response.status_code == 409:
                # Artifact already exists, try to get it
                print("⚠ Build artifact already exists, fetching existing...")
                return self.get_existing_artifact(artifact_name, artifact_version)
            else:
                print(f"⚠ Failed to create build artifact: {response.status_code}")
                print(f"  Response: {response.text}")
                return None
                
        except Exception as e:
            print(f"⚠ Error creating build artifact: {e}")
            return None
    
    def get_existing_artifact(self, name: str, version: str) -> Optional[str]:
        """Get existing build artifact ID"""
        if not self.application_id:
            return None
        
        endpoint = f"{self.concert_url}/core/api/v1/applications/{self.application_id}/build_artifacts"
        
        try:
            response = self.session.get(endpoint)
            
            if response.status_code == 200:
                data = response.json()
                artifacts = data.get('build_artifacts', [])
                
                for artifact in artifacts:
                    if artifact.get('name') == name and artifact.get('version') == version:
                        artifact_id = artifact.get('id')
                        print(f"✓ Found existing artifact: {artifact_id}")
                        return artifact_id
            
            return None
            
        except Exception as e:
            print(f"⚠ Error fetching artifacts: {e}")
            return None
    
    def upload_sbom(self, sbom_path: Path) -> bool:
        """Upload SBOM to Concert"""
        print("\n" + "="*60)
        print("IBM Concert SBOM Upload")
        print("="*60)
        
        # Validate SBOM
        print("\n[1/4] Validating SBOM...")
        try:
            sbom_info = self.validate_sbom(sbom_path)
        except Exception as e:
            print(f"✗ SBOM validation failed: {e}")
            return False
        
        # Create build artifact (if application ID provided)
        print("\n[2/4] Creating build artifact...")
        artifact_id = self.create_build_artifact(sbom_info)
        
        # Prepare upload payload
        print("\n[3/4] Preparing upload...")
        
        # Note: Adjust endpoint based on actual Concert API
        # This is a placeholder implementation
        if artifact_id:
            endpoint = f"{self.concert_url}/core/api/v1/applications/{self.application_id}/build_artifacts/{artifact_id}/sbom"
        else:
            endpoint = f"{self.concert_url}/core/api/v1/sbom"
        
        payload = {
            "format": sbom_info['format'],
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "sbom": sbom_info['data']
        }
        
        if self.application_id and not artifact_id:
            payload['application_id'] = self.application_id
        
        # Upload SBOM
        print("\n[4/4] Uploading to Concert...")
        try:
            response = self.session.post(endpoint, json=payload)
            
            if response.status_code in [200, 201, 202]:
                print(f"✓ SBOM uploaded successfully!")
                print(f"  Status: {response.status_code}")
                
                try:
                    result = response.json()
                    if 'id' in result:
                        print(f"  SBOM ID: {result['id']}")
                except:
                    pass
                
                return True
            else:
                print(f"✗ Upload failed: HTTP {response.status_code}")
                print(f"  Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"✗ Upload error: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(
        description='Upload SBOM to IBM Concert',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Upload SBOM with application context
  python upload-sbom-to-concert.py sbom.json --application-id app-123
  
  # Upload SBOM without application context
  python upload-sbom-to-concert.py sbom.json
  
Environment Variables:
  CONCERT_URL          - Concert instance URL (required)
  CONCERT_API_KEY      - Concert API key (required)
  CONCERT_INSTANCE_ID  - Concert instance ID (required)
  CONCERT_APPLICATION_ID - Default application ID (optional)
        """
    )
    
    parser.add_argument(
        'sbom_file',
        type=Path,
        help='Path to SBOM file (JSON format)'
    )
    
    parser.add_argument(
        '--application-id',
        type=str,
        help='Concert application ID'
    )
    
    args = parser.parse_args()
    
    # Get configuration from environment
    concert_url = os.getenv('CONCERT_URL')
    api_key = os.getenv('CONCERT_API_KEY')
    instance_id = os.getenv('CONCERT_INSTANCE_ID')
    application_id = args.application_id or os.getenv('CONCERT_APPLICATION_ID')
    
    # Validate configuration
    if not all([concert_url, api_key, instance_id]):
        print("✗ Missing required environment variables:")
        if not concert_url:
            print("  - CONCERT_URL")
        if not api_key:
            print("  - CONCERT_API_KEY")
        if not instance_id:
            print("  - CONCERT_INSTANCE_ID")
        print("\nSet these variables or add them to ~/.dev-infrastructure.env")
        sys.exit(1)
    
    # Create uploader and upload SBOM
    uploader = ConcertSBOMUploader(
        concert_url=str(concert_url),
        api_key=str(api_key),
        instance_id=str(instance_id),
        application_id=application_id
    )
    
    success = uploader.upload_sbom(args.sbom_file)
    
    print("\n" + "="*60)
    if success:
        print("✓ SBOM upload completed successfully")
    else:
        print("✗ SBOM upload failed")
    print("="*60 + "\n")
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

# Made with Bob
