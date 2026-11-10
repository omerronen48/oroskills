#!/usr/bin/env bash
# Kernel additions: §0 factory files, factory-check metric, severity gate, REJECT, meta-loop history.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
K="$REPO/skills/loop-kernel/SKILL.md"; L="$REPO/skills/loop-kernel"
fail() { echo "FAIL: $1"; exit 1; }
for s in "## 0. Factory files" ".factory/checks" ".factory/run.md" ".github/workflows/factory.yml" \
         "factory-workflow.yml" "chore(factory): bootstrap .factory" "before the run base is recorded" \
         "factory-check.sh" "→ fix:" "[P0]" "[P3]" "[deferred]" "REJECT:" "re-raised" \
         "intervention-log.sh" "pr_review" "pr_opened" "human-feedback.md" "scorecard.sh" "/gc" \
         "git worktree list --porcelain" 'touch "$MAIN/.loop/active"' '<goal-or-"">' "any [P0]–[P2] item (blocking)"; do
  grep -qF -- "$s" "$K" || fail "kernel missing '$s'"
done
# the old two-step metric (separate test-guard step) is gone from §2
awk '/^## 2\. Metric/{s=1;next} /^## 3\./{s=0} s' "$K" | grep -q '^2\. `bash "\$KERNEL/test-guard.sh"' && fail "§2 still runs test-guard separately"
# retry triggers on P0-P2, never on P3
awk '/^## 4\. Retry/{s=1;next} /^## 5\./{s=0} s' "$K" | grep -q "P0\]–\[P2\]" || fail "§4 severity trigger missing"
[ -f "$L/factory-checks-template" ] || fail "checks template missing"
grep -q "^#" "$L/factory-checks-template" || fail "checks template needs comment header"
for s in "## Launch" "## Logs" "## Smoke" "## Browser"; do grep -qF "$s" "$L/factory-run-template.md" || fail "run template missing $s"; done
KERNEL_ONLY=1 bash "$REPO/tests/loop/check_loop_kernel.sh" >/dev/null || fail "existing kernel checks broken"
echo "PASS: kernel factory"
