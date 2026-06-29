#!/usr/bin/env bash
# tests/dev/check_usage_guard.sh — usage-window guard smoke tests
# Covers: doc/behavior greps, statusline bridge roundtrip, PushNotification assertions.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
_pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# ── 1. DOC / BEHAVIOR GREPS ────────────────────────────────────────────────

DEV_MD="$ROOT/pipelines/dev-pipeline/commands/dev.md"
RUNBOOK="$ROOT/pipelines/dev-pipeline/RUNBOOK-autonomous-dev.md"
MEM_PROTO="$ROOT/pipelines/dev-pipeline/memory-protocol.md"

[ -f "$DEV_MD" ] || { echo "FAIL: dev.md missing"; exit 1; }
[ -f "$RUNBOOK" ] || { echo "FAIL: RUNBOOK-autonomous-dev.md missing"; exit 1; }
[ -f "$MEM_PROTO" ] || { echo "FAIL: memory-protocol.md missing"; exit 1; }

# dev.md: "Usage-window guard" subsection
grep -q "Usage-window guard" "$DEV_MD" \
  && _pass "dev.md has Usage-window guard subsection" \
  || _fail "dev.md missing 'Usage-window guard' subsection"

# dev.md: mentions 95 (five_hour threshold)
grep -q "95" "$DEV_MD" \
  && _pass "dev.md mentions 95% threshold" \
  || _fail "dev.md missing 95% five_hour threshold"

# dev.md: mentions 90 (seven_day threshold)
grep -q "90" "$DEV_MD" \
  && _pass "dev.md mentions 90% threshold" \
  || _fail "dev.md missing 90% seven_day threshold"

# dev.md: mentions oro-usage.json
grep -q "oro-usage.json" "$DEV_MD" \
  && _pass "dev.md mentions oro-usage.json" \
  || _fail "dev.md missing oro-usage.json"

# dev.md: mentions resets_at
grep -q "resets_at" "$DEV_MD" \
  && _pass "dev.md mentions resets_at" \
  || _fail "dev.md missing resets_at"

# dev.md: between-phases / overrun note
grep -qiE "between.phase|between phase|overrun|cannot.*interrupt|no.*mid.phase" "$DEV_MD" \
  && _pass "dev.md documents between-phases overrun note" \
  || _fail "dev.md missing between-phases / overrun / cannot-interrupt note"

# dev.md: clean-session resume contract (resume rehydrates from .dev/memory, no --continue)
grep -qiE "clean session|fresh.*session|Resume contract" "$DEV_MD" \
  && grep -qiE "do.*not.*(--continue|--resume)|no .--continue" "$DEV_MD" \
  && _pass "dev.md documents clean-session resume contract" \
  || _fail "dev.md missing clean-session resume contract (fresh session, no --continue/--resume)"

# dev.md: one-shot resume / at command
grep -qiE "one.shot|\" at \"|echo.*at |at <" "$DEV_MD" \
  && _pass "dev.md mentions one-shot resume / at" \
  || _fail "dev.md missing one-shot resume / 'at' scheduling"

# dev.md: PushNotification used for BOTH the 95% and 90% paths
PUSH_COUNT=$(grep -ic "PushNotification" "$DEV_MD" 2>/dev/null || true)
if [ "${PUSH_COUNT:-0}" -ge 2 ]; then
  _pass "dev.md instructs PushNotification for both 95% and 90% paths"
else
  _fail "dev.md must mention PushNotification at least twice (once per guard path); found $PUSH_COUNT"
fi

# memory-protocol.md: documents usage.md
grep -q "usage.md" "$MEM_PROTO" \
  && _pass "memory-protocol.md documents usage.md" \
  || _fail "memory-protocol.md missing usage.md entry"

# memory-protocol.md: NOT in read-order chain
grep -qiE "not in.*read.order|NOT in.*chain|read.order.*chain" "$MEM_PROTO" \
  && _pass "memory-protocol.md states usage.md is NOT in read-order chain" \
  || _fail "memory-protocol.md missing NOT-in-read-order statement for usage.md"

# RUNBOOK: bridge dependency (statusline must be installed / active)
grep -qi "statusline" "$RUNBOOK" \
  && _pass "RUNBOOK documents bridge/statusline dependency" \
  || _fail "RUNBOOK missing bridge/statusline dependency note"

# RUNBOOK: PushNotification
grep -qi "PushNotification" "$RUNBOOK" \
  && _pass "RUNBOOK documents PushNotification" \
  || _fail "RUNBOOK missing PushNotification note"

# RUNBOOK: interactive-only limitation
grep -qiE "interactive|headless" "$RUNBOOK" \
  && _pass "RUNBOOK documents interactive-only limitation" \
  || _fail "RUNBOOK missing interactive-only limitation"

# ── 2. FUNCTIONAL: statusline bridge roundtrip ─────────────────────────────

STATUSLINE="$ROOT/statusline-command.sh"
[ -f "$STATUSLINE" ] || { echo "FAIL: statusline-command.sh missing"; exit 1; }

if ! command -v jq >/dev/null 2>&1; then
  echo "NOTE: jq not available — skipping statusline bridge functional tests"
