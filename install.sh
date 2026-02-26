#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Claude-QA Installer
#
# Run this from your project root after cloning or adding Claude-QA as a
# submodule. It symlinks the agent/command/skill definitions and copies
# the CI workflow into your project.
#
# Usage:
#   ./claude-qa/install.sh          (if cloned as claude-qa/)
#   ./.claude-qa/install.sh         (if cloned as .claude-qa/)
# ---------------------------------------------------------------------------

CLAUDE_QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$CLAUDE_QA_DIR/.." && pwd)"

echo "=== Claude-QA Installer ==="
echo "Claude-QA directory: $CLAUDE_QA_DIR"
echo "Project root:        $PROJECT_ROOT"
echo ""

# ---------------------------------------------------------------------------
# Compute the relative path from project root to Claude-QA dir.
# This ensures symlinks are relative (portable across machines).
# ---------------------------------------------------------------------------
RELATIVE_QA_DIR=$(python3 -c "import os.path; print(os.path.relpath('$CLAUDE_QA_DIR', '$PROJECT_ROOT'))" 2>/dev/null \
  || echo "$(basename "$CLAUDE_QA_DIR")")

# ---------------------------------------------------------------------------
# 1. Symlink .claude/ directories
# ---------------------------------------------------------------------------
echo "1. Setting up .claude/ directory..."

mkdir -p "$PROJECT_ROOT/.claude"

for subdir in agents commands skills; do
  TARGET="$PROJECT_ROOT/.claude/$subdir"
  SOURCE="$RELATIVE_QA_DIR/.claude/$subdir"

  if [[ -L "$TARGET" ]]; then
    echo "   $subdir: symlink exists, updating..."
    rm "$TARGET"
  elif [[ -d "$TARGET" ]]; then
    echo "   $subdir: directory exists — merging (your files will be preserved)"
    # Back up existing files before symlinking
    BACKUP="$PROJECT_ROOT/.claude/${subdir}.backup.$(date +%s)"
    mv "$TARGET" "$BACKUP"
    echo "   $subdir: existing files backed up to $BACKUP"
  fi

  ln -s "$SOURCE" "$TARGET"
  echo "   $subdir: symlinked -> $SOURCE"
done

echo ""

# ---------------------------------------------------------------------------
# 2. Copy GitHub Actions workflow
# ---------------------------------------------------------------------------
echo "2. Setting up GitHub Actions workflow..."

mkdir -p "$PROJECT_ROOT/.github/workflows"

WORKFLOW_TARGET="$PROJECT_ROOT/.github/workflows/claude-qa.yml"

if [[ -f "$WORKFLOW_TARGET" ]]; then
  echo "   Workflow already exists at $WORKFLOW_TARGET — skipping."
  echo "   To update: cp $CLAUDE_QA_DIR/.github/workflows/qa-pipeline.yml $WORKFLOW_TARGET"
else
  cp "$CLAUDE_QA_DIR/.github/workflows/qa-pipeline.yml" "$WORKFLOW_TARGET"
  echo "   Copied workflow to $WORKFLOW_TARGET"
fi

echo ""

# ---------------------------------------------------------------------------
# 3. Create starter config
# ---------------------------------------------------------------------------
echo "3. Setting up configuration..."

CONFIG_TARGET="$PROJECT_ROOT/qa.config.yml"

if [[ -f "$CONFIG_TARGET" ]]; then
  echo "   Config already exists at $CONFIG_TARGET — skipping."
else
  cp "$CLAUDE_QA_DIR/qa.config.yml" "$CONFIG_TARGET"
  echo "   Created $CONFIG_TARGET — customize this for your project."
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Add output directory to .gitignore
# ---------------------------------------------------------------------------
echo "4. Updating .gitignore..."

GITIGNORE="$PROJECT_ROOT/.gitignore"

if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q ".claude-qa-output" "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Claude-QA pipeline output" >> "$GITIGNORE"
    echo ".claude-qa-output/" >> "$GITIGNORE"
    echo "   Added .claude-qa-output/ to .gitignore"
  else
    echo "   .claude-qa-output/ already in .gitignore"
  fi
else
  echo "# Claude-QA pipeline output" > "$GITIGNORE"
  echo ".claude-qa-output/" >> "$GITIGNORE"
  echo "   Created .gitignore with .claude-qa-output/"
fi

echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Add your Anthropic API key as a GitHub secret:"
echo "     gh secret set ANTHROPIC_API_KEY"
echo ""
echo "  2. Customize qa.config.yml for your project"
echo ""
echo "  3. Open a PR to see Claude-QA in action!"
echo ""
