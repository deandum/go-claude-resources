#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Captures operational learnings from the session.
# Agents write learnings via hooks/learn.sh to per-user buffer files during
# the session. This hook persists them to project-specific JSONL on session
# end, under a file lock so concurrent session ends cannot overwrite each
# other's appends during the rotating truncate step.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

LEARNINGS_DIR="${HOME}/.claude-resources/learnings"
mkdir -p "$LEARNINGS_DIR"

PROJECT_SLUG=$(project_slug)
LEARNINGS_FILE="${LEARNINGS_DIR}/${PROJECT_SLUG}.jsonl"
BUFFER_DIR=$(buffer_dir)

# Critical section: drain buffers into the learnings file, then cap its
# length. Held under with_lock so a second session-end can't race the
# tail|mv truncation and lose recently-appended entries.
_persist_learnings() {
  for buf in "$BUFFER_DIR/${PROJECT_SLUG}-"*; do
    [ -f "$buf" ] || continue
    cat "$buf" >> "$LEARNINGS_FILE"
    rm -f "$buf"
  done

  if [ -f "$LEARNINGS_FILE" ] && [ "$(wc -l < "$LEARNINGS_FILE")" -gt 50 ]; then
    tail -50 "$LEARNINGS_FILE" > "${LEARNINGS_FILE}.tmp"
    mv "${LEARNINGS_FILE}.tmp" "$LEARNINGS_FILE"
  fi
}

with_lock "$LEARNINGS_FILE" _persist_learnings
