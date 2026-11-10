#!/usr/bin/env bash
# guard-edits.sh denies Edit/Write on locked tests and on a frozen goal.md.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="$REPO/skills/loop-kernel/guard-edits.sh"
fail() { echo "FAIL: $1"; exit 1; }
command -v jq >/dev/null || { echo "SKIP: jq missing"; exit 0; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cd "$D"; git init -q; mkdir -p tests src .loop
echo x > tests/test_a.py; echo y > src/a.py
call() { jq -nc --arg f "$1" '{tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$G"; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$1"; }

[ -z "$(call "$D/tests/test_a.py")" ] || fail "no lock → allow"
shasum -a 256 tests/test_a.py > .loop/test-lock
[ "$(decision "$(call "$D/tests/test_a.py")")" = deny ] || fail "locked test should be denied"
[ -z "$(call "$D/src/a.py")" ] || fail "implementation should be allowed"
out="$(jq -nc '{tool_input:{file_path:"tests/test_a.py"}}' | CLAUDE_PROJECT_DIR="$D" bash "$G")"
[ "$(decision "$out")" = deny ] || fail "relative path should resolve and be denied"
echo g > .loop/goal.md
[ -z "$(call "$D/.loop/goal.md")" ] || fail "goal editable before freeze"
touch .loop/active
[ "$(decision "$(call "$D/.loop/goal.md")")" = deny ] || fail "frozen goal should be denied"
[ -z "$(call "$D/newdir/x.py")" ] || fail "file in new dir should be allowed"
[ -z "$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$G")" ] || fail "non-file tool passes through"
mkdir -p .factory; echo pytest > .factory/checks
rm -f .loop/active
[ -z "$(call "$D/.factory/checks")" ] || fail "factory checks editable outside a run"
touch .loop/active
[ "$(decision "$(call "$D/.factory/checks")")" = deny ] || fail "factory checks should be frozen during a run"
[ -z "$(call "$D/.factory/run.md")" ] || fail "run.md stays editable"
echo "PASS: guard-edits"
