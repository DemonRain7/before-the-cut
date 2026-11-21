# Play-logic review

November 21, 2026. Written by Claude (Fable) for the student, in answer to
`docs/development/play-logic-review-brief.md`. Rules version 10, commit `361baa7` plus the
uncommitted polish of November 20 and 21 (which changes no rule).

**Nothing in this review is built.** No game code, data, test or text was changed for it. Every
number is computed, by the game's own rule code or by a small model of one visit; the label on
each table says which. Nobody has played the current build, and computed play is not a playtest:
the computed player reads every line against the sheet without a mistake, never hesitates and
never misses the shutter unless the table says so.

## 1. The short answer

1. **The student's feeling is right, and it has one cause.** The sheet says two broken lines make
   a drift, but no steady visitor ever shows a broken line, so one broken line is proof. Any one
   reading that comes back wrong ends the visit.
2. **No tool is ever needed.** Every drifting visitor has two to four broken lines, so there are
   always at least two different ways to see it. Taking any single tool out of the game costs the
   best possible player nothing.
3. **One dull routine is enough.** LIGHT, GRIP and the port on everyone, Trauma Team on the first
   broken line, TREAT otherwise: 98.7 % of calls right for 2.5 of the 5 to 7 lamps. ASK and PRESS
   are needed for 4.3 % of drifting visitors (1.7 % of all visits); CALM, the second PRESS and
   typing are never needed.
4. **Examining is free.** Lamps belong to one visit and are worth nothing left over. A visitor
   who snaps and is stopped pays like a right call. So "do everything" is never worse than
   deciding early.
5. **There are loopholes.** Re-opening a tool that is already read costs no lamp but can make a
   drifting visitor snap (a one-lamp routine reaches 99.2 %). PRESS works with no lamps left.
   CALM opens a port that insisting never opens. With the patient AI on, typed lines are free
   after the first.
6. **My recommendation:** make the house rule true. Let a steady visitor carry one broken line
   (wear), so that one broken line is a question and the second one is the answer. In the model
   every tool then decides 6 to 7 % of calls and CALM becomes worth buying. Close the loopholes
   whatever the pick.
7. **The second PRESS:** a chance version is the sure version watered down, and the sure version
   already has no payoff. Keep it sure, warn on the pad, and pay for the catch.

## 2. Method, and where the evidence is

Everything is under `validation/2026-11-21/play-logic/` (Git ignores it).

| File | What it is |
| --- | --- |
| `measure.gd`, `measure.out`, `results.json` | A headless script that loads the game's own `case_db.gd`, `visit_state.gd`, `shift_state.gd` and `scripted_brain.gd` and plays fixed routines on drawn nights. 5000 nights, seeds 1 to 5000, 25,000 visits. |
| `extras.gd`, `extras.out` | Single visits printed step by step (T1 to T7 below), on the fixed test nights and on two drawn nights. |
| `policy.py`, `policy.out`, `policy.json` | A model of one visit that finds the best possible play by search, fed with the measured draw and the measured costs. |

Commands, from the repository root (`$GODOT` is the 4.7.2 console build, `$V` the folder above):

```
"$GODOT" --headless --audio-driver Dummy --path game --script "$V/measure.gd" -- --nights=5000 --seed0=1 --out="$V"
"$GODOT" --headless --audio-driver Dummy --path game --script "$V/extras.gd" -- --m="$V/measure.gd"
python "$V/policy.py" "$V" --q=0.5
```

Labels used below:

- **[G]** computed with the game's own rule code and the scripted patient.
- **[M]** from the model of one visit. It is not the game's code. It has no snaps, flares, codes
  or glass, and it values a visit in credits.
- **[A]** arithmetic on the measured draw.
- **[R]** read in the code or the data, not run.
- **[U]** untried by anyone.

No number here comes from the scene test's driver. No model call was made, paid or mock.

Assumptions of the computed player: it reads every shown line correctly; it says both codes to
the right couriers unless the table says "no codes"; the shutter is always in time unless the
table says "9 of 10"; a routine is fixed and does not adapt beyond what its name says.

## 3. The evidence map

What each action can show, and what it costs **[G]**. Lamps are the visitor's patience. `3i/1c`
means a refused tool: 3 lamps by insisting, or 1 lamp and one CALM (30 credits). A star marks a
question that can show a broken SPEECH line.

