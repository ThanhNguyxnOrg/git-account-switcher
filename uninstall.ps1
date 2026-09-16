<#
.SYNOPSIS
    Uninstalls switch-git from the local user environment.
#>

[CmdletBinding()]
param(
    [switch]$PurgeConfig
)

Write-Host ""
Write-Host "Uninstalling switch-git..." -ForegroundColor Yellow

$binDir = "$HOME\.local\bin"
$filesToRemove = @("switch-git.ps1", "switch-git.cmd", "switch-git")

foreach ($file in $filesToRemove) {
    $targetPath = Join-Path $binDir $file
    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Force
        Write-Host "[OK] Removed $targetPath" -ForegroundColor Green
    }
}

# Remove Git aliases
git config --global --unset alias.who 2>$null
git config --global --unset alias.switch-acc 2>$null
Write-Host "[OK] Removed git aliases (git who, git switch-acc)" -ForegroundColor Green

if ($PurgeConfig) {
    $configDir = "$HOME\.config\switch-git"
    if (Test-Path $configDir) {
        Remove-Item -Path $configDir -Recurse -Force
        Write-Host "[OK] Removed configuration directory: $configDir" -ForegroundColor Green
    }
}

Write-Host "Uninstallation completed." -ForegroundColor Green
Write-Host ""
