# oroskills

Claude Code skills for **project idea → roadmap → spec → plan → executed code**. Graphify-first, parallelization-aware, TDD-enforced.

## Installation

```bash
git clone https://github.com/omerronen48/oroskills.git ~/oroskills
cd ~/oroskills && ./install.sh
```

Flags:

| Flag | Effect |
|---|---|
| _(none)_ | Symlink into `~/.claude/` (global) |
| `--project` | Symlink into `./.claude/` (project-scoped) |
| `--copy` | Copy files instead of symlinking |
| `--force` | Overwrite same-named skills/agents (and an existing statusline) |
| `--refresh` | Re-link new files + re-copy hook scripts (skips statusline); used by the post-merge hook |

What it installs: skills → `~/.claude/skills/`, `oro-*` pipeline agents → `~/.claude/agents/`, the `/ship` `/fix` `/dev` `/loop-manager` `/loop-worker` commands → `~/.claude/commands/`, the caveman + statusline session hooks, and the ponytail plugin. Project install swaps `~/.claude/` for `<project>/.claude/`.

- **Changes apply live** — symlinked files take effect with no reinstall. A `post-merge` git hook re-runs `install.sh --refresh` on every `git pull` to wire newly-added files (skips statusline; won't clobber a non-oroskills hook).
- Verify: `ls ~/.claude/skills/` and `ls ~/.claude/commands/`, then restart Claude Code.

### Caveman mode (on by default)

- A `SessionStart` hook turns caveman mode on each session — compressed replies, full technical accuracy.
- Say "stop caveman" / "normal mode" to drop it for a session.
- The hook script is **copied** to `~/.claude/caveman-hook.sh`, so moving/deleting the repo won't break it. Idempotent; remove via the `SessionStart` entry in `settings.json`.

### Statusline

Emoji bar installed and wired into `settings.json`:

```
📁 ~/project  🌿 main · 🤖 Opus 4.8 · 🦴 caveman · 🧠 42% ctx · ⏳ 18% 5h · 📅 63% 7d · 💰 $4.05 · 🕐 07:11
```

- `caveman-state.sh` drives the caveman chip (`🦴` on / `💤` off), tracked per session.
- **Never clobbered:** an existing statusline is left alone; you get `skills/caveman/statusline-snippet.sh` to paste the chip yourself. `--force` replaces it.

### Ponytail

[ponytail](https://github.com/DietrichGebert/ponytail) — a "lazy senior dev" plugin enforcing minimal code (YAGNI, stdlib first). Installed via the Claude Code plugin CLI (not vendored; self-updates with `claude plugin update ponytail`).

- Activates at mode `full`; adjust with `/ponytail lite|full|ultra|off`, audit with `/ponytail-review` / `/ponytail-audit`.
- The coding skills reference ponytail's ladder, so subagents apply it even without the session hook.

## Skills

| Skill | What it does |
|---|---|
| **project-time** | Project idea → technical roadmap with milestones. One-question-at-a-time interview; locks architecture/stack/scope/non-functionals up front. |
| **brainstorming-time** | Idea (or one milestone) → reviewable spec. Graphify context + a mind map before the written spec. |
| **writing-plans-time** | Approved spec → plan with a File Edit Manifest and tasks grouped into parallel waves. |
| **executing-plan-time** | Approved plan → code. Worktree, parallel implementer subagents, TDD-before-commit, spec + code-quality review, branch finishing. |
| **caveman** | Compressed comms mode (~75% fewer tokens, full accuracy). Trigger "caveman mode" / `/caveman`, or on by default. From [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md). |

- **The chain:** project-time → brainstorming-time → writing-plans-time → executing-plan-time. Don't skip stages; each hands off to the next.
- `project-time` is optional — only for a new project/large initiative. Single feature in an existing repo: start at `brainstorming-time`.
- Auto-trigger from their descriptions, or invoke explicitly (`Use writing-plans-time on <spec file>.`).

## Pipelines

**Three doors** by size: `/ship` (one feature) · `/fix` (punch-list of small fixes) · `/dev` (multi-phase roadmap).

### `/ship` — single feature, one sitting

`/ship <feature request>` runs four subagents over a shared `.pipeline/` folder:

| Agent | Model | Stage |
|---|---|---|
| **oro-planner** | opus | Request → `.pipeline/spec.md` (paths, signatures, edge cases; flags `OPEN QUESTION`) |
| **oro-coder** | sonnet | Implements spec → `.pipeline/changes.md`. No scope creep. |
| **oro-tester** | sonnet | Writes/runs tests → `.pipeline/test-results.md`. **Stops** on failure, doesn't patch. |
| **oro-reviewer** | opus | Read-only `git diff` review → `VERDICT: SHIP / NEEDS WORK / BLOCK` |

- Runs in order, pausing on open questions or test failures, **never merges** — leaves the branch for review.
- ⚠️ Deliberate fast lane: **no TDD-before-commit, no worktree, no graphify.** For the full discipline use `/dev`.

### `/fix` — batch of small fixes

`/fix <blurb of small changes>` decomposes the blurb into an ordered mini-roadmap (`.fix/roadmap.md`), then ships each fix **lean**: `oro-coder` → `oro-tester` (no planner; roadmap entry is the spec), with one `oro-reviewer` pass at the end.

- **Regression guard:** full test suite runs after every fix, so a later fix can't silently break an earlier one.
- Each fix lands on its own stacked branch (`fix/N-<slug>`). Any red **halts** the loop; nothing merges.

### `/dev` — continuous chain loop

`/dev "<idea>"` wraps the full chain across a multi-phase roadmap in one resumable command:

1. Builds the roadmap once (project-time), seeding `.dev/memory/` (`goals.md`, `decisions.md`, `lessons.md`, `glossary.md`, `progress.md`).
2. Per phase: brainstorm + plan interactively, then dispatch an **oro-phase-executor** subagent that runs `executing-plan-time` unattended.
3. Auto-advances, logging decisions to `.dev/memory/decisions.md`. Resumable from `progress.md`.

Flags:

| Flag | Effect |
|---|---|
| `--auto` | Unattended: decide from roadmap + memory instead of asking. Reversible forks auto-decide (`[auto]`); irreversible ones **park** to `escalations.md`, mark the phase `blocked`, and **halt**. Never merges. |
| `--design <ref>` | Resolve a design source at bootstrap → `.dev/memory/design.md`. `<ref>` is a DesignSync UUID or a mockups folder path. |
| `--import <path>` | Seed the roadmap from an existing markdown roadmap file instead of interviewing. |
| `--force` | With `--import`: overwrite existing roadmap phases. |

- Plain `/dev` keeps interactive per-phase gates.
- **Scheduling:** run locally on a timer (needs the real repo/worktrees/graphify/tests) — a cron line firing `claude -p '/dev --auto'`, or `/loop` / ScheduleWakeup in-session. Reuse `loop-settings.json` as the no-merge backstop. Operator steps: `pipelines/dev-pipeline/RUNBOOK-autonomous-dev.md`.

### `/loop-manager` + `/loop-worker` — autonomous loop pipeline

Two agent loops that auto-develop a repo through a **GitHub Issues control plane**. Neither ever merges — **human merge is the gate**.

| Command | Stage | Flags |
|---|---|---|
| **`/loop-manager`** | Triages open issues: risk + type labels, `agent:ready` / `needs:human`, posts an *Agent Assessment* comment. Labels/comments only — never codes, PRs, or merges. | `--dry-run`, `--retriage`, `--repo <owner/repo>` |
| **`/loop-worker`** | Takes one `agent:ready` + `risk:low` issue, isolates it in a worktree, drives `/ship`, and on `VERDICT: SHIP` opens a PR + comments the link. Non-SHIP → `needs:human`. | `--dry-run`, `--repo <owner/repo>` |

- The Manager delegates per-issue classification to **oro-triager**, a read-only agent with no write access.
- **Labels:** `risk:{low,medium,high}` · `type:{bug,feature,docs,test,refactor,chore}` · `agent:ready` · `needs:human` · `agent:in-progress`.
- **Safety:** run via `/schedule` routines (see `pipelines/loop-pipeline/RUNBOOK.md`). `loop-settings.json` **denies `gh pr merge`** as a hard stop. Honest limit: routines can't carry per-routine permission scopes today, so isolation rests on the read-only classifier + human PR review, not a hard sandbox.

## Requirements

### graphify (the headline dependency)

Skills are **graphify-first**: they query a codebase knowledge graph (`graphify query`) instead of reading files one at a time, and `executing-plan-time` uses the call-graph to pick parallel-safe tasks. It's a separate tool — the [`graphifyy`](https://pypi.org/project/graphifyy/) package + a `/graphify` skill:

```bash
uv tool install graphifyy          # or: pip install graphifyy
# extras: pip install 'graphifyy[gemini]'  ·  'graphifyy[video]'
```

Run `/graphify` once per repo to build `graphify-out/graph.json`; skills offer to init it if missing; `graphify --update` refreshes it.

- **Degraded mode (without graphify):** every skill falls back to `Read`/`Grep`. Still works, but `executing-plan-time` can't verify call-graph disjointness so it drops to file-level checks and serializes.

### Other

- **git** — `executing-plan-time` always works inside a worktree.
- **jq** — merges the caveman hook into `settings.json`; if missing, the hook is skipped and reported.
- **node** — ponytail's hooks; if missing they no-op until node is available.
- **claude CLI** — required to install ponytail; if missing, ponytail is skipped and the rest proceeds.

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
  fix-pipeline/
    commands/  fix.md          # reuses ship-pipeline's oro-coder/tester/reviewer
  dev-pipeline/
    agents/    oro-implementer.md  oro-spec-reviewer.md  oro-code-quality-reviewer.md  oro-phase-executor.md
    commands/  dev.md
    memory-protocol.md  RUNBOOK-autonomous-dev.md
  loop-pipeline/
    agents/    oro-triager.md
    commands/  loop-manager.md  loop-worker.md
    RUNBOOK.md  loop-settings.json
tests/                    # install-wiring smoke tests (dev/, fix/, loop/)
statusline-command.sh     # emoji bar with the caveman chip
install.sh
LICENSE                   # MIT
```

`tests/` are **install-wiring smoke tests** — they verify agents/commands are present, named, and referenced correctly, and that `install.sh` parses. They do **not** test skill behavior.
