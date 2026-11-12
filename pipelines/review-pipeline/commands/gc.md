---
description: Weekly garbage collection for the software factory — scorecard of the last 7 days, then the distiller turns repeated human feedback and findings into proposed checks (mechanical first) for you to approve. NOT for fixing a PR (use /address-review) or a bug (use /fix).
argument-hint: [--since YYYY-MM-DD]
---

Run garbage collection for: $ARGUMENTS

`/gc` is the factory's **meta loop**: once a week, look at what humans had to correct and make sure the factory never needs that correction again. Schedule it with the `/schedule` skill (weekly, in this repo). Nothing is applied without my approval.

1. **Window:** `--since <date>` from the arguments, else 7 days ago (`date -u -v-7d +%F 2>/dev/null || date -u -d '7 days ago' +%F`).
2. **Scorecard:** `bash ~/.claude/skills/loop-kernel/scorecard.sh .dev/memory/history.jsonl --since <date>`. Show it to me, and the previous week's numbers if `.dev/memory/scorecard.md` has them. Append this week's block to `.dev/memory/scorecard.md` with the date.
3. **Distill:** dispatch `oro-distiller` in **gc mode** with the `.dev/memory/human-feedback.md` lines whose `<YYYY-MM-DD>` is on or after the window start (`awk -v s=<date> '$3 >= s' .dev/memory/human-feedback.md`; pass none if the file does not exist yet), `.dev/memory/history.jsonl`, `.dev/memory/lessons.md`, and the oroskills repo path (`readlink -f ~/.claude/skills/loop-kernel/..` → repo `skills/`; none if not a symlink install). Proposals land in `.dev/proposals/`.
4. **Approve:** list each proposal (file + one-line rationale). Ask approve/reject per item. Apply approved ones with `git apply` in the repo the diff targets (target project or oroskills) and commit each as `chore(gc): <rationale>`. Report apply failures; leave the file. Never apply anything I did not approve.
5. **Report:** scorecard deltas vs last week, lessons added, proposals applied/rejected. Interventions per run and human comments per PR should trend down; say plainly if they did not.
