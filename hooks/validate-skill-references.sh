#!/usr/bin/env bash
# validate-skill-references.sh — assert every agent's `skills:` list resolves
# to a directory with a SKILL.md file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$REPO_ROOT/agents"
SKILLS_DIR="$REPO_ROOT/skills"

if [ ! -d "$AGENTS_DIR" ]; then
  echo "validate-skill-references: $AGENTS_DIR not found" >&2
  exit 2
fi

errors=0
checked_agents=0

for agent in "$AGENTS_DIR"/*.md; do
  [ -f "$agent" ] || continue
  checked_agents=$((checked_agents + 1))
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [ ! -f "$SKILLS_DIR/$ref/SKILL.md" ]; then
      echo "FAIL: $(basename "$agent") references missing skill: $ref" >&2
      errors=$((errors + 1))
    fi
  done < <(awk '
    # Enter skills: block
    /^skills:/ { in_block=1; next }
    # Frontmatter close always exits
    in_block && /^---/ { in_block=0; next }
    # Next top-level YAML key exits (e.g., "memory:")
    in_block && /^[a-zA-Z_][a-zA-Z_0-9]*:/ { in_block=0 }
    # Capture indented list items "  - skill/name"
    in_block && /^[[:space:]]*-[[:space:]]+/ {
      sub(/^[[:space:]]*-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*$/, "")
      print
      next
    }
  ' "$agent")
done

if [ "$errors" -gt 0 ]; then
  echo "validate-skill-references: $errors error(s) across $checked_agents agents" >&2
  exit 1
fi

echo "validate-skill-references: OK ($checked_agents agents checked)"
