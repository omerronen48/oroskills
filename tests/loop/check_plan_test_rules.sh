#!/usr/bin/env bash
# Plans must carry tests that are hard to game: ≥2 inputs per behavior + a Behavior check.
set -euo pipefail
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/skills/writing-plans-time/SKILL.md"
fail() { echo "FAIL: $1"; exit 1; }
grep -q "## Test quality rules" "$W" || fail "test quality section missing"
grep -q "at least 2 distinct inputs" "$W" || fail "multi-input rule missing"
grep -q "Behavior check" "$W" || fail "behavior check rule missing"
grep -q "committed by oro-tester before the implementer runs" "$W" || fail "plan-test handoff note missing"
echo "PASS: plan test rules"
