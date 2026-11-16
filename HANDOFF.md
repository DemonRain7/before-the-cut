# Before the Cut: handoff

Updated **November 15, 2026**. Communicate with the student in Chinese; write game text, code comments and project files in English.

**This repository is the only active checkout.** On November 15 the game, the patient-AI proxy and the tools were moved here from the legacy `fathom` workspace and checked here ([transition record](docs/development/repository-transition.md)). `fathom` is an archive; its long layered handoffs (`HANDOFF.md`, `CODEX_RUNTIME_HANDOFF.md`, `CLAUDE_VOICE_HANDOFF.md`, `CODEX_NEXT_HANDOFF.md`) are history, not instructions.

AI use: Claude wrote the earlier runtime history; Codex added the live-test results and speech-feedback correction. No student review of this update is recorded.

## Current checkpoint: first live run complete

The [dated report](docs/development/live-model-results-2026-11-15.md) is the source of truth.
The student explicitly authorized up to USD 50, revoked manual-only credential entry and
asked the assistant to supply voice input. The ignored local credential was configured
without reading or printing it. The completed run used **30 live dialogue calls and 10 live
transcriptions of Windows-synthesized speech**. The proxy and test windows are stopped;
the persistent ledger is stopped at 30/10. No additional paid run was made.

- Dialogue: median **1.32 s**, p90 **1.84 s**, max **2.54 s**, 30/30 successful.
- Transcription: median **0.66 s**, p90 **1.27 s**, max **1.33 s**, 10/10 successful.
  Synthetic WER: **0 errors / 80 words**. This is not the student's voice or a live microphone test.
- Reported usage: dialogue 20,917 input / 1,597 output tokens; speech 502 / 110.
  Published-token-price estimate: **USD 0.0040677**, not an inspected invoice.
- Codex operated two real game visits (Kip, Vale), six model calls each, with zero game fallbacks.
  Kip was correctly treated. Vale attacked after the correct Trauma Team call; the operator
  missed the shutter timing and was injured. Another 18 calls were HTTP probes across three
  characters. No human played or listened.
- 29 replies were inspected; one port reply was replaced by the tool result before review.
  The inspected replies stayed in character. One allowed deceptive claim contradicted a
  physical sign; the game's actual reading stayed fixed.
- Measured bug fixed: the results screen falsely quoted an authored sleep line that the
  model never said. Generated speech feedback now shows the actual recorded reply under
  neutral **PATIENT SAID**, without automatic normal/abnormal grading. Physical facts,
  outcomes, scoring and the fully scripted comparison retain their behavior.
- Checks after the correction: **505 rule checks**, **333 scene checks**, **5 normal-close
  checks** pass. Earlier proxy 38/38 and guard 6/6 checks remain applicable. The smoke harness
  has pre-existing shutdown resource warnings; do not describe it as warning-free.
- No prompt or limit tuning was warranted: retain **16 replies/visit**, **256 output tokens**
  and the existing deadlines.

Limits of this run: automatic text entry could not fill the game's field (paste is unsupported);
free dialogue was probed via HTTP. The automated GRIP hold was too short to complete that
physical measurement. A final synthetic feedback preview returned black; activation recovery
ended with `GetCursorPos` access denied. It was stopped, with no further desktop input.
The feedback change has regression coverage but still needs visual approval on an available desktop.

Local evidence: `validation/2026-11-15/codex-live-test/`, containing numeric metadata and
judgments only, no live replies, transcripts, audio or credential archive. The student was
asked whether to retain or clear the configured local key after testing; absent a new instruction,
it remains in the ignored file for normal application loading.

## Where things stand

- **G1 is submitted.** The student published the main post on November 14 at 23:16 New York and replaced its recording link at 23:41 (`before-the-cut-g1-recording-updated.mp4`, 5:30.33). See [docs/g1/05](docs/g1/05-submission-draft-and-checklist.md). The deck, PDF, Word script and video stay in the student's local workspace.
- **Still due:** two Braintrust replies to classmates' G1 pitches by **Thursday, November 19, 23:59 New York**. Draft them for the student's review; never send them. Then read the instructor's Approve/Hold comment.
- **The game** is version 0.3.0: one night at the counter with five patients (Kip, Rook, Vale, Juno, Maren) in a shuffled order, the first of a session steady, a Normal Reference Sheet, optional looks, tools, questions, reassurance and pressure in any order, a typing line, push-to-talk, TREAT or Trauma Team, attacks and the shutter, slips and an end-of-shift report. Controls, rules and spoilers: [game/README.md](game/README.md). Look, sound and design choices: [docs/development/direction.md](docs/development/direction.md).
- **The patient AI** (protocol 3) writes every reply and reaction from the character brief and the conversation so far; the authored script is the offline comparison and the fallback. The first live OpenAI run is complete; see the checkpoint above. Google and Vertex remain untested live.

