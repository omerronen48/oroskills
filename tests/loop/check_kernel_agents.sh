#!/usr/bin/env bash
# Contract check for the two kernel agents.
set -euo pipefail
A="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/pipelines/dev-pipeline/agents"
fail() { echo "FAIL: $1"; exit 1; }
J="$A/oro-judge.md"; D="$A/oro-distiller.md"
[ -f "$J" ] && [ -f "$D" ] || fail "agent file missing"
grep -q '^name: oro-judge$' "$J" || fail "judge name"
grep -q '^tools: Read, Grep, Glob, Bash$' "$J" || fail "judge must be read-only"
grep -q 'SCORES' "$J" && grep -q 'IMPROVEMENTS' "$J" || fail "judge output format"
grep -q '^name: oro-distiller$' "$D" || fail "distiller name"
grep -q 'seen:' "$D" || fail "distiller seen counter"
grep -qi 'never apply' "$D" || fail "distiller must never apply diffs"
grep -q 'files:' "$D" || fail "distiller must scope lessons with files:"
grep -q 'screenshot' "$J" || fail "judge must read screenshots"
C="$A/oro-critic.md"
[ -f "$C" ] || fail "critic missing"
grep -q '^name: oro-critic$' "$C" || fail "critic name"
grep -q '^tools: Read, Grep, Glob, Bash$' "$C" || fail "critic must be read-only"
grep -q 'VERDICT: CLEAR | GAPS' "$C" || fail "critic output format"
grep -q 'history' "$D" || fail "distiller must read history"
grep -q 'reward-hack' "$D" || fail "distiller must fast-track reward-hack lessons"
grep -q '.loop/proposals/' "$D" || fail "distiller proposal path"
echo "PASS: kernel agents"
