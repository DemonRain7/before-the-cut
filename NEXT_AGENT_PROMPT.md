# Continue Before the Cut

Updated November 19, 2026. Work on main in this repository, the only active checkout;
pull first. The sibling fathom directory is an archive. Do not write there or copy its Git history.

Read AGENTS.md, HANDOFF.md, game/README.md, docs/development/chinese-translation.md and
docs/development/story-and-clarity-2026-11-17.md first. The only live run is described in
docs/development/live-model-results-2026-11-15.md.
Communicate in Chinese; write code and documents in English. The game's own text is bilingual,
English and Chinese: a change to its English is a change to its Chinese in the same commit
(student, November 18; AGENTS.md, Languages).

Git: both rounds of November 16 are in commit 822e8d7. The work of November 17 is in e7f94d7,
made and pushed to origin/main on November 18 when the student asked. The language work of
November 18 is in 3f1fcbd, pushed; the work of late November 18 is in a487cea, pushed. The
data and the code of random signs are in 5b64d87, the model's night signs in 484ff85, every
part's art in 813b9d0, the five new characters in e486887 and the launcher's -TestNight option
in 62a5251, all pushed; Vale's redrawn port close-up is committed after 62a5251, together with
this file. Run git status -sb and git log -3 --oneline:
anything uncommitted is newer than this file.

Latest checkpoint (November 19, afternoon): every character's art for each part (813b9d0)
and five new characters (e486887), built by Claude (Opus 5.5) and checked; nobody has played it. Every
sign a template can draw has its picture (a _t twin with dark threads of every hands layer
where the bust shows the port, a hands layer for each temper gesture, close-ups of both eyes,
the grip and the port with and without threads), and every patient turns with a weapon of
their own. The cast is ten (rules.json roster): Kip, Rook, Vale, Juno and Maren, and Priya Nair
(night-ward nurse; SCAN eye, LANCET hands; a laser), Ozzie Brandt (noodle-cart cook; CHOP hand;
a cleaver), Lux Ferreira (net diver; IRIS and KITE eyes, DIVER temple jack; an arc), Dana
Kirsch (off-duty police sergeant; TALON eye, MIL-SPEC neck plate; a stun baton) and Bo Kowalski
(pit fighter; PISTON fist; a spike). Each night draws five whose fees come to 1,700 to 1,999.
data/nights.json has test nights A to H (C to G new); together they show every character
steady and drifting and every sign, and run_tests.gd fails otherwise (case_db.gd
night_coverage). OPEN, BARELY can now be reached on some nights (test nights D and F); ON
NOTICE never can (two right calls and both drops make 1,750 at most, under 2,000): for the
student to decide. The opening card's made-up KESTREL entry fitted Lux; its clue changed and a
rule test guards it. Vale's port close-up showed a round socket where the binder and Dana's
close-up show a plate; when the student said so, it was redrawn as the same sealed plate in his
own finish (his port is never examined in play). The scene tests play only
nights A and B; the newer five reach the real scene only in the capture's weapon nights (C to
F). Checks, all passed: run_tests 1179; the scene test 1079, 1080 in Chinese, 1079 with less
blood; the window close 5; the proxy 40; over HTTP 199 and 16 wire checks; measure_text 1513
lines in each language; dry captures 439, 439, 334 and 235; the weapon nights drawn on a hidden
desktop, 235 frames, none missed. Mock calls only; nothing paid. run-game.ps1 -TestNight C
plays a test night (a stand-in for Godot and a headless boot checked it; no window was opened).

