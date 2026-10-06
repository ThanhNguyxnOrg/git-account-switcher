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
    if ($outStr1 -notmatch "v1\.2\.0") {
        throw "Expected version v1.2.0, got: $outStr1"
    }
    $output2 = Invoke-Gswitch -v
    $outStr2 = ($output2 | Out-String)
    if ($outStr2 -notmatch "v1\.2\.0") {
        throw "Expected version v1.2.0, got: $outStr2"
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
        $isolatedCfgFile = "$HOME\.gitconfig-testisolatedkey"
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

} finally {
    Remove-Item -Path $sandboxDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item env:GIT_ACCOUNT_SWITCHER_CONFIG -ErrorAction SilentlyContinue
}

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
