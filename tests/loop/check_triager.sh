# tests/loop/check_triager.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
f="$ROOT/pipelines/loop-pipeline/agents/oro-triager.md"
test -f "$f" || { echo "FAIL: oro-triager.md missing"; exit 1; }
head -1 "$f" | grep -q '^---$' || { echo "FAIL: missing frontmatter"; exit 1; }
grep -q '^name: oro-triager$' "$f" || { echo "FAIL: name mismatch"; exit 1; }
grep -q '^description:' "$f" || { echo "FAIL: no description"; exit 1; }
# Read-only: tools line present, must NOT grant Write or Edit.
grep -q '^tools:' "$f" || { echo "FAIL: no tools line"; exit 1; }
grep '^tools:' "$f" | grep -Eq 'Write|Edit' && { echo "FAIL: triager must be read-only (no Write/Edit)"; exit 1; }
# Risk taxonomy + routing vocabulary.
for k in 'risk:low' 'risk:medium' 'risk:high' 'agent:ready' 'needs:human' 'fits-one-ship'; do
  grep -q "$k" "$f" || { echo "FAIL: missing taxonomy term: $k"; exit 1; }
done
# Conservative-default contract.
grep -Eqi 'conservativ|uncertain' "$f" || { echo "FAIL: no conservative-default rule"; exit 1; }
# Idempotency marker the orchestrator anchors on.
grep -q 'oro-triager:v1' "$f" || { echo "FAIL: missing assessment marker"; exit 1; }
echo "PASS"
