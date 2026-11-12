#!/usr/bin/env bash
# Behavior test for the auto-only Stop hook.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO/skills/loop-kernel/goal-stop.sh"
fail() { echo "FAIL: $1"; exit 1; }
command -v jq >/dev/null || { echo "SKIP: jq missing"; exit 0; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
run() { echo '{}' | CLAUDE_PROJECT_DIR="$D" bash "$HOOK"; }
goal() { mkdir -p "$D/.loop"; printf '# Goal\nShip it.\n\n## Done-criteria\n- [ ] `%s` exits 0\n\n## Rubric\n- x: y\n' "$1" > "$D/.loop/goal.md"; }

# 1. no goal, no marker -> allow silently
[ -z "$(run)" ] || fail "no goal should allow"
# 2. goal but no auto marker -> allow
goal false; [ -z "$(run)" ] || fail "no marker should allow"
# 3. marker + failing criterion -> block JSON
touch "$D/.loop/auto"
out="$(run)"; [ "$(jq -r .decision <<<"$out")" = block ] || fail "should block"
grep -q "false" <<<"$(jq -r .reason <<<"$out")" || fail "reason names failing cmd"
# 4. blocks 2 and 3 still block, 4th call gives up + escalates
run >/dev/null; run >/dev/null
[ -z "$(run)" ] || fail "4th call should give up"
grep -q "ESCALATE" "$D/.loop/escalations.md" || fail "escalation note missing"
# 5. passing criterion -> allow and counter reset
goal true; [ -z "$(run)" ] || fail "passing should allow"
[ ! -f "$D/.loop/stop-blocks" ] || fail "counter should reset"

# 6. jq missing -> allow silently, no counter write
B="$D/bin"; mkdir -p "$B"; rm -f "$D/.loop/stop-blocks"; goal false
for t in bash cat awk sed tail rm dirname; do ln -s "$(command -v $t)" "$B/$t"; done
out="$(echo '{}' | PATH="$B" CLAUDE_PROJECT_DIR="$D" "$B/bash" "$HOOK")"
[ -z "$out" ] || fail "no jq should allow silently"
[ ! -f "$D/.loop/stop-blocks" ] || fail "no jq should not bump counter"

echo "PASS: goal-stop"
