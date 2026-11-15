AI use: Claude drafted the initial configuration and code. Codex ran local game and integration checks and updated this document. Final student review is pending.

# Before the Cut: Initial Configuration Document

Version 0.6, G1 Concept, 2026-11-14. The machine-readable version of this document is `agent-config.json` in the project root.

This project has two kinds of agents. They are configured separately and must not be confused.

- **The runtime agent** is inside the game. It plays the patient at the counter (Part A).
- **The production agents** are the coding assistants that help one student build the game (Part B).

Every item carries one of three labels.

| Label | Meaning |
|---|---|
| **Verified** | Built, run, and the result is recorded with its date |
| **Implemented** | Written but not run, or run only against a stand-in |
| **Unresolved** | Planned or undecided |

Existing-build evidence on 2026-11-12 (before the observation-guide revision): the game runs in Godot 4.7.2. The original suites pass 269 rule assertions, 141 UI-flow assertions and 28 proxy tests. A new real Godot-to-proxy run passes 73 checks, including a complete 10-request mock shift and both timeout paths. **No live model call or human playtest has occurred.** Nothing is deployed. See `07-verification-record.md`.

---

# Part A. The runtime agent: the patient

**Repository update, November 14:** this is now the ongoing `before-the-cut` repository. G1 documents are in `docs/g1/`. Claude/Fable is still implementing the revised game in the legacy workspace; new case data and pixel-art work have been observed, but completion is not verified. Source transfer waits until that writer stops. Technical results below are dated evidence for the earlier prototype, not tests of the current work. See the [transition record](../development/repository-transition.md).

**Student decision, November 14:** replace the referral choice with **Call Trauma Team**. The player calls an emergency response unit to take over the patient situation. The exact handling, cost and consequences remain authored design choices; the call does not change case truth or give the model control over attacks. For the first slice, a short dispatch response and fixed encounter outcome are sufficient. A new combat or squad-control system is not required. Current screenshots and runtime data still use the earlier REFER label; implementation is pending while the active writer continues.

## A0. Revised gameplay contract and migration boundary

**Student direction, clarified November 13:** a normal reference sheet shows expected appearance, states and responses. The player chooses appearance comparison, a requested action/tool interaction, ordinary dialogue or provocative language. All methods are optional, can be combined or skipped, and have no fixed order. A universal re-check or inspect-then-action sequence is superseded.

**Target, not yet implemented:** choose any available examination method or decide with current information. Compare the resulting observation with the normal reference, then choose another method or surgery/call-in. No checklist-completion gate unlocks a verdict. An immediate threat is separate from an elevated risk assessment.

The runtime agent remains the patient. It may cooperate, refuse or offer an authored explanation. Cooperation determines whether an interaction proceeds; it does not determine what symptoms the completed interaction reveals. Refusal records no test result. The game owns the guide, case risk, visible response, evidence record, outcomes and attack timing. The agent cannot invent gestures as diagnostic evidence through its dialogue.

For optional conversation and verbal pressure, the proposed first slice uses authored question/tone choices. The selected action or tone becomes bounded context; the agent selects a case-legal response. Any conversational pattern that counts as evidence must be authored and validated by game rules. Ordinary irritation at provocation is not automatically a warning. Tone-aware request events and evidence validation are planned extensions; the old executable does not implement them.

The existing `comply`, `stall`, `deflect` and `explain:<claim>` interface is reusable infrastructure. The current tool ids, scan/re-check evidence states, strain rules and case files below describe the **earlier executable**, not approved mechanics for the revised design. Before the new loop is called implemented, update its case schema, reference-to-response mapping, optional dialogue/tone events, validators, prompts, stateful baseline, presentation and meaningful tests together. Keep the timeout and offline path.

**Fairness target:** every legal cooperation/refusal sequence leaves an authored evidence route, so the agent cannot force an unsupported emergency call. A patient who declines is not automatically abnormal. Both model and scripted conditions use the same guide and authored responses.

The game-specific configuration details in A4-A18 are the current technical baseline unless explicitly labeled target. Their November 12 verification does not validate the new observation loop.

## A1. Purpose

On each question or test request from the player, choose **one move from a legal list** and say **one line of at most 110 characters**, in character as tonight's patient.

