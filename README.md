# Before the Cut

G1 Concept documentation for an individual Godot 4 project.

You play an implant doctor who decides whether a patient is safe for surgery. Compare their appearance and responses with a sheet of normal states, choose optional examinations or dialogue in any order, and decide whether to proceed or refer. Defend yourself if threatened. The fictional premise is inspired by Cyberpunk 2077; the screening rules and patients are original game design.

## Required G1 documents

1. [Initial Game Design Document](g1/01-initial-gdd.md) — player experience, optional examination loop, design pillars, scope and open questions.
2. [Initial Configuration Document](g1/02-initial-configuration-document.md) — patient AI, game-owned evidence, fallback, budgets and planned production-agent roles.
3. [Initial Project Plan and Risk Register](g1/03-initial-project-plan-and-risk-register.md) — gate dates, tasks through G2/G3, dependencies and risks.

## Supporting materials

- [Agent configuration manifest](agent-config.json)
- [Case-author skill](agent_team/case-author/SKILL.md)
- [Rules-reviewer brief](agent_team/rules-reviewer.md)
- [Sources](g1/06-sources-and-requirements.md)
- [Verification summary](g1/07-verification-record.md)

## Implementation status

An earlier scan/re-check prototype has passed local automated tests. The revised optional-examination design is planned and still needs implementation. Live-model evaluation and human playtests remain pending.

This repository publishes the G1 documents and their configuration/agent attachments. It does not include the game executable, implementation source, local handoff history, raw test logs, slides or third-party reference images. Implementation and evidence paths mentioned inside the documents identify files in the separate development workspace; they are not download links in this documentation snapshot. The playable build and later prototype evidence will be shared separately.

The G1 recording and CourseWorks post are separate deliverables. Publishing this repository does not submit the assignment.

## AI assistance

The student directs the project as Executive Producer and Creative Director. Claude and Codex assisted with research, design drafts, the earlier prototype, local verification and document preparation. The documents distinguish student decisions, agent proposals, implemented features, verified results and unresolved work.
