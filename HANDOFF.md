# Before the Cut: handoff

Updated **November 16, 2026, evening**. Communicate with the student in Chinese; write game text, code comments and project files in English.

**This repository is the only active checkout.** On November 15 the game, the patient-AI proxy and the tools were moved here from the legacy `fathom` workspace and checked here ([transition record](docs/development/repository-transition.md)). `fathom` is an archive; its long layered handoffs (`HANDOFF.md`, `CODEX_RUNTIME_HANDOFF.md`, `CLAUDE_VOICE_HANDOFF.md`, `CODEX_NEXT_HANDOFF.md`) are history, not instructions.

AI use: Claude wrote the earlier runtime history; Codex added the live-test results and speech-feedback correction of November 15; Claude built the answers to the student's eleven notes and then, later on November 16, the counter-first screen and the paid glass repair, and wrote the November 16 parts of this file. No student review of this update is recorded.

**Both rounds of November 16 are in one commit on top of `90fcc87`.** The student asked for it on the evening of November 16, after the second round: commit the working tree changes with a sensible message, in English. The request named a commit and did not mention a push. Run `git status -sb`: if `main` is ahead of `origin/main`, the commit is still local and the student has not yet been heard on pushing it, so ask. `validation/2026-11-16/checkpoint-eleven-notes/` (local) holds the tree as it was between the two rounds.

## Current checkpoint: the counter-first screen and paid glass repair (November 16, evening)

In the afternoon of November 16, at about 15:20 New York, the student sent two requests. Paraphrased from Chinese:

1. For immersion, perhaps this interface should keep only the counter: one large view that shows the counter and the visitor across it. Everything else becomes things on the desk or somewhere, such as papers, that are clicked to bring up the reference sheet, the player's own notes, the surveillance camera or the other operations. "Think carefully about what I mean, then implement it."
2. The player may also spend money to repair the counter's blast-proof glass, if earlier visitors have broken it.

Claude designed and built both that afternoon and evening. **Nobody has played, watched or listened to this version, and no paid service was called for it.** The two requests are the student's. The layout, the keys, the price and every sentence are assistant proposals that the student has not reviewed.

The screen now (640 x 360; every rectangle is in `game/scripts/ui/gfx.gd`):

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
- Three layers cost 120, one hour of the line. In the authored order, five right calls with a whole pane bought back close at 1,020, still over the line; the fourth capture shift shows that night.
- The fitter's arm wipes the pane. Blood on the sill and the walls and the damage to the shutter stay until the next shift. The arm has a new generated sound, `glass_fit.wav`.

What this round changed, on top of the eleven notes: `game/data/rules.json` (version 5) and `intro.json` (version 2); `game/scripts/core/shift_state.gd` and three lines of `case_db.gd`; in `game/scripts/ui/` the files `main.gd`, `gfx.gd`, `clinic_view.gd`, `desk.gd`, `clipboard.gd`, `dialogue_box.gd`, `guide.gd`, `scope_view.gd`, `gore_layer.gd`, and a few lines of `patient_rig.gd` and `screens.gd`; five of the six scripts in `game/tests/` (all but `run_close_check.gd`); in `tools/art/` the new `gen_booth.py` and changes to `build_all.py`, `gen_audio.py`, `gen_clinic.py` and `measure_text.py`; the generated assets `clinic/booth.png`, `clinic/cam_panel.png`, `ui/obj_sheet.png`, `ui/obj_guide.png`, `ui/obj_card.png`, `ui/pad_w.png`, `ui/pad_w_hot.png`, `ui/tool_glass.png` and `audio/glass_fit.wav`, each with its `.import` file, and a regenerated `clinic/lamp_glow.png`; the documents. Not changed in this round: the five case files, `sheet.json`, `visit_state.gd`, `intro.gd`, `run_close_check.gd`. Not changed on November 16 at all: `agent_proxy/`, the agent limits (so `rules.json` `agent` and `core.mjs` still agree), `agent-config.json`, the G1 documents, slides and narration. The version string is still 0.3.0.

Results on the evening of November 16, on the final working tree (logs in the local `validation/2026-11-16/checks-counter-first/`; commands in the table under "Results in this checkout"):

