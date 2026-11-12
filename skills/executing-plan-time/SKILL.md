---
name: executing-plan-time
description: "Use when executing an approved implementation plan end-to-end: worktree isolation, overlap-gated parallel waves, TDD-before-commit, per-task review, PR opened right after review with goal verification after (fixes go into the PRs)."
---

# Direct Executing Plans

One skill that runs an approved plan to done: worktree, parallel waves, tests-first TDD, per-task review, PR and post-PR verification in a single runner.

**Announce at start:** "I'm using the executing-plan-time skill to run the plan."

**Inputs:**
- A written, approved plan file (preferably produced by writing-plans-time, which already includes the File Edit Manifest + wave structure).
- A repo with (or willing to initialize) a graphify graph.

**Dispatched agents:**
- `oro-tester` (pipelines/ship-pipeline/agents/oro-tester.md) — plan-test mode: commits each task's tests from the plan and shows them red before the implementer runs; strengthen mode after mutate-check.
- `oro-implementer` (pipelines/dev-pipeline/agents/oro-implementer.md) — the per-task oro-implementer subagent. Worktree-aware, manifest-constrained, enforces the TDD-before-commit contract.
- `oro-task-reviewer` (pipelines/dev-pipeline/agents/oro-task-reviewer.md) — the combined per-task reviewer: spec compliance, manifest discipline, TDD-artifact integrity (test commit matches the plan, untouched since the lock, green at head), code quality, and sibling-task conflicts when the task ran inside a parallel wave.
- Via loop-kernel: `oro-critic` (§1, `--auto` only), `oro-judge` (§5) and `oro-distiller` (§6), each only when its kernel condition holds.

Every oro-implementer dispatch MUST dispatch the `oro-implementer` agent by name. Every task MUST pass the `oro-task-reviewer` before being marked done. Skipping the review is a hard-gate violation — see below.

<HARD-GATE>
Four hard gates. Violating any of them is a stop-the-line event:

1. **Worktree gate.** No edits to the main checkout. All work happens inside a git worktree created by this skill.
2. **TDD-before-commit gate.** A task does not commit unless a test that exercises the change was written, observed to fail, and then observed to pass — in that order. The fail log + pass log + commit triple is the artifact.
3. **Overlap gate.** Two tasks run in parallel only if overlap analysis (files + functions + call-graph edges) shows zero conflict. When in doubt, serialize.
4. **Review gate.** A task is not done until the `oro-task-reviewer` agent returns PASS — one review covering spec compliance, TDD-artifact integrity, code quality, and sibling conflicts.
</HARD-GATE>

## Checklist

Create a TodoWrite todo for each phase. Each phase has its own internal steps.

1. **Pre-flight** — graphify exists, plan loaded, worktree created, baseline tests green, memory read (read `.dev/memory/` per `~/.claude/memory-protocol.md` if present; pass memory pointers to each dispatched agent)
2. **Overlap analysis** — for every wave, verify file + function + call-graph disjointness; downgrade waves if needed
3. **Wave loop** — for each wave: dispatch parallel `oro-implementer` agents, await all; per task run the combined review (dispatch the `oro-task-reviewer` agent), fix loop if needed; verify the wave; mark tasks done
4. **Open the PR** — as soon as every task has passed review: branch-integrity precheck, push, open the PR (body says full verification is pending). Never merge.
5. **Post-PR verification** — goal done-criteria + spec coverage on the pushed branch (the pre-push hook already ran `.factory/checks`); every failure is fixed test-first and pushed to the PR it belongs to (an earlier stacked PR if the bug lives there); post the result as a PR comment

---

## Phase 1: Pre-flight

