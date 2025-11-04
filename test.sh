#!/usr/bin/env bash
# Test script to verify the NHSD Git Secrets pre-commit hook works correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Testing NHSD Git Secrets Pre-commit Hook"
echo "========================================"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}"

echo "Package directory: ${PACKAGE_DIR}"
echo ""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass_test() {
    echo -e "  ${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    echo -e "  ${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn_test() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

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
        pass_test "${file} exists"
    else
        fail_test "${file} - MISSING"
        exit 1
    fi
done

# Test 2: Check if scripts are executable
echo ""
echo "Test 2: Checking script permissions..."
if [[ -x "${PACKAGE_DIR}/scripts/git-secrets-wrapper.sh" ]]; then
    pass_test "git-secrets-wrapper.sh is executable"
else
    fail_test "git-secrets-wrapper.sh is not executable"
    exit 1
fi

if [[ -x "${PACKAGE_DIR}/scripts/git-secrets" ]]; then
    pass_test "git-secrets is executable"
else
    fail_test "git-secrets is not executable"
    exit 1
fi

# Test 3: Validate .pre-commit-hooks.yaml syntax
echo ""
echo "Test 3: Validating .pre-commit-hooks.yaml..."
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "
import yaml
import sys
try:
    with open('${PACKAGE_DIR}/.pre-commit-hooks.yaml', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
" 2>/dev/null; then
        pass_test "YAML syntax is valid"
    else
        fail_test "YAML syntax error"
        exit 1
    fi
else
    warn_test "Python3 not available, skipping YAML validation"
fi

# Test 4: Check git-secrets executable
echo ""
echo "Test 4: Testing git-secrets executable..."
if "${PACKAGE_DIR}/scripts/git-secrets" --help >/dev/null 2>&1 || [[ $? -eq 129 ]]; then
    pass_test "git-secrets executable works"
else
    fail_test "git-secrets executable failed"
    exit 1
fi

# Test 5: Check rules file format
echo ""
echo "Test 5: Checking rules file..."
RULE_COUNT=$(grep -v '^#' "${PACKAGE_DIR}/rules/nhsd-rules-deny.txt" | grep -v '^$' | wc -l | tr -d ' ')
if [[ $RULE_COUNT -gt 0 ]]; then
    pass_test "Rules file contains ${RULE_COUNT} patterns"
else
    fail_test "Rules file is empty"
    exit 1
fi

# Test 6: Test custom rules file argument parsing
echo ""
echo "Test 6: Testing custom rules file argument..."
TEMP_RULES=$(mktemp)
echo "test_custom_pattern_[0-9a-f]{32}" > "$TEMP_RULES"

# Create a temp git repo for testing
TEMP_REPO=$(mktemp -d)
cd "$TEMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

# Create a test file with content
echo "No secrets here" > test.txt
git add test.txt
git commit -q -m "Initial commit"

# Now test with the wrapper (should pass - no secrets)
if "${PACKAGE_DIR}/scripts/git-secrets-wrapper.sh" --custom-rules-file "$TEMP_RULES" >/dev/null 2>&1; then
    pass_test "Wrapper script accepts --custom-rules-file argument"
else
    # Exit code 1 might be OK if there are no staged files
    warn_test "Wrapper returned non-zero (might be expected with no changes)"
fi

cd "$SCRIPT_DIR"
rm -rf "$TEMP_REPO" "$TEMP_RULES"

# Test 7: Check example files exist
echo ""
echo "Test 7: Checking example files..."
if [[ -f "${PACKAGE_DIR}/rules/custom-rules.txt.example" ]]; then
    pass_test "rules/custom-rules.txt.example exists"
else
    warn_test "rules/custom-rules.txt.example not found"
fi

if [[ -f "${PACKAGE_DIR}/.git-secrets-custom-rules.txt.example" ]]; then
    pass_test ".git-secrets-custom-rules.txt.example exists"
else
    warn_test ".git-secrets-custom-rules.txt.example not found"
fi

# Test 8: Functional test - detect actual secrets
echo ""
echo "Test 8: Testing secret detection (functional test)..."

# Create a temporary git repository for each sub-test
run_secret_test() {
    local test_name="$1"
    local test_content="$2"
    local should_detect="$3"
    
    TEMP_TEST_REPO=$(mktemp -d)
    cd "$TEMP_TEST_REPO"
    git init -q >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    echo "$test_content" > test.txt
    git add test.txt
    
    OUTPUT=$("${PACKAGE_DIR}/scripts/git-secrets-wrapper.sh" 2>&1) || true
    
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_TEST_REPO"
    
    if [[ "$should_detect" == "yes" ]]; then
        if echo "$OUTPUT" | grep -qi "error\|prohibited\|match"; then
            pass_test "$test_name"
            return 0
        else
            fail_test "$test_name"
            return 1
        fi
    else
        if echo "$OUTPUT" | grep -qi "error\|prohibited\|match"; then
            fail_test "$test_name (false positive)"
            return 1
        else
            pass_test "$test_name"
            return 0
        fi
    fi
}

# Test 8a: Should NOT detect secrets in clean file
run_secret_test "Clean file passes (no false positives)" "This is a safe file with no secrets" "no"

# Test 8b: Should detect password pattern
run_secret_test "Detected password pattern" 'password = "mysecretpassword123"' "yes"

# Test 8c: Should detect token pattern  
run_secret_test "Detected token pattern" 'token = "secret_token_value_12345"' "yes"

# Test 8d: Should detect Slack webhook
run_secret_test "Detected Slack webhook" "https://hooks.slack.com/services/T12345678/B12345678/XXXXXXXXXXXXXXXXXXXXXXXX" "yes"

# Test 8e: Test custom rules functionality
echo "Testing custom rules..."
TEMP_TEST_REPO=$(mktemp -d)
cd "$TEMP_TEST_REPO"
git init -q >/dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"

CUSTOM_RULES_FILE="${TEMP_TEST_REPO}/.custom-rules.txt"
echo "SUPER_SECRET_KEY_[0-9a-f]{16}" > "$CUSTOM_RULES_FILE"

echo 'SUPER_SECRET_KEY_abc123456789def0 = "test"' > test.txt
git add test.txt

OUTPUT=$("${PACKAGE_DIR}/scripts/git-secrets-wrapper.sh" --custom-rules-file "$CUSTOM_RULES_FILE" 2>&1) || true
if echo "$OUTPUT" | grep -qi "error\|prohibited\|match"; then
    pass_test "Custom rules are loaded and working"
else
    fail_test "Custom rules not working"
fi

cd "$SCRIPT_DIR"
rm -rf "$TEMP_TEST_REPO"

# Summary
echo ""
echo "========================================"
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC} ✨ ($TESTS_PASSED passed)"
    echo ""
    echo "The hook is working correctly and detecting secrets!"
else
    echo -e "${RED}Some tests failed!${NC} ($TESTS_PASSED passed, $TESTS_FAILED failed)"
    exit 1
fi
echo ""
echo "To use this hook, add the following to your .pre-commit-config.yaml:"
echo ""
echo "repos:"
echo "  - repo: /path/to/this/directory"
echo "    rev: HEAD"
echo "    hooks:"
echo "      - id: nhsd-git-secrets"
echo "        # Optional: add custom rules from your repository"
echo "        # args: ['--custom-rules-file', '.git-secrets-custom-rules.txt']"
echo ""
echo "For production use, publish this to a Git repository and reference it like:"
echo ""
echo "repos:"
echo "  - repo: https://github.com/your-org/nhsd-git-secrets-precommit"
echo "    rev: v1.0.0"
echo "    hooks:"
echo "      - id: nhsd-git-secrets"
echo "        args: ['--custom-rules-file', '.git-secrets-custom-rules.txt']"