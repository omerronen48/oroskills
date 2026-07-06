---
description: Work one triaged GitHub issue end-to-end — claim an agent:ready + risk:low issue, isolate in a worktree, run the ship pipeline, open a PR (never merge). Pairs with /loop-manager. NOT for local interactive work.
argument-hint: [--dry-run] [--repo <owner/repo>]
---

# /loop-worker

Run as: `/loop-worker $ARGUMENTS`

Supported flags: `--dry-run` (preview selected issue and intended actions; no claim, no worktree, no PR), `--repo <owner/repo>` (default: current repo inferred from `gh repo view`).

## Design card

- **JOB:** take one `agent:ready`+`risk:low` issue and produce one reviewed pull request.
- **INPUTS:** open issues (number, title, body, labels) via `gh`; the ship pipeline's review verdict.
- **ALLOWED:** add/remove labels, comment on issues, create branches/worktrees, commit, push, create PRs.
- **FORBIDDEN:** never merge a PR — a human merge is the gate. Never act on anything above `risk:low`.
- **OUTPUT:** on SHIP, one PR on branch `agent/issue-<n>` + a link comment; otherwise the issue routed to `needs:human` with the blocker.
- **EVALUATION:** exactly one PR per ready issue; a re-run opens no duplicate; failed/blocked issues never produce a PR.

## Procedure

1. **Parse flags:** `--dry-run` previews selected issue and intended actions; no claim, no worktree, no PR is created. `--repo <owner/repo>` overrides the default repo.

2. **Preflight:** run `gh auth status` to verify authentication; confirm repo context with `gh repo view`; verify the working tree is clean enough to add a worktree (`git status --porcelain`). On any failure: STOP and report the error; change nothing.

3. **Bootstrap claim label (idempotent):** run `gh label create "agent:in-progress" --color "0075ca" --description "Claimed by a Worker loop"` — ignore "already exists" errors.

4. **Select one issue:** run `gh issue list --state open --label "agent:ready" --label "risk:low" --json number,title,body,labels` to get candidates. Drop any issue that already carries `agent:in-progress`. Drop any issue that already has an open PR targeting its branch (check via `gh pr list --head "agent/issue-<n>" --state open`). Take the first remaining issue. If none qualify: report "no eligible issues" and stop.

5. **Claim:** `gh issue edit <n> --add-label "agent:in-progress"` — do this before any long-running work so concurrent workers see it claimed.

6. **Isolate:** `git worktree add -b agent/issue-<n> <worktree-path>` and operate inside that worktree for all subsequent steps.

7. **Drive the ship pipeline** inside the worktree, with the feature request set to `Issue #<n>: <title>` plus the issue body. Dispatch ship agents in sequence:
   - `oro-planner` → produces `.pipeline/spec.md`; if the spec contains `OPEN QUESTIONS` → early stop (blocker: unresolved questions).
   - `oro-coder` → produces `.pipeline/changes.md`.
   - `oro-tester` → produces `.pipeline/test-results.md`; if tests fail → early stop (blocker: failing tests).
   - `oro-reviewer` → produces `.pipeline/review.md` containing `VERDICT: SHIP | NEEDS WORK | BLOCK`.

8. **Route on `VERDICT`:**
   - **`VERDICT: SHIP`:** stage all code changes (exclude `.pipeline/`), commit referencing the issue, run `git push -u origin agent/issue-<n>`, run `gh pr create --base <default-branch> --head agent/issue-<n>` with title and body drawn from the issue and reviewer summary, then run `gh issue comment <n>` with the PR link, then run `gh issue edit <n> --remove-label "agent:in-progress" --remove-label "agent:ready"` — remove both `agent:in-progress` and `agent:ready` — the open PR is the record; a human re-adds `agent:ready` to request a retry. (The open-PR guard remains as belt-and-suspenders.)
   - **Non-SHIP or early stop:** open NO PR. Run `gh issue comment <n>` with the specific blocker (reviewer findings / open questions / failing tests). Run `gh issue edit <n> --remove-label "agent:ready" --remove-label "agent:in-progress" --add-label "needs:human"`.

9. **Dispose:** run `git worktree remove <worktree-path>` once done — EXCEPT if `git push` or `gh pr create` failed after a clean SHIP verdict: in that case keep the worktree, comment the push/create failure on the issue, leave `agent:in-progress` for a human to resolve, and log the error.

---

The Worker consumes `agent:ready`+`risk:low` issues handed off by the Manager and coordinates exclusively through GitHub labels and comments. It opens pull requests but never merges — the human merge is the gate, ensuring that no automated path can land code without a human decision.
