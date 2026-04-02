#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

zsh -n "$ROOT_DIR/bin/ai-switch"
zsh -n "$ROOT_DIR/bin/ai-switch-auth"
zsh -n "$ROOT_DIR/bin/opencode-wrapper"
bash -n "$ROOT_DIR/install.sh"

for test_file in "$ROOT_DIR"/tests/*-regressions.zsh; do
  [ -e "$test_file" ] || continue
  zsh "$test_file"
done
