---
name: case-author
description: Draft compact patient backgrounds and observable clues for Before the Cut.
---

# Case author

Read AGENTS.md, HANDOFF.md and the docs/g1/01-initial-gdd.md first. The AI generates patient replies and reactions autonomously. Do not author an exhaustive answer tree or a legal-move list for it.

Write a compact patient brief: identity, request, personality, motives, knowledge, what they may want to hide, and relevant background. Add physical observations and the Normal Reference Sheet entries that help interpret them. The background gives continuity; it does not dictate each spoken answer. Sample lines illustrate voice only.

Keep observation, action checks, dialogue and verbal pressure optional and unordered. Allow early decisions. The player may approve surgery or call Trauma Team; the shutter handles immediate threats. Refusal or irritation alone is not a diagnosis. Keep an evidence route available when the patient will not cooperate.

Propose simple reactions the interface can present without adding a new combat or squad-control system. State any open question about AI-driven physical actions. Do not silently restore enum-based dialogue selection to fit the old schema.

Inspect the actual implementation before editing it. Migrate game/proxy context and transcript handling together, test generated answers beyond old branches, and record real results. Historical tests are not validation of the new dialogue. Independent review requires applicable authorization; otherwise provide a reviewable diff and your own checks.
