# Claude handoff for Before the Cut

You are taking over a Godot 4 game about screening patients at an underground implant clinic. The owner rejected the first end-of-shift film. **Your implementation assignment is a complete remake of the closing animation.** The two-player concept below is for a later phase. Multiplayer, playable surgery and surgery QTEs are deferred.

## Build a new ending for each shift

Aim for the moment when a player says, “I remember that patient. I let them in. This is what happened.” A successful repair deserves a consequence worth seeing. A dangerous admission can turn a routine implant replacement into a frightening incident that hurts the people in the room. Choose the story you want to tell with the people the player actually saw that night.

You have creative control over viewpoint, art, motion, sound, pacing, editing and implementation. You can discard the CCTV framing, the fixed shot per patient, the scene order, the existing assets and the reel code. Choose which events deserve screen time. The [old preview](ward-preview-zh.mp4) records the version the owner rejected. Rook and Priya are available characters alongside the rest of the cast.

Use the completed appointments as the source for who was seen, who was admitted and how the shift ended. A mixed night, several dangerous admissions, a night when everyone was turned away, and a doctor's death halfway through the queue should each make sense on screen. Only admitted patients can undergo surgery at this clinic. If you invent a new consequence, make the written closing report agree with what the player sees.

In the current build, `VisitState.settlement()` feeds `ShiftState.records`. The director opens the film in `_start_reel()` and returns to the report through `_finish_reel()`. The old renderer lives in `game/scripts/ui/closing_reel.gd`. Case files contain patient identities, implant models and authored outcomes. The existing integration already handles skipping, replaying from a report page and starting another shift. Replaying a film should leave the player's report page and accounts intact. [Visit outcomes](../../../game/scripts/core/visit_state.gd) · [Shift records](../../../game/scripts/core/shift_state.gd) · [Game director](../../../game/scripts/ui/main.gd) · [Patient cases](../../../game/data/cases)

Deliver the remake working at the actual end of a shift. Watch it in motion at normal speed. Capture a new in-game clip and give the owner a reproducible way to see a different outcome. A good viewing test is whether someone can recognize a patient and describe the consequence before reading the report. Exercise both languages, reduced blood, an empty ward, an early death, skip and replay. Update the existing capture fixture and any tests tied to retired staging. Report what you built and what you actually verified in Chinese.

## Keep this idea for a later two-player version

Player one runs intake, checks the evidence and decides who goes through. Player two is the operating doctor. The person admitted at the front is the person on the table, with the same implant and the findings the first player obtained. The second player gets close to the affected body part, physically handles the old component, fits its replacement and performs a short timed input at a meaningful point in the operation.

For example, while changing a coupling in a patient's wrist, the doctor might feel the hand tighten. They can keep watching the part as it seats, or look up to see whether the patient is watching them. That choice belongs to the player. During facial surgery the face already fills the view. It can suddenly distort at any moment, even while the player's tool is engaged or between QTEs. The horror comes from working within inches of someone whose expression could change while the job still needs both hands.

When this idea gets its own prototype, test what the operating doctor can do while intake interviews the first patient or turns several people away. Preparing a likely implant or examining a returned part could give the front desk a useful finding. The hands-on operation and that division of attention are the owner's priorities for the future mode. [Earlier co-op exploration](next-game.md)

## What is already working

- Gameplay baseline `c36f883` on `main`. The M0–M6 play-loop redesign shipped. Ten patients use a bilingual counter with a registration entry, an independent slip, questions and two examination lamps. A single broken row can be ordinary wear. Two establish drift. Fixed nights K and L exercise different evidence. [Milestone record](../play-loop-redesign/PROGRESS.md)
- Rules 15 draw a physical tell and an end to the appointment independently on each committed PRESS. The tell chances are 25%, 45%, 65% and 85%. The respective end chances are 5%, 20%, 50% and 100%. A steady patient leaves and a drifting patient lunges when the end draw fires. [Rules and recorded checks](release.md)
- Patient protocol 5 handles typed questions and reviewed dictation. Each case holds the character's persona. Common instructions live in `agent_proxy/src/patient_instructions.mjs`. Each appointment starts its own session for dialogue and observable actions and clears it on exit. Godot owns diagnosis, evidence and settlement. The local game service has exercised real GPT-6 Luna. The public mock and forced-timeout Workers are available, and the public live Worker is kept disabled. [Patient instructions](../../../agent_proxy/src/patient_instructions.mjs) · [Local model and cache results](../live-model-results-2026-11-21.md)
- The baseline passed 7,921 engine assertions and bilingual UI and reduced-blood checks. Those results describe the previous build. For a quick offline start, run `.\run-game.ps1 -Patient script -Language zh -TestNight K` from the checkout. The build instructions and test entry points are in the [project README](../../../README.md) and [working instructions](../../../AGENTS.md).
