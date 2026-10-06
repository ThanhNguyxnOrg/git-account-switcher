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
    [switch]$Help,
    [Alias("v")]
    [switch]$Version
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SCRIPT_VERSION = "1.2.0"
$RAW_REPO_BASE  = "https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master"

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
                    $sKey = if ($item.signingkey) { [string]$item.signingkey } elseif ($item.signingKey) { [string]$item.signingKey } else { $null }
                    $null = $list.Add([PSCustomObject]@{
                        Index       = $idx
                        Key         = [string]$item.key
                        AliasList   = [string[]]$item.aliases
                        Label       = [string]$item.label
                        Username    = [string]$item.username
                        Name        = [string]$item.name
                        Email       = [string]$item.email
                        Description = [string]$item.description
                        SigningKey  = $sKey
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
        $cleanedAliases = New-Object System.Collections.Generic.List[string]
        $null = $cleanedAliases.Add("$idx")
        if ($a.AliasList) {
            foreach ($al in $a.AliasList) {
                $alStr = [string]$al
                if ($alStr -notmatch '^\d+$' -and -not $cleanedAliases.Contains($alStr.ToLower())) {
                    $null = $cleanedAliases.Add($alStr.ToLower())
                }
            }
        }
        if ($a.Key -and -not $cleanedAliases.Contains($a.Key.ToLower())) {
            $null = $cleanedAliases.Add($a.Key.ToLower())
        }
        if ($a.Username -and -not $cleanedAliases.Contains($a.Username.ToLower())) {
            $null = $cleanedAliases.Add($a.Username.ToLower())
        }

        $itemObj = [ordered]@{
            index       = $idx
            key         = [string]$a.Key
            aliases     = @($cleanedAliases)
            label       = [string]$a.Label
            username    = [string]$a.Username
            name        = [string]$a.Name
            email       = [string]$a.Email
            description = [string]$a.Description
        }
        $sKey = if ($a.SigningKey) { $a.SigningKey } elseif ($a.signingkey) { $a.signingkey } else { $null }
        if ($sKey) {
            $itemObj["signingkey"] = [string]$sKey
        }
        $export += [PSCustomObject]$itemObj
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
        $statusOut = gh auth status --active 2>&1
        foreach ($line in $statusOut) {
            if ($line -match 'Logged in to .* account ([a-zA-Z0-9_-]+)') {
                return $matches[1]
            }
        }
    } catch {}

    try {
        $u = gh api user --jq ".login" 2>$null
        if ($u -and $u.Trim()) { return $u.Trim() }
    } catch {}

    return "(none / not logged in)"
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
    $effectiveSign  = git config user.signingkey 2>$null

    if ($effectiveSign) {
        Write-Host " Git Signing Key   : " -NoNewline; Write-Host "$effectiveSign" -ForegroundColor Green
    }

    # Check if current directory matches any configured folder binding
    $currPath = (Get-Location).Path.Replace('\', '/').TrimEnd('/') + '/'
    $matchedBinding = $null
    $bindingLines = git config --global --list --show-origin 2>$null | Where-Object { $_ -match 'includeif\.gitdir' }
    foreach ($bl in $bindingLines) {
        if ($bl -match 'includeif\.gitdir(?:/i)?:(.*)\.path=(.*)') {
            $boundPat = $matches[1]
            $cfgTarget = $matches[2]
            $cleanPat = $boundPat.TrimEnd('/') + '/'
            if ($currPath.ToLower().StartsWith($cleanPat.ToLower())) {
                $matchedBinding = [PSCustomObject]@{
                    Pattern    = $boundPat
                    ConfigFile = $cfgTarget
                }
                break
            }
        }
    }

    if ($isRepo -and ($localName -or $localEmail)) {
        Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [Repo Local Override detected in current directory]" -ForegroundColor Yellow
        Write-Host " Git Local Name    : " -NoNewline; Write-Host "$localName" -ForegroundColor Yellow
        Write-Host " Git Local Email   : " -NoNewline; Write-Host "$localEmail" -ForegroundColor Yellow
        if ($matchedBinding) {
            Write-Host " [WARNING] Folder Binding active ($($matchedBinding.Pattern)) is currently SHADOWED by this local override!" -ForegroundColor Red
            Write-Host "           To inherit the folder account, run: git config --local --unset-all user.name; git config --local --unset-all user.email" -ForegroundColor DarkYellow
        }
    } elseif ($matchedBinding) {
        Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [Folder includeIf Binding Active in this directory]" -ForegroundColor Yellow
        Write-Host " Bound Folder      : " -NoNewline; Write-Host "$($matchedBinding.Pattern)" -ForegroundColor DarkCyan
        Write-Host " Effective Name    : " -NoNewline; Write-Host "$effectiveName" -ForegroundColor Green
        Write-Host " Effective Email   : " -NoNewline; Write-Host "$effectiveEmail" -ForegroundColor Green
        $boundUser = git config -f $matchedBinding.ConfigFile credential.https://github.com.username 2>$null
        if ($boundUser -and $activeGh -ne "(none / not logged in)" -and $activeGh.ToLower() -ne $boundUser.ToLower()) {
            Write-Host " [INFO] GitHub CLI is active as '$activeGh', while this folder commits/pushes as '$boundUser'." -ForegroundColor DarkYellow
            Write-Host "        To switch GitHub CLI commands (gh pr, gh issue) to '$boundUser', run: gswitch $boundUser" -ForegroundColor DarkGray
        }
    } elseif ($effectiveEmail -and ($effectiveEmail -ne $globalEmail -or $effectiveName -ne $globalName)) {
        Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [Folder includeIf Binding Active in this directory]" -ForegroundColor Yellow
        Write-Host " Effective Name    : " -NoNewline; Write-Host "$effectiveName" -ForegroundColor Yellow
        Write-Host " Effective Email   : " -NoNewline; Write-Host "$effectiveEmail" -ForegroundColor Yellow
    }

    if ($isRepo) {
        $remoteUrl = git config --get remote.origin.url 2>$null
        if ($remoteUrl) {
            Write-Host " ------------------------------------------------------------" -ForegroundColor DarkGray
            Write-Host " Remote Origin     : " -NoNewline; Write-Host "$remoteUrl" -ForegroundColor Gray
            if ($remoteUrl -match '^git@github\.com:' -or $remoteUrl -match '^ssh://') {
                Write-Host " [WARNING] Remote uses SSH ($remoteUrl)." -ForegroundColor Yellow
                Write-Host "           Git credential helper applies to HTTPS URLs." -ForegroundColor DarkYellow
                Write-Host "           To isolate push tokens with gswitch, switch remote to HTTPS:" -ForegroundColor DarkYellow
                Write-Host "           git remote set-url origin https://github.com/<org>/<repo>.git" -ForegroundColor DarkYellow
            }
        }
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
    
    $isRepo = (git rev-parse --is-inside-work-tree 2>$null) -eq "true"
    
    # 2. Switch Git Identity & Credential Helper
    if ($isLocalSwitch) {
        if (-not $isRepo) {
            Write-Host "[ERROR] Cannot apply --local: current directory is not a Git repository." -ForegroundColor Red
            return
        }
        git config --local user.name "$($acc.Name)"
        git config --local user.email "$($acc.Email)"
        git config --local credential.https://github.com.username "$($acc.Username)"
        git config --local --unset-all credential.https://github.com.helper 2>$null
        git config --local --add credential.https://github.com.helper "!git-account-switcher cred $($acc.Username)"
        git config --local credential.https://gist.github.com.username "$($acc.Username)"
        git config --local --unset-all credential.https://gist.github.com.helper 2>$null
        git config --local --add credential.https://gist.github.com.helper "!git-account-switcher cred $($acc.Username)"
        
        if ($acc.SigningKey) {
            git config --local user.signingkey "$($acc.SigningKey)"
            git config --local commit.gpgsign true
            if ($acc.SigningKey -match '^(ssh-|key::)') {
                git config --local gpg.format ssh
            }
            Write-Host "[OK] Git signingkey (LOCAL) : $($acc.SigningKey)" -ForegroundColor Green
        } else {
            git config --local --unset-all user.signingkey 2>$null
            git config --local --unset-all commit.gpgsign 2>$null
            git config --local --unset-all gpg.format 2>$null
        }

        Write-Host "[OK] GitHub CLI switched to : $($acc.Username)" -ForegroundColor Green
        Write-Host "[OK] Git user.name (LOCAL)  : $($acc.Name)" -ForegroundColor Green
        Write-Host "[OK] Git user.email (LOCAL) : $($acc.Email)" -ForegroundColor Green
        Write-Host "[OK] Git cred helper (LOCAL): !git-account-switcher cred $($acc.Username)" -ForegroundColor Green
        Write-Host ""
        Write-Host "=> Applied locally with isolated push permissions for this repository only!" -ForegroundColor Cyan
    } else {
        if ($isRepo) {
            $hasLocalName = git config --local user.name 2>$null
            $hasLocalEmail = git config --local user.email 2>$null
            $hasLocalCred = git config --local credential.https://github.com.username 2>$null
            $hasLocalSign = git config --local user.signingkey 2>$null
            if ($hasLocalName -or $hasLocalEmail -or $hasLocalCred -or $hasLocalSign) {
                git config --local --unset-all user.name 2>$null
                git config --local --unset-all user.email 2>$null
                git config --local --unset-all credential.https://github.com.username 2>$null
                git config --local --unset-all credential.https://github.com.helper 2>$null
                git config --local --unset-all credential.https://gist.github.com.username 2>$null
                git config --local --unset-all credential.https://gist.github.com.helper 2>$null
                git config --local --unset-all user.signingkey 2>$null
                git config --local --unset-all commit.gpgsign 2>$null
                git config --local --unset-all gpg.format 2>$null
                Write-Host "[INFO] Cleared repository-local overrides in current repository." -ForegroundColor Yellow
            }
        }
        
        git config --global user.name "$($acc.Name)"
        git config --global user.email "$($acc.Email)"
        if ($acc.SigningKey) {
            git config --global user.signingkey "$($acc.SigningKey)"
            git config --global commit.gpgsign true
            if ($acc.SigningKey -match '^(ssh-|key::)') {
                git config --global gpg.format ssh
            }
            Write-Host "[OK] Git signingkey (GLOBAL): $($acc.SigningKey)" -ForegroundColor Green
        } else {
            git config --global --unset-all user.signingkey 2>$null
            git config --global --unset-all commit.gpgsign 2>$null
            git config --global --unset-all gpg.format 2>$null
        }

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

    $existingAcc = $null
    $accounts = New-Object System.Collections.ArrayList
    foreach ($item in @(Get-Accounts)) {
        if ($item.Key.ToLower() -ne $key.ToLower() -and $item.Username.ToLower() -ne $user.ToLower()) {
            $null = $accounts.Add($item)
        } else {
            $existingAcc = $item
            Write-Host "[INFO] Updating existing profile for '$($item.Label)' ($($item.Username))..." -ForegroundColor Yellow
        }
    }

    $newIdx = $accounts.Count + 1
    $aliasSet = New-Object System.Collections.Generic.List[string]
    $null = $aliasSet.Add("$newIdx")
    if ($aliasSet -notcontains $key.ToLower()) { $null = $aliasSet.Add($key.ToLower()) }
    if ($aliasSet -notcontains $user.ToLower()) { $null = $aliasSet.Add($user.ToLower()) }
    # Preserve existing custom text aliases if updating
    if ($existingAcc -and $existingAcc.AliasList) {
        foreach ($al in $existingAcc.AliasList) {
            $alStr = [string]$al
            if ($alStr -notmatch '^\d+$' -and -not $aliasSet.Contains($alStr.ToLower())) {
                $null = $aliasSet.Add($alStr.ToLower())
            }
        }
    }
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

    # 1. Create included gitconfig file (authorship + isolated credential helper)
    $profileConfigFile = "$HOME\.gitconfig-$($match.Key)"
    $signingSection = ""
    if ($match.SigningKey) {
        $signingSection = "`n    signingkey = $($match.SigningKey)`n[commit]`n    gpgsign = true"
        if ($match.SigningKey -match '^(ssh-|key::)') {
            $signingSection += "`n[gpg]`n    format = ssh"
        }
    }
    $configContent = @"
[user]
    name = $($match.Name)
    email = $($match.Email)$signingSection
[credential "https://github.com"]
    username = $($match.Username)
    helper = 
    helper = "!git-account-switcher cred $($match.Username)"
[credential "https://gist.github.com"]
    username = $($match.Username)
    helper = 
    helper = "!git-account-switcher cred $($match.Username)"
"@
    $configContent | Set-Content -Path $profileConfigFile -Encoding UTF8

    # 2. Add to global ~/.gitconfig
    $includeKey = if ($IsWindows -or $env:OS -match "Windows") { "includeIf.gitdir/i:$gitdirPattern.path" } else { "includeIf.gitdir:$gitdirPattern.path" }
    $normalizedProfileConfig = $profileConfigFile.Replace('\', '/')
    git config --global $includeKey $normalizedProfileConfig

    Write-Host ""
    Write-Host "[OK] Folder '$resolvedFolder' successfully bound to account '$($match.Label)'!" -ForegroundColor Green
    Write-Host "     All Git repositories inside '$resolvedFolder' will automatically commit & push as:" -ForegroundColor Cyan
    Write-Host "     Name    : $($match.Name)" -ForegroundColor Green
    Write-Host "     Email   : $($match.Email)" -ForegroundColor Green
    Write-Host "     Username: $($match.Username) (auto-authenticated via gh token)" -ForegroundColor Green
    Write-Host ""

    # 3. Check for existing repositories with local overrides inside $resolvedFolder
    if (Test-Path $resolvedFolder) {
        $reposWithLocalOverride = @()
        $checkFolders = @()
        if (Test-Path (Join-Path $resolvedFolder ".git")) {
            $checkFolders += $resolvedFolder
        } else {
            try {
                $subDirs = Get-ChildItem -Path $resolvedFolder -Directory -ErrorAction SilentlyContinue
                foreach ($sd in $subDirs) {
                    if (Test-Path (Join-Path $sd.FullName ".git")) {
                        $checkFolders += $sd.FullName
                    }
                }
            } catch {}
        }
        foreach ($r in $checkFolders) {
            $locName = git -C $r config --local user.name 2>$null
            $locEmail = git -C $r config --local user.email 2>$null
            if ($locName -or $locEmail) {
                $reposWithLocalOverride += [PSCustomObject]@{
                    Path  = $r
                    Name  = $locName
                    Email = $locEmail
                }
            }
        }
        if ($reposWithLocalOverride.Count -gt 0) {
            Write-Host "[NOTICE] Found $($reposWithLocalOverride.Count) repository(ies) with local (.git/config) overrides:" -ForegroundColor Yellow
            foreach ($ro in $reposWithLocalOverride) {
                Write-Host "  - $([System.IO.Path]::GetFileName($ro.Path)): user.name='$($ro.Name)', user.email='$($ro.Email)'" -ForegroundColor DarkYellow
            }
            Write-Host "  Local overrides take precedence over folder bindings in Git." -ForegroundColor DarkYellow
            $cleanOverride = Read-Host "Would you like to clear local overrides in these repositories so they inherit '$($match.Label)'? [Y/n]"
            if (-not $cleanOverride -or $cleanOverride -match '^[yY]$') {
                foreach ($ro in $reposWithLocalOverride) {
                    git -C $ro.Path config --local --unset-all user.name 2>$null
                    git -C $ro.Path config --local --unset-all user.email 2>$null
                    Write-Host "  [CLEARED] Cleared local override for $([System.IO.Path]::GetFileName($ro.Path))" -ForegroundColor Green
                }
                Write-Host ""
            } else {
                Write-Host "  [SKIPPED] Local overrides preserved. Note: these repos will not use the folder binding until local configs are cleared." -ForegroundColor Gray
                Write-Host ""
            }
        }
    }
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
        $kClean = $k -replace '^includeif\.gitdir(/i)?:', '' -replace '\.path$', ''
        $kNorm = $kClean.TrimEnd('/') + '/'
        if ($kNorm.ToLower() -eq $gitdirPattern.ToLower() -or $k -like "*$gitdirPattern*") {
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
        $accounts = Get-Accounts
        foreach ($l in $lines) {
            if ($l -match 'includeif\.gitdir(?:/i)?:(.*)\.path=(.*)') {
                $dir = $matches[1]
                $cfg = $matches[2]
                $accLabel = ""
                if ($cfg -match '\.gitconfig-(.+)$') {
                    $accKey = $matches[1]
                    $matchedAcc = $accounts | Where-Object { $_.Key.ToLower() -eq $accKey.ToLower() }
                    if ($matchedAcc) {
                        $accLabel = "$($matchedAcc.Label) ($($matchedAcc.Username))"
                    } else {
                        $accLabel = $accKey
                    }
                }
                Write-Host "  Folder  : " -NoNewline; Write-Host "$dir" -ForegroundColor Green
                if ($accLabel) {
                    Write-Host "  Account : " -NoNewline; Write-Host "$accLabel" -ForegroundColor Yellow
                }
                Write-Host "  Config  : " -NoNewline; Write-Host "$cfg" -ForegroundColor DarkCyan
                Write-Host ""
            }
        }
    }
    Write-Host "================================================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Update-Gswitch {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " Updating git-account-switcher (gswitch)" -ForegroundColor Cyan
    Write-Host " Current Version: v$SCRIPT_VERSION" -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $binDir = "$HOME\.local\bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    # Detect if running from local git repo or installed script
    $isLocalRepo = $false
    $repoRoot = $null
    if ($PSScriptRoot) {
        $parentDir = Split-Path $PSScriptRoot -Parent
        if ((Test-Path (Join-Path $PSScriptRoot "..\bin")) -and (Test-Path (Join-Path $parentDir ".git"))) {
            $isLocalRepo = $true
            $repoRoot = $parentDir
        } elseif ((Test-Path (Join-Path $PSScriptRoot "git-account-switcher.ps1")) -and (Test-Path (Join-Path $PSScriptRoot "..\.git"))) {
            $isLocalRepo = $true
            $repoRoot = Split-Path $PSScriptRoot -Parent
        }
    }

    $filesToUpdate = @(
        "git-account-switcher.ps1", "git-account-switcher.cmd", "git-account-switcher",
        "gswitch.cmd", "gswitch",
        "switch-git.ps1", "switch-git.cmd", "switch-git"
    )

    if ($isLocalRepo -and $repoRoot) {
        Write-Host "Detected local development repository at: $repoRoot" -ForegroundColor Yellow
        Write-Host "Updating binaries in $binDir from local bin/..." -ForegroundColor Cyan
        $localBin = Join-Path $repoRoot "bin"
        foreach ($file in $filesToUpdate) {
            $src = Join-Path $localBin $file
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $binDir -Force
                Write-Host "  [OK] Updated $file" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "Fetching latest release from GitHub (master branch)..." -ForegroundColor Yellow
        foreach ($file in $filesToUpdate) {
            $fileUrl = "$RAW_REPO_BASE/bin/$file"
            $destFile = Join-Path $binDir $file
            try {
                Invoke-RestMethod -Uri $fileUrl -OutFile $destFile
                Write-Host "  [OK] Downloaded & updated $file" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Could not update $file : $_" -ForegroundColor Yellow
            }
        }
    }

    # Ensure aliases
    git config --global alias.who "!git-account-switcher status"
    git config --global alias.switch-acc "!git-account-switcher"

    Write-Host ""
    Write-Host "[OK] git-account-switcher updated successfully! (v$SCRIPT_VERSION)" -ForegroundColor Green
    Write-Host "     All profiles and folder bindings preserved." -ForegroundColor DarkCyan
    Write-Host ""
}

function Get-PowerShellCompletionScript {
    return @'
Register-ArgumentCompleter -Native -CommandName @('gswitch', 'git-account-switcher', 'switch-git') -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $subcommands = @(
        'status', 'who', 'list', 'ls', 'doctor', 'check',
        'bind', 'unbind', 'bindings', 'sync', 'setup',
        'add', 'remove', 'rm', 'alias', 'unalias',
        'edit', 'config', 'update', 'upgrade', 'version',
        'completion', 'help', '-l', '--local', '-g', '--global', '-f', '--force', '-v', '-h'
    )

    $elements = $commandAst.Elements
    $count = $elements.Count

    $accKeys = @()
    $cfg = if ($env:GIT_ACCOUNT_SWITCHER_CONFIG) { $env:GIT_ACCOUNT_SWITCHER_CONFIG } else { "$HOME\.config\git-account-switcher\accounts.json" }
    if (Test-Path $cfg) {
        try {
            $raw = Get-Content -Path $cfg -Raw -Encoding UTF8
            $json = $raw | ConvertFrom-Json
            foreach ($item in $json) {
                if ($item.key) { $accKeys += [string]$item.key }
                if ($item.username -and $item.username -ne $item.key) { $accKeys += [string]$item.username }
                if ($item.aliases) {
                    foreach ($al in $item.aliases) {
                        $alStr = [string]$al
                        if ($alStr -notmatch '^\d+$' -and $accKeys -notcontains $alStr) { $accKeys += $alStr }
                    }
                }
            }
        } catch {}
    }

    if ($count -le 2) {
        $candidates = $subcommands + $accKeys
        $candidates | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }

    $firstArg = $elements[1].Value.ToLower()

    if ($firstArg -in @('-l', '--local', 'remove', 'rm', 'delete', 'alias', 'unalias')) {
        $accKeys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }

    if ($firstArg -in @('bind')) {
        if ($count -ge 4) {
            $accKeys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }
        return
    }

    if ($firstArg -eq 'completion') {
        @('powershell', 'bash', 'zsh', 'install') | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }
}
'@
}

function Get-BashCompletionScript {
    return @'
_gswitch_completions() {
    local cur prev words cword
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    fi

    local subcommands="status who list ls doctor check bind unbind bindings sync setup add remove rm alias unalias edit config update upgrade version completion help -l --local -g --global -f --force -v -h"
    local cfg="${GIT_ACCOUNT_SWITCHER_CONFIG:-$HOME/.config/git-account-switcher/accounts.json}"
    local acc_keys=""

    if [[ -f "$cfg" ]] && command -v python3 >/dev/null 2>&1; then
        acc_keys=$(python3 -c "
import json
try:
    with open('$cfg') as f:
        data = json.load(f)
    keys = []
    for a in data:
        if a.get('key'): keys.append(a['key'])
        if a.get('username') and a['username'] not in keys: keys.append(a['username'])
        for al in a.get('aliases', []):
            if not str(al).isdigit() and al not in keys: keys.append(str(al))
    print(' '.join(keys))
except:
    pass
" 2>/dev/null || true)
    fi

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$subcommands $acc_keys" -- "$cur") )
        return 0
    fi

    case "$prev" in
        -l|--local|remove|rm|delete|alias|unalias)
            COMPREPLY=( $(compgen -W "$acc_keys" -- "$cur") )
            return 0
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh powershell install" -- "$cur") )
            return 0
            ;;
        bind)
            compopt -o filenames 2>/dev/null || true
            COMPREPLY=( $(compgen -d -- "$cur") )
            return 0
            ;;
        *)
            if [[ "${COMP_WORDS[1]}" == "bind" && "$COMP_CWORD" -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "$acc_keys" -- "$cur") )
                return 0
            fi
            ;;
    esac
}
complete -F _gswitch_completions gswitch git-account-switcher switch-git
'@
}

function Get-ZshCompletionScript {
    return @'
#compdef gswitch git-account-switcher switch-git
autoload -U +X bashcompinit && bashcompinit
_gswitch_completions() {
    local cur prev words cword
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="status who list ls doctor check bind unbind bindings sync setup add remove rm alias unalias edit config update upgrade version completion help -l --local -g --global -f --force -v -h"
    local cfg="${GIT_ACCOUNT_SWITCHER_CONFIG:-$HOME/.config/git-account-switcher/accounts.json}"
    local acc_keys=""

    if [[ -f "$cfg" ]] && command -v python3 >/dev/null 2>&1; then
        acc_keys=$(python3 -c "
import json
try:
    with open('$cfg') as f:
        data = json.load(f)
    keys = []
    for a in data:
        if a.get('key'): keys.append(a['key'])
        if a.get('username') and a['username'] not in keys: keys.append(a['username'])
        for al in a.get('aliases', []):
            if not str(al).isdigit() and al not in keys: keys.append(str(al))
    print(' '.join(keys))
except:
    pass
" 2>/dev/null || true)
    fi

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$subcommands $acc_keys" -- "$cur") )
        return 0
    fi

    case "$prev" in
        -l|--local|remove|rm|delete|alias|unalias)
            COMPREPLY=( $(compgen -W "$acc_keys" -- "$cur") )
            return 0
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh powershell install" -- "$cur") )
            return 0
            ;;
        bind)
            COMPREPLY=( $(compgen -d -- "$cur") )
            return 0
            ;;
        *)
            if [[ "${COMP_WORDS[1]}" == "bind" && "$COMP_CWORD" -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "$acc_keys" -- "$cur") )
                return 0
            fi
            ;;
    esac
}
complete -F _gswitch_completions gswitch git-account-switcher switch-git
'@
}

