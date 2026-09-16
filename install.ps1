<#
.SYNOPSIS
    Installs git-account-switcher (gswitch) to the local user environment.
.DESCRIPTION
    1. Copies executable scripts to $HOME\.local\bin
    2. Ensures $HOME\.local\bin is present in User PATH
    3. Deploys accounts configuration to $HOME\.config\git-account-switcher\accounts.json
    4. Auto-detects and syncs accounts from GitHub CLI (if available)
    5. Configures Git credential helper to use GitHub CLI
    6. Sets up git aliases (git who, git switch-acc)
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " git-account-switcher (gswitch) Installer" -ForegroundColor Cyan
Write-Host " Fast Multi-Account GitHub & Git Identity Switcher" -ForegroundColor DarkCyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Dependency checks
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Git is not installed or not in PATH." -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Git is available." -ForegroundColor Green

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] GitHub CLI (gh) is not installed or not in PATH." -ForegroundColor Red
    Write-Host "        Please install GitHub CLI from https://cli.github.com" -ForegroundColor Gray
    exit 1
}
Write-Host "  [OK] GitHub CLI (gh) is available." -ForegroundColor Green

# 2. Setup target bin directory
$binDir = "$HOME\.local\bin"
Write-Host "[2/5] Preparing installation directory ($binDir)..." -ForegroundColor Yellow
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

$sourceBin = Join-Path $PSScriptRoot "bin"
$filesToCopy = @(
    "git-account-switcher.ps1", "git-account-switcher.cmd", "git-account-switcher",
    "gswitch.cmd", "gswitch",
    "switch-git.ps1", "switch-git.cmd", "switch-git"
)
foreach ($file in $filesToCopy) {
    $srcPath = Join-Path $sourceBin $file
    if (Test-Path $srcPath) {
        Copy-Item -Path $srcPath -Destination $binDir -Force
        Write-Host "  [OK] Installed $file -> $binDir" -ForegroundColor Green
    }
}

# Ensure .local\bin is in User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$HOME\.local\bin*") {
    Write-Host "  Adding $binDir to User PATH..." -ForegroundColor DarkCyan
    $newUserPath = "$userPath;$binDir"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $env:Path = "$env:Path;$binDir"
    Write-Host "  [OK] PATH updated successfully." -ForegroundColor Green
} else {
    Write-Host "  [OK] User PATH already contains $binDir." -ForegroundColor Green
}

# 3. Setup configuration directory
Write-Host "[3/5] Setting up accounts configuration..." -ForegroundColor Yellow
$configDir = "$HOME\.config\git-account-switcher"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$destConfig = Join-Path $configDir "accounts.json"
$srcExample = Join-Path $PSScriptRoot "config\accounts.example.json"

if ((-not (Test-Path $destConfig)) -or $Force) {
    # Check if gh has logged in accounts to auto-sync
    $statusCheck = gh auth status 2>&1
    if ($statusCheck -match 'Logged in to .* account') {
        Write-Host "  Detected active GitHub CLI accounts! Running auto-discovery..." -ForegroundColor DarkCyan
        & "$binDir\git-account-switcher.ps1" sync
    } elseif (Test-Path $srcExample) {
        Copy-Item -Path $srcExample -Destination $destConfig -Force
        Write-Host "  [OK] Deployed template accounts.json -> $destConfig" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] Existing configuration preserved at $destConfig." -ForegroundColor Green
}

# 4. Configure Git credential helper for GitHub CLI
Write-Host "[4/5] Configuring Git credential helper for GitHub CLI..." -ForegroundColor Yellow
try {
    git config --global --unset-all credential.https://github.com.helper 2>$null
    $ghExe = (Get-Command gh).Source
    git config --global --add credential.https://github.com.helper "!`'$ghExe`' auth git-credential"
    git config --global --add credential.https://gist.github.com.helper "!`'$ghExe`' auth git-credential"
    Write-Host "  [OK] Git credential helper linked to GitHub CLI ($ghExe)." -ForegroundColor Green
} catch {
    Write-Host "  [WARNING] Could not auto-link git credential helper: $_" -ForegroundColor Yellow
}

# 5. Configure Git aliases
Write-Host "[5/5] Setting up Git aliases..." -ForegroundColor Yellow
git config --global alias.who "!git-account-switcher status"
git config --global alias.switch-acc "!git-account-switcher"
Write-Host "  [OK] Added git alias: git who" -ForegroundColor Green
Write-Host "  [OK] Added git alias: git switch-acc" -ForegroundColor Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "You can now use any of these commands from any terminal:" -ForegroundColor Cyan
Write-Host "  gswitch <account>                # Fast switch (e.g. gswitch main, gswitch work)" -ForegroundColor White
Write-Host "  gswitch -l <account>             # Switch locally for current repository only" -ForegroundColor White
Write-Host "  gswitch                          # Interactive account menu" -ForegroundColor White
Write-Host "  gswitch sync                     # Auto-import all logged in GitHub CLI accounts" -ForegroundColor White
Write-Host "  gswitch list                     # View all configured accounts" -ForegroundColor White
Write-Host "  gswitch status                   # View current active identity (or: git who)" -ForegroundColor White
Write-Host ""
