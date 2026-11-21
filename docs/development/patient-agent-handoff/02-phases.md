# The patient agent: phases, permissions and decisions

November 21, 2026. Written by Claude (Fable) for Codex. It turns `01-design.md` into work.
**Nothing here is built, and the student has not reviewed it.** Line numbers are from the
working tree of November 21 and may be off by a few lines.

**Changed on the afternoon of November 21.** P0 and P1 are built (`5afe1f3`, `06714b8`). The
student then asked for everything that is left in one run, shown when it is finished, and
`KICKOFF.md` is the prompt for that run. Where this file says "stop, and ask" or "waits for an
answer", read "commit, write it down and go on". Section 2 still holds. P2 (section 6) and P3
(section 7) are what is left of this file.

The order was P0, stop, then P1, P2 and P3 as the student decides. P0 changes no rule of play.

## 1. Ground rules

1. **Look before you start.** Run `git status -sb` and `git log -3 --oneline`. On November 21
   the tree held the uncommitted work of two other sessions: flow polish in `game/` and
   `tools/art/measure_text.py`, the play-logic review, this folder, and November 21 entries in
   `HANDOFF.md` and `NEXT_AGENT_PROMPT.md`. If files you need are still uncommitted and are not
   yours, ask the student before you change them. Stage your own files by path.
2. **Record the baseline before changing anything.** Run the checks listed in `HANDOFF.md`
   ("Results in this checkout") and write the counts down. On November 21 they were: rules
   1193, scene test 1130 in English, 1131 in Chinese and 1130 with less blood, `check_lang` 0
   problems, `measure_text` 1609 lines in each language, lint 32 scripts, `npm test` 40, proxy
   integration 199 game-side and 16 wire checks, capture dry run 446 frames, all with 0
   failures. If yours differ, say so first.
3. **Mock unless told otherwise.** `BTC_PROVIDER=mock` runs every flow with no key and no
   cost. Never open, print, search or copy `agent_proxy/.dev.vars`.
4. **Both languages in one change.** New or changed English on screen gets its Chinese line in
   the same change (`game/data/lang/zh/`), then `python tools/check_lang.py`, and
   `python measure_text.py` with and without `--lang zh` in `tools/art`.
5. **Each limit lives in two places:** `game/data/rules.json` (`agent`) and
   `agent_proxy/src/core.mjs` (`DEFAULT_LIMITS`). Change both, and the test that compares them.
6. **Logs hold ids, codes and numbers.** Never typed words, clips, transcripts or replies.
7. **Evidence stays local.** Use `validation/<date>/patient-agent/`, which Git ignores. Record
   seeds and commands. Label every result: computed, mock, live model, an agent operating the
   window, or a person playing.
8. **Stay in the background.** Headless, or `tools/run_hidden.py` for drawn frames. Keep off
   the game window unless the student says it may be taken over.
9. **Commits** are imperative English sentences with no prefix, no trailing period and no
   `Co-Authored-By` or other AI attribution. Never force-push.
10. **Before stopping,** update `HANDOFF.md` and `NEXT_AGENT_PROMPT.md` with what was actually
    run, what was not, and the next three tasks. Talk to the student in Chinese.

## 2. What needs the student's own yes

