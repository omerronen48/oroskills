#!/bin/sh
# oroskills: dead-man's switch for `/dev --auto` — relaunches roadmap runs that
# died mid-flight (usage limit, crash). Cron-invoked every ~15 min.
#
# Armed by dev.md at --auto start:   touch <repo>/.dev/auto-resume
#                                    claude pid  -> <repo>/.dev/auto.lock
#                                    repo path   -> ~/.claude/dev-auto-repos
# Disarmed on every orderly ending:  rm .dev/auto-resume .dev/auto.lock
# The registry self-prunes here: a line whose marker is gone is dropped.
#
# Usage gate: an exhausted window blocks relaunch until ITS reset — the weekly
# window is checked before the 5-hour one, so a tripped weekly limit schedules
# the resumption for the weekly reset. Data comes from ~/.claude/oro-usage.json
# (written by the statusline bridge); if the snapshot is absent we just try —
# a rate-limited headless run fails fast and the next tick retries.

REGISTRY="${OROSKILLS_REGISTRY:-$HOME/.claude/dev-auto-repos}"
USAGE="${OROSKILLS_USAGE:-$HOME/.claude/oro-usage.json}"
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"  # cron PATH is minimal; append fallbacks

[ -s "$REGISTRY" ] || exit 0
command -v claude >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

now=$(date +%s)

# epoch <- epoch-seconds or ISO8601 (statusline docs say epoch; older builds ISO)
to_epoch() {
  case "$1" in
    ''|null) echo 0 ;;
    *[!0-9]*) date -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null \
              || date -d "$1" +%s 2>/dev/null || echo 0 ;;
    *) echo "$1" ;;
  esac
}

if [ -f "$USAGE" ]; then
  for w in seven_day five_hour; do
    pct=$(jq -r ".${w}_pct // 0" "$USAGE" 2>/dev/null)
    at=$(to_epoch "$(jq -r ".${w}_resets_at // empty" "$USAGE" 2>/dev/null)")
    pct=${pct%.*}
    if [ "${pct:-0}" -ge 90 ] 2>/dev/null && [ "$at" -gt "$now" ]; then
      exit 0  # window exhausted and not yet reset — wait for it
    fi
  done
fi

tmp="$REGISTRY.tmp.$$"
: > "$tmp"
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  [ -f "$repo/.dev/auto-resume" ] || continue  # disarmed or repo gone — prune
  echo "$repo" >> "$tmp"
  # ponytail: liveness = claude pid captured at bootstrap; a bad pid read means
  # worst case one duplicate relaunch, which worktree isolation keeps safe.
  pid=$(cat "$repo/.dev/auto.lock" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && continue  # run still alive
  ( cd "$repo" && nohup claude -p '/dev --auto' >> .dev/auto.log 2>&1 & )
done < "$REGISTRY"
mv "$tmp" "$REGISTRY"
