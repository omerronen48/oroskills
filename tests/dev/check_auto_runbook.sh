# tests/dev/check_auto_runbook.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
R="$ROOT/pipelines/dev-pipeline/RUNBOOK-autonomous-dev.md"
[ -f "$R" ] || { echo "FAIL: RUNBOOK-autonomous-dev.md missing"; exit 1; }
grep -qi "preflight" "$R" || { echo "FAIL: preflight section missing"; exit 1; }
grep -qi "dev --auto" "$R" || { echo "FAIL: /dev --auto usage missing"; exit 1; }
grep -qiE "cron|/loop|ScheduleWakeup" "$R" || { echo "FAIL: local scheduling not documented"; exit 1; }
grep -qi "escalations.md" "$R" || { echo "FAIL: escalation review not documented"; exit 1; }
grep -qi "resume" "$R" || { echo "FAIL: resume procedure missing"; exit 1; }
grep -qi "loop-settings.json" "$R" || { echo "FAIL: deny-merge reuse not documented"; exit 1; }
echo "PASS"
