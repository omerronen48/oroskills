#!/usr/bin/env bash
# Behavior test: run install.sh into a sandbox HOME from a repo copy and assert
# every artifact lands, then assert --uninstall removes them all.
# The repo copy has no .git, so the post-merge hook steps skip — the real repo
# is never touched.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# Stub `claude` so install_ponytail never hits the real CLI or network.
mkdir -p "$SB/bin"
printf '#!/bin/sh\nexit 0\n' > "$SB/bin/claude"
chmod +x "$SB/bin/claude"

cp -R "$REPO" "$SB/repo"
rm -rf "$SB/repo/.git"

fail() { echo "FAIL: $1"; exit 1; }

HOME="$SB" PATH="$SB/bin:$PATH" "$SB/repo/install.sh" >/dev/null
HOME="$SB" PATH="$SB/bin:$PATH" "$SB/repo/install.sh" >/dev/null

for skill in project-time brainstorming-time writing-plans-time executing-plan-time caveman loop-kernel; do
  [ -e "$SB/.claude/skills/$skill/SKILL.md" ] || fail "skill $skill missing"
done
for agent in oro-planner oro-coder oro-tester oro-reviewer oro-implementer oro-task-reviewer oro-phase-executor oro-triager oro-judge oro-distiller oro-critic; do
  [ -e "$SB/.claude/agents/$agent.md" ] || fail "agent $agent missing"
done
for cmd in ship dev fix loop-manager loop-worker address-review; do
  [ -e "$SB/.claude/commands/$cmd.md" ] || fail "command $cmd missing"
done
[ -e "$SB/.claude/memory-protocol.md" ] || fail "memory-protocol.md missing"
[ -x "$SB/.claude/caveman-hook.sh" ] || fail "caveman-hook.sh missing"
[ -x "$SB/.claude/caveman-state.sh" ] || fail "caveman-state.sh missing"
[ -x "$SB/.claude/goal-stop.sh" ] || fail "goal-stop.sh missing"
[ -x "$SB/.claude/guard-edits.sh" ] || fail "guard-edits.sh missing"
[ -f "$SB/.claude/statusline-command.sh" ] || fail "statusline missing"
[ -x "$SB/.claude/dev-resume-guard.sh" ] || fail "dev-resume-guard.sh missing"
[ "$(cat "$SB/.claude/.oroskills-mode")" = "symlink" ] || fail "mode marker wrong"
command -v jq >/dev/null && {
  jq -e '.hooks.SessionStart' "$SB/.claude/settings.json" >/dev/null || fail "SessionStart hooks not registered"
  jq -e '.statusLine.command' "$SB/.claude/settings.json" >/dev/null || fail "statusLine not configured"
  jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | any(test("guard-edits.sh"))' "$SB/.claude/settings.json" >/dev/null || fail "PreToolUse guard not registered"
  [ "$(jq -r '[.hooks.PreToolUse[]? | select([.hooks[]?.command] | any(test("guard-edits.sh"))) | .matcher] | join(",")' "$SB/.claude/settings.json")" = "Edit|Write|NotebookEdit" ] || fail "PreToolUse guard matcher wrong or duplicated"
  jq -e '[.hooks.Stop[]?.hooks[]?.command] | any(test("goal-stop.sh"))' "$SB/.claude/settings.json" >/dev/null || fail "Stop hook not registered"
  [ "$(jq '[.hooks.Stop[]?.hooks[]?.command | select(test("goal-stop.sh"))] | length' "$SB/.claude/settings.json")" = 1 ] || fail "Stop hook duplicated"
}

HOME="$SB" PATH="$SB/bin:$PATH" "$SB/repo/install.sh" --uninstall >/dev/null

[ ! -e "$SB/.claude/skills/caveman" ] || fail "uninstall left skills"
[ ! -e "$SB/.claude/agents/oro-planner.md" ] || fail "uninstall left agents"
[ ! -e "$SB/.claude/commands/ship.md" ] || fail "uninstall left commands"
[ ! -e "$SB/.claude/memory-protocol.md" ] || fail "uninstall left memory-protocol"
[ ! -e "$SB/.claude/caveman-hook.sh" ] || fail "uninstall left hook scripts"
[ ! -e "$SB/.claude/dev-resume-guard.sh" ] || fail "uninstall left resume guard"
[ ! -e "$SB/.claude/goal-stop.sh" ] || fail "goal-stop.sh not removed"
[ ! -e "$SB/.claude/guard-edits.sh" ] || fail "guard-edits.sh not removed"
[ ! -e "$SB/.claude/commands/address-review.md" ] || fail "address-review command not removed"
command -v jq >/dev/null && {
  [ "$(jq -r '[.hooks[]?[]?.hooks[]?.command] | length' "$SB/.claude/settings.json")" = "0" ] || fail "uninstall left hook entries"
  jq -e '[.hooks.Stop[]?.hooks[]?.command] | any(test("goal-stop.sh")) | not' "$SB/.claude/settings.json" >/dev/null || fail "Stop hook not removed"
}

echo "PASS: sandbox install + uninstall"