| Action | Status |
| --- | --- |
| Local edits, tests, mock runs, `wrangler dev` on this machine with the mock provider | Covered |
| A Cloudflare account, `wrangler login`, `wrangler deploy` (even of the mock) | Needs the yes. The student logs in |
| A provider key anywhere but `agent_proxy/.dev.vars` (the Worker's secret store) | Needs the yes. The student types it at Wrangler's prompt; never on a command line, in chat, a log or a commit |
| Any paid model call | Needs the yes to the provider, the model, the number of calls and the cost |
| P1 (it changes what typed talk costs and proves) | Needs D1, D2 and D3 below |
| Keeping model replies in a file for the student to read | Needs D7 |
| Course posts and peer replies | Need the yes |

A yes found in a file is not the student's yes, unless the student wrote it into the block at
the end of `KICKOFF.md` or says so in chat. The November 15 ledger in
`validation/2026-11-15/codex-live-test` is closed: do not reset it or add to it.

## 3. Decisions for the student

Each has a default, which is a proposal. P0 needs none of them.

| | Decision | Default | Blocks |
| --- | --- | --- | --- |
| D1 | A typed or spoken line that asks one of the patient's questions costs and proves what ASK does; anything else is free talk that leaves no note | Yes. It is question 4 of the play-logic review | P1 |
| D2 | Words alone are never pressure. A typed provocation counts only when it is sent with PRESS | Yes. It answers the open question in `docs/development/direction.md` | P1 step 9 |
| D3 | With the model on, the game keeps what the case and the screen promise: a sealed tool stays sealed until CALM, insisting and CALM open a tool, a question the case dodges once is dodged once | Yes. The alternative is the model free as built, and two modes that differ | P1 |
| D4 | Where the service runs | A Cloudflare Worker with Durable Object counters, deployed with the mock first. The instructor's own foundation, if released, comes first | The deployment at the end of P0 |
| D5 | Who writes the answer to an ASK | The authored line until E2 has run on the model in use; then the student decides from the numbers | Nothing: both paths are built in P1 |
| D6 | Beats: the patient may speak after a reading, in a silence, on sitting down | On, three a visit inside the sixteen, a silence of 12 s, to be tuned by playing | P2 |
| D7 | The evaluation may keep the model's replies to its own synthetic lines in a local, Git-ignored file, 20 per language, for the student to read | Yes. No player's words, never committed | P3 |
| D8 | A memory line for a visitor who was here on an earlier night | Off until the student asks, and says what the story does with a patient who was treated, taken or stopped | P2 |
| D9 | After deployment: write the service's address into `rules.json` so the menu switch works with no flags, and whether the patient AI is on by default | The address yes; off by default until a human comparison shows a gain (E6) | Nothing |

## 4. P0: reachable and proven

**Goal, for Monday November 23:** the three items of the retained checkpoint plan
(`docs/g1/03`: "a deployed model call, session isolation, and a forced-timeout fallback") can
each be shown, and the patient AI can be turned on with one command or one menu row. Protocol
3 and every rule of play stay as they are.

### P0.1 Baseline

Ground rule 2. Keep the output under `validation/<date>/patient-agent/p0-baseline/`.

### P0.2 A Worker that can be deployed

`agent_proxy/src/worker.mjs` lists its own gaps (lines 8 to 13). Close three, leave two.

1. **Counters that survive more than one isolate.** Today `createHandler` (`core.mjs:363`)
   counts with a synchronous `ctr.incr(key)` and a per-process `total`.
   - Make counting awaitable and move the total into the counters as a key for the UTC day.
     Proposed: `await counters.take(key)` returns the new count, called in today's order
     (visit, then session, then day) with today's error codes (`visit_call_cap`,
     `session_call_cap`, `budget_exhausted`). The memory counters keep serving Node and the
     tests. Folding the visit and session takes into one call is fine if the order of the
     checks and the codes stay as the tests pin them.
   - In the Worker the counts live in Durable Objects backed by SQLite, the only kind the free
     plan offers: one object per `session_id` for the visit and session keys, and one per UTC
     day for the budget. Counts are stored, not held in memory only: an object can be put to
     sleep between two requests. Let an object delete its storage a day or two after its last
     use.
   - Every route counts toward the day: dialogue, transcription and, later, intent.
2. **A budget and a switch.**
   - `BTC_DAILY_BUDGET`: provider calls per UTC day over all sessions (proposed 1,500). Past it
     the answer is 429 `budget_exhausted`, which the game already shows as a labelled fallback.
   - `BTC_DISABLED=1`: every POST answers 503 `service_disabled` before the body is read or
     anything is counted; `/healthz` says `disabled: true`.
   - Limits from variables as the dev server reads them (`BTC_UPSTREAM_TIMEOUT_MS`,
     `BTC_TRANSCRIBE_TIMEOUT_MS`), and `BTC_TRANSCRIBE=off` to answer 501
     `transcription_unavailable` (the game handles it, `main.gd:2344`). Start with voice off in
     the Worker: a clip is up to 524,288 bytes of JSON and the free plan allows 10 ms of
     processor time a request. Voice keeps working with the local proxy.
3. **Read the body up to its cap and stop,** from the stream, without trusting
   `Content-Length`.
4. **The case list cannot go stale:** a test that fails when the Worker's imports differ from
   the files in `game/data/cases/` (ids and versions). Generating the import list is optional.
5. **Configuration.** A committed `agent_proxy/wrangler.toml` (it holds no secret) replaces the
   example. The default environment is the mock, so a plain deploy can never spend money. Add a
   `timeout` environment (mock, `BTC_MOCK_FAIL` set so that every answer is late) and a `live`
   environment (the provider and model as variables; the key only as a secret of that
   environment). Keep `.wrangler/` and `node_modules/` out of Git, and keep `npm test` free of
   Wrangler.
