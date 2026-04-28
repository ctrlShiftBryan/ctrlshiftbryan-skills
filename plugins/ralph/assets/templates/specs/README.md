# specs/

Stable end-state specs that describe what "done" looks like.

Specs are authoritative for *what* to build. `fix_plan.md` orders the *order*
to build it in. `AGENT.md` lists *how* to verify it.

Keep each spec short (~30–60 lines). One concern per file:

- `01-architecture.md` — module layout, data flow, key abstractions
- `02-<core-feature>.md` — happy path + edge cases for the main feature
- `03-<integration>.md` — external services, auth, network boundary
- `04-<persistence>.md` — what's stored where, migration rules

Specs change less often than the codebase. If Ralph finds a spec is wrong,
it should fix the spec in the same commit as the code and explain why in the
commit body.

> **TODO**: replace this README with your actual specs.
