<#
.SYNOPSIS
    Updates git-account-switcher (gswitch) to the latest version.
.DESCRIPTION
    1. Downloads/copies latest executable scripts to $HOME\.local\bin
    2. Ensures $HOME\.local\bin is present in User PATH
    3. Re-asserts Git aliases (git who, git switch-acc)
    4. Leaves all existing user accounts, credentials, and folder bindings untouched.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " git-account-switcher (gswitch) Updater" -ForegroundColor Cyan
Write-Host " Fast Multi-Account GitHub & Git Identity Switcher" -ForegroundColor DarkCyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$binDir = "$HOME\.local\bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

$RAW_BASE = "https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master"
$isLocal = ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "bin")))

$filesToCopy = @(
    "git-account-switcher.ps1", "git-account-switcher.cmd", "git-account-switcher",
    "gswitch.cmd", "gswitch",
    "switch-git.ps1", "switch-git.cmd", "switch-git"
)

Write-Host "Updating binaries in $binDir..." -ForegroundColor Yellow
foreach ($file in $filesToCopy) {
    $destFile = Join-Path $binDir $file
    if ($isLocal) {
        $srcPath = Join-Path (Join-Path $PSScriptRoot "bin") $file
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination $binDir -Force
            Write-Host "  [OK] Updated $file (local source)" -ForegroundColor Green
        }
    } else {
        $fileUrl = "$RAW_BASE/bin/$file"
        try {
            Invoke-RestMethod -Uri $fileUrl -OutFile $destFile
            Write-Host "  [OK] Downloaded and updated $file" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Failed to download $file : $_" -ForegroundColor Yellow
        }
    }
}

# Ensure .local\bin is in User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$HOME\.local\bin*") {
    $newUserPath = "$userPath;$binDir"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $env:Path = "$env:Path;$binDir"
    Write-Host "  [OK] User PATH verified." -ForegroundColor Green
}

# Re-assert Git aliases
git config --global alias.who "!git-account-switcher status" 2>$null
git config --global alias.switch-acc "!git-account-switcher" 2>$null
Write-Host "  [OK] Configured Git aliases (git who, git switch-acc)." -ForegroundColor Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " git-account-switcher has been updated successfully!" -ForegroundColor Green
Write-Host " All existing profiles and folder bindings were preserved." -ForegroundColor DarkCyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
