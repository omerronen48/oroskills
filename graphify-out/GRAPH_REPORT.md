# Graph Report - .  (2026-06-17)

## Corpus Check
- 24 files · ~16,501 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 80 nodes · 131 edges · 12 communities (7 shown, 5 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Ship Pipeline & Agents|Ship Pipeline & Agents]]
- [[_COMMUNITY_ExecutingWriting Plans|Executing/Writing Plans]]
- [[_COMMUNITY_Install & Session Setup|Install & Session Setup]]
- [[_COMMUNITY_ProjectBrainstorm & Roadmap|Project/Brainstorm & Roadmap]]
- [[_COMMUNITY_dev Loop & Memory Store|/dev Loop & Memory Store]]
- [[_COMMUNITY_install.sh Internals|install.sh Internals]]
- [[_COMMUNITY_Caveman Skill|Caveman Skill]]
- [[_COMMUNITY_check_dev_command test|check_dev_command test]]
- [[_COMMUNITY_check_install test|check_install test]]
- [[_COMMUNITY_caveman-hook script|caveman-hook script]]
- [[_COMMUNITY_check_agents test|check_agents test]]
- [[_COMMUNITY_check_memory_protocol test|check_memory_protocol test]]

## God Nodes (most connected - your core abstractions)
1. `executing-plan-time skill` - 18 edges
2. `writing-plans-time skill` - 12 edges
3. `.dev/memory/ protocol` - 11 edges
4. `brainstorming-time skill` - 9 edges
5. `ponytail minimal-code ladder` - 8 edges
6. `project-time skill` - 8 edges
7. `dev-pipeline memory-protocol.md` - 7 edges
8. `dev command (roadmap-driven loop)` - 7 edges
9. `implementer agent` - 7 edges
10. `dev pipeline` - 6 edges

## Surprising Connections (you probably didn't know these)
- `install_ponytail()` --implements--> `ponytail plugin`  [EXTRACTED]
  install.sh → README.md
- `caveman SessionStart hook` --conceptually_related_to--> `caveman mode`  [EXTRACTED]
  skills/caveman/caveman-hook.sh → README.md
- `ponytail minimal-code ladder` --conceptually_related_to--> `ponytail plugin`  [EXTRACTED]
  skills/executing-plan-time/SKILL.md → README.md
- `dev command (roadmap-driven loop)` --references--> `project-time skill`  [EXTRACTED]
  pipelines/dev-pipeline/commands/dev.md → skills/project-time/SKILL.md
- `.dev/memory/ protocol` --references--> `project-time skill`  [EXTRACTED]
  pipelines/dev-pipeline/memory-protocol.md → skills/project-time/SKILL.md

## Hyperedges (group relationships)
- **project to executed code skill chain** — project_time_skill, brainstorming_time_skill, writing_plans_time_skill, executing_plan_time_skill [EXTRACTED 1.00]
- **executing-plan-time dispatched agents** — agent_implementer, agent_spec_reviewer, agent_code_quality_reviewer [EXTRACTED 1.00]
- **install.sh setup actions** — install_install_item, install_install_session_hook, install_install_ponytail [EXTRACTED 1.00]
- **plan parallelization artifacts** — file_edit_manifest, execution_waves, overlap_analysis [INFERRED 0.85]
- **dev pipeline test checks** — check_dev_command, check_memory_protocol, check_agents, check_install [INFERRED 0.85]
- **ship feature pipeline stages** — ship_command, ship_pipeline_planner, ship_pipeline_coder, ship_pipeline_tester, ship_pipeline_reviewer [EXTRACTED 1.00]
- **ship pipeline handoff artifacts** — ship_spec_artifact, ship_changes_artifact, ship_test_results_artifact, ship_review_artifact [EXTRACTED 1.00]
- **.dev/memory shared store files** — dev_memory_goals, dev_memory_decisions, dev_memory_lessons, dev_memory_glossary, dev_memory_progress [EXTRACTED 1.00]
- **dev pipeline skill chain** — dev_command, project_time_skill, brainstorming_time_skill, writing_plans_time_skill, executing_plan_time_skill [EXTRACTED 1.00]
- **dev pipeline subagents** — dev_pipeline_phase_executor, dev_pipeline_implementer, dev_pipeline_spec_reviewer, dev_pipeline_code_quality_reviewer [INFERRED 0.85]

## Communities (12 total, 5 thin omitted)

### Community 0 - "Ship Pipeline & Agents"
Cohesion: 0.24
Nodes (15): code-quality-reviewer agent, implementer agent, spec-reviewer agent, file manifest hard constraint, ponytail minimal-code ladder, .pipeline/changes.md, ship command (feature pipeline), ship coder agent (+7 more)

### Community 1 - "Executing/Writing Plans"
Cohesion: 0.24
Nodes (12): code-quality-reviewer agent, implementer agent, spec-reviewer agent, executing-plan-time skill, parallel execution waves, File Edit Manifest, git worktree isolation, overlap analysis (file/function/call-graph) (+4 more)

### Community 2 - "Install & Session Setup"
Cohesion: 0.19
Nodes (9): phase-executor agent, caveman mode, caveman SessionStart hook, dev pipeline, install_ponytail(), install_session_hook(), ponytail plugin, oroskills README (+1 more)

### Community 3 - "Project/Brainstorm & Roadmap"
Cohesion: 0.27
Nodes (9): brainstorming-time skill, oroskills skill chain, .dev/memory layer, graphify knowledge graph, dev-pipeline memory-protocol.md, Mermaid mind map, project-time skill, roadmap file (docs/roadmaps) (+1 more)

### Community 4 - "/dev Loop & Memory Store"
Cohesion: 0.31
Nodes (9): blocking-ambiguity policy (escalate vs auto), dev command (roadmap-driven loop), decisions.md, glossary.md, goals.md, lessons.md, progress.md, .dev/memory/ protocol (+1 more)

### Community 5 - "install.sh Internals"
Cohesion: 0.70
Nodes (4): install_item(), install_ponytail(), install_session_hook(), install.sh script

### Community 6 - "Caveman Skill"
Cohesion: 0.67
Nodes (3): caveman auto-clarity exception, caveman persistence mode, caveman skill

## Knowledge Gaps
- **17 isolated node(s):** `check_dev_command.sh script`, `check_memory_protocol.sh script`, `check_agents.sh script`, `check_install.sh script`, `caveman-hook.sh script` (+12 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `executing-plan-time skill` connect `Executing/Writing Plans` to `Ship Pipeline & Agents`, `Install & Session Setup`, `Project/Brainstorm & Roadmap`, `/dev Loop & Memory Store`?**
  _High betweenness centrality (0.225) - this node is a cross-community bridge._
- **Why does `ponytail minimal-code ladder` connect `Ship Pipeline & Agents` to `Executing/Writing Plans`, `Install & Session Setup`?**
  _High betweenness centrality (0.095) - this node is a cross-community bridge._
- **Why does `.dev/memory/ protocol` connect `/dev Loop & Memory Store` to `Ship Pipeline & Agents`, `Project/Brainstorm & Roadmap`?**
  _High betweenness centrality (0.091) - this node is a cross-community bridge._
- **What connects `check_dev_command.sh script`, `check_memory_protocol.sh script`, `check_agents.sh script` to the rest of the system?**
  _19 weakly-connected nodes found - possible documentation gaps or missing edges._