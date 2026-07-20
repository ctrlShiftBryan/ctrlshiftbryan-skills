# Tighten Frontier and Handoff

## Context and assumptions

- Iteration 1 scored 7/8 in both with-skill evaluations.
- The account-recovery run violated frontier dependencies by asking downstream decisions in the same round as their prerequisites.
- The job-retry run omitted an explicit instruction to paste the copied prompt back into chat.
- Reuse the same evaluation prompts so iteration 2 measures the targeted revision rather than a different task mix.
- Compare the adjusted skill against a snapshot of the iteration-1 skill.

## Implementation phases

1. Require stable prerequisite IDs on every decision and enforce that a frontier contains only nodes whose prerequisites are settled before the round.
2. Add a pairwise dependency audit that defers any question whose wording or options could change based on another question in the same round.
3. Add a visible paste-back instruction to the HTML and a required final-response handoff template to the skill.
4. Run the account-recovery and job-retry evaluations against both the adjusted and snapshotted skills.
5. Grade, aggregate, and generate a safe static iteration-2 review artifact with iteration-1 outputs available for comparison.

## Expected outcomes

- Account recovery asks only true root decisions in its first round.
- Job retry explicitly tells the user to click **Copy prompt** and paste the result back into chat.
- Existing HTML requirements continue to pass without regression.
- Iteration 2 improves from 7/8 to 8/8 on both scenarios.
