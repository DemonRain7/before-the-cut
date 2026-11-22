# Play loop redesign: ask, test twice, call

Written on November 21, 2026 by Claude for the student. Codex builds it from [KICKOFF.md](KICKOFF.md) and keeps [PROGRESS.md](PROGRESS.md).

This is a design and a build plan. Nothing in it is built. No game file, data file or test was changed to write it, and no model was called. Baseline: `main` at `31c8dbd`, rules version 12, patient protocol 4. Function names and line numbers are as read at that commit. Where this document and the code disagree, the code wins and PROGRESS.md gets one line.

Every number here comes from a scratch model outside the engine (section 10). They are starting values. What must hold after the build is the set of measured relations R1 to R11.

## 1. What the student asked for

The student, November 21, after the full patient-agent build:

> 就我觉得这块的逻辑应该是需要好好考量的，现在这样肯定不行，选择太多没有引导性、然后还会有patience次数限制，又加上我们还有agent、会让整个input复杂度指数提升，目前设计的包括玩起来都会很不合理。

In English: the play logic needs real thought. As it stands it will not do. There are too many choices and nothing guides them, a limit on patience sits on top, and the agent's free input multiplies what a player can enter. The design and the way it plays are both unreasonable.

Earlier the same day (already in `HANDOFF.md`):

> 所有的这些我总感觉有些用得到有些用不到，就感觉可能有些部分玩家一整局都不会用就能得出结论。

In English: some of these tools get used and some never do. A player can finish a whole night without parts of them and still reach the calls.

Codex's own report on the finished build named two weaknesses. The patient is too cooperative: the live model refused 0 of 58 civil, 1 of 58 neutral and 0 of 58 rude requests. Free questions are not recognized reliably: 81 of 240 were missed in the live test, and accuracy was not measured again after the classifier changed.

The audit asked for in `docs/development/play-logic-review-brief.md` is cancelled by the student. This document replaces it.

## 2. What is wrong today

| Complaint | What the build does | Cause |
| --- | --- | --- |
| Too many choices, nothing guides them | About 17 clickable things and 26 verbs during an exam. LOOK, LIGHT, GRIP, PORT, ASK and PRESS each read one sheet line at nearly the same price. Computed play of the built rules: three instruments 79.84 % right calls, plus ASK and PRESS 95.47 %, plus CALM 98.73 %. | The choices are equal in value and 5 to 7 lamps pay for nearly all of them. The best routine is "do almost everything, in any order". A choice between equals cannot be guided. |
| A patience limit on top | Seven things move the lamps at five prices: a test 1, a refused test with INSIST 2, ASK 1 (a dodge takes the lamp and gives nothing), PRESS 2, the second PRESS all, a wrong code 1, CALM gives 1 back for 30 credits, twice a visit. | The limit is real but soft and hard to predict. It reads as a tax on every click instead of the rule of the game. |
| The agent multiplies the input | A typed or spoken line goes through a ten-class router. A line read as a listed question costs a lamp, so a "YOUR MEANING" menu asks the player to confirm. | Free text was given the job the ASK button already has, with a price attached. It is either a slower and less reliable ASK, or flavour. |
| The patient never changes a decision | Consent to a test was left to the model, and the model consents every time. | INSIST and CALM are built on refusals that do not happen. |
| Some tools are never needed | CALM adds about 3 points to a routine already at 95 %. A free look writes a note on the row (`look()`), and the counter sprite draws port threads before any test (`patient_rig.gd` `_threads_layer`; verify). Fourteen training tips, thirteen of them before the first call. | Same cause as the first row. |

One fact sits under all of it. With all five sheet lines read there is no question left: a steady visitor shows at most one broken line and a drifting one at least two. So some limit has to exist, and it should be the simplest limit there can be. The heart of the game is the visit that ends on exactly one broken line: wear or drift? Everything else should lead to that case and offer clean ways out of it.

## 3. The new loop on one page

The rule a player can hold in their head:

> **Ask what's wrong. Test where it hurts. Two broken lines: Trauma Team. One can be wear: your call.**

A visit has three parts and each kind of input has one job.

| Part | Input | Job | Price | Can it hurt? |
| --- | --- | --- | --- | --- |
| TALK | chips, typing, voice | Find out where to look. Read the SPEECH line. | free, as often as you like | never |
| TEST | LIGHT, GRIP, PORT, PRESS | Read one sheet line. | one lamp each, two lamps a visitor | a drifting visitor may turn |
| CALL | TREAT, TRAUMA TEAM, BREAK | The bet. | ends the visit | yes, that is the bet |

