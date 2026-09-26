# CONTEXT.md - Ubiquitous Domain Glossary & System Architecture

This document establishes the official domain terminology, core concepts, and invariant business rules for `git-account-switcher` (`gswitch`).

---

## 🏛️ Domain Concepts & Ubiquitous Language

### 1. Account Profile
A persistent entity stored in `accounts.json` representing a user's GitHub persona.
- **`index`**: 1-based display and shortcut integer (`1`, `2`, `3`). Auto-assigned dynamically upon save.
- **`key`**: Unique slug identifier (e.g. `work`, `school`, `personal`).
- **`aliases`**: Array of shortcut triggers (e.g. `["1", "work", "w", "corp", "octocat"]`). Always includes current index string, key, and GitHub username in lowercase.
- **`label`**: Human-readable display name in CLI lists and menus (e.g. `Personal`, `Enterprise Work`).
- **`username`**: Exact GitHub handle used for authentication (`gh auth switch -u <username>`).
- **`name`**: Git commit author name (`git config user.name "<name>"`).
- **`email`**: Git commit author email (`git config user.email "<email>"`). Supports custom corporate emails or GitHub privacy noreply addresses (`<id>+<username>@users.noreply.github.com`).
- **`description`**: Optional context notes explaining the account profile role.

---

### 2. Dual-Layer Architecture

`git-account-switcher` operates simultaneously across two complementary layers:

```
                            ┌────────────────────────────────────────┐
                            │  git-account-switcher <acc> / gswitch  │
                            └───────────────────┬────────────────────┘
                                                │
                        ┌───────────────────────┴───────────────────────┐
                        ▼                                               ▼
         [1. Authentication Layer (Token)]               [2. Authorship Layer (Git Identity)]
               gh auth switch -u <user>                     git config user.name / user.email
            Controls HTTPS Push/Pull/API                   Controls Commit Log Attribution
```

1. **Authentication Layer (Server Permissions)**:
   - Managed via GitHub CLI OAuth tokens.
   - Determines repository push/pull permissions and GitHub API rights.
   - Scopes:
     - Global: `gh auth switch -u <username>`
     - Folder/Repo Specific: dynamic Git credential helper (`git-account-switcher cred <username>`).
2. **Authorship Layer (Commit Attribution)**:
   - Managed via standard Git configuration (`git config user.name` and `git config user.email`).
   - Stamps Git commit logs with verified identity and noreply addresses to earn contribution graph activity.
   - Scopes:
     - Global: `~/.gitconfig`
     - Local: `.git/config` within a specific repository
     - Folder: `includeIf.gitdir` conditional include referencing a dedicated profile config.

---

### 3. Dynamic Credential Bridge (`gswitch cred <user>`)
A native Git credential helper implemented within `git-account-switcher`.
- **Purpose**: Solves 403 Forbidden push errors in folder-bound (`includeIf`) or repo-local setups.
- **Protocol**: Responds to `git credential fill` with:
  ```text
  username=<user>
  password=<gh auth token -u user>
  ```
- **Invariant**: Allows repositories bound to Account B to push successfully even when Account A is globally active in GitHub CLI.

---

## 🔒 Invariant Business Rules

1. **Index Isolation & Re-Indexing**:
   - Numeric aliases must always match the account's current 1-based `index`.
   - On profile removal or re-ordering, stale numeric aliases (`^\d+$`) must be purged and replaced with the new index.
   - User-defined text aliases (`w`, `personal`, `corp`) must NEVER be discarded during re-indexing or profile updates.
2. **Configuration Preservation in `sync`**:
   - `gswitch sync` must inspect local `accounts.json` before querying GitHub.
   - Existing profiles must retain their custom labels, custom corporate emails, and custom aliases.
   - Only newly detected accounts from `gh auth status` are appended.
3. **No Unintentional Local Override Masking**:
   - When switching globally (`gswitch <target>`), if the current directory is inside a repository with local overrides (`user.name`, `user.email`), `gswitch` clears the local overrides so the global identity takes immediate effect.
4. **Local Isolation (`-l`) & Folder Bindings (`bind`) Integrity**:
   - Any local switch (`gswitch -l`) or folder binding (`gswitch bind`) must configure BOTH the commit authorship layer (`user.*`) AND the credential helper layer (`credential.https://github.com.*`).
