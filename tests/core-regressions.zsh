#!/bin/zsh

set -euo pipefail

TEST_DIR="${0:A:h}"
source "$TEST_DIR/lib/test-helpers.zsh"

test_copilot_usage_formats() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-copilot1/opencode" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
copilot1:copilot:c1:
EOF

  cat > "$temp_home/.local/share/opencode-copilot1/opencode/auth.json" <<'EOF'
{
  "github-copilot": {
    "access": "ghu_test_copilot_token"
  }
}
EOF

  cat > "$temp_home/bin/curl" <<'EOF'
#!/bin/zsh
cat <<'JSON'
{
  "quotaSnapshots": {
    "premiumInteractions": {
      "percentRemaining": 72
    },
    "chat": {
      "percentRemaining": 55
    }
  }
}
JSON
EOF
  chmod +x "$temp_home/bin/curl"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  local output=$(HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" usage c1)

  assert_contains "$output" "Premium interactions:" "expected premium interactions output for camelCase Copilot response"
  assert_contains "$output" "72% left" "expected premium remaining percentage for camelCase Copilot response"
  assert_contains "$output" "Chat messages:" "expected chat output for camelCase Copilot response"
  assert_contains "$output" "55% left" "expected chat remaining percentage for camelCase Copilot response"

  cat > "$temp_home/bin/curl" <<'EOF'
#!/bin/zsh
cat <<'JSON'
{
  "quota_snapshots": {
    "chat": {
      "percent_remaining": 100.0,
      "unlimited": true
    },
    "premium_interactions": {
      "entitlement": 300,
      "percent_remaining": 86.0,
      "remaining": 258,
      "unlimited": false
    }
  }
}
JSON
EOF
  chmod +x "$temp_home/bin/curl"

  local output2=$(HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" usage c1)

  assert_contains "$output2" "Premium interactions:" "expected premium interactions output for snake_case Copilot response"
  assert_contains "$output2" "86% left" "expected premium remaining percentage for snake_case Copilot response"
  assert_contains "$output2" "Chat messages:" "expected chat output for snake_case Copilot response"
  assert_contains "$output2" "100% left" "expected chat remaining percentage for snake_case Copilot response"

  rm -rf "$temp_home"
}

test_codex_status_fallback() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-free1/opencode" "$temp_home/.local/share/codex-free1" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:
EOF

  cat > "$temp_home/.local/share/opencode-free1/opencode/auth.json" <<'EOF'
{
  "openai": {
    "access": "test_access_token",
    "refresh": "test_refresh_token",
    "accountId": "acct-free-1"
  }
}
EOF

  cat > "$temp_home/bin/codex" <<'EOF'
#!/bin/zsh
if [[ "${1-}" == "app-server" ]]; then
  exit 1
fi

while IFS= read -r line; do
  case "$line" in
    /status)
      print "5h limit: 18% left"
      print "Weekly limit: 64% left"
      print "Credits: 12"
      ;;
    /exit)
      exit 0
      ;;
  esac
done
EOF
  chmod +x "$temp_home/bin/codex"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  local output=$(HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" usage f1)

  assert_contains "$output" "5h limit:" "expected 5h limit from codex /status fallback"
  assert_contains "$output" "18% left" "expected 5h limit percentage from codex /status fallback"
  assert_contains "$output" "Weekly limit:" "expected weekly limit from codex /status fallback"
  assert_contains "$output" "64% left" "expected weekly limit percentage from codex /status fallback"
  assert_contains "$output" "Credits:" "expected credits line from codex /status fallback"
  assert_contains "$output" "Data from codex /status fallback" "expected fallback data source label"

  rm -rf "$temp_home"
}

test_codex_launcher_isolates_home() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-free1/opencode" "$temp_home/.codex/plugins" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:
EOF

  cat > "$temp_home/.local/share/opencode-free1/opencode/auth.json" <<'EOF'
{
  "openai": {
    "access": "test_access_token",
    "refresh": "test_refresh_token",
    "accountId": "acct-free-1"
  }
}
EOF

  cat > "$temp_home/.codex/config.toml" <<'EOF'
model = "gpt-5"
EOF

  cat > "$temp_home/bin/opencode" <<'EOF'
#!/bin/zsh
print -r -- "$XDG_DATA_HOME" > "$HOME/opencode-home.txt"
EOF
  chmod +x "$temp_home/bin/opencode"

  cat > "$temp_home/bin/codex" <<'EOF'
#!/bin/zsh
if [[ "${1-}" == "app-server" ]]; then
  exit 1
fi

print -r -- "$CODEX_HOME" > "$HOME/codex-home.txt"
EOF
  chmod +x "$temp_home/bin/codex"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" f1 >/dev/null
  HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" codex f1 >/dev/null

  local opencode_home=$(<"$temp_home/opencode-home.txt")
  local codex_home=$(<"$temp_home/codex-home.txt")
  local expected_opencode_home="$temp_home/.local/share/opencode-free1"
  local expected_codex_home="$temp_home/.local/share/codex-free1"

  [[ "$opencode_home" == "$expected_opencode_home" ]] || {
    print -u2 -- "expected isolated opencode XDG_DATA_HOME"
    return 1
  }
  [[ "$codex_home" == "$expected_codex_home" ]] || {
    print -u2 -- "expected isolated CODEX_HOME"
    return 1
  }
  [[ -L "$expected_codex_home/config.toml" ]] || {
    print -u2 -- "expected codex config.toml to be shared as symlink"
    return 1
  }
  [[ -f "$expected_codex_home/auth.json" && ! -L "$expected_codex_home/auth.json" ]] || {
    print -u2 -- "expected codex auth.json to be an isolated regular file"
    return 1
  }

  rm -rf "$temp_home"
}

