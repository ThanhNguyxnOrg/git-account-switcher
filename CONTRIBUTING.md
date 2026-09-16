# Contributing to git-account-switcher 🤝

Thank you for your interest in contributing to `git-account-switcher`! We welcome contributions, bug reports, documentation enhancements, and feature suggestions.

---

## 🎯 Project Philosophy
1. **Ultra Lightweight & Zero Dependency:** The switcher relies exclusively on Git and the official GitHub CLI (`gh`). We avoid bulky runtimes (Node.js, Python packages, Rust binaries) so users can install and switch instantly in milliseconds.
2. **True Cross-Platform Equality:** Every feature available on Windows (PowerShell) must have a native POSIX Bash counterpart for macOS and Linux.
3. **Strict Privacy & Zero Secrets:** The repository must never contain hardcoded personal identities, private email addresses, or secrets. All examples use generic mocks (`octocat`, `mona-corp`, `student-mona`).
4. **100% English:** All documentation, comments, CLI output, and commit messages must be written in clear English.

---

## 📂 Repository Structure

```
git-account-switcher/
├── bin/
│   ├── git-account-switcher.ps1   # Primary PowerShell implementation (Windows)
│   ├── git-account-switcher       # Primary POSIX Bash implementation (macOS / Linux)
│   ├── gswitch.cmd                # Primary short alias wrapper for Windows
│   ├── gswitch                    # Primary short alias wrapper for macOS / Linux
│   ├── switch-git.ps1             # Backward-compatible PowerShell alias wrapper
│   ├── switch-git.cmd             # Windows Command Prompt (CMD) wrapper
│   └── switch-git                 # Backward-compatible Bash alias wrapper
├── config/
│   ├── accounts.example.json      # Generic 3-account sample configuration
│   └── accounts.json              # Default template copied on first installation
├── docs/
│   ├── workflow.md                # 6-Phase Complete Workflow Guide
│   ├── configuration.md           # Schema specification & real-world examples
│   └── troubleshooting.md         # FAQ & troubleshooting solutions
├── tests/
│   ├── test-all.ps1               # Automated test suite for PowerShell
│   └── test-all.sh                # Automated test suite for POSIX Bash
├── install.ps1                    # Windows 1-line & local installer
├── install.sh                     # macOS & Linux 1-line & local installer
├── uninstall.ps1                  # Windows uninstaller (supports -PurgeConfig)
├── uninstall.sh                   # Unix uninstaller (supports --purge)
├── AGENT.md                       # AI Agent autonomous execution protocol
├── CONTRIBUTING.md                # Development & contribution guide
├── LICENSE                        # MIT License
└── README.md                      # Main project landing page
```

---

## 💻 Local Development Setup

### 1. Clone the Repository
```bash
git clone https://github.com/ThanhNguyxnOrg/git-account-switcher.git
cd git-account-switcher
```

### 2. Isolated Testing Environment
During local development, you do **not** want your tests to modify your actual personal `accounts.json`.  
Both scripts support the `GIT_ACCOUNT_SWITCHER_CONFIG` environment variable to sandbox configuration:

**PowerShell (Windows):**
```powershell
# Point to a temporary local configuration
$env:GIT_ACCOUNT_SWITCHER_CONFIG = "$PWD\tests\sandbox.json"

# Test your changes directly
.\bin\git-account-switcher.ps1 list
.\bin\git-account-switcher.ps1 add octocat work
.\bin\git-account-switcher.ps1 remove work -f

# Clean up
Remove-Item env:GIT_ACCOUNT_SWITCHER_CONFIG
Remove-Item .\tests\sandbox.json -ErrorAction SilentlyContinue
```

**Bash (macOS / Linux):**
```bash
# Point to a temporary sandbox
export GIT_ACCOUNT_SWITCHER_CONFIG="$PWD/tests/sandbox.json"

# Test your changes directly
./bin/git-account-switcher list
./bin/git-account-switcher add octocat work
./bin/git-account-switcher remove work -f

# Clean up
unset GIT_ACCOUNT_SWITCHER_CONFIG
rm -f ./tests/sandbox.json
```

---

## 🧪 Running Automated Tests

Before submitting any Pull Request, ensure that all automated tests pass with 0 failures:

### On Windows:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test-all.ps1
```

### On macOS / Linux / Git Bash:
```bash
bash ./tests/test-all.sh
```

The test suites verify:
- ✅ Script syntax validation (`ParseFile` / `bash -n`)
- ✅ Help flag execution and structure
- ✅ Empty configuration handling
- ✅ Non-interactive profile creation (`add`)
- ✅ Multi-profile addition and index assignment
- ✅ In-place profile updates without duplicate entries
- ✅ Shortcut alias assignment (`alias`) and removal (`unalias`)
- ✅ Profile removal (`remove -f`) and re-indexing

---

## 📝 Pull Request Guidelines

1. **Create a Feature Branch:**
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. **Follow Conventional Commits:**
   - `feat: add support for custom SSH key per profile`
   - `fix: resolve JSON serialization for single account profile`
   - `docs: improve complete workflow documentation`
   - `test: add unit test for remove confirmation bypass`
3. **Keep Code Clean:**
   - Ensure variables and functions are descriptively named.
   - Verify that your changes run identically on Windows PowerShell 5.1+, PowerShell 7+, and POSIX Bash.
4. **Submit Your PR:**
   - Push your branch to your fork and submit a PR to `master`.
   - Describe what the PR accomplishes and mention any relevant issues.

---

## 📚 Related Documentation

- 🏠 [Main Project README](README.md)
- 🚀 [Complete Workflow Guide](docs/workflow.md)
- ⚙️ [Configuration & Schema Guide](docs/configuration.md)
- ❓ [Troubleshooting & FAQ](docs/troubleshooting.md)
- 🤖 [Autonomous AI Agent Protocol](AGENT.md)

Thank you for helping make `git-account-switcher` great! 🚀
