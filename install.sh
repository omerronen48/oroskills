#!/usr/bin/env bash
# Install oroskills into Claude Code's skills directory.
#
# Usage:
#   ./install.sh              # install globally to ~/.claude/skills
#   ./install.sh --project    # install to ./.claude/skills (project-scoped)
#   ./install.sh --copy       # copy files instead of symlinking
#   ./install.sh --force      # overwrite existing skills with the same name
#   ./install.sh --refresh    # re-link new files + re-copy hook scripts (skips statusline); used by the auto-installed post-merge git hook
#   ./install.sh --uninstall  # remove everything install.sh added (skills, agents, commands, hooks, statusline)

set -euo pipefail

SKILLS=(project-time brainstorming-time writing-plans-time executing-plan-time caveman)
# The ship pipeline ships as agents + a slash command rather than a skill.
# Agents are namespaced (oro-*) to avoid collisions in the global agents dir.
AGENTS=(oro-planner oro-coder oro-tester oro-reviewer)
COMMANDS=(ship)
# The dev pipeline also ships as agents + a slash command.
DEV_AGENTS=(oro-implementer oro-task-reviewer oro-phase-executor)
DEV_COMMANDS=(dev)
# The loop pipeline (autonomous agent loops) also ships as agents + slash commands.
LOOP_AGENTS=(oro-triager)
LOOP_COMMANDS=(loop-manager loop-worker)
# The fix pipeline (batch of small fixes) ships as a slash command reusing the ship agents.
FIX_COMMANDS=(fix)
# The review pipeline (post-PR feedback) also reuses the ship agents.
REVIEW_COMMANDS=(address-review)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCOPE="global"
MODE="symlink"
FORCE=0
REFRESH=0
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --global)  SCOPE="global"  ;;
    --copy)    MODE="copy"     ;;
    --symlink) MODE="symlink"  ;;
    --force|-f) FORCE=1        ;;
    --refresh) REFRESH=1; FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$SCOPE" == "global" ]]; then
  BASE_DIR="$HOME/.claude"
  PLUGIN_SCOPE="user"
else
  BASE_DIR="$PWD/.claude"
  PLUGIN_SCOPE="project"
fi

# Remember the --copy/--symlink choice so --refresh (run blindly by the
# post-merge hook) doesn't convert a copy install into symlinks.
MODE_FILE="$BASE_DIR/.oroskills-mode"
if [[ "$REFRESH" -eq 1 && -f "$MODE_FILE" ]]; then
  MODE="$(cat "$MODE_FILE")"
fi

SKILLS_DIR="$BASE_DIR/skills"
AGENTS_DIR="$BASE_DIR/agents"
COMMANDS_DIR="$BASE_DIR/commands"
SETTINGS_FILE="$BASE_DIR/settings.json"
# SessionStart hook that turns caveman mode on by default. The script is copied
# into BASE_DIR (not symlinked/referenced), so moving the repo won't break it.
HOOK_SRC="$SCRIPT_DIR/skills/caveman/caveman-hook.sh"
HOOK_DEST="$BASE_DIR/caveman-hook.sh"
HOOK_CMD="bash \"$HOOK_DEST\""

# Per-session caveman on/off flag for the statusline. Same copy-not-reference
# treatment. Registered on SessionStart (seed "on") + UserPromptSubmit (toggle).
STATE_SRC="$SCRIPT_DIR/skills/caveman/caveman-state.sh"
STATE_DEST="$BASE_DIR/caveman-state.sh"
STATE_CMD="sh \"$STATE_DEST\""
STATUSLINE_SRC="$SCRIPT_DIR/statusline-command.sh"
STATUSLINE_FILE="$BASE_DIR/statusline-command.sh"
STATUSLINE_CMD="sh \"$STATUSLINE_FILE\""
STATUSLINE_SNIPPET="$SCRIPT_DIR/skills/caveman/statusline-snippet.sh"

# install_item <src> <dest> <label>
install_item() {
  local src="$1" dest="$2" label="$3"

  if [[ ! -e "$src" ]]; then
    echo "  ! skip $label (not found at $src)"
    return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      rm -rf "$dest"
    else
      echo "  ! skip $label (already exists; use --force to overwrite)"
      return
    fi
  fi

  if [[ "$MODE" == "copy" ]]; then
    cp -R "$src" "$dest"
    echo "  + copied  $label"
  else
    ln -s "$src" "$dest"
    echo "  + linked  $label"
  fi
}

