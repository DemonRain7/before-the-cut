---
name: case-author
description: Draft or revise a Before the Cut patient whose appearance and action responses can be compared with the observation guide. Keep fixed case truth, readable evidence and bounded patient behavior.
---

# Case author

Updated 2026-11-13 for the student's observation-guide direction. The separate author/reviewer workflow has not yet been exercised.

## Design authority

Read `AGENTS.md`, `HANDOFF.md` and `docs/g1/01-initial-gdd.md` first. The core is comparison with a sheet of normal appearance, states and responses. Observation, actions and dialogue (including verbal pressure) are optional, unordered choices. A player can skip any method and decide; no checklist-completion gate is allowed. The older universal re-check rule is superseded.

The executable still uses the earlier case schema and scan/re-check rule. Do not rename a scan and claim the new interaction is implemented. Before writing a new runtime case, inspect `case_db.gd`, `visit_state.gd` and the current rules to see whether the guide/response migration exists.

## Draft a compact case

Use established student decisions; propose unspecified content with a clear label. Ask only when a missing decision actually blocks work.

1. Fix the intended screening assessment before writing clues. Distinguish elevated risk, uncertainty and immediate threat.
2. Write the patient's request, one short arrival line and a few visible details.
3. Name the guide entry that makes each relevant observation interpretable.
4. Specify the player action, the visible response and its meaning. The game owns this response; dialogue cannot invent it.
5. Identify which appearance cues are enough and which invite a follow-up. Repetition is optional and case-specific.
6. List legal cooperation, refusal and conversational responses for the chosen action or tone. Verbal pressure is optional; ordinary irritation is not automatically a symptom. Any diagnostic response pattern must be constrained by case data. Refusal is not an abnormal completed test.
7. Keep another authored evidence route reachable under every allowed refusal sequence; refusal alone must not force an emergency call.
8. Write concise outcome feedback that names the observation supporting the decision.
9. Add an attack only if this case needs it. Keep a local warning and one defensive action; calling Trauma Team does not inherently trigger violence.

Do not add long biographies, free-text interrogation, an economy or additional systems to make a case interesting.

## Implement only against the correct schema

For the new flow, coordinate guide entries, action ids, visible-response data, rule validation, UI and the scripted baseline. Update both proxy and game case versions together where the contract changes. Keep truth, future results and attack data outside the agent context.

If maintaining the earlier executable before migration, its first-check/re-check invariants still apply to that code. Label the work as legacy maintenance and preserve the new GDD as the design authority. The old four-tool fields and five score totals are not requirements for the revised design.

## Verify and report

Run checks relevant to changed rules, UI or transport. Existing suites are in `game/tests/` and `agent_proxy/test/`. Update meaningful expectations when the underlying design changes; passing the old tests alone does not establish the revised loop.

The change note should contain the fixed case assessment, guide mapping, player action and visible response, intended decision, worst legal refusal path, and actual commands/results. Clearly identify draft-only content.

When a separate review is explicitly authorized, use `agent_team/rules-reviewer.md`. Otherwise prepare a reviewable diff and report your own checks without calling them independent review. The student remains Creative Director and judges the case's tone and usefulness.
