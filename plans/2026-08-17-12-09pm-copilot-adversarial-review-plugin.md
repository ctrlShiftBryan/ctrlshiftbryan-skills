# Copilot Adversarial Review Plugin

Design settled via 3-pass pre-batch grill interview (all decisions confirmed by Bryan).

## Goal

A Copilot counterpart of `/codex:adversarial-review`, invoked as `/copilot:adversarial-review`, packaged in this repo and installed locally from the marketplace.

## Steps

1. Create `plugins/copilot` plugin with three skills:
   - `adversarial-review` — new; full port of the codex adversarial prompt (skeptic stance, attack surface, finding bar, grounding/calibration, design-challenge framing) onto `copilot -p` mechanics: foreground only, `--model gpt-5.6-sol`, writes denied, full review-target table + weighted focus text, markdown ship/no-ship report, Claude relays full report marking confirmed vs unverified findings.
   - `review`, `implementation` — migrated from loose `~/.agents/skills/copilot-*` copies, renamed (descriptions unchanged).
2. Packaging (AGENTS.md 4 checks): `plugin.json`, `marketplace.json` entry, README table row, `npx skills` discovery check.
3. Add this checkout as a local marketplace; install `copilot` and `codex-delegation` plugins from it.
4. After verifying installs, delete the five loose `~/.agents/skills` copies (copilot-review, copilot-implementation, codex-review, codex-implementation, codex-computer-use) and their `~/.claude/skills` symlinks — the loose codex copies had drifted stale (gpt-5.5).
5. Commit straight to main.

## Outcomes

- `/copilot:adversarial-review`, `/copilot:review`, `/copilot:implementation` available from the plugin.
- Repo is the single source of truth; skill edits flow via marketplace refresh, not loose files.

## Excluded

Background execution mode, JSON output, companion script, changes to the openai codex plugin.
