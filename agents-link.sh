#!/usr/bin/env bash
# agents-link — Consolidate agent-specific .md files into AGENTS.md and symlink the rest.
#
# Usage:
#   agents-link              # Run in current project directory
#   agents-link --global     # Run in ~/.claude (user-level)
#   agents-link --dry-run    # Show what would happen, don't change anything
#
# Known agent files recognized:
#   CLAUDE.md  GEMINI.md  .cursorrules  .windsurfrules  CODEX.md  CURSOR.md

set -euo pipefail

DRY_RUN=false
TARGET_DIR="."
GLOBAL_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global|-g) GLOBAL_MODE=true; TARGET_DIR="$HOME/.claude"; shift ;;
    --dry-run|-n) DRY_RUN=true; shift ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: directory '$TARGET_DIR' does not exist."
  exit 1
fi

cd "$TARGET_DIR"

KNOWN_FILES=("CLAUDE.md" "GEMINI.md" ".cursorrules" ".windsurfrules" "CODEX.md" "CURSOR.md")
CANONICAL="AGENTS.md"

# Step 1: Collect content from existing real files (not symlinks)
COLLECTED=""
HAS_REAL_AGENTS=false
if [ -f "$CANONICAL" ] && [ ! -L "$CANONICAL" ]; then
  HAS_REAL_AGENTS=true
  echo "  [info] $CANONICAL exists as real file, will merge others into it"
else
  echo "  [info] $CANONICAL will be created"
fi

CONTENT_FILES=()

for f in "${KNOWN_FILES[@]}"; do
  if [ -f "$f" ] && [ ! -L "$f" ]; then
    CONTENT_FILES+=("$f")
    echo "  [found] $f (real file, will migrate)"
  elif [ -L "$f" ]; then
    local tgt
    tgt=$(readlink "$f")
    echo "  [skip]  $f → $tgt (already symlink)"
  fi
done

if [ "$HAS_REAL_AGENTS" = false ] && [ ${#CONTENT_FILES[@]} -eq 0 ]; then
  echo "Nothing to do — no real agent files found and $CANONICAL doesn't exist."
  exit 0
fi

# Step 2: Build AGENTS.md content
AGENTS_CONTENT=""

if [ "$HAS_REAL_AGENTS" = true ]; then
  AGENTS_CONTENT=$(cat "$CANONICAL")
fi

for f in "${CONTENT_FILES[@]}"; do
  if [ -n "$AGENTS_CONTENT" ]; then
    AGENTS_CONTENT+=$'\n\n'
  fi
  AGENTS_CONTENT+="# === Migrated from $f === "$'\n\n'
  AGENTS_CONTENT+=$(cat "$f")
done

if $DRY_RUN; then
  echo ""
  echo "=== DRY RUN — would create $CANONICAL with content from: ${CONTENT_FILES[*]:-none} ==="
  echo "$AGENTS_CONTENT" | head -20
  echo "..."
  echo ""
  echo "Would then create symlinks:"
  for f in "${KNOWN_FILES[@]}"; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then
      echo "  rm $f && ln -s $CANONICAL $f"
    elif [ ! -e "$f" ]; then
      echo "  ln -s $CANONICAL $f"
    fi
  done
  if [ "$HAS_REAL_AGENTS" = false ]; then
    echo "  (create $CANONICAL)"
  fi
  echo ""
  echo "Also symlink $CANONICAL back to CLAUDE.md for agent compatibility."
  exit 0
fi

# Step 3: Write AGENTS.md if needed
if [ "$HAS_REAL_AGENTS" = false ] || [ ${#CONTENT_FILES[@]} -gt 0 ]; then
  echo "$AGENTS_CONTENT" > "$CANONICAL"
  echo "  [write] $CANONICAL"
fi

# Step 4: Replace real files with symlinks
for f in "${CONTENT_FILES[@]}"; do
  rm "$f"
  ln -s "$CANONICAL" "$f"
  echo "  [link]  $f → $CANONICAL"
done

# Step 5: Create symlinks for any known files that don't exist at all
for f in "${KNOWN_FILES[@]}"; do
  if [ ! -e "$f" ]; then
    ln -s "$CANONICAL" "$f"
    echo "  [link]  $f → $CANONICAL (new)"
  fi
done

# Ensure CLAUDE.md exists (at minimum)
if [ ! -e "CLAUDE.md" ]; then
  ln -s "$CANONICAL" "CLAUDE.md"
  echo "  [link]  CLAUDE.md → $CANONICAL"
fi

echo ""
echo "Done. All agent files now point to $CANONICAL."
echo "Edit $CANONICAL to maintain them all."
