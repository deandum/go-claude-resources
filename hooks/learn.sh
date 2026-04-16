#!/usr/bin/env bash
set -euo pipefail
umask 077

# Records a project-specific learning to a per-user buffer file.
# Buffer files are collected by session-end.sh into persistent JSONL storage.
#
# Usage:
#   ./hooks/learn.sh "discovered that service X requires auth header"
#   ./hooks/learn.sh "always run migrations before tests" "gotcha"
#
# Categories: convention (default), gotcha, pattern, tool

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

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

case "$CATEGORY" in
  convention|gotcha|pattern|tool) ;;
  *)
    echo "Error: invalid category '$CATEGORY'. Must be one of: convention, gotcha, pattern, tool" >&2
    exit 2
    ;;
esac

PROJECT_SLUG=$(project_slug)
BUFFER_FILE="$(buffer_dir)/${PROJECT_SLUG}-$$"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

printf '{"learning":"%s","category":"%s","timestamp":"%s"}\n' \
  "$(json_escape "$LEARNING")" \
  "$(json_escape "$CATEGORY")" \
  "$(json_escape "$TIMESTAMP")" >> "$BUFFER_FILE"

echo "Recorded learning (${CATEGORY}): ${LEARNING}"
