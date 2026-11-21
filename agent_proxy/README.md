# Patient dialogue proxy — protocol 3

This server gives the patient model its character background, the player's current action
and the recent conversation. The model generates its own spoken reply and visible reaction.
There is no answer bank, legal-move enum or substitution of an authored line after generation.

It has a second, separate job for push-to-talk: it turns one short spoken clip from the
player into text. The text goes back to the game's typing line. It is not sent to the patient
until the player presses ENTER.

The Godot game remains playable offline using the authored comparison. Real AI requires
a configured provider; the default proxy is a **synthetic mock**, not an intelligent patient
and not a speech service. The mock cannot hear: it returns the same labelled sentence for any clip,
in the language the game asks for.

## Start the patient

From the repository root on Windows, with Node 22.9+ and Godot 4:

```powershell
.\run-game.ps1 -Patient script
.\run-game.ps1 -Patient mock
.\run-game.ps1 -Patient timeout
.\run-game.ps1 -Patient http://127.0.0.1:8787
```

The first command selects the authored patient. The next two start a loopback-only Node mock on an OS-assigned port, check its health and stop that child when Godot exits. With `timeout`, open the typing line with T, type a question and press ENTER. Within the game's four-second deadline the corner reads **OFFLINE FALLBACK**, the authored patient answers and the hint gives the timeout reason. The normal mock labels its replies **MOCK TRANSPORT**. To reproduce either demonstration headlessly, add `-CheckPatient`. Each check enters a visit through the title menu and finishes at the slip.

The address form connects to an existing service. The original `-Model -AgentUrl <address>` also works. To let the player choose in SETTINGS, pass just `-AgentUrl <address>`, or set `BTC_AGENT_URL` before launching. Address precedence is the launch argument, the environment, then `agent.default_url` in the game's rules. The shipped address is empty. PATIENT AI starts OFF and remembers a player selection. An explicit launcher mode overrides the saved preference for one run. Enabling it checks the protocol and all ten case versions with a two-second GET. The settings hint reports the result and the game offers voice only when the connected service supports it.

For a separately managed Node server, run `npm run dev` from `agent_proxy`. It binds to 127.0.0.1:8787 and defaults to mock. The command uses the process environment. `-Patient live` starts the configured local provider only after the operator types `LIVE`. Node then loads the ignored credential file. Both patient replies and transcriptions can cost money and share the 2,000-attempt process cap. For the proposed 24-call course check use a separately approved, bounded test session.

`GET /healthz` lists protocol `"3"`, provider, model, case ids and versions, `disabled` and `speech_to_text`. Health checks use zero provider calls. An old protocol receives 409 on a POST.

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
and `BTC_TRANSCRIBE_TIMEOUT_MS` are configurable. The Worker uses durable counters and has been exercised under local Wrangler. The public deployment and its real CPU usage are pending.

## Patient dialogue: `POST /v1/patient-dialogue`

Request: `protocol: "3"`, session/visit/case identifiers, case version, tonight's `signs`,
`event` with `type`, `id` and the doctor's exact `text`, current visit state,
`conversation_history`, a reply-length limit, and the player's `language`.

`signs` is `{"speech": id, "temper": id}`: the sign each of those two rows shows tonight, as
the game drew it from the case file's template (`game/data/cases/<id>.json`, `signs`). Both
are required, no other row is accepted, and each id must be one of that row's normal or broken
signs for this patient; anything else is refused with `400 bad_request` (message `signs`). The
prompt adds each sign's `model` sentence after the reason for the visit (`Tonight: ...`). The
background in `src/character_profiles.mjs` holds on any night, so whether a patient drifts
reaches the model only through these two sentences; the other rows (eyes, hands, port) are
the game's readings and are not sent.

`language` is `"en"` or `"zh"`, the language the player chose on the title card. A request
without it is English; any other value is refused with `400 bad_request` (message
`language`). In Chinese the patient is told to write `reply` and `reaction` in Simplified
Chinese and to keep people's names and code names (Kip, SPARROW) in Latin letters, as the game
writes them. A hanzi takes the room of two letters on the dialogue strip, so Chinese has
smaller length limits of its own (see Bounds). The language is written to the log with each
entry; the words are not.

Supported actions: `check`, `ask`, `press`, `reassure`, `say`. `say` carries a sentence the
player typed (or spoke and then sent) in their own words.
History entries have role `doctor`, `patient` or `reaction` and literal text.
The history is reset between patients. No legal-move list is transmitted.

