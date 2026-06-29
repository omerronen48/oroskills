# tests/dev/check_auto_brainstorm.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/skills/brainstorming-time/SKILL.md"
grep -qi "## Autonomous mode" "$S" || { echo "FAIL: Autonomous mode section missing"; exit 1; }
grep -qi "clarifying questions" "$S" || { echo "FAIL: clarifying-questions gate not addressed"; exit 1; }
grep -qi "mind map" "$S" || { echo "FAIL: mind-map gate not addressed"; exit 1; }
grep -qi "self-review" "$S" || { echo "FAIL: spec-approval -> self-review not addressed"; exit 1; }
grep -qi "graphify" "$S" || { echo "FAIL: graphify-missing gate not addressed"; exit 1; }
grep -qi "irreversible" "$S" || { echo "FAIL: irreversible-escalation path not addressed"; exit 1; }
echo "PASS"