Nothing is required and no order is enforced. A player may call at once, skip the talk, or test before asking. The guidance comes from what the patient says, which is fiction, not a checklist. This keeps the agreed rule in `AGENTS.md` ("Do not reinstate a mandatory checklist, universal re-check or fixed examination sequence").

How it answers each complaint:

- **Guidance.** The patient complains about parts of themselves. A complaint is more likely on a broken part, so it tells the player which test to run first. The card and the test button show a "?" where the patient complained.
- **The limit.** One number, the same for everyone: two tests. Nothing else spends a lamp except a wrong courier code. Nothing gives a lamp back.
- **The agent.** Typed and spoken words can never cost a lamp, end a visit or set anyone off. So a misread line is harmless and the confirmation menu goes. The model voices facts the game owns.
- **Every tool earns its place.** Four tests for two lamps means two are always left unread. Which two is the decision, and the complaints make it a reasoned one.
- **The patient changing a decision.** What the patient says now decides the player's next test. That chain is recorded and can be compared between the scripted and the generated patient (section 6).

## 4. The rules

Words: a sheet has five lines (`eyes`, `hands`, `port`, `speech`, `temper`). Each line shows a normal or a broken sign on this visit. A steady visitor has at most one broken line (wear). A drifting visitor has at least two.

### 4.1 Lamps

- Every visitor arrives with two lamps: one rule number (`visit.lamps`, 2). The per-character `patience` of 5 to 7 is retired from the ten case files, the case template and the validator.
- A lamp is spent by a test that has not been run on this visit, and by a wrong courier code. The price is always one.
- Reopening a finished test is free and safe, as today.
- Nothing returns a lamp.

### 4.2 Complaints

A complaint is one sentence in which the patient names a part of themselves that bothers them. It is the same sentence whether that part is broken, worn or fine.

- **Rows.** Complaints exist for the four tested lines: eyes, hands, port, temper. SPEECH is read by talking and has none.
- **Draw.** Per visitor and per row, at the time the night is drawn: with probability `complaints.broken` (0.65) when the row's sign is broken on this visit, drift or wear alike; with probability `complaints.normal` (0.2) when it is normal. Use a separate generator seeded like wear (`complaints:<seed>`), so that for a given seed the visitors, truths, signs and wear of rules version 12 do not change.
- **The protected first visitor** (steady, no wear) has exactly one complaint, on a row drawn evenly from the four. It teaches the chain: complaint, test, normal, tick, TREAT.
- **Fixed nights.** A visitor in `data/nights.json` may list `complaints` explicitly. Without the field they are drawn. Nights A to J draw them. Nights K and L list them (section 9).
- **Delivery.** Asking "What's bothering you?" delivers up to `complaints.per_reply` (2) complaints not yet told, in a drawn order. Asking again delivers the rest, then an authored "that is all". A visitor with none answers with their authored "nothing" line. Delivery costs nothing, rolls no surprise and is not an action for the snap count.
- **A part named by the player.** When a typed or spoken line names a tested row by its sheet word in either language (matched by the game from the catalogs, not by the model), that row is answered first: its complaint if it has one, otherwise the "nothing" line.
- **Volunteered.** After `agent.beats.idle_seconds` (12) quiet seconds a visitor with an untold complaint offers one. It counts against the existing optional-line budget (at most two idle lines a visit). The scripted patient does the same. A player who never asks still gets pointed somewhere.
- **The card is the authority.** Each delivered complaint writes a game-owned note on its card row (`Complains: <the authored sentence>`) and puts a "?" on that row and on the matching test button. The model's wording never writes a note. A symptom the model invents in small talk marks nothing.
- **Nothing leaks.** A complaint says nothing certain: 35 % of broken rows draw none and 20 % of normal rows draw one. Right and wrong still come only at closing.
- **Closing report.** Each visit shows which rows were complained about, which were tested and what each row really was, and the night shows "you followed X of Y complaints".

### 4.3 Talk

- The dialogue strip offers the complaint question and the visit's three listed questions. All are free and all are answered the first time. Dodges are removed.
- A typed or spoken line is routed as today, with one more class (`complaint`). A line read as a listed question is answered at once: no price, no "YOUR MEANING" menu. A line read as `complaint` delivers complaints. Everything else is conversation.
- Typed words never spend a lamp. A typed request for a test (`tool_request`) is answered in character and the matching test button pulses; only the button runs the test. A rude line (`provocation`) is conversation; only the PRESS button presses. CTRL+ENTER as a typed PRESS goes (`main.gd` `SAY_HINT`, `SAY_VOICE_HINT`).
- SPEECH evidence stays in the authored answers to the listed questions (the November 21 evaluation: generated speech carried a normal sign 49 of 120 times). The earned-cue gate for SPEECH and TEMPER stays.
- A question the router missed must never look answered. Only an answered listed question ticks its chip and writes `Says: …` on the card.
- The cap of 16 patient replies a visit stays (student, November 15). After the cap, chips still work with the authored lines, so a visit can always be finished. Verify.

