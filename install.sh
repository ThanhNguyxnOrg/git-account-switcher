#!/usr/bin/env bash
# ==============================================================================
# git-account-switcher (gswitch) Installer for macOS and Linux
# ==============================================================================
set -e

echo ""
echo "============================================================"
echo " git-account-switcher (gswitch) Installer (macOS & Linux)"
echo " Fast Multi-Account GitHub & Git Identity Switcher"
echo "============================================================"
echo ""

# 1. Dependency checks
echo "[1/5] Checking prerequisites..."
if ! command -v git >/dev/null 2>&1; then
    echo "  [ERROR] Git is not installed." >&2
    exit 1
fi
echo "  [OK] Git is available."

if ! command -v gh >/dev/null 2>&1; then
    echo "  [ERROR] GitHub CLI (gh) is not installed." >&2
    echo "          Install via: brew install gh (macOS) or package manager (Linux)" >&2
    exit 1
fi
echo "  [OK] GitHub CLI (gh) is available."

# 2. Target bin directory
BIN_DIR="$HOME/.local/bin"
echo "[2/5] Preparing installation directory ($BIN_DIR)..."
mkdir -p "$BIN_DIR"

RAW_BASE="https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master"
IS_LOCAL=false
if [[ -n "${BASH_SOURCE[0]}" && -d "$(dirname "${BASH_SOURCE[0]}")/bin" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    IS_LOCAL=true
fi

if [[ "$IS_LOCAL" == "true" ]]; then
    cp "$SCRIPT_DIR/bin/git-account-switcher" "$BIN_DIR/git-account-switcher"
    cp "$SCRIPT_DIR/bin/gswitch" "$BIN_DIR/gswitch"
    cp "$SCRIPT_DIR/bin/switch-git" "$BIN_DIR/switch-git"
else
    echo "  Downloading binaries from GitHub repository..."
    curl -fsSL "$RAW_BASE/bin/git-account-switcher" -o "$BIN_DIR/git-account-switcher"
    curl -fsSL "$RAW_BASE/bin/gswitch" -o "$BIN_DIR/gswitch"
    curl -fsSL "$RAW_BASE/bin/switch-git" -o "$BIN_DIR/switch-git"
fi

chmod +x "$BIN_DIR/git-account-switcher" "$BIN_DIR/gswitch" "$BIN_DIR/switch-git"
echo "  [OK] Installed executables -> $BIN_DIR (git-account-switcher, gswitch, switch-git)"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "  [INFO] $BIN_DIR is not in your current PATH."
    echo "         Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "         export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 3. Setup configuration directory
echo "[3/5] Setting up accounts configuration..."
CONFIG_DIR="$HOME/.config/git-account-switcher"
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/accounts.json" ]]; then
    if gh auth status 2>&1 | grep -q 'Logged in to .* account'; then
        echo "  Detected active GitHub CLI accounts! Running auto-discovery..."
        "$BIN_DIR/gswitch" sync || true
    elif [[ "$IS_LOCAL" == "true" && -f "$SCRIPT_DIR/config/accounts.example.json" ]]; then
        cp "$SCRIPT_DIR/config/accounts.example.json" "$CONFIG_DIR/accounts.json"
        echo "  [OK] Deployed template accounts.json -> $CONFIG_DIR/accounts.json"
    else
        echo "  Deploying default configuration template..."
        curl -fsSL "$RAW_BASE/config/accounts.example.json" -o "$CONFIG_DIR/accounts.json" 2>/dev/null || echo "[]" > "$CONFIG_DIR/accounts.json"
        echo "  [OK] Deployed template accounts.json -> $CONFIG_DIR/accounts.json"
    fi
else
    echo "  [INFO] Existing configuration preserved at $CONFIG_DIR/accounts.json"
fi

# 4. Configure Git credential helper for GitHub CLI
echo "[4/5] Configuring Git credential helper for GitHub CLI..."
git config --global --unset-all credential.https://github.com.helper 2>/dev/null || true
git config --global --add credential.https://github.com.helper '!gh auth git-credential'
git config --global --add credential.https://gist.github.com.helper '!gh auth git-credential'
echo "  [OK] Git credential helper linked to GitHub CLI (gh)."

# 5. Configure Git aliases
echo "[5/5] Setting up Git aliases..."
git config --global alias.who '!git-account-switcher status'
git config --global alias.switch-acc '!git-account-switcher'
echo "  [OK] Added git alias: git who"
echo "  [OK] Added git alias: git switch-acc"

echo ""
echo "============================================================"
echo " Installation Complete!"
echo "============================================================"
echo "Run from any terminal:"
echo "  gswitch <account>       # Fast switch"
echo "  gswitch -l <account>    # Local repo switch"
echo "  gswitch sync            # Auto-import logged-in accounts"
echo "  gswitch list            # View configured accounts"
echo "  gswitch status          # Check current identity"
echo ""
