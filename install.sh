#!/usr/bin/env bash
# ==============================================================================
# git-account-switcher (gswitch) Installer for macOS and Linux
# ==============================================================================
set -e

if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    echo "[ERROR] Windows detected. Use install.ps1 from PowerShell instead of install.sh." >&2
    exit 1
fi

RELEASES_REPO="ThanhNguyxnOrg/git-account-switcher"
RELEASE_WORKFLOW="ThanhNguyxnOrg/git-account-switcher/.github/workflows/release.yml"
RELEASE_TMP=""
cleanup() {
    [[ -n "$RELEASE_TMP" ]] && rm -rf "$RELEASE_TMP"
}
trap cleanup EXIT

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

if ! command -v python3 >/dev/null 2>&1; then
    echo "  [ERROR] Python 3 is required to manage accounts.json." >&2
    echo "          macOS: xcode-select --install   Linux: install the python3 package" >&2
    exit 1
fi
echo "  [OK] Python 3 is available."

# 2. Target bin directory
BIN_DIR="${GIT_ACCOUNT_SWITCHER_HOME:-$HOME}/.local/bin"
echo "[2/5] Preparing installation directory ($BIN_DIR)..."
mkdir -p "$BIN_DIR"

IS_LOCAL=false
if [[ -n "${BASH_SOURCE[0]}" && -d "$(dirname "${BASH_SOURCE[0]}")/bin" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    IS_LOCAL=true
fi

if [[ "$IS_LOCAL" == "true" ]]; then
    for f in git-account-switcher gswitch switch-git; do
        cp "$SCRIPT_DIR/bin/$f" "$BIN_DIR/.$f.new.$$"
        chmod +x "$BIN_DIR/.$f.new.$$"
        mv -f "$BIN_DIR/.$f.new.$$" "$BIN_DIR/$f"
    done
else
    if ! command -v gh >/dev/null 2>&1; then
        echo "  [ERROR] GitHub CLI (gh) is required to verify release assets." >&2
        exit 1
    fi
    TAG="${GSWITCH_INSTALL_TAG:-$(gh release view --repo "$RELEASES_REPO" --json tagName --jq '.tagName' 2>/dev/null || true)}"
    if [[ -z "$TAG" ]]; then
        echo "  [ERROR] No GitHub release found for $RELEASES_REPO." >&2
        echo "          Create a v* release with attested assets, or set GSWITCH_INSTALL_TAG." >&2
        exit 1
    fi
    RELEASE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/gswitch-install.XXXXXX")
    echo "  Downloading verified release $TAG..."
    gh release download "$TAG" --repo "$RELEASES_REPO" --dir "$RELEASE_TMP" --clobber >/dev/null
    if ! gh attestation verify "$RELEASE_TMP/SHA256SUMS" --repo "$RELEASES_REPO" --signer-workflow "$RELEASE_WORKFLOW" --deny-self-hosted-runners >/dev/null 2>&1; then
        echo "  [ERROR] Release attestation verification failed." >&2
        exit 1
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$RELEASE_TMP" && sha256sum -c SHA256SUMS >/dev/null) || { echo "  [ERROR] Checksum verification failed." >&2; exit 1; }
    elif command -v shasum >/dev/null 2>&1; then
        (cd "$RELEASE_TMP" && shasum -a 256 -c SHA256SUMS >/dev/null) || { echo "  [ERROR] Checksum verification failed." >&2; exit 1; }
    else
        echo "  [ERROR] sha256sum or shasum is required to verify releases." >&2
        exit 1
    fi
    for f in git-account-switcher gswitch switch-git; do
        cp "$RELEASE_TMP/$f" "$BIN_DIR/.$f.new.$$"
        chmod +x "$BIN_DIR/.$f.new.$$"
        mv -f "$BIN_DIR/.$f.new.$$" "$BIN_DIR/$f"
    done
    echo "  [OK] Attestation and checksums verified for $TAG"
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
CONFIG_DIR="${GIT_ACCOUNT_SWITCHER_HOME:-$HOME}/.config/git-account-switcher"
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/accounts.json" ]]; then
    if gh auth status 2>&1 | grep -q 'Logged in to .* account'; then
        echo "  Detected active GitHub CLI accounts! Running auto-discovery..."
        "$BIN_DIR/gswitch" sync || true
    elif [[ "$IS_LOCAL" == "true" && -f "$SCRIPT_DIR/config/accounts.example.json" ]]; then
        cp "$SCRIPT_DIR/config/accounts.example.json" "$CONFIG_DIR/accounts.json"
        echo "  [OK] Deployed template accounts.json -> $CONFIG_DIR/accounts.json"
    elif [[ -n "$RELEASE_TMP" && -f "$RELEASE_TMP/accounts.example.json" ]]; then
        cp "$RELEASE_TMP/accounts.example.json" "$CONFIG_DIR/accounts.json"
        echo "  [OK] Deployed template accounts.json from release -> $CONFIG_DIR/accounts.json"
    else
        echo "[]" > "$CONFIG_DIR/accounts.json"
        echo "  [OK] Initialized empty accounts.json -> $CONFIG_DIR/accounts.json"
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
echo "[5/5] Setting up Git aliases & completions..."
git config --global alias.who '!git-account-switcher status'
git config --global alias.switch-acc '!git-account-switcher'
echo "  [OK] Added git alias: git who"
echo "  [OK] Added git alias: git switch-acc"

# 6. Configure Shell auto-completion
"$BIN_DIR/git-account-switcher" completion install >/dev/null 2>&1 || true
echo "  [OK] Configured shell auto-completion (gswitch <Tab>)"

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
