#!/usr/bin/env bash
# ==============================================================================
# switch-git Uninstaller for macOS and Linux
# ==============================================================================
set -e

echo ""
echo "Uninstalling switch-git..."

rm -f "$HOME/.local/bin/switch-git"
echo "[OK] Removed $HOME/.local/bin/switch-git"

git config --global --unset alias.who 2>/dev/null || true
git config --global --unset alias.switch-acc 2>/dev/null || true
echo "[OK] Removed git aliases"

if [[ "$1" == "--purge" ]]; then
    rm -rf "$HOME/.config/switch-git"
    echo "[OK] Removed configuration directory $HOME/.config/switch-git"
fi

echo "Uninstallation completed."
echo ""
