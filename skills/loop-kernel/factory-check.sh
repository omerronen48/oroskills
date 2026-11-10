#!/usr/bin/env bash
# factory-check.sh <base-ref> [goal-file] [manifest]   (loop-kernel §2)
# The one metric entry point, used in-session and in CI (outer-loop.yml):
#  1. every command line in .factory/checks (blank and # lines skipped)
#  2. every `cmd` under "## Done-criteria" in the goal file, when given
#  3. test-guard.sh <base-ref> [manifest]
# Each failure prints "FAIL: <what>", the output tail and a "→ fix:" line:
# that block is the retry prompt. Exit 0 green; 1 any failure; 2 can't run.
set -uo pipefail
base="${1:-}"; goal="${2:-}"; manifest="${3:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$base" ]] || { echo "usage: factory-check.sh <base-ref> [goal-file] [manifest]"; exit 2; }
abs() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
if [[ -n "$goal" ]]; then
  [[ -f "$goal" ]] || { echo "factory-check: goal file not found: $goal → fix: pass an existing goal file, or \"\" to skip it"; exit 2; }
  goal="$(abs "$goal")"
fi
if [[ -n "$manifest" ]]; then
  [[ -f "$manifest" ]] || { echo "factory-check: manifest not found: $manifest"; exit 2; }
  manifest="$(abs "$manifest")"
fi
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "factory-check: not a git repo"; exit 2; }
cd "$top" || exit 2
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "factory-check: bad ref $base"; exit 2; }

cmds=()
if [[ -f .factory/checks ]]; then
  while IFS= read -r l || [[ -n "$l" ]]; do
    [[ "$l" =~ ^[[:space:]]*(#|$) ]] || cmds+=("$l")
  done < .factory/checks
fi
if [[ -n "$goal" ]]; then
  n=${#cmds[@]}
  while IFS= read -r c; do [[ -n "$c" ]] && cmds+=("$c"); done < <(
    awk '/^## /{s=($0 ~ /^## Done-criteria/)} s && /^- \[.\] `/' "$goal" | sed -E 's/^- \[.\] `([^`]*)`.*/\1/')
  (( ${#cmds[@]} > n )) || { echo "factory-check: no runnable done-criteria in $goal → fix: write each as a '- [ ] \`<command>\` exits 0' line under ## Done-criteria"; exit 2; }
fi
(( ${#cmds[@]} )) || { echo "factory-check: nothing to check → fix: add .factory/checks (one command per line, loop-kernel §0) or pass a goal file"; exit 2; }

fail=0
for c in "${cmds[@]}"; do
  if ! out="$(bash -c "$c" 2>&1)"; then
    echo "FAIL: $c"
    tail -n 40 <<<"$out"
    echo "→ fix: make \`$c\` pass by changing the code; never edit this command, a locked test or the goal"
    fail=1
  fi
done
if ! out="$(bash "$here/test-guard.sh" "$base" ${manifest:+"$manifest"} 2>&1)"; then
  echo "FAIL: test-guard"; echo "$out"; fail=1
elif [[ -n "$out" ]]; then
  echo "$out"   # warn: lines, for the reviewer
fi
exit "$fail"
