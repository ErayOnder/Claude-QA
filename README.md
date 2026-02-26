# Claude-QA

AI-powered QA pipeline that acts like a senior QA engineer on every pull request.

```
Developer pushes code / opens PR
          |
  ANALYZE — Claude reads the diff, maps impact, classifies risk
          |
     PLAN — Generates test plan: happy paths, edge cases, regression
          |
  EXECUTE — Runs tests via Playwright, API calls, or existing suites
          |
   REPORT — Posts structured results as a PR comment
          |
Developer gets actionable feedback before merge
```

## Quick Start

### Option A: Clone into your project

```bash
cd your-project/
git clone https://github.com/erayonder/Claude-QA.git claude-qa
bash claude-qa/install.sh
```

### Option B: Add as a git submodule

```bash
cd your-project/
git submodule add https://github.com/erayonder/Claude-QA.git claude-qa
bash claude-qa/install.sh
```

### After install

1. **Add your API key** as a GitHub Actions secret:
   ```bash
   gh secret set ANTHROPIC_API_KEY
   ```

2. **Customize** `qa.config.yml` in your project root (optional — sensible defaults included).

3. **Open a PR** — Claude-QA will automatically analyze it and post a comment.

## What Gets Installed

Running `install.sh` does the following in your project:

| What | Where | How |
|------|-------|-----|
| Agent definitions | `.claude/agents/` | Symlinked |
| Slash commands | `.claude/commands/` | Symlinked |
| QA skills | `.claude/skills/` | Symlinked |
| CI workflow | `.github/workflows/claude-qa.yml` | Copied |
| Config template | `qa.config.yml` | Copied |

Symlinks point back to the `claude-qa/` directory, so pulling updates is as simple as:

```bash
cd claude-qa && git pull
```

## Local Usage

With Claude Code installed, you can run the QA pipeline locally:

```bash
# Using the slash command (inside Claude Code)
/qa

# Using the shell script directly
PR_NUMBER=42 bash claude-qa/scripts/run-qa.sh
```

## Configuration

Edit `qa.config.yml` in your project root:

```yaml
app:
  url: http://localhost:3000    # Your app URL for browser tests
  type: auto                    # auto | web | api | fullstack

testing:
  run_existing_tests: true
  test_command: "npm test"      # Leave empty for auto-detection

analysis:
  risk_threshold: medium        # Minimum risk level to flag
  ignore_paths:                 # Files to skip
    - "*.md"
    - "docs/**"

reporting:
  post_comment: true            # Post results to PR
  block_on_high_risk: false     # Block merge on CRITICAL risk
```

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) — the AI engine
- [GitHub CLI](https://cli.github.com/) (`gh`) — for PR interaction
- `jq` — for JSON processing in CI
- An Anthropic API key

## Current Status

**Tile 1 (current):** Analyzer agent is functional — reads PR diffs, classifies risk, posts analysis comments.

Tiles 2-6 (planner, executor, reporter, polish) are on the roadmap. See agent placeholder files for details.

## How It Works

The pipeline is built entirely on Claude Code's native agent system:

- **Agents** (`.claude/agents/*.md`) define how Claude thinks at each stage
- **Commands** (`.claude/commands/*.md`) provide local slash-command triggers
- **Skills** (`.claude/skills/*.md`) give agents reusable domain knowledge
- **Shell scripts** (`scripts/`) handle CI orchestration and PR commenting
- **GitHub Actions** (`.github/workflows/`) trigger the pipeline on PRs

No Python. No custom runtime. Just markdown and bash.
