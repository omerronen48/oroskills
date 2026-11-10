#!/usr/bin/env bash
# Behavior test for pre-push-hook.sh (loop-kernel outer loop): runs factory-check on push, via real `git push`.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO/skills/loop-kernel/pre-push-hook.sh"
fail() { echo "FAIL: $1"; exit 1; }
[ -f "$HOOK" ] || fail "pre-push-hook.sh missing"
[ "$(git -C "$REPO" ls-files -s skills/loop-kernel/pre-push-hook.sh | cut -c1-6)" = 100755 ] || fail "hook must be mode 100755 in git"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export OROSKILLS_KERNEL="$REPO/skills/loop-kernel"
# fresh remote + clone with hook installed; base commit pushed on main
mk() { # $1 = name
  git init -q --bare "$T/$1.git"; git clone -q "$T/$1.git" "$T/$1" 2>/dev/null; cd "$T/$1"
  git config user.email t@t; git config user.name t; git checkout -q -b main
  install -m 755 "$HOOK" .git/hooks/pre-push
  echo x > f; git add -A; git commit -qm base; git push -q -u origin main 2>/dev/null
  git remote set-head origin main >/dev/null 2>&1 || true
}
checks() { mkdir -p .factory; printf '%s\n' "$1" > .factory/checks; git add -A; git commit -qm c; }
push() { set +e; out="$(git push "$@" 2>&1)"; rc=$?; set -e; }

# (a) green and red on an existing branch
mk a; checks 'true'; push origin main
[ $rc = 0 ] || fail "(a) green push should succeed: $out"
echo y > g; echo 'test -f g' >> .factory/checks; git add -A; git commit -qm more; push origin main
[ $rc = 0 ] || fail "(a2) second green push (appended check) should succeed: $out"
echo z > h; checks 'test -f h'; push origin main
[ $rc != 0 ] || fail "(a3) replacing a check line should be rejected"
grep -qi "factory check" <<<"$out" || fail "(a3) output missing 'factory check': $out"
# (b) red blocks
mk b; checks 'echo boom; false'; push origin main
[ $rc != 0 ] || fail "(b) red push should be rejected"
grep -q boom <<<"$out" || fail "(b) output missing boom"
grep -qF "→ fix:" <<<"$out" || fail "(b) missing remediation"
grep -qF -- "--no-verify" <<<"$out" || fail "(b) missing --no-verify note"
mk b2; checks 'echo kaboom2; test -f nope'; push origin main
[ $rc != 0 ] && grep -q kaboom2 <<<"$out" || fail "(b2) second red input should be rejected"
# (c) new remote branch still checked
mk c; git checkout -q -b feat; checks 'echo newred; false'; push -u origin feat
[ $rc != 0 ] || fail "(c) red new branch should be rejected"
grep -q newred <<<"$out" || fail "(c) checks did not run for new branch"
mk c2; git checkout -q -b feat2; checks 'true'; push -u origin feat2
[ $rc = 0 ] || fail "(c2) green new branch should succeed: $out"
mk c3; git checkout -q -b feat3; checks 'echo r3; false'; push origin feat3   # no -u: falls back to origin/HEAD
[ $rc != 0 ] || fail "(c3) red new branch w/o upstream should be rejected"
# (d) no .factory/checks -> silent success
mk d; echo z > z; git add -A; git commit -qm z; push origin main
[ $rc = 0 ] || fail "(d) unbootstrapped push should succeed: $out"
mk d2; git checkout -q -b other; echo q > q; git add -A; git commit -qm q; push -u origin other
[ $rc = 0 ] || fail "(d2) unbootstrapped new branch should succeed: $out"
# (e) kernel missing
mk e; checks 'true'; OROSKILLS_KERNEL="$T/nokernel" push origin main
[ $rc != 0 ] || fail "(e) missing kernel should reject"
grep -qF "loop-kernel not found" <<<"$out" || fail "(e) message"
grep -qF "→ fix:" <<<"$out" || fail "(e) remediation"
mk e2; checks 'true'; OROSKILLS_KERNEL="$T/other-missing" push origin main
[ $rc != 0 ] && grep -qF "loop-kernel not found" <<<"$out" || fail "(e2) second missing path"
# (f) deletion not blocked
mk f; git checkout -q -b gone; checks 'true'; push -u origin gone; [ $rc = 0 ] || fail "(f) setup: $out"
git checkout -q main; checks 'false'                     # red checks present, must not matter
push origin --delete gone
[ $rc = 0 ] || fail "(f) deletion should not be blocked: $out"
# (g) deleting/emptying .factory/checks must not disable the hook
mk g; checks 'true'; push origin main; [ $rc = 0 ] || fail "(g) setup: $out"
git rm -q .factory/checks; git commit -qm rmchecks; push origin main
[ $rc != 0 ] || fail "(g) deleting .factory/checks should be rejected"
grep -qi "factory check" <<<"$out" || fail "(g) output missing 'factory check': $out"
mk g2; checks 'true'; push origin main; [ $rc = 0 ] || fail "(g2) setup: $out"
echo '# nothing' > .factory/checks; git add -A; git commit -qm emptied; push origin main
[ $rc != 0 ] || fail "(g2) comment-only .factory/checks should be rejected"
grep -qi "factory check" <<<"$out" || fail "(g2) output missing 'factory check': $out"
# (h) delete-only push never needs the kernel
mk h; git checkout -q -b gone2; checks 'true'; push -u origin gone2; [ $rc = 0 ] || fail "(h) setup: $out"
git checkout -q main; OROSKILLS_KERNEL="$T/nokernel" push origin --delete gone2
[ $rc = 0 ] || fail "(h) delete-only push with missing kernel should succeed: $out"
echo "PASS: pre-push hook"