- **719 rule checks**, **724 scene checks** (six shifts; the same count with `--less-blood`), **5 normal-close checks**, **38 proxy tests**, and over HTTP with the mock provider and a simulated microphone **196 game checks and 15 wire checks**: all passed, every run exited 0 with nothing on standard error.
- Text measurement: 454 lines, 0 problems. Lint: 29 scripts, no findings. Capture script, dry: 180 frames named, 0 moments missed.
- Import: with the existing cache, exit 0 and no error. From an empty cache (`game/.godot/` moved aside for the run and put back afterwards), exit 0 in four seconds with the same single `Parameter "t" is null` error from the headless dummy renderer as on November 15 and one line about a dummy texture leaked at exit; the rule, scene, close and dry-capture checks passed on that fresh cache, and no tracked file changed.
- **Drawn on a hidden desktop** by `tools/run_hidden.py` (Dummy audio, simulated microphone, authored dialogue, a stand-in voice service): the full run saved **180 frames of four shifts, 0 moments missed**, exit 0, in 165.4 s; the attack scenes and the fitter with `--less-blood` saved **89 frames, 0 missed**, exit 0, in 115.6 s. The runner reported no window on the user's desktop in either run. The main scene also booted there on the real renderer through the normal start path (exit 0 in 4.0 s on OpenGL 3.3, only the known `--quit-after` warning).
- Frame review, by Claude and not by a person at the game: about 150 of the 180 frames of a first drawing, which led to three changes. The face of the transcript unit is now a separate node (`dialogue.back`) drawn under the blood that runs down the desk, with the words over it, so they stay readable. The hints call the CALM pad by the name printed on it; they said REASSURE. The capture script moves the pointer off the card it has just stamped. Both sets were then drawn again; 45 of the 180 redrawn frames were looked at, three transcript strips were enlarged, and 27 of the 89 less-blood frames were looked at, with no blood seen in those 27. Left as they are: the card that has come down overlaps the blank top right margin of a slip by 11 pixels; the stamp in hand hides a few letters of the card; two frames catch the card halfway through its slide.
- The scene test presses the shutter within one frame of the moment it chooses. It shows that every grade of stop is reachable and told correctly, not that a person can do it.

Limits of this checkpoint:

- No human playtest, no listening test, no human voice test. Nobody, agent or person, has operated this build in a visible window.
- The counter-first screen is one reading of a two-line request. Whether it is what the student meant, whether the papers are comfortable in front of the window (each covers the top of one side, 132 of 440 pixels in width), and whether a player finds the things on the walls without the guide are all unknown.
- Glass repair is untuned: 40 credits a layer, debt allowed, no limit but the three layers. Nobody knows whether buying glass is ever the right move.
- `glass_fit.wav` is generated and played by the game, but the tests run with the dummy audio driver; its place in the mix has not been measured and nobody has heard it.
- No live model has seen any of the November 16 changes.

## Earlier checkpoint of November 16: the student's eleven notes

**Superseded in part by the checkpoint above.** This section describes the build as it stood at about 15:10 New York on November 16. Since then the three-column screen has become the booth, the guide has four pages instead of three, a layer of glass can be bought back, and every count below has grown. The rules in the table are otherwise still in force.

On the evening of November 15 the student sent eleven notes on the build and asked for a planned, reasonable fix for all of them, with freedom to invent where a note said so. Claude designed and built the answers; the checks below ran on November 16. **Nobody has played, watched or listened to this version, and no paid service was called for it.** The notes are the student's. Every answer, number, name and sentence in the table is an assistant proposal that the student has not reviewed.

