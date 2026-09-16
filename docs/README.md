# Documentation Hub 📚

Welcome to the **`git-account-switcher`** documentation center. Here you will find comprehensive references, architecture breakdowns, practical examples, and troubleshooting guides.

---

## 📑 Documentation Index

| Guide | Description | Target Audience |
| :--- | :--- | :--- |
| 🚀 **[Complete Workflow Guide](workflow.md)** | Step-by-step walkthrough across 6 phases: authentication, credential helper linking, profile setup, daily switching, verification, and maintenance. | Everyone / Getting Started |
| ⚙️ **[Configuration & Schema Guide](configuration.md)** | Complete JSON schema for `accounts.json`, privacy noreply email rules, finding user IDs, 3 real-world multi-account examples, and folder isolation (`includeIf`). | Power Users & Customizers |
| ❓ **[Troubleshooting & FAQ](troubleshooting.md)** | Resolving Windows Credential Manager (GCM) caching conflicts, fixing detached commit authors, handling 403 Forbidden errors, and self-tests. | Problem Solving |
| 🤖 **[Autonomous AI Agent Protocol](../AGENT.md)** | Standard operating instructions for AI coding assistants (Cursor, Copilot, Claude Code, Antigravity) to manage your accounts autonomously. | AI Assistants & Prompting |
| 🤝 **[Contributing & Testing Guide](../CONTRIBUTING.md)** | Local development environment setup, running test suites on Windows and macOS/Linux, and pull request guidelines. | Contributors & Developers |

---

## 🗺️ Architectural Relationship

```
                          ┌────────────────────────┐
                          │   Root: README.md      │
                          │   (Quick Start & Hub)  │
                          └───────────┬────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         ▼                            ▼                            ▼
  ┌───────────────┐           ┌───────────────┐           ┌───────────────────┐
  │  docs/        │           │  AGENT.md     │           │  CONTRIBUTING.md  │
  │  Workflow &   │           │  (Autonomous  │           │  (Testing & Pull  │
  │  Config & FAQ │           │   AI Protocol)│           │   Requests)       │
  └───────────────┘           └───────────────┘           └───────────────────┘
```

---

Back to [Main Project README](../README.md).
