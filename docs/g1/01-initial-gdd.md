AI use: Claude drafted the earlier prototype. Codex revised this G1 document to follow the student's November 13 correction. The student chose observation-guide comparison and action-based screening; examples and numbers remain proposals.

# Before the Cut: Initial Game Design Document

Version 0.6, G1 Concept, 2026-11-14.

**Repository update, November 14:** this is now the ongoing `before-the-cut` repository. G1 documents are in `docs/g1/`. Claude/Fable is still implementing the revised game in the legacy workspace; new case data and pixel-art work have been observed, but completion is not verified. Source transfer waits until that writer stops. Technical results below are dated evidence for the earlier prototype, not tests of the current work. See the [transition record](../development/repository-transition.md).

## 0. Design authority and implementation status

**Current direction [Student]:** a reference sheet shows normal appearance, states and responses, similar to the comparison/checklist structure of the earlier impostor-game reference. The player compares the current patient with that reference to notice mismatches and judge possible cyberpsychosis risk before surgery.

**Choice of method [Student]:** inspect appearance, use a tool or request an action, have a conversation, or deliberately use confrontational/provocative language to observe the response. All are optional. The player chooses the order, combines or skips methods, and decides when to stop examining. The sheet is a reference, not a mandatory completion checklist.

This replaces both a universal re-check rule and any implied inspect-then-action sequence. A repeat check may be available, but it is optional. Conversation is an alternative evidence-gathering method, including optional verbal pressure; no player must use it.

**Build status:** the earlier three-patient prototype runs locally. Its scan/re-check rules, automatic red/green verdict hints, strain and scoring have not been migrated to this design. Existing tests and screenshots demonstrate that earlier build only. The revised observation guide, visible action responses and revised case logic are **planned**. See section 19 and the project plan. The earlier detailed specification is retained in a private local archive in the legacy workspace.

Labels used below:

- **[Student]** A direction explicitly chosen by the student.
- **[Proposed]** An example or concrete implementation choice to test.
- **[Open]** A choice that G1 does not settle.
- **[Existing]** Behavior in the earlier build, not evidence that the new design is implemented.

## 1. The X

> My game is screening patients through observation and simple interactions before cybernetic surgery, and you feel the suspense of deciding who is safe to treat.

Working title: **Before the Cut**. Fixed counter, Godot 4, 2D, individual project. **[Student]**

The concept is inspired by *Cyberpunk 2077*. Cyberpsychosis is a fictional condition in the Cyberpunk setting, associated with heavy augmentation and loss of control. We use it as a familiar premise, not as a claim that the term originated in the 2077 video game. The observation guide and screening rules in this project are invented gameplay, not canonical diagnostic criteria or real clinical tests.

The player's task is **risk screening before a procedure**, not proving a complete psychiatric diagnosis. A concerning presentation can justify referral without guaranteeing an attack.

## 2. Player and motivation

**Audience [Student]:** Cyberpunk 2077 fans interested in the implant-doctor role, plus players who enjoy close observation and simple deduction. Familiarity with the franchise should help the fantasy, but should not be necessary to read the guide or make a decision. Audience interest is a hypothesis, not measured demand.

**Primary motivations [Student]: Fantasy and Discovery.** Fantasy comes from acting as an implant doctor and choosing how to examine a patient. Discovery comes from uncovering what a patient's appearance and responses reveal, then wanting to meet the next visitor. Curiosity about an unfamiliar face does not require random case facts.

**Secondary motivation: Sensation.** A patient who might attack creates suspense. The response should remain readable and fair: the emergency shutter tests the player's response to a warning, while the examination still centers on evidence. Whether suspense improves the experience remains a hypothesis.

**Pitch scope, November 14:** the unconfirmed shuffled-arrivals proposal was removed from the G1 presentation. Fantasy, Discovery and Sensation remain the motivation hypotheses. Arrival order is an open design choice, not a promised feature or a reason to randomize patient truth.

| Hypothesis | Observable playtest behavior |
|---|---|
| Fantasy, primary | Explains a treatment/referral decision in the doctor's role and chooses or skips methods for a stated purpose |
| Discovery, primary | Voluntarily tries a useful check, revises an impression after a response, or chooses to meet another patient when stopping is available |
| Sensation, secondary | Notices a threat cue, responds with the shutter, and reports suspense rather than confusion or an unfair loss |
| Possible rival motivation | Chases a perfect score or attacks rather than examining patients; report that observation instead of forcing the original interpretation |

