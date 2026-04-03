#!/bin/bash
# dev-sync-tool installer
# Installs: Tete Output Style + Dev-Sync (file sync) + Statusline + gentle-ai (Engram + SDD)
# Usage: bash install.sh

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

SYNC_REPO="$HOME/dev-sync"
SCRIPTS_DIR="$HOME/.claude/scripts"
SETTINGS_FILE="$HOME/.claude/settings.json"
INSTALLER_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          Dev-Sync Tool Installer             ║${NC}"
echo -e "${BOLD}║  Tete Style + Sync + Statusline + Engram     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${DIM}  Components:${NC}"
echo -e "  ${GREEN}●${NC} Tete Style  — Andaluz cordobes output style for Claude Code"
echo -e "  ${GREEN}●${NC} Dev-Sync    — Google Drive for your code"
echo -e "  ${GREEN}●${NC} Statusline  — Custom Claude Code status bar"
echo -e "  ${GREEN}●${NC} Engram      — Persistent AI memory across sessions"
echo -e "  ${GREEN}●${NC} SDD         — Spec-Driven Development workflow"
echo ""

# ===================================================================
# STEP 1: Dependencies
# ===================================================================
step "1/7 — Dependencies"

MISSING=""
for cmd in git jq rsync; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING="$MISSING $cmd"
  fi
done

if [[ -n "$MISSING" ]]; then
  warn "Missing:$MISSING"
  if command -v brew &>/dev/null; then
    info "Installing via Homebrew..."
    brew install $MISSING
  else
    error "Please install:$MISSING"
    exit 1
  fi
fi
ok "Core dependencies ready (git, jq, rsync)"

# ===================================================================
# STEP 2: Dev-Sync scripts
# ===================================================================
step "2/7 — Dev-Sync Scripts"

mkdir -p "$SCRIPTS_DIR"

SCRIPT_SOURCE=""
if [[ -d "$INSTALLER_DIR/scripts" ]]; then
  SCRIPT_SOURCE="$INSTALLER_DIR/scripts"
elif [[ -d "./scripts" ]]; then
  SCRIPT_SOURCE="./scripts"
fi

if [[ -n "$SCRIPT_SOURCE" ]]; then
  cp "$SCRIPT_SOURCE"/dev-sync*.sh "$SCRIPTS_DIR/"
else
  REPO_URL="https://raw.githubusercontent.com/tete-cordobes/dev-sync-tool/main/scripts"
  for script in dev-sync.sh dev-sync-pull.sh dev-sync-restore.sh; do
    curl -fsSL "$REPO_URL/$script" -o "$SCRIPTS_DIR/$script"
  done
fi

chmod +x "$SCRIPTS_DIR"/dev-sync*.sh
ok "Sync scripts installed to $SCRIPTS_DIR"

# ===================================================================
# STEP 3: Output Style (Tete)
# ===================================================================
step "3/7 — Output Style (Tete)"

STYLES_DIR="$HOME/.claude/output-styles"
mkdir -p "$STYLES_DIR"

STYLE_SOURCE=""
if [[ -f "$INSTALLER_DIR/output-styles/tete.md" ]]; then
  STYLE_SOURCE="$INSTALLER_DIR/output-styles/tete.md"
elif [[ -f "./output-styles/tete.md" ]]; then
  STYLE_SOURCE="./output-styles/tete.md"
fi

if [[ -n "$STYLE_SOURCE" ]]; then
  cp "$STYLE_SOURCE" "$STYLES_DIR/tete.md"
  ok "Output style 'Tete' installed (andaluz cordobes puro)"
else
  STYLE_URL="https://raw.githubusercontent.com/tete-cordobes/dev-sync-tool/main/output-styles/tete.md"
  curl -fsSL "$STYLE_URL" -o "$STYLES_DIR/tete.md"
  ok "Output style 'Tete' downloaded and installed"
fi

# ===================================================================
# STEP 4: Statusline
# ===================================================================
step "4/7 — Statusline"

STATUSLINE_SOURCE=""
if [[ -f "$INSTALLER_DIR/statusline.sh" ]]; then
  STATUSLINE_SOURCE="$INSTALLER_DIR/statusline.sh"
elif [[ -f "./statusline.sh" ]]; then
  STATUSLINE_SOURCE="./statusline.sh"
fi

if [[ -n "$STATUSLINE_SOURCE" ]]; then
  cp "$STATUSLINE_SOURCE" "$HOME/.claude/statusline.sh"
  chmod +x "$HOME/.claude/statusline.sh"
  ok "Statusline installed (with sync indicator)"
