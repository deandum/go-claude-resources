#!/usr/bin/env bash
# validate-skill-anatomy.sh — assert every core/ops skill has the required 5 sections.
# Meta-skills opt out with an HTML comment `<!-- meta-skill: skip-anatomy -->`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

TIER_DIRS=(
  "$REPO_ROOT/skills/core"
  "$REPO_ROOT/skills/ops"
)

REQUIRED_SECTIONS=(
  "## When to Use"
  "## When NOT to Use"
  "## Common Rationalizations"
  "## Red Flags"
  "## Verification"
)

errors=0
checked=0
skipped=0
tiers_seen=0

for tier_dir in "${TIER_DIRS[@]}"; do
  [ -d "$tier_dir" ] || continue
  tiers_seen=$((tiers_seen + 1))
  for skill in "$tier_dir"/*/SKILL.md; do
    [ -f "$skill" ] || continue
    if grep -q '^<!-- meta-skill: skip-anatomy -->' "$skill"; then
      skipped=$((skipped + 1))
      continue
    fi
    checked=$((checked + 1))
    for section in "${REQUIRED_SECTIONS[@]}"; do
      if ! grep -qF "$section" "$skill"; then
        echo "FAIL: ${skill#"$REPO_ROOT"/} missing section: $section" >&2
        errors=$((errors + 1))
      fi
    done
  done
done

if [ "$tiers_seen" -eq 0 ]; then
  echo "validate-skill-anatomy: no tier directories found (expected skills/core/ or skills/ops/)" >&2
  exit 2
fi

if [ "$errors" -gt 0 ]; then
  echo "validate-skill-anatomy: $errors error(s) across $checked skills" >&2
  exit 1
fi

echo "validate-skill-anatomy: OK ($checked skills checked across $tiers_seen tier(s), $skipped meta-skills skipped)"
