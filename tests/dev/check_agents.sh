# tests/dev/check_agents.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
for a in oro-implementer oro-task-reviewer oro-phase-executor; do
  f="$ROOT/pipelines/dev-pipeline/agents/$a.md"
  test -f "$f" || { echo "FAIL: agent $a.md missing"; exit 1; }
  head -1 "$f" | grep -q '^---$' || { echo "FAIL: $a missing frontmatter"; exit 1; }
  grep -q "^name: $a$" "$f" || { echo "FAIL: $a name mismatch"; exit 1; }
  grep -q "^description:" "$f" || { echo "FAIL: $a no description"; exit 1; }
  grep -qi "memory-protocol\|\.dev/memory" "$f" || { echo "FAIL: $a no memory protocol ref"; exit 1; }
done
echo "PASS"