Explaining a mismatch shows rule comprehension; it does not alone establish curiosity or role immersion. No human playtest has been recorded. The G1 assignment asks for an observable motivation hypothesis and gives no numerical quota of motivations (rechecked November 13).

## 3. Genre, platform and session

- Fixed-screen inspection and light deduction, one visitor at a time. **[Student]**
- Godot 4 / 2D, Windows first. Pixel-art target, readable placeholders first. **[Student]**
- Mouse for observation and interactions; one emergency shutter key. **[Proposed]**
- First slice: one counter and three authored patients. **[Proposed scope]**
- A complete shift should be short enough to test repeatedly. Session length remains **[Open]**; no assignment minimum game duration was found. The 3-5 minute requirement concerns the G1 recording.

## 4. Core loop

1. **Arrive:** a patient sits at the counter and requests a procedure.
2. **Choose freely:** compare appearance, request an action or use a tool, start a conversation (calm or provocative), or make a decision with the information already available.
3. **Receive feedback if a check was chosen:** see a detail, a movement, a refusal or a conversational response. No action-test stage follows automatically.
4. **Compare and interpret:** use the sheet's normal reference to identify what differs and how much the evidence supports a conclusion.
5. **Choose again or decide:** switch methods, repeat a useful check, or select treatment/referral. No method-completion gate blocks a verdict.
6. **Resolve:** receive concise feedback showing which observations supported the result, then meet the next visitor. If an authored threat occurs, use the shutter.

The repeated decision is **do I know enough, or which optional check would help?** The list above describes a decision loop, not an ordered examination protocol. A player can skip all movement tests, skip all dialogue, or decide from appearance alone. Skipping a method may leave uncertainty; it does not prevent progression or rewrite the case truth.

## 5. Observation guide and interactions

### 5.1 The guide

**[Student]** A visible **Normal Reference Sheet** showing what normal appearance, states and responses should look like. The player compares the patient with it, much as a player compares a visitor with a reference in an impostor-screening game. It is not merely a log of abnormalities found so far. Small illustrations or concise examples can show normal states; exact entries remain proposed.

**[Proposed examples, not final symptoms]:**

| Optional method | Example normal reference | What the player may compare |
|---|---|---|
| Appearance | Hand rests without repeated clenching | Does the resting hand differ from the illustrated normal state? |
| Requested action | Releases a grip when asked | Does the completed movement match the expected response? |
| Dialogue, including verbal pressure | Follows the exchange coherently, even when annoyed | Does the response stay connected to the exchange, or show an authored warning pattern? |

These are illustrative entries to test, not final symptom criteria or three separate minigames. The minimum slice offers simple versions of all three optional methods through the same assessment interface. Specific content is still open.

A visible feature may be sufficient when the guide explicitly says so; other features only suggest a follow-up. Not every unusual appearance is a warning, and hostility or refusal alone is not proof of risk. The guide must tell the player the relevant distinction. Exact exceptions and evidence thresholds are **[Open]**.

### 5.2 What players do every few seconds

- Optionally inspect a body area and compare it with the reference sheet.
- Optionally move a simple tool or select an instruction such as "Grip" and "Release."
- Optionally choose a conversational approach, including a confrontational or provocative remark, and observe the response.
- Compare whatever was observed, then choose another method or make the treatment/referral decision.

These are choices available to the player, not steps to complete in order. **[Proposed implementation]** Use a small menu of authored questions and tones in the first slice rather than requiring typed free-text conversation. Verbal pressure is an available choice, never a required test.

Tool handling is simple. The first slice should test observation and judgment rather than precise aiming or a complex motor-skill minigame. Short captions can make a visible response accessible; captions must describe the observation, not announce the diagnosis.

### 5.3 Player interpretation

The guide gives a rule the player can apply. The patient record may save "kept gripping after the cue"; it should not automatically replace the player's reasoning with "RED: cyberpsychosis confirmed."

