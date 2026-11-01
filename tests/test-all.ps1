<#
.SYNOPSIS
    Automated Test Suite for git-account-switcher (PowerShell)
.DESCRIPTION
    Runs syntax verification, help commands, and isolated end-to-end account management
    tests without modifying or touching your actual personal configuration.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$SwitcherPs1 = Join-Path $ScriptRoot "..\bin\git-account-switcher.ps1"

# Fully isolated environment: no test may touch the real user profile or Git config.
$suiteRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("gswitch_ps_suite_" + [System.Guid]::NewGuid().ToString("N"))
$suiteHome = Join-Path $suiteRoot "home"
$suiteBin = Join-Path $suiteRoot "bin"
New-Item -ItemType Directory -Path $suiteHome, $suiteBin -Force | Out-Null
$origSwitcherHome = $env:GIT_ACCOUNT_SWITCHER_HOME
$origSwitcherProfile = $env:GIT_ACCOUNT_SWITCHER_PROFILE
$origGitConfigGlobal = $env:GIT_CONFIG_GLOBAL
$origGitConfigNoSystem = $env:GIT_CONFIG_NOSYSTEM
$origGitTerminalPrompt = $env:GIT_TERMINAL_PROMPT
$origGhLog = $env:GH_LOG
$origPath = $env:PATH
$env:GIT_ACCOUNT_SWITCHER_HOME = $suiteHome
$env:GIT_ACCOUNT_SWITCHER_PROFILE = Join-Path $suiteHome "profile.ps1"
$env:GIT_CONFIG_GLOBAL = Join-Path $suiteRoot "gitconfig"
$env:GIT_CONFIG_NOSYSTEM = "1"
$env:GIT_TERMINAL_PROMPT = "0"
$env:GH_LOG = Join-Path $suiteRoot "gh.log"

$fakeGhCmd = @'
@echo off
echo %*>>"%GH_LOG%"
if "%1"=="auth" if "%2"=="token" echo fake-token
if "%1"=="auth" if "%2"=="status" echo Logged in to github.com account mock-active (keyring)
if "%1"=="api" echo {"id":1,"login":"mock-active","name":"Mock User"}
exit /b 0
'@
[System.IO.File]::WriteAllText((Join-Path $suiteBin "gh.cmd"), $fakeGhCmd, [System.Text.Encoding]::ASCII)

$fakeGhSh = @'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
if [[ "$1" == "auth" && "$2" == "token" ]]; then echo "fake-token"; exit 0; fi
if [[ "$1" == "auth" && "$2" == "status" ]]; then echo "Logged in to github.com account mock-active (keyring)"; exit 0; fi
if [[ "$1" == "api" && "$2" == "user" ]]; then echo "mock-active"; exit 0; fi
if [[ "$1" == "api" ]]; then echo '{"id":1,"login":"mock-active","name":"Mock User"}'; exit 0; fi
exit 0
'@
[System.IO.File]::WriteAllText((Join-Path $suiteBin "gh"), $fakeGhSh, (New-Object System.Text.UTF8Encoding($false)))
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue
if ($bashCmd) {
    & $bashCmd.Source -c "chmod +x '$($suiteBin.Replace('\', '/'))/gh'" 2>$null
}
$env:PATH = "$suiteBin;$env:PATH"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Running git-account-switcher Test Suite (PowerShell)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0

function Assert-Test([string]$testName, [scriptblock]$action) {
    Write-Host "  RUN   : $testName ... " -NoNewline
    try {
        & $action
        Write-Host "[PASS]" -ForegroundColor Green
        $script:passed++
    } catch {
        Write-Host "[FAIL]" -ForegroundColor Red
        Write-Host "         $_" -ForegroundColor DarkRed
        $script:failed++
    }
}

# 1. Syntax Check
Assert-Test "PowerShell Script Syntax Validation" {
    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($SwitcherPs1, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "Syntax errors detected: $($errors -join '; ')"
    }
}

function Invoke-Gswitch {
    & powershell.exe -NoProfile -InputFormat None -ExecutionPolicy Bypass -File $SwitcherPs1 @args 2>&1
}

