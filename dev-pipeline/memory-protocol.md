# `.dev/memory/` Protocol

Shared, persistent memory contract for the `/dev` pipeline. Every stage reads
from and writes to this store so context survives across phases and stages.

## Location

Project-local `.dev/memory/`, git-tracked. Created by `/dev` at runtime if
absent.

## Files & writer-domain

- `goals.md` — project goals + non-functional constraints. Writer: project-time.
  Downstream: read-only unless the user changes goals.
- `decisions.md` — **every** decision + **why**, by any stage. Each line tagged
  `[interactive]` / `[auto]` / `[escalated]` and prefixed `phase<N>/<stage>:`.
  The single audit log.
- `lessons.md` — lessons from user corrections. Entry format is three lines: the
  lesson, `**Why:**`, `**How to apply:**`.
- `glossary.md` — domain terms, appended on first definition.
- `progress.md` — phases with status `pending` / `planned` / `done`. Writers:
  `/dev` orchestrator + phase-executor only.

## Read order

At the start of every stage, read in this order:

goals → decisions → glossary → lessons → progress

## Settled-question suppression

Interactive stages must not re-ask anything already fixed in `goals.md`,
`decisions.md`, or `glossary.md`.

## Lesson-detection heuristic

Capture a lesson when the user corrects, rejects a proposal, states a
preference, or says "no, do X instead". Normal answers are not lessons.

## Append-only

Stages append; they do not rewrite existing entries.
