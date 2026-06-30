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
  project-time **or roadmap import** seeds the initial phase list; thereafter
  only the `/dev` orchestrator updates phase status.
- `usage.md` — rate-limit window metadata for the headless backstop. Fields:
  `window_start` (ISO8601 timestamp when the current 5-hour window began); plus,
  when the guard pauses at 95%, `paused_at` and `resume_scheduled_for`. The
  resumed clean session uses `resume_scheduled_for` as the new `window_start`,
  then clears both. Writer: `/dev` orchestrator only.
  **This file is NOT part of the goals→decisions→glossary→lessons→progress
  read-order chain.** It is read only by the usage-window guard logic, never
  by brainstorm/plan/execute stages.
- `design.md` — design-mockup pointer + manifest for UI-aware phases. Writer:
  `/dev` orchestrator at bootstrap (only when `--design <ref>` is given).
  Fields: **source** (`kind: uuid | folder` and the `ref`), **resolved-at**
  (timestamp/note for folder-ref staleness), and **manifest** (a list of
  `component → file` entries: each mockup component, its source path — remote
  project path for `uuid`, local relative path for `folder` — and a one-line
  description where available). Component bodies are fetched on demand by
  readers, not inlined. **This file is NOT part of the
  goals→decisions→glossary→lessons→progress read-order chain** — it is read
  only by design-aware readers (brainstorming-time, oro-phase-executor), never
  by the general stage read order. `design.md` is absent when no `--design`
  ref was given.

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
