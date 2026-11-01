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
$homeDir = if ($env:GIT_ACCOUNT_SWITCHER_HOME) { $env:GIT_ACCOUNT_SWITCHER_HOME } else { $HOME }
$binDir = "$homeDir\.local\bin"
Write-Host "[2/5] Preparing installation directory ($binDir)..." -ForegroundColor Yellow
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

$ReleasesRepo = "ThanhNguyxnOrg/git-account-switcher"
$ReleaseWorkflow = "ThanhNguyxnOrg/git-account-switcher/.github/workflows/release.yml"
$isLocal = ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "bin")))
$releaseTmp = $null

$filesToCopy = @(
    "git-account-switcher.ps1", "git-account-switcher.cmd", "git-account-switcher",
    "gswitch.cmd", "gswitch",
    "switch-git.ps1", "switch-git.cmd", "switch-git"
)

if ($isLocal) {
    foreach ($file in $filesToCopy) {
        $srcPath = Join-Path (Join-Path $PSScriptRoot "bin") $file
        if (Test-Path $srcPath) {
            $destFile = Join-Path $binDir $file
            Copy-Item -Path $srcPath -Destination "$destFile.new" -Force
            Move-Item -Path "$destFile.new" -Destination $destFile -Force
            Write-Host "  [OK] Installed $file -> $binDir" -ForegroundColor Green
        }
    }
} else {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] GitHub CLI (gh) is required to verify release assets." -ForegroundColor Red
        exit 1
    }
    $tag = if ($env:GSWITCH_INSTALL_TAG) {
        $env:GSWITCH_INSTALL_TAG
    } else {
        (gh release view --repo $ReleasesRepo --json tagName --jq ".tagName" 2>$null | Select-Object -First 1)
    }
    if (-not $tag) {
        Write-Host "[ERROR] No GitHub release found for $ReleasesRepo." -ForegroundColor Red
        Write-Host "        Create a v* release with attested assets, or set GSWITCH_INSTALL_TAG." -ForegroundColor Gray
        exit 1
    }
    $releaseTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gswitch-install-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $releaseTmp -Force | Out-Null
    Write-Host "  Downloading verified release $tag..." -ForegroundColor DarkCyan
    gh release download $tag --repo $ReleasesRepo --dir $releaseTmp --clobber 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "release download failed" }

    $manifest = Join-Path $releaseTmp "SHA256SUMS"
    if (-not (Test-Path $manifest)) { throw "release is missing SHA256SUMS" }
    gh attestation verify $manifest --repo $ReleasesRepo --signer-workflow $ReleaseWorkflow --deny-self-hosted-runners 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "attestation verification failed" }

    $version = $tag -replace '^v', ''
    $stage = "gswitch-v$version"
    $archive = Join-Path $releaseTmp "$stage.zip"
    if (-not (Test-Path $archive)) { throw "release is missing $stage.zip" }
    $manifestLines = Get-Content -Path $manifest
    $expectedLine = $manifestLines | Where-Object { $_ -match ("^[0-9a-fA-F]{64}\s+\*?" + [regex]::Escape("$stage.zip") + "$") } | Select-Object -First 1
    if (-not $expectedLine) { throw "SHA256SUMS has no entry for $stage.zip" }
    $expected = ($expectedLine -split '\s+')[0].ToLower()
    $actual = (Get-FileHash -Path $archive -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) { throw "checksum mismatch for $stage.zip" }
    Expand-Archive -Path $archive -DestinationPath $releaseTmp -Force
    foreach ($file in $filesToCopy) {
        $source = Join-Path (Join-Path $releaseTmp $stage) "bin\$file"
        if (-not (Test-Path $source)) { throw "archive is missing bin\$file" }
        $destFile = Join-Path $binDir $file
        Copy-Item -Path $source -Destination "$destFile.new" -Force
        Move-Item -Path "$destFile.new" -Destination $destFile -Force
        Write-Host "  [OK] Verified & installed $file" -ForegroundColor Green
    }
    Write-Host "  [OK] Attestation and archive checksum verified for $tag" -ForegroundColor Green
}

# Ensure .local\bin is in User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathEntries = @($userPath -split ';' | Where-Object { $_ })
$binNorm = $binDir.TrimEnd('\', '/')
$alreadyInPath = @($pathEntries | Where-Object { $_.TrimEnd('\', '/') -ieq $binNorm }).Count -gt 0
if (-not $alreadyInPath) {
    Write-Host "  Adding $binDir to User PATH..." -ForegroundColor DarkCyan
    $newUserPath = if ($userPath) { "$userPath;$binDir" } else { $binDir }
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $env:Path = "$env:Path;$binDir"
    Write-Host "  [OK] PATH updated successfully." -ForegroundColor Green
} else {
    Write-Host "  [OK] User PATH already contains $binDir." -ForegroundColor Green
}

# 3. Setup configuration directory
Write-Host "[3/5] Setting up accounts configuration..." -ForegroundColor Yellow
$configDir = "$homeDir\.config\git-account-switcher"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$destConfig = Join-Path $configDir "accounts.json"

if ((-not (Test-Path $destConfig)) -or $Force) {
    # Check if gh has logged in accounts to auto-sync
    $statusCheck = gh auth status 2>&1
    if ($statusCheck -match 'Logged in to .* account') {
        Write-Host "  Detected active GitHub CLI accounts! Running auto-discovery..." -ForegroundColor DarkCyan
        & "$binDir\git-account-switcher.ps1" sync
    } elseif ($isLocal -and (Test-Path (Join-Path $PSScriptRoot "config\accounts.example.json"))) {
        Copy-Item -Path (Join-Path $PSScriptRoot "config\accounts.example.json") -Destination $destConfig -Force
        Write-Host "  [OK] Deployed template accounts.json -> $destConfig" -ForegroundColor Green
    } elseif ($releaseTmp -and (Test-Path (Join-Path (Join-Path $releaseTmp $stage) "config\accounts.example.json"))) {
        Copy-Item -Path (Join-Path (Join-Path $releaseTmp $stage) "config\accounts.example.json") -Destination $destConfig -Force
        Write-Host "  [OK] Deployed template accounts.json from release -> $destConfig" -ForegroundColor Green
    } else {
        [System.IO.File]::WriteAllText($destConfig, "[]", (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  [OK] Initialized empty accounts.json -> $destConfig" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] Existing configuration preserved at $destConfig." -ForegroundColor Green
}

# 4. Configure Git credential helper for GitHub CLI
Write-Host "[4/5] Configuring Git credential helper for GitHub CLI..." -ForegroundColor Yellow
try {
    git config --global --unset-all credential.https://github.com.helper 2>$null
    $ghExe = (Get-Command gh).Source
    $ghExeSafe = $ghExe.Replace("'", "'\''")
    git config --global --add credential.https://github.com.helper "!'$ghExeSafe' auth git-credential"
    git config --global --add credential.https://gist.github.com.helper "!'$ghExeSafe' auth git-credential"
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

# 6. Configure Shell auto-completion
try {
    & (Join-Path $binDir "git-account-switcher.ps1") completion install | Out-Null
    Write-Host "  [OK] Configured shell auto-completion (gswitch <Tab>)." -ForegroundColor Green
} catch {}

if ($releaseTmp) {
    Remove-Item -Path $releaseTmp -Recurse -Force -ErrorAction SilentlyContinue
}

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
