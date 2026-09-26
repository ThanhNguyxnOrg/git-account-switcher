# Research: Git Credential Resolution, Directory Scoping, and Diagnostics Architecture

**Investigator**: Antigravity Pair Programmer  
**Date**: 2026-09-26  
**Status**: Completed  
**Artifact Target**: `git-account-switcher`  

---

## 1. Executive Summary

This document validates the technical foundation for `git-account-switcher`'s dynamic credential bridge, directory-scoped identities, and self-diagnostic architecture (`doctor`) against high-trust primary documentation from [git-scm.com](https://git-scm.com) and [cli.github.com](https://cli.github.com).

The research confirms:
1. **Dynamic Credential Protocol**: Git's `credential.<context>.helper` cascade reliably isolates HTTPS OAuth tokens per folder and local repository when using URL-scoped helpers (`credential.https://github.com.helper`).
2. **Path Matching Invariants**: Using `gitdir/i:` (case-insensitive matching) with normalized forward slashes (`/`) and trailing slashes (`/`) is mandatory on Windows to guarantee matching across varied drive letters and shell environments.
3. **Transport Protocol Divergence**: Repositories configured with SSH remotes (`git@github.com:...`) completely bypass `credential.helper`. Status reporting and diagnostics must detect SSH URLs and advise switching to HTTPS or configuring SSH aliases.
4. **Offline Token Resolution**: `gh auth token -u <username>` retrieves the exact token without mutating GitHub CLI's active session, making it a safe provider for Git's `get` action.

---

## 2. Git Credential Resolution Hierarchy

### 2.1 The Credential Helper Cascade
*Primary Source: [gitcredentials(7)](https://git-scm.com/docs/gitcredentials), [git-config(1)](https://git-scm.com/docs/git-config)*

Git determines credentials using a multi-tier hierarchy:
1. Exact context match: `credential.<url>.<key>` (e.g. `credential.https://github.com.helper`)
2. Pattern match / wildcard: `credential.<wildcard>.<key>`
3. Global fallbacks: `credential.<key>`

When multiple helpers are defined, Git queries them sequentially until one returns a `password=...` attribute. 

```ini
# Inside .gitconfig-<key> (loaded via includeIf)
[credential "https://github.com"]
    username = ThanhNguyn
    helper = "!git-account-switcher cred ThanhNguyn"
```

### 2.2 Shell Execution and Action Dispatch
*Primary Source: [gitcredentials(7) Custom Helpers](https://git-scm.com/docs/gitcredentials)*

- If the helper string starts with `!` or contains arguments, Git executes it through the system shell (`sh` on POSIX, `cmd.exe`/`powershell` on Windows depending on wrapper).
- Git appends an operation argument to the invocation: `get`, `store`, or `erase`.
- For `get`:
  - Git sends key-value pairs to STDIN ending with an empty newline:
    ```text
    protocol=https
    host=github.com
    username=ThanhNguyn
    
    ```
  - The helper must respond on STDOUT with attributes:
    ```text
    username=ThanhNguyn
    password=gho_xxxx...
    
    ```
  - Any helper exiting with code 0 and returning `password=` satisfies Git and halts downstream helper queries.

---

## 3. Directory-Scoped Configuration (`includeIf`)

### 3.1 Syntax and Windows Path Handling
*Primary Source: [git-config(1) Conditional Includes](https://git-scm.com/docs/git-config#_conditional_includes)*

Git evaluates `includeIf` directives when loading configuration. Key invariants include:

1. **Case-Insensitive Directive (`gitdir/i:`)**:
   - Standard `gitdir:` performs case-sensitive matching.
   - On Windows (NTFS), path casing frequently diverges (e.g., `d:/code/...` vs `D:/Code/...`).
   - Git provides `includeIf "gitdir/i:<path>"` specifically for case-insensitive file systems.
2. **Trailing Slash Requirement**:
   - `gitdir/i:D:/Code/work/` matches any repository whose `.git` directory is located within `D:/Code/work/`.
   - Without a trailing slash, Git only matches if `$GIT_DIR` literally equals that path.
3. **Slash Normalization**:
   - Backslashes `\` are interpreted as escape characters by Git's config parser.
   - All folder bindings must be normalized to forward slashes `/`.

---

## 4. GitHub CLI Authentication Protocol

### 4.1 Token Extraction Behavior
*Primary Source: [gh auth token manual](https://cli.github.com/manual/gh_auth_token)*

```shell
gh auth token -u <username> [-h <hostname>]
```
- Retrieves stored credentials from the OS keyring or `hosts.yml`.
- Does **not** alter the currently active account on the host.
- Returns exit code `0` on success and prints the token to STDOUT.
- Returns non-zero on failure (e.g., token expired or user not logged in).

### 4.2 Non-Blocking Status Checking
*Primary Source: [gh auth status manual](https://cli.github.com/manual/gh_auth_status)*

- `gh auth status --active` checks local configuration without performing remote API calls, preventing latency or offline hangs during CLI startup.

---

## 5. Transport Protocol Divergence: HTTPS vs SSH

### 5.1 The SSH Blind Spot
*Primary Source: [git-push(1)](https://git-scm.com/docs/git-push), [git-remote(1)](https://git-scm.com/docs/git-remote)*

- Git remotes starting with `git@github.com:...` or `ssh://` delegate transport to the OpenSSH client (`ssh.exe` or `/usr/bin/ssh`).
- OpenSSH relies solely on private key pairs and `~/.ssh/config`; it never invokes `credential.helper`.
- Therefore, a repository using an SSH remote will use the default SSH key regardless of what `git-account-switcher` configured in `credential.helper`.

### 5.2 Diagnostic Mitigation
`git-account-switcher doctor` and `gswitch status` must inspect:
```powershell
$remoteUrl = git config --get remote.origin.url
```
If `$remoteUrl -match '^git@github\.com:'`:
- Warn the user: *Remote is using SSH. `gswitch` credential isolation applies to HTTPS URLs.*
- Provide resolution: `git remote set-url origin https://github.com/<org>/<repo>.git`

---

## 6. Commit Signing Architecture (`signingkey`)

### 6.1 GPG and SSH Signing
*Primary Source: [git-config(1) user.signingKey](https://git-scm.com/docs/git-config)*

Git supports commit signing via OpenPGP and SSH keys:
- `user.signingkey`: Specifies GPG key ID (e.g. `3AA5C34371567BD2`) or SSH public key (`ssh-ed25519 AAAAC3...` or path `~/.ssh/id_ed25519.pub`).
- `gpg.format`: Can be `openpgp` (default), `x509`, or `ssh`.
- `commit.gpgsign = true`: Automatically signs all commits.

When `signingkey` is configured per-account in `accounts.json`, `git-account-switcher` can automatically inject signing preferences into `.gitconfig-<key>` or the local repository.

---

## 7. Conclusions & Implementation Plan

| Feature | Primary Source Rationale | Implementation Rule |
| :--- | :--- | :--- |
| **`cred` Helper** | `gitcredentials(7)` `get` protocol | Respond to `get` with `username` + `password`, ignore `store`/`erase` |
| **`includeIf` Bindings** | `git-config(1)` conditional includes | Use `includeIf "gitdir/i:<normalized_path>/"` with forward slashes |
| **`gswitch doctor`** | Diagnostics & SSH blind spot | Check git, gh, auth tokens, credential helper cascade, and flag SSH remotes |
| **Signing Support** | `git-config(1)` `user.signingKey` | Support optional `signingkey` in `accounts.json` profiles |
