# Continue Before the Cut

Updated November 15, 2026, about 19:15 New York. Work in this repository (`before-the-cut`) on `main`, and pull first; it is the only active checkout. The sibling `fathom` folder is an archive: read it for history if needed, never write to it, never copy its `.git`, and do not run its `tools/prepare_g1_repository.py`.

Read `AGENTS.md`, then `HANDOFF.md` (current state, results, the live-test answer and the next three tasks), then `game/README.md` and `agent_proxy/README.md` for the parts you touch. Communicate with the student in Chinese; write game text, comments and project files in English.

Where things stand:

- G1 was submitted on November 14. Two Braintrust replies are due November 19, 23:59 New York: draft them for the student's review, never send them yourself.
- The game (Godot 4.7.2, 640 x 360 pixel art) is playable offline and with the patient-AI proxy. It has passed every automated check in this checkout and has been operated by an agent in a real window with the real microphone and the mock proxy. No person has played it or listened to it.
- The proxy speaks to a mock, Google (API key or Vertex OAuth) or OpenAI (API key only). No live call has ever been made. The student has now explicitly authorized the requested OpenAI test with a USD 50 ceiling; do not request that same authorization again. Keep the specified models (`gpt-6-luna`, reasoning `none`; `gpt-4o-mini-transcribe`) and the smaller test scope: approximately 30 dialogue calls and 10 voice clips, hard limits 40 and 15.
- Codex reran the free checks: proxy 38/38, Godot rules 493/493, new guard 6/6. Application startup reported a missing credential and exited before opening a server or making any paid call. An ignored blank `.dev.vars` was prepared without opening an existing credential file. Pending questions: the student should confirm it is filled, or explicitly replace the handoff's manual-entry rule and let the assistant configure it; separately, confirm availability for ten real spoken clips. Do not read, print, search or copy that file. Node loads it normally as an environment file.
- Use the bounded launcher in `docs/development/live-test-session.md`, alongside the original `docs/development/live-model-test.md`. It keeps the call ledger in `validation/2026-11-15/codex-live-test/`, pauses after the first reply for review, and blocks continuation if that first reply fails. Do not reset the ledger, loop retries or substitute models. The current ledger is 0 dialogue, 0 clips. No runtime parameters were tuned.
- Late on November 15 the attack sounds were turned down 9 dB, an early shutter fades the whine, each shift shuffles the arrival order (the first patient of a session is steady), and looking, the TREAT stamp, the Trauma Team line and the shutter no longer wait for a patient reply. These were measured and checked automatically, not heard or played by a person. Blood was left alone at the student's request.

Keep to the design: a Normal Reference Sheet; looking, tools, questions, reassurance and pressure all optional and in any order; a decision allowed at any moment; TREAT or Trauma Team; defence with the shutter. The model writes the patient's replies and reactions; the game owns the case truth, the readings, the attacks and the score. Keep the authored script as the offline comparison and fallback. Keep 16 patient replies per visit; each limit is in `game/data/rules.json` (`agent`) and `agent_proxy/src/core.mjs` (`DEFAULT_LIMITS`), change both together.

Testing: you may open the game window, use the keyboard, mouse, audio and microphone (student, November 15). If the student is using the computer at the same time, drive the window with posted messages and capture it with `PrintWindow`, or use `tools/run_hidden.py`, so you never take focus. Put new evidence in a new dated folder under `validation/` (local only). Never call a mock run a live result, automated checks a playtest, or your own operation of the window a human playtest or listening test.

Next three tasks:

1. Resolve credential readiness and finish the authorized dialogue test: inspect the first response, then cover steady and drifting visits. Record the actual operator and evaluator, latency, tokens, character checks, game fallbacks and estimated cost. No live result exists yet.
2. Run the ten real voice clips when the student is available. Keep word-error counts and timings, never transcripts or audio. A human shift with headphones remains needed for pacing and sound.
3. Prepare the two Braintrust replies due November 19, 23:59 New York, when the student supplies the pitches. Draft for review; do not send. Leave submitted G1 documents, slides and narration alone.

Before you stop, update `HANDOFF.md` and this file with what you actually did, the real results, what is still unverified, and the next three tasks. Commit and push normally to `main` when the student's request covers it; never force-push. Never add `Co-Authored-By` or any AI attribution to commits.
