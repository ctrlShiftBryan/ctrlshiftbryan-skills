# ctrlshiftbryan-skills

Bryan's personal Claude Code plugins and skills.

## Plugins

| Plugin | Description |
|---|---|
| [`ralph`](plugins/ralph) | Install and run the Ralph Wiggum agentic loop (claude/codex) in any project. |

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
