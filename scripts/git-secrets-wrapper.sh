#!/usr/bin/env bash
set -e

# Cross-platform wrapper script for NHSD Git Secrets
# This script detects the operating system and runs the appropriate git-secrets command

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect the operating system
OS="$(uname -s 2>/dev/null || echo "Windows")"

case "${OS}" in
    Linux*|Darwin*)
        # Unix-like systems (Linux, macOS)
        GIT_SECRETS_EXEC="${SCRIPT_DIR}/git-secrets"
        RULES_FILE="${SCRIPT_DIR}/../rules/nhsd-rules-deny.txt"
        
        # Make sure git-secrets is executable
        chmod +x "${GIT_SECRETS_EXEC}" 2>/dev/null || true
        
        # Add the NHSD rules provider
        "${GIT_SECRETS_EXEC}" --add-provider -- cat "${RULES_FILE}"
        
        # Run the pre-commit hook
        "${GIT_SECRETS_EXEC}" --pre_commit_hook
        ;;
    MINGW*|CYGWIN*|MSYS*|Windows*)
        # Windows systems (including Git Bash, MINGW, CYGWIN)
        # Try to find PowerShell and run the PowerShell script
        if command -v powershell.exe >/dev/null 2>&1; then
            exec powershell.exe -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/git-secrets-wrapper.ps1" "$@"
        elif command -v pwsh >/dev/null 2>&1; then
            exec pwsh -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/git-secrets-wrapper.ps1" "$@"
        else
            # Fallback: try to run with bash anyway (might work in Git Bash)
            GIT_SECRETS_EXEC="${SCRIPT_DIR}/git-secrets"
            RULES_FILE="${SCRIPT_DIR}/../rules/nhsd-rules-deny.txt"
            
            # Add the NHSD rules provider
            "${GIT_SECRETS_EXEC}" --add-provider -- cat "${RULES_FILE}"
            
            # Run the pre-commit hook
            "${GIT_SECRETS_EXEC}" --pre_commit_hook
        fi
        ;;
    *)
        echo "Unsupported operating system: ${OS}" >&2
        exit 1
        ;;
esac