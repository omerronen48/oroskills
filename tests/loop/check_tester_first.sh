#!/usr/bin/env bash
# oro-tester writes tests before code, from goal + spec only, and never edits code.
set -euo pipefail
T="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines/ship-pipeline/agents/oro-tester.md"
fail() { echo "FAIL: $1"; exit 1; }
grep -q "## test-first" "$T" || fail "test-first mode missing"
grep -q "## strengthen" "$T" || fail "strengthen mode missing"
grep -q "## dispute-fix" "$T" || fail "dispute-fix mode missing"
grep -q "## plan-test" "$T" || fail "plan-test mode missing"
grep -q "exactly as the plan gives it" "$T" || fail "plan-test must copy the plan verbatim"
grep -q "Do NOT read \`.pipeline/changes.md\`" "$T" || fail "must not read the coder's summary"
grep -q "## Test files" "$T" || fail "test file list contract missing"
grep -q "never edit implementation code" "$T" || fail "must never edit code"
grep -q "Read .pipeline/changes.md to see what was built" "$T" && fail "old test-after step still present"
echo "PASS: tester first"
