#!/usr/bin/env bash
# lessons-for.sh returns ≤5 lessons: repo-wide + file-scoped matches, highest seen first.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LF="$REPO/skills/loop-kernel/lessons-for.sh"
fail() { echo "FAIL: $1"; exit 1; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
L="$D/lessons.md"
cat > "$L" <<'EOT'
# Lessons
- [distilled] 2026-10-01 empty rows crash csv → handle empty (files: src/csv/*; seen: 3)
- [distilled] 2026-10-01 api missing auth → add guard (files: src/api/*,*.sql; seen: 5)
- [interactive] always use pnpm
EOT
out="$(bash "$LF" "$L" src/csv/a.py)"
grep -q "csv" <<<"$out" || fail "scoped match missing"
grep -q "pnpm" <<<"$out" || fail "repo-wide lesson missing"
grep -q "auth" <<<"$out" && fail "non-matching scoped lesson leaked"
[ "$(head -1 <<<"$out" | grep -c csv)" = 1 ] || fail "higher seen should sort first"
out="$(bash "$LF" "$L" db/m.sql)"; grep -q "auth" <<<"$out" || fail "second glob in list must match"
[ -z "$(bash "$LF" "$D/missing.md" x)" ] || fail "missing file should print nothing"
for i in 1 2 3 4 5 6 7; do echo "- [interactive] general $i" >> "$L"; done
[ "$(bash "$LF" "$L" x | wc -l | tr -d ' ')" = 5 ] || fail "cap at 5"
printf -- '- general\n- x (files: src/*; seen: 2)\n' > "$D/l2.md"
bash "$LF" "$D/l2.md" other.py >/dev/null || fail "must exit 0 when output is correct"
echo "PASS: lessons-for"
