# Play-logic review: brief for Claude (Fable)

Written on November 21, 2026 by Claude (Opus 5.5), for the student to hand to Claude (Fable).
Talk to the student in Chinese. Write the review in English.

## The task

The student wants the play logic of Before the Cut reviewed as a whole. That covers every way
the player can examine a patient, talk to them and decide about them, and whether each of those
earns its place. The student's concern: some tools get used and some never do, so a player
may finish a whole night without some of them and still make the right calls. The question
started with the second PRESS (below), but it covers the whole loop.

Deliver a review with two or three concrete proposals and a recommendation. Discuss it with the
student in Chinese, and build nothing until the student picks one. This is a design task
first: read, measure with the game's own code, and write.

## The student's words (November 21, verbatim)

The student was replying to the assistant's line "失控的病人：第二次施压时扑上来" (a
drifting patient lunges on the second PRESS: option B, below).

> 我觉得可以改趁这个、但是要提示说有几率会发狂（仅限赛博精神病哈）、普通人则有几率会走。但这样又显得收益不足。整体各种的审查以及这个逼问、包括ask、或者后续玩家可能会给agent去发消息。所有的这些我总感觉有些用得到有些用不到，就感觉可能有些部分玩家一整局都不会用就能得出结论。这块我觉得得好好盘盘游玩逻辑

In English: "I think it could change to this. But the warning should say there is a chance they
go berserk (cyberpsychos only), and an ordinary person has a chance to walk out. Then again,
the payoff looks too small. Overall, the examinations, this pressing, ASK too, and the
messages a player may send to the agent: I keep feeling that some of these get used and some
don't, as if a player could go a whole night without some parts and still reach a conclusion.
The play logic needs a proper going-over."

Notes on the quote:
- 改趁这个 is a typo for 改成这个 ("change it to this").
- The cyberpsychos are the game's drifting patients (失控).
- The messages to the agent are the doctor's own typed or spoken lines to the patient AI.

## Read first

- `AGENTS.md`: the agreed design and the working rules.
- `HANDOFF.md`, these sections:
  - the current checkpoint (the first section);
  - "Not done, not verified";
  - "For the student to decide";
  - "Student decisions", November 17 to 21.
- `game/README.md`, these sections:
  - "The screen": the pads, what each one costs, patience, and the push that breaks;
  - "The reference sheet";
  - "Contacts and codes";
  - "Decisions and money": the money table, snaps and flares, the lender's line;
  - "The patients (spoilers)": how a night is drawn, test nights A to H, every sign;
  - "Saying it in your own words".
- `docs/development/direction.md`: the motivations, and the open questions (one is whether a
  typed provocation should count as pressure).
- Data in `game/data/`:
  - `rules.json`: costs, patience, snap, flare, night, line, contacts;
  - `sheet.json`: the house rule;
  - `parts.json`;
  - `cases/*.json`, one per character: patience, fee, the three questions, refusals, and for
    every row the normal and the broken sign with its look, readings, answers and press
    reaction;
  - `nights.json`;
  - `intro.json`: the guide, the training and HOW TO PLAY.
- Code:
  - `game/scripts/core/visit_state.gd`: patience, tools, questions, PRESS, CALM, codes, snaps,
    flares and the result;
  - `shift_state.gd`: `draw_night` and the money;
  - `case_db.gd`: `compose`, `reachable_rows`, `fair_contacts`, `night_coverage`;
  - `scripted_brain.gd`: the offline patient;
  - `game/scripts/ui/main.gd`: the pads, their hints and badges.

## What the player does today (check it against the code)

**The decision.**
- Each visitor is STEADY or DRIFTING. One to three of the five drift (weights 1, 2, 1).
- A steady visitor shows every row of the sheet normal.
- A drifting visitor shows two to four broken rows (weights 2, 2, 1). At least two of them are
  rows the doctor can reach.
- The calls:
  - TREAT is right for a steady patient;
  - TRAUMA is right for a drifting one;
  - the shutter is right on a patient who turns.
- A patient has 5 to 7 lamps of patience.
- Right or wrong is told only at closing.

| Action | What it can show | Cost | Notes |
| --- | --- | --- | --- |
| Look (point at and click the eyes, hands or port) | some broken signs show in the picture, such as dark threads at a port the bust shows | free; not an action | |
| LIGHT | the EYES row: a readout for each eye, set against the sheet | 1 patience to ask, then free | after a refusal: insist for 1 more, or CALM first |
| GRIP | the HANDS row: release time against the model's limit, red past it | as LIGHT | |
| PORT | the PORT row | 1 if covered, otherwise free | Vale's sealed plate is never examined |
| ASK | the SPEECH row ("I" and "my", or "it" and "we") in the answers to three questions | 1 for each new answer | |
| The doctor's own words (T to type, hold TAB to speak) | with the patient AI: whatever the model says in character (it is told the night's speech and temper signs). Offline: only a line that matches one of the three questions gets an answer | with the AI: 1 for the first exchange, then free. Offline: nothing unless the line matches a question | a provocation has no rule effect |
| PRESS | the TEMPER row: whether face and voice react together | 2 | the second PRESS breaks anyone (below) |
| CALM | +1 patience, and it clears refusals | 30 credits, twice a visit | |
| SAY a code | nothing about the truth, by design | wrong: 1 patience; right: a 300-credit drop | |
| TREAT, TRAUMA (press twice), SHUT | the call | | a drifting Vale, Rook or Dana turns on a TRAUMA call |

