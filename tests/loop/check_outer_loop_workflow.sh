#!/usr/bin/env bash
# CI for oroskills + the reusable outer loop target projects call.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
T="$REPO/.github/workflows/test.yml"; O="$REPO/.github/workflows/outer-loop.yml"; C="$REPO/skills/loop-kernel/factory-workflow.yml"
for f in "$T" "$O" "$C"; do [ -f "$f" ] || fail "$f missing"; done
grep -q "pull_request" "$T" || fail "test.yml must run on PRs"
grep -q "ubuntu-latest" "$T" && grep -q "macos-latest" "$T" || fail "test.yml needs ubuntu + macos matrix"
grep -qF 'tests/*/check_*.sh' "$T" || fail "test.yml must run the suite"
grep -q "workflow_call" "$O" || fail "outer-loop must be reusable"
grep -q "fetch-depth: 0" "$O" || fail "outer-loop needs full history for base diffs"
grep -q "factory-check.sh" "$O" || fail "outer-loop must run factory-check"
grep -q "mutate-check.sh" "$O" || fail "outer-loop must run mutate-check"
grep -q "test-command" "$O" && grep -q "setup" "$O" || fail "outer-loop inputs"
grep -q 'inputs\.\(setup\|test-command\) }}' <(grep -v 'env:' "$O" | grep 'run:') && fail "inputs must go through env, not inline in run:"
grep -q "omerronen48/oroskills/.github/workflows/outer-loop.yml@" "$C" || fail "caller must use the reusable workflow"
grep -q "pull_request" "$C" || fail "caller must run on PRs"
if python3 -c 'import yaml' 2>/dev/null; then
  for f in "$T" "$O" "$C"; do python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$f" || fail "$f is not valid YAML"; done
fi
echo "PASS: outer-loop workflows"
