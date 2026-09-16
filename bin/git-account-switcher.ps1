<#
.SYNOPSIS
    git-account-switcher (gswitch) - Fast Multi-Account GitHub & Git Identity Switcher
.DESCRIPTION
    Switches active GitHub CLI token, Git user.name, and Git user.email in one command.
    Supports global and repository-local switching, auto-syncing from GitHub CLI,
    and profile management.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Argument,

    [switch]$Local,
    [switch]$Global,
    [Alias("h")]
    [switch]$Help
)

$ConfigFile = "$HOME\.config\git-account-switcher\accounts.json"
$ConfigDir  = "$HOME\.config\git-account-switcher"

function Get-Accounts {
    $list = @()
    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
            foreach ($item in $json) {
                $list += @{
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
        } catch {
            Write-Host "[WARNING] Could not parse $ConfigFile : $_" -ForegroundColor Yellow
        }
    }
    return $list
}

function Save-Accounts($accountsList) {
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    $export = @()
    $idx = 1
    foreach ($a in $accountsList) {
        $export += [PSCustomObject]@{
            index       = $idx
            key         = $a.Key
            aliases     = $a.AliasList
            label       = $a.Label
            username    = $a.Username
            name        = $a.Name
            email       = $a.Email
            description = $a.Description
        }
        $idx++
    }
    $export | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8
}

function Get-ActiveGhUser {
    try {
        $u = gh api user --jq "{login: .login, name: .name}" 2>$null | ConvertFrom-Json
        return $u.login
    } catch {
        return "(none / not logged in)"
    }
}

