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

# 2. Help Command Check
Assert-Test "Help flag execution ('help')" {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 help 2>&1
    $outStr = ($output | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "Expected exit code 0, got $LASTEXITCODE"
    }
    if ($outStr -notmatch "USAGE:" -or $outStr -notmatch "COMMANDS:") {
        throw "Help output did not contain expected sections."
    }
}

# 3. Isolated Sandbox Integration Tests
$sandboxDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gswitch_test_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null
$sandboxConfig = Join-Path $sandboxDir "accounts.json"

try {
    $env:GIT_ACCOUNT_SWITCHER_CONFIG = $sandboxConfig

    Assert-Test "Empty config list handling" {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 list 2>&1
        $outStr = ($out | Out-String)
        if ($outStr -notmatch "No account profiles configured yet") {
            throw "Expected empty profile notice, got: $outStr"
        }
    }

    Assert-Test "Add profile non-interactively ('add octocat work')" {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 add octocat work "Mona Lisa" "mona@enterprise.com" 2>&1
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
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 add student-mona school "Mona Student" "mona@school.edu" 2>&1
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 2) {
            throw "Expected 2 accounts in sandbox, found $($json.Count). Raw content: $raw. Output: $out"
        }
    }

    Assert-Test "Update existing profile without duplicate key/user" {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 add octocat work "Mona Updated" "mona.new@enterprise.com" 2>&1
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 2) {
            throw "Expected 2 accounts after update, found $($json.Count) (duplicates were created)"
        }
        $workAcc = $json | Where-Object { $_.key -eq "work" }
        if ($workAcc.name -ne "Mona Updated") {
            throw "Account was not updated with new author name."
        }
    }

    Assert-Test "Add shortcut alias ('alias work w')" {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 alias work w 2>&1
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        $workAcc = $json | Where-Object { $_.key -eq "work" }
        $aliases = @($workAcc.aliases | ForEach-Object { $_.ToString().ToLower() })
        if ($aliases -notcontains "w") {
            throw "Expected alias 'w' in work account aliases, found: $($aliases -join ', ')"
        }
    }

    Assert-Test "Remove shortcut alias ('unalias work w')" {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 unalias work w 2>&1
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        $workAcc = $json | Where-Object { $_.key -eq "work" }
        $aliases = @($workAcc.aliases | ForEach-Object { $_.ToString().ToLower() })
        if ($aliases -contains "w") {
            throw "Expected alias 'w' to be removed from work account aliases, found: $($aliases -join ', ')"
        }
    }

    Assert-Test "Remove profile ('remove school -f')" {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SwitcherPs1 remove school -f 2>&1
        $raw = Get-Content -Path $sandboxConfig -Raw
        $json = $raw | ConvertFrom-Json
        if ($json.Count -ne 1) {
            throw "Expected 1 account remaining, found $($json.Count)"
        }
        if ($json[0].key -ne "work") {
            throw "Remaining account was not 'work'."
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
