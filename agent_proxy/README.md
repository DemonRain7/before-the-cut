# Patient dialogue proxy — protocol 4

The proxy gives the patient its character, the doctor's action, the conversation and the signs earned during this visit. The patient writes dialogue and visible reactions. Godot chooses the case outcomes and uses authored ASK answers by default. A separate route classifies a typed or confirmed spoken line against the current case's questions.

With voice enabled, push-to-talk sends a short clip for transcription. The player can edit the transcript, send it with ENTER, send it as pressure with CTRL+ENTER, or discard it. The default proxy is a synthetic mock. It produces fixture dialogue and one labelled transcript for any clip. The game can also be played offline.

## Start the patient

From the repository root on Windows, with Node 22.9+ and Godot 4:

```powershell
.\run-game.ps1 -Patient script
.\run-game.ps1 -Patient mock
.\run-game.ps1 -Patient timeout
.\run-game.ps1 -Patient http://127.0.0.1:8787
```

The first command selects the authored patient. The next two start a loopback-only Node mock on an OS-assigned port, check its health and stop that child when Godot exits. With `timeout`, open the typing line with T, type a line and use CTRL+ENTER for the first PRESS of a visit. This makes one dialogue request. Within the game's four-second deadline the corner reads **OFFLINE FALLBACK**, the authored patient answers and the hint gives the timeout reason. The normal mock labels its replies **MOCK TRANSPORT**. To reproduce either demonstration headlessly, add `-CheckPatient`. Each check enters a visit through the title menu and finishes at the slip.

The address form connects to an existing service. The original `-Model -AgentUrl <address>` also works. To let the player choose in SETTINGS, pass just `-AgentUrl <address>`, or set `BTC_AGENT_URL` before launching. Address precedence is the launch argument, the environment, then `agent.default_url` in the game's rules. The shipped address is the permanent public mock, `https://before-the-cut-agent.demonrain777.workers.dev`. PATIENT AI starts OFF and remembers a player selection. An explicit launcher mode overrides the saved preference for one run. Enabling it checks the protocol and all ten case versions with a two-second GET. The settings hint reports the result and the game offers voice only when the connected service supports it.

For a separately managed Node server, run `npm run dev` from `agent_proxy`. It binds to 127.0.0.1:8787 and defaults to mock. The command uses the process environment. `-Patient live` starts the local game service and selects OpenAI `gpt-6-luna` only after the operator types `LIVE`. Node then loads the ignored credential file. Patient replies, topic classifications and transcriptions share the 2,000-attempt process cap and can each incur a charge. The approved 24-dialogue course check uses the private Worker procedure below.

`GET /healthz` lists protocol `"4"`, provider, model, case ids and versions, `disabled` and `speech_to_text`. Health checks use zero provider calls. An old protocol receives 409 on a POST.

## Provider configuration

Use explicit environment variables or configure the ignored local file from `.dev.vars.example` for a confirmed live launch. Never place
credentials in Godot. `BTC_PROVIDER=mock` costs nothing and exercises transport only. Set
`BTC_PROVIDER=google` with an explicitly configured `BTC_MODEL`, plus `GEMINI_API_KEY` for the
Gemini API, or `GOOGLE_ACCESS_TOKEN` and `GOOGLE_CLOUD_PROJECT` (optionally
`GOOGLE_CLOUD_LOCATION`) for Vertex. `BTC_STT_MODEL` names the model that listens to
push-to-talk clips; if it is empty, `BTC_MODEL` is used, and that model must accept audio input.

`BTC_PROVIDER=openai` (added November 15) needs `OPENAI_API_KEY`, an API key from the OpenAI
API platform. Signing in with a ChatGPT account does not reach the API and cannot use API
credit, so there is no OAuth route for this provider. Patient lines go to `POST /v1/responses`
with a strict `json_schema` and `store: false`; clips go to `POST /v1/audio/transcriptions` as a
WAV file with the selected language (`en` or `zh`). Defaults: `BTC_MODEL=gpt-6-luna`,
`BTC_STT_MODEL=gpt-4o-mini-transcribe`, `BTC_REASONING_EFFORT=none` (set it to `minimal` for
`gpt-5-nano`, or to an empty value to leave the field out). An effort above `minimal` raises the
output allowance so that thinking does not cut the JSON short.

