---
description: Fix bugs and small chores — a single bug (repro-test-first) or a punch-list of independent small fixes, each shipped on stacked branches with a full-suite regression guard. NOT for a new feature (use /ship) or a multi-feature roadmap (use /dev).
argument-hint: <bug description or list of small fixes>
---

Run a batch of small fixes for: $ARGUMENTS

`/fix` is the **bug-and-chore lane**: a single bug or a punch-list of small fixes from one blurb — not a feature (that's `/ship`) and not a roadmap of features (that's `/dev`). It decomposes the blurb, ships each fix lean, and after every fix runs the full test suite so a later fix can't silently break an earlier one. Any red halts the loop. Nothing is merged.

## Decompose
1. Parse the blurb above into an ordered list of atomic fixes. Sequence fixes that touch the same file; keep independent fixes in input order. Write `.fix/roadmap.md`, one line per fix:
   `- [ ] N. <title> — files: <paths> — status: pending`
2. **Single-bug mode:** if the blurb yields only one fix and it's a bug, don't punt — run the loop once for it with repro-first discipline: oro-tester writes the failing repro test first (step 7a, test-first mode); the coder only fixes until it passes. Skip the roadmap confirmation gate. If the single item is a *feature* rather than a bug, suggest `/ship`; proceed only if I confirm.
3. Show me `.fix/roadmap.md` and wait for my confirmation (or edits) before looping.

## Baseline
4. Bootstrap missing `.factory/` files and commit them on the base branch (loop-kernel §0) before anything else. Wipe stale handoffs (`rm -rf .pipeline .loop && mkdir .pipeline .loop`; make sure `.pipeline/`, `.fix/` and `.loop/` are gitignored). Run the full test suite once and record the base branch. If the suite is already red, stop and report — the regression guard needs a green baseline. (I may re-invoke to override.) Before coding, write one `.fix/spec-N.md` mini-spec per roadmap item. Then write `.loop/goal.md` (loop-kernel §1): end state = every roadmap fix done; done-criteria = the full test suite command **plus one runnable Behavior/reproduction command per fix** that exercises the real affected CLI, endpoint, UI, or library interface; rubric = correctness, minimal diff, regression safety. Run `oro-critic` over the goal and all mini-specs; blocking gaps are revised and re-reviewed (max 2 rounds). Only after CLEAR, freeze with `touch .loop/active`.

## Per-fix loop (in roadmap order), for fix N:
5. `git checkout -b fix/N-<slug>` off the **previous fix's branch** (off the base branch for N=1). Branches stack so the regression guard sees every prior fix.
6. Copy `.fix/spec-N.md` to `.pipeline/spec.md` (overwrite). The critic has already checked this mini-spec against the frozen batch goal.
7a. Before step 7 (tests come first, loop-kernel §8): delegate to the oro-tester subagent in **test-first** mode with fix N's spec + goal.md. It writes the repro/acceptance test and shows it red. Commit it and lock it (`shasum -a 256 <test files> >> .loop/test-lock; git rev-parse HEAD > .loop/lock-ref`). Step 7's oro-coder must make it pass without touching it.
7. Delegate to the oro-coder subagent. Wait for `.pipeline/changes.md`.
8. Run fix N's locked tests. They must pass.
9. **Regression guard + metric (loop-kernel §2):** run `bash ~/.claude/skills/loop-kernel/factory-check.sh "$(cat .loop/lock-ref)" ""` (.factory/checks — the full suite — plus test-guard; the batch goal is checked once at the end). Both must be clean. A `TEST-DISPUTE:` from the coder → handle per loop-kernel §8.
10. On any red at steps 7-9 → retry (loop-kernel §4): fresh oro-coder with the failing output, repeat 7-9. Max 3 attempts per fix. On the 3rd failure: mark fix N `failed` in `.fix/roadmap.md`, **halt**, report the fix, failing stage and output, then run step 13b (Distill). Leave the branches as-is.
11. On green: commit on `fix/N-<slug>`, mark fix N `done` in `.fix/roadmap.md`, continue to the next fix.

## Finish
12. After the last fix, run `bash ~/.claude/skills/loop-kernel/factory-check.sh <base> .loop/goal.md` (base branch from step 4): every fix's behavior command must pass together. Red → treat as a NEEDS WORK finding below. After all fixes ship green, delegate to the oro-reviewer subagent once, fresh and blind (loop-kernel §3), over the accumulated diff — tell it the base branch from step 4 so it reviews `git diff <base>...HEAD`. NEEDS WORK → one fresh oro-coder pass on the last fix branch with the findings, then re-review (counts against a max of 3 review attempts). Then run mutate-check (§2 step 3; test author = oro-tester in strengthen mode) and Climb (§5) against the base on the last fix branch. Show me `.pipeline/review.md` and the climb score.
13b. Run Distill (loop-kernel §6), show me the proposals, and `rm -f .loop/active` on every orderly ending.
13. Report the summary: fixes shipped, branch names, and the review verdict. **Do not merge** — leave the stacked branches for my review.

Re-invoking `/fix` skips entries already marked `done` in `.fix/roadmap.md`.