**Loop kernel.** This skill runs on the `loop-kernel` contract (`~/.claude/skills/loop-kernel/SKILL.md`). Before the first wave, ensure `.loop/goal.md` exists in the worktree (write it from the spec per §1 if the plan didn't), run the §1 critic over goal.md + this plan under `--auto` only (interactive: the human already approved the spec and plan, so skip it), then freeze (`touch .loop/active`) — and, because the session's hooks run in the main checkout, also `mkdir -p <main-checkout>/.loop && touch <main-checkout>/.loop/active` (every run, not only autonomous ones; remove it when the run ends) so the intervention hook logs prompts during the run. Also record the run base SHA. Each task runs as **tests first, then code** (§8), so the tests are locked before the implementer starts.

**Autonomous runs only:** the Stop hook reads `.loop/` in the *main checkout* (the session's project dir), not the worktree. So also write `<main-checkout>/.loop/goal.md` as a copy whose done-criteria commands are prefixed `cd <worktree> && `. Remove that copy when the phase ends.

### 1.1 Graphify

```bash
test -f graphify-out/graph.json && echo present || echo missing
```

If missing, stop and offer:

> "No graphify graph found. I need it for overlap analysis (function-level + call-graph) before dispatching parallel agents. OK to run `/graphify`?"

If the user declines, fall back to file-level overlap only and note this limitation. Function-level and call-graph overlap checks will be skipped — say so out loud, since the skill's parallelization safety is degraded.

**Freshness gate (required before trusting the graph for parallelism).** The call-graph drives the function + cross-edge overlap checks; a stale graph can declare racing tasks "disjoint." Before any parallel dispatch, confirm the graph is current:

```bash
# Stale if any tracked code file is newer than the graph, or the tree is dirty.
test -n "$(git status --porcelain)" && echo dirty
find . \( -name '*.py' -o -name '*.ts' -o -name '*.go' \) -newer graphify-out/graph.json 2>/dev/null | head
```

If either signals staleness, run `graphify --update` and re-verify. If you cannot refresh (no graphify, user declines, update fails), **do not parallelize on function/call-graph claims** — drop to file-level disjointness only and **serialize every wave with more than one task**. Stale-graph parallelism is a correctness risk; the safe default is serial.

### 1.2 Worktree (always)

```bash
git worktree add -b exec/<plan-slug>-<yyyymmdd> ../<repo>-exec-<slug>
cd ../<repo>-exec-<slug>
```

All subsequent work — every read, every edit, every commit, every test run — happens inside this worktree. The main checkout is untouched.

If a worktree for the same plan already exists, ask the user whether to resume it or create a fresh one. Never silently reuse.

### 1.3 Baseline tests green

Run the project's test command inside the worktree before doing anything else. If baseline is red:

> "Baseline tests are failing on `<branch>` before any changes. I'm halting — fixing pre-existing failures is not in this plan's scope, and proceeding would conflate failures."

Wait for user direction. Do not start the plan.

### 1.4 Context discipline

From this point on, the main agent (you) does **not** read source files directly except to inspect the plan itself, the graphify query results, and the short status reports returned by subagents. All file edits, test runs, and commits happen inside dispatched subagents — the main context never accumulates code.

Concrete rules for the main agent:
- Do not call Read on source files. Use `graphify query` for understanding.
- Do not call Edit/Write on source files. Dispatch a subagent.
- Do not run the full test suite from main except at the final verification step. Per-task tests run inside the subagent.

### 1.5 Memory protocol

Read `.dev/memory/` per `~/.claude/memory-protocol.md` if present; pass memory pointers to each dispatched agent. No-op when absent. If `.dev/memory/design.md` is present, include it in the memory pointers passed to each dispatched `oro-implementer` — it sits outside the goals→…→progress read chain, so it must be forwarded explicitly or UI tasks lose the mockup reference.

---

## Phase 2: Overlap Analysis (per wave)

The plan declares waves and file-level disjointness. This phase **verifies** that and adds two stronger checks.

For every pair of tasks (T_a, T_b) intended to run in the same wave, all three must hold:

| Check | How | Mandatory |
|-------|-----|-----------|
| **File-disjoint** | `files(T_a) ∩ files(T_b) == ∅` | Yes |
| **Function-disjoint** | No function/symbol appears in both `functions(T_a)` and `functions(T_b)` via `graphify query "what functions live in <file>"` | Yes |
| **No cross-edge** | No symbol modified by T_a is called by any file modified by T_b (and vice versa) via `graphify query "what calls <symbol>"` | Yes |

If any check fails for a pair, **demote the later task to the next wave**. Re-run analysis. Repeat until all waves are clean.

The cross-edge check is what catches the case where T_a renames `parseConfig` and T_b modifies a caller of `parseConfig` — file-disjoint but logically racing.

Document the analysis result in a short note before dispatching:

```
Wave 2 overlap check:
- T2 vs T3: files disjoint ✓, functions disjoint ✓, no cross-edges ✓ → parallel OK
- T2 vs T4: T4 calls T2.serialize → cross-edge → T4 demoted to W3
```

---

## Phase 3: Wave Loop

For each wave, in order:

### 3.1 Dispatch parallel oro-implementer subagents

**One isolated worktree per parallel task.** Git's index and branch tip are shared mutable state even when source files are disjoint, so parallel writers must never stage or commit in the same worktree. Record `<wave-base>`, then create a task branch and sibling worktree for every task in the wave from that exact SHA (`git worktree add -b <wave-branch>-<task-id> <task-worktree> <wave-base>`). Seed `<task-worktree>/.loop/` with the integration worktree's frozen `goal.md`, `active`, existing `test-lock`, and `lock-ref*`; verify any copied lock before dispatch. Each task then appends only its own lock entries. Dispatches for that task use only its task worktree. Tasks may run in parallel because their indexes, branch tips and `.loop/` state are isolated.

**Single-task wave:** skip all of the above. The task runs directly in the phase's integration worktree — no task worktree, no `.loop/` seeding, no cherry-pick — and "task worktree" below means the integration worktree.

**Tests first (loop-kernel §8).** In each task worktree, dispatch `oro-tester` in **plan-test** mode. It commits the task's test code exactly as the plan gives it, runs it, and returns the red output. Check the output is red for the right reason (behavior missing, not a syntax error); otherwise re-dispatch it once, then escalate. Lock it inside that task worktree: `shasum -a 256 <repo-relative task test files> >> .loop/test-lock && git rev-parse HEAD > .loop/lock-ref-<task-id>`. Only then dispatch the oro-implementer in the same task worktree, told that the tests are already committed and locked: it writes and commits implementation only. The TDD artifact is the tester's red log + test commit, then the implementer's green log + implementation commit.

Send **all tasks in the wave as a single message with multiple Agent tool calls**. Dispatch the `oro-implementer` agent (pipelines/dev-pipeline/agents/oro-implementer.md) by name with the task slice — do not write ad-hoc instructions. Each dispatch gets:

- The task worktree absolute path and task branch (never the shared integration worktree)
- The full task text from the plan (verbatim — do NOT have the subagent read the plan file)
- The task's File Edit Manifest entries (Create / Modify / Test / Delete)
- Pre-queried graphify context (functions defined in modified files, callers, callees) — run these queries once in main BEFORE dispatching, paste the results into each dispatch
- Output of `lessons-for.sh .dev/memory/lessons.md <task files>` (loop-kernel §1), and on a retry the reviewer findings plus earlier attempts' `## Diagnosis` sections (§4). Attempt 3 is dispatched with `model: opus`.

The `oro-implementer` agent already enforces the TDD-before-commit contract (3.2) and the manifest constraint. Do not weaken it; do not skip required context. If a context slot doesn't apply, write "none" — never leave it blank or invent a value.

### 3.2 TDD-before-commit (the contract)

The full contract lives in the `oro-implementer` agent: fail log → pass log → commit — the triple is the artifact.

The orchestrator's job here is to verify the implementer's report contains the fail log, pass log, and commit SHA before accepting it; a report missing any of the three is not done — re-dispatch or roll back.

### 3.3 Await all

Collect statuses (≤20-line reports) from every oro-implementer in the wave. Do not integrate a task yet; first review it in its isolated worktree (§3.4).

### 3.4 Per-task review

For each task in the wave, dispatch the `oro-task-reviewer` agent (pipelines/dev-pipeline/agents/oro-task-reviewer.md) by name in that task's isolated worktree, before integration. Reviewers for different tasks can run in parallel.

Provide:
- Isolated task worktree path
- Base SHA (commit immediately before this task's commit) and head SHA (the task's commit)
- The full task text from the plan
- The task's File Edit Manifest
- **Sibling-task touch sets** — the files modified by every other task in this same wave (this is what the sibling-conflicts check needs)
- `.loop/goal.md` path, the task's test commit (`.loop/lock-ref-<task-id>`) and implementation head, and `test-guard.sh <lock-ref-<task-id>> <manifest>` output (loop-kernel §2: per task, test-guard plus the task's own tests only; `.factory/checks` run on push and goal criteria at final verification). **Not** the implementer's report — the reviewer is held out (§3); dispatch it fresh, never as a fork.

The reviewer returns `PASS` or `FAIL` with specific findings — one report covering spec compliance, TDD-artifact integrity, code quality, and sibling conflicts. If `FAIL`:
- Re-dispatch a **fresh** oro-implementer with the reviewer's findings and failing output (not the previous implementer's report) — loop-kernel §4.
- Re-run metric + review. **Max 3 attempts per task total.** On the 3rd failure: interactive → stop and show the user the findings; autonomous → return an `ESCALATE:` block for that task.

