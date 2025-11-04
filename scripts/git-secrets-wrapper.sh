#!/usr/bin/env bash
set -e

# Cross-platform wrapper script for NHSD Git Secrets
# This script detects the operating system and runs the appropriate git-secrets command
#
# Usage: git-secrets-wrapper.sh [--custom-rules-file <path>]
#
# Arguments:
#   --custom-rules-file: Path to additional rules file (relative to repo root or absolute)

# Parse command line arguments
CUSTOM_RULES_ARG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --custom-rules-file)
            CUSTOM_RULES_ARG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the repository root directory
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Detect the operating system
OS="$(uname -s 2>/dev/null || echo "Windows")"

case "${OS}" in
    Linux*|Darwin*)
        # Unix-like systems (Linux, macOS)
        GIT_SECRETS_EXEC="${SCRIPT_DIR}/git-secrets"
        RULES_FILE="${SCRIPT_DIR}/../rules/nhsd-rules-deny.txt"
        CUSTOM_RULES_FILE="${SCRIPT_DIR}/../rules/custom-rules.txt"
        
        # Make sure git-secrets is executable
        chmod +x "${GIT_SECRETS_EXEC}" 2>/dev/null || true
        
        # Add the NHSD rules provider
        "${GIT_SECRETS_EXEC}" --add-provider -- cat "${RULES_FILE}"
        
        # Add custom rules from hook's directory if it exists
        if [ -f "${CUSTOM_RULES_FILE}" ]; then
            echo "Loading custom rules from hook directory: ${CUSTOM_RULES_FILE}" >&2
            "${GIT_SECRETS_EXEC}" --add-provider -- cat "${CUSTOM_RULES_FILE}"
        fi
        
        # Add custom rules from user's repository if specified
        if [ -n "${CUSTOM_RULES_ARG}" ]; then
            # Check if path is absolute or relative
            if [[ "${CUSTOM_RULES_ARG}" = /* ]]; then
                USER_RULES_FILE="${CUSTOM_RULES_ARG}"
            else
                USER_RULES_FILE="${REPO_ROOT}/${CUSTOM_RULES_ARG}"
            fi
            
            if [ -f "${USER_RULES_FILE}" ]; then
                echo "Loading custom rules from repository: ${USER_RULES_FILE}" >&2
                "${GIT_SECRETS_EXEC}" --add-provider -- cat "${USER_RULES_FILE}"
            else
                echo "Warning: Custom rules file not found: ${USER_RULES_FILE}" >&2
            fi
        fi
        
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
            CUSTOM_RULES_FILE="${SCRIPT_DIR}/../rules/custom-rules.txt"
            
            # Add the NHSD rules provider
            "${GIT_SECRETS_EXEC}" --add-provider -- cat "${RULES_FILE}"
            
            # Add custom rules from hook's directory if it exists
            if [ -f "${CUSTOM_RULES_FILE}" ]; then
                echo "Loading custom rules from hook directory: ${CUSTOM_RULES_FILE}" >&2
                "${GIT_SECRETS_EXEC}" --add-provider -- cat "${CUSTOM_RULES_FILE}"
            fi
            
            # Add custom rules from user's repository if specified
            if [ -n "${CUSTOM_RULES_ARG}" ]; then
                # Check if path is absolute or relative
                if [[ "${CUSTOM_RULES_ARG}" = /* ]]; then
                    USER_RULES_FILE="${CUSTOM_RULES_ARG}"
                else
                    USER_RULES_FILE="${REPO_ROOT}/${CUSTOM_RULES_ARG}"
                fi
                
                if [ -f "${USER_RULES_FILE}" ]; then
                    echo "Loading custom rules from repository: ${USER_RULES_FILE}" >&2
                    "${GIT_SECRETS_EXEC}" --add-provider -- cat "${USER_RULES_FILE}"
                else
                    echo "Warning: Custom rules file not found: ${USER_RULES_FILE}" >&2
                fi
            fi
            
            # Run the pre-commit hook
            "${GIT_SECRETS_EXEC}" --pre_commit_hook
        fi
        ;;
    *)
        echo "Unsupported operating system: ${OS}" >&2
        exit 1
        ;;
esac