Response:

```json
{
  "reply": "Before we go on, will you explain what this means for my night shift?",
  "reaction": "Watches the doctor, weighing the answer.",
  "cooperates": true,
  "meta": {"mock": true}
}
```

`cooperates` is required only for requested examinations. It lets the AI accept or refuse
a tool even if the offline case's authored options differ. It never selects the spoken line.
`reply` and `reaction` are original text. Only JSON shape, display size and control
characters are checked. Words about symptoms, instruments or implants are allowed.
Instrument readings, attack choreography and scoring are still implemented by the game.

Successful replies reach the dialogue UI and patient record unchanged. Normal display
wrapping and record-column ellipsis do not change the stored text. Failure uses an explicitly
labelled offline fallback. Mock responses are labelled as mock transport on screen.

## Push-to-talk: `POST /v1/transcribe`

The game records only while the player holds the talk key, then sends the clip here.

Request:

```json
{
  "protocol": "3",
  "session_id": "1a2b3c4d",
  "visit_id": "1a2b3c4d-2-rook",
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

| Limit | Patient lines | Push-to-talk clips |
| --- | --- | --- |
| Attempts per visit | 16 | 24 |
| Attempts per session | 240 | 360 |
| Provider attempts per UTC day | 1,500 across both routes by default | |
| Provider attempts per local Node process | 2,000 across both routes, including across dates | |
| Proxy deadline | 3.5 s | 6 s |
| Game deadline | 4 s | 7 s |
| Request size | 32 KiB | 512 KiB (10 s of audio is about 417 KiB in base64) |
| Output | 256 tokens; reply asked at 110 characters, refused only over 220; reaction up to 110 | 256 tokens; transcript up to 300 characters |
| Output in Chinese | reply asked at 55 characters, refused only over 110; reaction asked at 55, accepted up to 110 | the same as English |
| History | 48 most recent entries | none: a clip carries no conversation |

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

`npm test` in `agent_proxy` runs on Node without Wrangler, an account or a provider key. The November 21 P0 run has **47 passing tests**. From the repository root, `node tools/run_proxy_integration.mjs <Godot-console-path> <evidence-directory>` drives the actual Godot HTTP client against local mocks. **312 game-side and 96 wire checks passed.** For each of ten characters in each language, four requests cross normal/broken SPEECH with normal/broken TEMPER. The wire checks match both sign ids and prompt sentences. Voice inputs are generated tones. These results measure transport, limits and game behavior. Live model dialogue quality and a human player's experience remain unmeasured on this build.

For two separate sessions the game supplies a fresh random session id and sends only the current visit's conversation with each action. The proxy constructs a fresh prompt from that request's character, signs, language and history. It stores no conversation. Each night's visit id includes the night number so a returning character starts with a fresh visit allowance.

The Worker sends one reservation to the SQLite-backed Durable Object named for the session. Visit and session limits are checked there in order. A second object named for the UTC date reserves one daily slot across sessions and routes in that environment. These writes survive Worker and object restarts. Failed provider attempts use a slot. An unavailable counter fails closed with 503 `counter_unavailable`. Objects discard their storage after two idle days. Client-chosen session ids provide no authentication. The daily ceiling covers callers that change ids. The local Node process uses memory for the same limits and also stops at 2,000 provider attempts over its lifetime.

### Run the actual Worker locally

Use Node 22.12+ for Wrangler. From `agent_proxy`, start the pinned CLI. Its `--local` mode uses local SQLite and requires no Cloudflare account. Keep `--env-file .env.example` on development commands. This deliberately empty file selects the public TOML settings and bypasses Wrangler's automatic local secret-file loading.

```powershell
npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787
```

In another terminal in `agent_proxy`:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/healthz
node probe.mjs http://127.0.0.1:8787 isolation
```

The probe checks the mock identity before sending synthetic fixtures. Session A receives 16 replies and a 429 `visit_call_cap` on call 17. Session B uses the same visit id in Chinese and still receives its second reply. A streamed 32,769-byte dialogue body gets 413. The Core unit test runs the same interleaving with delayed counters and inspects each in-memory prompt and log id. Only metadata is written to evidence.

For the other demonstrations, stop the previous local server with Ctrl+C and run one line at a time. Run the probe shown in the second terminal.

