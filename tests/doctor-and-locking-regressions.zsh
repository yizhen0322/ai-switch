#!/bin/zsh

set -euo pipefail

TEST_DIR="${0:A:h}"
source "$TEST_DIR/lib/test-helpers.zsh"

test_wrapper_detects_default_auth_change() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.local/share/opencode" "$temp_home/.local/bin" "$temp_home/.opencode/bin"

  cat > "$temp_home/.local/share/opencode/auth.json" <<'EOF'
{
  "openai": {
    "accountId": "acct-old"
  }
}
EOF

  cat > "$temp_home/.local/bin/ai-switch" <<'EOF'
#!/bin/zsh
printf '%s\n' "$*" >> "$HOME/ai-switch-calls.log"
EOF
  chmod +x "$temp_home/.local/bin/ai-switch"

  cat > "$temp_home/.opencode/bin/opencode" <<'EOF'
#!/bin/zsh
cat > "$HOME/.local/share/opencode/auth.json" <<'JSON'
{
  "openai": {
    "accountId": "acct-new"
  }
}
JSON
EOF
  chmod +x "$temp_home/.opencode/bin/opencode"

  HOME="$temp_home" zsh "$OPENCODE_WRAPPER_SCRIPT" >/dev/null

  [[ -f "$temp_home/ai-switch-calls.log" ]] || {
    print -u2 -- "expected opencode wrapper to call ai-switch after a default auth change"
    return 1
  }

  if ! grep -q '^__auto_add_default' "$temp_home/ai-switch-calls.log"; then
    print -u2 -- "expected wrapper to call ai-switch __auto_add_default"
    cat "$temp_home/ai-switch-calls.log" >&2
    return 1
  fi

  rm -rf "$temp_home"
}

test_copilot_requests_have_timeouts() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-copilot1/opencode" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
copilot1:copilot:c1:
EOF

  cat > "$temp_home/.local/share/opencode-copilot1/opencode/auth.json" <<'EOF'
{
  "github-copilot": {
    "access": "copilot-token"
  }
}
EOF

  cat > "$temp_home/bin/curl" <<'EOF'
#!/bin/zsh
printf '%s\n' "$@" > "$HOME/curl-args.log"
print '{"login":"octocat","quota_snapshots":{"premium_interactions":{"percent_remaining":86},"chat":{"percent_remaining":100}}}'
EOF
  chmod +x "$temp_home/bin/curl"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" usage c1 >/dev/null

  if ! grep -q -- '--connect-timeout' "$temp_home/curl-args.log"; then
    print -u2 -- "expected Copilot curl call to set a connect timeout"
    return 1
  fi

  if ! grep -q -- '--max-time' "$temp_home/curl-args.log"; then
    print -u2 -- "expected Copilot curl call to set a total timeout"
    return 1
  fi

  rm -rf "$temp_home"
}

test_usage_file_writes_are_locked() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" \
    "$temp_home/.local/share/opencode-api1/opencode" \
    "$temp_home/.local/share/opencode-api2/opencode" \
    "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
api1:api:a1:api-one
api2:api:a2:api-two
EOF

  cat > "$temp_home/.local/share/ai-usage.json" <<'EOF'
{}
EOF

  cat > "$temp_home/bin/opencode" <<'EOF'
#!/bin/zsh
exit 0
EOF
  chmod +x "$temp_home/bin/opencode"

  cat > "$temp_home/bin/jq" <<EOF
#!/bin/zsh
for arg in "\$@"; do
  if [[ "\$arg" == "\$HOME/.local/share/ai-usage.json" ]]; then
    sleep 0.2
    break
  fi
done
exec "$REAL_JQ" "\$@"
EOF
  chmod +x "$temp_home/bin/jq"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" a1 >/dev/null &
  local pid1=$!
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" a2 >/dev/null &
  local pid2=$!
  wait "$pid1" "$pid2"

  if ! "$REAL_JQ" -e '.api1.lastUsedAt and .api2.lastUsedAt' "$temp_home/.local/share/ai-usage.json" >/dev/null; then
    print -u2 -- "expected concurrent usage writes to preserve both account timestamps"
    "$REAL_JQ" '.' "$temp_home/.local/share/ai-usage.json" >&2
    return 1
  fi

  rm -rf "$temp_home"
}

test_config_writes_are_locked() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:first@example.com
free2:free:f2:second@example.com
EOF

  cat > "$temp_home/bin/mv" <<EOF
#!/bin/zsh
dest="\${@: -1}"
if [[ "\$dest" == "\$HOME/.config/ai-accounts.conf" ]]; then
  sleep 0.2
fi
exec "$REAL_MV" "\$@"
EOF
  chmod +x "$temp_home/bin/mv"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" rename f1 alpha >/dev/null &
  local pid1=$!
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" rename f2 beta >/dev/null &
  local pid2=$!
  wait "$pid1" "$pid2"

  local config_contents=$(<"$temp_home/.config/ai-accounts.conf")
  assert_contains "$config_contents" "free1:free:f1:alpha" "expected concurrent config writes to keep the first rename"
  assert_contains "$config_contents" "free2:free:f2:beta" "expected concurrent config writes to keep the second rename"

  rm -rf "$temp_home"
}

test_doctor_reports_environment_issues() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" \
    "$temp_home/.local/share/opencode-free1/opencode" \
    "$temp_home/.local/share/opencode-free2/opencode" \
    "$temp_home/bin"

  ln -s /missing/plugins "$temp_home/.local/share/opencode-free1/opencode/plugins"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:first@example.com
free2:free:f1:duplicate@example.com
broken-line
EOF

  ln -s "$REAL_JQ" "$temp_home/bin/jq"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  set +e
  local output
  output=$(HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" doctor 2>&1)
  local exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || {
    print -u2 -- "expected ai doctor to exit non-zero when issues are detected"
    return 1
  }

  assert_contains "$output" "Dependencies" "expected ai doctor to print a dependencies section"
  assert_contains "$output" "codex" "expected ai doctor to report codex availability"
  assert_contains "$output" "duplicate shortcut: f1" "expected ai doctor to report duplicate shortcuts"
  assert_contains "$output" "invalid config line" "expected ai doctor to report malformed config lines"
  assert_contains "$output" "free1 missing auth.json" "expected ai doctor to report missing auth files"
  assert_contains "$output" "free1 broken symlink" "expected ai doctor to report broken symlinks"
  assert_contains "$output" "wrapper" "expected ai doctor to report wrapper installation status"

  rm -rf "$temp_home"
}

run_case "Wrapper auth detection" test_wrapper_detects_default_auth_change
run_case "Copilot request timeouts" test_copilot_requests_have_timeouts
run_case "Usage file locking" test_usage_file_writes_are_locked
run_case "Config file locking" test_config_writes_are_locked
run_case "Doctor environment report" test_doctor_reports_environment_issues