| Note | The student's note, paraphrased | What the build does now |
|---|---|---|
| 1, 5 | A patient whose patience is gone should leave by themselves: the round is missed, nothing gained and nothing lost. What is reassurance for, then? | The action that spends the last lamp still happens. The patient then says an authored line, a red LEAVING bar runs for 8 s (`rules.json` `patience.leave_ms`) and they walk out: outcome `gave_up`, 0 credits, not a right call. A decision can still be made while the bar runs. CALM (+1 lamp, twice a visit) buys another question, clears a refusal and, during the bar, holds the patient at the counter. |
| 2 | Give the till a meaning: the doctor is squeezed too, and needs so much an hour to stay off the cut line. | One patient is one hour. The chair, the tools and the doctor's own hands are on lease from a lender (the invented "Harrow Credit"), whose meter wants 120 more in the till every hour (`line.per_hour`). It is read after each slip and shown on the wall and in the report. Only the closing reading decides: under 600 is the ending THE CUT, whatever else went right. Nothing ends the night early. |
| 3 | Where is voice input? Is the reply fixed afterwards? Does it differ from the options in the tree? | The voice path is unchanged; it was made easier to find. Hold TAB or the SPEAK chip, only with the patient service running (`-Model -AgentUrl`); the words land on the typing line and ENTER says them. With the service every reply is generated, including the answers to the three ASK suggestions. Offline there is no voice, and a typed sentence either matches an authored question or gets an honest hint. New: the title card says which mode is on tonight, and the guide names the typing line and push-to-talk. (Offline, TAB already showed a hint that says what speaking needs.) |
| 4 | Can one see from a patient's looks what is wrong? Are patients recombined at random, or is the stage fixed? | Not changed. Looks show part of the signs; the rest needs a tool or talk, and steady patients carry harmless oddities. The cast of five and each truth are fixed; only the arrival order is shuffled. There is no random combination of signs. |
| 6, 10 | Defence should feel like a timed QTE. A badly timed one should crack the glass, so that a later attack lands more easily. | After the warning a red timing bar over the printer slot fills until the patient is through (1.8 s); its notches are the blows on the glass (0.54, 0.99, 1.44 s). Every blow that lands before the shutter costs one of three glass lamps for the rest of the shift, and with fewer lamps the patient is through sooner (1.44 s, 0.99 s, then 0.65 s). A plate grades each stop. A pane with no lamp left drops out of its frame; the next shift starts with a new one. (Since the evening a layer can also be bought back between patients; see the first section.) |
| 7 | Let the player tick or cross the intake record; keep the automatic notes. | The automatic notes stay. The box at each row was already there before these notes (one click is a tick, two a cross, three clears it, shown beside the truth after the visit), but nothing pointed at it. New: the guide and a one-time hint name the boxes, the card counts the crosses (next row), and each mark is logged as `mark`. Marks are never scored. |
| 8 | Is there a tutorial, or clear feedback: for example X of N marks means over the line? | The sheet's house rule is now a number (`sheet.json` `threshold`: two broken lines = drifting). The card counts the player's crosses against it (`CROSSED 1/2`) and the strip says so when the count is reached. It is advice, never a verdict. A three-page counter guide (four pages since the evening) opens with the first patient of a session (H or F1 opens it again), and three hints appear once each. The data check refuses a drifting case that breaks fewer lines than the threshold and a steady case that breaks any. |
| 9 | A short opening scene that gives the background. | Five skippable cards with moving pictures drawn by code, after the title card, once a session (`--no-intro` turns them and the guide's first showing off). |
| 11 | While the agent is thinking, the visitor should show it. | A quarter of a second after a question goes to the service the patient looks away in their own manner, with a small thought bubble; while the microphone is open they watch the doctor and their hands stop. Both follow the patient's idle habit, never the truth. Offline there is no wait and no pose. |

What changed in the repository at that checkpoint: `game/data/rules.json` (version 4), `sheet.json`, the five case files and the new `intro.json`; `game/scripts/core/` (`visit_state.gd`, `shift_state.gd`, `case_db.gd`); `game/scripts/ui/` (`main.gd`, `clinic_view.gd`, `clipboard.gd`, `patient_rig.gd`, `screens.gd`, `gfx.gd`, and the new `intro.gd` and `guide.gd`); every test script; `tools/art/measure_text.py`; the documents. Not changed: `agent_proxy/`, the agent limits (so `rules.json` `agent` and `core.mjs` still agree), `game/assets/` (no picture or sound was added or regenerated), `agent-config.json`, the G1 documents, slides and narration. The version string is still 0.3.0. The last commit before this work is `90fcc87`; read `git log` and `git status` to see whether this checkpoint has been committed.

Results at that checkpoint, at about 15:10 New York on November 16 (superseded by the evening's results above; logs in the local `validation/2026-11-16/checks/`; the commands are those of the table under "Results in this checkout", which now shows the evening's counts):

- **691 rule checks**, **570 scene checks** (five shifts; the same count with `--less-blood`), **5 normal-close checks**, **38 proxy tests**, and over HTTP with the mock provider and a simulated microphone **196 game checks and 15 wire checks**: all passed, every run exited 0 with nothing on standard error, and the saved output has no warning, error or leak line. November 15's note about shutdown resource warnings in the smoke harness did not recur: `leave()` in `game/tests/play_driver.gd` now stops every sound and waits 250 ms before the scene is freed. That is what these runs showed, not a guarantee for other ways of ending the engine.
- Text measurement: 433 lines, 0 problems. Lint: 29 scripts, no findings. Capture script, dry: 162 frames named, 0 moments missed.
- **Drawn on a hidden desktop** by `tools/run_hidden.py` (Dummy audio, simulated microphone, authored dialogue, a stand-in voice service): the full run saved **162 frames, 0 moments missed**, exit 0, in 173.7 s; the attack scenes with `--less-blood` saved **79 frames, 0 missed**, exit 0, in 86.0 s. The runner reported no window on the user's desktop in either run. Claude looked at about 30 of the 162 frames (the opening cards, the guide pages, the marks and the crossed rule, the meter over and under the line, the timing bar, the stop plates, the leaving bar and its slip, the listening and thinking poses, the three reports), not at every one, and at 16 of the 79: no blood was seen in those 16. Defects found in earlier frames were fixed and drawn again, among them guide badges that covered three labels and an HOUR note that turned before the meter had read the till. Frames: `validation/2026-11-16/captures-full/` and `captures-attacks-less-blood/`.
- The scene test presses the shutter within one frame of the moment it chooses. It shows that every grade of stop is reachable and told correctly, not that a person can do it.

Limits of that checkpoint, all of which still hold for the current build:

- No human playtest, no listening test, no human voice test. The November 16 build has not been operated in a visible window by anyone, agent or person.
- No live model has seen the new moments. The thinking pose, the leaving countdown while a reply is on its way and the meter have run only offline and against the mock.
- Every new number is an untuned first guess: 120 an hour, 8 s to leave, the 1.8 s window and its blow times, three glass lamps, 0.65 s with none, two crosses.
- The opening cards, the guide, the coach hints, the ending text of THE CUT and the name Harrow Credit are assistant writing.
- One correction to an earlier status message to the student: the change of the stop plate's condition from "the pane is out" to "no lamp is left" is not a visible fix. With the shipped rules a pane with no lamp left is always removed before the next attack, so both conditions give the same plate. The change ties the plate to the lamps, and the fifth test shift adds the scene checks that were missing for two plates.

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
- **The game** is version 0.3.0: one night at the counter with five patients (Kip, Rook, Vale, Juno, Maren) in a shuffled order, the first of a session steady, a Normal Reference Sheet, optional looks, tools, questions, reassurance and pressure in any order, a typing line, push-to-talk, TREAT or Trauma Team, attacks and the shutter, slips and an end-of-shift report. Since November 16 also: an opening and a counter guide, the lender's hourly line, patients who leave when their patience is gone, the player's own marks counted against the house rule, the timing bar and the counter glass, and the patient's thinking and listening poses (the table of the eleven notes above). Since that evening the screen is the inside of the booth, with the counter window in the middle and the papers, the hall camera and the controls as things on its walls and desk, and a layer of glass can be bought back between patients (first section). Controls, rules and spoilers: [game/README.md](game/README.md). Look, sound and design choices: [docs/development/direction.md](docs/development/direction.md).
- **The patient AI** (protocol 3) writes every reply and reaction from the character brief and the conversation so far; the authored script is the offline comparison and the fallback. The first live OpenAI run is complete; see the checkpoint above. Google and Vertex remain untested live.

## Student decisions, November 15

1. Recording is finished: the game window, mouse, keyboard, audio and microphone may be used for testing.
2. The student authorized the specified OpenAI run with a USD 50 ceiling, allowed assistant credential configuration and asked the assistant to supply voice input. The completed test used local synthetic speech and is explicitly not a human voice test.
3. The cap stays at 16 patient replies per visit.
4. The sentence in `AGENTS.md` that called voice a future task was replaced (done).
5. The repository transfer was left to the agent to schedule (done, November 15).
6. In the evening the student sent the eleven notes in the table of the earlier November 16 checkpoint above and asked for all of them to be fixed, with free choice where a note said so. Stated as wishes in those notes: a patient with no patience left leaves by themselves, with nothing gained or lost; the till gets a meaning, with the doctor squeezed too; the automatic notes stay and the player's ticks and crosses go on top; the defence is a timing moment, and badly timed stops wear the glass down so that later attacks land more easily; the visitor shows that they are thinking; the game opens with a short scene. A fixed stage of five patients is acceptable for testing. The codebase stays in English.

## Student decisions, November 16

1. In the afternoon the student sent the two requests paraphrased in the first section. Stated in them: the purpose is immersion; one large view shows the counter and the visitor across it; everything else becomes things on the desk "or somewhere", with papers as the example; clicking them brings up the reference sheet, the player's own notes, the surveillance camera or the other operations; the player may pay to repair the counter glass that earlier visitors broke. The student left the rest to the assistant ("think carefully about what I mean, then implement it"), so where each thing hangs, what it looks like, the keys, the price and the rules of the repair are not student decisions.
2. In the evening, after the second round, the student asked for the working tree changes to be committed with a sensible message, and for the commit to be in English. Both rounds went into one commit on `main`. The request did not mention a push. (After the first round the student had been asked whether to commit and push, and had answered with the next request instead.)

## Game runtime: current state

### What was done on November 16, evening (the counter-first screen and glass repair)

The first section says what the screen and the repair are; [game/README.md](game/README.md) has them as a player meets them. Where each thing lives:

- **The layout.** `gfx.gd` holds every rectangle: `WINDOW` (100, 0, 440 x 300), `DIALOGUE` (the transcript unit in the desk), `SHEET` and `RECORD` (the two papers once they are down), `CAM` (the larger hall screen), `THUMB` (the small monitor), `METER`. The view through the window is drawn at twice its earlier size (`VIEW_SCALE`, `to_view()`).
- **The booth and the things in it.** `tools/art/gen_booth.py` writes the booth (`clinic/booth.png`), the hall screen's frame (`clinic/cam_panel.png`), the three wall objects (`ui/obj_sheet.png`, `obj_guide.png`, `obj_card.png`), the glass key (`ui/tool_glass.png`) and the wall pads (`ui/pad_w.png`, `pad_w_hot.png`); `build_all.py` runs it with the other generators. `desk.gd`: `PADS` (ten: three instruments and three ways of talking on the desk, four controls on the right wall) and `OBJECTS` (sheet, guide, card), `object_at()`, `badges` (the price on the glass key, the unread count on the card), `taken`, and `nudge` (blinking corners). `clinic_view.gd` draws the meter (`_draw_meter()`), the hall monitor and the larger screen.
- **Papers.** `clipboard.gd`: `sheet_open`, `card_open`, `tab_at()`, `mark_at()`. `main.gd`, the block headed "the booth walls": `act_sheet()`, `act_card()`, `act_cam()`, `_panels_live()`, `_card_forced()`, `_papers_aside()` and `_papers_return()` (around a close-up), `_sync_panels()` (every frame: what is down, the badges, the nudges). `_wall_click()` handles the tabs, the hall screen and the wall objects before anything else in `_exam_click()`. Each opening or closing is logged as `panel`.
- **Keys** (`_key_press()`): R sheet, N card, C hall camera, G glass, next to the older H or F1, SPACE, TAB, T, ENTER, ESC, M and F11. While the typing line is open only F1 is not a letter.
- **Glass repair.** `rules.json` `attack.repair_cost`. `shift_state.gd`: `repairs`, `repair_cost()`, `can_repair()`, `repair_glass()`, `repair_total()`; `total()` and `reading()` count them. `main.gd`: `_can_mend()`, `_glass_hint()`, `act_repair_glass()`; the event is `glass_repair`. `clinic_view.gd` `clear_decals()` is the wipe; `gen_audio.py` writes `glass_fit.wav`.
- **The transcript unit.** `dialogue_box.gd` has a separate node for its face (`back`), so that blood running down the desk is drawn over the face and under the words.
- **Words.** `data/intro.json` version 2 (four guide pages, with `{repair_cost}` filled in from the rules) and `guide.gd`; in `main.gd` the hints of the wall objects (`OBJECT_HINT`, `TAB_HINT`, `CAM_HINT`, `CAM_PEEK_HINT`, `CAM_OFF_HINT`), the glass key's four hints (`GLASS_HINT`, `GLASS_BUSY_HINT`, `GLASS_WHOLE_HINT`, `GLASS_OFF_HINT`) and the fitter's line (`GLASS_LINE`).
- **Tests.** `run_tests.gd` 719 checks (691 before); `run_ui_smoke.gd` 724 checks over six shifts (570 over five before); `run_proxy_integration.gd` 196 (the same count, adapted to the new screen); `capture_shift.gd` 180 frames over four shifts (162 over three before) and 89 with `--attacks-only --less-blood` (79 before); `measure_text.py` 454 lines (433 before). `play_driver.gd` gained the inputs for the papers, the hall screen and the glass key.

### What was done on November 16, earlier (the eleven notes)

The table of the eleven notes above says what each change is for. Where each one lives:

- **Leaving.** `visit_state.gd`: `is_spent()`, `leave_ms()`, `give_up()` (outcome `gave_up`). `main.gd`: `_start_leaving()`, `_update_leaving()`, `_gave_up()`; the bar stands still while a reply is on its way, a test or the microphone is open, or the guide is up. Each case file has a `lines.spent` sentence. The old walk-out after pressing stays a separate outcome.
- **The lender's line.** `shift_state.gd`: `line_per_hour()`, `line_at()`, `reading()`, `readings()`, `hours_under()`; `report()` adds `line_held`, `hours_under` and the readings. `rules.json` `titles` entries may carry `line_held`; the first entry that fits wins, so THE CUT is listed first. `main.gd` `_begin_wait(reading)` shows the meter's line after a slip; the last reading is the report.
- **Timing bar and glass.** `shift_state.gd`: `glass`, `glass_out`, `glass_max()`, `glass_blow()`, `glass_break()`, `attack_plan()` (which blows land and when the patient is through, from the glass left). `visit_state.gd`: `take_blow()`, `shutter_grade()`. `clinic_view.gd`: `bar_start()`, `bar_stop()`, `bar_clear()`, `set_glass_left()`. The five plates are the `STOP_*_LINE` constants in `main.gd`.
- **Marks and the house rule.** The mark boxes and `cycle_mark()` are older. New: `visit_state.gd` `crossed()` and `ticked()`; `main.gd` `act_mark(row)` logs the mark and sets the strip hints (`CROSS_SOME_HINT`, `CROSS_RULE_HINT`); `clipboard.gd` draws `CROSSED n/N` in the decision box. `sheet.json` `threshold`; `case_db.gd` checks every case against it.
- **Opening, guide, hints.** `scripts/ui/intro.gd` and `guide.gd` draw everything in code; the words are in `data/intro.json` with `{per_hour}`, `{hours}`, `{total}` and `{threshold}` filled in from the rules. `main.gd`: `_run_intro()`, `act_guide()`, `_coach(id, text)` for the three one-time hints, `_status_line()` for the title card.
- **Poses.** `patient_rig.gd`: `thinking`, `listening`, the thought bubble. `main.gd` sets them every frame from `_thinking`, `THINK_POSE_AFTER` (0.25 s) and the microphone state.
- **Tests.** `run_tests.gd` 691 checks (505 before); `run_ui_smoke.gd` 570 checks over five shifts (333 over three before); `run_proxy_integration.gd` 196 (193 before); `capture_shift.gd` 162 frames over three shifts (122 over two before); `measure_text.py` 433 lines (302 before) with the opening, the guide, the plates and the new hints. `play_driver.gd` gained the inputs for all of it and a `leave()` that silences the scene before it is freed.

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

Run on the evening of November 16 at about 20:14 New York, in one pass on the final game code of both rounds, and once more at about 20:40 after the documents were written, with the same counts. Logs of the second pass: local `validation/2026-11-16/checks-counter-first/`, with the runner script beside them (`validation/` is not in the repository). The two imports and the boot on the real renderer ran at about 20:24 and 20:30, between the two passes. The counts of the afternoon (691, 570, 433 lines, 162 and 79 frames) are in the earlier checkpoint above and in `validation/2026-11-16/checks/`. PowerShell, from the repository root:

```powershell
$GODOT = "$env:LOCALAPPDATA\CodexTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
```

| Check | Command | Result |
|---|---|---|
| Import with the existing cache | `& $GODOT --headless --audio-driver Dummy --path game --import` | exit 0, nothing on standard error; no tracked file changed |
| Import from an empty cache (`game/.godot/` moved aside for the run, then put back) | the same | exit 0 in 4 s; one `Parameter "t" is null` error from the headless dummy renderer, as on November 15, and one line about a dummy texture leaked at exit; no tracked file changed. The rule, scene (both blood settings), close and dry-capture checks passed on that cache |
| Rules, outcomes, agent and voice units | `& $GODOT --headless --audio-driver Dummy --path game --script res://tests/run_tests.gd` | 719 passed, 0 failed |
| Six shifts through the real scene, offline | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/run_ui_smoke.gd` | 724 passed, 0 failed |
| The same, less blood | add ` -- --less-blood` | 724 passed, 0 failed |
| Window close | `& $GODOT --headless --audio-driver Dummy --verbose --path game --script res://tests/run_close_check.gd` | 5 passed, 0 failed; no leak line in the verbose exit report |
| Proxy unit tests | `npm test` in `agent_proxy` | 38 passed, 0 failed (the proxy did not change) |
| Game and proxy over HTTP, local mocks, simulated microphone | `node tools/run_proxy_integration.mjs $GODOT validation/2026-11-16/http-integration` | 196 passed, 0 failed; wire checks 15 passed, 0 failed |
| Every text fits | `python measure_text.py` inside `tools/art` | 454 lines, 0 problems |
| Rough GDScript lint | `python tools/gd_static_check.py` | 29 scripts, no findings |
| Capture script, dry run | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd` | 180 frames named, 0 missed |
| Capture drawn on a hidden desktop (the same game code) | `python tools/run_hidden.py ...` (command in its header) | 180 frames of four shifts saved, 0 missed, exit 0 in 165.4 s; with ` --attacks-only --less-blood`, 89 frames, 0 missed, exit 0 in 115.6 s; no window on the student's desktop in either run |
| Main scene boots | `--quit-after 240`, default and `-- --agent-url=http://127.0.0.1:9 --model` | exit 0 both; the known `4 ObjectDB instances were leaked` warning that `--quit-after` causes, and nothing else |
| Main scene boots on the real renderer | the windowed executable through `python tools/run_hidden.py`, `--audio-driver Dummy --path game --quit-after 420` | exit 0 in 4.0 s on OpenGL 3.3; the same known warning and nothing else; no window on the student's desktop. This is the normal start path into the opening cards, with no input sent |

Every row from "Rules" to "dry run" exited 0 and wrote nothing to standard error. These are automated checks with the dummy audio driver, a simulated microphone and the mock. They show the flow holds together, not that it is fun, and not that a person can make the timing windows: the scene test presses the shutter within one frame of the moment it chooses.

### Launch

```powershell
.\run-game.ps1                      # offline; -LessBlood, -Mute, -Seed 123, -GodotPath <exe>
cd agent_proxy; npm run dev         # patient service (mock unless .dev.vars says otherwise)
.\run-game.ps1 -Model -AgentUrl http://127.0.0.1:8787   # second terminal, repository root
```

The window's corner reads `AI DIALOGUE`, `MOCK TRANSPORT` or `OFFLINE FALLBACK`.

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
- Neither round of November 16 has been operated in a visible window by anyone, been heard, or met a live model. Whether a person can stop an attack inside the timing bar, whether eight seconds is enough to decide, and whether 120 an hour is a fair line are all unknown. So are the questions of the evening: whether the counter-first screen is what the student meant, whether a paper in front of the window is comfortable to read beside the patient, whether a player finds the things on the walls without the guide, and whether paying for glass is ever worth it.
- The -9 dB attack trim and the whine fade were judged from measurements of a silent recording only. The sounds reused by the new moments (meter, crossed rule, leaving countdown, opening, guide) have not been measured in the mix, and neither has the new `glass_fit.wav`.
- Keyboard layouts, input methods and a denied Windows microphone permission are untested. A device that fails to open after the press is covered only by reading the code.
- A typed or spoken provocation has no rule effect; only the PRESS pad costs patience. The patient does not speak aloud. The typing line has no paste.
- The Worker entry (`agent_proxy/src/worker.mjs`) has never been deployed.
- Leftovers: `agent_proxy/src/scripted.mjs` is no longer imported; `move_validator.gd` keeps an old name for a shape check.

### For the student to decide

Proposals of the evening of November 16 (the counter-first screen and glass repair), built but not reviewed:

- **Whether this is the screen that was meant.** One large window with the patient, and everything else as a thing in the booth. Is anything missing from the booth, in the wrong place, or still too much like a panel? The transcript stays as a unit set into the desk, and the meter and the small hall monitor are always on the wall; only the two papers, the larger hall screen and the guide open on a click.
- **How the papers behave.** Both start a shift on the wall, the sheet's corners blink until it has been down once, a paper stays where it was left from patient to patient, and the intake card comes down by itself for the stamp and for the findings. A night that starts with the sheet already down was not built.
- **Keys**: R sheet, N card, C hall camera, G glass, next to the older ones.
- **The hall camera**: between patients a second press of C, or a click on the larger screen, lets the next patient in; ENTER does it at once.
- **Glass repair**: 40 credits a layer (`rules.json` `attack.repair_cost`; 0 switches repairs off), only between patients, the till may go into debt for it, and no limit but the three layers of the pane. The fitter wipes the pane and leaves the rest of the blood.
- **Words**: the four guide pages (`data/intro.json`), the hints of the wall objects and of the glass key and the fitter's line (constants in `main.gd`), and CALM instead of REASSURE in the hints, after the name printed on the pad.

Proposals of the eleven notes (earlier on November 16), built but not reviewed (each is one number or one text file to change):

- **The house rule**: two crosses (`sheet.json` `threshold`), and whether the card should count the player's crosses at all.
- **Leaving**: eight seconds (`rules.json` `patience.leave_ms`; 0 makes them leave at once), and that CALM during the countdown holds the patient.
- **The line**: 120 an hour (`line.per_hour`), and that an hour under the line costs nothing until closing. A harsher version (a second hour under the line ends the night) was not built.
- **The glass**: three lamps (`attack.glass`), a new pane every shift, the 1.8 s window with blows at 0.54, 0.99 and 1.44 s (`attack.window_ms`, `blow_at`) and 0.65 s with none left (`min_window_ms`).
- **Words and names**: the five opening cards, the guide, the three coach hints and the ending text of THE CUT (`data/intro.json`, `rules.json`, constants in `main.gd`), and the lender's name, Harrow Credit.
- **The cast**: fixed truths and signs with a shuffled order, as the student said is fine for testing. Random combination of signs is not built and is listed as out of scope in the direction document.

Seen earlier, not changed:

- Blood stays until the shift ends (left alone on November 15 at the student's request): blood on the sill and seeping below it, gore on the shutter, and wall and desk stains all stay through the next patients. So do a broken window, a caught splash and dents in the glass, unless a layer of glass is paid for (since the evening of November 16): the fitter's arm wipes the pane and nothing else. `--less-blood` removes the blood, not the broken glass.
- After a listening test: whether the -9 dB attack trim is right (`ATTACK_TRIM_DB`, one number).
- Whether asking, tools, CALM and PRESS should also be allowed while a reply is on its way (they still wait; a live run will show for how long).
- Whether shuffled arrivals should stay (`rules.json` `arrivals.shuffle`).
- Open questions in the direction document: should a typed provocation count as pressure, should the patient speak aloud, how much blood by default.

### Documents behind the runtime

`docs/g1/01`-`04`, `06` and `07` are the submitted G1 versions and were left as submitted: the Configuration document and risk R3 still describe four calls per visit and 2-2.5 s deadlines, and `07` says voice is not implemented. `agent-config.json` was brought up to date on November 15.

## Next three tasks

Before them: run `git status -sb`. The work of November 16 is committed (one commit on top of `90fcc87`, at the student's request). If `main` is ahead of `origin/main`, ask the student whether to push it.

1. **The student plays a shift on the new screen** (`.\run-game.ps1`, with headphones): first whether the counter-first booth is what was meant; then taking the sheet and the card down and hanging them back, the hall camera, the hourly line, a patient left to run out of patience, the marks and `CROSSED n/2`, the timing bar with the glass wearing down, and the GLASS key after a bad stop. Then settle the proposals listed under "For the student to decide" and tune the numbers from what the student felt, not from the tests. An agent operating the window is not a substitute, and neither is the scene test.
2. **Real voice and a live look at the new moments**: the student's own voice through TAB for accuracy, and a short live run so that the thinking pose and the leaving countdown are seen with real latency. A live run is a paid call and needs the student's explicit yes with provider, model, number of calls and cost; the November 15 ledger stays closed. The visual check of the corrected PATIENT SAID row (Codex, November 15) and paste support for the typing line are still open and belong here.
3. **Braintrust replies** (due November 19, 23:59 New York): the student picks two G1 pitches with fewer than two replies; draft specific, moment-based notes in English for review; the student sends them.

## Evidence (local, not in Git)

- `validation/2026-11-16/checks-counter-first/`: the output and standard error of every check of the evening of November 16 on the final tree, with the runner script, the output of the two imports, and the log and report of the boot on the real renderer (`boot-real-renderer.log`, `boot-real-renderer.report.json`).
- `validation/2026-11-16/captures-counter-first-full/`: 180 frames of four scripted shifts on the counter-first screen, drawn on a hidden desktop. The log and the runner's report are beside the folder (`captures-counter-first-full.log`, `.report.json`).
- `validation/2026-11-16/captures-counter-first-attacks-less-blood/`: 89 frames of the attack scenes and the fitter with `--less-blood`, with its `.log` and `.report.json` beside it.
- `validation/2026-11-16/http-integration/`: the mock-provider HTTP run (prompt sizes, request shapes, wire checks; no live reply). The evening's run wrote over the afternoon's.
- `validation/2026-11-16/checkpoint-eleven-notes/`: the working tree as it was between the two rounds (`tracked.patch` against `90fcc87`, and the files that were untracked then under `untracked/`). It is the way back to the three-column build.
- `validation/2026-11-16/checks/`, `captures-full/` (162 frames of three shifts) and `captures-attacks-less-blood/` (79 frames): the afternoon's checkpoint, the three-column screen. Their counts are not results for the current build.
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
