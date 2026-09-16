#!/usr/bin/env bash
# ==============================================================================
# git-account-switcher Uninstaller for macOS and Linux
# ==============================================================================
set -e

echo ""
echo "Uninstalling git-account-switcher..."

rm -f "$HOME/.local/bin/git-account-switcher" "$HOME/.local/bin/gswitch" "$HOME/.local/bin/switch-git"
echo "[OK] Removed binaries from $HOME/.local/bin"

git config --global --unset alias.who 2>/dev/null || true
git config --global --unset alias.switch-acc 2>/dev/null || true
echo "[OK] Removed git aliases"

if [[ "$1" == "--purge" ]]; then
    rm -rf "$HOME/.config/git-account-switcher" "$HOME/.config/switch-git"
    echo "[OK] Removed configuration directories"
fi

echo "Uninstallation completed."
echo ""
