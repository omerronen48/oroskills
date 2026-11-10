#!/usr/bin/env bash
# Behavior test for factory-check.sh (loop-kernel §2): checks file + goal done-criteria + test-guard.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FC="$REPO/skills/loop-kernel/factory-check.sh"
fail() { echo "FAIL: $1"; exit 1; }
rc_of() { set +e; "$@" >/dev/null 2>&1; local r=$?; set -e; echo "$r"; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cd "$D"; git init -q; git config user.email t@t; git config user.name t
mkdir -p src tests .factory .loop
printf 'def test_a():\n    assert 1 == 1\n' > tests/test_x.py; echo 'x = 1' > src/x.py
git add -A; git commit -qm base; BASE="$(git rev-parse HEAD)"

# 1. nothing to check -> exit 2 with remediation
[ "$(rc_of bash "$FC" "$BASE")" = 2 ] || fail "nothing to check should exit 2"
{ bash "$FC" "$BASE" 2>&1 || true; } | grep -q "→ fix:" || fail "nothing-to-check remediation"
# 2. bad ref -> exit 2
printf 'true\n' > .factory/checks
[ "$(rc_of bash "$FC" nope)" = 2 ] || fail "bad ref should exit 2"
# 3. passing checks, comments and blanks ignored -> 0
printf '# comment\n\ntrue\ntest -f src/x.py\n' > .factory/checks
[ "$(rc_of bash "$FC" "$BASE")" = 0 ] || fail "green checks should exit 0"
# 4. a failing check -> exit 1, FAIL line, output tail, remediation
printf 'true\necho boom-output; false\n' > .factory/checks
out="$(bash "$FC" "$BASE" 2>&1 || true)"
[ "$(rc_of bash "$FC" "$BASE")" = 1 ] || fail "red check should exit 1"
grep -qF "FAIL: echo boom-output; false" <<<"$out" || fail "FAIL line"
grep -q "boom-output" <<<"$out" || fail "output tail"
grep -qF "→ fix:" <<<"$out" || fail "remediation line"
# 5. goal done-criteria are run too (two distinct inputs)
printf 'true\n' > .factory/checks
printf '# Goal\nx\n\n## Done-criteria\n- [ ] `test -f src/missing.py` exits 0\n\n## Rubric\n- a: b\n' > .loop/goal.md
[ "$(rc_of bash "$FC" "$BASE" .loop/goal.md)" = 1 ] || fail "failing done-criterion should exit 1"
printf '# Goal\nx\n\n## Done-criteria\n- [ ] `test -f src/x.py` exits 0\n\n## Rubric\n- a: b\n' > .loop/goal.md
[ "$(rc_of bash "$FC" "$BASE" .loop/goal.md)" = 0 ] || fail "passing done-criterion should exit 0"
# 6. empty goal arg skips the goal; goal-only (no checks file) works
rm .factory/checks
[ "$(rc_of bash "$FC" "$BASE" .loop/goal.md)" = 0 ] || fail "goal-only should run"
printf 'true\n' > .factory/checks
[ "$(rc_of bash "$FC" "$BASE" "")" = 0 ] || fail "empty goal arg should be skipped"
# 7. test-guard violation surfaces as a failure
git add .factory; git commit -qm checks; BASE2="$(git rev-parse HEAD)"
S=skip; printf "import pytest\n@pytest.mark.$S\ndef test_a():\n    assert 1 == 1\n" > tests/test_x.py; git add tests; git commit -qm skip
out="$(bash "$FC" "$BASE2" 2>&1 || true)"
grep -q "FAIL: test-guard" <<<"$out" || fail "test-guard failure not surfaced"
grep -q "skip" <<<"$out" || fail "test-guard detail missing"
# 8. works from a subdirectory (resolves repo root and goal path)
git reset -q --hard "$BASE2"
cd src; [ "$(rc_of bash "$FC" "$BASE2" ../.loop/goal.md)" = 0 ] || fail "subdirectory run"; cd ..
# 9. a goal that is given but missing, or has no `- [ ] \`cmd\`` lines, is a can't-run (never silently skipped)
[ "$(rc_of bash "$FC" "$BASE2" .loop/nope.md)" = 2 ] || fail "missing goal file should exit 2"
[ "$(rc_of bash "$FC" "$BASE2" "" nope.txt)" = 2 ] || fail "missing manifest should exit 2"
printf '# Goal\nx\n\n## Done-criteria\n- Behavior check: `true`\n' > .loop/bad.md
[ "$(rc_of bash "$FC" "$BASE2" .loop/bad.md)" = 2 ] || fail "goal with no runnable criteria should exit 2"
{ bash "$FC" "$BASE2" .loop/bad.md 2>&1 || true; } | grep -q "→ fix:" || fail "no-criteria remediation"
echo "PASS: factory-check"
