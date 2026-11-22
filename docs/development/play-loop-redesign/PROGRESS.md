# Play loop redesign: progress

Codex keeps this file during the run described in [KICKOFF.md](KICKOFF.md). The design is [01-design.md](01-design.md).

Status on November 21, 2026: M1 verified. M0 tagged 31c8dbd as loop-v12.

## Milestones

- [x] M0 Baseline (counts written, tag `loop-v12`, pointers in `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `docs/README.md`)
- [x] M1 Rules and data (rules version 13, complaints, nights K and L, R1 to R11 measured)
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

Vale's v12 sign sampler weighted port outside its first two picks. Preserving that distribution while opening every test reproduced the v12 seed fixture byte-for-byte. Some random second visitors have no fair authored clue pair. On a teaching night only, the desk swaps in the next eligible courier for that slot; every visitor keeps their truth, wear and signs. Fixed K and L already put a fair courier second.

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

M1, November 21: 5,929 engine rules; 1,155 / 1,156 / 1,155 scene checks; 57 proxy, 9 guard/evaluation; 352 game HTTP / 102 wire; 1,608 width checks and 281 hidden frames per language. Fixed A completed 24 checks in each of scripted, mock and forced-timeout fallback. Sources: `M1/`, `M1retry/`. The earlier seed fixture and v13 file have identical SHA-256.

Replaced v12 scenarios: free LOOK evidence → selecting an instrument with no evidence; refusal, INSIST, sealed port and CALM → first reactions always admitting each tool; per-case patience, paid or dodged ASK and price confirmation → two lamps, free answers and harmless text; second PRESS lamp requirement → warned BREAK at zero; v12 numbers in credit and glass scenarios → 50 bonus; idle lamp restoration → paused 30-second departure; first-slot courier and fourteen-tip lesson → second-slot courier. The old captures of these paths are preserved in the baseline. Fixed K/L and 235 weapon/attack frames now cover the redesigned counter. The speech-confirmation and typed-PRESS wire steps were replaced by free dispatch and button-only pressure. M0 commit `a351a21`; M1 commit titled *Build the two-lamp visit and measure complaint-guided play*.

## The relations

Source of every figure: the engine, with the date and the number of visits. The scratch values are from `validation/2026-11-21/play-loop-scratch/`, which is not the engine.

| | Relation | Scratch | Engine | Held |
| --- | --- | --- | --- | --- |
| R1 | Guidance pays: best plain call with complaints at least 5 points above without | 90.3 / 83.0 | 90.183 / 83.044% | held |
| R2 | Talking pays: never talking at least 7 points under best play | 82.0 / 91.6 | 82.575 / 92.073% | held |
| R3 | Testing pays: talk only at most 80 % and at least 10 points under the routine | 76.4 / 89.0 | 76.727 / 88.817% | held |
| R4 | The routine is 86 % to 93 % right | 89.0 | 88.817% | held |
| R5 | One-cross endings 25 % to 35 % of visits, 25 % to 45 % of them drifting | 30.8, 34.3 | 31.024 / 34.512% | held |
| R6 | Two crosses: TRAUMA TEAM at least BREAK with a 90 % shutter, every fee | 220/213, 400/375, 600/555 | 220/213, 400/375, 600/555 credits | held |
| R7 | One cross: BREAK at least TRAUMA TEAM; above TREAT at the lowest fee, below at the highest | see design | 220: 6.03 / -22.31 / 73.51; 600: 254.88 / 108.84 / 191.54 credits | held |
| R8 | Each test is worth at least 1 point and is first in at least 10 % of visits | not modelled | eyes: −1.57 pp, 25.22% first, hands: −1.55 pp, 25.08% first, port: −1.41 pp, 24.75% first, temper: −1.57 pp, 24.96% first | held |
| R9 | TREAT, TRAUMA TEAM or BREAK for everyone earns at most 60 % of the routine | 0, 125, 187 / 312 | −13.58 / 111.37 / 175.24 vs 304.11 credits | held |
| R10 | A drifting visitor turns before the call in 10 % to 20 % of visits; never after talk or a code | about 17 % | 12.468% of drift; 7.433% flare across all; zero rolls on speech or codes | held |
| R11 | The line with no, one and two drops; a blind code worth less than a matched one | not modelled | 0 / 68.092 / 68.092%; blind 1300.25, matched 2189.99 credits/night | held |

Engine, November 21. `tools/eval/measure_loop.gd` drove 25,000 five-person nights, seeds 1–25,000. Relations R1–R10 analyze the 100,000 later visits. R11 includes all 125,000 visits. `tools/eval/analyze_loop.py` enumerates credit-optimal decisions on the empirical patient/sign prior, and compares the ordinary routines on identical draws. C's diagnostic accuracy before surprises was 88.817%, rising to 91.093% with the actual snaps, flares and a perfect shutter. R6–R7 use a 90% shutter. At two certain crosses, Dana, Rook and Vale attack on either call. A caught BREAK adds 50 credits, worth 45 in expectation at 90%. The one/two-drop rates coincide because a missed drift costs more than the second drop in these seeded nights. The blind routine tries both codes until matched or out of lamps. It receives the same drop income, loses tests and scores less. Evidence: `validation/2026-11-21/play-loop/relations-final.json` and `visits-final.csv`.

All relations held at the starting settings: complaints 0.65 / 0.20, catch 50, snap 0 / 0.06 / 0.18, idle 30,000 ms and line 400 per hour.

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
