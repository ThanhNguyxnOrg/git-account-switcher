<#
.SYNOPSIS
    git-account-switcher (gswitch) - Fast Multi-Account GitHub & Git Identity Switcher
.DESCRIPTION
    Switches active GitHub CLI token, Git user.name, and Git user.email in one command.
    Supports global and repository-local switching, first-time setup wizard,
    auto-syncing from GitHub CLI, and dynamic account management.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Argument,

    [Parameter(Position = 2)]
    [string]$Extra1,

    [Parameter(Position = 3)]
    [string]$Extra2,

    [Parameter(Position = 4)]
    [string]$Extra3,

    [Parameter(Position = 5)]
    [string]$Extra4,

    [switch]$Local,
    [switch]$Global,
    [switch]$Force,
    [Alias("h")]
    [switch]$Help
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigFile = if ($env:GIT_ACCOUNT_SWITCHER_CONFIG) { $env:GIT_ACCOUNT_SWITCHER_CONFIG } else { "$HOME\.config\git-account-switcher\accounts.json" }
$ConfigDir  = if ($ConfigFile) { [System.IO.Path]::GetDirectoryName($ConfigFile) } else { "$HOME\.config\git-account-switcher" }

function Get-Accounts {
    $list = New-Object System.Collections.ArrayList
    if (Test-Path $ConfigFile) {
        try {
            $raw = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
            if ($raw -and $raw.Trim()) {
                $json = $raw | ConvertFrom-Json
                $idx = 1
                foreach ($item in $json) {
                    $null = $list.Add([PSCustomObject]@{
                        Index       = $idx
                        Key         = [string]$item.key
                        AliasList   = [string[]]$item.aliases
                        Label       = [string]$item.label
                        Username    = [string]$item.username
                        Name        = [string]$item.name
                        Email       = [string]$item.email
                        Description = [string]$item.description
                    })
                    $idx++
                }
            }
        } catch {
            Write-Host "[WARNING] Could not parse $ConfigFile : $_" -ForegroundColor Yellow
        }
    }
    return @($list)
}

