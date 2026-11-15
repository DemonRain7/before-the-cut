# Continue Before the Cut

Updated November 15, 2026. Work in this repository (`before-the-cut`); it is the only active checkout. The sibling `fathom` folder is an archive: read it for history if needed, never write to it, never copy its `.git`, and do not run its `tools/prepare_g1_repository.py`.

Read `AGENTS.md`, then `HANDOFF.md` (current state, results, the live-test answer and the next three tasks), then `game/README.md` and `agent_proxy/README.md` for the parts you touch. Communicate with the student in Chinese; write game text, comments and project files in English.

Where things stand:

- G1 was submitted on November 14. Two Braintrust replies are due November 19, 23:59 New York: draft them for the student's review, never send them yourself.
- The game (Godot 4.7.2, 640 x 360 pixel art) is playable offline and with the patient-AI proxy. It has passed every automated check in this checkout and has been operated by an agent in a real window with the real microphone and the mock proxy. No person has played it or listened to it.
- The proxy speaks to a mock, Google (API key or Vertex OAuth) or OpenAI (API key only). No live call has ever been made. Before the first one, tell the student the provider, the model, the number of calls and the estimated cost (`HANDOFF.md` has the numbers) and wait for a clear yes. The key goes only into `agent_proxy/.dev.vars`, which the student fills in.

Keep to the design: a Normal Reference Sheet; looking, tools, questions, reassurance and pressure all optional and in any order; a decision allowed at any moment; TREAT or Trauma Team; defence with the shutter. The model writes the patient's replies and reactions; the game owns the case truth, the readings, the attacks and the score. Keep the authored script as the offline comparison and fallback. Keep 16 patient replies per visit; each limit is in `game/data/rules.json` (`agent`) and `agent_proxy/src/core.mjs` (`DEFAULT_LIMITS`), change both together.

Testing: you may open the game window, use the keyboard, mouse, audio and microphone (student, November 15). If the student is using the computer at the same time, drive the window with posted messages and capture it with `PrintWindow`, or use `tools/run_hidden.py`, so you never take focus. Put new evidence in a new dated folder under `validation/` (local only). Never call a mock run a live result, automated checks a playtest, or your own operation of the window a human playtest or listening test.

Before you stop, update `HANDOFF.md` and this file with what you actually did, the real results, what is still unverified, and the next three tasks. Commit and push normally to `main` when the student's request covers it; never force-push. Never add `Co-Authored-By` or any AI attribution to commits.
