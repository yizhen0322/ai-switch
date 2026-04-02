# ai-switch

A multi-account manager for [OpenCode](https://opencode.ai) / [Codex](https://github.com/openai/codex) CLI. Seamlessly switch between multiple ChatGPT accounts (Free, Plus, GitHub Copilot) while sharing sessions and plugins.

## Features

- **Multi-account support**: Manage multiple ChatGPT Free, Plus, and GitHub Copilot accounts
- **Account isolation**: Each account has isolated authentication
- **Shared sessions**: All accounts share the same session history and plugins
- **Rate limit tracking**: View cached ChatGPT limits and live GitHub Copilot usage
- **Auto-detection**: Automatically detects and adds new accounts when using `/connect`
- **Quick shortcuts**: Launch accounts with simple aliases like `f1`, `p1`, `c1`

## Requirements

- macOS (uses zsh)
- [OpenCode](https://opencode.ai) or [Codex CLI](https://github.com/openai/codex) installed
- `jq` for JSON processing

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yizhen0322/ai-switch.git
cd ai-switch

# Run the install script
./install.sh
```

### Manual Install

1. Copy scripts to `~/.local/bin/`:

```bash
mkdir -p ~/.local/bin
cp bin/ai-switch ~/.local/bin/
cp bin/opencode-wrapper ~/.local/bin/opencode
chmod +x ~/.local/bin/ai-switch ~/.local/bin/opencode
```

2. Add to your `~/.zshrc`:

```bash
# Ensure ~/.local/bin is first in PATH (for opencode wrapper)
export PATH="$HOME/.local/bin:$PATH"

# AI Multi-Account Manager
alias ai='~/.local/bin/ai-switch'
```

3. Create initial config:

```bash
mkdir -p ~/.config
cat > ~/.config/ai-accounts.conf << 'EOF'
# Format: name:type:shortcut:display_name
# Types: free, plus, copilot, api
free1:free:f1:
EOF
```

4. Initialize:

```bash
source ~/.zshrc
ai setup
```

## Usage

### View Status

```bash
ai
```

Output:
```
AI Multi-Account Status
========================

FREE Accounts:
  ● f1  john@example.com  72% left (14:30 on 01 Apr)
  ● f2  work@example.com  45% left (16:00 on 01 Apr)

PLUS Accounts:
  ● p1  premium@example.com  5h limit 90% left (14:30 on 01 Apr) | Weekly limit 85% left (00:00 on 07 Apr)

COPILOT Accounts:
  ● c1  octocat  84% left

Commands:
  ai                  Show this status
  ai <shortcut>       Launch account (e.g., ai f1)
  ai codex <shortcut> Launch Codex with account
  ai usage <shortcut> Show plan & usage info
  ai renew usage      Refresh usage data for all supported accounts
  ai add [TYPE]       Add account (free/plus/copilot/api)
  ai rm <shortcut>    Remove account
```

### Launch an Account

```bash
ai f1        # Launch free account 1
ai p1        # Launch plus account 1
ai c1        # Launch copilot account 1
```

Or use aliases (after adding to `.zshrc`):

```bash
f1           # Same as ai f1
p1           # Same as ai p1
```

### Add Accounts

```bash
ai add           # Add a free account
ai add plus      # Add a Plus account
ai add copilot   # Add a GitHub Copilot account
ai add api       # Add an API-based account
```

After adding, launch the account and log in:

```bash
ai f2           # Launch and login
```

### View Account Usage

```bash
ai usage f1
```

Refresh all supported usage data:

```bash
ai renew usage
```

Output:
```
Account: john@example.com (free)
================================
Email: john@example.com

Usage Limits:
  ████████████░░░░░░░░ 28% left (14:30 on 01 Apr)
  Plan: free

Data from Codex app-server
```

### Auto-Detection

When you use `/connect` in OpenCode to log into a new account, ai-switch automatically:
1. Detects the new authentication
2. Creates a new account slot
3. Names it based on your email

This works both when launching via `ai` and when running `opencode` directly.

### Rename Account

```bash
ai rename f1 work-email
```

### Remove Account

```bash
ai rm f2
```

## How It Works

### Account Isolation

Each account gets its own data directory for authentication:
- `~/.local/share/opencode-{account}/opencode/auth.json`

### Shared Resources

All accounts share these via symlinks:
- Session database (`opencode.db`)
- Plugins directory
- Logs, snapshots, tool outputs

This means:
- Sessions are visible across all accounts
- Plugins work with any account
- Only authentication is isolated

### Rate Limit Tracking

For ChatGPT accounts (free/plus), ai-switch fetches rate limits from Codex's app-server using JSON-RPC:
- Free accounts: Single rolling limit
- Plus accounts: 5-hour limit + Weekly limit

Limits are cached and refreshed automatically when exiting OpenCode.

## Configuration

### Config File

`~/.config/ai-accounts.conf`:

```
# Format: name:type:shortcut:display_name
free1:free:f1:john@example.com
free2:free:f2:work@example.com
plus1:plus:p1:premium@example.com
copilot1:copilot:c1:octocat
```

### Aliases

Add to `~/.zshrc` for quick access:

```bash
alias f1='ai f1'
alias f2='ai f2'
alias p1='ai p1'
alias c1='ai c1'
```

## Troubleshooting

### "Config not found"

Run `ai setup` to initialize directories.

### Rate limits not showing

Ensure you're logged in to the account first. Rate limits are only available for ChatGPT accounts (not GitHub Copilot).

### Sessions not shared

Run `ai setup` to recreate symlinks.

### PATH issues

Ensure `~/.local/bin` is first in your PATH (for the opencode wrapper to work):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## License

MIT

## Credits

Built for use with [OpenCode](https://opencode.ai) and [Codex CLI](https://github.com/openai/codex).