Previous checkpoint (November 19, early): the data and the code of random signs, then the model's
night signs, built by Claude (Opus 5.5) and checked; nobody has played it. The five characters stay as they are; each night draws
from its seed who of them drift (one to three) and which sign each sheet row shows (two to four
broken rows on a drifting visitor, at least two of them rows the doctor can test whatever the
patient says). cases/<id>.json (version 3) lists each character's normal and broken signs, row
by row, with their notes, looks, readings, answers, reactions, report lines and a sentence for
the model; case_db.gd compose() builds the night's case and checks every sign in its place.
data/nights.json has fixed test nights A (as written), B (the truths turned round) and H
(--test-night=<name>; --authored-order plays A). Rules version 9: Trauma Team's bounty is the
patient's own fee, paid on account at the counter and kept or taken back at closing; the line
is 400 an hour; the visitors' fees come under the line but within one drop of it. Not done yet:
attack art for Kip, Rook and Juno, and dark threads on any port but Vale's (a drifting Kip
attacks as an unchanged portrait; a port with threads looks clean). The model's backgrounds
hold on any night, and every request names tonight's speech and temper signs, whose sentences
the proxy adds for the model (mock calls only). OPEN, BARELY and ON NOTICE are out of reach
with the present five. Checks, all passed: run_tests 1001; the scene test 1001, 1002 in
Chinese, 1001 with less blood; the window close 5; the proxy 40; over HTTP 199 and 16 wire
checks; measure_text 908 lines in each language; dry captures 204, 204, 99 and 99 (run before
the night signs, which changed no drawing).