## Student decisions, November 15

1. Recording is finished: the game window, mouse, keyboard, audio and microphone may be used for testing.
2. The student authorized the specified OpenAI run with a USD 50 ceiling, allowed assistant credential configuration and asked the assistant to supply voice input. The completed test used local synthetic speech and is explicitly not a human voice test.
3. The cap stays at 16 patient replies per visit.
4. The sentence in `AGENTS.md` that called voice a future task was replaced (done).
5. The repository transfer was left to the agent to schedule (done, November 15).

## Game runtime: current state

### What was done on November 15

Later in the day, from the student's list of things seen but not changed (Claude; automated checks and measurements only, nobody played or listened; evidence in `validation/2026-11-15/claude-mix-fixes/`):

- **Attack loudness.** Every sound of an attack plays 9 dB quieter (`ATTACK_TRIM_DB` in `game/scripts/ui/main.gd`, one number). Measured from a silent recording of the master bus (`--audio-driver Dummy` still mixes): the loudest second of an attack sat about 24 dB over the room; now 19 dB when the shutter catches it and 22 dB when it lands. The limiter was holding in 21% (caught) and 59% (landed) of 50 ms windows; now 0% and 8%. The room stays at -33 dBFS. -6 dB was tried first and was not enough for a landed attack.
- **Whine.** An early shutter fades the whine over 0.12 s instead of cutting it, and `whine.wav` (regenerated by `tools/art/gen_audio.py`) ends with a 60 ms release: its last millisecond went from 0.600 to 0.008 of full scale.
- **Arrival order.** `rules.json` `arrivals`: each shift shuffles `shift_order` from its seed; the first shift of a session opens with a steady patient. `--authored-order` keeps the listed order; the tests and captures use it. 40 seeds give at least 10 different orders.
- **Acting while the patient answers.** Looking, marking the sheet, picking up the TREAT stamp, opening the Trauma Team line and the shutter no longer wait for a reply. A look shows its own line and holds the dots off for 1.6 s. TREAT or the call decide at once and drop the reply (`reply_dropped` in the event log, with the stage). Asking, tools, CALM, PRESS, typing and speaking still wait; after 0.8 s the strip says "Still answering. You can look meanwhile, or decide now." Offline and with the mock there is no wait beyond the doctor's own line typing; the live wait is unmeasured (deadlines 3.5 s / 4 s).
- **Blood** was left alone at the student's request.
- **Live-test brief** for Codex: [docs/development/live-model-test.md](docs/development/live-model-test.md).

Earlier on November 15:

- **Agent-operated play in a real window** (`validation/2026-11-15/claude-window-play/`). Claude drove the built game in a real Windows window on the real GPU and sound driver through posted window messages, captured screens with `PrintWindow`, and recorded the master mix. Offline: two full shifts plus part of a third, every pad, the typing line, both decisions, false calls and alarms, both attacks with a late and an early shutter, a walk-out, the reports, a 3x window and `--less-blood`. Everything behaved as designed; the console logs have no error, warning or leak line. **This is not a human playtest and not a listening test: nobody watched or listened.**
- **Sound measured, not heard.** Peak -1.0 dBFS with no clipped samples; the rain and drone bed sits near -33 dBFS RMS and never drops out; attacks reach about -6 to -9 dBFS, a jump of about 27 dB from the bed. Loop seams are clean. `whine.wav` stops abruptly behind an early shutter. Both need a person with headphones.
- **Push-to-talk freeze found and fixed** (`validation/2026-11-15/claude-mock-voice/`). With the real microphone and the mock proxy, every TAB press froze the game for about 450 ms, because opening the Windows input device blocks; about 300-500 ms of every press was lost (a 0.48 s press arrived as 168 ms and was refused as a tap). `game/scripts/core/voice_input.gd` now opens the device on a worker thread. Until it is ready the strip says **OPENING THE MICROPHONE...** and "Speak when it says LISTENING."; letting go before then sends nothing and says so. Measured after the fix: no frame gap over 50 ms at any press, the device ready after 465-472 ms, the push-to-talk duck down to -18 dB and back within about 150 ms, focus loss throwing the clip away, a decision during transcription dropping the late transcript, and a slow service (5 s) falling back to the authored line after 3.5 s. New tests: 7 rule checks with a slow simulated device, 4 scene checks over HTTP.
- **OpenAI route added** to the proxy (`agent_proxy/src/providers.mjs`, `BTC_PROVIDER=openai`): the Responses API with a strict JSON schema, `store: false`, no retry, and `/v1/audio/transcriptions` for push-to-talk. At this earlier checkpoint only six fake-network tests had run; the later live result is recorded above.
- `tools/art/measure_text.py` now also measures every fixed hint in `main.gd` against the 376 px strip (widest 288 px).
- `AGENTS.md`'s outdated voice sentence was replaced, and the source was transferred into this repository.

