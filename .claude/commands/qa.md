---
name: qa
description: >
  Run the full Claude-QA pipeline on the current pull request.
  Analyzes the diff, generates a test plan, executes browser tests,
  and posts a report to the PR. Use this to trigger QA manually from Claude Code.
allowed-tools: Bash(gh *), Bash(cat *), Bash(find *), Bash(grep *), Bash(mkdir *), Read, Glob
---

# /qa — Run the Claude-QA Pipeline

Run the complete QA pipeline for the current pull request.

## What This Does

1. **Analyzes** the PR diff using the `analyzer` agent
2. **Saves** the analysis and test plan to `.claude-qa-output/`
3. **Hands off** to the `executor` agent to run browser tests
4. **Generates** a structured QA report via the `reporter` agent
5. **Posts** the report as a PR comment (if `--comment` flag provided)

## Usage

```
/qa                  # Run full pipeline, output to terminal
/qa --comment        # Run + post report to PR
/qa --plan-only      # Only analyze and generate test plan (no execution)
/qa --pr 42          # Run on a specific PR number
```

## Arguments: $ARGUMENTS

---

## Pipeline Execution

Parse arguments from: $ARGUMENTS

- If `--pr NUMBER` provided, set PR_NUMBER=NUMBER; otherwise use current branch PR
- If `--plan-only` provided, stop after Step 1 and display the test plan
- If `--comment` provided, post the final report to the PR

First, create the output directory if it doesn't exist:
```bash
mkdir -p .claude-qa-output
```

### Step 1: Run the Analyzer Agent

Launch the `analyzer` subagent to analyze the PR and produce a test plan.

Pass it:
- The PR context (fetched via `gh pr view` and `gh pr diff`)
- The path to `qa.config.yml`
- The PR number (from args or current branch)

Wait for the analyzer to complete and save its JSON output to `.claude-qa-output/analysis.json`.

If the analyzer returns `{"skip": true}`, output the skip reason and stop here gracefully.

Display the test plan summary to the user:
```
Test Plan Generated
   PR #XX: [title]
   Risk Level: [LEVEL] ([score]/10)
   Test Cases: [N] total, [N] required
   Estimated Duration: ~[N] minutes
```

If `--plan-only` flag was provided, stop here and display the full test plan.

### Step 2: Run the Executor Agent

Launch the `executor` subagent with the test plan from `.claude-qa-output/analysis.json`.

The executor runs browser and/or API tests and writes results to `.claude-qa-output/results.json`.

Display live progress to the user as tests run.

### Step 3: Generate Report

Once execution is complete, launch the `reporter` subagent to generate the final
QA report from `.claude-qa-output/results.json`.

The reporter writes the formatted report to `.claude-qa-output/report.md`.

### Step 4: Output Report

Always display the report to the terminal.

If `--comment` flag was provided, post it to the PR:
```bash
gh pr comment $PR_NUMBER --body-file .claude-qa-output/report.md
```

Confirm to the user: "QA report posted to PR #XX"

---

## Error Handling

- If `gh` CLI is not authenticated, stop and tell the user to run `gh auth login`
- If `qa.config.yml` is missing, stop and tell the user to run `install.sh` first
- If `app.url` is not set in config, stop and ask the user to set it
- If the executor fails to reach the app, include "APP UNREACHABLE" in the report
- Never mark a PR as safe-to-merge if required tests did not run
