# Before the Cut: a first two-player version (handoff for Claude Fable)

> **Before you send this.** Delete any line under "Approvals" that you do not approve, and change
> any "Decision made for you" you disagree with. The approval lines count only in the message the
> student sends; this copy in the repository approves nothing.

## Approvals (the student's)

- Paid model calls: up to 40 live patient requests to OpenAI `gpt-6-luna` through the game's local
  patient service on loopback (started as item 3 under "Decisions made for you" says), at most
  USD 0.05 in total, only to check one two-player night with the live patient on the host's front
  desk. (On November 21, 14 such requests cost about USD 0.0009.)
- Push the branch `two-player-v1` to `origin`. Do not merge it into `main`.

Not approved here: deploying any server or relay, switching on the public live Worker, course posts
or peer replies.

## Decisions made for you (the student may change them before sending)

1. **Where.** Work in a git worktree on a new branch `two-player-v1` cut from `origin/main`, for
   example `git worktree add ../before-the-cut-two-player -b two-player-v1 origin/main`, then run
   `.\run-game.ps1 -ImportOnly` there once. Other sessions keep editing the main checkout; do not
   touch it. The single-player build is being polished for the course, so two-player lives on its
   own branch until the student merges it. Commit at every working checkpoint and push the branch,
   so a stop for quota loses nothing.
2. **Network.** Godot's built-in high-level multiplayer over ENet. One player hosts, the other joins
   by address and port. The host is authoritative: it owns the night's seed, every visit's state,
   the tray, the money, the rolls and the settlement; the other machine sends intents. Two windows
   on one PC (127.0.0.1) and two PCs on one LAN must both work. No relay or matchmaking server in
   v1, since that would be a deployment; the design doc says how two players in different places
   can connect today (a virtual-LAN tool gives them direct addresses) and what a relay would take.
3. **Patient.** The scripted patient is the default in two-player. The live patient runs only on
   the host: the host's game calls a local service on loopback, and words typed on the other
   machine travel to the host over the game connection and never into a log. The worktree has no
   `agent_proxy/.dev.vars` (Git ignores it); never copy, open or search that file. For the live
   check, start the service from the main checkout's `agent_proxy` folder the way
   `run-game.ps1 -Patient live` does (`node --env-file-if-exists=.dev.vars src/dev_server.mjs` with
   `BTC_PROVIDER=openai`, `BTC_MODEL=gpt-6-luna`, `BTC_REASONING_EFFORT=none`,
   `BTC_HOST=127.0.0.1` and a free `BTC_PORT`). Node loads the key itself, and nothing in that
   checkout changes. Start the worktree's host with `-Patient http://127.0.0.1:<port>`, read the
   request and token counts from the service's `/healthz` (`prompt_cache_usage`) afterwards, and
   stop the service.
4. **Nights.** Fixed nights K and L. Both languages. Less blood is each player's own setting.
5. **Single player stays as it is.** Two-player is a new item on the title menu. Every
   single-player rule, screen and test result stays the same.
6. **The design is yours.** Within the student's direction below, you decide how the seats work,
   how the players reach each other, how seats are chosen and swapped, and what the theatre does.
   Where you depart from the direction, say why in the design doc. Put every such choice in the
   doc's "Decisions made for the student" list so the student can review it.

## What the student asked

November 23, verbatim:

> 我现在想尝试实现我说的那个联机的部分……就现在应该只是一个初级的版本、但是怎么协调二人的配合、让整个游戏更加有意思我觉得挺重要的。比如最担心的就是二人所做的事情不一致带来的游玩体验差异很大，又或者他们二者都想体验。这块我很拿不准、我觉得可以让fable去好好想想。包括整体的游玩逻辑是否完整顺畅也需要他好好考虑

In English: build a first, basic online two-player version. How the two players work together, and
whether that makes the whole game more fun, matters most. The student's worries: the two seats do
such different things that the two players have very different experiences; or both players want to
play the same part. They are unsure how to solve this and want it thought through, together with
whether the whole play logic is complete and smooth.

