#!/bin/zsh

set -euo pipefail

TEST_HELPERS_DIR="${${(%):-%N}:A:h}"
REPO_ROOT="${TEST_HELPERS_DIR:h:h}"

AI_SWITCH_SCRIPT="${AI_SWITCH_SCRIPT:-$REPO_ROOT/bin/ai-switch}"
OPENCODE_WRAPPER_SCRIPT="${OPENCODE_WRAPPER_SCRIPT:-$REPO_ROOT/bin/opencode-wrapper}"

REAL_JQ="$(command -v jq)"
REAL_MV="$(command -v mv)"

make_test_home() {
  mktemp -d "${TMPDIR:-/tmp}/ai-switch-test.XXXXXX"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -- "$message"
    print -u2 -- "expected to find: $needle"
    print -u2 -- "actual output:"
    print -u2 -- "$haystack"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 -- "$message"
    print -u2 -- "did not expect to find: $needle"
    print -u2 -- "actual output:"
    print -u2 -- "$haystack"
    return 1
  fi
}

run_case() {
  local name="$1"
  shift

  print -r -- "==> $name"
  "$@"
}
