# The student's five notes of November 17: clarity, paid CALM, training, sudden rage, the new story

Written November 17, 2026. AI use: Claude (Fable) began this round on the student's notes and stopped partway when its quota ran out; Claude (Opus 5.5) took over in the same working tree and finished the design, the code, the tests, the captures and this note. The split between the two is not recorded file by file. **Nobody has played, watched or listened to this version, and no paid service was called for it.** The notes are the student's; every answer, number, name and sentence below is an assistant proposal that the student has not reviewed.

## The notes

Paraphrased from Chinese:

1. Pass and fail are unclear. There is a reference sheet, but nothing points at it: how long a grip is reasonable, for example.
2. There should be no CALM option, or CALM should cost money.
3. The grip and the eye test are confusing. The opening guidance should be clearer, ideally walking the player through everything once.
4. During the eye test, the grip or any other action, the patient may suddenly fly into a rage and lunge, with animated transitions.
5. A new story. The doctor is fired by a megacorp and is in debt, and is forced to work for a gang at a street implant clinic. Contacts come in to exchange codes and smuggle military or high-end implants; illegally chromed cyberpsychos come in too. A daily contact list is used to cross-reference the visitors; a wrong code costs patience, and each contact has a different code. "Design it carefully, so that the whole experience and its logic are smooth and airtight."

## What the build does now

