# Graph Report - .  (2026-06-17)

## Corpus Check
- 13 files · ~20,311 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 102 nodes · 194 edges · 7 communities
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_dev Loop, Memory & Roadmap|/dev Loop, Memory & Roadmap]]
- [[_COMMUNITY_Roadmap-Import Feature|Roadmap-Import Feature]]
- [[_COMMUNITY_ExecutingWriting Plans|Executing/Writing Plans]]
- [[_COMMUNITY_Install & Caveman Statusline|Install & Caveman Statusline]]
- [[_COMMUNITY_Ship Pipeline & Agents|Ship Pipeline & Agents]]
- [[_COMMUNITY_Workflow Chain & Pipelines|Workflow Chain & Pipelines]]
- [[_COMMUNITY_Caveman Skill|Caveman Skill]]

## God Nodes (most connected - your core abstractions)
1. `executing-plan-time skill` - 23 edges
2. `dev-pipeline memory-protocol.md` - 15 edges
3. `.dev/memory/ protocol` - 13 edges
4. `writing-plans-time skill` - 12 edges
5. `brainstorming-time skill` - 9 edges
6. `ponytail minimal-code ladder` - 9 edges
7. `project-time skill` - 8 edges
8. `dev command (roadmap-driven loop)` - 8 edges
9. `Spec: /dev roadmap import` - 8 edges
10. `spec-reviewer agent` - 8 edges

## Surprising Connections (you probably didn't know these)
- `install_ponytail()` --references--> `ponytail plugin`  [EXTRACTED]
  install.sh → README.md
- `phase-executor agent` --calls--> `executing-plan-time skill`  [INFERRED]
  pipelines/dev-pipeline/commands/dev.md → skills/executing-plan-time/SKILL.md
- `caveman SessionStart hook` --conceptually_related_to--> `caveman mode`  [EXTRACTED]
  skills/caveman/caveman-hook.sh → README.md
- `Task 2: memory-protocol writer-domain + check` --references--> `progress.md`  [EXTRACTED]
  docs/plans/2026-06-17-roadmap-import.md → pipelines/dev-pipeline/memory-protocol.md
- `Completion prompt bridge` --shares_data_with--> `progress.md`  [EXTRACTED]
  docs/specs/2026-06-17-roadmap-import.md → pipelines/dev-pipeline/memory-protocol.md

## Hyperedges (group relationships)
- **caveman per-session flag flow** — caveman_caveman_state, caveman_statusline_snippet, caveman_per_session_flag [INFERRED 0.85]
- **install.sh orchestration steps** — install_install_item, install_install_session_hook, install_install_statusline_chip, install_install_ponytail [EXTRACTED 0.75]
- **dev pipeline memory layer files** — dev_memory_protocol, dev_memory_layer, dev_command [INFERRED 0.75]
- **roadmap import touches dev.md + memory-protocol** — specs_2026_06_17_roadmap_import, commands_dev, memory_protocol [EXTRACTED 1.00]
- **executing-plan-time three dispatched agents** — executing_plan_time_implementer, agents_spec_reviewer, executing_plan_time_code_quality_reviewer [EXTRACTED 1.00]
- **four hard gates form execution discipline** — executing_plan_time_hard_gates, executing_plan_time_tdd_contract, executing_plan_time_overlap_analysis, executing_plan_time_finishing_handoff [INFERRED 0.85]
- **phase loop chains brainstorm/plan/execute skills** — commands_dev_phase_loop, brainstorming_time, writing_plans_time, phase_executor [EXTRACTED 1.00]

## Communities (7 total, 0 thin omitted)

### Community 0 - "/dev Loop, Memory & Roadmap"
Cohesion: 0.17
Nodes (17): blocking-ambiguity policy (escalate vs auto), brainstorming-time skill, oroskills skill chain, dev command (roadmap-driven loop), .dev/memory layer, decisions.md, glossary.md, lessons.md (+9 more)

### Community 1 - "Roadmap-Import Feature"
Cohesion: 0.13
Nodes (19): brainstorming-time skill, /dev command (orchestrator), Import subsection, Phase loop, Roadmap stage (§2), goals.md, phase-executor agent, Plan: /dev Roadmap Import (+11 more)

### Community 2 - "Executing/Writing Plans"
Cohesion: 0.18
Nodes (17): code-quality-reviewer agent, implementer agent, spec-reviewer agent, TDD artifact integrity check, executing-plan-time skill, Finishing handoff (PR / merge / leave), Four hard gates, parallel execution waves (+9 more)

### Community 3 - "Install & Caveman Statusline"
Cohesion: 0.19
Nodes (13): caveman mode, per-session caveman flag file, caveman SessionStart hook, caveman SessionStart hook, install_item(), install_ponytail(), install_session_hook(), install_statusline_chip (+5 more)

### Community 4 - "Ship Pipeline & Agents"
Cohesion: 0.24
Nodes (15): spec-reviewer agent, code-quality-reviewer agent, implementer agent, file manifest hard constraint, ponytail minimal-code ladder, .pipeline/changes.md, ship command (feature pipeline), ship coder agent (+7 more)

### Community 5 - "Workflow Chain & Pipelines"
Cohesion: 0.28
Nodes (7): phase-executor agent, dev pipeline, ponytail plugin, oroskills README, ship pipeline, check_install.sh script, project-time to executing-plan-time chain

### Community 6 - "Caveman Skill"
Cohesion: 0.67
Nodes (3): caveman auto-clarity exception, caveman persistence mode, caveman skill

## Knowledge Gaps
- **20 isolated node(s):** `check_agents.sh script`, `check_install.sh script`, `caveman-hook.sh script`, `caveman mode`, `two-stage review gate` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `executing-plan-time skill` connect `Executing/Writing Plans` to `/dev Loop, Memory & Roadmap`, `Roadmap-Import Feature`, `Install & Caveman Statusline`, `Ship Pipeline & Agents`, `Workflow Chain & Pipelines`?**
  _High betweenness centrality (0.352) - this node is a cross-community bridge._
- **Why does `dev-pipeline memory-protocol.md` connect `/dev Loop, Memory & Roadmap` to `Roadmap-Import Feature`, `Executing/Writing Plans`, `Ship Pipeline & Agents`?**
  _High betweenness centrality (0.222) - this node is a cross-community bridge._
- **Why does `writing-plans-time skill` connect `Executing/Writing Plans` to `/dev Loop, Memory & Roadmap`, `Install & Caveman Statusline`, `Ship Pipeline & Agents`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **What connects `check_agents.sh script`, `check_install.sh script`, `caveman-hook.sh script` to the rest of the system?**
  _23 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Roadmap-Import Feature` be split into smaller, more focused modules?**
  _Cohesion score 0.13450292397660818 - nodes in this community are weakly interconnected._