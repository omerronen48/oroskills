# oroskills

A set of Claude Code skills for moving from project idea → roadmap → spec → plan → executed code with less ceremony than the standard `superpowers` chain. Graphify-first, parallelization-aware, TDD-enforced.

## The Skills

| Skill | What it does |
|---|---|
| **project-time** | Turns a project-sized idea into a technical roadmap with milestones. Grill-me style one-question-at-a-time interview with recommended answers; resolves architecture, stack, scope, and non-functional targets up front so feature-level brainstorms stop re-litigating them. |
| **brainstorming-time** | Turns an idea (or one milestone from a roadmap) into a reviewable spec. Uses graphify for codebase context and produces a mind map before the written spec. |
| **writing-plans-time** | Turns an approved spec into an implementation plan with a File Edit Manifest up front and tasks grouped into parallel-executable waves. |
| **executing-plan-time** | Runs an approved plan end-to-end: worktree setup, parallel implementer subagents, TDD-before-commit, spec + code-quality review, branch finishing. |
| **caveman** | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Trigger with "caveman mode" / "/caveman", or have it **on by default** (see below). Sourced from [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md). |

### Caveman on by default

`install.sh` also registers a `SessionStart` hook that turns caveman mode on automatically for every new session. The hook script (`caveman/caveman-hook.sh`) is **copied** into the install target (`~/.claude/caveman-hook.sh`, or `./.claude/caveman-hook.sh` for `--project`) and the hook points at that copy — so moving or deleting the repo won't break it. It injects a self-contained directive that works whether or not the caveman skill is installed. Say "stop caveman" / "normal mode" any time to drop it for the session.

- Requires `jq` (used to merge the hook into `settings.json` without clobbering existing settings). If `jq` is missing, the install skips the hook and reports it.
- Both the script copy and the merge are idempotent; re-running `install.sh` refreshes the script and won't duplicate the hook.
- To remove it, delete the `SessionStart` entry from `~/.claude/settings.json` (or `./.claude/settings.json` for a `--project` install) and, optionally, the copied `caveman-hook.sh`.

`brainstorming-time`, `writing-plans-time`, and `executing-plan-time` are drop-in replacements for the corresponding `superpowers:*` skills (`brainstorming`, `writing-plans`, `executing-plans` + the worktree/subagent/TDD/verification/finishing chain). `project-time` sits one stage above the chain and has no `superpowers:*` counterpart — invoke it when starting a new project or large multi-feature initiative.

## The Ship Pipeline

A separate, self-contained feature pipeline that ships as **four subagents plus a `/ship` slash command** rather than a skill. You run `/ship <feature request>` and four agents hand work off to each other through a shared `.pipeline/` folder:

| Agent | Model | Stage |
|---|---|---|
| **planner** | opus | Feature request → `.pipeline/spec.md` (exact paths, signatures, edge cases). Flags ambiguity as `OPEN QUESTION`. |
| **coder** | sonnet | Implements the spec exactly → `.pipeline/changes.md`. No scope creep. |
| **tester** | sonnet | Writes/runs tests → `.pipeline/test-results.md`. On failure it **stops** rather than patching the code. |
| **reviewer** | opus | Read-only `git diff` review → `.pipeline/review.md` with `VERDICT: SHIP / NEEDS WORK / BLOCK`. |

`/ship` orchestrates the four in order, confirming each handoff file exists before the next stage, pausing on open questions or test failures, and **never merging** — it leaves the branch for your review. Opus handles the reasoning-heavy plan/review stages; Sonnet handles the bulk code/test work (~30/70 spend split).

```
/ship add rate limiting to the login endpoint
/ship build a user settings page with email notification preferences
```

Source lives in `ship-pipeline/`. The agents and command are installed automatically by `install.sh` (no separate step).

## The /dev Continuous Loop

`/dev "<idea>"` runs the whole chain end-to-end and keeps going across a multi-phase roadmap, so you don't hand-walk each stage. It wraps **project-time → brainstorming-time → writing-plans-time → executing-plan-time** in one resumable command:

1. Builds the roadmap once (project-time), seeding a project-local `.dev/memory/` layer (`goals.md`, `decisions.md`, `lessons.md`, `glossary.md`, `progress.md`).
2. For each phase: brainstorm + plan **interactively** (it asks you), then dispatches a **phase-executor** subagent that runs `executing-plan-time` unattended in its own context window.
3. Auto-advances to the next phase. Every decision — interactive, auto, and escalated — is logged to `.dev/memory/decisions.md` for review.

