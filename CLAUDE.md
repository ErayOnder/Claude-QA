# Claude-QA — Project Instructions

This is the Claude-QA pipeline repository. It provides an AI-powered QA system
that automatically analyzes pull requests and acts like a senior QA engineer:

1. Analyzes pull request diffs to understand what changed
2. Generates a structured test plan (happy path, negative, edge cases, regression risks)
3. Executes tests against the running app using Playwright (browser) or API calls
4. Posts a structured QA report back to the PR as a comment

## How It Works in a Host Project

This repo is cloned into a host project and wired in via `install.sh`.
The install script symlinks `.claude/` and `.github/workflows/` into the parent project
so Claude Code and GitHub Actions pick them up automatically.

## Repository Layout

- `.claude/agents/` — Agent definitions (one per pipeline stage)
- `.claude/commands/` — Slash commands for local use
- `.claude/skills/` — Reusable knowledge for agents
- `.github/workflows/` — GitHub Actions CI/CD workflow
- `scripts/` — Shell scripts for CI glue (orchestration + PR commenting)
- `qa.config.yml` — Default project configuration
- `install.sh` — One-command setup for target projects

## Agents Available

1. **Analyzer** (`analyzer.md`) — Reads the PR diff, classifies risk, maps impact area and generates test plan
2. **Executor** (`executor.md`) — Takes the test plan and runs it (browser, API, or existing test suite)
3. **Reporter** (`reporter.md`) — Formats results into a structured QA report and posts to PR

## Slash Commands

- `/qa` — trigger the full QA pipeline manually from Claude Code

## Configuration

All project-specific configuration lives in `qa.config.yml` at the root of this repo.
Edit this file after cloning. Everything else is zero-config by default.

## Skills

- **qa-thinking** — QA reasoning patterns: risk matrix, equivalence partitioning, boundary values
- **playwright** — Browser automation best practices and resilient selector strategies

## Working on This Repo

When modifying agents, keep the output contracts stable — downstream stages
depend on the JSON schemas defined in each agent's "Output Format" section.

When modifying shell scripts, test locally with:
```
PR_NUMBER=<number> bash scripts/run-qa.sh
```

The `.claude-qa-output/` directory is gitignored and used for intermediate files.

## Important Rules for Claude

- Always read `qa.config.yml` before running any agent
- Always run the **analyzer** agent first — never skip straight to execution
- The **executor** agent should receive the full test plan from the analyzer as input
- Never post a report unless tests have actually been run
- If `app_url` is not set in config, ask the user before proceeding
- Screenshots must be captured on any test failure
- Risk level in the report must always be one of: LOW / MEDIUM / HIGH / CRITICAL