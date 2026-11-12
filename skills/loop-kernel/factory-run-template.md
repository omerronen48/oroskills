# How agents run this project

Commands only; write `n/a` where a section does not apply. Behavior checks and climb screenshots use these (loop-kernel §0).

## Launch
- <command that starts the app/server/CLI locally, and the URL or port it serves on>

## Logs
- <where runtime logs go, or the command to tail them>

## Smoke
- <one command that proves the real thing works end to end, exits 0 on success>

## Browser
- `agent-browser --session "$(agent-browser session id --scope worktree --prefix task)" open <URL>` (plus any login/seed step: `agent-browser snapshot -i`, `agent-browser click @e3`), then `agent-browser screenshot <path>` and `agent-browser close`; or n/a
