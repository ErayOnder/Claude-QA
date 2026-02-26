# /qa — Run the Claude-QA Pipeline

Trigger the full QA analysis pipeline on the current branch's pull request.

## What to Do

1. **Detect the PR** — Run `gh pr view --json number -q .number` to get the
   current branch's PR number. If there is no open PR, tell the user and stop.

2. **Run the Analyzer** — Invoke the `analyzer` agent to analyze the PR diff.
   Pass the PR number as context. The analyzer will fetch the diff itself and
   produce a structured JSON analysis.

   Store the analyzer output in `.claude-qa-output/analysis.json`.

3. **Display the results** — Print a human-readable summary of the analysis:
   - PR title and number
   - Risk level (with color: LOW=green, MEDIUM=yellow, HIGH=orange, CRITICAL=red)
   - One-line summary
   - Top impact areas
   - Recommended testing types

4. **Post to PR (if configured)** — If `qa.config.yml` has `reporting.post_comment: true`,
   run `scripts/post-report.sh` to post the analysis as a PR comment.

## Future Stages (not yet implemented)

Once the planner, executor, and reporter agents are built, this command
will chain all four stages:

```
analyzer → planner → executor → reporter
```

For now, it runs only the analyzer stage.

## Output Directory

Create `.claude-qa-output/` in the project root if it doesn't exist.
All intermediate and final outputs go here:

- `analysis.json` — analyzer output
- `test-plan.json` — planner output (future)
- `results.json` — executor output (future)
- `report.md` — reporter output (future)
