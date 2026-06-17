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
AGENTS=(planner coder tester reviewer)
COMMANDS=(ship)
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
else
  BASE_DIR="$PWD/.claude"
fi

SKILLS_DIR="$BASE_DIR/skills"
AGENTS_DIR="$BASE_DIR/agents"
COMMANDS_DIR="$BASE_DIR/commands"
SETTINGS_FILE="$BASE_DIR/settings.json"
# SessionStart hook that turns caveman mode on by default. The script is copied
# into BASE_DIR (not symlinked/referenced), so moving the repo won't break it.
HOOK_SRC="$SCRIPT_DIR/caveman/caveman-hook.sh"
HOOK_DEST="$BASE_DIR/caveman-hook.sh"
HOOK_CMD="bash \"$HOOK_DEST\""

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

# Merge the caveman SessionStart hook into the target settings.json (idempotent).
install_session_hook() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "  ! skip caveman session hook (jq not found; install jq to enable)"
    return
  fi

  # Copy the hook script into BASE_DIR so it survives the repo moving. Always
  # refresh it so updates to the script propagate on re-install.
  cp "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST"

  [[ -f "$SETTINGS_FILE" ]] || echo '{}' > "$SETTINGS_FILE"

  if jq -e --arg c "$HOOK_CMD" \
      '[.hooks.SessionStart[]?.hooks[]?.command] | any(. == $c)' \
      "$SETTINGS_FILE" >/dev/null; then
    echo "  = caveman session hook (already present)"
    return
  fi

  local tmp
  tmp="$(mktemp)"
  jq --arg c "$HOOK_CMD" '
    .hooks //= {}
    | .hooks.SessionStart = ((.hooks.SessionStart // []) + [{hooks: [{type: "command", command: $c}]}])
  ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  echo "  + caveman session hook -> $SETTINGS_FILE"
}

echo "Installing oroskills"
echo "  source: $SCRIPT_DIR"
echo "  target: $BASE_DIR"
echo "  mode:   $MODE"
echo

mkdir -p "$SKILLS_DIR"
for skill in "${SKILLS[@]}"; do
  install_item "$SCRIPT_DIR/$skill" "$SKILLS_DIR/$skill" "$skill"
done

mkdir -p "$AGENTS_DIR"
for agent in "${AGENTS[@]}"; do
  install_item "$SCRIPT_DIR/ship-pipeline/agents/$agent.md" "$AGENTS_DIR/$agent.md" "agent:$agent"
done

mkdir -p "$COMMANDS_DIR"
for command in "${COMMANDS[@]}"; do
  install_item "$SCRIPT_DIR/ship-pipeline/commands/$command.md" "$COMMANDS_DIR/$command.md" "command:/$command"
done

install_session_hook

echo
echo "Done. Restart Claude Code (or start a new session) to pick up the skills, agents, commands, and caveman default."
