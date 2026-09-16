# git-account-switcher ⚡

> **The missing bridge between Git commit identities and GitHub CLI authentication.**  
> Switch GitHub accounts, active OAuth tokens, commit authors, and private noreply emails in a single command — with zero SSH configuration needed. Works natively across **Windows**, **macOS**, and **Linux**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows | macOS | Linux](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)]()
[![Shell: PowerShell | Bash | Zsh](https://img.shields.io/badge/Shell-PowerShell%20%7C%20Bash%20%7C%20Zsh-blueviolet.svg)]()
[![Git: >= 2.13](https://img.shields.io/badge/Git-%3E%3D%202.13-orange.svg)](https://git-scm.com/)
[![GitHub CLI: >= 2.24](https://img.shields.io/badge/GitHub%20CLI-%3E%3D%202.24-green.svg)](https://cli.github.com/)

---

## 🎯 The Problem

Developers managing multiple GitHub accounts (e.g., **Personal**, **Work**, and **School**) consistently suffer from two major friction points:

1. **`gh auth switch` is incomplete:**  
   GitHub CLI provides `gh auth switch`, but it **only swaps the CLI API/push token**. It leaves Git's `user.name` and `user.email` unchanged. As a result, you push code with your work token, but Git stamps the commit with your personal avatar and email (or vice-versa).
2. **SSH multi-account configuration is fragile & tedious:**  
   Traditional SSH workflows require generating multiple key pairs (`id_ed25519_*`), writing custom `~/.ssh/config` host aliases (e.g., `Host github-work`), and manually rewriting remote URLs (`git@github-work:user/repo.git`).

---

## 💡 The Solution

`git-account-switcher` unifies both layers into an atomic, instantaneous switch:
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

## 🚀 Features

- ⚡ **Single Command Switch:** Switch active token and git author in under 1 second.
- 🔄 **Auto-Discovery (`gswitch sync`):** Automatically scans your authenticated GitHub CLI accounts, fetches user IDs, and generates private noreply emails with zero manual setup.
- 🎯 **Repository-Local Switching (`-l` / `--local`):** Apply an identity solely to the current repository without modifying your system-wide global Git identity.
- 🔒 **Privacy First:** Out-of-the-box support for GitHub's private noreply emails (`<id>+<username>@users.noreply.github.com`).
- 🌐 **100% Cross-Platform:** Native support for Windows (PowerShell/CMD), macOS, and Linux (Bash/Zsh).
- ⌨️ **Ergonomic CLI:** Use the short command `gswitch`, the full command `git-account-switcher`, or legacy alias `switch-git`.
- 🎨 **Interactive Menu:** Run `gswitch` without arguments to launch a clean terminal selector.
- 🛠️ **Native Git Aliases:** Integrated seamlessly into `git who` and `git switch-acc`.
- 📁 **Folder Isolation Compatible:** Fully interoperable with Git's native `includeIf` conditional configs.
- ⚙️ **Portable JSON Profiles:** Profiles live in clean, human-readable JSON configurations (`~/.config/git-account-switcher/accounts.json`).

---

## 📦 Installation

### 1-Line Quick Install (No git clone required)

#### Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.ps1 | iex
```

#### macOS & Linux (Bash / Zsh):
```bash
curl -fsSL https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.sh | bash
```

---

### Manual Clone Installation

```bash
git clone https://github.com/ThanhNguyxnOrg/git-account-switcher.git
cd git-account-switcher

# On Windows:
.\install.ps1

# On macOS / Linux:
chmod +x install.sh
./install.sh
```

The installer will:
1. Copy executable scripts to your local user binary path (`~/.local/bin`).
2. Ensure `~/.local/bin` is in your environment `PATH`.
3. Auto-discover and populate your logged-in GitHub accounts via `gswitch sync`.
4. Configure Git's credential helper to use GitHub CLI (`gh auth git-credential`).
5. Register global Git aliases: `git who` and `git switch-acc`.

---

## 🎮 Usage

### 1. Fast Global Switch

You can switch using account keys, usernames, or index numbers:

```bash
gswitch main          # Switch to Personal / Main account
gswitch work          # Switch to Work account
gswitch school        # Switch to Academic / School account

# Or by index number:
gswitch 1
gswitch 2
gswitch 3
```

### 2. Repository-Local Switch (`-l` / `--local`)

Need to work on a specific repository under your work account without altering your machine's global Git profile?

```bash
cd ~/path/to/enterprise-repo
gswitch -l work
```
*This sets `user.name` and `user.email` locally in `.git/config` for this repository only, while switching your active GitHub CLI token!*

### 3. Auto-Discover & Sync Accounts

Have accounts already logged into GitHub CLI (`gh auth login`)? Import them automatically in 1 second:

```bash
gswitch sync
```

`gswitch` will inspect `gh auth status`, query GitHub's user API, and configure all IDs and private noreply emails automatically.

### 4. Interactive Selection Menu

Simply run `gswitch` with no arguments:

```text
============================================================
 CURRENT GITHUB & GIT IDENTITY
============================================================
 GitHub CLI Active : octocat
 Git Global Name   : Mona Lisa Octocat
 Git Global Email  : 583231+octocat@users.noreply.github.com
============================================================

Available accounts:
 [1] Personal           583231+octocat@users.noreply.github.com        (key: main)
 [2] Work               mona@enterprise.com                            (key: work)
 [3] School             mona@university.edu                            (key: school)

Select account [1-3], 's' to sync, or Enter to cancel: 
```

### 5. Check Current Identity

```bash
gswitch status
# or with Git alias:
git who
```

### 6. List All Configured Profiles

```bash
gswitch list
# (shows which account is currently * ACTIVE with a green indicator)
```

---

## 🔧 Profile Configuration (`accounts.json`)

Account profiles are stored in:
```
~/.config/git-account-switcher/accounts.json
```

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
  },
  {
    "index": 3,
    "key": "school",
    "aliases": ["3", "school", "academic"],
    "label": "School",
    "username": "student-mona",
    "name": "Mona Student",
    "email": "mona@university.edu",
    "description": "University assignments & research"
  }
]
```

---

## 📂 Bonus: Automatic Folder Isolation (`includeIf`)

If you maintain specific directories dedicated to a specific account (e.g., `~/University/` for school projects), you can pair `gswitch` with Git's native `includeIf` in `~/.gitconfig`:

```gitconfig
[includeIf "gitdir:~/University/"]
    path = ~/.gitconfig-school
```

And inside `~/.gitconfig-school`:
```gitconfig
[user]
    name = Student Name
    email = <school-id>+student@users.noreply.github.com
```

With this setup:
- Any commit made inside `~/University/` is **permanently guaranteed** to commit under your school identity.
- When creating repos or pushing remotely, simply run `gswitch school` to align your GitHub CLI push token!

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
