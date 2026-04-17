#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PLUGIN_ROOT/skills"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PROJECT_ROOT=$(project_root)
PROJECT_SLUG=$(project_slug)

# Detect project language from the project root, not the current directory —
# running Claude from a subdir (myproject/cmd/tool/) must still detect the
# project languages at the top level.
DETECTED_LANGS=()
[ -f "$PROJECT_ROOT/go.mod" ]        && DETECTED_LANGS+=("go")
[ -f "$PROJECT_ROOT/angular.json" ]  && DETECTED_LANGS+=("angular")
[ -f "$PROJECT_ROOT/Cargo.toml" ]    && DETECTED_LANGS+=("rust")
{ [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]; } \
  && DETECTED_LANGS+=("python")
if [ -f "$PROJECT_ROOT/package.json" ] && [ ! -f "$PROJECT_ROOT/angular.json" ]; then
  DETECTED_LANGS+=("node")
fi

# List available core skills
CORE_SKILLS=$(list_subdirs "$SKILLS_DIR/core" | tr '\n' ',' | sed 's/,$//')

# List available language skills for detected languages
LANG_SKILLS=""
for lang in "${DETECTED_LANGS[@]+"${DETECTED_LANGS[@]}"}"; do
  skills=$(list_subdirs "$SKILLS_DIR/$lang" | tr '\n' ',' | sed 's/,$//')
  [ -n "$skills" ] && LANG_SKILLS+="$lang: [$skills] "
done
LANG_SKILLS="${LANG_SKILLS% }"
[ -z "$LANG_SKILLS" ] && LANG_SKILLS="none"

# Detect ops-skills opt-in: ops_enabled is true iff skills/ops/ exists AND
# contains at least one skill subdirectory (e.g. skills/ops/git-remote/).
# An empty skills/ops/ directory is NOT sufficient — agents must find at least
# one ops skill to load before writing to remote services.
OPS_ENABLED="false"
OPS_SKILLS=""
if [ -d "$SKILLS_DIR/ops" ]; then
  ops_list=$(list_subdirs "$SKILLS_DIR/ops" | tr '\n' ',' | sed 's/,$//')
  if [ -n "$ops_list" ]; then
    OPS_ENABLED="true"
    OPS_SKILLS="$ops_list"
  fi
fi

# Load recent operational learnings for this project
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

