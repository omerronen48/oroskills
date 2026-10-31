---
description: Ship one small self-contained feature through planner→coder→tester→reviewer on its own branch (the deliberate fast lane — tests-first on the loop-kernel contract, no worktree). NOT for bug fixes or chores (use /fix) or multi-phase work (use the brainstorm→plan→execute chain).
argument-hint: <feature request>
---

Run the full feature pipeline for: $ARGUMENTS

Note: /ship is the deliberate **fast lane** — there is no git worktree and no graphify context, but tests are written BEFORE the code (by oro-tester) and it runs on the loop-kernel contract.

This pipeline runs on the `loop-kernel` contract (`~/.claude/skills/loop-kernel/SKILL.md`); section numbers below refer to it.

Execute these stages in order. Do not skip ahead. After each stage, confirm the handoff file exists before starting the next.
0. Setup: wipe stale handoffs (`rm -rf .pipeline .loop && mkdir .pipeline .loop`) so a previous run's files can't satisfy a stage gate, and make sure `.pipeline/` and `.loop/` are gitignored (add if missing). If on the default branch, create and switch to `ship/<slug>`. Record the base SHA.
1. Delegate to the oro-planner subagent with the feature request above. Wait for .pipeline/spec.md and .loop/goal.md (§1).
2. If the spec has OPEN QUESTIONS, stop and show them to me. Run the critic (§1); blocking gaps → planner revises (max 2 rounds). Then freeze: `touch .loop/active`.
3. **Tests first (§8):** delegate to the oro-tester subagent in **test-first** mode (goal.md + spec only). Wait for .pipeline/test-results.md showing the new tests red for the right reason. Commit the tests, then lock them: `shasum -a 256 <test files> >> .loop/test-lock; git rev-parse HEAD > .loop/lock-ref`.
4. Delegate to the oro-coder subagent with the spec, goal.md and `lessons-for.sh` output (§1). It must make the locked tests pass without touching them. Wait for .pipeline/changes.md. Commit.
5. Metric (§2): run the tests, goal.md done-criteria, and `test-guard.sh "$(cat .loop/lock-ref)"`.
6. Delegate to the oro-reviewer subagent as a fresh, blind reviewer (§3), passing any test-guard `warn:` lines. Wait for .pipeline/review.md.
7. Any red in 4-6 (failed tests, metric finding, NEEDS WORK) → retry (§4): fresh oro-coder with the findings and diagnoses, then repeat 4-6. Max 3 attempts total. A `TEST-DISPUTE:` in changes.md → handle per §8 (show it to me). BLOCK or cap hit → stop and show me the last findings, then go to step 10.
8. On SHIP: run mutate-check (§2 step 3; the test author is oro-tester in strengthen mode).
9. Run Climb (§5); commit any climb changes.
10. Run Distill (§6) and show me the proposals to approve. `rm -f .loop/active`.
Report the final verdict, climb score, any `[reward-hack]` findings, lessons added and proposals. Do not merge anything. Leave the branch for my review.
