#!/usr/bin/env bash
# Don't use set -e because we need to handle git-secrets exit codes properly
# and ensure output is displayed to the user

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

# Get the directory where this script is located (resolve symlinks for robustness)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Get the repository root directory
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Detect the operating system
OS="$(uname -s 2>/dev/null || echo "Windows")"

# Function to load patterns directly (avoiding provider path issues)
load_patterns_from_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # Read patterns, skip comments and empty lines
        grep -v '^#' "$file" | grep -v '^[[:space:]]*$' || true
    fi
}

# Function to scan staged files directly using grep
scan_staged_files() {
    local patterns_file="$1"
    local custom_patterns_file="$2"
    local user_patterns_file="$3"
    local gitallowed_file="$4"
    
    # Get the list of staged files
    local rev="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    git rev-parse --verify HEAD >/dev/null 2>&1 && rev="HEAD"
    
    local staged_files
    staged_files=$(git diff-index --diff-filter 'ACMU' --name-only --cached "$rev" -- 2>/dev/null)
    
    if [ -z "$staged_files" ]; then
        # No staged files, nothing to scan
        return 0
    fi
    
    # Build combined patterns
    local all_patterns=""
    
    # Load main rules
    if [ -f "$patterns_file" ]; then
        all_patterns=$(load_patterns_from_file "$patterns_file")
    fi
    
    # Add custom rules from hook directory
    if [ -f "$custom_patterns_file" ]; then
        local custom_patterns
        custom_patterns=$(load_patterns_from_file "$custom_patterns_file")
        if [ -n "$custom_patterns" ]; then
            if [ -n "$all_patterns" ]; then
                all_patterns="$all_patterns"$'\n'"$custom_patterns"
            else
                all_patterns="$custom_patterns"
            fi
        fi
    fi
    
    # Add user custom rules
    if [ -n "$user_patterns_file" ] && [ -f "$user_patterns_file" ]; then
        local user_patterns
        user_patterns=$(load_patterns_from_file "$user_patterns_file")
        if [ -n "$user_patterns" ]; then
            if [ -n "$all_patterns" ]; then
                all_patterns="$all_patterns"$'\n'"$user_patterns"
            else
                all_patterns="$user_patterns"
            fi
        fi
    fi
    
    if [ -z "$all_patterns" ]; then
        echo "Warning: No patterns loaded" >&2
        return 0
    fi
    
    # Load allowed patterns
    local allowed_patterns=""
    if [ -f "$gitallowed_file" ]; then
        allowed_patterns=$(grep -v '^#' "$gitallowed_file" | grep -v '^[[:space:]]*$' || true)
    fi
    
    # Scan each staged file
    local found_secrets=0
    local output=""
    
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ ! -f "$file" ] && continue
        
        # Get the staged content of the file
        local content
        content=$(git show ":$file" 2>/dev/null) || continue
        
        # Check each pattern
        while IFS= read -r pattern; do
            [ -z "$pattern" ] && continue
            
            # Use grep to find matches
            local matches
            matches=$(echo "$content" | grep -nE "$pattern" 2>/dev/null) || continue
            
            if [ -n "$matches" ]; then
                # Check if matches are allowed
                while IFS= read -r match_line; do
                    local is_allowed=0
                    
                    if [ -n "$allowed_patterns" ]; then
                        while IFS= read -r allowed; do
                            [ -z "$allowed" ] && continue
                            if echo "$match_line" | grep -qE "$allowed" 2>/dev/null; then
                                is_allowed=1
                                break
                            fi
                        done <<< "$allowed_patterns"
                    fi
                    
                    if [ "$is_allowed" -eq 0 ]; then
                        output="$output$file:$match_line"$'\n'
                        found_secrets=1
                    fi
                done <<< "$matches"
            fi
        done <<< "$all_patterns"
    done <<< "$staged_files"
    
    if [ "$found_secrets" -eq 1 ]; then
        echo "$output" >&2
        echo >&2
        echo "[ERROR] Matched one or more prohibited patterns" >&2
        echo >&2
        echo "Possible mitigations:" >&2
        echo "- Mark false positives as allowed by adding regular expressions to .gitallowed at repository's root directory" >&2
        echo "- Use --no-verify if this is a one-time false positive" >&2
        return 1
    fi
    
    return 0
}

