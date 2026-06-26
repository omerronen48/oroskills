# tests/loop/check_loop_settings.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
f="$ROOT/pipelines/loop-pipeline/loop-settings.json"
test -f "$f" || { echo "FAIL: loop-settings.json missing"; exit 1; }
# Valid JSON AND denies gh pr merge.
python3 -c "
import json,sys
d=json.load(open('$f'))
deny=d.get('permissions',{}).get('deny',[])
assert 'Bash(gh pr merge)' in deny, 'deny must contain Bash(gh pr merge)'
" || { echo "FAIL: invalid JSON or missing deny rule"; exit 1; }
echo "PASS"
