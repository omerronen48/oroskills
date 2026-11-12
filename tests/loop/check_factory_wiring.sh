#!/usr/bin/env bash
# Every pipeline bootstraps .factory/ (kernel §0) and measures with factory-check.sh (§2).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
S="$REPO/pipelines/ship-pipeline/commands/ship.md"; F="$REPO/pipelines/fix-pipeline/commands/fix.md"
DV="$REPO/pipelines/dev-pipeline/commands/dev.md"; E="$REPO/skills/executing-plan-time/SKILL.md"
for f in "$S" "$F" "$DV"; do grep -q "§0" "$f" && grep -q ".factory/" "$f" || fail "$f: factory bootstrap missing"; done
for f in "$S" "$F" "$E"; do grep -q "factory-check.sh" "$f" || fail "$f: metric must use factory-check.sh"; done
grep -q 'test-guard.sh "$(cat .loop/lock-ref)"' "$S" && fail "ship still runs test-guard directly"
grep -q 'test-guard.sh "$(cat .loop/lock-ref)"' "$F" && fail "fix still runs test-guard directly"
# ship: bootstrap happens before the base SHA is recorded
awk '/^0\. Setup/{print; exit}' "$S" | grep -q "§0.*Record the base SHA" || fail "ship: bootstrap must precede base SHA"
grep -qF 'test-guard.sh <lock-ref-<task-id>> <manifest>' "$E" || fail "executing-plan-time per-task metric is test-guard + the task's own tests"
grep -qF 'factory-check.sh <run-base> .loop/goal.md' "$E" || fail "executing-plan-time final verification must run the goal"
grep -qF 'touch <main-checkout>/.loop/active' "$E" || fail "worktree runs must mirror .loop/active to the main checkout"
grep -qF 'factory-check.sh "$(cat .loop/lock-ref)" ""' "$F" || fail "fix per-fix metric must skip the goal"
grep -qF 'factory-check.sh <base> .loop/goal.md' "$F" || fail "fix must run the goal at the end"
grep -qF 'factory-check.sh "$(cat .loop/lock-ref)" .loop/goal.md' "$S" || fail "ship metric runs the goal every attempt"
echo "PASS: factory wiring"
