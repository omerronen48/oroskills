#!/usr/bin/env bash
# tests/dev/check_auto_dev.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$ROOT/pipelines/dev-pipeline/commands/dev.md"
grep -q -- "--auto" "$D" || { echo "FAIL: --auto flag not documented"; exit 1; }
grep -qi "autonomous" "$D" || { echo "FAIL: autonomous mode not described"; exit 1; }
grep -qi "escalations.md" "$D" || { echo "FAIL: escalation parking file not named"; exit 1; }
grep -qi "blocked" "$D" || { echo "FAIL: blocked phase status not documented"; exit 1; }
grep -qi "halt" "$D" || { echo "FAIL: park+halt behavior not documented"; exit 1; }
grep -qi "never\b.*merge\|do NOT merge\|not.*merge" "$D" || { echo "FAIL: no-merge guarantee missing"; exit 1; }
echo "PASS"