Their direction of November 22 (`docs/development/closing-shift/next-game.md`, "The owner's
direction"): one player works the front desk and decides who goes in; the other is the surgeon in
the back room, receives exactly that patient, takes out and fits the part by hand and plays short
QTEs at moments such as seating and calibration. "我最在意的是手术时看哪里" (what matters most is
where you look during surgery): head down over a wrist part, the surgeon feels the hand tighten and
chooses whether to look up; on a face, the change can come before the hands are done. The surgeon
must have something worth doing while the front desk is still talking or keeps refusing people.

Today the game is single-player. At an implant clinic's counter the doctor screens five patients a
night: asks what hurts, tests the suspect part with up to two examination lamps, may PRESS the
patient (the fourth push is a warned BREAK that ends the visit), and calls TREAT or TRAUMA TEAM. A
drifting patient who snaps lunges at the glass, and the shutter stops them. The doctor learns only
at closing whether each call was right, and then watches one silhouette film of the back room: a
repair, or a massacre by a drifting patient they let in, ending on its face.

## Read first

- `AGENTS.md` (the rules for every agent here), `README.md`, the top sections of `HANDOFF.md`, and
  `NEXT_AGENT_PROMPT.md`.
- `docs/development/closing-shift/next-game.md`: the student's two-player direction and earlier
  sketches (two framings, feel before sight, two QTEs, stopping always allowed, waiting with a
  purpose, intercom buttons, a first test of the sketch; then two stations with one shared tray,
  quiet and overloaded stretches, the host owning state, reconnects, and an inexpensive decision
  test with outside players). The sketches are ideas, not decisions.
- `docs/development/closing-shift/film.md` and `game/scripts/ui/closing_film.gd`: the closing film.
  Its insert close-up (the old part backed out, the new one seated and calibrated, at an integer 3×
  pixel scale) is the surgeon's view played back. The gloves and parts are in `game/assets/film/`,
  drawn by `tools/art/gen_film.py`.
- `docs/development/closing-shift/release.md` and `docs/development/play-loop-redesign/PROGRESS.md`:
  the single-player rules as built.
- `docs/development/chinese-translation.md`: how both languages are kept in step, and each
  patient's voice.
- `../motivation-atlas/content/player-motivations.md`: the course's eleven motivators (see
  Fellowship). The student reads designs as motivator ← dynamic ← mechanic.
- Code: `game/scripts/ui/main.gd` (the single-player controller, about 5,100 lines);
  `game/scripts/core/` (`shift_state.gd` draws a night from a seed, `visit_state.gd`, `case_db.gd`,
  `scripted_brain.gd`, `patient_agent.gd`, `model_client.gd`); `game/scripts/ui/` (`clinic_view.gd`,
  `scope_view.gd`, `patient_rig.gd`, `intro.gd`, `screens.gd` with HOW TO PLAY, `guide.gd` the
  counter guide, `coach.gd` the first night's tips); `game/tests/` (`play_driver.gd`
  plays the real screen the way a person does, `record_night.gd` plays a night from a plan);
  `tools/run_hidden.py`; `run-game.ps1`.
