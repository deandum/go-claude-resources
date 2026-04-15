#!/usr/bin/env bash
# validate-all.sh — run all repo validators. Exit non-zero if any fail.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATORS=(
  validate-marketplace.sh
  validate-skill-anatomy.sh
  validate-skill-references.sh
  validate-agents.sh
)

failed=0
for v in "${VALIDATORS[@]}"; do
  if [ -x "$SCRIPT_DIR/$v" ]; then
    if ! "$SCRIPT_DIR/$v"; then
      failed=$((failed + 1))
    fi
  else
    echo "SKIP: $v not found or not executable" >&2
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "validate-all: $failed validator(s) failed" >&2
  exit 1
fi

echo "validate-all: all validators passed"