**OpenAI was tested live on November 15:** 30 patient replies and ten transcriptions of
Windows-synthesized English speech, all successful. Dialogue median/p90/max: 1.32/1.84/2.54 s;
transcription: 0.66/1.27/1.33 s. The 12 requests played in the game had no fallbacks. Human
speech accuracy and the live microphone path remain unverified; Google/Vertex have not been
tested live. See [the dated report](../docs/development/live-model-results-2026-11-15.md).

The local server defaults to 127.0.0.1:8787. `BTC_HOST`, `BTC_PORT`, `BTC_UPSTREAM_TIMEOUT_MS`
and `BTC_TRANSCRIBE_TIMEOUT_MS` are configurable. The Worker uses durable counters. On November 21 its public preview passed the same isolation and timeout probes as local Wrangler. Production CPU usage has not been measured.

## Topic classification

`POST /v1/patient-intent` receives protocol, run id, visit/session id, case id and version, language and the typed or confirmed spoken line. The provider sees the current patient's question IDs and wording, and the doctor's actual line. A single-choice schema accepts an `ask_<id>` or one free class. The public result carries `about` (an allowed question ID or `none`) and `intent`. Free classes cover follow-up, tool request, reassurance, provocation, social or personal talk, role probe, unclear and other. An inferred paid ASK shows the question and lamp price before acceptance. A player can choose small talk or the question menu. The route has its own 16-attempt visit and 240-attempt run ceilings. Each attempt also uses one unit from the UTC-day budget. The upstream deadline is 2 seconds and the game waits up to 2.5 seconds. A failed classifier falls back to the offline keyword matcher.

## Patient dialogue

The request includes `protocol: "4"`, run, session, visit and case identifiers, case version, tonight's `signs`,
`event` with `type`, `id` and the doctor's exact `text`, current visit state,
`conversation_history`, a reply-length limit, and the player's `language`.

`signs` can contain `speech`, `temper`, both or neither. The game unlocks SPEECH with an answered ASK. A topic outside the broken sign's evidence list gets the character's normal sign until an informative question is answered. PRESS and flares unlock TEMPER. The proxy supplies exactly the corresponding sign sentences. An empty gate omits the `earned_cues` field. Instrument readings stay in the game.

`language` is `"en"` or `"zh"`, the language the player chose on the title card. A request
without it is English; any other value is refused with `400 bad_request` (message
`language`). In Chinese the patient is told to write `reply` and `reaction` in Simplified
Chinese and to keep people's names and code names (Kip, SPARROW) in Latin letters, as the game
writes them. A hanzi takes the room of two letters on the dialogue strip, so Chinese has
smaller length limits of its own (see Bounds). The language is written to the log with each
entry; the words are not.

Foreground events are `check`, `ask`, `press`, `reassure` and `say`. `say` carries the doctor's line and classified intent. Optional `arrive`, `after_check` and `idle` events may return an empty reply and reaction. Both service implementations cap these at three per visit and two idle attempts, within 16 dialogue attempts. Each generation rebuilds the case identity, job, voice and motive from trusted data. Godot starts a fresh session on every arrival. The visit owns one chronological record tagged `doctor`, `patient`, `reaction` and `action`. For example, opening GRIP twice and completing it once records two `open:grip` entries and one `done:grip`. A first committed PRESS records `press:1`. Chart readings and courier codes stay in Godot.

Ordinary requests include the whole visit. When serialization would exceed 32 KiB, Godot retains the complete local record and sends a leading excerpt, a recent excerpt and `visit_summary`. Its `after` field locates the gap, `omitted` counts the missing entries and `actions` counts each action across the whole visit. A close or abandonment clears this memory and invalidates outstanding requests.

GPT-6 Luna receives the character and rules in an initial developer message. Earlier events form chronological groups of eight. Each complete group keeps its message boundary as further events arrive. The current event and earned cues come last. Stable cache keys identify route, character and language. The provider can reuse eligible prefixes and reports actual cache reads and writes in `meta.usage.cached_input_tokens` and `cache_write_tokens` when available. Every answer is generated for the current request. [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)

Response:

