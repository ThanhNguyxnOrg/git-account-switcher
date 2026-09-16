# Configuration File Guide (`accounts.json`) 📋

`git-account-switcher` stores your account profiles in a lightweight, transparent JSON file.

---

## 📍 File Locations

The configuration file is stored in standard user configuration directories:

| Operating System | Default Path |
| :--- | :--- |
| **Windows** | `C:\Users\<Username>\.config\git-account-switcher\accounts.json` |
| **macOS** | `/Users/<username>/.config/git-account-switcher/accounts.json` |
| **Linux** | `~/.config/git-account-switcher/accounts.json` |

> [!TIP]
> You can override this location anytime by setting the `GIT_ACCOUNT_SWITCHER_CONFIG` environment variable.

To open and edit your configuration in your default editor:
```bash
gswitch edit
```

---

## 📄 JSON Schema Specification

```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "octocat", "p", "main"],
    "label": "Personal",
    "username": "octocat",
    "name": "Mona Lisa",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Personal open source & side projects"
  }
]
```

### Field Reference

| Field | Type | Description |
| :--- | :--- | :--- |
| `index` | Integer | Auto-assigned display sequence (1, 2, 3...). Used for quick numeric switching (`gswitch 1`). |
| `key` | String | Unique slug identifier (e.g. `work`, `personal`, `school`). |
| `aliases` | Array[String] | Array of shortcuts, abbreviations, and nicknames that trigger switching to this profile. |
| `label` | String | Human-readable title displayed in the interactive selection menu. |
| `username` | String | Exact GitHub handle used for authentication (`gh auth switch -u <username>`). |
| `name` | String | Git author name stamped on commits (`git config user.name "<name>"`). |
| `email` | String | Git author email stamped on commits (`git config user.email "<email>"`). |
| `description` | String | Optional note explaining the role of this account profile. |

---

## 🔒 Privacy-Protected Noreply Emails

GitHub allows you to keep your personal email private by using a special `noreply` address. Commits using this email will still be associated with your profile and earn contribution green squares, but your real email won't be exposed in public Git commit logs.

### Format
```
<USER_ID>+<USERNAME>@users.noreply.github.com
```

### How to Find Your Numerical GitHub User ID

**Option 1: Using GitHub CLI (Instant)**
```bash
gh api user --jq '.id'
```

**Option 2: Using GitHub Public API in Browser**
Open `https://api.github.com/users/<your-username>` and look for the `"id"` field.

> [!TIP]
> Running `gswitch sync` automatically resolves your User ID and constructs this noreply email for every account without any manual lookup!

---

## 💡 Real-World Configuration Examples

### Example 1: Freelancer / Independent Contractor
*Managing personal projects alongside multiple distinct client repositories.*

```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "p", "main"],
    "label": "Personal",
    "username": "dev-freelancer",
    "name": "Alex Dev",
    "email": "12345678+dev-freelancer@users.noreply.github.com",
    "description": "Alex's personal open-source projects"
  },
  {
    "index": 2,
    "key": "fintech",
    "aliases": ["2", "fintech", "client-a", "bank"],
    "label": "FinTech Corp",
    "username": "alex-fintech",
    "name": "Alex Dev (Consultant)",
    "email": "alex.consultant@fintechcorp.example.com",
    "description": "Client A: Financial banking portal"
  },
  {
    "index": 3,
    "key": "health",
    "aliases": ["3", "health", "client-b"],
    "label": "HealthTech",
    "username": "alex-health",
    "name": "Alex Dev",
    "email": "alex@healthtech.example.org",
    "description": "Client B: Telemedicine mobile backend"
  }
]
```

---

### Example 2: Corporate Developer & Open Source Maintainer
*Separating internal enterprise code from public open-source contributions.*

```json
[
  {
    "index": 1,
    "key": "work",
    "aliases": ["1", "work", "corp", "w", "job"],
    "label": "Enterprise Work",
    "username": "octocat-enterprise",
    "name": "Mona Lisa",
    "email": "mona.lisa@enterprise-cloud.com",
    "description": "Official company repos & internal tooling"
  },
  {
    "index": 2,
    "key": "oss",
    "aliases": ["2", "oss", "personal", "open"],
    "label": "Open Source",
    "username": "octocat",
    "name": "Mona Lisa Octocat",
    "email": "583231+octocat@users.noreply.github.com",
    "description": "Public packages, crates, and libraries"
  }
]
```

---

### Example 3: Student & Research Lab
*Separating university coursework, research papers, and hobby projects.*

```json
[
  {
    "index": 1,
    "key": "personal",
    "aliases": ["1", "personal", "me"],
    "label": "Personal",
    "username": "student-dev",
    "name": "Jordan Lee",
    "email": "98765432+student-dev@users.noreply.github.com",
    "description": "Personal side projects & portfolio"
  },
  {
    "index": 2,
    "key": "school",
    "aliases": ["2", "school", "cs", "uni"],
    "label": "University",
    "username": "jlee-university",
    "name": "Jordan Lee",
    "email": "jordan.lee@cs.university.edu",
    "description": "CS homework assignments & team labs"
  },
  {
    "index": 3,
    "key": "lab",
    "aliases": ["3", "lab", "research", "ai"],
    "label": "Robotics Lab",
    "username": "jlee-robotics",
    "name": "Jordan Lee (Researcher)",
    "email": "jlee@robotics-institute.org",
    "description": "Autonomous vehicle research codebase"
  }
]
```

---

## 📂 Automatic Folder Isolation (`gswitch bind` / `includeIf`)

If you want all Git repositories inside a specific folder (e.g. `D:\Code\Work` or `~/work`) to **permanently and automatically commit as a specific account**, `gswitch` provides built-in automated folder binding using Git's native `includeIf` mechanism:

### 1. Bind a Folder to an Account
```bash
# Windows
gswitch bind D:\Code\Work work

# macOS / Linux
gswitch bind ~/work work
```

*What happens under the hood:*  
`gswitch` automatically creates `~/.gitconfig-<key>` with the account's name and noreply email, then registers a case-insensitive `[includeIf "gitdir/i:<folder>/**"]` entry inside your global `~/.gitconfig`. Every repository inside that folder will instantly commit under that identity without typing any switch command!

### 2. Inspect All Active Folder Bindings
```bash
gswitch bindings
```

### 3. Remove a Folder Binding
```bash
gswitch unbind D:\Code\Work
```

> **Why you still use `gswitch` for GitHub CLI:**  
> While folder binding automatically locks Git's commit authorship inside that folder, running `gswitch <key>` or `gswitch` synchronizes your active GitHub CLI push token (`gh auth switch`) when pushing over HTTPS, submitting PRs, or managing issues.

---

## Related Documentation

- 🚀 [Complete Workflow Guide](workflow.md)
- ❓ [Troubleshooting & FAQ](troubleshooting.md)
- 🤖 [Autonomous AI Agent Guide](../AGENT.md)