Whether the player actively marks a matching guide entry is **[Open]**. Start with a readable record and a clear final decision. Do not add a separate scoring puzzle for filling out paperwork.

The reference sheet records the expected normal states; the patient record stores what this patient actually showed. Keep those two functions visually distinct. Looking at or ticking every row is not required before a verdict.

### 5.4 Pressure and failure

**[Student]** Possible sudden attacks and consequences for a bad judgment.

**[Student]** The player may deliberately provoke the patient through dialogue to see how they react. **[Proposed fairness rule]** Ordinary anger at an insult is not automatically a cyberpsychosis tell. The fictional reference and case data must distinguish a normal irritated response from any meaningful warning. How pressure affects willingness to cooperate or threats is still open; it cannot change the fixed underlying case assessment.

**[Proposed]** An unsafe procedure, unnecessary rejection or failed defensive action can harm the shift result. A patient who refuses an interaction can make the player choose another route or defer treatment. Threats have a visible cue and one defensive action; the reaction clock never runs during reading or a model wait.

A visit-level interaction budget is a candidate if players otherwise run everything mechanically. The old "3 checks, 4 tools, strain 0-4" is **not** a settled rule for this design. Do not add it to the pitch as a student decision.

## 6. A short example for the G1 pitch

**[Proposed, not implemented; one possible route, not required steps]**

| Moment | Player action | Game response | Interpretation and next action |
|---|---|---|---|
| Arrival | Inspect a hand that twitches | The hand briefly contracts | A guide entry suggests checking voluntary release |
| Interaction | Ask the patient to grip a handle, then release | They agree, but the hand keeps gripping after the cue | Compare the continued grip with the guide's warning pattern |
| Decision | Defer the procedure and refer the patient | The visit resolves according to the fixed case | The feedback identifies the observed warning and what it supported |
| Optional threat branch | Respond if a lunge is visibly telegraphed | The game opens the defensive window | Close the shutter; no model call runs here |

This illustrates one choice of action, response, interpretation and next action. The player could instead compare appearance only, talk first, apply verbal pressure, or stop checking earlier. No action test is compulsory. This example does not imply that every referred patient attacks or that one failed movement diagnoses every case.

## 7. Initial patients and content authoring

**[Proposed]** Keep three patient slots, with different outward behavior and fixed evidence:

1. A tutorial patient that introduces the normal reference and the choice of methods, without requiring a fixed order.
2. A patient whose unusual appearance needs context before deciding.
3. A patient whose composed manner does not rule out a warning response.

The older prototype names Kip, Rook and Vale may be reused, but their old scan tables are not automatically the new design. Do not treat the exact characters or these three roles as student-approved content.

Each case needs only a brief arrival, visible details, a few authored responses, a fixed assessment, permitted cooperation choices and concise outcome feedback. Avoid long branching scripts. A production agent can propose cases from this structure; a reviewer checks that the guide supports the decision before the student accepts the content.

## 8. Evidence and outcomes

The game has a fixed underlying case assessment. It does not change the truth to agree with the player's guess.

- **Proceed with the requested procedure:** always selectable during a visit; whether it is well supported depends on the evidence gathered and the fixed case. No mandatory method checklist unlocks it.
- **Refer / defer:** appropriate for elevated or unresolved risk according to the authored rules. Referral is a normal screening outcome, not inherently a mistake.
- **Emergency shutter:** a protective response to an immediate threat. A risk indicator and an immediate threat are separate facts.
- **Continue examining:** useful while an available interaction could change the decision.

Exact rules for enough evidence, uncertainty and partial credit remain **[Open]**. The player can decide with incomplete information, bearing its uncertainty. Author at least one understandable evidence route for each case, but do not enforce that route as a required player sequence.

## 9. Scoring and losing

G1 needs understandable stakes, not final balance numbers. **[Proposed]** The shift report can summarize correct treatment/referral decisions, unsupported decisions and harm prevented or suffered. Rewards should make careful screening useful without making "operate on everyone" or "reject everyone" the obvious best strategy.

The existing prototype's 300-credit fees, 400 rent and 700 clean-shift target describe its old rules only. Revised scoring and whether credits are needed at all remain **[Open]**. No economy, upgrades or surgery simulation is added.

