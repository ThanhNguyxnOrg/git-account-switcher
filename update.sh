#!/usr/bin/env bash
# ==============================================================================
# git-account-switcher Updater for macOS and Linux
# ==============================================================================
set -e

echo ""
echo "============================================================"
echo " git-account-switcher (gswitch) Updater (macOS & Linux)"
echo " Fast Multi-Account GitHub & Git Identity Switcher"
echo "============================================================"
echo ""

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

RAW_BASE="https://raw.githubusercontent.com/ThanhNguyxnOrg/git-account-switcher/master"
IS_LOCAL=false
if [[ -n "${BASH_SOURCE[0]}" && -d "$(dirname "${BASH_SOURCE[0]}")/bin" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    IS_LOCAL=true
fi

echo "Updating binaries in $BIN_DIR..."
if [[ "$IS_LOCAL" == "true" ]]; then
    cp "$SCRIPT_DIR/bin/git-account-switcher" "$BIN_DIR/git-account-switcher"
    cp "$SCRIPT_DIR/bin/gswitch" "$BIN_DIR/gswitch"
    cp "$SCRIPT_DIR/bin/switch-git" "$BIN_DIR/switch-git"
    echo "  [OK] Updated executables from local repository."
else
    curl -fsSL "$RAW_BASE/bin/git-account-switcher" -o "$BIN_DIR/git-account-switcher"
    curl -fsSL "$RAW_BASE/bin/gswitch" -o "$BIN_DIR/gswitch"
    curl -fsSL "$RAW_BASE/bin/switch-git" -o "$BIN_DIR/switch-git"
    echo "  [OK] Downloaded latest executables from repository."
fi

chmod +x "$BIN_DIR/git-account-switcher" "$BIN_DIR/gswitch" "$BIN_DIR/switch-git"

# Re-assert Git aliases
git config --global alias.who "!git-account-switcher status" 2>/dev/null || true
git config --global alias.switch-acc "!git-account-switcher" 2>/dev/null || true
echo "  [OK] Configured Git aliases (git who, git switch-acc)."

echo ""
echo "============================================================"
echo " git-account-switcher has been updated successfully!"
echo " All existing profiles and folder bindings were preserved."
echo "============================================================"
echo ""
