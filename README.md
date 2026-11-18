# Before the Cut

A Godot 4 game about examining patients before cybernetic surgery. You compare a patient's appearance and responses with a sheet of normal states, choose examinations or dialogue in any order, and decide whether to approve surgery or call in Trauma Team. Every examination is optional. Defend yourself if threatened. Fired by a megacorp and deep in debt, the doctor works the counter of a street gang's back-street clinic, where two of each night's visitors are contacts to be picked out from tonight's list and given the right code.

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

Windows, PowerShell, from the repository root. The launcher looks for Godot 4.7.2 in `$env:GODOT_BIN`, then `%LOCALAPPDATA%\CodexTools\Godot\4.7.2\`, then on `PATH` (or pass `-GodotPath <exe>`). In a fresh clone its first run imports the pictures, fonts and sounds before the game starts (a few seconds; `-ImportOnly` does only that).

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

On November 15, 2026, the first live OpenAI run completed 30 patient requests and ten transcriptions of local synthetic speech, all successful. Twelve dialogue requests were played by an agent in the real window; eighteen were HTTP probes. No human microphone, listening or playtest result is claimed. A feedback bug found during the run was fixed: generated speech now retains what the patient actually said. See the [live report](docs/development/live-model-results-2026-11-15.md).

On November 16 the student's eleven notes on that build were answered in the game: a patient whose patience is gone leaves by themselves; the till is read every hour against a line set by the doctor's lender; the shutter is a timing bar, and the counter glass wears down with every blow that lands; the intake card counts the player's own crosses against the sheet's house rule; there is a short opening, a counter guide, and a thinking pose while the patient AI answers. These are assistant proposals with untuned numbers.

Later the same day the student asked for a more immersive screen (keep only the counter, with the visitor across it on one large view, and turn everything else into things on the desk or the walls that open when clicked) and for a way to pay for repairs to the counter glass that earlier attackers damaged. The screen was rebuilt that way: the counter window fills most of it; the reference sheet, the intake card, the hall camera, the counter guide and the controls are objects in the booth (click one, or press R, N, C or H); and between patients 40 credits put one layer back in the pane (the GLASS key, or G). The two requests are the student's. The layout, the keys, the price and the wording are assistant proposals.

On November 17 the student sent five notes on that build: pass and fail were unclear, since nothing pointed at the reference sheet (how long a grip is reasonable, for example); CALM should go or cost money; the grip and the eye test were confusing, and the opening should walk the player through everything once; a patient should be able to fly into a rage in the middle of any action; and a new story, in which the doctor, fired by a megacorp and in debt, works for a gang at a street implant clinic, contacts come in to exchange codes and smuggle military chrome, a daily contact list is used to cross-reference the visitors, and a wrong code costs patience. The game now holds the sheet up in every close-up, with plain readouts under the eyes and the grip limit marked (LIMIT 1s); CALM is a calm-patch for 30 credits; a first-night training points at one thing at a time and can be skipped with K; a drifting patient may snap mid-exam, the more likely the longer the exam runs, and anyone may flare once a visit without attacking; and six opening cards tell the story (Kessler, Harrow Credit, the Lanterns), with two contacts a night on a list on the left wall (L), each given an alias, two clues and a code. The lender's line rose to 240 an hour, so right calls alone no longer hold it. The notes are the student's; the answers, numbers, names and words are assistant proposals that the student has not reviewed. Details are in the [November 17 note](docs/development/story-and-clarity-2026-11-17.md).

On the current tree 820 rule checks, 940 scene checks over nine scripted shifts, 5 normal-close checks, 38 proxy tests and 196 game checks plus 15 wire checks over HTTP pass, and 196 + 91 frames were drawn by the real renderer on a hidden desktop. Godot 4.7.2's import from an empty cache, which a fresh clone needs, sometimes crashes, on the last commit as well (in 20 tries each, twice on this tree and once on the commit, and once more in the final check run); a second import mended the copy that crashed in the final run, so `run-game.ps1` now imports before the first run and tries again if the import stops short. All of that is automated, with the mock provider and a simulated microphone; no paid service was called and nobody played or listened. See [HANDOFF.md](HANDOFF.md) for evidence and limits.

Personal settings, credentials, generated caches, local evidence and private CourseWorks material stay out of Git. Reference images in the separately prepared pitch deck are not game assets.

## AI assistance

The student directs the project as Executive Producer and Creative Director. Claude and Codex assisted with research, design, implementation, verification and document preparation. Dated records distinguish student decisions, assistant proposals, implemented features and verified results.
