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
- [🚀 Complete Workflow (From Scratch to Daily Use)](#-complete-workflow-from-scratch-to-daily-use)
- [🎮 Commands Reference & Help](#-commands-reference--help)
- [📋 Configuration File (`accounts.json`) & Examples](#-configuration-file-accountsjson--examples)
- [🛠️ Account Management (`add`, `remove`, `sync`)](#️-account-management-add-remove-sync)
- [🤖 AI-Native Setup (For Cursor, Claude, Copilot, Antigravity)](#-ai-native-setup-for-cursor-claude-copilot-antigravity)
- [📂 Bonus: Automatic Folder Isolation (`includeIf`)](#-bonus-automatic-folder-isolation-includeif)
- [💻 Local Development & Testing](#-local-development--testing)
- [🤝 Contributing](#-contributing)
- [❓ FAQ & Troubleshooting](#-frequently-asked-questions--troubleshooting)
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
gswitch -l work       # Switch for current repository only
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

## 🚀 Complete Workflow (From Scratch to Daily Use)

Here is the complete end-to-end guide for setting up and working with multiple GitHub accounts on any machine:

### Phase 1: Prerequisites & Authentication
1. Ensure **Git** (>= 2.13) and **GitHub CLI** (>= 2.24) are installed:
   ```bash
   git --version
   gh --version
   ```
   *(If `gh` is missing, install via `winget install --id GitHub.cli` on Windows, or `brew install gh` on macOS).*

2. Authenticate **each** of your GitHub accounts in GitHub CLI:
   ```bash
   gh auth login
   ```
   - What account do you want to log into? **GitHub.com**
   - What is your preferred protocol for Git operations? **HTTPS**
   - Authenticate Git with your GitHub credentials? **Yes**
   - How would you like to authenticate GitHub CLI? **Login with a web browser**
   *(Repeat this step once for every account you own: personal, work, school).*

3. Confirm that all accounts are authenticated:
   ```bash
   gh auth status
   ```

---

### Phase 2: Installation
Run the 1-line installation script:
- **Windows (PowerShell):**
  ```powershell
  irm https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.ps1 | iex
  ```
- **macOS / Linux (Bash):**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.sh | bash
  ```

---

### Phase 3: First-Time Account Onboarding
Choose whichever onboarding flow suits your preference:

- **Flow A: Instant Auto-Discovery (`gswitch sync`)**  
  Scans your `gh auth status`, retrieves your numerical GitHub user IDs, and generates privacy-protected emails (`<id>+<username>@users.noreply.github.com`):
  ```bash
  gswitch sync
  ```

- **Flow B: Guided Setup Wizard (`gswitch setup`)**  
  An interactive step-by-step interview to name roles (`work`, `personal`, `school`) and set custom author labels:
  ```bash
  gswitch setup
  ```

- **Flow C: Add Individually via CLI (`gswitch add`)**  
  ```bash
  gswitch add octocat personal
  gswitch add mona-corp work "Mona Corp" "mona@enterprise.com"
  ```

---

### Phase 4: Daily Development Scenarios

#### Scenario 1: Working on Personal Projects (Global Switch)
Switch system-wide so any new repository or terminal uses your personal identity:
```bash
gswitch personal
# Or switch by number:
gswitch 1
```

#### Scenario 2: Working on a Client or Corporate Repo (Local Switch)
Inside a specific corporate repository, you want commits and pushes to use your work account **without** changing your global machine defaults:
```bash
cd ~/projects/enterprise-client
gswitch -l work
```
*Notice the `-l` (`--local`) flag: this configures `.git/config` exclusively for this project folder.*

#### Scenario 3: Interactive Selection Menu
Not sure of the exact shortcut key? Run `gswitch` with no arguments:
```bash
gswitch
```
An interactive list will appear showing all profiles and an `* ACTIVE` badge next to the current user. Just type the number and press Enter!

---

### Phase 5: Committing and Pushing with Confidence

1. Check your active identity at any time:
   ```bash
   git who
   # or
   gswitch status
   ```
   Output:
   ```
   ============================================================
    CURRENT GITHUB & GIT IDENTITY
   ============================================================
    GitHub CLI Active : mona-corp
    Git Global Name   : Mona Octocat
    Git Global Email  : mona@enterprise.com
   ============================================================
   ```

2. Make your commit and push normally:
   ```bash
   git add .
   git commit -m "feat: complete user authentication"
   git push origin main
   ```
   - **No SSH key collisions.**
   - **No Git Credential Manager popup mismatches.**
   - **100% correct avatar and contribution attribution on GitHub!**

---

### Phase 6: Ongoing Account Maintenance
- Need to add another account? `gswitch add`
- Need to remove an old account? `gswitch remove work` (or `gswitch remove 2 -f`)
- Need to re-sync after logging into GitHub CLI? `gswitch sync`

---

## 🎮 Commands Reference & Help

Run `gswitch help` in your terminal to see the built-in reference at any time:

```
============================================================
 git-account-switcher (gswitch) ⚡
 Fast Multi-Account GitHub & Git Identity Switcher
============================================================

USAGE:
  gswitch [account]                   Switch account globally (by key, username, or index)
  gswitch -l [account]                Switch account locally (current repository only)
  gswitch                             Open interactive account selection menu
  gswitch status | who                View active GitHub token & Git identities
  gswitch list | ls                   List all configured account profiles
  gswitch sync                        Auto-discover & sync accounts from GitHub CLI
  gswitch setup                       Launch interactive first-time setup wizard
  gswitch add [user] [key] [name] [email]  Add or update an account profile
  gswitch remove [key] [-f]           Remove an account profile and re-index list
  gswitch help                        Display this help message
```

### Command Matrix

| Command | Description | Example |
| :--- | :--- | :--- |
| `gswitch <key\|index>` | Switch account globally | `gswitch work` or `gswitch 1` |
| `gswitch -l <key\|index>` | Switch account **only for current repository** | `gswitch -l work` |
| `gswitch` | Open interactive menu selector | `gswitch` |
| `gswitch status` *(or `git who`)* | Inspect active token, global, and local identities | `gswitch status` |
| `gswitch list` *(or `ls`)* | View all profiles with `* ACTIVE` indicator | `gswitch list` |
| `gswitch sync` | Auto-discover & import all accounts from `gh auth status` | `gswitch sync` |
| `gswitch setup` | Launch first-time interactive setup wizard | `gswitch setup` |
| `gswitch add` | Interactively or directly add/update a profile | `gswitch add octocat work` |
| `gswitch remove <key>` *(or `rm`)* | Delete a profile and re-index list | `gswitch remove work` |
| `gswitch help` *(or `-h`)* | Show detailed help message | `gswitch help` |

### Command Flags

| Flag | Meaning | Scope |
| :--- | :--- | :--- |
| `-l`, `--local` | Scope Git identity change to current repository (`.git/config`) | Local Repo |
| `-g`, `--global` | Scope Git identity change system-wide (`~/.gitconfig`) | Global (Default) |
| `-f`, `--force` | Force execution without interactive confirmation prompts | Action flag |
| `-h`, `--help` | Show command-line options and examples | Help flag |

*(Aliases: `gswitch`, `git-account-switcher`, and `switch-git` can be used interchangeably).*

---

## 📋 Configuration File (`accounts.json`) & Examples

### Storage Location
Account configurations are stored in an easily accessible JSON file:
- **Windows:** `%USERPROFILE%\.config\git-account-switcher\accounts.json`  
  *(e.g., `C:\Users\<User>\.config\git-account-switcher\accounts.json`)*
- **macOS & Linux:** `~/.config/git-account-switcher/accounts.json`

---

### Schema Specification

Each entry in `accounts.json` contains the following fields:

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `index` | Integer | Numerical selector for fast switching (`gswitch 1`, `gswitch 2`). Re-indexed automatically. | `1` |
| `key` | String | Short memorable keyword for quick CLI switching (`gswitch personal`, `gswitch work`). | `"work"` |
| `aliases` | Array | Alternative keywords or shortcuts that activate this account. | `["2", "work", "corp"]` |
| `label` | String | Friendly display label shown in menus, tables, and headers. | `"Work (Enterprise)"` |
| `username` | String | Exact GitHub username used for `gh auth switch -u <username>`. | `"mona-corp"` |
| `name` | String | Git commit author name (`git config user.name`). | `"Mona Octocat"` |
| `email` | String | Git commit author email (`git config user.email`). | `"mona@enterprise.com"` |
| `description`| String | Human-readable note describing the account's purpose. | `"Company client projects"` |

> [!TIP]
> **What is the numerical ID in the GitHub noreply email?**  
> GitHub generates a privacy email for every user in the format `<id>+<username>@users.noreply.github.com`. Using this hides your private email on GitHub while still linking your commits directly to your GitHub avatar and contribution activity graph.  
> You can find your ID at any time by running:
> ```bash
> gh api user --jq .id
> ```

---

### Configuration Examples

#### Example 1: Standard 2-Account Setup (Personal & Work)
```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "main"],
    "label": "Personal",
    "username": "octocat",
    "name": "Mona Lisa Octocat",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Personal open-source and side projects"
  },
  {
    "index": 2,
    "key": "work",
    "aliases": ["2", "work", "corp"],
    "label": "Work",
    "username": "mona-corp",
    "name": "Mona Octocat",
    "email": "mona@company.com",
    "description": "Corporate client projects"
  }
]
```

#### Example 2: 3-Account Setup (Personal, Work, School / Research)
```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "main"],
    "label": "Personal",
    "username": "octocat",
    "name": "Mona Lisa",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Personal projects"
  },
  {
    "index": 2,
    "key": "work",
    "aliases": ["2", "work"],
    "label": "Work",
    "username": "mona-corp",
    "name": "Mona Octocat",
    "email": "mona@enterprise.com",
    "description": "Company work projects"
  },
  {
    "index": 3,
    "key": "school",
    "aliases": ["3", "school", "edu"],
    "label": "School",
    "username": "student-mona",
    "name": "Mona Student",
    "email": "mona@university.edu",
    "description": "University assignments and research"
  }
]
```

---

## 🛠️ Account Management (`add`, `remove`, `sync`)

### 1. Adding an Account (`gswitch add`)
You can add accounts either **interactively** or **directly via command-line arguments**:

- **Interactive Mode:**
  ```bash
  gswitch add
  ```
  Prompts you for username, role/key, display label, and suggests the noreply email from the GitHub API.

- **Direct CLI Mode (Script & AI Friendly):**
  ```bash
  gswitch add octocat personal
  # Or with full parameters:
  gswitch add octocat personal "Mona Lisa" "583231+octocat@users.noreply.github.com"
  ```
  *If an account with the same username or key already exists, `gswitch add` updates it cleanly without creating duplicates!*

---

### 2. Removing an Account (`gswitch remove`)
Remove any profile by its **number index**, **key**, or **username**:

- **Interactive Removal:**
  ```bash
  gswitch remove
  ```
  Displays the account list and asks which profile you want to delete.

- **Direct Removal by Key or Index:**
  ```bash
  gswitch remove work
  # Or:
  gswitch remove 2
  ```

- **Silent / Force Removal (`-f`):**
  ```bash
  gswitch remove work -f
  ```
  Bypasses the confirmation prompt — ideal for scripts and AI agents.

---

### 3. Auto-Syncing (`gswitch sync`)
If you logged into new accounts in GitHub CLI (`gh auth login`), run:
```bash
gswitch sync
```
This automatically scans all logged-in sessions, fetches user IDs from the GitHub API, preserves your custom labels, and writes the updated configuration.

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
- When pushing remotely or creating pull requests, run `gswitch work` to align your GitHub CLI token!

---

## 💻 Local Development & Testing

Want to contribute, test improvements, or run your own customized build of `git-account-switcher`?

### 1. Repository Directory Structure
```
git-account-switcher/
├── bin/
│   ├── git-account-switcher.ps1   # PowerShell engine (Windows)
│   ├── git-account-switcher       # POSIX Bash engine (macOS / Linux)
│   ├── switch-git.ps1             # Backward-compatible PowerShell wrapper
│   ├── switch-git.cmd             # Windows CMD wrapper
│   └── switch-git                 # Backward-compatible Bash wrapper
├── config/
│   ├── accounts.example.json      # Sample generic configuration
│   └── accounts.json              # First-time installation template
├── tests/
│   ├── test-all.ps1               # Automated test suite for PowerShell
│   └── test-all.sh                # Automated test suite for POSIX Bash
├── install.ps1                    # 1-line & local installer for Windows
├── install.sh                     # 1-line & local installer for macOS / Linux
├── uninstall.ps1                  # Uninstaller for Windows
├── uninstall.sh                   # Uninstaller for macOS / Linux
├── AGENT.md                       # AI Agent autonomous operations protocol
├── CONTRIBUTING.md                # Contribution & developer guide
├── LICENSE                        # MIT License
└── README.md                      # Documentation & guides
```

### 2. Testing Locally Without Modifying Your Personal Config
Both PowerShell and Bash implementations support the `GIT_ACCOUNT_SWITCHER_CONFIG` environment variable to sandbox configuration during development:

**Windows (PowerShell):**
```powershell
# Point to an isolated sandbox config
$env:GIT_ACCOUNT_SWITCHER_CONFIG = "$PWD\tests\sandbox.json"

# Run your modified script directly
.\bin\git-account-switcher.ps1 list
.\bin\git-account-switcher.ps1 add octocat work
.\bin\git-account-switcher.ps1 status

# Reset environment variable
Remove-Item env:GIT_ACCOUNT_SWITCHER_CONFIG
Remove-Item .\tests\sandbox.json -ErrorAction SilentlyContinue
```

**macOS & Linux (Bash):**
```bash
# Point to an isolated sandbox config
export GIT_ACCOUNT_SWITCHER_CONFIG="$PWD/tests/sandbox.json"

# Run your modified script directly
./bin/git-account-switcher list
./bin/git-account-switcher add octocat work
./bin/git-account-switcher status

# Reset environment variable
unset GIT_ACCOUNT_SWITCHER_CONFIG
rm -f ./tests/sandbox.json
```

### 3. Running the Automated Test Suites
Run the automated test runner to ensure a 100% test pass rate across syntax, commands, and sandbox integration:

- **On Windows:**
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test-all.ps1
  ```

- **On macOS / Linux / Git Bash:**
  ```bash
  bash ./tests/test-all.sh
  ```

---

## 🤝 Contributing

We welcome community contributions! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) guide for details on:
- Project philosophy and cross-platform parity requirements
- How to create sandbox tests for new features
- Conventional commit conventions
- Submitting Pull Requests

---

## ❓ Frequently Asked Questions & Troubleshooting

### Q: Why does `git-account-switcher` use GitHub CLI (`gh`) credentials instead of Git Credential Manager (GCM)?
**A:** Traditional Git Credential Manager (GCM) stores one Windows Credential / Keychain token per hostname (`github.com`). When you attempt to work with multiple GitHub accounts, GCM frequently forces you to re-login, triggers modal login popups, or pushes with the wrong token.  
`git-account-switcher` delegates Git credentials to GitHub CLI's `gh auth git-credential`. Because `gh` manages multiple simultaneous authenticated sessions, swapping accounts is an instant atomic command (`gh auth switch -u <user>`).

---

### Q: How do private GitHub noreply emails work, and why are they recommended?
**A:** GitHub provides every user with an official privacy email formatted as:  
`<id>+<username>@users.noreply.github.com`  
Using this email in Git commits:
1. Keeps your personal and corporate email addresses private from web scrapers and public Git logs.
2. Correctly matches commits to your GitHub user profile, rendering your user avatar.
3. Automatically increments your GitHub contribution activity graph ("green squares").

> [!TIP]
> You can retrieve your account's numeric GitHub user ID at any time by running:
> ```bash
> gh api user --jq .id
> ```

---

### Q: How does the `-l` / `--local` flag differ from global switching?
**A:**
- **Global (`gswitch work`):** Updates `user.name` and `user.email` in `~/.gitconfig` (affects your whole system) and switches the active GitHub CLI token.
- **Local (`gswitch -l work`):** Updates `user.name` and `user.email` **only inside `.git/config` of the current repository**. Your system-wide Git configuration remains untouched, while your active GitHub CLI token is switched so remote pushes succeed under the work account.

---

### Q: What should I do if `git push` fails with "Authentication Failed" or 403?
**A:** Follow this quick checklist:
1. Verify who is currently active:
   ```bash
   git who
   ```
2. If your GitHub CLI token has expired or is invalid, refresh it:
   ```bash
   gh auth refresh -h github.com
   ```
3. Confirm that Git's credential helper is configured to use GitHub CLI:
   ```bash
   git config --get-all credential.helper
   ```
   *The output should end with `!gh auth git-credential` (or `!'C:\Program Files\GitHub CLI\gh.exe' auth git-credential` on Windows).*

---

### Q: Can I use custom domain emails for work instead of noreply emails?
**A:** Yes! You can provide any valid email in `accounts.json` (such as `mona@enterprise.com`), or configure it directly via:
```bash
gswitch add <username> <key> "Mona Octocat" "mona@enterprise.com"
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
