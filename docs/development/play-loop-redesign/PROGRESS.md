# Play loop redesign: progress

Codex keeps this file during the run described in [KICKOFF.md](KICKOFF.md). The design is [01-design.md](01-design.md).

Status on November 21, 2026: M0–M6 complete and verified. M0 tagged 31c8dbd as loop-v12.

## Milestones

- [x] M0 Baseline (counts written, tag `loop-v12`, pointers in `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `docs/README.md`)
- [x] M1 Rules and data (rules version 13, complaints, nights K and L, R1 to R11 measured)
- [x] M2 Screen and input (three groups, "?" tags, marks in the close-up, BREAK state, free typed questions)
- [x] M3 Teaching and words (tips, HOW TO PLAY, guide, KEYS, closing report, both languages)
- [x] M4 The generated patient, protocol 5 (`complaint` class, voiced complaints, prompt rules, mock fixtures)
- [x] M5 Evidence (final tables, captures, live evaluation and redeploy if approved, acceptance sheet)
- [x] M6 Handoff (`HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `AGENTS.md`, last report)

All seven releases are on main. November 21 (New York): M0 `a351a21`, M1 `37c90b8`, M2 `526c469`, M3 `31aec41`, M4 `f8bccdf`, M5 `5cdaece`. M6 is the commit titled *Hand off the verified two-lamp counter*.

## What the student's message approved

Deployment: yes. Once protocol 5 is green, redeploy the three existing Workers one time: mock, forced-timeout, and live kept disabled by its kill switch.

Paid model calls: yes. OpenAI GPT-6 Luna, at most 400 requests, total cost ceiling USD 5, only for the slim evaluation L1 to L5 in M5.

## Decisions taken by default

D1–D12 as written. Two lamps, free speech, authored clues, all tests granted, free BREAK, 50 bonus, 30 idle seconds, training contact second, test-only surprises, staged teaching, dated handoff, milestone pushes.

## Where the design was wrong

Vale's v12 sign sampler weighted port outside its first two picks. Preserving that distribution while opening every test reproduced the v12 seed fixture byte-for-byte. Some random second visitors have no fair authored clue pair. On a teaching night only, the desk swaps in the next eligible courier for that slot; every visitor keeps their truth, wear and signs. Fixed K and L already put a fair courier second.

## Needs the student

The remaining evidence needs people at the counter. Try the ten-minute sheet and observe outside players on fixed nights K and L. The E6 sheet pairs the scripted patient with the live service and records the next test after each complaint. A separate human-session budget would be needed for paid human play. No external human play, microphone or IME observations were collected in this build.

## Counts

| Check | Baseline (version 12) | After |
| --- | --- | --- |
| Rule tests | 2,099 | 5,929 |
| Scene tests, English / Chinese / less blood | 1,247 / 1,248 / 1,247 | 1,172 / 1,173 / 1,172 |
| Proxy tests | 57 + 9 guard/evaluation | 62 + 10 guard/evaluation |
| Godot HTTP / wire | 354 / 102 | 352 / 102 |
| Lines and drawn frames per language | 1,624 / 464 | 1,597 / 281 |

M0 source, November 21: local engine, hidden desktop, Node mock and check logs under `validation/2026-11-21/play-loop/M0/`. All 23 groups green, six appointments and 24 mock checkpoint replies. Seed comparison fixture covers 5,120 v12 visitors.

M1, November 21: 5,929 engine rules; 1,155 / 1,156 / 1,155 scene checks; 57 proxy; 352 game HTTP / 102 wire; 1,608 width checks and 281 hidden frames per language. Fixed A completed 24 checks in each of scripted, mock and forced-timeout fallback. Sources: `M1/`, `M1retry/`. The earlier seed fixture and v13 file have identical SHA-256.

Replaced v12 scenarios: free LOOK evidence → selecting an instrument with no evidence; refusal, INSIST, sealed port and CALM → first reactions always admitting each tool; per-case patience, paid or dodged ASK and price confirmation → two lamps, free answers and harmless text; second PRESS lamp requirement → warned BREAK at zero; v12 numbers in credit and glass scenarios → 50 bonus; idle lamp restoration → paused 30-second departure; first-slot courier and fourteen-tip lesson → second-slot courier. The old captures of these paths are preserved in the baseline. Fixed K/L and 235 weapon/attack frames now cover the redesigned counter. The speech-confirmation and typed-PRESS wire steps were replaced by free dispatch and button-only pressure. M0 commit `a351a21`; M1 commit titled *Build the two-lamp visit and measure complaint-guided play*.

M2, November 21. Commit *Group the counter around free talk and two marked tests*. The engine passed 5,929 rules, 1,162 / 1,163 / 1,162 scene checks and 352 HTTP / 102 wire checks. The proxy retained 57 passing tests. Each language passed 1,608 fitted lines and produced 281 hidden-desktop frames including all five visits of K and L. Night K passed 32 checks through each of script, mock and forced timeout. The general conversation fixture now asks about looking away, since the former hand question legitimately asks about a body part. Sources: `M2/`, `M2release/`. M1 commit `37c90b8`.

