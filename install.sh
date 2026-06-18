#!/usr/bin/env bash
# Install oroskills into Claude Code's skills directory.
#
# Usage:
#   ./install.sh              # install globally to ~/.claude/skills
#   ./install.sh --project    # install to ./.claude/skills (project-scoped)
#   ./install.sh --copy       # copy files instead of symlinking
#   ./install.sh --force      # overwrite existing skills with the same name

set -euo pipefail

SKILLS=(project-time brainstorming-time writing-plans-time executing-plan-time caveman)
# The ship pipeline ships as agents + a slash command rather than a skill.
# Agents are namespaced (oro-*) to avoid collisions in the global agents dir.
AGENTS=(oro-planner oro-coder oro-tester oro-reviewer)
COMMANDS=(ship)
# The dev pipeline also ships as agents + a slash command.
DEV_AGENTS=(oro-implementer oro-spec-reviewer oro-code-quality-reviewer oro-phase-executor)
DEV_COMMANDS=(dev)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCOPE="global"
MODE="symlink"
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --global)  SCOPE="global"  ;;
    --copy)    MODE="copy"     ;;
    --symlink) MODE="symlink"  ;;
    --force|-f) FORCE=1        ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
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
  ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  echo "  + hook $event -> registered"
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
      "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    echo "  + statusLine config -> $SETTINGS_FILE"
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
  out="$(claude plugin install ponytail@ponytail --scope "$PLUGIN_SCOPE" 2>&1)"; rc=$?
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

echo "Installing oroskills"
echo "  source: $SCRIPT_DIR"
echo "  target: $BASE_DIR"
echo "  mode:   $MODE"
echo

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

install_session_hook

install_statusline

install_ponytail

echo
echo "Done. Restart Claude Code (or start a new session) to pick up the skills, agents, commands (/ship, /dev), caveman default, and ponytail."