If only Minor quality issues remain and spec compliance is clean, the reviewer returns `PASS` with the minors noted for follow-up (non-blocking). Do NOT silently fix the issues yourself in main — dispatch a subagent.

Only after a task passes review (multi-task waves; a single-task wave is already in the integration worktree), cherry-pick its test commit and implementation commit(s), in task order, into the phase's integration worktree. After each test commit lands, hash its test paths into the integration worktree's `.loop/test-lock` and record the new cherry-picked SHA as `.loop/lock-ref-<task-id>`. A cherry-pick conflict means the overlap analysis was wrong: abort that cherry-pick, demote the later task, and re-run it from the new integration tip. Never resolve a parallel integration conflict by guessing.

After every passing task has been integrated, verify the wave:

```bash
# In the integration worktree
git log --oneline <wave-base>..HEAD   # confirm test + implementation commits per task
git diff --stat <wave-base>..HEAD     # confirm changed files match the manifests
<project-test-command-for-touched-areas>
```

If verification fails, demote and re-run the conflicting task; if a commit touched files outside its manifest, re-dispatch it. After successful integration, remove the task worktrees and temporary task branches. Preserve failed or escalated task worktrees for diagnosis.

### 3.5 Mark done + context hygiene between waves

A task is marked done in TodoWrite only after the oro-task-reviewer green-lights it. Then summarize the wave in 3–5 lines (tasks, files touched, peak parallelism, any reviewer iterations) and discard the per-task status blobs and reviewer reports from working memory.

