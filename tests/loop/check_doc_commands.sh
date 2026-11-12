#!/usr/bin/env bash
# Shell snippets agents copy from docs must keep `&&` (not `||`).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
chk() { # file snippet flipped
  grep -qF -- "$2" "$R/$1" || fail "$1: missing: $2"
  grep -qF -- "$3" "$R/$1" && fail "$1: has flipped: $3"
  return 0
}
chk pipelines/fix-pipeline/commands/fix.md 'rm -rf .pipeline .loop && mkdir .pipeline .loop' 'rm -rf .pipeline .loop || mkdir .pipeline .loop'
M='mkdir -p "$MAIN/.loop" && touch "$MAIN/.loop/active"'
F='mkdir -p "$MAIN/.loop" || touch "$MAIN/.loop/active"'
chk pipelines/loop-pipeline/commands/loop-worker.md "$M" "$F"
chk skills/loop-kernel/SKILL.md "$M" "$F"
chk skills/executing-plan-time/SKILL.md 'mkdir -p <main-checkout>/.loop && touch <main-checkout>/.loop/active' 'mkdir -p <main-checkout>/.loop || touch <main-checkout>/.loop/active'
echo "PASS: doc commands"
