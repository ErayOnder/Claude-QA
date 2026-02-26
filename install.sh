#!/usr/bin/env bash
# ============================================================
# Claude-QA Install Script
# Wires this repo into the host project so Claude Code and
# GitHub Actions pick it up automatically.
#
# Usage:
#   cd your-project
#   git clone https://github.com/you/claude-qa ./claude-qa
#   cd claude-qa && ./install.sh
#
# What it does:
#   1. Symlinks .claude/ agents, commands, and skills into host project
#   2. Copies GitHub Actions workflow into host project
#   3. Creates starter qa.config.yml in host project if missing
#   4. Adds .claude-qa-output/ to host project's .gitignore
# ============================================================
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Helpers ──────────────────────────────────────────────────
info()    { echo -e "${BLUE}[claude-qa]${NC} $1"; }
success() { echo -e "${GREEN}[claude-qa] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[claude-qa] ⚠${NC} $1"; }
error()   { echo -e "${RED}[claude-qa] ✗${NC} $1"; exit 1; }

CLAUDE_QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$CLAUDE_QA_DIR/.." && pwd)"

info "=== Claude-QA Installer ==="
info "Claude-QA directory: $CLAUDE_QA_DIR"
info "Project root:        $PROJECT_ROOT"
info ""

# ── Sanity checks ────────────────────────────────────────────

if [[ "$CLAUDE_QA_DIR" == "$PROJECT_ROOT" ]]; then
  error "Cannot install: install script is at filesystem root. Clone claude-qa inside a host project directory."
fi

if [[ ! -f "$CLAUDE_QA_DIR/qa.config.yml" ]]; then
  error "qa.config.yml not found in claude-qa directory. Something went wrong with the clone."
fi

if [[ ! -f "$CLAUDE_QA_DIR/.github/workflows/qa-pipeline.yml" ]]; then
  error ".github/workflows/qa-pipeline.yml not found in claude-qa directory. Something went wrong with the clone."
fi

# ---------------------------------------------------------------------------
# Compute the relative path from project root to Claude-QA dir.
# This ensures symlinks are relative (portable across machines).
# ---------------------------------------------------------------------------
RELATIVE_QA_DIR=$(python3 -c "import os.path; print(os.path.relpath('$CLAUDE_QA_DIR', '$PROJECT_ROOT'))" 2>/dev/null \
  || echo "$(basename "$CLAUDE_QA_DIR")")

# ---------------------------------------------------------------------------
# 1. Symlink .claude/ directories
# ---------------------------------------------------------------------------
info "1. Setting up .claude/ directory..."

mkdir -p "$PROJECT_ROOT/.claude"

for subdir in agents commands skills; do
  TARGET="$PROJECT_ROOT/.claude/$subdir"
  SOURCE="$RELATIVE_QA_DIR/.claude/$subdir"

  if [[ -L "$TARGET" ]]; then
    info "   $subdir: symlink exists, updating..."
    rm "$TARGET"
  elif [[ -d "$TARGET" ]]; then
    warn "   $subdir: directory exists — merging (your files will be preserved)"
    # Back up existing files before symlinking
    BACKUP="$PROJECT_ROOT/.claude/${subdir}.backup.$(date +%s)"
    mv "$TARGET" "$BACKUP"
    info "   $subdir: existing files backed up to $BACKUP"
  fi

  ln -s "$SOURCE" "$TARGET"
  success "   $subdir: symlinked -> $SOURCE"
done

info ""

# ---------------------------------------------------------------------------
# 2. Copy GitHub Actions workflow
# ---------------------------------------------------------------------------
info "2. Setting up GitHub Actions workflow..."

mkdir -p "$PROJECT_ROOT/.github/workflows"

WORKFLOW_TARGET="$PROJECT_ROOT/.github/workflows/claude-qa.yml"

if [[ -f "$WORKFLOW_TARGET" ]]; then
  warn "   Workflow already exists at $WORKFLOW_TARGET — skipping."
  info "   To update: cp $CLAUDE_QA_DIR/.github/workflows/qa-pipeline.yml $WORKFLOW_TARGET"
else
  cp "$CLAUDE_QA_DIR/.github/workflows/qa-pipeline.yml" "$WORKFLOW_TARGET"
  success "   Copied workflow to $WORKFLOW_TARGET"
fi

info ""

# ---------------------------------------------------------------------------
# 3. Create starter config
# ---------------------------------------------------------------------------
info "3. Setting up configuration..."

CONFIG_TARGET="$PROJECT_ROOT/qa.config.yml"

if [[ -f "$CONFIG_TARGET" ]]; then
  warn "   Config already exists at $CONFIG_TARGET — skipping."
else
  cp "$CLAUDE_QA_DIR/qa.config.yml" "$CONFIG_TARGET"
  success "   Created $CONFIG_TARGET — customize this for your project."
fi

info ""

# ---------------------------------------------------------------------------
# 4. Add output directory to .gitignore
# ---------------------------------------------------------------------------
info "4. Updating .gitignore..."

GITIGNORE="$PROJECT_ROOT/.gitignore"

if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q ".claude-qa-output" "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Claude-QA pipeline output" >> "$GITIGNORE"
    echo ".claude-qa-output/" >> "$GITIGNORE"
    success "   Added .claude-qa-output/ to .gitignore"
  else
    info "   .claude-qa-output/ already in .gitignore"
  fi
else
  echo "# Claude-QA pipeline output" > "$GITIGNORE"
  echo ".claude-qa-output/" >> "$GITIGNORE"
  success "   Created .gitignore with .claude-qa-output/"
fi

info ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
success "=== Setup Complete ==="
info ""
info "Next steps:"
info "  1. Add your Anthropic API key as a GitHub secret:"
info "     gh secret set ANTHROPIC_API_KEY"
info ""
info "  2. Customize qa.config.yml for your project"
info ""
info "  3. Open a PR to see Claude-QA in action!"
info ""
