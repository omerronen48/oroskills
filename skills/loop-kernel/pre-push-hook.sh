#!/usr/bin/env bash
# git pre-push hook (loop-kernel outer loop): runs factory-check.sh against the
# push base, so no check depends on an agent choosing to run it. Install: SKILL.md §0.
# ponytail: runs the full checks per push; scope to changed packages if pushes get slow.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
kernel="${OROSKILLS_KERNEL:-$HOME/.claude/skills/loop-kernel}"
while read -r lref lsha _ rsha; do
  [[ "$lsha" =~ ^0+$ ]] && continue
  if [[ "$lsha" != "$(git rev-parse HEAD)" ]]; then
    echo "pre-push: $lref is not checked out; factory-check skipped → fix: check it out and push from it"; continue
  fi
  base=""
  if [[ ! "$rsha" =~ ^0+$ ]] && git cat-file -e "$rsha^{commit}" 2>/dev/null; then base="$rsha"
  else
    for up in '@{upstream}' "refs/remotes/$1/HEAD"; do
      base="$(git merge-base "$lsha" "$up" 2>/dev/null)" && [[ -n "$base" ]] && break; base=""
    done
  fi
  [[ -n "$base" ]] || { echo "pre-push: no base to compare; skipped → fix: set an upstream (git push -u) or fetch the remote's default branch"; continue; }
  [[ -f .factory/checks ]] || git cat-file -e "$base:.factory/checks" 2>/dev/null || continue
  [[ -f "$kernel/factory-check.sh" ]] || { echo "pre-push: loop-kernel not found at $kernel → fix: run oroskills ./install.sh, or set OROSKILLS_KERNEL"; exit 1; }
  if ! out="$(bash "$kernel/factory-check.sh" "$base" 2>&1)"; then
    echo "$out"
    echo "pre-push: blocked by factory-check → fix: make the checks pass; agents never use --no-verify (loop-kernel §8)"; exit 1
  fi
done
exit 0
