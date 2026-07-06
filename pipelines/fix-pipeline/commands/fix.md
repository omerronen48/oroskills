Run a batch of small fixes for: $ARGUMENTS

`/fix` is the **punch-list lane**: many small fixes from one blurb — not a single feature (that's `/ship`) and not a roadmap of features (that's `/dev`). It decomposes the blurb, ships each fix lean, and after every fix runs the full test suite so a later fix can't silently break an earlier one. Any red halts the loop. Nothing is merged.

## Decompose
1. Parse the blurb above into an ordered list of atomic fixes. Sequence fixes that touch the same file; keep independent fixes in input order. Write `.fix/roadmap.md`, one line per fix:
   `- [ ] N. <title> — files: <paths> — status: pending`
2. If the blurb yields only one fix, say so and suggest `/ship` instead; proceed only if I confirm.
3. Show me `.fix/roadmap.md` and wait for my confirmation (or edits) before looping.

## Baseline
4. Wipe stale handoffs (`rm -rf .pipeline && mkdir .pipeline`; make sure `.pipeline/` and `.fix/` are gitignored). Run the full test suite once and record the base branch. If the suite is already red, stop and report — the regression guard needs a green baseline. (I may re-invoke to override.)

## Per-fix loop (in roadmap order), for fix N:
5. `git checkout -b fix/N-<slug>` off the **previous fix's branch** (off the base branch for N=1). Branches stack so the regression guard sees every prior fix.
6. Write `.pipeline/spec.md` from fix N's roadmap entry (overwrite). This replaces the planner — the roadmap entry is the mini-spec.
7. Delegate to the oro-coder subagent. Wait for `.pipeline/changes.md`.
8. Delegate to the oro-tester subagent. Wait for `.pipeline/test-results.md`. Fix N's own tests must pass — this is "shipped properly".
9. **Regression guard:** run the full test suite (the same command oro-tester used). It must be green.
10. On any red at steps 7–9: mark fix N `failed` in `.fix/roadmap.md`, **halt**, and report the fix, the failing stage (ship vs regression), and the captured output. Leave the branches as-is. Do not attempt the remaining fixes.
11. On green: commit on `fix/N-<slug>`, mark fix N `done` in `.fix/roadmap.md`, continue to the next fix.

## Finish
12. After all fixes ship green, delegate to the oro-reviewer subagent once over the accumulated diff — tell it the base branch from step 4 so it reviews `git diff <base>...HEAD` (everything is committed on the stacked branches; plain `git diff` would be empty). Show me `.pipeline/review.md`.
13. Report the summary: fixes shipped, branch names, and the review verdict. **Do not merge** — leave the stacked branches for my review.

Re-invoking `/fix` skips entries already marked `done` in `.fix/roadmap.md`.
