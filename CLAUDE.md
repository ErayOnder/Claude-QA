# Claude-QA — Project Instructions

This is the Claude-QA pipeline repository. It provides an AI-powered QA system
that automatically analyzes pull requests and acts like a senior QA engineer.

## Repository Layout

- `.claude/agents/` — Agent definitions (one per pipeline stage)
- `.claude/commands/` — Slash commands for local use
- `.claude/skills/` — Reusable knowledge for agents
- `.github/workflows/` — GitHub Actions CI/CD workflow
- `scripts/` — Shell scripts for CI glue (orchestration + PR commenting)
- `qa.config.yml` — Default project configuration
- `install.sh` — One-command setup for target projects

## Pipeline Stages

1. **Analyzer** (`analyzer.md`) — Reads the PR diff, classifies risk, maps impact
2. **Planner** (`planner.md`) — Generates structured test plan (future)
3. **Executor** (`executor.md`) — Runs tests against the app (future)
4. **Reporter** (`reporter.md`) — Formats and posts PR comment (future)

## Working on This Repo

When modifying agents, keep the output contracts stable — downstream stages
depend on the JSON schemas defined in each agent's "Output Format" section.

When modifying shell scripts, test locally with:
```
PR_NUMBER=<number> bash scripts/run-qa.sh
```

The `.claude-qa-output/` directory is gitignored and used for intermediate files.
