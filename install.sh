#!/usr/bin/env bash
# ==============================================================================
# switch-git Installer for macOS and Linux
# ==============================================================================
set -e

echo ""
echo "============================================================"
echo " switch-git Installer (macOS & Linux)"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/bin/switch-git" "$BIN_DIR/switch-git"
chmod +x "$BIN_DIR/switch-git"
echo "  [OK] Installed switch-git -> $BIN_DIR/switch-git"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "  [INFO] $BIN_DIR is not in your current PATH."
    echo "         Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "         export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 3. Setup configuration directory
echo "[3/5] Setting up accounts configuration..."
CONFIG_DIR="$HOME/.config/switch-git"
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/accounts.json" ]]; then
    if [[ -f "$SCRIPT_DIR/config/accounts.json" ]]; then
        cp "$SCRIPT_DIR/config/accounts.json" "$CONFIG_DIR/accounts.json"
        echo "  [OK] Deployed accounts.json -> $CONFIG_DIR/accounts.json"
    elif [[ -f "$SCRIPT_DIR/config/accounts.example.json" ]]; then
        cp "$SCRIPT_DIR/config/accounts.example.json" "$CONFIG_DIR/accounts.json"
        echo "  [OK] Deployed template accounts.json -> $CONFIG_DIR/accounts.json"
    fi
else
    echo "  [INFO] Existing configuration found at $CONFIG_DIR/accounts.json"
fi

# 4. Configure Git credential helper for GitHub CLI
echo "[4/5] Configuring Git credential helper for GitHub CLI..."
git config --global --unset-all credential.https://github.com.helper 2>/dev/null || true
git config --global --add credential.https://github.com.helper '!gh auth git-credential'
git config --global --add credential.https://gist.github.com.helper '!gh auth git-credential'
echo "  [OK] Git credential helper linked to GitHub CLI (gh)."

# 5. Configure Git aliases
echo "[5/5] Setting up Git aliases..."
git config --global alias.who '!switch-git status'
git config --global alias.switch-acc '!switch-git'
echo "  [OK] Added git alias: git who"
echo "  [OK] Added git alias: git switch-acc"

echo ""
echo "============================================================"
echo " Installation Complete!"
echo "============================================================"
echo "Run from any terminal:"
echo "  switch-git              # Interactive selection"
echo "  switch-git <account>    # Quick switch"
echo "  switch-git status       # Check current identity"
echo "  git who                 # Git alias for status"
echo "  git switch-acc <acc>    # Git alias for switching"
echo ""
