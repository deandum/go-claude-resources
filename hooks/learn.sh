#!/usr/bin/env bash
set -euo pipefail

# Records a project-specific learning to a /tmp buffer file.
# Buffer files are collected by session-end.sh into persistent JSONL storage.
#
# Usage:
#   ./hooks/learn.sh "discovered that service X requires auth header"
#   ./hooks/learn.sh "always run migrations before tests" "gotcha"
#
# Categories: convention (default), gotcha, pattern, tool

usage() {
  cat <<'USAGE'
Usage: learn.sh <learning> [category]

Record a project-specific learning for future sessions.

Arguments:
  learning    Description of what you learned (required)
  category    One of: convention, gotcha, pattern, tool (default: convention)

Examples:
  ./hooks/learn.sh "service X requires auth header on all endpoints"
  ./hooks/learn.sh "always run migrations before tests" "gotcha"
  ./hooks/learn.sh "use make lint instead of golangci-lint directly" "tool"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "Error: learning text is required" >&2
  usage >&2
  exit 2
fi

LEARNING="$1"
CATEGORY="${2:-convention}"

# Validate category
case "$CATEGORY" in
  convention|gotcha|pattern|tool) ;;
  *)
    echo "Error: invalid category '$CATEGORY'. Must be one of: convention, gotcha, pattern, tool" >&2
    exit 2
    ;;
esac

# Determine project slug from git root or pwd basename
PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")

# Write JSONL line to buffer file (PID for uniqueness)
BUFFER_FILE="/tmp/claude-learnings-${PROJECT_SLUG}-$$"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# JSON-escape helper (pure bash; handles \, ", and common control chars)
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

printf '{"learning":"%s","category":"%s","timestamp":"%s"}\n' \
  "$(json_escape "$LEARNING")" \
  "$(json_escape "$CATEGORY")" \
  "$(json_escape "$TIMESTAMP")" >> "$BUFFER_FILE"

echo "Recorded learning (${CATEGORY}): ${LEARNING}"
