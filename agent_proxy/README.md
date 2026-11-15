# Patient dialogue proxy — protocol 3

This server gives the patient model its character background, the player's current action
and the recent conversation. The model generates its own spoken reply and visible reaction.
There is no answer bank, legal-move enum or substitution of an authored line after generation.

It has a second, separate job for push-to-talk: it turns one short spoken clip from the
player into text. The text goes back to the game's typing line. It is not sent to the patient
until the player presses ENTER.

The Godot game remains playable offline using the authored comparison. Real AI requires
a configured provider; the default proxy is a **synthetic mock**, not an intelligent patient
and not a speech service. The mock cannot hear: it returns the same labelled sentence for any clip.

## Run locally

Node 22.9 or newer; no npm dependencies.

```powershell
cd agent_proxy
npm run dev
```

Then from the project root:

```powershell
.\run-game.ps1 -Model -AgentUrl http://127.0.0.1:8787
```

Both the proxy and the game must speak protocol 3; a protocol 2 client gets `409 protocol_mismatch`.
`GET /healthz` reports protocol 3, the provider, five cases and `speech_to_text: true|false`.

Checked on November 14 and again on November 15 with the mock provider on a spare port, using
the command that `npm run dev` runs: the server started, `/healthz` answered 200 with
`speech_to_text: true`, and both POST routes refused an old-protocol body with 409. The game
window was not opened for that check. The November 15 output is in
`validation/2026-11-15/claude-rendered-checks/proxy-start.log`.

## Provider configuration

Use environment variables or the ignored `.dev.vars` (copy `.dev.vars.example`). Never place
credentials in Godot. `BTC_PROVIDER=mock` costs nothing and exercises transport only. Set
`BTC_PROVIDER=google` with an explicitly configured `BTC_MODEL`, plus `GEMINI_API_KEY` for the
Gemini API, or `GOOGLE_ACCESS_TOKEN` and `GOOGLE_CLOUD_PROJECT` (optionally
`GOOGLE_CLOUD_LOCATION`) for Vertex. `BTC_STT_MODEL` names the model that listens to
push-to-talk clips; if it is empty, `BTC_MODEL` is used, and that model must accept audio input.

`BTC_PROVIDER=openai` (added November 15) needs `OPENAI_API_KEY`, an API key from the OpenAI
API platform. Signing in with a ChatGPT account does not reach the API and cannot use API
credit, so there is no OAuth route for this provider. Patient lines go to `POST /v1/responses`
with a strict `json_schema` and `store: false`; clips go to `POST /v1/audio/transcriptions` as a
WAV file with `language=en`. Defaults: `BTC_MODEL=gpt-6-luna`,
`BTC_STT_MODEL=gpt-4o-mini-transcribe`, `BTC_REASONING_EFFORT=none` (set it to `minimal` for
`gpt-5-nano`, or to an empty value to leave the field out). An effort above `minimal` raises the
output allowance so that thinking does not cut the JSON short.

**No live provider call has been made for any route.** Availability, cost, latency,
transcription quality and whether the default model accepts audio are all unverified.

The local server defaults to 127.0.0.1:8787. `BTC_HOST`, `BTC_PORT`, `BTC_UPSTREAM_TIMEOUT_MS`
and `BTC_TRANSCRIBE_TIMEOUT_MS` are configurable. Deployment remains untested; the Worker
entry needs shared counters and deployment/authentication review before external use.

## Patient dialogue: `POST /v1/patient-dialogue`

Request: `protocol: "3"`, session/visit/case identifiers, case version, `event`
with `type`, `id` and the doctor's exact `text`, current visit state,
`conversation_history`, and a reply-length limit.

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
  "audio": {"mime": "audio/wav", "data": "<base64>"}
}
```

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
| 501 | `transcription_unavailable` | the configured provider has no speech-to-text |
| 502 | `provider_error` | the provider failed; the message is a short code such as `http_503` |
| 504 | `upstream_timeout` | no transcript inside the proxy deadline |

The game shows a short hint for each of these and leaves whatever was already typed on the line.

## Bounds

These are technical and cost limits, not an answer-selection policy. The game holds the same
numbers in `game/data/rules.json` (`agent` and `agent.voice`); change both together.

| Limit | Patient lines | Push-to-talk clips |
| --- | --- | --- |
| Attempts per visit | 16 | 24 |
| Attempts per session | 240 | 360 |
| Provider calls per proxy process | 2,000, shared by both routes | |
| Proxy deadline | 3.5 s | 6 s |
| Game deadline | 4 s | 7 s |
| Request size | 32 KiB | 512 KiB (10 s of audio is about 417 KiB in base64) |
| Output | 256 tokens; reply asked at 110 characters, refused only over 220; reaction up to 110 | 256 tokens; transcript up to 300 characters |
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

```powershell
npm test
```

runs the three test files (`test/core.test.mjs`, `test/transcribe.test.mjs`,
`test/openai.test.mjs`): 38 tests, 38 passing on November 15. The OpenAI tests use a fake
`fetch`; nothing is sent to OpenAI.

From the root, `node tools/run_proxy_integration.mjs <Godot-console-path> [output-folder]` runs
a real headless Godot HTTP client against local mock servers, one per failure mode, and plays
typed and spoken conversations in the actual scene with a simulated microphone. No device is
opened, no credentials are read and no paid calls occur. November 15 result in this
repository: 179 game-side checks and 15 wire checks, all passing.

Current evidence is local (`validation/` is not in the repository): `validation/2026-11-15/transfer-checks/`
(every check, run in this checkout after the transfer; the HTTP run's requests, wire checks and
prompt sizes are in its `http-integration/` folder), `validation/2026-11-15/claude-mock-voice/`
(push-to-talk in a real window with the real microphone and this mock) and
`validation/2026-11-15/claude-rendered-checks/` (the earlier run with source hashes). Earlier runs, all from November 14, are in
`validation/2026-11-14/claude-final-checks/`, `validation/2026-11-14/claude-voice-input/`
(voice and typed lines), `validation/2026-11-14/claude-typed-dialogue/` (typed lines) and
`validation/2026-11-14/autonomous-runtime/` (the protocol 3 migration). See `HANDOFF.md`, "Game runtime: current state", for exact current results. The November 12 results describe an older prototype and are not
evidence for this implementation.

Logs contain identifiers, action types, timing, sizes and usage counts, not conversation text,
audio or transcripts. The game keeps its recent conversation in memory only. Synthetic mocks do
not measure agent believability, speech recognition, live latency or real cost.

## What a live setup still needs

1. The student's yes to the spend, and a key or Vertex token in `.dev.vars`. `mock`, `google`
   and `openai` exist in `src/providers.mjs`.
2. A model name that exists for that account, and for push-to-talk one that accepts audio.
3. One supervised run: watch `latency_ms`, `input_tokens` and `output_tokens` in the proxy log,
   compare them with the deadlines and caps above, and listen for transcription quality.
4. `maxOutputTokens: 256` has not been checked against a model that spends output tokens on
   thinking; a truncated JSON answer would show up as `invalid_model_output` or `provider_error`.
