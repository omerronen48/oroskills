# tests/loop/check_loop_worker.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
f="$ROOT/pipelines/loop-pipeline/commands/loop-worker.md"
test -f "$f" || { echo "FAIL: loop-worker.md missing"; exit 1; }
# Orchestrator + flags. (`--` so dash-patterns are not parsed as grep options.)
for k in '\$ARGUMENTS' '--dry-run'; do
  grep -Eq -- "$k" "$f" || { echo "FAIL: loop-worker missing: $k"; exit 1; }
done
# Selection filter, claim, isolation, ship drive, routing, boundary.
for k in 'agent:ready' 'risk:low' 'agent:in-progress' 'needs:human' \
         'gh label create' 'git worktree' 'agent/issue-' \
         'oro-planner' 'oro-coder' 'oro-tester' 'oro-reviewer' 'VERDICT' \
         'gh pr create' 'gh issue comment' 'gh pr list'; do
  grep -q "$k" "$f" || { echo "FAIL: loop-worker missing contract: $k"; exit 1; }
done
# Design card fields.
for k in 'JOB' 'ALLOWED' 'FORBIDDEN' 'EVALUATION'; do
  grep -q "$k" "$f" || { echo "FAIL: design card missing field: $k"; exit 1; }
done
# Never-merge boundary, stated AND no merge call present.
grep -Eqi 'never.*merge|FORBIDDEN' "$f" || { echo "FAIL: no never-merge boundary"; exit 1; }
grep -q 'gh pr merge' "$f" && { echo "FAIL: must not call gh pr merge"; exit 1; }
echo "PASS"
