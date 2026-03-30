#!/bin/bash
################################################################################
# SBOM Generation Script
# Purpose: Generate Software Bill of Materials using Syft and upload to Concert
# Usage: ./generate-sbom.sh [image-name:tag] [--upload]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Configuration
IMAGE_NAME="${1:-}"
UPLOAD_TO_CONCERT="${2:-}"
SBOM_DIR="${SBOM_DIR:-./sbom}"
SBOM_FORMAT="${SBOM_FORMAT:-spdx-json}"  # Options: spdx-json, cyclonedx-json, syft-json

# Concert Configuration (from environment)
CONCERT_URL="${CONCERT_URL:-}"
CONCERT_API_KEY="${CONCERT_API_KEY:-}"
CONCERT_INSTANCE_ID="${CONCERT_INSTANCE_ID:-}"
CONCERT_APPLICATION_ID="${CONCERT_APPLICATION_ID:-}"

# Check if Syft is installed
check_syft() {
    if ! command -v syft &> /dev/null; then
        log_error "Syft is not installed"
        log_info "Installing Syft..."
        
        # Detect OS and install Syft
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install syft
            else
                log_error "Homebrew not found. Install from: https://github.com/anchore/syft/releases"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
        else
            log_error "Unsupported OS. Install Syft from: https://github.com/anchore/syft/releases"
            exit 1
        fi
        
        log_info "Syft installed successfully"
    else
        log_info "Syft version: $(syft version | head -n1)"
    fi
}

# Generate SBOM from Docker image
generate_sbom_from_image() {
    local image="$1"
    local output_file="$2"
    
    log_step "Generating SBOM from Docker image: ${image}"
    
    syft "${image}" \
        --output "${SBOM_FORMAT}=${output_file}" \
        --quiet
    
    if [ $? -eq 0 ]; then
        log_info "SBOM generated: ${output_file}"
        log_info "File size: $(du -h "${output_file}" | cut -f1)"
        
        # Display summary
        if command -v jq &> /dev/null; then
            local package_count=$(jq '.packages | length' "${output_file}" 2>/dev/null || echo "N/A")
            log_info "Packages found: ${package_count}"
        fi
        
        return 0
    else
        log_error "Failed to generate SBOM"
        return 1
    fi
}

# Generate SBOM from directory (source code)
generate_sbom_from_directory() {
    local directory="$1"
    local output_file="$2"
    
    log_step "Generating SBOM from directory: ${directory}"
    
    syft "dir:${directory}" \
        --output "${SBOM_FORMAT}=${output_file}" \
        --quiet
    
    if [ $? -eq 0 ]; then
        log_info "SBOM generated: ${output_file}"
        log_info "File size: $(du -h "${output_file}" | cut -f1)"
        return 0
    else
        log_error "Failed to generate SBOM"
        return 1
    fi
}

# Upload SBOM to IBM Concert
upload_to_concert() {
    local sbom_file="$1"
    
    # Validate Concert configuration
    if [ -z "${CONCERT_URL}" ] || [ -z "${CONCERT_API_KEY}" ] || [ -z "${CONCERT_INSTANCE_ID}" ]; then
        log_warn "Concert configuration incomplete. Skipping upload."
        log_info "Required environment variables:"
        log_info "  - CONCERT_URL"
        log_info "  - CONCERT_API_KEY"
        log_info "  - CONCERT_INSTANCE_ID"
        log_info "  - CONCERT_APPLICATION_ID (optional)"
        return 1
    fi
    
    log_step "Uploading SBOM to IBM Concert..."
    
    # Prepare upload payload
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local sbom_content=$(cat "${sbom_file}")
    
    # Concert API endpoint for SBOM upload
    # Note: This is a placeholder - adjust based on actual Concert API
    local api_endpoint="${CONCERT_URL}/core/api/v1/sbom"
    
    # Upload SBOM
    local response=$(curl -s -w "\n%{http_code}" -X POST "${api_endpoint}" \
        -H "C_API_KEY: ${CONCERT_API_KEY}" \
        -H "InstanceID: ${CONCERT_INSTANCE_ID}" \
        -H "Content-Type: application/json" \
        -d "{
            \"application_id\": \"${CONCERT_APPLICATION_ID}\",
            \"timestamp\": \"${timestamp}\",
            \"format\": \"${SBOM_FORMAT}\",
            \"sbom\": $(echo "${sbom_content}" | jq -Rs .)
        }")
    
    local http_code=$(echo "${response}" | tail -n1)
    local response_body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" -ge 200 ] && [ "${http_code}" -lt 300 ]; then
        log_info "SBOM uploaded successfully to Concert"
        log_info "Response: ${response_body}"
        return 0
    else
        log_error "Failed to upload SBOM to Concert (HTTP ${http_code})"
        log_error "Response: ${response_body}"
        return 1
    fi
}

# Main execution
main() {
    log_info "============================================"
    log_info "SBOM Generation Tool"
    log_info "============================================"
    
    # Check Syft installation
    check_syft
    
    # Create SBOM directory
    mkdir -p "${SBOM_DIR}"
    
    # Determine what to scan
    if [ -n "${IMAGE_NAME}" ]; then
        # Scan Docker image
        local timestamp=$(date +"%Y%m%d-%H%M%S")
        local safe_image_name=$(echo "${IMAGE_NAME}" | tr ':/' '_')
        local sbom_file="${SBOM_DIR}/sbom-${safe_image_name}-${timestamp}.json"
        
        generate_sbom_from_image "${IMAGE_NAME}" "${sbom_file}"
    else
        # Scan current directory
        local project_name=$(basename "$(pwd)")
        local timestamp=$(date +"%Y%m%d-%H%M%S")
        local sbom_file="${SBOM_DIR}/sbom-${project_name}-${timestamp}.json"
        
        generate_sbom_from_directory "." "${sbom_file}"
    fi
    
    # Upload to Concert if requested
    if [ "${UPLOAD_TO_CONCERT}" == "--upload" ] || [ "${UPLOAD_TO_CONCERT}" == "-u" ]; then
        upload_to_concert "${sbom_file}"
    else
        log_info "Skipping Concert upload (use --upload flag to enable)"
    fi
    
    log_info "============================================"
    log_info "SBOM Generation Complete"
    log_info "============================================"
    log_info "SBOM file: ${sbom_file}"
    log_info ""
    log_info "Next steps:"
    log_info "1. Review SBOM: cat ${sbom_file} | jq ."
    log_info "2. Upload to Concert: $0 ${IMAGE_NAME} --upload"
    log_info "3. Integrate into CI/CD pipeline"
    log_info "============================================"
}

# Run main function
main

# Made with Bob
