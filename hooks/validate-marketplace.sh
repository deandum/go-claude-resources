#!/usr/bin/env bash
# validate-marketplace.sh — assert every skill path in marketplace.json has a SKILL.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

if [ ! -f "$MARKETPLACE" ]; then
  echo "validate-marketplace: $MARKETPLACE not found" >&2
  exit 2
fi

errors=0
count=0
while IFS= read -r rel; do
  count=$((count + 1))
  abs="$REPO_ROOT/${rel#./}"
  if [ ! -f "$abs/SKILL.md" ]; then
    echo "FAIL: $rel has no SKILL.md" >&2
    errors=$((errors + 1))
  fi
done < <(grep -oE '"\./skills/[^"]+"' "$MARKETPLACE" | tr -d '"')

if [ "$count" -eq 0 ]; then
  echo "validate-marketplace: no skill paths found in marketplace.json" >&2
  exit 2
fi

if [ "$errors" -gt 0 ]; then
  echo "validate-marketplace: $errors of $count skill paths broken" >&2
  exit 1
fi

echo "validate-marketplace: OK ($count skills)"
