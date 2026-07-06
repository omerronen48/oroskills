---
description: Ship one small self-contained feature through planner→coder→tester→reviewer on its own branch (the deliberate fast lane — no TDD contract, no worktree). NOT for bug fixes or chores (use /fix) or multi-phase work (use the brainstorm→plan→execute chain).
argument-hint: <feature request>
---

Run the full feature pipeline for: $ARGUMENTS

Note: /ship is the deliberate **fast lane** — tests are written *after* the code, there is no git worktree, and no graphify context. It does NOT enforce the TDD-before-commit contract that the /dev chain treats as a hard gate. For that discipline, use /dev or the chain.

Execute these stages in order. Do not skip ahead. After each stage, confirm the handoff file exists before starting the next.
0. Setup: wipe stale handoffs (`rm -rf .pipeline && mkdir .pipeline`) so a previous run's files can't satisfy a stage gate, and make sure `.pipeline/` is gitignored (add it if missing). If on the default branch, create and switch to `ship/<slug>` so the work lands on its own branch.
1. Delegate to the oro-planner subagent with the feature request above. Wait for .pipeline/spec.md.
2. If the spec has OPEN QUESTIONS, stop and show them to me. Otherwise delegate to the oro-coder subagent. Wait for .pipeline/changes.md.
3. Delegate to the oro-tester subagent. Wait for .pipeline/test-results.md. If tests failed, stop and show me the failures.
4. Delegate to the oro-reviewer subagent. Show me .pipeline/review.md.
Commit the work on the ship branch (after the review — the reviewer reads the uncommitted diff), then report the final verdict. Do not merge anything. Leave the branch for my morning review.
