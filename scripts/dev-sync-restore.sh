#!/bin/bash
# dev-sync-restore.sh - Manually restore a project from the sync repo

set -euo pipefail

SYNC_REPO="$HOME/dev-sync"

usage() {
  echo "Usage: dev-sync-restore.sh [project-name] [target-dir]"
  echo ""
  echo "  project-name  Name of the project folder in ~/dev-sync/"
  echo "  target-dir    Where to restore (default: ./<project-name>)"
  echo ""
  echo "Examples:"
  echo "  dev-sync-restore.sh my-app ~/projects/my-app"
  echo "  dev-sync-restore.sh my-app  # restores to ./my-app"
  echo ""
  echo "Available projects:"
  for dir in "$SYNC_REPO"/*/; do
    [[ -d "$dir" ]] && echo "  - $(basename "$dir")"
  done
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

PROJECT_NAME="$1"
SOURCE_DIR="$SYNC_REPO/$PROJECT_NAME"
TARGET_DIR="${2:-$(pwd)/$PROJECT_NAME}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "[ERROR] Project '$PROJECT_NAME' not found in $SYNC_REPO"
  echo ""
  usage
  exit 1
fi

echo "[*] Pulling latest from remote..."
cd "$SYNC_REPO"
git pull --rebase 2>/dev/null || git pull || true

echo "[*] Restoring $PROJECT_NAME -> $TARGET_DIR"
mkdir -p "$TARGET_DIR"
rsync -av --exclude='.git/' --exclude='.gitignore' "$SOURCE_DIR/" "$TARGET_DIR/"

echo ""
echo "[OK] Done! Files restored to $TARGET_DIR"
