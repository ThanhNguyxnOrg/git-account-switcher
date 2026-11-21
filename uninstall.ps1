<#
.SYNOPSIS
    Uninstalls git-account-switcher from the local user environment.
#>

[CmdletBinding()]
param(
    [switch]$PurgeConfig
)

$homeDir = if ($env:GIT_ACCOUNT_SWITCHER_HOME) { $env:GIT_ACCOUNT_SWITCHER_HOME } else { $HOME }
$profileFile = if ($env:GIT_ACCOUNT_SWITCHER_PROFILE) { $env:GIT_ACCOUNT_SWITCHER_PROFILE } else { $PROFILE }
$binDir = "$homeDir\.local\bin"
$configDir = "$homeDir\.config\git-account-switcher"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host ""
Write-Host "Uninstalling git-account-switcher..." -ForegroundColor Yellow

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

$installedConfig = Join-Path $configDir "installed.gitconfig"
if (Test-Path -LiteralPath $installedConfig) {
    foreach ($key in 'alias.who', 'alias.switch-acc', 'credential.https://github.com.helper', 'credential.https://gist.github.com.helper') {
        $value = git config --file $installedConfig --get $key
        if ($LASTEXITCODE -eq 1) { continue }
        if ($LASTEXITCODE -ne 0) { throw "Could not read recorded Git setting: $key" }
        $pattern = '^' + [regex]::Escape($value) + '$'
        git config --global --unset $key $pattern
        if ($LASTEXITCODE -notin 0, 5) { throw "Could not remove installed Git setting: $key" }
    }
    Remove-Item -LiteralPath $installedConfig -Force
}

$removedFiles = @()
$bindingKeys = git config --global --name-only --get-regexp '^includeif\.gitdir' 2>$null
foreach ($bindingKey in @($bindingKeys)) {
    if (-not $bindingKey) { continue }
    $bindingFile = git config --global --get $bindingKey 2>$null
    if ($bindingFile -and (Test-Path $bindingFile)) {
        if (Select-String -Path $bindingFile -Pattern 'git-account-switcher.*cred' -Quiet) {
            git config --global --unset-all $bindingKey 2>$null
            $removedFiles += $bindingFile
        }
    }
}

$remaining = (git config --global --get-regexp '^includeif\.gitdir' 2>$null | Out-String)
foreach ($file in @($removedFiles | Select-Object -Unique)) {
    if ($file -and $remaining -notlike "*$file*" -and (Test-Path $file)) {
        Remove-Item -LiteralPath $file -Force
        Write-Host "[OK] Removed generated profile config: $file" -ForegroundColor Green
    }
}

foreach ($file in Get-ChildItem -Path $homeDir -Filter ".gitconfig-*" -File -ErrorAction SilentlyContinue) {
    if (Select-String -Path $file.FullName -Pattern 'git-account-switcher.*cred' -Quiet) {
        Remove-Item -LiteralPath $file.FullName -Force
        Write-Host "[OK] Removed orphaned profile config: $($file.FullName)" -ForegroundColor Green
    }
}

function Remove-CompletionLoader([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $lines = Get-Content -Path $Path -ErrorAction SilentlyContinue | Where-Object {
        $_ -notmatch 'git-account-switcher shell completion' -and $_ -notmatch 'git-account-switcher.*completion\.(ps1|bash|zsh)'
    }
    [System.IO.File]::WriteAllLines($Path, @($lines), $utf8NoBom)
    Write-Host "[OK] Removed completion loader from $Path" -ForegroundColor Green
}

Remove-CompletionLoader $profileFile
Remove-CompletionLoader (Join-Path $homeDir ".bashrc")
Remove-Item -Path (Join-Path $configDir "completion.ps1") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $configDir "completion.bash") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $configDir "completion.zsh") -Force -ErrorAction SilentlyContinue

if ($PurgeConfig) {
    $configDirs = @(
        $configDir,
        "$homeDir\.config\switch-git"
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
