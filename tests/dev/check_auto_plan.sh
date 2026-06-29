# tests/dev/check_auto_plan.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/skills/writing-plans-time/SKILL.md"
grep -qi "## Autonomous mode" "$S" || { echo "FAIL: Autonomous mode section missing"; exit 1; }
grep -qi "graphify" "$S" || { echo "FAIL: graphify-missing gate not addressed"; exit 1; }
grep -qi "self-review" "$S" || { echo "FAIL: approval -> self-review not addressed"; exit 1; }
grep -qi "executing-plan-time" "$S" || { echo "FAIL: autonomous handoff not addressed"; exit 1; }
echo "PASS"
