# Before the Cut: handoff

Updated **November 19, 2026**, after the data and the code of random signs (first section): each night now draws which of the five characters drift and which sign each of their parts shows, with fixed test nights besides, and the patient model is told the night's speech and temper signs. Every character's art for each part and the five new characters are the next steps. Late on November 18: right or wrong told only at closing, and a night that ends when the doctor is killed. Earlier on November 18: a language option with the whole game in Chinese, the opening redrawn for the new story, and reference sheets that follow each patient's implant models. Communicate with the student in Chinese; write game text, code comments and project files in English. The game itself is bilingual, and a change to its English is a change to its Chinese in the same commit (student, November 18; `AGENTS.md`, Languages).

**This repository is the only active checkout.** On November 15 the game, the patient-AI proxy and the tools were moved here from the legacy `fathom` workspace and checked here ([transition record](docs/development/repository-transition.md)). `fathom` is an archive; its long layered handoffs (`HANDOFF.md`, `CODEX_RUNTIME_HANDOFF.md`, `CLAUDE_VOICE_HANDOFF.md`, `CODEX_NEXT_HANDOFF.md`) are history, not instructions.

AI use: Claude wrote the earlier runtime history; Codex added the live-test results and speech-feedback correction of November 15; Claude built the answers to the student's eleven notes, the counter-first screen and the paid glass repair on November 16. On November 17 Claude (Fable) began the answers to the student's five notes and stopped partway when its quota ran out; Claude (Opus 5.5) took over in the same working tree, finished the design, the code, the tests and the captures, and wrote the November 17 parts of this file. The split between the two is not recorded file by file. On November 18 Claude (Opus 5.5) built the answers to that day's requests (the language switch and the Chinese translation, the redrawn opening, the spec binder) and wrote the November 18 parts of this file; the translation is Claude's and no person has reviewed it. Late that evening Claude (Opus 5.5) built the first two of the student's five requests of that evening (right or wrong at closing; a night that ends with the doctor) and wrote that checkpoint. On November 19 Claude (Opus 5.5) built the data and the code of random signs and the model's night signs, and wrote the first section. No student review of these updates is recorded.

**Git.** Both rounds of November 16 are in commit `822e8d7`. The work of November 17 is in commit `e7f94d7`, made and pushed to `origin/main` on November 18 when the student asked. The language work of November 18 is in commit `3f1fcbd`, pushed to `origin/main`. The work of late November 18 (right or wrong at closing, lights out) is in commit `a487cea`, pushed. The data and the code of random signs are in commit `5b64d87`, pushed. The model's night signs (first section) are committed after it, together with this file. Run `git status -sb` and `git log -3 --oneline` to see where it stands now.

## Current checkpoint: random signs, the data and the code (November 19)

On November 19 Claude (Opus 5.5) built and checked the data and the code of the student's request 3 of late November 18: the characters stay as they are, and any of their parts may be the abnormal one. Later that day it gave the patient model the night's speech and temper signs (the row "The model's night" below). Its art and the five new characters (request 5) come next (Next three tasks). **Nobody has played this version**, and every number, sign and sentence below is an assistant proposal that the student has not reviewed.

