Run the continuous roadmap-driven dev loop for: $ARGUMENTS

You are the orchestrator. Run the stages below in order. Do not skip ahead. After each stage, confirm its handoff artifact exists before advancing. The orchestrator owns every `progress.md` status update — no other stage writes phase status.

## 1. Bootstrap

Ensure `.dev/memory/` exists. If absent, create the skeleton files — `goals.md`, `decisions.md`, `lessons.md`, `glossary.md`, `progress.md` — per the contract in `dev-pipeline/memory-protocol.md`. Then read `progress.md`.

## 2. Roadmap

If the idea is multi-feature and no roadmap exists yet, run the `project-time` skill (interactive). It writes `goals.md`, seeds `decisions.md`/`glossary.md`, and seeds `progress.md` phases as `pending`. If the idea is a single feature, `progress.md` gets one phase.

## 3. Phase loop

Repeat for the next non-`done` phase in `progress.md`:

a. Read `.dev/memory/` (goals → decisions → glossary → lessons → progress). This feeds context and suppresses re-asking questions already settled there.
b. Run the `brainstorming-time` skill (interactive, in the main session) → produces a spec file. Confirm the spec exists before continuing.
c. Run the `writing-plans-time` skill (in the main session) → produces a plan file. Confirm the plan exists before continuing.
d. Set this phase to `planned` in `progress.md` and persist any new decisions/glossary terms.
e. Dispatch the `phase-executor` agent with: the plan path, memory pointers, and the phase id. Await its ≤10-line summary. Execution runs unattended in that subagent's isolated context — this is what keeps the main session lean across phases.
f. If the summary contains an `ESCALATE:` block → STOP, surface it to the user, record the user's resolution in `decisions.md` tagged `[escalated]`, then resume. The phase-executor escalates only irreversible forks; it auto-decides reversible ones on its own (full policy lives in the phase-executor agent).
g. Set this phase to `done` in `progress.md` and record the summary. Advance to the next non-`done` phase.

## 4. Final report

When no `pending`/`planned` phase remains, report. Do NOT merge unless the user authorized it — executing-plan-time's finishing handoff governs integration per phase.

## Resume

Re-invoking `/dev` reads `progress.md` and continues at the first non-`done` phase. Completed (`done`) phases are never re-run. An escalation from a prior run that was resolved is recorded in `decisions.md`; the phase-executor escalates irreversible forks and auto-decides reversible ones, so a resumed phase does not re-ask settled questions.

## Context

Because each phase executes inside the `phase-executor` subagent — fresh context, discarded on return — the main session holds only loop state plus one summary per phase. The model does NOT self-trigger `/clear` or `/compact`; state lives in `.dev/memory`, so any harness auto-compact is lossless.

## Decision logging

Every decision — `[interactive]`, `[auto]`, and `[escalated]` — is logged to `decisions.md` so the user can review the full trail.
