#!/usr/bin/env bash
# Behavior test for dev-resume-guard.sh: usage gating (weekly beats 5-hour),
# liveness skip, relaunch, and registry pruning — all against a sandbox.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/pipelines/dev-pipeline/dev-resume-guard.sh"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# Stub claude that records each launch.
mkdir -p "$SB/bin"
cat > "$SB/bin/claude" <<EOF
#!/bin/sh
echo "launched \$*" >> "$SB/launches"
EOF
chmod +x "$SB/bin/claude"

REPO="$SB/repo"; mkdir -p "$REPO/.dev"
REG="$SB/dev-auto-repos"; USAGE="$SB/oro-usage.json"
echo "$REPO" > "$REG"
touch "$REPO/.dev/auto-resume"

run_guard() { OROSKILLS_REGISTRY="$REG" OROSKILLS_USAGE="$USAGE" PATH="$SB/bin:$PATH" sh "$GUARD"; sleep 1; }

now=$(date +%s)

# 1. Weekly window exhausted, resets in the future -> no launch.
printf '{"five_hour_pct":10,"five_hour_resets_at":"%s","seven_day_pct":95,"seven_day_resets_at":"%s"}\n' \
  "$((now+60))" "$((now+3600))" > "$USAGE"
run_guard
[ ! -f "$SB/launches" ] || fail "launched despite exhausted weekly window"

# 2. Five-hour exhausted, already reset (resets_at in the past) -> launch.
printf '{"five_hour_pct":97,"five_hour_resets_at":"%s","seven_day_pct":10,"seven_day_resets_at":"%s"}\n' \
  "$((now-60))" "$((now+3600))" > "$USAGE"
run_guard
[ -f "$SB/launches" ] && grep -q "launched -p /dev --auto" "$SB/launches" || fail "no relaunch after window reset"
rm -f "$SB/launches"

# 3. Live lock (this test's own pid) -> no launch.
echo $$ > "$REPO/.dev/auto.lock"
run_guard
[ ! -f "$SB/launches" ] || fail "launched despite a live run holding the lock"

# 4. Dead lock pid -> launch resumes.
echo 99999999 > "$REPO/.dev/auto.lock"
run_guard
[ -f "$SB/launches" ] || fail "no relaunch with a stale lock"

# 5. Marker removed (disarmed) -> registry line pruned, no launch.
rm -f "$SB/launches" "$REPO/.dev/auto-resume"
run_guard
[ ! -f "$SB/launches" ] || fail "launched a disarmed repo"
[ ! -s "$REG" ] || fail "registry line not pruned after disarm"

echo "PASS: resume guard (usage gate, liveness, prune)"
