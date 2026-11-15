**Latest decision, November 14:** replace referral with calling Trauma Team to take over. The live deck is version 21; slide 2 narration still has 84 words and the total remains 555. Current recording files in the legacy g1 folder are `before-the-cut-g1-trauma-team.pdf` and `before-the-cut-recording-script-trauma-team.docx`. Runtime button labels, normal-sheet text and case outcomes still need implementation. The response team is an authored outcome, not an additional model agent. Do not change the active writer's game files mid-run; apply the action change at its next checkpoint.

# Before the Cut: working instructions

Read `README.md`, `HANDOFF.md` and `docs/development/repository-transition.md` first. This is the ongoing Before the Cut repository, formerly named before-the-cut-g1. Source transfer is pending while Claude/Fable is working in the legacy sibling `fathom` directory. Do not start a competing implementation in this checkout or move files out from under that process.

Communicate with the student in Chinese. Write game text, comments, documents, slides, scripts and handoffs in English.

## Agreed design

- Godot 4, 2D pixel art, initially a clinic counter. The player is an implant doctor examining patients before surgery.
- A Normal Reference Sheet shows expected appearance, states and responses. Players compare it with the patient and make their own judgments.
- Observation, requested actions/tool interactions, ordinary dialogue and provocative verbal pressure are optional and unordered. Players may skip any method and decide early. Do not reinstate a mandatory checklist, universal re-check or fixed examination sequence.
- Case truth and evidence are fixed. The game controls physical/conversational evidence, attacks and scoring. The patient agent chooses only permitted cooperation, refusal and dialogue. Refusal or irritation alone is not an automatic diagnosis.
- Keep a stateful scripted baseline and playable offline fallback. Model benefit is a hypothesis to test.
- Fantasy and Discovery are primary motivations; Sensation supports the suspense. The pitch does not promise shuffled arrivals.
- The student wants Claude/Fable to develop the art, presentation and implementation creatively. Exact signs, cases, balance and patient counts are proposals, not frozen requirements.

## Project organization

Game files belong in `game/`, runtime API files in `agent_proxy/`, production-agent artifacts in `agent_team/`, G1 materials in `docs/g1/`, and reusable development tools in `tools/`. Keep game and proxy relative paths intact during the transfer. Original presentation reference images are separate from game assets; record asset permissions before publication.

Preserve the published G1 links under `g1/` as forwarding documents. Do not use the older documentation-only export checkout or its preparation script to overwrite this repository.

The corrected announcement supplied by the student on November 14 sets G1 for November 15, 2026 at 23:59 and two self-selected Braintrust replies for November 19 at 23:59, New York time. G1 is the only submission due before Monday's class. Use `docs/g1/06-sources-and-requirements.md`; do not add superseded pre-class notes or syllabus-only tasks.

## Evidence and permissions

Distinguish old test results from current runs, mocks from live-model calls, automated checks from human playtests, and repository publication from course submission. Current source is in progress; do not claim the new implementation passes historical tests.

The student authorized the repository rename, restructuring and eventual source consolidation. Finish the active legacy editing session before transferring its latest files. Preserve unrelated work. Course posts, peer messages, paid model calls and deployment need applicable user authorization; repository authorization does not cover them.

Update `HANDOFF.md` and `NEXT_AGENT_PROMPT.md` at checkpoints, including actual results, limitations and the next three tasks.

- NEVER add `Co-Authored-By` or any AI attribution to Git commits.
- Keep `.claude/` ignored. Do not commit personal settings, secrets, caches, private course pages or local evidence archives.
- Written course AI-use disclosures are separate from commit attribution and must remain truthful.