The next wave's oro-implementer subagents only need: the next task slice, the worktree path, and any new graphify context.

---

## Phase 4: Open the PR (before full verification)

**Directive (user, 2026-11-11):** open the PR as soon as every task has passed its review. The push itself runs `.factory/checks` + test-guard (pre-push hook, loop-kernel §0); goal verification runs *after* the PR is open (Phase 5); anything it catches is fixed by updating the PRs. Per-task scoped tests + per-task review are the gate for opening.

1. Run the **branch-integrity precheck** (below) so the pushed branch carries every task.
2. Push the branch (a push blocked by the pre-push hook is fixed test-first and retried — never `--no-verify`) and `gh pr create` against the base branch (in a stack, the previous phase's branch). Title + summary from the plan. The body MUST contain a line saying full verification is pending and that failures will be fixed in this PR (or the earlier stacked PR they belong to), plus the "Not verified" list.
3. Never merge. Never force-push a branch someone else's PR is stacked on without rebasing the stack after it.

**Branch-integrity precheck.** A subagent may have detached the worktree HEAD during the run, leaving the branch ref behind the real work — pushing the ref would then ship only part of the plan. Confirm the branch label actually points at the work tip:

```bash
git -C <worktree> rev-parse HEAD          # the real work tip
git -C <worktree> rev-parse <branch>      # the branch label
git -C <worktree> symbolic-ref -q HEAD || echo "DETACHED HEAD"
```

If `HEAD` is detached or the two SHAs differ, repoint the branch before pushing:

```bash
git -C <worktree> branch -f <branch> <work-tip-SHA>
```

---

## Phase 5: Post-PR Verification

After the PR is open, from main, in the worktree (run it in the background; it can overlap planning of the next phase):

```bash
# The push already ran .factory/checks + test-guard (pre-push hook). Not a repeat: the goal's done-criteria.
<each Done-criteria command in .loop/goal.md>
# Only if no pre-push hook ran on the push (loop-kernel §0 reported a foreign hook):
bash ~/.claude/skills/loop-kernel/factory-check.sh <run-base> .loop/goal.md

# Optional: spec coverage check
# For each requirement in the spec, confirm at least one commit references it
git log --oneline <main>..HEAD | grep -iE "<requirement-keywords>"
```

If any fail, **update the PRs**:
- Dispatch a fresh subagent to investigate, following the TDD-before-commit contract for any fix. Max 3 attempts total, then escalate (loop-kernel §4).
- Commit the fix on the branch whose PR introduced the bug. In a stack, fix it on the earliest PR that owns the bug, push it, then merge that branch forward into each later branch in the stack (merge commits, no rebase/force-push) and push those.
- Re-run the failed check; the push re-runs `.factory/checks`.
- Known environmental flakes: retry ≤2, then report as environmental in the PR comment — never weaken the test.

When verification is green, run **loop-kernel §2 step 3 (mutate-check)** over the run and **§5 (Climb)** against the run base — each only when its kernel condition holds (a small, non-risky diff skips both) — re-run verification if the climb changed code, then **§6 (Distill)**. Push any resulting commits to the PR.

Post the result as a PR comment (`gh pr comment`): each check with pass/fail and counts, fixes pushed (SHAs, which PR), anything environmental. Update the PR body's "pending" line to the result. State the result explicitly — no "it should be working".

Merging stays the user's call: never merge; offer it only after verification is green.

---

## Ponytail Integration (Required)

Ponytail (minimal-code enforcement) runs at mode `full`. Every oro-implementer and reviewer dispatch operates under its decision ladder, applied in order before any line is written:

1. Does this need to exist? (If not, don't write it.)
2. Does the standard library solve it?
3. Is there a native platform/framework feature?
4. Is a dependency already installed that solves it?
5. Can it be one line?
6. Only then: the minimum viable implementation.

Because dispatched subagents may not inherit ponytail's global session hook, the ladder is stated explicitly in the `oro-implementer` agent and the over-engineering check in the `oro-task-reviewer` agent — do not rely on the hook alone.

## Token & Context Discipline

This skill exists partly because chaining separate sub-skills wastes context. To keep main lean:

- **Main never reads source files.** Graphify queries + subagent reports are the only signal.
- **Per-task work is fully delegated.** Subagents return ≤5-line status, not full diffs.
- **Graphify queries run once per topic per session.** Cache the result in the message you pass to the next subagent rather than re-querying.
- **Per-wave summary is ≤5 lines.** Discard per-task blobs.
- **Verification commands run in the worktree, not in scratchpads.** Don't paste long outputs into main — paste pass/fail + the failing test name.
- **No code in main messages.** If you find yourself about to paste a function body into main context, dispatch a subagent instead.

Target: main context after a 10-task plan should be roughly the plan file + 10 status lines + 5 wave summaries + final verification log. Not 10 file diffs.

---

## Overlap Analysis — How to Query

For each task, precompute its **touch set** and **call set**:

```bash
# Touch set: files the task will modify (from the manifest, already known)
# Plus: functions defined in those files
graphify query "what functions are defined in <file>"

# Call set: symbols the task's modified code will call
graphify query "what does <symbol> depend on"

# Reverse calls: symbols that call into the task's modified code
graphify query "what calls <symbol>"
```

For wave admission, two tasks T_a, T_b can co-run iff:
- `files(T_a) ∩ files(T_b) = ∅`
- `defined_functions(T_a) ∩ defined_functions(T_b) = ∅`
- `(symbols_modified(T_a) ∩ symbols_called_by(T_b)) = ∅` AND symmetric

If any intersection is non-empty, serialize.

---

## Common Failure Modes

| Symptom | Likely Cause | Recovery |
|---|---|---|
| Two parallel subagents both modify the same line | File-overlap missed in plan; manifest entry too coarse | Roll back later commit, re-run analysis, demote |
| Test passes per-task but full suite fails after wave | Cross-edge missed by analysis (shared dependency renamed) | Add cross-edge check to the analysis, fix the broken caller in next wave |
| Subagent commits without showing failing test | TDD contract not enforced in dispatch prompt | Roll back commit, re-dispatch with explicit "show fail log" requirement |
| Main context bloats mid-execution | Main agent reading files instead of querying graphify | Stop, summarize current state in ≤10 lines, continue with discipline |
| Baseline was red when we started, masked by new failures | Skipped phase 1.3 | Stash current work, return to base, fix baseline first |
| "Final verification" was implicit ("should be fine") | Verification gate skipped | Run the suite explicitly, don't hand off without evidence |
| Merge to base brings only some tasks; branch ref lags the real work | An agent ran `git checkout <sha>` on the shared worktree → detached HEAD, later commits left the branch ref behind | Before pushing, assert worktree HEAD == branch tip (see Phase 4); if detached, `git branch -f <branch> <worktree-HEAD>` then merge |
| Editing files in the main checkout instead of the worktree | Worktree gate violated | Stop; move all work into the worktree |
| Skipping the oro-task-reviewer | Review gate skipped — hard-gate violation | Dispatch the `oro-task-reviewer` before marking the task done |
| Skipping the sibling-task touch-sets in the reviewer dispatch | Incomplete reviewer context — the agent's parallel-aware check will silently degrade | Re-dispatch the reviewer with the sibling touch sets included |
| Writing ad-hoc subagent prompts instead of dispatching the named `oro-implementer` / `oro-task-reviewer` agents | Named-agent requirement skipped | Re-dispatch by agent name |
| Main agent fixing reviewer findings itself instead of re-dispatching the oro-implementer | Context pollution | Re-dispatch the oro-implementer with the findings |
| Reusing an old worktree without asking the user | Skipped the resume-or-fresh prompt (Phase 1.2) | Ask: resume or create fresh |
| Parallelizing on file-disjointness alone (graphify skipped) | Cross-edge races will bite | Refresh/initialize the graph, or serialize every multi-task wave |
| Implementer adds an unrequested abstraction, option, or speculative code | Ponytail violation | Re-dispatch with the minimal-code ladder re-emphasized |

- Never inspect another commit by running `git checkout` on the **shared** worktree — it detaches HEAD, races siblings, and orphans the branch ref so later commits land off-branch. Use `git show` / `git diff`.

## Autonomous mode (under `/dev --auto`)

When dispatched by `oro-phase-executor` under `/dev --auto`, never wait for a user. Clear each gate:
- **Existing worktree for this plan (§1.2):** resume it; never create a parallel one.
- **Red baseline (§1.3):** do not start the plan; return an `ESCALATE:` block with the failing output.
- **Plan-test not red for the right reason after one re-dispatch:** return an `ESCALATE:` block (the plan's test is likely wrong; that is a planning decision).
- **Review cap hit (§3.4) / verification cap hit (Phase 5):** return an `ESCALATE:` block naming the task and last findings (the PR stays open; say so in a PR comment).
- **Open the PR (Phase 4):** as soon as all tasks pass review, run the branch-integrity precheck, push, and open the PR if `gh` is authenticated; otherwise leave the branch. Then run Phase 5 and fix failures into the PRs. Never merge.
- Distill proposals are listed in the summary, not applied.
This section is inert when the skill runs interactively.
