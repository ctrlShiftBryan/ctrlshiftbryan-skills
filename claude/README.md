# claude/

Versioned copies of my global `~/.claude/` config.

- `CLAUDE.md` — global instructions for all projects
- `statusline.sh` — custom status bar script

## Status bar

Shows: `dir:branch │ Model │ ctx% │ $cost │ in:tokens out:tokens │ session-time api:time`

- Context % is colored green (<50%), yellow (<75%), red (≥75%)
- Handles git worktrees — always shows the main worktree's name

### Setup

Requires `jq` and `bc` (both preinstalled on macOS; `brew install jq` if missing).

1. Copy the script:

   ```bash
   cp claude/statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

3. Restart Claude Code (or start a new session).

The script optionally pipes session JSON to `~/.claude/hooks/capture-session-metrics.js` for metrics logging — that hook is not included here and the script skips it if absent.
