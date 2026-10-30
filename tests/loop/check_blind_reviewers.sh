#!/usr/bin/env bash
# Reviewers must be blind: goal + diff, never the author's report.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines"
fail() { echo "FAIL: $1"; exit 1; }
TR="$R/dev-pipeline/agents/oro-task-reviewer.md"; SR="$R/ship-pipeline/agents/oro-reviewer.md"
grep -q "Implementer's Report" "$TR" && fail "task-reviewer still takes implementer report"
grep -q ".loop/goal.md" "$TR" || fail "task-reviewer must read goal.md"
grep -q "test-guard" "$TR" || fail "task-reviewer must get test-guard output"
grep -q "changes summary" "$SR" && fail "oro-reviewer still reads changes summary"
grep -q ".loop/goal.md" "$SR" || fail "oro-reviewer must read goal.md"
grep -q "Do not read .pipeline/changes.md" "$SR" || fail "oro-reviewer must be told to skip changes.md"
for f in "$TR" "$SR"; do grep -q "reward-hack" "$f" || fail "$f: reward-hack scan missing"; grep -q "exemplar" "$f" || fail "$f: exemplar check missing"; done
grep -q "plan's task" "$TR" || fail "task-reviewer must compare test to plan"
echo "PASS: blind reviewers"
