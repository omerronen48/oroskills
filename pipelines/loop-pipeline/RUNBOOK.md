# Loop Pipeline — Operator Runbook

## Prerequisites

- Target repository is on GitHub and accessible to your `gh` session.
- `gh` CLI authenticated (`gh auth status`).
- Claude GitHub App installed on the target repo (required for cloud routines).
- `oroskills` installed via `install.sh`.
- The `loop-settings.json` deny-merge template merged into the target repo's `.claude/settings.json` (prevents both loops from running `gh pr merge`).

## One-Time Setup

Bootstrap issue labels:

```bash
# dry-run first to preview label changes
/loop-manager --dry-run
# apply when output looks correct
/loop-manager
```

Confirm the taxonomy labels exist on the repo before proceeding.

## Grade Before You Schedule

Run the Manager in dry-run mode against the real backlog and review output:

```bash
/loop-manager --dry-run
```

Passing grade: high-risk or ambiguous issues stay `needs:human`; obviously-safe issues get `agent:ready`; all reasons are specific.  
**Only proceed to scheduling after a passing grade.**

## Scheduling

Routines run a freeform prompt in the cloud; the prompt must name the repo and instruct the routine to follow the appropriate procedure.

### Manager routine — recommended cadence: hourly

Use `/schedule` with this prompt template:

```
In repo <owner/repo>, follow the /loop-manager command procedure in apply mode:
triage open issues, apply risk/type labels and agent:ready/needs:human, and post
Agent Assessment comments. Do not edit code, open PRs, or merge.
```

### Worker routine — recommended cadence: every 4 h

Cadence is operator-tunable; Worker throughput is bounded by human review speed (each PR requires a human merge before the next issue can ship).

```
In repo <owner/repo>, follow the /loop-worker command procedure: take one
agent:ready+risk:low issue, run the ship pipeline, and on VERDICT: SHIP open a PR
and comment the link. Never merge — a human merges.
```

Schedule both via `/schedule`:

```bash
/schedule --cadence "0 * * * *"   --prompt "<manager prompt above>"
/schedule --cadence "0 */4 * * *" --prompt "<worker prompt above>"
```

## Operating Controls

**Pause a routine** — disable the scheduled trigger in your scheduler UI or remove the `/schedule` entry; the in-flight run completes safely.

**Stop a routine** — delete the schedule entry; no further runs will start.

**Grant apply mode** — enable the Worker routine only after the Manager dry-run produces a passing grade (see above).

**Audit trail** — read Agent Assessment comments on each issue (posted by loop-manager) and review open PRs posted by loop-worker. The deny-merge rule in `loop-settings.json` ensures neither loop can call `gh pr merge`; all merges are human-initiated.

## Limitations & Safety

- **No per-routine tool isolation** in Claude Code today. The enforceable boundary is the deny-merge rule in `loop-settings.json`; per-loop distinction relies on the read-only `oro-triager` role, prose instructions, and human PR review.
- **Isolation** between loops is procedural, not enforced at the tool level — treat it as a research preview subject to change.
- **Limitation**: routines share the same tool permissions; tighter isolation requires running each loop from a separate checkout with its own `.claude/settings.json`.
- Optional hardening: create a second repo checkout with a stricter settings file scoped to that loop's allowed tools.
- Routines are a research preview and behaviour may change between oroskills releases.
