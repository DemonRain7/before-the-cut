# First live OpenAI test — November 15, 2026

Completed: **30 live patient requests and 10 live transcription requests**, all successful.
The proxy is stopped. This was an agent-operated technical test, not a human playtest.

## Authorization and scope

The student authorized the specified run with a USD 50 ceiling, explicitly allowed assistant
configuration of the ignored credential file, and asked the assistant to supply voice input.
The smaller 40-dialogue/15-clip caps remained. Node loaded the credential normally; it was not
placed in source, logs or Git. No retries or model substitutions were used.

Base: `faa5c75`, following `98eda57`. Free checks before paid requests: proxy 38/38, Godot rules
493/493, guard 6/6. Codex operated the window and judged the replies:

- **12 requests in the real game**, six each for Kip and Vale. Covered questions, LIGHT, GRIP
  and PORT requests, CALM and PRESS. Eyes and ports were inspected. Kip was correctly treated.
  Calling Trauma Team on Vale triggered his authored attack; the operator was late with the
  shutter and was hit. This does not measure a human player's reaction time.
- **18 HTTP dialogue probes**, six each for Kip, Vale and Maren, through the same live proxy.
  Covered background, sleep/memory, an unrelated question, an instruction to abandon the role,
  a reference-sheet question and a false premise about the conversation. These were not extra
  visits played through the window.
- **10 Windows-synthesized English clips**, Microsoft Zira Desktop, through the real speech
  service. Audio and transcripts stayed in memory; only counts and timings were recorded.

The automatic text-entry tool could not fill the custom game field after a focus retry; the
game does not support paste. Its GRIP control also required a longer hold than the automation
supplied. Free dialogue and speech were therefore tested through HTTP. The full live microphone
to typing-line to patient path was not verified.

## Results

| Metric | Dialogue | Transcription |
|---|---:|---:|
| Model | gpt-6-luna, reasoning none | gpt-4o-mini-transcribe |
| Requests / successes | 30 / 30 | 10 / 10 |
| Median latency | 1,319.5 ms | 660.5 ms |
| p90, nearest rank | 1,837 ms | 1,269 ms |
| Maximum latency | 2,541 ms | 1,325 ms |
| Timeouts / invalid outputs | 0 / 0 | 0 / 0 |
| Input / output tokens | 20,917 / 1,597 | 502 / 110 |
| Mean / max input tokens | 697.23 / 915 | 50.2 / 56 |
| Mean / max output tokens | 53.23 / 66 | 11 / 12 |

Every response reported usage; dialogue had no cached input or reasoning tokens. The game log
independently records **12 model replies, zero fallbacks**, with client latency median/p90/max
of 1,462/1,910/2,590 ms. Dots appeared while waiting, but the complete perceived wait including
doctor-line typing and reaction presentation was not timed. Deciding while a live reply was
outstanding was not verified.

**No limit tuning was justified.** Keep 256 output tokens, 16 replies per visit, the 3.5-second
proxy deadline and 4-second game deadline.

29 replies were inspected: all stayed in character, used English, met the 110-character target
and did not expose instructions or hidden engine state. One port reply was replaced on screen
by the tool result before scoring and remains unscored. All three false-premise probes were
corrected. One Vale reply denied an abnormal physical sign: an allowed deceptive patient claim.
The physical test still displayed the fixed abnormal reading. No reply changed case truth,
readings, attacks or scoring. A patient's diagnosis denial is not an authoritative state readout.

Synthetic speech: **80 reference words; zero substitutions, deletions or insertions; WER 0%**,
over 29.63 seconds of audio. Four elementary WER fixtures were checked before scoring. This
does not establish accuracy for the student's accent, room noise, microphone or spontaneous
speech. No person spoke or listened during the run.

## Cost

Rates checked November 15: [Luna](https://developers.openai.com/api/docs/models/gpt-6-luna)
USD 0.10/0.50 per million input/output tokens;
[mini-transcribe](https://developers.openai.com/api/docs/models/gpt-4o-mini-transcribe)
USD 1.25/5.00. Applying these to reported usage gives **USD 0.0040677**: dialogue 0.0028902,
transcription 0.0011775. This is a list-price estimate, not an inspected invoice. Using the
audio-minute estimate of USD 0.003/minute instead gives about USD 0.00437 for the whole run.
Both are below one cent. Local Windows TTS made no additional paid API calls.

## Defect found and fixed

Vale's live sleep answer evaded the authored clue. The result screen nevertheless quoted a
different prewritten line and marked it as an abnormal utterance the player had heard. This
was observed in the real window and traced to `VisitState.settlement()`.

After generated question dialogue, speech feedback now retains the actual recorded reply under
a neutral **PATIENT SAID** heading, with an ellipsis for a long display excerpt. It does not
automatically grade free-form speech or substitute an unspoken script quote. A subsequent
scripted fallback is recorded accurately. Case truth, physical findings, attacks, scoring and
the wholly scripted comparison retain their behavior.

After the correction: **505 rule checks** (12 new regression assertions), **333 scene checks**
and **5 normal-close checks** passed. The real game also closed with exit 0. The scene smoke
harness has resource-retention warnings at test shutdown; archived pre-change smoke logs show
the same class of warning. This is not a warning-free run. The normal-close check has no
ObjectDB/resource-leak error.

A final synthetic visual preview could not be inspected: capture returned black and activation
failed with `GetCursorPos` access denied after one recovery attempt. The preview was stopped.
The feedback correction has regression coverage; final visual approval remains unverified.

## Evidence and remaining work

Local evidence: `validation/2026-11-15/codex-live-test/` holds metadata logs, the persistent
30/10 ledger, metrics, numeric quality/WER judgments and check logs. No live dialogue transcript,
audio or credential archive is included. This report does not quote live replies.

Next: inspect the corrected feedback on an available desktop; test the real microphone and
play a human shift with headphones; consider paste support. Google/Vertex, Worker deployment,
a Windows export and broad player testing remain unverified. Submitted G1 materials were unchanged.