function Show-Status {
    $activeGh = Get-ActiveGhUser
    $globalName  = git config --global user.name 2>$null
    $globalEmail = git config --global user.email 2>$null
    
    $isRepo = (git rev-parse --is-inside-work-tree 2>$null) -eq "true"
    $localName = $null
    $localEmail = $null
    if ($isRepo) {
        $localName  = git config --local user.name 2>$null
        $localEmail = git config --local user.email 2>$null
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " CURRENT GITHUB & GIT IDENTITY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " GitHub CLI Active : " -NoNewline; Write-Host "$activeGh" -ForegroundColor Green
    Write-Host " Git Global Name   : " -NoNewline; Write-Host "$globalName" -ForegroundColor Green
    Write-Host " Git Global Email  : " -NoNewline; Write-Host "$globalEmail" -ForegroundColor Green
    
    if ($isRepo -and ($localName -or $localEmail)) {
        Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [Repo Local Override detected in current directory]" -ForegroundColor Yellow
        Write-Host " Git Local Name    : " -NoNewline; Write-Host "$localName" -ForegroundColor Yellow
        Write-Host " Git Local Email   : " -NoNewline; Write-Host "$localEmail" -ForegroundColor Yellow
    }
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-List {
    $accounts = Get-Accounts
    $activeGh = Get-ActiveGhUser
    
    Write-Host ""
    Write-Host "Configured Account Profiles ($($accounts.Count)):" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor DarkGray
    foreach ($a in $accounts) {
        $isActive = ($a.Username.ToLower() -eq $activeGh.ToLower())
        if ($isActive) {
            Write-Host " > [$($a.Index)] " -NoNewline -ForegroundColor Green
            Write-Host "$($a.Label.PadRight(18)) " -NoNewline -ForegroundColor Green
            Write-Host "$($a.Username.PadRight(18)) " -NoNewline -ForegroundColor Green
            Write-Host "$($a.Email.PadRight(42)) " -NoNewline -ForegroundColor Green
            Write-Host "* ACTIVE" -ForegroundColor Green
        } else {
            Write-Host "   [$($a.Index)] " -NoNewline -ForegroundColor White
            Write-Host "$($a.Label.PadRight(18)) " -NoNewline -ForegroundColor White
            Write-Host "$($a.Username.PadRight(18)) " -NoNewline -ForegroundColor Gray
            Write-Host "$($a.Email.PadRight(42)) " -NoNewline -ForegroundColor DarkGray
            Write-Host "(key: $($a.Key))" -ForegroundColor DarkCyan
        }
    }
    Write-Host "================================================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Switch-Account($acc, [bool]$isLocalSwitch) {
    Write-Host ""
    Write-Host ">> Switching to account: [$($acc.Label)] ($($acc.Username))..." -ForegroundColor Yellow
    
    # 1. Switch GitHub CLI
    $switchOutput = gh auth switch -u $acc.Username 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to switch GitHub CLI: $switchOutput" -ForegroundColor Red
        return
    }
    
    # 2. Switch Git Identity
    if ($isLocalSwitch) {
        $isRepo = (git rev-parse --is-inside-work-tree 2>$null) -eq "true"
        if (-not $isRepo) {
            Write-Host "[ERROR] Cannot apply --local: current directory is not a Git repository." -ForegroundColor Red
            return
        }
        git config --local user.name "$($acc.Name)"
        git config --local user.email "$($acc.Email)"
        Write-Host "[OK] GitHub CLI switched to : $($acc.Username)" -ForegroundColor Green
        Write-Host "[OK] Git user.name (LOCAL)  : $($acc.Name)" -ForegroundColor Green
        Write-Host "[OK] Git user.email (LOCAL) : $($acc.Email)" -ForegroundColor Green
        Write-Host ""
        Write-Host "=> Applied locally to this repository only!" -ForegroundColor Cyan
    } else {
        git config --global user.name "$($acc.Name)"
        git config --global user.email "$($acc.Email)"
        Write-Host "[OK] GitHub CLI switched to : $($acc.Username)" -ForegroundColor Green
        Write-Host "[OK] Git user.name (GLOBAL) : $($acc.Name)" -ForegroundColor Green
        Write-Host "[OK] Git user.email (GLOBAL): $($acc.Email)" -ForegroundColor Green
        Write-Host ""
        Write-Host "=> Ready to commit & push as $($acc.Label)!" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Sync-FromGitHubCli {
    Write-Host ""
    Write-Host "Scanning GitHub CLI for authenticated accounts..." -ForegroundColor Cyan
    
    $statusLines = gh auth status 2>&1
    $detectedUsernames = @()
    foreach ($line in $statusLines) {
        if ($line -match 'Logged in to .* account ([a-zA-Z0-9_-]+)') {
            $detectedUsernames += $matches[1]
        }
    }
    
    if ($detectedUsernames.Count -eq 0) {
        Write-Host "[WARNING] No authenticated GitHub CLI accounts found." -ForegroundColor Yellow
        Write-Host "          Run 'gh auth login' first to sign in to your accounts." -ForegroundColor Gray
        return
    }
    
    Write-Host "Found $($detectedUsernames.Count) account(s): $($detectedUsernames -join ', ')" -ForegroundColor Green
    
    $existing = Get-Accounts
    $origUser = Get-ActiveGhUser
    $newList = @()
    $idx = 1
    
    foreach ($u in $detectedUsernames) {
        Write-Host "  Fetching account details for '$u'..." -ForegroundColor DarkGray
        gh auth switch -u $u 2>$null | Out-Null
        $userInfo = gh api user --jq "{id: .id, login: .login, name: .name, email: .email}" 2>$null | ConvertFrom-Json
        
        $userId   = if ($userInfo.id) { $userInfo.id } else { "0" }
        $userName = if ($userInfo.name) { $userInfo.name } else { $u }
        $userEmail = "$userId+$u@users.noreply.github.com"
        
        # Check if already in config to preserve custom label/key
        $match = $existing | Where-Object { $_.Username.ToLower() -eq $u.ToLower() }
        $key = if ($match -and $match.Key) { $match.Key } else { $u.ToLower() }
        $label = if ($match -and $match.Label) { $match.Label } else { $u }
        $desc = if ($match -and $match.Description) { $match.Description } else { "GitHub account $u" }
        $aliases = if ($match -and $match.AliasList) { $match.AliasList } else { @("$idx", $key, $u.ToLower()) }
        
        $newList += @{
            Index       = $idx
            Key         = $key
            AliasList   = $aliases
            Label       = $label
            Username    = $u
            Name        = $userName
            Email       = $userEmail
            Description = $desc
        }
        $idx++
    }

    if ($origUser -and $origUser -ne "(none / not logged in)") {
        gh auth switch -u $origUser 2>$null | Out-Null
    }
    
    Save-Accounts $newList
    Write-Host ""
    Write-Host "[OK] Successfully synced $($newList.Count) account(s) to $ConfigFile!" -ForegroundColor Green
    Show-List
}

function Show-HelpMessage {
    Write-Host @"
git-account-switcher (gswitch) ⚡
Fast Multi-Account GitHub & Git Identity Switcher

USAGE:
  gswitch [account]           Switch to account globally (by keyword or index)
  gswitch -l [account]        Switch to account locally (current repository only)
  gswitch                     Interactive selection menu
  gswitch status | who        Show current active GitHub token & Git identities
  gswitch list | ls           List all configured accounts
  gswitch sync                Auto-discover & sync logged-in GitHub CLI accounts

EXAMPLES:
  gswitch main
  gswitch work
  gswitch 1
  gswitch -l work             # Applies user.name/email to this repo only
  gswitch sync                # Auto-imports all accounts from 'gh auth status'
"@
}

# -------------------------------------------------------------
# Dispatcher
# -------------------------------------------------------------
if ($Help -or $Command -in @("help", "-h", "--help")) {
    Show-HelpMessage
    exit 0
}

if ($Command -in @("status", "who", "current", "-s")) {
    Show-Status
    exit 0
}

if ($Command -in @("list", "ls")) {
    Show-List
    exit 0
}

if ($Command -in @("sync", "import")) {
    Sync-FromGitHubCli
    exit 0
}

# Handle local flag passed before command: gswitch -l <target>
$targetArg = $Command
$applyLocal = $Local.IsPresent

if ($Command -in @("-l", "--local")) {
    $applyLocal = $true
    $targetArg = $Argument
}

$accounts = Get-Accounts

# If no target argument provided, display interactive selector
if (-not $targetArg) {
    Show-Status
    Write-Host "Available accounts:" -ForegroundColor Yellow
    foreach ($a in $accounts) {
        Write-Host " [$($a.Index)] " -NoNewline -ForegroundColor White
        Write-Host "$($a.Label.PadRight(18)) " -NoNewline -ForegroundColor Green
        Write-Host "$($a.Email.PadRight(48)) " -NoNewline -ForegroundColor Gray
        Write-Host "(key: $($a.Key))" -ForegroundColor DarkCyan
    }
    Write-Host ""
    $choice = Read-Host "Select account [1-$($accounts.Count)], 's' to sync, or Enter to cancel"
    if ($choice -match '^[sS]$') {
        Sync-FromGitHubCli
        exit 0
    }
    if ($choice) {
        $targetArg = $choice
    } else {
        Write-Host "Cancelled." -ForegroundColor Gray
        exit 0
    }
}

# Resolve target account
$selected = $null
$cleanTarget = $targetArg.Trim().ToLower()
foreach ($a in $accounts) {
    if ($a.Index.ToString() -eq $cleanTarget -or `
        $a.Key.ToLower() -eq $cleanTarget -or `
        $a.Username.ToLower() -eq $cleanTarget -or `
        ($a.AliasList -contains $cleanTarget)) {
        $selected = $a
        break
    }
}

if ($selected) {
    Switch-Account $selected $applyLocal
} else {
    Write-Host "[ERROR] Account '$targetArg' not found. Run 'gswitch list' to view available accounts or 'gswitch sync' to auto-detect." -ForegroundColor Red
    exit 1
}
