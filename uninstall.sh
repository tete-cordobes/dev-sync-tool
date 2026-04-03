#!/bin/bash
# dev-sync uninstaller

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${RED}Dev-Sync Uninstaller${NC}"
echo ""
echo "This will remove:"
echo "  - Scripts from ~/.claude/scripts/dev-sync*.sh"
echo "  - Hooks from ~/.claude/settings.json"
echo "  - Shell aliases"
echo ""
echo "This will NOT remove:"
echo "  - ~/dev-sync/ repo (your synced data)"
echo ""
echo -e "${YELLOW}Continue? (y/n)${NC}"
read -r CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

# Remove scripts
rm -f "$HOME/.claude/scripts/dev-sync.sh"
rm -f "$HOME/.claude/scripts/dev-sync-pull.sh"
rm -f "$HOME/.claude/scripts/dev-sync-restore.sh"
echo -e "${GREEN}[OK]${NC} Scripts removed"

# Remove hooks from settings.json
SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null; then
  TEMP=$(mktemp)
  jq '
    .hooks.PostToolUse = [.hooks.PostToolUse[]? | select(.hooks[]?.command | contains("dev-sync") | not)] |
    .hooks.SessionStart = [.hooks.SessionStart[]? | select(.hooks[]?.command | contains("dev-sync") | not)] |
    if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end |
    if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end |
    if (.hooks | length) == 0 then del(.hooks) else . end
  ' "$SETTINGS" > "$TEMP"
  mv "$TEMP" "$SETTINGS"
  echo -e "${GREEN}[OK]${NC} Hooks removed from settings.json"
fi

# Remove shell aliases (cross-platform sed -i)
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]]; then
    if sed --version &>/dev/null 2>&1; then
      # GNU sed (Linux)
      sed -i '/dev-sync-restore/d; /dev-sync-log/d; /dev-sync-status/d; /Dev-Sync/d' "$rc"
    else
      # BSD sed (macOS)
      sed -i '' '/dev-sync-restore/d; /dev-sync-log/d; /dev-sync-status/d; /Dev-Sync/d' "$rc"
    fi
  fi
done
echo -e "${GREEN}[OK]${NC} Shell aliases removed"

# Cleanup temp files
rm -rf /tmp/dev-sync.lock /tmp/dev-sync.log /tmp/dev-sync-last-pull

echo ""
echo -e "${GREEN}Done!${NC} Dev-sync removed."
echo "Your ~/dev-sync/ repo is still intact if you need your data."
echo ""