else
  STATUSLINE_URL="https://raw.githubusercontent.com/tete-cordobes/dev-sync-tool/main/statusline.sh"
  curl -fsSL "$STATUSLINE_URL" -o "$HOME/.claude/statusline.sh"
  chmod +x "$HOME/.claude/statusline.sh"
  ok "Statusline downloaded and installed"
fi

# ===================================================================
# STEP 5: Claude Code hooks + settings
# ===================================================================
step "5/7 — Claude Code Configuration"

mkdir -p "$HOME/.claude"

# -- Hooks --
if [[ ! -f "$SETTINGS_FILE" ]]; then
  cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "outputStyle": "Tete",
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
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
SETTINGS
  ok "Created settings.json with hooks + statusline + Tete output style"
else
  # Add hooks if not present
  if jq -e '.hooks.PostToolUse' "$SETTINGS_FILE" &>/dev/null; then
    if jq -e '.hooks.PostToolUse[] | select(.hooks[]?.command | contains("dev-sync"))' "$SETTINGS_FILE" &>/dev/null; then
      ok "Dev-sync hooks already configured"
    else
      TEMP_FILE=$(mktemp)
      jq '.hooks.PostToolUse += [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync.sh\"", "timeout": 10}]}]' "$SETTINGS_FILE" > "$TEMP_FILE"
      mv "$TEMP_FILE" "$SETTINGS_FILE"
      ok "Added dev-sync PostToolUse hook"
    fi
  else
    TEMP_FILE=$(mktemp)
    jq '. + {"hooks": {"PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync.sh\"", "timeout": 10}]}], "SessionStart": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync-pull.sh\"", "timeout": 15}]}]}}' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    ok "Added hooks to settings.json"
  fi

  if ! jq -e '.hooks.SessionStart' "$SETTINGS_FILE" &>/dev/null; then
    TEMP_FILE=$(mktemp)
    jq '.hooks.SessionStart = [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/scripts/dev-sync-pull.sh\"", "timeout": 15}]}]' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    ok "Added SessionStart hook"
  fi

  # Add statusline config if not present
  if ! jq -e '.statusLine' "$SETTINGS_FILE" &>/dev/null; then
    TEMP_FILE=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 0}}' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    ok "Added statusline to settings.json"
  else
    ok "Statusline already configured in settings.json"
  fi

  # Add outputStyle if not present (NEVER overwrite existing choice)
  if ! jq -e '.outputStyle' "$SETTINGS_FILE" &>/dev/null; then
    TEMP_FILE=$(mktemp)
    jq '. + {"outputStyle": "Tete"}' "$SETTINGS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$SETTINGS_FILE"
    ok "Set output style to 'Tete' (andaluz cordobes)"
  else
    CURRENT_STYLE=$(jq -r '.outputStyle' "$SETTINGS_FILE")
    ok "Output style already set to '$CURRENT_STYLE' (not modified)"
  fi
fi

# ===================================================================
# STEP 5: Sync repo setup
# ===================================================================
step "6/7 — Sync Repo"

if [[ -d "$SYNC_REPO/.git" ]]; then
  ok "Sync repo already exists at $SYNC_REPO"
  cd "$SYNC_REPO"
  if git remote get-url origin &>/dev/null; then
    info "Pulling latest..."
    git pull --rebase 2>/dev/null || git pull 2>/dev/null || true
  fi
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
  ok "Sync repo created at $SYNC_REPO"

  # Connect to GitHub
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    echo ""
    echo -e "  ${BOLD}Create private GitHub repo for sync? (y/n)${NC}"
    read -r CREATE_REMOTE
    if [[ "$CREATE_REMOTE" == "y" || "$CREATE_REMOTE" == "Y" ]]; then
      info "Creating private repo on GitHub..."
      gh repo create dev-sync --private --source=. --push
      ok "Remote repo created and pushed!"
    fi
  else
    warn "No gh CLI or not authenticated."
    echo "  Run later:"
    echo "    cd ~/dev-sync && gh repo create dev-sync --private --source=. --push"
  fi
fi

# ===================================================================
# STEP 6: gentle-ai (Engram + SDD)
# ===================================================================
step "7/7 — Engram + SDD (via gentle-ai)"

if command -v gentle-ai &>/dev/null; then
  ok "gentle-ai already installed: $(gentle-ai version 2>/dev/null || echo 'unknown version')"
  info "Syncing components..."
  gentle-ai sync --component engram 2>/dev/null || true
  gentle-ai sync --component sdd 2>/dev/null || true
elif command -v engram &>/dev/null; then
  ok "Engram already installed: $(engram version 2>/dev/null || echo 'unknown version')"
  warn "gentle-ai not found — install it for SDD workflow"
