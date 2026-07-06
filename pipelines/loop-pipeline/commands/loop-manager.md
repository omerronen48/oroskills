---
description: Triage open GitHub issues into the autonomous agent loop — dispatches the read-only oro-triager per issue and applies risk/type/agent:ready labels. Control plane for /loop-worker. NOT for doing the fixes themselves (use /fix or /ship locally).
argument-hint: [--dry-run] [--retriage] [--repo <owner/repo>]
---

# /loop-manager

Orchestrate backlog triage for the current repo. Invoked as `/loop-manager $ARGUMENTS` with flags: `--dry-run`, `--retriage`, `--repo <owner/repo>`.

## Design card
- **JOB:** triage the open GitHub backlog — classify risk/type, route safe work.
- **INPUTS:** open issues (titles, bodies, labels) via `gh`.
- **ALLOWED:** create labels, add labels to issues, post/edit Agent Assessment comments.
- **FORBIDDEN:** never edit code, never open/close PRs, never merge.
- **OUTPUT:** every triaged issue carries risk/type + (`agent:ready` | `needs:human`) and one Agent Assessment comment.
- **EVALUATION:** a dry-run keeps high-risk work `needs:human`, marks obviously-safe work `agent:ready`, and gives specific reasons.

## Procedure

### 1. Parse flags

- `--dry-run` — preview only; write nothing to GitHub.
- `--retriage` — re-assess issues already carrying an Agent Assessment comment (overrides skip logic).
- `--repo <owner/repo>` — target repo; default: current repo from `gh` context.

Default (no flag) = **apply**.

### 2. Preflight

Run `gh auth status` to confirm authentication. Confirm repo context resolves. On any failure: STOP, report the error, write nothing.

### 3. Bootstrap labels (idempotent)

For each taxonomy label, run:

```
gh label create <name> --color <hex> --description <description>
```

Ignore "already exists" errors. Taxonomy:

| Label | Color | Description |
|---|---|---|
| `risk:low` | `#0e8a16` | Low risk — safe for agent |
| `risk:medium` | `#e4a400` | Medium risk — review before agent |
| `risk:high` | `#d93f0b` | High risk — human only |
| `type:bug` | `#ee0701` | Bug report |
| `type:feature` | `#84b6eb` | Feature request |
| `type:docs` | `#cfd3d7` | Documentation |
| `type:test` | `#bfd4f2` | Test coverage |
| `type:refactor` | `#fef2c0` | Refactor |
| `type:chore` | `#c5def5` | Chore / maintenance |
| `agent:ready` | `#0075ca` | Safe for autonomous agent execution |
| `needs:human` | `#e4e669` | Requires human decision |

### 4. Fetch

```
gh issue list --state open --json number,title,body,labels,comments
```

### 5. Filter

Skip any issue that already has a comment containing the marker `<!-- oro-triager:v1 -->`, unless `--retriage` is set.

### 6. Per-issue: dispatch oro-triager

For each remaining issue, dispatch the `oro-triager` agent with the issue's number, title, body, and current labels. Receive back the Agent Assessment body (must include `<!-- oro-triager:v1 -->` marker, a risk label, a type label, a routing label, and a reasoning section).

### 7. Apply (default mode)

```
gh issue edit <n> --add-label <risk>,<type>,<routing>
gh issue comment <n> --body <assessment>
```

On `--retriage`, edit the existing marked comment in place rather than appending a new one.

### 8. Dry-run (`--dry-run`)

Print, per issue, the exact labels and comment body it **WOULD** write. Change nothing. This is the operator grading mode — run it first and confirm judgment before applying or scheduling.

### 9. Error handling

- If `oro-triager` returns an unparseable or incomplete assessment: SKIP that issue (no labels, no comment), log it, and continue. A bad classification must **never** default an issue to `agent:ready`.
- If apply half-fails (label applied but comment fails, or vice versa): log the issue number and continue. A subsequent `--retriage` run will complete the missing half.

---

The Manager coordinates with the Worker only through the `agent:ready` + `risk:low` labels; it never merges — a human merge is the gate. The `gh issue` workflow and `gh label create` commands are the only write operations this agent is permitted to perform.
