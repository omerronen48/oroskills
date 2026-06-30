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

## Usage-window guard

`/dev --auto` reads `~/.claude/oro-usage.json` at each phase boundary to check quota usage.
That file is written by the statusline bridge embedded in `statusline-command.sh`, which
means **the statusline must be installed and active** for the live-% path to work.

- **Interactive limitation:** `~/.claude/oro-usage.json` is only refreshed when the statusline
  renders (i.e. in an active Claude Code session). In a headless run started by `at`/cron
  there is no statusline, so the guard falls back to `.dev/memory/usage.md` `window_start`
  and estimates elapsed time. This estimate is conservative; it will not catch quota spikes
  mid-window.
- **Headless backstop:** ensure `.dev/memory/usage.md` has a current `window_start` before
  scheduling an unattended run, or accept that the guard will skip silently for that session.

## One-shot resume scheduling

When the 5-hour guard fires, `/dev --auto` schedules a resume. `five_hour_resets_at` is a **UTC ISO8601** timestamp — bare `at <ISO>` fails with `garbled time` and a naive digit-strip drops the UTC→local offset, so convert through epoch and use `at -t`:
```bash
resets="$five_hour_resets_at"   # e.g. 2026-06-29T18:00:00Z (UTC)
epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$resets" "+%s" 2>/dev/null || date -u -d "$resets" "+%s")
stamp=$(date -r "$epoch" +%Y%m%d%H%M 2>/dev/null || date -d "@$epoch" +%Y%m%d%H%M)   # local time
echo "claude -p '/dev --auto'" | at -t "$stamp"
```
`at` must be enabled on the machine (`sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist` on macOS). If `at` is unavailable, a `cron` equivalent is logged to stdout and `.dev/auto.log`:
```
# add to crontab: run once at <five_hour_resets_at>
# crontab -e  →  <MM> <HH> <DD> <mon> * cd /path/to/repo && claude -p '/dev --auto' >> .dev/auto.log 2>&1
```
The resume runs as a **fresh, clean session** (`claude -p` with no `--continue`/`--resume`): it carries no prior context and rebuilds all state from `.dev/memory/`, so the resumed run starts lean. Note: a clean session does **not** reset the 5-hour quota — only the wait until `five_hour_resets_at` does. That is why the resume is scheduled for that timestamp rather than fired immediately.

## Notifications

Updates (quota warnings, pause) are delivered via the Claude app **PushNotification** tool —
the orchestrator invokes the tool directly at each notify step. No external service, no
credentials, and no shell script are required. Requires the Claude app with notifications
enabled on your device.

## Limitations

- Autonomous brainstorming self-approves specs: review the audit trail before trusting a long
  unattended run. The no-merge gate is your backstop — nothing reaches `main` without you.
- Cloud `/schedule` routines are possible but the cloud env must clone the repo and provide
  graphify + the test runner (same research-preview caveat as the loop-pipeline). Local
  scheduling is the supported default.
- The usage guard is between-phases only. A single long-running phase can overrun the quota
  with no interrupt — plan phases accordingly.
