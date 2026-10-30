#!/usr/bin/env bash
# Structural check: kernel contract exists with every section, and each
# pipeline references it (wiring half skipped with KERNEL_ONLY=1).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
K="$REPO/skills/loop-kernel/SKILL.md"; T="$REPO/skills/loop-kernel/goal-template.md"
[ -f "$K" ] || fail "SKILL.md missing"
head -5 "$K" | grep -q '^name: loop-kernel' || fail "frontmatter name"
for s in "## 1. Objective" "## 2. Metric" "## 3. Verifier" "## 4. Retry" "## 5. Climb" "## 6. Distill" "## 7. Auto marker" "Behavior check" "lessons-for.sh" "## Diagnosis" "model: opus" "Variant A" "Variant B" ".loop/shots/" "## 8. Integrity" "oro-critic" ".loop/active" ".loop/test-lock" ".loop/lock-ref" "TEST-DISPUTE" "mutate-check.sh" "history.jsonl" "exemplar"; do
  grep -qF "$s" "$K" || fail "kernel section '$s' missing"
done
for s in "# Goal" "## Done-criteria" "Behavior check" "## Screens" "## Rubric" "## Non-goals"; do
  grep -qF "$s" "$T" || fail "template section '$s' missing"
done
[ "${KERNEL_ONLY:-0}" = 1 ] && { echo "PASS: loop-kernel (kernel only)"; exit 0; }
for f in skills/executing-plan-time/SKILL.md pipelines/ship-pipeline/commands/ship.md \
         pipelines/fix-pipeline/commands/fix.md pipelines/dev-pipeline/commands/dev.md; do
  grep -q "loop-kernel" "$REPO/$f" || fail "$f does not reference loop-kernel"
done
grep -q "/ship" "$REPO/pipelines/loop-pipeline/commands/loop-worker.md" || fail "loop-worker must call /ship"
grep -q "oro-coder\` → produces" "$REPO/pipelines/loop-pipeline/commands/loop-worker.md" && fail "loop-worker still inlines ship stages"
grep -q "Re-run the review until \`PASS\`" "$REPO/skills/executing-plan-time/SKILL.md" && fail "uncapped review loop still present"
grep -q "## Autonomous mode" "$REPO/skills/executing-plan-time/SKILL.md" || fail "executing-plan-time autonomous mode missing"
grep -q "goal.md" "$REPO/pipelines/ship-pipeline/agents/oro-planner.md" || fail "planner must emit goal.md"
echo "PASS: loop-kernel"