# 2. Help Command Check
Assert-Test "Help flag execution ('help')" {
    $output = Invoke-Gswitch help
    $outStr = ($output | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "Expected exit code 0, got $LASTEXITCODE"
    }
    if ($outStr -notmatch "USAGE:" -or $outStr -notmatch "COMMANDS:") {
        throw "Help output did not contain expected sections."
    }
}

# 3. Version Command Check
Assert-Test "Version command execution ('version' & '-v')" {
    $output1 = Invoke-Gswitch version
    $outStr1 = ($output1 | Out-String)
    if ($outStr1 -notmatch "v1\.0\.0") {
        throw "Expected version v1.0.0, got: $outStr1"
    }
    $output2 = Invoke-Gswitch -v
    $outStr2 = ($output2 | Out-String)
    if ($outStr2 -notmatch "v1\.0\.0") {
        throw "Expected version v1.0.0, got: $outStr2"
    }
}

# 4. Update Command Check
Assert-Test "Update command execution ('update')" {
    $out = Invoke-Gswitch update
    $outStr = ($out | Out-String)
    if ($outStr -notmatch "Updating git-account-switcher" -or $outStr -notmatch "updated successfully") {
        throw "Expected update output, got: $outStr"
    }
}

# 5. Shell Completion Script Check
Assert-Test "Shell completion script generator ('completion powershell')" {
    $out = Invoke-Gswitch completion powershell
    $outStr = ($out | Out-String)
    if ($outStr -notmatch "Register-ArgumentCompleter") {
        throw "Expected Register-ArgumentCompleter in completion script, got: $outStr"
    }
}

# 6. Isolated Sandbox Integration Tests
$sandboxDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gswitch_test_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null
$sandboxConfig = Join-Path $sandboxDir "accounts.json"