Each phase executes in a fresh subagent, so the main session stays lean; the loop is **resumable** from `.dev/memory/progress.md` if a session ends. Irreversible forks pause and escalate to you; reversible ones are auto-decided and logged.

Source lives in `dev-pipeline/` (a `/dev` command + four agents + a shared `memory-protocol.md`), installed automatically by `install.sh`.

**Two doors:** use `/ship` for a single feature in one sitting (no roadmap, no worktree); use `/dev` (or run the chain by hand) for anything larger — multiple phases, parallel waves, per-task two-stage review.

## Ponytail

[ponytail](https://github.com/DietrichGebert/ponytail) is a "lazy senior dev" plugin that enforces minimal, necessary code (YAGNI, stdlib first, one line over fifty). `install.sh` installs and enables it via the Claude Code plugin CLI (`claude plugin marketplace add DietrichGebert/ponytail` + `claude plugin install ponytail@ponytail`) — it is **not** vendored, so ponytail manages its own skills, commands, hooks, and updates (`claude plugin update ponytail`).

- It activates at mode **`full`** by default. Adjust at runtime with `/ponytail lite|full|ultra|off`; audit with `/ponytail-review` and `/ponytail-audit`.
- Its hooks require **`node`**. If `node` is missing at install time, the plugin still installs but its hooks no-op until node is available.
- If the `claude` CLI is not found at install time, `install.sh` skips ponytail and reports it; the rest of the install proceeds.
- The coding skills (`executing-plan-time`, the ship `coder`/`reviewer`) reference ponytail's minimal-code ladder by default, so dispatched subagents apply it even if they don't inherit the global session hook.

## Install

Clone the repo and run the install script:

```bash
git clone https://github.com/<you>/oroskills.git ~/oroskills
cd ~/oroskills
./install.sh
```

Options:

```
./install.sh              # symlink into ~/.claude/skills (global)
./install.sh --project    # symlink into ./.claude/skills (project-scoped)
./install.sh --copy       # copy files instead of symlinking
./install.sh --force      # overwrite existing skills with the same name
```

Verify:

```bash
ls ~/.claude/skills/
# brainstorming-time  caveman  executing-plan-time  project-time  writing-plans-time
ls ~/.claude/agents/
# code-quality-reviewer.md  coder.md  implementer.md  phase-executor.md
# planner.md  reviewer.md  spec-reviewer.md  tester.md
ls ~/.claude/commands/
# dev.md  ship.md
```

Restart Claude Code (or start a new session) and the skills, agents, and the `/ship` + `/dev` commands will appear.

### Project-scoped install

To install for a single project instead of globally, use `<project>/.claude/skills/` in place of `~/.claude/skills/`.

## Requirements

- **graphify** — all three skills use `graphify query` as their primary source for codebase context. Install graphify and run `/graphify` once per repo; the skills will offer to initialize it if `graphify-out/graph.json` is missing.
- **git** — `executing-plan-time` always runs work inside a git worktree.
- **ponytail** (optional but recommended) — installed automatically by `install.sh` when the `claude` CLI is present; requires `node` for its hooks. See the Ponytail section above.

## Usage

The skills auto-trigger from their descriptions, but you can invoke them explicitly:

```
Use project-time to scope out <project idea>.
Use brainstorming-time to spec out <idea or milestone Mn>.
Use writing-plans-time on <spec file>.
Use executing-plan-time to run <plan file>.
```

The intended chain is **project-time → brainstorming-time → writing-plans-time → executing-plan-time**. `project-time` is optional and only used at the start of a new project or large initiative; for a single feature inside an existing codebase, start at `brainstorming-time`. Each stage hands off to the next; don't skip stages.

## Layout

```
project-time/
  SKILL.md
brainstorming-time/
  SKILL.md
writing-plans-time/
  SKILL.md
  plan-template.md
executing-plan-time/
  SKILL.md
caveman/
  SKILL.md
  caveman-hook.sh
ship-pipeline/
  agents/
    planner.md
    coder.md
    tester.md
    reviewer.md
  commands/
    ship.md
dev-pipeline/
  agents/
    implementer.md
    spec-reviewer.md
    code-quality-reviewer.md
    phase-executor.md
  commands/
    dev.md
  memory-protocol.md
tests/dev/
  check_memory_protocol.sh
  check_agents.sh
  check_dev_command.sh
  check_install.sh
```
