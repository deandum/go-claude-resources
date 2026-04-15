#!/usr/bin/env bash
# validate-agents.sh — assert every command's agent references resolve to agents/*.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
COMMANDS_DIR="$REPO_ROOT/.claude/commands"
AGENTS_DIR="$REPO_ROOT/agents"

if [ ! -d "$COMMANDS_DIR" ] || [ ! -d "$AGENTS_DIR" ]; then
  echo "validate-agents: missing commands or agents directory" >&2
  exit 2
fi

agents=$(grep -h '^name:' "$AGENTS_DIR"/*.md 2>/dev/null | awk '{print $2}' | sort -u)
if [ -z "$agents" ]; then
  echo "validate-agents: no agents found in $AGENTS_DIR" >&2
  exit 2
fi

errors=0

if grep -rn '{plugin}:{lang}' "$COMMANDS_DIR" 2>/dev/null; then
  echo "FAIL: unresolved template strings (above) in command files" >&2
  errors=$((errors + 1))
fi

for cmd in "$COMMANDS_DIR"/*.md; do
  [ -f "$cmd" ] || continue
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if ! echo "$agents" | grep -qx "$ref"; then
      echo "FAIL: $(basename "$cmd") references unknown agent: $ref" >&2
      errors=$((errors + 1))
    fi
  done < <(grep -iE '(spawn|the) `[a-z-]+` agent' "$cmd" 2>/dev/null | grep -oE '`[a-z-]+`' | tr -d '`' | sort -u)
done

if [ "$errors" -gt 0 ]; then
  echo "validate-agents: $errors error(s)" >&2
  exit 1
fi

cmd_count=$(find "$COMMANDS_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
agent_count=$(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
echo "validate-agents: OK ($cmd_count commands, $agent_count agents)"