Earlier checkpoint (November 18, late evening): the student's five requests of that evening,
paraphrased: say whether a call succeeded only at the end, so the player is less sure, and go
over the whole logic for holes; what is 黑丝 (answered in chat: the assistant's shorthand for the
dark threads that spread from a port, 黑色纹路 in the game; the glossary now warns that 黑丝
reads as black stockings); the characters stay as they are, but any part may be abnormal at
random, so every character needs a normal look, an abnormal look for each part and attack art,
the rage attack included, done that way now if it was not (this answers the random-signs
question: build it, with the art); a doctor who is killed ends the night; and five more
characters with all their assets. Built by Claude (Opus 5.5) and checked:
- Right or wrong is told only at closing. The slip says what the counter did (TREATED, HANDED
  OVER, SHUTTER HELD, SHUTTER DOWN, WALKED OUT or OUT OF PATIENCE; rules.json counter,
  version 8), the money AT THE COUNTER and "Right or wrong: at closing." Only fees for work
  done, drops, CALM and glass change hands at the counter; every bounty, bill and fine comes
  at closing, the bill for treating a drifting patient taking the fee back too, so each
  outcome's total is unchanged. The intake card keeps only the doctor's own marks; the meter's
  lamps show what was done, not whether it was right; a needless shutter is quiet; the slip's
  sound follows the counter money; the crew says the same lines on every call; Maren's and
  Vale's lines that gave their truth away were rewritten; the till and the hourly readings
  count the counter money until the last reading, at closing. The report has a page for each
  visit (the call, the truth, RIGHT CALL, WRONG CALL or NO CALL, the findings beside the
  doctor's marks, the money at the counter, at closing and in all), then the totals; a click
  or ENTER turns the page, BACKSPACE goes back, ESC goes to the totals. RIGHT THE HARD WAY
  was removed. Left on purpose: a patient who turns on a call shows they were drifting (only
  Vale does), a quiet hand-over proves nothing (Maren drifts but goes quietly), and the
  readings during the night can mislead.
- A blow that lands ends the night: the screen goes dark, no slip prints, nobody else is
  buzzed in, and the report comes up under LIGHTS OUT with the visitors still in the hall
  named as never seen; the hour is not read, the meter stays at that hour and no line is held.
  The event log records lights_out.
Not built then: random signs with the per-part art, and the five new characters.

Earlier checkpoint (November 18, evening): the student's requests of that day, built by Claude
(Opus 5.5). After the November 17 build was pushed and opened for them in a window, the student
sent a screenshot of the third opening card (THE LANTERNS) and asked, paraphrased: what the
card and "chrome" mean; a language option on the title screen, Chinese first, with everything
translated, and a change on one side always made on the other; an opening redrawn for the new
story; and reference sheets that differ from patient to patient, with a reason in the story
(implant models), organized by model and body part rather than by character, so that a
character is a set of parts and the cast is easier to extend. They answered three questions:
download Fusion Pixel Font for the glyphs; keep the patients' names and the contacts' code
names in English and translate companies, gangs and the rest; and, for the Chinese title,
"think of a more reasonable and interesting one". What was built:
- The language. English | 中文 in the title card's top-right corner, kept in
  user://settings.cfg and changed only there. scripts/core/lang.gd translates each shown line
  where it is drawn, from catalogs in game/data/lang/zh/ (about 720 lines in 12 catalogs)
  keyed by the exact English; the rules, the data and the event log stay English. Ten pictures
  with painted words have _zh twins (their words in tools/art/words.py), and the sign reads
  先别下刀 ("don't cut yet") over a small BEFORE THE CUT, as does the window's title. Names,
  code names, the binder's model names and the key names stay English. The glyphs are
  Fusion Pixel Font's 10-pixel cut (OFL 1.1), built into assets/fonts/zh.fnt, the fallback of
  every Counter Sans font. The input method is on only while the typing line is open in
  Chinese. Chinese is typed out and held at half the English rate per character.
- The patients answer in the player's language: the request names it, the proxy refuses an
  unknown one before any call, asks for Chinese with names and code names in Latin letters,
  holds Chinese to 55 characters a line and 110 a reply (rules.json agent.languages and
  core.mjs DEFAULT_LIMITS.languages, together) and passes the language on to transcription.
  The offline patient's lines are in the case catalogs, and it listens for the Chinese words
  of lang/zh/topics.json too.
- The opening's pictures were redrawn: FIRED in three panels, the debt file stamped SOLD TO
  HARROW, the Lanterns' CONTACT and PACKAGE tags, a crate of filed-off military surplus and a
  visitor whose eye implant glitches; the cards' words were rewritten (intro.json version 5).
  The words that teach the rules say implant where they said chrome; chrome is left as slang
  around Juno.
- The spec binder (game/data/parts.json): the factory normal of each implant model, by slot
  (eyes NATURAL, KITE, IRIS, TALON; hands NATURAL 1.0 s, LOADER 1.5, SEAM 0.8, DEFT 0.5,
  REFLEX 0.3; ports STREET, WORK, MIL-SPEC; voices NATURAL, VX-9). Each case's parts name a
  model per slot, and case_db.gd sheet_for() builds the sheet for the patient at the counter;
  between patients the sheet is the baseline body. The close-ups name the model, and the
  grip's LIMIT is the hands model's (rules.json version 7 has no grip.limit_ms). Rook's
  release moved to 1.2 s and Vale's to 0.2 s so that each keeps its verdict against its own
  model; no case's truth or row's verdict changed. case_db.gd refuses data that wears a model
  the binder lacks or whose verdicts disagree with the models.
- Three checks keep the languages in step: python tools/check_lang.py, measure_text.py
  --lang zh in tools/art, and the scene test with -- --lang=zh, which fails on any English
  that reaches the Chinese screen.
In the November 17 checkpoint below, the IMPLANT readout and rules.json grip.limit_ms are
superseded: the penlight readout names each eye's model (NO PUPIL for an eye without one),
and the grip's limit is the hands model's.

Earlier checkpoint (November 17, evening): the student's five notes. They were first given to
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

The notes and requests are the student's. Every layout, key, price, number, name, model,
picture, translation and sentence above is an assistant proposal. The student has not reviewed
or played any of it, and no person has read the Chinese. Do not present it as approved, tuned
or reviewed.

Checks late on November 18, on the final tree (automated, mock provider, simulated microphone,
no paid call): 970 rule checks, 1001 scene checks over nine shifts (1002 in Chinese, 1001 with
--less-blood), 5 normal-close checks, 39 proxy tests, 199 HTTP game checks and 15 wire checks
(in English), the translation check with 0 problems, 682 measured text lines in each language
and 31 linted scripts. All passed with exit code 0. The first HTTP run failed one check: Vale's
blow landed there, which now ends the night with no slip; the check now drops the shutter in
time. Drawn on a hidden desktop: 204 frames of five shifts in English and 204 in Chinese, and 99 attack frames with less blood, 0 moments missed in each; the main scene booted on the real renderer. Claude looked at some of the frames (the report's pages, the two nights that end in the dark, slips in both languages, two attack frames with less blood); no person has. Logs and frames:
validation/2026-11-18/checks-closing/ and the captures-closing-* folders (local, ignored by
Git). The counts of the earlier checkpoints are not results for this build. The scene test cues snaps and
flares and presses the shutter within one frame, so it says nothing about human timing.
Nobody has operated this build in a visible window, read its Chinese in play, typed with a
real input method, listened to it, spoken to it or run it against a live model, in either
language. Do not claim a playtest, a listening test, a voice test, a translation review or a
live result for it.

Known engine problem: Godot 4.7.2's headless import from an empty cache is not reliable. In 20
tries each on November 17 it crashed (0xC0000005) twice on that day's tree and once on 822e8d7,
and twice more on that tree it printed engine errors without crashing; in that day's final
check run it crashed while writing the fonts and left the copy's checks failing. A second
import mended that copy, the one crash it was tried on. On November 18 the one import of a copy
with no cache was clean and the copy passed its checks, which says little about a crash that
came twice in twenty tries.
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
the computer usable while screenshots were made, and the rounds of November 16, 17 and 18 ran
only headless and through tools/run_hidden.py. On November 18 the November 17 build was started
in a visible window because the student asked to look at it (run-game.ps1; exit code 0 when
they closed it). Keep working in the background unless the student says the window may be
taken over.

Keep the design: Normal Reference Sheet; optional, unordered observations/tools/questions/
pressure; early decisions; TREAT or Trauma Team; shutter defense. The training only points
and never forces an order. The model writes its own speech and can evade or lie. The game owns
truth, physical results, codes and drops. Keep the offline comparison. Limits are unchanged:
16 replies/visit, 256 output tokens and the existing deadlines; Chinese has its own pair (55
characters a line, 110 a reply) in both places. Any later limit change must match rules.json
and core.mjs. Art and sound come from tools/art, never from hand edits: on November 17
gen_booth.py redrew clinic/booth.png without the HOUSE RULE sign and wrote ui/obj_list.png, and
gen_clinic.py wrote clinic/list.png; no sound was added. On November 18 every generator that
paints words writes the English picture and its _zh twin together from tools/art/words.py,
gen_font.py builds assets/fonts/zh.fnt from the cut in tools/art/fonts/ (font_zh.py reads it;
extract_zh_font.py records how it was cut from the downloaded release, and a downloaded file is
read only with python -I), and no English picture or sound changed. Commit each .import and
.uid file with its asset. The proxy did not change on November 16 or 17; on November 18 it
gained the language field, the Chinese limits, the Chinese prompt and the transcription
language.

Random signs, answered late on November 18: build them, with the art, now. The data, the code
and the model's night signs are built (November 19, above); the art is not. What was built
differs from the proposal of that afternoon in three ways: the signs live in each character's
file (cases/<id>.json, version 3) rather than in a sign library keyed by slot and model; a
steady visitor shows only normal signs (no decoys yet); and the money changed (rules version 9)
because drawn truths broke the old line. HANDOFF.md, Student decisions, November 18, items 2
and 4, has the proposal and the answer.

Next three tasks (first run git status -sb and git log -3 --oneline):
1. Prepare two Braintrust replies due today, November 19, 23:59 New York (the soonest deadline), once
   the student has picked two G1 pitches with fewer than two replies: specific, moment-based
   notes in English for the student's review, never sent unasked. G1 is submitted; leave its
   snapshots, slides and narration alone.
2. The student plays and reads (.\run-game.ps1, with headphones): a drawn night in Chinese from
   a fresh start and a night in English, reading every card, tip, sheet, slip and report page
   and typing with a real Chinese input method; then the test nights with the newer five
   (.\run-game.ps1 -TestNight C, and D to G likewise); then settles the proposals in
   HANDOFF.md under "For the student to decide" (ON NOTICE, and the five themselves). An agent
   operating the window, or the scene test, is not a substitute.
3. Small fixes from that play, and a scene test for a drifting newer patient (a test night of
   C to G) if the student wants one; English and Chinese together.
After these: a short live run in both languages (the model's Chinese inside 55 and 110
characters, the night's signs and the newer five's voices, the student's real voice through TAB
in both languages, the new moments with real latency), which is paid and needs the student's explicit yes first; a code is never passed to
the model, so the patient AI does not know one was said. Then the visual check of the PATIENT
SAID row, paste support for the typing line, and the fresh-import crash (another Godot version
on a copy, or an upstream report with the logs; a public report is a post and needs the
student's yes).

Update the handoffs at checkpoints with actual results and remaining work. Commit and push
normally to main when authorized; never force-push, add Co-Authored-By or add AI commit
attribution. Keep .claude/, credentials and local evidence ignored.
