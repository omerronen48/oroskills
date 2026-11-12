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

What it installs: skills → `~/.claude/skills/`, `oro-*` pipeline agents → `~/.claude/agents/`, the `/ship` `/fix` `/dev` `/loop-manager` `/loop-worker` `/address-review` commands → `~/.claude/commands/`, the caveman + statusline session hooks, and the ponytail plugin. Project install swaps `~/.claude/` for `<project>/.claude/`.

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
| **brainstorming-time** | Idea (or one milestone) → reviewable spec. Graphify context, then a mind map + written spec approved in one gate. |
| **writing-plans-time** | Approved spec → plan with a File Edit Manifest and tasks grouped into parallel waves. |
| **executing-plan-time** | Approved plan → code. Worktree, parallel waves, tests-first TDD, per-task review, PR, post-PR verification. |
| **caveman** | Compressed comms mode (~75% fewer tokens, full accuracy). Trigger "caveman mode" / `/caveman`, or on by default. From [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md). |

- **The chain:** project-time → brainstorming-time → writing-plans-time → executing-plan-time. Don't skip stages; each hands off to the next.
- Non-trivial specs get an optional Goldfish review (`egm:egm-synthesizer`, egm plugin) in `brainstorming-time` before the user gate; skipped if egm is not installed.
- `project-time` is optional — only for a new project/large initiative. Single feature in an existing repo: start at `brainstorming-time`.
- Auto-trigger from their descriptions, or invoke explicitly (`Use writing-plans-time on <spec file>.`).

## Pipelines

### Which door?

| Situation | Door | Discipline you get |
|---|---|---|
| Trivial edit (rename, typo, one-liner) | none — just ask | judgment |
| Single bug | `/fix` | repro-test-first, stacked branch, full-suite regression guard |
| Punch-list of small fixes/chores | `/fix` | branch per fix, regression guard after each |
| One small self-contained feature | `/ship` | planner→tester→coder→reviewer on a `ship/<slug>` branch (fast lane: tests-first, no worktree) |
| Feature worth a spec + plan | chain: `brainstorming-time` → `writing-plans-time` → `executing-plan-time` | worktree, parallel waves, TDD-before-commit, per-task review |
| New project / multi-feature roadmap | `project-time`, then `/dev` | roadmap loop; `--auto` for unattended runs |
| Autonomous issue-driven runs | `/loop-manager` + `/loop-worker` | triage labels, worktree, PR-only |
| Open PR has red CI / review comments | `/address-review` | punch list from checks+comments, fix on the PR branch, push |

Every door stops before merge — a human merges, always.

### `/ship` — single feature, one sitting

`/ship <feature request>` runs four subagents over a shared `.pipeline/` folder:

| Agent | Model | Stage |
|---|---|---|
| **oro-planner** | opus | Request → `.pipeline/spec.md` (paths, signatures, edge cases; flags `OPEN QUESTION`) |
| **oro-tester** | sonnet | Writes the acceptance tests **before the code**, shows them red → `.pipeline/test-results.md`; they are then hash-locked. |
| **oro-coder** | sonnet | Makes the locked tests pass → `.pipeline/changes.md`. No scope creep, never edits tests. |
| **oro-reviewer** | opus | Read-only `git diff` review → `VERDICT: SHIP / NEEDS WORK / BLOCK` |

- Runs in order, pausing on open questions or test failures, **never merges** — leaves the branch for review.
- ⚠️ Deliberate fast lane: **no worktree, no graphify** — but tests are written first and locked. For multi-phase work use `/dev`.

### `/fix` — bugs + batches of small fixes

`/fix <bug or blurb of small changes>` decomposes the blurb into an ordered mini-roadmap (`.fix/roadmap.md`), then ships each fix **lean**: `oro-tester` (failing test first) → `oro-coder` (no planner; roadmap entry is the spec), with one `oro-reviewer` pass at the end.

- **Regression guard:** full test suite runs after every fix, so a later fix can't silently break an earlier one (a single fix is not re-run at the end).
- **Single-bug mode:** a blurb that is one bug runs the loop once with repro-first discipline — failing test → fix → pass; no critic, no roadmap gate.
- Each fix lands on its own stacked branch (`fix/N-<slug>`). Any red **halts** the loop; nothing merges.