The agent exists to test one idea: a patient who chooses when to cooperate and which reason to give can change what the player checks next. The comparison is a stateful authored script with the same facts and legal moves. The baseline can also respond to visit history; any additional benefit from the model remains a hypothesis.

The proposed distinction is flexibility across combinations of optional checks and conversational tones beyond explicitly authored branches. Cover common situations in the baseline, then compare both conditions with the same case facts, visit history, legal responses and limits. Observe whether a coherent response gives the player a reason to change the next check. A script could cover those combinations too; a model advantage is not assumed. This supports the primary Fantasy and Discovery motivations. Sensation comes from game-controlled threats. The G1 pitch no longer claims Chance through shuffled arrivals. Threats and patient truth are not delegated to the patient model.

## A2. Where it runs

```
Godot game  --(ids, enums, numbers)-->  patient-move proxy  --(prompt)-->  model provider
   owns truth, results, score              owns keys, limits, validation
```

- The game sends a request with ids, enums and numbers only. Version 1 has no typed player text. Validating identifiers and rebuilding prompts from authored data reduces the player-controlled input surface; it is not a general guarantee against prompt injection or dialogue leakage.
- The proxy holds its own copy of the case files, checks every field of the request against them, builds the prompt, calls the provider once, validates the answer and returns it.
- The game validates the answer again and applies the move through the same rule code the script uses.
- Provider keys exist only on the proxy. Nothing secret is stored in the Godot project or its exported build.

## A3. Tools

The agent has **no tools**. It cannot browse, read files, call functions or keep notes.

The agent is itself reached through a function-calling style interface: `POST /v1/patient-move` takes a structured request and returns `{ "move": <one of the legal moves>, "line": <string> }`. The provider is asked for JSON that matches a schema whose `move` field is an enum of the legal moves for that turn.

## A4. Permissions and prohibited actions

**Allowed:** pick `comply`, `stall`, `deflect` or `explain:<claim>` when that move is on the list for this turn, and write the spoken line.

**Prohibited, and how each is enforced:**

| The agent must not | Enforced by |
|---|---|
| Change the truth, a test result, a lead, strain, the attack or the score | It has no channel to do so. Its answer is one enum value and one string; all state lives in `game/scripts/core/visit_state.gd` |
| Choose a move that is not legal this turn | Schema enum at the provider, then `validateMove` in the proxy, then `move_validator.gd` in the game |
| Start an attack, leave, pay or bargain | No such moves exist |
| Put a machine readout, stage direction or markup in its line | Length limit, control-character check and a list of 12 forbidden tokens, in both validators |
| Say outright whether the patient is safe or dangerous, or confess what the patient hides | **Prompt rule only.** No code detects this today. See A10 |
| See the truth flag, the check table, the look texts, the attack data, the fee or the script | The prompt builder reads a fixed list of case fields. A test asserts the excluded text is absent from every prompt |
| Act during the attack window | The game never calls it in that phase |

## A5. Named context sources

Everything the model sees comes from these places and nowhere else.

