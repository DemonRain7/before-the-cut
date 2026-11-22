# Play loop redesign: progress

Codex keeps this file during the run described in [KICKOFF.md](KICKOFF.md). The design is [01-design.md](01-design.md).

Status on November 21, 2026: M0 verified against 31c8dbd (loop-v12).

## Milestones

- [x] M0 Baseline (counts written, tag `loop-v12`, pointers in `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `docs/README.md`)
- [ ] M1 Rules and data (rules version 13, complaints, nights K and L, R1 to R11 measured)
- [ ] M2 Screen and input (three groups, "?" tags, marks in the close-up, BREAK state, free typed questions)
- [ ] M3 Teaching and words (tips, HOW TO PLAY, guide, KEYS, closing report, both languages)
- [ ] M4 The generated patient, protocol 5 (`complaint` class, voiced complaints, prompt rules, mock fixtures)
- [ ] M5 Evidence (final tables, captures, live evaluation and redeploy if approved, acceptance sheet)
- [ ] M6 Handoff (`HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `AGENTS.md`, last report)

For each ticked milestone: the commit, the date, and one line on what it holds.

## What the student's message approved

Deployment: yes. Once protocol 5 is green, redeploy the three existing Workers one time: mock, forced-timeout, and live kept disabled by its kill switch.

Paid model calls: yes. OpenAI GPT-6 Luna, at most 400 requests, total cost ceiling USD 5, only for the slim evaluation L1 to L5 in M5.

## Decisions taken by default

D1–D12 as written. Two lamps, free speech, authored clues, all tests granted, free BREAK, 50 bonus, 30 idle seconds, training contact second, test-only surprises, staged teaching, dated handoff, milestone pushes.

## Where the design was wrong

One line each: what the design said, what the code or the measurement showed, what was done.

## Needs the student

Steps skipped for want of the student's own yes, and anything only the student can settle.

## Counts

| Check | Baseline (version 12) | After |
| --- | --- | --- |
| Rule tests | 2,099 | |
| Scene tests, English / Chinese / less blood | 1,247 / 1,248 / 1,247 | |
| Proxy tests | 57 + 9 guard/evaluation | |
| Godot HTTP / wire | 354 / 102 | |
| Lines and drawn frames per language | 1,624 / 464 | |

M0 source, November 21: local engine, hidden desktop, Node mock and check logs under `validation/2026-11-21/play-loop/M0/`. All 23 groups green, six appointments and 24 mock checkpoint replies. Seed comparison fixture covers 5,120 v12 visitors.

Removed tests, each with the rule that removed it:

## The relations

Source of every figure: the engine, with the date and the number of visits. The scratch values are from `validation/2026-11-21/play-loop-scratch/`, which is not the engine.

| | Relation | Scratch | Engine | Held |
| --- | --- | --- | --- | --- |
| R1 | Guidance pays: best plain call with complaints at least 5 points above without | 90.3 / 83.0 | | |
| R2 | Talking pays: never talking at least 7 points under best play | 82.0 / 91.6 | | |
| R3 | Testing pays: talk only at most 80 % and at least 10 points under the routine | 76.4 / 89.0 | | |
| R4 | The routine is 86 % to 93 % right | 89.0 | | |
| R5 | One-cross endings 25 % to 35 % of visits, 25 % to 45 % of them drifting | 30.8, 34.3 | | |
| R6 | Two crosses: TRAUMA TEAM at least BREAK with a 90 % shutter, every fee | 220/213, 400/375, 600/555 | | |
| R7 | One cross: BREAK at least TRAUMA TEAM; above TREAT at the lowest fee, below at the highest | see design | | |
| R8 | Each test is worth at least 1 point and is first in at least 10 % of visits | not modelled | | |
| R9 | TREAT, TRAUMA TEAM or BREAK for everyone earns at most 60 % of the routine | 0, 125, 187 / 312 | | |
| R10 | A drifting visitor turns before the call in 10 % to 20 % of visits; never after talk or a code | about 17 % | | |
| R11 | The line with no, one and two drops; a blind code worth less than a matched one | not modelled | | |

Final numbers in `rules.json`: complaints broken / normal, catch bonus, snap grace / step / max, leave wait, line per hour.

## The live evaluation

Only if approved. Provider, model, requests used, conservative cost. L1 to L5 with targets and results.

## Acceptance sheet for the student (ten minutes)

Write the exact commands once nights K and L exist. The student checks, in Chinese and then once with the mock patient:

1. The first visitor shows at most seven tips and each asks for one action.
2. Asking what is wrong puts a "?" on a card row and on that row's test.
3. Two lamps. Talking, typing and speaking never take one.
4. A test shows its reading with the sheet line beside it and a tick and a cross.
5. CALM, INSIST and the "YOUR MEANING" menu are nowhere.
6. BREAK warns first and names SPACE.
7. With no lamp left the visitor waits, visibly, and the wait stops while a paper is open.
8. The closing report says what each row really was and how many complaints were followed.
9. With the mock patient, a typed "哪里不舒服" and a typed question about one part both bring the complaint.

Whatever the student marks wrong goes under "Needs the student" with their words.
