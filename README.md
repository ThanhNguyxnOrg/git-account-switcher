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
- **Toggles Git Identity (`git config --global`):** Updates `user.name` and `user.email` (using GitHub's privacy-protected `noreply` email).
- **Zero SSH required:** Uses GitHub CLI as Git's native HTTPS credential helper (`git-credential`).

```
                         ┌────────────────────────────────────────┐
                         │  git-account-switcher <acc> / gswitch  │
                         └───────────────────┬────────────────────┘
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     ▼                                               ▼
         [GitHub Server Token]                             [Local Git Identity]
           gh auth switch -u                               git config --global
      Push/Pull HTTPS Permissions                     user.name & user.email (noreply)
```

---

## 🚀 Features

- ⚡ **Single Command Switch:** Switch active token and git author in under 1 second.
- 🔒 **Privacy First:** Configured out-of-the-box with GitHub's private noreply emails (`<id>+<username>@users.noreply.github.com`).
- 🌐 **100% Cross-Platform:** Native support for Windows (PowerShell/CMD), macOS, and Linux (Bash/Zsh).
- ⌨️ **Multiple CLI Commands:** Use full command `git-account-switcher`, quick alias `gswitch`, or legacy `switch-git`.
- 🎨 **Interactive Menu:** Run `gswitch` without arguments to launch a clean terminal selector.
- 🛠️ **Native Git Aliases:** Integrated seamlessly into `git who` and `git switch-acc`.
- 📁 **Folder Isolation Compatible:** Fully interoperable with Git's native `includeIf` conditional configs.
- ⚙️ **JSON Profile Management:** Profiles live in clean, portable JSON configurations (`~/.config/git-account-switcher/accounts.json`).

---

## 📦 Installation

### Clone the Repository

```bash
git clone https://github.com/ThanhNguyxnOrg/git-account-switcher.git
cd git-account-switcher
```

### Windows (PowerShell)

Run PowerShell in the repository root:

```powershell
.\install.ps1
```

### macOS & Linux (Bash / Zsh)

Run in terminal:

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Copy executable scripts to your local user binary path (`~/.local/bin`).
2. Ensure `~/.local/bin` is in your environment `PATH`.
3. Deploy your account profile configuration to `~/.config/git-account-switcher/accounts.json`.
4. Configure Git's credential helper to use GitHub CLI (`gh auth git-credential`).
5. Register global Git aliases: `git who` and `git switch-acc`.

---

## 🎮 Usage

### 1. Fast Switch via Keywords or Index

You can use either `git-account-switcher` or the short alias `gswitch`:

```bash
gswitch school        # Switch to Academic / School account
gswitch real          # Switch to Primary / Personal account
gswitch 07            # Switch to Secondary / Work account
```

*(You can also use index numbers: `gswitch 1`, `gswitch 2`, `gswitch 3`)*

### 2. Interactive Selection Menu

Simply run `gswitch` (or `git-account-switcher`) with no arguments:

```text
============================================================
 CURRENT GITHUB & GIT IDENTITY
============================================================
 GitHub CLI Active : ThanhNguyn
 Git Global Name   : ThanhNguyn
 Git Global Email  : 253024274+ThanhNguyn@users.noreply.github.com
============================================================

Available accounts:
 [1] School               253024274+ThanhNguyn@users.noreply.github.com        (Command: gswitch school)
 [2] RealThanhNguyxn      274720769+RealThanhNguyxn@users.noreply.github.com   (Command: gswitch real)
 [3] ThanhNguyxn07        272073999+ThanhNguyxn07@users.noreply.github.com     (Command: gswitch 07)

Select account [1-3] or press Enter to cancel: 
```

### 3. Check Current Identity

```bash
gswitch status
# or with Git alias:
git who
```

### 4. Git Native Aliases

```bash
git switch-acc real
git switch-acc school
git who
```

---

## 🔧 Managing Account Profiles (`accounts.json`)

Account profiles are stored in:
```
~/.config/git-account-switcher/accounts.json
```

### Schema Example:

```json
[
  {
    "index": 1,
    "key": "school",
    "aliases": ["1", "school", "thanhnguyn"],
    "label": "School",
    "username": "ThanhNguyn",
    "name": "ThanhNguyn",
    "email": "253024274+ThanhNguyn@users.noreply.github.com",
    "description": "Academic / University"
  },
  {
    "index": 2,
    "key": "real",
    "aliases": ["2", "real", "realthanhnguyxn"],
    "label": "RealThanhNguyxn",
    "username": "RealThanhNguyxn",
    "name": "RealThanhNguyxn",
    "email": "274720769+RealThanhNguyxn@users.noreply.github.com",
    "description": "Personal / Primary"
  }
]
```

### Finding your GitHub Noreply Email:
1. Switch to your desired account: `gh auth switch -u <username>`
2. Query your GitHub ID via CLI:
   ```bash
   gh api user --jq "{id: .id, login: .login}"
   ```
3. Your private noreply email is:
   ```
   <id>+<login>@users.noreply.github.com
   ```

---

## 📂 Bonus: Automatic Folder Isolation (`includeIf`)

If you maintain specific directories dedicated to a specific account (e.g., `D:/University/` for school projects), you can leverage Git's native `includeIf` in `~/.gitconfig`:

```gitconfig
[includeIf "gitdir/i:D:/University/"]
    path = C:/Users/YourUser/.gitconfig-school
```

And inside `C:/Users/YourUser/.gitconfig-school`:
```gitconfig
[user]
    name = YourSchoolName
    email = <school-id>+YourSchoolName@users.noreply.github.com
```

With this setup:
- Any commit made inside `D:/University/` is **permanently guaranteed** to commit under your school identity.
- When creating repos or pushing remotely, simply run `gswitch school` to align your GitHub CLI token!

---

## 🗑️ Uninstallation

### Windows
```powershell
.\uninstall.ps1
# To purge config as well:
.\uninstall.ps1 -PurgeConfig
```

### macOS & Linux
```bash
./uninstall.sh
# To purge config as well:
./uninstall.sh --purge
```

---

## 📄 License

Distributed under the [MIT License](LICENSE). Copyright (c) 2026 Thanh Nguyen.