else
  info "Installing gentle-ai (includes Engram + SDD + Skills)..."
  echo ""

  INSTALLED=false

  # Try Homebrew first
  if command -v brew &>/dev/null; then
    info "Trying Homebrew..."
    if brew tap Gentleman-Programming/homebrew-tap 2>/dev/null && \
       brew install gentle-ai 2>/dev/null; then
      INSTALLED=true
      ok "gentle-ai installed via Homebrew"
    else
      warn "Homebrew install failed, trying curl..."
    fi
  fi

  # Fallback to curl installer
  if [[ "$INSTALLED" == "false" ]]; then
    if curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh -o /tmp/gentle-ai-install.sh 2>/dev/null; then
      bash /tmp/gentle-ai-install.sh
      rm -f /tmp/gentle-ai-install.sh
      INSTALLED=true
      ok "gentle-ai installed via script"
    else
      warn "Could not download gentle-ai installer"
    fi
  fi

  if [[ "$INSTALLED" == "false" ]]; then
    warn "gentle-ai could not be installed automatically."
    echo ""
    echo "  Install manually:"
    echo "    brew tap Gentleman-Programming/homebrew-tap && brew install gentle-ai"
    echo "  Or:"
    echo "    curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh | bash"
    echo ""
  fi
fi

# Run gentle-ai setup for Claude Code if available
if command -v gentle-ai &>/dev/null; then
  echo ""
  echo -e "  ${BOLD}Run gentle-ai setup for Claude Code? (y/n)${NC}"
  echo -e "  ${DIM}(Configures Engram MCP, SDD workflow, Skills)${NC}"
  read -r SETUP_GENTLE
  if [[ "$SETUP_GENTLE" == "y" || "$SETUP_GENTLE" == "Y" ]]; then
    info "Running gentle-ai installer for Claude Code..."
    gentle-ai install --agent claude-code --preset full-gentleman 2>/dev/null || \
    gentle-ai install --agent claude-code 2>/dev/null || \
    gentle-ai 2>/dev/null || \
    warn "gentle-ai setup needs manual run: gentle-ai"
  fi
fi

# Also install engram standalone if gentle-ai didn't install it
if ! command -v engram &>/dev/null; then
  info "Installing Engram standalone..."
  if command -v brew &>/dev/null; then
    brew install gentleman-programming/tap/engram 2>/dev/null && \
      ok "Engram installed via Homebrew" || \
      warn "Engram brew install failed — install manually: brew install gentleman-programming/tap/engram"
  else
    warn "Install Engram manually: https://github.com/Gentleman-Programming/engram/releases"
  fi
fi

# ===================================================================
# Shell aliases
# ===================================================================
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
  if ! grep -q "dev-sync-restore" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'ALIASES'

# Dev-Sync aliases
alias dev-sync-restore='bash $HOME/.claude/scripts/dev-sync-restore.sh'
alias dev-sync-log='tail -20 /tmp/dev-sync.log'
alias dev-sync-status='echo "Last sync:" && stat -f "%Sm" /tmp/dev-sync.log 2>/dev/null || echo "No syncs yet"'
ALIASES
    ok "Shell aliases added (dev-sync-restore, dev-sync-log, dev-sync-status)"
  fi
fi

# ===================================================================
# DONE!
# ===================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          Installation Complete!              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Tete Style   Andaluz cordobes output style"
echo -e "  ${GREEN}✓${NC} Dev-Sync     ~/dev-sync/ + Claude Code hooks"
echo -e "  ${GREEN}✓${NC} Statusline   ~/.claude/statusline.sh (with sync indicator)"

if command -v engram &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} Engram       AI memory persistence"
else
  echo -e "  ${YELLOW}○${NC} Engram       Not installed (install manually)"
fi

if command -v gentle-ai &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} gentle-ai    SDD + Skills configured"
else
  echo -e "  ${YELLOW}○${NC} gentle-ai    Not installed (install manually)"
fi

echo ""
echo -e "  ${BOLD}How it works:${NC}"
echo -e "  1. Work with Claude Code → edits auto-sync to ~/dev-sync/"
echo -e "  2. Switch PC → open Claude Code → auto-pulls latest"
echo -e "  3. Engram remembers what Claude learned across sessions"
echo -e "  4. YOUR commits/pushes → your REAL project repo"
echo ""
echo -e "  ${BOLD}Statusline shows:${NC}"
echo -e "  Model | Dir | Git | Lines | Context | Cost | Tokens | ${CYAN}✓ sync 2m${NC}"
echo ""
echo -e "  ${BOLD}Commands:${NC}"
echo -e "  dev-sync-restore <project>   Restore project from sync"
echo -e "  dev-sync-log                 View sync activity"
echo -e "  dev-sync-status              Last sync time"
echo ""