**Snaps and flares.** Every action except looking is rolled for both.
- **A snap** happens only to a drifting patient. Its chance per action is (actions - 3) x 0.08,
  never above 0.30. It is an attack with the red bar. A shutter in time makes it a right call;
  a blow that lands ends the night and costs 300.
- **A flare** can happen to anyone: 0.10 per action after the first, at most once a visit. It
  is a shout at the glass, and evidence for the TEMPER row only.

**Money.**
- The night needs 2,000 in the till.
- The five fees come to 1,700-1,999, so holding the line takes right calls and at least one
  contact's drop (300).
- What wrong calls cost is in the README's money table.

**Facts to start from.**

- No steady case breaks any row, so a single broken row already proves drift, even though the
  sheet's house rule says two. Whether a steady patient may rarely break one row has been open
  since November 18.
- **What the second PRESS does today** (option A, rules version 10):
  - it breaks anyone: a steady patient walks out at once (no fee, no fine, not a right call),
    and a drifting one lunges;
  - it takes every lamp left.
- **How the player is warned about it:**
  - a hint that shows only while the pointer is on the pad;
  - the pad's badge, which reads -N for the lamps left. With 2 or 1 lamps left it reads -2 or
    -1, which is the same as an ordinary PRESS or less;
  - one guide item, one training tip and one line of HOW TO PLAY.

  The student finds it strange to lose every lamp without warning.
- **Options discussed on November 20 and 21** (none chosen):
  - **B:** the second PRESS costs 2. A steady patient stays while lamps are left, and only the
    drifting break. The flaw: two PRESSes become a cheap, certain test of drift.
  - **C:** keep A, but make it a visible decision. After the first PRESS the pad turns red,
    reads BREAK and shows "!"; the warning appears at once in the hint line; the second press
    ends the visit.
  - **D:** one PRESS a visit.
  - **The student's idea** (above): tell the player up front about the chances. A drifting
    patient may snap and a steady one may walk out. The student worries that the payoff is too
    small.

## Questions the review must answer

1. **Evidence.** For each hidden fact (steady or drifting, and which row is broken):
   - which actions can reveal it, how reliably, and at what cost and risk;
   - which free sources give it away: looks, flares, a patient turning on a call.
2. **Necessity.** Measure it across the nights the draw makes, and on test nights A to H:
   - How often is each action the only way to reach the right call?
   - What share of right calls do simple fixed routines reach, and how often do they hold the
     line? Examples: the three instruments only; instruments and ASK; never PRESS; never talk.
   - Is there a short routine a player can repeat on every visit without needing the rest?
     This is the student's suspicion.
3. **Value.** For each action:
   - Is there a situation where it is the best choice?
   - Is it dominated (always worse than another), redundant (the same information as a cheaper
     action) or only decoration?
4. **Risk and payoff.** What does each risk buy, and is it ever worth taking? Cover PRESS, the
   second PRESS, insisting, long exams (the snap chance), codes and CALM.
5. **The patient AI.** Talking is the course's in-game agent, and AGENTS.md calls the model's
   benefit a hypothesis to test.
   - What decision can talking change today that ASK cannot? If none, the agent is decoration.
   - What should free talk be for, within the rules? The model writes the words, the game owns
     truth and scoring, and a refusal is not a sign.
   - Should a typed provocation count as pressure? This is an open question in `direction.md`.
6. **Learning.**
   - Does the closing report teach a player which tool would have caught what they missed? It
     marks "you did not check".
   - Can the night teach anything before closing without giving the truth away?
7. **The second PRESS.**
   - Evaluate the student's idea and its payoff problem, alongside options A to D.
   - Recommend one, including the warning a player sees before it can hurt them.

## How to measure

- **Use the game's own code** rather than a copy of its rules:
  - draw many nights from seeds with `shift_state.gd` (`draw_night`) and `case_db.gd`
    (`compose`);
  - for each visitor, work out which rows are broken and which actions could see them. Account
    for refusals, covered ports, Vale's plate and the signs a look shows;
  - then score the routines above: the share of right calls, the patience spent, the snap risk
    from the formula, and how often the night holds the line;
  - run the same routines on test nights A to H.
- **Run headless:** `& $GODOT --headless --audio-driver Dummy --path game --script <script>`.
  `$GODOT` is set in game/README.md, "Checks".
