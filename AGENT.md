# AI Agent Setup & Operations Guide (Cursor, Claude Code, Copilot, Antigravity, ChatGPT)

> **For AI Assistants:** When a user asks you to set up, configure, add accounts, or troubleshoot `git-account-switcher` on their machine, follow this autonomous protocol. Avoid making the user run manual commands unless interactive browser login is required.

---

## Autonomous Setup Protocol

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

### Step 4: Ask the User for Role Mapping (If multiple accounts found)
Present the discovered accounts clearly to the user:
> *"I detected these GitHub accounts on your system: `<Account1>`, `<Account2>`. Would you like to map them to specific roles (e.g., `personal`, `work`, `school`) so you can switch using simple keywords like `gswitch work`?"*

If the user specifies roles, either use `gswitch add <user> <key>` or edit their local configuration file at:
- **Windows:** `C:\Users\<Username>\.config\git-account-switcher\accounts.json`
- **macOS / Linux:** `~/.config/git-account-switcher/accounts.json`

#### Configuration File Schema:
```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "octocat"],
    "label": "Personal",
    "username": "octocat",
    "name": "Mona Lisa",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Personal account"
  }
]
```

---

### Step 5: Verification & Hand-off
1. Verify configured accounts:
   ```bash
   gswitch list
   ```
2. Confirm active account:
   ```bash
   gswitch status
   ```
3. Test help output:
   ```bash
   gswitch help
   ```
4. Provide the user with a concise summary of how to use it:
   - `gswitch <key>`: Switch globally (e.g. `gswitch work`, `gswitch 1`).
   - `gswitch -l <key>`: Switch locally for the current repository only.
   - `gswitch`: Open interactive menu.
   - `gswitch add <user> <key>`: Add an account.
   - `gswitch remove <key> -f`: Remove an account.
   - `git who`: Git alias to view active identity.
