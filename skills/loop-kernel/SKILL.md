---
name: loop-kernel
description: Shared loop contract for /dev, /ship, /fix and /loop-worker — goal file, rich metric + test-guard, blind held-out verifier, capped retry, final hill-climb, and a distiller that turns findings into lessons and proposed skill diffs. Not invoked directly; pipelines call its sections by name.
---

# Loop kernel

An agent keeps working only as long as something other than the user can say "this is wrong, try again". This contract is that something. Pipelines reference sections below by number; they do not restate them.

Run state lives in the **target project** under `.loop/` (git-ignored): `goal.md`, `findings.md`, `proposals/`, `auto`, `stop-blocks`, `escalations.md`, `active`, `test-lock`, `lock-ref`, `lock-ref-<task-id>`, `shots/` (run history is not here: it lives in `.dev/memory/history.jsonl`). Committed per-project files live in .factory/ (§0). Interactive runs start with `rm -rf .loop && mkdir -p .loop` (clears any stale `auto` marker).

Kernel scripts live next to this file: `KERNEL=~/.claude/skills/loop-kernel` (or `.claude/skills/loop-kernel` for a project install).

## 0. Factory files — `.factory/` (committed, per project)

Agents need a durable, project-specific description of how to run and check the project. Before writing goal.md — and before the run base is recorded — the owning stage (`/dev` bootstrap, `/ship` step 0, `/fix` baseline) makes sure the target project has:
- `.factory/checks` — one shell command per line (`#` comments allowed) that must exit 0 on every change: the full test command, lint/typecheck, and the smoke command. Template: `factory-checks-template`.
- `.factory/run.md` — Launch, Logs, Smoke and Browser sections. Template: `factory-run-template.md`. Behavior checks (§1) and climb screens (§5) use these commands instead of guessing.
- The pre-push hook (outer loop): `install -m 755 "$KERNEL/pre-push-hook.sh" "$(git rev-parse --git-path hooks)/pre-push"`; if a different pre-push hook already exists, report it and do not overwrite. The hook runs `factory-check.sh` against the upstream base on every push, so no check depends on an agent choosing to run it.
Create any missing file by inspecting the project (package.json scripts, Makefile, pyproject.toml, Cargo.toml, go.mod, README). Ask the user only for what cannot be inferred (`--auto`: reversible default logged `[auto]` to `decisions.md`). Every `.factory/checks` line must pass on the current commit before it is committed; a red line is reported, not committed. Commit these files alone: `chore(factory): bootstrap .factory`. During a run, lines are only added; removing or weakening one is a test-guard violation and `guard-edits.sh` denies edits while `.loop/active` exists. Changes to existing lines go through a distiller proposal (§6).

## 1. Objective — `.loop/goal.md`

- The stage that owns intent writes it once, from `goal-template.md`: brainstorm/plan (`/dev`), `oro-planner` (`/ship`), the decompose step (`/fix`).
- **Goal** = end state only. Steps belong in the spec/plan, never here.
- **Done-criteria** = runnable commands only. **At least one Behavior check**: a command that exercises the real end state (run the CLI with real input, curl the endpoint, build and load the page headless, run the migration on a scratch DB). Unit tests alone are not a done-criterion set. Anything not expressible as a command goes in **Rubric**. The project's `.factory/checks` (which include its test command) run on every attempt anyway (§2), so done-criteria list only the Behavior check plus goal-specific commands.
- **UI goals** (goal touches UI files or describes something a user sees): add `## Screens` listing 1-5 screens/states to capture (URL or route + state). Climb captures these for the judges (§5).
- **Rubric** = 3-5 criteria derived from the Goal, each with what a 10/10 looks like.
- **Grill:** if the goal can't be written without guessing, the owning stage asks the user (its existing question mechanism). Under `--auto`: answer from `.dev/memory/`; reversible → sensible default logged `[auto]` to `decisions.md`; irreversible → `ESCALATE:`.
- **Critique before code:** after goal.md and the spec/plan exist, dispatch `oro-critic` (fresh, read-only) with both. `GAPS` with any [P0]–[P2] item (blocking) → the owning stage revises goal/spec and the critic re-runs (max 2 critic rounds). Interactive: show blocking gaps that need the user's input. `--auto`: reversible → decide and log `[auto]`; irreversible → `ESCALATE:`.
- **Freeze:** after the critic is CLEAR, `touch .loop/active`. goal.md is now frozen; the `guard-edits.sh` PreToolUse hook denies edits to it. `rm -f .loop/active` at run end.
- **Exemplars:** the spec names, for every file to create, the existing file whose patterns it must follow (`exemplar: <path>`). Coders follow it; reviewers check it.
- **Lessons:** for every coder/implementer dispatch, run `bash "$KERNEL/lessons-for.sh" .dev/memory/lessons.md <files the task touches>` and pass its output (≤ 5 lessons, highest `seen` first, file-scoped ones only when they match). Never paste the whole lessons file.
- **Raw output:** every subagent dispatch (coder, tester, reviewer, judge) says: run git as `/usr/bin/git --no-pager`, one plain command per Bash call, and when a shell wrapper condenses test output, build the test binary and run it directly. Agents that see condensed output miss printed lines and diff hunks.

