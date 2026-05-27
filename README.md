# ctrlshiftbryan-skills

Bryan's personal Claude Code plugins and skills.

## Plugins

| Plugin | Description |
|---|---|
| [`ralph`](plugins/ralph) | Install and run the Ralph Wiggum agentic loop (claude/codex) in any project. |
| [`manual-chrome-review`](plugins/manual-chrome-review) | Verify a running web app in a real Chrome session — user drives keyboard/mouse, Claude inspects DOM/network/WebSocket/server state. |
| [`pr-review-html`](plugins/pr-review-html) | Generate a single-file interactive HTML code-review artifact for a GitHub PR. |
| [`review-address`](plugins/review-address) | Reply to every PR review comment (GitHub Copilot, bots, humans) with code fixes or reasoned push-backs. |
| [`figma-fetcher`](plugins/figma-fetcher) | Auto-delegating Haiku sub-agent that offloads Figma MCP read calls out of the main conversation, caching design payloads to `tmp/figma/`. |

## Install

### Claude Code (full plugin — commands + skill + agent)

```
/plugin marketplace add ctrlShiftBryan/ctrlshiftbryan-skills
/plugin install ralph@ctrlshiftbryan-skills
```

### skills.sh (skill only — natural-language trigger)

```
npx skills add ctrlShiftBryan/ctrlshiftbryan-skills
```

## Layout

```
ctrlshiftbryan-skills/
├── .claude-plugin/
│   └── marketplace.json     ← marketplace listing
└── plugins/
    └── ralph/
        ├── .claude-plugin/plugin.json
        ├── commands/        ← /ralph:install, /ralph:once, /ralph:afk
        ├── skills/          ← install-ralph (natural-language trigger)
        ├── agents/          ← ralph-runner subagent
        ├── assets/          ← scripts + templates copied into target projects
        └── scripts/         ← install.sh
```

## Adding new plugins

1. `mkdir -p plugins/<name>/.claude-plugin && cd plugins/<name>`
2. Write `.claude-plugin/plugin.json` (name, version, description, author).
3. Add `commands/`, `skills/`, `agents/`, `scripts/`, `assets/` as needed.
4. Add an entry to `.claude-plugin/marketplace.json` under `plugins[]`.
