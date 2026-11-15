**Current student decision, November 14: autonomous patient dialogue.** The AI uses the patient's background, personality, motives and conversation history to decide what to say and how to react. It generates original responses; it is not restricted to a legal-move list, authored answer bank or fixed dialogue tree. Technical format, length and timeout checks do not select its answer. The earlier enum-constrained protocol is superseded; protocol 3 is now implemented locally and verified with mocks only.

AI use: Claude drafted the initial plan. Codex updated the implementation status, risks and G1 package on 2026-11-12. Hour estimates remain provisional and final student review is pending.

# Before the Cut: Initial Project Plan and Initial Risk Register

Version 0.7, G1 Concept, 2026-11-14. Schedule updated from the corrected announcement supplied by the student. One student, directing coding agents as Executive Producer and Creative Director. The G1 assignment permits this repository document as the Initial Project Plan. It moves into Asana after G1, with owners, acceptance criteria, dependencies and the full Risk Register developed at G2/G3. Asana is not set up yet.

**Repository status, November 14:** this public repository contains the required G1 documents and shared production-agent briefs. The active development workspace has a newer five-patient Godot prototype and protocol-3 dialogue integration. Runtime source transfer is still pending; this submission does not claim the repository already contains a runnable build. G1 proposes a three-patient evaluation slice, not a commitment to add more content.

## 1. Where the project stands on November 14

- **Student decisions:** individual project; clinic counter; Godot 4 / 2D pixel art; a normal reference sheet; optional unordered appearance, action and dialogue methods; autonomous patient replies; Call Trauma Team as the proposed second decision.
- **Local build:** five-patient development shift with the revised guide/tool loop; three patients remain the proposed evaluation scope in the pitch.
- **Current verification:** 260 game/agent assertions, 246 UI assertions, 18 proxy tests and 49 real-client/scene mock checks passed. These are automated checks only.
- **Pending:** Trauma Team runtime wording, live model quality/cost/latency, outside playtest, deployment, standalone export and source transfer to this repository.
- **Submission:** the student recorded the nine-slide pitch. Final recording duration and upload are being audited. The main CourseWorks post has not been submitted.

Hour estimates are provisional; the student's available weekly hours are unknown and they are new to Godot.

## 2. Phase dates

All times are New York time. The G1 assignment (discussion 1701307) was checked in authenticated Chrome on 2026-11-13; the student supplied the corrected announcement (1701304) on 2026-11-14. Together they define the current G1 checklist. The correction makes the G1 pitch the only submission due before Monday's class and sets two self-selected Braintrust replies for Thursday, November 19, 23:59. The earlier provisional November 18 target and assigned pre-class note are superseded. Later gate dates below are retained from earlier course research for planning and should be reconfirmed when active; they add no deliverables to the November 15 submission.

| Phase | Dates | Ends with |
|---|---|---|
| 0. Concept and first code | to Wed 11 Nov | Rule set v0.1, prototype code, G1 drafts |
| 1. G1 Concept | Wed 11 Nov to Sun 15 Nov | **Sun 15 Nov 23:59: recording and G1 main post.** Mon 16 Nov: class review. About Tue 17 Nov: Approve or Hold from the instructor |
| 2. Live agent | Mon 16 Nov to Mon 23 Nov | **Mon 23 Nov: retained course-checkpoint plan**, to be reconfirmed: a deployed model call, session isolation, and a forced-timeout fallback. **Two G1 Braintrust replies: Thu 19 Nov 23:59**, per the corrected announcement |
| 3. First playable | Mon 23 Nov to Sat 28 Nov | **Sat 28 Nov: G2/G3 recording**, with a first playable and at least one outside player observed. Mon 30 Nov: review |
| 4. Gold | Sun 29 Nov to Sat 5 Dec | **Sat 5 Dec: G4 Gold recording.** Mon 7 Dec: review |

