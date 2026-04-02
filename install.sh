#!/bin/bash
# ai-switch installer
# https://github.com/yizhen0322/ai-switch

set -e

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing ai-switch..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Copy scripts
cp "$SCRIPT_DIR/bin/ai-switch" "$INSTALL_DIR/ai-switch"
cp "$SCRIPT_DIR/bin/opencode-wrapper" "$INSTALL_DIR/opencode"
chmod +x "$INSTALL_DIR/ai-switch"
chmod +x "$INSTALL_DIR/opencode"

# Create default config if not exists
if [[ ! -f "$CONFIG_DIR/ai-accounts.conf" ]]; then
  cat > "$CONFIG_DIR/ai-accounts.conf" << 'EOF'
# ai-switch account configuration
# Format: name:type:shortcut:display_name
# Types: free, plus, copilot, api
#
# Examples:
# free1:free:f1:john@example.com
# plus1:plus:p1:premium@example.com
# copilot1:copilot:c1:octocat

free1:free:f1:
EOF
  echo "Created default config: $CONFIG_DIR/ai-accounts.conf"
fi

# Check if PATH needs updating
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo ""
  echo "Add to your ~/.zshrc:"
  echo ""
  echo '  # Ensure ~/.local/bin is first in PATH (for opencode wrapper)'
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  echo ""
  echo '  # AI Multi-Account Manager'
  echo "  alias ai='~/.local/bin/ai-switch'"
  echo ""
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Add the lines above to ~/.zshrc (if not already)"
echo "  2. Run: source ~/.zshrc"
echo "  3. Run: ai setup"
echo "  4. Run: ai"
echo ""