| Start the Worker (inside `agent_proxy`) | Probe |
| --- | --- |
| `npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787 --env timeout` | `node probe.mjs http://127.0.0.1:8787 timeout` expects 504 `upstream_timeout` |
| `npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787 --var BTC_DISABLED:1` | `node probe.mjs http://127.0.0.1:8787 disabled` expects 503 even on an unknown POST route |
| `npx --yes wrangler@4.166.0 dev --local --env-file .env.example --port 8787 --var BTC_DAILY_BUDGET:3 --persist-to $demoState` | `node probe.mjs http://127.0.0.1:8787 budget` expects three accepted attempts and one 429 `budget_exhausted` |

For the last row, first set `$demoState = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())` in the server terminal so the demo starts with a fresh local budget. Restarting against the same directory keeps that day's count. A fresh directory supplies a repeatable demonstration without touching another run's counters.

### Deployment and rollback

The checked-in `wrangler.toml` defines three separate services. The default and `timeout` use the mock. The `live` environment names OpenAI and `gpt-6-luna`, starts disabled and has a 30-call daily ceiling. Voice is off in all three Worker environments. The local Node proxy offers voice. SQLite exports and bindings are specified for each environment. If the instructor supplies a required Worker foundation, compare its entry and bindings before the first deployment. [Cloudflare class exports](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/) · [Wrangler environments](https://developers.cloudflare.com/workers/wrangler/environments/)

1. **Deploy the mocks after approval.** The student runs `npx --yes wrangler@4.166.0 login` interactively. From `agent_proxy`, deploy with `npx --yes wrangler@4.166.0 deploy` and `npx --yes wrangler@4.166.0 deploy --env timeout`. Use the returned addresses for the isolation and timeout probes above. Pass the timeout address to the game for the on-screen demonstration. This fits the Workers and Durable Objects free allowances at the documented demonstration volume. [Worker limits](https://developers.cloudflare.com/workers/platform/limits/) · [Durable Objects pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/)
2. **Set up live after separate approval.** Deploy the disabled live config with `npx --yes wrangler@4.166.0 deploy --env live`. The student runs `npx --yes wrangler@4.166.0 secret put OPENAI_API_KEY --env live` and types the key at the hidden prompt. This publishes a new Worker version. Keep the key in that environment's secret store. Set the OpenAI project monthly spend limit and enable hard enforcement in the provider dashboard. Health should report disabled. [Cloudflare Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/) · [OpenAI project limits](https://help.openai.com/en/articles/9186755-managing-projects-in-the-api-platform)
3. **Enable calls only for the approved run.** Set `BTC_DISABLED = "0"` under `[env.live.vars]` for the approved window, deploy that environment, and check its health. Keep the test to its separately authorized number of attempts. A public service with a day ceiling of 30 can still serve other traffic. A private test window or access restriction is needed to reserve those calls for the class demo. Restore the disabled setting and redeploy immediately after the run. Keep the operator's consent for any later redeployment explicit.
4. **Inspect and recover.** `npx --yes wrangler@4.166.0 tail --env live` streams request ids, case and session ids, result codes, latency and token counts. The service omits bodies, transcripts and replies. Start with `/healthz`, then inspect codes such as `upstream_timeout` and `budget_exhausted`. Set the kill switch in the affected environment and redeploy to stop POSTs before reading or counting them. For a code rollback use `npx --yes wrangler@4.166.0 deployments list --env live` and `npx --yes wrangler@4.166.0 rollback <known-good-version-id> --env live`. Check the restored switch and health before allowing traffic. Keep the same object bindings and data. Cloudflare restricts rollback across Durable Object class lifecycle changes. [Cloudflare rollbacks](https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/)

`BTC_DAILY_BUDGET` accepts a nonnegative call count (default 1,500). `BTC_DISABLED=1` switches off all POSTs. `BTC_TRANSCRIBE=off` returns 501 before reading a clip. Positive `BTC_UPSTREAM_TIMEOUT_MS` and `BTC_TRANSCRIBE_TIMEOUT_MS` override the provider deadlines. The Worker counts actual bytes from the incoming stream, including bodies without a length header. Desktop Godot requires no CORS headers. The Worker has no Vertex service-account token exchange.

November 21 evidence is local under `validation/2026-11-21/patient-agent/`. All P0 checks were computed or used mocks, including local Wrangler. The [November 15 live results](../docs/development/live-model-results-2026-11-15.md) describe an older build.