### 4.4 Tests

- Four tests: LIGHT reads eyes, GRIP reads hands, PORT reads port, PRESS reads temper. One lamp each. Always granted.
- The patient's authored first reaction to a test (`checks.<tool>.first`: comply, stall or `explain:<claim>`) is spoken as the close-up opens. It is flavour and decides nothing.
- INSIST, refusals and the sealed port go. The sleeve comes off as part of the PORT test. Vale's `insist: refuse` goes.
- A row's sign is shown only by its test. LOOK is removed as a source of evidence: no row note comes from a look, and the counter sprite must not show a broken sign before the row is tested (port threads today; check eyes and hands the same way). A click on a part of the patient highlights the matching test button and names its price.
- After a reading the close-up shows the sheet line for that row beside it, with two buttons: tick and cross. They set the same mark as the card (`cycle_mark`). The game does not judge the reading. The card shows the tally of crosses.

### 4.5 PRESS and BREAK

- The first PRESS is the TEMPER test: one lamp, the patient reacts, the visit goes on.
- BREAK is the second push, with the warning it has today. A steady visitor walks out unpaid. A drifting visitor comes at the glass, and SPACE drops the shutter.
- BREAK is available once TEMPER has been tested on this visit, or when no lamp is left. It needs no lamp and takes whatever is left. So it is always reachable: at once, or after one PRESS.
- A caught BREAK pays the fee plus `scoring.press_catch_bonus`, lowered from 150 to 50.

### 4.6 The call

TREAT and TRAUMA TEAM are unchanged and allowed at any time. The shutter outside an attack is unchanged (`locked_out` 0 for a drifting visitor, `false_alarm` −100 for a steady one) and is not taught as a call.

### 4.7 No lamps left

The student's rule of November 15 stays: a visitor with no patience left leaves by themselves, nothing gained or lost (`gave_up`). Two things change because an empty bar is now the normal end of an exam. The wait grows from 8 to 30 seconds (`patience.leave_ms`). The clock runs only while the counter is idle: it stops while a paper, a close-up, the typing line, voice capture, a spoken line or a confirmation is open. The visitor says so when the bar empties and the lamps show the wait.

### 4.8 Surprises

- Only a test or a PRESS can set a drifting visitor off. Talk never does, and neither does a courier code, right or wrong. Players get one sentence: "Only a test or a push can set them off."
- Snap: `grace` 3 → 0, `step` 0.08 → 0.06, `max` 0.3 → 0.18. That is 6 % after the first test and 12 % after the second, about 17 % of drifting visitors who are tested twice.
- Flares are unchanged. They give TEMPER evidence without a lamp; report how often.

### 4.9 Contacts