function Save-Accounts($accountsList) {
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    $export = @()
    $idx = 1
    foreach ($a in @($accountsList)) {
        $export += [PSCustomObject]@{
            index       = $idx
            key         = [string]$a.Key
            aliases     = [string[]]$a.AliasList
            label       = [string]$a.Label
            username    = [string]$a.Username
            name        = [string]$a.Name
            email       = [string]$a.Email
            description = [string]$a.Description
        }
        $idx++
    }

    if ($export.Count -eq 0) {
        "[]" | Set-Content -Path $ConfigFile -Encoding UTF8
    } elseif ($export.Count -eq 1) {
        $single = $export[0] | ConvertTo-Json -Depth 5
        "[`n$single`n]" | Set-Content -Path $ConfigFile -Encoding UTF8
    } else {
        $export | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8
    }
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
    
    $effectiveName  = git config user.name 2>$null
    $effectiveEmail = git config user.email 2>$null

    if ($isRepo -and ($localName -or $localEmail)) {
        Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [Repo Local Override detected in current directory]" -ForegroundColor Yellow
        Write-Host " Git Local Name    : " -NoNewline; Write-Host "$localName" -ForegroundColor Yellow
        Write-Host " Git Local Email   : " -NoNewline; Write-Host "$localEmail" -ForegroundColor Yellow
    } elseif ($effectiveEmail -and ($effectiveEmail -ne $globalEmail -or $effectiveName -ne $globalName)) {
        Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [Folder includeIf Binding Active in this directory]" -ForegroundColor Yellow
        Write-Host " Effective Name    : " -NoNewline; Write-Host "$effectiveName" -ForegroundColor Yellow
        Write-Host " Effective Email   : " -NoNewline; Write-Host "$effectiveEmail" -ForegroundColor Yellow
    }
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-List {
    $accounts = Get-Accounts
    $activeGh = Get-ActiveGhUser
    
    if ($accounts.Count -eq 0) {
        Write-Host ""
        Write-Host "[INFO] No account profiles configured yet." -ForegroundColor Yellow
        Write-Host "       Run 'gswitch setup', 'gswitch add', or 'gswitch sync' to add accounts." -ForegroundColor Gray
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host "Configured Account Profiles ($($accounts.Count)):" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor DarkGray
    foreach ($a in $accounts) {
        $isActive = ($a.Username.ToLower() -eq $activeGh.ToLower())
        $aliasStr = if ($a.AliasList) { ($a.AliasList -join ', ') } else { "$($a.Index), $($a.Key)" }
        if ($isActive) {
            Write-Host " > [$($a.Index)] " -NoNewline -ForegroundColor Green
            Write-Host "$($a.Label.PadRight(16)) " -NoNewline -ForegroundColor Green
            Write-Host "$($a.Username.PadRight(16)) " -NoNewline -ForegroundColor Green
            Write-Host "$($a.Email.PadRight(40)) " -NoNewline -ForegroundColor Green
            Write-Host "* ACTIVE" -ForegroundColor Green
            Write-Host "       Aliases: $aliasStr" -ForegroundColor DarkGreen
        } else {
            Write-Host "   [$($a.Index)] " -NoNewline -ForegroundColor White
            Write-Host "$($a.Label.PadRight(16)) " -NoNewline -ForegroundColor White
            Write-Host "$($a.Username.PadRight(16)) " -NoNewline -ForegroundColor Gray
            Write-Host "$($a.Email.PadRight(40)) " -NoNewline -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "       Aliases: $aliasStr" -ForegroundColor DarkCyan
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

function Add-AccountInteractive([string]$passedUser, [string]$passedKey, [string]$passedName, [string]$passedEmail, [string]$passedLabel, [string]$passedAliases) {
    Write-Host ""
    Write-Host "=== Add New GitHub Account Profile ===" -ForegroundColor Cyan
    
    $user = $passedUser
    if (-not $user) {
        $user = Read-Host "Enter GitHub Username (e.g. octocat)"
    }
    if (-not $user) {
        Write-Host "Cancelled: username cannot be empty." -ForegroundColor Gray
        return
    }

    Write-Host "Querying GitHub user details for '$user'..." -ForegroundColor DarkGray
    $userId = "0"
    $defaultName = $user
    try {
        $info = gh api "users/$user" --jq "{id: .id, login: .login, name: .name}" 2>$null | ConvertFrom-Json
        if ($info.id) { $userId = $info.id }
        if ($info.name) { $defaultName = $info.name }
    } catch {}

    $key = $passedKey
    if (-not $key) {
        $key = Read-Host "Enter role/key for quick switching (e.g. work, personal, school) [default: $($user.ToLower())]"
    }
    if (-not $key) { $key = $user.ToLower() }

    $label = $passedLabel
    if (-not $label) {
        if ($passedUser -and $passedKey) {
            $label = (Get-Culture).TextInfo.ToTitleCase($key)
        } else {
            $label = Read-Host "Enter display label [default: $user]"
        }
    }
    if (-not $label) { $label = $user }

    $commitName = $passedName
    if (-not $commitName) {
        if ($passedUser -and $passedKey) {
            $commitName = $defaultName
        } else {
            $commitName = Read-Host "Enter Git commit author name [default: $defaultName]"
        }
    }
    if (-not $commitName) { $commitName = $defaultName }

    $defaultEmail = if ($userId -ne "0") { "$userId+$user@users.noreply.github.com" } else { "$user@users.noreply.github.com" }
    $commitEmail = $passedEmail
    if (-not $commitEmail) {
        if ($passedUser -and $passedKey) {
            $commitEmail = $defaultEmail
        } else {
            $commitEmail = Read-Host "Enter Git commit email [default: $defaultEmail]"
        }
    }
    if (-not $commitEmail) { $commitEmail = $defaultEmail }

    $customAliases = $passedAliases
    if (-not $customAliases -and -not ($passedUser -and $passedKey)) {
        $customAliases = Read-Host "Enter additional shortcut aliases (comma-separated, e.g. 'work, w, corp') [optional]"
    }

    $accounts = New-Object System.Collections.ArrayList
    foreach ($item in @(Get-Accounts)) {
        if ($item.Key.ToLower() -ne $key.ToLower() -and $item.Username.ToLower() -ne $user.ToLower()) {
            $null = $accounts.Add($item)
        } else {
            Write-Host "[INFO] Updating existing profile for '$($item.Label)' ($($item.Username))..." -ForegroundColor Yellow
        }
    }

    $newIdx = $accounts.Count + 1
    $aliasSet = New-Object System.Collections.Generic.List[string]
    $null = $aliasSet.Add("$newIdx")
    if ($aliasSet -notcontains $key.ToLower()) { $null = $aliasSet.Add($key.ToLower()) }
    if ($aliasSet -notcontains $user.ToLower()) { $null = $aliasSet.Add($user.ToLower()) }
    if ($customAliases) {
        $parts = $customAliases -split '[,; ]+'
        foreach ($p in $parts) {
            $cleaned = $p.Trim().ToLower()
            if ($cleaned -and ($aliasSet -notcontains $cleaned)) {
                $null = $aliasSet.Add($cleaned)
            }
        }
    }

    $null = $accounts.Add([PSCustomObject]@{
        Index       = $newIdx
        Key         = $key.ToLower()
        AliasList   = @($aliasSet)
        Label       = $label
        Username    = $user
        Name        = $commitName
        Email       = $commitEmail
        Description = "$label account ($user)"
    })

    Save-Accounts $accounts
    Write-Host ""
    Write-Host "[OK] Account '$label' ($user) successfully configured!" -ForegroundColor Green
    Show-List
}

function Remove-Account([string]$target, [bool]$forceDelete) {
    if (-not $target) {
        Show-List
        $target = Read-Host "Enter account number, key, username, or alias to remove (or Enter to cancel)"
    }
    if (-not $target) {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    $accounts = @(Get-Accounts)
    $clean = $target.Trim().ToLower()
    $match = $null

    foreach ($a in $accounts) {
        $aliasesLower = @($a.AliasList | ForEach-Object { $_.ToString().ToLower() })
        if ($a.Index.ToString() -eq $clean -or $a.Key.ToLower() -eq $clean -or $a.Username.ToLower() -eq $clean -or ($aliasesLower -contains $clean)) {
            $match = $a
            break
        }
    }

    if (-not $match) {
        Write-Host "[ERROR] Account '$target' not found. Run 'gswitch list' to view available accounts." -ForegroundColor Red
        return
    }

    $proceed = $forceDelete
    if (-not $proceed) {
        $confirm = Read-Host "Are you sure you want to remove '$($match.Label)' ($($match.Username))? [y/N]"
        $proceed = ($confirm -match '^[yY]$')
    }

    if ($proceed) {
        $remaining = New-Object System.Collections.ArrayList
        foreach ($a in $accounts) {
            if ($a.Username.ToLower() -ne $match.Username.ToLower() -and $a.Key.ToLower() -ne $match.Key.ToLower()) {
                $null = $remaining.Add($a)
            }
        }
        Save-Accounts $remaining
        Write-Host ""
        Write-Host "[OK] Account '$($match.Label)' ($($match.Username)) removed successfully." -ForegroundColor Green
        Show-List
    } else {
        Write-Host "Cancelled." -ForegroundColor Gray
    }
}

function Add-Alias-To-Account([string]$target, [string]$newAlias) {
    $accounts = @(Get-Accounts)
    if ($accounts.Count -eq 0) {
        Write-Host "[ERROR] No accounts configured yet. Run 'gswitch add' or 'gswitch setup'." -ForegroundColor Red
        return
    }

    if (-not $target) {
        Show-List
        $target = Read-Host "Enter account number, key, or username to add alias to"
    }
    if (-not $target) {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    $cleanTarget = $target.Trim().ToLower()
    $match = $null
    foreach ($a in $accounts) {
        $aliasesLower = @($a.AliasList | ForEach-Object { $_.ToString().ToLower() })
        if ($a.Index.ToString() -eq $cleanTarget -or $a.Key.ToLower() -eq $cleanTarget -or $a.Username.ToLower() -eq $cleanTarget -or ($aliasesLower -contains $cleanTarget)) {
            $match = $a
            break
        }
    }

    if (-not $match) {
        Write-Host "[ERROR] Account '$target' not found. Run 'gswitch list' to view accounts." -ForegroundColor Red
        return
    }

    if (-not $newAlias) {
        Write-Host "Account selected: $($match.Label) ($($match.Username))" -ForegroundColor Cyan
        Write-Host "Current aliases : $($match.AliasList -join ', ')" -ForegroundColor Gray
        $newAlias = Read-Host "Enter new shortcut alias (e.g. 'w', 'corp', 'main')"
    }
    if (-not $newAlias) {
        Write-Host "Cancelled: alias cannot be empty." -ForegroundColor Gray
        return
    }

    $cleanAlias = $newAlias.Trim().ToLower()

    # Check if this alias is already claimed by another account
    foreach ($a in $accounts) {
        if ($a.Username.ToLower() -ne $match.Username.ToLower()) {
            $otherAliases = @($a.AliasList | ForEach-Object { $_.ToString().ToLower() })
            if ($a.Key.ToLower() -eq $cleanAlias -or $a.Username.ToLower() -eq $cleanAlias -or ($otherAliases -contains $cleanAlias)) {
                Write-Host "[WARNING] Alias '$cleanAlias' is already used by '$($a.Label)' ($($a.Username))." -ForegroundColor Yellow
                $confirm = Read-Host "Do you want to reassign this alias to '$($match.Label)'? [y/N]"
                if ($confirm -notmatch '^[yY]$') {
                    Write-Host "Cancelled." -ForegroundColor Gray
                    return
                }
                # Remove from other account
                $newOther = @($a.AliasList | Where-Object { $_.ToString().ToLower() -ne $cleanAlias })
                $a.AliasList = $newOther
            }
        }
    }

    $curAliases = @($match.AliasList | ForEach-Object { $_.ToString().ToLower() })
    if ($curAliases -contains $cleanAlias) {
        Write-Host "[INFO] Account '$($match.Label)' already has alias '$cleanAlias'." -ForegroundColor Yellow
        return
    }

    $match.AliasList = @($match.AliasList) + $cleanAlias
    Save-Accounts $accounts
    Write-Host ""
    Write-Host "[OK] Added alias '$cleanAlias' to account '$($match.Label)' ($($match.Username))!" -ForegroundColor Green
    Write-Host "     All aliases: $($match.AliasList -join ', ')" -ForegroundColor DarkCyan
    Write-Host ""
}

function Remove-Alias-From-Account([string]$target, [string]$aliasToRemove) {
    $accounts = @(Get-Accounts)
    if ($accounts.Count -eq 0) {
        Write-Host "[ERROR] No accounts configured yet." -ForegroundColor Red
        return
    }

    if (-not $target) {
        Show-List
        $target = Read-Host "Enter account number, key, or username to remove alias from"
    }
    if (-not $target) {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    $cleanTarget = $target.Trim().ToLower()
    $match = $null
    foreach ($a in $accounts) {
        $aliasesLower = @($a.AliasList | ForEach-Object { $_.ToString().ToLower() })
        if ($a.Index.ToString() -eq $cleanTarget -or $a.Key.ToLower() -eq $cleanTarget -or $a.Username.ToLower() -eq $cleanTarget -or ($aliasesLower -contains $cleanTarget)) {
            $match = $a
            break
        }
    }

    if (-not $match) {
        Write-Host "[ERROR] Account '$target' not found." -ForegroundColor Red
        return
    }

    if (-not $aliasToRemove) {
        Write-Host "Current aliases for '$($match.Label)': $($match.AliasList -join ', ')" -ForegroundColor Cyan
        $aliasToRemove = Read-Host "Enter alias to remove"
    }
    if (-not $aliasToRemove) {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    $cleanAlias = $aliasToRemove.Trim().ToLower()
    $remainingAliases = @($match.AliasList | Where-Object { $_.ToString().ToLower() -ne $cleanAlias })

    if ($remainingAliases.Count -eq $match.AliasList.Count) {
        Write-Host "[WARNING] Alias '$cleanAlias' was not found on '$($match.Label)'." -ForegroundColor Yellow
        return
    }

    $match.AliasList = $remainingAliases
    Save-Accounts $accounts
    Write-Host ""
    Write-Host "[OK] Removed alias '$cleanAlias' from account '$($match.Label)'." -ForegroundColor Green
    Write-Host "     Remaining aliases: $($match.AliasList -join ', ')" -ForegroundColor DarkCyan
    Write-Host ""
}

function Open-ConfigEditor {
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $ConfigFile)) {
        "[]" | Set-Content -Path $ConfigFile -Encoding UTF8
    }

    Write-Host ""
    Write-Host "Configuration file location:" -ForegroundColor Cyan
    Write-Host "  $ConfigFile" -ForegroundColor Green
    Write-Host ""

    $codeCmd = Get-Command "code" -ErrorAction SilentlyContinue
    if ($codeCmd) {
        Write-Host "Opening in VS Code..." -ForegroundColor DarkGray
        Start-Process "code" -ArgumentList "`"$ConfigFile`""
        return
    }

    if ($IsWindows -or $env:OS -match "Windows") {
        Write-Host "Opening in Notepad..." -ForegroundColor DarkGray
        Start-Process "notepad.exe" -ArgumentList "`"$ConfigFile`""
        return
    }

    if ($env:EDITOR) {
        & $env:EDITOR $ConfigFile
        return
    }

    Write-Host "You can edit this file directly in your favorite text editor." -ForegroundColor Gray
}

function Bind-FolderToAccount([string]$folderPath, [string]$targetAccount) {
    if (-not $folderPath) {
        $folderPath = Read-Host "Enter folder path to bind (e.g. C:\Projects\Work or ~/projects/work)"
    }
    if (-not $folderPath) {
        Write-Host "Cancelled: folder path cannot be empty." -ForegroundColor Gray
        return
    }

    $resolvedFolder = $folderPath
    try {
        if (Test-Path $folderPath) {
            $resolvedFolder = (Resolve-Path $folderPath).Path
        }
    } catch {}

    $accounts = @(Get-Accounts)
    if ($accounts.Count -eq 0) {
        Write-Host "[ERROR] No accounts configured yet." -ForegroundColor Red
        return
    }

    if (-not $targetAccount) {
        Show-List
        $targetAccount = Read-Host "Enter account number, key, username, or alias to bind to this folder"
    }
    if (-not $targetAccount) {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    $cleanTarget = $targetAccount.Trim().ToLower()
    $match = $null
    foreach ($a in $accounts) {
        $aliasesLower = @($a.AliasList | ForEach-Object { $_.ToString().ToLower() })
        if ($a.Index.ToString() -eq $cleanTarget -or $a.Key.ToLower() -eq $cleanTarget -or $a.Username.ToLower() -eq $cleanTarget -or ($aliasesLower -contains $cleanTarget)) {
            $match = $a
            break
        }
    }

    if (-not $match) {
        Write-Host "[ERROR] Account '$targetAccount' not found." -ForegroundColor Red
        return
    }

    # Normalize folder path for gitdir (must use forward slashes / and end with /)
    $gitdirPattern = $resolvedFolder.Replace('\', '/').TrimEnd('/') + '/'

    # 1. Create included gitconfig file
    $profileConfigFile = "$HOME\.gitconfig-$($match.Key)"
    $configContent = "[user]`n    name = $($match.Name)`n    email = $($match.Email)`n"
    $configContent | Set-Content -Path $profileConfigFile -Encoding UTF8

    # 2. Add to global ~/.gitconfig
    $includeKey = if ($IsWindows -or $env:OS -match "Windows") { "includeIf.gitdir/i:$gitdirPattern.path" } else { "includeIf.gitdir:$gitdirPattern.path" }
    $normalizedProfileConfig = $profileConfigFile.Replace('\', '/')
    git config --global $includeKey $normalizedProfileConfig

    Write-Host ""
    Write-Host "[OK] Folder '$resolvedFolder' successfully bound to account '$($match.Label)'!" -ForegroundColor Green
    Write-Host "     All Git repositories inside '$resolvedFolder' will automatically commit as:" -ForegroundColor Cyan
    Write-Host "     Name : $($match.Name)" -ForegroundColor Green
    Write-Host "     Email: $($match.Email)" -ForegroundColor Green
    Write-Host ""
}

function Unbind-Folder([string]$folderPath) {
    if (-not $folderPath) {
        Show-FolderBindings
        $folderPath = Read-Host "Enter folder path to unbind (or Enter to cancel)"
    }
    if (-not $folderPath) {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }

    $resolvedFolder = $folderPath
    try {
        if (Test-Path $folderPath) {
            $resolvedFolder = (Resolve-Path $folderPath).Path
        }
    } catch {}
    $gitdirPattern = $resolvedFolder.Replace('\', '/').TrimEnd('/') + '/'

    $keys = git config --global --name-only --get-regexp '^includeif\.gitdir' 2>$null
    $found = $false
    foreach ($k in $keys) {
        if ($k -like "*$gitdirPattern*") {
            git config --global --unset $k
            $found = $true
        }
    }

    if ($found) {
        Write-Host ""
        Write-Host "[OK] Unbound folder '$resolvedFolder'." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "[WARNING] No binding found matching '$resolvedFolder'." -ForegroundColor Yellow
        Write-Host ""
    }
}

function Show-FolderBindings {
    Write-Host ""
    Write-Host "Configured Folder Bindings (includeIf):" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor DarkGray
    $lines = git config --global --list --show-origin 2>$null | Where-Object { $_ -match 'includeif\.gitdir' }
    if (-not $lines) {
        Write-Host "  No folder bindings configured." -ForegroundColor Gray
        Write-Host "  Use 'gswitch bind <folder> <account>' to bind a folder to an account." -ForegroundColor DarkCyan
    } else {
        foreach ($l in $lines) {
            if ($l -match 'includeif\.gitdir(?:/i)?:(.*)\.path=(.*)') {
                $dir = $matches[1]
                $cfg = $matches[2]
                Write-Host "  Folder : " -NoNewline; Write-Host "$dir" -ForegroundColor Green
                Write-Host "  Config : " -NoNewline; Write-Host "$cfg" -ForegroundColor DarkCyan
                Write-Host ""
            }
        }
    }
    Write-Host "================================================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Setup-Wizard {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " git-account-switcher First-Time Setup Wizard" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This wizard will help you configure your GitHub accounts." -ForegroundColor White
    Write-Host ""

    # Check if gh CLI has accounts
    $statusLines = gh auth status 2>&1
    $detected = @()
    foreach ($line in $statusLines) {
        if ($line -match 'Logged in to .* account ([a-zA-Z0-9_-]+)') {
            $detected += $matches[1]
        }
    }

    if ($detected.Count -gt 0) {
        Write-Host "Found $($detected.Count) account(s) in GitHub CLI: $($detected -join ', ')" -ForegroundColor Green
        $auto = Read-Host "Would you like to auto-import them now? [Y/n]"
        if (-not $auto -or $auto -match '^[yY]$') {
            Sync-FromGitHubCli
            return
        }
    }

    Write-Host "Let's add your accounts one by one." -ForegroundColor Yellow
    $adding = $true
    while ($adding) {
        Add-AccountInteractive
        $more = Read-Host "Do you want to add another account? [y/N]"
        if ($more -notmatch '^[yY]$') {
            $adding = $false
        }
    }
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
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " git-account-switcher (gswitch) ⚡" -ForegroundColor Cyan
    Write-Host " Fast Multi-Account GitHub & Git Identity Switcher" -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  gswitch [account]                   Switch account globally (by key, username, alias, or index)" -ForegroundColor White
    Write-Host "  gswitch -l [account]                Switch account locally (current repository only)" -ForegroundColor White
    Write-Host "  gswitch                             Open interactive account selection menu" -ForegroundColor White
    Write-Host "  gswitch status | who                View active GitHub token & Git identities" -ForegroundColor White
    Write-Host "  gswitch list | ls                   List all configured account profiles with aliases" -ForegroundColor White
    Write-Host "  gswitch alias [acc] [shortcut]      Add or view shortcut aliases for quick switching" -ForegroundColor White
    Write-Host "  gswitch unalias [acc] [alias]       Remove a shortcut alias from an account profile" -ForegroundColor White
    Write-Host "  gswitch bind [dir] [account]        Permanently bind an entire folder to an account" -ForegroundColor White
    Write-Host "  gswitch unbind [dir]                Remove a folder binding" -ForegroundColor White
    Write-Host "  gswitch bindings                    List all active folder bindings (includeIf)" -ForegroundColor White
    Write-Host "  gswitch edit | config               Open accounts.json in VS Code / Notepad" -ForegroundColor White
    Write-Host "  gswitch sync                        Auto-discover & sync accounts from GitHub CLI" -ForegroundColor White
    Write-Host "  gswitch setup                       Launch interactive first-time setup wizard" -ForegroundColor White
    Write-Host "  gswitch add [user] [key] [name] [email]  Add or update an account profile" -ForegroundColor White
    Write-Host "  gswitch remove [key] [-f]           Remove an account profile and re-index list" -ForegroundColor White
    Write-Host "  gswitch help                        Display this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor Yellow
    Write-Host "  add      Add a new profile interactively or via args: gswitch add <user> <key> [name] [email]" -ForegroundColor White
    Write-Host "  alias    Add shortcut alias: gswitch alias <acc> <shortcut> (or list all if no args)" -ForegroundColor White
    Write-Host "  unalias  Remove shortcut alias: gswitch unalias <acc> <shortcut>" -ForegroundColor White
    Write-Host "  bind     Bind a directory to an account (includeIf): gswitch bind <dir> <account>" -ForegroundColor White
    Write-Host "  unbind   Remove a folder binding: gswitch unbind <dir>" -ForegroundColor White
    Write-Host "  bindings List all active directory bindings configured on system" -ForegroundColor White
    Write-Host "  edit     Open accounts.json directly in VS Code / Notepad / default editor" -ForegroundColor White
    Write-Host "  remove   Remove a profile by key, user, alias, or index: gswitch remove <key> [-f]" -ForegroundColor White
    Write-Host "  sync     Scan 'gh auth status', fetch IDs, and configure private noreply emails" -ForegroundColor White
    Write-Host "  setup    Launch the first-time guided setup wizard" -ForegroundColor White
    Write-Host "  status   Display active GitHub CLI user and global/local Git user.name & email" -ForegroundColor White
    Write-Host "  list     Display formatted table of all configured profiles with * ACTIVE badge" -ForegroundColor White
    Write-Host ""
    Write-Host "FLAGS:" -ForegroundColor Yellow
    Write-Host "  -l, --local                         Scope changes to current repository only (.git/config)" -ForegroundColor White
    Write-Host "  -g, --global                        Scope changes system-wide (default)" -ForegroundColor White
    Write-Host "  -f, --force                         Force action without interactive confirmation" -ForegroundColor White
    Write-Host "  -h, --help                          Show detailed help information" -ForegroundColor White
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  gswitch personal                    # Switch to 'personal' profile globally" -ForegroundColor Gray
    Write-Host "  gswitch work                        # Switch to 'work' profile globally" -ForegroundColor Gray
    Write-Host "  gswitch 1                           # Switch to profile #1" -ForegroundColor Gray
    Write-Host "  gswitch -l work                     # Apply 'work' author to THIS repository only" -ForegroundColor Gray
    Write-Host "  gswitch alias work w                # Add shortcut alias 'w' to work account" -ForegroundColor Gray
    Write-Host "  gswitch unalias work w              # Remove shortcut alias 'w' from work" -ForegroundColor Gray
    Write-Host "  gswitch bind C:\Projects\Work work  # All repos in C:\Projects\Work commit as work" -ForegroundColor Gray
    Write-Host "  gswitch unbind C:\Projects\Work     # Remove folder binding" -ForegroundColor Gray
    Write-Host "  gswitch bindings                    # View all active folder bindings" -ForegroundColor Gray
    Write-Host "  gswitch edit                        # Open accounts.json in editor" -ForegroundColor Gray
    Write-Host "  gswitch sync                        # Auto-import all accounts from 'gh auth status'" -ForegroundColor Gray
    Write-Host "  gswitch add                         # Add a new account interactively" -ForegroundColor Gray
    Write-Host "  gswitch add octocat work            # Add 'octocat' with key 'work' non-interactively" -ForegroundColor Gray
    Write-Host "  gswitch remove work                 # Remove the 'work' account profile" -ForegroundColor Gray
    Write-Host "  gswitch remove 2 -f                 # Force remove account #2 without confirmation" -ForegroundColor Gray
    Write-Host "  git who                             # Fast alias to inspect current identity" -ForegroundColor Gray
    Write-Host ""
    Write-Host "CONFIG PATH:" -ForegroundColor Yellow
    Write-Host "  $ConfigFile" -ForegroundColor DarkCyan
    Write-Host ""
}

# -------------------------------------------------------------
# Dispatcher
# -------------------------------------------------------------
if ($Help -or $Command -in @("help", "-h", "--help", "-?", "/?")) {
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

if ($Command -in @("setup", "init")) {
    Setup-Wizard
    exit 0
}

if ($Command -eq "add") {
    Add-AccountInteractive $Argument $Extra1 $Extra2 $Extra3 $Extra4
    exit 0
}

if ($Command -in @("alias", "aliases", "shortcut")) {
    if (-not $Argument) {
        Show-List
        exit 0
    }
    Add-Alias-To-Account $Argument $Extra1
    exit 0
}

if ($Command -in @("unalias", "rmalias")) {
    Remove-Alias-From-Account $Argument $Extra1
    exit 0
}

if ($Command -in @("bind", "folder", "link")) {
    Bind-FolderToAccount $Argument $Extra1
    exit 0
}

if ($Command -in @("unbind", "unlink")) {
    Unbind-Folder $Argument
    exit 0
}

if ($Command -in @("bindings", "folders", "dirs")) {
    Show-FolderBindings
    exit 0
}

if ($Command -in @("edit", "config")) {
    Open-ConfigEditor
    exit 0
}

if ($Command -in @("remove", "rm", "delete")) {
    $isForce = $Force.IsPresent -or ($Extra1 -in @("-f", "--force", "-y", "--yes")) -or ($Argument -in @("-f", "--force"))
    $target = if ($Argument -in @("-f", "--force")) { $Extra1 } else { $Argument }
    Remove-Account $target $isForce
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

# If no accounts exist at all, offer setup wizard
if ($accounts.Count -eq 0) {
    Write-Host "[INFO] No account profiles found." -ForegroundColor Yellow
    $runWizard = Read-Host "Would you like to run the first-time setup wizard now? [Y/n]"
    if (-not $runWizard -or $runWizard -match '^[yY]$') {
        Setup-Wizard
        exit 0
    } else {
        exit 0
    }
}

# If no target argument provided, display interactive selector
if (-not $targetArg) {
    Show-Status
    Write-Host "Available accounts:" -ForegroundColor Yellow
    foreach ($a in $accounts) {
        $aliasStr = if ($a.AliasList) { ($a.AliasList -join ', ') } else { "$($a.Index), $($a.Key)" }
        Write-Host " [$($a.Index)] " -NoNewline -ForegroundColor White
        Write-Host "$($a.Label.PadRight(16)) " -NoNewline -ForegroundColor Green
        Write-Host "$($a.Email.PadRight(40)) " -NoNewline -ForegroundColor Gray
        Write-Host "(aliases: $aliasStr)" -ForegroundColor DarkCyan
    }
    Write-Host ""
    $choice = Read-Host "Select account [1-$($accounts.Count)], 's' to sync, 'a' to add, 'e' to edit, or Enter to cancel"
    if ($choice -match '^[sS]$') {
        Sync-FromGitHubCli
        exit 0
    }
    if ($choice -match '^[aA]$') {
        Add-AccountInteractive
        exit 0
    }
    if ($choice -match '^[eE]$') {
        Open-ConfigEditor
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

# 1. Exact match
foreach ($a in $accounts) {
    $aliasesLower = @($a.AliasList | ForEach-Object { $_.ToString().ToLower() })
    if ($a.Index.ToString() -eq $cleanTarget -or `
        $a.Key.ToLower() -eq $cleanTarget -or `
        $a.Username.ToLower() -eq $cleanTarget -or `
        ($aliasesLower -contains $cleanTarget)) {
        $selected = $a
        break
    }
}

# 2. Fuzzy match fallback
if (-not $selected) {
    foreach ($a in $accounts) {
        if ($a.Username.ToLower().Contains($cleanTarget) -or `
            $cleanTarget.Contains($a.Username.ToLower()) -or `
            $a.Key.ToLower().Contains($cleanTarget) -or `
            $cleanTarget.Contains($a.Key.ToLower())) {
            $selected = $a
            break
        }
    }
}

if ($selected) {
    Switch-Account $selected $applyLocal
} else {
    Write-Host "[ERROR] Account '$targetArg' not found. Run 'gswitch list' to view available accounts or 'gswitch sync' to auto-detect." -ForegroundColor Red
    exit 1
}
