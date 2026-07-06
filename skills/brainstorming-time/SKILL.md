---
name: brainstorming-time
description: "Use when turning an idea, feature, or change request into a reviewable spec — mind map first, then written spec — before any creative work. Replaces superpowers:brainstorming. Hands off to writing-plans-time."
---

# Direct Brainstorming

Turn an idea into a reviewable spec quickly. Same goal as superpowers:brainstorming — never implement without an approved design — but with less back-and-forth, graphify-first context gathering, and a mind map review step before the written spec.

<HARD-GATE>
Do NOT write code, scaffold, or invoke any implementation skill until you have presented the mind map AND the written spec and the user has approved both. This applies regardless of perceived simplicity.
</HARD-GATE>

## When to Use

Use this skill instead of superpowers:brainstorming when:
- The user wants to move quickly and dislikes one-question-at-a-time interrogation
- The repo already has (or should have) a graphify knowledge graph
- A visual mind map of the proposed design would help the user review faster than prose

## Checklist

Create a TodoWrite todo for each item and complete them in order:

1. **Ensure graphify graph exists** — check for `graphify-out/graph.json`; if missing, offer to run `/graphify` and wait for the user before continuing
2. **Gather context via `graphify query`** — do NOT use Read/Grep for general exploration; only fall back to file reads when a query result is insufficient for a specific line/implementation
3. **Ask batched clarifying questions** — one message containing all open questions (use AskUserQuestion for choices); follow up only if answers reveal new unknowns
4. **Propose one recommended approach** — short paragraph, name the main tradeoff, name the alternative you rejected and why (one sentence)
5. **Present mind map** — a Mermaid `mindmap` of the design (root = feature name; branches = components, data flow, interfaces, risks, test surface); ask the user to confirm or correct the shape before writing prose
6. **Write the spec** — save to `docs/specs/YYYY-MM-DD-<topic>.md` (or the project's existing spec location if different); include the mind map at the top
7. **Spec self-review** — scan inline for placeholders, contradictions, ambiguity, scope creep; fix in place
8. **User reviews the spec file** — ask for approval or changes; loop until approved
9. **Hand off to writing-plans-time** — invoke `writing-plans-time` to produce the implementation plan; do not invoke any implementation skill directly

## Graphify Integration (Required)

This is what makes the skill "direct": you read the codebase through the graph, not by opening files one at a time.

**Initialization gate.** Before any context gathering, check `graphify-out/graph.json`. If missing, stop and offer to run `/graphify` — "so I can answer design questions from the knowledge graph instead of reading files one by one" — and **wait** for the reply. If declined, fall back to file reads and note the limitation.

**Querying.** For every "where is X", "how does Y work", "what depends on Z", "what's the current shape of A" question, run:

```bash
graphify query "<question>"
```

Use Read/Grep only when:
- The query result is too high-level and you need an exact line or implementation detail
- The query returns nothing relevant (then both query and read, and consider that the graph may be stale)

**Staleness.** If the repo has changed substantially since the last graph build, suggest `graphify --update` before continuing.

## Mind Map Step (Required)

Before writing the spec, produce a Mermaid `mindmap` of the proposed design and present it for visual review. This is cheaper feedback than a written spec — users can spot a missing branch or a mis-shaped boundary in seconds.

**Minimum branches:**
- Components / modules
- Data flow (inputs → transforms → outputs)
- External interfaces (APIs, files, events)
- Risks / open questions
- Test surface

**Example shape:**

```mermaid
mindmap
  root((Feature X))
    Components
      Parser
      Validator
      Writer
    Data flow
      Input: CLI args
      Transform: normalize
      Output: JSON file
    Interfaces
      stdin/stdout
      fs read/write
    Risks
      Large inputs streaming
      Path traversal
    Tests
      Unit: validator
      Integration: end-to-end CLI
```

After presenting the mind map, ask one direct question: **"Does this shape match what you want, or is a branch missing/wrong?"** Iterate the mind map (not the prose) until the user confirms the shape. Only then write the spec.

Apply "does this need to exist?" to every proposed component; cut scope that fails it before it reaches the spec.

## Spec File

- Default path: `docs/specs/YYYY-MM-DD-<topic>.md` (user preferences override)
- First section of the spec is the approved Mermaid mind map
- Then: purpose, scope, architecture, data flow, interfaces, error handling, testing, open questions
- Scale each section to its complexity — a few sentences is fine when the topic is small
- Commit the spec to git if the repo uses git

### Self-review (inline, no separate pass)

Before showing the user the spec file path:

- Any `TBD`, `TODO`, or vague requirement? Replace or remove.
- Any section that contradicts another? Reconcile.
- Any requirement readable two ways? Pick one explicitly.
- Is the scope still one implementation plan's worth of work? If not, flag decomposition.

Fix in place. Don't loop on self-review.

### User review gate

> "Spec written to `<path>` and mind map approved. Please review the file and tell me if you want changes before I hand off to `writing-plans-time`."

Loop until the user approves, then invoke `writing-plans-time`.

## Red Flags — Stop and Course-Correct

- Calling Read/Grep before running a single `graphify query`
- `graphify-out/` is missing and you proceeded anyway
- Writing the spec without showing a mind map
- Asking the user one question at a time instead of batching
- Proposing 2–3 approaches with full tradeoff tables
- Invoking an implementation skill before user approves the written spec

## Memory protocol (when run under /dev)

When this skill runs inside a `/dev` loop, read `.dev/memory/` **first**, before gathering context or asking clarifying questions:

- **Suppress re-asking** anything already settled in `goals.md`, `decisions.md`, or `glossary.md`. Do not re-ask settled questions — treat those decisions as fixed inputs to the spec.
- Append new design decisions made during the brainstorm to `.dev/memory/decisions.md` tagged `[interactive]` (see `~/.claude/memory-protocol.md` for the full entry format, including the `phase<N>/<stage>:` prefix), and append any new domain terms to `.dev/memory/glossary.md`.
- **Design mockups.** If `.dev/memory/design.md` exists (written when `/dev` was invoked with `--design`), read it too — it is outside the goals→…→progress read chain, so name it explicitly. Treat the mockup manifest as a first-class **UI constraint**: derive the spec's UI sections and the mind map's screens/components branch from the listed mockup components, not from invented layout. No-op when `design.md` is absent.

See `~/.claude/memory-protocol.md` for the file formats. This step is a **no-op when `.dev/memory/` is absent** — the skill still runs standalone without it.

## Autonomous mode (under `/dev --auto`)

When the `/dev` orchestrator invokes this skill in autonomous mode, do not wait for the
user at any gate. Read `.dev/memory/` first, then clear each gate as follows:

1. **graphify-missing gate** — do not offer `/graphify` and do not wait. Fall back to
   targeted file reads silently and note the limitation in the spec. If `graphify` is
   installed, you may run `graphify --update` non-interactively.
2. **Clarifying questions** — answer from the milestone text + `.dev/memory/`
   (`goals`/`decisions`/`glossary`). For a question with no answer there: if the choice is
   **reversible**, pick the sensible default and append it to `decisions.md` tagged `[auto]`;
   if **irreversible**, do not guess — return an `ESCALATE:` block to the orchestrator (it
   parks the fork to `escalations.md` and halts).
3. **Mind-map confirm** — generate the mind map, self-confirm, include it at the top of the
   spec; do not wait for an "OK?".
4. **Spec approval + `<HARD-GATE>`** — the inline self-review replaces human approval. The
   HARD-GATE is satisfied by "mind map + self-reviewed spec produced". Then hand off to
   `writing-plans-time` (also in autonomous mode).

All new decisions/glossary terms are appended to `.dev/memory/` per the memory protocol.
This section is inert when the skill runs standalone (not under `/dev --auto`).
