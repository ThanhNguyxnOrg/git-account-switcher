# AI Agent Setup & Operations Guide (Cursor, Claude Code, Copilot, Antigravity, ChatGPT)

> **For AI Coding Assistants:** When a user asks you to set up, configure, add accounts, or troubleshoot `git-account-switcher` on their machine, follow this autonomous protocol. Avoid making the user run manual commands unless interactive browser login is required.

[![Platform: Cross-Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)](README.md)
[![Status: Autonomous Ready](https://img.shields.io/badge/Autonomous%20Protocol-Ready-green.svg)](AGENT.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

---

## 🧠 System Architecture Overview

`git-account-switcher` operates at two complementary layers:

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

1. **GitHub CLI Authentication Layer:** Swaps active OAuth tokens via `gh auth switch -u <username>`. This controls HTTPS push/pull permissions and repository API access.
2. **Git Commit Authorship Layer:** Swaps `user.name` and `user.email` (using GitHub's privacy-protected noreply email format `<id>+<username>@users.noreply.github.com`) globally or locally within `.git/config`.

---

## 🤖 Autonomous Setup Protocol

### Step 1: Inspect System Environment
Execute non-intrusive terminal checks:
1. **Detect OS:** Windows, macOS, or Linux.
2. **Check Git:**
   ```bash
   git --version
   ```
3. **Check GitHub CLI (`gh`):**
   ```bash
   gh --version
   ```
   *(If `gh` is missing, offer or proceed to install it: `winget install --id GitHub.cli` on Windows, `brew install gh` on macOS, or the appropriate package manager on Linux).*
4. **Check Authenticated Accounts:**
   ```bash
   gh auth status
   ```

---

### Step 2: Execute 1-Line Installer
Run the official 1-line installation command:

#### On Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.ps1 | iex
```

#### On macOS & Linux (Bash / Zsh):
```bash
curl -fsSL https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master/install.sh | bash
```

---

### Step 3: Run Auto-Discovery or Add Accounts
If the user already has accounts authenticated in `gh`:
```bash
gswitch sync
```
*`gswitch sync` automatically scans `gh auth status`, queries GitHub's user API, retrieves user IDs, and configures privacy-protected noreply emails.*

If the user wants to add an account directly via CLI:
```bash
gswitch add <username> <role_key>
# Example:
gswitch add octocat work
```

---

### Step 4: Ask the User for Roles & Shortcut Aliases
Present the discovered accounts clearly to the user:
> *"I detected these GitHub accounts on your system: `<Account1>`, `<Account2>`. What roles and shortcut aliases would you like to assign to them? (For example: `work` with shortcut `w`, `personal` with shortcut `p`, `school` with shortcut `s`)"*

Once the user replies with their preferences:
1. Assign roles and shortcut aliases using:
   ```bash
   gswitch alias <account> <shortcut>
   ```
   Or edit their local configuration file directly at:
   - **Windows:** `C:\Users\<Username>\.config\git-account-switcher\accounts.json`
   - **macOS / Linux:** `~/.config/git-account-switcher/accounts.json`

#### Configuration File Schema:
```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "octocat", "p"],
    "label": "Personal",
    "username": "octocat",
    "name": "Mona Lisa",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Personal account"
  }
]
```

---

### Step 5: Verification & Self-Testing Checklist
Before completing your response to the user, run these non-destructive checks:
1. **List configured profiles:**
   ```bash
   gswitch list
   ```
2. **Confirm active identity:**
   ```bash
   gswitch status
   ```
3. **Verify help output:**
   ```bash
   gswitch help
   ```
4. **Run integration test suite (optional verification):**
   - Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test-all.ps1`
   - Unix: `bash ./tests/test-all.sh`

---

## 🛠️ Edge Cases & AI Remediation

| Scenario | Symptom | Remediation Action |
| :--- | :--- | :--- |
| **Missing `gh` CLI** | Command not found: `gh` | Install via `winget install --id GitHub.cli` (Windows) or `brew install gh` (macOS), then restart terminal. |
| **No Logged-In Accounts** | `gh auth status` returns "You are not logged in" | Ask the user to run `gh auth login` in their terminal to complete the web browser OAuth flow. |
| **Windows Credential Manager Conflict** | Git pushes as old account despite switching | Run `git config --global --unset-all credential.helper` followed by `git config --global credential.helper ""` and `git config --global --add credential.helper "!gh auth git-credential"`. |
| **Expired Token** | `gh api` returns 401 Unauthorized | Run `gh auth refresh -h github.com`. |
| **Repository-Local Work** | User only wants to change email for 1 repo | Instruct the user to run `cd <repo> && gswitch -l <key>`. |
| **Folder-Specific Separation** | User wants all repos in a folder bound to one account | Run `gswitch bind <dir> <account>` (Optional set-and-forget power feature). |

---

## 📋 Agent Response Summary Template

When finishing setup, output a clean, friendly summary:

```markdown
✅ **git-account-switcher has been successfully installed and configured!**

- **Active Identity:** `<Active Username>` (`<Active Email>`)
- **Configured Profiles:**
  - `gswitch personal` (or `gswitch 1`) -> `<Username 1>`
  - `gswitch work` (or `gswitch 2`) -> `<Username 2>`

**Quick Commands:**
- `gswitch <key>`: Switch globally across your system.
- `gswitch -l <key>`: Switch locally for the current repository only.
- `gswitch`: Open interactive selection menu.
- `git who`: Check active token and Git commit authorship.
- `gswitch help`: View all commands and flags.
```

---

## 📚 Related Documentation

- 🏠 [Main Project README](README.md)
- 🚀 [Complete Workflow Guide](docs/workflow.md)
- ⚙️ [Configuration & Schema Guide](docs/configuration.md)
- ❓ [Troubleshooting & FAQ](docs/troubleshooting.md)
- 🤝 [Contributing & Testing Guide](CONTRIBUTING.md)

