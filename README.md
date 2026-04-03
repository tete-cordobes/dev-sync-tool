# Dev-Sync Tool

**Google Drive for your code + AI memory.** Everything you need to work seamlessly across multiple machines with Claude Code.

## What's included

| Component | What it does |
|-----------|-------------|
| **Dev-Sync** | Auto-mirrors code files to a central repo (like Google Drive) |
| **Statusline** | Custom Claude Code status bar with sync indicator |
| **Engram** | Persistent AI memory across sessions (via [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai)) |
| **SDD** | Spec-Driven Development workflow for complex features |

## How it works

```
MACHINE A                              MACHINE B
─────────                              ─────────
Work with Claude Code                  
  ↓ (silent hook)                      
~/dev-sync/ ← auto-commit + push      
  + Engram saves AI memory             
                                       Open Claude Code
                                         ↓ (SessionStart hook)
                                       ~/dev-sync/ ← auto-pull + restore
                                         + Engram loads AI memory
                                       Continue working seamlessly
```

Your **real commits** go to your actual project repo when YOU say so. Dev-sync is a transparent draft layer.

## Install

```bash
git clone https://github.com/tete-cordobes/dev-sync-tool.git /tmp/dev-sync-tool
bash /tmp/dev-sync-tool/install.sh
```

The installer will:
1. Install sync scripts + Claude Code hooks
2. Install custom statusline with sync indicator
3. Create `~/dev-sync/` mirror repo (+ optional GitHub private repo)
4. Install gentle-ai (Engram + SDD + Skills)

## Statusline

Custom two-line status bar for Claude Code:

```
🎭 Opus 4.6 (1M context) Tete I ⟡project 📁dir  branch*  +28 -28
ctx ████ 26% $9.44 ↓76 ↑13.8k 32t/s 5h 7%→2h48m 7d 12%  ✓ sync 2m
```

### Sync indicator (rightmost element, line 2)

| Status | Meaning |
|--------|---------|
| `✓ sync 30s` (green) | Synced less than 1 minute ago |
| `✓ sync 5m` (green) | Synced minutes ago |
| `⚠ sync 2h` (yellow) | Last sync was hours ago |
| `✗ sync 1d` (red) | Last sync was days ago |
| `⟳ syncing` (cyan) | Sync in progress |

## Claude Code Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `PostToolUse` | After every `Edit` / `Write` | Copies file → sync repo → commit → push |
| `SessionStart` | When Claude Code opens | Pulls sync repo → restores files to project |

## Sync repo structure

```
~/dev-sync/
├── .gitignore          # Excludes node_modules, build, secrets, etc.
├── project-alpha/      # Mirror of project-alpha
├── project-beta/       # Mirror of project-beta
└── ...
```

## Safety

- **Secrets excluded** — `.env`, credentials, keys are never synced
- **Non-blocking** — sync runs in background
- **Lock mechanism** — prevents concurrent git operations
- **Loop prevention** — edits inside `~/dev-sync/` are ignored
- **Batching** — 2-second delay batches rapid edits

## Commands

```bash
dev-sync-restore <project> [target]   # Restore project from sync
dev-sync-log                          # View sync activity
dev-sync-status                       # Last sync time
```

## Uninstall

```bash
bash uninstall.sh
```

Removes scripts, hooks, aliases. Your `~/dev-sync/` data is preserved.

## Requirements

- macOS or Linux
- `git`, `jq`, `rsync`
- Claude Code with hooks support
- GitHub account (for remote sync)

## License

MIT
