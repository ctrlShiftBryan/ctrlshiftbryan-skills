---
name: questionnaire
description: Batch 3+ clarifying questions into a local HTML questionnaire with pre-checked recommended answers, per-question comment boxes, and a "Copy prompt" button that serializes everything into one paste-back prompt. Use whenever you are about to ask the user several questions at once — during planning, grilling, requirements gathering, spec refinement, or when the user says "what do you need to know?", "any questions?", "ask me your questions", or asks for a questionnaire/form. If you have 1-2 questions, ask in chat one per turn instead; at ~3+ open questions, stop asking serially and build the form.
---

# Questionnaire

Asking many questions in one chat message forces the user to juggle several decision threads at once; asking them one per turn is slow. This skill resolves that tension: few questions go in chat, many go in a single local HTML form the user fills at their own pace and pastes back as one prompt.

## Decision rule

- **1–2 questions**: ask in chat, one question per turn, each with concrete options and a recommendation. Never multi-part questions, never the AskUserQuestion tool.
- **3+ open questions**: build the questionnaire. It's fine to ask the first question or two in chat and then batch the remainder once it's clear several more are coming.

## Building the form

1. Draft the questions. For each one:
   - Write the question and (optionally) 1–2 sentences of context explaining why it matters.
   - List concrete options with a short `detail` explaining the tradeoff.
   - Mark exactly the option(s) you'd recommend with `"recommended": true` — the form pre-checks them, so a user who agrees with all your recommendations can just click "Copy prompt" and be done. Always have a recommendation unless the question is genuinely a coin flip.
   - Pick a type: `"single"` (radio), `"multi"` (checkbox), or `"text"` (freeform only). Single/multi questions automatically get an "Other" free-text option and a per-question comment box — don't add your own.

2. Read `assets/questionnaire.html` from this skill's directory and replace:
   - `__TITLE__` (both occurrences) — short form title, e.g. "Auth rework — 6 questions"
   - `__QUESTIONS_JSON__` — a JSON array like:

   ```json
   [
     {
       "question": "Which auth method should the API use?",
       "context": "Affects mobile client work and session revocation.",
       "type": "single",
       "options": [
         {"label": "JWT access + refresh tokens", "detail": "Stateless, more client code", "recommended": true},
         {"label": "Server-side sessions", "detail": "Easy revocation, needs sticky store"}
       ]
     },
     {
       "question": "Anything else I should know before starting?",
       "type": "text"
     }
   ]
   ```

   Avoid the literal string `</script>` inside question text — it would break the inline script tag.

3. Write the filled file to `/tmp/questionnaire-<slug>.html` and open it (`open` on macOS, `xdg-open` on Linux).

4. End your turn with a one-liner: the form is open in the browser; fill it out, hit **Copy prompt**, and paste the result back here. Do not keep asking questions in chat while the form is pending.

## Handling the paste-back

The pasted prompt lists each question with the chosen answer and optional `Note:` lines. Treat notes as authoritative — if a note contradicts the checked option, the note wins (ask a quick follow-up in chat only if genuinely ambiguous). `(no answer)` means the user skipped it; use your recommendation and say so.
