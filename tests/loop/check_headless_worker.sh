#!/usr/bin/env bash
# /loop-worker --headless never asks and ends with a machine-readable summary; README documents the factory.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
W="$REPO/pipelines/loop-pipeline/commands/loop-worker.md"; RD="$REPO/README.md"
grep -q -- "--headless" "$W" || fail "worker: --headless flag missing"
grep -q "argument-hint: .*--headless" "$W" || fail "worker: argument-hint must list --headless"
grep -q "LOOP-WORKER: <issue|none> <SHIP|needs:human|no-eligible>" "$W" || fail "worker: summary line format"
grep -q '"event":"pr_opened"' "$W" || fail "worker: must log pr_opened"
grep -qF 'touch "$MAIN/.loop/active"' "$W" || fail "worker: must mirror .loop/active to the main checkout"
grep -q "never asks" "$W" || fail "worker: headless must never ask"
for s in ".factory/checks" "pre-push" "factory-check.sh" "scorecard.sh" "/gc" "intervention" "--headless" "[P0]"; do
  grep -qF -- "$s" "$RD" || fail "README missing '$s'"
done
grep -qF "outer-loop.yml" "$RD" && fail "README still mentions outer-loop.yml"
echo "PASS: headless worker"
