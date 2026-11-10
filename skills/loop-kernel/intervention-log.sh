#!/usr/bin/env bash
# UserPromptSubmit hook (loop-kernel §6). While a run is active (.loop/active),
# every human prompt is an intervention: a place the harness failed to carry
# the agent on its own. Appends {"date","event":"intervention","prompt"} to
# .dev/memory/history.jsonl for scorecard.sh. Never blocks, never prints.
# ponytail: counts every prompt during a run (incl. approvals); scorecard trend matters, not absolutes.
input="$(cat)"
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[[ -f .loop/active ]] || exit 0
command -v jq >/dev/null || exit 0
p="$(jq -r '.prompt // ""' <<<"$input" 2>/dev/null)" || p=""
p="${p:0:80}"
mkdir -p .dev/memory 2>/dev/null || exit 0
jq -nc --arg d "$(date -u +%FT%TZ)" --arg p "$p" '{date:$d,event:"intervention",prompt:$p}' \
  >> .dev/memory/history.jsonl 2>/dev/null
exit 0