try {
    $env:GIT_ACCOUNT_SWITCHER_CONFIG = $sandboxConfig

    Assert-Test "Empty config list handling" {
        $out = Invoke-Gswitch list
        $outStr = ($out | Out-String)
        if ($outStr -notmatch "No account profiles configured yet") {
            throw "Expected empty profile notice, got: $outStr"
        }
    }

    Assert-Test "Add profile non-interactively ('add octocat work')" {
        $out = Invoke-Gswitch add octocat work "Mona Lisa" "mona@enterprise.com"
        if (-not (Test-Path $sandboxConfig)) {
            throw "Sandbox config was not created at $sandboxConfig"
        }
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 1 -or $json[0].key -ne "work" -or $json[0].username -ne "octocat") {
            throw "Config did not record the added account accurately. Raw: $raw"
        }
    }

    Assert-Test "Add second profile ('add student-mona school')" {
        $out = Invoke-Gswitch add student-mona school "Mona Student" "mona@school.edu"
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 2) {
            throw "Expected 2 accounts in sandbox, found $($json.Count). Raw content: $raw. Output: $out"
        }
    }

    Assert-Test "Add shortcut alias ('alias work w')" {
        $out = Invoke-Gswitch alias work w
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        $workAcc = $json | Where-Object { $_.key -eq "work" }
        $aliases = @($workAcc.aliases | ForEach-Object { $_.ToString().ToLower() })
        if ($aliases -notcontains "w") {
            throw "Expected alias 'w' in work account aliases, found: $($aliases -join ', ')"
        }
    }

    Assert-Test "Update existing profile preserves custom aliases" {
        $out = Invoke-Gswitch add octocat work "Mona Updated" "mona.new@enterprise.com"
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 2) {
            throw "Expected 2 accounts after update, found $($json.Count) (duplicates were created)"
        }
        $workAcc = $json | Where-Object { $_.key -eq "work" }
        if ($workAcc.name -ne "Mona Updated") {
            throw "Account was not updated with new author name."
        }
        $aliases = @($workAcc.aliases | ForEach-Object { $_.ToString().ToLower() })
        if ($aliases -notcontains "w") {
            throw "Custom alias 'w' was wiped out upon updating profile! Found: $($aliases -join ', ')"
        }
    }

    Assert-Test "Remove shortcut alias ('unalias work w')" {
        $out = Invoke-Gswitch unalias work w
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        $workAcc = $json | Where-Object { $_.key -eq "work" }
        $aliases = @($workAcc.aliases | ForEach-Object { $_.ToString().ToLower() })
        if ($aliases -contains "w") {
            throw "Expected alias 'w' to be removed from work account aliases, found: $($aliases -join ', ')"
        }
    }

    Assert-Test "Remove profile and verify clean re-indexing ('remove work -f')" {
        # Profile 1 is work, Profile 2 is school. Remove work: school becomes Profile 1.
        $out = Invoke-Gswitch remove work -f
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 1) {
            throw "Expected 1 account remaining, found $($json.Count)"
        }
        if ($json[0].key -ne "school") {
            throw "Remaining account was not 'school'."
        }
        if ($json[0].index -ne 1) {
            throw "Expected remaining account index to be 1, found $($json[0].index)"
        }
        $aliases = @($json[0].aliases | ForEach-Object { $_.ToString() })
        if ($aliases -contains "2") {
            throw "Old index '2' was not purged from aliases! Aliases: $($aliases -join ', ')"
        }
        if ($aliases -notcontains "1") {
            throw "New index '1' was not added to aliases! Aliases: $($aliases -join ', ')"
        }
    }

    Assert-Test "List folder bindings command ('bindings')" {
        $out = Invoke-Gswitch bindings
        $outStr = ($out | Out-String)
        if ($outStr -notmatch "Configured Folder Bindings") {
            throw "Expected bindings output, got: $outStr"
        }
    }

    Assert-Test "End-to-End Folder Binding & Inheritance ('bind' & 'unbind')" {
        $testBoundDir = Join-Path $sandboxDir "bound_work_dir"
        $subRepo = Join-Path $testBoundDir "sub_repo"
        New-Item -ItemType Directory -Path $subRepo -Force | Out-Null
        $isolatedCfgFile = Join-Path $env:GIT_ACCOUNT_SWITCHER_HOME ".gitconfig-testisolatedkey"
        try {
            # Add an isolated account for testing folder binding
            Invoke-Gswitch add mockuser testisolatedkey "Mock Author" "mock@author.org" | Out-Null

            # Bind the folder to testisolatedkey
            $bindOut = Invoke-Gswitch bind $testBoundDir testisolatedkey
            $bindStr = ($bindOut | Out-String)
            if ($bindStr -notmatch "successfully bound to account") {
                throw "Failed to bind folder. Output: $bindStr"
            }

            # Verify bindings listing shows the bound dir
            $listOut = (Invoke-Gswitch bindings | Out-String)
            if ($listOut -notmatch "bound_work_dir") {
                throw "Folder was not found in 'bindings' output: $listOut"
            }

            # Initialize git repo inside bound dir and verify author inheritance
            Push-Location $subRepo
            try {
                git init -q
                $effName = git config user.name
                $effEmail = git config user.email
                if ($effName -ne "Mock Author" -or $effEmail -ne "mock@author.org") {
                    throw "Sub-repo did not inherit folder binding identity! Got: name='$effName', email='$effEmail'"
                }

                # Verify gswitch status detects folder binding
                $statusOut = (Invoke-Gswitch status | Out-String)
                if ($statusOut -notmatch "Folder includeIf Binding Active") {
                    throw "Status did not report active folder binding: $statusOut"
                }

                # Test local override shadowing warning
                git config --local user.name "OverrideAuthor"
                $shadowOut = (Invoke-Gswitch status | Out-String)
                if ($shadowOut -notmatch "SHADOWED by this local override") {
                    throw "Status failed to warn that local override shadows folder binding: $shadowOut"
                }
            } finally {
                Pop-Location
            }

            # Unbind the folder
            $unbindOut = (Invoke-Gswitch unbind $testBoundDir | Out-String)
            if ($unbindOut -notmatch "Unbound folder") {
                throw "Failed to unbind folder: $unbindOut"
            }
        } finally {
            # Ensure unbind cleanup
            Invoke-Gswitch unbind $testBoundDir 2>$null | Out-Null
            Remove-Item -Path $testBoundDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $isolatedCfgFile -Force -ErrorAction SilentlyContinue
        }
    }

    Assert-Test "Credential helper command ('cred <user> get')" {
        $out = Invoke-Gswitch cred non_existent_user_test get
        $outStr = ($out | Out-String)
        # Should exit 0 without crashing
        if ($LASTEXITCODE -ne 0) {
            throw "Expected exit code 0 for cred command, got: $LASTEXITCODE"
        }
    }

    Assert-Test "Diagnostics command ('doctor')" {
        $out = Invoke-Gswitch doctor
        $outStr = ($out | Out-String)
        if ($outStr -notmatch "GIT ACCOUNT SWITCHER - SYSTEM & REPO DIAGNOSTICS") {
            throw "Expected doctor diagnostic header, got: $outStr"
        }
        if ($outStr -notmatch "DOCTOR RESULT:") {
            throw "Expected doctor result section, got: $outStr"
        }
    }

    Assert-Test "SSH Remote Warning in Status" {
        $dummyRepo = Join-Path $sandboxDir "dummy-ssh-repo"
        New-Item -ItemType Directory -Path $dummyRepo -Force | Out-Null
        Push-Location $dummyRepo
        try {
            git init -q
            git remote add origin "git@github.com:dummy/ssh-repo.git"
            $out = Invoke-Gswitch status
            $outStr = ($out | Out-String)
            if ($outStr -notmatch "Remote uses SSH") {
                throw "Expected SSH remote warning, got: $outStr"
            }
        } finally {
            Pop-Location
            Remove-Item -Path $dummyRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Assert-Test "Local switch isolates Git credentials from global helper" {
        $oldConfig = $env:GIT_ACCOUNT_SWITCHER_CONFIG
        $credConfig = Join-Path $sandboxDir "cred-accounts.json"
        $env:GIT_ACCOUNT_SWITCHER_CONFIG = $credConfig
        try {
            $null = Invoke-Gswitch add mock-work work "Mock Work" "mock@work.test"
            $credRepo = Join-Path $sandboxDir "credrepo"
            New-Item -ItemType Directory -Path $credRepo -Force | Out-Null
            Push-Location $credRepo
            try {
                git init -q
                git config --global credential.https://github.com.helper '!f() { echo username=global; echo password=globalpass; }; f'
                $null = Invoke-Gswitch -l work
                if ($LASTEXITCODE -ne 0) { throw "gswitch -l failed with exit $LASTEXITCODE" }
                $gitDir = git rev-parse --git-dir
                $localConfig = Join-Path (Resolve-Path $gitDir).Path "config"
                if (-not (Select-String -Path $localConfig -Pattern '^\s*helper\s*=\s*$' -Quiet)) {
                    throw "Local credential helper has no empty reset."
                }
                $credInput = Join-Path $sandboxDir "cred-input.txt"
                $credOutput = Join-Path $sandboxDir "cred-output.txt"
                $credError = Join-Path $sandboxDir "cred-error.txt"
                [System.IO.File]::WriteAllText($credInput, "protocol=https`nhost=github.com`n`n", [System.Text.Encoding]::ASCII)
                $gitExe = (Get-Command git).Source
                $credProc = Start-Process -FilePath $gitExe -ArgumentList @("credential", "fill") `
                    -RedirectStandardInput $credInput -RedirectStandardOutput $credOutput `
                    -RedirectStandardError $credError -NoNewWindow -Wait -PassThru
                $credOut = (Get-Content -Path $credOutput -Raw -ErrorAction SilentlyContinue)
                $credErr = (Get-Content -Path $credError -Raw -ErrorAction SilentlyContinue)
                if ($credProc.ExitCode -ne 0) { throw "git credential fill failed: $credErr" }
                if ($credOut -notmatch 'username=mock-work' -or $credOut -notmatch 'password=fake-token') {
                    throw "Local credential helper did not win: $credOut"
                }
                $doctorOut = (Invoke-Gswitch doctor | Out-String)
                if ($doctorOut -match 'no empty reset') { throw "doctor reported missing reset: $doctorOut" }
            } finally {
                Pop-Location
            }
        } finally {
            $env:GIT_ACCOUNT_SWITCHER_CONFIG = $oldConfig
        }
    }

    Assert-Test "Local switch validates repository before touching gh" {
        $oldConfig = $env:GIT_ACCOUNT_SWITCHER_CONFIG
        $credConfig = Join-Path $sandboxDir "preflight-accounts.json"
        $env:GIT_ACCOUNT_SWITCHER_CONFIG = $credConfig
        try {
            $null = Invoke-Gswitch add mock-work work "Mock Work" "mock@work.test"
            if (Test-Path $env:GH_LOG) { Remove-Item -Path $env:GH_LOG -Force }
            $notRepo = Join-Path $sandboxDir "not-a-repo"
            New-Item -ItemType Directory -Path $notRepo -Force | Out-Null
            Push-Location $notRepo
            try {
                $null = Invoke-Gswitch -l work
                $code = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            if ($code -eq 0) { throw "Expected gswitch -l to fail outside a repository." }
            $ghLog = if (Test-Path $env:GH_LOG) { Get-Content -Path $env:GH_LOG -Raw } else { "" }
            if ($ghLog -match 'auth switch') { throw "gh was switched before repository validation: $ghLog" }
        } finally {
            $env:GIT_ACCOUNT_SWITCHER_CONFIG = $oldConfig
        }
    }

    Assert-Test "Add update preserves signingkey and custom aliases" {
        $oldConfig = $env:GIT_ACCOUNT_SWITCHER_CONFIG
        $signConfig = Join-Path $sandboxDir "sign-accounts.json"
        $env:GIT_ACCOUNT_SWITCHER_CONFIG = $signConfig
        [System.IO.File]::WriteAllText($signConfig, @'
[
  {"index":1,"key":"work","aliases":["1","work"],"label":"Work","username":"mock-work","name":"Mock Work","email":"mock@work.test","signingkey":"ssh-ed25519 AAAATESTKEY"}
]
'@, (New-Object System.Text.UTF8Encoding($false)))
        try {
            $null = Invoke-Gswitch alias work w
            $null = Invoke-Gswitch add mock-work work "Mock Updated" "new@work.test"
            $account = (Get-Content -Path $signConfig -Raw | ConvertFrom-Json)[0]
            if ($account.signingkey -ne "ssh-ed25519 AAAATESTKEY") { throw "signingkey was lost on update." }
            if (@($account.aliases) -notcontains "w") { throw "custom alias was lost on update." }
        } finally {
            $env:GIT_ACCOUNT_SWITCHER_CONFIG = $oldConfig
        }
    }

    Assert-Test "Global switch preserves repo-local overrides; ClearLocal removes them" {
        $oldConfig = $env:GIT_ACCOUNT_SWITCHER_CONFIG
        $switchConfig = Join-Path $sandboxDir "switch-accounts.json"
        $env:GIT_ACCOUNT_SWITCHER_CONFIG = $switchConfig
        try {
            $null = Invoke-Gswitch add mock-work work "Mock Work" "mock@work.test"
            $localRepo = Join-Path $sandboxDir "local-override-repo"
            New-Item -ItemType Directory -Path $localRepo -Force | Out-Null
            Push-Location $localRepo
            try {
                git init -q
                git config --local user.name "Repo Local"
                git config --local user.email "local@repo.test"
                $null = Invoke-Gswitch work
                if ((git config --local user.name) -ne "Repo Local") { throw "Global switch removed the local user.name." }
                $null = Invoke-Gswitch -ClearLocal work
                if (git config --local user.name) { throw "ClearLocal did not remove the local user.name." }
            } finally {
                Pop-Location
            }
        } finally {
            $env:GIT_ACCOUNT_SWITCHER_CONFIG = $oldConfig
        }
    }

    Assert-Test "Removing an account cleans folder bindings and profile file" {
        $oldConfig = $env:GIT_ACCOUNT_SWITCHER_CONFIG
        $bindConfig = Join-Path $sandboxDir "bind-cleanup-accounts.json"
        $env:GIT_ACCOUNT_SWITCHER_CONFIG = $bindConfig
        try {
            $null = Invoke-Gswitch add mock-work work "Mock Work" "mock@work.test"
            $bindDir = Join-Path $sandboxDir "cleanup-bound"
            New-Item -ItemType Directory -Path $bindDir -Force | Out-Null
            $null = Invoke-Gswitch bind $bindDir work
            $profileFile = Join-Path $env:GIT_ACCOUNT_SWITCHER_HOME ".gitconfig-work"
            if (-not (Test-Path $profileFile)) { throw "bind did not create the profile file." }
            $null = Invoke-Gswitch remove work -f
            $bindings = git config --global --get-regexp '^includeif\.gitdir' 2>$null
            if ($bindings -match 'gitconfig-work') { throw "folder binding was not removed." }
            if (Test-Path $profileFile) { throw "profile file was not removed." }
        } finally {
            $env:GIT_ACCOUNT_SWITCHER_CONFIG = $oldConfig
        }
    }

    Assert-Test "Completion and JSON writes are BOM-free" {
        $oldConfig = $env:GIT_ACCOUNT_SWITCHER_CONFIG
        $cfgDir = Join-Path $env:GIT_ACCOUNT_SWITCHER_HOME ".config\git-account-switcher"
        New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
        $env:GIT_ACCOUNT_SWITCHER_CONFIG = Join-Path $cfgDir "accounts.json"
        [System.IO.File]::WriteAllText($env:GIT_ACCOUNT_SWITCHER_CONFIG, "[]", (New-Object System.Text.UTF8Encoding($false)))
        try {
            $null = Invoke-Gswitch completion install
            $compFile = Join-Path $cfgDir "completion.bash"
            $compBytes = [System.IO.File]::ReadAllBytes($compFile)
            if ($compBytes[0] -eq 0xEF) { throw "completion.bash starts with a UTF-8 BOM." }
            if (Test-Path $env:GIT_ACCOUNT_SWITCHER_PROFILE) {
                $profBytes = [System.IO.File]::ReadAllBytes($env:GIT_ACCOUNT_SWITCHER_PROFILE)
                if ($profBytes[0] -eq 0xEF) { throw "PowerShell profile starts with a UTF-8 BOM." }
            }
        } finally {
            $env:GIT_ACCOUNT_SWITCHER_CONFIG = $oldConfig
        }
    }

} finally {
    Remove-Item -Path $sandboxDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item env:GIT_ACCOUNT_SWITCHER_CONFIG -ErrorAction SilentlyContinue
}

# Restore the caller environment and remove the isolated suite root.
if ($null -eq $origSwitcherHome) { Remove-Item env:GIT_ACCOUNT_SWITCHER_HOME -ErrorAction SilentlyContinue } else { $env:GIT_ACCOUNT_SWITCHER_HOME = $origSwitcherHome }
if ($null -eq $origSwitcherProfile) { Remove-Item env:GIT_ACCOUNT_SWITCHER_PROFILE -ErrorAction SilentlyContinue } else { $env:GIT_ACCOUNT_SWITCHER_PROFILE = $origSwitcherProfile }
if ($null -eq $origGitConfigGlobal) { Remove-Item env:GIT_CONFIG_GLOBAL -ErrorAction SilentlyContinue } else { $env:GIT_CONFIG_GLOBAL = $origGitConfigGlobal }
if ($null -eq $origGitConfigNoSystem) { Remove-Item env:GIT_CONFIG_NOSYSTEM -ErrorAction SilentlyContinue } else { $env:GIT_CONFIG_NOSYSTEM = $origGitConfigNoSystem }
if ($null -eq $origGitTerminalPrompt) { Remove-Item env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue } else { $env:GIT_TERMINAL_PROMPT = $origGitTerminalPrompt }
if ($null -eq $origGhLog) { Remove-Item env:GH_LOG -ErrorAction SilentlyContinue } else { $env:GH_LOG = $origGhLog }
if ($null -eq $origPath) { Remove-Item env:PATH -ErrorAction SilentlyContinue } else { $env:PATH = $origPath }
Remove-Item -Path $suiteRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Test Summary: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
