param(
    [string]$Target
)

# Determine configuration path
$configPaths = @(
    "$HOME\.config\git-account-switcher\accounts.json",
    "$HOME\.config\switch-git\accounts.json",
    "$PSScriptRoot\..\config\accounts.json",
    "$PSScriptRoot\accounts.json"
)

$accounts = @()
foreach ($cp in $configPaths) {
    if (Test-Path $cp) {
        try {
            $jsonContent = Get-Content -Path $cp -Raw | ConvertFrom-Json
            foreach ($item in $jsonContent) {
                $accounts += @{
                    Index       = [int]$item.index
                    Key         = [string]$item.key
                    AliasList   = [string[]]$item.aliases
                    Label       = [string]$item.label
                    Username    = [string]$item.username
                    Name        = [string]$item.name
                    Email       = [string]$item.email
                    Description = [string]$item.description
                }
            }
            break
        } catch {
            # continue checking next path
        }
    }
}

# Fallback default configuration if no JSON file exists
if ($accounts.Count -eq 0) {
    $accounts = @(
        @{
            Index       = 1
            Key         = "school"
            AliasList   = @("1", "school", "thanhnguyn")
            Label       = "School"
            Username    = "ThanhNguyn"
            Name        = "ThanhNguyn"
            Email       = "253024274+ThanhNguyn@users.noreply.github.com"
            Description = "School / Primary"
        },
        @{
            Index       = 2
            Key         = "real"
            AliasList   = @("2", "real", "realthanhnguyxn")
            Label       = "RealThanhNguyxn"
            Username    = "RealThanhNguyxn"
            Name        = "RealThanhNguyxn"
            Email       = "274720769+RealThanhNguyxn@users.noreply.github.com"
            Description = "Personal / Primary"
        },
        @{
            Index       = 3
            Key         = "07"
            AliasList   = @("3", "07", "thanhnguyxn07")
            Label       = "ThanhNguyxn07"
            Username    = "ThanhNguyxn07"
            Name        = "ThanhNguyxn07"
            Email       = "272073999+ThanhNguyxn07@users.noreply.github.com"
            Description = "Secondary / Work"
        }
    )
}

function Show-Status {
    $currentGh = ""
    try {
        $userJson = gh api user --jq "{login: .login, name: .name}" 2>$null | ConvertFrom-Json
        $currentGh = $userJson.login
    } catch {
        $currentGh = "(not logged in / gh error)"
    }
    $currentName = git config --global user.name
    $currentEmail = git config --global user.email

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " CURRENT GITHUB & GIT IDENTITY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " GitHub CLI Active : " -NoNewline; Write-Host "$currentGh" -ForegroundColor Green
    Write-Host " Git Global Name   : " -NoNewline; Write-Host "$currentName" -ForegroundColor Green
    Write-Host " Git Global Email  : " -NoNewline; Write-Host "$currentEmail" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Switch-Account($acc) {
    Write-Host ""
    Write-Host ">> Switching to account: [$($acc.Label)] ($($acc.Username))..." -ForegroundColor Yellow
    
    # 1. Switch GitHub CLI active account
    $switchOutput = gh auth switch -u $acc.Username 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to switch GitHub CLI account: $switchOutput" -ForegroundColor Red
        return
    }
    
    # 2. Switch Git global user config
    git config --global user.name "$($acc.Name)"
    git config --global user.email "$($acc.Email)"

    Write-Host "[OK] GitHub CLI switched to : $($acc.Username)" -ForegroundColor Green
    Write-Host "[OK] Git user.name set to   : $($acc.Name)" -ForegroundColor Green
    Write-Host "[OK] Git user.email set to  : $($acc.Email)" -ForegroundColor Green
    Write-Host ""
    Write-Host "=> Ready to commit & push as $($acc.Label)!" -ForegroundColor Cyan
    Write-Host ""
}

# Handle status/query options
if ($Target -in @("status", "who", "current", "-s")) {
    Show-Status
    exit 0
}

# Match target argument
$selected = $null
if ($Target) {
    $cleanTarget = $Target.Trim().ToLower()
    foreach ($acc in $accounts) {
        if ($acc.AliasList -contains $cleanTarget -or $acc.Username.ToLower() -eq $cleanTarget -or $acc.Key.ToLower() -eq $cleanTarget) {
            $selected = $acc
            break
        }
    }
}

# Interactive selection prompt if no valid target was provided
if (-not $selected) {
    Show-Status
    Write-Host "Available accounts:" -ForegroundColor Yellow
    foreach ($acc in $accounts) {
        Write-Host " [$($acc.Index)] " -NoNewline -ForegroundColor White
        Write-Host "$($acc.Label.PadRight(20)) " -NoNewline -ForegroundColor Green
        Write-Host "$($acc.Email.PadRight(52)) " -NoNewline -ForegroundColor Gray
        Write-Host "(Command: gswitch $($acc.Key))" -ForegroundColor DarkCyan
    }
    Write-Host ""
    $choice = Read-Host "Select account [1-$($accounts.Count)] or press Enter to cancel"
    if ($choice) {
        $cleanChoice = $choice.Trim().ToLower()
        foreach ($acc in $accounts) {
            if ($acc.AliasList -contains $cleanChoice -or $acc.Username.ToLower() -eq $cleanChoice -or $acc.Key.ToLower() -eq $cleanChoice) {
                $selected = $acc
                break
            }
        }
    } else {
        Write-Host "Cancelled." -ForegroundColor Gray
        exit 0
    }
}

if ($selected) {
    Switch-Account $selected
} else {
    Write-Host "Account not found for '$Target'." -ForegroundColor Red
    exit 1
}
