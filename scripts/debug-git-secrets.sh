#!/usr/bin/env bash
# Debug script for NHSD Git Secrets pre-commit hook
# Run this script from your repository root to diagnose issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=============================================="
echo "NHSD Git Secrets - Debug Information"
echo "=============================================="
echo ""

# System Information
echo -e "${BLUE}[1/8] System Information${NC}"
echo "----------------------------------------------"
echo "OS: $(uname -s)"
echo "OS Version: $(uname -r)"
echo "Machine: $(uname -m)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Shell: $SHELL"
echo "Bash Version: ${BASH_VERSION:-$(bash --version | head -1)}"
echo "Current Directory: $(pwd)"
echo ""

# Git Information
echo -e "${BLUE}[2/8] Git Information${NC}"
echo "----------------------------------------------"
echo "Git Version: $(git --version)"
echo "Git Repo Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'NOT IN A GIT REPO')"
echo ""

# Check for git-secrets in config
echo -e "${BLUE}[3/8] Git Secrets Configuration${NC}"
echo "----------------------------------------------"
echo "Local secrets.providers:"
git config --local --get-all secrets.providers 2>/dev/null || echo "  (none)"
echo ""
echo "Local secrets.patterns:"
git config --local --get-all secrets.patterns 2>/dev/null || echo "  (none)"
echo ""
echo "Global secrets.providers:"
git config --global --get-all secrets.providers 2>/dev/null || echo "  (none)"
echo ""
echo "Global secrets.patterns:"
git config --global --get-all secrets.patterns 2>/dev/null || echo "  (none)"
echo ""

# Check for global git-secrets installation
echo -e "${BLUE}[4/8] Global git-secrets Installation${NC}"
echo "----------------------------------------------"
if command -v git-secrets &> /dev/null; then
    echo -e "${YELLOW}WARNING: git-secrets is installed globally${NC}"
    echo "Location: $(which git-secrets)"
    echo "This may conflict with the pre-commit hook"
else
    echo -e "${GREEN}OK: git-secrets is NOT installed globally${NC}"
fi
echo ""

# Check pre-commit installation
echo -e "${BLUE}[5/8] Pre-commit Installation${NC}"
echo "----------------------------------------------"
if command -v pre-commit &> /dev/null; then
    echo "Pre-commit Version: $(pre-commit --version)"
    echo "Pre-commit Location: $(which pre-commit)"
else
    echo -e "${RED}ERROR: pre-commit is not installed${NC}"
fi
echo ""

# Check pre-commit cache
echo -e "${BLUE}[6/8] Pre-commit Cache${NC}"
echo "----------------------------------------------"
CACHE_DIR="${HOME}/.cache/pre-commit"
if [ -d "$CACHE_DIR" ]; then
    echo "Cache directory: $CACHE_DIR"
    echo "Cache size: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"
    echo ""
    echo "Looking for nhsd-git-secrets-precommit in cache..."
    FOUND_REPOS=$(find "$CACHE_DIR" -type d -name "repo*" 2>/dev/null | head -5)
    if [ -n "$FOUND_REPOS" ]; then
        for repo in $FOUND_REPOS; do
            if [ -f "$repo/scripts/git-secrets-wrapper.sh" ]; then
                echo -e "${GREEN}Found hook at: $repo${NC}"
                echo "  Scripts dir exists: $([ -d "$repo/scripts" ] && echo 'YES' || echo 'NO')"
                echo "  Rules dir exists: $([ -d "$repo/rules" ] && echo 'YES' || echo 'NO')"
                echo "  Rules file exists: $([ -f "$repo/rules/nhsd-rules-deny.txt" ] && echo 'YES' || echo 'NO')"
                if [ -f "$repo/rules/nhsd-rules-deny.txt" ]; then
                    echo "  Rules file line count: $(wc -l < "$repo/rules/nhsd-rules-deny.txt" | tr -d ' ')"
                fi
            fi
        done
    else
        echo "No cached repos found"
    fi
else
    echo "Cache directory does not exist: $CACHE_DIR"
fi
echo ""

# Check .git/hooks
echo -e "${BLUE}[7/8] Git Hooks${NC}"
echo "----------------------------------------------"
HOOKS_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/.git/hooks"
if [ -d "$HOOKS_DIR" ]; then
    echo "Hooks directory: $HOOKS_DIR"
    echo ""
    if [ -f "$HOOKS_DIR/pre-commit" ]; then
        echo "pre-commit hook exists:"
        echo "  Size: $(wc -c < "$HOOKS_DIR/pre-commit" | tr -d ' ') bytes"
        echo "  First 5 lines:"
        head -5 "$HOOKS_DIR/pre-commit" | sed 's/^/    /'
    else
        echo "No pre-commit hook found"
    fi
else
    echo "Not in a git repository or .git/hooks not found"
fi
echo ""

# Check grep compatibility
echo -e "${BLUE}[8/8] Grep Compatibility${NC}"
echo "----------------------------------------------"
echo "Grep version:"
grep --version 2>&1 | head -1 || echo "Unknown"
echo ""
echo "Testing pattern matching..."

# Test patterns
test_pattern() {
    local name="$1"
    local pattern="$2"
    local test_string="$3"
    local should_match="$4"
    
    if echo "$test_string" | grep -qE "$pattern" 2>/dev/null; then
        if [ "$should_match" = "yes" ]; then
            echo -e "  ${GREEN}✓${NC} $name - matched as expected"
        else
            echo -e "  ${RED}✗${NC} $name - matched but shouldn't have"
        fi
    else
        if [ "$should_match" = "no" ]; then
            echo -e "  ${GREEN}✓${NC} $name - no match as expected"
        else
            echo -e "  ${RED}✗${NC} $name - should have matched but didn't"
        fi
    fi
}

test_pattern "Password pattern" 'password\s*[=:]\s*.+' 'password = secret123' "yes"
test_pattern "Token pattern" 'token\s*[=:]\s*.+' 'token = abc123' "yes"
test_pattern "Private key" '-----BEGIN.*(PRIVATE|RSA).*-----' '-----BEGIN RSA PRIVATE KEY-----' "yes"
test_pattern "Slack webhook" 'https://hooks.slack.com/services/T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8,12}/[a-zA-Z0-9_]{24}' 'https://hooks.slack.com/services/T12345678/B12345678/XXXXXXXXXXXXXXXXXXXXXXXX' "yes"
test_pattern "Clean text (no match)" 'password\s*[=:]\s*.+' 'This is clean text' "no"

echo ""
echo "=============================================="
echo "Debug information collection complete"
echo "=============================================="
echo ""
echo "If you're still having issues, please share the output above."
echo ""
echo -e "${YELLOW}Suggested fixes:${NC}"
echo "1. Clear pre-commit cache: pre-commit clean"
echo "2. Remove old git-secrets config:"
echo "   git config --local --unset-all secrets.providers"
echo "   git config --local --unset-all secrets.patterns"
echo "   git config --global --unset-all secrets.providers"
echo "   git config --global --unset-all secrets.patterns"
echo "3. Reinstall pre-commit: pre-commit install"
echo "4. Run again: pre-commit run --all-files"