| What | What the build does now |
|---|---|
| A drawn night | The five characters stay as they are (`rules.json` `roster`, version 9). Who of them drifts, and which sign each of the five sheet rows (eyes, hands, port, speech, temper) shows, is drawn from the shift seed (`shift_state.gd` `draw_night`; `rules.json` `night`), so one seed always gives the same night. One to three visitors drift, each with two to four broken rows, at least two of them (`sheet.json` `threshold`) rows the doctor can test whatever the patient says (`case_db.gd` `reachable_rows`). Every other row shows the character's normal sign (a template may list several, and the night then draws one). The first night of a session opens with a steady visitor who is on the contact list, and the contacts' clues must still pick out exactly one visitor each (`case_db.gd` `fair_contacts`). |
| Characters as templates | `cases/<id>.json` (version 3) lists each character's normal and broken signs row by row: the card's note and the look; the readings (the eyes' follow and tighten, the grip's release time and tremor, the port's dark threads); the answers to the three questions; the reaction to a press and the flare; the line on the report; and a sentence for the model. It also has the outcomes for either truth. `case_db.gd` `compose()` builds the night's case from a pick (`{truth, signs}`), and the template check puts every sign in its place (`check_picks()`). |
| Test nights | `data/nights.json` has three fixed nights. A is the night as written before (Vale and Maren drifting). B turns the truths round (Kip, Juno and Rook drifting). H has three drifting visitors with few signs each. Together they show every sign of Kip, Juno and Vale. Rook's broken eyes and temper and Maren's dark threads wait for the nights with the new visitors. `--test-night=<name>` plays one, `--authored-order` plays A, and tests and captures build A when they name no night. |
| The money (rules version 9) | With the visitors and truths drawn, the old money no longer held: a night with one drifting visitor held the line without a drop, and a night with three fell far short. Version 9 changes four things. Trauma Team's bounty is now the patient's own fee (`scoring.refer_drifting` adds 0), so a night of right calls brings in exactly the night's fees, whoever drifted. The line is 400 an hour (2000 a night). The visitors are drawn so that their fees come under the line but within one drop (300) of it (`night.fees_under_line`). Trauma Team pays the fee on account at the counter when it takes somebody. At closing its report keeps the fee as the bounty, or for a steady patient takes it back and bills the call-out (-150 in all, as before). So a treat and a call read the same all night, and the counter still says nothing about right or wrong. Night A's fees are 1900. The meter's readings before the last count the counter money; the last, at closing, counts everything. A repair counts from the hour after it, and no reading is taken in the hour the doctor died. |
| Texts that fit | `measure_text.py` measures every sign of every row (908 lines in each language). 33 sign texts did not fit one line of the card's record (186 px) and were shortened in both languages. `gd_static_check.py` now reads a function signature that runs over several lines. |
| The model's night | The backgrounds in `agent_proxy/src/character_profiles.mjs` now hold on any night: nothing in them says that a patient drifts. Every request names tonight's speech and temper signs (`patient_agent.gd` `model_signs()`, `signs` in the payload; protocol 3 unchanged, since the game and the proxy ship from this repository together). The proxy refuses a request whose signs are missing, name another row or are not this patient's (`400 bad_request`, message `signs`), and adds each sign's sentence for the model from the case file (`Tonight: ...`). So a steady Maren is told that her hands are her own, and a drifting one that they finish jobs she does not remember starting. Maren's case brief now says that her hands twitch after she stops, not that they keep working. The eyes, the grip and the port are the game's readings and are not sent. Only mock calls have been made. |

Found and not fixed yet:

- **The art does not follow the signs yet** (step 2 of Next three tasks).
  - A drifting Kip, Rook or Juno has no attack drawing. This happens on nights B and H and on drawn nights: the portrait stays at the counter while the attack's sounds play and the glass breaks.
  - No portrait has a twin with dark threads (`<layer>_t`), and only Vale, whose port cannot be reached, has a dark-threads close-up. So when a night gives Kip, Rook, Juno or Maren threads at the port, the close-up and the portrait show a clean port while the card's note and the report say threads.
- **Titles.** At 400 an hour the line needs most of the night's fees: night A holds it only with four or more right calls and a drop.
  - OPEN, BARELY (three right calls) needs a drawn night with dearer visitors than the present five.
  - ON NOTICE (the line held with fewer right calls) cannot happen on a five-visitor night.
  - `max_injuries` no longer matters, because a hit ends the night.

  Left as they are, for the student to decide.

Checks on the final working tree, November 19, after the model's night signs (logs in `validation/2026-11-19/checks-night-signs/` and `http-integration/`; the run on the tree of `5b64d87` is in `checks/`; none of it is in the repository):

| Check | Result |
|---|---|
| `run_tests.gd` | 1001 passed, 0 failed (970 before the first section, 996 on `5b64d87`; new: the templates and the composer, the draw over seeded nights, the test nights, the money of version 9, and the signs a request names, never the truth) |
| `run_ui_smoke.gd`, in English, in Chinese, with less blood | 1001, 1002 and 1001 passed, 0 failed. The first six shifts play night A with the old numbers pinned (120 an hour, CALM free, no contacts); shift 7 on plays the rules as they are |
| `run_close_check.gd`, last and alone | 5 passed, 0 failed, no leak line |
| `npm test` in `agent_proxy` | 40 passed, 0 failed (39 on `5b64d87`; new: the signs a request must name, and a normal night hears no broken sentence) |
| `tools/run_proxy_integration.mjs` | 199 passed, 0 failed; wire checks 16 passed, 0 failed (new: every request named tonight's speech and temper signs, and the model heard them) |
| `capture_shift.gd` dry runs | 204, 204 in Chinese, 99 attacks only, 99 attacks only with less blood; 0 missed. Run on `5b64d87`, not again after the night signs, which changed no drawing |
| `check_lang.py`, `measure_text.py` in both languages, `gd_static_check.py` | 0 problems; 908 lines, 0 problems in each; 31 scripts, no findings |

These are automated checks with the dummy audio driver and the mock.

## Earlier checkpoint of late November 18: right or wrong at closing, and a night that ends with the doctor

Late on November 18, after the language work had been pushed (`3f1fcbd`), the student sent five requests in one message, paraphrased from Chinese:

1. Say whether a call succeeded only at the end, so that the player is less sure of it; and go over the whole logic again for holes.
2. What is 黑丝? Stockings?
3. The characters stay as they are, but for randomness any part may be abnormal: every character needs its normal look and an abnormal look for each part, and the attack art, the rage attack included. "If it was not done that way, do it that way now."
4. If the doctor is killed, the night should end there: how can it go on?
5. Go on and design more characters, five more, with all their assets.

Request 3 answers the random-signs question that had waited since earlier that day (Student decisions, November 18, item 2): build it, with the art. Requests 1, 2 and 4 are built and checked here; 3 and 5 are the next steps (Next three tasks).

**Nobody has played this version.** The requests are the student's. The slip's words, the report's pages, the lamps' colours, the title LIGHTS OUT and its text, and every new sentence are assistant proposals that the student has not reviewed. [game/README.md](game/README.md) has the rules as a player meets them (Decisions and money; The lender's line; A blow that lands ends the night).

| Request | What the build does now |
|---|---|
| 1 | **Right or wrong is told only at closing.** The slip says what the counter did, never whether it was right: TREATED, HANDED OVER, SHUTTER HELD, SHUTTER DOWN, WALKED OUT or OUT OF PATIENCE (`rules.json` `counter`, version 8), a line that holds whoever the patient was, the money AT THE COUNTER, a drop, a missed drop or CALM, and "Right or wrong: at closing." Only fees for work done, drops, CALM and glass change hands at the counter: a treated patient pays the fee whatever their truth, and every bounty, bill and fine comes at closing, the bill for treating a drifting patient taking the fee back as well (-(fee + 400)), so each outcome's total is as before. The intake card keeps only the doctor's own marks; the meter's lamps show what was done (green TREAT, amber Trauma Team, blue shutter, red a patient through, dark nothing), not whether it was right; a shutter on a patient who did not turn falls quiet; the slip's sound follows only the counter money; the crew says the same lines on every call; Maren's and Vale's lines that gave their truth away were rewritten; the till and the hourly readings count only the counter money until the last reading, which is taken at closing. The report has a page for each visit seen (the call, the truth, RIGHT CALL, WRONG CALL or NO CALL, what became of them, the five findings beside the doctor's marks, and the money at the counter, at closing and in all), then the totals (both columns, the till, the lamps, the title). It opens on the first visit; a click, ENTER, SPACE or RIGHT turns the page, BACKSPACE or LEFT goes back, ESC or a right-click goes to the totals, and the till's jingle plays on the totals. The title RIGHT THE HARD WAY, a night of right calls that still hurt you, can no longer happen and was removed. |
| 2 | Answered in chat: 黑丝 was the assistant's shorthand in chat for "dark threads", the dark lines spreading out from a port that are a sign of drift; the game's Chinese says 黑色纹路. The glossary now says so and warns against 黑丝, which reads as black stockings. |
| 4 | **A blow that lands ends the night.** After it the screen goes dark: no slip prints, nobody else is buzzed in, and the report comes up out of the dark under LIGHTS OUT (熄灯): "Nobody reads the meter tonight. Harrow Credit takes the clinic back." The visitors still in the hall are listed on the totals as never seen (没等到接诊), the hour is not read, the meter on the wall stays at that hour, and no line is held. The -300 is billed at closing like every other outcome, and the event log records `lights_out` (case, hour, who was unseen). |

The logic review of request 1 left three things as they are, on purpose. A patient who turns on a call shows by turning that they were drifting (only Vale does, on a call to Trauma Team); that is the nature of the attack, not a leak. A quiet hand-over proves nothing: Maren drifts but goes with the crew without a fight. And the readings during the night can mislead: a night of treatments reads well at the counter and may still close under the line when the bills come in (the scene test's eighth shift reads 900 at the fourth hour and closes at 620, THE CUT). Holes found and closed besides the slip: the findings on the intake card, the lamps' ticks and crosses, the bounty plate and the cash sound on a needless shutter, the till and readings that counted bills during the night, the jingle on every page, the crew's lines, and three case lines.

What changed in the repository:

- Modified, besides this file, `NEXT_AGENT_PROMPT.md` and `game/README.md`: `docs/development/chinese-translation.md` (the glossary); in `game/data/` `cases/maren.json`, `cases/vale.json`, `intro.json` (version 6) and `rules.json` (version 8), and in `game/data/lang/zh/` `cases/maren.json`, `cases/vale.json`, `intro.json`, `rules.json` and `ui.json`; in `game/scripts/core/` `shift_state.gd` and `visit_state.gd`; in `game/scripts/ui/` `clinic_view.gd`, `clipboard.gd`, `main.gd` and `screens.gd`; in `game/tests/` `capture_shift.gd`, `play_driver.gd`, `run_proxy_integration.gd`, `run_tests.gd` and `run_ui_smoke.gd`; `tools/art/measure_text.py` and `tools/check_lang.py`.
- Not changed: every picture and every sound, the proxy, every limit, the cases' truths and signs, every number in `rules.json`, the G1 documents, slides and narration. The version string is still 0.3.0.

Results on the late evening of November 18, on the final working tree (logs in the local `validation/2026-11-18/checks-closing/`; commands under "Results in this checkout"):

- **970 rule checks**, **1001 scene checks** over nine shifts (**1002 in Chinese**, 1001 with `--less-blood`), **5 normal-close checks**, **39 proxy tests**, and over HTTP with the mock provider and a simulated microphone **199 game checks and 15 wire checks**: all passed, each with exit code 0. The first HTTP run failed one check of 196: in it Vale turns on a call to Trauma Team and his blow landed, which now ends the night with no slip; the check now drops the shutter in time and looks for the slip (three checks more), and the rule and scene checks and the window close were run again after that change, with the commands exactly as the README gives them.
- The translation check: 0 problems. Text measurement: 682 lines, 0 problems, in English and in Chinese (none left in English). Lint: 31 scripts, no findings. Capture script, dry: 204 frames named in English and 204 in Chinese, 99 with `--attacks-only` and 99 with `--attacks-only --less-blood`, 0 moments missed.
- **Drawn on a hidden desktop** by `tools/run_hidden.py`: the English closing capture, 204 frames of five shifts (`validation/2026-11-18/captures-closing-en/`, exit 0 in 197 s), the same in Chinese (204 frames, `captures-closing-zh/`, 191 s) and the attack scenes with less blood (99 frames, `captures-closing-attacks-less-blood/`, 136 s), 0 moments missed in each and no window on the student's desktop; and the main scene booted on the real renderer (exit 0 in 4.5 s, OpenGL 3.3).
- Frame review, by Claude and not by a person at the game: in a first English drawing that evening, the report coming up out of the dark after Maren's blow, the first night's pages and totals (counter +1440, closing -180, till 1260, LIGHTS OUT, 4 of 5 right), a false alarm's quiet slip, Rook's HANDED OVER slip, the second night's totals with Juno and Maren never seen, and the fifth night's (THE CUT, 5 of 5 right). It found two faults, both fixed before the final drawings: after a death the meter on the wall showed the whole night's line in red, and one frame caught the report's blinking prompt unlit. In the final drawings: in English the second night's first page with the meter left at the third hour (LINE 720), its totals, and the first night's last page with the prompt lit; in Chinese the first night's first and last pages, the second night's lights-out totals (熄灯, 没等到接诊), Rook's 已移交 slip and Vale's 卷闸守住了 slip, with his intake card enlarged in both languages (only the doctor's marks; in Chinese its eye row of three notes touches, as documented); with less blood, Maren's strike and a report page after Vale's blow. These are automated captures of fixed moments, not a playtest.

Limits of this checkpoint:

- No human playtest. Whether a night told only at closing feels more uncertain or only more confusing, whether the report's pages are read or skipped, and whether ending the night on a death feels fair are questions for play.
- The slip's lines, the report's words and their Chinese are assistant writing that no person has read in play.
- Random signs, per-part art and the five new characters (requests 3 and 5) are not built yet; the cast's signs are still fixed per patient.

## Earlier checkpoint of November 18: the language, the opening and the binder

On November 18, after the November 17 build had been pushed and started in a window for them, the student sent a screenshot of the third opening card (THE LANTERNS) with these requests, paraphrased from Chinese:

1. What does this card mean, and what does "chrome" mean?
2. A language option on the title screen, Chinese first, with everything that should be translated translated; "if one side is changed, the other must be changed too".
3. The opening animation had hardly changed, though a new story had been asked for: update it to match.
4. If every character has the same normal sheet, the exam grows tiring. The difference needs a reason in the story, such as different implant models. Then, in two more messages: organize it by implant model rather than by character, so that a character is made of several parts, which is more reasonable and easier to extend.

During the work the student answered three questions: yes to downloading Fusion Pixel Font (a 23.4 MB archive) for pixel Chinese glyphs; keep the patients' names and the contacts' code names in English and translate companies, gangs and everything else; and, for the Chinese title, "think of a more reasonable and interesting one". Before the screenshot the student had also asked about random signs; the student answered that proposal late that evening (current checkpoint, request 3).

**Nobody has played this version, read its Chinese in play or reviewed the translation, and no paid service was called for it.** The requests and the three answers are the student's. The translation, the title 先别下刀, the binder's models and their numbers, the new pictures and every new sentence are assistant proposals that the student has not reviewed. [game/README.md](game/README.md) has the details as a player meets them (Languages, The opening, The reference sheet); the [translation note](docs/development/chinese-translation.md) has the glossary, the patients' voices in Chinese and how the two languages are kept in step.

| Request | What the build does now |
|---|---|
| 1 | Answered in chat: the card is the Lanterns' back-street clinic, whose contacts come in as patients smuggling military implants; tonight's list gives each an alias, two clues and a code, and the right code to the right visitor earns the package, +300. "Chrome" is street slang for implants (义体). The words that teach the rules no longer say chrome: the opening cards and the list's clue say implant ("Implants in both eyes.", whose id in `contacts.json` is now `implant_eyes`), and the training's penlight tip now sends the player to the sheet. Chrome is left as slang around Juno only: her lines, the doctor's question to her, her brief for the model and a line of her report. In Chinese it is 义体 throughout. |
| 2 | **English \| 中文** in the title card's top-right corner switches every word the game shows; the choice is kept in `user://settings.cfg`, and the language changes only on the title card. Everything the player reads is translated, from the opening to the report, about 720 lines in 12 catalogs; ten pictures with words in them have Chinese twins, and the sign reads 先别下刀 ("don't cut yet") over a small BEFORE THE CUT, as does the window's title. People's names, code names, the binder's model names and the key names stay English. The patient model is asked to answer in the player's language, typing Chinese goes through the system's input method, and three checks keep the two languages in step. |
| 3 | The opening's pictures were redrawn for the story: FIRED is three panels (the badge refused on Kessler's floor 88, the lift down between two guards, the doctor outside in the rain with the spec binder), THE DEBT is Kessler's staff debt file stamped SOLD TO HARROW under Harrow's lease, THE LANTERNS tags the matched patient CONTACT and the parcel PACKAGE, and THE DRIFT is a crate of military surplus with filed-off serials, then a visitor whose eye implant glitches before they crack the glass. The cards' words were rewritten to match (`intro.json` version 5). No picture shows one of the five visitors. |
| 4 | The doctor kept Kessler's **spec binder** (`game/data/parts.json`): the factory normal of each implant model, by slot. Each patient wears one model in each slot (left eye, right eye, hands, port, voice; `parts` in the case file), and the sheet for the patient at the counter is put together from those models (`case_db.gd` `sheet_for`), so two patients with the same models get the same sheet and a new patient needs only models from the binder. Between patients the sheet on the wall is the baseline body. The close-ups name the model and use its numbers: the grip's LIMIT is the patient's hands model's. |

The binder (`parts.json` version 1; `sheet.json` version 4; `rules.json` version 7, where `grip.limit_ms` left the rules for the hands models):

| Slot | Models and their normal |
|---|---|
| Eyes | NATURAL (pupils tighten in light), KITE (an optic) and IRIS (a display): no pupil, nothing tightens; TALON (a combat eye): shutters snap tight in light. Every model follows the light. |
| Hands | let go on "release" inside NATURAL 1.0 s, LOADER 1.5, SEAM 0.8, DEFT 0.5, REFLEX 0.3 |
| Port | STREET and WORK (sockets) and MIL-SPEC (a plate): calm skin, no dark threads |
| Voice | NATURAL and VX-9: says "I" and "my", remembers what they did |

Each model also has its own line of what is odd but harmless (a cracked lens for KITE, locking up now and then for LOADER, a st-stutter for VX-9). The cast: Kip a KITE left eye, the rest natural with a street port; Rook natural eyes, LOADER hands, a work port; Vale TALON eyes, REFLEX hands, a MIL-SPEC plate; Juno IRIS eyes, DEFT hands, a street port and a VX-9 voice; Maren natural eyes, SEAM hands, a work port. No case's truth and no row's verdict changed; two release times moved so that each keeps its verdict against its own model: Rook's from 0.5 to 1.2 s (steady: slow for a hand, inside a LOADER's 1.5) and Vale's from 0.6 to 0.2 s (inside a REFLEX's 0.3). The eyes in the case files lost their `kind`, which the model now gives. When the data loads, `case_db.gd` refuses a case that wears a model the binder does not have, an eye that tightens with no pupil to tighten, or a hands verdict that disagrees with its release time against its model's limit.

The Chinese:

- **Catalogs.** `game/data/lang/zh/` holds one catalog for each data file with shown words (`cases/*.json`, `contacts.json`, `intro.json`, `parts.json`, `rules.json`, `sheet.json`), `ui.json` for the words in the scripts, and `topics.json`, the Chinese words the offline patient listens for. Each maps the exact English to its Chinese, with a `keep` list of Latin words a translation keeps as they are. Text is translated where it is drawn (`scripts/core/lang.gd`), so the rules, the data and the event log stay English.
- **Glyphs.** Fusion Pixel Font's 10-pixel cut (SIL Open Font License 1.1), downloaded with the student's yes, was cut to every ideograph it draws (10,687) plus CJK punctuation (`tools/art/extract_zh_font.py`, `tools/art/fonts/`) and built into `game/assets/fonts/zh.fnt` (`font_zh.py`, `gen_font.py`; the licence is `zh_LICENSE.txt` beside it). It is the fallback of every Counter Sans font, so Latin letters and digits stay Counter Sans.
- **Pictures.** The words painted into pictures live in `tools/art/words.py`; each generator writes `<name>.png` and `<name>_zh.png` together. The twins: the booth (the hall camera's label), the hall (the EXIT light), the shutter's stencil, the four things on the two pinboards, the three imprints on the intake card, and the logo.
- **Typing and pace.** While the typing line is open in Chinese the game turns the system's input method on, places its candidate window at the caret and shows the text being composed; otherwise it is off, so the letter keys stay the game's keys. Chinese is typed out and held at half the English rate per character (`Lang.PER_CHAR`), since a line says as much in about half the characters.
- **The intake card.** A hanzi is nine pixels tall, so in Chinese a row's one or two notes are set ten pixels apart and a finding puts 正常 or 异常 at the start of its text, with 你没有检查 on the right (`Gfx.tall_lines()`, `clipboard.gd`). A row with three notes still sets them nine apart; they touch.
- **The patients.** The request names the language (`patient_agent.gd`); the proxy refuses a language it does not have before any call, asks the model to answer in Chinese with names and code names in Latin letters, holds it to 55 characters a line and 110 a reply (`rules.json` `agent.languages` and `core.mjs` `DEFAULT_LIMITS.languages`, together), and passes the language on to transcription. The offline patient's lines are in the case catalogs, and it listens for the Chinese words of `topics.json` as well as the English ones (`scripted_brain.gd`).
- **Keeping the two in step.** `python tools/check_lang.py` fails on a shown line with no translation, a translation whose English has changed, two translations of one line, a line and its translation with different `{slots}` or `%`-codes, a translation that is empty or the English again, and a picture without its twin; `measure_text.py --lang zh` measures every line as it reads in Chinese; and the scene test run with ` -- --lang=zh` fails on any English that reaches the screen untranslated. `AGENTS.md` makes the rule a working instruction.

What changed in the repository (in commit `3f1fcbd`):

- Modified, besides this file, `NEXT_AGENT_PROMPT.md`, `README.md`, `AGENTS.md` and `game/README.md`: in `agent_proxy/` `README.md`, `src/core.mjs`, `src/providers.mjs`, `test/core.test.mjs` and `test/openai.test.mjs`; in `game/data/` the five case files, `contacts.json`, `intro.json`, `rules.json` and `sheet.json`; in `game/scripts/core/` `case_db.gd`, `patient_agent.gd`, `scripted_brain.gd`, `visit_state.gd`; in `game/scripts/ui/` `clinic_view.gd`, `clipboard.gd`, `coach.gd`, `dialogue_box.gd`, `gfx.gd`, `guide.gd`, `intro.gd`, `main.gd`, `scope_view.gd`, `screens.gd`; in `game/tests/` `capture_shift.gd`, `run_close_check.gd`, `run_proxy_integration.gd`, `run_tests.gd`, `run_ui_smoke.gd`; in `tools/art/` `gen_booth.py`, `gen_clinic.py`, `gen_font.py`, `gen_team.py`, `gen_ui.py`, `measure_text.py`; `tools/run_proxy_integration.mjs`.
- New: `docs/development/chinese-translation.md`; `game/data/parts.json` and the catalogs in `game/data/lang/zh/`; `game/scripts/core/lang.gd` with its `.uid`; `game/assets/fonts/zh.fnt`, `zh.png` (each with its `.import` file) and `zh_LICENSE.txt`; the eleven `_zh.png` pictures in `game/assets/clinic/` and `game/assets/ui/`, each with its `.import` file; `tools/art/words.py`, `font_zh.py`, `extract_zh_font.py` and `fonts/` (the cut font and its licences); `tools/check_lang.py`.
- Not changed: every English picture and every sound, `run-game.ps1`, `agent-config.json`, the cases' truths and signs, every limit but the new Chinese pair (so `rules.json` `agent` and `core.mjs` still agree), the G1 documents, slides and narration. The version string is still 0.3.0.

Results on the evening of November 18, on that checkpoint's final working tree, committed as `3f1fcbd` (logs in the local `validation/2026-11-18/checks/`; commands under "Results in this checkout"):

- **934 rule checks**, **953 scene checks** over nine shifts (**954 in Chinese**, 953 with `--less-blood`), **5 normal-close checks**, **39 proxy tests**, and over HTTP with the mock provider and a simulated microphone **196 game checks and 15 wire checks**: all passed; every run exited 0 with nothing on standard error.
- The translation check: 0 problems. Text measurement: 616 lines, 0 problems, in English and in Chinese (none left in English). Lint: 31 scripts, no findings. Capture script, dry: 196 frames named in English and 196 in Chinese, and 91 with `--attacks-only --less-blood`, 0 moments missed.
- Import with the existing cache: exit 0, nothing on standard error. A copy of `game/` with no cache imported cleanly (exit 0 in 10 s, nothing on standard error, 754 cache files) and passed 934 rule and 953 scene checks; one clean import says little about the crash of November 17 (below), which came twice in twenty tries. The headless boots (offline, and in model mode with no service behind the address) printed only the known `4 ObjectDB instances were leaked` warning that `--quit-after` causes; the boot on the real renderer on a hidden desktop exited 0 in 4 s on OpenGL 3.3. No file in `game/` changed during the run.
- **Drawn on a hidden desktop** by `tools/run_hidden.py`, on the same code: 196 frames of four shifts in English in 174 s, the same 196 in Chinese in 171 s, and 91 attack frames with `--less-blood` in 116 s, 0 moments missed, exit 0, and no window on the user's desktop in any run.
- Frame review, by Claude and not by a person at the game: in the final drawings the first opening card, the training's sheet tip, Kip's penlight readouts (RIGHT EYE NATURAL, LEFT EYE KITE), Rook's grip against LIMIT 1.5s and Rook's slip with findings that name his LOADER; in Chinese the Lanterns card, the same readouts, the staged transcript and Rook's slip. Two earlier Chinese drawings that day led to two changes: the intake card's Chinese spacing (enlarged crops of five cards from the second drawing, whose card code is the final one, showed it fixed) and the staged transcript, which was still in English.

Limits of this checkpoint:

- No human playtest, listening test or human voice test, in either language. Nobody has operated the November 18 build in a visible window.
- The Chinese is assistant writing that no person has read, in the data or in play. Whether it reads naturally, whether the glossary's choices are right and whether the patients keep their voices (Vale's formal 您, Maren calling the doctor 孩子, Juno's stutter) are open.
- No model has been asked to answer in Chinese, and no Chinese speech has been transcribed: whether the patients sound right in Chinese, keep to 55 and 110 characters and keep names in Latin letters is untested. The HTTP checks run in English; the Chinese request is checked by the rule tests and the proxy's own tests only.
- Typing Chinese is checked only by the scene test, which hands the typing line what an input method would; nobody has typed with a real input method in the game window, so where its candidate list appears and how it behaves are unknown.
- In Chinese an intake row with three notes sets them nine pixels apart, so they touch, and a line may break inside a word (常 | 见).
- The binder's numbers (1.5, 0.8, 0.5 and 0.3 s) are first guesses. Whether sheets that change with the patient make the exam fresher or only harder to read is a question for play.
- Signs are still fixed per patient: nothing is drawn at random but the arrival order, the two contacts and the timing of snaps and flares.

## Earlier checkpoint of November 17: the student's five notes

**Superseded in part by the checkpoint above.** Since November 18 the game is in English or Chinese, the opening's pictures are redrawn, the rule text says implant where it said chrome, and the reference sheet and the grip's LIMIT follow the patient's implant models (LIMIT 1s is the natural hand's). Every count below has grown. The rest is as described.

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
| 5 | Six opening cards tell the story: FIRED (Kessler), THE DEBT (Harrow Credit), THE LANTERNS (the gang's back-street clinic, their contacts, tonight's list, +300 for the right code), THE LINE (240 an hour), THE DRIFT (illegal street implants), BEFORE THE CUT. Two of each night's five visitors are contacts. Tonight's list (left wall, or L) gives each an alias, two clues and a code line. Clues use only the intake card and the eyes; each alone fits at least two visitors and both together exactly one, which is checked when the data loads. SAY speaks a code: the right contact hands over a package (+300 at once, whatever the call), and anyone else loses 1 patience. Codes are game-owned: no model call, nothing in the patient's memory. The lender's line rose to 240 an hour, so five right calls (1,140) no longer reach the 1,200 of closing without a drop. |

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
- **The game** is version 0.3.0: one night at the counter with five patients (Kip, Rook, Vale, Juno, Maren) in a shuffled order, the first of a session steady, a Normal Reference Sheet, optional looks, tools, questions, reassurance and pressure in any order, a typing line, push-to-talk, TREAT or Trauma Team, attacks and the shutter, slips and an end-of-shift report. Since November 16 also: an opening and a counter guide, the lender's hourly line, patients who leave when their patience is gone, the player's own marks counted against the house rule, the timing bar and the counter glass, the patient's thinking and listening poses, and the screen as the inside of the booth, with a layer of glass to buy back between patients. Since November 17 also: the story (fired by Kessler, in debt to Harrow Credit, working the Lanterns' counter), two contacts a night on a list with clues and codes, CALM at 30 credits, a line of 240 an hour that right calls alone no longer hold, readouts and the sheet's limit in every close-up, a first-night training, and patients who snap or flare in the middle of an action. Since November 18 also: the game in English or Chinese (a switch on the title card), the opening redrawn for the story, and reference sheets put together from Kessler's spec binder for the implant models each patient wears. Since the late evening of November 18 also: right or wrong told only at closing, on a report with a page for each visit, and a night that ends when a patient gets through (LIGHTS OUT). Since November 19 also: each night draws who of the five drift and which sign each of their parts shows, with three fixed test nights, and the money of rules version 9 (the line at 400 an hour, Trauma Team's bounty the patient's own fee, paid on account) (first section). Controls, rules and spoilers: [game/README.md](game/README.md). Look, sound and design choices: [docs/development/direction.md](docs/development/direction.md).
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

1. The student asked for the work of November 17 to be pushed, and then for the game to be started so that they could look at it. The work went into one commit on `main` (`e7f94d7`), with an English message and no AI attribution, and was pushed to `origin/main`. The game was started with `run-game.ps1` in a visible window and exited with code 0 when the student closed it. What the student saw is recorded only by the next item and the screenshot of the third opening card.
2. While the game was open, the student asked whether random signs were built: abnormal signs appearing at random on different parts of a patient, with the assets prepared in advance and combined at play time. The student added that there should still be a fixed wave of patients like the present one, for testing, through which every situation that can occur can be experienced. The assistant answered that they are not built (only the arrival order, the two contacts, the timing of snaps and flares and a few offline line variants are random) and proposed: the characters stay fixed (face, voice, manner, job, age, visit, fee, and the implants that are part of who they are), and each night draws their condition from its seed: one to three drifting patients, never the first of a session; each drifting one breaks at least two lines, at least one of which needs a tool or a question; one to three harmless oddities on the steady ones as decoys. The parts to prepare: a sign library (`data/signs.json`: where each sign can appear, whether it is seen or measured, its readings and card text, a sentence for the model, offline lines); port overlays and close-ups, and attack pictures for Kip, Rook and Juno (only Vale and Maren have them); character briefs for the model made neutral, with the night's signs sent by the game; and a validator that every generated night must pass (every broken line can be found, no drifting patient can be called on looks alone, no contradictions on one part, the contacts' clues still pick out exactly one visitor, every training tip has something to point at), run over a few hundred generated nights in the tests. Two fixed test nights: A, the five cases as they are, and B, the reverse (Kip, Rook and Juno drifting, Vale and Maren steady) with the signs and parts A does not show; together every patient steady once and drifting once, every sign and part at least once, a snap and a flare; opened from TEST NIGHTS on the title card or `-Test`; and a coverage check in `run_tests.gd` that fails on a sign no test night shows. Three steps, each playable: rules and data (step 1, about the size of the November 17 round, mock calls only), then art, then words, ending in a small paid live check that will need its own yes with provider, model, number of calls and cost. Optional: a steady patient may rarely have one line truly broken, so that finding the second line matters; built first as one example in a test night. Not proposed: new characters generated at random. The assistant asked whether to do step 1 and stop for the student to play, or all three steps in a row. No answer came that afternoon; the student answered late that evening (item 4). The spec binder built in between (the earlier checkpoint of November 18) is the natural home for the sign library: a sign can name the slots and models it can appear on.
3. The student then sent the screenshot of the third opening card with the four requests in the first section. In answer to the assistant's questions: yes to downloading Fusion Pixel Font for the Chinese glyphs; keep the patients' names and the contacts' code names in English, and translate companies, gangs and everything else; and for the Chinese title, "think of a more reasonable and interesting one" (the assistant chose 先别下刀). That the model names on the sheet (KITE, VX-9) and the key names stay English, the glossary, every translated sentence, the binder's models and numbers, and the new pictures are the assistant's choices, not student decisions.
4. Late that evening, after `3f1fcbd` had been pushed, the student sent the five requests of the first section. Stated in them: whether a call was right is told only at the end, for more uncertainty; the whole logic is to be gone over for holes; a doctor who is killed ends the night; the characters stay as they are, and any of their parts may be abnormal at random, so every character needs a normal look, an abnormal look for each part and attack art, the rage attack included, done that way now if it was not; and five more characters with all their assets. This answers item 2: build the random signs, with the art. The student did not choose between "step 1 and stop" and "all three steps" in so many words; the requests ask for all of it now. The slip's words, the split of the money between the counter and closing, the report's pages, the lamps' colours, LIGHTS OUT and its text, and that the meter is not read for a dead doctor are the assistant's choices, not student decisions.

## Game runtime: current state

### What was done on November 19 (the model's night signs)

- `agent_proxy/src/character_profiles.mjs`: each background holds on any night. Nothing in it says that the patient drifts; Kip's fall, Rook's cable, Vale's employer, Juno's singing and Maren's thirty years of welding stay.
- `agent_proxy/src/core.mjs`: `MODEL_ROWS` (speech and temper), `signIn()`, `signsOf()` and `tonight()`. `validateRequest()` refuses a request whose `signs` are missing, name another row or are not this patient's (`400 bad_request`, message `signs`), and keeps them in the checked request; `buildPrompt()` adds `Tonight: ` with each sign's `model` sentence after the reason for the visit.
- `game/scripts/core/patient_agent.gd`: `MODEL_ROWS` and `model_signs()`; `build_payload()` sends `signs`. The protocol stays 3.
- `game/data/cases/maren.json`: the brief says that her hands twitch after she stops, not that they keep working. The brief is for the model only and has no Chinese twin.
- Tests: `run_tests.gd` (the payload names tonight's two signs for night A's Kip and Vale and never the truth; a case without signs names none); `agent_proxy/test/` (every body carries `signs`; nine kinds of bad `signs` are refused; a night of normal speech and temper hears no broken sentence, and no background states one); `tools/run_proxy_integration.mjs` (the wire check that every request named both signs and the model heard them).
- Documents: `agent_proxy/README.md` (`signs`), `game/README.md` (Patient AI modes), `HANDOFF.md`, `NEXT_AGENT_PROMPT.md` and `README.md`.
- Not changed: every picture, sound and line the player sees; the rules, the agent limits and the signs in the case files.

### What was done on November 19 (random signs: the data and the code)

- `game/data/`: the five case files and their Chinese (version 3: templates of signs, row by row, and the outcomes for either truth); `rules.json` and its Chinese (version 9: `roster`, `night`, the line at 400 an hour, the scoring note, the counter words for the fee on account); `contacts.json` (BALLAST's clues, so the list stays fair among drawn visitors); `intro.json` and its Chinese (the till's guide line); and the new `nights.json` (test nights A, B and H).
- `game/scripts/core/`: `case_db.gd` (the template check, `compose()`, `check_picks()`, `reachable_rows()`, `fair_contacts()`, the test nights); `shift_state.gd` (`draw_night()`, the readings); `visit_state.gd` (the counter money of a hand-over).
- `game/scripts/ui/`: `main.gd` (the drawn night, `--test-night=`, the till while the slip prints); `patient_rig.gd` and `scope_view.gd` (dark threads only on a night whose port sign has them, where a picture exists).
- Tests and tools: `run_tests.gd`, `run_ui_smoke.gd` and `capture_shift.gd`; the proxy tests (case version 3); `tools/art/measure_text.py`, `tools/check_lang.py` and `tools/gd_static_check.py`.
- Documents: `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `README.md`, `game/README.md` (the money of version 9, the drawn night, the test nights and every character's signs) and `docs/development/direction.md` (the slip and the report of late November 18, the line, the drawn night, the open questions).
- Not changed: every picture and sound, `agent_proxy/src/`, the agent limits (so `rules.json` `agent` and `core.mjs` still agree), `sheet.json`, `parts.json`, the G1 documents, slides and narration. The version string is still 0.3.0.

### What was done late on November 18 (right or wrong at closing, lights out)

The first section says what each change is; [game/README.md](game/README.md) has it as a player meets it. Where each thing lives:

- **The money.** `visit_state.gd`: `counter_credits_for()` and `closing_credits_for()` split each outcome's credits between the counter and closing, `call_kind()` (treat, team, shutter or none) and `counter_key()` (which entry of `rules.json` `counter` the slip uses); the settlement carries `counter`, `counter_fee`, `closing`, `counter_title`, `counter_text` and `call`. `shift_state.gd`: `till()` (the counter money less glass: what the till shows and what the readings count until the last hour), `total()`, `died` (set by a blow that lands), `unseen()`, and in `report()` `died`, `unseen`, `counter_total`, `closing_total` and the title LIGHTS OUT (`rules.json` `titles` with `died`, `line_text.died`).
- **The slip.** `main.gd` `_draw_slip()`: the counter title and text, AT THE COUNTER with its credits, `_slip_breakdown()` (drop, missed drop, CALM) and `SLIP_LATER`; the till moves by the counter money only, and the slip's sound follows it. `clipboard.gd` lost the findings (`show_findings()`, `_draw_findings()`, `_finding_after()`): the card holds the doctor's marks only.
- **The report.** `screens.gd`: `pages()`, `on_summary()`, `turn()`, `_draw_visit_page()`, `_draw_finding()` and `_finding_text()` (the findings, moved here from the card), `_draw_totals()`, `_money_row()`, `_call_of()` and `_verdict_of()`. `main.gd`: `act_report_next()`, `act_report_back()`, `act_report_skip()`, `_report_turn()`, `_report_summary_reached()` (the till's jingle) and the keys of the `REPORT` state.
- **The meter's lamps.** `clinic_view.gd` `CALL_LAMPS` and `results` (one call kind per finished visit).
- **Lights out.** `main.gd` `_hit()` (the dark after the blow), `_resolve()` and `_lights_out()` (no slip; the `lights_out` event), and `_show_report()`, which leaves the meter on the wall unread for a dead doctor.
- **Words.** `rules.json` version 8 (`counter`, `titles`, `line_text`, the notes), `intro.json` version 6 (two tips: bounties and bills come in at closing; whether a call was right, you learn at closing), Maren's and Vale's case lines, every new line in `lang/zh/`, and the glossary in `docs/development/chinese-translation.md`.
- **Tests.** `run_tests.gd` 970 checks (934 before; new `test_counter_and_closing()`: the split of every outcome's credits, the counter words, the till and the readings, LIGHTS OUT and the unseen); `run_ui_smoke.gd` 1001 over the same nine shifts (953 before), 1002 in Chinese: every slip's counter words, a card that never turns to findings, the till against the counter money, the report read a page at a time, two nights that end in the dark with the unseen named; `play_driver.gd` `wait_for_report()` and `read_report()`; `run_proxy_integration.gd` 199 over HTTP (196 before): in its `meanwhile()` part Vale turns on the call, and a blow that landed would now end the night, so the shutter stops him and the slip is awaited; `capture_shift.gd` five shifts (four before) and 204 frames (196): each report as three frames (the first visit's page, the last visit's page, the totals) and two nights that end in the dark; `measure_text.py` 682 lines (616), with the slip's counter text, the report's pages and the finding rows; `check_lang.py` checks the new `counter` table.

### What was done on November 18 (the language, the opening, the binder)

The first section says what each change is; [game/README.md](game/README.md) has them as a player meets them, and the [translation note](docs/development/chinese-translation.md) the glossary and the rules of the catalogs. Where each thing lives:

- **The language.** `scripts/core/lang.gd` (new, `const Lang = preload(...)` where it is used): `CODES`, `NAMES` (each language by its own name), `PER_CHAR`; `load_saved()` (`--lang=` wins over the saved choice; English when neither), `save()`, `pin()` for the tests; `t()`, `tf()` and `fill()` to translate a line where it is drawn; `topic_keys` for the offline patient; `record` and `misses` for the scene test. `main.gd`: `act_language()` (only on the title card; logs `language`), `_apply_language()`, `_sync_ime()` and the input-method notifications; `session_start` carries `language`. `screens.gd`: `language_rects()`, `language_at()`, `_draw_languages()` (the switch on the title card). `gfx.gd`: the Chinese fallback font (`_with_chinese()`), `_wrap_cjk()` and `wrap_after()` for lines that break between hanzi, `tall_lines()`, `typeable()`, and `*_raw` text calls for words that must not be translated. `dialogue_box.gd`: `input_compose()`, `caret_point()`, the composed text on the typing line, and typewriters paced by `PER_CHAR`. `clipboard.gd`: `_finding_after()` for the Chinese findings (late on November 18 the findings moved to the report, `screens.gd` `_draw_finding()` and `_finding_text()`). `visit_state.gd` writes the intake notes in the player's language as they are taken. Every other script that draws words translates them where it draws them.
- **The patients.** `patient_agent.gd`: the request's `language` and the Chinese limits (`line_chars()`, `reply_chars()`, `_own_limits()`). `scripted_brain.gd`: the Chinese topic words. `agent_proxy/src/core.mjs`: `DEFAULT_LIMITS.languages`, the check of `language`, the prompt in Chinese; `providers.mjs`: the language passed to transcription; both test files and the proxy's README.
- **The binder.** `data/parts.json` (new); `case_db.gd`: `validate_parts()`, `resolve_parts()` (writes each eye's model, kind, pupil and tag, and the grip's model, tag and `limit_ms`, into the case), `sheet_for()`, `_eyes_row()`, `seconds()`, and `validate_case()` with the sheet and the binder; `scope_view.gd`: the model tags in the readouts, NO PUPIL and the TALON shutter, LIMIT from `limit_ms`; `clipboard.gd` and `main.gd` (`_hang_sheet()`, `_grip_limit_s()`): the patient's sheet and the baseline sheet between patients. `sheet.json` version 4, `rules.json` version 7, the `parts` of each case file.
- **The opening.** `intro.gd`: new pictures for FIRED, THE DEBT, THE LANTERNS and THE DRIFT (`_art_fired()`, `_fired_badge()`, `_fired_lift()`, `_fired_out()`, `_art_debt()`, `_debt_file()`, `_lease_paper()`, `_drift_crate()`, `_drift_glass()`, `_visitor()`, `_tag()`); `intro.json` version 5.
- **Art.** `tools/art/words.py` (new) holds every word painted into a picture, in both languages; `gen_booth.py`, `gen_clinic.py`, `gen_ui.py` and `gen_team.py` write each picture with words and its `_zh` twin; `gen_font.py` builds `zh.fnt` from `font_zh.py`, which reads the cut in `tools/art/fonts/` (`extract_zh_font.py` says how it was cut). No English picture changed.
- **Tests.** `run_tests.gd` 934 checks (820 before; new: `test_parts()` for the binder and every patient's sheet, and in `test_conversation()`, `test_offline_say()` and `test_voice()` the Chinese request, its limits and the offline patient in Chinese); `run_ui_smoke.gd` 953 over the same nine shifts (940 before), 954 with `--lang=zh`: `languages()` presses the title card's switch both ways and checks the painted twins, and in Chinese `untranslated_words()` fails on English that reached the screen; `capture_shift.gd` takes `--lang=`; `run_close_check.gd` and `run_proxy_integration.gd` pin English; the proxy tests 39 (38 before); `tools/check_lang.py` (new); `measure_text.py` 616 lines (514 before) and `--lang zh`; `gd_static_check.py` 31 scripts (`lang.gd` is new).

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

The checks of November 19, on the tree of the first section, are in that section (`validation/2026-11-19/checks-night-signs/`, and on the tree of `5b64d87` `checks/`). The table below was run late on November 18 in this checkout, on the final working tree (`validation/2026-11-18/checks-closing/`, with the runners `chain.sh` and `chain2.sh` and their outputs beside the logs; `validation/` is not in the repository). The results of the evening of November 18, on the tree committed as `3f1fcbd`, are in `validation/2026-11-18/checks/`; the counts of November 17 and 16 are in the checkpoints above and in `validation/2026-11-17/` and `2026-11-16/`. PowerShell, from the repository root:

```powershell
$GODOT = "$env:LOCALAPPDATA\CodexTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
```

| Check | Command | Result |
|---|---|---|
| Import with the existing cache | `& $GODOT --headless --audio-driver Dummy --path game --import` | exit 0 |
| Import from an empty cache (a copy of `game/` without `.godot/`) | the same, on the copy, then the rule and scene checks on it | not run late on November 18 (no picture, sound or font changed). On the evening of November 18 (`3f1fcbd`): exit 0 in 10 s, nothing on standard error, 754 cache files, 934 and 953 passed on the copy. Not reliable on November 17 (2 crashes in 20 on that tree, 1 in 20 on `822e8d7`; first section of that checkpoint) |
| Rules, outcomes, agent and voice units | `& $GODOT --headless --audio-driver Dummy --path game --script res://tests/run_tests.gd` | 970 passed, 0 failed |
| Nine shifts through the real scene, offline | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/run_ui_smoke.gd` | 1001 passed, 0 failed |
| The same, in Chinese | add ` -- --lang=zh` | 1002 passed, 0 failed |
| The same, less blood | add ` -- --less-blood` | 1001 passed, 0 failed |
| Window close | `& $GODOT --headless --audio-driver Dummy --verbose --path game --script res://tests/run_close_check.gd`, last and alone, without `--fixed-fps` (with it the check fails) | 5 passed, 0 failed; no leak line in the verbose exit report |
| Proxy unit tests | `npm test` in `agent_proxy` | 39 passed, 0 failed |
| Game and proxy over HTTP, local mocks, simulated microphone | `node tools/run_proxy_integration.mjs $GODOT validation/2026-11-18/http-integration` | 199 passed, 0 failed; wire checks 15 passed, 0 failed (in English). The first run failed one check of 196: Vale's blow landed in the `meanwhile` part, which now ends the night with no slip; the check now drops the shutter in time |
| Translations in step | `python tools/check_lang.py` | 0 problems |
| Every text fits | `python measure_text.py` inside `tools/art` | 682 lines, 0 problems |
| Every text fits, in Chinese | `python measure_text.py --lang zh` inside `tools/art` | 682 lines, 0 problems, none left in English |
| Rough GDScript lint | `python tools/gd_static_check.py` | 31 scripts, no findings |
| Capture script, dry run | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd` | 204 frames named, 0 missed; with ` -- --lang=zh` 204, 0 missed; with ` -- --attacks-only` 99 and with ` -- --attacks-only --less-blood` 99, 0 missed |
| Capture drawn on a hidden desktop (the same game code) | `python tools/run_hidden.py ...` (command in its header) | 204 frames of five shifts in English, exit 0 in 197 s; 204 in Chinese, 191 s; 99 with ` --attacks-only --less-blood`, 136 s; 0 missed in each; no window on the student's desktop in any run |
| Main scene boots | `--quit-after 240`, default and `-- --agent-url=http://127.0.0.1:9 --model` | exit 0 both; the known `4 ObjectDB instances were leaked` warning that `--quit-after` causes, and nothing else |
| Main scene boots on the real renderer | the windowed executable through `python tools/run_hidden.py`, `--audio-driver Dummy --path game --quit-after 420` | exit 0 in 4.5 s on OpenGL 3.3, with the same warning; no window on the student's desktop |

Every row exited 0. The logs hold standard error together with the output; no line in them is an error, and the only warnings are the `ObjectDB instances were leaked` lines that `--quit-after` causes in the three boots. The HTTP row's test file changed after the first run of the other rows; the rule and scene checks and the window close were run again after that change, with the commands exactly as above, and the dry captures do not read that file. These are automated checks with the dummy audio driver, a simulated microphone and the mock. They show the flow holds together in both languages, not that it is fun or reads well, and not that a person can make the timing windows: the scene test presses the shutter within one frame of the moment it chooses.

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
| Reply length | asked for 110 characters, refused only over 220; in Chinese 55 and 110 (`agent.languages`) |
| Conversation memory | 48 entries per visit, cleared for the next patient |
| Spoken clips | 0.35-10 s, 24 per visit, 360 per session; 6 s / 7 s deadlines |
| Provider calls per proxy process | 2,000, shared by both routes |

The live run's maximum output was 66 tokens and maximum response time 2.54 seconds. No increase to the 256-token budget or deadlines was warranted.

### Not done, not verified

- From November 19 (first section): a drifting Kip, Rook or Juno has no attack drawing; dark threads at the port are drawn only for Vale, whose port cannot be reached; OPEN, BARELY and ON NOTICE are out of reach with the present five. The model hears the night's speech and temper signs only in mock runs: whether a live model plays a steady or a drifting patient well from one sentence each is unknown. Unknown: whether drawn nights feel fair, whether two to four broken rows are too few or too many, and whether 400 an hour leaves room for one mistake.
- No human playtest, human speech-accuracy check, listening test or Windows export build. The live-model run and synthetic-speech service check of November 15 are complete; nobody spoke into the microphone in that run. Google/Vertex remain untested live.
- None of the builds of November 16, 17 and 18 has been heard or met a live model, and none but the November 17 build (started for the student on November 18, who looked at its opening) has been in a visible window. Unknown from late on November 18: whether a night told only at closing feels more uncertain or only more confusing, whether players read the report's pages or skip to the totals, and whether a night that ends on a death feels fair. Unknown from earlier on November 18: whether the Chinese reads naturally and fits in play, whether a real input method works in the window, whether the model answers well in Chinese inside 55 and 110 characters, whether Chinese speech is transcribed well, and whether sheets that follow the implant models make the exam fresher or only harder to read. Unknown from November 17: whether the training walks a new player through the eye test and the grip, whether the readouts make them clear, whether the list is fun, whether a person can react to a snap in time, whether a flare panics the player, and whether 240 an hour with 300 a drop is a fair night. Unknown from November 16: whether a person can stop an attack inside the timing bar, whether eight seconds is enough to decide, whether the counter-first screen is what the student meant, whether a paper in front of the window is comfortable to read beside the patient, whether a player finds the things on the walls without the guide, and whether paying for glass is ever worth it.
- No sound was added on November 17: the snap, the flare, the list, the codes and the training reuse existing sounds, and nobody has measured how they sit in the mix. The -9 dB attack trim and the whine fade were judged from measurements of a silent recording only. The sounds reused by the moments of November 16 (meter, crossed rule, leaving countdown, opening, guide) have not been measured in the mix, and neither has `glass_fit.wav`.
- The fresh-import crash: its cause is not known, and it is not in this project's files as far as the commit's crash shows. Not tried: another Godot version, the editor's first import, a `--verbose` import that might show where it stops.
- Keyboard layouts and a denied Windows microphone permission are untested, and a Chinese input method has been tried only through the scene test's stand-in. A device that fails to open after the press is covered only by reading the code.
- A typed or spoken provocation has no rule effect; only the PRESS pad costs patience. A typed code is not a code either: only SAY on the list says one. The patient does not speak aloud. The typing line has no paste.
- The Worker entry (`agent_proxy/src/worker.mjs`) has never been deployed.
- Leftovers: `agent_proxy/src/scripted.mjs` is no longer imported; `move_validator.gd` keeps an old name for a shape check.

### For the student to decide

New on November 19: the titles OPEN, BARELY and ON NOTICE are out of reach at 400 an hour with the present five (first section). Lower their thresholds, or keep them for nights with dearer visitors?

Answered late on November 18: **random signs** are to be built, with every character's art for each part (Student decisions, November 18, item 4). Still open from that proposal: whether a steady patient may rarely have one line truly broken.

Proposals of late November 18 (right or wrong at closing, lights out), built but not reviewed:

- **The split of the money.** Fees for work done, drops, CALM and glass at the counter; every bounty, bill and fine at closing, the bill for treating a drifting patient taking the fee back. The alternative, nothing at all until closing, would leave the till and the hourly readings with nothing to say.
- **The slip's words** (`rules.json` `counter`) and "Right or wrong: at closing."
- **The report's pages**: one for each visit, then the totals, opening on the first visit; the keys; the findings beside the doctor's marks.
- **The meter's lamps** in the colour of what was done (green, amber, blue, red, dark) rather than ticks and crosses.
- **Lights out**: the title, its text and the meter's line ("Nobody reads the meter tonight. Harrow Credit takes the clinic back."), that the hour is not read and no line is held, and that the visitors still in the hall are named as never seen. A death that only costs money and lets the night go on was the behaviour before.

Proposals of November 18 (the language, the opening, the binder), built but not reviewed:

- **The Chinese as a whole**, and the glossary ([translation note](docs/development/chinese-translation.md)): 义体 for implant and chrome, 稳定 and 失控 for steady and drifting, 灯笼帮, 凯斯勒, 哈罗信贷, 创伤小组 and the rest; the patients' voices in Chinese.
- **The title** 先别下刀 ("don't cut yet") over a small BEFORE THE CUT, also in the window's title.
- **What else stays English**: the binder's model names (KITE, LOADER, VX-9) and the key names, beside the names and code names the student chose to keep.
- **The binder**: its models and numbers (hands 1.0, 1.5, 0.8, 0.5 and 0.3 s), which patient wears what, and the two release times moved to fit them (Rook 1.2 s, Vale 0.2 s). Whether more slots (skin, a spine, a voice box with its own readout) are wanted.
- **The opening's new pictures**, and that none of them shows one of the five visitors.

Proposals of November 17 (the five notes), built but not reviewed:

- **The training.** 14 tips on the first night only, their words (`data/intro.json`), the 2 s and 10 s after which a tip gives way, and K to skip it. A walk-through with forced steps was not built, because the design keeps every examination optional and unordered.
- **CALM at 30 credits** (`reassure.cost`; 0 makes it free again), or removing it.
- **The readouts.** Whether TIGHTENS, STAYS WIDE, FOLLOWS and the red grip past LIMIT 1s say too much, or still too little.
- **The contacts.** Two a night (`contacts.per_night`), 300 a drop, 1 patience for a wrong code (`contacts.wrong_cost`), clues only from the intake card and the eyes, a pool of ten entries, the first visitor on the training night's list.
- **The line at 240 an hour** (400 since November 19, with Trauma Team's bounty the patient's own fee: first section). Five right calls without a drop end in THE CUT. Whether that is the pressure meant, or whether right calls alone should hold the line (a lower `line.per_hour`).
- **Snaps and flares.** A snap's 3 free actions, 0.08 a step and 0.30 at most (`snap`), the 0.35 s before its attack (`snap.lead_ms`), a flare's 0.10 an action, once a visit (`flare`), and a shutter on a flare counted as a false alarm (−100).
- **The story's names and words.** Kessler and the Lanterns (Harrow Credit is from November 16), the six cards, the aliases, clues, codes and packages, the flare lines.
- **The booth.** The HOUSE RULE sign removed so that the booklet fits on the right wall; the list on the sheet's hook, so that one of the two papers is down at a time.
- **Words on screen.** "Contact" for the gang's people (the code and the data still say courier for the role), and Kip a bike courier.

Proposals of the evening of November 16 (the counter-first screen and glass repair), built but not reviewed:

- **Whether this is the screen that was meant.** One large window with the patient, and everything else as a thing in the booth. Is anything missing from the booth, in the wrong place, or still too much like a panel? The transcript stays as a unit set into the desk, and the meter and the small hall monitor are always on the wall; only the papers, the larger hall screen and the guide open on a click.
- **How the papers behave.** All start a shift on the wall, the sheet's corners blink until it has been down once, a paper stays where it was left from patient to patient, and the intake card comes down by itself for the stamp (and, until late on November 18, for the findings, which are now on the report). A night that starts with the sheet already down was not built.
- **Keys**: R sheet, N card, C hall camera, G glass (and since November 17 L list, K skip the training), next to the older ones.
- **The hall camera**: between patients a second press of C, or a click on the larger screen, lets the next patient in; ENTER does it at once.
- **Glass repair**: 40 credits a layer (`rules.json` `attack.repair_cost`; 0 switches repairs off), only between patients, the till may go into debt for it, and no limit but the three layers of the pane. The fitter wipes the pane and leaves the rest of the blood.
- **Words**: the four guide pages (`data/intro.json`), the hints of the wall objects and of the glass key and the fitter's line (constants in `main.gd`), and CALM instead of REASSURE in the hints, after the name printed on the pad.

Proposals of the eleven notes (earlier on November 16), built but not reviewed (each is one number or one text file to change):

- **The house rule**: two crosses (`sheet.json` `threshold`), and whether the card should count the player's crosses at all.
- **Leaving**: eight seconds (`rules.json` `patience.leave_ms`; 0 makes them leave at once), and that CALM during the countdown holds the patient.
- **The line**: an hour under the line costs nothing until closing (the amount is 240 since November 17 and 400 since November 19, above). A harsher version (a second hour under the line ends the night) was not built.
- **The glass**: three lamps (`attack.glass`), a new pane every shift, the 1.8 s window with blows at 0.54, 0.99 and 1.44 s (`attack.window_ms`, `blow_at`) and 0.65 s with none left (`min_window_ms`).
- **Words and names**: the opening cards, the guide, the coach hints and the ending text of THE CUT (`data/intro.json`, `rules.json`, constants in `main.gd`), and the lender's name, Harrow Credit.
- **The cast**: fixed truths and signs with a shuffled order, as the student said is fine for testing. Superseded on November 19: each night now draws the truths and the signs (first section), and the test nights of `data/nights.json` keep the fixed nights for testing.

Seen earlier, not changed:

- Blood stays until the shift ends (left alone on November 15 at the student's request): blood on the sill and seeping below it, gore on the shutter, and wall and desk stains all stay through the next patients. So do a broken window, a caught splash and dents in the glass, unless a layer of glass is paid for: the fitter's arm wipes the pane and nothing else. `--less-blood` removes the blood, not the broken glass.
- After a listening test: whether the -9 dB attack trim is right (`ATTACK_TRIM_DB`, one number).
- Whether asking, tools, CALM, PRESS and codes should also be allowed while a reply is on its way (they still wait; a live run will show for how long).
- Whether shuffled arrivals should stay. Superseded on November 19: the whole night is drawn (first section); `--test-night=` and `--authored-order` play fixed nights.
- Open questions in the direction document: should a typed provocation count as pressure, should the patient speak aloud, how much blood by default.

### Documents behind the runtime

`docs/g1/01`-`04`, `06` and `07` are the submitted G1 versions and were left as submitted: the Configuration document and risk R3 still describe four calls per visit and 2-2.5 s deadlines, and `07` says voice is not implemented. `agent-config.json` was brought up to date on November 15.

## Next three tasks

Before them: run `git status -sb` and `git log -3 --oneline`. The work of the first section is in `5b64d87` and the commit after it, together with this file; anything uncommitted is newer. Never add AI attribution to a commit.

1. **Braintrust replies** (due **today, November 19, 23:59 New York**, the soonest deadline): the student picks two G1 pitches with fewer than two replies; draft specific, moment-based notes in English for review; the student sends them.
2. **Every character's art for each part** (the rest of the student's request 3 of late November 18; the model's part was done on November 19, first section). From `tools/art/` only: for every character the port clean and with dark threads (the portrait's `<layer>_t` twins where the port shows, and the close-up's `port_threads.png`), and attack art for Kip, Rook and Juno, with the attack drawing in `main.gd`, `patient_rig.gd` and `clinic_view.gd` made general (its style, blows, cut and sounds). English and Chinese together.
3. **Five new characters with all their assets** (request 5): a case file with parts from the binder (new models where needed), contacts' clues that still pick out one visitor, the Chinese, the proxy's imports (`agent_proxy/src/worker.mjs`, `dev_server.mjs`) and a background that holds on any night, with a sentence for the model on every speech and temper sign, and every part's art and an attack. Each needs every sign of every row, test nights that show them (and Rook's broken eyes and temper and Maren's dark threads, which A, B and H leave out), a coverage check that fails on a sign no test night shows, and contacts' clues for the pool. A working sketch, not reviewed: Priya Nair, 45, a night-ward nurse with a scanner eye and scalpel fingers; Hiro Tanaka, 63, a noodle cook with a cleaver hand; Lux Ferreira, 19, a net diver with IRIS eyes and a jack port, whose attack is an electric arc; Dana Kirsch, 47, an off-duty police officer with a TALON right eye and a MIL-SPEC port, who attacks with a stun baton; Bo Kowalski, 29, a pit fighter with piston hands.

Once they are built, **the student plays and reads** (`.\run-game.ps1`, with headphones): a night in Chinese from a fresh start, reading every card, tip, sheet, slip and report page and typing a sentence with a real Chinese input method; then a night in English. Look at the report at closing (does it make the night more uncertain, or only more confusing?), a night that ends in the dark, the sheets changing with the patient, the redrawn opening, and the open questions of November 16 and 17. Then settle the proposals under "For the student to decide" and correct the translation from what the student marks, in both languages at once. An agent operating the window is not a substitute, and neither is the scene test.

After these, or sooner if the student asks: a short live run in Chinese and in English (the model's answers in Chinese inside 55 and 110 characters, Chinese and English speech through TAB, the thinking pose and the new moments with real latency), which is a paid call and needs the student's explicit yes with provider, model, number of calls and cost; the visual check of the PATIENT SAID row and paste support for the typing line; and the fresh-import crash (another Godot version on a copy, or an upstream report with the logs in `validation/2026-11-17/fresh-import-repeats/`; a public report is a post and needs the student's yes).

## Evidence (local, not in Git)

- `validation/2026-11-19/checks-night-signs/`: the run after the model's night signs (the rule tests, the three scene tests, the window close, the proxy tests, the static check). `validation/2026-11-19/http-integration/` holds that run's HTTP integration (requests, wire checks, prompt sizes), which replaced the files of the run on `5b64d87`; the console output of that earlier run is `checks/proxy-integration.log`. `validation/2026-11-19/checks/`: the run on the tree of `5b64d87`, the captures' dry runs among them.
- `validation/2026-11-18/checks-closing/`: the run of the late evening of November 18 (each check's log, holding its standard error with the output; the runners `chain.sh` and `chain2.sh` and their outputs; `boot-real-renderer.log`). The first HTTP run's own log was overwritten by the rerun; its result (195 passed, 1 failed) is in `chain-output.txt`, and `http-diagnostic.log` is a second run before the fix, with a line that names where it stopped (the events `attack`, `attack_hit`, `visit_end`, `lights_out`).
- `validation/2026-11-18/captures-closing-en/` (204 frames), `captures-closing-zh/` (204, in Chinese) and `captures-closing-attacks-less-blood/` (99), with their `.log` files beside them: the drawings of the late evening.
- `validation/2026-11-18/checks/`: the last run of the evening of November 18, on the tree committed as `3f1fcbd` (output and standard error of every check, `summary.txt`, the runner `run_checks.sh`, `git status` and the checksums of `game/` before and after, `boot-real-renderer.log`). The copy of `game/` it imported from an empty cache was made in the assistant's scratch folder and is not kept.
- `validation/2026-11-18/captures-en/` (196 frames), `captures-zh-3/` (196, in Chinese) and `captures-en-attacks-less-blood/` (91), with their `.log` files beside them: the drawings of the evening, on the tree of `3f1fcbd`. `captures-zh/` and `captures-zh-2/` are earlier Chinese drawings of the same day, before the intake card's Chinese spacing was fixed and with the staged transcript still in English; they are not results for the final tree.
- `validation/2026-11-18/intro-frames/`, `intro-frames2/`, `intro-sheets/`, `intro-sheets2/`: frames and contact sheets of the opening while it was being redrawn, before its last change.
- `validation/2026-11-18/http-integration/`: the last mock-provider HTTP run, of the late evening (199 checks, in English); each run writes over it.
- `validation/2026-11-17/checks/`: the final run of November 17 (not results for the current build) (output and standard error of every check, `summary.txt`, the runner `run_checks.ps1`, `git status` before and after, the boot logs with `boot-real-renderer.log`). `fresh-copy/` is the copy of `game/` whose fresh import crashed, as mended by the second import (the three empty temporary files are still in its cache); `crashed-fresh-import/` holds the crashed import's output and the rule and scene logs on that copy before it was mended (the scene check's standard error cut to its first 300 lines).
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
