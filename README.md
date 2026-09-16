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

## 🎯 The Problem & The Solution

- **The Problem:** `gh auth switch` swaps your GitHub CLI push token, but **leaves Git's commit identity untouched**. Your commit logs still stamp your personal email on work repositories (or vice versa). Meanwhile, setting up multiple SSH keys and host aliases is fragile and cumbersome.
- **The Solution:** `git-account-switcher` (`gswitch`) atomically updates **both layers** in 1 second:
  1. Switches active GitHub CLI token (`gh auth switch -u <username>`).
  2. Updates Git commit author (`git config user.name` & `user.email`) — supporting both **global** and **repository-local** scopes.
  3. Uses GitHub's native privacy-protected `noreply` email to keep personal addresses safe.

```
                         ┌────────────────────────────────────────┐
                         │  git-account-switcher <acc> / gswitch  │
                         └───────────────────┬────────────────────┘
                                             │
                      ┌──────────────────────┴──────────────────────┐
                      ▼                                             ▼
       ┌──────────────────────────────┐              ┌──────────────────────────────┐
       │   GitHub CLI Token Layer     │              │      Git Identity Layer      │
       │   (gh auth switch -u <user>) │              │    (git config user.*)       │
       └──────────────┬───────────────┘              └──────────────┬───────────────┘
                      ▼                                             ▼
       HTTPS Push / Pull / PR Token                  Author Name & Noreply Email
       ✓ Zero SSH Config Required                    ✓ Global or Repo-Local (--local)
```

---

## ⚡ Quick Start

Choose your preferred setup method:

### 🤖 Method 1: AI Agent Auto-Setup (Zero Touch)

> **Using an AI Coding Assistant?** (Cursor, Claude Code, GitHub Copilot, Antigravity, Windsurf)  
> Copy & paste this prompt into your AI chat:
>
> ```text
> Read https://github.com/ThanhNguyxnOrg/git-account-switcher/blob/master/AGENT.md and set up git-account-switcher on my machine. Check my authenticated GitHub CLI accounts, ask me what roles and shortcut aliases I want for each account, and configure everything automatically.
> ```
>
> *The AI agent will autonomously read the protocol, run the installer, prompt you for your preferred nicknames/shortcuts (e.g. `work / w`, `personal / p`), and test everything for you!*

---

### 💻 Method 2: 1-Line Self-Installation (Manual)

#### Step 1: Install via 1-Line Command

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.ps1 | iex
```

**macOS & Linux (Bash / Zsh):**
```bash
curl -fsSL https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.sh | bash
```

#### Step 2: Configure Your Accounts

- **Auto-Discovery (Fastest):** If you already logged in with `gh auth login`, simply run:
  ```bash
  gswitch sync
  ```
- **Setup Wizard:** Run the interactive assistant:
  ```bash
  gswitch setup
  ```
- **Add Accounts Manually:**
  ```bash
  gswitch add
  ```

#### Step 3: Switch & Code!

```bash
gswitch personal      # Switch globally
gswitch -l work       # Switch for current repository only
gswitch               # Open interactive selection menu
git who               # Check who is currently active
```

---

## 🎮 Command Cheat Sheet

| Command | Shorthand | Description |
| :--- | :--- | :--- |
| `gswitch <target>` | `gswitch 1` | Switch account globally by key, username, alias, or index |
| `gswitch -l <target>` | `gswitch --local` | Switch account for the **current repository only** |
| `gswitch` | | Open interactive numbered selection menu |
| `gswitch status` | `gswitch current`, `git who` | Inspect active GitHub token, global identity, and local repo override |
| `gswitch list` | `gswitch ls` | List all profiles with active status and assigned shortcut aliases |
| `gswitch alias <acc> <new>`| | Assign a new shortcut alias (e.g. `gswitch alias work w`) |
| `gswitch bind <dir> <acc>`| `gswitch folder` | Permanently bind an entire folder/dir to an account (`includeIf`) |
| `gswitch unbind <dir>` | `gswitch unlink` | Remove a folder-to-account binding |
| `gswitch bindings` | `gswitch dirs` | List all active folder-to-account bindings |
| `gswitch edit` | `gswitch config` | Open `accounts.json` in VS Code / Notepad / default editor |
| `gswitch sync` | `gswitch import` | Auto-detect all accounts logged into `gh` and fetch privacy IDs |
| `gswitch setup` | `gswitch init` | Run the guided first-time interactive setup wizard |
| `gswitch add` | | Add or update an account profile interactively |
| `gswitch remove <acc>` | `gswitch rm` | Remove an account profile (supports index, key, user, or alias) |
| `gswitch help` | `gswitch -h` | Display help reference and usage examples |

---

## 🖥️ Terminal Interface Preview

Running `gswitch list` or `gswitch` displays your accounts, active indicators, and aliases clearly:

```text
Configured Account Profiles (3):
================================================================================
   [1] Personal         octocat          583231+octocat@users.noreply.github.com 
       Aliases: 1, personal, octocat, p
 > [2] Work             mona-corp        mona@enterprise.com * ACTIVE
       Aliases: 2, work, corp, w
   [3] School           student-mona     mona@university.edu 
       Aliases: 3, school, uni