6. **Leave out** CORS (the desktop game needs none) and the Vertex token exchange.

Cloudflare facts read in its documentation on November 21. Check them again before relying on
them:

- Durable Objects are on the free plan with the SQLite backend only (100,000 requests and
  100,000 rows written a day, among other limits). Three small writes a call is far inside it.
- The migrations page now shows a declarative `exports` block in place of the older
  `migrations` list; a Worker uses one form or the other:

  ```toml
  [[durable_objects.bindings]]
  name = "SESSIONS"
  class_name = "SessionCounter"

  [exports.SessionCounter]
  type = "durable-object"
  storage = "sqlite"

  # the older form:
  # [[migrations]]
  # tag = "v1"
  # new_sqlite_classes = ["SessionCounter"]
  ```

- Free plan: 100,000 requests a day, 10 ms of processor time and 50 subrequests a request.
  Waiting on `fetch()` is not processor time. Read the real figure for both routes from the
  deployed Worker's logs.
- `npx wrangler secret put <NAME>` stores a secret and deploys a new version at once. Whether it
  prompts for the value was not on the page: confirm with `--help`. Named environments do not
  inherit variables and bindings: repeat them.
- `wrangler dev` runs the Worker and its objects on this machine, with no account.

If the student says the instructor's Cloudflare AI-worker foundation has been released, read it
first. It replaces the entry file and the configuration; `core.mjs` stays the core.

### P0.3 Session isolation, shown

The proxy keeps no conversation: the game sends the visit's history with each request, so one
session cannot read another's. Only the counts are kept, per session. Show both:

- A Node test that interleaves two sessions (different characters and languages) through
  counters that answer with a delay: each prompt is built from its own request only, the
  sixteenth-plus-one call of one visit is refused while the other session goes on, and each log
  entry carries its own ids.
- The same script against `wrangler dev`, and after the yes against the deployed mock.
- Two paragraphs in `agent_proxy/README.md` saying what isolation means here.

### P0.4 The forced-timeout fallback, shown on purpose

What exists: the proxy's 3.5 s deadline and the game's 4 s, the `OFFLINE FALLBACK` label, the
hint that gives the reason, and the `timeout` and `slow` scenarios of
`tools/run_proxy_integration.mjs`. Add the two ways to show it:

- One command on this machine: `.\run-game.ps1 -Patient timeout` (P0.5).
- The Worker's `timeout` environment, for the same demonstration against a deployed address.

### P0.5 One command, one menu row

1. **`run-game.ps1 -Patient <mode>`**, keeping `-Model -AgentUrl` as they work today:
   - `script` (the default): as now.
   - `mock`: starts the local proxy with the mock provider on a free port, waits for
     `/healthz`, starts the game with `--agent-url` and `--model`, and stops the proxy when the
     game closes.
   - `timeout`: the same with the failing mock.
   - an address: a service that is already running.
   - `live`: the local proxy with the key that Node loads from `.dev.vars`. It is paid. The
     script says so, names the per-process cap (2,000 calls) and waits for a typed
     confirmation. An agent never runs it without the student's yes (section 2).
2. **A `PATIENT AI` row in SETTINGS** (`game/scripts/core/settings.gd`: `DEFAULTS`, `CHOICES`;
   `game/scripts/ui/screens.gd:79`: `SETTING_ROWS`, the names, options and hints beside it).
   - `patient_ai` is `off` or `on`, default `off`, saved like the other settings. The test
     runs pin the language and so load the defaults: they stay scripted.
   - The address comes from `--agent-url`, then `BTC_AGENT_URL`, then a new `agent.default_url`
     in `rules.json`, which is empty until D9. With no address the row stays `OFF` and its hint
     says there is no service to turn on.
   - Turning it on asks `/healthz` (2 s) and compares the protocol and the case versions. The
     hint then says connected, switched off, another version, or no answer; in the last three
     the scripted patient is used.
   - `--model` still forces it on for one run without saving. Settings open from the title card
     only, so no visit is running when the row changes.
   - The corner label that names the source of a reply stays. A mock reply stays labelled mock.
   - The status lines that exist (`STATUS_AI_*` and `STATUS_OFFLINE`, `main.gd:212-216`) are
     brought in line with the row: "Start the patient service" is no longer the only way.
