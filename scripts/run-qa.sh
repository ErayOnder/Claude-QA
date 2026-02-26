#!/usr/bin/env bash
# ============================================================
# run-qa.sh — Claude-QA local pipeline entrypoint
#
# Runs the full QA pipeline locally via Claude Code CLI.
# In CI, the GitHub Actions workflow handles this instead.
#
# Usage:
#   ./scripts/run-qa.sh                    # current branch PR
#   ./scripts/run-qa.sh --pr 42            # specific PR
#   ./scripts/run-qa.sh --plan-only        # analyze only, no execution
#   ./scripts/run-qa.sh --pr 42 --comment  # run + post to PR
#
# Prerequisites:
#   - claude CLI installed (npm install -g @anthropic-ai/claude-code)
#   - gh CLI installed and authenticated
#   - ANTHROPIC_API_KEY set in environment or .env
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[qa]${NC} $1"; }
success() { echo -e "${GREEN}[qa]${NC} $1"; }
warn()    { echo -e "${YELLOW}[qa]${NC} $1"; }
error()   { echo -e "${RED}[qa]${NC} $1"; exit 1; }
step()    { echo -e "\n${CYAN}${BOLD}--- $1 ---${NC}"; }

# ── Parse arguments ──────────────────────────────────────────
PR_NUMBER=""
PLAN_ONLY=false
POST_COMMENT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --pr)        PR_NUMBER="$2"; shift 2 ;;
    --plan-only) PLAN_ONLY=true; shift ;;
    --comment)   POST_COMMENT=true; shift ;;
    --help|-h)
      echo "Usage: ./scripts/run-qa.sh [--pr NUMBER] [--plan-only] [--comment]"
      exit 0
      ;;
    *) error "Unknown argument: $1" ;;
  esac
done

# ── Resolve paths ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/.claude-qa-output"

cd "$PROJECT_ROOT"
mkdir -p "$OUTPUT_DIR/screenshots"

# ── Pre-flight checks ───────────────────────────────────────
step "Pre-flight checks"

if ! command -v claude &>/dev/null; then
  error "claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
fi
success "claude CLI installed"

if ! command -v gh &>/dev/null; then
  error "gh CLI not found. Install from: https://cli.github.com"
fi
if ! gh auth status &>/dev/null; then
  error "gh CLI not authenticated. Run: gh auth login"
fi
success "gh CLI authenticated"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
  fi
  if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    error "ANTHROPIC_API_KEY not set. Export it or add to .env"
  fi
fi
success "ANTHROPIC_API_KEY set"

if [ -f "$PROJECT_ROOT/qa.config.yml" ]; then
  success "qa.config.yml found"
else
  warn "qa.config.yml not found — using defaults"
fi

if [ -z "$PR_NUMBER" ]; then
  PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
  if [ -z "$PR_NUMBER" ]; then
    error "Could not detect PR for current branch. Use --pr NUMBER to specify."
  fi
fi
success "PR: #$PR_NUMBER"

# ── Step 1: Analyze ─────────────────────────────────────────
step "Step 1/3 — Analyzing PR #$PR_NUMBER"

claude --print \
  --max-turns 25 \
  --allowedTools "Bash(gh *),Bash(cat *),Bash(find *),Bash(grep *),Bash(mkdir *),Bash(echo *),Read,Write,Glob,Grep" <<PROMPT
Run the analyzer agent on PR #$PR_NUMBER.
Config: qa.config.yml
Save the analysis JSON to $OUTPUT_DIR/analysis.json
PROMPT

if [ ! -f "$OUTPUT_DIR/analysis.json" ]; then
  error "Analyzer did not produce $OUTPUT_DIR/analysis.json"
fi

SKIP=$(python3 -c "import sys,json; d=json.load(open('$OUTPUT_DIR/analysis.json')); print(d.get('skip',False))" 2>/dev/null || echo "false")
if [ "$SKIP" = "True" ]; then
  REASON=$(python3 -c "import sys,json; d=json.load(open('$OUTPUT_DIR/analysis.json')); print(d.get('skip_reason','unknown'))" 2>/dev/null || echo "unknown")
  warn "QA skipped: $REASON"
  exit 0
fi

success "Analysis saved to $OUTPUT_DIR/analysis.json"

python3 -c "
import json
d = json.load(open('$OUTPUT_DIR/analysis.json'))
risk = d.get('risk', {})
print(f\"  Risk: {risk.get('level', 'UNKNOWN')}\")
print(f\"  Summary: {d.get('summary', 'N/A')[:120]}\")
recs = d.get('recommended_testing', {})
types = [k for k,v in recs.items() if v]
if types:
    print(f\"  Testing needed: {', '.join(types)}\")
" 2>/dev/null || true

if [ "$PLAN_ONLY" = "true" ]; then
  success "Plan-only mode — stopping here."
  info "Full analysis at: $OUTPUT_DIR/analysis.json"
  exit 0
fi

# ── Step 2: Execute ──────────────────────────────────────────
step "Step 2/3 — Executing tests"

claude --print \
  --max-turns 40 \
  --allowedTools "Bash(node *),Bash(npx *),Bash(npm *),Bash(cat *),Bash(find *),Bash(mkdir *),Bash(echo *),Bash(test *),Bash(sleep *),Read,Write,Glob" <<PROMPT
Run the executor agent using the analysis at $OUTPUT_DIR/analysis.json.
Config: qa.config.yml
Screenshots dir: $OUTPUT_DIR/screenshots/
Save results to: $OUTPUT_DIR/results.json
PROMPT

if [ ! -f "$OUTPUT_DIR/results.json" ]; then
  error "Executor did not produce $OUTPUT_DIR/results.json"
fi

success "Results saved to $OUTPUT_DIR/results.json"

# ── Step 3: Report ───────────────────────────────────────────
step "Step 3/3 — Generating report"

claude --print \
  --max-turns 10 \
  --allowedTools "Bash(cat *),Bash(echo *),Read,Write" <<PROMPT
Run the reporter agent to generate the final QA report.
Analysis: $OUTPUT_DIR/analysis.json
Results: $OUTPUT_DIR/results.json
PR Number: $PR_NUMBER
Save the markdown report to: $OUTPUT_DIR/report.md
PROMPT

if [ ! -f "$OUTPUT_DIR/report.md" ]; then
  error "Reporter did not produce $OUTPUT_DIR/report.md"
fi

# ── Display report ───────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────────────────"
cat "$OUTPUT_DIR/report.md"
echo "──────────────────────────────────────────────────────────"

# ── Post to PR ───────────────────────────────────────────────
if [ "$POST_COMMENT" = "true" ]; then
  step "Posting report to PR #$PR_NUMBER"
  bash "$SCRIPT_DIR/post-report.sh" "$PR_NUMBER"
else
  info "To post to PR, run with --comment flag"
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
success "QA pipeline complete!"
echo ""
echo "  Artifacts:"
echo "    Analysis:    $OUTPUT_DIR/analysis.json"
echo "    Results:     $OUTPUT_DIR/results.json"
echo "    Report:      $OUTPUT_DIR/report.md"
echo "    Screenshots: $OUTPUT_DIR/screenshots/"
echo ""
