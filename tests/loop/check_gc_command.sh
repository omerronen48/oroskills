#!/usr/bin/env bash
# Meta loop: /address-review records human signals; /gc runs scorecard + distiller weekly;
# the distiller proposes mechanical checks before prose.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines"
fail() { echo "FAIL: $1"; exit 1; }
G="$R/review-pipeline/commands/gc.md"; A="$R/review-pipeline/commands/address-review.md"; D="$R/dev-pipeline/agents/oro-distiller.md"
[ -f "$G" ] || fail "gc.md missing"
head -4 "$G" | grep -q '^description: ' || fail "gc frontmatter"
for s in "scorecard.sh" "--since" "oro-distiller" "gc mode" "human-feedback.md" ".dev/proposals/" "/schedule" "Never apply"; do
  grep -qF -- "$s" "$G" || fail "gc.md missing '$s'"
done
grep -q '"event":"pr_review"' "$A" || fail "address-review must log pr_review"
grep -q "human-feedback.md" "$A" || fail "address-review must append human feedback"
grep -qF -- "- [human] <YYYY-MM-DD> PR#<n>" "$A" || fail "human feedback lines must be dated"
grep -q "git worktree list --porcelain" "$A" || fail "address-review must write to the main checkout"
grep -q "awk -v s=" "$G" || fail "gc must filter feedback to the window"
grep -q "\[bot\]" "$A" || fail "address-review must exclude bots from human count"
grep -q "\[human\]" "$D" || fail "distiller must read [human] entries"
grep -q "Mechanical first" "$D" || fail "distiller mechanical-first rule"
grep -q ".factory/checks" "$D" || fail "distiller must propose .factory/checks lines"
grep -q "gc mode" "$D" || fail "distiller gc mode"
grep -q "\[deferred\]" "$D" || fail "distiller must read deferred findings"
grep -qi 'never apply' "$D" || fail "distiller must still never apply"
echo "PASS: gc + meta loop"
