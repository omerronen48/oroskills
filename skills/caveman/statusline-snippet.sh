# Caveman statusline chip — paste into your ~/.claude/statusline-command.sh.
# Reads the per-session flag written by caveman-state.sh (installed by install.sh).
# Shows "🦴 caveman" when on, "caveman off" otherwise. Requires the script to
# read its JSON input into `$input` (e.g. `input=$(cat)`) and assemble a `$line`.

# 1) After you read stdin into `$input`, add this block:
# Caveman is on by default, so a missing flag reads on; only an explicit
# "stop caveman" (flag == off) shows the sleeping chip.
caveman="🦴 caveman"
sid=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$sid" ]; then
  cf="${TMPDIR:-/tmp}/claude-caveman/$sid"
  [ -f "$cf" ] && [ "$(cat "$cf")" = "off" ] && caveman="💤 caveman"
fi

# 2) Where you build the output line, append the chip, e.g.:
#    line="${line}${sep}${caveman}"
# (use whatever separator your statusline already uses).