# Load project constitution invariants (id + severity pairs) from docs/constitution.md.
# Format in JSON: "id1(critical);id2(important);..." — parseable by agents without yq.
PROJECT_CONSTITUTION=""
CONSTITUTION_FILE="$PROJECT_ROOT/docs/constitution.md"
if [ -f "$CONSTITUTION_FILE" ]; then
  PROJECT_CONSTITUTION=$(awk '
    BEGIN { in_fm = 0; in_inv = 0; id = ""; sev = ""; out = "" }
    /^---[[:space:]]*$/ { if (!in_fm) { in_fm = 1; next } else { exit } }
    !in_fm { next }
    /^invariants:/ { in_inv = 1; next }
    in_inv && /^[^[:space:]-]/ { in_inv = 0 }
    in_inv && /^[[:space:]]*-[[:space:]]*id:/ {
      if (id != "" && sev != "") {
        out = out (out == "" ? "" : ";") id "(" sev ")"
      }
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      gsub(/"/, "")
      id = $0
      sev = ""
    }
    in_inv && /^[[:space:]]+severity:/ {
      sub(/^[[:space:]]*severity:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      gsub(/"/, "")
      sev = $0
    }
    END {
      if (id != "" && sev != "") {
        out = out (out == "" ? "" : ";") id "(" sev ")"
      }
      print out
    }
  ' "$CONSTITUTION_FILE")

  # Warn if the file exists but parsing produced nothing — likely malformed YAML.
  if [ -z "$PROJECT_CONSTITUTION" ]; then
    echo "[hooks session-start] warn: $CONSTITUTION_FILE exists but no invariants parsed; check frontmatter (must have 'invariants:' list with 'id:' and 'severity:' on each entry)" >&2
  fi
fi

# Scan for in-progress spec directories (status != complete).
# Validate frontmatter fields; malformed specs are excluded from ACTIVE_SPECS
# with a stderr warning so the user can fix them.
ACTIVE_SPECS=""
SPECS_ROOT="$PROJECT_ROOT/docs/specs"
if [ -d "$SPECS_ROOT" ]; then
  parts=""
  for spec_dir in "$SPECS_ROOT"/*/; do
    spec_file="$spec_dir/spec.md"
    [ -f "$spec_file" ] || continue
    slug=${spec_dir%/}
    slug=${slug##*/}

    frontmatter=$(awk '
      BEGIN { in_fm = 0; status = ""; cw = ""; tw = "" }
      /^---[[:space:]]*$/ { if (!in_fm) { in_fm = 1; next } else { exit } }
      !in_fm { next }
      /^status:/        { if (status == "") { sub(/^status:[[:space:]]*/, "");        sub(/[[:space:]]+$/, ""); status = $0 } }
      /^current_group:/ { if (cw == "")     { sub(/^current_group:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); cw = $0 } }
      /^total_groups:/  { if (tw == "")     { sub(/^total_groups:[[:space:]]*/, "");  sub(/[[:space:]]+$/, ""); tw = $0 } }
      END { printf "%s|%s|%s", status, cw, tw }
    ' "$spec_file")

    status=${frontmatter%%|*}
    rest=${frontmatter#*|}
    cw=${rest%%|*}
    tw=${rest#*|}

    # Skip completed specs silently.
    [ "$status" = "complete" ] && continue

    # Warn and skip specs with missing/invalid frontmatter — main Claude would
    # otherwise act on bogus state during resumption.
    if [ -z "$status" ]; then
      echo "[hooks session-start] warn: $spec_file has no 'status' field in frontmatter; excluded from active_specs" >&2
      continue
    fi
    case "$status" in
      draft|approved|in-progress|blocked) ;;
      *)
        echo "[hooks session-start] warn: $spec_file has invalid status='$status' (expected draft|approved|in-progress|complete|blocked); excluded" >&2
        continue
        ;;
    esac
    if [ -z "$cw" ] || [ -z "$tw" ]; then
      echo "[hooks session-start] warn: $spec_file missing current_group or total_groups; excluded" >&2
      continue
    fi

    entry="${slug}:${cw}/${tw}"
    if [ -z "$parts" ]; then
      parts="$entry"
    else
      parts="$parts, $entry"
    fi
  done
  ACTIVE_SPECS="$parts"
fi

# --- Integration discovery (every probe is try/fail-silent) ---

# Known CLI tools agents might leverage. Fixed list keeps noise low.
KNOWN_TOOLS=(ast-grep fd rg jq yq gh docker kubectl)
AVAILABLE_TOOLS=()
MISSING_TOOLS=()
for t in "${KNOWN_TOOLS[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    AVAILABLE_TOOLS+=("$t")
  else
    MISSING_TOOLS+=("$t")
  fi
done
AVAILABLE_TOOLS_STR=$(IFS=,; echo "${AVAILABLE_TOOLS[*]+"${AVAILABLE_TOOLS[*]}"}")
MISSING_TOOLS_STR=$(IFS=,; echo "${MISSING_TOOLS[*]+"${MISSING_TOOLS[*]}"}")

# Plugin manifest path — used by both MCP discovery (plugin-bundled .mcp.json)
# and the USER_PLUGINS block below.
_plugins_manifest="${HOME}/.claude/plugins/installed_plugins.json"

# MCP server names. jq-only: proper JSON parsing is the only way to
# handle nested objects correctly. When jq is missing, emit nothing
# and warn once — MCP discovery is observational, no agent depends on it.
#
# Handles three on-disk shapes:
#   1. {"mcpServers": {"name": {...}}}                — ~/.claude.json, settings.json
#   2. {"projects": {"<dir>": {"mcpServers": {...}}}} — ~/.claude.json
#   3. {"name": {"command": "...", "args": [...]}}    — flat, used by some plugin .mcp.json
_mcp_extract_names() {
  local file="$1"
  [ -f "$file" ] || return 0
  jq -r '
    [
      (.mcpServers // {} | keys),
      (to_entries | map(select(.value | type == "object" and has("command"))) | map(.key)),
      (.projects // {} | to_entries | map(.value.mcpServers // {} | keys) | add // [])
    ] | add | unique | .[]
  ' "$file" 2>/dev/null || true
}

MCP_SERVERS=""
if command -v jq >/dev/null 2>&1; then
  MCP_SERVERS=$({
    _mcp_extract_names "${HOME}/.claude.json"
    _mcp_extract_names "${HOME}/.claude/settings.json"
    _mcp_extract_names "$PROJECT_ROOT/.mcp.json"
    # Plugin-bundled .mcp.json files live under each plugin's installPath.
    if [ -f "$_plugins_manifest" ]; then
      jq -r '.plugins // {} | to_entries[] | .value[] | .installPath' "$_plugins_manifest" 2>/dev/null \
        | while IFS= read -r install_path; do
            [ -n "$install_path" ] && _mcp_extract_names "$install_path/.mcp.json"
          done
    fi
  } | sort -u | tr '\n' ',' | sed 's/,$//')
else
  echo "[hooks session-start] jq not installed; MCP server discovery skipped" >&2
fi

# User-scope skills and agents: direct bash listings under ~/.claude/
USER_SKILLS=$(list_subdirs "${HOME}/.claude/skills" | tr '\n' ',' | sed 's/,$//')
USER_AGENTS=$(list_subdirs "${HOME}/.claude/agents" | tr '\n' ',' | sed 's/,$//')

# User-scope plugins: read manifest, strip @marketplace suffix from keys
USER_PLUGINS=""
if [ -f "$_plugins_manifest" ]; then
  if command -v jq >/dev/null 2>&1; then
    USER_PLUGINS=$(jq -r '.plugins // {} | keys | map(split("@")[0]) | unique | join(",")' \
      "$_plugins_manifest" 2>/dev/null || true)
  else
    USER_PLUGINS=$(sed -n 's/^[[:space:]]*"\([^"@]*\)@[^"]*"[[:space:]]*:.*/\1/p' \
      "$_plugins_manifest" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//' || true)
  fi
fi

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
  "available_tools": "$(json_escape "$AVAILABLE_TOOLS_STR")",
  "missing_tools": "$(json_escape "$MISSING_TOOLS_STR")",
  "mcp_servers": "$(json_escape "$MCP_SERVERS")",
  "user_skills": "$(json_escape "$USER_SKILLS")",
  "user_agents": "$(json_escape "$USER_AGENTS")",
  "user_plugins": "$(json_escape "$USER_PLUGINS")",
  "recent_learnings": "$(json_escape "$RECENT_LEARNINGS")",
  "active_specs": "$(json_escape "$ACTIVE_SPECS")",
  "project_constitution": "$(json_escape "$PROJECT_CONSTITUTION")",
  "external_writes_policy": "Agents MUST check ops_enabled before executing any remote-write command (git push, gh pr, docker push, deploy). When ops_enabled=false, report the intended action as a Follow-up in the Agent Reporting format defined in docs/extending.md; do not execute.",
  "spec_resumption_policy": "When active_specs is non-empty, main Claude surfaces the in-progress specs on first response via AskUserQuestion and asks whether to resume (/orchestrate --resume <slug>), ignore, or mark blocked. See skills/core/orchestration/SKILL.md Resumption section.",
  "constitution_policy": "When project_constitution is non-empty, reviewer MUST check every diff against the listed invariants after the five-axis review. Critical-severity violations force Critical findings; important-severity violations force Important findings. Critic MUST use invariants as the reference frame for Scope Hazards during /define. Full invariant text lives at docs/constitution.md."
}
JSON
