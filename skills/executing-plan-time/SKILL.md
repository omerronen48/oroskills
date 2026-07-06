---
name: executing-plan-time
description: "Use when executing an approved implementation plan end-to-end: worktree isolation, overlap-gated parallel waves, TDD-before-commit, per-task review, finishing handoff. Replaces the superpowers execution skills."
---

# Direct Executing Plans

One skill that runs an approved plan to done. Replaces the chain of superpowers:using-git-worktrees → superpowers:executing-plans → superpowers:subagent-driven-development → superpowers:dispatching-parallel-agents → superpowers:test-driven-development → superpowers:verification-before-completion → superpowers:finishing-a-development-branch with a single runner.

**Announce at start:** "I'm using the executing-plan-time skill to run the plan."

**Inputs:**
- A written, approved plan file (preferably produced by writing-plans-time, which already includes the File Edit Manifest + wave structure).
- A repo with (or willing to initialize) a graphify graph.

**Dispatched agents (in `pipelines/dev-pipeline/agents/`):**
- `oro-implementer` (pipelines/dev-pipeline/agents/oro-implementer.md) — the per-task oro-implementer subagent. Worktree-aware, manifest-constrained, enforces the TDD-before-commit contract.
- `oro-task-reviewer` (pipelines/dev-pipeline/agents/oro-task-reviewer.md) — the combined per-task reviewer: spec compliance, manifest discipline, TDD-artifact integrity (re-runs the test on the parent commit to confirm it would have failed), code quality, and sibling-task conflicts when the task ran inside a parallel wave.

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
4. **Final verification** — full test suite + lint + type-check + spec coverage check on the worktree
5. **Finishing handoff** — present PR / merge-to-main / leave-as-worktree choice; do not act without user confirmation

---

## Phase 1: Pre-flight

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

Send **all tasks in the wave as a single message with multiple Agent tool calls**. Dispatch the `oro-implementer` agent (pipelines/dev-pipeline/agents/oro-implementer.md) by name with the task slice — do not write ad-hoc instructions. Each dispatch gets:

- The worktree absolute path and branch (Phase 1.2)
- The full task text from the plan (verbatim — do NOT have the subagent read the plan file)
- The task's File Edit Manifest entries (Create / Modify / Test / Delete)
- Pre-queried graphify context (functions defined in modified files, callers, callees) — run these queries once in main BEFORE dispatching, paste the results into each dispatch

The `oro-implementer` agent already enforces the TDD-before-commit contract (3.2) and the manifest constraint. Do not weaken it; do not skip required context. If a context slot doesn't apply, write "none" — never leave it blank or invent a value.

### 3.2 TDD-before-commit (the contract)

The full contract lives in the `oro-implementer` agent: fail log → pass log → commit — the triple is the artifact.

The orchestrator's job here is to verify the implementer's report contains the fail log, pass log, and commit SHA before accepting it; a report missing any of the three is not done — re-dispatch or roll back.

### 3.3 Await all + verify wave-level integration

Collect statuses (≤20-line reports) from every oro-implementer in the wave. Then, from main, run only what's needed to verify the wave integrates:

```bash
# In the worktree
git log --oneline <wave-base>..HEAD   # confirm one commit per task
git diff --stat <wave-base>..HEAD     # confirm changed files match the manifest entries for this wave
<project-test-command-for-touched-areas>
```

If wave verification fails: investigate. Common causes:
- A subagent's test passes in isolation but conflicts with another subagent's change → the overlap check missed something; demote one task to the next wave and re-run.
- A commit touched files outside the manifest → roll back that task's commit, re-dispatch with the manifest constraint re-emphasized.

### 3.4 Per-task review

For each task in the wave, dispatch the `oro-task-reviewer` agent (pipelines/dev-pipeline/agents/oro-task-reviewer.md) by name. Reviewers for different tasks in the same wave can run in parallel (they read disjoint diffs).

Provide:
- Worktree path
- Base SHA (commit immediately before this task's commit) and head SHA (the task's commit)
- The full task text from the plan
- The task's File Edit Manifest
- **Sibling-task touch sets** — the files modified by every other task in this same wave (this is what the sibling-conflicts check needs)
- The oro-implementer's full status report

The reviewer returns `PASS` or `FAIL` with specific findings — one report covering spec compliance, TDD-artifact integrity, code quality, and sibling conflicts. If `FAIL`:
- Re-dispatch the same oro-implementer (fresh subagent, same model unless the failure suggests a more capable model is needed) with the reviewer's findings as additional context.
- Re-run the review until `PASS`.

If only Minor quality issues remain and spec compliance is clean, the reviewer returns `PASS` with the minors noted for follow-up (non-blocking). Do NOT silently fix the issues yourself in main — dispatch a subagent.

