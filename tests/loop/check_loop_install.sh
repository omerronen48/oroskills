# tests/loop/check_loop_install.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
f="$ROOT/install.sh"
test -f "$f" || { echo "FAIL: install.sh missing"; exit 1; }
# Loop agent + commands declared and installed from the loop pipeline.
grep -Eq 'LOOP_AGENTS=\(.*oro-triager' "$f" || { echo "FAIL: oro-triager not in LOOP_AGENTS"; exit 1; }
grep -Eq 'LOOP_COMMANDS=\(.*loop-manager.*loop-worker' "$f" || { echo "FAIL: loop commands not in LOOP_COMMANDS"; exit 1; }
grep -q 'pipelines/loop-pipeline/agents' "$f" || { echo "FAIL: no install loop for loop agents"; exit 1; }
grep -q 'pipelines/loop-pipeline/commands' "$f" || { echo "FAIL: no install loop for loop commands"; exit 1; }
echo "PASS"