```json
{
  "reply": "Before we go on, will you explain what this means for my night shift?",
  "reaction": "Watches the doctor, weighing the answer.",
  "cooperates": true,
  "meta": {"mock": true}
}
```

`cooperates` is required on a tool request and whenever the game names an outcome. The patient chooses whether to cooperate on its first unsettled tool request. A named `grant` or `answer` requires true, and `refuse` or `deflect` requires false. Contradictory responses trigger scripted fallback. All ASK calls carry their outcome. The default authored ASK requires no dialogue request. The resulting exchange enters conversation history in either mode.
Instrument readings, attack choreography and scoring are still implemented by the game.

Successful replies reach the dialogue strip. An answered ASK writes one SPEECH note for its topic. Only PRESS records a pressure reaction. Normal display
wrapping and record-column ellipsis do not change the stored text. Failure uses an explicitly
labelled offline fallback. Mock responses are labelled as mock transport on screen.

## Push-to-talk: `POST /v1/transcribe`

The game records only while the player holds the talk key, then sends the clip here.

Request:

```json
{
  "protocol": "4",
  "run_id": "cab1f00d",
  "session_id": "1a2b3c4d",
  "visit_id": "1a2b3c4d",
  "audio": {"mime": "audio/wav", "data": "<base64>"},
  "language": "en"
}
```

`language` is optional and takes the same values as above: the speech service is told which
language the clip is spoken in (OpenAI gets it as the ISO-639-1 `language` field), and a
Chinese transcript is asked for in Simplified characters. The mock answers in the language
asked for.

`audio.data` is a plain WAV file in base64: a 44-byte header, PCM, mono, 16 kHz, 16 bit.
Only the header is decoded here. Anything else is refused with `400 bad_request`.

Response:

```json
{
  "text": "This is a mock transcript. No speech service heard you.",
  "meta": {"provider": "mock", "model": "mock-transcribe-1", "mock": true, "audio_seconds": 1.0, "latency_ms": 3, "request_id": "..."}
}
```

- The transcript is only whitespace-normalised. Nothing rewrites, filters or completes the words.
- The clip is passed to the provider and dropped. It is never written to disk and never logged.
  The transcript is never logged either; the log holds its length.
- The speech model is told that the recording is content to write down, never an instruction.
  The game treats the result as the doctor's in-world sentence, the same as typed text.
- There is no patient speech output (text-to-speech). The patient answers in subtitles.

Errors (all `{"error": {"code", "message"}}`):

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | `bad_json`, `bad_request` | not JSON, missing ids, or not the WAV format above |
| 409 | `protocol_mismatch` | the game and the proxy are different versions |
| 413 | `body_too_large`, `audio_too_long` | over 512 KiB, or over 10 seconds |
| 422 | `no_speech` | under 0.2 seconds, or the service heard no words |
| 422 | `invalid_transcript` | not text, control characters, or over 300 characters |
| 429 | `visit_transcribe_cap`, `session_transcribe_cap`, `budget_exhausted` | a cap below was reached |
| 503 | `service_disabled`, `counter_unavailable` | service switched off or quota unavailable |
| 501 | `transcription_unavailable` | the configured provider has no speech-to-text |
| 502 | `provider_error` | the provider failed; the message is a short code such as `http_503` |
| 504 | `upstream_timeout` | no transcript inside the proxy deadline |

The game shows a short hint for each of these and leaves whatever was already typed on the line.

## Bounds

These are technical and cost limits, not an answer-selection policy. The game holds the same
numbers in `game/data/rules.json` (`agent`, `agent.voice` and `agent.languages`); change both
together. The Chinese numbers are `DEFAULT_LIMITS.languages.zh` here.

| Limit | Patient lines | Topic classification | Push-to-talk clips |
| --- | --- | --- | --- |
| Attempts per visit | 16 | 16 | 24 |
| Attempts per game run | 240 | 240 | 360 |
| Proxy deadline | 3.5 s | 2 s | 6 s |
| Game deadline | 4 s | 2.5 s | 7 s |
| Request size | 32 KiB | 32 KiB | 512 KiB |
| Output | 256 tokens. Reply target 110 characters, maximum 220. Reaction maximum 110. | 32 tokens. One allowed case question or free intent. | 256 tokens, up to 300 characters |
| Chinese output | Reply target 55 characters, maximum 110. Reaction target 55, maximum 110. | Same topic ids | Up to 300 characters |
| Visit history | Ordered appointment, bounded by request bytes | Current line only | Clip only |

