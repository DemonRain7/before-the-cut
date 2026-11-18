# Continue Before the Cut

Updated November 18, 2026. Work on main in this repository, the only active checkout;
pull first. The sibling fathom directory is an archive. Do not write there or copy its Git history.

Read AGENTS.md, HANDOFF.md, game/README.md and
docs/development/story-and-clarity-2026-11-17.md first. The only live run is described in
docs/development/live-model-results-2026-11-15.md.
Communicate in Chinese; write game text, code and documents in English.

Git: both rounds of November 16 are in commit 822e8d7. The work of November 17 is in the commit
after it, made on November 18 when the student asked for it to be pushed, and is on origin/main.
Run git status -sb and git log -3 --oneline; anything uncommitted is newer than this file.

Latest checkpoint (November 17, evening): the student's five notes. They were first given to
Claude (Fable), whose quota ran out partway; Claude (Opus 5.5) took over in the same working
tree and finished them. The notes, paraphrased: pass and fail were unclear, with nothing
pointing at the reference sheet (how long is a reasonable grip?); CALM should go, or cost
money; the grip and the eye test were confusing, so the opening should walk the player through
everything once; a patient may suddenly rage and lunge in the middle of any action; and a new
story: a doctor fired by a megacorp and in debt, working a gang's street implant clinic,
contacts who trade codes and smuggle military or high-end implants, illegally chromed
cyberpsychos, a daily contact list to cross-reference the visitors, a different code for each
contact, a wrong code costing patience, and the whole smooth and airtight. What was built:
- Readouts. Every close-up shows a SHEET line with what the sheet calls steady for that tool.
  The penlight prints each eye's result (RIGHT EYE / LEFT EYE; TIGHTENS, STAYS WIDE or
  IMPLANT; FOLLOWS or DOESN'T FOLLOW). The grip runs on a two-second scale with LIMIT 1s
  marked (rules.json grip.limit_ms) and turns red past it. The readouts say what happened,
  never steady or drifting.
- CALM costs 30 credits a use (rules.json reassure.cost; 0 makes it free), still twice a
  visit and +1 patience. The pad shows the price, the slip prints CALM -30, and the till may
  go below zero for it.
- A first-night training (scripts/ui/coach.gd, 14 tips in data/intro.json) replaces the guide
  that opened by itself: one tip at a time with a pulsing frame round its subject, NEXT and
  SKIP ALL [K]. It never blocks and never sets an order, and it ends when the second visitor
  is buzzed in. --no-training brings back the guide that opens by itself.
- Snaps and flares. A drifting patient may snap during any action, more likely the longer the
  exam runs (three free actions, then 8, 16, 24 and at most 30 per cent an action): an open
  close-up is torn away, the patient surges at the glass, and the ordinary attack follows
  0.35 s later. Anyone may flare once a visit (10 per cent an action after the first): a
  shout and a hand slammed on the glass, TEMPER evidence only, never an attack, and a shutter
  on it is a false alarm. Neither happens on the training visit. --no-surprises switches both
  off.