| Visitor | Lamps | Fee | EYES (LIGHT) | HANDS (GRIP) | PORT | Questions and their price | TEMPER (PRESS) | All five lines |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bo | 6 | 320 | 3i/1c | 1 | free look | why 1, sleep* 1, cage* 2 | 2 | 7 of 6 |
| Dana | 5 | 550 | 1 | 1 | 3i/1c | why 1, sleep* 1, duty* 2 | 2 | 8 of 5 |
| Juno | 6 | 350 | 1 | 1 | free look | why* 1, chrome* 2, sleep* 1 | 2 | 5 of 6 |
| Kip | 6 | 250 | 1 | 1 | free look | why 1, sleep* 1, implant* 1 | 2 | 5 of 6 |
| Lux | 5 | 500 | 1 | 1 | free look | why 1, sleep* 1, dive* 2 | 2 | 5 of 5 |
| Maren | 6 | 400 | 1 | 1 | 1 | why* 1, sleep* 1, fear* 2 | 2 | 6 of 6 |
| Ozzie | 7 | 220 | 1 | 1 | free look | why 1, sleep* 1, alone* 2 | 2 | 5 of 7 |
| Priya | 6 | 450 | 1 | 3i/1c | 1 | why 1, sleep* 1, ward* 2 | 2 | 8 of 6 |
| Rook | 5 | 300 | 1 | 3i/1c | free look | why 1, mood* 2, implant* 1 | 2 | 7 of 5 |
| Vale | 5 | 600 | 3i/1c | 1 | sealed: CALM only | why 1, lapses 2, sleep* 1 | 2 | 8 of 5 |

The other actions:

| Action | What it gives | Price | Notes |
| --- | --- | --- | --- |
| LOOK | The port, when it is open (6 of 10 visitors) | free, never rolled for a surprise | Shows a broken line for 37.3 % of drifting visitors. |
| Insist | The refused tool | 2 more lamps | Never opens Vale's port (T5). |
| CALM | 1 lamp back, and the next refused request is granted | 30 credits, twice a visit | The only way into Vale's port. |
| Second PRESS | The truth, by breaking the visitor | 2 more lamps (none are checked) | Steady: walks out, no fee, not a right call. Drifting: lunges; stopped, it pays the fee. |
| Code (SAY) | 300 credits from the right courier | free when right, 1 lamp when wrong | Fees alone never reach Harrow's line, by design: with no codes the line is held on 0 % of nights. |
| Typed or spoken line, scripted patient | The same as ASK: the words are matched to a question | as ASK | **[R]** |
| Typed or spoken line, patient AI | A "Says" note under SPEECH and a "Reaction" note under TEMPER | 1 lamp for the first line, later lines free | **[R]** SPEECH is then "reported", not graded, at closing. Not run live since November 15. |
| Re-open a tool already read | Nothing new | no lamp, but it rolls for a surprise | See problem 4a. |

## 4. Measurements

### 4.1 What a night draws [G]

5000 drawn nights, 25,000 visits.

- 40.1 % of visitors are drifting (one a night 25.0 %, two 49.7 %, three 25.3 %).
- A drifting visitor has 2 broken lines (39.7 %), 3 (39.8 %) or 4 (20.5 %). Each line is broken
  for 54 to 57 % of them.
- **Steady visitors with a broken line: 0 of 14,981.**
- An instrument line (EYES, HANDS or PORT) is broken for 95.7 % of drifting visitors. SPEECH or
  TEMPER is broken for 84.4 %. Only SPEECH and TEMPER are broken for 4.3 %; only instrument lines
  for 15.6 %.
- Because there are always two broken lines, no single action is ever the only way to see a
  drift.

### 4.2 Fixed routines on the rules as built [G]

A routine calls Trauma Team on the first broken line it is shown and stamps TREAT otherwise. Both
codes, shutter always in time. "Credits" are a night's total; the line is 2000.

