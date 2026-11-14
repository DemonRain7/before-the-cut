AI use: Codex rewrote the student's G1 narration in spoken English for first-time viewers, following the normal reference sheet and optional examination methods. Student review and recording are pending.

# Before the Cut: G1 recording script

Revised **November 14, 2026**. **555 spoken words**, matched to the existing nine slides. Read only the paragraphs under each slide title.

At 120 words per minute, the narration is about **4:38**. The cue sheet adds short pauses and targets **4:57**. These are estimates. The required recording length is **3-5 minutes**; actual rehearsal and recording are still pending.

Use this as a draft for your own presentation. Confirm the first-person claims before recording. An earlier scan/re-check build works locally. The revised guide and action responses are planned; live-model testing and human playtests are still pending.

| Slide | Suggested timing | Words | Subject |
|---|---|---|---|
| 1 | 0:00-0:29 | 53 | Before the Cut |
| 2 | 0:29-1:13 | 84 | How a patient visit works |
| 3 | 1:13-1:46 | 62 | Players, motivations and pillars |
| 4 | 1:46-2:27 | 78 | Concepts and references |
| 5 | 2:27-3:02 | 66 | The patient agent's role |
| 6 | 3:02-3:30 | 52 | How the game and agent work together |
| 7 | 3:30-4:02 | 60 | Scope and budgets |
| 8 | 4:02-4:27 | 45 | Risks and mitigations |
| 9 | 4:27-4:57 | 55 | Prototype approval and next steps |

## Slide 1: Before the Cut

Before the Cut is a game about deciding whether a patient is safe for cybernetic surgery. You play a doctor who installs mechanical body parts. It's inspired by Cyberpunk 2077 and its fictional condition, cyberpsychosis, where people with extensive implants can lose control. The tension comes from examining someone who might attack you.

## Slide 2: How a patient visit works

Here's what you do. On the left is our early prototype; on the right is a reference game's checklist. Your sheet describes normal appearance and behavior. You can inspect their appearance, ask them to move, or talk, including provoking a reaction. Every method is optional, in any order. For example, you ask a patient to release a handle, but their hand stays closed. Use that clue to decide whether to check more, approve surgery, or refer them elsewhere. If attacked, close the safety shutter.

## Slide 3: Players, motivations and pillars

The audience is Cyberpunk fans and players who enjoy spotting clues. The main motivations are Fantasy, feeling like the doctor, and Discovery, uncovering a patient's condition. Sensation adds the suspense of an attack. My design pillars, or guiding priorities, are clear clues, freedom to choose checks, and patients with different personalities. I'll watch whether players explain their decisions and want another patient.

## Slide 4: Concepts and references

I considered two alternatives. In the island concept, you searched for your missing sister. Time kept restarting, but you used what you'd learned to reach new clues. It needed too many locations and story events. In the shop concept, you inspected customers' objects and decided what to pay for them. I chose the clinic to keep the small counter setting while investigating people through their reactions. The references here inspired the visitor flow, appearance comparisons, and cyberpunk setting.

## Slide 5: The patient agent's role

Those reactions are where AI comes in. It plays the patient, choosing whether to cooperate, refuse, or answer. A refusal might make you try another examination; refusal alone isn't a symptom. I'll compare AI with written response rules that remember the visit. AI might handle combinations those rules don't cover. The test is whether that flexibility changes the player's next check, not just the dialogue's wording.

## Slide 6: How the game and agent work together

This diagram shows how that works. AI receives a character brief, the visit so far, and your action. The game checks its reply, using a prepared response if it breaks the rules or arrives too late. Symptoms, attacks and scoring follow fixed game rules. AI cannot invent evidence or change the answer.

## Slide 7: Scope and budgets

For scope, I'm proposing one counter and three patients, without a surgery minigame. The earlier prototype works, and the revised examinations are next. Ten AI requests per shift would cost about four tenths of a cent, below a two-cent limit. Replies should take one second, switching to prepared responses after two point five seconds. These are estimates, awaiting live testing.

## Slide 8: Risks and mitigations

The biggest risks are my experience and the deadline: I'm a beginner working alone. That's what Team and Timeline mean here. I'll keep the prototype small, cut decorative polish first, and recruit playtesters. The other four rows cover originality, audience interest, technology, and repetitive gameplay.

## Slide 9: Prototype approval and next steps

Finally, I'm asking to build and test this version. I chose the clinic and optional checks; the AI assistants helping me develop the game suggested three patients. I'll test whether players understand their decisions and whether patient reactions affect their choices. If players are guessing, or AI only changes wording, I'll revise before adding content.

## Before recording

- Rehearse once with a timer. Pause briefly when changing slides.
- In slide 2, identify the early clinic prototype on the left and the checklist reference on the right, then point to our optional examination loop below. The screenshot rules are not the revised game rules. In slide 6, follow the diagram from left to right.
- Keep the numerical budgets and the distinction between estimates and measured results. Four tenths of a cent is USD 0.004, not USD 0.40.
- Check sound, readability and the actual 3-5 minute duration before uploading.

To revise the script later, edit narration in deck-source.mjs, rerun build-notes.mjs, and sync the saved deck notes. Sources remain in the deck notes and 06-sources-and-requirements.md.
