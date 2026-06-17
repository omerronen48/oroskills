# oroskills

Claude Code skills for moving from project idea → roadmap → spec → plan → executed code with less ceremony than the standard `superpowers` chain. Graphify-first, parallelization-aware, TDD-enforced.

## Installation

```bash
git clone https://github.com/<you>/oroskills.git ~/oroskills
cd ~/oroskills
./install.sh
```

Options:

| Flag | Effect |
|---|---|
| _(none)_ | Symlink into `~/.claude/` (global) |
| `--project` | Symlink into `./.claude/` (project-scoped) |
| `--copy` | Copy files instead of symlinking |
| `--force` | Overwrite existing skills/agents with the same name |

The installer places skills in `~/.claude/skills/`, the pipeline agents in `~/.claude/agents/`, the `/ship` + `/dev` commands in `~/.claude/commands/`, registers the caveman session hook, and installs the ponytail plugin. For a project-scoped install, swap `~/.claude/` for `<project>/.claude/`.

Verify, then restart Claude Code (or start a new session):

```bash
ls ~/.claude/skills/    # brainstorming-time caveman executing-plan-time project-time writing-plans-time
ls ~/.claude/commands/  # dev.md ship.md
```

### Caveman on by default

`install.sh` registers a `SessionStart` hook that turns caveman mode on for every new session. The hook script is **copied** into the install target (`~/.claude/caveman-hook.sh`) and points at that copy, so moving or deleting the repo won't break it. Say "stop caveman" / "normal mode" to drop it for a session. Both the copy and the `settings.json` merge are idempotent. To remove it, delete the `SessionStart` entry from `settings.json` and, optionally, the copied script.

**Statusline.** `install.sh` installs an emoji-labelled statusline (`statusline-command.sh`) and points `settings.json` at it:

```
📁 ~/project  🌿 main · 🤖 Opus 4.8 · 🦴 caveman · 🧠 42% ctx · ⏳ 18% 5h · 📅 63% 7d · 💰 $4.05 · 🕐 07:11
```

The caveman chip is driven by `caveman-state.sh`, which the installer also copies and registers on `SessionStart` (seed `on`) + `UserPromptSubmit` (flip on verbal toggle), tracking on/off per session in a tmp flag file: `🦴 caveman` when on, `💤 caveman` when off.

Your statusline is **never clobbered**: if one already exists, the installer leaves it alone and points you at `skills/caveman/statusline-snippet.sh` (the 5-line chip to paste into your own bar). Use `--force` to replace it with the oroskills statusline.

### Ponytail

