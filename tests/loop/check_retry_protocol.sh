#!/usr/bin/env bash
# Coder and implementer must diagnose before a retry (loop-kernel §4).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines"
fail() { echo "FAIL: $1"; exit 1; }
for f in "$R/ship-pipeline/agents/oro-coder.md" "$R/dev-pipeline/agents/oro-implementer.md"; do
  grep -q "## Retry protocol" "$f" || fail "$f: retry protocol missing"
  grep -q "## Diagnosis" "$f" || fail "$f: diagnosis section missing"
  grep -q "structurally different" "$f" || fail "$f: attempt-3 rule missing"
  grep -q "TEST-DISPUTE" "$f" || fail "$f: dispute path missing"
  grep -q "do not write or edit tests" "$f" || fail "$f: locked-tests rule missing"
  grep -q "exemplar" "$f" || fail "$f: exemplar rule missing"
done
grep -q "already committed and locked by" "$R/dev-pipeline/agents/oro-implementer.md" || fail "implementer: locked-tests contract missing"
grep -q "Single commit" "$R/dev-pipeline/agents/oro-implementer.md" && fail "implementer: stale single-commit mandate is back"
grep -q "(oro-coder:" "$R/dev-pipeline/agents/oro-implementer.md" && fail "implementer names oro-coder"
echo "PASS: retry protocol"
