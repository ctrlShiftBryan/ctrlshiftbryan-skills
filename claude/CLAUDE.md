# Personal Preferences

## TypeScript

- Never use `any` unless 100% necessary or specifically instructed.

## Commands

- Don't run dev server commands (e.g., `bun run dev`) — assume it's already running.
- Don't run build commands unless specifically told to.
- Focus on checking commands like `bun run typecheck`, `bun run lint`, etc.

## Code Style

- Always strive for concise, simple solutions.
- If a problem can be solved in a simpler way, propose it.

## General preferences

- If asked to do too much work at once, stop and state that clearly.
- If computer use is helpful for completing or verifying work, shell out to gpt-5.5 with Codex for it

## Picking the right models for workflows and subagents

Rankings, higher = better — including affordability (9 = nearly free, 1 = priciest). Affordability reflects what I actually pay (OpenAI has really generous limits), not list price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model    | affordability        | intelligence | taste |
| -------- | -------------------- | ------------ | ----- |
| gpt-5.5  | 9 (effectively free) | 8            | 5     |
| sonnet-5 | 5                    | 5            | 7     |
| opus-4.8 | 4                    | 7            | 8     |
| fable-5  | 2 (priciest)         | 9            | 9     |

How to apply:

- **Always set `model` explicitly on every `Agent` call and every workflow `agent()` call.** Omitting it silently inherits the session model — that is a default, not a decision. If inheriting is right, say so in one clause ("inherits opus-4.8; parity transcription needs intelligence ≥ 7 and this is the cheapest model that clears it").
- Meet the bar, then buy the cheapest model that clears it. Escalate past that only when the output misses the bar, or when the work is hard to verify after the fact. Easy-to-verify work (tests that go red/green, migrations with a diff to read) can go cheap — a bad result announces itself. Hard-to-verify work (visual rendering, API shape, copy) is where the expensive model earns its money, because typecheck and green tests will happily stay green while it's wrong.
- These are defaults, not limits. You have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Don't let cost prevent you from using the right model for the job. Instead, take advantage of cheaper options to get more information and try things before moving the work to a more expensive option.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt-5.5 — it's effectively free.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans/implementations: fable-5 or opus-4.8, optionally gpt-5.5 as an extra independent perspective.
- Mechanics: gpt-5.5 is only reachable through the Codex CLI — `codex exec` / `codex review` (my ~/.codex/config.toml defaults to gpt-5.5). Use the codex-implementation, codex-review, and codex-computer-use skills; for work they don't cover (investigation, data analysis), run `codex exec -s read-only` directly with a self-contained prompt.
- Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent/Workflow model parameter.

Using gpt-5.5 inside workflows and subagents (the model parameter only takes Claude models, so use a wrapper):

- Spawn a thin Claude wrapper agent with `model: 'sonnet', effort: 'low'` whose prompt instructs it to write a self-contained codex prompt, run `codex exec` via Bash, and return the report (use `schema` on the wrapper to get structured output back).
- Always label these agents with a `gpt-5.5:` prefix, e.g. `{label: 'gpt-5.5:review-auth'}`; the workflow UI shows the wrapper's Claude model, so the label is the only indication the real worker is gpt-5.5.
- Codex runs can exceed Bash's 10-minute timeout: pass an explicit timeout, or run in the background and poll for the report file.
- Parallel gpt-5.5 implementation agents must use `isolation: 'worktree'` so codex edits don't collide in the shared checkout.
- Workflow token budgets only count Claude tokens; codex work is free and invisible to `budget.spent()`.

# Important

In all interactions and commit messages, be extremely concise and sacrifice grammar for the sake of concision.

# Who I Am

my name is bryan

my github username is ctrlshiftbryan

## Portable Paths

Never use hardcoded usernames or absolute home paths (e.g. `/Users/bryanarendt/`) in config files like `settings.json`. Always use `~` or `$HOME` so configs work across machines with different usernames.

## Asking Questions

Never use the AskUserQuestion tool. Ask in normal chat. One question at a time — no multi-part questions, no questions with multi-part answers. Wait for the answer before asking the next.