| Routine | Calls right | Drifting found | Lamps a visit | Snaps | Flares | Credits a night | Line held |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Treat everyone | 59.9 % | 0 % | 0.00 | 0 % | 0 % | 918 | 0 % |
| Look only (free) | 74.9 % | 37.3 % | 0.00 | 0 % | 0 % | 1451 | 16.5 % |
| LIGHT only | 83.4 % | 58.6 % | 1.35 | 0 % | 5.6 % | 1826 | 37.2 % |
| PRESS only | 82.8 % | 57.1 % | 2.00 | 0 % | 4.0 % | 1804 | 35.3 % |
| ASK only (the right question) | 82.7 % | 56.9 % | 1.00 | 0 % | 4.0 % | 1800 | 35.3 % |
| ASK and PRESS, no instruments | 93.7 % | 84.4 % | 2.54 | 0 % | 11.3 % | 2225 | 72.1 % |
| **The three instruments** | **98.7 %** | **96.8 %** | **2.47** | 0.3 % | 14.9 % | 2415 | 93.6 % |
| Instruments, CALM instead of insisting | 98.9 % | 97.2 % | 1.76 | 0.9 % | 18.0 % | 2363 | 94.4 % |
| Instruments and ASK | 99.8 % | 99.5 % | 2.99 | 0.4 % | 19.2 % | 2454 | 99.0 % |
| Instruments, ASK and PRESS | 100 % | 100 % | 3.70 | 0.4 % | 23.5 % | 2465 | 100 % |
| PRESS twice on everyone | 40.1 % | 100 % | 5.78 | 0 % | 4.0 % | 1345 | 0.8 % |
| **LIGHT, then re-open it ten times** | **99.2 %** | **98.1 %** | **1.35** | 11.9 % | 48.6 % | 2435 | 96.1 % |
| Instruments, then re-open ten times | 99.98 % | 99.9 % | 2.47 | 1.2 % | 46.3 % | 2464 | 99.9 % |

A steady visitor is never called wrongly by any of these: "steady right" is 100 % in every row
but the last two of the first block, because a broken line never appears on one.

With no codes said, the instruments routine is still right 98.6 % of the time but earns 1811 and
never holds the line. With the shutter in time 9 times of 10, it earns 2340, holds the line on
89.2 % of nights and ends 4.6 % of nights in the doctor's death; "PRESS twice on everyone" then
kills the doctor on 19.6 % of nights.

How the instruments routine's visits end, per 1000 visits: treated and steady 599, handed to
Trauma Team and drifting 286, stopped at the shutter 102, treated and drifting 13. The 102 are
nearly all Dana, Rook and Vale, who lunge when Trauma Team is called.

### 4.3 The best possible player on the rules as built [M]

Credits a visit; 372.9 is what a doctor who knew the truth would earn.

| Tools allowed | Credits a visit | Change | Calls right |
| --- | --- | --- | --- |
| Every tool | 372.9 | | 100 % |
| Without LIGHT, or GRIP, or PORT, or the free look, or ASK, or CALM, or the second PRESS | 372.9 | 0.0 | 100 % |
| Without PRESS | 371.7 | -1.2 | 99.9 % |
| Without ASK and PRESS | 359.4 | -13.5 | 98.3 % |
| Without the three instruments | 324.9 | -48.0 | 93.7 % |
| No examination at all | 74.0 | -298.9 | 49.5 % |

Tighter numbers and no new rule: two lamps fewer for everyone, 372.9 and 100 %; three fewer,
371.9 and 99.9 %; every port behind a cover, 372.9; three lamps fewer and covered ports, 369.7
and 99.6 %. With PRESS made to cost its lamps, taking ASK away costs 4.2 credits a visit.

### 4.4 The fixed test nights [G]

Right calls of five. The pattern is EYES, HANDS, PORT, SPEECH, TEMPER; `-` is a steady visitor.

| Night | Instruments | Instruments, ASK, PRESS | ASK and PRESS only | Look only | Visitors |
| --- | --- | --- | --- | --- | --- |
| A | 5 | 5 | 5 | 3 | kip -, rook -, vale 10111, juno -, maren 11011 |
| B | 5 | 5 | 4 | 4 | maren -, kip 11000, vale -, juno 11101, rook 01110 |
| C | 5 | 5 | 5 | 4 | lux -, bo 11110, dana 11110, ozzie 11110, kip - |
| D | 5 | 5 | 5 | 4 | dana -, priya 11110, ozzie -, lux 11110, kip 00101 |
| E | 4 | 5 | 4 | 2 | bo -, ozzie 10001, juno 00011, maren 10100, priya - |
| F | 5 | 5 | 5 | 2 | vale -, ozzie -, lux 10001, rook 10001, bo 01001 |
| G | 3 | 5 | 5 | 2 | bo -, rook -, priya 00011, dana 01001, juno 00011 |
| H | 5 | 5 | 5 | 3 | rook -, vale 01010, kip 00111, maren -, juno 01010 |

