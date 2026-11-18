# Before the Cut: handoff

Updated **November 18, 2026**, after the work of November 17 was committed and pushed. Communicate with the student in Chinese; write game text, code comments and project files in English.

**This repository is the only active checkout.** On November 15 the game, the patient-AI proxy and the tools were moved here from the legacy `fathom` workspace and checked here ([transition record](docs/development/repository-transition.md)). `fathom` is an archive; its long layered handoffs (`HANDOFF.md`, `CODEX_RUNTIME_HANDOFF.md`, `CLAUDE_VOICE_HANDOFF.md`, `CODEX_NEXT_HANDOFF.md`) are history, not instructions.

AI use: Claude wrote the earlier runtime history; Codex added the live-test results and speech-feedback correction of November 15; Claude built the answers to the student's eleven notes, the counter-first screen and the paid glass repair on November 16. On November 17 Claude (Fable) began the answers to the student's five notes and stopped partway when its quota ran out; Claude (Opus 5.5) took over in the same working tree, finished the design, the code, the tests and the captures, and wrote the November 17 parts of this file. The split between the two is not recorded file by file. No student review of these updates is recorded.

**Git.** Both rounds of November 16 are in commit `822e8d7`. The work of November 17 is in the commit after it on `main`, made on November 18 when the student asked for it to be pushed, and is on `origin/main`; the files are listed in the first section. Run `git status -sb` and `git log -3 --oneline` to see where it stands now.

## Current checkpoint: the student's five notes (November 17)

On November 17 the student handed over five notes that had first been given to Claude (Fable), whose quota ran out before it finished, and asked for all of them to be thought through, planned and implemented. Paraphrased from Chinese:

1. Pass and fail are unclear. There is a reference sheet, but nothing points at it: how long a grip is reasonable, for example.
2. There should be no CALM, or CALM should cost money.
3. The grip and the eye test are confusing. The opening guidance should be clearer, ideally walking the player through everything once.
4. During the eye test, the grip or any other action, the patient may suddenly fly into a rage and lunge, with transitions.
5. A new story. The doctor, fired by a megacorp and in debt, works for a gang at a street implant clinic. Contacts come in to exchange codes and smuggle military or high-end implants; illegally chromed cyberpsychos come in too. A daily contact list is used to cross-reference the visitors; a wrong code costs patience, and each contact has a different code. "Design it carefully, so that the whole experience and its logic are smooth and airtight."

**Nobody has played, watched or listened to this version, and no paid service was called for it.** The notes are the student's. Every answer, number, name and sentence below is an assistant proposal that the student has not reviewed. The full account, with the exact rules of snaps, flares and codes and the reasons for them, is the [November 17 note](docs/development/story-and-clarity-2026-11-17.md); [game/README.md](game/README.md) has the rules as a player meets them.

| Note | What the build does now |
|---|---|
| 1 | Every close-up holds the sheet up beside the picture, with a SHEET line saying what the sheet calls steady for that tool. The penlight gives each eye a plain readout once it has had the light long enough (RIGHT EYE / LEFT EYE, then TIGHTENS, STAYS WIDE or IMPLANT, then FOLLOWS or DOESN'T FOLLOW). The grip timer runs on a two-second scale with the sheet's limit marked and labelled LIMIT 1s (`rules.json` `grip.limit_ms`); past it the bar and the figure turn red. The readouts say what happened, never steady or drifting. The house rule (two crosses) and `CROSSED n/2` on the card are unchanged. |
| 2 | CALM stays and costs money: a calm-patch for 30 credits a use (`reassure.cost`), still twice a visit and +1 patience, and it still holds a leaving patient at the counter. The pad wears its price, the slip prints `CALM -30`, the report `calm -N`. The till may go below zero for it. |
| 3 | A first-night training takes the place of the guide that opened by itself: 14 tips, one at a time, each with a pulsing frame round the one thing it is about, NEXT on each (DONE on the last) and SKIP ALL [K]. Nothing blocks and nothing sets an order: a tip for something already done is passed over, a tip that is only read gives way to the next action after 2 s, one that asks for something after 10 s. It runs once a session, from the end of the opening cards until the second visitor is buzzed in. `--no-training` brings back the guide that opens by itself. |
| 4 | Snaps and flares. A drifting patient may snap during any action, more likely the longer the exam runs (nothing for the first three actions, then 8, 16, 24 and at most 30 per cent an action): an open close-up is torn out of the doctor's hands, the patient surges at the glass with a bang, a shake and a red flash, and the ordinary attack follows 0.35 s later. Anyone may flare once a visit (10 per cent an action after the first): a shout and a hand slammed on the glass, with no red bar and nothing to stop. A flare is evidence for the TEMPER row only, and a shutter on it is a false alarm. Neither happens on the training visit. `--no-surprises` switches both off. |
| 5 | Six opening cards tell the story: FIRED (Kessler), THE DEBT (Harrow Credit), THE LANTERNS (the gang's back-street clinic, their contacts, tonight's list, +300 for the right code), THE LINE (240 an hour), THE DRIFT (illegal street chrome), BEFORE THE CUT. Two of each night's five visitors are contacts. Tonight's list (left wall, or L) gives each an alias, two clues and a code line. Clues use only the intake card and the eyes; each alone fits at least two visitors and both together exactly one, which is checked when the data loads. SAY speaks a code: the right contact hands over a package (+300 at once, whatever the call), and anyone else loses 1 patience. Codes are game-owned: no model call, nothing in the patient's memory. The lender's line rose to 240 an hour, so five right calls (1,140) no longer reach the 1,200 of closing without a drop. |

The booth: the list hangs on the sheet's hook, so one of the two papers is down at a time (R or L, or the swap tab on the paper that is down). To make room, the COUNTER GUIDE booklet moved to the right wall, into the place of the HOUSE RULE sign ("THEY TURN? DROP THE SHUTTER. [SPACE]"), which is gone; the guide's right-wall page, the last training tip and the last opening card say what the shutter is for. The booth picture was redrawn without the sign.

The launcher: `run-game.ps1` now checks, before it starts the game, that every file the `.import` files name is in Godot's import cache (`game/.godot/`, which is not in the repository), and if not, imports, up to three times; `-ImportOnly` does only that. Before this, a fresh clone started the game with no pictures, fonts or sounds (results below).

`rules.json` version 6:

| Rule | Value |
|---|---|
| `line.per_hour` | 240 (was 120); 1,200 at closing |
| `contacts` | 2 a night, 300 a drop, a wrong code costs 1 patience |
| `reassure` | 30 credits a use (was free), +1 patience, 2 a visit |
| `snap` | 3 free actions, +0.08 an action, at most 0.30; fires 0.6-1.6 s later; the attack starts 0.35 s after |
| `flare` | after the first action, 0.10 an action, once a visit; fires 0.5-1.4 s later |
| `grip.limit_ms` | 1,000, now drawn as the LIMIT mark |

`intro.json` is version 4; `contacts.json` (version 1) is new.

What changed in the repository (committed on November 18):

- Modified, besides this file and `NEXT_AGENT_PROMPT.md`: `README.md`, `run-game.ps1`, `docs/development/direction.md`, `game/README.md`; `game/data/rules.json`, `intro.json` and the five case files (each gained a `lines.code` sentence and a `flare`; Kip is now a bike courier); in `game/scripts/core/` `case_db.gd`, `shift_state.gd`, `visit_state.gd`; in `game/scripts/ui/` `main.gd`, `clipboard.gd`, `desk.gd`, `guide.gd`, `intro.gd`, `patient_rig.gd`, `scope_view.gd`, `screens.gd`; in `game/tests/` `run_tests.gd`, `run_ui_smoke.gd`, `capture_shift.gd`, `play_driver.gd`; `game/assets/clinic/booth.png` (regenerated); `tools/art/gen_booth.py`, `gen_clinic.py`, `measure_text.py`; `tools/gd_static_check.py`.
- New: `docs/development/story-and-clarity-2026-11-17.md`, `game/data/contacts.json`, `game/scripts/ui/coach.gd` with its `.uid`, and `game/assets/clinic/list.png` and `game/assets/ui/obj_list.png` with their `.import` files.
- Not changed: `agent_proxy/`, the agent limits (so `rules.json` `agent` and `core.mjs` still agree), `sheet.json`, `agent-config.json`, the five cases' truths and signs, the other scripts (among them `gfx.gd`, `clinic_view.gd`, `dialogue_box.gd`, `gore_layer.gd`, `audio_bank.gd` and the agent and voice scripts in `core/`), `run_close_check.gd` and `run_proxy_integration.gd`, every sound (the new moments reuse existing ones), the G1 documents, slides and narration. The version string is still 0.3.0.

Results on the evening of November 17, on the final working tree (logs in the local `validation/2026-11-17/checks/`; commands under "Results in this checkout"):

- **820 rule checks**, **940 scene checks** over nine shifts (the same count with `--less-blood`), **5 normal-close checks**, **38 proxy tests**, and over HTTP with the mock provider and a simulated microphone **196 game checks and 15 wire checks**: all passed; every run exited 0 with nothing on standard error.
- Text measurement: 514 lines, 0 problems. Lint: 30 scripts, no findings. Capture script, dry: 196 frames named, and 91 with `--attacks-only --less-blood`, 0 moments missed.
- Import with the existing cache: exit 0, nothing on standard error; no run rewrote a tracked `.import` file. The headless boots (`--quit-after 240`, offline and in model mode with no service behind the address) and the boot on the real renderer on a hidden desktop (exit 0 in 5 s, OpenGL 3.3) printed only the known `4 ObjectDB instances were leaked` warning that `--quit-after` causes.
- **Drawn on a hidden desktop** by `tools/run_hidden.py` (Dummy audio, simulated microphone, authored dialogue, a stand-in voice service): 196 frames of four shifts in 176 s and 91 attack frames with `--less-blood` in 117 s, 0 moments missed, exit 0, and no window on the user's desktop in either run.
- The runner compares `git status` before and after and flags `README.md` and `game/README.md`: the assistant was editing them while the run went on. No check writes them.
- The money, from the rule checks: five right calls and no drop make 1,140 and end under the line, THE CUT; with one drop they make 1,440, STEADY HANDS. Treating everyone makes 100 and calling Trauma Team on everyone −210, both under. One false call (Juno) with both drops makes 1,240 and holds the line; with one drop it does not. Two false calls (Rook, Juno) with both drops make 790, under. All 1,024 ways five visits can end (TREAT, Trauma Team, the shutter, or leaving), with no drop and with two, end in a titled report, and THE CUT goes to exactly the nights that end under the line.
- Frame review, by Claude and not by a person at the game. A first run earlier that evening gave the same check counts (`validation/2026-11-17/first-run/`). About 60 frames of its drawing were looked at, as 16 contact sheets and enlarged crops, and that led to two changes: the grip scale read LIMIT at the mark and 2s at its far end, which could be taken for a two-second limit, so the mark now says LIMIT 1s and the far end has no number; and the word courier, which was also Kip's job, became contact wherever the player reads it, with Kip a bike courier. In the final drawing the frames those changes touch were looked at again, with the other new words (the title, the Lanterns' card, training tips 1, 2, 4 and 5, the hover lines of the list and SAY, Kip's card, the guide's left page, the CALM pad's price, both grip results enlarged). So were 16 of the 91 frames drawn with `--less-blood`, three of them enlarged beside the same moments drawn with blood: no splatter, drips, pools or blood on the hands.

**The import from an empty cache is not reliable** with Godot 4.7.2 headless, on the last commit as well as on this tree, and a fresh clone needs it. Each run of the checks imports a copy of `game/` without its `.godot/` folder and runs the rule and scene checks on it.

- In the first run of the evening that import exited 0 with three `Unicode parsing error: Unpaired surrogate (ddd0)` lines, and the checks on the copy passed.
- In the final run it crashed: exit code -1073741819 (0xC0000005, an access violation), nothing on standard error, while it was writing the three fonts, the first files it imports. The cache then held three empty temporary files, one for each font, all created in the same instant, and none of its 664 files. The rule check on that copy stopped at the missing font (768 passed, 1 failed), and the scene check was stopped by hand after four and a half minutes and 902,139 lines of errors.
- Repeated 20 times each from an empty cache, on a copy of this tree and on a copy of `822e8d7`:

  | From an empty cache | Clean | Engine errors, exit 0, all files in the cache | Crashed (0xC0000005) |
  |---|---|---|---|
  | this tree | 16 | 2 | 2, both after the last file, with all 664 files in the cache |
  | last commit, 822e8d7 | 19 | 0 | 1, at `counter_bold.fnt`, with 3 files in the cache |

- The errors that came without a crash are the engine's own (`Initializing already initialized RID`, `Parameter "mem" is null`, `Parameter "t" is null` in the headless renderer's texture store). They and the crash on the commit point at a race inside Godot's headless import rather than at a project file, but the cause is not known, and 2 crashes against 1 cannot say whether this tree makes it more likely.
- A second import mended the copy that crashed in the final run, the one crash it was tried on: imported once more without clearing its cache, it exited 0 in 7 s with all 332 named files and their `.md5` files in place (the three empty temporary files stayed behind, unused); then 820 rule checks and 940 scene checks passed on it.
- A copy started without an import, the way `run-game.ps1` would have started a fresh clone before (headless, for five seconds), printed 37,233 lines of errors.
- So `run-game.ps1` now imports first. It was run with `-ImportOnly` on a copy of the repository: with no cache (332 to go, imported in 6 s, 664 cache files); on the same copy again (nothing to do); with the three fonts taken out of the cache (3 to go, imported again); with a stand-in engine whose first import fails with the crash's exit code (the second try finished it); with a stand-in that never imports (three tries, then the message to open the project in the editor once, exit 1); and in this checkout (nothing to do). A stand-in that prints its arguments showed that the game options still reach the game.

