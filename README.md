# Before the Cut

A Godot 4 game about examining patients before cybernetic surgery. You compare a patient's appearance and responses with a sheet of normal states, choose examinations or dialogue in any order, and decide whether to approve surgery or call in Trauma Team. Every examination is optional. Defend yourself if threatened.

This is one student's ongoing course project. The fictional cyberpsychosis premise is inspired by Cyberpunk 2077; the patients and screening rules are original game design.

## Required G1 documents

1. [Initial Game Design Document](docs/g1/01-initial-gdd.md)
2. [Initial Configuration Document](docs/g1/02-initial-configuration-document.md)
3. [Initial Project Plan and Risk Register](docs/g1/03-initial-project-plan-and-risk-register.md)

The [G1 index](docs/g1/README.md) also contains the English recording script, submission checklist, sources and dated verification summary. The G1 pitch was submitted on November 14, 2026; these are the submitted versions.

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

## Run it

Windows, PowerShell, from the repository root. The launcher looks for Godot 4.7.2 in `$env:GODOT_BIN`, then `%LOCALAPPDATA%\CodexTools\Godot\4.7.2\`, then on `PATH` (or pass `-GodotPath <exe>`).

```powershell
.\run-game.ps1                 # offline: authored patients, no network
.\run-game.ps1 -LessBlood      # the attack scenes without blood
```

With the patient-AI proxy (Node.js; a mock unless `agent_proxy/.dev.vars` names a provider):

```powershell
cd agent_proxy; npm run dev
.\run-game.ps1 -Model -AgentUrl http://127.0.0.1:8787    # second terminal, repository root
```

Controls and rules are in [game/README.md](game/README.md); providers, keys and limits in [agent_proxy/README.md](agent_proxy/README.md). The source was moved here from the earlier local workspace on November 15, 2026 ([transition record](docs/development/repository-transition.md)).

## Design and verification

The [agent manifest](agent-config.json) and [production-agent artifacts](agent_team/) describe the bounded patient agent and planned development roles. The patient AI creates original replies and reactions from its character context and conversation history. Its normal replies are not selected by a fixed rule table. An offline scripted version must remain playable.

On November 15, 2026, in this checkout: 485 rule checks, 325 scene checks (and 325 with less blood), 5 window-close checks, 38 proxy tests and 179 game-and-proxy HTTP checks pass, all automated with a dummy audio driver, a simulated microphone and a local mock patient service. An agent also operated the game in a real window with the real microphone and the mock. No live model has been called, and no person has played this version or listened to it. Current results and limits: [HANDOFF.md](HANDOFF.md).

Personal settings, credentials, generated caches, local evidence and private CourseWorks material stay out of Git. Reference images in the separately prepared pitch deck are not game assets.

## AI assistance

The student directs the project as Executive Producer and Creative Director. Claude and Codex assisted with research, design, implementation, verification and document preparation. Dated records distinguish student decisions, assistant proposals, implemented features and verified results.
