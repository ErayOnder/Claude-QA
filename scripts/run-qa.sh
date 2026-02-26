#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/.claude-qa-output"

mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Resolve PR number: prefer env var, fall back to gh CLI detection
# ---------------------------------------------------------------------------
PR_NUMBER="${PR_NUMBER:-""}"

if [[ -z "$PR_NUMBER" ]]; then
  PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "ERROR: No PR found. Set PR_NUMBER or run from a branch with an open PR."
  exit 1
fi

echo "=== Claude-QA Pipeline ==="
echo "PR: #$PR_NUMBER"
echo ""

# ---------------------------------------------------------------------------
# Load config (if present)
# ---------------------------------------------------------------------------
CONFIG_FILE="${QA_CONFIG:-qa.config.yml}"
CONFIG_FLAG=""
if [[ -f "$CONFIG_FILE" ]]; then
  echo "Config: $CONFIG_FILE"
  CONFIG_FLAG="The project config is at $CONFIG_FILE — read it and respect its settings."
else
  echo "Config: not found (using defaults)"
fi

echo ""

# ---------------------------------------------------------------------------
# Stage 1: ANALYZE
# ---------------------------------------------------------------------------
echo "--- Stage 1: ANALYZE ---"
echo "Running analyzer agent on PR #$PR_NUMBER ..."

ANALYZE_PROMPT="You are the analyzer agent. Analyze PR #$PR_NUMBER.
Fetch the diff with: gh pr diff $PR_NUMBER
Fetch PR metadata with: gh pr view $PR_NUMBER --json files,commits,title,body
$CONFIG_FLAG
Follow your instructions exactly. Output ONLY valid JSON — no markdown, no commentary."

claude -p \
  --agent-file "$REPO_ROOT/.claude/agents/analyzer.md" \
  "$ANALYZE_PROMPT" \
  > "$OUTPUT_DIR/analysis.json"

echo "Analysis saved to $OUTPUT_DIR/analysis.json"
echo ""

# ---------------------------------------------------------------------------
# Quick summary for CI logs
# ---------------------------------------------------------------------------
if command -v jq &>/dev/null && [[ -f "$OUTPUT_DIR/analysis.json" ]]; then
  RISK=$(jq -r '.risk.level // "UNKNOWN"' "$OUTPUT_DIR/analysis.json")
  SUMMARY=$(jq -r '.summary // "No summary"' "$OUTPUT_DIR/analysis.json")
  echo "Risk Level: $RISK"
  echo "Summary: $SUMMARY"
  echo ""
fi

# ---------------------------------------------------------------------------
# Post report (if configured or forced via env)
# ---------------------------------------------------------------------------
POST_REPORT="${POST_REPORT:-true}"

if [[ "$POST_REPORT" == "true" ]]; then
  echo "--- Posting report to PR ---"
  bash "$SCRIPT_DIR/post-report.sh" "$PR_NUMBER" "$OUTPUT_DIR/analysis.json"
fi

echo ""
echo "=== Claude-QA Pipeline Complete ==="
