#!/usr/bin/env bash
# scorecard.sh turns .dev/memory/history.jsonl into autonomy/automation/quality numbers.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SC="$REPO/skills/loop-kernel/scorecard.sh"
fail() { echo "FAIL: $1"; exit 1; }
command -v jq >/dev/null || { echo "SKIP: jq missing"; exit 0; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
H="$D/history.jsonl"
cat > "$H" <<'EOT'
{"date":"2026-11-01T00:00:00Z","pipeline":"ship","goal":"a","attempts":{"t1":1,"t2":3},"climb":[7,8.5],"caps":0,"reward_hacks":1}
{"date":"2026-11-02T00:00:00Z","pipeline":"fix","goal":"b","attempts":{"t1":2},"climb":[6],"caps":1,"reward_hacks":0}
not json
{"date":"2026-11-02T01:00:00Z","event":"intervention","prompt":"continue"}
{"date":"2026-11-02T02:00:00Z","event":"intervention","prompt":"no, use pnpm"}
{"date":"2026-11-03T00:00:00Z","event":"pr_opened","pr":5,"by":"agent"}
{"date":"2026-11-03T00:00:00Z","event":"pr_opened","pr":6,"by":"agent"}
{"date":"2026-11-04T00:00:00Z","event":"pr_review","pr":5,"human_comments":3}
{"date":"2026-11-04T00:00:00Z","event":"pr_review","pr":6,"human_comments":0}
EOT
out="$(bash "$SC" "$H")"
want() { grep -qx "$1" <<<"$out" || fail "expected '$1' in: $out"; }
want "runs: 2"; want "mean_attempts_per_task: 2"; want "cap_hits: 1"; want "reward_hacks: 1"
want "interventions: 2"; want "interventions_per_run: 1"
want "agent_prs: 2"; want "zero_touch_prs: 1"; want "human_comments_per_reviewed_pr: 1.5"
want "climb_runs: 1"; want "mean_climb_gain: 1.5"; want "malformed_lines: 1"
# --since filters dated lines (second input set)
out="$(bash "$SC" "$H" --since 2026-11-02)"
want "runs: 1"; want "reward_hacks: 0"; want "interventions_per_run: 2"; want "climb_runs: 0"; want "mean_climb_gain: 0"
# empty history and missing file are not errors
: > "$D/empty.jsonl"; out="$(bash "$SC" "$D/empty.jsonl")"; want "runs: 0"; want "interventions_per_run: 0"
out="$(bash "$SC" "$D/missing.jsonl")" || fail "missing file must exit 0"
grep -q "no history" <<<"$out" || fail "missing file message"
# --since without a value must exit 2, not hang
set +e; perl -e 'alarm 5; exec @ARGV' bash "$SC" "$H" --since >/dev/null 2>&1; rc=$?; set -e
[ "${rc:-0}" = 2 ] || fail "--since without value should exit 2 (got ${rc:-0})"
echo "PASS: scorecard"
