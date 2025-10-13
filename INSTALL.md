# Installation and Usage Guide

## Quick Start

### 1. Using the package directly from GitHub (Recommended for production)

Once published to GitHub, add this to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/your-org/nhsd-git-secrets-precommit
    rev: v1.0.0  # Use the latest release
    hooks:
      - id: nhsd-git-secrets
```

### 2. Using a local copy (For testing/development)

If you have a local copy of this package:

```yaml
repos:
  - repo: /path/to/nhsd-git-secrets-precommit
    rev: HEAD
    hooks:
      - id: nhsd-git-secrets
```

### 3. Installing and running

```bash
# Install pre-commit if not already installed
pip install pre-commit

# Install the hooks
pre-commit install

# Run on all files (optional)
pre-commit run --all-files

# Run only git-secrets
pre-commit run nhsd-git-secrets --all-files
```

## Platform Requirements

### Linux/macOS
- Bash shell
- Git

### Windows
- Git for Windows (includes Bash)
- PowerShell (usually pre-installed)

## What gets scanned

The hook scans for these types of secrets:

- **Slack webhooks**: `https://hooks.slack.com/services/...`
- **AWS MWS keys**: `amzn.mws.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **GitHub tokens**: `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` prefixed tokens
- **Slack tokens**: `xox[baprs]-...`
- **Private keys**: `-----BEGIN PRIVATE KEY-----`
- **Google API keys**: `AIza...`
- **Service account files**: `"type": "service_account"`
- **RDS endpoints**: `*.rds.amazonaws.com`
- **DynamoDB endpoints**: `*.dynamodb.amazonaws.com`
- **ElasticSearch endpoints**: `*.es.amazonaws.com`
- **ElastiCache endpoints**: `*.cache.amazonaws.com`
- **SSL certificates**: `-----BEGIN CERTIFICATE-----`
- **IPv6 addresses**
- **IPv4 addresses**
- **Client secrets**: Pattern matching client secret formats
- **Passwords**: Basic password pattern matching

## Customizing Rules

To add custom rules, edit `rules/nhsd-rules-deny.txt`. Each line should contain a regular expression pattern.

Example:
```
# Add a custom API key pattern
myapi_[0-9a-fA-F]{32}
```

## Troubleshooting

### "Command not found" errors on Windows
Make sure Git for Windows is installed and that the `bash` command is available in your PATH.

### Permission denied errors
Make sure the scripts are executable:
```bash
chmod +x scripts/git-secrets-wrapper.sh
chmod +x scripts/git-secrets
```

### Hook not running
Verify your `.pre-commit-config.yaml` syntax:
```bash
pre-commit validate-config
```

### False positives
If you have legitimate content that matches the patterns, you can:

1. Add an ignore comment: `# git-secrets: ignore`
2. Add an allowed pattern to your git config:
   ```bash
   git secrets --add --allowed 'your-allowed-pattern'
   ```

## Development

### Testing the hook locally
```bash
./test.sh
```

### Adding new rules
1. Edit `rules/nhsd-rules-deny.txt`
2. Test with `./test.sh`
3. Commit and push changes

### Publishing releases
1. Update `VERSION` file
2. Create a git tag: `git tag v1.0.1`
3. Push the tag: `git push origin v1.0.1`
4. Update your `.pre-commit-config.yaml` files to use the new version

## Integration Examples

### Full example `.pre-commit-config.yaml`
```yaml
repos:
  # Secrets scanning
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.24.2
    hooks:
      - id: gitleaks

  - repo: https://github.com/your-org/nhsd-git-secrets-precommit
    rev: v1.0.0
    hooks:
      - id: nhsd-git-secrets

  # Code formatting and linting
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.13.2
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # General hooks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-json
      - id: check-toml

  # Security
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

## Support

For issues and questions:
1. Check this guide first
2. Run `./test.sh` to verify your setup
3. Check the git-secrets documentation
4. Open an issue in the repository