For current G1 feedback, choose two classmates' pitches in the G1 discussion, starting with posts with fewer than two replies. Watch the recordings and use the Braintrust primer. No separate assigned note is due before the November 16 class under the corrected announcement. Syllabus-only midterm notes are outside the current checklist.

## 3. Work-cycle plan to G2/G3

**Goal.** By the G2/G3 recording on 28 November, a player will be able to play a full three-patient shift in a Windows build, with each patient driven either by the script or by a live model, and we will know whether the patient's choices change what players check next and whether players can explain their verdicts.

| # | Task and outcome | Student as owner, and the delegated role | Depends on | Estimate | Acceptance criteria | Test or review evidence |
|---|---|---|---|---|---|---|
| 1.1 | **Complete, Nov 12:** install portable Godot 4.7.2 and run the project | Tech Lead, within the authorized continuation | None | Actual automated work completed | Main scene renders. Suites pass 269 and 141 assertions | `07-verification-record.md`, validation logs and actual captures |
| 1.2 | Review the optional-check proposal and labeled layout/reference images; optionally play the earlier build for comparison | Student, as Creative Director | 1.1 | 1 to 2 h | Identify the desired observation, interaction, response and decision. Old universal re-check and automatic verdict colors are not assumed approved | Dated notes in `HANDOFF.md`. This is a self-test, not a playtest with an outside player |
| 1.3 | Review the completed English G1 documents, nine-slide deck and script | Student | Materials prepared Nov 12 | 2 to 3 h | Disclosures match actual contributions. The student's observation-guide concept is represented; examples and open choices are labeled. Recording stays within 3-5 minutes | Reviewed files and actual rehearsal time |
| 1.4 | **Complete, Nov 14:** publish the G1 documents; rename and organize the ongoing repository | Student authorized; Producer prepared and published | Reviewed publication file list; authenticated GitHub account | Completed | Required documents open without signing in; private workspace files stay excluded | https://github.com/DemonRain7/before-the-cut; all three required raw documents returned HTTP 200 without authentication |
| 1.5 | Rehearse and record the 3 to 5 minute pitch | **Student only** | 1.3 | 1 to 2 h | Recording length between 3:00 and 5:00 | Measured length written into the script file |
| 1.6 | Publish the G1 main post | **Student only** | 1.4, 1.5 | 0.5 h | Post visible, every link works | The post |
| 1.7 | Two Braintrust replies on self-selected G1 posts, starting with posts with fewer than two replies | Student reviews and authorizes; assistant may draft from observed recordings | Main post makes classmates' posts visible, or accessible recordings supplied | 1 h | Posted by Thu 19 Nov 23:59 New York, each naming a specific moment and reporting what was understood or experienced before proposing a cause; student reviews drafts before sending | The approved replies |
| 1.8 | Implement one revised examination loop, then adapt the other patient slots | Tech Lead and Design roles; student judges readability | Revised GDD sections 4-8 | Provisional 4 to 8 h | Normal states are visible on a reference sheet; observation/action/dialogue choices are optional and unordered; verdicts stay available; fixed physical evidence and freely generated dialogue are tested | Local captures, rule checks and a short self-test; old passing tests are not sufficient |
| 2.1 | Choose the model provider and confirm access | Student | Course Vertex AI project, or another key | 0.5 h, by Mon 16 Nov | A credential exists outside the repository. The choice is recorded | `HANDOFF.md` |
| 2.2 | First live model calls through the local proxy, with measurements | Tech Lead agent; student approves the spend | 2.1 and 1.8 for gameplay evaluation | 2 to 3 h | Begin with a small student-authorized pilot on fixed briefs and conversation scenarios; expand only after reviewing cost. Record response-format success, relevance, continuity, cooperation, median/95th-percentile latency, tokens and cost | A results file. Budget labels in the Configuration Document change from estimate to measured |
| 2.3 | Review generated dialogue for continuity, relevance and tone | QA agent lists; student judges | 2.2 | 1 to 2 h | Student reviews multi-turn conversations. Replies beyond old branches display correctly; character continuity and meaningful player choices are assessed | Notes in `HANDOFF.md` |
| 2.4 | Deploy the proxy with session isolation and a forced-timeout fallback | Tech Lead agent; student owns the hosting account | 2.2; the course's Worker foundation or a Cloudflare account | 4 to 6 h | The game receives generated dialogue from the deployed address. Two sessions do not share limits. A forced timeout shows as `fallback` in the game log | Game log excerpt and the deployed health check, for the 23 Nov checkpoint |
| 2.5 | Run the proxy tests and the lint on every push | Tech Lead agent | 1.4 | 1 h | A failing test blocks a green check | The workflow file and one green run |
| 3.1 | Windows export | Publishing role | 1.8 | 1 to 2 h | A person who has not seen the project starts it from the README | Their confirmation |
| 3.2 | First playtest with at least one outside player; target three. Half meet the scripted patients first, half the model-driven ones | **Student observes in person**; BI role summarizes logs | 3.1, 2.2 | 3 to 4 h | One record per session: who (role only), build, condition, what they did, what they said, what surprised us | Playtest log and the session log files |
| 3.3 | Fix what the playtest shows, rule clarity first | Design Lead and Tech Lead agents; student decides | 3.2 | 3 to 5 h | Each change traced to an observation | Change notes; tests rerun |
| 3.4 | Art pass 1: three readable pixel portraits | Art Lead role | 1.2 | 4 to 8 h | A new player identifies the intended response and its matching guide entry | Observed in 3.2 or a later session. **Cut first if late** |
| 3.5 | Update the GDD, Configuration Document, plan and risks; record G2/G3 | Student; Producer agent drafts | 3.2, 3.3 | 2 to 3 h | Documents match the build. Recording submitted | The recording and post |

