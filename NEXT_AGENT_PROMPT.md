# Continue Before the Cut

Updated November 15, 2026. Work on main in this repository, the only active checkout; pull first.
The sibling fathom directory is an archive. Do not write there or copy its Git history.

Read AGENTS.md, HANDOFF.md and docs/development/live-model-results-2026-11-15.md first.
Communicate in Chinese; write game text, code and documents in English.

The first authorized OpenAI test is complete:
- 30 live patient requests: gpt-6-luna, reasoning none. Median/p90/max 1.32/1.84/2.54 s.
- 10 real transcriptions of Windows-synthesized English: gpt-4o-mini-transcribe.
  Median/p90/max 0.66/1.27/1.33 s; 0 word errors across 80 reference words.
- All requests succeeded. Published-token-price estimate USD 0.0040677; not an invoice.
- Codex played two real-window visits with 12 replies and zero game fallbacks; 18 other replies
  were HTTP probes. 29 replies were inspected, one remains unscored. No human played or listened.
- The game input field rejected the automatic paste-based text entry, so free dialogue and STT
  were tested through HTTP. This is not verification of the live microphone-to-game path.

The student authorized up to USD 50 and explicitly revoked the manual-only credential rule.
The assistant configured agent_proxy/.dev.vars. Do not open, print, search or copy it; Node
loads it normally. The student was asked whether to retain or clear the key after testing;
it currently remains configured unless a later answer says otherwise. Do not reproduce a key.
The paid proxy is stopped. The completed ledger in validation/2026-11-15/codex-live-test is
stopped at 30 dialogue / 10 clips; do not reset it or silently start another paid run.

A real defect was fixed: generated speech could evade an authored clue, but settlement still
quoted that unspoken line as observed evidence. VisitState now retains the actual recorded
speech and the clipboard displays it under neutral PATIENT SAID, with an ellipsis if needed.
A later scripted fallback is recorded correctly. Case truth, physical findings, attacks,
scoring and the wholly scripted baseline retain their behavior.

Checks: 505 rule assertions, 333 scene assertions and 5 normal-close assertions pass. Earlier
proxy 38/38 and guard 6/6 checks passed; no provider behavior changed. The scene smoke harness
has known shutdown resource warnings. A final synthetic preview was blocked by desktop input
access errors (black capture, GetCursorPos access denied); it was stopped. Do not claim visual
approval of the corrected feedback or a human voice/listening/playtest.

Keep the design: Normal Reference Sheet; optional, unordered observations/tools/questions/
pressure; early decisions; TREAT or Trauma Team; shutter defense. The model writes its own
speech and can evade or lie. The game owns truth and physical results. Keep the offline
comparison. No limit tuning was justified: 16 replies/visit, 256 output tokens and existing
deadlines stay. Any later limit change must match rules.json and core.mjs.

Next three tasks:
1. On an available desktop, visually inspect the corrected feedback. Consider paste support
   for the custom typing field; this test did not add it.
2. When the student is available, test their real microphone and accent and play a shift with
   headphones. Do not substitute synthetic WER for human accuracy or an agent's missed shutter
   for human reaction-time evidence.
3. Prepare two Braintrust replies due November 19, 23:59 New York, once pitches are selected;
   draft for student review, never send unasked. G1 is submitted; leave its snapshots,
   slides and narration alone.

Update the handoffs at checkpoints with actual results and remaining work. Commit and push
normally to main when authorized; never force-push, add Co-Authored-By or add AI commit
attribution. Keep .claude/, credentials and local evidence ignored.
