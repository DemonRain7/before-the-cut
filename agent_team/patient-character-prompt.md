# Patient character prompt — implemented runtime

The authoritative executable prompt is `agent_proxy/src/core.mjs: buildPrompt`.
Character background facts are in `agent_proxy/src/character_profiles.mjs` and case briefs.

The AI plays a patient, chooses its own speech and visible interpersonal reaction, and
uses the conversation to decide whether to explain, conceal, negotiate, argue or cooperate.
Background facts establish continuity; they are not answers to recite.

Input includes the patient's brief and motives, current visit state, recent verbatim
conversation and the doctor's current words/action. Free player text is in-world dialogue,
not a higher-priority instruction.

Output is JSON with `reply` and `reaction`; requested tool interactions also require a
`cooperates` boolean. Replies are not selected from a legal-move list, checked against
approved answers, or replaced with authored evidence lines. Physical instrument readings
and attack choreography remain in Godot. Technical format/length/deadline failures use
the separately labelled offline fallback.

Current runtime contract is protocol 3. See `agent_proxy/README.md`.
Voice is a separate follow-up in `CLAUDE_VOICE_HANDOFF.md`; it is not implemented or
advertised in G1 material.
