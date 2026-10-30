#!/usr/bin/env bash
# /dev --auto <idea> with an empty roadmap must run project-time once
# interactively, then continue unattended; bare --auto still halts.
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines/dev-pipeline/commands/dev.md"
fail() { echo "FAIL: $1"; exit 1; }
grep -q "Interactive bootstrap" "$D" || fail "bootstrap rule missing"
grep -qi "then switch to autonomous mode" "$D" || fail "must switch to auto after roadmap"
grep -q "no phases to run; import a roadmap or pass an idea" "$D" || fail "bare --auto halt wording"
echo "PASS: auto bootstrap"
