#!/usr/bin/env bash
set -euo pipefail

# Captures operational learnings from the session.
# Agents write learnings via hooks/learn.sh to /tmp buffer files during the session.
# This hook persists them to project-specific JSONL on session end.

LEARNINGS_DIR="${HOME}/.claude-resources/learnings"
mkdir -p "$LEARNINGS_DIR"

# Determine project slug from git root or directory name
PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
LEARNINGS_FILE="${LEARNINGS_DIR}/${PROJECT_SLUG}.jsonl"

# Find and persist any learning buffers from this session
for buf in "/tmp/claude-learnings-${PROJECT_SLUG}-"*; do
  [ -f "$buf" ] || continue
  cat "$buf" >> "$LEARNINGS_FILE"
  rm -f "$buf"
done

# Keep only last 50 learnings to prevent unbounded growth
if [ -f "$LEARNINGS_FILE" ] && [ "$(wc -l < "$LEARNINGS_FILE")" -gt 50 ]; then
  tail -50 "$LEARNINGS_FILE" > "${LEARNINGS_FILE}.tmp"
  mv "${LEARNINGS_FILE}.tmp" "$LEARNINGS_FILE"
fi
