# adversarial-review

A prompt-only skill for reviewing the current branch against `main` with a skeptical
ship/no-ship stance. It uses open pull request information from GitHub when available.

## Skills

| Skill | What it does |
|---|---|
| `adversarial-review` | Reviews the committed branch diff against `main`, checks open pull requests for the branch with `gh`, and attacks the approach, design, and assumptions rather than scanning for ordinary defects. |