M3, November 21. Commit *Teach one action at a time across the first two visitors*. The bilingual scene test walked seven first-visitor tips, then the warning and three courier actions. Counts: 5,929 rules, 1,172 / 1,173 / 1,172 scenes, 57 proxy, 352 / 102 HTTP and wire, 1,603 fitted lines and 281 hidden frames per language. The five replaced training strings account for the width-count change. The closing report totals the patient complaints that prompted the next test. Sources: `M3release/` and the `M3/checkpoint/` mock run. M2 commit `526c469`.

M4, November 21. Commit *Voice only delivered complaints through patient protocol five*. The protocol-5 service has 59 passing proxy tests. The game passed 5,929 rules, 1,172 / 1,173 / 1,172 scenes, 352 HTTP / 102 wire, 1,603 fitted lines per language and 281 frames per language. Tests cover the old protocol-4 endpoint with a labelled fallback, both languages across all ten character prompts, and rejecting medical consent overrides. Night K passed 35 scene checks in each of script, mock and forced-timeout, including chip, typed general and typed part. Mock checkpoint: 24 replies across six isolated appointments. Sources: `M4release/` and `M4/checkpoint/`. M3 commit `31aec41`.

M5, November 21. Commit *Verify the slim patient evaluation and publish protocol five*. M4 commit `f8bccdf`. A launch check through `run-game.ps1` caught an outdated protocol-4 check. The real launcher now obtains its version from the same rules used in Godot. The mock launcher passed six checks and the forced-timeout launcher seven, including a labelled fallback after one timed-out classifier and zero dialogue retries. Night K passed 38 checks in each of the three modes. All 80 authored part sentences pass the production wording validation. The HOW TO PLAY lamp diagram and PRESS hover now show the two-lamp rules. Superseded CALM strings account for the last six text-width entries removed. See `M5final/`, `M5/checkpoint/`, `M5-modes.log` and `launcher-*-final.log` within the dated evidence folder.

Correction to the earlier milestone counts. The independent paid-session guard passed. One assertion in the accompanying **historical E4 corpus** suite expected 58 rude controls but enumerated 60 after Vale's port became available. This was missed in M1–M4. The old 174-case corpus is now explicit, independent of current gameplay. All ten guard/evaluation checks, including the new 400-call/5-dollar budget regression, passed at M5. The historical E-series and November 15 paid ledgers stayed closed.

M6, November 21. Updated the current rules, agent contract, play instructions, release handoff and next three tasks. During acceptance a bare body-part name such as “Eyes.” or “眼睛。” was found to need a local row match even when the router chose ordinary conversation. The client now uses the sheet vocabulary in both languages, including short Chinese part names. The seven first-visitor training tips now suppress incidental duplicate coaching. The final fixed K run passed 42 checks in each of script, mock and forced-timeout modes. The standalone Godot import crashed once on an earlier disposable copy. Two subsequent clean imports passed. All 23 final check groups passed, along with the ten guard checks and the independent six-appointment mock checkpoint. See `M6verified/`, `M6verified-guard.log` and `M6verified-modes.log`. The client refinements affect no Worker or paid request.

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
| R7 | One cross: BREAK at least TRAUMA TEAM; above TREAT at the lowest fee, below at the highest | 220: 7.3 / −23.0 / 73.1; 600: 256.9 / 107.3 / 190.4 | 220: 6.03 / -22.31 / 73.51; 600: 254.88 / 108.84 / 191.54 credits | held |
| R8 | Each test is worth at least 1 point and is first in at least 10 % of visits | not modelled | eyes: −1.57 pp, 25.22% first, hands: −1.55 pp, 25.08% first, port: −1.41 pp, 24.75% first, temper: −1.57 pp, 24.96% first | held |
| R9 | TREAT, TRAUMA TEAM or BREAK for everyone earns at most 60 % of the routine | 0, 125, 187 / 312 | −13.58 / 111.37 / 175.24 vs 304.11 credits | held |
| R10 | A drifting visitor turns before the call in 10 % to 20 % of visits; never after talk or a code | about 17 % | 12.468% of drift; 7.433% flare across all; zero rolls on speech or codes | held |
| R11 | The line with no, one and two drops; a blind code worth less than a matched one | not modelled | 0 / 68.092 / 68.092%; blind 1300.25, matched 2189.99 credits/night | held |

Engine, November 21. `tools/eval/measure_loop.gd` drove 25,000 five-person nights, seeds 1–25,000. Relations R1–R10 analyze the 100,000 later visits. R11 includes all 125,000 visits. `tools/eval/analyze_loop.py` enumerates credit-optimal decisions on the empirical patient/sign prior, and compares the ordinary routines on identical draws. C's diagnostic accuracy before surprises was 88.817%, rising to 91.093% with the actual snaps, flares and a perfect shutter. R6–R7 use a 90% shutter. At two certain crosses, Dana, Rook and Vale attack on either call. A caught BREAK adds 50 credits, worth 45 in expectation at 90%. The one/two-drop rates coincide because a missed drift costs more than the second drop in these seeded nights. The blind routine tries both codes until matched or out of lamps. It receives the same drop income, loses tests and scores less. Evidence: `validation/2026-11-21/play-loop/relations-final.json` and `visits-final.csv`.