function Handle-Completion($subArg) {
    if ($subArg -eq "bash") {
        Write-Output (Get-BashCompletionScript)
        return
    }
    if ($subArg -eq "zsh") {
        Write-Output (Get-ZshCompletionScript)
        return
    }
    if ($subArg -eq "powershell" -or -not $subArg) {
        Write-Output (Get-PowerShellCompletionScript)
        return
    }
    if ($subArg -eq "install") {
        Write-Host ""
        Write-Host "Installing shell auto-completion for git-account-switcher..." -ForegroundColor Cyan

        if (-not (Test-Path $ConfigDir)) {
            New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        }

        # 1. PowerShell Profile
        $psCompFile = Join-Path $ConfigDir "completion.ps1"
        [System.IO.File]::WriteAllText($psCompFile, (Get-PowerShellCompletionScript), [System.Text.Encoding]::UTF8)
        Write-Host "  [OK] Generated PowerShell completion script -> $psCompFile" -ForegroundColor Green

        $profPath = $PROFILE
        $profDir = Split-Path $profPath -Parent
        if (-not (Test-Path $profDir)) {
            New-Item -ItemType Directory -Path $profDir -Force | Out-Null
        }
        if (-not (Test-Path $profPath)) {
            New-Item -ItemType File -Path $profPath -Force | Out-Null
        }

        $profContent = Get-Content -Path $profPath -Raw -ErrorAction SilentlyContinue
        $includeLine = "`nif (Test-Path `"$psCompFile`") { . `"$psCompFile`" }`n"
        if ($profContent -notlike "*$psCompFile*") {
            Add-Content -Path $profPath -Value $includeLine -Encoding UTF8
            Write-Host "  [OK] Added completion loader to PowerShell `$PROFILE ($profPath)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] PowerShell `$PROFILE already configured." -ForegroundColor Green
        }

        # 2. Bash / Git Bash Profile
        $bashCompFile = Join-Path $ConfigDir "completion.bash"
        [System.IO.File]::WriteAllText($bashCompFile, (Get-BashCompletionScript), [System.Text.Encoding]::UTF8)
        Write-Host "  [OK] Generated Bash completion script -> $bashCompFile" -ForegroundColor Green

        $bashRc = Join-Path $HOME ".bashrc"
        $bashUnixPath = $bashCompFile.Replace('\', '/')
        $bashInclude = "`n[[ -f `"$bashUnixPath`" ]] && source `"$bashUnixPath`"`n"
        if (Test-Path $bashRc) {
            $bashContent = Get-Content -Path $bashRc -Raw -ErrorAction SilentlyContinue
            if ($bashContent -notlike "*$bashUnixPath*") {
                Add-Content -Path $bashRc -Value $bashInclude -Encoding UTF8
                Write-Host "  [OK] Added completion loader to ~/.bashrc" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "[OK] Shell auto-completion successfully installed!" -ForegroundColor Green
        Write-Host "     Type 'gswitch <Tab>' in a new terminal session to auto-complete accounts and commands." -ForegroundColor Cyan
        Write-Host ""
        return
    }

    Write-Host "[ERROR] Unknown completion target: '$subArg'. Supported: powershell, bash, zsh, install" -ForegroundColor Red
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
            if ($detectedUsernames -notcontains $matches[1]) {
                $detectedUsernames += $matches[1]
            }
        }
    }
    
    if ($detectedUsernames.Count -eq 0) {
        Write-Host "[WARNING] No authenticated GitHub CLI accounts found." -ForegroundColor Yellow
        Write-Host "          Run 'gh auth login' first to sign in to your accounts." -ForegroundColor Gray
        return
    }
    
    Write-Host "Found $($detectedUsernames.Count) account(s): $($detectedUsernames -join ', ')" -ForegroundColor Green
    
    $existing = Get-Accounts
    $newList = New-Object System.Collections.ArrayList
    
    # 1. Preserve existing accounts that are authenticated, or keep existing ones
    foreach ($u in $detectedUsernames) {
        $match = $existing | Where-Object { $_.Username.ToLower() -eq $u.ToLower() }
        if ($match) {
            Write-Host "  [KEEP] Preserved profile for '$($match.Label)' ($u)" -ForegroundColor Green
            $null = $newList.Add($match)
        } else {
            Write-Host "  [NEW] Fetching account details for '$u'..." -ForegroundColor DarkCyan
            $userInfo = $null
            try {
                $userInfo = gh api "users/$u" --jq "{id: .id, login: .login, name: .name}" 2>$null | ConvertFrom-Json
            } catch {}
            
            $userId   = if ($userInfo -and $userInfo.id) { $userInfo.id } else { "0" }
            $userName = if ($userInfo -and $userInfo.name) { $userInfo.name } else { $u }
            $userEmail = if ($userId -ne "0") { "$userId+$u@users.noreply.github.com" } else { "$u@users.noreply.github.com" }
            
            $null = $newList.Add([PSCustomObject]@{
                Key         = $u.ToLower()
                AliasList   = @($u.ToLower())
                Label       = $u
                Username    = $u
                Name        = $userName
                Email       = $userEmail
                Description = "GitHub account $u"
            })
        }
    }

    # Also keep any accounts that might be configured but not currently in gh auth status
    foreach ($old in $existing) {
        $inDetected = $detectedUsernames | Where-Object { $_.ToLower() -eq $old.Username.ToLower() }
        if (-not $inDetected) {
            $null = $newList.Add($old)
        }
    }

    Save-Accounts $newList
    Write-Host ""
    Write-Host "[OK] Successfully synced $($newList.Count) account(s) to $ConfigFile!" -ForegroundColor Green
    Show-List
}