case "${OS}" in
    Linux*|Darwin*)
        # Unix-like systems (Linux, macOS)
        RULES_FILE="${SCRIPT_DIR}/../rules/nhsd-rules-deny.txt"
        CUSTOM_RULES_FILE="${SCRIPT_DIR}/../rules/custom-rules.txt"
        GITALLOWED_BASE="${SCRIPT_DIR}/../.gitallowed-base"
        GITALLOWED_USER="${REPO_ROOT}/.gitallowed"
        
        # Clean up any old git-secrets config that might interfere
        # This prevents old cached providers from causing errors
        git config --local --unset-all secrets.providers 2>/dev/null || true
        git config --local --unset-all secrets.patterns 2>/dev/null || true
        
        # Debug: show which rules file we're using
        if [ ! -f "${RULES_FILE}" ]; then
            echo "ERROR: Rules file not found at: ${RULES_FILE}" >&2
            echo "SCRIPT_DIR is: ${SCRIPT_DIR}" >&2
            ls -la "${SCRIPT_DIR}/../rules/" >&2 2>/dev/null || echo "Rules directory not found" >&2
            exit 1
        fi
        
        # Initialize .gitallowed in user's repo if it doesn't exist
        if [ ! -f "${GITALLOWED_USER}" ] && [ -f "${GITALLOWED_BASE}" ]; then
            echo "Initializing .gitallowed file in repository..." >&2
            cp "${GITALLOWED_BASE}" "${GITALLOWED_USER}"
            echo "Created .gitallowed - you can add your own patterns to this file" >&2
        fi
        
        # Resolve user custom rules path
        USER_RULES_FILE=""
        if [ -n "${CUSTOM_RULES_ARG}" ]; then
            if [[ "${CUSTOM_RULES_ARG}" = /* ]]; then
                USER_RULES_FILE="${CUSTOM_RULES_ARG}"
            else
                USER_RULES_FILE="${REPO_ROOT}/${CUSTOM_RULES_ARG}"
            fi
            
            if [ ! -f "${USER_RULES_FILE}" ]; then
                echo "Warning: Custom rules file not found: ${USER_RULES_FILE}" >&2
                USER_RULES_FILE=""
            else
                echo "Loading custom rules from repository: ${USER_RULES_FILE}" >&2
            fi
        fi
        
        # Run the scan directly (avoids git-secrets provider path issues)
        scan_staged_files "${RULES_FILE}" "${CUSTOM_RULES_FILE}" "${USER_RULES_FILE}" "${GITALLOWED_USER}"
        exit $?
        ;;
    MINGW*|CYGWIN*|MSYS*|Windows*)
        # Windows systems (including Git Bash, MINGW, CYGWIN)
        # Use the same cross-platform scan function
        RULES_FILE="${SCRIPT_DIR}/../rules/nhsd-rules-deny.txt"
        CUSTOM_RULES_FILE="${SCRIPT_DIR}/../rules/custom-rules.txt"
        GITALLOWED_BASE="${SCRIPT_DIR}/../.gitallowed-base"
        GITALLOWED_USER="${REPO_ROOT}/.gitallowed"
        
        # Clean up any old git-secrets config that might interfere
        git config --local --unset-all secrets.providers 2>/dev/null || true
        git config --local --unset-all secrets.patterns 2>/dev/null || true
        
        # Debug: show which rules file we're using
        if [ ! -f "${RULES_FILE}" ]; then
            echo "ERROR: Rules file not found at: ${RULES_FILE}" >&2
            echo "SCRIPT_DIR is: ${SCRIPT_DIR}" >&2
            exit 1
        fi
        
        # Initialize .gitallowed in user's repo if it doesn't exist
        if [ ! -f "${GITALLOWED_USER}" ] && [ -f "${GITALLOWED_BASE}" ]; then
            echo "Initializing .gitallowed file in repository..." >&2
            cp "${GITALLOWED_BASE}" "${GITALLOWED_USER}"
            echo "Created .gitallowed - you can add your own patterns to this file" >&2
        fi
        
        # Resolve user custom rules path
        USER_RULES_FILE=""
        if [ -n "${CUSTOM_RULES_ARG}" ]; then
            if [[ "${CUSTOM_RULES_ARG}" = /* ]]; then
                USER_RULES_FILE="${CUSTOM_RULES_ARG}"
            else
                USER_RULES_FILE="${REPO_ROOT}/${CUSTOM_RULES_ARG}"
            fi
            
            if [ ! -f "${USER_RULES_FILE}" ]; then
                echo "Warning: Custom rules file not found: ${USER_RULES_FILE}" >&2
                USER_RULES_FILE=""
            else
                echo "Loading custom rules from repository: ${USER_RULES_FILE}" >&2
            fi
        fi
        
        # Run the scan directly
        scan_staged_files "${RULES_FILE}" "${CUSTOM_RULES_FILE}" "${USER_RULES_FILE}" "${GITALLOWED_USER}"
        exit $?
        ;;
    *)
        echo "Unsupported operating system: ${OS}" >&2
        exit 1
        ;;
esac