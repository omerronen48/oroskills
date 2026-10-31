#!/usr/bin/env bash
# Stop hook (loop-kernel). Active only when .loop/auto AND .loop/goal.md exist
# in the project: runs each `cmd` under "## Done-criteria" and blocks the stop
# until all pass. Gives up after 3 consecutive blocks and logs an ESCALATE note.
# ponytail: no per-command timeout; Claude Code's hook timeout bounds the run.
set -uo pipefail
cat >/dev/null   # drain hook input; block counter replaces stop_hook_active
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[[ -f .loop/auto && -f .loop/goal.md ]] || exit 0
command -v jq >/dev/null || exit 0   # cannot emit block JSON; allow without bumping counter

counter=.loop/stop-blocks
blocks=$(cat "$counter" 2>/dev/null || echo 0)
cmds="$(awk '/^## /{s=($0 ~ /^## Done-criteria/)} s && /^- \[.\] `/' .loop/goal.md \
  | sed -E 's/^- \[.\] `([^`]*)`.*/\1/')"

failing=""; tail_out=""
while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  if ! out="$(bash -c "$c" 2>&1)"; then failing="$c"; tail_out="$(tail -n 30 <<<"$out")"; break; fi
done <<<"$cmds"

if [[ -z "$failing" ]]; then rm -f "$counter"; exit 0; fi
if (( blocks >= 3 )); then
  echo "ESCALATE: goal-stop gave up after 3 blocks; failing: $failing" >> .loop/escalations.md
  rm -f "$counter"; exit 0
fi
echo $((blocks + 1)) > "$counter"
goal="$(awk '/^# Goal/{g=1;next} /^## /{g=0} g' .loop/goal.md)"
jq -n --arg r "Goal not met yet:$goal
Failing done-criterion: \`$failing\`
$tail_out
Keep working until every done-criterion in .loop/goal.md passes." '{decision:"block",reason:$r}'
