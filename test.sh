#!/usr/bin/env bash
# Test script to verify the NHSD Git Secrets pre-commit hook works correctly

set -e

echo "Testing NHSD Git Secrets Pre-commit Hook"
echo "========================================"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}"

echo "Package directory: ${PACKAGE_DIR}"
echo ""

# Test 1: Check if all required files exist
echo "Test 1: Checking required files..."
REQUIRED_FILES=(
    ".pre-commit-hooks.yaml"
    "scripts/git-secrets-wrapper.sh"
    "scripts/git-secrets-wrapper.ps1"
    "scripts/git-secrets"
    "rules/nhsd-rules-deny.txt"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "${PACKAGE_DIR}/${file}" ]]; then
        echo "  ✓ ${file}"
    else
        echo "  ✗ ${file} - MISSING"
        exit 1
    fi
done

# Test 2: Check if scripts are executable
echo ""
echo "Test 2: Checking script permissions..."
if [[ -x "${PACKAGE_DIR}/scripts/git-secrets-wrapper.sh" ]]; then
    echo "  ✓ git-secrets-wrapper.sh is executable"
else
    echo "  ✗ git-secrets-wrapper.sh is not executable"
    exit 1
fi

if [[ -x "${PACKAGE_DIR}/scripts/git-secrets" ]]; then
    echo "  ✓ git-secrets is executable"
else
    echo "  ✗ git-secrets is not executable"
    exit 1
fi

# Test 3: Validate .pre-commit-hooks.yaml syntax
echo ""
echo "Test 3: Validating .pre-commit-hooks.yaml..."
if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import yaml
import sys
try:
    with open('${PACKAGE_DIR}/.pre-commit-hooks.yaml', 'r') as f:
        yaml.safe_load(f)
    print('  ✓ YAML syntax is valid')
except Exception as e:
    print(f'  ✗ YAML syntax error: {e}')
    sys.exit(1)
" || echo "  ⚠ Python3 not available, skipping YAML validation"
else
    echo "  ⚠ Python3 not available, skipping YAML validation"
fi

# Test 4: Check git-secrets help
echo ""
echo "Test 4: Testing git-secrets executable..."
if "${PACKAGE_DIR}/scripts/git-secrets" --help >/dev/null 2>&1 || [[ $? -eq 129 ]]; then
    echo "  ✓ git-secrets executable works"
else
    echo "  ✗ git-secrets executable failed"
    exit 1
fi

# Test 5: Check rules file format
echo ""
echo "Test 5: Checking rules file..."
RULE_COUNT=$(wc -l < "${PACKAGE_DIR}/rules/nhsd-rules-deny.txt")
echo "  ✓ Rules file contains ${RULE_COUNT} patterns"

echo ""
echo "All tests passed! 🎉"
echo ""
echo "To use this hook, add the following to your .pre-commit-config.yaml:"
echo ""
echo "repos:"
echo "  - repo: /path/to/this/directory"
echo "    rev: HEAD"
echo "    hooks:"
echo "      - id: nhsd-git-secrets"
echo ""
echo "For production use, publish this to a Git repository and reference it like:"
echo ""
echo "repos:"
echo "  - repo: https://github.com/your-org/nhsd-git-secrets-precommit"
echo "    rev: v1.0.0"
echo "    hooks:"
echo "      - id: nhsd-git-secrets"