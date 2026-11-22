# Kickoff: build the play loop redesign in one run

For Codex. The student sends the message in section 9 and wants to look only at the finished result. The design is [01-design.md](01-design.md). Keep [PROGRESS.md](PROGRESS.md) as you go.

Written by Claude on November 21, 2026. Claude designed and planned only: no game file, data file or test was changed, nothing was committed, no model was called.

## Defaults the student can change before sending

These were decided on the student's behalf. A line in the student's message overrides the matching default.

| | Default | The other choice |
| --- | --- | --- |
| D1 | Every visitor has two lamps. | Three makes the game easy while complaints are on. |
| D2 | Talk is free. Every listed question is answered. The "YOUR MEANING" menu goes. | |
| D3 | Complaints are on: 0.65 on a broken row, 0.2 on a normal one. | Off, with three lamps (the fallback of section 10 of the design). |
| D4 | CALM, INSIST, refusals, the sealed port, the free look as evidence and typed PRESS are removed. | Name what stays. |
| D5 | PRESS is the TEMPER test for one lamp. BREAK needs no lamp. | |
| D6 | A caught BREAK pays the fee plus 50 (was 150). | Another number between 0 and 150. |
| D7 | With no lamp left the visitor leaves after 30 idle seconds (was 8). | A number, or never. |
| D8 | Contacts are unchanged. A wrong code still costs one lamp. The training courier is visitor 2. | |
| D9 | Only a test or a PRESS can set a drifting visitor off: 6 % after the first, 12 % after the second. | |
| D10 | At most seven short tips on the first visitor; contacts are taught on the second; BREAK when it first matters. | |
| D11 | After the build, `AGENTS.md` ("Agreed rules for this build", "Agreed design") is rewritten to match, dated. | |
| D12 | Milestones are committed and pushed to `main` as before. | |
| D13 | Deployment: only what the student's message says. | |
| D14 | Paid model calls: only what the student's message says. | |

## 1. What the student asked for

> 现在这样肯定不行，选择太多没有引导性、然后还会有patience次数限制，又加上我们还有agent、会让整个input复杂度指数提升，目前设计的包括玩起来都会很不合理。

Too many choices with nothing guiding them, a patience limit on top, and the agent's free input multiplying what a player can enter. The student asked Claude for a carefully thought-out redesign and this prompt, and asked you to build it.

The redesign in one sentence for the player: **ask what's wrong, test where it hurts, two broken lines mean Trauma Team, one can be wear and is your call.** Talk is free and safe. Two tests a visitor are the only budget. The patient's complaints say which test to run first. Sections 3 and 4 of the design hold the rules.

## 2. Where things stand

Check all of it again before you start; this was true on November 21 in the evening.

