<#
.SYNOPSIS
    Uninstalls git-account-switcher from the local user environment.
#>

[CmdletBinding()]
param(
    [switch]$PurgeConfig
)

Write-Host ""
Write-Host "Uninstalling git-account-switcher..." -ForegroundColor Yellow

$binDir = "$HOME\.local\bin"
$filesToRemove = @(
    "git-account-switcher.ps1", "git-account-switcher.cmd", "git-account-switcher",
    "gswitch.cmd", "gswitch",
    "switch-git.ps1", "switch-git.cmd", "switch-git"
)

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
    $configDirs = @(
        "$HOME\.config\git-account-switcher",
        "$HOME\.config\switch-git"
    )
    foreach ($cd in $configDirs) {
        if (Test-Path $cd) {
            Remove-Item -Path $cd -Recurse -Force
            Write-Host "[OK] Removed configuration directory: $cd" -ForegroundColor Green
        }
    }
}

Write-Host "Uninstallation completed." -ForegroundColor Green
Write-Host ""
