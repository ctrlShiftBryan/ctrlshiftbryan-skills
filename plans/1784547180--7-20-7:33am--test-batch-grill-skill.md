# Test Batch Grill Me HTML

## Context and assumptions

- Evaluate the newly created `batch-grill-me-html` skill against independent no-skill baselines.
- Focus on the first interview round because later rounds require human answers and are best assessed after the initial artifact works.
- Use two realistic architecture scenarios with known facts and dependent decisions.
- Run comparisons in paired batches because the workspace permits only three concurrent workers in addition to the primary session.

## Test phases

1. Define account-recovery and job-retry evaluation prompts.
2. Run each prompt once with the skill and once without it.
3. Grade generated artifacts against objective behavioral and HTML requirements.
4. Aggregate pass rates, timing, and output patterns.
5. Generate the skill-creator HTML review artifact for Bryan's qualitative feedback.

## Expected outcomes

- The skill produces a first-round HTML decision frontier rather than implementing the design.
- Every question is single- or multi-choice, has valid recommendations, an `Other` option, and an additional-comment box.
- The form includes Plannotator injection and a top-level **Copy prompt** interaction.
- The skill avoids asking for facts already supplied and defers decisions whose prerequisites remain unsettled.
