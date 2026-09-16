# git-account-switcher ⚡

> **The missing bridge between Git commit identities and GitHub CLI authentication.**  
> Switch GitHub accounts, active OAuth tokens, commit authors, and private noreply emails in a single command — with zero SSH configuration needed. Works natively across **Windows**, **macOS**, and **Linux**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows | macOS | Linux](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)]()
[![Shell: PowerShell | Bash | Zsh](https://img.shields.io/badge/Shell-PowerShell%20%7C%20Bash%20%7C%20Zsh-blueviolet.svg)]()
[![AI Agent Ready](https://img.shields.io/badge/AI%20Agent-Ready-9cf.svg)](AGENT.md)
[![Git: >= 2.13](https://img.shields.io/badge/Git-%3E%3D%202.13-orange.svg)](https://git-scm.com/)
[![GitHub CLI: >= 2.24](https://img.shields.io/badge/GitHub%20CLI-%3E%3D%202.24-green.svg)](https://cli.github.com/)

---

## 📑 Table of Contents
- [⚡ Quick Start (30 Seconds)](#-quick-start-30-seconds)
- [🎯 The Problem & Solution](#-the-problem--solution)
- [🎮 Commands Cheat Sheet](#-commands-cheat-sheet)
- [🛠️ First-Time Onboarding Guide](#️-first-time-onboarding-guide)
- [🤖 AI-Native Setup Guide](#-ai-native-setup-for-cursor-claude-copilot-antigravity)
- [📂 Folder Isolation (`includeIf`)](#-bonus-automatic-folder-isolation-includeif)
- [🔧 Configuration Reference](#-profile-configuration-accountsjson)
- [🗑️ Uninstallation](#️-uninstallation)
- [📄 License](#-license)

---

## ⚡ Quick Start (30 Seconds)

### Step 1: Install via 1-Line Command (No clone needed)

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.ps1 | iex
```

**macOS & Linux (Bash / Zsh):**
```bash
curl -fsSL https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.sh | bash
```

*(Or clone manually: `git clone https://github.com/ThanhNguyxnOrg/git-account-switcher.git && cd git-account-switcher && ./install.ps1`)*

---

### Step 2: Configure Your Accounts (Choose any method)

- **Option A (Instant Auto-Discovery):**  
  If you already logged into your accounts via `gh auth login`, simply run:
  ```bash
  gswitch sync
  ```
  *It will scan GitHub CLI, fetch your user IDs, and configure private noreply emails automatically!*

- **Option B (Interactive Setup Wizard):**  
  Don't have accounts configured yet? Run:
  ```bash
  gswitch setup
  ```

- **Option C (Add accounts one-by-one):**
  ```bash
  gswitch add
  ```

---

### Step 3: Switch & Code!

```bash
gswitch personal      # Switch globally
gswitch -l work       # Switch for the current repository only
gswitch               # Open interactive selection menu
git who               # Check who is currently active
```

---

## 🎯 The Problem & Solution

### The Friction
Developers managing multiple GitHub accounts (Personal, Work, School) constantly run into two pitfalls:
1. **`gh auth switch` is incomplete:**  
   GitHub CLI provides `gh auth switch`, but it **only swaps the CLI API/push token**. It leaves Git's `user.name` and `user.email` untouched. You push code with your work token, but Git stamps the commit with your personal avatar and email.
2. **SSH multi-account configuration is fragile:**  
   Traditional SSH workflows require generating multiple key pairs (`id_ed25519_*`), writing custom `~/.ssh/config` host aliases, and manually rewriting remote URLs (`git@github-work:user/repo.git`).

### The Solution
`git-account-switcher` unifies both layers into an atomic, 1-second operation:
- **Toggles GitHub CLI (`gh auth switch`):** Grants instant HTTPS push/pull permissions and repository creation capabilities under the target account.
- **Toggles Git Identity (`git config`):** Updates `user.name` and `user.email` (using GitHub's privacy-protected `noreply` email). Supports both **global** and **repository-local** scopes.
- **Zero SSH required:** Uses GitHub CLI as Git's native HTTPS credential helper (`git-credential`).

```
                         ┌────────────────────────────────────────┐
                         │  git-account-switcher <acc> / gswitch  │
                         └───────────────────┬────────────────────┘
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     ▼                                               ▼
         [GitHub Server Token]                             [Local Git Identity]
           gh auth switch -u                           git config (--global / --local)
      Push/Pull HTTPS Permissions                     user.name & user.email (noreply)
```

---

## 🎮 Commands Cheat Sheet

| Command | Description | Example |
| :--- | :--- | :--- |
| `gswitch <key\|index>` | Switch active account globally | `gswitch work` or `gswitch 1` |
| `gswitch -l <key>` | Switch account **only for current repository** | `gswitch -l work` |
| `gswitch` | Open interactive menu selector | `gswitch` |
| `gswitch status` *(or `git who`)* | Inspect active token and git identities | `gswitch status` |
| `gswitch list` *(or `ls`)* | View all profiles with active indicator | `gswitch list` |
| `gswitch sync` | Auto-discover & import all accounts from `gh` | `gswitch sync` |
| `gswitch setup` | Launch first-time interactive setup wizard | `gswitch setup` |
| `gswitch add` | Interactively add a new account profile | `gswitch add` |
| `gswitch remove <key>` *(or `rm`)* | Delete a profile and re-index list | `gswitch rm work` |

*(You can also use the full command `git-account-switcher` or legacy alias `switch-git` interchangeably).*

---

## 🛠️ First-Time Onboarding Guide

### How does account management work?
You don't need to manually calculate your GitHub ID or noreply email address. `gswitch` handles this for you:

### 1. Automatic Discovery (`gswitch sync`)
If you have logged into your GitHub accounts using GitHub CLI:
```bash
gh auth login    # Run once for each account
```
Then run:
```bash
gswitch sync
```
`gswitch` automatically:
1. Detects all authenticated logins.
2. Queries the GitHub API for each account's numeric User ID and display name.
3. Automatically sets up the official private noreply email (`<id>+<username>@users.noreply.github.com`).
4. Generates easy shortcut keys (`1`, `2`, `work`, `main`).

---

### 2. Manual Interactive Addition (`gswitch add`)
To add an account that isn't logged into GitHub CLI yet:
```bash
gswitch add
```
You will be prompted for:
- **GitHub Username:** e.g., `octocat`
- **Role/Shortcut Key:** e.g., `personal`, `work`, `school`
- **Display Label:** e.g., `Personal Dev`
- **Commit Author Name & Email:** automatically suggested from GitHub API.

---

### 3. Repository-Scoped Switching (`-l` / `--local`)
When working inside a client or corporate repository, you often want your work email applied **only** to that specific folder without affecting your global personal Git configuration:
```bash
cd ~/projects/company-repo
gswitch -l work
```
- Sets `user.name` and `user.email` in `.git/config` of this repository only.
- Switches your active GitHub CLI token to `work` so `git push` and `gh pr create` succeed with correct permissions.

---

## 🤖 AI-Native Setup (For Cursor, Claude, Copilot, Antigravity)

Using an AI coding assistant? You don't even need to run commands manually. Simply copy and paste this prompt to your AI:

```text
Set up git-account-switcher on my machine from: https://github.com/ThanhNguyxnOrg/git-account-switcher
```

Your AI will read [`AGENT.md`](AGENT.md), check your prerequisites, run the 1-line installer, auto-discover your accounts via `gswitch sync`, and configure everything autonomously!

---

## 📂 Bonus: Automatic Folder Isolation (`includeIf`)

If you prefer completely hands-free folder automation (e.g., all repos in `~/work/` automatically commit with your work email), you can combine `gswitch` with Git's native `includeIf` in `~/.gitconfig`:

```gitconfig
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work
```

And inside `~/.gitconfig-work`:
```gitconfig
[user]
    name = Work Name
    email = <work-id>+work@users.noreply.github.com
```

- When editing and committing code inside `~/work/`, Git automatically signs commits as your work identity.
- When creating repos or pushing remotely, run `gswitch work` to align your GitHub CLI token!

---

## 🔧 Profile Configuration (`accounts.json`)

Account profiles are stored in:
- **Windows:** `C:\Users\<User>\.config\git-account-switcher\accounts.json`
- **macOS / Linux:** `~/.config/git-account-switcher/accounts.json`

### Schema Example:

```json
[
  {
    "index": 1,
    "key": "main",
    "aliases": ["1", "main", "personal"],
    "label": "Personal",
    "username": "octocat",
    "name": "Mona Lisa Octocat",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Personal side projects & open source"
  },
  {
    "index": 2,
    "key": "work",
    "aliases": ["2", "work", "corp"],
    "label": "Work",
    "username": "mona-corp",
    "name": "Mona Octocat",
    "email": "mona@enterprise.com",
    "description": "Enterprise company projects"
  }
]
```

---

## 🗑️ Uninstallation

### Windows
```powershell
.\uninstall.ps1
# To purge config directory as well:
.\uninstall.ps1 -PurgeConfig
```

### macOS & Linux
```bash
./uninstall.sh
# To purge config directory as well:
./uninstall.sh --purge
```

---

## 📄 License

Distributed under the [MIT License](LICENSE). Copyright (c) 2026 Thanh Nguyen.
