# AI Agent Setup Guide (Cursor, Claude Code, Copilot, Antigravity, ChatGPT)

> **For AI Assistants:** When a user asks you to set up or configure `git-account-switcher` on their machine, follow this step-by-step autonomous workflow. Do not make the user run manual commands unless permission is required.

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
   *(If `gh` is missing, offer or proceed to install it: `winget install --id GitHub.cli` on Windows, `brew install gh` on macOS, or package manager on Linux).*
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

### Step 3: Run Auto-Discovery
Run `gswitch sync` to automatically scan `gh auth status`, query GitHub's user API, retrieve user IDs, and calculate private noreply emails:
```bash
gswitch sync
```

---

### Step 4: Ask the User for Role Mapping (If multiple accounts found)
Present the discovered accounts clearly to the user and ask:
> *"I detected these GitHub accounts on your system: `<Account1>`, `<Account2>`. Would you like to map them to specific roles (e.g., `personal`, `work`, `school`) so you can switch using simple keywords like `gswitch work`?"*

If the user specifies roles, update their local configuration file at:
- **Windows:** `C:\Users\<Username>\.config\git-account-switcher\accounts.json`
- **macOS / Linux:** `~/.config/git-account-switcher/accounts.json`

Ensure the JSON entry has the desired `key`, `label`, and `aliases`.

---

### Step 5: Verification & Hand-off
1. Verify the setup by running:
   ```bash
   gswitch list
   ```
2. Confirm the active account:
   ```bash
   gswitch status
   ```
3. Provide the user with a concise summary of how to use it:
   - `gswitch <key>`: Switch globally.
   - `gswitch -l <key>`: Switch locally for the current repository only.
   - `gswitch`: Interactive menu.
   - `git who`: Git alias to view active identity.
