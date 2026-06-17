# tests/dev/check_roadmap_import.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$ROOT/pipelines/dev-pipeline/commands/dev.md"
F="$ROOT/tests/dev/fixtures/roadmap-sample.md"
test -f "$D" || { echo "FAIL: dev.md missing"; exit 1; }

# --- dev.md documents the import contract ---
for kw in 'roadmap' 'ROADMAP\.md' '\.dev/roadmap\.md' 'docs/roadmap\.md' \
          '--import' '--force' 'Milestone' 'pending' 'Goals' 'goals\.md' \
          'complete' 'detect'; do
  grep -Eqi -e "$kw" "$D" || { echo "FAIL: dev.md missing import contract: $kw"; exit 1; }
done

# --- parse simulation: reference impl of the documented milestone rule ---
test -f "$F" || { echo "FAIL: fixture missing"; exit 1; }
mcount=$(grep -Ec '^## (Milestone|Phase|M[0-9]|[0-9]+[.)])' "$F")
[ "$mcount" -eq 4 ] || { echo "FAIL: expected 4 milestone headings, got $mcount"; exit 1; }
first=$(grep -E '^## (Milestone|Phase|M[0-9]|[0-9]+[.)])' "$F" | head -1)
echo "$first" | grep -q "Auth foundation" || { echo "FAIL: first milestone not Auth foundation"; exit 1; }
goals=$(awk '/^## Goals$/{f=1;next} /^## /{f=0} f' "$F")
echo "$goals" | grep -qi "billing system" || { echo "FAIL: goals body not extracted"; exit 1; }
echo "PASS"