## 2. Metric

After every coder/implementer attempt, the orchestrator runs:
1. `bash "$KERNEL/factory-check.sh" <ref> <goal-or-""> [<manifest-file>]`, where `<ref>` = `.loop/lock-ref` (per task in /dev: `.loop/lock-ref-<task-id>`) if it exists, so the coder is judged only on what it changed after tests were locked; else the run base. It runs every line of `.factory/checks` (§0), every done-criterion of the goal file when one is given, then `test-guard.sh <ref> [<manifest-file>]`. Pass `.loop/goal.md` only where the whole goal should already hold: every /ship attempt (one task = the whole goal) and final verification of /fix and /dev. Per /dev task and per /fix fix, pass `""` — goal criteria are end-of-run checks and would stay red until the last task. Each failure prints `FAIL: <what>`, the output tail and a `→ fix:` line. Pass these blocks to the retry verbatim: they are the prompt (errors as prompts). `FAIL: test-guard` lines are tagged `[reward-hack]`. `warn:` lines go to the reviewer. Exit 2 → metric failure (report; never treat as pass).
2. When a failure class repeats, the fix is a new check with a remediation message (a `.factory/checks` line, a lint rule, a structural test), not more prose. The distiller proposes these (§6).
3. **Once per run, after all tasks pass and before §5:** `bash "$KERNEL/mutate-check.sh" <run-base> "<test command>"` on a clean tree. Exit 1 (tests still pass with the change reverted) → red, finding `[reward-hack] tests don't exercise the change`, retry via §4 with the **test author**, not the coder. Exit 3 (mutants survived) → dispatch the test author once in strengthen mode to add tests that kill the survivors (locked tests stay untouched), lock the new tests, re-run. Still surviving → `[metric]` finding for the reviewer. Exit 2 (dirty tree or bad ref) → metric failure: report it, never treat as pass; commit or clean the tree and re-run.
Append every finding to `.loop/findings.md` as `- [metric] <task>: <line>`.

## 3. Verifier — blind and held out

- Reviewers are **fresh subagents, never forks** of the author. Say so explicitly when dispatching.
- Reviewer input is exactly: `.loop/goal.md`, the task spec, `git diff <base>..HEAD`, test/metric output. **Never** the author's report, summary, or reasoning (`changes.md`, implementer status).
- Append each reviewer finding to `.loop/findings.md` as `- [review] <task>: <finding>`.
- Every finding carries a severity tag: `[P0]` broken/unsafe/reward-hack, `[P1]` wrong behavior or spec miss, `[P2]` should fix before merge (design, missing edge case, exemplar drift), `[P3]` nit or style. Bias toward code that is accepted, not perfect: a P3 never blocks.

## 4. Retry — capped optimizer

On any red: factory-check exit ≠ 0, or any reviewer finding tagged [P0]–[P2] or [reward-hack]. [P3] findings never trigger a retry: append them to findings as `- [deferred] <task>: <finding>` for the distiller.
1. Dispatch a **fresh** coder/implementer with: goal.md, task spec, lessons (§1), the findings + failing output, and the `## Diagnosis` sections of earlier attempts. Not the previous author's code reasoning.
1b. **Push-back:** the retrying coder may answer a `[P2]` finding with `REJECT: <finding> — <reason>` in its report. The orchestrator passes only the rejected finding and the reason (never the rest of the report) to the next blind reviewer, who either drops it or re-raises it; a re-raised finding is binding. `[P0]`, `[P1]` and `[reward-hack]` cannot be rejected; for a wrong test, `TEST-DISPUTE:` (§8) is the only path.
2. **Diagnose before retrying:** every retry must open its report with `## Diagnosis` — root cause of the last failure (cite the failing output), why the last approach failed, and the different approach it will take. A retry that re-applies the previous approach is a protocol violation; reject it and count the attempt.
3. **Escalate the attempt:** attempt 2 = same model, new approach from the diagnosis. Attempt 3 = dispatch with the most capable model (`model: opus`) and require a structurally different approach than attempts 1-2.
4. Re-run §2 and §3.
5. **3 attempts per task total** (1 initial + 2 retries). When attempt 3 fails, stop that task.
6. Cap hit or reviewer `BLOCK` (BLOCK skips retries): interactive → stop and show the user the last findings; `--auto` → append an `ESCALATE:` block (task, last findings) to `.dev/memory/escalations.md` (or `.loop/escalations.md` if no `.dev/`); loop-worker → `needs:human`.
7. When the user redirects or corrects anything mid-run, append it to `.loop/findings.md` as `- [user] <what they said>`.