### 3.5 Mark done + context hygiene between waves

A task is marked done in TodoWrite only after the oro-task-reviewer green-lights it. Then summarize the wave in 3–5 lines (tasks, files touched, peak parallelism, any reviewer iterations) and discard the per-task status blobs and reviewer reports from working memory.

The next wave's oro-implementer subagents only need: the next task slice, the worktree path, and any new graphify context.

---

## Phase 4: Final Verification

Before any finishing action, from main, in the worktree:

```bash
# Full test suite
<project test command>

# Lint
<project lint command>

# Type-check (if applicable)
<project type-check command>

# Optional: spec coverage check
# For each requirement in the spec, confirm at least one commit references it
git log --oneline <main>..HEAD | grep -iE "<requirement-keywords>"
```

All must pass. If any fail:
- Do NOT proceed to finishing.
- Dispatch a single subagent to investigate, following the TDD-before-commit contract for any fix.
- Re-run final verification.

State the final verification result explicitly. No "it should be working" — evidence before claims.

---

## Phase 5: Finishing Handoff

After final verification is green, present the choice. Do not act without the user picking one.

**Branch-integrity precheck (do this first, before any merge/PR).** A subagent may have detached the worktree HEAD during the run, leaving the branch ref behind the real work — merging the ref would then ship only part of the plan. Confirm the branch label actually points at the work tip:

```bash
git -C <worktree> rev-parse HEAD          # the real work tip
git -C <worktree> rev-parse <branch>      # the branch label
git -C <worktree> symbolic-ref -q HEAD || echo "DETACHED HEAD"
```

If `HEAD` is detached or the two SHAs differ, repoint the branch before finishing:

```bash
git -C <worktree> branch -f <branch> <work-tip-SHA>
```

Then, after any merge, re-check the merge diffstat covers **every** task in the plan — not just the early ones.

> "Plan complete and verified on worktree `<path>` (branch `<branch>`). Summary: <N> tasks across <W> waves, peak parallelism <P>, all tests green, lint clean.
>
> Finishing options:
>
> 1. **Open a PR** against `<base-branch>` — push the branch and create a PR (I'll draft title + summary).
> 2. **Merge to `<base-branch>`** — fast-forward / merge / rebase your preference, then optionally remove the worktree.
> 3. **Leave as worktree** — keep the branch and worktree as-is for further iteration.
>
> Which?"

For option 1: push the branch, run `gh pr create` with a generated title + summary derived from the plan, return the PR URL.

For option 2: ask which merge style (`--ff-only`, `--no-ff`, rebase), do the merge, then ask whether to `git worktree remove` the worktree.

For option 3: print the worktree path and branch name and stop.

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

This skill exists partly because chaining seven sub-skills wastes context. To keep main lean:

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
| Merge to base brings only some tasks; branch ref lags the real work | An agent ran `git checkout <sha>` on the shared worktree → detached HEAD, later commits left the branch ref behind | Before finishing, assert worktree HEAD == branch tip (see Phase 5); if detached, `git branch -f <branch> <worktree-HEAD>` then merge |
| Editing files in the main checkout instead of the worktree | Worktree gate violated | Stop; move all work into the worktree |
| Skipping the oro-task-reviewer | Review gate skipped — hard-gate violation | Dispatch the `oro-task-reviewer` before marking the task done |
| Skipping the sibling-task touch-sets in the reviewer dispatch | Incomplete reviewer context — the agent's parallel-aware check will silently degrade | Re-dispatch the reviewer with the sibling touch sets included |
| Writing ad-hoc subagent prompts instead of dispatching the named `oro-implementer` / `oro-task-reviewer` agents | Named-agent requirement skipped | Re-dispatch by agent name |
| Main agent fixing reviewer findings itself instead of re-dispatching the oro-implementer | Context pollution | Re-dispatch the oro-implementer with the findings |
| Reusing an old worktree without asking the user | Skipped the resume-or-fresh prompt (Phase 1.2) | Ask: resume or create fresh |
| Parallelizing on file-disjointness alone (graphify skipped) | Cross-edge races will bite | Refresh/initialize the graph, or serialize every multi-task wave |
| Implementer adds an unrequested abstraction, option, or speculative code | Ponytail violation | Re-dispatch with the minimal-code ladder re-emphasized |

- Never verify parent-commit behavior by running `git checkout` on the **shared** worktree (e.g. a reviewer "checking out the parent to verify TDD") — it detaches HEAD, races siblings, and orphans the branch ref so later commits land off-branch. Verify in a throwaway `git worktree add --detach`, overlaying the HEAD test onto the parent — not a plain parent checkout, which reverts the test too and falsely passes.
