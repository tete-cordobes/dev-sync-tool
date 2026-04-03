# Dev-Sync

**Google Drive for your code.** Auto-syncs everything you do in Claude Code to a central GitHub repo so you can seamlessly continue on another machine.

## What it does

```
MACHINE A                              MACHINE B
─────────                              ─────────
Work with Claude Code                  
  ↓ (silent hook)                      
~/dev-sync/ ← auto-commit + push      
                                       Open Claude Code
                                         ↓ (SessionStart hook)
                                       ~/dev-sync/ ← auto-pull + restore
                                       Continue working seamlessly
```

- **Every file edit** is silently mirrored to `~/dev-sync/<project>/`
- **Auto-commits and pushes** in the background (non-blocking)
- **Auto-pulls on startup** when you open Claude Code on another machine
- **Your real commits** go to your actual project repo — dev-sync is just a transparent draft layer

## Install

```bash
# Clone and run
git clone https://github.com/tete-cordobes/dev-sync-tool.git /tmp/dev-sync-tool
bash /tmp/dev-sync-tool/install.sh
```

Or if you already have it locally:

```bash
cd dev-sync-tool
bash install.sh
```

The installer will:
1. Install sync scripts to `~/.claude/scripts/`
2. Add hooks to `~/.claude/settings.json`
3. Create the `~/dev-sync/` mirror repo
4. Optionally create a private GitHub repo via `gh`

## How it works

### Claude Code Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `PostToolUse` | After every `Edit` / `Write` | Copies file to sync repo, commits, pushes |
| `SessionStart` | When Claude Code starts | Pulls latest from sync repo, restores to project |

### Sync repo structure

```
~/dev-sync/
├── .gitignore          # Excludes node_modules, build, secrets, etc.
├── project-alpha/      # Mirror of ~/projects/project-alpha
├── project-beta/       # Mirror of ~/projects/project-beta
└── ...
```

### What gets synced

| Synced | Not synced |
|--------|------------|
| Source code files | `node_modules/`, `vendor/`, `.venv/` |
| Config files | Build outputs (`dist/`, `build/`, `.next/`) |
| Project `.gitignore` | Secrets (`.env`, `*.pem`, `*.key`) |
| | Large binaries (`.zip`, `.dmg`, `.mp4`) |

### Safety

- **Secrets are excluded** — `.env`, credentials, keys are never synced
- **Non-blocking** — sync runs in the background, never slows down your work
- **Lock mechanism** — prevents concurrent git operations
- **Loop prevention** — edits inside `~/dev-sync/` are ignored
- **Batching** — 2-second delay batches rapid consecutive edits

## Commands

```bash
# Manually restore a project on the other machine
dev-sync-restore my-project ~/projects/my-project

# View sync activity
dev-sync-log
```

## Complementary tools

Dev-sync handles **file synchronization**. For **AI memory synchronization** (so Claude remembers what it learned about your project across machines), check out [Engram](https://github.com/Gentleman-Programming/engram).

| Tool | Syncs | Purpose |
|------|-------|---------|
| **Dev-Sync** | Code files | Same code on both machines |
| **Engram** | Agent memory | Claude knows what it did on the other machine |

## Uninstall

```bash
bash uninstall.sh
```

Removes scripts, hooks, and aliases. Your `~/dev-sync/` data is preserved.

## Requirements

- macOS or Linux
- `git`, `jq`, `rsync`
- Claude Code with hooks support
- GitHub account (for remote sync)

## License

MIT
