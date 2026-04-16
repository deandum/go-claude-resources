# shellcheck shell=bash
# Shared helpers for session-start.sh, session-end.sh, learn.sh.
# Source once per process; re-sourcing is a no-op.

[ -n "${_CLAUDE_HOOKS_COMMON_LOADED:-}" ] && return 0
_CLAUDE_HOOKS_COMMON_LOADED=1

# Escapes a string for use inside a double-quoted JSON value.
# Handles backslash, double-quote, and the common control characters
# (newline, carriage return, tab). Other control chars are rare in the
# values we emit (skill names, tool names, paths, learning text) and
# are left as-is.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Memoized absolute path to the project root. Falls back to $PWD outside
# of a git checkout so the hooks still work on loose directories.
project_root() {
  if [ -z "${_CLAUDE_HOOKS_PROJECT_ROOT:-}" ]; then
    _CLAUDE_HOOKS_PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  fi
  printf '%s' "$_CLAUDE_HOOKS_PROJECT_ROOT"
}

# Memoized basename of project_root. Used as the per-project namespace
# for learnings and buffer files.
project_slug() {
  if [ -z "${_CLAUDE_HOOKS_PROJECT_SLUG:-}" ]; then
    _CLAUDE_HOOKS_PROJECT_SLUG=$(basename "$(project_root)")
  fi
  printf '%s' "$_CLAUDE_HOOKS_PROJECT_SLUG"
}

# Per-user buffer directory for learning JSONL fragments. Prefers
# $XDG_RUNTIME_DIR (Linux/systemd tmpfs, user-owned, mode 700 by default)
# and falls back to $HOME/.cache — which is where macOS lands, since
# XDG_RUNTIME_DIR is unset there. Created mode 700 on first use.
buffer_dir() {
  if [ -z "${_CLAUDE_HOOKS_BUFFER_DIR:-}" ]; then
    local base="${XDG_RUNTIME_DIR:-$HOME/.cache}"
    _CLAUDE_HOOKS_BUFFER_DIR="$base/claude-resources/buffers"
    mkdir -p "$_CLAUDE_HOOKS_BUFFER_DIR"
    chmod 700 "$_CLAUDE_HOOKS_BUFFER_DIR" 2>/dev/null || true
  fi
  printf '%s' "$_CLAUDE_HOOKS_BUFFER_DIR"
}

# Advisory exclusive lock around a command that mutates $1.
# Uses flock when available, mkdir-based spinlock (5 s timeout) otherwise.
# If neither succeeds, logs a warning and runs the command unlocked —
# learnings are best-effort, not critical.
#
# Usage: with_lock <file> <cmd> [args...]
with_lock() {
  local file="$1"
  shift

  if command -v flock >/dev/null 2>&1; then
    (
      exec 9>>"$file.lock"
      flock -x 9
      "$@"
    )
    return $?
  fi

  local lock_dir="$file.lock"
  local waited=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    if [ "$waited" -ge 50 ]; then
      echo "[hooks] could not acquire lock on $file after 5s; proceeding unlocked" >&2
      "$@"
      return $?
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  local rc=0
  "$@" || rc=$?
  rmdir "$lock_dir" 2>/dev/null || true
  return "$rc"
}

# Lists the names of immediate subdirectories of $1 without forking
# basename per entry. Prints nothing if $1 is missing or empty.
list_subdirs() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  shopt -s nullglob
  local d name names=()
  for d in "$dir"/*/; do
    name=${d%/}
    name=${name##*/}
    names+=("$name")
  done
  shopt -u nullglob
  [ ${#names[@]} -eq 0 ] && return 0
  # Sort for deterministic output
  printf '%s\n' "${names[@]}" | sort
}
