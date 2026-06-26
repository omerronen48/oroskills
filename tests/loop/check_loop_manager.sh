# tests/loop/check_loop_manager.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
f="$ROOT/pipelines/loop-pipeline/commands/loop-manager.md"
test -f "$f" || { echo "FAIL: loop-manager.md missing"; exit 1; }
# Orchestrator contract markers.
for k in '\$ARGUMENTS' '--dry-run' '--retriage' 'oro-triager' 'oro-triager:v1' \
         'risk:low' 'risk:medium' 'risk:high' 'type:' 'agent:ready' 'needs:human' \
         'gh label create' 'gh issue' 'comment' 'gh auth'; do
  grep -Eq -- "$k" "$f" || { echo "FAIL: loop-manager missing contract: $k"; exit 1; }
done
# Design card present.
for k in 'JOB' 'ALLOWED' 'FORBIDDEN' 'EVALUATION'; do
  grep -q "$k" "$f" || { echo "FAIL: design card missing field: $k"; exit 1; }
done
# Boundary: must forbid code/PR/merge.
grep -Eqi 'never.*(merge|pull request|PR)|no code|FORBIDDEN' "$f" || { echo "FAIL: no boundary statement"; exit 1; }
echo "PASS"
