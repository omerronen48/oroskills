#!/usr/bin/env bash
# UserPromptSubmit hook logs human prompts only while a loop run is active; never blocks.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO/skills/loop-kernel/intervention-log.sh"
fail() { echo "FAIL: $1"; exit 1; }
command -v jq >/dev/null || { echo "SKIP: jq missing"; exit 0; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
H="$D/.dev/memory/history.jsonl"
send() { jq -nc --arg p "$1" '{prompt:$p}' | CLAUDE_PROJECT_DIR="$D" bash "$HOOK"; }
# 1. no active run -> nothing logged, no output, exit 0
out="$(send "continue")" || fail "must exit 0"
[ -z "$out" ] || fail "must print nothing"
[ ! -f "$H" ] || fail "logged without .loop/active"
# 2. active run -> one intervention line per prompt, prompt kept
mkdir -p "$D/.loop"; touch "$D/.loop/active"
send "continue" >/dev/null; send "no, use pnpm instead" >/dev/null
[ "$(wc -l < "$H" | tr -d ' ')" = 2 ] || fail "expected 2 lines"
[ "$(jq -r 'select(.event=="intervention") | .prompt' "$H" | tail -1)" = "no, use pnpm instead" ] || fail "prompt text"
jq -e 'select(.date | test("^[0-9]{4}-"))' "$H" >/dev/null || fail "date missing"
# 3. long prompt truncated to 80 chars
send "$(printf 'x%.0s' $(seq 1 120))" >/dev/null
[ "$(tail -1 "$H" | jq -r '.prompt | length')" = 80 ] || fail "truncate to 80"
# 4. malformed stdin -> exit 0, no output
out="$(echo 'not json' | CLAUDE_PROJECT_DIR="$D" bash "$HOOK")" || fail "malformed must exit 0"
[ -z "$out" ] || fail "malformed must print nothing"
echo "PASS: intervention-log"
