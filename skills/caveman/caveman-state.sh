#!/bin/sh
# Tracks caveman on/off per session so the statusline can display it.
# Registered on SessionStart (seed "on" — also proves the hook fired) and
# UserPromptSubmit (flip when the user toggles caveman verbally).
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0

dir="${TMPDIR:-/tmp}/claude-caveman"
mkdir -p "$dir" || exit 0   # can't create state dir → no-op, don't write a stray flag
f="$dir/$sid"

event=$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null)
case "$event" in
  SessionStart)
    echo on > "$f"
    ;;
  UserPromptSubmit)
    p=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null | tr 'A-Z' 'a-z')
    case "$p" in
      *"stop caveman"*|*"normal mode"*) echo off > "$f" ;;
      *"caveman mode"*|*"/caveman"*|*"talk like caveman"*|*"use caveman"*) echo on > "$f" ;;
    esac
    ;;
esac
exit 0
