#!/bin/sh
# oroskills statusline — p10k-inspired, emoji-labelled.
# Layout: 📁 dir  🌿 branch · 🤖 model · 🦴 caveman · 🧠 ctx · ⏳ 5h · 📅 7d · 💰 cost · 🕐 time
input=$(cat)

# --- Usage snapshot (bridge: write ~/.claude/oro-usage.json atomically) ---
# Runs silently; never delays or breaks the status line output.
_oro_write_usage() {
  command -v jq >/dev/null 2>&1 || return 0
  _five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  _five_at=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
  _week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  _week_at=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
  [ -z "$_five_pct" ] && [ -z "$_week_pct" ] && return 0
  _ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  _tmp="${HOME}/.claude/oro-usage.$$.json"
  printf '{"five_hour_pct":%s,"five_hour_resets_at":"%s","seven_day_pct":%s,"seven_day_resets_at":"%s","captured_at":"%s"}\n' \
    "${_five_pct:-0}" "${_five_at:-}" "${_week_pct:-0}" "${_week_at:-}" "$_ts" > "$_tmp" 2>/dev/null \
    && mv "$_tmp" "${HOME}/.claude/oro-usage.json" 2>/dev/null
  rm -f "$_tmp" 2>/dev/null
}
_oro_write_usage

# --- 📁 Directory ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
if [ -n "$cwd" ]; then
  home="$HOME"
  short_cwd="${cwd#$home}"
  [ "$short_cwd" != "$cwd" ] && short_cwd="~$short_cwd"
else
  short_cwd="$(pwd)"; short_cwd="${short_cwd#$HOME}"
  [ "${short_cwd}" != "$(pwd)" ] && short_cwd="~$short_cwd"
fi
dir_seg="📁 ${short_cwd}"

# --- 🌿 Git branch ---
git_branch=""
git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
if [ -n "$git_dir" ]; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && git_branch="  🌿 $branch"
fi

# --- 🤖 Model ---
model="🤖 $(echo "$input" | jq -r '.model.display_name // "Unknown Model"')"

# --- 🦴 Caveman mode (per-session flag written by caveman-state.sh) ---
# Caveman is on by default every session, so a missing flag reads on; only an
# explicit "stop caveman" (flag == off) shows the sleeping chip.
caveman="🦴 caveman"
sid=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$sid" ]; then
  cf="${TMPDIR:-/tmp}/claude-caveman/$sid"
  [ -f "$cf" ] && [ "$(cat "$cf")" = "off" ] && caveman="💤 caveman"
fi

# --- 🧠 Context usage (session window) ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_session=""
[ -n "$used_pct" ] && ctx_session=$(printf "🧠 %.0f%% ctx" "$used_pct")

# --- ⏳ 5-hour rate limit window ---
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
ctx_5h=""
[ -n "$five_pct" ] && ctx_5h=$(printf "⏳ %.0f%% 5h" "$five_pct")

# --- 📅 7-day rate limit window ---
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
ctx_week=""
[ -n "$week_pct" ] && ctx_week=$(printf "📅 %.0f%% 7d" "$week_pct")

# --- 💰 Cost estimate ---
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
model_id=$(echo "$input" | jq -r '.model.id // ""')
case "$model_id" in
  *opus*)   input_rate=15; output_rate=75 ;;
  *sonnet*) input_rate=3;  output_rate=15 ;;
  *haiku*)  input_rate=0.8; output_rate=4 ;;
  *)        input_rate=3;  output_rate=15 ;;
esac
cost=$(echo "$total_input $total_output $input_rate $output_rate" | awk '{
  cost = ($1 / 1000000 * $3) + ($2 / 1000000 * $4)
  printf "💰 $%.4f", cost
}')

# --- 🕐 Time ---
time_now="🕐 $(date +%H:%M)"

# --- Assemble ---
sep=" · "
line="${dir_seg}${git_branch}${sep}${model}${sep}${caveman}"
[ -n "$ctx_session" ] && line="${line}${sep}${ctx_session}"
[ -n "$ctx_5h" ]      && line="${line}${sep}${ctx_5h}"
[ -n "$ctx_week" ]    && line="${line}${sep}${ctx_week}"
line="${line}${sep}${cost}${sep}${time_now}"

printf "%s" "$line"
