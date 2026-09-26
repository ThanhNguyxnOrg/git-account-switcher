# 1. Credential Helper per Folder and Local Repository

Date: 2026-09-26

## Status

Accepted

## Context

When users organize repositories into dedicated folders (e.g., school projects in `D:\SchoolProjects\` and work projects in `C:\Work\`) using Git's conditional includes (`includeIf.gitdir`), Git automatically switches `user.name` and `user.email`.

However, GitHub CLI's active OAuth token (`gh auth switch -u <user>`) is global. When a user in the school folder runs `git push`, Git invokes the global credential helper (`gh auth git-credential`), which provides the token of whichever account is currently active globally (e.g. `work`). This causes `git push` to fail with HTTP 403 Forbidden or pushes under the wrong account.

Similarly, switching an account locally with `gswitch -l <account>` previously updated `.git/config` for authorship, but relied on the global GitHub CLI token for network operations.

## Decision

We introduce a built-in Git credential helper bridge: `git-account-switcher cred <username>`.

1. **Helper Protocol**:
   When Git runs `git credential fill`, `git-account-switcher cred <username> get` outputs:
   ```text
   username=<username>
   password=<token from gh auth token -u username>
   ```

2. **Folder Bindings (`gswitch bind`)**:
   The generated `.gitconfig-<key>` file is updated from:
   ```gitconfig
   [user]
       name = <name>
       email = <email>
   ```
   to:
   ```gitconfig
   [user]
       name = <name>
       email = <email>
   [credential "https://github.com"]
       username = <username>
       helper = 
       helper = "!git-account-switcher cred <username>"
   [credential "https://gist.github.com"]
       username = <username>
       helper = 
       helper = "!git-account-switcher cred <username>"
   ```

3. **Repository-Local Switch (`gswitch -l`)**:
   `gswitch -l` configures `.git/config` with both authorship (`user.name`, `user.email`) and local credential helper settings (`credential.https://github.com.username` and `credential.https://github.com.helper "!git-account-switcher cred <username>"`).

4. **Global Switch Cleanup**:
   When switching globally (`gswitch <target>`), if the current directory is inside a Git repository that has local overrides (`user.name`, `user.email`, `credential.*`), they are automatically unset so that the global profile applies seamlessly.

## Consequences

### Positive
- Pushing to repositories inside bound folders works out of the box with the correct permissions, regardless of which account is globally active.
- Zero manual `gh auth switch` needed when hopping between work, personal, and school directories.
- Completely compatible with Windows Credential Manager and cross-platform setups.

### Negative
- Requires `gh` CLI to have valid saved tokens for each configured account (which is already a prerequisite for `git-account-switcher`).
