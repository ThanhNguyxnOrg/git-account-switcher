#!/usr/bin/env bash
# ==============================================================================
# Automated Test Suite for git-account-switcher (POSIX Bash)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCHER="$SCRIPT_DIR/../bin/git-account-switcher"

echo ""
echo "============================================================"
echo " Running git-account-switcher Test Suite (Bash)"
echo "============================================================"
echo ""

PASSED=0
FAILED=0

assert_test() {
    local name="$1"
    shift
    printf "  RUN   : %-48s ... " "$name"
    if "$@"; then
        echo -e "\033[0;32m[PASS]\033[0m"
        PASSED=$((PASSED + 1))
    else
        echo -e "\033[0;31m[FAIL]\033[0m"
        FAILED=$((FAILED + 1))
    fi
}

test_syntax() {
    bash -n "$SWITCHER"
}

test_help() {
    local out
    out=$("$SWITCHER" help 2>&1)
    [[ "$out" == *"USAGE:"* && "$out" == *"COMMANDS:"* ]]
}

test_version() {
    local out1 out2
    out1=$("$SWITCHER" version 2>&1)
    out2=$("$SWITCHER" -v 2>&1)
    [[ "$out1" == *"v1.3.1"* && "$out2" == *"v1.3.1"* ]]
}

test_update() {
    local out
    out=$("$SWITCHER" update 2>&1)
    [[ "$out" == *"Updating git-account-switcher"* && "$out" == *"updated successfully"* ]]
}

test_completion() {
    local out
    out=$("$SWITCHER" completion bash 2>&1)
    [[ "$out" == *"complete -F _gswitch_completions"* ]]
}

# Sandbox integration tests
SANDBOX_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'gswitch_test')
SANDBOX_HOME="$SANDBOX_DIR/home"
SANDBOX_BIN="$SANDBOX_DIR/bin"
SANDBOX_CONFIG="$SANDBOX_DIR/accounts.json"
mkdir -p "$SANDBOX_HOME" "$SANDBOX_BIN"
export GIT_ACCOUNT_SWITCHER_HOME="$SANDBOX_HOME"
export GIT_ACCOUNT_SWITCHER_CONFIG="$SANDBOX_CONFIG"
export GIT_CONFIG_GLOBAL="$SANDBOX_DIR/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0
export GH_LOG="$SANDBOX_DIR/gh.log"

cat > "$SANDBOX_BIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
if [[ "$1" == "auth" && "$2" == "token" ]]; then echo "fake-token"; exit 0; fi
if [[ "$1" == "auth" && "$2" == "status" ]]; then echo "Logged in to github.com account mock-active (keyring)"; exit 0; fi
if [[ "$1" == "api" && "$2" == "user" ]]; then echo "mock-active"; exit 0; fi
if [[ "$1" == "api" ]]; then echo '{"id":1,"login":"mock-active","name":"Mock User"}'; exit 0; fi
exit 0
EOF
chmod +x "$SANDBOX_BIN/gh"
export PATH="$SANDBOX_BIN:$PATH"

cleanup() {
    rm -rf "$SANDBOX_DIR"
    unset GIT_ACCOUNT_SWITCHER_CONFIG GIT_ACCOUNT_SWITCHER_HOME GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_TERMINAL_PROMPT GH_LOG
}
trap cleanup EXIT

test_empty_list() {
    local out
    out=$("$SWITCHER" list 2>&1 || true)
    [[ "$out" == *"No accounts configured"* || "$out" == *"No account profiles"* ]]
}

test_add_first() {
    "$SWITCHER" add octocat work "Mona Lisa" "mona@enterprise.com" >/dev/null 2>&1
    [[ -f "$SANDBOX_CONFIG" ]] && grep -q '"work"' "$SANDBOX_CONFIG" && grep -q '"octocat"' "$SANDBOX_CONFIG"
}

test_add_second() {
    "$SWITCHER" add student-mona school "Mona Student" "mona@school.edu" >/dev/null 2>&1
    local count
    count=$(grep -c '"key"' "$SANDBOX_CONFIG" || echo "0")
    [[ "$count" -eq 2 ]]
}

test_update_existing() {
    "$SWITCHER" add octocat work "Mona Updated" "mona.new@enterprise.com" >/dev/null 2>&1
    local count
    count=$(grep -c '"key"' "$SANDBOX_CONFIG" || echo "0")
    [[ "$count" -eq 2 ]] && grep -q "Mona Updated" "$SANDBOX_CONFIG"
}

test_add_alias() {
    "$SWITCHER" alias work w >/dev/null 2>&1
    grep -q '"w"' "$SANDBOX_CONFIG"
}

test_remove_alias() {
    "$SWITCHER" unalias work w >/dev/null 2>&1
    ! grep -q '"w"' "$SANDBOX_CONFIG"
}

