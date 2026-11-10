#!/usr/bin/env bash
# scorecard.sh [history.jsonl] [--since YYYY-MM-DD]   (loop-kernel §6)
# Is the factory improving? Autonomy (interventions per run), automation
# (zero-touch agent PRs, human comments per PR) and quality (attempts, caps,
# reward hacks, climb gain) from .dev/memory/history.jsonl. Read-only.
set -uo pipefail
file=".dev/memory/history.jsonl"; since=""
while (( $# )); do
  case "$1" in
    --since) [[ -n "${2:-}" ]] || { echo "scorecard: --since needs a date"; exit 2; }; since="$2"; shift 2 ;;
    *) file="$1"; shift ;;
  esac
done
command -v jq >/dev/null || { echo "scorecard: jq required"; exit 2; }
[[ -f "$file" ]] || { echo "scorecard: no history at $file"; exit 0; }
jq -R -s -r --arg since "$since" '
  def avg: if length == 0 then 0 else add / length end;
  def r2: ((. * 100 + 0.5) | floor) / 100;
  [split("\n")[] | select(length > 0)] as $lines
  | [$lines[] | (try fromjson catch null)] as $parsed
  | ([$parsed[] | select(type != "object")] | length) as $bad
  | [$parsed[] | select(type == "object") | select($since == "" or ((.date // "") >= $since))] as $h
  | [$h[] | select(.event == null and .pipeline != null)] as $runs
  | [$runs[] | (.attempts // {}) | to_entries[] | .value] as $att
  | ([$h[] | select(.event == "intervention")] | length) as $int
  | [$h[] | select(.event == "pr_opened" and .by == "agent") | .pr] as $aprs
  | [$h[] | select(.event == "pr_review")] as $rev
  | [$rev[] | select((.human_comments // 0) > 0) | .pr] as $touched
  | [$runs[] | (.climb // []) | select(length >= 2) | (.[-1] - .[0])] as $gain
  | "runs: \($runs | length)",
    "mean_attempts_per_task: \($att | avg | r2)",
    "cap_hits: \([$runs[] | .caps // 0] | add // 0)",
    "reward_hacks: \([$runs[] | .reward_hacks // 0] | add // 0)",
    "interventions: \($int)",
    "interventions_per_run: \(if ($runs | length) == 0 then 0 else ($int / ($runs | length) | r2) end)",
    "agent_prs: \($aprs | length)",
    "zero_touch_prs: \([$aprs[] | . as $p | select($touched | any(. == $p) | not)] | length)",
    "human_comments_per_reviewed_pr: \([$rev[] | .human_comments // 0] | avg | r2)",
    "climb_runs: \($gain | length)",
    "mean_climb_gain: \($gain | avg | r2)",
    "malformed_lines: \($bad)"
' "$file"
