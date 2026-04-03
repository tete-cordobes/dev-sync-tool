#!/bin/bash
# dev-sync installer
# Usage: curl -fsSL https://raw.githubusercontent.com/USERNAME/dev-sync/main/install.sh | bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

SYNC_REPO="$HOME/dev-sync"
SCRIPTS_DIR="$HOME/.claude/scripts"
SETTINGS_FILE="$HOME/.claude/settings.json"

info()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         Dev-Sync Installer           ║${NC}"
echo -e "${BOLD}║   Google Drive for your code + AI    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# -------------------------------------------------------------------
# Step 1: Check dependencies
# -------------------------------------------------------------------
info "Checking dependencies..."

MISSING=""
for cmd in git jq rsync; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING="$MISSING $cmd"
  fi
done

if [[ -n "$MISSING" ]]; then
  warn "Missing dependencies:$MISSING"
  if command -v brew &>/dev/null; then
    info "Installing via Homebrew..."
    brew install $MISSING
  else
    error "Please install:$MISSING"
    exit 1
  fi
fi
ok "Dependencies ready"

# -------------------------------------------------------------------
# Step 2: Install scripts
# -------------------------------------------------------------------
info "Installing scripts to $SCRIPTS_DIR..."

mkdir -p "$SCRIPTS_DIR"

# Download or copy scripts
SCRIPT_SOURCE=""
if [[ -d "$(dirname "$0")/scripts" ]]; then
  SCRIPT_SOURCE="$(dirname "$0")/scripts"
elif [[ -d "./scripts" ]]; then
  SCRIPT_SOURCE="./scripts"
fi

if [[ -n "$SCRIPT_SOURCE" ]]; then
  cp "$SCRIPT_SOURCE"/dev-sync*.sh "$SCRIPTS_DIR/"
else
  # Download from GitHub
  REPO_URL="https://raw.githubusercontent.com/tete-cordobes/dev-sync-tool/main/scripts"
  for script in dev-sync.sh dev-sync-pull.sh dev-sync-restore.sh; do
    curl -fsSL "$REPO_URL/$script" -o "$SCRIPTS_DIR/$script"
  done
fi

chmod +x "$SCRIPTS_DIR"/dev-sync*.sh
ok "Scripts installed"

# -------------------------------------------------------------------
# Step 3: Configure Claude Code hooks
# -------------------------------------------------------------------
info "Configuring Claude Code hooks..."

mkdir -p "$HOME/.claude"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  # Create fresh settings with hooks
  cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/scripts/dev-sync.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/scripts/dev-sync-pull.sh\"",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
SETTINGS
  ok "Created settings.json with hooks"
else
  # Check if hooks already exist
  if jq -e '.hooks.PostToolUse' "$SETTINGS_FILE" &>/dev/null; then
    # Check if our hook is already there
    if jq -e '.hooks.PostToolUse[] | select(.hooks[]?.command | contains("dev-sync"))' "$SETTINGS_FILE" &>/dev/null; then
      ok "Dev-sync hooks already configured"
    else
      # Append our hooks to existing ones
      TEMP_FILE=$(mktemp)
      jq '.hooks.PostToolUse += [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync.sh\"", "timeout": 10}]}]' "$SETTINGS_FILE" > "$TEMP_FILE"
      mv "$TEMP_FILE" "$SETTINGS_FILE"
      ok "Added dev-sync to existing PostToolUse hooks"
    fi
  else
    # Add hooks key
    TEMP_FILE=$(mktemp)
    jq '. + {"hooks": {"PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync.sh\"", "timeout": 10}]}], "SessionStart": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync-pull.sh\"", "timeout": 15}]}]}}' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    ok "Added hooks to settings.json"
  fi

  # Add SessionStart if missing
  if ! jq -e '.hooks.SessionStart' "$SETTINGS_FILE" &>/dev/null; then
    TEMP_FILE=$(mktemp)
    jq '.hooks.SessionStart = [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync-pull.sh\"", "timeout": 15}]}]' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    ok "Added SessionStart hook"
  fi
fi

# -------------------------------------------------------------------
# Step 4: Setup sync repo
# -------------------------------------------------------------------
info "Setting up sync repo at $SYNC_REPO..."