test_remove_profile() {
    # Remove school, work remains as #1
    "$SWITCHER" remove school -f >/dev/null 2>&1
    local count
    count=$(grep -c '"key"' "$SANDBOX_CONFIG" || echo "0")
    [[ "$count" -eq 1 ]] && grep -q '"work"' "$SANDBOX_CONFIG" && grep -q '"1"' "$SANDBOX_CONFIG"
}

test_cred() {
    "$SWITCHER" cred non_existent_user get >/dev/null 2>&1 || true
}

test_doctor() {
    local out
    out=$("$SWITCHER" doctor 2>&1)
    [[ "$out" == *"GIT ACCOUNT SWITCHER - SYSTEM & REPO DIAGNOSTICS"* && "$out" == *"DOCTOR RESULT:"* ]]
}

test_ssh_warning() {
    local dummy_repo="$SANDBOX_DIR/dummy-ssh"
    mkdir -p "$dummy_repo"
    (
        cd "$dummy_repo"
        git init -q
        git remote add origin "git@github.com:dummy/ssh-repo.git"
        local out
        out=$("$SWITCHER" status 2>&1)
        [[ "$out" == *"Remote uses SSH"* ]]
    )
}

test_bindings() {
    local out
    out=$("$SWITCHER" bindings 2>&1)
    [[ "$out" == *"Configured Folder Bindings"* ]]
}

test_bind_unbind() {
    local bound_dir="$SANDBOX_DIR/test_bound"
    local sub_repo="$bound_dir/sub"
    mkdir -p "$sub_repo"
    "$SWITCHER" add mockbashuser testisolatedbashkey "Bash Mock" "bash@mock.org" >/dev/null 2>&1
    "$SWITCHER" bind "$bound_dir" testisolatedbashkey >/dev/null 2>&1
    local blist
    blist=$("$SWITCHER" bindings 2>&1)
    [[ "$blist" == *"test_bound"* ]]
    (
        cd "$sub_repo"
        git init -q
        local ename eemail
        ename=$(git config user.name)
        eemail=$(git config user.email)
        [[ "$ename" == "Bash Mock" && "$eemail" == "bash@mock.org" ]]
        local st
        st=$("$SWITCHER" status 2>&1)
        [[ "$st" == *"Folder includeIf Binding Active"* ]]
    )
    "$SWITCHER" unbind "$bound_dir" >/dev/null 2>&1
    rm -f "$GIT_ACCOUNT_SWITCHER_HOME/.gitconfig-testisolatedbashkey"
    local blist_after
    blist_after=$("$SWITCHER" bindings 2>&1)
    [[ "$blist_after" != *"test_bound"* ]]
}

test_credential_isolation() (
    set -e
    export GIT_ACCOUNT_SWITCHER_CONFIG="$SANDBOX_DIR/cred.json"
    "$SWITCHER" add mock-work work "Mock Work" "mock@work.test" >/dev/null 2>&1
    mkdir -p "$SANDBOX_DIR/credrepo"
    cd "$SANDBOX_DIR/credrepo"
    git init -q
    git config --global credential.https://github.com.helper '!f() { echo username=global; echo password=globalpass; }; f'
    "$SWITCHER" -l work >/dev/null 2>&1
    local git_dir
    git_dir=$(git rev-parse --git-dir)
    grep -qE '^[[:space:]]*helper[[:space:]]*=[[:space:]]*$' "$git_dir/config"
    local out
    out=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>&1)
    [[ "$out" == *"username=mock-work"* && "$out" == *"password=fake-token"* ]]
    local doctor_out
    doctor_out=$("$SWITCHER" doctor 2>&1)
    [[ "$doctor_out" != *"no empty reset"* ]]
)

test_preflight() (
    set -e
    export GIT_ACCOUNT_SWITCHER_CONFIG="$SANDBOX_DIR/preflight.json"
    "$SWITCHER" add mock-work work "Mock Work" "mock@work.test" >/dev/null 2>&1
    rm -f "$GH_LOG"
    mkdir -p "$SANDBOX_DIR/not-a-repo"
    cd "$SANDBOX_DIR/not-a-repo"
    if "$SWITCHER" -l work >/dev/null 2>&1; then
        return 1
    fi
    local log
    log=$(cat "$GH_LOG" 2>/dev/null || true)
    [[ "$log" != *"auth switch"* ]]
)

test_add_preserves_fields() (
    set -e
    local cfg="$SANDBOX_DIR/sign.json"
    export GIT_ACCOUNT_SWITCHER_CONFIG="$cfg"
    cat > "$cfg" <<'JSON'
[
  {"index":1,"key":"work","aliases":["1","work"],"label":"Work","username":"mock-work","name":"Mock Work","email":"mock@work.test","signingkey":"ssh-ed25519 AAAATESTKEY"}
]
JSON
    "$SWITCHER" alias work w >/dev/null 2>&1
    "$SWITCHER" add mock-work work "Mock Updated" "new@work.test" >/dev/null 2>&1
    python3 - "$cfg" <<'PY'
import json, sys
a = json.load(open(sys.argv[1], encoding='utf-8-sig'))[0]
assert a.get('signingkey') == 'ssh-ed25519 AAAATESTKEY', a
assert 'w' in a.get('aliases', []), a
PY
)

