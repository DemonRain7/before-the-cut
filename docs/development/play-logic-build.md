# Play logic: the build brief

November 21, 2026. Written by Claude (Fable) for Codex. It turns the recommendations of
`docs/development/play-logic-review.md` into work. **Nothing here is built.**

## 0. Whose decision this is

- **The student's (November 21):** build everything that is left in one run and show it when it
  is finished ("我想让codex直接去全部完整的做完再给我看").
- **Not the student's:** the student has not picked a rule in words. Every choice below is the
  review's recommendation, taken as the default of that run
  (`docs/development/patient-agent-handoff/KICKOFF.md`, section 9). The message that starts you
  can change a default. Where it names another choice, it wins over this file.
- **So keep every new rule behind its number** in `game/data/rules.json`, with a value that
  gives the rule as built. The student may switch any of them off after playing.

Already built by P1 (`06714b8`): fix 4 of the review, typed and spoken questions at the price
and proof of ASK. Do not rebuild it.

## 1. What to build (rules version 12)

### R1. Wear: a steady visitor can carry one broken line (proposal A)

The rule in one sentence: one broken line can be wear; two or more make a drift, as the sheet's
footer, the card's counter (`CROSSED n/2`) and HOW TO PLAY already say. It also answers an item
left open on November 18 (a steady patient with one line truly broken).

- **Data.** `rules.json`, `night.wear`: a chance (0.5), a weight for each of the five sheet
  rows (equal), and that the first visitor of a session's first night is never worn. A chance
  of 0 gives the rule as built and must keep working.
- **The draw** (`shift_state.gd`, `draw_night`). For each steady visitor, with that chance, one
  row shows one of that character's broken signs for the row, picked by the weights. Every
  other row is drawn as now. Drifting visitors do not change: two to four broken rows, at least
  the threshold of them reachable.
  - Use a generator of its own, derived from the shift seed, as `name_contacts()` does. A seed
    then gives the same visitors, truths and drifting signs as before, and the same wear every
    time.
  - Contacts are validated on the night as composed, wear included (`validate_contacts`,
    `fair_contacts`). A clue must not depend on a sign that wear can change.
- **Truth and signs are two things.** A worn visitor is steady: no snap, no lunge at a call, a
  walk-out on the breaking PRESS, and TREAT is the right call. Evidence follows the row's sign:
  wherever a reading, a reaction, a flare's note or a report line is chosen by `is_drifting()`
  today, choose it by the sign that row shows. Truth decides the verdict of the call, snaps,
  lunges and the break, and nothing else.
- **Validation** (`case_db.gd`). A steady case may show at most one broken row. `night_drawable`
  accepts that. `night_coverage` also requires each of the five rows worn on a steady visitor
  at least once across the fixed nights.
- **Fixed nights** (`nights.json`). Add nights that carry wear (I and J, say) and leave A to H
  as they are, so the scene tests and the captures keep their meaning. If a night has to
  change, say which and why.
- **The patient AI.** The gates of P1 already go by open signs. A worn SPEECH or TEMPER sign
  reaches the model exactly as a drifting visitor's does, once the player has paid for it. Add
  the test: with equal open signs, the request is equal whatever the truth.
- **The closing report.** A steady visitor's broken line reads as wear ("broken: wear. One
  broken line is not a drift."). The doctor's cross on it is a correct mark. Check
  `settlement()` for any place that assumes a steady visitor has no broken row.
- **Teaching it.**
  - HOW TO PLAY, THE JOB: "One broken line can be wear. Two is a drift."
  - The guide booklet and the training's tip about the house rule say the same.
  - A hint the first time the doctor's own crosses on the card stand at one. It is keyed to
    the player's marks, never to what a row truly shows: the game must not confirm a reading.
- **Art.** No new art is expected: a steady visitor composed with a broken part already works
  in the rules. Nobody has seen one drawn, so draw every row's wear on the hidden desktop and
  look at the frames. Anything missing comes from `tools/art/`.
- **Not in this build:** authored excuses for a worn line, fewer lamps, covered ports.

### R2. The second PRESS: sure, warned, and paid for the catch

- It stays sure, as built on November 20: a drifting visitor lunges, a steady one walks out
  with no fee, and it takes every lamp left.
- **The catch.** `rules.json`, a bonus of 150 (0 switches it off). It is paid when a drifting
  visitor broken by the second PRESS is stopped at the shutter, and for no other attack: not a
  snap during the examination and not a lunge at a call. Like every bounty it is paid at
  closing, on its own line of that visit's page. The slip at the counter does not change.
- **The warning,** before the second push can be made, on the pad's badge and hint: what
  happens to each kind of visitor, that it takes every lamp, the bonus, and the key. A
  proposal: "PRESS AGAIN: they break. A drifting one lunges: SPACE drops the shutter, +150 if
  it holds. A steady one walks out, no fee."
- Leave `attack.window_ms` alone. With a shutter that never misses, breaking beats calling by
  150 on every drift the doctor is sure of. Nobody knows how often a person makes the shutter,
  so list the bonus and the window as the first things to tune after a playtest.

### R3. An action that costs nothing rolls nothing (fix 1)