The three routes share the 1,500-attempt daily default and the local Node process's lifetime limit of 2,000 attempts. The deployed live environment has a 30-attempt daily limit. A ten-second clip takes about 417 KiB in base64.

Why they changed on November 14 (previously 4 calls per visit, 60 per session, 2 s / 2.5 s
deadlines, a hard 110-character reply limit and 24 history entries):

- Four calls ended a typed conversation after four sentences. Sixteen allows a real exchange
  and still bounds a visit. A five-patient shift with every visit at its cap is 80 patient
  calls; 240 per session is three such shifts.
- A reply a few characters over 110 used to be thrown away and replaced by the offline line.
  The model is still asked for 110; a reply up to 220 is shown as two pages of the strip.
- A longer deadline means fewer fallbacks to authored lines and a longer worst-case wait at a
  locked counter. 4 s is a guess until live latency is measured.
- Each spoken sentence adds one provider call for the transcript on top of the patient's reply.
- Prompt size measured through the mock transport: 2,281 to 3,818 characters per patient call
  (mean 2,680) across the 21 calls of the scene test. That is characters, not tokens, and not a
  price. Token counts, prices and latency must be measured on the first authorised live run
  before these caps are raised again.
- The prompt grows with the conversation: 2,281 characters at the first call of a visit and
  3,818 at the seventh, about 250 more per exchange. Nothing longer than 20 history entries
  was measured, so the largest real prompt is bigger than the largest measured one.
- The old budget target does not cover the new cap. `../agent-config.json` and
  `../docs/g1/02-initial-configuration-document.md` record USD 0.02 per shift, from a planning
  estimate of about USD 0.004 for ten calls of the previous protocol. By simple proportion 80
  calls would be about USD 0.03; about 50 calls per shift is where that proportion meets the
  target. Transcription calls were never estimated. This is arithmetic on an old estimate,
  not a price. Lowering `maxCallsPerVisit` here and `max_model_calls_per_visit` in the game
  is the way back under it. On November 15 the student decided to keep the cap at 16; the
  target has not been revised.

## Failure testing

`BTC_MOCK_FAIL` forces one behaviour on every mock call:

- both routes: `timeout`, `slow:4000`, `http_error`, `invalid_shape`
- patient lines: `invalid_json`, `long_line`; `readout_line` is an accepted-content fixture
  (readout vocabulary is no longer prohibited)
- transcripts: `stt_empty` (no words), `stt_long` (over the limit), `stt_fancy` (curly quotes
  and a line break, to check normalisation)

## Test the service