if [[ -d "$SYNC_REPO/.git" ]]; then
  ok "Sync repo already exists"
else
  mkdir -p "$SYNC_REPO"
  cd "$SYNC_REPO"
  git init -b main

  cat > .gitignore << 'GITIGNORE'
# Dependencies
node_modules/
vendor/
.venv/
venv/
__pycache__/
*.pyc
.tox/

# Build outputs
dist/
build/
.next/
.nuxt/
out/
target/
*.o
*.a
*.so
*.dylib

# IDE
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# Secrets - NEVER sync
.env
.env.*
*.pem
*.key
*.p12
*.pfx
id_rsa*
credentials.json
secrets/
*.secret

# Large files
*.zip
*.tar.gz
*.tgz
*.rar
*.7z
*.dmg
*.iso
*.mp4
*.mov

# iOS/Xcode
DerivedData/
*.xcuserdata
Pods/

# Caches
.cache/
.turbo/
.parcel-cache/
*.log
GITIGNORE

  git add -A
  git commit -m "init: dev-sync workspace"
  ok "Sync repo created"
fi

# -------------------------------------------------------------------
# Step 5: Connect to GitHub remote
# -------------------------------------------------------------------
echo ""
cd "$SYNC_REPO"

if git remote get-url origin &>/dev/null; then
  ok "Remote already configured: $(git remote get-url origin)"
  info "Pulling latest..."
  git pull --rebase 2>/dev/null || git pull 2>/dev/null || true
else
  warn "No GitHub remote configured yet."
  echo ""

  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    echo -e "  ${BOLD}Create the remote repo now? (y/n)${NC}"
    read -r CREATE_REMOTE
    if [[ "$CREATE_REMOTE" == "y" || "$CREATE_REMOTE" == "Y" ]]; then
      info "Creating private repo on GitHub..."
      cd "$SYNC_REPO"
      gh repo create dev-sync --private --source=. --push
      ok "Remote repo created and pushed!"
    fi
  else
    echo "  To connect to GitHub, run:"
    echo ""
    echo "    cd ~/dev-sync"
    echo "    gh repo create dev-sync --private --source=. --push"
    echo ""
    echo "  Or manually:"
    echo ""
    echo "    cd ~/dev-sync"
    echo "    git remote add origin git@github.com:YOUR_USER/dev-sync.git"
    echo "    git push -u origin main"
    echo ""
  fi
fi

# -------------------------------------------------------------------
# Step 6: Add shell alias for restore
# -------------------------------------------------------------------
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
  if ! grep -q "dev-sync-restore" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Dev-Sync: restore projects from sync repo" >> "$SHELL_RC"
    echo "alias dev-sync-restore='bash \$HOME/.claude/scripts/dev-sync-restore.sh'" >> "$SHELL_RC"
    echo "alias dev-sync-log='tail -20 /tmp/dev-sync.log'" >> "$SHELL_RC"
    ok "Added shell aliases (dev-sync-restore, dev-sync-log)"
  fi
fi

# -------------------------------------------------------------------
# Done!
# -------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         Installation Complete!       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Sync repo:${NC}     ~/dev-sync/"
echo -e "  ${GREEN}Scripts:${NC}       ~/.claude/scripts/dev-sync*.sh"
echo -e "  ${GREEN}Hooks:${NC}         ~/.claude/settings.json"
echo ""
echo -e "  ${BOLD}How it works:${NC}"
echo -e "  1. Work with Claude Code normally"
echo -e "  2. Every edit auto-syncs to ~/dev-sync/ (silent)"
echo -e "  3. On the other machine: open Claude Code → auto-pulls"
echo -e "  4. YOUR commits/pushes go to your REAL project repo"
echo ""
echo -e "  ${BOLD}Commands:${NC}"
echo -e "  dev-sync-restore <project>  Manually restore a project"
echo -e "  dev-sync-log                View sync activity log"
echo ""
echo -e "  ${YELLOW}Tip:${NC} For AI memory sync, also install Engram:"
echo -e "  https://github.com/Gentleman-Programming/engram"
echo ""
