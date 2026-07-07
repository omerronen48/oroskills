# Autonomous `/dev` — Operator Runbook

`/dev --auto` runs the brainstorm→plan→execute chain across a roadmap unattended. It never
waits at a human gate, parks irreversible forks, and never merges. Use this runbook to run it
on a schedule and to recover when it halts.

## Prerequisites

- Repo is a git repository with a seeded `progress.md` (run `/dev --import <roadmap>` once, or
  let a prior `/dev` seed it).
- `gh` authenticated if the executor's finishing step opens PRs.
- The deny-merge template `pipelines/loop-pipeline/loop-settings.json` merged into the repo's
  `.claude/settings.json`, so an unattended run can never `gh pr merge`.

## Preflight (before leaving it unattended)

1. Confirm `progress.md` lists the phases you expect, with the right ones already `done`.
2. Run **one** `/dev --auto` pass while watching it. Review the produced spec + plan and the
   `[auto]` entries in `.dev/memory/decisions.md` — do you trust the auto-decisions? Only
   schedule once you do.
3. Confirm no phase is unexpectedly `blocked`.

## Scheduling (local)

`/dev` needs the local repo, worktrees, graphify, and the test runner, so schedule it on the
machine that has them.

- **cron** (machine on, e.g. overnight):
  ```bash
  0 2 * * *  cd /path/to/repo && claude -p '/dev --auto' >> .dev/auto.log 2>&1
  ```
- **`/loop` skill or ScheduleWakeup** — for an in-session self-paced cadence while you have
  Claude Code open.

## Auto-resume (dead-man's switch)

`/dev --auto` arms a switch at start — `.dev/auto-resume` marker, claude pid in `.dev/auto.lock`,
repo path in `~/.claude/dev-auto-repos`, and a `*/15 min` crontab entry running
`~/.claude/dev-resume-guard.sh` — and disarms it on every orderly ending. If the run dies
mid-flight (usage limit, crash) the switch stays armed and the guard relaunches
`claude -p '/dev --auto'` once usage allows: an exhausted window blocks until *its* reset, the
weekly window checked before the 5-hour one. Usage comes from `~/.claude/oro-usage.json`
(written by the statusline bridge); with no snapshot the guard just tries — a limited headless
run fails fast and the next tick retries. `progress.md` makes relaunches idempotent.

- Status: `crontab -l | grep dev-resume-guard` · `cat ~/.claude/dev-auto-repos`
- Disable one repo: `rm -f <repo>/.dev/auto-resume` · all: remove the crontab line
- Ceiling (ponytail): run-liveness keys on the claude pid captured at bootstrap; a bad pid read
  means at worst one duplicate relaunch, which worktree isolation keeps from corrupting state.

## Recovering from a halt (parked escalation)

When the loop halts, a phase is `blocked` and the fork is recorded in `.dev/memory/escalations.md`.

1. Read `.dev/memory/escalations.md` — it names the phase, the question, and the options.
2. Decide. Record the resolution in `.dev/memory/decisions.md` tagged `[escalated]`.
3. Clear the phase's `blocked` status in `progress.md` (back to `pending`).
4. Re-run `/dev --auto` — it resumes at the first non-`done` phase.

## Audit trail

- `.dev/memory/decisions.md` — every `[auto]` and `[escalated]` decision.
- `.dev/memory/escalations.md` — every parked fork.
- Per-phase branches/PRs — the executor's output. All merges are human-initiated.

## Limitations

- Autonomous brainstorming self-approves specs: review the audit trail before trusting a long
  unattended run. The no-merge gate is your backstop — nothing reaches `main` without you.
- Cloud `/schedule` routines are possible but the cloud env must clone the repo and provide
  graphify + the test runner (same research-preview caveat as the loop-pipeline). Local
  scheduling is the supported default.
- Quota interruptions are not caught mid-run: a run that hits the usage limit dies where it
  stands. The resume guard (below) relaunches it once the exhausted window resets.