**After G2/G3, in outline:** tune guide clarity, responses and the amount of evidence needed from play; grow to five or six patients with a fixed tutorial and a shuffled rest; sound for the warning and the shutter; final export; Gold documents; record G4 by 5 December.

## 4. Scope changes

| Date | Change | Why |
|---|---|---|
| 2026-11-10 | From an island time-loop investigation to a fixed counter | Movement, maps and cross-location clue chains were too much for one beginner in one month, and too much reading |
| 2026-11-10 | From appraising cyberware at a recycling counter to examining the patient | The student wanted the judgment to be about a person, with simple reasoning and no price balancing |
| 2026-11-13 | Normal reference sheet plus optional observation, actions and dialogue (including provocative language) | Student clarification: all methods can be skipped or combined, no fixed order. The grip example is one route only. Earlier code remains a technical starting point |
| 2026-11-14 | Autonomous patient speech replaces the earlier legal-move reply protocol | The student wants AI to decide its own answers. Format/time/cost limits remain; no authored answer substitution. A player typing interface is outside the G1 minimum |

First cuts if time runs short, in order: sound; pixel art; patients four and later; the returning-patient idea; deployment polish beyond the checkpoint. Preserve the guide, visible interaction response, player judgment, feedback and the script baseline. Cut elaborate animation before the basic response; test one patient before expanding to the proposed three-patient slice.

## 5. Progress, plans, problems

**Progress.** The revised reference-sheet prototype and autonomous dialogue adapter run locally with the current automated checks. The student recorded the nine-slide G1 pitch. Live-model and human-player benefits remain unverified.

**Plans.** Complete the duration/accessibility audit, prepare the main post for student submission, then return to implementation. Complete Trauma Team wording, confirm an authorized provider, measure dialogue behavior and observe outside players before expanding content.

**Problems.**