Limits of this checkpoint:

- No human playtest, no listening test, no human voice test. Nobody, agent or person, has operated this build in a visible window.
- No live model has seen the November 17 build. A code is never passed to the model, so the patient AI does not know when one was said.
- Every new number is an untuned first guess: 240 an hour, 300 a drop, two contacts a night, 1 patience for a wrong code, 30 credits for CALM, a snap's 3 free actions, 0.08 a step and 0.30 at most, the 0.35 s between a snap and its attack, a flare's 0.10.
- The scene test cues a snap and a flare by pinning their rules for one action, and presses the shutter within one frame of the moment it chooses. It shows that the flow holds together, not that a person can react to a snap.
- Whether the training says too much or too little, whether the readouts make the eye test and the grip clear, whether the clue pairs are fun to cross-reference or a chore, whether anyone still buys CALM, and whether a flare is read as temper or panics the player into a false alarm are questions for play.
- The cause of the fresh-import crash is not known. `run-game.ps1` works around it. A clone imported another way (a bare `godot --import`) may need a second import, and the editor's first import, which the launcher's message suggests, has not been tried.
- The new words (the story and its names, the six cards, the 14 tips, the list's aliases, clues, codes and packages, the flare lines, the new hints) are assistant writing.

## Earlier checkpoint of November 16, evening: the counter-first screen and paid glass repair

**Superseded in part by the checkpoint above.** Since November 17 the contact list shares the sheet's hook on the left wall, the COUNTER GUIDE booklet hangs on the right wall in the place of the HOUSE RULE sign, which is gone, the CALM pad costs 30 credits, the line is 240 an hour, and on a first night the training takes the place of the guide that opened by itself. Every count below has grown. The rest of the screen and of the glass repair is as described.

In the afternoon of November 16, at about 15:20 New York, the student sent two requests. Paraphrased from Chinese:

1. For immersion, perhaps this interface should keep only the counter: one large view that shows the counter and the visitor across it. Everything else becomes things on the desk or somewhere, such as papers, that are clicked to bring up the reference sheet, the player's own notes, the surveillance camera or the other operations. "Think carefully about what I mean, then implement it."
2. The player may also spend money to repair the counter's blast-proof glass, if earlier visitors have broken it.

Claude designed and built both that afternoon and evening. **Nobody has played, watched or listened to this version, and no paid service was called for it.** The two requests are the student's. The layout, the keys, the price and every sentence are assistant proposals that the student has not reviewed.

The screen then (640 x 360; every rectangle is in `game/scripts/ui/gfx.gd`):

| Where | What is there | How it is used |
|---|---|---|
| Centre: the counter window, 440 x 300 | The patient across the counter, drawn at twice the earlier size. Patience lamps at the top, glass lamps at the bottom right, the timing bar in the slot of the sill | Click eyes, hands or port for a look. A tool fills the window with its close-up |
| Left wall | The reference sheet, pinned up; the COUNTER GUIDE booklet; the lender's meter (till, hour, line, a tick or cross for each finished call); the hall camera's small monitor | Sheet: click it, or R, and it comes down over the left part of the window. Booklet, H or F1: the guide. Monitor, or C: a larger screen in the window's lower left corner; between patients a second press, or a click on that screen, buzzes the next patient in, and ENTER does it at once |
| Right wall | The intake card on its clipboard, with a count of unread notes; the HOUSE RULE sign; a plate with the TREAT stamp, the TRAUMA call box, the SHUT lever and the GLASS key | Card: click it, or N, and it comes down over the right part of the window. The stamp, the call box and the lever work as the pads did before; the GLASS key is new |
| Desk | LIGHT, GRIP, PORT; the transcript unit (what is said, the question list, the typing line, the hint line); ASK, CALM, PRESS | As before |

How the papers behave (`main.gd`, the block headed "the booth walls"):

- A paper is in front of the window only while the player has taken it down. Its tab, the same key or a right-click on it hangs it back. With empty hands, right-click or ESC puts back the hall screen, then the card, then the sheet.
- A paper that is down takes the pointer before the patient does. Both papers step aside for a tool close-up and return after it.
- The intake card comes down by itself while the TREAT stamp is in hand, for 1.3 s after it lands, and with the findings at the end of a visit. Notes are written on it also while it hangs on the wall; a number on it counts the ones not yet looked at, and a one-time hint says where the card is.
- Once a patient has turned, nothing is in front of the window. Until then the papers behave the same for every patient, so they give nothing away.
- Papers stay where they were left from patient to patient; a new shift starts with both on the wall. The sheet's corners blink until it has been down once.
- While the counter guide is open the papers hang back, so that the guide can point at them. The guide has four pages now: the window, the left wall, the right wall, the desk.

Glass repair (`rules.json` version 5, `attack.repair_cost`; `shift_state.gd` `repair_cost()`, `can_repair()`, `repair_glass()`, `repair_total()`; `main.gd` `_can_mend()`, `_glass_hint()`, `act_repair_glass()`):

- Only between patients, while the next one waits in the hall: the GLASS key on the right wall, or G. One press is one layer for 40 credits, up to the three of a whole pane; an empty frame gets glass again. The key shows its price when a layer can be ordered, and pointing at it says why when it cannot. A cost of 0 switches repairs off, and the guide then leaves its line about them out.
- The money leaves the till at once, and the till may go under zero for it. `total()` subtracts it. `reading(h)` counts a repair only at readings taken after it, so a reading already shown never changes. The report has a row "Till, after N paid for glass", and `shift_end` logs `glass_paid`.
- Three layers cost 120: one hour of the line on November 16, half an hour since November 17. In the authored order, five right calls with a whole pane bought back close at 1,020: over the line of November 16 (600), and under the 1,200 of November 17 unless a drop is picked up. The fourth capture shift of November 16 showed that night.
- The fitter's arm wipes the pane. Blood on the sill and the walls and the damage to the shutter stay until the next shift. The arm has a new generated sound, `glass_fit.wav`.

What that round changed, on top of the eleven notes: `game/data/rules.json` (version 5) and `intro.json` (version 2); `game/scripts/core/shift_state.gd` and three lines of `case_db.gd`; in `game/scripts/ui/` the files `main.gd`, `gfx.gd`, `clinic_view.gd`, `desk.gd`, `clipboard.gd`, `dialogue_box.gd`, `guide.gd`, `scope_view.gd`, `gore_layer.gd`, and a few lines of `patient_rig.gd` and `screens.gd`; five of the six scripts in `game/tests/` (all but `run_close_check.gd`); in `tools/art/` the new `gen_booth.py` and changes to `build_all.py`, `gen_audio.py`, `gen_clinic.py` and `measure_text.py`; the generated assets `clinic/booth.png`, `clinic/cam_panel.png`, `ui/obj_sheet.png`, `ui/obj_guide.png`, `ui/obj_card.png`, `ui/pad_w.png`, `ui/pad_w_hot.png`, `ui/tool_glass.png` and `audio/glass_fit.wav`, each with its `.import` file, and a regenerated `clinic/lamp_glow.png`; the documents. Not changed in that round: the five case files, `sheet.json`, `visit_state.gd`, `intro.gd`, `run_close_check.gd`. Not changed on November 16 at all: `agent_proxy/`, the agent limits (so `rules.json` `agent` and `core.mjs` still agree), `agent-config.json`, the G1 documents, slides and narration.

Results on the evening of November 16, on that working tree (logs in the local `validation/2026-11-16/checks-counter-first/`; not results for the current build):

- **719 rule checks**, **724 scene checks** (six shifts; the same count with `--less-blood`), **5 normal-close checks**, **38 proxy tests**, and over HTTP with the mock provider and a simulated microphone **196 game checks and 15 wire checks**: all passed, every run exited 0 with nothing on standard error.
- Text measurement: 454 lines, 0 problems. Lint: 29 scripts, no findings. Capture script, dry: 180 frames named, 0 moments missed.
- Import: with the existing cache, exit 0 and no error. From an empty cache (`game/.godot/` moved aside for the run and put back afterwards), exit 0 in four seconds with the same single `Parameter "t" is null` error from the headless dummy renderer as on November 15 and one line about a dummy texture leaked at exit; the rule, scene, close and dry-capture checks passed on that fresh cache, and no tracked file changed. (On November 17 the same import crashed outright, on this tree and on that commit; see the checkpoint above.)
- **Drawn on a hidden desktop** by `tools/run_hidden.py`: the full run saved **180 frames of four shifts, 0 moments missed**, exit 0, in 165.4 s; the attack scenes and the fitter with `--less-blood` saved **89 frames, 0 missed**, exit 0, in 115.6 s. The runner reported no window on the user's desktop in either run. The main scene also booted there on the real renderer through the normal start path (exit 0 in 4.0 s on OpenGL 3.3, only the known `--quit-after` warning).
- Frame review, by Claude and not by a person at the game: about 150 of the 180 frames of a first drawing, which led to three changes (the transcript unit's face under the blood that runs down the desk, CALM instead of REASSURE in the hints, the pointer moved off a stamped card). 45 of the 180 redrawn frames and 27 of the 89 less-blood frames were looked at, with no blood seen in those 27.

Limits of that checkpoint, which still hold: no human playtest, listening test or human voice test; whether the counter-first screen is what the student meant, whether the papers are comfortable in front of the window (each covers the top of one side, 132 of 440 pixels in width), and whether a player finds the things on the walls without the guide are unknown; glass repair is untuned; `glass_fit.wav` has not been heard or measured in the mix; no live model has seen any of the November 16 changes.

## Earlier checkpoint of November 16: the student's eleven notes

**Superseded in part by the checkpoints above.** This section describes the build as it stood at about 15:10 New York on November 16. Since then the three-column screen has become the booth, the guide has four pages instead of three, a layer of glass can be bought back, and every count below has grown; since November 17 the line is 240 an hour (1,200 at closing), CALM costs 30 credits a use, and on a first night the training takes the place of the guide that opened by itself. The rules in the table are otherwise still in force.

On the evening of November 15 the student sent eleven notes on the build and asked for a planned, reasonable fix for all of them, with freedom to invent where a note said so. Claude designed and built the answers; the checks below ran on November 16. **Nobody has played, watched or listened to this version, and no paid service was called for it.** The notes are the student's. Every answer, number, name and sentence in the table is an assistant proposal that the student has not reviewed.

| Note | The student's note, paraphrased | What the build did then |
|---|---|---|
| 1, 5 | A patient whose patience is gone should leave by themselves: the round is missed, nothing gained and nothing lost. What is reassurance for, then? | The action that spends the last lamp still happens. The patient then says an authored line, a red LEAVING bar runs for 8 s (`rules.json` `patience.leave_ms`) and they walk out: outcome `gave_up`, 0 credits, not a right call. A decision can still be made while the bar runs. CALM (+1 lamp, twice a visit) buys another question, clears a refusal and, during the bar, holds the patient at the counter. |
| 2 | Give the till a meaning: the doctor is squeezed too, and needs so much an hour to stay off the cut line. | One patient is one hour. The chair, the tools and the doctor's own hands are on lease from a lender (the invented "Harrow Credit"), whose meter wanted 120 more in the till every hour (`line.per_hour`; 240 since November 17). It is read after each slip and shown on the wall and in the report. Only the closing reading decides: under the line is the ending THE CUT, whatever else went right. Nothing ends the night early. |
| 3 | Where is voice input? Is the reply fixed afterwards? Does it differ from the options in the tree? | The voice path is unchanged; it was made easier to find. Hold TAB or the SPEAK chip, only with the patient service running (`-Model -AgentUrl`); the words land on the typing line and ENTER says them. With the service every reply is generated, including the answers to the three ASK suggestions. Offline there is no voice, and a typed sentence either matches an authored question or gets an honest hint. New: the title card says which mode is on tonight, and the guide names the typing line and push-to-talk. (Offline, TAB already showed a hint that says what speaking needs.) |
| 4 | Can one see from a patient's looks what is wrong? Are patients recombined at random, or is the stage fixed? | Not changed. Looks show part of the signs; the rest needs a tool or talk, and steady patients carry harmless oddities. The cast of five and each truth are fixed; only the arrival order is shuffled. There is no random combination of signs. |
| 6, 10 | Defence should feel like a timed QTE. A badly timed one should crack the glass, so that a later attack lands more easily. | After the warning a red timing bar over the printer slot fills until the patient is through (1.8 s); its notches are the blows on the glass (0.54, 0.99, 1.44 s). Every blow that lands before the shutter costs one of three glass lamps for the rest of the shift, and with fewer lamps the patient is through sooner (1.44 s, 0.99 s, then 0.65 s). A plate grades each stop. A pane with no lamp left drops out of its frame; the next shift starts with a new one. (Since the evening a layer can also be bought back between patients.) |
| 7 | Let the player tick or cross the intake record; keep the automatic notes. | The automatic notes stay. The box at each row was already there before these notes (one click is a tick, two a cross, three clears it, shown beside the truth after the visit), but nothing pointed at it. New: the guide and a one-time hint name the boxes, the card counts the crosses (next row), and each mark is logged as `mark`. Marks are never scored. |
| 8 | Is there a tutorial, or clear feedback: for example X of N marks means over the line? | The sheet's house rule is now a number (`sheet.json` `threshold`: two broken lines = drifting). The card counts the player's crosses against it (`CROSSED 1/2`) and the strip says so when the count is reached. It is advice, never a verdict. A three-page counter guide (four pages since the evening) opened with the first patient of a session (H or F1 opens it again; since November 17 the first night has the training instead), and three hints appear once each. The data check refuses a drifting case that breaks fewer lines than the threshold and a steady case that breaks any. |
| 9 | A short opening scene that gives the background. | Five skippable cards with moving pictures drawn by code (six since November 17), after the title card, once a session (`--no-intro` turns them and the guide's first showing off). |
| 11 | While the agent is thinking, the visitor should show it. | A quarter of a second after a question goes to the service the patient looks away in their own manner, with a small thought bubble; while the microphone is open they watch the doctor and their hands stop. Both follow the patient's idle habit, never the truth. Offline there is no wait and no pose. |

Results of that checkpoint (691 rule checks, 570 scene checks over five shifts, 5 close checks, 38 proxy tests, 196 + 15 HTTP checks, 433 text lines, 29 linted scripts, 162 + 79 frames) are in `validation/2026-11-16/checks/`, `captures-full/` and `captures-attacks-less-blood/`. They are not results for the current build.

## Checkpoint of November 15: first live run complete

The [dated report](docs/development/live-model-results-2026-11-15.md) is the source of truth.
The student explicitly authorized up to USD 50, revoked manual-only credential entry and
asked the assistant to supply voice input. The ignored local credential was configured
without reading or printing it. The completed run used **30 live dialogue calls and 10 live
transcriptions of Windows-synthesized speech**. The proxy and test windows are stopped;
the persistent ledger is stopped at 30/10. No additional paid run was made.

- Dialogue: median **1.32 s**, p90 **1.84 s**, max **2.54 s**, 30/30 successful.
- Transcription: median **0.66 s**, p90 **1.27 s**, max **1.33 s**, 10/10 successful.
  Synthetic WER: **0 errors / 80 words**. This is not the student's voice or a live microphone test.
- Reported usage: dialogue 20,917 input / 1,597 output tokens; speech 502 / 110.
  Published-token-price estimate: **USD 0.0040677**, not an inspected invoice.
- Codex operated two real game visits (Kip, Vale), six model calls each, with zero game fallbacks.
  Kip was correctly treated. Vale attacked after the correct Trauma Team call; the operator
  missed the shutter timing and was injured. Another 18 calls were HTTP probes across three
  characters. No human played or listened.
- 29 replies were inspected; one port reply was replaced by the tool result before review.
  The inspected replies stayed in character. One allowed deceptive claim contradicted a
  physical sign; the game's actual reading stayed fixed.
- Measured bug fixed: the results screen falsely quoted an authored sleep line that the
  model never said. Generated speech feedback now shows the actual recorded reply under
  neutral **PATIENT SAID**, without automatic normal/abnormal grading. Physical facts,
  outcomes, scoring and the fully scripted comparison retain their behavior.
- Checks after the correction: **505 rule checks**, **333 scene checks**, **5 normal-close
  checks** pass. Earlier proxy 38/38 and guard 6/6 checks remain applicable. The smoke harness
  has pre-existing shutdown resource warnings; do not describe it as warning-free.
- No prompt or limit tuning was warranted: retain **16 replies/visit**, **256 output tokens**
  and the existing deadlines.

Limits of this run: automatic text entry could not fill the game's field (paste is unsupported);
free dialogue was probed via HTTP. The automated GRIP hold was too short to complete that
physical measurement. A final synthetic feedback preview returned black; activation recovery
ended with `GetCursorPos` access denied. It was stopped, with no further desktop input.
The feedback change has regression coverage but still needs visual approval on an available desktop.

Local evidence: `validation/2026-11-15/codex-live-test/`, containing numeric metadata and
judgments only, no live replies, transcripts, audio or credential archive. After testing, the
student explicitly chose to retain the configured key in the Git-ignored `.dev.vars` for future
game runs. Keep it there; do not read, print or commit it.

## Background interface captures, November 15

The student asked for game screenshots and an explanation while continuing to use the
computer. `tools/run_hidden.py` ran `game/tests/capture_shift.gd` on a separate Windows
desktop that was never displayed, with the Dummy audio driver and simulated microphone.
The real renderer saved **122 frames, zero missed moments**, and exited normally after
84.2 seconds. The runner reported **no game windows on the user's desktop**. No mouse or
keyboard input was sent to that desktop and no model service was called.

Evidence is in `validation/2026-11-15/background-guide/`: `frames/`, `capture.log` and
`hidden-run.json`. Selected frames were visually inspected for the main interface,
penlight, grip, reassurance, Trauma Team call, attack, visit receipt and shift report.
These are authored/offline automated captures; the voice frames are staged, not real speech.
They do not resolve the separate pending visual check of generated-speech feedback.
The stale mock-only verification paragraph in `game/README.md` was corrected.

## Where things stand

- **G1 is submitted.** The student published the main post on November 14 at 23:16 New York and replaced its recording link at 23:41 (`before-the-cut-g1-recording-updated.mp4`, 5:30.33). See [docs/g1/05](docs/g1/05-submission-draft-and-checklist.md). The deck, PDF, Word script and video stay in the student's local workspace.
- **Still due:** two Braintrust replies to classmates' G1 pitches by **Thursday, November 19, 23:59 New York**. Draft them for the student's review; never send them. Then read the instructor's Approve/Hold comment.
- **The game** is version 0.3.0: one night at the counter with five patients (Kip, Rook, Vale, Juno, Maren) in a shuffled order, the first of a session steady, a Normal Reference Sheet, optional looks, tools, questions, reassurance and pressure in any order, a typing line, push-to-talk, TREAT or Trauma Team, attacks and the shutter, slips and an end-of-shift report. Since November 16 also: an opening and a counter guide, the lender's hourly line, patients who leave when their patience is gone, the player's own marks counted against the house rule, the timing bar and the counter glass, the patient's thinking and listening poses, and the screen as the inside of the booth, with a layer of glass to buy back between patients. Since November 17 also: the story (fired by Kessler, in debt to Harrow Credit, working the Lanterns' counter), two contacts a night on a list with clues and codes, CALM at 30 credits, a line of 240 an hour that right calls alone no longer hold, readouts and the sheet's limit in every close-up, a first-night training, and patients who snap or flare in the middle of an action (first section). Controls, rules and spoilers: [game/README.md](game/README.md). Look, sound and design choices: [docs/development/direction.md](docs/development/direction.md).
- **The patient AI** (protocol 3) writes every reply and reaction from the character brief and the conversation so far; the authored script is the offline comparison and the fallback. The first live OpenAI run is complete; see the November 15 checkpoint. Google and Vertex remain untested live.

## Student decisions, November 15

1. Recording is finished: the game window, mouse, keyboard, audio and microphone may be used for testing.
2. The student authorized the specified OpenAI run with a USD 50 ceiling, allowed assistant credential configuration and asked the assistant to supply voice input. The completed test used local synthetic speech and is explicitly not a human voice test.
3. The cap stays at 16 patient replies per visit.
4. The sentence in `AGENTS.md` that called voice a future task was replaced (done).
5. The repository transfer was left to the agent to schedule (done, November 15).
6. In the evening the student sent the eleven notes in the table of the earlier November 16 checkpoint above and asked for all of them to be fixed, with free choice where a note said so. Stated as wishes in those notes: a patient with no patience left leaves by themselves, with nothing gained or lost; the till gets a meaning, with the doctor squeezed too; the automatic notes stay and the player's ticks and crosses go on top; the defence is a timing moment, and badly timed stops wear the glass down so that later attacks land more easily; the visitor shows that they are thinking; the game opens with a short scene. A fixed stage of five patients is acceptable for testing. The codebase stays in English.

## Student decisions, November 16

1. In the afternoon the student sent the two requests paraphrased in the November 16 evening checkpoint. Stated in them: the purpose is immersion; one large view shows the counter and the visitor across it; everything else becomes things on the desk "or somewhere", with papers as the example; clicking them brings up the reference sheet, the player's own notes, the surveillance camera or the other operations; the player may pay to repair the counter glass that earlier visitors broke. The student left the rest to the assistant ("think carefully about what I mean, then implement it"), so where each thing hangs, what it looks like, the keys, the price and the rules of the repair are not student decisions.
2. In the evening, after the second round, the student asked for the working tree changes to be committed with a sensible message, and for the commit to be in English. Both rounds went into one commit on `main` (`822e8d7`), which is now on `origin/main`.

## Student decisions, November 17

1. The student sent the five notes paraphrased in the first section, first given to Claude (Fable) and handed over when its quota ran out, and asked for all of them to be thought through, planned and implemented. Stated in them: pass and fail should be clear, with something pointing at the sheet (how long a grip is reasonable, for example); CALM goes, or costs money; the opening guidance walks the player through everything once; a patient may fly into a rage and lunge in the middle of any action, with transitions; the story: a doctor fired by a megacorp and in debt, working for a gang at a street implant clinic, contacts who exchange codes and smuggle military or high-end implants, illegally chromed cyberpsychos, a daily contact list to cross-reference the visitors, a different code for each contact, and a wrong code that costs patience; and the whole should be smooth and airtight. Paid CALM rather than none, the form of the training and the readouts, the rules and numbers of snaps, flares and codes, the line at 240, the names Kessler and the Lanterns, and every sentence are the assistant's choices, not student decisions.

## Student decisions, November 18

1. The student asked for the work of November 17 to be pushed, and then for the game to be started so that they could look at it. The work went into one commit on `main`, with an English message and no AI attribution, and was pushed to `origin/main`. What the student saw or made of the game is not recorded here.

## Game runtime: current state

### What was done on November 17 (the five notes)

The first section says what each change is; the [November 17 note](docs/development/story-and-clarity-2026-11-17.md) has the exact rules. Where each thing lives:

- **Rules and data.** `game/data/rules.json` version 6 (`line`, `reassure`, `contacts`, `snap`, `flare`, `grip.limit_ms`); the new `contacts.json` (ten entries, two per visitor, each with an alias, a clue pair, a code line, an answer and a package); `intro.json` version 4 (six cards, the guide with the list, the 14 training tips); a `lines.code` sentence and a `flare` in each case file. `scripts/core/case_db.gd` checks the new groups and the clue logic (`validate_contacts()`, `_validate_surprises()`); a contacts file in which one clue alone picks out a visitor, or two clues fit anyone but their own, does not load.
- **State.** `shift_state.gd`: `draw_contacts()` (seeded from the shift seed; the training night puts its first visitor on the list), `contact_for()`, and in the report `contacts`, `drops`, `drop_total`, `calm_total`. `visit_state.gd`: `say_code()`, `code_cost()`, `till_change()`, `reassure_cost()`, `roll_action()`, `snap_chance()`, `flare_chance()`, `snap()`, `flare()`.
- **Screen.** `main.gd`: `act_list()`, `act_say_code()`, the first-night training block, `_roll_surprise()`, `_update_surprise()`, `_tear_scope()`, `_snap_now()`, `_flare_now()`, the new hints. The new `coach.gd` is the training box. `clipboard.gd`: the list paper, SAY, the swap tab. `scope_view.gd`: the SHEET line, the eye readouts, the LIMIT mark, `tear()`. `patient_rig.gd`: `surge()`. `intro.gd`: the four new card pictures. `screens.gd`: title and report. `desk.gd` and `guide.gd`: the list on the left wall, the booklet on the right.
- **Keys and options.** New keys: L (the list) and K (skip the training). New game options: `--no-training`, `--no-surprises`. New launcher option: `-ImportOnly`.
- **Art.** `tools/art/gen_booth.py` and `gen_clinic.py` write `ui/obj_list.png` (the list on the wall) and `clinic/list.png` (its paper when it is down), and redraw `clinic/booth.png` without the HOUSE RULE sign. No sound was added.
- **Launcher.** `run-game.ps1`: `Get-MissingImports`, the import loop (up to three tries) and `-ImportOnly`.
- **Event log.** New events `contacts`, `code`, `surprise_due`, `snap`, `flare`, `training`, `training_end`; `reassure` now carries `cost` and `calm_spent`.
- **Tests.** `run_tests.gd` 820 checks (719 before); `run_ui_smoke.gd` 940 checks over nine shifts (724 over six before; the first six hold the new rules still, the last three play the night as it is: the list and the paid CALM at 240 an hour, a cued flare and snap, and the training); `run_proxy_integration.gd` 196 (the same count; the file did not change); `capture_shift.gd` 196 frames over four shifts (180 before) and 91 with `--attacks-only --less-blood` (89 before); `measure_text.py` 514 lines (454 before); `gd_static_check.py` 30 scripts (`coach.gd` is new) and knows the new objects. `play_driver.gd` gained the inputs for the list, SAY, the training and the cued surprises.

### What was done on November 16, evening (the counter-first screen and glass repair)

The November 16 evening checkpoint says what the screen and the repair are; [game/README.md](game/README.md) has them as a player meets them. Where each thing lives:

- **The layout.** `gfx.gd` holds every rectangle: `WINDOW` (100, 0, 440 x 300), `DIALOGUE` (the transcript unit in the desk), `SHEET` and `RECORD` (the two papers once they are down), `CAM` (the larger hall screen), `THUMB` (the small monitor), `METER`. The view through the window is drawn at twice its earlier size (`VIEW_SCALE`, `to_view()`).
- **The booth and the things in it.** `tools/art/gen_booth.py` writes the booth (`clinic/booth.png`), the hall screen's frame (`clinic/cam_panel.png`), the wall objects (`ui/obj_sheet.png`, `obj_guide.png`, `obj_card.png`, and since November 17 `obj_list.png`), the glass key (`ui/tool_glass.png`) and the wall pads (`ui/pad_w.png`, `pad_w_hot.png`); `build_all.py` runs it with the other generators. `desk.gd`: `PADS` (ten: three instruments and three ways of talking on the desk, four controls on the right wall) and `OBJECTS`, `object_at()`, `badges` (the price on the glass key, the unread count on the card), `taken`, and `nudge` (blinking corners). `clinic_view.gd` draws the meter (`_draw_meter()`), the hall monitor and the larger screen.
- **Papers.** `clipboard.gd`: `sheet_open`, `card_open`, `tab_at()`, `mark_at()`. `main.gd`, the block headed "the booth walls": `act_sheet()`, `act_card()`, `act_cam()`, `_panels_live()`, `_card_forced()`, `_papers_aside()` and `_papers_return()` (around a close-up), `_sync_panels()` (every frame: what is down, the badges, the nudges). `_wall_click()` handles the tabs, the hall screen and the wall objects before anything else in `_exam_click()`. Each opening or closing is logged as `panel`.
- **Keys** (`_key_press()`): R sheet, N card, C hall camera, G glass, next to the older H or F1, SPACE, TAB, T, ENTER, ESC, M and F11 (and since November 17 L and K). While the typing line is open only F1 is not a letter.
- **Glass repair.** `rules.json` `attack.repair_cost`. `shift_state.gd`: `repairs`, `repair_cost()`, `can_repair()`, `repair_glass()`, `repair_total()`; `total()` and `reading()` count them. `main.gd`: `_can_mend()`, `_glass_hint()`, `act_repair_glass()`; the event is `glass_repair`. `clinic_view.gd` `clear_decals()` is the wipe; `gen_audio.py` writes `glass_fit.wav`.
- **The transcript unit.** `dialogue_box.gd` has a separate node for its face (`back`), so that blood running down the desk is drawn over the face and under the words.
- **Words.** In `main.gd` the hints of the wall objects (`OBJECT_HINT`, `TAB_HINT`, `CAM_HINT`, `CAM_PEEK_HINT`, `CAM_OFF_HINT`), the glass key's four hints (`GLASS_HINT`, `GLASS_BUSY_HINT`, `GLASS_WHOLE_HINT`, `GLASS_OFF_HINT`) and the fitter's line (`GLASS_LINE`); the guide's pages are in `data/intro.json`.

### What was done on November 16, earlier (the eleven notes)

The table of the eleven notes above says what each change is for. Where each one lives:

- **Leaving.** `visit_state.gd`: `is_spent()`, `leave_ms()`, `give_up()` (outcome `gave_up`). `main.gd`: `_start_leaving()`, `_update_leaving()`, `_gave_up()`; the bar stands still while a reply is on its way, a test or the microphone is open, or the guide is up. Each case file has a `lines.spent` sentence. The old walk-out after pressing stays a separate outcome.
- **The lender's line.** `shift_state.gd`: `line_per_hour()`, `line_at()`, `reading()`, `readings()`, `hours_under()`; `report()` adds `line_held`, `hours_under` and the readings. `rules.json` `titles` entries may carry `line_held`; the first entry that fits wins, so THE CUT is listed first. `main.gd` `_begin_wait(reading)` shows the meter's line after a slip; the last reading is the report.
- **Timing bar and glass.** `shift_state.gd`: `glass`, `glass_out`, `glass_max()`, `glass_blow()`, `glass_break()`, `attack_plan()` (which blows land and when the patient is through, from the glass left). `visit_state.gd`: `take_blow()`, `shutter_grade()`. `clinic_view.gd`: `bar_start()`, `bar_stop()`, `bar_clear()`, `set_glass_left()`. The five plates are the `STOP_*_LINE` constants in `main.gd`.
- **Marks and the house rule.** The mark boxes and `cycle_mark()` are older. New: `visit_state.gd` `crossed()` and `ticked()`; `main.gd` `act_mark(row)` logs the mark and sets the strip hints (`CROSS_SOME_HINT`, `CROSS_RULE_HINT`); `clipboard.gd` draws `CROSSED n/N` in the decision box. `sheet.json` `threshold`; `case_db.gd` checks every case against it.
- **Opening, guide, hints.** `scripts/ui/intro.gd` and `guide.gd` draw everything in code; the words are in `data/intro.json` with `{per_hour}`, `{hours}`, `{total}` and `{threshold}` filled in from the rules. `main.gd`: `_run_intro()`, `act_guide()`, `_coach(id, text)` for the one-time hints, `_status_line()` for the title card.
- **Poses.** `patient_rig.gd`: `thinking`, `listening`, the thought bubble. `main.gd` sets them every frame from `_thinking`, `THINK_POSE_AFTER` (0.25 s) and the microphone state.

### What was done on November 15

Later in the day, from the student's list of things seen but not changed (Claude; automated checks and measurements only, nobody played or listened; evidence in `validation/2026-11-15/claude-mix-fixes/`):

- **Attack loudness.** Every sound of an attack plays 9 dB quieter (`ATTACK_TRIM_DB` in `game/scripts/ui/main.gd`, one number). Measured from a silent recording of the master bus (`--audio-driver Dummy` still mixes): the loudest second of an attack sat about 24 dB over the room; now 19 dB when the shutter catches it and 22 dB when it lands. The limiter was holding in 21% (caught) and 59% (landed) of 50 ms windows; now 0% and 8%. The room stays at -33 dBFS. -6 dB was tried first and was not enough for a landed attack.
- **Whine.** An early shutter fades the whine over 0.12 s instead of cutting it, and `whine.wav` (regenerated by `tools/art/gen_audio.py`) ends with a 60 ms release: its last millisecond went from 0.600 to 0.008 of full scale.
- **Arrival order.** `rules.json` `arrivals`: each shift shuffles `shift_order` from its seed; the first shift of a session opens with a steady patient. `--authored-order` keeps the listed order; the tests and captures use it. 40 seeds give at least 10 different orders.
- **Acting while the patient answers.** Looking, marking the sheet, picking up the TREAT stamp, opening the Trauma Team line and the shutter no longer wait for a reply. A look shows its own line and holds the dots off for 1.6 s. TREAT or the call decide at once and drop the reply (`reply_dropped` in the event log, with the stage). Asking, tools, CALM, PRESS, typing and speaking still wait; after 0.8 s the strip says "Still answering. You can look meanwhile, or decide now." Offline and with the mock there is no wait beyond the doctor's own line typing; the live wait is unmeasured (deadlines 3.5 s / 4 s).
- **Blood** was left alone at the student's request.
- **Live-test brief** for Codex: [docs/development/live-model-test.md](docs/development/live-model-test.md).

Earlier on November 15:

- **Agent-operated play in a real window** (`validation/2026-11-15/claude-window-play/`). Claude drove the built game in a real Windows window on the real GPU and sound driver through posted window messages, captured screens with `PrintWindow`, and recorded the master mix. Offline: two full shifts plus part of a third, every pad, the typing line, both decisions, false calls and alarms, both attacks with a late and an early shutter, a walk-out, the reports, a 3x window and `--less-blood`. Everything behaved as designed; the console logs have no error, warning or leak line. **This is not a human playtest and not a listening test: nobody watched or listened.**
- **Sound measured, not heard.** Peak -1.0 dBFS with no clipped samples; the rain and drone bed sits near -33 dBFS RMS and never drops out; attacks reach about -6 to -9 dBFS, a jump of about 27 dB from the bed. Loop seams are clean. `whine.wav` stops abruptly behind an early shutter. Both need a person with headphones.
- **Push-to-talk freeze found and fixed** (`validation/2026-11-15/claude-mock-voice/`). With the real microphone and the mock proxy, every TAB press froze the game for about 450 ms, because opening the Windows input device blocks; about 300-500 ms of every press was lost (a 0.48 s press arrived as 168 ms and was refused as a tap). `game/scripts/core/voice_input.gd` now opens the device on a worker thread. Until it is ready the strip says **OPENING THE MICROPHONE...** and "Speak when it says LISTENING."; letting go before then sends nothing and says so. Measured after the fix: no frame gap over 50 ms at any press, the device ready after 465-472 ms, the push-to-talk duck down to -18 dB and back within about 150 ms, focus loss throwing the clip away, a decision during transcription dropping the late transcript, and a slow service (5 s) falling back to the authored line after 3.5 s. New tests: 7 rule checks with a slow simulated device, 4 scene checks over HTTP.
- **OpenAI route added** to the proxy (`agent_proxy/src/providers.mjs`, `BTC_PROVIDER=openai`): the Responses API with a strict JSON schema, `store: false`, no retry, and `/v1/audio/transcriptions` for push-to-talk. At this earlier checkpoint only six fake-network tests had run; the later live result is recorded above.
- `tools/art/measure_text.py` now also measures every fixed hint in `main.gd` against the 376 px strip (widest 288 px).
- `AGENTS.md`'s outdated voice sentence was replaced, and the source was transferred into this repository.

### Results in this checkout

Run on the evening of November 17 in this checkout: a first run before the last two changes (logs in the local `validation/2026-11-17/first-run/`), then a final run on the tree as it stands, with the same counts (`validation/2026-11-17/checks/`, with the runner script `run_checks.ps1` beside the logs; `validation/` is not in the repository). The repeated imports from an empty cache, the mending of the crashed copy and the launcher tests came after the final run. The counts of November 16 are in the checkpoints above and in `validation/2026-11-16/`. PowerShell, from the repository root:

```powershell
$GODOT = "$env:LOCALAPPDATA\CodexTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
```

| Check | Command | Result |
|---|---|---|
| Import with the existing cache | `& $GODOT --headless --audio-driver Dummy --path game --import` | exit 0, nothing on standard error; no tracked file changed |
| Import from an empty cache (a copy of `game/` without `.godot/`) | the same, on the copy | not reliable: exit 0 with three Unicode errors in the first run, a crash (0xC0000005) in the final one; in 20 repeats, 2 crashes on this tree and 1 on `822e8d7` (first section). A second import mended the copy that crashed |
| Rules, outcomes, agent and voice units | `& $GODOT --headless --audio-driver Dummy --path game --script res://tests/run_tests.gd` | 820 passed, 0 failed |
| Nine shifts through the real scene, offline | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/run_ui_smoke.gd` | 940 passed, 0 failed |
| The same, less blood | add ` -- --less-blood` | 940 passed, 0 failed |
| Window close | `& $GODOT --headless --audio-driver Dummy --verbose --path game --script res://tests/run_close_check.gd` | 5 passed, 0 failed; no leak line in the verbose exit report |
| Proxy unit tests | `npm test` in `agent_proxy` | 38 passed, 0 failed (the proxy did not change) |
| Game and proxy over HTTP, local mocks, simulated microphone | `node tools/run_proxy_integration.mjs $GODOT validation/2026-11-17/http-integration` | 196 passed, 0 failed; wire checks 15 passed, 0 failed |
| Every text fits | `python measure_text.py` inside `tools/art` | 514 lines, 0 problems |
| Rough GDScript lint | `python tools/gd_static_check.py` | 30 scripts, no findings |
| Capture script, dry run | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd` | 196 frames named, 0 missed; with ` -- --attacks-only --less-blood`, 91 frames named, 0 missed |
| Capture drawn on a hidden desktop (the same game code) | `python tools/run_hidden.py ...` (command in its header) | 196 frames of four shifts saved, 0 missed, exit 0 in 176 s; with ` --attacks-only --less-blood`, 91 frames, 0 missed, exit 0 in 117 s; no window on the student's desktop in either run |
| Main scene boots | `--quit-after 240`, default and `-- --agent-url=http://127.0.0.1:9 --model` | exit 0 both; the known `4 ObjectDB instances were leaked` warning that `--quit-after` causes, and nothing else |
| Main scene boots on the real renderer | the windowed executable through `python tools/run_hidden.py`, `--audio-driver Dummy --path game --quit-after 420` | exit 0 in 5 s on OpenGL 3.3; the same known warning and nothing else; no window on the student's desktop |
| The launcher's import step | `.\run-game.ps1 -ImportOnly` on a copy of the repository, six cases | as in the first section; scripts and output in `validation/2026-11-17/launcher-test/` |

Every row from "Rules" to "dry run" exited 0 and wrote nothing to standard error. These are automated checks with the dummy audio driver, a simulated microphone and the mock. They show the flow holds together, not that it is fun, and not that a person can make the timing windows: the scene test presses the shutter within one frame of the moment it chooses.

### Launch

```powershell
.\run-game.ps1                      # offline; -LessBlood, -Mute, -Seed 123, -GodotPath <exe>, -ImportOnly
cd agent_proxy; npm run dev         # patient service (mock unless .dev.vars says otherwise)
.\run-game.ps1 -Model -AgentUrl http://127.0.0.1:8787   # second terminal, repository root
```

In a fresh clone the first run imports the pictures, fonts and sounds before the game starts (about 6 s) and tries again if the import stops short. The window's corner reads `AI DIALOGUE`, `MOCK TRANSPORT` or `OFFLINE FALLBACK`.

### The live model test: route, what is needed, cost

- **OpenAI configuration:** the API uses a project key in the ignored `agent_proxy/.dev.vars`, loaded by Node. The student explicitly authorized assistant configuration on November 15. Do not read, print or copy this file, or place its credential in the game, command lines, logs or Git.
- **OAuth works for Google** (Vertex AI with a short-lived token from `gcloud auth application-default print-access-token` and the course project), if the student prefers that route. Its billing state is unconfirmed, and whether `gemini-3.5-flash-lite` accepts audio for push-to-talk is unverified.
- **Proposed OpenAI test:** `gpt-6-luna` (reasoning effort `none`) for the patient and `gpt-4o-mini-transcribe` for speech. List prices read on November 15 on OpenAI's pricing page: USD 0.10 per million input tokens, 0.50 per million output tokens, USD 0.003 per minute of audio. Measured prompts are 2,281-3,818 characters (about 600-1,000 tokens). About 30 patient lines and 10 spoken clips would cost about **USD 0.006**; a full three-shift session at the caps (240 calls) about USD 0.05. These are estimates from list prices, not measurements.
- **The step-by-step brief for the agent who runs it** (written for Codex, November 15): [docs/development/live-model-test.md](docs/development/live-model-test.md).
- During the run, read `latency_ms`, `input_tokens` and `output_tokens` in the proxy log; compare with the 3.5 s / 4 s deadlines; judge whether the patient stays in character and never contradicts the fixed evidence; check transcription on the student's own voice.

### Limits (both places: `game/data/rules.json` `agent`, `agent_proxy/src/core.mjs` `DEFAULT_LIMITS`)

| Limit | Value |
|---|---|
| Patient replies per visit / per session | 16 / 240 (student: keep 16) |
| Proxy deadline / game deadline | 3.5 s / 4 s |
| Reply length | asked for 110 characters, refused only over 220 |
| Conversation memory | 48 entries per visit, cleared for the next patient |
| Spoken clips | 0.35-10 s, 24 per visit, 360 per session; 6 s / 7 s deadlines |
| Provider calls per proxy process | 2,000, shared by both routes |

The live run's maximum output was 66 tokens and maximum response time 2.54 seconds. No increase to the 256-token budget or deadlines was warranted.

### Not done, not verified

- No human playtest, human speech-accuracy check, listening test or Windows export build. The live-model run and synthetic-speech service check of November 15 are complete; nobody spoke into the microphone in that run. Google/Vertex remain untested live.
- None of the builds of November 16 and 17 has been operated in a visible window by anyone, been heard, or met a live model. Unknown from November 17: whether the training walks a new player through the eye test and the grip, whether the readouts make them clear, whether the list is fun, whether a person can react to a snap in time, whether a flare panics the player, and whether 240 an hour with 300 a drop is a fair night. Unknown from November 16: whether a person can stop an attack inside the timing bar, whether eight seconds is enough to decide, whether the counter-first screen is what the student meant, whether a paper in front of the window is comfortable to read beside the patient, whether a player finds the things on the walls without the guide, and whether paying for glass is ever worth it.
- No sound was added on November 17: the snap, the flare, the list, the codes and the training reuse existing sounds, and nobody has measured how they sit in the mix. The -9 dB attack trim and the whine fade were judged from measurements of a silent recording only. The sounds reused by the moments of November 16 (meter, crossed rule, leaving countdown, opening, guide) have not been measured in the mix, and neither has `glass_fit.wav`.
- The fresh-import crash: its cause is not known, and it is not in this project's files as far as the commit's crash shows. Not tried: another Godot version, the editor's first import, a `--verbose` import that might show where it stops.
- Keyboard layouts, input methods and a denied Windows microphone permission are untested. A device that fails to open after the press is covered only by reading the code.
- A typed or spoken provocation has no rule effect; only the PRESS pad costs patience. A typed code is not a code either: only SAY on the list says one. The patient does not speak aloud. The typing line has no paste.
- The Worker entry (`agent_proxy/src/worker.mjs`) has never been deployed.
- Leftovers: `agent_proxy/src/scripted.mjs` is no longer imported; `move_validator.gd` keeps an old name for a shape check.

### For the student to decide

Proposals of November 17 (the five notes), built but not reviewed:

- **The training.** 14 tips on the first night only, their words (`data/intro.json`), the 2 s and 10 s after which a tip gives way, and K to skip it. A walk-through with forced steps was not built, because the design keeps every examination optional and unordered.
- **CALM at 30 credits** (`reassure.cost`; 0 makes it free again), or removing it.
- **The readouts.** Whether TIGHTENS, STAYS WIDE, FOLLOWS and the red grip past LIMIT 1s say too much, or still too little.
- **The contacts.** Two a night (`contacts.per_night`), 300 a drop, 1 patience for a wrong code (`contacts.wrong_cost`), clues only from the intake card and the eyes, a pool of ten entries, the first visitor on the training night's list.
- **The line at 240 an hour.** Five right calls without a drop now end in THE CUT. Whether that is the pressure meant, or whether right calls alone should hold the line (a lower `line.per_hour`).
- **Snaps and flares.** A snap's 3 free actions, 0.08 a step and 0.30 at most (`snap`), the 0.35 s before its attack (`snap.lead_ms`), a flare's 0.10 an action, once a visit (`flare`), and a shutter on a flare counted as a false alarm (−100).
- **The story's names and words.** Kessler and the Lanterns (Harrow Credit is from November 16), the six cards, the aliases, clues, codes and packages, the flare lines.
- **The booth.** The HOUSE RULE sign removed so that the booklet fits on the right wall; the list on the sheet's hook, so that one of the two papers is down at a time.
- **Words on screen.** "Contact" for the gang's people (the code and the data still say courier for the role), and Kip a bike courier.

Proposals of the evening of November 16 (the counter-first screen and glass repair), built but not reviewed:

- **Whether this is the screen that was meant.** One large window with the patient, and everything else as a thing in the booth. Is anything missing from the booth, in the wrong place, or still too much like a panel? The transcript stays as a unit set into the desk, and the meter and the small hall monitor are always on the wall; only the papers, the larger hall screen and the guide open on a click.
- **How the papers behave.** All start a shift on the wall, the sheet's corners blink until it has been down once, a paper stays where it was left from patient to patient, and the intake card comes down by itself for the stamp and for the findings. A night that starts with the sheet already down was not built.
- **Keys**: R sheet, N card, C hall camera, G glass (and since November 17 L list, K skip the training), next to the older ones.
- **The hall camera**: between patients a second press of C, or a click on the larger screen, lets the next patient in; ENTER does it at once.
- **Glass repair**: 40 credits a layer (`rules.json` `attack.repair_cost`; 0 switches repairs off), only between patients, the till may go into debt for it, and no limit but the three layers of the pane. The fitter wipes the pane and leaves the rest of the blood.
- **Words**: the four guide pages (`data/intro.json`), the hints of the wall objects and of the glass key and the fitter's line (constants in `main.gd`), and CALM instead of REASSURE in the hints, after the name printed on the pad.

Proposals of the eleven notes (earlier on November 16), built but not reviewed (each is one number or one text file to change):

- **The house rule**: two crosses (`sheet.json` `threshold`), and whether the card should count the player's crosses at all.
- **Leaving**: eight seconds (`rules.json` `patience.leave_ms`; 0 makes them leave at once), and that CALM during the countdown holds the patient.
- **The line**: an hour under the line costs nothing until closing (the amount is 240 since November 17, above). A harsher version (a second hour under the line ends the night) was not built.
- **The glass**: three lamps (`attack.glass`), a new pane every shift, the 1.8 s window with blows at 0.54, 0.99 and 1.44 s (`attack.window_ms`, `blow_at`) and 0.65 s with none left (`min_window_ms`).
- **Words and names**: the opening cards, the guide, the coach hints and the ending text of THE CUT (`data/intro.json`, `rules.json`, constants in `main.gd`), and the lender's name, Harrow Credit.
- **The cast**: fixed truths and signs with a shuffled order, as the student said is fine for testing. Random combination of signs is not built and is listed as out of scope in the direction document.

Seen earlier, not changed:

- Blood stays until the shift ends (left alone on November 15 at the student's request): blood on the sill and seeping below it, gore on the shutter, and wall and desk stains all stay through the next patients. So do a broken window, a caught splash and dents in the glass, unless a layer of glass is paid for: the fitter's arm wipes the pane and nothing else. `--less-blood` removes the blood, not the broken glass.
- After a listening test: whether the -9 dB attack trim is right (`ATTACK_TRIM_DB`, one number).
- Whether asking, tools, CALM, PRESS and codes should also be allowed while a reply is on its way (they still wait; a live run will show for how long).
- Whether shuffled arrivals should stay (`rules.json` `arrivals.shuffle`).
- Open questions in the direction document: should a typed provocation count as pressure, should the patient speak aloud, how much blood by default.

### Documents behind the runtime

`docs/g1/01`-`04`, `06` and `07` are the submitted G1 versions and were left as submitted: the Configuration document and risk R3 still describe four calls per visit and 2-2.5 s deadlines, and `07` says voice is not implemented. `agent-config.json` was brought up to date on November 15.

## Next three tasks

Before them: run `git status -sb` and `git log -3 --oneline`. The work of November 17 was committed and pushed on November 18, so anything uncommitted is newer than this file. Never add AI attribution to a commit.

1. **The student plays a first night from a fresh start** (`.\run-game.ps1`, with headphones; a fresh clone imports first): the training from start to end, the eye test and the grip with their readouts and LIMIT 1s, the list and its clues, a right code and a wrong one, CALM at its price, a long exam of a drifting patient (a snap) and a flare; then a second night without the training, to see whether 240 an hour feels fair. Then settle the proposals under "For the student to decide" and tune the numbers from what the student felt, not from the tests. The questions of November 16 (whether the counter-first booth is what was meant, the papers, the glass) are still open and belong in the same session. An agent operating the window is not a substitute, and neither is the scene test.
2. **Real voice and a live look**: the student's own voice through TAB for accuracy, and a short live run so that the thinking pose, the leaving countdown and the replies around the new moments are seen with real latency (a code is never passed to the model, so the patient AI does not know one was said). A live run is a paid call and needs the student's explicit yes with provider, model, number of calls and cost; the November 15 ledger stays closed. The visual check of the corrected PATIENT SAID row (Codex, November 15) and paste support for the typing line are still open and belong here.
3. **Braintrust replies** (due November 19, 23:59 New York): the student picks two G1 pitches with fewer than two replies; draft specific, moment-based notes in English for review; the student sends them.

After these, or sooner if it gets in the way: the fresh-import crash. Try another Godot version on a copy, or report it upstream with the logs in `validation/2026-11-17/fresh-import-repeats/`; a public report is a post and needs the student's yes.

## Evidence (local, not in Git)

- `validation/2026-11-17/checks/`: the final run of November 17 (output and standard error of every check, `summary.txt`, the runner `run_checks.ps1`, `git status` before and after, the boot logs with `boot-real-renderer.log`). `fresh-copy/` is the copy of `game/` whose fresh import crashed, as mended by the second import (the three empty temporary files are still in its cache); `crashed-fresh-import/` holds the crashed import's output and the rule and scene logs on that copy before it was mended (the scene check's standard error cut to its first 300 lines).
- `validation/2026-11-17/fresh-import-repeats/`: the 20 + 20 imports from an empty cache (`repeat_fresh_import.ps1`, `summary.txt` for runs 1-6, `summary-7-20.txt`, each run's output and standard error), the mending of the crashed copy (`recover_crashed_copy.ps1`, `recovery-summary.txt`, `recover_*`), the copy started without an import (`launch-noimport.*`), and the copies `tree-current`, `tree-822e8d7` (from `git archive`) and `tree-launch` (used by the launcher tests).
- `validation/2026-11-17/launcher-test/`: the launcher tests, their stand-in engines and their output, with a `README.txt`. The first try of the crash case failed because the stand-in itself had been written with a broken engine path; the rerun after the fix passed.
- `validation/2026-11-17/captures-full/` (196 frames of four shifts) and `captures-attacks-less-blood/` (91 frames), with their `.log` files beside them.
- `validation/2026-11-17/first-run/`: the first run of the evening, before the last two changes: checks, both captures and the HTTP run.
- `validation/2026-11-17/http-integration/`: the final mock-provider HTTP run (prompt sizes, request shapes, wire checks; no live reply).
- The folders of November 16 describe the builds before the five notes; their counts are not results for this one. `validation/2026-11-16/checks-counter-first/`, `captures-counter-first-full/` (180 frames) and `captures-counter-first-attacks-less-blood/` (89 frames) are the evening's counter-first screen; `checks/`, `captures-full/` (162) and `captures-attacks-less-blood/` (79) the afternoon's three-column screen; `http-integration/` the evening's HTTP run; `checkpoint-eleven-notes/` the working tree between the two rounds (`tracked.patch` against `90fcc87`, and the then untracked files under `untracked/`).
- `validation/2026-11-15/codex-live-test/`: completed 30/10 ledger, metadata from live requests, game events, numeric quality and synthetic-WER scores, and regression logs. No live reply text, transcript or audio archive.
- `validation/2026-11-15/claude-mix-fixes/`: the mix measurements before and after (caught and landed, -6 and -9 dB), the whine file, every check on the final tree, the hidden-desktop capture, the probe scripts.
- `validation/2026-11-15/transfer-checks/`: every check right after the transfer.
- `validation/2026-11-15/claude-mock-voice/`: the push-to-talk freeze, before and after the fix.
- `validation/2026-11-15/claude-window-play/`: agent-operated offline play and the sound measurements.
- `validation/2026-11-15/claude-final-checks/`, `claude-rendered-checks/`: the same checks in `fathom` and the earlier rendered captures.
- Older folders under `validation/2026-11-14/` and `2026-11-12/` describe earlier builds; their counts are not results for this one.

## Rules that do not change

- Never add `Co-Authored-By` or any AI attribution to Git commits.
- Keep `.claude/`, credentials, caches, private course pages and `validation/` out of Git.
- Never call a mock run a live-model result, automated checks a human playtest, or an agent-operated run a playtest or listening test.
- Logs hold lengths and stages, never typed words, clips or transcripts.
- Course posts, peer replies, paid model calls and deployment each need the student's own yes.