- The story. Six opening cards: fired by Kessler, in debt to Harrow Credit, working the
  Lanterns' back-street counter. Two of each night's five visitors are contacts. Tonight's
  list (left wall, or L; it shares the sheet's hook) gives each an alias, two clues and a code
  line. Clues use only the intake card and the eyes; each alone fits at least two visitors and
  both together exactly one, which case_db.gd validate_contacts() checks when the data loads.
  SAY on the list speaks a code: the right contact hands over a package for +300, and anyone
  else loses 1 patience. Codes are game-owned: no model call, nothing in the patient's memory.
- The lender's line rose to 240 an hour (1,200 at closing), so five right calls (1,140) need a
  drop to hold it. The COUNTER GUIDE booklet took the HOUSE RULE sign's place on the right
  wall, and the booth was redrawn without the sign.
- run-game.ps1 checks Godot's import cache before it starts the game and imports when files
  are missing (up to three tries; -ImportOnly does only that). Before this, a fresh clone
  started the game with no pictures, fonts or sounds.

The rounds of November 16 are still in force under the new story. The screen is the inside of
the booth: a 440 x 300 counter window with the patient drawn at twice the earlier size; on the
left wall the sheet and the list on one hook (R, L), the lender's meter and the hall camera's
monitor (C; between patients a second press, or a click on the larger screen, buzzes the next
patient in, and ENTER does it at once); on the right wall the intake card (N), the COUNTER
GUIDE booklet (H or F1) and a plate with TREAT, TRAUMA, SHUT and GLASS; on the desk LIGHT,
GRIP, PORT, the transcript unit with the typing line, ASK, CALM and PRESS. A paper is in front
of the window only while the player has it down. Between patients 40 credits put one layer of
glass back (G), up to a whole pane. A patient with no patience left leaves after an
eight-second LEAVING bar, with no fee and no fine. Defence is a timing bar, and each blow
before the shutter costs one of three glass lamps for the shift. The intake card counts the
player's own crosses against the house rule (CROSSED n/2, advice only). The patient shows a
thinking pose while a reply is on its way and watches the doctor while the microphone is
open. HANDOFF.md has every table and where each thing lives in the code.

The notes and requests are the student's. Every layout, key, price, number, name and sentence
above is an assistant proposal. The student has not reviewed or played any of it. Do not
present it as approved or as tuned.

Checks on the evening of November 17 (automated, mock provider, simulated microphone, no paid
call): 820 rule checks, 940 scene checks over nine shifts (the same with --less-blood), 5
normal-close checks, 38 proxy tests, 196 HTTP game checks and 15 wire checks, 514 measured
text lines and 30 linted scripts. All passed with exit code 0 and an empty standard error. The
hidden-desktop runner drew 196 frames of four shifts and 91 attack frames with --less-blood,
with zero missed moments and no window on the user's desktop, and the main scene booted there
on the real renderer. Claude looked at about 60 frames of a first drawing (two changes
followed) and, in the final drawing, at the frames those changes touched, the other new words
and 16 of the 91 less-blood frames; no person has. Logs and frames: validation/2026-11-17/
(local, ignored by Git). The counts of November 16 are not results for this build. The scene
test cues snaps and flares and presses the shutter within one frame, so it says nothing about
human timing. Nobody has operated this build in a visible window, listened to it, spoken to it
or run it against a live model. Do not claim a playtest, a listening test, a voice test or a
live result for it.

Known engine problem: Godot 4.7.2's headless import from an empty cache is not reliable. In 20
tries each it crashed (0xC0000005) twice on this tree and once on 822e8d7, and twice more on
this tree it printed engine errors without crashing; in the final check run it crashed while
writing the fonts and left the copy's checks failing. A second import mended that copy, the one
crash it was tried on.
Before you trust checks on a fresh copy, import it with .\run-game.ps1 -ImportOnly (or import
twice). The cause is not known. Evidence: validation/2026-11-17/fresh-import-repeats/ and
validation/2026-11-17/launcher-test/.

The first authorized OpenAI test (Codex, November 15) is complete and predates these changes:
- 30 live patient requests: gpt-6-luna, reasoning none. Median/p90/max 1.32/1.84/2.54 s.
- 10 real transcriptions of Windows-synthesized English: gpt-4o-mini-transcribe.
  Median/p90/max 0.66/1.27/1.33 s; 0 word errors across 80 reference words.
- All requests succeeded. Published-token-price estimate USD 0.0040677; not an invoice.
- Codex played two real-window visits with 12 replies and zero game fallbacks; 18 other replies
  were HTTP probes. 29 replies were inspected, one remains unscored. No human played or listened.
- The game input field rejected the automatic paste-based text entry, so free dialogue and STT
  were tested through HTTP. This is not verification of the live microphone-to-game path.
- A defect found in that run was fixed: the clipboard now shows what a generated patient
  actually said, under a neutral PATIENT SAID. Nobody has looked at that row in a window yet.

The student authorized up to USD 50 and explicitly revoked the manual-only credential rule.
The assistant configured agent_proxy/.dev.vars. Do not open, print, search or copy it; Node
loads it normally. After testing, the student explicitly chose to retain the key in the
Git-ignored file for future game runs. Keep it configured; do not reproduce or commit it.
The paid proxy is stopped. The completed ledger in validation/2026-11-15/codex-live-test is
stopped at 30 dialogue / 10 clips; do not reset it or silently start another paid run. A new
paid run needs the student's own yes to the provider, the model, the number of calls and the cost.

The student's recording is finished, so the window, mouse, keyboard, sound and microphone may
be used for testing. The student's last word on the screen itself (November 15) was to keep
the computer usable while screenshots were made, and the rounds of November 16 and 17 ran only
headless and through tools/run_hidden.py. Keep working in the background unless the student
says the window may be taken over.

Keep the design: Normal Reference Sheet; optional, unordered observations/tools/questions/
pressure; early decisions; TREAT or Trauma Team; shutter defense. The training only points
and never forces an order. The model writes its own speech and can evade or lie. The game owns
truth, physical results, codes and drops. Keep the offline comparison. Limits are unchanged:
16 replies/visit, 256 output tokens and the existing deadlines. Any later limit change must
match rules.json and core.mjs. Art and sound come from tools/art, never from hand edits: on
November 17 gen_booth.py redrew clinic/booth.png without the HOUSE RULE sign and wrote
ui/obj_list.png, and gen_clinic.py wrote clinic/list.png; no sound was added. Commit each
.import and .uid file with its asset. The proxy did not change on November 16 or 17.

Next three tasks (first run git status -sb; the work of November 17 is committed and pushed):
1. The student plays a first night from a fresh start with headphones (.\run-game.ps1): the
   training from start to end, the eye test and the grip with their readouts and LIMIT 1s,
   the list and its clues, a right code and a wrong one, CALM at its price, a long exam of a
   drifting patient (a snap) and a flare; then a second night without the training, to see
   whether 240 an hour feels fair. Then settle the proposals listed in HANDOFF.md under "For
   the student to decide" and tune the numbers from what the student felt. The questions of
   November 16 (the booth, the papers, the glass) are still open and belong to the same
   session. An agent operating the window, or the scene test, is not a substitute.
2. Test the student's real voice through TAB, and look at the new moments with real latency
   in a short live run. That run is paid and needs the student's explicit yes first. A code is
   never passed to the model, so the patient AI does not know one was said. The visual check
   of the PATIENT SAID row and paste support for the typing line are still open.
3. Prepare two Braintrust replies due November 19, 23:59 New York, once pitches are selected;
   draft for student review, never send unasked. G1 is submitted; leave its snapshots,
   slides and narration alone.
After these: the fresh-import crash. Try another Godot version on a copy, or report it
upstream with the logs; a public report is a post and needs the student's yes.

Update the handoffs at checkpoints with actual results and remaining work. Commit and push
normally to main when authorized; never force-push, add Co-Authored-By or add AI commit
attribution. Keep .claude/, credentials and local evidence ignored.
