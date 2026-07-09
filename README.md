# ctrlshiftbryan-skills

Bryan's personal Claude Code plugins and skills.

## Plugins

| Plugin | Components | Description |
|---|---|---|
| [`ralph`](plugins/ralph) | commands · skill · agent | Install and run the Ralph Wiggum agentic loop (claude/codex) in any project — adds `once.sh`/`afk.sh`, package scripts, and prompt/state scaffolding. |
| [`manual-chrome-review`](plugins/manual-chrome-review) | skill | Verify a running web app in a real Chrome session — user drives keyboard/mouse, Claude inspects DOM/network/WebSocket/server state. |
| [`pr-review-html`](plugins/pr-review-html) | skill | Generate a single-file interactive HTML code-review artifact for a GitHub PR (collapsible diffs, severity chips, per-finding checkboxes, feedback-prompt builder). |
| [`review-address`](plugins/review-address) | skill | Reply to every PR review comment (GitHub Copilot, bots, humans) with code fixes or reasoned push-backs, committing and posting an inline reply to each. |
| [`figma-fetcher`](plugins/figma-fetcher) | agent | Auto-delegating Haiku sub-agent that offloads Figma MCP read calls out of the main conversation, caching design payloads to `tmp/figma/`. Read-only. |
| [`pr-explainer`](plugins/pr-explainer) | command · skill | Install the AI PR-explainer GitHub Action into a repo — nag workflow + check/publish scripts, an orphan `ai-docs` branch, GitHub Pages, and a sticky 🔴/🟡/🟢 'explainer' comment + status gate linking an AI HTML walkthrough. |
| [`post-review-as-bot`](plugins/post-review-as-bot) | skill | Post a code review to a GitHub PR as inline comments attributed to a GitHub App `[bot]` account — mints an installation token, validates comments against the diff, submits one atomic review. |
| [`codex-delegation`](plugins/codex-delegation) | skills ×3 | Delegate work to Codex CLI (gpt-5.5) — `codex-implementation` (scoped changes via `codex exec`), `codex-review` (independent diff review), `codex-computer-use` (browser/simulator/screenshot verification). |

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