function Invoke-Doctor {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  GIT ACCOUNT SWITCHER - SYSTEM & REPO DIAGNOSTICS (DOCTOR)  " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    $issueCount = 0
    $warnCount = 0

    # 1. Check Git
    Write-Host "`n[1/5] Checking Git toolchain..." -ForegroundColor Yellow
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVer = (git --version 2>$null) -replace 'git version ', ''
        Write-Host "  [PASS] Git executable found : $($gitCmd.Source)" -ForegroundColor Green
        Write-Host "         Version              : $gitVer" -ForegroundColor Gray
    } else {
        Write-Host "  [FAIL] Git executable not found in PATH." -ForegroundColor Red
        $issueCount++
    }

    # 2. Check GitHub CLI (gh)
    Write-Host "`n[2/5] Checking GitHub CLI (gh)..." -ForegroundColor Yellow
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $ghVer = (gh --version 2>$null | Select-Object -First 1) -replace 'gh version ', ''
        Write-Host "  [PASS] GitHub CLI found     : $($ghCmd.Source)" -ForegroundColor Green
        Write-Host "         Version              : $ghVer" -ForegroundColor Gray
    } else {
        Write-Host "  [FAIL] GitHub CLI (gh) not found in PATH." -ForegroundColor Red
        Write-Host "         Please install from https://cli.github.com" -ForegroundColor DarkGray
        $issueCount++
    }

    # 3. Check Account Profiles & Tokens
    Write-Host "`n[3/5] Checking account profiles & authentication tokens..." -ForegroundColor Yellow
    $accounts = @(Get-Accounts)
    if ($accounts.Count -eq 0) {
        Write-Host "  [WARN] No account profiles configured in $ConfigFile." -ForegroundColor Yellow
        Write-Host "         Run 'gswitch sync' to auto-detect accounts from GitHub CLI." -ForegroundColor DarkGray
        $warnCount++
    } else {
        Write-Host "  Found $($accounts.Count) account profile(s) in $($ConfigFile):" -ForegroundColor Gray
        foreach ($a in $accounts) {
            $tokenOk = $false
            if ($ghCmd) {
                try {
                    $tokenOut = gh auth token -u $a.Username 2>$null
                    if ($LASTEXITCODE -eq 0 -and $tokenOut -and $tokenOut.Trim().Length -gt 0) {
                        $tokenOk = $true
                    }
                } catch {}
            }
            if ($tokenOk) {
                Write-Host "  [PASS] Profile '$($a.Label)' ($($a.Username)): Valid OAuth token" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Profile '$($a.Label)' ($($a.Username)): Token missing or expired" -ForegroundColor Yellow
                Write-Host "         Run 'gh auth login -h github.com' to authenticate this user." -ForegroundColor DarkYellow
                $warnCount++
            }
        }
    }

    # 4. Check Folder Bindings (includeIf)
    Write-Host "`n[4/5] Checking folder bindings (includeIf)..." -ForegroundColor Yellow
    $bindingLines = git config --global --list --show-origin 2>$null | Where-Object { $_ -match 'includeif\.gitdir' }
    if (-not $bindingLines) {
        Write-Host "  [INFO] No folder bindings configured in ~/.gitconfig." -ForegroundColor Gray
        Write-Host "         To bind a folder: gswitch bind <folder> <account>" -ForegroundColor DarkGray
    } else {
        foreach ($line in $bindingLines) {
            if ($line -match 'includeif\.gitdir(?:/i)?:([^.]*?)\.path=(.*)') {
                $boundPattern = $matches[1]
                $includedFile = $matches[2]
                
                $cleanFolder = $boundPattern.TrimEnd('/')
                $folderExists = Test-Path $cleanFolder
                
                $fileClean = $includedFile.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                $fileExists = Test-Path $fileClean
                
                if ($folderExists -and $fileExists) {
                    Write-Host "  [PASS] Binding: $boundPattern -> $includedFile" -ForegroundColor Green
                    $helperConfig = git config -f $fileClean --get credential.https://github.com.helper 2>$null
                    if ($helperConfig -like "*git-account-switcher cred*") {
                        Write-Host "         Credential Helper: Configured ($helperConfig)" -ForegroundColor DarkGreen
                    } else {
                        Write-Host "  [WARN] Credential helper missing or non-standard in $fileClean" -ForegroundColor Yellow
                        Write-Host "         Re-run 'gswitch bind $cleanFolder <account>' to repair." -ForegroundColor DarkYellow
                        $warnCount++
                    }
                } else {
                    if (-not $folderExists) {
                        Write-Host "  [WARN] Bound folder does not exist: $boundPattern" -ForegroundColor Yellow
                        $warnCount++
                    }
                    if (-not $fileExists) {
                        Write-Host "  [FAIL] Target config file missing: $includedFile" -ForegroundColor Red
                        $issueCount++
                    }
                }
            }
        }
    }

    # 5. Check Current Working Directory / Repository
    Write-Host "`n[5/5] Checking current repository state..." -ForegroundColor Yellow
    $isRepo = (git rev-parse --is-inside-work-tree 2>$null) -eq "true"
    if ($isRepo) {
        $effName = git config user.name 2>$null
        $effEmail = git config user.email 2>$null
        $effSign = git config user.signingkey 2>$null
        $remoteUrl = git config --get remote.origin.url 2>$null

        Write-Host "  [PASS] Inside Git repository: $((Get-Location).Path)" -ForegroundColor Green
        Write-Host "         Active User Name  : $effName" -ForegroundColor Gray
        Write-Host "         Active User Email : $effEmail" -ForegroundColor Gray
        if ($effSign) {
            Write-Host "         Active Signing Key: $effSign" -ForegroundColor Gray
        }
        
        if ($remoteUrl) {
            Write-Host "         Remote Origin URL : $remoteUrl" -ForegroundColor Gray
            if ($remoteUrl -match '^git@github\.com:' -or $remoteUrl -match '^ssh://') {
                Write-Host "  [WARN] Repository uses SSH remote ($remoteUrl)." -ForegroundColor Yellow
                Write-Host "         Git credential helper is bypassed for SSH transport." -ForegroundColor DarkYellow
                Write-Host "         To enable HTTPS token switching: git remote set-url origin https://github.com/<org>/<repo>.git" -ForegroundColor DarkYellow
                $warnCount++
            } else {
                Write-Host "  [PASS] Remote uses HTTPS transport (credential helper active)" -ForegroundColor Green
            }
        } else {
            Write-Host "  [INFO] No remote.origin.url configured in this repo." -ForegroundColor Gray
        }

        $locName = git config --local user.name 2>$null
        $locEmail = git config --local user.email 2>$null
        if ($locName -or $locEmail) {
            $currP = ((Get-Location).Path.Replace('\', '/').TrimEnd('/') + '/').ToLower()
            $shadowed = $false
            foreach ($bl in $bindingLines) {
                if ($bl -match 'includeif\.gitdir(?:/i)?:([^.]*?)\.path=(.*)') {
                    $bClean = ($matches[1].TrimEnd('/') + '/').ToLower()
                    if ($currP.StartsWith($bClean)) {
                        $shadowed = $true
                        Write-Host "  [WARN] Local repository override active ($locName <$locEmail>) in a bound directory!" -ForegroundColor Yellow
                        Write-Host "         This repo will NOT inherit folder binding '$($matches[1])' until cleared." -ForegroundColor DarkYellow
                        Write-Host "         To inherit folder account: git config --local --unset-all user.name; git config --local --unset-all user.email" -ForegroundColor DarkYellow
                        $warnCount++
                        break
                    }
                }
            }
            if (-not $shadowed) {
                Write-Host "  [INFO] Local repository override active ($locName <$locEmail>)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "  [INFO] Current directory is not a Git repository." -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    if ($issueCount -eq 0 -and $warnCount -eq 0) {
        Write-Host "  DOCTOR RESULT: ALL CHECKS PASSED [OK]" -ForegroundColor Green
    } elseif ($issueCount -eq 0) {
        Write-Host "  DOCTOR RESULT: $warnCount WARNING(S) FOUND (SYSTEM OPERATIONAL)" -ForegroundColor Yellow
    } else {
        Write-Host "  DOCTOR RESULT: $issueCount ISSUE(S), $warnCount WARNING(S) FOUND" -ForegroundColor Red
    }
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
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
    Write-Host "  gswitch doctor | check              Run system & repository diagnostic health checks" -ForegroundColor White
    Write-Host "  gswitch update | upgrade            Update git-account-switcher to latest version" -ForegroundColor White
    Write-Host "  gswitch version | -v                Display installed version" -ForegroundColor White
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
    Write-Host "  doctor   Run complete self-diagnostics on Git, GitHub CLI, tokens, bindings, and remotes" -ForegroundColor White
    Write-Host "  edit     Open accounts.json directly in VS Code / Notepad / default editor" -ForegroundColor White
    Write-Host "  remove   Remove a profile by key, user, alias, or index: gswitch remove <key> [-f]" -ForegroundColor White
    Write-Host "  sync     Scan 'gh auth status', fetch IDs, and configure private noreply emails" -ForegroundColor White
    Write-Host "  setup    Launch the first-time guided setup wizard" -ForegroundColor White
    Write-Host "  status   Display active GitHub CLI user and global/local Git user.name & email" -ForegroundColor White
    Write-Host "  list     Display formatted table of all configured profiles with * ACTIVE badge" -ForegroundColor White
    Write-Host "  update   Download and install latest release of git-account-switcher" -ForegroundColor White
    Write-Host "  version  Display installed version: gswitch version / gswitch -v" -ForegroundColor White
    Write-Host "  completion Install or output tab auto-completion: gswitch completion [install|powershell|bash|zsh]" -ForegroundColor White
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
    Write-Host "  gswitch update                      # Update gswitch to latest version" -ForegroundColor Gray
    Write-Host "  gswitch version                     # Show installed version (e.g. v$SCRIPT_VERSION)" -ForegroundColor Gray
    Write-Host "  gswitch completion install          # Install shell tab auto-completion to profile" -ForegroundColor Gray
    Write-Host "  git who                             # Fast alias to inspect current identity" -ForegroundColor Gray
    Write-Host ""
    Write-Host "CONFIG PATH:" -ForegroundColor Yellow
    Write-Host "  $ConfigFile" -ForegroundColor DarkCyan
    Write-Host ""
}

# -------------------------------------------------------------
# Dispatcher
# -------------------------------------------------------------
if ($Command -eq "cred") {
    $targetUser = $Argument
    $action = $Extra1
    if (-not $targetUser) {
        $stdinLines = @($input)
        foreach ($line in $stdinLines) {
            if ($line -match '^username=(.+)$') {
                $targetUser = $matches[1].Trim()
                break
            }
        }
    }
    if ($action -eq "get" -or -not $action) {
        if ($targetUser) {
            $token = ""
            try {
                $token = (gh auth token -u $targetUser 2>$null)
                if ($token) { $token = $token.Trim() }
            } catch {}
            if ($token) {
                Write-Output "username=$targetUser"
                Write-Output "password=$token"
            }
        }
    }
    exit 0
}

if ($Help -or $Command -in @("help", "-h", "--help", "-?", "/?")) {
    Show-HelpMessage
    exit 0
}

if ($Version -or $Command -in @("version", "-v", "--version", "-V")) {
    Write-Host "git-account-switcher (gswitch) v$SCRIPT_VERSION" -ForegroundColor Cyan
    exit 0
}

if ($Command -in @("update", "upgrade")) {
    Update-Gswitch
    exit 0
}

if ($Command -in @("completion", "completions", "autocomplete")) {
    Handle-Completion $Argument
    exit 0
}

if ($Command -in @("status", "who", "current", "-s")) {
    Show-Status
    exit 0
}

if ($Command -in @("doctor", "check", "diag", "diagnose")) {
    Invoke-Doctor
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

# 2. Substring match fallback (minimum 3 chars, query must be part of username or key)
if (-not $selected -and $cleanTarget.Length -ge 3) {
    foreach ($a in $accounts) {
        if ($a.Username.ToLower().Contains($cleanTarget) -or `
            $a.Key.ToLower().Contains($cleanTarget)) {
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