Unchanged: two couriers a night, an alias and two clues each, a drop pays 300, a right code is free, a wrong code costs one lamp (the student's rule of November 17). One lamp is now half an exam, so a careless code hurts. Measure it (R11). On the training night the courier is the second visitor instead of the first (section 8).

### 4.10 Scoring

Unchanged apart from the catch bonus.

## 5. What goes, what changes, what stays, what is new

### Goes

| Thing | Rules key | Code and data |
| --- | --- | --- |
| CALM | `reassure` | `visit_state.gd` `reassure_cost` 419, `reassure` 425; `main.gd` `act_reassure` 2120; case `lines.reassure` |
| INSIST, refusals, sealed port | `costs.insist`, `costs.free_sealed_repeat` | `visit_state.gd` `check_status` 233, `check_cost` 241, `sealed_repeat` 252, `check_outcome` 256, `legal_moves_for_check` 265, `apply_check` 289; case `checks.<tool>.insist`; `case_db.gd` `reachable_rows` (every row is reachable now) |
| The price and the dodge of ASK | `costs.ask` | `visit_state.gd` `ask_cost` 372, `legal_moves_for_ask` 376, `apply_ask` 389; case `topics[].first`, `lines.deflect` |
| "YOUR MEANING" | | `main.gd` `act_say` 2193, `_offer_reading` 2225, `_choose_reading` 2236; the price fields of the patient protocol |
| LOOK as evidence | | `visit_state.gd` `look` 209; `main.gd` `act_look` 1794; `patient_rig.gd` `_threads_layer`; case `looks` |
| Typed PRESS | | `main.gd` `SAY_HINT` 258, `SAY_VOICE_HINT` 265, `_input` 3665 |
| The lamp gates of PRESS | `costs.require_press_lamps` | `visit_state.gd` `press_breaks` 449, `can_pay_press` 459, `press_cost` 463, `press` 470 |
| Per-character patience | | case `patience`; `case_db.gd` validators |

Remove what goes. Do not leave a legacy mode, a switch back to version 12 or dead data. The old loop stays reachable through the tag `loop-v12`.

### Changes

| Key in `rules.json` | Version 12 | Version 13, start | May be tuned within |
| --- | --- | --- | --- |
| `visit.lamps` (new; replaces case `patience`) | 5 to 7 | 2 | fixed |
| `costs.check` | 1 | 1 | fixed |
| `costs.press` | 2 | 1 | fixed |
| `costs.ask` | 1 | removed (free) | fixed |
| `scoring.press_catch_bonus` | 150 | 50 | 0 to 100 |
| `patience.leave_ms` | 8000 | 30000, idle time only | 20000 to 45000 |
| `snap.grace` / `step` / `max` | 3 / 0.08 / 0.3 | 0 / 0.06 / 0.18 | to meet R10 |
| `contacts.training_slot` (new) | first visitor | 2 | fixed |
| `version` | 12 | 13, with a "Version 13" paragraph in `note` | |

### New

| Thing | Where |
| --- | --- |
| `complaints` rules: `enabled` true, `broken` 0.65, `normal` 0.2, `per_reply` 2 | `rules.json`; tune `broken` within 0.55 to 0.8 and `normal` within 0.1 to 0.3 |
| Complaint sentences | `cases/<id>.json` `complaints: {eyes, hands, port, temper, none}`; Chinese in `lang/zh/cases/<id>.json` |
| The draw and its state | `shift_state.gd` `draw_night`; `visit_state.gd` (`complaints`, `complaints_told`, a `complain()` call); `nights.json` (optional `complaints`) |
| The complaint question and the question chips | `main.gd`, `dialogue_box.gd` |
| Tick and cross inside the close-up, "?" tags, the tally | `scope_view.gd`, `clipboard.gd`, `clinic_view.gd` |
| Router class `complaint`, dialogue event `complain` | `patient_intents.json`, `agent_proxy/src/core.mjs`, `game/scripts/core/patient_agent.gd`, `scripted_brain.gd`, mock fixtures |
| Fixed nights K and L | `nights.json` (started with `.\run-game.ps1 -TestNight K`) |
| Stage fields: complaints told, tests in order, complaint followed | the closing report and the evidence the E6 sheet reads (`tools/eval/README.md`) |

### Stays

The sheet, its five lines and the threshold of two. Wear at 0.5 with the protected first visitor. The drift draw and the broken-row weights. Signs, parts and art. Scoring apart from the bonus. The closing reveal and the rule that nothing leaks during play. Contacts, clues, codes and drops. The glass, the shutter, attack timing and repairs. Flares. A killed doctor ends the night. The 16-reply cap. Voice input. One session per appointment. The scripted, mock and live patients. The optional-line budget. The earned-cue gate. Authored ASK answers. Both languages changed together.

## 6. The patient AI after the change

**What the model does.** It speaks. It carries the conversation in the patient's own identity, work, voice and motive. It says the complaints the game hands it in the patient's words. It reacts to tests and pushes. It offers the optional lines.

**What the game owns.** Every fact and every change of state: which complaints exist and when they are told, the card notes, consent to tests, readings, lamps, surprises, the call, the money.

**Rules for the prompt.**

- A complaint enters the prompt only when it is being delivered now or was delivered earlier in this appointment. Untold complaints are never in the prompt.
- The model may not state a test result, call a part fine or broken as a fact, or name a new symptom of the eyes, hands, port or temper. It may say what the patient feels about a delivered complaint.
- The authored complaint sentence is the fallback whenever the reply fails validation, arrives late or the cap is reached, exactly as authored ASK answers work today.
- Refusal, irritation and warmth stay colour. Consent is the game's, because the live model consented 173 times in 174.

**The router.** One more class, `complaint`: the player asks what is wrong, what hurts, how the patient feels, or about a part. The instruction changes its bias. Today a wrong match on a listed question costs the player a lamp, so the router was told to be sure. Now a wrong match costs nothing: when a line could be one of the listed questions or the complaint question, choose it. `unclear` goes to conversation.

**The scripted patient and the mock.** Both deliver the authored complaint sentences, the "nothing" line and the "that is all" line. The mock gets fixtures for the `complaint` class and the `complain` event.

**Protocol.** The enum of the router and the events of the dialogue request change, and the price-confirmation fields go. That is protocol 5. The public mock Worker speaks protocol 4 until it is redeployed, and deployment needs the student's own yes. If a limit changes, change `rules.json` (`agent`) and `agent_proxy/src/core.mjs` (`DEFAULT_LIMITS`) together.

**Build it in two steps** so that the game is whole even if the second is not reached. Step one changes nothing on the wire: chips and tests work in every patient mode with authored lines, a routed listed question is answered free, the menu is gone. Step two is protocol 5: the `complaint` class, the voiced complaint, the prompt rules and the new bias.

**A slim live evaluation**, only with the student's yes for paid calls (provider, model, number, cost). At most 400 requests:

| Probe | Requests | Target |
| --- | --- | --- |
| L1 Listed questions, paraphrased, both languages | 120 | missed at most 15 % (was 81 of 240) |
| L2 Complaint questions, general and by part, both languages | 80 | read as `complaint` at least 85 % |
| L3 Small talk controls | 80 | read as a question or a complaint at most 10 % |
| L4 Complaints voiced: 10 characters, 4 rows, 2 languages | 80 | valid and naming the right part at least 95 %; a stated test result 0 |
| L5 Small talk about health with no complaint to give | 40 | an invented symptom of a tested row at most 5 % |

A missed target is reported, not hidden. L4 or L5 failing means complaints are spoken from the authored sentence in live mode too.

**What the comparison can now show.** The course gate asks for the in-game agent shown against the scripted version with an observable effect on the player's next choice. The chain "the patient complains about a part, the player's next test is that part" is that observable. It is recorded as stages only, never words, in both modes, so the follow rate can be compared.

## 7. The screen

Targets, not pixels. Codex places them in the 640×360 counter and shows captures in both languages.

- **Three groups** in the bottom strip. TESTS: LIGHT, GRIP, PORT, PRESS, each with its price of one lamp and a "?" when the patient complained about its row. TALK: the dialogue strip with the complaint question always visible and the three listed questions at most one more click away, plus T to type and TAB to speak. The calls stay where they are (the TREAT stamp, the Trauma Team call); BREAK is the PRESS button's second state.
- **The PRESS button** reads PRESS with its price while TEMPER is untested and a lamp is left. Otherwise it reads BREAK, in the warning colour, and opens the warning with SPACE named.
- **The lamp bar** shows two lamps.
- **The card** is the one place that adds up a visit: per row the "?" and the complaint, the reading or what was said, the player's mark, and the tally of crosses.
- **The close-up** of a test shows the reading, the sheet line for that row beside it, and the tick and the cross.
- **Gone from the screen:** CALM, INSIST, the lamp price on ASK, the "YOUR MEANING" menu, the CTRL+ENTER hint.
- **Keys.** The KEYS page lists only SPACE, ENTER, T, TAB, ESC, R, L, N, H or F1, K, M, F10 and F11. Other bindings may remain.

A new player's exam then has about ten controls in three groups.

## 8. Teaching and words

At most seven tips on the first visitor, each naming one next action. The words below are drafts in English; the Chinese goes into the catalogs with the terms they already use.

| Tip | Shown until | Draft |
| --- | --- | --- |
| `buzz` | the visitor is called in | as today |
| `ask` | a complaint is told | Start by asking. Click WHAT'S BOTHERING YOU? Talking is free and never sets anyone off. |
| `test` | a test is run | They named a part. It shows ? on the card and on its test. Run that test. A test takes one lamp and you have {lamps}. |
| `mark` | a mark is set | Compare the reading with the sheet line beside it. It fits: tick. It does not: cross. |
| `second` | the second test or NEXT | One lamp left: one more test, any part you like. Reopening a finished test is free. |
| `speech` | a listed question is answered | How they talk is the SPEECH line. Ask the listed questions and compare with the sheet [R]. |
| `decide` | the call | No cross: stamp TREAT. {threshold} crosses: call TRAUMA TEAM. One cross can be plain wear: your call. Right or wrong comes at closing. |

After the first visit, as today, the warning with the key: from now on a drifting patient may turn on you when you test or push them; a red bar means SPACE. A harmless shutter drill before the second visitor is welcome if it is cheap.

On the second visitor, three tips for the contacts (the list, the two clues against the card, the code and its price). The training night's courier moves from the first visitor to the second (`draw_contacts` `first_on_list` in `shift_state.gd`).

The first time a visit stands at exactly one cross with no lamp left, one tip for BREAK: one cross and no lamps, wear or drift? BREAK pushes until they show it. A steady patient walks out and pays nothing. A drifting one comes at the glass: SPACE. Catch them and Trauma Team pays the fee plus {bonus}. The tip is triggered by the player's own marks, so it gives nothing away.

Rewrite HOW TO PLAY (`intro.json` `howto`), the counter guide (`guide`) and the closing report in both languages around the sentence of section 3. The story cards do not change.

Draft Chinese for the two lines everything hangs on:

- WHAT'S BOTHERING YOU? → 哪里不舒服？
- The rule → 先问哪里不舒服，再查他说的地方。两行不合格：叫创伤小组。只有一行，可能只是磨损：你来定。

## 9. Data to write

**Complaint sentences.** Ten characters, four rows each, plus a "nothing" line: 50 sentences in English and 50 in Chinese. One generic "that is all" line per character may reuse an existing line.

- First person, in the character's voice, at most 90 characters in English and 45 in Chinese, so that two fit in one reply.
- It names the part in words a player can map to a sheet row: eyes or sight, hands or grip or fingers, the port or socket, temper or mood or fuse.
- It tells a feeling or an event, never a reading. "My hands shake when I'm tired" is right. "My grip is over the limit" is wrong.
- It is true to say whether the row is broken, worn or fine. No word for drift or psychosis.
- The validator in `case_db.gd` checks presence and length in both languages.

**Fixed nights.** Every test night must be a night the draw could produce, so the first visitor is steady, unworn and has exactly one complaint.

Night K teaches the loop in order:

| Visitor | Truth | Broken rows | Complaints | What a careful player meets |
| --- | --- | --- | --- | --- |
| 1 | steady | none | one normal row | complaint, test, normal, TREAT |
| 2 | steady | one worn row | that row | one cross, second test normal: wear, TREAT |
| 3 | drifting | eyes, hands | eyes, hands | two crosses: TRAUMA TEAM |
| 4 | drifting | speech, port, temper | port | a cross from talk, a cross from PORT |
| 5 | steady | none | two normal rows | two false alarms, both tests normal, TREAT |

Night L holds the hard cases:

| Visitor | Truth | Broken rows | Complaints | What a careful player meets |
| --- | --- | --- | --- | --- |
| 1 | steady | none | one normal row | the protected opening |
| 2 | drifting | hands, temper | hands | one cross and a guess for the second test |
| 3 | steady | hands (wear) | hands, eyes | one cross, the other complaint tests normal |
| 4 | drifting | eyes, hands, port, temper | none | no guidance, and any two tests find it |
| 5 | drifting | speech, eyes | temper | a cross from talk, a false complaint, eyes easily missed |

Codex picks the characters so that fees and contacts fit the night rules (`fees_under_line`, two fair contacts).

## 10. The numbers

### The scratch model

Three small Python scripts, copied to `validation/2026-11-21/play-loop-scratch/` (ignored by Git): `sim_leads.py` (Monte Carlo), `sim_opt.py` (exact best play and exact plain routines), `sim_final.py` (the tables below; run it from that folder).

It models one later visitor of a first night: drifting with probability 0.5, wear 0.5, five rows, SPEECH read free by talking, four tests at one lamp, broken rows of a drifting visitor 2, 3 or 4 at weights 2, 2, 1, fee 400, today's scoring. It leaves out reading errors by the player, snaps, flares, contacts, the three characters who attack when Trauma Team is called (dana, rook, vale), glass damage and a killed doctor. A hit counts −300. It is not the engine and it is not a playtest.

### What it says at two lamps, complaints at 0.65 and 0.2

| Play | Right calls | Credits a visit |
| --- | --- | --- |
| Best play, no BREAK | 91.6 % | 338.4 |
| Best play, complaints not heard | 83.0 % | 301.5 |
| Best play, never talks | 82.0 % | 281.0 |
| Talk only, no tests | 76.4 % | 252.5 |
| Plain routine: complaints first; no cross TREAT, two crosses TRAUMA TEAM, one cross TREAT | 89.0 % | 311.7 |
| Same, but one cross with a complaint left untested goes to TRAUMA TEAM | 90.3 % | 325.0 |
| Same tests in random order, best plain call | 83.0 % | 301.5 |

Best play runs 1.70 tests a visit. A visitor draws 1.39 complaints on average; 19.8 % draw none and 13.8 % three or more.

Where the plain routine ends:

| Ends on | Share of visits | Of those, drifting |
| --- | --- | --- |
| No cross | 30.3 % | 1.6 % |
| One cross | 30.8 % | 34.3 % |
| – one cross, and a complaint left untested | 3.4 % | 69.9 % |
| – one cross alone | 27.4 % | 29.9 % |
| Two crosses | 39.0 % | certain |

So the dilemma comes up in about three visits of ten, and a player has two honest reasons to lean one way: a complaint they could not test, and the fee.

Expected credits on one cross (34.3 % drifting), with a shutter that holds nine times in ten:

| Fee | TREAT | TRAUMA TEAM | BREAK, bonus 50 | BREAK, bonus 150 |
| --- | --- | --- | --- | --- |
| 220 | 7.3 | −23.0 | 73.1 | 104.0 |
| 400 | 125.5 | 38.7 | 128.7 | 159.5 |
| 600 | 256.9 | 107.3 | 190.4 | 221.3 |

A cheap job with one cross says BREAK. An expensive one tempts TREAT.

On two crosses, TRAUMA TEAM against BREAK:

| Fee | TRAUMA TEAM | BREAK, bonus 50, shutter 1.0 / 0.9 / 0.7 | BREAK, bonus 150, shutter 1.0 / 0.9 / 0.7 |
| --- | --- | --- | --- |
| 220 | 220 | 270 / 213 / 99 | 370 / 303 / 169 |
| 400 | 400 | 450 / 375 / 225 | 550 / 465 / 295 |
| 600 | 600 | 650 / 555 / 365 | 750 / 645 / 435 |

At 150 a player whose shutter holds more than about 82 % of the time should never call Trauma Team (best play calls it 0 % of the time). At 50 the sure call stays right for anyone short of a perfect shutter.

Why two lamps and not three. With three lamps and complaints, best play is 96.3 % right and a one-cross ending is drifting only 15.2 % of the time: safe and dull, and BREAK never pays. Without complaints three lamps give 92.0 % and a one-cross ending that is drifting 28.6 % of the time, close to two lamps with complaints.

Why BREAK needs no lamp. When it does, the best player tests less to keep the lamp (1.37 tests a visit against 1.64).

BREAK on every visitor earns about 187 credits a visit against 338.

### What must hold in the engine

Measure in the engine, exactly or with at least 100,000 visits a figure, on later visitors, with the method `HANDOFF.md` records under "Computed rules". Routines: C, the plain routine above (all complaints heard, all listed questions asked, complained rows tested first, stop at two crosses); N, the same without hearing complaints; S, never talks; T, talks and never tests; and exact best play.

| | Relation | Scratch value |
| --- | --- | --- |
| R1 | Guidance pays: the best plain call under C is at least 5 points above the best plain call under N. | 90.3 against 83.0 |
| R2 | Talking pays: best play that never talks is at least 7 points under best play. | 82.0 against 91.6 |
| R3 | Testing pays: T is at most 80 % and at least 10 points under C. | 76.4 against 89.0 |
| R4 | The band: C is between 86 % and 93 % right. | 89.0 |
| R5 | The dilemma exists: C ends on one cross in 25 % to 35 % of visits, and 25 % to 45 % of those are drifting. | 30.8, 34.3 |
| R6 | Two crosses: for a visitor who does not attack on a call, TRAUMA TEAM pays at least as much as BREAK with a 90 % shutter, at every fee of the roster. | 220 / 213, 400 / 375, 600 / 555 |
| R7 | One cross: BREAK with a 90 % shutter pays at least as much as TRAUMA TEAM at every fee, more than TREAT at the lowest fee and less than TREAT at the highest. | table above |
| R8 | Every tool earns its place: taking away any one test lowers best play by at least 1 point, and each test is the first test in at least 10 % of visits under C. | not modelled |
| R9 | No lazy call: TREAT for everyone, TRAUMA TEAM for everyone and BREAK for everyone each earn at most 60 % of what C earns. | 0, 125 and 187 against 312 |
| R10 | Surprises: under C a drifting visitor turns before the call in 10 % to 20 % of their visits, and never after talk or a code. | about 17 % |
| R11 | The line and the code: report how often C holds the line with no drop, one and two. If one drop holds it in fewer than 45 % or more than 75 % of nights, move `line.per_hour` and nothing else. Report what a code tried on every visitor is worth against a code said only on a match; the blind try must be worth less. | not modelled |

Tune in this order and stop at the first set that holds: the two complaint probabilities, then the catch bonus, then the snap numbers, each inside its range in section 5. Lamps stay at two, wear at 0.5 and the threshold at two. If the relations cannot be met inside the ranges, keep the starting numbers, report which relation failed and by how much, and go on.

Dana, rook and vale attack when Trauma Team is called. For them BREAK beats the call by the bonus when two crosses are certain. At 50 credits that is a small reward for knowing the regulars; report the measured figure.

### The fallback

If the complaints cannot be finished or cannot pass the language checks, switch them off (`complaints.enabled` false) and give three lamps. The scratch model puts that near the same band. The rest of the redesign does not depend on them.

## 11. The student's decisions

### Kept as decided

The cap of 16 replies (November 15). A visitor with no patience left leaves by themselves, nothing gained or lost (November 15). Automatic notes with the player's own ticks and crosses on top (November 15). Pass and fail made clear with the sheet line beside the reading (November 17). A patient may turn in the middle of an action (November 17). The story, the contacts, a different code per contact and a wrong code that costs patience (November 17). Right and wrong only at closing; a killed doctor ends the night (November 18). Any part may be the broken one, with full art (November 18). The contact list gives nobody away and a missed drop is not told during play (November 20). A warning and the key before anything can hurt (November 20). Wear, the warned and certain second push, and a bonus for the catch (November 21).

### Changed, and to be told to the student plainly

Each line is a default in [KICKOFF.md](KICKOFF.md) that the student can change before sending.

| Decided or built | Becomes | Why |
| --- | --- | --- |
| Patience of 5 to 7 by character | two lamps for everyone | one limit a player can count |
| ASK costs a lamp and can be dodged | talk is free and answered | a price on words is what forced the confirmation menu |
| "A paid inferred question displays the topic and lamp price for confirmation" (`AGENTS.md`) | no paid questions, no confirmation | follows from the line above |
| "A first unsettled instrument request can be refused" (`AGENTS.md`) | tests are always granted | the model never refuses; INSIST had nothing to act on |
| CALM costs 30 credits (November 17: "CALM goes, or costs money") | CALM goes | the other half of the student's own either-or |
| PRESS costs two lamps | PRESS is the TEMPER test for one | every test has the same price |
| "The second PRESS needs two lamps, takes all lamps and pays 150" (November 21) | BREAK needs no lamp and pays 50 | a lamp gate makes the best player test less; at 150 the sure call is never right |
| A wait of 8 seconds at no lamps | 30 seconds of idle time | an empty bar is now the normal end of an exam |
| Observation as a free method (`AGENTS.md`) | a look happens inside a test | a free look reads a row for nothing |
| The opening guidance walks through everything on the first visitor (November 17) | still once, but spread: the loop on visitor 1, the warning after, contacts on visitor 2, BREAK when it first matters | fourteen tips at once were the wall |

After the build Codex rewrites "Agreed rules for this build" and "Agreed design" in `AGENTS.md` to match, dated, with the student's words from section 1.

## 12. Engineering notes

- **Versions.** Rules 13. Patient protocol 5 in the second step of section 6. Tag the last commit of the old loop `loop-v12` before the first change.
- **Languages.** Every shown word is English in `game/data` and the scripts, with its Chinese in `game/data/lang/zh/`, changed in the same commit. Words painted into pictures go through `tools/art/words.py` and the generator. Do not hand-edit `game/assets/`. No new art is needed; the lamp bar draws two.
- **Tests.** Rule tests for every rule of section 4: prices, the complaint draw (same seed, same complaints; the protected visitor; nights that list them), delivery order, free talk, no refusals, BREAK without lamps, the bonus, the idle clock, the snap sources. Scene tests for the three groups, the "?" tags, the close-up marks and the removed controls, in English, Chinese and less blood. Proxy, wire and checkpoint tests for protocol 5. A removed test is listed in PROGRESS.md with the rule that removed it; no count falls for any other reason.
- **Evidence.** Stages and lengths only, never typed words, clips or transcripts. Results in a dated folder under `validation/`. Call a mock run a mock run, computed play computed play, and a run where an agent drove the window by that name. Nobody has played these rules.

## 13. Not in this change

- A patient whose treatment by the player changes what they agree to. The live model does not refuse, so it would have to be game-owned; it is a second mechanic and waits for players.
- More than two lamps on some nights, or lamps that differ by character.
- Any change to fees, the drift draw, wear, the threshold, the glass or the story.
- The Braintrust item, the G1 documents, slides and narration.

What only people at the counter can settle: whether complaints feel like guidance or like a script; whether two tests feel tight or stingy; whether the one-cross call is a pleasure or a coin toss; whether anyone types once the chips exist; how often a real shutter holds, which decides the bonus.
