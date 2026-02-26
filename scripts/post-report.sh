#!/usr/bin/env bash
# ============================================================
# post-report.sh — Post QA report to GitHub PR
#
# Posts .claude-qa-output/report.md as a PR comment.
# Use --replace to delete previous Claude-QA comments first.
#
# Usage:
#   ./scripts/post-report.sh 42
#   ./scripts/post-report.sh 42 --replace
#   ./scripts/post-report.sh 42 --report path/to/report.md
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
success() { echo -e "${GREEN}[post-report]${NC} $1"; }
warn()    { echo -e "${YELLOW}[post-report]${NC} $1"; }
error()   { echo -e "${RED}[post-report]${NC} $1"; exit 1; }

# ── Parse args ───────────────────────────────────────────────
PR_NUMBER="${1:-}"
REPLACE=false
REPORT_FILE=".claude-qa-output/report.md"

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --replace) REPLACE=true; shift ;;
    --report)  REPORT_FILE="$2"; shift 2 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

[ -z "$PR_NUMBER" ] && error "Usage: post-report.sh <PR_NUMBER> [--replace] [--report FILE]"
[ ! -f "$REPORT_FILE" ] && error "Report file not found: $REPORT_FILE"

# ── Check gh auth ────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
  error "gh CLI not authenticated. Run: gh auth login"
fi

# ── Delete previous Claude-QA comments (if --replace) ────────
if [ "$REPLACE" = "true" ]; then
  echo "Checking for previous Claude-QA comments..."
  COMMENT_IDS=$(gh pr view "$PR_NUMBER" --json comments \
    --jq '.comments[] | select(.body | startswith("## ") and contains("QA")) | .databaseId' \
    2>/dev/null || echo "")

  if [ -n "$COMMENT_IDS" ]; then
    for ID in $COMMENT_IDS; do
      gh api --method DELETE "/repos/{owner}/{repo}/issues/comments/$ID" 2>/dev/null || true
      warn "Deleted previous QA comment: $ID"
    done
  fi
fi

# ── Post the report ──────────────────────────────────────────
echo "Posting QA report to PR #$PR_NUMBER..."
gh pr comment "$PR_NUMBER" --body-file "$REPORT_FILE"
success "QA report posted to PR #$PR_NUMBER"

# ── Print comment URL ────────────────────────────────────────
PR_URL=$(gh pr view "$PR_NUMBER" --json url -q '.url' 2>/dev/null || echo "")
if [ -n "$PR_URL" ]; then
  success "View at: ${PR_URL}"
fi
