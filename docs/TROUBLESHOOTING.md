# NHSD Git Secrets - Troubleshooting Guide

This guide helps diagnose and fix issues with the NHSD Git Secrets pre-commit hook.

## Quick Fix (Try This First)

Run these commands in your repository:

```bash
# 1. Remove old git-secrets configuration
git config --local --unset-all secrets.providers 2>/dev/null || true
git config --local --unset-all secrets.patterns 2>/dev/null || true
git config --global --unset-all secrets.providers 2>/dev/null || true
git config --global --unset-all secrets.patterns 2>/dev/null || true

# 2. Clear pre-commit cache
pre-commit clean

# 3. Reinstall and run
pre-commit install
pre-commit run --all-files --verbose
```

---

## Running the Debug Script

We've provided a debug script to collect information about your environment:

```bash
# Download and run the debug script
curl -sSL https://raw.githubusercontent.com/nhsengland/nhsd-git-secrets-precommit/main/scripts/debug-git-secrets.sh | bash
```

Or if you have the repo cloned:

```bash
./scripts/debug-git-secrets.sh
```

**Please share the output if you need help!**

---

## Common Errors and Solutions

### Error: `empty (sub)expression`

```
fatal: command line, '...patterns...': empty (sub)expression
```

**Cause:** Old git-secrets patterns are stored in your git config and contain regex syntax that doesn't work on your system.

**Solution:**
```bash
git config --local --unset-all secrets.providers
git config --local --unset-all secrets.patterns
git config --global --unset-all secrets.providers
git config --global --unset-all secrets.patterns
pre-commit clean
pre-commit run --all-files --verbose
```

---

### Error: `No such file or directory: nhsd-rules-deny.txt`

```
cat: nhsd-git-secrets/nhsd-rules-deny.txt: No such file or directory
```

**Cause:** Old cached version of the hook is being used, or the cache is corrupted.

**Solution:**
```bash
# Nuclear option - clear entire cache
rm -rf ~/.cache/pre-commit
pre-commit install
pre-commit run --all-files --verbose
```

---

### Error: `git-secrets: command not found`

**Cause:** The hook is trying to call a globally installed git-secrets that doesn't exist.

**Solution:** This is usually caused by old git config. Run:
```bash
git config --local --unset-all secrets.providers
git config --global --unset-all secrets.providers
```

---

### Hook Not Running at All

**Check if pre-commit is installed correctly:**
```bash
# Check pre-commit is installed
pre-commit --version

# Check hook is installed in your repo
cat .git/hooks/pre-commit

# Verify your .pre-commit-config.yaml references the hook
cat .pre-commit-config.yaml
```

---

## Verbose Debugging

### Get More Output from Pre-commit

```bash
# Verbose mode
pre-commit run --all-files --verbose

# Debug mode (shows internal pre-commit operations)
PRE_COMMIT_DEBUG=1 pre-commit run --all-files
```

### Run the Wrapper Script Directly

Find where pre-commit cached the hook and run it manually:

```bash
# Find the cached hook
HOOK_DIR=$(find ~/.cache/pre-commit -type f -name "git-secrets-wrapper.sh" 2>/dev/null | head -1 | xargs dirname)
echo "Found hook at: $HOOK_DIR"

# Check files exist
ls -la "$HOOK_DIR"
ls -la "$HOOK_DIR/../rules/"

# Run with bash debug mode (shows every command)
cd /path/to/your/repo
bash -x "$HOOK_DIR/git-secrets-wrapper.sh"
```

### Test Pattern Matching

Check if your system's grep can handle the patterns:

```bash
# Test password pattern
echo 'password = secret123' | grep -E 'password\s*[=:]\s*.+'

# Test private key pattern  
echo '-----BEGIN RSA PRIVATE KEY-----' | grep -E '-----BEGIN.*(PRIVATE|RSA).*-----'

# Test Slack webhook
echo 'https://hooks.slack.com/services/T12345678/B12345678/XXXXXXXXXXXXXXXXXXXXXXXX' | grep -E 'https://hooks.slack.com/services/T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8,12}/[a-zA-Z0-9_]{24}'
```

---

## Mac-Specific Issues

### BSD vs GNU grep

Mac uses BSD grep by default, which has some differences from GNU grep.

**Check your grep version:**
```bash
grep --version
```

If patterns aren't matching, try installing GNU grep:
```bash
brew install grep
# Then use ggrep instead of grep, or add to PATH
```

### Old Bash Version

Mac ships with an old version of Bash (3.x). The hook should work, but check:
```bash
bash --version
```

---

## Check for Conflicting Installations

### Global git-secrets

If you have git-secrets installed globally, it might conflict:

```bash
# Check if installed
which git-secrets

# Check if it has hooks installed
ls -la .git/hooks/ | grep -E "pre-commit|commit-msg"
```

If you see git-secrets hooks in `.git/hooks/`, remove them:
```bash
rm .git/hooks/pre-commit
rm .git/hooks/commit-msg
rm .git/hooks/prepare-commit-msg
pre-commit install
```

---

## Simulate Fresh Install

Test with a completely fresh setup:

```bash
# 1. Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 2. Clone a test repo (or init new one)
git init test-repo
cd test-repo
git config user.email "test@example.com"
git config user.name "Test"

# 3. Create pre-commit config
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/nhsengland/nhsd-git-secrets-precommit
    rev: main
    hooks:
      - id: nhsd-git-secrets
EOF

# 4. Install and test
pre-commit install
echo "password = secret123" > test.txt
git add test.txt
pre-commit run --all-files

# 5. Clean up
cd ~
rm -rf "$TEMP_DIR"
```

---

## Still Having Issues?

1. Run the debug script and save the output
2. Note the exact error message
3. Note your operating system and version
4. Share this information with the team

**Debug script:**
```bash
curl -sSL https://raw.githubusercontent.com/nhsengland/nhsd-git-secrets-precommit/main/scripts/debug-git-secrets.sh | bash > debug-output.txt 2>&1
```