- On this machine: Godot 4.7.2 is in `%LOCALAPPDATA%\CodexTools\Godot\4.7.2\` (`run-game.ps1` finds
  it; use `Godot_v4.7.2-stable_win64_console.exe` for headless runs). Run anything that opens a
  window under `tools/run_hidden.py`, so nothing appears on the student's screen. Set
  `PYTHONIOENCODING=utf-8` when a Python script prints Chinese.

## The four questions to answer

Answer each in the design doc with a mechanism, a timeline and a check, not a principle.

1. **Two seats, one night that is as good for each.** The seats will do different things; that is
   the point of the design. The risk is that one player gets the real game and the other gets a
   helper's job, or an empty theatre. Define what an equally good night means for each seat and
   design to it. At least, for each seat, on three nights (mixed calls, everyone admitted,
   everyone refused):
   - no stretch over 10 seconds without a meaningful action, outside the shared report and film;
   - at least one decision per admitted patient that changes what happens to that patient;
   - information only that seat has, which the other seat needs;
   - a moment where that seat's call saves or dooms the crew;
   - a share in the payoff: both players see the face of whoever was let in, and the report shows
     what each of them did.

   Build each seat's timeline second by second, as the tables in `next-game.md` do, and count the
   choices each player faces at each moment. You may lighten the counter in two-player if this
   analysis calls for it; single-player keeps its counter.
2. **Both want the same seat, or both want to play both.** Decide how seats are chosen, what
   happens when both pick the same one, and how each player gets to play both seats in one session:
   a swap between nights, a swap at a natural break, a scheme where each player screens a patient
   and then operates on them, or something better. Weigh what each option does to the drama the
   student's direction is built on: receiving a patient someone else let in.
3. **Working together is the fun.** Decide what each seat must tell the other and how. Use a few
   preset intercom calls per seat and no free chat (the student asked for guided, simple input),
   and make sure the design still works when the two players also talk aloud or over voice. A call
   should regularly change because of what the partner said; the winning habit must not be reading
   one code aloud. Shared things (the tray, a single certified part, the money, the queue) can tie
   the seats together; each must earn its place.
4. **The whole loop is complete and smooth.** Map every screen from the title to the end of the
   session: the two-player menu, host and join, the lobby (seat, language, less blood, ready),
   teaching each seat before it matters, the night, its end, the report, the film, the next night,
   a rematch or leaving. Every state needs a way forward and a way out, and every wait says what it
   is waiting for. Define and handle at least: everyone refused; the theatre busy when the next
   patient is admitted; the front-desk doctor killed while a surgery runs; the surgeon killed while
   the front desk is mid-interview; a drifting patient stopped in the theatre; a steady patient
   stopped in the theatre; one player quitting, disconnecting or reconnecting mid-night; the host
   leaving; different languages on the two machines; one player skipping the film; mismatched game
   versions. Write down any single-player holes you notice, but leave single-player rules alone.

## Rules this game already keeps

- **Uncertainty until closing.** Nothing during play says whether a call was right: no stamps,
  verdict sounds, money changes or crew lines that give it away. What the theatre shows is evidence
  with a steady and a drifting explanation, as at the counter, not a verdict. Whatever reveals the
  truth by its nature (a patient who turns) is allowed and must be listed in the docs. Any new way
  to die ends the night; decide what that means with two doctors.
- **Guided, simple input.** Count the choices at each moment and say what guides each one. Prefer
  removing a verb to adding a rule. Free text to the patient AI never costs or breaks anything.
- **Every tool earns its place.** For each new action, say what it reveals that nothing cheaper
  does, when it is the best choice, and what its risk buys. Every examination stays optional.
- **Clear onboarding.** Warn before anything can hurt a player and name the key that answers it.
  Each seat gets its own HOW TO PLAY pages in both languages; settings stay on the title menu.
- **A consequence the player recognises.** One film per night, ending on the face of the patient
  someone let in. The surgeon may now live through a wake-up in the theatre; decide how the live
  theatre and the night's film relate, so that neither player loses the reveal.
- **Composable characters.** Any part of any patient can be the broken one, so the theatre must
  work for every part type (eye, hand, port, voice box), at least in a shared form, with the hand
  and the face done properly.
- **Both languages, less blood.** Every shown word in English and Chinese in the same commit
  (`AGENTS.md`, Languages). The Chinese reads the way a person talks, with character, never word for
  word and never flat. Less blood removes all blood and wet sounds and keeps the horror.
- **Generated art and sound.** Everything comes from `tools/art/` (`gen_film.py`, `gen_audio.py`
  and the rest). Never hand-edit `game/assets/`; commit `.import` and `.uid` files with their assets.

## What v1 must do

Small and complete beats wide. Cut breadth (part types in a shared form, two nights, preset calls,
no relay), never the loop. v1 is done when two people on one PC or one LAN can:

- pick seats in a lobby, with a clear answer when both want the same seat;
- play night K or L together from the opening to the report and the film, each seat taught before
  it matters;
- each make real decisions from their own information, and never wait more than 10 seconds for
  nothing;
- reach each other through the intercom calls;
- see the same report and film, then swap seats for the next night;
- lose the connection without a crash or a stuck screen;
- play in either language, with less blood available.

## How to work

1. **Design first, in one pass.** Write `docs/development/two-player/01-design.md`: the target
   motivation for each seat and for the pair, the answers to the four questions, the per-seat
   timelines and choice counts, the screen map, the edge cases, the network model (what the host
   owns, what each message carries, how reconnects and repeated packets are handled, how timed
   inputs are judged across the latency), what you considered and rejected and why, and the
   "Decisions made for the student" list. Then build it; do not wait for approval.
2. **Build** on the branch. Reuse the core (`shift_state`, `visit_state`, `case_db`) and the
   counter instead of forking `main.gd` wholesale. If the counter needs a seam for networking, cut
   it so single-player behaves exactly as before.
3. **Prove it automatically.**
   - Two peers in one process (separate `MultiplayerAPI` branches of the scene tree), and two
     processes on 127.0.0.1 under `tools/run_hidden.py`, each seat played by a scripted stand-in
     that follows a plan, as `record_night.gd` does. Decide whether to offer that stand-in to
     players too, for example to try the theatre alone or to fill a seat after a disconnect.
   - Plans for at least: mixed calls, everyone admitted, everyone refused, a drifting patient
     stopped in the theatre, a death at each seat, a disconnect and a reconnect, the host leaving,
     and one player in each language.
   - From those runs, measure each seat's idle stretches and decisions per patient, and compare
     them with the design's targets.
   - Keep every single-player suite green and report the counts: `run_tests.gd`;
     `run_ui_smoke.gd` in English, in Chinese (`-- --lang=zh`) and with `-- --less-blood` (each
     takes about 280 s on this machine; slow, not hung); `run_close_check.gd`;
     `run_loop_night.gd` (K, L, K in Chinese); the `capture_shift.gd` dry runs; the
     `record_night.gd` plans; `python tools/check_lang.py`; `python measure_text.py` and
     `python measure_text.py --lang zh` in `tools/art`; `python tools/gd_static_check.py`.
   - Record one night from both seats with two agent-operated instances (Movie Maker on a hidden
     desktop) and put the two side by side in one clip, labelled as agent-operated with scripted
     inputs.
   - Only if the live-patient approval above was sent: play one two-player night with the live
     patient on the host, within its limits, and record the request count and the cost.
4. **Keep a progress file**, `docs/development/two-player/PROGRESS.md`: what is done, in progress
   and next, and every check with its result, so another agent could pick up if you stop.
5. **Write the acceptance sheet**, `docs/development/two-player/ACCEPTANCE.md`: what the student
   does in fifteen minutes with a friend, or alone with two windows, to accept or reject v1, with
   the commands that start the host and the joiner on one PC and on two PCs.
6. **Hand over.** On the branch, add a new top section to `HANDOFF.md` (leave the rest as it is so
   the merge stays easy) and update `NEXT_AGENT_PROMPT.md`, with the actual results, the
   limitations, the next three tasks and the AI-use note. Add the two-player rules to HOW TO PLAY
   in both languages. Push the branch.

## Hard rules

From `AGENTS.md`, which wins over anything here:

- Never add `Co-Authored-By` or any AI attribution to commits. The written AI-use notes in the docs
  stay truthful.
- Never open, print or search `agent_proxy/.dev.vars`. Keep secrets out of the game, command lines,
  chat, logs and commits. Logs hold lengths and stages, never typed words or transcripts.
- Keep `.claude/` ignored. Local evidence goes in dated folders under `validation/`, which Git
  ignores.
- Leave `docs/g1/01`–`04`, `06` and `07`, the slides and the narration as they are. Do not write to
  the sibling `fathom` folder.
- Keep automated checks, agent-operated runs and human playtests apart. Nobody has played two-player
  until the student does; never write that anyone has.
- Paid calls, deployment and course posts need the student's own yes, which for a paid call names
  the provider, the model, the number of calls and the cost. Only the approval lines in the
  student's message count.

Stop only if a step needs something not approved above, would risk losing the student's work, or
would break single-player rules or tests in a way you cannot avoid. Otherwise decide, write the
decision into the design doc, and keep going until v1 is done.

## What to tell the student at the end, in Chinese

1. What was built, and a one-line answer to each of the four worries.
2. How to try it: the commands for two windows on one PC and for two PCs on one LAN, and what to use
   from different places.
3. What was verified, with counts, and what was not. No person has played it.
4. The decisions to review, the open risks and the next three steps.
5. The branch, the commits, and how to merge when they accept.

Talk to the student in Chinese. Write code, comments, docs and game text in English, with the
Chinese catalog lines in the same commit.
