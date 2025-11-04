# PowerShell wrapper for NHSD Git Secrets on Windows
# This script provides Windows compatibility for the git-secrets pre-commit hook
#
# Usage: git-secrets-wrapper.ps1 [--custom-rules-file <path>]

param(
    [string]$CustomRulesFile = ""
)

# Parse arguments (support both PowerShell style and bash-style arguments)
$customRulesArg = ""
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--custom-rules-file" -and $i -lt ($args.Count - 1)) {
        $customRulesArg = $args[$i + 1]
        $i++
    }
}

# Use CustomRulesFile parameter if provided, otherwise use parsed arg
if ($CustomRulesFile) {
    $customRulesArg = $CustomRulesFile
}

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    $RepoRoot = Get-Location
}

# Path to the git-secrets executable (use bash on Windows)
$GitSecretsExec = Join-Path $ScriptDir "git-secrets"

# Path to the rules file
$RulesFile = Join-Path (Split-Path -Parent $ScriptDir) "rules\nhsd-rules-deny.txt"
$CustomRulesFile = Join-Path (Split-Path -Parent $ScriptDir) "rules\custom-rules.txt"

try {
    # Run git-secrets through bash (Git for Windows provides bash)
    $bashPath = where.exe bash 2>$null
    if (-not $bashPath) {
        # Try common Git for Windows paths
        $gitPaths = @(
            "${env:ProgramFiles}\Git\bin\bash.exe",
            "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
            "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe"
        )
        
        foreach ($path in $gitPaths) {
            if (Test-Path $path) {
                $bashPath = $path
                break
            }
        }
    }
    
    if (-not $bashPath) {
        Write-Error "Bash not found. Please ensure Git for Windows is installed and bash is in PATH."
        exit 1
    }
    
    # Convert Windows paths to Unix-style for bash
    $UnixGitSecretsExec = $GitSecretsExec -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    $UnixRulesFile = $RulesFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    $UnixCustomRulesFile = $CustomRulesFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    
    # Add the NHSD rules provider
    & $bashPath -c "`"$UnixGitSecretsExec`" --add-provider -- cat `"$UnixRulesFile`""
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add rules provider"
        exit $LASTEXITCODE
    }
    
    # Add custom rules from hook's directory if the file exists
    if (Test-Path $CustomRulesFile) {
        Write-Host "Loading custom rules from hook directory: $CustomRulesFile" -ForegroundColor Yellow
        & $bashPath -c "`"$UnixGitSecretsExec`" --add-provider -- cat `"$UnixCustomRulesFile`""
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to add custom rules provider"
            exit $LASTEXITCODE
        }
    }
    
    # Add custom rules from user's repository if specified
    if ($customRulesArg) {
        # Check if path is absolute or relative
        if ([System.IO.Path]::IsPathRooted($customRulesArg)) {
            $UserRulesFile = $customRulesArg
        } else {
            $UserRulesFile = Join-Path $RepoRoot $customRulesArg
        }
        
        if (Test-Path $UserRulesFile) {
            Write-Host "Loading custom rules from repository: $UserRulesFile" -ForegroundColor Yellow
            $UnixUserRulesFile = $UserRulesFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
            & $bashPath -c "`"$UnixGitSecretsExec`" --add-provider -- cat `"$UnixUserRulesFile`""
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to add user custom rules provider"
                exit $LASTEXITCODE
            }
        } else {
            Write-Warning "Custom rules file not found: $UserRulesFile"
        }
    }
    
    # Run the pre-commit hook
    & $bashPath -c "`"$UnixGitSecretsExec`" --pre_commit_hook"
    exit $LASTEXITCODE
}
catch {
    Write-Error "Error running git-secrets: $($_.Exception.Message)"
    exit 1
}