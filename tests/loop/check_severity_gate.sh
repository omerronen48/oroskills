#!/usr/bin/env bash
# Findings carry P0-P3; only P0-P2 block; coders may REJECT a P2; reviewers rule on it.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines"
fail() { echo "FAIL: $1"; exit 1; }
SR="$R/ship-pipeline/agents/oro-reviewer.md"; TR="$R/dev-pipeline/agents/oro-task-reviewer.md"
CR="$R/dev-pipeline/agents/oro-critic.md"
for f in "$SR" "$TR" "$CR"; do grep -qF "[P0]" "$f" && grep -qF "[P3]" "$f" || fail "$f: severity tags missing"; done
grep -q "only \[P3\] findings → SHIP" "$SR" || fail "reviewer: P3-only must SHIP"
grep -q "\[P1\]–\[P2\] → NEEDS WORK" "$SR" || fail "reviewer: P1-P2 mapping"
grep -q "Critical = \[P0\]/\[P1\], Important = \[P2\], Minor = \[P3\]" "$TR" || fail "task-reviewer mapping"
grep -q "Important (should fix)" "$TR" || fail "task-reviewer must keep its report shape"
for f in "$SR" "$TR"; do grep -q "REJECT:" "$f" && grep -q "re-raise" "$f" || fail "$f: must rule on REJECT"; done
for f in "$R/ship-pipeline/agents/oro-coder.md" "$R/dev-pipeline/agents/oro-implementer.md"; do
  grep -q "REJECT: <finding> — <reason>" "$f" || fail "$f: REJECT protocol missing"
  grep -q "never a \[P0\], \[P1\] or \[reward-hack\]" "$f" || fail "$f: REJECT limits missing"
  grep -qF "→ fix:" "$f" || fail "$f: must follow → fix: lines"
done
echo "PASS: severity gate"
