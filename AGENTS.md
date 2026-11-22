# Before the Cut: working instructions

## Agreed rules for this build

November 21, 2026. The student asked for fewer choices and clearer guidance: “选择太多没有引导性、然后还会有patience次数限制，又加上我们还有agent、会让整个input复杂度指数提升”. The counter now asks what hurts, lets the doctor test the named part, then leaves the decision with the doctor. Any action may be skipped. Fixed night K teaches the rule and night L exercises misleading or absent complaints.

Each arrival gets two lamps. A new LIGHT, GRIP, PORT or PRESS costs one lamp and is always granted. Reopening a check, asking a listed question, requesting a complaint and talking are free. Wrong codes cost one lamp. Only a fresh test or PRESS can trigger a surprise, with a 6% snap chance on the first and 12% on the second. At zero lamps the visitor waits 30 idle seconds. BREAK is available after PRESS or at zero lamps, shows a SPACE warning, and needs no lamp. A steady visitor walks out unpaid. Catching a drifting visitor pays the fee plus 50. Half of steady later visitors can show wear. Two genuinely broken rows establish drift. Only closing reveals the truth. [Rules, sources and measured balance](docs/development/play-loop-redesign/PROGRESS.md)

Read `README.md`, `HANDOFF.md` and `NEXT_AGENT_PROMPT.md` first. This is the ongoing Before the Cut repository (formerly before-the-cut-g1) and, since November 15, 2026, the only active checkout: the game, the patient-AI proxy and the tools live here. The sibling `fathom` folder is an archive; do not write to it.

Communicate with the student in Chinese. Write game text, comments, documents, slides, scripts and handoffs in English. The game itself is bilingual: its English text has a Chinese translation in `game/data/lang/zh/` (see Languages below).

The student's recording is finished (decision of November 15): the game window, mouse, keyboard, audio and microphone may be used for testing. Voice input (hold TAB to speak) is built. The November 15 live run tested 30 OpenAI patient replies and ten real transcriptions of local synthetic speech; that is not a human microphone or accent test. See `docs/development/live-model-results-2026-11-15.md`. Do not change slides or narration.

## Agreed design

- A Godot 4 pixel-art implant clinic. Fantasy and Discovery lead, with Sensation in the shutter sequence. The sheet beside each instrument describes the normal result for that patient's model. Players mark their own ticks and crosses and can decide at any time.
- Every protected first visitor is steady, unworn and has one complaint. The four physical/temper rows of later visitors draw complaints independently: 65% on a broken row, 20% on a normal row. Asking generally delivers up to two untold rows. Asking about one part repeats its own report or a neutral answer. Each delivered row gets a question mark on the instrument and card. Listed questions supply the free SPEECH evidence. Choosing TREAT, calling Trauma Team and a warned BREAK are all available according to the rules above.
- Protocol 5 carries eleven intents, including listed questions and complaints. A listed question is answered immediately. Typing and reviewed dictation share that router. A request for an instrument can point to it. Only the physical controls can operate one. The patient speaks from their own identity, work, voice and motive. Godot owns consent, evidence, symptoms, lamps, danger, codes and money.
- One appointment owns one session. The current visit's ordered words, reactions, completed actions and already disclosed complaints supply its memory. Keep the persona prefix stable for provider caching. Above 32 KiB retain the opening, recent turns and whole-visit action counts. Ending an appointment clears the record and invalidates late replies.
- A generated complaint receives only the rows being delivered now and those already delivered. Character-specific wording supplies fallback on missing part names, stated test results, invalid output, timeout or exhaustion. Graded ASK uses authored wording. The live November 21 L1–L5 evaluation met all five targets. The next comparison is with outside players.
- Keep the scripted offline patient and the public mock transport available. Three optional turns and at most two idle turns share the 16-reply visit allowance. The game can volunteer an untold complaint after 12 quiet seconds. Player input cancels pending optional dialogue. Keep the existing public live Worker disabled outside separately authorized use.

## Project organization

Game files belong in `game/`, the runtime API in `agent_proxy/`, production-agent artifacts in `agent_team/`, G1 materials in `docs/g1/`, development notes in `docs/development/`, and reusable tools in `tools/`. Local evidence goes in dated folders under `validation/`, which Git ignores. `docs/g1/01`-`04`, `06` and `07` are the submitted G1 versions; leave them as submitted unless the student asks. Former `g1/` paths forward to `docs/g1/`. Do not use the older documentation-only export or its preparation script on this repository.

Each limit lives in two places, `game/data/rules.json` (`agent`) and `agent_proxy/src/core.mjs` (`DEFAULT_LIMITS`); change both together. Art and sound are generated by `tools/art/`; do not hand-edit `game/assets/`. Commit `.import` and `.uid` files with the assets they belong to.

## Languages

The player picks English or Chinese (中文) on the title card. Every word the game shows is written in English, in `game/data` and the scripts; the Chinese is a set of catalogs in `game/data/lang/zh/`, keyed by that exact English (`game/scripts/core/lang.gd`). A change on one side is a change on both (student, November 18):

- Changing or adding shown English means writing its Chinese line in the same change, and changing a translation means checking that it still says what the English says. Names and code names stay English; companies, gangs and organizations are translated. The glossary and the patients' voices are in `docs/development/chinese-translation.md`.
- Words painted into pictures live in `tools/art/words.py`. Change them there and run the generator, which writes the English picture and its twin `<name>_zh.png` together.
- Before committing, run `python tools/check_lang.py` (a missing, stale or mismatched line, or a missing picture twin), `python measure_text.py` and `python measure_text.py --lang zh` in `tools/art` (every line fits in both languages), and the UI smoke test in both languages (`... --script res://tests/run_ui_smoke.gd -- --lang=zh` fails on any English that reached the screen untranslated).
- The patient model answers in the player's language (the proxy's `language` field); the scripted patient's lines and key words are in the case catalogs and `lang/zh/topics.json`.

## Evidence and permissions

Distinguish old results from current runs, mocks from live-model calls, automated checks from human playtests, an agent operating the window from a person playing it, and repository publication from course submission.

Routine local edits, reversible setup, tests and normal pushes to `main` are covered by the student's continuation requests. Course posts, peer replies, paid model calls and deployment each need the student's own explicit yes; for a paid call that means the provider, the model, the number of calls and the cost. Existing explicit authorization remains valid; do not ask for it again. The local proxy loads its API key from `agent_proxy/.dev.vars`. For the approved live Worker, the owner delegated configuration of the existing application credential. A process using the application's normal environment loader can supply that binding to Wrangler over standard input. Keep secrets out of the game, command lines, chat, logs and commits. On November 15 the student explicitly revoked the manual-entry-only rule and authorized assistant configuration. Do not open, print or search that file; the app loads it normally. Logs hold lengths and stages, never typed words, clips or transcripts.

Update `HANDOFF.md` and `NEXT_AGENT_PROMPT.md` at checkpoints and before stopping, with actual results, limitations and the next three tasks.

- NEVER add `Co-Authored-By` or any AI attribution to Git commits.
- Keep `.claude/` ignored. Do not commit personal settings, secrets, caches, private course pages or local evidence archives.
- Written course AI-use disclosures are separate from commit attribution and must remain truthful.