### 4.5 Single visits [G]

From `extras.out`. Each is one visit on the game's rules with the scripted patient.

- **T1. Night C, Bo (11110).** A free look at the open port shows a broken line. Trauma Team:
  right, 320 credits, 6 of 6 lamps unspent, two actions.
- **T2a. Night E, Juno (00011).** LIGHT clean, GRIP clean, port clean, TREAT: minus 400 at
  closing. **T2b.** The same visit with one question (why, 1 lamp): broken SPEECH line, Trauma
  Team, right, 350 credits.
- **T3. Night E, Juno, LIGHT once and then opened again up to ten times.** 200 runs: she turned
  and was stopped at the shutter in 181 (a right call, the fee paid, one lamp spent) after 5.8
  re-openings on average; in 19 she never turned. The same on a steady visitor: nothing happens,
  200 of 200.
- **T4. Night G, Priya (00011).** LIGHT, GRIP by insisting, PORT and one question spend all six
  lamps. PRESS with no lamps left still works and shows the broken TEMPER line. The question she
  was asked (why) could not show her broken SPEECH line, so the closing report would say "you
  did not check" on it.
- **T5. Night A, Vale (10111).** The port is refused three times in a row and takes all five
  lamps. After one CALM it opens and shows a broken line.
- **T6a. Night A, Kip (steady).** PRESS, PRESS: he walks out. No fee, not a right call. **T6b.
  Maren (11011).** PRESS, PRESS: she lunges, the shutter holds, 400 credits. **T6c.** PRESS once
  and Trauma Team: the same 400 credits, no attack, four lamps left.

## 5. The problems

**Problem 1. The sheet says two, the game plays one.** The sheet's footer, HOW TO PLAY and the
card's counter (`CROSSED 1/2`) all say that two broken lines make a drift. In 5000 nights no
steady visitor shows even one (4.1), so the first broken line is always right (T1). A player who
obeys the sheet pays lamps for a second line that changes nothing; a player who notices has
solved the game.

**Problem 2. No tool is needed, so most are never used.** Table 4.3: any one tool can go at no
cost. Table 4.2: the three instruments alone are right 98.7 % of the time. The only visits that
need talk are the 4.3 % of drifting visitors whose broken lines are SPEECH and TEMPER only (T2,
and nights E and G in 4.4). This is exactly what the student said: a player can finish a night
without ASK, PRESS, CALM or a typed line and still reach the calls.

**Problem 3. Examining is free, so there is nothing to weigh.** The instruments routine uses 2.5
of 5 to 7 lamps, and unspent lamps buy nothing. Doing everything costs 3.7 lamps and is right
every time. The surprises do not push back either: a snap that is stopped pays the fee and
counts as a right call, and a flare hands over the TEMPER line for nothing. The design says a
player may decide early; nothing rewards it.

**Problem 4. Loopholes.**

- a. *Re-opening.* A tool that is already read opens again for no lamp, and each opening is an
  action that can make a drifting visitor snap. Stopped at the shutter, that is a right call
  with the fee (T3). One lamp and patience reach 99.2 % (4.2).
- b. *PRESS has no lamp check* (T4). With one lamp left it takes the one; with none it is free.
- c. *CALM opens anything.* It grants the next refused request, even the port that insisting
  never opens, while insisting on that port burns every lamp with no sign that it is hopeless
  (T5).
- d. *Typed lines with the patient AI on* **[R]**. The first line costs a lamp and later lines
  are free; each reply writes a "Says" note under SPEECH and a "Reaction" note under TEMPER; at
  closing SPEECH is reported and not graded. So with the model on, talk is a cheaper ASK and a
  free look at manner, and the report can no longer say whether the SPEECH line was found.
- e. *Codes* **[R]**. A wrong code costs one lamp, and lamps are spare (problem 3), so saying
  both codes to everyone is nearly free. Not measured as a routine.

**Problem 5. Risks that buy nothing.**

- *The second PRESS* is never the best choice (4.3, and section 7). On a steady visitor it
  throws the fee away (T6a). On a drifting one it pays what Trauma Team pays, with an attack
  added (T6b against T6c).
- *Insisting against CALM.* Insisting costs two lamps that are spare, so CALM's 30 credits buy
  nothing: the CALM routine is 0.2 points more often right and 51 credits a night poorer (4.2).
- *Long examinations.* The chance of a snap grows with every action, but a stopped snap is paid
  like a right call. The only real risk is the player's own hand on the shutter.

