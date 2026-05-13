param(
    [Parameter(Position = 0)]
    [string]$Message
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Text) {
    Write-Error $Text
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is not installed or not available in PATH."
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Fail "Current directory is not inside a Git repository."
}

Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = Read-Host "Commit message"
}

if ([string]::IsNullOrWhiteSpace($Message)) {
    Fail "Commit message is required."
}

$currentBranch = git branch --show-current
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    Fail "Could not determine the current Git branch."
}

git add .

$hasChanges = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace(($hasChanges | Out-String).Trim())) {
    Write-Host "No changes to commit."
    exit 0
}

git commit -m $Message
git push origin $currentBranch

Write-Host ""
Write-Host "Published successfully."
Write-Host "Branch: $currentBranch"
