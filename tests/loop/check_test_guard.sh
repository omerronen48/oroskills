#!/usr/bin/env bash
# Behavior test for skills/loop-kernel/test-guard.sh using throwaway git repos.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TG="$REPO/skills/loop-kernel/test-guard.sh"
fail() { echo "FAIL: $1"; exit 1; }

# new_repo: fresh repo with one python and one js test, committed as base.
new_repo() {
  local d; d="$(mktemp -d)"; cd "$d"
  git init -q; git config user.email t@t; git config user.name t
  mkdir -p tests src
  printf 'def test_a():\n    assert 1 == 1\n\ndef test_b():\n    assert 2 == 2\n' > tests/test_x.py
  printf 'it("a", () => { expect(1).toBe(1) })\n' > src/x.test.js
  echo 'x = 1' > src/x.py
  git add -A; git commit -qm base
}
commit() { git add -A; git commit -qm change; }

# 1. plain code change passes
new_repo; echo 'x = 2' > src/x.py; commit
bash "$TG" HEAD~1 >/dev/null || fail "plain change should pass"

# 2. added it.skip fails
new_repo; printf 'it.skip("a", () => { expect(1).toBe(1) })\n' > src/x.test.js; commit
out="$(bash "$TG" HEAD~1)" && fail "it.skip should fail"; grep -q "skip" <<<"$out" || fail "skip msg"

# 3. added pytest xfail fails
new_repo; printf '@pytest.mark.xfail\ndef test_a():\n    assert 1 == 1\n\ndef test_b():\n    assert 2 == 2\n' > tests/test_x.py; commit
bash "$TG" HEAD~1 >/dev/null && fail "xfail should fail"

# 4. deleted assertion fails
new_repo; printf 'def test_a():\n    pass\n\ndef test_b():\n    assert 2 == 2\n' > tests/test_x.py; commit
out="$(bash "$TG" HEAD~1)" && fail "deleted assert should fail"; grep -q "assertion" <<<"$out" || fail "assert msg"

# 5. removed test def fails (count drop)
new_repo; printf 'def test_a():\n    assert 1 == 1\n    assert 2 == 2\n' > tests/test_x.py; commit
out="$(bash "$TG" HEAD~1)" && fail "count drop should fail"; grep -q "count" <<<"$out" || fail "count msg"

# 6. test file outside manifest fails; inside passes
new_repo; printf 'def test_a():\n    assert 1 == 1\n\ndef test_b():\n    assert 2 == 2\n\ndef test_c():\n    assert 3 == 3\n' > tests/test_x.py; commit
echo "src/x.py" > m.txt
bash "$TG" HEAD~1 m.txt >/dev/null && fail "outside manifest should fail"
echo "tests/test_x.py" >> m.txt
bash "$TG" HEAD~1 m.txt >/dev/null || fail "inside manifest should pass"

# 7. bad ref exits 2
new_repo; set +e; bash "$TG" nope >/dev/null; rc=$?; set -e
[ "$rc" -eq 2 ] || fail "bad ref should exit 2 (got $rc)"

# 8. locked test modified fails (even with assertions added, not removed)
new_repo; mkdir -p .loop; shasum -a 256 tests/test_x.py > .loop/test-lock
printf 'def test_a():\n    assert 1 == 1\n    assert 3 == 3\n\ndef test_b():\n    assert 2 == 2\n' > tests/test_x.py; commit
out="$(bash "$TG" HEAD~1)" && fail "locked edit should fail"; grep -q "locked" <<<"$out" || fail "locked msg"

# 9. test config file / runner setting changed fails; allowed if in manifest
new_repo; echo '[pytest]' > pytest.ini; git add -A; git commit -qm cfg; echo 'addopts = -k "not slow"' >> pytest.ini; commit
bash "$TG" HEAD~1 >/dev/null && fail "config change should fail"
echo "pytest.ini" > m.txt; bash "$TG" HEAD~1 m.txt >/dev/null || fail "config change in manifest should pass"
new_repo; echo '{"scripts":{"test":"jest"}}' > package.json; git add -A; git commit -qm pkg
echo '{"scripts":{"test":"jest --passWithNoTests"}}' > package.json; commit
bash "$TG" HEAD~1 >/dev/null && fail "runner setting change should fail"

# 10. test literal hard-coded in implementation -> warn, exit 0
new_repo
printf 'def test_a():\n    assert 1 == 1\n\ndef test_b():\n    assert 2 == 2\n\ndef test_c():\n    assert f(41) == "magic-answer"\n' > tests/test_x.py
printf 'def f(x):\n    if x == 41: return "magic-answer"\n' > src/x.py; commit
out="$(bash "$TG" HEAD~1)" || fail "literal warn must not fail"
grep -q "warn" <<<"$out" || fail "literal warn missing"

# 11. conventional inline Rust unit tests are guarded even though they live in src/
new_repo
cat > src/lib.rs <<'EOF'
#[cfg(test)]
mod tests {
    #[test]
    fn works() { assert!(true); }
}
EOF
git add -A; git commit -qm rust-base
perl -i -pe 'print "    #[ignore]\n" if /#\[test\]/' src/lib.rs; commit
out="$(bash "$TG" HEAD~1)" && fail "inline Rust #[ignore] should fail"
grep -q "skip" <<<"$out" || fail "Rust ignore message missing"

echo "PASS: test-guard"
