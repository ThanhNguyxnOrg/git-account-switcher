# Troubleshooting & FAQ Guide ❓

This document covers common questions, edge cases, and troubleshooting steps when using **`git-account-switcher` (`gswitch`)**.

---

## 📑 Table of Contents
1. [First Step: Run System Diagnostics (`gswitch doctor`)](#first-step-run-system-diagnostics-gswitch-doctor)
2. [Windows Credential Manager (GCM) Conflict](#windows-credential-manager-gcm-conflict)
3. [SSH Remote Bypass: Why Push Fails Despite Switching Accounts](#ssh-remote-bypass-why-push-fails-despite-switching-accounts)
4. [Resolving 403 Forbidden on Git Push](#resolving-403-forbidden-on-git-push)
5. [Fixing Past Commits with Wrong Author](#fixing-past-commits-with-wrong-author)
6. [GitHub Email Privacy: "Push rejected due to email privacy"](#github-email-privacy-push-rejected-due-to-email-privacy)
7. [PowerShell ExecutionPolicy Restriction on Windows](#powershell-executionpolicy-restriction-on-windows)
8. [Switching Back to Default Identity](#switching-back-to-default-identity)
9. [Running Self-Tests](#running-self-tests)

---

## First Step: Run System Diagnostics (`gswitch doctor`)

Whenever you encounter unexpected behavior with switching, permissions, or git push, run the built-in self-diagnostics first:

```bash
gswitch doctor
# Shorthand:
gswitch check
```

`gswitch doctor` executes 5 automated health checks:
1. **Git Installation & Minimum Version:** Verifies Git >= 2.13.
2. **GitHub CLI (`gh`) & Authentication:** Verifies `gh` CLI version and logged-in accounts.
3. **Token Health & Account Verification:** Validates your OAuth tokens against GitHub's API (`gh api user`).
4. **Folder Binding Integrity:** Checks `includeIf` rules and generated profile configs.
5. **Active Repository Context:** If inside a Git repository, inspects remote URLs (detecting SSH bypass), local author overrides, and repository-specific credential helpers.

---

## Windows Credential Manager (GCM) Conflict

### The Symptom
You switched accounts with `gswitch work`, but `git push` fails with a permission error or uses your personal credentials.

### Why It Happens
On Windows, Git Credential Manager (GCM) can aggressively cache OAuth credentials in the Windows Credential Store (`Generic Credentials`), overriding GitHub CLI's helper.

### The Solution: Dynamic Credential Bridge
`git-account-switcher` includes a built-in dynamic credential bridge:
- When using **Folder Bindings** (`gswitch bind`), each bound directory automatically injects:
  ```text
  credential.https://github.com.helper = !git-account-switcher cred <username>
  ```
- When using **Local Switching** (`gswitch -l <account>`), the same helper is written directly to `.git/config`.

This instructs Git to request the token directly from GitHub CLI for that specific username, completely bypassing GCM token poisoning!

If you switch globally without folder bindings or `-l`, configure Git to ask GitHub CLI:

```bash
gh auth setup-git
```

If old tokens persist in Windows Credential Store:
1. Press `Win + S` and type **Credential Manager**.
2. Select **Windows Credentials**.
3. Under **Generic Credentials**, find entries for `git:https://github.com` or `GitHub - https://api.github.com`.
4. Click **Remove**.
5. Run `gswitch <your-account>` and retry.

---

## SSH Remote Bypass: Why Push Fails Despite Switching Accounts

### The Symptom
You switched to Account B via `gswitch`, but `git push` fails with:
```text
ERROR: Permission to org/repo.git denied to user-a.
fatal: Could not read from remote repository.
```

### Why It Happens
Your repository remote is configured with an **SSH URL**:
```text
origin  git@github.com:org/repo.git (push)
```
Git credential helpers and GitHub CLI OAuth tokens **only apply to HTTPS remotes**. When using SSH, Git uses your local SSH keys (`~/.ssh/id_rsa` or `~/.ssh/id_ed25519`), completely bypassing `gswitch` and GitHub CLI authentication!

### The Fix: Switch Remote to HTTPS
Convert your repository remote to HTTPS so `gswitch`'s dynamic token bridge manages authentication:

```bash
# 1. Switch remote URL to HTTPS:
git remote set-url origin https://github.com/org/repo.git

# 2. Verify with gswitch doctor:
gswitch doctor

# 3. Push seamlessly:
git push
```

---

## Resolving 403 Forbidden on Git Push

### The Symptom
```text
remote: Permission to org/repo.git denied to user-personal.
fatal: unable to access 'https://github.com/org/repo.git/': The requested URL returned error: 403
```

### Root Cause
Your active GitHub token belongs to Account A, but the repository belongs to Account B or an organization requiring Account B.

### Fix
1. Run diagnostics to spot the mismatch:
   ```bash
   gswitch doctor
   ```
2. Switch to the account that owns or has write permissions on the repository:
   ```bash
   gswitch work
   ```
3. To permanently isolate push permissions for this specific repository without touching global settings:
   ```bash
   gswitch -l work
   ```
   *This configures both local Git commit authorship (`user.name`/`user.email`) and isolates push authentication via `credential.https://github.com.helper "!git-account-switcher cred work"` in `.git/config`.*

---

## Fixing Past Commits with Wrong Author

### Fixing the Most Recent Commit (Unpushed)
If you just committed code under the wrong identity before pushing:

```bash
# 1. Switch to the desired identity:
gswitch work

# 2. Amend the commit author to match the active Git identity:
git commit --amend --reset-author --no-edit
```

### Fixing Multiple Past Commits
If you have multiple unpushed commits with the wrong author:

```bash
git rebase -i HEAD~3 --exec "git commit --amend --reset-author --no-edit"
```

---

## GitHub Email Privacy: "Push rejected due to email privacy"

### The Symptom
```text
remote: error: GH007: Your push would publish a private email address.
```

### Why It Happens
You have **"Block command line pushes that expose my email"** enabled in your GitHub Account Settings under **Emails**, and your Git commit was stamped with your public or unverified email.

### The Fix
Use your official GitHub privacy noreply email:
```
<ID>+<USERNAME>@users.noreply.github.com
```

You can automatically re-sync all accounts with proper noreply emails by running:
```bash
gswitch sync
```

Or update a single profile:
```bash
gswitch add <username> <key> "<name>" "<ID>+<username>@users.noreply.github.com"
```

---

## PowerShell ExecutionPolicy Restriction on Windows

### The Symptom
```text
File ...\git-account-switcher.ps1 cannot be loaded because running scripts is disabled on this system.
```

### The Fix
PowerShell by default blocks unsigned external scripts on client versions of Windows. Set the policy to `RemoteSigned` for your current user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

Alternatively, the wrapper `gswitch.cmd` and installer automatically run with `-ExecutionPolicy Bypass`.

---

## Switching Back to Default Identity

To return to your default or personal account at any time:

```bash
gswitch personal
# Or by number:
gswitch 1
```

To remove repository-local overrides in the current folder:
```bash
git config --local --unset user.name
git config --local --unset user.email
```

---

## Running Self-Tests

You can verify that your `git-account-switcher` installation and JSON parsing are operating correctly without touching your personal accounts:

**Windows (PowerShell):**
```powershell
powershell.exe -File .\tests\test-all.ps1
```

**macOS / Linux (Bash):**
```bash
./tests/test-all.sh
```

All tests execute in an isolated sandbox temporary directory (`$sandboxConfig`) to ensure zero impact on your production profiles.

---

## Folder Binding Doesn't Seem to Apply (`includeIf` Gotchas)

### 1. Repository-Local `.git/config` Overrides
Git evaluates configuration in the following order:
1. Local repository config (`.git/config` or `gswitch -l`)
2. Global configuration (`~/.gitconfig`, including `includeIf` rules)

If a repository inside a bound directory previously had `user.name` or `user.email` set locally, Git will **ignore the folder binding** and use the local value.
- **Diagnosis:** Run `gswitch status` or `gswitch doctor` inside the repository. It will report `[WARNING] Folder Binding active is SHADOWED by this local override!`.
- **Solution:** Clear the local override so the repository inherits the folder binding:
  ```bash
  git config --local --unset-all user.name
  git config --local --unset-all user.email
  ```
  *(Note: Running `gswitch bind` automatically detects existing repositories with local overrides and offers to clear them for you).*

### 2. GitHub CLI (`gh`) Remains Global
Git's `includeIf` operates strictly on Git commit authorship and Git HTTPS push/pull credentials. Standalone GitHub CLI commands (`gh pr create`, `gh issue list`, `gh repo view`) do not read Git configuration files.
- If you need to run `gh` CLI commands under the folder's account, run `gswitch <account>` to switch the active GitHub CLI session.

### 3. Cloning Private Repositories into a Bound Folder
`includeIf.gitdir` requires an existing `.git` directory to match the folder pattern. When running `git clone` from inside the bound directory, Git has not yet created the `.git` directory during credential resolution, so it uses the global account token.
- **Solution:** If cloning a private repository belonging to the bound account, either run `gswitch <account>` first, or include the username in the clone URL:
  ```bash
  git clone https://<username>@github.com/<org>/<repo>.git
  ```

---

## Related Documentation

- 🚀 [Complete Workflow Guide](workflow.md)
- ⚙️ [Configuration & Schema Guide](configuration.md)
- 🤖 [Autonomous AI Agent Guide](../AGENT.md)

