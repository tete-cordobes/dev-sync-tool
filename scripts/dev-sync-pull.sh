#!/bin/bash
# dev-sync-pull.sh - Auto-pull sync repo on Claude Code session start
# Pulls latest and restores files to the current project

set -euo pipefail

SYNC_REPO="$HOME/dev-sync"
PULL_MARKER="/tmp/dev-sync-last-pull"

# Bail if sync repo not set up
if [[ ! -d "$SYNC_REPO/.git" ]]; then
  exit 0
fi

# Only pull if we haven't pulled in the last 60 seconds
if [[ -f "$PULL_MARKER" ]]; then
  LAST_PULL=$(cat "$PULL_MARKER" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_PULL))
  if [[ $DIFF -lt 60 ]]; then
    exit 0
  fi
fi

# Pull and restore in background
(
  cd "$SYNC_REPO"
  git pull --rebase --quiet 2>/dev/null || git pull --quiet 2>/dev/null || true
  date +%s > "$PULL_MARKER"

  # If we're in a project that exists in sync, restore changed files
  CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  if [[ -d "$CWD/.git" ]]; then
    PROJECT_NAME=$(basename "$(cd "$CWD" && git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")")
    SYNC_PROJECT="$SYNC_REPO/$PROJECT_NAME"
    if [[ -d "$SYNC_PROJECT" ]]; then
      rsync -au \
        --exclude='.git/' \
        --exclude='.gitignore' \
        --exclude='node_modules/' \
        --exclude='.next/' \
        --exclude='dist/' \
        --exclude='build/' \
        --exclude='venv/' \
        --exclude='.venv/' \
        --exclude='__pycache__/' \
        --exclude='Pods/' \
        --exclude='DerivedData/' \
        "$SYNC_PROJECT/" "$CWD/" 2>/dev/null || true
    fi
  fi
) &>/dev/null &

exit 0
