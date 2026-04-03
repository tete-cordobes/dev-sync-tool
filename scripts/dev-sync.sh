#!/bin/bash
# dev-sync.sh - Auto-sync hook for Claude Code
# Mirrors edited files to a central sync repo (like Google Drive for code)
# Called by Claude Code PostToolUse hook on Edit/Write

set -euo pipefail

SYNC_REPO="$HOME/dev-sync"
LOCK_FILE="/tmp/dev-sync.lock"
LOG_FILE="/tmp/dev-sync.log"

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Bail if no file path
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Bail if sync repo not set up
if [[ ! -d "$SYNC_REPO/.git" ]]; then
  exit 0
fi

# Skip files inside the sync repo itself (avoid loops)
if [[ "$FILE_PATH" == "$SYNC_REPO"* ]]; then
  exit 0
fi

# Skip sensitive files
case "$FILE_PATH" in
  *.env|*.env.*|*credentials*|*secret*|*.pem|*.key|*id_rsa*)
    exit 0
    ;;
esac

# Determine project root (nearest .git or fallback to parent dir)
PROJECT_ROOT=$(cd "$(dirname "$FILE_PATH")" && git rev-parse --show-toplevel 2>/dev/null || echo "")

if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(dirname "$FILE_PATH")"
  PROJECT_NAME="__standalone"
else
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
fi

# Relative path within project
REL_PATH="${FILE_PATH#$PROJECT_ROOT/}"

# Target in sync repo
TARGET_DIR="$SYNC_REPO/$PROJECT_NAME/$(dirname "$REL_PATH")"
mkdir -p "$TARGET_DIR"

# Copy the file
cp "$FILE_PATH" "$SYNC_REPO/$PROJECT_NAME/$REL_PATH"

# Also sync the project's .gitignore if it exists
if [[ -f "$PROJECT_ROOT/.gitignore" ]]; then
  cp "$PROJECT_ROOT/.gitignore" "$SYNC_REPO/$PROJECT_NAME/.gitignore" 2>/dev/null || true
fi

# Auto-commit and push in background (non-blocking)
(
  # Simple lock to avoid concurrent git operations
  if [[ -f "$LOCK_FILE" ]]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
      exit 0
    fi
  fi
  echo $$ > "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT

  cd "$SYNC_REPO"

  # Small delay to batch rapid consecutive edits
  sleep 2

  git add -A
  if ! git diff --cached --quiet 2>/dev/null; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    git commit -m "sync: $PROJECT_NAME ($TIMESTAMP)" >> "$LOG_FILE" 2>&1
    git push >> "$LOG_FILE" 2>&1 || true
  fi
) &>/dev/null &

exit 0
