#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PLUGIN_ROOT/skills"

# Detect project language from current working directory
DETECTED_LANGS=()
[ -f "go.mod" ] && DETECTED_LANGS+=("go")
[ -f "angular.json" ] && DETECTED_LANGS+=("angular")
[ -f "Cargo.toml" ] && DETECTED_LANGS+=("rust")
{ [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; } && DETECTED_LANGS+=("python")
if [ -f "package.json" ] && [ ! -f "angular.json" ]; then
  DETECTED_LANGS+=("node")
fi

# List available core skills
CORE_SKILLS=""
if [ -d "$SKILLS_DIR/core" ]; then
  CORE_SKILLS=$(find "$SKILLS_DIR/core" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
fi

# List available language skills for detected languages
LANG_SKILLS=""
for lang in "${DETECTED_LANGS[@]+"${DETECTED_LANGS[@]}"}"; do
  if [ -d "$SKILLS_DIR/$lang" ]; then
    skills=$(find "$SKILLS_DIR/$lang" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
    LANG_SKILLS+="$lang: [$skills] "
  fi
done
LANG_SKILLS="${LANG_SKILLS% }"
[ -z "$LANG_SKILLS" ] && LANG_SKILLS="none"

# Detect ops-skills opt-in: presence of populated skills/ops/ directory
OPS_ENABLED="false"
OPS_SKILLS=""
if [ -d "$SKILLS_DIR/ops" ]; then
  ops_list=$(find "$SKILLS_DIR/ops" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
  if [ -n "$ops_list" ]; then
    OPS_ENABLED="true"
    OPS_SKILLS="$ops_list"
  fi
fi

# Load recent operational learnings for this project
PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
LEARNINGS_FILE="${HOME}/.claude-resources/learnings/${PROJECT_SLUG}.jsonl"
RECENT_LEARNINGS=""
if [ -f "$LEARNINGS_FILE" ]; then
  recent=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    val=$(printf '%s' "$line" | sed -n 's/.*"learning"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -n "$val" ]; then
      if [ -z "$recent" ]; then
        recent="$val"
      else
        recent="$recent; $val"
      fi
    fi
  done < <(tail -10 "$LEARNINGS_FILE" 2>/dev/null)
  RECENT_LEARNINGS="$recent"
fi

# Scan for in-progress spec directories (status != complete)
ACTIVE_SPECS=""
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPECS_ROOT="$PROJECT_ROOT/docs/specs"
if [ -d "$SPECS_ROOT" ]; then
  parts=""
  for spec_dir in "$SPECS_ROOT"/*/; do
    [ -d "$spec_dir" ] || continue
    slug=$(basename "$spec_dir")
    spec_file="$spec_dir/spec.md"
    [ -f "$spec_file" ] || continue

    status=$(sed -n 's/^status:[[:space:]]*\(.*\)$/\1/p' "$spec_file" | head -n1 | sed 's/[[:space:]]*$//')
    cw=$(sed -n 's/^current_group:[[:space:]]*\(.*\)$/\1/p' "$spec_file" | head -n1 | sed 's/[[:space:]]*$//')
    tw=$(sed -n 's/^total_groups:[[:space:]]*\(.*\)$/\1/p' "$spec_file" | head -n1 | sed 's/[[:space:]]*$//')

    case "$status" in
      complete|"") continue ;;
    esac

    entry="${slug}:${cw}/${tw}"
    if [ -z "$parts" ]; then
      parts="$entry"
    else
      parts="$parts, $entry"
    fi
  done
  ACTIVE_SPECS="$parts"
fi

# Check for recommended codebase exploration tools
TOOLS_MISSING=()
command -v ast-grep >/dev/null 2>&1 || TOOLS_MISSING+=("ast-grep")

TOOLS_MSG=""
if [ ${#TOOLS_MISSING[@]} -gt 0 ]; then
  TOOLS_MSG="Missing recommended tools: ${TOOLS_MISSING[*]}. See README for setup."
fi

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

# Emit JSON
LANGS_STR="${DETECTED_LANGS[*]+"${DETECTED_LANGS[*]}"}"
cat <<JSON
{
  "priority": "IMPORTANT",
  "detected_languages": "$(json_escape "$LANGS_STR")",
  "core_skills": "$(json_escape "$CORE_SKILLS")",
  "language_skills": "$(json_escape "$LANG_SKILLS")",
  "ops_enabled": $OPS_ENABLED,
  "ops_skills": "$(json_escape "$OPS_SKILLS")",
  "tools_warning": "$(json_escape "$TOOLS_MSG")",
  "recent_learnings": "$(json_escape "$RECENT_LEARNINGS")",
  "active_specs": "$(json_escape "$ACTIVE_SPECS")",
  "style": "Apply core/token-efficiency (standard) to human-facing output only. Drop filler, lead with action, fragments ok. Code/commands/paths/specs unchanged.",
  "external_writes_policy": "Agents MUST check ops_enabled before executing any remote-write command (git push, gh pr, docker push, deploy). When ops_enabled=false, report the intended action as a Follow-up in docs/agent-reporting.md format; do not execute.",
  "spec_resumption_policy": "When active_specs is non-empty, lead surfaces the in-progress specs on first response and asks the user whether to resume (/orchestrate --resume <slug>), ignore, or mark blocked. See agents/lead.md Step 0."
}
JSON
