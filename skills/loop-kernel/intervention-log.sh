#!/usr/bin/env bash
# UserPromptSubmit hook: log human prompts to history.jsonl while a loop run is active. Never blocks.
in="$(cat)"  # drain stdin so the sender never gets SIGPIPE
D="${CLAUDE_PROJECT_DIR:-.}"
[ -f "$D/.loop/active" ] || exit 0
command -v jq >/dev/null || exit 0
mkdir -p "$D/.dev/memory"
line="$(jq -c '{date:(now|strftime("%Y-%m-%d")), event:"intervention", prompt:(.prompt|tostring|.[0:80])}' <<<"$in" 2>/dev/null)" && echo "$line" >> "$D/.dev/memory/history.jsonl"
exit 0