## 10. Fairness and shortcuts

- Appearance should direct attention; it should not reduce every case to one reused cosmetic tell.
- A refusal, accent, rude line or calm personality must not become the diagnosis.
- When the agent blocks an interaction, another authored route or a fair referral outcome must remain possible.
- Symptoms and their meaning must be stable for a given case and version.
- A repeat test is permitted when a case needs it, not required for every sign.
- Feedback must explain an outcome using evidence the player could have obtained.

Test whether the guide becomes rote matching. If it does, first adjust how visible signs direct the next interaction rather than adding more systems.

## 11. Design pillars

1. **Readable clues:** the guide and short responses are legible without prior Cyberpunk knowledge.
2. **Freedom to choose checks:** the player chooses observation, an action or dialogue, and may skip any method.
3. **Distinct patients:** appearance, needs and cooperation create curiosity about the next arrival.

The pillars constrain scope. A long dialogue tree, complicated surgery or a large symptom encyclopedia would work against them.

## 12. Progression and curiosity

The first slice introduces the guide, then varies how patients present and cooperate. A brief glimpse or one-line teaser can suggest the next visitor. This is a content pattern, not an additional progression system.

More patients and returning visitors are stretch ideas only. Test the initial three before authoring more. Arrival order remains open; patient truth and evidence stay fixed.

## 13. Controls and feedback

**[Proposed]** Click to inspect, request an action or choose a dialogue line/tone; optionally guide a simple tool; click a verdict whenever ready; press Space for the shutter. All examination methods are accessible from the same visit screen. Do not require a LOOK action before allowing conversation.

Keep the guide beside the patient. Record observations in plain language. A refusal means "test not performed," not "abnormal test." On timeout the scripted patient responds. No model is needed for animation timing or the defensive window.

## 14. Technical edge cases to cover

| Case | Required behavior |
|---|---|
| Patient refuses | No invented result; offer a permitted alternative or allow a fair referral |
| The same completed action is repeated | Apply the authored case rule; the model cannot randomly reroll evidence |
| Player skips a method or decides early | Allow the decision; preserve uncertainty and fixed case consequences. Do not force completion or treat missing evidence as normal |
| Player provokes the patient | Use only case-legal responses; ordinary anger is not automatically a diagnosis |
| An animation is hard to see | Replay or a descriptive caption; no diagnostic answer revealed |
| Model answer is invalid or late | Use the stateful script for that turn |
| Threat begins | Local warning and shutter timing; no text-reading or model delay consumes the window |

## 15. Scope and first cuts

**Included target:** one counter, one normal reference sheet, simple optional appearance/action/dialogue methods (including verbal pressure), three fixed patients, treatment/referral decisions, one defensive action, feedback and restart. Script baseline and bounded patient agent use the same evidence. There is no required examination order.

**Excluded:** exploration, surgery minigames, trading, upgrades, free-text chat, procedural mysteries and a general-purpose case editor.

**Cut first:** sound, decorative art, extra patients and elaborate animation. Preserve the guide, readable response, judgment and feedback. The basic tool response itself is gameplay, so it cannot be replaced by final diagnostic text just to save animation work.

## 16. Patient agent hypothesis and boundary

The agent selects cooperation, refusal or a permitted conversational response to the player's chosen action or tone. The game's fixed case determines physical test results and any conversational pattern that counts as diagnostic evidence. The agent can vary permitted social behavior and wording, but cannot invent symptoms, change reference criteria, rewrite the case assessment or directly trigger attacks. Adding tone-aware events and validating diagnostic dialogue patterns is planned work, not a feature of the old executable.

**Hypothesis:** the agent may respond coherently to combinations of optional checks and tones beyond the combinations explicitly covered by authored branches. If those responses give players a reason to change their next check, visits may feel less routine.

**Baseline:** a stateful authored script with the same facts, legal moves and limits. A script can also respond to history; the comparison is with our implemented baseline, not a claim that scripts cannot be reactive.

**What may be lost with that baseline:** flexibility beyond its explicitly authored branches. For example, a player might combine a reassuring question, a provocative remark and a new action request. The comparison should test whether the response remains consistent with that sequence and changes the player's next choice. This is a proposed test situation, not an implemented feature or a claim that a script cannot handle the same sequence. Extend the baseline fairly to cover common situations; do not deliberately make it unresponsive. The examination loop remains playable without AI.

