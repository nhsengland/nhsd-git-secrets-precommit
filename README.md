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

## Development

To modify the rules, edit `rules/nhsd-rules-deny.txt` and follow the git-secrets pattern format.

## License

This project follows the same licensing as the original git-secrets tool (Apache 2.0).