### Results in this checkout

Run on November 15 between about 17:00 and 18:10 New York, on the final working tree of the changes above. Logs: local `validation/2026-11-15/claude-mix-fixes/checks/` (`validation/` is not in the repository). The import and boot rows are from the run at about 15:34, after the transfer (`transfer-checks/`). PowerShell, from the repository root:

```powershell
$GODOT = "$env:LOCALAPPDATA\CodexTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
```

| Check | Command | Result |
|---|---|---|
| Fresh import | `& $GODOT --headless --audio-driver Dummy --path game --import` | exit 0; one `Parameter "t" is null` error from the headless dummy renderer |
| Rules, outcomes, agent and voice units | `& $GODOT --headless --audio-driver Dummy --path game --script res://tests/run_tests.gd` | 493 passed, 0 failed |
| Three shifts through the real scene, offline | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/run_ui_smoke.gd` | 333 passed, 0 failed |
| The same, less blood | add ` -- --less-blood` | 333 passed, 0 failed |
| Window close | `& $GODOT --headless --audio-driver Dummy --verbose --path game --script res://tests/run_close_check.gd` | 5 passed, 0 failed |
| Proxy unit tests | `npm test` in `agent_proxy` | 38 passed, 0 failed |
| Game and proxy over HTTP, local mocks, simulated microphone | `node tools/run_proxy_integration.mjs $GODOT validation/2026-11-15/claude-mix-fixes/checks/http-integration-final` | 193 passed, 0 failed; wire checks 15 passed, 0 failed |
| Every text fits | `python measure_text.py` inside `tools/art` | 302 lines, 0 problems |
| Rough GDScript lint | `python tools/gd_static_check.py` | 27 scripts, no findings |
| Capture script, dry run | `& $GODOT --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd` | 122 frames named, 0 missed |
| Capture drawn on a hidden desktop | `python tools/run_hidden.py ...` (command in its header) | 122 frames saved, no window on the student's desktop; 40 pixel-identical to the transfer capture, the same run-to-run spread as two captures of the older code (38) |
| Main scene boots | `--quit-after 240`, default and `-- --agent-url=http://127.0.0.1:9 --model` | exit 0 both; the known `4 ObjectDB instances were leaked` warning that `--quit-after` causes |

These are automated checks with the dummy audio driver, a simulated microphone and the mock. They show the flow holds together, not that it is fun.

### Launch

```powershell
.\run-game.ps1                      # offline; -LessBlood, -Mute, -Seed 123, -GodotPath <exe>
cd agent_proxy; npm run dev         # patient service (mock unless .dev.vars says otherwise)
.\run-game.ps1 -Model -AgentUrl http://127.0.0.1:8787   # second terminal, repository root
```

The window's corner reads `AI DIALOGUE`, `MOCK TRANSPORT` or `OFFLINE FALLBACK`.

### The live model test: route, what is needed, cost

- **OpenAI configuration:** the API uses a project key in the ignored `agent_proxy/.dev.vars`, loaded by Node. The student explicitly authorized assistant configuration on November 15. Do not read, print or copy this file, or place its credential in the game, command lines, logs or Git.
- **OAuth works for Google** (Vertex AI with a short-lived token from `gcloud auth application-default print-access-token` and the course project), if the student prefers that route. Its billing state is unconfirmed, and whether `gemini-3.5-flash-lite` accepts audio for push-to-talk is unverified.
- **Proposed OpenAI test:** `gpt-6-luna` (reasoning effort `none`) for the patient and `gpt-4o-mini-transcribe` for speech. List prices read on November 15 on OpenAI's pricing page: USD 0.10 per million input tokens, 0.50 per million output tokens, USD 0.003 per minute of audio. Measured prompts are 2,281-3,818 characters (about 600-1,000 tokens). About 30 patient lines and 10 spoken clips would cost about **USD 0.006**; a full three-shift session at the caps (240 calls) about USD 0.05. These are estimates from list prices, not measurements.
- **The step-by-step brief for the agent who runs it** (written for Codex, November 15): [docs/development/live-model-test.md](docs/development/live-model-test.md).
- During the run, read `latency_ms`, `input_tokens` and `output_tokens` in the proxy log; compare with the 3.5 s / 4 s deadlines; judge whether the patient stays in character and never contradicts the fixed evidence; check transcription on the student's own voice.

