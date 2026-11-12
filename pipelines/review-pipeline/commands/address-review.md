---
description: Address feedback on an open PR — fetch failing CI checks, review comments, and merge conflicts; fix each on the PR branch; push. NOT for opening a PR (use /ship or /fix) or reviewing a PR (use the built-in /review).
argument-hint: [<PR number or URL>] [--repo <owner/repo>]
---

Address feedback on PR: $ARGUMENTS

`/address-review` is the **post-PR lane**: every other door ends at "PR opened, never merged" — this one picks up what comes back. It gathers failing checks, review comments, and conflicts into a punch list, fixes each on the PR branch with the ship agents, and pushes. Nothing is merged, no threads are resolved, and nothing is posted to GitHub unless I ask.

## Setup
1. Wipe stale handoffs (`rm -rf .pipeline && mkdir .pipeline`; make sure `.pipeline/` and `.review/` are gitignored). Resolve the PR: explicit number/URL from the arguments, else the PR for the current branch (`gh pr view --json number,headRefName,baseRefName,mergeable,url`). No PR found → stop and ask me which.
2. `gh pr checkout <n>`. Record the branch tip SHA as the **session base** — the final review diffs against it.

## Gather
3. Collect actionable items:
   - **Failing checks:** `gh pr checks <n>`; for each failure pull the log (`gh run view <run-id> --log-failed`) and extract the actual error, not just the check name.
   - **Review comments:** inline comments (`gh api repos/{owner}/{repo}/pulls/<n>/comments`) plus review bodies and issue comments (`gh pr view <n> --json reviews,comments`). Skip resolved threads and pure praise. An ambiguous comment goes on the list flagged `needs-owner-input` — never guess the reviewer's intent.
   - **Conflicts:** if `mergeable` is `CONFLICTING`, "rebase onto <base branch>" becomes item 1.
4. Write `.review/feedback.md`, one line per item:
   `- [ ] N. <title> — source: <check name | comment URL> — status: pending`
   Show me the list and wait for my confirmation (or edits). `needs-owner-input` items stay parked unless I answer them here.

4b. **Record human signals (meta loop, loop-kernel §6).** Count the review comments from step 3 whose author login does not end in `[bot]` (human comments). Append one line to `.dev/memory/history.jsonl` (create the dir if missing):
   `jq -nc --arg d "$(date -u +%FT%TZ)" --argjson pr <n> --argjson k <human comment count> '{date:$d,"event":"pr_review",pr:$pr,human_comments:$k}' >> .dev/memory/history.jsonl`
   For each human comment, append `- [human] <YYYY-MM-DD> PR#<n>: <one-line summary> (<comment URL>)` (the comment's date) to `.dev/memory/human-feedback.md`. Write both files in the main checkout (`git worktree list --porcelain | sed -n '1s/^worktree //p'`), never a worktree. `/gc` turns these into checks so the same comment is never needed twice.

## Fix loop (per item, in order)
5. Conflict item: rebase onto the base branch, resolve, run the full suite. A rebase means the final push needs `--force-with-lease` — note it now.
6. Write `.pipeline/spec.md` from the item (overwrite). For a CI failure the spec is "make this check pass" with the extracted error — reproduce the failure locally first when the check's command can run locally. For a comment the spec is the requested change, quoting the comment verbatim.
7. Delegate to oro-coder (`.pipeline/changes.md`). Run the tests the item touches, then commit on the PR branch, one commit per item: `address-review: <title>`. If the item changed behavior (not a CI-config, docs or style item), run `bash ~/.claude/skills/loop-kernel/mutate-check.sh HEAD~1 "<test command>"`; exit 1 or 3 → delegate to oro-tester in **strengthen** mode with that output (`.pipeline/test-results.md`) and amend the new tests into the item's commit.
8. Any red at steps 5–7: mark the item `failed` in `.review/feedback.md`, **halt**, report the item and the captured output. Leave commits as-is.
9. Green: mark `done`, continue.

## Finish
10. Full test suite must be green. Delegate to oro-reviewer over the session's accumulated work — tell it the session base so it reviews `git diff <session-base>..HEAD`. Show me `.pipeline/review.md`.
11. Push: plain `git push`. If step 5 rebased, ask me before `git push --force-with-lease` — never force-push without confirmation.
12. Report: item → commit map, parked `needs-owner-input` items, the review verdict, and which checks still need CI to confirm. **Do not merge. Do not resolve threads or post PR comments unless I ask.**

Re-invoking `/address-review` skips items already marked `done` in `.review/feedback.md`.