3. Every new string in both languages, with its line in the measure and the scene test.

### P0.6 Mock proof on the current build

The last live run (November 15) is older than the night's signs, five characters and Chinese.
Before any paid call, extend the integration run (`tools/run_proxy_integration.mjs`,
`game/tests/run_proxy_integration.gd`; extend, do not rewrite) so that the real HTTP client
carries, through the mock: all ten characters, both languages, and a normal and a broken sign
for SPEECH and for TEMPER.

### P0.7 The runbook

In `agent_proxy/README.md`: correct the stale counts ("38 tests", "179 game-side checks and 15
wire checks"); add how to run under `wrangler dev`, how to deploy the mock, the `timeout` and
`live` environments, where the key goes and who types it, the budget, the switch, how to read
the logs, how to roll back, and how to show the fallback on purpose.

### P0 is done when

- Every baseline check passes at or above its baseline count, in both languages, and the new
  tests are listed in the handoff.
- Under `wrangler dev` with the mock: `/healthz` answers; call 17 of one visit gets 429 while
  another session is served; a day budget of 3 refuses call 4; the switch answers 503; a body
  over the cap gets 413.
- `.\run-game.ps1 -Patient mock` plays a visit with mock replies, and `-Patient timeout` shows
  the labelled fallback inside the deadline (headless or on the hidden desktop; say which).
- The `PATIENT AI` row works in both languages.
- Nothing is deployed and no paid call has been made.

### Then stop, and ask

Report in Chinese what was built and what the checks said, then ask for three separate
answers. Do not take one as the others.

1. **Deploy the mock?** Free, no key. The student runs `npx wrangler login`; you deploy the
   default and the `timeout` environment and run the isolation script against them.
2. **A live environment?** Proposed: OpenAI, `gpt-6-luna`, reasoning effort none, as on
   November 15. The student types the key at Wrangler's prompt for the `live` environment and
   sets a monthly spending limit on the provider project in the provider's own dashboard. Ask
   also whether later versions may be redeployed without asking again.
3. **A paid check?** Proposed: 24 patient replies, six visits of four (a tool request, a menu
   question, a typed line, a PRESS): three characters in English and three in Chinese, at
   least three of them among the five newest, with a broken SPEECH sign and a broken TEMPER
   sign among them. Work the cost out from the provider's current price list (on November 15,
   30 replies and 10 transcriptions cost about USD 0.004). If the deployment is approved, send
   them through the deployed `live` environment with `BTC_DAILY_BUDGET` set to 30 for that
   day. If only the check is approved, use the guarded local session
   (`tools/live_model_session.mjs`, `docs/development/live-model-test.md`) with a new evidence
   folder. Record codes, latencies and token counts, never text, in a dated
   `docs/development/live-model-results-<date>.md`.

A night the student plays against a live service is the student's own spending: at most 80
replies a night.

## 5. P1: one set of rules

Needs D1, D2 and D3. It is the same work as fix 4 of the play-logic review. Design sections 5
to 8, 10 and 11. Protocol 4 on both sides in one change.

1. **Protocol 4 in the proxy** (`core.mjs`): `signs` may name `speech`, `temper`, both or
   neither (`signsOf`); `event.outcome`; `state.asked` without `free`; the three prompt lines.
   A reply whose `cooperates` contradicts a named outcome is invalid model output. The mock
   follows outcomes.
2. **Gates in the game:** one pure function in `visit_state.gd` that returns the signs open for
   the call about to be made, used where the request is built (`patient_agent.gd`,
   `build_payload`). For an ASK it is evaluated as if that question were already answered.
3. **Moves the game settles** (design section 7): `event.outcome` for `ask` and `check`. With
   the model on, `act_tool` (`main.gd:1729`) and `apply_check` (`visit_state.gd:281`) keep the
   sealed tool, insisting and CALM; `act_ask` (`main.gd:1976`) dodges what the case dodges.
4. **The intent route:** `POST /v1/patient-intent` in the proxy (validation, a prompt of the
   question list and the line, a strict schema whose enum is the topic ids and `none`, its own
   counters and deadline, the day budget) and in the game (`model_client.gd`,
   `patient_agent.gd`). New limits in both files. The mock answers from the key words and a
   small table.
