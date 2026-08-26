# Copilot Adversarial Review Plugin

Design settled via 3-pass pre-batch grill interview (all decisions confirmed by Bryan).

## Goal

A Copilot-driven adversarial review, invoked as `/copilot:copilot-adversarial-review`, packaged in this repo and installed locally from the marketplace.

## Steps

1. Create `plugins/copilot` plugin with three skills:
   - `copilot-adversarial-review` — new; self-contained adversarial prompt with a skeptic stance, attack surface, finding bar, grounding, and design-challenge framing. It runs through `copilot -p` in the foreground with writes denied, supports every review target plus weighted focus text, and returns a markdown ship/no-ship report for verification.
   - `review`, `implementation` — migrated from loose `~/.agents/skills/copilot-*` copies, renamed (descriptions unchanged).
2. Packaging (AGENTS.md 4 checks): `plugin.json`, `marketplace.json` entry, README table row, `npx skills` discovery check.
3. Add this checkout as a local marketplace; install `copilot` and `codex-delegation` plugins from it.
4. After verifying installs, delete the five loose `~/.agents/skills` copies (copilot-review, copilot-implementation, codex-review, codex-implementation, codex-computer-use) and their `~/.claude/skills` symlinks — the loose codex copies had drifted stale (gpt-5.5).
5. Commit straight to main.

## Outcomes

- `/copilot:copilot-adversarial-review`, `/copilot:review`, `/copilot:implementation` available from the plugin.
- Repo is the single source of truth; skill edits flow via marketplace refresh, not loose files.

## Excluded

Background execution mode, JSON output, companion script, changes to the openai codex plugin.
