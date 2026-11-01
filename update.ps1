<#
.SYNOPSIS
    Updates git-account-switcher (gswitch) to the latest attested release.
.DESCRIPTION
    Delegates to the installed or local CLI so the update path verifies the
    release checksum and GitHub artifact attestation before replacing files.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$homeDir = if ($env:GIT_ACCOUNT_SWITCHER_HOME) { $env:GIT_ACCOUNT_SWITCHER_HOME } else { $HOME }
$localScript = Join-Path $PSScriptRoot "bin\git-account-switcher.ps1"
$installedScript = Join-Path $homeDir ".local\bin\git-account-switcher.ps1"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " git-account-switcher (gswitch) Updater" -ForegroundColor Cyan
Write-Host " Fast Multi-Account GitHub & Git Identity Switcher" -ForegroundColor DarkCyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $localScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $localScript update
    exit $LASTEXITCODE
}
if (Test-Path $installedScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installedScript update
    exit $LASTEXITCODE
}

Write-Host "[ERROR] git-account-switcher is not installed." -ForegroundColor Red
Write-Host "        Run install.ps1 first, or run this script from a local clone." -ForegroundColor Gray
exit 1