| Source | What is taken |
|---|---|
| `game/data/cases/<case>.json` (the proxy's copy) | `name`, `tagline`, `request`, `brief`, `opening_line`, the labels of leads the player has noticed, the text of claims, and one or two sample lines for each legal move |
| `game/data/rules.json` | The display names of the tools |
| The request's public state, from `VisitState.snapshot()` | Strain, checks left, the state of each noticed lead (open, cleared, confirmed), each test already run and whether it was normal or abnormal, reasons already given and whether each is unverified, verified or busted, and up to ten recent event tags |
| The request's event | Which lead was asked about, or which test is requested |
| The request's legal moves | The list to choose from |

## A6. Knowledge boundary

| | |
|---|---|
| **The world knows** (game only) | Whether the patient is dangerous. The result and readout of every test, including tests not yet run. What each spot shows. When and how an attack happens. Fees, outcomes, score |
| **The agent may know** | The patient's own first-person brief: who they are, what they want, how they feel. For Adrian Vale this includes that his hands move on their own and that he is steering the doctor away from one test. The agent knows the role the way an actor does |
| **The agent is never given** | The truth flag and truth summary. The check table and readouts. The look texts. Attack data. Outcomes. Fee. The teaser. The script. Lines for events it does not control (pushed, referred, operated, snap, walk-out) |
| **The agent cannot rewrite** | Authored truth, test results or scoring rules. Its permitted cooperation and disclosure choices can still affect the player's route and costs through normal game rules |

**Named weakness.** Because the brief can contain a secret, the model could give it away in its spoken line. Today only the prompt forbids this. It has not been tried against a real model. The check is planned (A11), and the contingency is to remove the secret from the brief and give the model only behavior instructions.

## A7. Memory policy

No private persistent model memory. Each request reconstructs the current visit from public state and recent event tags, so earlier interaction can affect the next choice. No conversation state carries into another patient or player. The proxy separately keeps call counters in process memory.

## A8. Models and settings

| Setting | Value | Label |
|---|---|---|
| Default mode | `script`: no model, no network | Verified in local game tests |
| Mock mode | The proxy replays the case's rule list. Answers are tagged `mock: true` | Verified offline |
| Live provider | Google: Vertex AI (the course default) or the Gemini API, selected by which credentials are set | Implemented. Tested only against a fake network function |
| Live model | `gemini-3.5-flash-lite` candidate. A comparison with `gemini-3.8-flash` is optional | Account access and a successful real call remain unresolved |
| Output | JSON with a schema; at most 256 output tokens | Implemented |
| Attempts | 1. No retries | Verified offline |
| Other providers | An Anthropic adapter is planned. It needs a package install and the student's approval to spend credit | Unresolved |

The model id is read from the `BTC_MODEL` setting. The resolved model id returned by the provider is recorded with each call.

## A9. Prompt and system instructions

Location: `agent_proxy/src/core.mjs`, function `buildPrompt()`. The prompt is built by code on every call. There is no hand-edited prompt file.

The system part tells the model that it plays one patient, gives the brief, the request and the patient's opening line, and sets these hard rules: copy the move exactly from the legal list; the line is only what is said aloud, in plain words, within the length limit; no brackets, stage directions, lists, readouts or test results; never say outright whether you are safe or dangerous and never confess what the character would hide; never mention the game or its rules; you cannot attack, leave, pay or bargain.

The user part lists the current tension, tests remaining, what the doctor has noticed, tests already run with normal or abnormal, reasons already given, recent events, what the doctor just did, and each legal move with a short description.

The initial planning notes report a 32-prompt sample on November 11: 2,064-3,723 characters, mean 2,910. A new reproducible integration run on November 12 measured the 10 requests on the actual evidence path: **2,043-2,828 characters, mean 2,432**. See `../validation/2026-11-12/prompt-measurements.json`. These are character counts, not provider token measurements. The planning budget keeps headroom above the smaller integration sample.

## A10. Failure modes

| Failure | Detected by | Response | Label |
|---|---|---|---|
| Answer is not JSON, or lacks a move or a line | Proxy validator | `422`; game uses the script for this turn | Verified offline with forced failures |
| Illegal move | Schema enum, proxy validator, game validator | Same | Verified locally in proxy and game tests |
| Line too long, empty, or with control characters | Both validators | Same | Verified locally in proxy and game tests |
| Line imitates a readout or carries markup | Forbidden-token list in both validators | Same | Verified locally in proxy and game tests |
| Line gives away what the patient hides | **Nothing in code** | Planned: a leak review on a fixed set of states; then either a stricter prompt, a second check, or a brief without the secret | Unresolved |
| Provider timeout | 2.0 s deadline in the proxy, 2.5 s in the game | `504`; script for this turn | Verified through the real Godot client: proxy-deadline fallback at 2,068 ms and client-deadline fallback at 2,504 ms on November 12 (mock only) |
| Provider error or quota | HTTP status from the provider | `502`; script for this turn | Verified offline against a fake network function |
| Too many calls in a visit, a session, or overall | Counters in the proxy; the game also counts per visit | `429`; script for the rest | Verified locally in proxy and game tests |
| Game and proxy have different versions of a case | `case_version` in the request | `409`; script | Verified offline |
| Proxy unreachable | Game request fails | Script | Implemented; the new integration run verifies timeout and invalid-output paths, not every network outage |
| Model is correct but dull: always picks the same move | Play logs | Compare move distributions between script and model sessions | Unresolved |

## A11. Evaluations

| Evaluation | What it shows | Label |
|---|---|---|
| `agent_proxy/test/core.test.mjs`, 28 tests | Request validation, the prompt boundary for every event of all three cases, answer validation, call caps, session isolation, the deadline, logs, the Google request shape | **Verified again** on 2026-11-12: 28 pass, 0 fail. Mock and fake network only |
| `game/tests/run_tests.gd` | Rules, each patient's evidence path, five whole-shift strategies, the fallback path with a fake client | **Verified: 269 assertions pass on 2026-11-12** |
| `game/tests/run_ui_smoke.gd` | The real scene driven through four shifts | **Verified: 141 assertions pass on 2026-11-12** |
| `tools/run_proxy_integration.mjs` and `game/tests/run_proxy_integration.gd` | Real Godot HTTP requests, a 10-request mock shift, move agreement, invalid response and both timeout fallbacks | **Verified: 73 checks pass on 2026-11-12. No live AI** |
| Live-model set | The 17 fixed game states already used with the mock, each run at least 10 times against the live model: share of legal moves, share passing validation, latency, token use, and a human read of every line for leaks and tone | Unresolved. Needs provider access |
| Script-versus-model playtest | Whether the patient's choices change what players check next (see the playtest question below) | Unresolved. Needs a running game and players |

**Playtest question for G2/G3.** With the same guide, patients and authored responses, does model-driven cooperation or disclosure change the next interaction and the player's reason for choosing it? Can players connect an observed or spoken response to the normal reference, choose or skip methods freely, and explain approving surgery or calling Trauma Team? Compare with the stateful script; separately record whether waiting is disruptive. Different wording alone is not a successful result.

## A12. Logging

- **Game log.** One JSON Lines file per session on the player's machine: session and shift start, each visit with case id and seed, every look, ask, check, push, back-off, verdict and shutter, each patient move with the legal list, the move taken, the line, its source (`script`, `model` or `fallback`), the fallback reason, measured latency and the provider's reported token use, the attack window with reaction time, the result and the shift report. Automated runs are tagged so they cannot be mistaken for a person playing. Label: verified in local automated game tests.
- **Proxy log.** One JSON line per request: request id, provider, model, status, error code, latency, session id, visit id, case id, event, number of legal moves, token counts, the move. It never contains prompts or patient lines. Label: verified offline.
- Session ids are random eight-character codes. Neither log holds a name, an account or a key.

## A13. Human override

| Who | Can |
|---|---|
| Player | Close the shutter at any time. Restart the shift. Switch the patient between script and model with F2 |
| Student (operator) | Start the game without `--model`. Stop the proxy, which sends every turn to the script. Set `BTC_PROVIDER=mock`, which spends nothing. Lower any limit in one place |

## A14. Timeout, retry and spending limits

| Limit | Value | Where it is set |
|---|---|---|
| Model calls per patient visit | 4 | Proxy, and counted again in the game |
| Model calls per play session | 60 | Proxy |
| Model calls per proxy process | 2,000 | Proxy. A request-count guardrail. About 1.84 USD under the high planning assumptions, not a guaranteed monetary ceiling |
| Provider deadline | 2,000 ms | Proxy |
| Game-side timeout | 2,500 ms | `game/data/rules.json` |
| Attempts per turn | 1. No retries | Proxy |
| Output tokens | 256 | Proxy |
| Patient line | 110 characters | `game/data/rules.json` |
| Request body | 8,192 bytes | Proxy |
| Player text sent to the model | 0 characters | By design |

The call counters live in one process. That is enough for the local server. A deployed proxy needs shared storage for the limits to hold across instances. Label: unresolved.

## A15. Fallback

Any timeout, error, limit or invalid answer makes the game use the scripted move and line for that turn and write the reason to the log. The player sees a normal answer. The fallback follows the same rules as the model path because both only choose from the same legal list.

The game runs fully with no proxy at all. This is the default.

Label: proxy and game fallback are verified locally, including the real HTTP path with mock providers. Live-provider evaluation remains pending.

## A16. Budgets

Each number is labeled. **Nothing here is measured against a live model.** The measured ten-call path belongs to the earlier scan/re-check build. Ten calls remains a provisional planning assumption for the revised slice; twelve is the three-visit cap. Remeasure prompts and call counts after the observation flow is implemented. The old attack window is a baseline value, not a finalized timing for the new design.

| Budget | Number | Label and basis |
|---|---|---|
| Time to the patient's answer, typical | 1.0 s or less | **Target** |
| Time to the patient's answer, worst case | 2.5 s, then the script answers | **Limit**, enforced in the game |
| Forced-timeout fallback as seen by Godot | 2.068 s for the proxy deadline; 2.504 s for the client deadline | **Measured** on 2026-11-12 with controlled mock failures, not live-model latency |
| Attack reaction window | 1.8 s, never overlapping a model call | **Design rule** |
| Prompt size on the actual evidence path | 2,043 to 2,828 characters, mean 2,432 | **Measured** over 10 Godot-to-mock requests on 2026-11-12 |
| Input tokens per call | New path sample suggests about 510-710, mean about 610. Plan with 730 typical / 930 high | **Estimates**, using 4 characters per token and planning headroom. Provider token counts are still unknown |
| Output tokens per call | About 60 typical; 256 at the cap | **Estimate**. One move plus a short line. If the model spends hidden reasoning tokens, the real number is higher |
| Model calls per shift | 10 on the follow-the-evidence path (3 + 3 + 4); 12 at the limits | **Verified** as mock HTTP requests. PUSH issues no request |
| Cost per shift, typical | About 0.004 USD | **Estimate**: 10 x (730 x 0.30 + 60 x 2.50) / 1,000,000 |
| Cost per shift, at the limits | About 0.011 USD | **Estimate**: 12 x (930 x 0.30 + 256 x 2.50) / 1,000,000 |
| Cost per shift on the comparison model | About 0.008 USD typical, 0.020 USD at the limits | **Estimate** at introductory prices |
| Cost per shift | 0.02 USD or less | **Target** |

Price basis: Google's published Vertex AI price list at <https://cloud.google.com/model-garden/pricing>, rechecked on 2026-11-12. Gemini 3.5 Flash-Lite, global endpoint: 0.30 USD per million input tokens and 2.50 USD per million output tokens. Gemini 3.8 Flash, global endpoint: 0.75 and 3.75 USD, listed as introductory prices until 2026-12-31, after which the page lists 1.50 and 7.50 USD. Prices can change; re-read the page before relying on these numbers.

Whether the course's Vertex AI project is available to this student has not been confirmed.

## A17. Configuration versions

| Item | Version |
|---|---|
| This configuration | 0.4.0 (2026-11-13); optional methods and normal reference plus explicitly labeled earlier runtime |
| Rule set, `game/data/rules.json` | 0.1.0 |
| Each case file | `version: 1`. The game and the proxy must agree, or the proxy answers `409` |
| Wire protocol | 1 |
| Proxy package | 0.1.0 |

The ongoing repository is https://github.com/DemonRain7/before-the-cut, renamed from before-the-cut-g1 on November 14 under student authorization. It preserves the published G1 history and will also hold the implementation. Source transfer is deferred while Claude/Fable is still writing in the legacy workspace. The current public contents are the course documents, agent artifacts and directory placeholders; the game is not deployed.

## A18. Executable artifacts, test commands, CI

| Artifact | Location |
|---|---|
| Patient-move interface: validation, prompt builder, limits | `agent_proxy/src/core.mjs` |
| Providers: mock and Google | `agent_proxy/src/providers.mjs` |
| Local server | `agent_proxy/src/dev_server.mjs` |
| Deployable entry (Cloudflare Worker), never deployed | `agent_proxy/src/worker.mjs` |
| Game side: agent, HTTP client, validator | `game/scripts/core/patient_agent.gd`, `model_client.gd`, `move_validator.gd` |
| Script baseline | `game/scripts/core/scripted_brain.gd` and the `script` list in each case file |
| Manifest | `agent-config.json` |

Test commands, run from the project root:

```bash
cd agent_proxy && npm test
```

```bash
python tools/gd_static_check.py
```

```bash
godot --headless --path game --script res://tests/run_tests.gd
```

```bash
godot --headless --path game --script res://tests/run_ui_smoke.gd
```

Results on 2026-11-12: the proxy suite passes 28 tests. The two Godot suites pass 269 and 141 assertions. The earlier lint was a rough static check, not an engine run. Additional command: `node tools/run_proxy_integration.mjs PATH_TO_GODOT_CONSOLE_EXE validation/latest` runs 73 real-client integration checks using mock providers.

CI workflow path: none. The ongoing repository is public, but runtime source transfer remains pending. Planned after transfer: `.github/workflows/checks.yml` using commands verified against the revised implementation.

---

# Part B. The production agent team

## B1. Who decides

The student is Executive Producer and Creative Director: sets the concept, approves scope and content, runs and judges the game, records and submits. The instructor is the Gate Approver. Agents propose, write and check. The student controls course submission, spending and gate decisions. Agents may publish repository materials under explicit student authorization; the student requested G1 document publication and the subsequent repository rename and restructuring on November 14. No CourseWorks post was made.

## B2. What has actually happened so far

- **2026-11-10 to 11, Codex** (a coding agent): course research, a comparison of game directions, the First Pitch draft, the G1 preparation notes and the handoff note. These are the older Chinese-language notes in the project root.
- **2026-11-11, Claude Code** (a coding agent): rule set v0.1, the three patients, the Godot project, the proxy and its tests, the lint tool, and the drafts in this G1 folder.
- **2026-11-12, Codex:** resumed from the code, installed portable Godot, ran local tests, added real-client integration checks, captured actual frames, completed the G1 deck and handoff records.
- **2026-11-13, the student:** corrected the concept to observation-guide comparison and action-based screening, and requested corresponding material changes. Codex revised the design and pitch; implementation of that flow remains planned.
- **The student** sets the concept, audience, scope and language. This concept correction is recorded; a complete artifact review, self-play and recording are not yet recorded.

So today there is one working production role, the implementation agent, used by two different tools in turn. The other roles below are a plan with two artifacts already written and not yet used.

## B3. Role coverage

| Role | Executable artifact | Purpose | Context it reads | Tools and permissions | Outputs | Handoff to | How it is checked | Human approval boundary | Label |
|---|---|---|---|---|---|---|---|---|---|
| **Producer** | `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, the plan and risk register in this folder | Keep scope, dates, risks and the next three tasks current | `HANDOFF.md`, this folder, course dates | Read and write project files. No posting, no gate decisions | Updated plan, risks, handoff | Student, then the next agent | A fresh agent can state the goal, run the checks and name the next task from the handoff alone | Student sets priorities and accepts every scope change | Implemented during Codex resumption. Fresh-agent handoff usability remains to be checked |
| **Design Lead and Narrative** | `agent_team/case-author/SKILL.md` | One procedure for adding or changing a patient so the rules stay fair | `rules.json`, the case files, the GDD, `AGENTS.md` | Edits only `game/data/cases` and test expectations | A case file, updated expectations, a change note | Rules reviewer | Guide entries support each authored response and verdict; relevant tests cover the revised rule schema. Old strategy totals are historical until rebalanced | Student approves each patient's truth and tone | Implemented (written, not used) |
| **Tech Lead** | `AGENTS.md` | Build and change the game and the proxy | `AGENTS.md`, `HANDOFF.md`, the code | Read and write the project, run local tests. No secrets in files. Routine local setup and reversible fixes follow the student's task authorization. No paid calls, publication or unrelated changes without authorization | Code, tests, real test output, updated handoff | Rules reviewer and student | The four test commands | Student runs the game, accepts the change, commits | Verified in use (two agents so far) |
| **QA** | `agent_team/rules-reviewer.md`, `tools/gd_static_check.py`, `game/tests/`, `agent_proxy/test/` | An independent check, in a context that did not write the change | The diff and change note, the data files, the rule code | Read and search only | Findings with file and line, or "No findings" | Student; blocking findings go back to the Tech Lead | Planned: seed a known fault and confirm it is found | Student decides every finding. The reviewer cannot approve or merge | Reviewer brief implemented (not used). Proxy and game tests verified. The separate reviewer workflow remains unexercised |
| **Art Lead** | Planned: `agent_team/art-brief.md`. Today: placeholder figures drawn by `game/scripts/ui/patient_view.gd` | Readable look spots first, pixel art later | The GDD's feedback section, the UI code | Would write under `game/assets`. Third-party assets only with recorded license terms | Sprites and a license log | Tech Lead | A new player can describe the visible response and find the matching guide entry | Student approves the look | Unresolved |
| **Audio** | Planned: a list of at most six sounds | A sound for the warning and the shutter | The GDD | Same as Art Lead | Sound files with license terms | Tech Lead | The warning is noticed without reading | Student approves | Unresolved. First to be cut |
| **Business Intelligence** | `game/scripts/core/event_log.gd`. Planned: a log summary script | Turn play logs into the few numbers the playtest question needs | Session logs | Read logs, write summaries. No identities | A per-session table | Student | Numbers match a hand count on one session | Student writes the interpretation | Log writer verified in local tests. BI summary tool unresolved |
| **Publishing and Release** | `game/README.md`, `README.md`. Planned: an export checklist | Make the build reachable and runnable by a playtester | The READMEs, course publishing guidance | Local export only. Deployment or any public post needs the student's explicit go-ahead | A Windows build, run instructions, a submission checklist | Student | Someone who has not seen the project runs it from the README | Student records and approves submissions; agents may publish repository files when authorized | Run instructions implemented (not yet followed by a person) |

## B4. The executable artifacts

The course asks for at least one agent delivered as a skill, plugin, tool bundle, MCP server, function-calling interface or equivalent. The plan, with today's state:

| # | Artifact | Kind | State |
|---|---|---|---|
| 1 | `agent_proxy/`: the patient-move interface | Function-calling interface with a schema-constrained answer | Verified offline (28 tests). No live model yet |
| 2 | `agent_team/case-author/SKILL.md` | Skill, in the common `SKILL.md` format | Implemented. Not yet used on a real change |
| 3 | `agent_team/rules-reviewer.md` | Reviewer brief for a separate agent context | Implemented. Not yet used |
| 4 | `tools/gd_static_check.py` | Tool | Verified: runs and reports |
| 5 | `AGENTS.md` | Shared standing instructions for any coding agent | In use |

Personal agent settings live in `.claude/`, which Git ignores. Shared team artifacts therefore live in the tracked `agent_team/` folder so that any agent or person can use them. To use the skill in Claude Code, copy the `case-author` folder into `.claude/skills/`. In another tool, point the agent at the file.

## B5. How work moves between roles

1. The student states a change ("add a patient who fakes calm").
2. The Design Lead skill produces the case file and updates the expected results.
3. The Tech Lead runs the test commands and records the real output.
4. The rules reviewer, in a fresh context, reads the diff and reports findings.
5. The student plays the change, decides on the findings, and commits.
6. The Producer updates the handoff, plan and risks.

Steps 2 and 4 have not been exercised yet.

## B6. Gaps

- G1 documents are public in the ongoing repository. Source transfer waits for the active implementation writer to stop; CI is not configured.
- The reviewer has never run, so its usefulness is unknown.
- New procedural pixel-art assets and generation scripts have been observed in the active workspace but are not yet reviewed or transferred. Audio, log analysis and release verification remain unconfirmed.
- One student is the only human check. There is no second person to catch what the student and the agents both miss. External playtesters are the planned counterweight.

---

# Part C. Summary of labels

| Area | Verified | Implemented, not run | Unresolved |
|---|---|---|---|
| Runtime agent | Local proxy and game validators, fallback and logs. Real HTTP mock shift and deadline paths | Google adapter tested only against fake fetch | Live model call, real latency and cost, leak check, deployment, shared limit storage |
| Baseline | Earlier build: three cases, five strategy totals, four UI-flow shifts and the 10-turn mock comparison | | Observation-guide migration, fair evidence paths and call-in outcomes, revised strategy comparison and player evaluation |
| Production team | Implementation agent in use; lint; proxy tests | Case-author skill; reviewer brief; handoff set | CI; art, audio, analysis and release artifacts; a first independent review |
| Evidence from people | | | Any playtest |