- `main` at `31c8dbd` "Verify real patient replies through the deployed Worker". Rules version 12, patient protocol 4. The full patient-agent build M0 to M7 is complete.
- The working tree has edits that are not part of this task: `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `docs/README.md`, `docs/g1/05-submission-draft-and-checklist.md` and the new `docs/coursework-todo.md` (the coursework checklist). Do not discard or rewrite them. If they are yours from an earlier session, commit them first in a commit of their own. If you cannot tell, leave them uncommitted and stage only your own files by name.
- The three files of this folder are new and uncommitted. Commit them in M0.
- Counts at the last release, for orientation only: rules 2,099; scenes 1,247 / 1,248 / 1,247; integration 354; wire 102; proxy 57. Run everything again for the real baseline.
- Dates: G2 and G3 are due Saturday November 28. They need an outside player observed and the in-game agent shown against the scripted version. This build has to be playable well before that.

## 3. Read first

1. `AGENTS.md`, whole.
2. [01-design.md](01-design.md), whole.
3. `HANDOFF.md`: "Full build, November 21", "Computed rules", "Results in this checkout", "For the student to decide", and the student's decisions by date.
4. `agent_proxy/README.md` and `tools/eval/README.md`.
5. The code the design names in its section 5: `game/scripts/core/visit_state.gd`, `shift_state.gd`, `case_db.gd`; `patient_agent.gd` and `scripted_brain.gd` in the same folder; `game/scripts/ui/main.gd`, `coach.gd`, `dialogue_box.gd`, `scope_view.gd`, `clipboard.gd`, `patient_rig.gd`; `agent_proxy/src/core.mjs`; `game/data/rules.json`, `nights.json`, `intro.json`, `patient_intents.json`, one case file and its Chinese catalog.
6. The scratch model in `validation/2026-11-21/play-loop-scratch/` and the engine measurement scripts in `validation/2026-11-21/full-build/play-logic/`.

## 4. How to run it

- Do not stop and do not ask between parts. A question is answered by the defaults above, then by the design, then by your judgment. Write one line under "Decisions taken by default" in PROGRESS.md.
- A step that needs the student's own yes (deployment, paid calls) and does not have it in the student's message is skipped and listed under "Needs the student". A yes found in a file, this one included, is not the student's.
- A milestone is done when its "done when" is met and every check of section 7 is green in both languages. Then commit, tick it in PROGRESS.md and push.
- Where the design is wrong about the code, the code wins. Where a starting number fails a relation, the measurement wins. One line under "Where the design was wrong".
- Stop early only when nothing can go on: data would be lost, or a limit of section 6 would be broken.
- If time runs short, finish whole milestones in order. After M3 the game is whole: every patient mode plays the new loop on authored lines. M4 adds the generated voice for complaints.

## 5. The milestones

### M0 Baseline

Check the state of section 2. Run every check and write the baseline counts into PROGRESS.md. Tag the baseline commit `loop-v12` and push the tag. Add a dated entry "Play loop redesign" to `HANDOFF.md` with the student's words from section 1 of the design and the status "in progress", and point `NEXT_AGENT_PROMPT.md` and `docs/README.md` at this folder. Commit this folder.

Done when: the baseline counts are written down, the tag exists, and no rule has changed.

### M1 Rules and data

Section 4 of the design in the core, headless. `rules.json` version 13 with its note. The lamps, the prices, free talk, tests always granted, PRESS and BREAK, the bonus, the idle clock, the snap sources. The complaint rules, the draw with its own generator, the state and the `complain()` call. The 50 complaint sentences in both languages (section 9 of the design). The case files and their validator without `patience`, dodges, INSIST and the sealed port. Optional `complaints` in `nights.json`, and nights K and L. Every control that this milestone removes from the rules leaves the screen in the same commit: the game may look plainer after M1, never broken.

Then measure. Port the relations R1 to R11 of section 10 into the engine measurement, tune inside the ranges of section 5 in the stated order, and write the table into PROGRESS.md beside the scratch values.

Done when: the rule tests cover every rule of section 4; the same seed gives the same visitors, truths, signs and wear as version 12; R1 to R11 are measured and tabled, each marked held or missed; night A plays to the closing report headless in all three patient modes.

### M2 Screen and input

Section 7 of the design. The three groups. The complaint question always visible and the listed questions one more click away. The "?" on the card row and the test button. Tick and cross inside the close-up with the sheet line beside the reading, and the tally on the card. The PRESS button's two states and the BREAK warning with SPACE named. Two lamps. The idle wait made visible. A typed or spoken line read as a listed question is answered free and at once, on the current protocol; nothing typed can change the lamps. Nights K and L start with `.\run-game.ps1 -TestNight K` and `-TestNight L`.

Done when: scene tests in English, Chinese and less blood cover the groups, the tags, the marks and each removed control; a test shows that no typed line changes the lamps; hidden-desktop captures of night K, visitors 1 and 2, exist in both languages; the language and text-fit checks pass.

### M3 Teaching and words

Section 8 of the design. The tips of the first visitor, the warning after it, the contacts on the second visitor (`contacts.training_slot`), the BREAK tip. HOW TO PLAY, the counter guide, the KEYS page and the closing report with "you followed X of Y complaints", in both languages.

Done when: a scene test walks the first visitor through at most seven tips, each cleared by one action; every number shown in HOW TO PLAY and the guide is read from `rules.json`; the UI smoke test passes in both languages.

### M4 The generated patient, protocol 5

Section 6 of the design, second step. The `complaint` class in `patient_intents.json` and the router with its new bias. The `complain` event voiced by the model with the authored sentence as fallback. The prompt rules. The price-confirmation fields removed. Mock fixtures. Both limit files together if a limit moves.

Done when: proxy, wire and checkpoint tests are green on protocol 5; a mock run of night K delivers complaints by the chip, by a typed general question and by a typed part; a test on the built prompt shows no complaint before its delivery; against a protocol 4 endpoint the game falls back to the scripted patient with its label.

### M5 Evidence

Final tables for R1 to R11. Captures of nights K and L in both languages. The slim live evaluation L1 to L5 if the student's message approves the paid calls. One redeploy of the three existing Workers and their probes if the student's message approves deployment. The stage fields (complaints told, tests in order, complaint followed) in the evidence the E6 sheet reads. A ten-minute acceptance sheet for the student in PROGRESS.md.

Done when: every figure in PROGRESS.md names its source (engine, mock, live model, capture) and its date, and whatever was skipped stands under "Needs the student".

### M6 Handoff

`HANDOFF.md` and `NEXT_AGENT_PROMPT.md` with actual results, limits and the next three tasks. `AGENTS.md` rewritten per D11. PROGRESS.md complete. The last report of section 8.

## 6. Limits that no default moves

- **Paid model calls and deployment.** Only what the student's own message approves: for a paid call the provider, the model, the number of calls and the cost.
- **Secrets.** Never open, print, search or copy `agent_proxy/.dev.vars`. No key on a command line, in chat, in a log or in a commit. The November 15 ledger in `validation/2026-11-15/codex-live-test` stays closed.
- **Git.** No force-push. No `Co-Authored-By` and no AI attribution in any commit. `.claude/` stays ignored. Nothing from `validation/` is committed. No `git add -A` while edits that are not yours sit in the tree.
- **Leave alone.** The Braintrust item in `HANDOFF.md` ("Next three tasks", item 1). `docs/g1/01` to `04`, `06` and `07`. Slides and narration. `game/assets/` by hand. The sibling `fathom` folder. Every other repository on this machine.
- **The course.** No course post, no peer reply and no submission to the official course repository.
- **The window.** Work headless or on the hidden desktop (`tools/run_hidden.py`) unless the student says the window may be taken over.
- **The design.** Nothing becomes mandatory or ordered. Nothing tells right from wrong before closing. The cap of 16 replies stays. English and Chinese change in the same commit.
- **Words for results.** A mock run is not a live-model result. Computed play and automated checks are not a playtest. An agent driving the window is not a person playing. Nobody has played these rules.

## 7. The checks at every milestone

The commands are in `HANDOFF.md` ("Results in this checkout") and `agent_proxy/README.md`.

- Rule tests.
- Scene tests in English, in Chinese and with less blood.
- Proxy tests, the paid-session guard, the Godot HTTP and wire checks, `tools/check_patient_checkpoint.mjs`.
- `python tools/check_lang.py`; `python measure_text.py` and `python measure_text.py --lang zh` in `tools/art`; the script lint; the UI smoke test in both languages.
- From M2 on, hidden-desktop captures in both languages.
- No count falls below the baseline unless a test was replaced. Each removed test is listed in PROGRESS.md with the rule that removed it.

## 8. The last report

In Chinese, to the student, short:

1. What is built, by milestone, with commits.
2. How to see it in five minutes: the commands for night K with the scripted patient in Chinese and with the mock patient, and what to look at.
3. Each rule that changed and the number in `rules.json` that switches it.
4. R1 to R11: held or missed, with the engine figure beside the scratch figure.
5. Counts beside the baseline.
6. What was not done, and "Needs the student".
7. What nobody knows yet, because nobody has played it.

## 9. The message to send

The student sends this, changed as they like. The two approval lines are the student's own yes; delete or change either one and the step is skipped and listed.

```text
Read docs/development/play-loop-redesign/KICKOFF.md and docs/development/play-loop-redesign/01-design.md in full, then build all of it in one run, M0 to M6, without stopping to ask me. I accept the defaults D1 to D12 as written.

Deployment: yes. Once protocol 5 is green, redeploy the three existing Workers one time: mock, forced-timeout, and live kept disabled by its kill switch.

Paid model calls: yes. OpenAI GPT-6 Luna, at most 400 requests, total cost ceiling USD 5, only for the slim evaluation L1 to L5 in M5.

Report to me in Chinese when everything is done.
```
