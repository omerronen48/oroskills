#!/usr/bin/env bash
# tests/dev/check_usage_guard_fixes.sh — regression tests for the review findings
# on PR #6 (usage-window guard). Each test first PROVES the issue is real, then
# asserts the fix is in place.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
_pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

DEV_MD="$ROOT/pipelines/dev-pipeline/commands/dev.md"
RUNBOOK="$ROOT/pipelines/dev-pipeline/RUNBOOK-autonomous-dev.md"
STATUSLINE="$ROOT/statusline-command.sh"
SNIPPET="$ROOT/skills/caveman/statusline-snippet.sh"
INSTALL="$ROOT/install.sh"
GUARD_TEST="$ROOT/tests/dev/check_usage_guard.sh"

# ── FINDING 1 (HIGH): `at <ISO8601>` is unparseable → resume never schedules ──
# Proof the issue is real: BSD/macOS `at` rejects an ISO8601 timestamp, AND the
# UTC->local offset means a naive digit-strip schedules the resume at the wrong
# wall-clock time. The fix routes through epoch and uses `at -t`.

if command -v at >/dev/null 2>&1; then
  # 1a. Proof: feeding raw ISO8601 to `at` garbles.
  ISO="2026-06-29T18:00:00Z"
  GARBLE=$(echo true | at "$ISO" 2>&1 | head -1 || true)
  case "$GARBLE" in
    *garbled*|*Garbled*|*"can't"*|*invalid*|*"bad time"*)
      _pass "proof: raw ISO8601 piped to bare 'at' is rejected ($GARBLE)" ;;
    *)
      # On GNU at this may actually parse; then the bug is TZ-only, still note it.
      echo "NOTE: bare 'at' accepted ISO on this platform ($GARBLE) — TZ bug still applies" ;;
  esac

  # 1b. Proof the fix works: epoch conversion + `at -t` queues successfully and
  # at the correct LOCAL time (UTC 18:00Z must NOT land on local 18:00 unless UTC).
  TS=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ISO" "+%s" 2>/dev/null \
       || date -u -d "$ISO" "+%s" 2>/dev/null || true)
  if [ -n "$TS" ]; then
    STAMP=$(date -r "$TS" +%Y%m%d%H%M 2>/dev/null || date -d "@$TS" +%Y%m%d%H%M 2>/dev/null || true)
    NAIVE=$(echo "$ISO" | tr -d 'TZ:-' | cut -c1-12)
    OFFSET=$(date +%z)
    if [ -n "$STAMP" ]; then
      if [ "$OFFSET" = "+0000" ] || [ "$STAMP" != "$NAIVE" ]; then
        _pass "proof: epoch conversion corrects UTC->local (stamp=$STAMP naive=$NAIVE offset=$OFFSET)"
      else
        _fail "epoch conversion produced same stamp as naive strip at non-UTC offset $OFFSET"
      fi
      if echo true | at -t "$STAMP" >/dev/null 2>&1; then
        _pass "fix: 'at -t $STAMP' queues successfully"
        # cleanup any jobs we just queued
        atq 2>/dev/null | awk '{print $1}' | xargs -I{} atrm {} 2>/dev/null || true
      else
        echo "NOTE: 'at -t' rejected (atrun likely not loaded) — skipping queue assertion"
      fi
    fi
  fi
else
  echo "NOTE: 'at' not installed — skipping functional at(1) tests"
fi

# 1c. Docs must NOT instruct the broken bare `at <...resets_at>` form, and MUST
#     use `at -t`. (greps so the test is meaningful even without at(1) installed.)
for f in "$DEV_MD" "$RUNBOOK"; do
  name=$(basename "$f")
  if grep -qE '\| *at +<' "$f"; then
    _fail "$name still pipes into bare 'at <...>' (unparseable ISO8601)"
  else
    _pass "$name no longer uses bare 'at <ISO>'"
  fi
  if grep -q 'at -t' "$f"; then
    _pass "$name uses 'at -t' form"
  else
    _fail "$name missing 'at -t' (BSD/macOS at needs -t [[CC]YY]MMDDhhmm)"
  fi
  # Must convert UTC->local (epoch / date) not just strip punctuation.
  if grep -qiE 'date .*(\+%s|-f |%Y%m%d%H%M)|epoch|UTC' "$f"; then
    _pass "$name documents UTC->local conversion for the resume timestamp"
  else
    _fail "$name does not convert resets_at (UTC) to local time for 'at -t'"
  fi
done

# ── FINDING 2 (MED): captured_at written but never validated for staleness ────
# In a headless resume run the statusline never renders, so oro-usage.json is
# present-but-stale. The guard must check captured_at freshness, not just presence.
if grep -q 'captured_at' "$STATUSLINE"; then
  _pass "proof: statusline bridge writes captured_at"
else
  _fail "statusline bridge no longer writes captured_at (test stale?)"
fi
if grep -qiE 'captured_at' "$DEV_MD" && grep -qiE 'stale|fresh|too old|age of' "$DEV_MD"; then
  _pass "dev.md documents captured_at staleness handling"
else
  _fail "dev.md never checks captured_at freshness — stale snapshot trusted as live"
fi

# ── FINDING 3 (LOW): install.sh prints false success when jq fails ────────────
# register_hook does `jq ... > tmp && mv ...` then an UNCONDITIONAL success echo.
# Feed it invalid JSON: it must NOT report the hook as registered.
extract_fn() { awk "/^$1\\(\\) \\{|^$1\\(\\)\\{/{f=1} f{print} f&&/^}/{exit}" "$INSTALL"; }
BAD=$(mktemp)
printf '{this is not json' > "$BAD"
HARNESS=$(mktemp)
{
  echo 'set -uo pipefail'
  echo "SETTINGS_FILE='$BAD'"
  extract_fn register_hook
  echo 'register_hook SessionStart "/tmp/x.sh"'
} > "$HARNESS"
OUT=$(bash "$HARNESS" 2>/dev/null || true)
if echo "$OUT" | grep -q -- '-> registered'; then
  _fail "install.sh register_hook prints '-> registered' even when jq fails on bad settings JSON"
else
  _pass "install.sh register_hook does not falsely report success on jq failure"
fi
rm -f "$BAD" "$HARNESS"

# ── FINDING 4 (LOW): statusline-snippet.sh comment misstates the off chip ─────
if grep -q '"caveman off"' "$SNIPPET"; then
  _fail "statusline-snippet.sh comment says \"caveman off\" but emits 💤 caveman"
else
  _pass "statusline-snippet.sh comment matches actual 💤 output"
fi

# ── FINDING 5 (LOW): usage-guard test fixture uses wrong context field ────────
# Real statusline/docs field is context_window.used_percentage, not used_percent.
if grep -q 'used_percent"' "$GUARD_TEST"; then
  _fail "check_usage_guard.sh fixture uses 'used_percent' (real field is used_percentage)"
else
  _pass "check_usage_guard.sh fixture uses correct context_window.used_percentage"
fi

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -gt 0 ] && exit 1
echo "PASS"
