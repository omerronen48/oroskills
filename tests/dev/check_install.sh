# tests/dev/check_install.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
I="$ROOT/install.sh"
grep -q "pipelines/dev-pipeline/commands" "$I" || { echo "FAIL: dev command not installed"; exit 1; }
grep -q "pipelines/dev-pipeline/agents" "$I" || { echo "FAIL: dev agents not installed"; exit 1; }
for a in oro-implementer oro-task-reviewer oro-phase-executor; do
  grep -q "$a" "$I" || { echo "FAIL: dev agent $a not listed"; exit 1; }
done
grep -q "\bdev\b" "$I" || { echo "FAIL: /dev command not listed"; exit 1; }
bash -n "$I" || { echo "FAIL: install.sh syntax"; exit 1; }
echo "PASS"