# register_hook <event> <command> — idempotently add a command hook to SETTINGS_FILE.
register_hook() {
  local event="$1" cmd="$2" tmp
  if jq -e --arg e "$event" --arg c "$cmd" \
      '[.hooks[$e][]?.hooks[]?.command] | any(. == $c)' "$SETTINGS_FILE" >/dev/null; then
    echo "  = hook $event (already present)"
    return
  fi
  tmp="$(mktemp)"
  jq --arg e "$event" --arg c "$cmd" '
    .hooks //= {}
    | .hooks[$e] = ((.hooks[$e] // []) + [{hooks: [{type: "command", command: $c}]}])
  ' "$SETTINGS_FILE" > "$tmp" \
    && mv "$tmp" "$SETTINGS_FILE" \
    && echo "  + hook $event -> registered" \
    || { rm -f "$tmp"; echo "  ! hook $event NOT registered (jq failed on $SETTINGS_FILE)"; return 1; }
}

# Copy the caveman hook scripts into BASE_DIR and register their hooks (idempotent).
# Scripts are copied (not referenced) so they survive the repo moving; always
# refreshed so updates propagate on re-install.
install_session_hook() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "  ! skip caveman session hook (jq not found; install jq to enable)"
    return
  fi

  cp "$HOOK_SRC"  "$HOOK_DEST";  chmod +x "$HOOK_DEST"
  cp "$STATE_SRC" "$STATE_DEST"; chmod +x "$STATE_DEST"

  [[ -f "$SETTINGS_FILE" ]] || echo '{}' > "$SETTINGS_FILE"

  register_hook SessionStart    "$HOOK_CMD"   # caveman on by default
  register_hook SessionStart    "$STATE_CMD"  # seed per-session on/off flag
  register_hook UserPromptSubmit "$STATE_CMD"  # flip the flag on verbal toggle
}

# Install the oroskills statusline (emoji-labelled, caveman chip baked in) and
# point settings.json at it. Guarded: an existing statusline you customized is
# never clobbered without --force — we just point you at the paste-in snippet.
install_statusline() {
  if [[ -f "$STATUSLINE_FILE" && "$FORCE" -ne 1 ]]; then
    if grep -q 'claude-caveman' "$STATUSLINE_FILE"; then
      echo "  = statusline (already has caveman chip)"
    else
      echo "  ! statusline exists; not replacing (use --force). To add just the"
      echo "    caveman chip, paste: $STATUSLINE_SNIPPET"
    fi
    return
  fi

  cp "$STATUSLINE_SRC" "$STATUSLINE_FILE"
  chmod +x "$STATUSLINE_FILE"
  echo "  + statusline -> $STATUSLINE_FILE"

  if command -v jq >/dev/null 2>&1; then
    [[ -f "$SETTINGS_FILE" ]] || echo '{}' > "$SETTINGS_FILE"
    local tmp; tmp="$(mktemp)"
    jq --arg c "$STATUSLINE_CMD" '.statusLine = {type: "command", command: $c}' \
      "$SETTINGS_FILE" > "$tmp" \
      && mv "$tmp" "$SETTINGS_FILE" \
      && echo "  + statusLine config -> $SETTINGS_FILE" \
      || { rm -f "$tmp"; echo "  ! statusLine config NOT set (jq failed on $SETTINGS_FILE)"; }
  else
    echo "  ! statusLine config not set (jq not found); add it manually"
  fi
}

# Install + enable the ponytail plugin (minimal-code enforcement) via the
# Claude Code plugin CLI. Delegated, not vendored — ponytail owns its own
# hooks, skills, and updates. Default mode is ponytail's own 'full'.
install_ponytail() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "  ! skip ponytail (claude CLI not found)"
    return
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "  ! ponytail installing but node not found; its hooks no-op until node is available"
  fi

  claude plugin marketplace add DietrichGebert/ponytail --scope "$PLUGIN_SCOPE" >/dev/null 2>&1 || true

  local out rc
  out="$(claude plugin install ponytail@ponytail --scope "$PLUGIN_SCOPE" 2>&1)" && rc=0 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "  + ponytail plugin (mode: full)"
  elif echo "$out" | grep -qi 'already'; then
    echo "  = ponytail (already installed)"
  else
    # Surface the real failure (network/auth/etc.) instead of masking it.
    echo "  ! ponytail install failed (rc=$rc):"
    echo "$out" | sed 's/^/      /'
  fi
}

