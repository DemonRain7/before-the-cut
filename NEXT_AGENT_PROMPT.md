# Continue Before the Cut

Updated November 16, 2026, evening. Work on main in this repository, the only active checkout;
pull first. The sibling fathom directory is an archive. Do not write there or copy its Git history.

Read AGENTS.md, HANDOFF.md and game/README.md first. The only live run is described in
docs/development/live-model-results-2026-11-15.md.
Communicate in Chinese; write game text, code and documents in English.

Both rounds of work from November 16 are in one commit on top of 90fcc87, made that evening
when the student asked for the working tree changes to be committed (message in English). The
request did not mention a push. Run git status -sb: if main is ahead of origin/main, the
commit is still local and the student has not yet been heard on pushing it, so ask.
validation/2026-11-16/checkpoint-eleven-notes/ (local) holds the tree as it was between the
two rounds.

Latest checkpoint (Claude, November 16, evening): the counter-first screen and paid glass
repair. In the afternoon the student asked, for immersion, to keep only the counter on screen,
as one large view of it with the visitor across it, and to turn everything else into things on
the desk or the walls (papers, for example) that open when clicked: the reference sheet, the
player's own notes, the surveillance camera, the other operations. The student also asked that
the player may pay to repair the counter glass that earlier visitors broke. What was built:
- The screen is the inside of the booth. The counter window takes 440 x 300 of the 640 x 360,
  and the patient is drawn at twice the earlier size.
- Left wall: the reference sheet (click it, or R), the COUNTER GUIDE booklet (H or F1), the
  lender's meter, and the hall camera's monitor (C; between patients a second press, or a
  click on the larger screen, buzzes the next patient in, and ENTER does it at once).
- Right wall: the intake card with a count of unread notes (click it, or N), the house rule,
  and a plate with TREAT, TRAUMA, SHUT and the new GLASS key.
- Desk: LIGHT, GRIP, PORT, the transcript unit with the typing line, ASK, CALM, PRESS.
- A paper is in front of the window only while the player has taken it down. Papers step
  aside for a tool close-up, the card comes down by itself for the stamp and for the findings,
  and nothing is in front once a patient has turned. Until then the papers behave the same
  for every patient.
- Glass: between patients, 40 credits put one layer back (the GLASS key, or G), up to a whole
  pane. The till may go into debt for it, later readings of the meter count it, and the
  report shows it. The number is rules.json attack.repair_cost; 0 switches repairs off.
- The counter guide has four pages: the window, the left wall, the right wall, the desk.

The earlier round of November 16 (the student's eleven notes) is still in force under the new
screen: a patient with no patience left leaves after an eight-second LEAVING bar, with no fee
and no fine; the lender's meter (the invented Harrow Credit) wants 120 more every hour, and
closing under 600 is the ending THE CUT; defence is a timing bar, and each blow before the
shutter costs one of three glass lamps for the shift; the intake card counts the player's own
crosses against the house rule (CROSSED n/2, advice only); there are five skippable opening
cards and three one-time hints; the patient shows a thinking pose while a reply is on its way
and watches the doctor while the microphone is open. HANDOFF.md has both tables and where
each thing lives in the code.

The requests and the notes are the student's. Every layout, key, price, number, name and
sentence above is an assistant proposal. The student has not reviewed or played any of it.
Do not present it as approved or as tuned.

Checks on the evening of November 16 (automated, mock provider, simulated microphone, no paid
call): 719 rule checks, 724 scene checks over six shifts (the same with --less-blood), 5
normal-close checks, 38 proxy tests, 196 HTTP game checks and 15 wire checks, 454 measured
text lines and 29 linted scripts. All passed with exit code 0 and an empty standard error. The
hidden-desktop runner drew 180 frames of four shifts and 89 attack frames with --less-blood,
with zero missed moments and no window on the user's desktop. An assistant looked at about
150 of the 180 frames of a first drawing, fixed three things, drew both sets again and looked
at 45 of the 180 and 27 of the 89. Logs and frames: validation/2026-11-16/ (local, ignored by
Git). The folders checks-counter-first and captures-counter-first-* are the current build;
checks, captures-full and captures-attacks-less-blood are the afternoon's three-column screen.
The scene test presses the shutter within one frame, so it says nothing about human timing.
Nobody has operated this build in a visible window, listened to it, spoken to it or run it
against a live model. Do not claim a playtest, a listening test, a voice test or a live
result for it.

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
the computer usable while screenshots were made, and both rounds of November 16 ran only
headless and through tools/run_hidden.py. Keep working in the background unless the student
says the window may be taken over.

Keep the design: Normal Reference Sheet; optional, unordered observations/tools/questions/
pressure; early decisions; TREAT or Trauma Team; shutter defense. The model writes its own
speech and can evade or lie. The game owns truth and physical results. Keep the offline
comparison. Limits are unchanged: 16 replies/visit, 256 output tokens and the existing
deadlines. Any later limit change must match rules.json and core.mjs. Art and sound come from
tools/art, never from hand edits: on the evening of November 16 the booth, the wall objects,
the wall pads, the glass key and glass_fit.wav were generated there (gen_booth.py is new) and
lamp_glow.png was regenerated. The proxy did not change on November 16.

Next three tasks (first see whether the commit of November 16 still has to be pushed):
1. The student plays a shift with headphones (.\run-game.ps1) on the new screen: first whether
   the counter-first booth is what was meant; then the papers taken down and hung back, the
   hall camera, the hourly line, a patient left to run out of patience, the crossed count,
   the timing bar with the glass wearing down, and the GLASS key after a bad stop. Then settle
   the proposals listed in HANDOFF.md under "For the student to decide" and tune the numbers
   from what the student felt. An agent operating the window, or the scene test, is not a
   substitute.
2. Test the student's real voice through TAB, and look at the new moments with real latency
   (thinking pose, leaving countdown) in a short live run. That run is paid and needs the
   student's explicit yes first. The visual check of the PATIENT SAID row and paste support
   for the typing line are still open.
3. Prepare two Braintrust replies due November 19, 23:59 New York, once pitches are selected;
   draft for student review, never send unasked. G1 is submitted; leave its snapshots,
   slides and narration alone.

Update the handoffs at checkpoints with actual results and remaining work. Commit and push
normally to main when authorized; never force-push, add Co-Authored-By or add AI commit
attribution. Keep .claude/, credentials and local evidence ignored.
