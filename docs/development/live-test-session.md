# Supervised OpenAI session: operator sheet

This accompanies [the original brief](live-model-test.md). It is a test procedure, not evidence
that a live call or a human playtest succeeded. Use one local proxy and one game window.

**Completed November 15:** 30 live dialogue requests and ten synthetic-speech transcriptions.
The ledger is stopped; do not restart this completed session. See [the actual results](live-model-results-2026-11-15.md).

## Authorization and configuration

On November 15, 2026, the student supplied an API key and authorized up to USD 50 for the requested
OpenAI test. That authorization covers this initial run; do not ask for the same budget again.
The narrower run limits still apply: approximately 30 dialogue calls and 10 spoken clips, with
hard stops of 40 and 15. The credential itself is not documented here.

The student explicitly revoked the handoff's manual-entry-only requirement and authorized the
assistant to configure the ignored `agent_proxy/.dev.vars`. No reading, printing or searching
of that file is needed. Node loads it when starting the app.

Models: `gpt-6-luna`, reasoning `none`; `gpt-4o-mini-transcribe`. On November 15, the official
[Luna page](https://developers.openai.com/api/docs/models/gpt-6-luna) lists USD 0.10 input and
0.50 output per million tokens. The [pricing table](https://developers.openai.com/api/docs/pricing?latest-pricing-expanded=true)
estimates transcription at USD 0.003 per minute. Thirty short replies plus ten five-second clips
are roughly USD 0.006, not a guaranteed bill. Failed requests can have unreported usage.
The [transcription model](https://developers.openai.com/api/docs/models/gpt-4o-mini-transcribe)
is deprecated; its announced shutdown is February 26, 2027. It remains the requested model for
this run. Do not silently substitute another model.

## Start and first-call gate

Run the free checks first. If any fails, stop before starting a paid request.

```powershell
# In agent_proxy:
npm.cmd test
# In the repository root:
node --test tools/live_model_guard.test.mjs
& "$env:LOCALAPPDATA\CodexTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --audio-driver Dummy --path game --script res://tests/run_tests.gd

node --env-file=agent_proxy/.dev.vars tools/live_model_session.mjs start validation/2026-11-15/codex-live-test
# In a second terminal:
.\run-game.ps1 -Model -AgentUrl http://127.0.0.1:8787 -Seed 7
```

The launcher refuses a different provider or model, reserves each attempted call before sending
it, and retains counts across restarts. It does not alter the production limits, including
16 replies per visit, 256 output tokens and the existing deadlines. A missing credential exits
before opening a server or making a request.

Check the corner says **AI DIALOGUE**. Ask one built-in question, then inspect the reply and the
metadata. After the first successful, validated reply the launcher pauses paid access. Continue
only after reviewing that result:

```powershell
node tools/live_model_session.mjs continue validation/2026-11-15/codex-live-test
```

A failed first call blocks continuation. Stop and report the failure; do not reset the ledger,
retry in a loop, or select a different model. A launcher restart is not a fresh call budget.
Do not run two launcher processes against the same evidence directory.

## Dialogue coverage

Play two or three visits, including a steady and a drifting patient. Aim for ten calls per visit:
three tool requests, three built-in questions, CALM, PRESS, and two typed lines. Spread these
typed probes across visits: an unrelated topic; an instruction to abandon the patient role;
and a question about a particular normal-sheet sign. Try looking or handling a decision during
one pending response. If a patient leaves or attacks, record it; do not change the rules to force
the planned number of calls.

Judge every visible reply, recording only IDs and yes/no counts: in character, English,
within 110 characters, no explicit hidden-label disclosure, and no unsupported physical sign.
Distinguish a patient's evasive claim from an actual change to game evidence. Verify readings
and outcomes in the game. Preserve no reply quotations in the evidence without permission.
Say who operated the window and who judged it; agent operation is not a human playtest.

## Ten voice prompts

The following are authored test inputs, not recordings or transcripts. For a human test, the student reads them.
Do not synthesize a voice or replay unrelated recordings and call that a student microphone test.
For the completed run the student requested assistant-supplied audio; Windows TTS was used in
memory and every result was labeled synthetic. It tested the HTTP speech route, not the microphone.
Wait for **LISTENING**, then speak; release TAB and inspect the recognized text before Enter.
For the WER-only check, dismiss the typed line after inspecting it: Enter would add a dialogue call.

1. What brings you to the clinic tonight?
2. When did the trouble with your implant begin?
3. Please follow the light with your eyes.
4. Hold the handle and let go when I ask.
5. May I take a look at your implant port?
6. How much sleep did you get last night?
7. Does your hand ever move without your permission?
8. I need a moment to check the reference sheet.
9. Have you lost track of time recently?
10. Tell me if this examination makes you uncomfortable.

For each clip save only its number, reference word count, substitutions, deletions, insertions,
duration, latency and failure stage. Ignore case and punctuation; treat contractions as one word.
WER is `(substitutions + deletions + insertions) / reference words`. If the speaker misreads the
prompt, mark that clip unscored rather than blaming transcription. No audio or transcript archive.

## Finish and report

```powershell
node tools/live_model_session.mjs stop validation/2026-11-15/codex-live-test
# Stop the running proxy with Ctrl+C as well.
node tools/live_model_session.mjs report validation/2026-11-15/codex-live-test
```

The report records latency median, nearest-rank p90 and maximum, errors and token counts. Usage
from an upstream response is retained as numbers even if the provider rejects a truncated reply.
Requests with no response metadata remain explicitly unknown. The list-price token calculation
is an estimate; cached input can reduce it. Add transcription cost from observed token/audio
usage, and identify any missing usage instead of reporting an exact invoice total.

Write the local evidence `README.md` and `summary.txt`: operator, evaluator, actual live call
count, game fallbacks, character scores, word errors and untested items. Never report a proxy
error count as an observed game fallback count without checking the game log. Leave runtime
limits unchanged unless a measured problem justifies tuning both corresponding files.