### `/address-review` — post-PR feedback

`/address-review [PR]` picks up where every other door stops. It pulls failing CI checks (`gh pr checks` + failed-run logs), unresolved review comments, and merge conflicts into a punch list (`.review/feedback.md`), fixes each on the PR branch via `oro-coder` (one commit per item; `oro-tester` strengthens the tests when `mutate-check.sh` shows a behavior change is unpinned), runs one `oro-reviewer` pass over the session diff, and pushes.

- Ambiguous review comments are parked `needs-owner-input` — it never guesses a reviewer's intent.
- Plain push only; force-push (after a conflict rebase) requires explicit confirmation. Never merges, never resolves threads.
- Re-invoking skips items already `done`.

### `/dev` — continuous chain loop

`/dev "<idea>"` wraps the full chain across a multi-phase roadmap in one resumable command:

1. Builds the roadmap once (project-time), seeding `.dev/memory/` (`goals.md`, `decisions.md`, `lessons.md`, `glossary.md`, `progress.md`).
2. Per phase: brainstorm + plan interactively, then dispatch an **oro-phase-executor** subagent that runs `executing-plan-time` unattended.
3. Auto-advances, logging decisions to `.dev/memory/decisions.md`. Resumable from `progress.md`.

Flags:

| Flag | Effect |
|---|---|
| `--auto` | Unattended: decide from roadmap + memory instead of asking. Reversible forks auto-decide (`[auto]`); irreversible ones **park** to `escalations.md`, mark the phase `blocked`, and **halt**. Never merges. |
| `--climb` | Force the final hill-climb on a small diff (also `/ship`, `/fix`). |
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
| **`/loop-worker`** | Takes one `agent:ready` + `risk:low` issue, isolates it in a worktree, drives `/ship`, and on `VERDICT: SHIP` opens a PR + comments the link. Non-SHIP → `needs:human`. | `--dry-run`, `--headless`, `--repo <owner/repo>` |

- The Manager delegates per-issue classification to **oro-triager**, a read-only agent with no write access.
- **Labels:** `risk:{low,medium,high}` · `type:{bug,feature,docs,test,refactor,chore}` · `agent:ready` · `needs:human` · `agent:in-progress`.
- **Safety:** run via `/schedule` routines (see `pipelines/loop-pipeline/RUNBOOK.md`). `loop-settings.json` **denies `gh pr merge`** as a hard stop. Honest limit: routines can't carry per-routine permission scopes today, so isolation rests on the read-only classifier + human PR review, not a hard sandbox.

`--auto` runs are guarded by a **dead-man's switch**: a cron-invoked `~/.claude/dev-resume-guard.sh` relaunches a run that died mid-roadmap (usage limit, crash) once the exhausted window resets — the weekly limit takes precedence over the 5-hour one (reset times from the statusline's `oro-usage.json` snapshot). Armed at `--auto` start, disarmed on every orderly ending; `progress.md` makes relaunches idempotent.

## Loop kernel

Every pipeline (`/dev`, `/ship`, `/fix`, `/loop-worker`) runs on one shared loop contract, `skills/loop-kernel`:

