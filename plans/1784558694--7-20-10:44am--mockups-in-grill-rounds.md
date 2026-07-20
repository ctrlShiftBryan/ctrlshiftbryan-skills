# Add visual/interactive HTML mockups to batch-grill-me-html rounds

Real-world feedback: rounds are text-only. Visual decisions (screen layouts, widget designs) are underdescribed by option labels. Add optional inline HTML mockups.

## Design

1. **Schema** — two optional `mockup` fields, both `{ html, height?, caption? }`:
   - question-level: rendered between context and options; shows the current state or the frame being decided
   - option-level: rendered inside the option card; shows each candidate concretely (visual A/B/C)
2. **Rendering** — sandboxed iframe (`sandbox="allow-scripts"`, srcdoc set programmatically). Mockup JS runs but is origin-isolated from the form; clicks inside a mockup cannot select the option (selection stays on the radio/checkbox). Height clamped 60–720px, default 180.
3. **Encoding** — mockup HTML rides inside `__QUESTIONS_JSON__`; serialize with `<`, `>`, `&` escaped as `\u003c` / `\u003e` / `\u0026` so literal `</script>` can never terminate the inline script.
4. **Prompt** — unchanged; labels must still stand alone in the copied text prompt.
5. **Skill guidance** — when to attach mockups (visual/spatial decisions only), self-contained (inline CSS/JS, no external requests, must work from file://), lightweight, representative not pixel-perfect.
6. **Runtime validation** — template throws if a `mockup` lacks a string `html`.

## Steps

1. Extend `assets/round.html`: CSS, validation, mockup iframe renderer for both levels.
2. Extend `SKILL.md`: schema docs, "Visual mockups" guidance, encoding rule.
3. Hand-build a sample round with question- and option-level mockups; verify in Chrome (render, isolation, copy prompt, console clean).
4. Add a visual-scenario eval to `evals/evals.json`; run one fresh with-skill agent (iteration-4) and grade.
5. Bump plugin to 0.2.0; update plugin README, root README row, marketplace entry.

## Outcome

Rounds can show screen/widget mockups per question or per option without weakening the text paste-back contract or the script-safety rules.
