# tests/dev/check_dev_command.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$ROOT/dev-pipeline/commands/dev.md"
test -f "$D" || { echo "FAIL: dev.md missing"; exit 1; }
for k in '\$ARGUMENTS' 'progress.md' '\.dev/memory' 'phase-executor' \
         'project-time' 'brainstorming-time' 'writing-plans-time' \
         'resume' 'escalat' 'irreversible' 'reversible'; do
  grep -Eqi "$k" "$D" || { echo "FAIL: dev.md missing contract: $k"; exit 1; }
done
echo "PASS"
