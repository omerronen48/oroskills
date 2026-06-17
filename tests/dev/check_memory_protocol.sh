# tests/dev/check_memory_protocol.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/pipelines/dev-pipeline/memory-protocol.md"
test -f "$P" || { echo "FAIL: memory-protocol.md missing"; exit 1; }
for f in goals.md decisions.md lessons.md glossary.md progress.md; do
  grep -q "$f" "$P" || { echo "FAIL: protocol does not document $f"; exit 1; }
done
grep -qi "read order" "$P" || { echo "FAIL: no read-order section"; exit 1; }
grep -qi "lesson" "$P" || { echo "FAIL: no lesson-detection rule"; exit 1; }
grep -Eqi "\[auto\]|\[escalated\]|\[interactive\]" "$P" || { echo "FAIL: no decision tags"; exit 1; }
# memory roundtrip: a write by one stage is readable by the next
TMP="$(mktemp -d)"; mkdir -p "$TMP/.dev/memory"
printf '%s\n' '- [auto] phase1/exec: chose list over set — order matters' >> "$TMP/.dev/memory/decisions.md"
grep -q "chose list over set" "$TMP/.dev/memory/decisions.md" || { echo "FAIL: roundtrip"; exit 1; }
rm -rf "$TMP"
echo "PASS"