| Note | Answer |
|---|---|
| 1 | Every close-up holds the sheet up beside the picture. A **SHEET** line along its bottom says what the sheet calls steady for that tool. The penlight gives each eye a plain readout once it has had the light long enough: **RIGHT EYE / LEFT EYE**, then **TIGHTENS**, **STAYS WIDE** or **IMPLANT**, then **FOLLOWS** or **DOESN'T FOLLOW**. The grip timer runs on a two-second scale that starts at 0, with the sheet's limit marked on it and labelled **LIMIT 1s** (`rules.json` `grip.limit_ms`); the far end of the scale carries no number, so the one figure printed on it is the limit. Past the mark the bar and the figure turn red. The readouts say what happened, never steady or drifting: the sheet, the marks and the call stay the player's. The house rule (two crosses) and `CROSSED n/2` on the card are unchanged. |
| 2 | CALM stays, and costs money: a calm-patch from the drawer, **30 credits** a use (`reassure.cost`), twice a visit, +1 patience, a refusal softens, and during the leaving countdown it holds the patient. The pad wears its price (`30cr`), the slip prints `CALM -30`, the report prints `calm -N` under the visit. The till may go below zero for it. Paid rather than removed, because a patient who runs out of patience leaves unpaid (November 16): CALM is now a trade of credits for a longer exam, not a free refill. |
| 3 | **The first-night training.** The guide no longer opens by itself on a first night. Instead a small TRAINING box gives 14 tips, one at a time, each with a pulsing frame round the one thing it is about: the contact list, how its clues work, the hall camera, the intake card, saying a code, the drop, the sheet, the penlight, the grip, the port, the talk pads with CALM's price, the marks, the decision, and on the first slip a last tip about snaps and flares. Every tip has **NEXT**; **SKIP ALL [K]** ends the training. Nothing blocks and nothing sets an order: a tip for something already done is passed over, a tip that is only read gives way to the next action after 2 s, one that asks for something after 10 s. The box keeps off the open papers, the slip, the big camera screen and the patient's eyes, and is out of the way while the guide or a close-up is open. It runs once a session, on the first night, from the end of the opening cards until the second visitor is buzzed in. The four-page guide (H, F1 or the booklet) now has the contact list on its left-wall page. `--no-training` brings back the guide that opens by itself. |
| 4 | **Snaps and flares** (next section). A drifting patient may snap in the middle of any action: an open close-up is knocked out of the doctor's hands (it jolts, drops and fades), the patient surges at the glass with a bang, a shake and a red flash, and the ordinary attack follows at once: the red bar, the shutter, the glass. Anyone may flare once a visit: a shout and a hand slammed on the glass, with a smaller surge and shake, but no red bar and nothing to stop. |
| 5 | **The story.** Six opening cards: FIRED (twelve years fitting chrome at Kessler, then security walks you out), THE DEBT (Kessler sold the debt to Harrow Credit; the chair, the tools and the doctor's hands are on lease), THE LANTERNS (the gang's back-street clinic; their contacts come in as patients, carrying smuggled military chrome; tonight's list; +300 for the right code), THE LINE (240 an hour), THE DRIFT (illegal street chrome; some who wear it drift and can turn without warning; most are only tired, scared or angry), BEFORE THE CUT (TREAT, TRAUMA TEAM, SHUTTER). **The contacts**: two of each night's five visitors are the Lanterns' contacts. Tonight's list hangs on the left wall (L) and gives each an alias, two clues and a code line; the clues are matched against the intake card and a look at the eyes, and SAY speaks the code (section after next). |

**The booth.** The list hangs on the left wall on the sheet's hook, under the sheet: one of the two papers is down at a time (R or L, or the swap tab on the paper that is down). To make room, the COUNTER GUIDE booklet moved to the right wall, into the place of the HOUSE RULE sign ("THEY TURN? DROP THE SHUTTER. [SPACE]"), which is gone; the guide's right-wall page, the last training tip and the opening's last card say what the shutter is for. The sheet's own house rule (two broken lines = drifting) is unchanged. The booth picture was redrawn without the sign.

## Snaps and flares, exactly

- **Who.** Only a drifting patient snaps (`snap`). Anyone may flare (`flare`), at most once a visit. A snap that comes up wins over a flare. Neither can happen on a visit that began while the training was running (the first visit of a session, unless the training was skipped before it); the last tip, on the first slip, says what both look like.
- **When.** Each action of the doctor's is rolled once when it has run its course: a tool, a question, pressure, CALM, a code, the player's own words. Looking is free and is not an action. A snap's chance is (actions − 3) × 0.08, never above 0.30: nothing for the first three actions, then 8, 16, 24 and 30 per cent. Over a whole exam that adds up: computed from these numbers, a drifting patient snaps about once in five exams of five actions, two in five of six, and seven in ten of eight. A flare's chance is 0.10 for every action after the first. These are first guesses, untuned.
- **How.** What came up waits 0.6–1.6 s (a flare 0.5–1.4 s), so it lands inside whatever the doctor is doing by then, but it never cuts into a reply on its way, a line still being typed, the typing line, the microphone or the guide. A close-up is no shelter: it is torn away. A snap starts the attack after 0.35 s (`snap.lead_ms`) instead of the usual 0.6–1.2 s beat; the window, the blows and the glass are those of any attack. Caught, a snap counts as a right call; missed, it is a hit (−300).
- **What a flare means.** It is evidence for the TEMPER row only, and it agrees with the case: a steady patient's face and voice go together (Kip: "Snapped and slapped the glass, all of him at once."), a drifting patient's do not (Vale: "His palm hit the glass. His face never moved."). It is never an attack: dropping the shutter on it is a false alarm (−100), and a one-time hint says "Only temper: no red bar, nothing to stop. The SHUTTER is for the red bar."
- **Why.** The note asked for sudden rage during any action. Tying the snap to the number of actions gives it a rule a player can learn: a long exam of a drifting patient is dangerous, so knowing when to stop examining and decide becomes part of the game. The flare is there so that a shout at the glass is not proof: without it, any outburst would give the drifting away.
- `--no-surprises` switches both off (the tests and the captures use it, and cue the two they need).

## Contacts and codes, exactly

- **The list.** Each night `contacts.per_night` (2) entries are drawn from the pool in `data/contacts.json`, each for a different visitor who comes that night, with a generator seeded from the shift seed. The pool has two entries per visitor, ten in all, each with its own alias, clue pair, code line, answer and package. The list is not in arrival order. On the training night the first visitor is always on it, so the first visit can show how a code works.
- **The clues** use only what the player can see: the intake card (age, fee, request) and the eyes on a look (chrome in both eyes, or at least one natural eye). When the data loads, `case_db.gd` checks every clue against the five cases: each clue alone fits at least two visitors, and an entry's two clues together fit exactly one, its own. A data file that breaks this does not load. So the list never names anyone, and a single clue never gives anyone away.
- **SAY.** During the exam each open entry has a SAY button. The right contact answers with the entry's counter-line and hands a package over: the narrator says what it is, and **+300** goes into the till at once, "whatever you decide". Anyone else, or a contact given the other contact's code, gives a blank look in their own words and loses **1 patience** (`contacts.wrong_cost`). A right code costs nothing, but any code needs at least that much patience left, so a patient on the way out cannot be sounded for free. A code a visitor has already heard cannot be said to them again, and after a drop the list is closed for the visit.
- **What a code is not.** It is not a test of the patient. The cost of a wrong code is the same for everybody, the blank line is in the visitor's own voice whatever their truth, and contacts are steady (Kip, Rook, Juno) and drifting (Vale, Maren) alike. The drop changes neither the case, nor the call's credits, nor the chance of an attack; a one-time hint says so ("The drop changes nothing about the exam. Steady or drifting, the call is still yours.").
- **Codes are game-owned.** Saying a code makes no model call and adds nothing to the patient's conversation memory, so the patient AI can never confirm, deny or leak one.
- **Words.** On screen the people on the list are always contacts. Kip's own job is bike courier (his card says "Bike courier, 22"), so the gang's people are never called couriers where the player can read it. The code, the data notes and the tests still say courier for the role.
- **On paper.** The list marks an entry PICKED UP after its drop, or MISSED when its contact came and went without one, and pencils in the codes a visitor did not know. The slip prints `DROP +300` or `ALIAS: NO DROP`; the report adds "Drops picked up: n of 2 (+X)" and, under each visit, `drop +300`, `drop missed` or `calm -N`.
- **Why the line doubled.** At 240 an hour the night needs 1,200 in the till at closing. The three fees and two Trauma Team hand-overs of five right calls make 1,140, so the night is held only with at least one drop: five right calls and one drop make 1,440, both drops 1,740, less what CALM and glass cost. The list is part of the night's goal, not a side errand, and a wrong code is a real cost. The meter's earlier warnings are still only warnings; the last reading decides.

## The rules, in one place

- The list never names a visitor; two clues pick out exactly one (checked at load).
- Clues use only the intake card and the eyes.
- A wrong code costs `wrong_cost` patience, whoever hears it; a code needs at least that much left.
- Codes are game-owned: no model call, nothing in the patient's history.
- The drop pays whatever the call and changes nothing else.
- Snaps are drifting-only and grow with the number of actions; flares are anyone's, once a visit, evidence for TEMPER only and never an attack.
- No snap or flare on the training visit; the training night puts its first visitor on the list.
- A night without a drop cannot hold the line.
- The till may go below zero for CALM and for glass; only the last reading decides the night.
- Unchanged: the five cases' truths and signs, the scoring of the calls, the attack window and its blows, the three glass lamps, glass repair at 40 a layer, the eight-second leaving countdown, the agent limits (16 replies a visit), `agent_proxy/`, the G1 documents, slides and narration. The version string is still 0.3.0.

## The numbers (`rules.json` version 6)

| Rule | Value |
|---|---|
| `line.per_hour` | 240 (was 120); 1,200 over five hours |
| `contacts` | 2 a night, 300 a drop, a wrong code costs 1 patience |
| `reassure` | 30 credits a use (was free), +1 patience, 2 uses a visit |
| `snap` | grace 3 actions, +0.08 an action, at most 0.30; fires 0.6–1.6 s later; the attack starts 0.35 s after |
| `flare` | after the first action, 0.10 an action, once a visit; fires 0.5–1.4 s later |
| `grip.limit_ms` | 1,000 (now drawn as the LIMIT mark) |

Everything else in `rules.json` is as on November 16. `intro.json` is version 4 (six cards, the guide with the list, 14 training tips); `contacts.json` is new (version 1). Each case file gained a `lines.code` sentence (the blank look) and a `flare`.

## Where it lives

- **Rules**: `game/data/rules.json` (`line`, `reassure`, `contacts`, `snap`, `flare`), `contacts.json`, the five case files. `scripts/core/case_db.gd` checks the new groups and the clue logic (`validate_contacts()`, `_validate_surprises()`, a case's `flare` and `lines.code`).
- **State**: `scripts/core/shift_state.gd` `draw_contacts()`, `contact_for()`, the report's `contacts`, `drops`, `drop_total`, `calm_total`; `scripts/core/visit_state.gd` `say_code()`, `code_cost()`, `till_change()`, `reassure_cost()`, `roll_action()`, `snap_chance()`, `flare_chance()`, `snap()`, `flare()`.
- **Screen**: `scripts/ui/main.gd` (`act_list()`, `act_say_code()`, the first-night training block, `_roll_surprise()`, `_update_surprise()`, `_tear_scope()`, `_snap_now()`, `_flare_now()`, the new hints), the new `scripts/ui/coach.gd` (the training box), `clipboard.gd` (the list paper, SAY, the swap tab), `scope_view.gd` (the SHEET line, the eye readouts, the LIMIT mark, `tear()`), `patient_rig.gd` (`surge()`), `intro.gd` (the four new pictures), `screens.gd` (title and report), `desk.gd` and `guide.gd`.
- **Art**: `tools/art/gen_booth.py` and `gen_clinic.py` write `ui/obj_list.png` (the list on the wall) and `clinic/list.png` (its paper when it is taken down), and redraw `clinic/booth.png` without the HOUSE RULE sign.
- **Launcher**: `run-game.ps1` imports a fresh clone before its first run, and tries again if the import stops short (Results, below); `-ImportOnly` does only that.
- **Tests**: `run_tests.gd`, `run_ui_smoke.gd`, `capture_shift.gd`, `play_driver.gd`; `tools/art/measure_text.py` measures the new words; `tools/gd_static_check.py` knows the new objects.

## Results

All automated, in this checkout on the evening of November 17, with the mock provider and a simulated microphone; no paid service was called. The logs are in `validation/2026-11-17/`, local evidence that is not in the repository. The final run, on the tree as it stands:

| Check | Result |
|---|---|
| Rules (`run_tests.gd`) | 820 passed, 0 failed |
| Scene (`run_ui_smoke.gd`, nine shifts), offline and with `--less-blood` | 940 passed, 0 failed, each |
| Window close | 5 passed, 0 failed; no "Leaked instance" |
| Proxy (`npm test`) | 38 passed, 0 failed |
| Game and proxy over HTTP | 196 passed, 0 failed; wire checks 15 passed, 0 failed |
| Text fits (`measure_text.py`) | 514 lines, 0 problems |
| Rough lint (`gd_static_check.py`) | 30 scripts, no findings |
| Captures, real renderer, hidden desktop | 196 frames of four shifts and 91 of the attacks with `--less-blood`; 0 moments missed; no window on the user's desktop |
| Import, existing cache | exit 0, no error |
| Import, empty cache | crashed (below) |

The money in the rule checks: five right calls and no drop make 1,140 and end under the line, THE CUT; with one drop they make 1,440, STEADY HANDS. Treating everyone makes 100 and calling Trauma Team on everyone −210, both under. One false call (Juno) with both drops makes 1,240 and holds the line; with one drop it does not. Two false calls (Rook, Juno) with both drops make 790, under. Every one of the 1,024 ways five visits can end (TREAT, Trauma Team, the shutter, or the patient leaving), with no drop and with two, ends in a titled report, and THE CUT is given to exactly the nights that end under the line.

A first run earlier the same evening, before the last two changes, gave the same counts. An assistant looked at about 60 frames of its drawing (16 contact sheets and enlarged crops), and that led to the two changes: the grip scale read LIMIT at the mark and 2s at its far end, which could be taken for a limit of two seconds, and the word courier was also Kip's job. In the final drawing the frames those changes touch were looked at again, with the other new words (title, the Lanterns' card, training tips 1, 2, 4 and 5, the hover lines of the list and SAY, Kip's card, the guide's left page, the CALM pad's price, both grip results enlarged), and so were 16 of the 91 frames drawn with `--less-blood`, three of them enlarged beside the same moments drawn with blood: no splatter, drips, pools or blood on the hands.

**The import from an empty cache**, which a fresh clone needs, is not reliable with Godot 4.7.2 headless. In the final run it crashed with an access violation (0xC0000005) while it was writing the three fonts, the first files it imports, and left nothing in the cache but three empty temporary files, one for each font; the rule check on that copy then stopped at the missing font (768 passed, 1 failed) and the scene check was stopped by hand. In the first run it exited 0 with three `Unicode parsing error` lines. In 20 repeats on each, this tree crashed twice (both after the last file, with all 664 files in the cache) and printed engine errors without crashing twice; the last commit, 822e8d7, crashed once, at the fonts, with 3 files in the cache. The errors (`Initializing already initialized RID`, `Parameter "t" is null` in the headless renderer's texture store) and the crash on the commit point at a race inside the engine rather than at a project file, but the cause is not known. A second import mended the crashed copy (then 820 rule and 940 scene checks passed on it), so `run-game.ps1` now checks that every file the `.import` files name is in the cache and, if not, imports, up to three times. That was tried on a copy with no cache, with part of the cache removed, with a stand-in engine whose first import crashes and with one that never imports. Before this, `run-game.ps1` in a fresh clone would have started the game with no pictures or fonts at all: a copy started the same way without an import (headless, for five seconds) printed over 37,000 error lines. Details: "Checks" in [game/README.md](../../game/README.md).

## What nobody knows yet

- Whether the training says too much or too little, and whether 14 tips feel like a walk-through or a wall of text.
- Whether the clue pairs are fun to cross-reference or a chore, and whether 300 a drop and 240 an hour make the list feel necessary without making it the whole game.
- Whether 30 credits is the right price for CALM, and whether anyone still uses it.
- Whether a snap feels sudden and fair, whether 0.35 s of warning is enough to reach the shutter, and whether a flare is read as temper or panics the player into a false alarm.
- Whether the readouts in the close-ups make the eye test and the grip clear, or still need the sheet.
- None of the new moments has met a live model, been heard, or been played by a person.
