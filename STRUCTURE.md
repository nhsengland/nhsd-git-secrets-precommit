# Repository Structure

```
nhsd-git-secrets-precommit/
├── .git-secrets-custom-rules.txt.example  # Example custom rules for users to copy
├── .gitignore                              # Git ignore rules
├── .pre-commit-hooks.yaml                  # Pre-commit hook definition
├── LICENSE                                 # Apache 2.0 license
├── README.md                               # Main documentation
├── example-.pre-commit-config.yaml         # Example configuration for users
├── test.sh                                 # Test script
├── rules/
│   ├── custom-rules.txt.example            # Example custom rules (hook level)
│   └── nhsd-rules-deny.txt                 # Default NHSD security rules
└── scripts/
    ├── git-secrets                         # git-secrets executable
    ├── git-secrets-wrapper.ps1             # PowerShell wrapper (Windows)
    └── git-secrets-wrapper.sh              # Bash wrapper (Linux/Mac)
```

## Key Files

- **`.pre-commit-hooks.yaml`**: Defines the hook for pre-commit framework
- **`scripts/git-secrets-wrapper.sh`**: Main entry point, handles custom rules
- **`rules/nhsd-rules-deny.txt`**: Default patterns for secret detection
- **`README.md`**: Complete usage documentation
- **`test.sh`**: Validates the hook setup

## For Users

Users only need to:
1. Reference this repo in their `.pre-commit-config.yaml`
2. Optionally create `.git-secrets-custom-rules.txt` in their repo
3. Run `pre-commit install`
