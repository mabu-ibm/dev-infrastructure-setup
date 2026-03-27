#!/bin/bash
################################################################################
# Chat Sync Script - Syncs Claude Code and IBM Bob conversations to git
# Purpose: Automatically save AI assistant conversations to project repos
# Usage: ./sync-chats.sh [project-path]
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
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Configuration
CLAUDE_DIR="${HOME}/.claude/projects"
BOB_DIR="${HOME}/.bob/projects"
PROJECT_DIR="${1:-$(pwd)}"

# Validate project directory
if [ ! -d "${PROJECT_DIR}" ]; then
    log_error "Project directory does not exist: ${PROJECT_DIR}"
    exit 1
fi

if [ ! -d "${PROJECT_DIR}/.git" ]; then
    log_warn "Not a git repository: ${PROJECT_DIR}"
    log_warn "Skipping sync for this directory"
    exit 0
fi

log_info "Syncing chats for project: ${PROJECT_DIR}"

# Function to find matching Claude project directory
find_claude_project() {
    local project_path="$1"
    local project_hash=$(echo -n "${project_path}" | md5sum | cut -d' ' -f1)
    
    # Try exact hash match first
    if [ -d "${CLAUDE_DIR}/${project_hash}" ]; then
        echo "${CLAUDE_DIR}/${project_hash}"
        return 0
    fi
    
    # Try to find by searching for project path in metadata
    for dir in "${CLAUDE_DIR}"/*; do
        if [ -d "${dir}" ] && [ -f "${dir}/project.json" ]; then
            if grep -q "${project_path}" "${dir}/project.json" 2>/dev/null; then
                echo "${dir}"
                return 0
            fi
        fi
    done
    
    return 1
}

# Function to find matching Bob project directory
find_bob_project() {
    local project_path="$1"
    local project_hash=$(echo -n "${project_path}" | md5sum | cut -d' ' -f1)
    
    # Try exact hash match first
    if [ -d "${BOB_DIR}/${project_hash}" ]; then
        echo "${BOB_DIR}/${project_hash}"
        return 0
    fi
    
    # Try to find by searching for project path in metadata
    for dir in "${BOB_DIR}"/*; do
        if [ -d "${dir}" ] && [ -f "${dir}/project.json" ]; then
            if grep -q "${project_path}" "${dir}/project.json" 2>/dev/null; then
                echo "${dir}"
                return 0
            fi
        fi
    done
    
    return 1
}

# Function to sync chats from a source to destination
sync_chat_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    local chat_type="$3"
    
    if [ ! -d "${source_dir}" ]; then
        log_debug "No ${chat_type} directory found: ${source_dir}"
        return 0
    fi
    
    # Create destination directory
    mkdir -p "${dest_dir}"
    
    # Count files to sync
    local file_count=$(find "${source_dir}" -type f \( -name "*.json" -o -name "*.md" \) 2>/dev/null | wc -l)
    
    if [ ${file_count} -eq 0 ]; then
        log_debug "No ${chat_type} files to sync"
        return 0
    fi
    
    log_info "Syncing ${file_count} ${chat_type} file(s)..."
    
    # Copy files with timestamp preservation
    rsync -a --delete "${source_dir}/" "${dest_dir}/"
    
    log_info "✓ ${chat_type} files synced to ${dest_dir}"
    return 0
}

# Main sync logic
cd "${PROJECT_DIR}"

CHANGES_MADE=false

# Sync Claude Code chats
if [ -d "${CLAUDE_DIR}" ]; then
    log_info "Looking for Claude Code conversations..."
    if CLAUDE_PROJECT=$(find_claude_project "${PROJECT_DIR}"); then
        log_info "Found Claude project: ${CLAUDE_PROJECT}"
        if sync_chat_directory "${CLAUDE_PROJECT}/conversations" "${PROJECT_DIR}/.claude-chats" "Claude Code"; then
            CHANGES_MADE=true
        fi
    else
        log_debug "No Claude Code project found for this directory"
    fi
else
    log_debug "Claude Code directory not found: ${CLAUDE_DIR}"
fi

# Sync IBM Bob chats
if [ -d "${BOB_DIR}" ]; then
    log_info "Looking for IBM Bob conversations..."
    if BOB_PROJECT=$(find_bob_project "${PROJECT_DIR}"); then
        log_info "Found Bob project: ${BOB_PROJECT}"
        if sync_chat_directory "${BOB_PROJECT}/conversations" "${PROJECT_DIR}/.bob-chats" "IBM Bob"; then
            CHANGES_MADE=true
        fi
    else
        log_debug "No IBM Bob project found for this directory"
    fi
else
    log_debug "IBM Bob directory not found: ${BOB_DIR}"
fi

# Commit changes if any
if [ "${CHANGES_MADE}" = true ]; then
    log_info "Committing chat history to git..."
    
    git add .claude-chats/ .bob-chats/ 2>/dev/null || true
    
    if git diff --cached --quiet; then
        log_info "No changes to commit"
    else
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        git commit -m "chore: sync AI chat history - ${TIMESTAMP}" --no-verify
        log_info "✓ Chat history committed"
        
        # Push if remote exists and is configured
        if git remote get-url origin &>/dev/null; then
            log_info "Pushing to remote repository..."
            if git push origin $(git branch --show-current) 2>/dev/null; then
                log_info "✓ Changes pushed to remote"
            else
                log_warn "Failed to push to remote (may need authentication)"
            fi
        fi
    fi
else
    log_info "No chat files to sync"
fi

log_info "Chat sync complete for ${PROJECT_DIR}"

# Made with Bob