- The earlier build passed local checks. New implementation work needs fresh verification and a human playtest.
- No model access is confirmed. Latency and cost are estimates.
- Required G1 documents are publicly accessible. Source transfer is pending; recording and deck access still need checking.
- Everything rests on one person who is new to the engine, and the calendar has four deadlines in four weeks.

## 6. Risk Profile

| Dimension | Rating | Why | Mitigation |
|---|---|---|---|
| **IP / Concept** | Medium | The inspection-counter premise is familiar. The guide and action-response loop has no player evidence yet. The pitch references the Cyberpunk setting, while the characters, text, rules and placeholder art are original | Test whether comparing visible responses with a guide produces meaningful examination choices. Attribute specific references, use original content, and keep the fictional clinic legible without franchise knowledge |
| **Business / Audience** | Medium | This is a course project with no revenue target, so the business risk is small. But the audience claim is untested: nobody from either target group has seen the concept. A commercial game with a similar counter and setting was released this autumn, which suggests interest and also means the setting alone is not new | Show the concept and the build to players from both groups at the first playtest. Test the interest in examining a responsive patient as well as the setting |
| **Technology** | Medium | The rules are simple and the proxy is tested offline. The game and HTTP mock path now run, but no live model call has been made and nothing is deployed. The first deployed call is due on 23 November | The game is complete without a model, and every model failure falls back to the script. Launch first, then one local live call, then deployment, in that order. Keep the deployable entry small and replace it with the course's foundation when available |
| **Team** | **High** | One student with no Godot or game-production experience, relying on coding agents. Weekly hours are unknown. There is no second person to notice what the student and the agents both miss | Agents write, the student verifies by running and playing. Every claim in the handoff is labeled run or not run. A written reviewer role checks rule changes in a separate context. Outside playtesters stand in for a second pair of eyes |
| **Genre / Mechanics** | Medium | Inspecting visitors at a desk is a proven format. The new guide/action implementation passes program checks but has not been evaluated by outside players. Matching may become rote, or the animations may be ambiguous | A normal reference sheet, optional examination methods and feedback that explains the evidence. Check that players do not feel forced to complete every method or mistake irritation for a symptom. The first playtest asks players to explain a verdict. Tuning and more patients come after that evidence |
| **Timeline** | **High** | Four deadlines in under four weeks: 15, 23 and 28 November and 5 December. The first launch passed on 12 November; human review and publication still remain before G1 | The smallest scope that still tests the idea. A fixed cut order. G1 does not require a completed revised build. Finish the concept materials first; live dialogue quality and guide clarity are the next prototype tests. Each phase ends with something runnable |

**Do the High ratings share a cause?** Yes. Team and Timeline are the same fact seen twice: one beginner and a short calendar. They compound with Technology: an ordinary surprise, such as a first launch that needs a day of fixes or a provider that needs a different sign-in, costs more here because nobody else can absorb it and the next deadline is days away. That is why the mitigations are mostly about order and scope rather than extra work: launch before polish, the script before the model, three patients before five.

## 7. Initial Risk Register

