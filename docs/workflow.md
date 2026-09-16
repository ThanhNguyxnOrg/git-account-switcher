# Complete Workflow Guide 🚀

This guide provides an end-to-end, step-by-step walkthrough of setting up and using **`git-account-switcher` (`gswitch`)** across multiple GitHub accounts on Windows, macOS, and Linux.

---

## 📑 Workflow Overview

```
Phase 1: Authenticate Accounts (`gh auth login`)
                       ↓
Phase 2: Enable Git Credential Helper (`gh auth setup-git`)
                       ↓
Phase 3: Configure Profiles & Aliases (`gswitch sync` or `gswitch add`)
                       ↓
Phase 4: Daily Switching (`gswitch <target>` or `gswitch -l <target>`)
                       ↓
Phase 5: Commit & Verification (`git who`)
                       ↓
Phase 6: Maintenance (`gswitch alias`, `gswitch edit`, `gswitch remove`)
```

---

## Phase 1: Authenticate Your GitHub Accounts

Before switching between accounts, log in to each GitHub account once via the official GitHub CLI (`gh`).

```bash
# 1. Sign in to your first account (e.g. personal)
gh auth login -p https -w

# 2. Sign in to your second account (e.g. work)
gh auth login -p https -w

# 3. Sign in to any additional accounts (e.g. school / freelance)
gh auth login -p https -w
```

Verify that all accounts are authenticated:

```bash
gh auth status
```

You should see output similar to:
```text
github.com
  ✓ Logged in to github.com account octocat (keyring)
  - Active account: true
  ✓ Logged in to github.com account mona-corp (keyring)
  - Active account: false
```

---

## Phase 2: Route Git HTTPS through GitHub CLI

Configure Git to use GitHub CLI as its credential helper so Git pushes and pulls automatically inherit the active token:

```bash
gh auth setup-git
```

> [!NOTE]
> On Windows, if you have Git Credential Manager (GCM) installed, GCM may occasionally cache an old token. Setting `gh auth setup-git` tells Git to ask `gh` first. If you experience 403 Forbidden errors, see the [Troubleshooting Guide](troubleshooting.md#windows-credential-manager-gcm-conflict).

---

## Phase 3: Configure Profiles & Shortcuts

You can populate your profile configuration (`accounts.json`) in one of three ways:

### Option A: Automatic Discovery (Fastest)

If you already logged into your accounts with `gh`, simply run:

```bash
gswitch sync
```

This scans GitHub CLI, queries GitHub's API to fetch your unique numerical User IDs, and sets up privacy-protected noreply email addresses automatically!

### Option B: Guided Setup Wizard

If you prefer an interactive step-by-step assistant:

```bash
gswitch setup
```

The wizard prompts you for each account's username, switching key, author name, and optional custom aliases.

### Option C: Add Manually or Non-Interactively

Add profiles one by one:

```bash
# Interactive prompt (asks for username, key, label, email, aliases):
gswitch add

# Or non-interactive one-liner:
gswitch add octocat personal "Mona Lisa" "583231+octocat@users.noreply.github.com"
```

---

## Phase 4: Daily Switching

### 1. Global Switching (Affects Entire Machine)

Use global switching when you want all new Git commits and GitHub CLI operations across your system to use a specific account:

```bash
gswitch personal      # Switch by key
gswitch octocat       # Switch by username
gswitch 1             # Switch by index number
gswitch p             # Switch by custom shortcut alias
```

### 2. Repository-Local Switching (`--local` / `-l`)

Use local switching when you want a repository to **always** commit as your work or school identity without altering your global machine defaults:

```bash
cd ~/projects/enterprise-app
gswitch -l work
```

This writes directly to `.git/config` within that repository, leaving your global `~/.gitconfig` untouched.

### 3. Interactive Selector

Run `gswitch` with no arguments to bring up the interactive menu:

```bash
gswitch
```

```text
Configured Account Profiles (2):
================================================================================
 > [1] Personal         octocat          583231+octocat@users.noreply.github.com * ACTIVE
       Aliases: 1, personal, octocat, p
   [2] Work             mona-corp        mona@enterprise.com 
       Aliases: 2, work, corp, w
================================================================================

Select account [1-2], 's' to sync, 'a' to add, 'e' to edit, or Enter to cancel: 
```

### 4. Optional Power Feature: Automatic Folder Isolation (Set & Forget)

If you organize your projects into separate directories (e.g., all company projects in `C:\Projects\Work` and personal code in `C:\Projects\Personal`), you can permanently bind directories to accounts so Git automatically switches identity without any manual command:

```bash
# 1. Bind directory to account profile (replace with your folder path):
gswitch bind C:\Projects\Work work          # Windows
gswitch bind ~/projects/work work          # macOS / Linux

# 2. View all active folder bindings:
gswitch bindings

# 3. Remove a binding when no longer needed:
gswitch unbind C:\Projects\Work
```

*Inside any bound directory, `git who` will automatically detect and report `[Folder Override via includeIf detected]`.*

---

## Phase 5: Verification & Safety

Always verify your active identity before making your first commit in a session:

```bash
gswitch current
# Or using the Git alias:
git who
```

Example output:

```text
============================================================
 CURRENT GITHUB & GIT IDENTITY
============================================================
 GitHub CLI Active : mona-corp
 Git Global Name   : Mona Corporate
 Git Global Email  : mona@enterprise.com
 ------------------------------------------------------------
 [Repo Local Override detected in current directory]
 Git Local Name    : Mona Corporate
 Git Local Email   : mona@enterprise.com
============================================================
```

Test commit and push:

```bash
git commit -m "feat: first commit under work identity"
git push origin main
```

---

## Phase 6: Maintenance & Shortcuts

### Adding Shortcut Aliases

Assign quick nicknames or symbols to accounts so you can switch even faster:

```bash
# Assign 'w' to work account:
gswitch alias work w

# Assign 'p' to personal account:
gswitch alias personal p
```

### Removing Shortcut Aliases

```bash
gswitch unalias work w
```

### Editing Raw Configuration

Open `accounts.json` directly in your default text editor (VS Code or Notepad / `$EDITOR`):

```bash
gswitch edit
```

### Removing an Account Profile

```bash
# Interactive confirmation:
gswitch remove work

# Force remove account by index without confirmation:
gswitch remove 2 -f
```

---

## Related Documentation

- ⚙️ [Configuration & Schema Guide](configuration.md)
- ❓ [Troubleshooting & FAQ](troubleshooting.md)
- 🤖 [Autonomous AI Agent Guide](../AGENT.md)
- 🤝 [Contributing & Testing](../CONTRIBUTING.md)
