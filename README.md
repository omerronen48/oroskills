# oroskills

A set of Claude Code skills for moving from project idea → roadmap → spec → plan → executed code with less ceremony than the standard `superpowers` chain. Graphify-first, parallelization-aware, TDD-enforced.

## The Skills

| Skill | What it does |
|---|---|
| **project-time** | Turns a project-sized idea into a technical roadmap with milestones. Grill-me style one-question-at-a-time interview with recommended answers; resolves architecture, stack, scope, and non-functional targets up front so feature-level brainstorms stop re-litigating them. |
| **brainstorming-time** | Turns an idea (or one milestone from a roadmap) into a reviewable spec. Uses graphify for codebase context and produces a mind map before the written spec. |
| **writing-plans-time** | Turns an approved spec into an implementation plan with a File Edit Manifest up front and tasks grouped into parallel-executable waves. |
| **executing-plan-time** | Runs an approved plan end-to-end: worktree setup, parallel implementer subagents, TDD-before-commit, spec + code-quality review, branch finishing. |
| **caveman** | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Trigger with "caveman mode" / "/caveman". Sourced from [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md). |

`brainstorming-time`, `writing-plans-time`, and `executing-plan-time` are drop-in replacements for the corresponding `superpowers:*` skills (`brainstorming`, `writing-plans`, `executing-plans` + the worktree/subagent/TDD/verification/finishing chain). `project-time` sits one stage above the chain and has no `superpowers:*` counterpart — invoke it when starting a new project or large multi-feature initiative.

## Install

Clone the repo and run the install script:

```bash
git clone https://github.com/<you>/oroskills.git ~/oroskills
cd ~/oroskills
./install.sh
```

Options:

```
./install.sh              # symlink into ~/.claude/skills (global)
./install.sh --project    # symlink into ./.claude/skills (project-scoped)
./install.sh --copy       # copy files instead of symlinking
./install.sh --force      # overwrite existing skills with the same name
```

Verify:

```bash
ls ~/.claude/skills/
# brainstorming-time  caveman  executing-plan-time  project-time  writing-plans-time
```

Restart Claude Code (or start a new session) and the skills will appear in the available-skills list.

### Project-scoped install

To install for a single project instead of globally, use `<project>/.claude/skills/` in place of `~/.claude/skills/`.

## Requirements

- **graphify** — all three skills use `graphify query` as their primary source for codebase context. Install graphify and run `/graphify` once per repo; the skills will offer to initialize it if `graphify-out/graph.json` is missing.
- **git** — `executing-plan-time` always runs work inside a git worktree.

## Usage

The skills auto-trigger from their descriptions, but you can invoke them explicitly:

```
Use project-time to scope out <project idea>.
Use brainstorming-time to spec out <idea or milestone Mn>.
Use writing-plans-time on <spec file>.
Use executing-plan-time to run <plan file>.
```

The intended chain is **project-time → brainstorming-time → writing-plans-time → executing-plan-time**. `project-time` is optional and only used at the start of a new project or large initiative; for a single feature inside an existing codebase, start at `brainstorming-time`. Each stage hands off to the next; don't skip stages.

## Layout

```
project-time/
  SKILL.md
brainstorming-time/
  SKILL.md
writing-plans-time/
  SKILL.md
  plan-template.md
executing-plan-time/
  SKILL.md
  implementer-prompt.md
  spec-reviewer-prompt.md
  code-quality-reviewer-prompt.md
caveman/
  SKILL.md
```