- **Objective:** `.loop/goal.md` holds the end state, done-criteria as commands, and a rubric. It is frozen once coding starts.
- **Metric:** per `/dev` task only test-guard plus the task's own tests run; otherwise one command, `factory-check.sh`, runs the project's `.factory/checks`, the goal's done-criteria and `test-guard.sh` (which fails on new skips/xfails, deleted assertions, a drop in test count, test edits outside the manifest, or removed factory checks). Every failure ends in a `→ fix:` line: the error is the prompt.
- **Verifier:** reviewers are fresh and blind. They see the goal and the diff, never the author's report.
- **Optimizer:** 3 attempts per task, then escalate. UI diffs, diffs of 50+ lines and `--climb` runs end with a hill-climb: 3 blind `oro-judge`s, at most 2 rounds, stop at 8.5 or when the gain is below 0.5, keep the best result. Small non-UI diffs skip it (no judges).
- **Durability:** when a run produced findings or corrections (clean runs skip it), `oro-distiller` writes `.dev/memory/lessons.md` with a `seen` counter. A pattern seen twice becomes a proposed skill diff in `.loop/proposals/`, which you approve; a `[reward-hack]` finding becomes a proposal on its first occurrence.
- **Integrity:** tests are written before the code by a different agent (in `/dev` the tests come from the plan and `oro-tester` commits them before the implementer runs), then hash-locked. A PreToolUse hook (matcher `Edit|Write|NotebookEdit`) blocks edits to locked tests and the frozen goal; `test-guard.sh` catches edits made any other way; `mutate-check.sh` proves the tests actually exercise the change (run for non-small or risky diffs). When a test is wrong, the only allowed route is a `TEST-DISPUTE:` that someone else rules on.
- **Pre-code critic:** `oro-critic` checks the goal and spec for gaps before any code is written — in `/ship` and `--auto` runs; skipped for single-bug `/fix` and for `/dev` plans a human already approved.
- **Unattended runs:** a Stop hook keeps `/dev --auto` and `/loop-worker` sessions going until the done-criteria pass (it gives up after 3 blocks).
- **Factory files:** each project gets committed `.factory/checks` (commands that must pass on every change), `.factory/run.md` (launch, logs, smoke, browser via `agent-browser`) and a pre-push hook, created on first run by `/dev`, `/ship` or `/fix`.
- **Outer loop (pre-push):** the hook (`pre-push-hook.sh`) runs `factory-check.sh` on every push — deterministic, no API key, no CI; `executing-plan-time` does not repeat those checks after the push. `mutate-check.sh` stays in-session (kernel §2).
- **Severity:** review findings are tagged `[P0]`–`[P3]`; only P0–P2 (and reward hacks) trigger a retry. A coder may `REJECT:` a P2 with a reason; the next blind reviewer drops or re-raises it.
- **Self-improvement (automatic):** at the end of any run with findings, the distiller reads that run's findings, the run history (`.dev/memory/history.jsonl`, one line per run) and human PR comments recorded by `/address-review` (`.dev/memory/human-feedback.md`); `lessons-for.sh` feeds the resulting lessons to the next coder. Nothing needs to be run by hand.
- **Headless:** `/loop-worker --headless` never asks and ends with `LOOP-WORKER: <issue|none> <SHIP|needs:human|no-eligible>`; schedule `/loop-manager` + `/loop-worker --headless` as a `/schedule` routine.

`.loop/` lives in your project and should be git-ignored.

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
  loop-kernel/         SKILL.md  goal-template.md  factory-checks-template  factory-run-template.md
                       factory-check.sh  test-guard.sh  mutate-check.sh  lessons-for.sh
                       guard-edits.sh  goal-stop.sh  pre-push-hook.sh      # hooks
pipelines/                # agents install namespaced (oro-*) to avoid collisions
  ship-pipeline/
    agents/    oro-planner.md  oro-coder.md  oro-tester.md  oro-reviewer.md
    commands/  ship.md
  fix-pipeline/
    commands/  fix.md          # reuses ship-pipeline's oro-coder/tester/reviewer
  review-pipeline/
    commands/  address-review.md  # post-PR lane; reuses ship-pipeline's agents
  dev-pipeline/
    agents/    oro-implementer.md  oro-task-reviewer.md  oro-phase-executor.md
               oro-critic.md  oro-judge.md  oro-distiller.md   # loop-kernel agents
    commands/  dev.md
    memory-protocol.md  RUNBOOK-autonomous-dev.md  dev-resume-guard.sh
  loop-pipeline/
    agents/    oro-triager.md
    commands/  loop-manager.md  loop-worker.md
    RUNBOOK.md  loop-settings.json
tests/                    # script behavior tests run by .factory/checks (dev/, loop/)
statusline-command.sh     # emoji bar with the caveman chip
install.sh
LICENSE                   # MIT
.factory/                 # this repo's own checks + run.md (loop-kernel §0)
```

`tests/` are behavior tests, run by `.factory/checks`: each executes a real script (sandbox install, resume guard, test-guard, factory-check, mutate-check, pre-push hook, guard-edits, goal-stop, lessons-for). Nothing pins the prose of skills, agents or commands, and nothing tests agent behavior.