An action is counted toward snaps and flares, and rolled (`visit_state.gd`, `roll_action`),
only when it took a lamp or was a CALM. Opening a tool that is already read, a right code, a
look and small talk count for nothing. Update the note of `snap` in `rules.json`.

### R4. PRESS needs its lamps (fix 2)

The first PRESS needs `costs.press` lamps. The breaking PRESS needs at least that many left and
takes all of them. With fewer, the pad answers as any other tool does when the patience is
spent.

### R5. A sealed tool says so (fix 3)

When insisting can never open a tool (Vale's port today), the first refusal says it, in the
hint and in the note under the row: insisting does nothing, CALM opens it. Insisting on it
again takes no lamp. What CALM does is unchanged.

### R6. The report names what would have shown a missed line (fix 5)

On the closing report only. For a broken line the doctor never saw, the row names the action
that shows it tonight: LIGHT, GRIP, the port (CALM first when it is sealed), the question that
shows tonight's SPEECH sign, PRESS. When the doctor did ask, but no question that shows the
line, the row says "asked, but not about this" where it says "you did not check" today.

### R7. A usage line on the night's totals

One line: in how many of the night's visits each of LIGHT, GRIP, PORT, ASK, PRESS and CALM was
used. It tells nothing about truth. If it does not fit in Chinese, give it a line of its own,
or leave it out and say so.

## 2. Words, in both languages, in the same change

- The guide's patience and talk items, the training's talk tip, the PRESS hints and the last
  point of HOW TO PLAY's attack page change with R2 to R4.
- New: THE JOB's line, the one-cross hint, the report's wear line and its "what shows it"
  lines, the sealed hint, the PRESS warning, the usage line.
- `python tools/check_lang.py` with 0 problems, `measure_text.py` in both languages, and the
  scene test in both languages.
- `AGENTS.md`, `README.md` and `game/README.md` where they describe a rule that changed. Say
  that the rules are the assistant's proposals and that the student has not played them.

## 3. Tests (in `game/tests/`, with the rule tests)

- Chance 0: no steady visitor is worn in 2,000 drawn nights.
- Chance 0.5, 5,000 nights: 45 to 55 % of steady visitors show exactly one broken row, none
  shows two, and each row carries about a fifth of the wear. Visitors, truths and drifting
  signs for a seed are what they were before wear.
- The first visitor of a first night is never worn. A steady case with two broken rows is
  refused. Each row is worn once across the fixed nights.
- A worn visitor never snaps, never lunges at a call and walks out on the breaking PRESS.
- The catch bonus is paid for the breaking PRESS stopped at the shutter and for nothing else.
- PRESS with too few lamps does nothing. Re-opening a read tool ten times counts no action.
  Insisting on a sealed tool takes no lamp.
- The report's rows for wear, for a missed line and for "asked, but not about this".
- P1's "same price, same proof" tests still pass. The scene test plays at least one worn
  visitor to the closing page, in both languages.

## 4. Measure what was built

The review's scripts are local: `validation/2026-11-21/play-logic/` (`measure.gd`, `extras.gd`,
`policy.py`; commands in the review's section 2). Copy them to
`validation/<date>/full-build/play-logic/`, point them at the built rule, and record the seeds
and the commands. Measurements stay out of `game/tests/`.

- **Wear alone,** against the review's what-if at 0.5 (5,000 nights, seeds 1 to 5000). Expect
  about 80 % right for "the three instruments, call on one broken line", about 98 % for
  "instruments; on one broken line ASK, then PRESS", 100 % for everything with CALM. A
  difference of more than two points is reported and explained, not tuned away.
- **Everything of this brief together:** the same routines, the breaking PRESS with a shutter
  that is in time always and 9 times of 10, and the re-opening routine, which should fall to
  the level of LIGHT alone.
- **The best possible player** (`policy.py`): what each tool is worth, and how often CALM and
  the break are bought.
- **The titles:** which of them a drawn night can reach now. Report it and change nothing.
- Label every number: computed with the game's code, from the model of one visit, or untried.
  None of it is a playtest.

## 5. Rules of this build

- **Optional and unordered.** No mandatory checklist, no universal re-check, no fixed sequence.
  A tool earns its place by being the best answer in some situations.
- **Nothing leaks.** Right or wrong is told only on the closing report. No hint, sound, stamp
  or number during the night may confirm a reading or a truth.
- **Deaths and warnings.** A blow that lands ends the night. Warn before anything can hurt the
  player and name the key. Every new rule goes into HOW TO PLAY in both languages.
- **Parts and test nights.** Characters are built from parts, and the fixed nights still cover
  every sign.
- **Already rejected,** do not build: proposal B, proposal C as a rule, a second PRESS by
  chance, a cheap sure test, mandatory re-checks, referral, the ideas of the archived Fathom
  project.
- The sixteen replies a visit, the limits in both places, the logs, the folders and the Git
  rules are as `AGENTS.md` says.

## 6. Say this in the final report

Nobody has played these rules. The computed player reads every line correctly and, unless the
table says otherwise, never misses the shutter. The numbers 0.5 and 150 are starting points.
