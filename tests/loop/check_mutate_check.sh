#!/usr/bin/env bash
# mutate-check.sh: revert check + operator-flip mutants, using bash as the "language".
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MC="$REPO/skills/loop-kernel/mutate-check.sh"
fail() { echo "FAIL: $1"; exit 1; }
CMD='bash tests/t.sh'
# repo <test body> <head impl>: base impl is "always true", tests committed with HEAD impl.
repo() {
  local d; d="$(mktemp -d)"; cd "$d"
  git init -q; git config user.email t@t; git config user.name t
  mkdir -p src tests; printf 'ok(){ true; }\n' > src/f.sh; git add -A; git commit -qm base
  printf '%s\n' "$1" > tests/t.sh; printf '%b' "$2" > src/f.sh; git add -A; git commit -qm head
}
rc() { set +e; out="$(bash "$MC" HEAD~1 "$CMD")"; code=$?; set -e; }

# 1. good tests: revert fails them, == flip killed → 0
repo '. src/f.sh; ok 1 && ! ok 2' 'ok(){ [ "$1" == 1 ]; }\n'; rc
[ "$code" = 0 ] || fail "good tests should exit 0 (got $code: $out)"
# 2. weak tests: still pass with change reverted → 1
repo '. src/f.sh; ok 1' 'ok(){ [ "$1" == 1 ]; }\n'; rc
[ "$code" = 1 ] || fail "weak tests should exit 1 (got $code)"
# 3. surviving mutant on an untested line → 3
repo '. src/f.sh; ok 1 && ! ok 2' 'ok(){ [ "$1" == 1 ]; }\nDEBUG=true\n'; rc
[ "$code" = 3 ] || fail "survivor should exit 3 (got $code)"; grep -q "survived" <<<"$out" || fail "survivor msg"
# 4. dirty tree → 2
repo '. src/f.sh; ok 1 && ! ok 2' 'ok(){ [ "$1" == 1 ]; }\n'; echo '# dirty' >> src/f.sh; rc
[ "$code" = 2 ] || fail "dirty tree should exit 2 (got $code)"
# 5. tree restored after a run
repo '. src/f.sh; ok 1 && ! ok 2' 'ok(){ [ "$1" == 1 ]; }\nDEBUG=true\n'; rc
[ -z "$(git status --porcelain)" ] || fail "working tree not restored"
echo "PASS: mutate-check"
