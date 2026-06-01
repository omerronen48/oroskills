# oroskills

A trio of Claude Code skills for moving from idea → spec → plan → executed code with less ceremony than the standard `superpowers` chain. Graphify-first, parallelization-aware, TDD-enforced.

## The Skills

| Skill | What it does |
|---|---|
| **brainstorming-time** | Turns an idea into a reviewable spec. Uses graphify for codebase context and produces a mind map before the written spec. |
| **writing-plans-time** | Turns an approved spec into an implementation plan with a File Edit Manifest up front and tasks grouped into parallel-executable waves. |
| **executing-plan-time** | Runs an approved plan end-to-end: worktree setup, parallel implementer subagents, TDD-before-commit, spec + code-quality review, branch finishing. |

Each skill is a drop-in replacement for the corresponding `superpowers:*` skill (`brainstorming`, `writing-plans`, `executing-plans` + the worktree/subagent/TDD/verification/finishing chain).

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
# brainstorming-time  executing-plan-time  writing-plans-time
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
Use brainstorming-time to spec out <idea>.
Use writing-plans-time on <spec file>.
Use executing-plan-time to run <plan file>.
```

The intended chain is **brainstorming-time → writing-plans-time → executing-plan-time**. Each stage hands off to the next; don't skip stages.

## Layout

```
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
```
