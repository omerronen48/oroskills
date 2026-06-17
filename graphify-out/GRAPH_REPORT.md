# Graph Report - .  (2026-06-17)

## Corpus Check
- Corpus is ~16,715 words - fits in a single context window. You may not need a graph.

## Summary
- 80 nodes · 141 edges · 17 communities (10 shown, 7 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.89)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Dev-Pipeline & Memory Store|Dev-Pipeline & Memory Store]]
- [[_COMMUNITY_Ship-Pipeline Stages|Ship-Pipeline Stages]]
- [[_COMMUNITY_Workflow Chain Front Door|Workflow Chain Front Door]]
- [[_COMMUNITY_Dev-Pipeline Agents|Dev-Pipeline Agents]]
- [[_COMMUNITY_Caveman Mode & Session Hook|Caveman Mode & Session Hook]]
- [[_COMMUNITY_Executing-Plan Mechanics|Executing-Plan Mechanics]]
- [[_COMMUNITY_install.sh Internals|install.sh Internals]]
- [[_COMMUNITY_Writing-Plans Artifacts|Writing-Plans Artifacts]]
- [[_COMMUNITY_README & Ponytail|README & Ponytail]]
- [[_COMMUNITY_Local SettingsPermissions|Local Settings/Permissions]]
- [[_COMMUNITY_check_agents test|check_agents test]]
- [[_COMMUNITY_caveman-hook script|caveman-hook script]]
- [[_COMMUNITY_check_dev_command test|check_dev_command test]]
- [[_COMMUNITY_check_install test|check_install test]]
- [[_COMMUNITY_check_memory_protocol test|check_memory_protocol test]]
- [[_COMMUNITY_settings_local|settings_local]]

## God Nodes (most connected - your core abstractions)
1. `executing-plan-time skill` - 16 edges
2. `writing-plans-time skill` - 12 edges
3. `dev memory protocol` - 12 edges
4. `oroskills README` - 9 edges
5. `brainstorming-time skill` - 9 edges
6. `dev command` - 9 edges
7. `project-time skill` - 8 edges
8. `implementer agent` - 8 edges
9. `coder agent` - 7 edges
10. `dev-pipeline memory protocol` - 6 edges

## Surprising Connections (you probably didn't know these)
- `coder agent` --semantically_similar_to--> `implementer agent`  [INFERRED] [semantically similar]
  ship-pipeline/agents/coder.md → dev-pipeline/agents/implementer.md
- `reviewer agent` --semantically_similar_to--> `code-quality-reviewer agent`  [INFERRED] [semantically similar]
  ship-pipeline/agents/reviewer.md → dev-pipeline/agents/code-quality-reviewer.md
- `install_ponytail()` --references--> `ponytail plugin (minimal-code enforcement)`  [EXTRACTED]
  install.sh → README.md
- `writing-plans-time skill` --conceptually_related_to--> `skill workflow chain`  [INFERRED]
  writing-plans-time/SKILL.md → README.md
- `executing-plan-time skill` --conceptually_related_to--> `skill workflow chain`  [INFERRED]
  executing-plan-time/SKILL.md → README.md

## Hyperedges (group relationships)
- **project-time to executing-plan-time chain** — project_time_skill, brainstorming_time_skill, writing_plans_time_skill, executing_plan_time_skill [EXTRACTED 1.00]
- **executing-plan-time dispatched agents** — executing_plan_time_skill, implementer_agent, spec_reviewer_agent, code_quality_reviewer_agent [EXTRACTED 1.00]
- **caveman-on-by-default install mechanism** — install_install_session_hook, caveman_caveman_hook, session_start_hook [EXTRACTED 1.00]
- **ship four-stage feature pipeline** — ship_pipeline_commands_ship, ship_pipeline_agents_planner, ship_pipeline_agents_coder, ship_pipeline_agents_tester, ship_pipeline_agents_reviewer [EXTRACTED 1.00]
- **dev roadmap-driven dev loop** — dev_pipeline_commands_dev, dev_pipeline_agents_phase_executor, skill_project_time, skill_brainstorming_time, skill_writing_plans_time, concept_dev_memory_store [EXTRACTED 1.00]
- **executing-plan-time implementer + two-stage review** — skill_executing_plan_time, dev_pipeline_agents_implementer, dev_pipeline_agents_spec_reviewer, dev_pipeline_agents_code_quality_reviewer, concept_tdd_before_commit_contract [INFERRED 0.85]
- **.dev/memory store files** — concept_dev_memory_store, concept_goals_md, concept_decisions_md, concept_lessons_md, concept_glossary_md, concept_progress_md [EXTRACTED 1.00]

## Communities (17 total, 7 thin omitted)

### Community 0 - "Dev-Pipeline & Memory Store"
Cohesion: 0.21
Nodes (19): decisions.md audit log, .dev/memory/ store, glossary.md, goals.md, lessons.md, ponytail minimal-code ladder, progress.md phase tracker, TDD-before-commit contract (+11 more)

### Community 1 - "Ship-Pipeline Stages"
Cohesion: 0.39
Nodes (9): .pipeline/changes.md handoff, .pipeline/review.md handoff, .pipeline/spec.md handoff, .pipeline/test-results.md handoff, coder agent, planner agent, reviewer agent, tester agent (+1 more)

### Community 2 - "Workflow Chain Front Door"
Cohesion: 0.43
Nodes (6): brainstorming-time skill, dev pipeline (/dev continuous loop), graphify knowledge graph, dev-pipeline memory protocol, project-time skill, skill workflow chain

### Community 3 - "Dev-Pipeline Agents"
Cohesion: 0.53
Nodes (4): code-quality-reviewer agent, implementer agent, phase-executor agent, spec-reviewer agent

### Community 4 - "Caveman Mode & Session Hook"
Cohesion: 0.50
Nodes (4): caveman skill, install_session_hook(), mattpocock/skills caveman source, caveman SessionStart hook

### Community 5 - "Executing-Plan Mechanics"
Cohesion: 0.40
Nodes (5): executing-plan-time skill, git worktree isolation, overlap analysis (file+function+call-graph), TDD-before-commit contract, two-stage review gate

### Community 6 - "install.sh Internals"
Cohesion: 0.70
Nodes (4): install_item(), install_ponytail(), install_session_hook(), install.sh script

### Community 7 - "Writing-Plans Artifacts"
Cohesion: 0.83
Nodes (3): parallel execution waves, File Edit Manifest, writing-plans-time skill

### Community 8 - "README & Ponytail"
Cohesion: 0.50
Nodes (4): install_ponytail(), ponytail plugin (minimal-code enforcement), oroskills README, ship pipeline (/ship)

## Knowledge Gaps
- **19 isolated node(s):** `check_dev_command.sh script`, `check_memory_protocol.sh script`, `check_agents.sh script`, `check_install.sh script`, `allow` (+14 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dev check_install.sh` connect `Dev-Pipeline & Memory Store` to `Dev-Pipeline Agents`?**
  _High betweenness centrality (0.287) - this node is a cross-community bridge._
- **Why does `implementer agent` connect `Dev-Pipeline & Memory Store` to `Ship-Pipeline Stages`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._
- **Why does `executing-plan-time skill` connect `Executing-Plan Mechanics` to `README & Ponytail`, `Workflow Chain Front Door`, `Dev-Pipeline Agents`, `Writing-Plans Artifacts`?**
  _High betweenness centrality (0.112) - this node is a cross-community bridge._
- **What connects `check_dev_command.sh script`, `check_memory_protocol.sh script`, `check_agents.sh script` to the rest of the system?**
  _19 weakly-connected nodes found - possible documentation gaps or missing edges._