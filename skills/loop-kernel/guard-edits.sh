#!/usr/bin/env bash
# PreToolUse hook (loop-kernel §8). Denies Edit/Write/NotebookEdit on:
#  - .loop/goal.md while .loop/active exists (goal frozen for the run)
#  - any file listed in .loop/test-lock (tests locked before code existed)
# Bash writes bypass this hook; test-guard.sh's hash check catches those.
set -uo pipefail
command -v jq >/dev/null || exit 0
fp="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[[ -n "$fp" ]] || exit 0
[[ "$fp" == /* ]] || fp="${CLAUDE_PROJECT_DIR:-$PWD}/$fp"
dir="$(dirname "$fp")"
[[ -d "$dir" ]] || exit 0                      # new directory → can't be a locked file
real="$(cd "$dir" && pwd -P)/$(basename "$fp")"
top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
top="$(cd "$top" && pwd -P)"
rel="${real#"$top"/}"
deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
if [[ "$rel" == ".loop/goal.md" && -f "$top/.loop/active" ]]; then
  deny "loop-kernel: .loop/goal.md is frozen for this run. If the goal is wrong, stop and tell the user (they can rm .loop/active)."
fi
if [[ -f "$top/.loop/test-lock" ]] && sed -E 's/^[0-9a-f]+ [ *]?//' "$top/.loop/test-lock" | grep -qxF -- "$rel"; then
  deny "loop-kernel: $rel is a locked test, written before the code. Never edit tests to get green. If it is wrong, write a TEST-DISPUTE: block in your report."
fi
exit 0