test_status_cache_and_hidden_local_data() {
  local temp_home=$(make_test_home)

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-free1/opencode" "$temp_home/.local/share/opencode-plus1/opencode" "$temp_home/.local/share"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:free-user
plus1:plus:p1:plus-user
EOF

  cat > "$temp_home/.local/share/opencode-free1/opencode/auth.json" <<'EOF'
{"loggedIn":true}
EOF

  cat > "$temp_home/.local/share/opencode-plus1/opencode/auth.json" <<'EOF'
{"loggedIn":true}
EOF

  dd if=/dev/zero of="$temp_home/.local/share/opencode-free1/opencode/opencode.db" bs=1024 count=2 >/dev/null 2>&1

  cat > "$temp_home/.local/share/ai-usage.json" <<'EOF'
{
  "free1": {
    "lastUsedAt": 1763400000,
    "lastRateLimits": {
      "rateLimits": {
        "primary": {
          "usedPercent": 33,
          "windowDurationMins": 10080,
          "resetsAt": 1764000000
        },
        "planType": "free"
      }
    }
  },
  "plus1": {
    "lastUsedAt": 1763400001,
    "lastRateLimits": {
      "rateLimits": {
        "primary": {
          "usedPercent": 10,
          "windowDurationMins": 300,
          "resetsAt": 1763500000
        },
        "secondary": {
          "usedPercent": 45,
          "windowDurationMins": 10080,
          "resetsAt": 1764000000
        },
        "planType": "plus"
      }
    }
  }
}
EOF

  local output=$(HOME="$temp_home" zsh "$AI_SWITCH_SCRIPT")

  assert_contains "$output" "67% left" "expected cached free limit summary in ai status"
  assert_contains "$output" "5h limit" "expected cached plus 5h limit summary in ai status"
  assert_contains "$output" "Weekly limit" "expected cached plus weekly limit summary in ai status"
  assert_not_contains "$output" "KB" "expected ai status to hide local data size"
  assert_not_contains "$output" "MB" "expected ai status to hide local data size"

  rm -rf "$temp_home"
}

test_renew_usage_upgrades_email_and_shows_status() {
  local temp_home=$(make_test_home)

  local id_payload="eyJlbWFpbCI6InBlcnNvbkBleGFtcGxlLmNvbSJ9"

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-free1/opencode" "$temp_home/.local/share/codex-free1" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:person
EOF

  cat > "$temp_home/.local/share/opencode-free1/opencode/auth.json" <<EOF
{
  "openai": {
    "access": "test_access_token",
    "refresh": "test_refresh_token",
    "accountId": "acct-free-1"
  },
  "tokens": {
    "id_token": "header.${id_payload}.sig"
  }
}
EOF

  cat > "$temp_home/bin/codex" <<'EOF'
#!/bin/zsh
if [[ "${1-}" == "app-server" ]]; then
  print '{"jsonrpc":"2.0","id":3,"result":{"rateLimits":{"primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":0},"planType":"free","credits":{"hasCredits":false,"balance":0}}}}'
  exit 0
fi

exit 1
EOF
  chmod +x "$temp_home/bin/codex"

  local test_path="$temp_home/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  local output=$(HOME="$temp_home" PATH="$test_path" zsh "$AI_SWITCH_SCRIPT" renew usage)
  local config_line=$(grep '^free1:' "$temp_home/.config/ai-accounts.conf")

  [[ "$config_line" == "free1:free:f1:person@example.com" ]] || {
    print -u2 -- "expected renew usage to migrate legacy display name to full email"
    return 1
  }
  assert_contains "$output" "AI Multi-Account Status" "expected renew usage to finish by showing the main status page"
  assert_contains "$output" "person@example.com" "expected renew usage status to show the upgraded full email"

  rm -rf "$temp_home"
}

test_usage_output_behaviors() {
  local temp_home=$(make_test_home)

  local id_payload="eyJlbWFpbCI6InBlcnNvbkBleGFtcGxlLmNvbSJ9"

  mkdir -p "$temp_home/.config" "$temp_home/.local/share/opencode-free1/opencode" "$temp_home/bin"

  cat > "$temp_home/.config/ai-accounts.conf" <<'EOF'
free1:free:f1:person
EOF

  cat > "$temp_home/.local/share/opencode-free1/opencode/auth.json" <<EOF
{
  "tokens": {
    "id_token": "header.${id_payload}.sig"
  }
}
EOF

  local jq_dir="${REAL_JQ:h}"
  local safe_path="$jq_dir:/usr/bin:/bin:/usr/sbin:/sbin"
  local output=$(HOME="$temp_home" PATH="$safe_path" zsh "$AI_SWITCH_SCRIPT" usage f1)

  assert_contains "$output" "Account: person@example.com" "expected usage title to show upgraded full email on first invocation"
  assert_contains "$output" "codex CLI not found" "expected codex missing guidance in usage output"
  assert_contains "$output" "install codex to read usage limits" "expected codex install guidance in usage output"
  assert_not_contains "$output" "Local data:" "expected usage output to hide local data line"

  rm -rf "$temp_home"
}

run_case "Copilot usage formats" test_copilot_usage_formats
run_case "Codex status fallback" test_codex_status_fallback
run_case "Codex launcher isolation" test_codex_launcher_isolates_home
run_case "Status cache and hidden local data" test_status_cache_and_hidden_local_data
run_case "Renew usage email migration" test_renew_usage_upgrades_email_and_shows_status
run_case "Usage output behaviors" test_usage_output_behaviors
