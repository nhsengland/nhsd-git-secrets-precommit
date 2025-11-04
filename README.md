# NHSD Git Secrets Pre-commit Hook

A standalone pre-commit hook for NHSD Git Secrets scanning that works across Mac, Linux, and Windows.

## Features

- Cross-platform compatibility (Mac, Linux, Windows)
- Standalone package that can be used with any repository
- Uses the established NHSD rules for secret detection
- Integrates seamlessly with pre-commit framework

## Usage

Add this to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/your-org/nhsd-git-secrets-precommit
    rev: v1.0.0
    hooks:
      - id: nhsd-git-secrets
```

Then install and run:

```bash
pre-commit install
pre-commit run --all-files
```

## Custom Configuration

You can customize the git-secrets scanning in several ways:

### 1. Add Custom Rules from Your Repository (Recommended)

The most flexible approach - add a custom rules file to **your own repository** and reference it in your `.pre-commit-config.yaml`:

1. Create a custom rules file in your repository (e.g., `.git-secrets-custom-rules.txt`):

   ```text
   # My company's API key pattern
   mycompany_api_[0-9a-zA-Z]{40}
   
   # Internal secret format
   INTERNAL_SECRET:\s*.+
   
   # Database passwords
   DB_PASSWORD\s*=\s*.+
   ```

2. Reference it in your `.pre-commit-config.yaml`:

   ```yaml
   repos:
     - repo: https://github.com/your-org/nhsd-git-secrets-precommit
       rev: v1.0.0
       hooks:
         - id: nhsd-git-secrets
           args: ['--custom-rules-file', '.git-secrets-custom-rules.txt']
   ```

   Or using an absolute path:

   ```yaml
   repos:
     - repo: https://github.com/your-org/nhsd-git-secrets-precommit
       rev: v1.0.0
       hooks:
         - id: nhsd-git-secrets
           args: ['--custom-rules-file', '/path/to/your/custom-rules.txt']
   ```

3. Add the custom rules file to your repository:

   ```bash
   git add .git-secrets-custom-rules.txt
   git commit -m "Add custom git-secrets rules"
   ```

**Important:** Your custom rules file should **not** contain actual secrets - only the regex patterns to detect them!

### 2. Add Rules to the Default Rules File

Add your custom regex patterns directly to `rules/nhsd-rules-deny.txt` in the hook repository (less common):

```bash
echo 'your-custom-regex-pattern' >> rules/nhsd-rules-deny.txt
```

### 3. Create a Custom Rules File in the Hook Repository

To add custom rules that apply to all repositories using this hook:

1. Copy the example file:

   ```bash
   cp rules/custom-rules.txt.example rules/custom-rules.txt
   ```

2. Add your custom patterns to `rules/custom-rules.txt`:

   ```text
   # Your custom patterns (one per line)
   mycompany_api_key_[0-9a-zA-Z]{40}
   internal_secret:\s*.+
   ```

3. The wrapper script will automatically detect and load `rules/custom-rules.txt` if it exists

### 4. Use .gitallowed for Exceptions

**The hook automatically creates a `.gitallowed` file in your repository on first run.** This file contains common false-positive patterns (like `127.0.0.1`, SVG files, terraform state, etc.) that are automatically excluded from scanning.

You can add your own patterns to `.gitallowed` to exclude specific files or patterns:

```text
# Exclude terraform state files
.*terraform.tfstate.*:*

# Exclude specific test files  
tests/fixtures/sample-data.json:*

# Exclude a specific line in a file
config/example.yaml:12

# Exclude files with test credentials
.*test.*password.*:*
```

**Important:** The `.gitallowed` file will be automatically created on the first pre-commit run. You should commit this file to your repository so all team members use the same exceptions.

### 5. Combine Pre-commit Config Options

You can combine the custom rules file with other pre-commit options:

```yaml
repos:
  - repo: https://github.com/your-org/nhsd-git-secrets-precommit
    rev: v1.0.0
    hooks:
      - id: nhsd-git-secrets
        # Add custom rules from your repository
        args: ['--custom-rules-file', '.git-secrets-custom-rules.txt']
        # Only scan specific file types
        files: \.(py|js|yaml|json|sh)$
        # Exclude certain directories
        exclude: ^(docs|tests/fixtures|vendor)/