| # | Risk | Evidence or trigger | Impact and likelihood | Responsible role | Mitigation | Contingency | Status and next check |
|---|---|---|---|---|---|---|---|
| R1 | First-launch failure before the G1 review | Godot 4.7.2 runs the game. Rule and UI suites pass; actual frames were captured | Original impact high. Launch risk now resolved | Tech Lead | Preserve reproducible tests and run instructions | Human usability remains covered by R6 | **Closed for first launch on Nov 12** |
| R2 | If no model call works through a deployed proxy by 23 November, then the course checkpoint is missed | No provider access confirmed. The Worker entry has never been deployed | Impact high, likelihood medium | Tech Lead; student for accounts | Choose the provider by 16 November. Local live call first. Deploy with the course's foundation | Show the local live call, the mock, and the forced-timeout fallback, and state what is missing | Open. Check 16 November |
| R3 | If the 95th-percentile model latency is above 2.5 s when measured, then most turns fall back to the script and the comparison is empty | Unmeasured. Only a target exists | Impact medium, likelihood medium | Tech Lead | Short prompt, small fast model, schema output, one attempt | Ask the model only on ASK turns (two per visit), or request the patient's move for the next likely action in advance | Open. Check at task 2.2 |
| R4 | If, at the first playtest, the model-driven patient changes wording but not what players do next, then the agent hypothesis fails | The pitch guide warns against agents that could be removed with no change | Impact high for the grade and the concept, likelihood medium to high | Design Lead | Compare the same characters and player scenarios in generated and authored-dialogue conditions. Track whether a relevant reply changes the next chosen check and whether the player can explain why | Revise character context and the examination choices, or report the negative result and keep the authored comparison; do not force AI speech back into an answer menu | Open. Check at task 3.2 |
| R5 | If the live model gives away the dangerous patient's secret in its line, then the deduction collapses | The brief contains the secret. Only a prompt rule guards it | Impact high, likelihood medium | QA | Leak review on fixed states before any player sees the model version | Revise what the character knows and why it would disclose it, review multi-turn examples, and simplify the case if needed; preserve original generated replies | Open. Check at task 2.3 |
| R6 | If players cannot explain a verdict after one shift, then the guide or action response is not clear enough and screening reads as guessing | No person has played | Impact high, likelihood medium | Design Lead | Tutorial patient with one guide entry and one readable action. Feedback names the observation that supports the decision | Reduce to one guide entry and one interaction, improve the response animation, shorten text | Open. Check at tasks 1.2 and 3.2 |
| R7 | If three patients feel finished after one shift, then the Gold build is a thin demo | Fixed order, fixed truths, about ten minutes | Impact medium, likelihood high | Design Lead | Five or six patients by Gold, a shuffled order after the tutorial | Present the game honestly as a short complete slice | Open. Check after 3.2 |
| R8 | If the student has fewer hours than this plan assumes in any week, then a phase slips into the next deadline | Hours are unknown. The student is new to the engine | Impact high, likelihood medium | Producer | The cut order in section 4. Agents do the writing. Each phase ends runnable | Cut art and sound entirely. Keep three patients | Open. Check every Monday |
| R9 | If the course's Vertex AI project is not available to the student, then the provider and the budget numbers change | Access has not been confirmed | Impact low, likelihood medium | Tech Lead | The provider sits behind one small interface. A Gemini API key works with the same adapter | Use another provider the student has access to, and recompute the budget | Open. Check 16 November |
| R10 | If the franchise words in the pitch are read as fan work, then the concept is questioned on IP | Two franchise terms in the X sentence | Impact low to medium, likelihood low | Student | Attribution in the GDD. Original content. Neutral wording ready | Rename in the pitch and the post | Open. Ask at G1 |
| R11 | If the course dates have changed since 10 November, then a deadline is missed | The assignment and corrected announcement were reread in authenticated Chrome on November 14 | Impact high, likelihood low | Student | Re-read the course site before recording | None beyond checking | Open. Check before 15 November |
| R12 | If the attack reads as a reflex test bolted onto a thinking game, then it works against the motivation we claim | Design reasoning only | Impact medium, likelihood medium | Design Lead | The clock never overlaps reading. A confirmed sign lets the player act with no reflex | Lengthen the window, or let the chart predict the attack so it becomes a decision | Open. Check at task 3.2 |

## 8. What exists as evidence at G1

| Course artifact | State at G1 |
|---|---|
| Game build | Revised guide/action prototype runs locally with five development cases; the pitch evaluates three. No standalone export, live-model validation or human playtest |
| Playtest log | No sessions. The test question is in the Configuration Document, sections A6 and A9 |
| Evaluation harness | 260 current game/agent assertions, 246 UI-flow assertions, 18 proxy tests and 49 real-client/scene mock checks pass. Live-model evaluation remains planned |
| Risk Register | This document |
