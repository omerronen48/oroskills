# tests/loop/check_runbook.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
f="$ROOT/pipelines/loop-pipeline/RUNBOOK.md"
test -f "$f" || { echo "FAIL: RUNBOOK.md missing"; exit 1; }
for k in 'Prerequisites' 'dry-run' '/schedule' 'loop-manager' 'loop-worker' \
         'gh pr merge' 'loop-settings.json'; do
  grep -qi "$k" "$f" || { echo "FAIL: runbook missing section/term: $k"; exit 1; }
done
# Pause/stop controls and the no-per-routine-scoping limitation note.
grep -Eqi 'pause|stop' "$f" || { echo "FAIL: no pause/stop controls"; exit 1; }
grep -Eqi 'per-routine|isolation|limitation' "$f" || { echo "FAIL: no limitations note"; exit 1; }
echo "PASS"