**Problem 6. The patient AI is decoration.** Under these rules nothing said in talk can change a
call that one instrument reading already settles, and when the model is on, talk is also a
loophole (4d). Section 8 says what talk could be for.

**Problem 7. The closing report tells what was missed, not how to find it.** Each row of the
report shows the line and "you did not check" when it was not shown. For SPEECH that message
also appears when the player did ask a question, but one that cannot show the line (T4), and the
report never names the question or the tool that would have shown it.

**Problem 8. The loudest moments come from one cause.** About one visit in ten ends at the
shutter, but nearly always because Dana, Rook or Vale lunges when Trauma Team is called (4.2).
A visitor who snaps during the examination appears in 0.3 % of visits under the plain routine,
so the other seven visitors' attacks are seen almost only by a player who presses twice or uses
loophole 4a.

## 6. Proposals

Three ways forward, then the recommendation. All numbers for A come from the what-if in
`measure.gd` (the drawn nights with one broken sign composed onto steady visitors; the game is
unchanged) and from the model.

### Proposal A. Two broken lines make a drift (recommended)

- **Target motivation.** Discovery <- the player gathers and weighs evidence under a budget <-
  one broken line is ambiguous, two decide. Fantasy <- being the doctor who tells wear from
  drift.
- **The rule in one sentence.** A steady visitor can carry one broken line, which is only wear;
  two or more make a drift, exactly as the sheet already says.