test_global_keeps_local() (
    set -e
    export GIT_ACCOUNT_SWITCHER_CONFIG="$SANDBOX_DIR/global.json"
    "$SWITCHER" add mock-work work "Mock Work" "mock@work.test" >/dev/null 2>&1
    mkdir -p "$SANDBOX_DIR/global-repo"
    cd "$SANDBOX_DIR/global-repo"
    git init -q
    git config --local user.name "Repo Local"
    git config --local user.email "local@repo.test"
    "$SWITCHER" work >/dev/null 2>&1
    [[ "$(git config --local user.name)" == "Repo Local" ]]
    "$SWITCHER" --clear-local work >/dev/null 2>&1
    [[ -z "$(git config --local user.name || true)" ]]
)

test_remove_cleans_binding() (
    set -e
    export GIT_ACCOUNT_SWITCHER_CONFIG="$SANDBOX_DIR/cleanup.json"
    "$SWITCHER" add mock-work work "Mock Work" "mock@work.test" >/dev/null 2>&1
    mkdir -p "$SANDBOX_DIR/cleanup-bound"
    "$SWITCHER" bind "$SANDBOX_DIR/cleanup-bound" work >/dev/null 2>&1
    [[ -f "$GIT_ACCOUNT_SWITCHER_HOME/.gitconfig-work" ]]
    "$SWITCHER" remove work -f >/dev/null 2>&1
    ! git config --global --get-regexp '^includeif\.gitdir' 2>/dev/null | grep -q 'gitconfig-work'
    [[ ! -f "$GIT_ACCOUNT_SWITCHER_HOME/.gitconfig-work" ]]
)

test_bom_config() (
    set -e
    local cfg="$SANDBOX_DIR/bom.json"
    printf '\xEF\xBB\xBF[{"index":1,"key":"bom","aliases":["1","bom"],"label":"BOM User","username":"bom-user","name":"BOM User","email":"bom@example.com"}]\n' > "$cfg"
    export GIT_ACCOUNT_SWITCHER_CONFIG="$cfg"
    local out
    out=$("$SWITCHER" list 2>&1)
    [[ "$out" == *"BOM User"* ]]
)

test_uninstall_cleanup() (
    set -e
    local uh="$SANDBOX_DIR/uninstall-home"
    mkdir -p "$uh/.local/bin"
    export GIT_ACCOUNT_SWITCHER_HOME="$uh"
    export GIT_ACCOUNT_SWITCHER_CONFIG="$uh/.config/git-account-switcher/accounts.json"
    printf '#!/bin/sh\n' > "$uh/.local/bin/gswitch"
    "$SWITCHER" add mock-work work "Mock Work" "mock@work.test" >/dev/null 2>&1
    mkdir -p "$SANDBOX_DIR/uninstall-bound"
    "$SWITCHER" bind "$SANDBOX_DIR/uninstall-bound" work >/dev/null 2>&1
    bash "$SCRIPT_DIR/../uninstall.sh" >/dev/null 2>&1
    ! git config --global --get-regexp '^includeif\.gitdir' 2>/dev/null | grep -q 'gitconfig-work'
    [[ ! -f "$uh/.gitconfig-work" ]]
)

assert_test "Bash Script Syntax Validation" test_syntax
assert_test "Help flag execution ('help')" test_help
assert_test "Version command execution ('version' & '-v')" test_version
assert_test "Update command execution ('update')" test_update
assert_test "Shell completion script generator ('completion bash')" test_completion
assert_test "Empty config list handling" test_empty_list
assert_test "Add profile non-interactively ('add octocat work')" test_add_first
assert_test "Add second profile ('add student-mona school')" test_add_second
assert_test "Update existing profile without duplicates" test_update_existing
assert_test "Add shortcut alias ('alias work w')" test_add_alias
assert_test "Remove shortcut alias ('unalias work w')" test_remove_alias
assert_test "Remove profile and clean reindex ('remove school -f')" test_remove_profile
assert_test "List folder bindings command ('bindings')" test_bindings
assert_test "Folder bind, inherit & unbind ('bind' & 'unbind')" test_bind_unbind
assert_test "Credential helper command ('cred <user> get')" test_cred
assert_test "Diagnostics command ('doctor')" test_doctor
assert_test "SSH Remote Warning in Status" test_ssh_warning
assert_test "Local credential isolation" test_credential_isolation
assert_test "Local switch preflight outside repo" test_preflight
assert_test "Add update preserves signingkey/aliases" test_add_preserves_fields
assert_test "Global switch preserves local overrides" test_global_keeps_local
assert_test "Remove account cleans folder bindings" test_remove_cleans_binding
assert_test "BOM-prefixed config is readable" test_bom_config
assert_test "Uninstall removes generated bindings/files" test_uninstall_cleanup

echo ""
echo "============================================================"
echo " Test Summary: $PASSED passed, $FAILED failed"
echo "============================================================"
echo ""

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
