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

The installer places skills in `~/.claude/skills/`, the pipeline agents (including `oro-triager`) in `~/.claude/agents/`, the `/ship`, `/dev`, `/loop-manager`, and `/loop-worker` commands in `~/.claude/commands/`, registers the caveman session hook, and installs the ponytail plugin. For a project-scoped install, swap `~/.claude/` for `<project>/.claude/`.

Verify, then restart Claude Code (or start a new session):

```bash
ls ~/.claude/skills/    # brainstorming-time caveman executing-plan-time project-time writing-plans-time
ls ~/.claude/commands/  # dev.md loop-manager.md loop-worker.md ship.md
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
| **oro-planner** | opus | Feature request → `.pipeline/spec.md` (exact paths, signatures, edge cases). Flags ambiguity as `OPEN QUESTION`. |
| **oro-coder** | sonnet | Implements the spec exactly → `.pipeline/changes.md`. No scope creep. |
| **oro-tester** | sonnet | Writes/runs tests → `.pipeline/test-results.md`. On failure it **stops** rather than patching the code. |
| **oro-reviewer** | opus | Read-only `git diff` review → `.pipeline/review.md` with `VERDICT: SHIP / NEEDS WORK / BLOCK`. |

`/ship` orchestrates the four in order, confirming each handoff file exists before the next stage, pausing on open questions or test failures, and **never merging** — it leaves the branch for your review. (Opus on the reasoning-heavy plan/review stages, Sonnet on the bulk code/test work.)

> ⚠️ **`/ship` is a deliberate fast lane and does NOT enforce the TDD-before-commit contract.** Tests are written *after* the code, there is no git worktree, and no graphify context — the opposite of what the `/dev` chain treats as hard gates. Use `/ship` only when that trade is acceptable; for the full discipline (TDD-first, worktree isolation, graph-driven parallelism, two-stage review) use `/dev` or run the chain.

```
/ship add rate limiting to the login endpoint
```

### `/dev` — continuous chain loop

`/dev "<idea>"` wraps **project-time → brainstorming-time → writing-plans-time → executing-plan-time** in one resumable command that runs across a multi-phase roadmap:

1. Builds the roadmap once (project-time), seeding a project-local `.dev/memory/` layer (`goals.md`, `decisions.md`, `lessons.md`, `glossary.md`, `progress.md`).
2. For each phase: brainstorm + plan **interactively** (it asks you), then dispatches an **oro-phase-executor** subagent that runs `executing-plan-time` unattended in its own context window.
3. Auto-advances to the next phase, logging every decision to `.dev/memory/decisions.md`.

Each phase runs in a fresh subagent so the main session stays lean; the loop is **resumable** from `.dev/memory/progress.md`. Irreversible forks pause and escalate to you; reversible ones are auto-decided and logged.

**Unattended runs (`--auto`).** `/dev --auto` runs the whole chain across the roadmap without
stopping at a human gate: brainstorming and planning decide from the roadmap + `.dev/memory/`
and self-review instead of asking, reversible forks auto-decide (logged `[auto]`), and
irreversible forks are **parked** to `.dev/memory/escalations.md` with the phase marked
`blocked` — the loop then **halts** so nothing builds on an unresolved decision. It never
merges. Resolve the parked fork, clear `blocked`, and re-run to resume. Plain `/dev` (no flag)
keeps the interactive gates — that's your per-phase checkpoint mode, no extra setup.

**Scheduling.** Run it on a timer locally (it needs the real repo, worktrees, graphify, and
test runner): a cron line firing `claude -p '/dev --auto'`, or the `/loop` skill /
ScheduleWakeup in-session. Reuse the loop-pipeline's `loop-settings.json` deny-merge template
as the hard no-merge backstop. Full operator steps — preflight, scheduling, recovering from a
halt — are in `pipelines/dev-pipeline/RUNBOOK-autonomous-dev.md`.

### `/loop-manager` + `/loop-worker` — autonomous loop pipeline

Two autonomous agent loops that auto-develop a repo through a **GitHub Issues control plane**: a Manager loop triages the backlog and a Worker loop turns safe issues into PRs. Neither ever merges — **human merge is the gate**. Inspired by the loop-engineering pattern.

| Command | Stage |
|---|---|
| **`/loop-manager`** | Triages open issues: classifies risk (`risk:low\|medium\|high`) and type, applies `agent:ready` / `needs:human`, and posts an *Agent Assessment* comment. Labels and comments only — **never** writes code, opens a PR, or merges. Apply mode by default; `--dry-run` previews; `--retriage` refreshes existing triage. |
| **`/loop-worker`** | Takes one `agent:ready` + `risk:low` issue, isolates it in a worktree, drives the `/ship` pipeline, and on `VERDICT: SHIP` opens a PR and comments the link. Any non-SHIP outcome routes the issue to `needs:human`. Never merges. |

The Manager delegates per-issue classification to **oro-triager**, a read-only agent that does the actual risk/type call without any write access.

**Label taxonomy:** `risk:low\|medium\|high` · `type:{bug,feature,docs,test,refactor,chore}` · `agent:ready` · `needs:human` · `agent:in-progress`.

**Scheduling & safety.** Run the loops unattended via Claude Code `/schedule` routines — see `pipelines/loop-pipeline/RUNBOOK.md`. A `.claude/settings.json` permission template (`pipelines/loop-pipeline/loop-settings.json`) **denies `gh pr merge`** as the enforceable hard stop, so even a misbehaving loop cannot merge. Honest limitation: Claude Code routines can't carry per-routine permission scopes today, so per-loop tool isolation rests on the read-only classifier, the command prose, and human PR review rather than a hard sandbox; routines themselves are a research preview.

## Requirements

### graphify (the headline dependency — read this)

The skills are **graphify-first**: they query a knowledge graph of your codebase (`graphify query`) instead of reading files one at a time, and `executing-plan-time` uses graphify's call-graph to decide which tasks are safe to run in parallel. graphify is a separate tool — the [`graphifyy`](https://pypi.org/project/graphifyy/) Python package plus a `/graphify` Claude Code skill that builds and queries the graph:

```bash
uv tool install graphifyy          # or: pip install graphifyy
# optional extras: pip install 'graphifyy[gemini]'  (Gemini extraction)  ·  'graphifyy[video]'
```

Run `/graphify` once per repo to build `graphify-out/graph.json`; the skills offer to initialize it if it's missing, and `graphify --update` refreshes it after changes.

**Degraded mode (be honest with yourself):** without graphify, every skill falls back to `Read`/`Grep`. They still work, but you lose the graph-driven context and — importantly — `executing-plan-time` can no longer verify function/call-graph disjointness, so it drops to file-level checks and serializes. In that mode these are essentially reworded `superpowers:*` skills; graphify is what makes them different.

### Other

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
pipelines/                # agents install namespaced (oro-*) to avoid collisions
  ship-pipeline/
    agents/    oro-planner.md  oro-coder.md  oro-tester.md  oro-reviewer.md
    commands/  ship.md
  dev-pipeline/
    agents/    oro-implementer.md  oro-spec-reviewer.md  oro-code-quality-reviewer.md  oro-phase-executor.md
    commands/  dev.md
    memory-protocol.md
  loop-pipeline/
    agents/    oro-triager.md
    commands/  loop-manager.md  loop-worker.md
    RUNBOOK.md  loop-settings.json
tests/dev/                # install-wiring smoke tests (see note below)
  check_install.sh  check_agents.sh  check_dev_command.sh  check_memory_protocol.sh
statusline-command.sh     # emoji-labelled bar with the caveman chip
install.sh
LICENSE                   # MIT
```

The `tests/dev/` scripts are **install-wiring smoke tests** — they verify agents/commands are present, named, and referenced correctly, and that `install.sh` parses. They do **not** test skill behavior; passing them is not evidence the skills produce good specs/plans/code.
