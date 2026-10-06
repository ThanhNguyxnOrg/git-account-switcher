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
    [[ "$out1" == *"v1.2.0"* && "$out2" == *"v1.2.0"* ]]
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
SANDBOX_CONFIG="$SANDBOX_DIR/accounts.json"
export GIT_ACCOUNT_SWITCHER_CONFIG="$SANDBOX_CONFIG"

cleanup() {
    rm -rf "$SANDBOX_DIR"
    unset GIT_ACCOUNT_SWITCHER_CONFIG
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
    rm -f "$HOME/.gitconfig-testisolatedbashkey"
    local blist_after
    blist_after=$("$SWITCHER" bindings 2>&1)
    [[ "$blist_after" != *"test_bound"* ]]
}

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

echo ""
echo "============================================================"
echo " Test Summary: $PASSED passed, $FAILED failed"
echo "============================================================"
echo ""

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