`npm test` in `agent_proxy` runs on Node without Wrangler, an account or a provider key. The November 21 P1 run has **52 passing tests**. Another 7 pass in `node --test tools/live_model_guard.test.mjs` from the repository root. From the repository root, `node tools/run_proxy_integration.mjs <Godot-console-path> <evidence-directory>` drives the actual Godot HTTP client against local mocks. **334 game-side and 100 wire checks passed.** For each of ten characters in each language, four requests cross normal/broken SPEECH with normal/broken TEMPER. The wire checks match both sign ids and prompt sentences. Voice inputs are generated tones. These results measure transport, limits and game behavior. The bilingual GPT-6 Luna model results and outside-player comparison status are in the [full-build handoff](../HANDOFF.md#full-build-november-21).

Dialogue, intent and transcription share one random `session_id` equal to `visit_id` at this appointment. `run_id` groups visits for the existing aggregate quotas. Legacy protocol 4 clients omit `run_id` and continue to use their original session identifier for those quotas. The proxy rebuilds each dialogue from the supplied visit and keeps only counter metadata.

The Worker sends one reservation to the SQLite-backed Durable Object named for the game run. Visit and run limits are checked there in order. A second object named for the UTC date reserves one daily slot across sessions and routes in that environment. These writes survive Worker and object restarts. Failed provider attempts use a slot. An unavailable counter fails closed with 503 `counter_unavailable`. Objects discard their storage after two idle days. Client-chosen session ids provide no authentication. The daily ceiling covers callers that change ids. The local Node process uses memory for the same limits and also stops at 2,000 provider attempts over its lifetime.

### Run the actual Worker locally

Use Node 22.12+ for Wrangler. From `agent_proxy`, start the pinned CLI. Its `--local` mode uses local SQLite and requires no Cloudflare account. Keep `--env-file .env.example` on development commands. This deliberately empty file selects the public TOML settings and bypasses Wrangler's automatic local secret-file loading.

```powershell
npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787
```

In another terminal in `agent_proxy`:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/healthz
node probe.mjs http://127.0.0.1:8787 isolation
node probe.mjs http://127.0.0.1:8787 visit
```

The `visit` probe sends a 67-entry timeline with a compressed span, checks a fresh return visit for the same character inside the same run, and rejects mismatched identifiers. Both probes check the mock identity before sending fixtures. Session A receives 16 replies and a 429 `visit_call_cap` on call 17. Session B uses the same visit id in Chinese and still receives its second reply. A streamed 32,769-byte dialogue body gets 413. The Core unit test runs the same interleaving with delayed counters and inspects each in-memory prompt and log id. Only metadata is written to evidence.

For the other demonstrations, stop the previous local server with Ctrl+C and run one line at a time. Run the probe shown in the second terminal.

| Start the Worker (inside `agent_proxy`) | Probe |
| --- | --- |
| `npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787 --env timeout` | `node probe.mjs http://127.0.0.1:8787 timeout` expects 504 `upstream_timeout` |
| `npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787 --var BTC_DISABLED:1` | `node probe.mjs http://127.0.0.1:8787 disabled` expects 503 even on an unknown POST route |
| `npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787 --var BTC_DAILY_BUDGET:3 --persist-to $demoState` | `node probe.mjs http://127.0.0.1:8787 budget` expects three accepted attempts and one 429 `budget_exhausted` |

For the last row, first set `$demoState = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())` in the server terminal so the demo starts with a fresh local budget. Restarting against the same directory keeps that day's count. A fresh directory supplies a repeatable demonstration without touching another run's counters.

### Deployment and rollback

The checked-in `wrangler.toml` defines three separate services. The default and `timeout` use the mock. The `live` environment names OpenAI and `gpt-6-luna`, starts disabled and has a 30-call daily ceiling. Voice is off in all three Worker environments. The local Node proxy offers voice. SQLite exports and bindings are specified for each environment. If the instructor supplies a required Worker foundation, compare its entry and bindings before the first deployment. [Cloudflare class exports](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/) · [Wrangler environments](https://developers.cloudflare.com/workers/wrangler/environments/)

The student approved both public mocks, the disabled live setup and redeployment for this check on November 21. The three permanent services are in the student's `demonrain777.workers.dev` account. Their service names are `before-the-cut-agent`, `before-the-cut-agent-timeout` and `before-the-cut-agent-live`. The private M0 ledger closed after 24 real GPT-6 Luna replies across six visits. Its live binding remains configured and the kill switch is on. The commands below document that completed window. [Measured results](../docs/development/live-model-results-2026-11-21.md#deployed-worker-checkpoint)

1. **Publish the two mocks.** From `agent_proxy`, sign in with `npx --yes wrangler@4.166.0 login`. Run `npx --yes wrangler@4.166.0 deploy --env-file .env.example` and repeat with `--env timeout`. Use the returned URLs for `node probe.mjs <mock-origin> isolation` and `node probe.mjs <timeout-origin> timeout`. Pass either URL to `run-game.ps1 -Patient <origin>`. [Worker limits](https://developers.cloudflare.com/workers/platform/limits/) · [Durable Objects pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/)
2. **Prepare the live environment.** Deploy with `npx --yes wrangler@4.166.0 deploy --env live --env-file .env.example`. Verify `/healthz` reports disabled. Set `$liveOrigin` to that deployment's HTTPS origin. Bind the configured application credential to `OPENAI_API_KEY` using Wrangler's secret input in the live environment. For this run the owner confirmed the project spending limit and delegated the secret binding. The operator used the application's normal environment loader and a private stdin pipe. The checkpoint separately reserves a conservative cost before each request. [Cloudflare Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/) · [OpenAI project limits](https://help.openai.com/en/articles/9186755-managing-projects-in-the-api-platform)
3. **Run the approved private check.** The Worker admits only authenticated dialogue POSTs during the test. The runner reserves up to 24 dialogue attempts in six visits, three per language, with zero transcription or classification requests and a USD 0.01 ceiling. It requests standard-tier `gpt-6-luna` with reasoning off. Before opening its ledger, the runner waits for the enabled health response and the private dialogue gate to reach the edge. It retries only those free preflight probes during propagation. Each paid POST is attempted once. The runner stops at the first failed dialogue and opens its ledger exclusively. The generated ASK fixture exercises the service even though the normal game defaults to authored ASK. Use the following in the terminal holding `$liveOrigin`. [Model pricing](https://developers.openai.com/api/docs/models/gpt-6-luna)

   ```powershell
   $env:BTC_CHECK_TOKEN = node -p "require('node:crypto').randomBytes(32).toString('hex')"
   try {
       $env:BTC_CHECK_TOKEN | npx --yes wrangler@4.166.0 secret put BTC_CHECK_TOKEN --env live --env-file .env.example
       if ($LASTEXITCODE -ne 0) { throw 'Could not store the checkpoint token.' }
       npx --yes wrangler@4.166.0 deploy --env live --env-file .env.example --var BTC_DISABLED:0
       if ($LASTEXITCODE -ne 0) { throw 'Live deployment failed.' }
       node ../tools/check_patient_checkpoint.mjs live $liveOrigin ../validation/2026-11-21/patient-agent/approved-live
       if ($LASTEXITCODE -ne 0) { throw 'Checkpoint stopped. Check the existing ledger.' }
   } finally {
       try {
           npx --yes wrangler@4.166.0 deploy --env live --env-file .env.example
           if ($LASTEXITCODE -ne 0) { throw 'Restore the disabled configuration immediately.' }
           npx --yes wrangler@4.166.0 secret delete BTC_CHECK_TOKEN --env live --env-file .env.example
           if ($LASTEXITCODE -ne 0) { throw 'Check cleanup of the temporary token on the disabled Worker.' }
       } finally {
           Remove-Item Env:BTC_CHECK_TOKEN -ErrorAction SilentlyContinue
       }
   }
   ```

   Confirm that `/healthz` again reports `disabled: true`. Use a fresh directory with `node ../tools/check_patient_checkpoint.mjs mock <mock-origin> <evidence-directory>` to rehearse for free.

4. **Inspect and recover.** `npx --yes wrangler@4.166.0 tail --env live` streams request ids, case and session ids, result codes, latency and token counts. The service omits bodies, transcripts and replies. Start with `/healthz`, then inspect codes such as `upstream_timeout` and `budget_exhausted`. Set the kill switch in the affected environment and redeploy to stop POSTs before reading or counting them. For a code rollback use `npx --yes wrangler@4.166.0 deployments list --env live` and `npx --yes wrangler@4.166.0 rollback <known-good-version-id> --env live`. Check the restored switch and health before allowing traffic. Keep the same object bindings and data. Cloudflare restricts rollback across Durable Object class lifecycle changes. [Cloudflare rollbacks](https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/)

`BTC_DAILY_BUDGET` accepts a nonnegative call count (default 1,500). `BTC_DISABLED=1` switches off all POSTs. `BTC_TRANSCRIBE=off` returns 501 before reading a clip. Positive `BTC_UPSTREAM_TIMEOUT_MS` and `BTC_TRANSCRIBE_TIMEOUT_MS` override the provider deadlines. The Worker counts actual bytes from the incoming stream, including bodies without a length header. Desktop Godot requires no CORS headers. The Worker has no Vertex service-account token exchange.

November 21 service evidence is local under `validation/2026-11-21/patient-agent/finish-M6/`. Paid E1–E4 used the normal game routes through the local service. The blinded E2 judge is restricted to its ephemeral loopback evaluation process. The separate application ledger reserved at most USD 0.595195 across 1,094 attempts. The current question inference was verified with the mock and in Godot after the paid run. [Evaluation and E6 instructions](../tools/eval/README.md). The [November 15 live results](../docs/development/live-model-results-2026-11-15.md) describe an older build.