```

For more details, see the [NHSD documentation](https://github.com/NHSDigital/software-engineering-quality-framework/blob/main/tools/nhsd-git-secrets/README-linux-workstation.md#custom-configuration-per-repo--per-service-team).

## Quick Start Example

Here's a complete example of setting up custom rules in your repository:

1. **Add the hook to your `.pre-commit-config.yaml`:**

   ```yaml
   repos:
     - repo: https://github.com/your-org/nhsd-git-secrets-precommit
       rev: v1.0.0
       hooks:
         - id: nhsd-git-secrets
           args: ['--custom-rules-file', '.git-secrets-custom-rules.txt']
   ```

2. **Create `.git-secrets-custom-rules.txt` in your repository root:**

   ```text
   # Company API keys (format: company_key_XXXXX...)
   company_api_key_[0-9a-zA-Z]{40}
   
   # Internal service tokens
   INTERNAL_TOKEN:\s*["']?[0-9a-zA-Z_-]{32,}["']?
   
   # Database passwords in config files
   db_password\s*[:=]\s*["'].+["']
   ```

3. **Add and commit the rules file:**

   ```bash
   git add .git-secrets-custom-rules.txt .pre-commit-config.yaml
   git commit -m "Add git-secrets with custom rules"
   ```

4. **Install pre-commit (if not already installed):**

   ```bash
   pip install pre-commit
   pre-commit install
   ```

Now every commit will be scanned with both the default NHSD rules and your custom rules!

## Requirements

- Git
- Bash (for Linux/Mac) or Git for Windows (for Windows)
- Pre-commit framework

## What it does

This hook scans your commits for:

- Slack webhook URLs
- AWS keys and secrets
- GitHub tokens
- Private keys
- Database connection strings
- API keys
- Passwords
- And other sensitive patterns defined in the NHSD rules

## Platform-specific notes

### Windows

This hook requires Git for Windows to be installed, as it uses the bash environment provided by Git for Windows to run the git-secrets tool.

### Linux/Mac

Works with standard bash environments.

## Rules

The rules are based on NHSD security guidelines and include patterns for detecting:

- Cloud service credentials
- API tokens
- Private keys
- Database credentials
- IP addresses and hostnames that might be sensitive
- Client secrets and passwords

## Troubleshooting

### Hook not running

Verify your `.pre-commit-config.yaml` syntax:

```bash
pre-commit validate-config
pre-commit run nhsd-git-secrets --all-files
```

### Permission denied errors (Linux/Mac)

Make sure the scripts are executable:

```bash
chmod +x scripts/git-secrets-wrapper.sh scripts/git-secrets
```

### "Command not found" errors on Windows

Make sure Git for Windows is installed and that `bash` is available in your PATH.

### False positives

If you have legitimate content that matches a pattern:

1. Use the `--no-verify` flag to skip the hook for a specific commit:

   ```bash
   git commit --no-verify -m "Your commit message"
   ```

2. Add the content to `.gitallowed` file in your repository root

3. Use a comment to mark safe content (if the file format supports it)

### Custom rules file not found

If you specify `--custom-rules-file` but get a warning:

- Ensure the path is relative to your repository root, or use an absolute path
- Verify the file exists: `ls -la .git-secrets-custom-rules.txt`
- Check the file name matches exactly what's in your `.pre-commit-config.yaml`

## Testing

Run the test script to verify the hook setup:

```bash
./test.sh
```

## Development

To modify the default rules, edit `rules/nhsd-rules-deny.txt` and follow the git-secrets pattern format (one regex pattern per line).

## License

This project follows the same licensing as the original git-secrets tool (Apache 2.0).