[ponytail](https://github.com/DietrichGebert/ponytail) is a "lazy senior dev" plugin that enforces minimal, necessary code (YAGNI, stdlib first, one line over fifty). `install.sh` installs and enables it via the Claude Code plugin CLI — it is **not** vendored, so ponytail manages its own skills, commands, hooks, and updates (`claude plugin update ponytail`).

- Activates at mode **`full`** by default. Adjust at runtime with `/ponytail lite|full|ultra|off`; audit with `/ponytail-review` and `/ponytail-audit`.
- The coding skills (`executing-plan-time`, the ship `coder`/`reviewer`) reference ponytail's minimal-code ladder, so dispatched subagents apply it even without the global session hook.

## Skills

| Skill | What it does |
|---|---|
| **project-time** | Turns a project-sized idea into a technical roadmap with milestones. One-question-at-a-time interview with recommended answers; resolves architecture, stack, scope, and non-functional targets up front so feature-level brainstorms stop re-litigating them. |
| **brainstorming-time** | Turns an idea (or one roadmap milestone) into a reviewable spec. Uses graphify for codebase context and produces a mind map before the written spec. |
| **writing-plans-time** | Turns an approved spec into an implementation plan with a File Edit Manifest up front and tasks grouped into parallel-executable waves. |
| **executing-plan-time** | Runs an approved plan end-to-end: worktree setup, parallel implementer subagents, TDD-before-commit, spec + code-quality review, branch finishing. |
| **caveman** | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Trigger with "caveman mode" / "/caveman", or have it on by default (see above). Sourced from [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md). |

The intended chain is **project-time → brainstorming-time → writing-plans-time → executing-plan-time**. Each stage hands off to the next; don't skip stages. `project-time` is optional — use it only when starting a new project or large initiative; for a single feature in an existing codebase, start at `brainstorming-time`.

The skills auto-trigger from their descriptions, but you can invoke them explicitly:

```
Use project-time to scope out <project idea>.
Use brainstorming-time to spec out <idea or milestone Mn>.
Use writing-plans-time on <spec file>.
Use executing-plan-time to run <plan file>.
```

`brainstorming-time`, `writing-plans-time`, and `executing-plan-time` are drop-in replacements for the corresponding `superpowers:*` skills (`brainstorming`, `writing-plans`, `executing-plans` + the worktree/subagent/TDD/verification/finishing chain). `project-time` sits one stage above the chain and has no `superpowers:*` counterpart.

## Pipelines

**Two doors:** `/ship` for a single feature in one sitting (no roadmap, no worktree); `/dev` (or running the chain by hand) for anything larger — multiple phases, parallel waves, per-task two-stage review.

### `/ship` — single-feature pipeline

`/ship <feature request>` runs four subagents that hand work off through a shared `.pipeline/` folder:

| Agent | Model | Stage |
|---|---|---|
| **planner** | opus | Feature request → `.pipeline/spec.md` (exact paths, signatures, edge cases). Flags ambiguity as `OPEN QUESTION`. |
| **coder** | sonnet | Implements the spec exactly → `.pipeline/changes.md`. No scope creep. |
| **tester** | sonnet | Writes/runs tests → `.pipeline/test-results.md`. On failure it **stops** rather than patching the code. |
| **reviewer** | opus | Read-only `git diff` review → `.pipeline/review.md` with `VERDICT: SHIP / NEEDS WORK / BLOCK`. |

`/ship` orchestrates the four in order, confirming each handoff file exists before the next stage, pausing on open questions or test failures, and **never merging** — it leaves the branch for your review. (Opus on the reasoning-heavy plan/review stages, Sonnet on the bulk code/test work.)

```
/ship add rate limiting to the login endpoint
```

### `/dev` — continuous chain loop

`/dev "<idea>"` wraps **project-time → brainstorming-time → writing-plans-time → executing-plan-time** in one resumable command that runs across a multi-phase roadmap:

1. Builds the roadmap once (project-time), seeding a project-local `.dev/memory/` layer (`goals.md`, `decisions.md`, `lessons.md`, `glossary.md`, `progress.md`).
2. For each phase: brainstorm + plan **interactively** (it asks you), then dispatches a **phase-executor** subagent that runs `executing-plan-time` unattended in its own context window.
3. Auto-advances to the next phase, logging every decision to `.dev/memory/decisions.md`.

Each phase runs in a fresh subagent so the main session stays lean; the loop is **resumable** from `.dev/memory/progress.md`. Irreversible forks pause and escalate to you; reversible ones are auto-decided and logged.

## Requirements

- **graphify** — the skills use `graphify query` as their primary source for codebase context. Install it and run `/graphify` once per repo; skills offer to initialize it if `graphify-out/graph.json` is missing.
- **git** — `executing-plan-time` always runs work inside a git worktree.
- **jq** — used to merge the caveman session hook into `settings.json`. If missing, the install skips the hook and reports it.
- **node** — required by ponytail's hooks. If missing at install time, ponytail still installs but its hooks no-op until node is available.
- **claude CLI** — required to install ponytail. If missing, `install.sh` skips ponytail and reports it; the rest of the install proceeds.

## Structure

```
skills/
  project-time/        SKILL.md
  brainstorming-time/  SKILL.md
  writing-plans-time/  SKILL.md  plan-template.md
  executing-plan-time/ SKILL.md
  caveman/             SKILL.md  caveman-hook.sh  caveman-state.sh  statusline-snippet.sh
pipelines/
  ship-pipeline/
    agents/    planner.md  coder.md  tester.md  reviewer.md
    commands/  ship.md
  dev-pipeline/
    agents/    implementer.md  spec-reviewer.md  code-quality-reviewer.md  phase-executor.md
    commands/  dev.md
    memory-protocol.md
tests/dev/
  check_install.sh  check_agents.sh  check_dev_command.sh  check_memory_protocol.sh
statusline-command.sh   # emoji-labelled bar with the caveman chip
install.sh
```