uninstall() {
  echo "Uninstalling oroskills from $BASE_DIR"
  local item tmp
  for item in "${SKILLS[@]}"; do rm -rf "$SKILLS_DIR/$item"; done
  for item in "${AGENTS[@]}" "${DEV_AGENTS[@]}" "${LOOP_AGENTS[@]}"; do rm -f "$AGENTS_DIR/$item.md"; done
  for item in "${COMMANDS[@]}" "${DEV_COMMANDS[@]}" "${LOOP_COMMANDS[@]}" "${FIX_COMMANDS[@]}" "${REVIEW_COMMANDS[@]}"; do rm -f "$COMMANDS_DIR/$item.md"; done
  rm -f "$HOOK_DEST" "$STATE_DEST" "$BASE_DIR/memory-protocol.md" "$MODE_FILE"
  rm -f "$BASE_DIR/dev-resume-guard.sh" "$BASE_DIR/dev-auto-repos" "$BASE_DIR/oro-usage.json"
  # Drop the resume-guard crontab line only if present (no-op otherwise, so a
  # sandboxed uninstall never rewrites the real crontab).
  if crontab -l 2>/dev/null | grep -q dev-resume-guard; then
    crontab -l 2>/dev/null | grep -v dev-resume-guard | crontab -
  fi
  # Only remove the statusline if it's ours (has the caveman chip).
  if [[ -f "$STATUSLINE_FILE" ]] && grep -q 'claude-caveman' "$STATUSLINE_FILE"; then
    rm -f "$STATUSLINE_FILE"
  fi
  if command -v jq >/dev/null 2>&1 && [[ -f "$SETTINGS_FILE" ]]; then
    tmp="$(mktemp)"
    jq --arg h "$HOOK_CMD" --arg s "$STATE_CMD" --arg sl "$STATUSLINE_CMD" '
      (if .hooks then .hooks |= with_entries(.value |= map(select([.hooks[]?.command] | any(. == $h or . == $s) | not))) else . end)
      | if (.statusLine.command // "") == $sl then del(.statusLine) else . end
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE" \
      || { rm -f "$tmp"; echo "  ! could not clean $SETTINGS_FILE (jq failed); remove oroskills hooks/statusLine manually"; }
  fi
  local hooks_dir
  if hooks_dir="$(git -C "$SCRIPT_DIR" rev-parse --git-path hooks 2>/dev/null)"; then
    case "$hooks_dir" in /*) ;; *) hooks_dir="$SCRIPT_DIR/$hooks_dir" ;; esac
    if [[ -f "$hooks_dir/post-merge" ]] && grep -q "oroskills: auto-apply" "$hooks_dir/post-merge"; then
      rm -f "$hooks_dir/post-merge"
    fi
  fi
  echo "Done. Ponytail plugin left as-is (remove with: claude plugin uninstall ponytail@ponytail)."
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  uninstall
  exit 0
fi

echo "Installing oroskills"
echo "  source: $SCRIPT_DIR"
echo "  target: $BASE_DIR"
echo "  mode:   $MODE"
echo

mkdir -p "$BASE_DIR"
[[ "$REFRESH" -eq 1 ]] || echo "$MODE" > "$MODE_FILE"

mkdir -p "$SKILLS_DIR"
for skill in "${SKILLS[@]}"; do
  install_item "$SCRIPT_DIR/skills/$skill" "$SKILLS_DIR/$skill" "$skill"
done

mkdir -p "$AGENTS_DIR"
for agent in "${AGENTS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/ship-pipeline/agents/$agent.md" "$AGENTS_DIR/$agent.md" "agent:$agent"
done

mkdir -p "$COMMANDS_DIR"
for command in "${COMMANDS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/ship-pipeline/commands/$command.md" "$COMMANDS_DIR/$command.md" "command:/$command"
done

for agent in "${DEV_AGENTS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/dev-pipeline/agents/$agent.md" "$AGENTS_DIR/$agent.md" "agent:$agent"
done

for command in "${DEV_COMMANDS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/dev-pipeline/commands/$command.md" "$COMMANDS_DIR/$command.md" "command:/$command"
done

# Memory-protocol contract referenced by the dev agents and chain skills.
install_item "$SCRIPT_DIR/pipelines/dev-pipeline/memory-protocol.md" "$BASE_DIR/memory-protocol.md" "dev:memory-protocol"

# /dev --auto resume guard (cron-invoked dead-man's switch). Copied, not
# symlinked, so the crontab entry survives the repo moving.
cp "$SCRIPT_DIR/pipelines/dev-pipeline/dev-resume-guard.sh" "$BASE_DIR/dev-resume-guard.sh"
chmod +x "$BASE_DIR/dev-resume-guard.sh"
echo "  + dev:resume-guard"

for agent in "${LOOP_AGENTS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/loop-pipeline/agents/$agent.md" "$AGENTS_DIR/$agent.md" "agent:$agent"
done

for command in "${LOOP_COMMANDS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/loop-pipeline/commands/$command.md" "$COMMANDS_DIR/$command.md" "command:/$command"
done

for command in "${FIX_COMMANDS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/fix-pipeline/commands/$command.md" "$COMMANDS_DIR/$command.md" "command:/$command"
done

for command in "${REVIEW_COMMANDS[@]}"; do
  install_item "$SCRIPT_DIR/pipelines/review-pipeline/commands/$command.md" "$COMMANDS_DIR/$command.md" "command:/$command"
done

# Remove dangling symlinks that point into this repo (left behind by renames).
for dir in "$SKILLS_DIR" "$AGENTS_DIR" "$COMMANDS_DIR"; do
  for link in "$dir"/*; do
    [[ -L "$link" && ! -e "$link" ]] || continue
    case "$(readlink "$link")" in
      "$SCRIPT_DIR"/*) rm "$link"; echo "  - removed dead link: $(basename "$link")" ;;
    esac
  done
done

install_post_merge_hook() {
  # .git/hooks is untracked, so the installer drops this into each clone. After every
  # `git pull`/merge it re-runs `install.sh --refresh`: symlinked content is already live,
  # so this just wires up newly-added skills/agents/commands and re-copies the hook scripts.
  # ponytail: post-merge only — add post-checkout/post-rewrite if branch-switching ever needs the same refresh.
  local hooks_dir
  hooks_dir="$(git -C "$SCRIPT_DIR" rev-parse --git-path hooks 2>/dev/null)" || {
    echo "  (skipped post-merge hook: $SCRIPT_DIR is not a git repo)"; return 0; }
  case "$hooks_dir" in /*) ;; *) hooks_dir="$SCRIPT_DIR/$hooks_dir" ;; esac   # --git-path may be relative
  mkdir -p "$hooks_dir"
  local hook="$hooks_dir/post-merge"
  local scope_flag="--global"
  [ "$SCOPE" = "project" ] && scope_flag="--project"
  if [ -e "$hook" ] && ! grep -q "oroskills: auto-apply" "$hook" 2>/dev/null; then
    echo "  (post-merge hook exists and isn't ours — leaving it; add '\$root/install.sh --refresh $scope_flag' yourself)"
    return 0
  fi
  cat > "$hook" <<EOF
#!/bin/sh
# oroskills: auto-apply repo changes after every pull/merge (installed by install.sh).
root=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -x "\$root/install.sh" ] || exit 0
"\$root/install.sh" --refresh $scope_flag >/dev/null 2>&1 || true
EOF
  chmod +x "$hook"
  echo "  Installed post-merge hook -> $hook (runs: install.sh --refresh $scope_flag on every pull)"
}

install_session_hook   # re-copies the 3 hook scripts; under --refresh FORCE=1 makes that a real refresh

install_post_merge_hook

if [ "$REFRESH" -eq 1 ]; then
  echo
  echo "Refreshed: re-linked skills/agents/commands and re-copied hook scripts (statusline left untouched)."
else
  install_statusline

  install_ponytail

  echo
  echo "Done. Restart Claude Code (or start a new session) to pick up the skills, agents, commands (/ship, /fix, /dev, /loop-manager, /loop-worker), caveman default, and ponytail."
fi
