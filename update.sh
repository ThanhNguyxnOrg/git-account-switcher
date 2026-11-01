#!/usr/bin/env bash
# ==============================================================================
# git-account-switcher Updater for macOS and Linux
# Delegates to the installed/local CLI so updates use the verified release path.
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSWITCH_HOME="${GIT_ACCOUNT_SWITCHER_HOME:-$HOME}"
LOCAL_BIN="$SCRIPT_DIR/bin/git-account-switcher"
INSTALLED_BIN="$GSWITCH_HOME/.local/bin/git-account-switcher"

echo ""
echo "============================================================"
echo " git-account-switcher (gswitch) Updater (macOS & Linux)"
echo " Fast Multi-Account GitHub & Git Identity Switcher"
echo "============================================================"
echo ""

if [[ -x "$LOCAL_BIN" ]]; then
    exec "$LOCAL_BIN" update
fi
if [[ -x "$INSTALLED_BIN" ]]; then
    exec "$INSTALLED_BIN" update
fi

echo "[ERROR] git-account-switcher is not installed." >&2
echo "        Run install.sh first, or run this script from a local clone." >&2
exit 1