**Playtest:** give both conditions the same case facts, visit history, legal moves and limits, then compare next-action choices and players' reasons. Inspect coherence and waiting separately. Wording alone does not establish a useful agent, and equal results would not support an agent advantage. No result has been measured yet.

Configuration A0 describes how this target maps to the earlier bounded interface.

## 17. References and attribution

| Reference | Specific borrowing | Change in this project |
|---|---|---|
| *Cyberpunk 2077* | The implant-doctor fantasy and cyberpsychosis premise | Original patients and invented screening guide; no claim of canonical diagnostic criteria |
| *Papers, Please* | One visitor, evidence at a desk and a consequential decision | Examination and behavior instead of a growing document bureaucracy |
| *That's not my Neighbor* | Compare visitor features with a reference/checklist to notice mismatches | A sheet defines normal patient states; appearance, actions and dialogue are optional ways to compare, with no fixed sequence |
| *Probably Stolen* | Cyberpunk counter presentation and a stream of visitors | Screen patients instead of pricing objects |

References are described from official pages and developer material, not claimed personal play sessions. See `06-sources-and-requirements.md` for links. No reference-game assets, dialogue or source code are reused in the Godot game; this is mechanic and setting inspiration, not permission to redistribute their content.

The G1 cover separately uses a student-supplied *Cyberpunk: Edgerunners* image as visual reference. It is credited in the deck notes and `assets/cyberpsychosis-reference-provenance.md`; exact frame provenance and permission are open. It is not a game asset.

November 14 presentation update: slide 2 shows an official *That's not my Neighbor* checklist screenshot credited to Nacho Sama, with source and use status in `assets/tnmn-checklist-reference-provenance.md`. It is not a game asset. Beside it, the restored Before the Cut screenshot illustrates the earlier clinic layout; its scan/re-check rules and verdict labels are not the current design.

## 18. Open questions and tests

| Question | How to answer it |
|---|---|
| Which two or three visible patterns are readable and distinct? | Build one simple response at a time and ask a new player to describe it |
| Which appearance cues are sufficient, and which need an action? | Draft guide entries, then check every case against them |
| How much evidence supports treatment or referral? | Author fixed case expectations before coding; test explanations after each decision |
| Does tool movement add useful interaction? | Compare a simple gesture with a button-issued instruction |
| Is a check limit needed? | Watch whether players inspect purposefully or run every action |
| Can players tell that every method is optional? | Check whether they feel forced to finish all rows or ask every question before a verdict |
| Does verbal pressure reveal useful information? | Compare authored reactions; check that players do not equate ordinary irritation with risk |
| Are refusal and symptoms being confused? | Include a clear refusal without an abnormal completed response |
| Does the patient agent change the next action? | Compare script/model action sequences and player explanations |
| Can every allowed refusal sequence be handled fairly? | Enumerate reachable paths and allowed referral outcomes |
| Do attacks add suspense without dominating screening? | Observe warnings and defensive actions during a playtest |
| Is another visitor appealing? | Ask whether the player wants to continue and observe their choice |

## 19. What exists and what is next

**Existing, verified November 12:** a local Godot 4.7.2 counter prototype; 269 rule assertions, 141 UI-flow assertions, 28 proxy tests and 73 real-client mock checks. Those checks cover the old re-check design. No live model call, human playtest, deployed proxy or standalone export is recorded.

**Revised G1 proposal, November 13:** the normal reference sheet and player-chosen observation/action/dialogue methods are the design authority. All methods, including verbal pressure, are optional. The November 14 slide combines labeled early/reference screenshots with one illustrative optional route; it does not demonstrate an implemented revision.

**Next implementation:** write a small normal reference sheet and one fixed patient; make simple observation, action and dialogue options available without a required order; let the player skip checks and decide. Add case-legal tone responses and update rules/validation/tests. Add the other patients only after that loop is readable. Keep the existing agent transport and fallback where they fit.

The G1 assignment asks whether the idea is clear and achievable enough to justify prototype work. It does not require the revised loop to be completed before this concept recording.