- **Keep evidence out of Git.** Put scratch scripts and their results under
  `validation/2026-11-21/play-logic/` (Git ignores it), and record the seeds and the commands.
  Do not add tests to `game/tests/` or change game code during the review.
- **Say where each number comes from:** computed, from the scene test's driver, or untried by
  anyone. Computed results are not playtests, and nobody has played the current build.
- **Stay in the background.** Keep off the game window unless the student says it may be taken
  over. An agent operating the window is not a playtest either.

## What to hand back

1. **`docs/development/play-logic-review.md`** (English), with these parts:
   1. the evidence map, as a table;
   2. the measurements, with the method, the seeds and where the evidence is kept;
   3. the problems found, each shown on a concrete night or visit;
   4. two or three proposals and a recommendation, each in the shape the student likes:
      - the target motivation as the course's chain (motivator <- dynamic <- mechanic);
      - the rule in one sentence;
      - what it changes for each action, with a few example moments;
      - how a player learns it before it can hurt them (the guide, the training, HOW TO PLAY);
      - what it does to "right or wrong only at closing";
      - the cost to build: the files, both languages, the tests;
      - the risks;
   5. a recommendation for the second PRESS that answers the student's idea and its payoff;
   6. the questions for the student.
2. **A short message to the student in Chinese:** the main findings, the proposals, your
   recommendation, and one question.
3. **The handoffs:** add the result to `HANDOFF.md` ("For the student to decide" and "Next
   three tasks") and to `NEXT_AGENT_PROMPT.md`.
4. **Save early.** Write the review file early and fill it in as you go. If your quota runs
   out, as it did on November 17, another agent can finish it from there.

## Constraints

**Design (the student's standing rules):**
- **Optional and unordered.** Every examination is optional and unordered. Do not bring back a
  mandatory checklist, a universal re-check or a fixed sequence. A tool earns its place by
  being the best answer in some situations; it must never be required on every visit.
- **Simple.** Simple observation and reasoning, and short, meaningful choices. Not long
  reading, not a knowledge exam, not a dialogue tree. The student prefers one simple, fun rule
  to more systems.
- **The game and the model:**
  - the game owns case truth, readings, attacks and scoring;
  - the patient AI writes its own words and may evade or lie;
  - technical checks never pick its answers;
  - refusal or irritation alone is not a diagnosis;
  - the cap of 16 patient replies per visit stays.
- **Nothing leaks.** Right or wrong is told only on the closing report. Nothing during play may
  give it away: the slip, the card, the lamps, sounds, the timing of money, crew and patient
  lines, stamps, or names that can be matched across screens. Leaks that come by nature, such
  as a patient who turns, are listed in the docs.
- **Deaths and warnings.** Any new way to die ends the night. Warn before anything can hurt the
  player, and name the key that answers it. A new rule goes into HOW TO PLAY in both languages.
- **Parts and test nights.** Characters are built from parts, and any part may carry the broken
  sign. The fixed test nights must still cover every sign (`case_db.gd`, `night_coverage`).
- **Already rejected,** do not propose again: mandatory re-checks, referral (replaced by Trauma
  Team), and the ideas from the archived Fathom project.

**Working rules:**
- **Languages.** Chinese with the student, English in files. A change to the game's English is
  a change to its Chinese in the same commit.
- **Model calls and keys.** No paid model call without the student's explicit yes, given with
  the provider, the model, the number of calls and the cost. Run mock or offline only. Never
  open, print or search `agent_proxy/.dev.vars`.
- **Git.** Never add Co-Authored-By or any other AI attribution to a commit, and never
  force-push. Stage your own files by path.
- **Folders.** `validation/` holds local evidence and stays out of Git. `fathom/` is an archive.
- **Leave the Braintrust item alone** (HANDOFF.md, "Next three tasks", item 1).
- **If the student asks you to build a proposal,** follow AGENTS.md:
  - run the checks before committing: `check_lang`, `measure_text` in both languages, the scene
    test in English, in Chinese and with less blood, and the rule tests;
  - redo the captures where screens change;
  - update the handoffs.

## The checkout on November 21

- HEAD is `361baa7`, pushed.
- **Another session's uncommitted work.** At 00:20 another Claude session ("Before the Cut
  game development") had uncommitted work in progress:
  - what it covers: the slip's money line (FEE + DROP - CALM), and the next-night and
    back-to-title keys on the totals page;
  - the files: `game/README.md`, `game/data/intro.json`, `game/data/lang/zh/intro.json` and
    `ui.json`, `game/scripts/ui/main.gd` and `screens.gd`, `game/tests/run_ui_smoke.gd`, and
    `tools/art/measure_text.py`.

  Run `git status -sb` first. Never edit, stage or commit another session's uncommitted
  change. If those files are still dirty when you need to change them, ask the student.
- **Also uncommitted:** this brief, and the November 21 lines in `HANDOFF.md` and
  `NEXT_AGENT_PROMPT.md`, written by Claude (Opus 5.5).