else
  # Test 2a: payload WITH rate_limits writes oro-usage.json correctly
  TMP_HOME=$(mktemp -d)
  trap 'rm -rf "$TMP_HOME"' EXIT
  mkdir -p "$TMP_HOME/.claude"

  SAMPLE_JSON='{"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":"2026-06-29T18:00:00Z"},"seven_day":{"used_percentage":77,"resets_at":"2026-07-03T00:00:00Z"}},"workspace":{"current_dir":"/tmp"},"model":"claude-opus-4-5","context_window":{"used_percent":10},"session_cost":{"total_usd":0.01}}'

  SL_OUTPUT=$(printf '%s' "$SAMPLE_JSON" | env HOME="$TMP_HOME" bash "$STATUSLINE" 2>/dev/null)

  # Assert status line non-empty
  if [ -n "$SL_OUTPUT" ]; then
    _pass "statusline emits non-empty output with rate_limits payload"
  else
    _fail "statusline emitted empty output with rate_limits payload"
  fi

  # Assert oro-usage.json created
  USAGE_JSON="$TMP_HOME/.claude/oro-usage.json"
  if [ -f "$USAGE_JSON" ]; then
    _pass "oro-usage.json created by statusline bridge"
  else
    _fail "oro-usage.json NOT created by statusline bridge"
  fi

  if [ -f "$USAGE_JSON" ]; then
    # Assert five_hour_pct = 42
    GOT_5H_PCT=$(jq -r '.five_hour_pct' "$USAGE_JSON" 2>/dev/null)
    if [ "$GOT_5H_PCT" = "42" ]; then
      _pass "oro-usage.json five_hour_pct = 42"
    else
      _fail "oro-usage.json five_hour_pct expected 42, got '$GOT_5H_PCT'"
    fi

    # Assert five_hour_resets_at
    GOT_5H_AT=$(jq -r '.five_hour_resets_at' "$USAGE_JSON" 2>/dev/null)
    if [ "$GOT_5H_AT" = "2026-06-29T18:00:00Z" ]; then
      _pass "oro-usage.json five_hour_resets_at correct"
    else
      _fail "oro-usage.json five_hour_resets_at expected '2026-06-29T18:00:00Z', got '$GOT_5H_AT'"
    fi

    # Assert seven_day_pct = 77
    GOT_7D_PCT=$(jq -r '.seven_day_pct' "$USAGE_JSON" 2>/dev/null)
    if [ "$GOT_7D_PCT" = "77" ]; then
      _pass "oro-usage.json seven_day_pct = 77"
    else
      _fail "oro-usage.json seven_day_pct expected 77, got '$GOT_7D_PCT'"
    fi

    # Assert seven_day_resets_at
    GOT_7D_AT=$(jq -r '.seven_day_resets_at' "$USAGE_JSON" 2>/dev/null)
    if [ "$GOT_7D_AT" = "2026-07-03T00:00:00Z" ]; then
      _pass "oro-usage.json seven_day_resets_at correct"
    else
      _fail "oro-usage.json seven_day_resets_at expected '2026-07-03T00:00:00Z', got '$GOT_7D_AT'"
    fi

    # Assert captured_at key exists (spec says 'captured_at', not 'snapshot_at')
    GOT_CAPTURED=$(jq -r '.captured_at // empty' "$USAGE_JSON" 2>/dev/null)
    if [ -n "$GOT_CAPTURED" ]; then
      _pass "oro-usage.json has captured_at key"
    else
      _fail "oro-usage.json missing 'captured_at' key (spec requires captured_at; implementation may use snapshot_at instead)"
    fi
  fi

  # Test 2b: payload WITHOUT rate_limits — no crash, status line still prints
  NO_RATE_JSON='{"workspace":{"current_dir":"/tmp"},"model":"claude-opus-4-5","context_window":{"used_percent":5},"session_cost":{"total_usd":0.00}}'

  TMP_HOME2=$(mktemp -d)
  trap 'rm -rf "$TMP_HOME" "$TMP_HOME2"' EXIT
  mkdir -p "$TMP_HOME2/.claude"

  SL_OUT2=$(printf '%s' "$NO_RATE_JSON" | env HOME="$TMP_HOME2" bash "$STATUSLINE" 2>/dev/null)
  SL_EXIT=$?

  if [ $SL_EXIT -eq 0 ]; then
    _pass "statusline exits 0 with no rate_limits in payload"
  else
    _fail "statusline exited non-zero ($SL_EXIT) with no rate_limits in payload"
  fi

  if [ -n "$SL_OUT2" ]; then
    _pass "statusline still prints status line with no rate_limits payload"
  else
    _fail "statusline emitted empty output with no rate_limits payload"
  fi

  # oro-usage.json should NOT be created (or may already be absent) when no rate_limits
  if [ ! -f "$TMP_HOME2/.claude/oro-usage.json" ]; then
    _pass "oro-usage.json not written when no rate_limits in payload"
  else
    _fail "oro-usage.json unexpectedly written when no rate_limits in payload"
  fi
fi

# ── SUMMARY ───────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ $FAIL_COUNT -gt 0 ]; then
  exit 1
fi
echo "PASS"