## 5. Climb — final hill-climb (every run)

After all tasks pass, before finishing:
1. `git tag -f loop/climb-0`. Compute run diff stats vs the run base.
2. **Small-diff exemption:** < 50 changed lines AND no file matching `*.css *.scss *.tsx *.jsx *.vue *.svelte *.html` → do step 3 once, report the score, skip to §6.
3. **Screens (UI goals only):** if goal.md has `## Screens`, launch the app (per `.factory/run.md` Launch/Browser first, falling back to the `run` skill's pattern for the project type or the built-in browser pane) and save a screenshot per listed screen to `.loop/shots/<tag>/<n>.png`. If launch fails, record that as a `[metric]` finding and judge from code only.
   Dispatch **3 `oro-judge`** subagents in parallel (fresh, blind): input = goal.md + `git diff <base>..HEAD` + the screenshot paths for this tag (if any). Judges 1-2: `persona: none`. Judge 3: `persona:` an expert fitting the goal's domain (e.g. senior UX designer, SRE, API designer). Each returns per-criterion scores 0-10 and up to 3 improvements.
4. Drop malformed judge output. < 2 valid judges → skip climb, report. Score = mean of all valid per-criterion scores.
5. Stop if score ≥ 8.5. Otherwise run **two competing variants** in parallel, each in its own worktree off the best tag (`git worktree add .loop/wt-a -b loop/climb-N-a <best-tag>`, same for `-b`). `.loop/` is ignored and is not carried into a worktree: before dispatch, create `<variant>/.loop/` and copy the frozen `goal.md`, `active`, `test-lock`, and every `lock-ref*` from the run worktree. Verify the copied lock with `shasum -a 256 -c <variant>/.loop/test-lock`. A missing or invalid lock discards the variant before any coder runs.
   - **Variant A (apply):** fresh coder applies the deduped improvement list (max 5) faithfully.
   - **Variant B (rethink):** fresh coder gets the same list plus goal.md and must address the lowest-scoring criterion with a different approach than the current code (it states the difference at the top of its report).
   Each coder must leave a clean worktree and commit its implementation without changing locked tests or `.loop/goal.md`; an uncommitted or dirty variant is red. Run §2 on each; a red variant is discarded. Capture screens (step 3) and judge each surviving variant with 3 fresh judges. Keep the higher-scoring variant by running `git merge --ff-only <winning-variant-branch>` in the original run worktree, then `git tag -f loop/climb-N`. Only after the fast-forward succeeds, remove both worktrees and variant branches. Both red → stay on the current best tag and stop.
6. Stop after round 2, or when gain < 0.5, or score ≥ 8.5. The run branch is already at the best accepted commit; never use `git reset --hard` as climb cleanup. Delete all `loop/climb-*` tags and remove any remaining variant worktrees/branches.
7. Append each judge improvement not applied to `.loop/findings.md` as `- [judge] <item>`.

## 6. Distill — durability (every run, also after escalation/cap)

First append one line of run history. `.loop/` is wiped per run, so history lives at `$MAIN/.dev/memory/history.jsonl` (`MAIN` as defined below; create the directory if missing):
`jq -nc --arg pipeline <ship|fix|dev> --arg goal "<first line of Goal>" --argjson attempts '<{"<task>":n,...}>' --argjson climb '[<score per round>]' --argjson caps <n> --argjson hacks <count of [reward-hack] findings> --arg date "$(date -u +%FT%TZ)" '{date:$date,pipeline:$pipeline,goal:$goal,attempts:$attempts,climb:$climb,caps:$caps,reward_hacks:$hacks}' >> "$MAIN/.dev/memory/history.jsonl"`

Other history events (all to `.dev/memory/history.jsonl`, one JSON object per line):
- `{"date","event":"intervention","prompt"}` — written by the `intervention-log.sh` UserPromptSubmit hook for every human prompt while `.loop/active` exists. Each one is a place the harness failed to carry the agent.
- `{"date","event":"pr_opened","pr":<n>,"by":"agent"}` — written when a pipeline opens a PR (`/loop-worker`).
- `{"date","event":"pr_review","pr":<n>,"human_comments":<n>}` — written by `/address-review`, which also appends each human comment to `.dev/memory/human-feedback.md` as `- [human] <YYYY-MM-DD> PR#<n>: <summary> (<url>)`.
Runs often happen in a git worktree (/dev, /loop-worker, climb variants), which is removed afterwards. So every history writer — the §6 run line included — writes to the **main checkout**: `MAIN="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"`, file `$MAIN/.dev/memory/history.jsonl` (same for `human-feedback.md`). A run that works in a worktree also does `mkdir -p "$MAIN/.loop" && touch "$MAIN/.loop/active"` at freeze and `rm -f "$MAIN/.loop/active"` at its end, so the intervention hook (which runs in the session's project dir) sees it.
`bash "$KERNEL/scorecard.sh"` turns these into autonomy (interventions per run), automation (zero-touch agent PRs, human comments per PR) and quality (attempts, caps, reward hacks, climb gain) numbers. The weekly `/gc` command runs the scorecard and the distiller over the week's human feedback.

Dispatch `oro-distiller` with: `.loop/findings.md`, `.loop/escalations.md` and `.dev/memory/escalations.md` (whichever exist), `.dev/memory/history.jsonl`, the target project's `.dev/memory/lessons.md` path, and the oroskills repo path (`readlink -f ~/.claude/skills/loop-kernel/..` → repo `skills/`; if not a symlink install, pass none and it skips proposals).
- It appends/increments lessons and writes proposals to `.loop/proposals/*.diff`. It **never** applies a diff.
- Interactive: list each proposal (file + one-line rationale), ask approve/reject per item, `git -C <oroskills> apply <diff>` for approved ones. Report apply failures; leave the file.
- `--auto`: list proposals in the run summary only.
- Proposals are mechanical first: a `.factory/checks` line, lint rule or structural test whose failure message says how to fix it. Skill/agent prose diffs only when the pattern cannot be checked by a command.
- Distiller failure never fails the run.

## 7. Auto marker

Unattended runs (`/dev --auto`, `/loop-worker`) `touch .loop/auto` after writing goal.md and `rm -f .loop/auto` on every orderly ending. While the marker and goal.md exist, the `goal-stop.sh` Stop hook refuses to let the session stop until done-criteria pass (gives up after 3 blocks, logging `ESCALATE:` to `.loop/escalations.md`). Interactive sessions are unaffected.

## 8. Integrity — no reward hacking, by construction

The agent that makes tests pass never decides what the tests are.
1. **Tests before code, by a different agent.** `/ship` and `/fix`: `oro-tester` writes the acceptance tests from goal.md + spec only (no code exists yet) and shows them failing for the right reason (the behavior is missing, not a syntax error). `/dev`: each task is split in two. First `oro-tester` (plan-test mode) commits the task's test code from the plan exactly as written and shows it red; it is locked; only then is `oro-implementer` dispatched, to write the implementation alone.
2. **Lock.** As soon as tests are committed and observed red (every pipeline): `shasum -a 256 <test files> >> .loop/test-lock`. Record the test commit: /ship and /fix → `git rev-parse HEAD > .loop/lock-ref`; /dev → per task, `git rev-parse HEAD > .loop/lock-ref-<task-id>` (parallel tasks in a wave each get their own). The lock only grows; existing entries are never rewritten during a run.
3. **Enforcement, three layers:** `guard-edits.sh` (PreToolUse) denies Edit/Write to locked tests and to the frozen goal.md; `test-guard.sh` hash-checks the lock, so edits made via Bash are caught at the next metric run; the blind reviewer and judges fail special-casing.
4. **Reward hacking (always a FAIL, tagged `[reward-hack]`):** editing, skipping or weakening a locked test; changing test config or runner flags to narrow or silence a run; special-casing test inputs or hard-coding expected outputs; detecting a test environment in production code; swallowing errors so a check passes; mocking out the code under test; editing goal.md or a done-criterion; claiming green without the command output; pushing with `--no-verify` or disabling the pre-push hook.
5. **The only legitimate path when a test is wrong:** the coder stops and writes a `TEST-DISPUTE:` block (test, why it contradicts goal.md/spec, proposed correction). Interactive: show it to the user. `--auto`: dispatch a fresh blind reviewer with goal.md + spec + the test + the dispute. Upheld → the orchestrator removes that file's line from `.loop/test-lock`, dispatches `oro-tester` in dispute-fix mode (never the coder) to amend it as ruled, re-locks it, and the attempt counts. Rejected → the attempt counts as failed.
   **Test author** everywhere in this contract = `oro-tester` (test-first, strengthen and dispute-fix modes), in every pipeline including /dev.
6. Every `[reward-hack]` finding is reported to the user in the run summary, and the distiller turns it into a lesson and a proposal on the first occurrence.

This makes reward hacking hard and visible, not impossible. Remaining risk: a coder can still overfit to the specific locked inputs. The mutation check, the independently written Behavior check, the hard-coded-literal warning and the blind reviewer are the backstops.
