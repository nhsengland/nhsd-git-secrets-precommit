# PowerShell wrapper for NHSD Git Secrets on Windows
# This script provides Windows compatibility for the git-secrets pre-commit hook

param(
    [string[]]$Files
)

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = git rev-parse --show-toplevel

# Path to the git-secrets executable (use bash on Windows)
$GitSecretsExec = Join-Path $ScriptDir "git-secrets"

# Path to the rules file
$RulesFile = Join-Path (Split-Path -Parent $ScriptDir) "rules\nhsd-rules-deny.txt"

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
    
    # Add the NHSD rules provider
    & $bashPath -c "`"$UnixGitSecretsExec`" --add-provider -- cat `"$UnixRulesFile`""
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add rules provider"
        exit $LASTEXITCODE
    }
    
    # Run the pre-commit hook
    & $bashPath -c "`"$UnixGitSecretsExec`" --pre_commit_hook"
    exit $LASTEXITCODE
}
catch {
    Write-Error "Error running git-secrets: $($_.Exception.Message)"
    exit 1
}