- **What I measured.** A steady visitor shows one broken line, on any of the five lines, with
  chance q. At q = 0.5:

  | Routine [G] | Calls right | Lamps a visit | Credits a night | Line held |
  | --- | --- | --- | --- | --- |
  | Instruments, call on one broken line (today's habit) | 80.1 % | 2.2 | 1930 | 47.4 % |
  | Instruments only, call on two | 86.2 % | 3.1 | 1931 | 45.3 % |
  | Instruments; on one broken line, ASK only | 93.8 % | 3.4 | 2211 | |
  | Instruments; on one broken line, PRESS only | 94.4 % | 3.6 | 2249 | |
  | Instruments; on one broken line, ASK, then PRESS | 98.0 % | 3.6 | 2382 | 90.4 % |
  | Everything on every visit, with CALM | 100 % | 4.1 | 2391 | 100 % |
  | LIGHT, then re-open ten times (loophole 4a) | 97.5 % | 1.4 | 2367 | |

  | Best possible player [M], q = 0.5 | Credits a visit | Change | Calls right |
  | --- | --- | --- | --- |
  | Every tool | 368.0 | | 100 % |
  | Without LIGHT | 318.9 | -49.1 | 93.5 % |
  | Without GRIP | 318.7 | -49.3 | 93.1 % |
  | Without PORT | 325.5 | -42.5 | 94.2 % |
  | Without ASK | 321.0 | -47.0 | 93.8 % |
  | Without PRESS | 319.0 | -49.0 | 93.3 % |
  | Without ASK and PRESS | 268.9 | -99.1 | 81.1 % |
  | Without the three instruments | 280.2 | -87.8 | 81.8 % |
  | Without CALM | 346.9 | -21.1 | 96.7 % |

  Under best play the lines are read on 93 % (EYES), 79 % (HANDS), 81 % (SPEECH) and 48 %
  (TEMPER) of visits, and CALM is bought on 16 %. The picture is the same at q = 0.3 and 0.7
  (ASK and PRESS are each worth 44 to 49 credits a visit).
- **What it changes, action by action.**
  - *LOOK and the instruments.* A first broken line is a lead. After the three instruments, 44 %
    of visits show nothing wrong (4 % of those are drifting), 32 % show one broken line (44 % of
    those are drifting: close to a coin) and 24 % show two or three (all drifting) **[A]**.
    Example: Bo's open port in T1 no longer ends the visit.
  - *ASK* is the cheap second opinion. After one broken instrument line, a clean answer takes
    the chance of a drift from 44 % to 22 % **[A]**. Example T7c: Juno (01011), GRIP broken, one
    question, second broken line, Trauma Team with three lamps left.
  - *PRESS* is the expensive closer. After one broken line and a clean answer, the TEMPER line
    settles it for certain, because a drift has to have a second line somewhere **[A]**. Example
    T7b: Bo, steady, with worn hands: the question is clean, PRESS is clean, TREAT is right, no
    lamp left.
  - *CALM* buys the lamp that makes the closer affordable, or a refused tool without the
    two-lamp fight. Reading all five lines costs 7 or 8 lamps of 5 or 6 for Bo, Dana, Priya,
    Rook and Vale, so for them it is CALM or a guess.
  - *Deciding early* becomes a gamble with a known price. At the mean fee, calling is the better
    guess when a drift is more than 40 % likely **[A]**.
  - *Codes.* A wrong code's lamp now costs something.
- **How a player learns it before it can hurt.** The sheet's footer already says it ("Two broken
  lines = drifting", "Strange is not sick") and so does the card's counter. Add one point to THE
  JOB in HOW TO PLAY ("One broken line can be wear. Two is a drift."), one guide line the first
  time a single broken line stands alone, and no wear on the first visitor of the first night.
  Both languages.
- **Right or wrong only at closing.** Nothing new is told during the night. It removes a quiet
  leak: today a broken line is a certain verdict in the middle of the visit. The closing report
  needs one new wording, for a steady visitor's broken line ("broken: wear, one line is not a
  drift").
- **Cost to build.** `shift_state.gd` (`draw_night`: wear on steady visitors, with a chance and
  row weights from `rules.json`), `rules.json` (the `night` block, version 11), `case_db.gd`
  (validation and `night_coverage`), `nights.json` (wear on some fixed nights, with every sign
  and every worn line still covered), the closing report row, HOW TO PLAY and the guide in both
  languages, rules tests and the smoke test. No new art: composing a steady visitor with a
  broken part already works in the rules (T7a), though nobody has looked at one drawn.
- **Risks.** It does not turn a visit into a puzzle on its own: reading everything is still
  always right when the lamps reach (4.1 lamps with CALM), so the lamps and CALM's price are the
  tuning. One lamp fewer for everyone brings best play to 99.5 % and CALM to 29 % of visits; two
  fewer, 97.3 % and 38 % **[M]**. I would ship the rule with the lamps as they are, because a
  person reads worse than the computed player, and tune after the first real playtest. A player
  with today's habit makes false calls (80.1 %), so the guide line matters. Visits get about one
  action longer. All of it is untried by a person **[U]**.

### Proposal B. The patient holds the keys

- **Target motivation.** Fantasy <- the player works on a person to get access <- every tool
  needs the patient's yes, and talk earns it.
- **The rule in one sentence.** A tool opens when the patient agrees; talk can earn the yes, and
  insisting or CALM buys it.
- **What it changes.** Talk matters on every visit, which gives the patient AI a job. But one
  broken line still proves a drift, so the tools stay interchangeable and problem 1 stands.
- **Learning and leaks.** A new trust state has to be shown and explained. Nothing leaks.
- **Cost and risks.** High. The scripted patient needs an authored trust model for ten
  characters in two languages, and the model's yes or no has to be shown to be fair. Talk risks
  becoming the mandatory first step, which the agreed design forbids, and it is the kind of
  layered system the student has found dull. A small piece of it is kept in the patient-AI
  design: how the doctor has spoken may count when the patient is first asked for a tool, and
  an evaluation checks that this stays fair.

### Proposal C. Tighten the numbers

- **Target motivation.** Sensation <- pressure <- fewer lamps, covered ports, dearer tools.
- **The rule in one sentence.** No new rule; less patience.
- **What it changes.** Almost nothing. With two lamps fewer the best player is still right every
  time, and with three fewer and every port covered, 99.6 % (4.3). One reading still decides, so
  less patience only produces more visits that end in "out of patience".
- **Cost and risks.** Cheapest to build, and it does not answer the student's point.

### Recommendation

**A, with the loophole fixes of section 9.** It is one sentence, it is already printed on the
sheet, it needs no new art, and it is the only one of the three that makes every tool decide
calls. B can follow later as a small layer if the student wants talk to carry more. C is only
useful as the tuning step inside A.

## 7. The second PRESS

The student's idea (November 21): tell the player up front that a second PRESS may make a
drifting visitor go berserk and may make a steady one leave, each by chance; and the student's
own doubt, that the payoff then looks too small.

The doubt is right, and it applies to the rule as built too.

- **As built (sure).** On a steady visitor the second PRESS throws the fee away; on a drifting
  one it pays exactly what Trauma Team pays, plus an attack (T6). The best player never uses it,
  under today's rules or under proposal A **[M]**.
- **By chance.** The price is the same (two lamps, the fee at stake, the shutter) and the answer
  comes only some of the time. At 50/50, 70/30 and 30/30 the best player never uses it **[M]**.
  A chance version is the sure version watered down.
- **A cheap sure test** (the steady visitor complains but stays) would be used on a third of
  visits and would push the other tools out **[M]**. Rejected.

What is missing is a reward. My recommendation:

1. **Keep it sure**, and say so on the pad before the second push: "PRESS AGAIN: they break. The
   drifting lunge. The steady walk out."
2. **Pay for the catch.** A drifting visitor broken by the second PRESS and stopped at the
   shutter pays the fee and a catch bonus (150 is the number I tried). Only this cause pays it,
   not a snap during the examination and not a lunge at Trauma Team, so nothing rewards
   provoking attacks by other means. The first PRESS already reads TEMPER, so the play becomes:
   press once to read, press again to break the one you are sure of.
3. **Make the risk real.** With a shutter that never misses, a bonus of 150 makes breaking the
   standard ending for every drifting visitor (368 to 428 credits a visit). With the shutter in
   time 9 times of 10 it is a real choice: the best player breaks 14 % of visitors and calls
   Trauma Team on 26 % **[M]**. Nobody knows how often a person makes the shutter **[U]**, so
   the bonus and the attack window after a break (perhaps shorter than 1800 ms) have to be tuned
   on real play.

It also gives spare lamps a use: a break costs four lamps, so a doctor who wants the bonus has
to examine with less.

If the student would rather not add a bonus, the simple alternative is **one PRESS a visit**:
the pad goes dark after the first. The model's best player loses nothing.

## 8. What talking is for (the brief's question 5)

- **Today** talk can change nothing that ASK cannot, and with the patient AI on it is cheaper
  than ASK and ungraded (problem 4d).
- **Should a typed provocation count as pressure?** Only when the player sends it through the
  PRESS pad. If the game guessed from the words that the player was provoking, it would charge
  lamps and risk an attack without a warning or a key, and a model would be choosing a rule
  outcome.
- **What free talk should be for.** The same actions in the player's own words, at the same
  price and with the same proof, so that the game plays by one set of rules with the scripted
  patient and with the model; and beyond that, the things only a model can do: answer anything
  in character, hold tonight's manner through follow-up questions in the player's own words,
  and speak first. The design is in `docs/development/patient-agent-handoff/`.

Under proposal A talk gains weight with no extra rule: a patient with one broken line always has
a story for it, the story proves nothing, and the second line decides.

## 9. Fixes worth making whatever the pick

These change rules, so each needs the student's yes. None is built.

1. **Re-opening a tool that is already read rolls no surprise** (4a). Only actions that cost a
   lamp or a CALM should count toward a snap.
2. **PRESS needs its lamps**, like every other action (4b).
3. **A refusal that insisting cannot move says so**, or CALM stops opening it (4c).
4. **Typed lines with the patient AI on follow the ASK rule**: same price, same proof, and the
   SPEECH line is graded at closing again (4d; section 8).
5. **The closing report names what would have shown a missed line** ("SPEECH: broken. Asking
   about sleep shows it; you asked why they came."), and says "asked, but not about this"
   instead of "you did not check" (problem 7). This teaches at closing and leaks nothing.

## 10. Learning (the brief's question 6)

- The report teaches which line was missed and, with fix 5, how to find it next time.
- During the night, the card's own counter and the sheet's footer can teach the house rule only
  if the rule is true (proposal A). Today they teach a rule the game does not play by.
- A usage line on the totals page ("LIGHT 5, GRIP 4, ASK 0, PRESS 0, CALM 0") would show a
  player, at closing, which tools they never touched. It leaks nothing.

## 11. Questions for the student

1. **The rule.** A (two lines, recommended), B (the patient holds the keys), C (tighter
   numbers), or keep the rules as built?
2. **The second PRESS.** Sure, warned and paid for the catch (recommended), one PRESS a visit,
   or as built?
3. **The five fixes of section 9.** All, some or none? My default is all five.
4. **Typed talk.** The same price and proof as ASK (my default, and the base of the patient-AI
   design), or something else?

## 12. What this review does not show

- How a person plays. Reading mistakes, hesitation, the shutter and enjoyment are all unknown.
- The patient AI live. Nothing here ran a model.
- Balance. Every number in the proposals is a starting point for tuning, not a tuned value.
