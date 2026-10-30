#!/usr/bin/env bash
# mutate-check.sh <base-ref> "<test command>"   (loop-kernel §2 step 3)
# Proves the tests exercise the change:
#  1. Revert check: put every changed non-test file back to <base-ref>
#     (delete added ones); the test command must now FAIL.
#  2. Up to 3 operator-flip mutants on added non-test lines; each must
#     make the test command fail.
# Exit 0 = all good; 1 = tests pass with the change reverted; 3 = mutants
# survived (printed); 2 = can't run (bad ref, dirty tree).
# ponytail: textual first-match flips; swap in mutmut/stryker per language if needed.
set -uo pipefail
base="${1:-}"; cmd="${2:-}"
[[ -n "$base" && -n "$cmd" ]] || { echo "usage: mutate-check.sh <base-ref> <test-cmd>"; exit 2; }
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "mutate-check: bad ref $base"; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "mutate-check: working tree dirty"; exit 2; }
is_test() { [[ "$1" =~ (^|/)(tests?|__tests__|spec)/ || "$1" =~ (_test\.|\.test\.|\.spec\.|(^|/)test_) ]]; }
passes() { bash -c "$cmd" >/dev/null 2>&1; }

mod=(); add=()
while IFS=$'\t' read -r st f; do
  is_test "$f" && continue
  case "$st" in M) mod+=("$f") ;; A) add+=("$f") ;; esac
done < <(git diff --name-status "$base"..HEAD)
(( ${#mod[@]} + ${#add[@]} )) || { echo "mutate-check: no implementation changes"; exit 0; }

# 1. Revert check
(( ${#mod[@]} )) && git checkout -q "$base" -- "${mod[@]}"
(( ${#add[@]} )) && rm -f -- "${add[@]}"
if passes; then git checkout -q HEAD -- .; echo "mutate-check: tests still pass with the change reverted"; exit 1; fi
git checkout -q HEAD -- .

# 2. Operator flips: first flippable op per added line, max 3 mutants total.
FROM=('==' '!=' '<=' '>=' '&&' '||' 'true' 'false' 'True' 'False')
TO=('!=' '==' '>' '<' '||' '&&' 'false' 'true' 'False' 'True')
tried=0; survived=0
for f in ${mod[@]+"${mod[@]}"} ${add[@]+"${add[@]}"}; do
  while read -r start count; do
    count="${count:-1}"
    for (( n = start; n < start + count && tried < 3; n++ )); do
      for i in "${!FROM[@]}"; do
        w=0; [[ "${FROM[$i]}" =~ ^[A-Za-z]+$ ]] && w=1
        perl -i -pe 'BEGIN{($n,$from,$to,$w)=splice(@ARGV,0,4); $q=quotemeta($from); $p=$w?qr/\b$q\b/:qr/$q/} $hit=1 if $.==$n && s/$p/$to/; END{exit($hit?0:1)}' \
          "$n" "${FROM[$i]}" "${TO[$i]}" "$w" "$f" || continue
        tried=$((tried + 1))
        if passes; then echo "mutate-check: survived: $f:$n ${FROM[$i]} -> ${TO[$i]}"; survived=1; fi
        git checkout -q HEAD -- "$f"
        break
      done
    done
  done < <(git diff -U0 "$base"..HEAD -- "$f" | sed -nE 's/^@@ [^+]*\+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p')
done
(( survived )) && exit 3
exit 0
