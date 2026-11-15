# Before the Cut

A Godot 4 game about examining patients before cybernetic surgery. You compare a patient's appearance and responses with a sheet of normal states, choose examinations or dialogue in any order, and decide whether to approve surgery or call in Trauma Team. Every examination is optional. Defend yourself if threatened.

This is one student's ongoing course project. The fictional cyberpsychosis premise is inspired by Cyberpunk 2077; the patients and screening rules are original game design.

## Required G1 documents

1. [Initial Game Design Document](docs/g1/01-initial-gdd.md)
2. [Initial Configuration Document](docs/g1/02-initial-configuration-document.md)
3. [Initial Project Plan and Risk Register](docs/g1/03-initial-project-plan-and-risk-register.md)

The [G1 index](docs/g1/README.md) also contains the English recording script, submission checklist, sources and dated verification summary. Recording and CourseWorks submission remain separate tasks.

## Repository layout

```text
game/          Godot project, scenes, scripts, cases and game assets
agent_proxy/   Patient-agent API, providers, validation and proxy tests
agent_team/    Production-agent skills and reviewer briefs
docs/g1/      G1 concept documents and presentation text
docs/development/  Development notes and repository transition
tools/         Development utilities and asset-generation scripts
```

This repository was renamed from `before-the-cut-g1` to `before-the-cut` so later code and coursework can live together. The former `g1/` document paths contain forwarding links.

**Source transfer is pending as of November 14, 2026.** Claude/Fable is still writing in the existing `fathom` workspace. Its files have not been moved, and `game/`, `agent_proxy/` and `tools/` currently contain placeholders only. Do not use this checkout as a runnable build yet. After that work stops, transfer the latest source into these directories, verify it here, and use this checkout for subsequent development. See the [transition checklist](docs/development/repository-transition.md).

## Design and verification

The [agent manifest](agent-config.json) and [production-agent artifacts](agent_team/) describe the bounded patient agent and planned development roles. The game owns case truth, evidence, attacks and scoring; the agent may only choose permitted responses. An offline scripted version must remain playable.

Older local tests cover the earlier scan/re-check prototype. New case data and pixel-art work are in progress in the active workspace; those old results do not validate the new implementation. No new game test, live-model evaluation or human playtest is claimed by this repository reorganization.

Personal settings, credentials, generated caches, local evidence and private CourseWorks material stay out of Git. Reference images in the separately prepared pitch deck are not game assets.

## AI assistance

The student directs the project as Executive Producer and Creative Director. Claude and Codex assisted with research, design, implementation, verification and document preparation. Dated records distinguish student decisions, assistant proposals, implemented features and verified results.
