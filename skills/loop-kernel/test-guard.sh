#!/usr/bin/env bash
# test-guard.sh <base-ref> [manifest-file]
# Fails (exit 1, one line per violation) when base..HEAD weakens tests:
# added skip/xfail, net-removed assertions, dropped test-definition count,
# a test file outside the manifest, a changed locked test (.loop/test-lock),
# or a changed test-runner config/setting not declared in the manifest.
# Prints "warn:" lines (exit unaffected) for test literals hard-coded in
# implementation. Exit 2 = can't run.
# ponytail: regex heuristics, not a parser; add per-language parsers if false positives bite.
set -uo pipefail
base="${1:-}"; manifest="${2:-}"
[[ -n "$base" ]] || { echo "usage: test-guard.sh <base-ref> [manifest]"; exit 2; }
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "test-guard: bad ref $base"; exit 2; }

SKIP='(\.skip\(|(^|[^a-zA-Z_])xit\(|xdescribe\(|@pytest\.mark\.(skip|xfail)|t\.Skip\(|#\[ignore\])'
ASSERT='(assert|expect\(|t\.(Error|Fatal))'
TESTDEF='(def test_|(^|[^a-zA-Z_.])it\(|(^|[^a-zA-Z_.])test\(|func Test|#\[test\])'
is_test() { [[ "$1" =~ (^|/)(tests?|__tests__|spec)/ || "$1" =~ (_test\.|\.test\.|\.spec\.|(^|/)test_) ]]; }
is_test_at() {
  local ref="$1" f="$2"
  is_test "$f" && return 0
  # Rust convention keeps unit tests inline in src/*.rs under #[cfg(test)].
  [[ "$f" == *.rs ]] && git show "$ref:$f" 2>/dev/null | grep -qF '#[cfg(test)]'
}

# count_defs <ref>: total test definitions across test files at <ref>.
# ponytail: O(test files) git show calls; fine for repo-sized suites.
count_defs() {
  local n=0 f c
  while IFS= read -r f; do
    is_test_at "$1" "$f" || continue
    c=$(git show "$1:$f" 2>/dev/null | grep -Ec "$TESTDEF" || true)
    n=$((n + c))
  done < <(git ls-tree -r --name-only "$1")
  echo "$n"
}

# Test-runner config files, and settings that silence or narrow test runs.
CFG_FILE='(^|/)(pytest\.ini|conftest\.py|tox\.ini|setup\.cfg|jest\.config\.[a-z]+|vitest\.config\.[a-z]+|\.mocharc[a-z.]*|karma\.conf\.[a-z]+)$'
CFG_KEY='(testPathIgnorePatterns|modulePathIgnorePatterns|coveragePathIgnorePatterns|passWithNoTests|"test" *:|addopts|testpaths|norecursedirs|collect_ignore)'
in_manifest() { [[ -n "$manifest" ]] && grep -qxF "$1" "$manifest"; }

fail=0; test_added=""; impl_added=""
while IFS= read -r f; do
  d="$(git diff "$base"..HEAD -- "$f")"
  added="$(grep -E '^\+[^+]' <<<"$d" || true)"
  removed="$(grep -E '^-[^-]' <<<"$d" || true)"
  if [[ "$f" =~ $CFG_FILE ]] && ! in_manifest "$f"; then echo "test-guard: test config file changed: $f"; fail=1; fi
  if ! is_test_at "$base" "$f" && ! is_test_at HEAD "$f"; then
    if grep -Eq "$CFG_KEY" <<<"$added"$'\n'"$removed" && ! in_manifest "$f"; then
      echo "test-guard: test runner setting changed in $f"; fail=1
    fi
    impl_added+="$added"$'\n'; continue
  fi
  test_added+="$added"$'\n'
  if grep -Eq "$SKIP" <<<"$added"; then echo "test-guard: skip/xfail added in $f"; fail=1; fi
  a=$(grep -Ec "$ASSERT" <<<"$added" || true); r=$(grep -Ec "$ASSERT" <<<"$removed" || true)
  if (( r > a )); then echo "test-guard: $((r - a)) assertion(s) removed in $f"; fail=1; fi
  if [[ -n "$manifest" ]] && ! in_manifest "$f"; then
    echo "test-guard: $f changed but not in manifest"; fail=1
  fi
done < <(git diff --name-only "$base"..HEAD)

# Locked tests (loop-kernel §8): any change, by any route, is a violation.
lock="$(git rev-parse --show-toplevel)/.loop/test-lock"
if [[ -f "$lock" ]]; then
  while IFS= read -r bad; do echo "test-guard: locked test modified: $bad"; fail=1; done \
    < <(cd "$(dirname "$lock")/.." && shasum -a 256 -c "$lock" 2>/dev/null | grep -v ': OK$' | sed 's/: FAILED.*//')
fi

# Warn (not fail): a literal from new test lines also hard-coded in implementation.
# ponytail: heuristic; the blind reviewer decides whether it's special-casing.
while IFS= read -r lit; do
  [[ -n "$lit" ]] && grep -qF -- "$lit" <<<"$impl_added" \
    && echo "test-guard: warn: test literal $lit also appears in implementation"
done < <(grep -oE '"[^"]{4,}"|[0-9]{3,}' <<<"$test_added" | sort -u)

before=$(count_defs "$base"); after=$(count_defs HEAD)
if (( after < before )); then echo "test-guard: test count dropped $before -> $after"; fail=1; fi
exit "$fail"