================================================================================
```

---

## 📂 Optional Power Feature: Folder-Based Isolation (Set & Forget)

> 💡 **100% Optional:** For most users, standard global switching (`gswitch work`) or repo-local switching (`gswitch -l work`) is all you need.  
> However, if you organize your code into dedicated folders (e.g., all company projects in `C:\Projects\Work` and personal projects in `C:\Projects\Personal`), you can bind an entire folder to an account so you **never have to switch manually**.

### How It Works:
`gswitch bind` leverages Git's native conditional includes (`includeIf`). Every repository inside the bound directory (including newly cloned ones) automatically commits under that account's name and email.

### Quick Step-by-Step Guide:

#### 1. Bind a Folder to an Account Profile
Replace the path with your own target directory:
```bash
# Windows
gswitch bind C:\Projects\Work work
gswitch bind C:\Projects\Personal personal

# macOS / Linux
gswitch bind ~/projects/work work
gswitch bind ~/projects/personal personal
```

#### 2. Verify It Works (`git who`)
Navigate to any repository inside that directory and check your identity:
```bash
cd C:\Projects\Work\any-project
git who
```
`git who` automatically detects the conditional rule:
```text
============================================================
 CURRENT GITHUB & GIT IDENTITY
============================================================
 GitHub CLI Active : mona-corp
 Git Global Name   : Mona Personal
 Git Global Email  : 583231+octocat@users.noreply.github.com
 ------------------------------------------------------------
 [Folder Override via includeIf detected]
 Git Folder Name   : Mona Corporate
 Git Folder Email  : mona@enterprise.com
============================================================
```

#### 3. List or Remove Bindings Anytime
```bash
# View all folder-to-account rules registered on your machine:
gswitch bindings

# Remove a binding when a project folder is archived or moved:
gswitch unbind C:\Projects\Work
```

*For multi-account JSON examples and technical details, see the [Configuration Guide](docs/configuration.md#📂-automatic-folder-isolation-gswitch-bind--includeif).*

---

## 📚 Documentation

- 🚀 **[Complete Workflow Guide](docs/workflow.md)**: 6-phase walkthrough from `gh auth login` to daily switching and verification.
- ⚙️ **[Configuration & Schema Guide](docs/configuration.md)**: `accounts.json` reference, private noreply emails, and real-world examples.
- ❓ **[Troubleshooting & FAQ](docs/troubleshooting.md)**: Resolving Windows Credential Manager caching, 403 Forbidden, and detached commits.
- 🤖 **[Autonomous AI Agent Protocol](AGENT.md)**: Prompt instructions for AI tools (Cursor, Claude, Copilot, Antigravity) to manage accounts.
- 🤝 **[Contributing & Testing](CONTRIBUTING.md)**: Local development setup, test suite execution, and PR guidelines.

---

## 🗑️ Uninstallation

To completely remove `git-account-switcher` and its shell aliases:

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/uninstall.ps1 | iex
```

**macOS & Linux (Bash / Zsh):**
```bash
curl -fsSL https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/uninstall.sh | bash
```

---

## 📄 License

Distributed under the [MIT License](LICENSE). Built for developers managing multiple GitHub identities with speed and security.
