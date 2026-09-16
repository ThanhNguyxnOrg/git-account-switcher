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

test_remove_profile() {
    "$SWITCHER" remove school -f >/dev/null 2>&1
    local count
    count=$(grep -c '"key"' "$SANDBOX_CONFIG" || echo "0")
    [[ "$count" -eq 1 ]] && grep -q '"work"' "$SANDBOX_CONFIG"
}

assert_test "Bash Script Syntax Validation" test_syntax
assert_test "Help flag execution ('help')" test_help
assert_test "Empty config list handling" test_empty_list
assert_test "Add profile non-interactively ('add octocat work')" test_add_first
assert_test "Add second profile ('add student-mona school')" test_add_second
assert_test "Update existing profile without duplicates" test_update_existing
assert_test "Remove profile ('remove school -f')" test_remove_profile

echo ""
echo "============================================================"
echo " Test Summary: $PASSED passed, $FAILED failed"
echo "============================================================"
echo ""

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
