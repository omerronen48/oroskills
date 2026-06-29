#!/usr/bin/env bash
# tests/dev/check_auto_readme.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
R="$ROOT/README.md"
grep -q -- "--auto" "$R" || { echo "FAIL: --auto not documented in README"; exit 1; }
grep -qi "unattended\|autonomous" "$R" || { echo "FAIL: unattended/autonomous not described"; exit 1; }
grep -qiE "cron|schedule|/loop" "$R" || { echo "FAIL: scheduling not mentioned"; exit 1; }
grep -q "RUNBOOK-autonomous-dev" "$R" || { echo "FAIL: runbook pointer missing"; exit 1; }
echo "PASS"