All relations held at the starting settings: complaints 0.65 / 0.20, catch 50, snap 0 / 0.06 / 0.18, idle 30,000 ms and line 400 per hour.

## The live evaluation

November 21, 2026 (New York). All 400 requests returned HTTP 200 through the game's local HTTP service with OpenAI GPT-6 Luna and standard processing. L1–L3 used the intent route; L4–L5 used dialogue. These were the only paid requests. There were no judges, retries or transcriptions. Source: `validation/2026-11-21/play-loop/slim-live/results.json` and its category-only ledger, produced by `tools/eval/slim.mjs`. The standard-rate estimate is USD 0.0293384 from 232,022 input and 11,021 output tokens, including 25,028 reported cache-write and zero reported cache-read tokens. All responses reported usage. The independent upper reservation was USD 1.0216562 against the approved USD 5. This estimate is separate from a provider invoice. [OpenAI GPT-6 Luna pricing](https://developers.openai.com/api/docs/models/gpt-6-luna)

| Probe | Target | Live result | English / Chinese passing |
| --- | --- | --- | --- |
| L1 Listed paraphrases | At most 15% wrong or missed | 118/120 correct, 1.67% missed or wrong | 58/60, 60/60 |
| L2 Complaint questions | At least 85% recognized | 79/80, 98.75% | 40/40, 39/40 |
| L3 Social controls | At most 10% false matches | 0/80 false matches | 40/40, 40/40 |
| L4 Voiced complaints | At least 95% name the part, zero test results | 77/80, 96.25%. Zero stated test results detected | 37/40, 40/40 |
| L5 Health-related social talk | At most 5% invent a tested-row symptom | 0/40 flagged | 20/20, 20/20 |

Intent latency was 764 ms median and 968 ms at p90. Dialogue was 1,370 ms median and 1,754 ms at p90. L4 and L5 used a bilingual phrase screen. After these measurements the same part-name and test-result checks were added to the complaint response validator. A rejected complaint uses the authored sentence without a second call. The three unclear live replies remain counted as misses. Generated complaint voice remains on when connected to a live provider. Graded ASK remains authored. The new response guard was checked with local fixtures after the paid ledger closed.

## Deployed services

November 21, Cloudflare. Each existing Worker received exactly one deployment after local protocol-5 checks. All three health checks returned version 5 and the full ten-case roster. Rows below link to the Workers that were actually probed. Source: `validation/2026-11-21/play-loop/workers/deploy.json` and `public-checks.json`.

| Worker | Version | Public check |
| --- | --- | --- |
| [default](https://before-the-cut-agent.demonrain777.workers.dev/healthz) | `c28e9a18-81bc-4400-98cd-682af32341f2` | 24 replies across six mock visits, repeat-visit isolation, bilingual complaint routing and authored delivery |
| [timeout](https://before-the-cut-agent-timeout.demonrain777.workers.dev/healthz) | `7d4dcdd8-0588-415e-9038-4c39f0a109ea` | 504 upstream_timeout on the forced synthetic request |
| [live](https://before-the-cut-agent-live.demonrain777.workers.dev/healthz) | `d87686aa-f9c7-42cb-80a6-9dfb9e9ad6b0` | Kill switch on. Dialogue returned 503 service_disabled. Zero paid requests on this Worker |


## Acceptance sheet for the student (ten minutes)

From the repository root in PowerShell, launch one command at a time. Use the first five minutes for K's first two visitors. Ask what hurts, test the tagged part, mark the close-up, and open the card. On the second visitor compare both contact clues. In the second five minutes repeat with mock or take L through the one-cross and BREAK decisions. Use F10 to return to the title. All three commands are free.

```powershell
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient mock -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight L
```

The student can check these nine observations:

1. The first visitor shows at most seven tips and each asks for one action.
2. Asking what is wrong puts a "?" on a card row and on that row's test.
3. Two lamps. Talking, typing and speaking never take one.
4. A test shows its reading with the sheet line beside it and a tick and a cross.
5. CALM, INSIST and the "YOUR MEANING" menu are nowhere.
6. BREAK warns first and names SPACE.
7. With no lamp left the visitor waits, visibly, and the wait stops while a paper is open.
8. The closing report says what each row really was and how many complaints were followed.
9. With the mock patient, a typed "哪里不舒服" and a typed question about one part both bring the complaint.

Record the visitor, the action and what happened. Capture evidence for both K and L is in the M5final frames-en and frames-zh directories; the numbered sequence reaches both closing reports.
