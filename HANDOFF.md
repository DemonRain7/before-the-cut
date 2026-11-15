**Latest recording files:** `before-the-cut-g1-autonomous-dialogue.pdf` and `before-the-cut-recording-script-autonomous-dialogue.docx`. Autonomous-dialogue revision: 543 spoken words, estimated 4:52 including slide changes; actual recording is pending. Runtime code still needs migration at the active writer's next checkpoint.

**Current student decision, November 14: autonomous patient dialogue.** The AI uses the patient's background, personality, motives and conversation history to decide what to say and how to react. It generates original responses; it is not restricted to a legal-move list, authored answer bank or fixed dialogue tree. Technical format, length and timeout checks do not select its answer. The earlier enum-constrained protocol is legacy implementation, not the current design.

**Latest decision, November 14:** replace referral with calling Trauma Team to take over. The live deck is version 21; slide 2 narration still has 84 words and the total remains 555. Current recording files in the legacy g1 folder are `before-the-cut-g1-trauma-team.pdf` and `before-the-cut-recording-script-trauma-team.docx`. Runtime button labels, normal-sheet text and case outcomes still need implementation. The response team is an authored outcome, not an additional model agent. Do not change the active writer's game files mid-run; apply the action change at its next checkpoint.

# Before the Cut: repository handoff

Updated November 14, 2026. The student asked to make the G1 repository the ongoing home for the codebase and to improve its name and structure.

## Current state

- The same GitHub repository is now `DemonRain7/before-the-cut`. Its existing history is preserved.
- Required course documents live in `docs/g1/`. Former `g1/` paths forward to them.
- `game/`, `agent_proxy/` and `tools/` are reserved for the implementation. They contain placeholders until source transfer.
- The student confirmed that Claude/Fable is **still running in `../fathom`**. That directory remains the active implementation workspace. Do not rename it, replace its files or switch the active agent to this checkout mid-run.
- New case data and pixel-art assets were observed there. Their completion and verification are unknown. Historical November 12 tests cover the earlier prototype only.
- A preliminary read-only copy is retained locally under ignored `artifacts/implementation-snapshot-2026-11-14/`. It may already be stale and is not an authoritative migration source.

The current G1 package includes nine slides and a 555-word English script. Word/PDF exports, editable deck assets, reference images and detailed local history remain in the legacy workspace; this change does not republish them. The student's own recording, deck sharing, CourseWorks post and two Braintrust replies remain separate tasks. See `docs/g1/05-submission-draft-and-checklist.md`.

## Next three tasks

1. Let the active Claude/Fable run finish. Read its final handoff and fresh source files in `fathom` before copying anything.
2. Follow `docs/development/repository-transition.md`: transfer reviewed source into this checkout, keep private files excluded, update internal paths, and run checks here. Preserve the old workspace and the existing repository history.
3. Commit and push the verified transfer; switch future work to this checkout and record the actual results. Test the revised optional-examination loop with a person before claiming enjoyment or agent benefit.

No runtime code was changed or retested by the repository reorganization. No course post, paid call or deployment was performed.

Repository checks: the manifest parses, 28 local Markdown links resolve, all five legacy document paths point to their replacements, the recording script text is unchanged, and staged files exclude runtime snapshots, private settings and credentials. Git whitespace checks pass. Local details are retained in ignored `artifacts/restructure-validation.json`.