### Limits (both places: `game/data/rules.json` `agent`, `agent_proxy/src/core.mjs` `DEFAULT_LIMITS`)

| Limit | Value |
|---|---|
| Patient replies per visit / per session | 16 / 240 (student: keep 16) |
| Proxy deadline / game deadline | 3.5 s / 4 s |
| Reply length | asked for 110 characters, refused only over 220 |
| Conversation memory | 48 entries per visit, cleared for the next patient |
| Spoken clips | 0.35-10 s, 24 per visit, 360 per session; 6 s / 7 s deadlines |
| Provider calls per proxy process | 2,000, shared by both routes |

The live run's maximum output was 66 tokens and maximum response time 2.54 seconds. No increase to the 256-token budget or deadlines was warranted.

### Not done, not verified

- No human playtest, human speech-accuracy check, listening test or Windows export build. The live-model run and synthetic-speech service check are complete; nobody spoke into the microphone in this run. Google/Vertex remain untested live.
- The -9 dB attack trim and the whine fade were judged from measurements of a silent recording only. How long a live reply keeps the dots up is unknown.
- Keyboard layouts, input methods and a denied Windows microphone permission are untested. A device that fails to open after the press is covered only by reading the code.
- A typed or spoken provocation has no rule effect; only the PRESS pad costs patience. The patient does not speak aloud. The typing line has no paste.
- The Worker entry (`agent_proxy/src/worker.mjs`) has never been deployed.
- Leftovers: `agent_proxy/src/scripted.mjs` is no longer imported; `move_validator.gd` keeps an old name for a shape check.

### For the student to decide (seen, not changed)

- Blood stays until the shift ends (left alone on November 15 at the student's request): a broken window, blood on the sill and seeping below it, gore on the shutter, wall and desk stains, a caught splash and dents in the glass all stay through the next patients. `--less-blood` removes the blood, not the broken glass.
- After a listening test: whether the -9 dB attack trim is right (`ATTACK_TRIM_DB`, one number).
- Whether asking, tools, CALM and PRESS should also be allowed while a reply is on its way (they still wait; a live run will show for how long).
- Whether shuffled arrivals should stay (`rules.json` `arrivals.shuffle`).
- Open questions in the direction document: should a typed provocation count as pressure, should the patient speak aloud, how much blood by default.

### Documents behind the runtime

`docs/g1/01`-`04`, `06` and `07` are the submitted G1 versions and were left as submitted: the Configuration document and risk R3 still describe four calls per visit and 2-2.5 s deadlines, and `07` says voice is not implemented. `agent-config.json` was brought up to date on November 15.

## Next three tasks

1. **Feedback visual review** on an available desktop: inspect the corrected neutral speech row. Consider adding paste support; the live test did not change the typing field.
2. **Real voice test and human playtest**: use the student's actual voice for WER when available. A shift with headphones is still needed to assess pacing and attack loudness; synthetic speech is not a substitute.
3. **Braintrust replies** (due November 19, 23:59): the student picks two G1 pitches with fewer than two replies; draft specific, moment-based notes in English for review; the student sends them.

## Evidence (local, not in Git)

- `validation/2026-11-15/codex-live-test/`: completed 30/10 ledger, metadata from live requests, game events, numeric quality and synthetic-WER scores, and regression logs. No live reply text, transcript or audio archive.
- `validation/2026-11-15/claude-mix-fixes/`: the mix measurements before and after (caught and landed, -6 and -9 dB), the whine file, every check on the final tree, the hidden-desktop capture, the probe scripts.
- `validation/2026-11-15/transfer-checks/`: every check right after the transfer.
- `validation/2026-11-15/claude-mock-voice/`: the push-to-talk freeze, before and after the fix.
- `validation/2026-11-15/claude-window-play/`: agent-operated offline play and the sound measurements.
- `validation/2026-11-15/claude-final-checks/`, `claude-rendered-checks/`: the same checks in `fathom` and the earlier rendered captures.
- Older folders under `validation/2026-11-14/` and `2026-11-12/` describe earlier builds; their counts are not results for this one.

## Rules that do not change

- Never add `Co-Authored-By` or any AI attribution to Git commits.
- Keep `.claude/`, credentials, caches, private course pages and `validation/` out of Git.
- Never call a mock run a live-model result, automated checks a human playtest, or an agent-operated run a playtest or listening test.
- Logs hold lengths and stages, never typed words, clips or transcripts.
- Course posts, peer replies, paid model calls and deployment each need the student's own yes.
