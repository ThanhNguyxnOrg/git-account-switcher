# Troubleshooting & FAQ Guide ❓

This document covers common questions, edge cases, and troubleshooting steps when using **`git-account-switcher` (`gswitch`)**.

---

## 📑 Table of Contents
1. [Windows Credential Manager (GCM) Conflict](#windows-credential-manager-gcm-conflict)
2. [Resolving 403 Forbidden on Git Push](#resolving-403-forbidden-on-git-push)
3. [Fixing Past Commits with Wrong Author](#fixing-past-commits-with-wrong-author)
4. [GitHub Email Privacy: "Push rejected due to email privacy"](#github-email-privacy-push-rejected-due-to-email-privacy)
5. [PowerShell ExecutionPolicy Restriction on Windows](#powershell-executionpolicy-restriction-on-windows)
6. [Switching Back to Default Identity](#switching-back-to-default-identity)
7. [Running Self-Tests](#running-self-tests)

---

## Windows Credential Manager (GCM) Conflict

### The Symptom
You switched accounts with `gswitch work`, but `git push` fails with a permission error or uses your personal credentials.

### Why It Happens
On Windows, Git Credential Manager (GCM) can aggressively cache OAuth credentials in the Windows Credential Store (`Generic Credentials`), overriding GitHub CLI's helper.

### The Fix
Configure Git to prioritize GitHub CLI as the credential helper:

```bash
gh auth setup-git
```

Or configure it manually in your global Git config:
```bash
git config --global credential.helper ""
git config --global --add credential.helper "!gh auth git-credential"
```

If old tokens persist, clear them from the Windows Credential Manager:
1. Press `Win + S` and type **Credential Manager**.
2. Select **Windows Credentials**.
3. Under **Generic Credentials**, find entries for `git:https://github.com` or `GitHub - https://api.github.com`.
4. Click **Remove**.
5. Run `gswitch <your-account>` and retry.

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
1. Inspect your current active accounts:
   ```bash
   git who
   ```
2. Switch to the account that owns or has write permissions on the repository:
   ```bash
   gswitch work
   ```
3. If inside a specific repository, make sure no conflicting local override exists:
   ```bash
   git config --local --unset user.name
   git config --local --unset user.email
   ```
   Or apply the correct account locally:
   ```bash
   gswitch -l work
   ```

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

## Related Documentation

- 🚀 [Complete Workflow Guide](workflow.md)
- ⚙️ [Configuration & Schema Guide](configuration.md)
- 🤖 [Autonomous AI Agent Guide](../AGENT.md)