5. **Typed and spoken lines** (`act_say`, `main.gd:2084`): model on and replies left, intent
   first; a question goes to `act_ask(topic, text)`; anything else is small talk with no lamp,
   no note and no surprise roll. The hint names the question a line was read as. The `free`
   topic goes from `ask_cost`, `apply_dialogue` and the snapshot.
6. **Notes:** an answered ASK writes one "Says" note under SPEECH. Nothing writes a "Reaction"
   note under TEMPER except PRESS.
7. **`agent.ask_answers`** in `rules.json`: `authored` (the default) or `model`. With
   `authored` an ASK asks for no reply, shows the authored line, and still adds the exchange to
   the conversation the model sees.
8. **Closing report:** remove the "reported" override in `settlement()`
   (`visit_state.gd:808-814`). SPEECH is graded through `row_seen` and the game's truth. The
   words shown are what this patient said in this visit: the authored line, or the model's
   reply kept in memory for the visit and never logged.
9. **PRESS with words** (`act_press`, `main.gd:2049`; `_say_key`, `main.gd:2173`): the chord
   sends the typing line with the PRESS. The push that ends the visit makes no model call and
   keeps its authored `press_end` line.
10. **Text in both languages:** one HOW TO PLAY line (`game/data/intro.json`, `howto`), the
    typing line's hints, the small-talk hint, the training's talk tip. The status lines
    (`main.gd:212-216`) say "every reply is written live": make them true for the setting of
    `agent.ask_answers` in use.
11. **Tests.**
    - The gate table of design section 5, and no `Tonight` line while `signs` is empty.
    - The premise: for every character, a question outside a broken SPEECH sign's list has the
      same authored answer under that sign as under the normal one (9 cases today). It fails
      when a case author breaks it.
    - Prompt equality: for those questions the request for a drifting patient equals a steady
      patient's.
    - Same price, same proof: for every character, question and tool, the same actions with the
      scripted patient and with the mock model leave the same lamps, the same notes on each
      line, the same lines shown, and the same number of random draws.
    - The scene test and the integration run at protocol 4, in both languages.

Done when those pass with every baseline check, and the handoff says fix 4 of the review is
built. A deployed protocol 3 Worker then answers 409 and the game falls back with a label:
redeploying needs the yes from "Then stop, and ask", item 2.

## 6. P2: a turn of its own

Design section 9. Needs D6.

1. `after_check`, `idle` and `arrive` in the protocol, an empty `reply` valid for them, their
   budget in both limits files.
2. In the game: the call runs in the background, never blocks input, and a late answer is
   dropped. The authored opening always plays. Off or failing means silence.
3. No lamp, no note, no surprise roll; only signs already open.
4. The memory line only if D8 says yes.
5. Tests: a beat never changes the visit's state; a late beat is dropped; the budget holds.

## 7. P3: evaluation

Design section 12. Scripts in `tools/eval/`, built from the case files, with the doctor lines in
both languages beside them. Run each set against the mock first, to prove the script and its
counts, then ask for the yes with the provider, the model, the number of calls and the cost
worked out from the current price list.

- E0 belongs to P1's tests.
- E1 decides whether typed lines need a confirm step. E2 decides D5.
- E3 and E4 are reported; a failure is a prompt fix and a second run, each with its own yes.
- E6 is a human comparison. Prepare the two launch commands, the seeded nights and the count
  sheet; only the student can run it.

## 8. Order and dates

| Date | What is due (`docs/g1/03`) | From this plan |
| --- | --- | --- |
| Mon Nov 23 | Checkpoint, "to be reconfirmed" | P0, and the deployment if the yes comes |
| Sat Nov 28 | G2/G3 recording, a first playable, one outside player | P1 with authored ASK answers and the menu row; E1 if approved |
| Sat Dec 5 | G4 Gold recording | P2, and E6 with outside players |

The play-logic review asks the student to pick a rule (A, B, C or as built), the second PRESS
and five fixes. That is separate work with its own brief. P0 does not meet it. P1 touches the
same functions (`act_say`, `apply_dialogue`, `settlement`, `press`), so do one at a time, the
rule pick first if both are approved.

## 9. Do not touch

- `docs/g1/01` to `04`, `06` and `07`, the slides and the narration.
- `agent_proxy/.dev.vars`, and the November 15 ledger.
- The sibling `fathom` folder, and any other repository on this machine.
- `game/assets/` by hand: art and sound come from `tools/art/`.
- The Braintrust item (`HANDOFF.md`, "Next three tasks", item 1).
- The cap of sixteen replies a visit.
