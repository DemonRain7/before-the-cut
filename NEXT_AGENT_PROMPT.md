# Continue Before the Cut

The end-of-shift animation was remade twice on November 22. It is now one silhouette film per night, chosen from the settlements: the massacre by a drifting patient the doctor treated, a repair when everyone admitted was steady, the crew waiting when the doctor was killed at the glass, or the empty chair. The massacre ends on the patient's face, flashed for under half a second with glowing eyes, so the player sees whom they let in. On November 23 the massacre was made bloodier at the owner's request: throats opened in pumps of blood, pools, a bloody palm that cracks the lens, blood on the face and the card, and nine new sounds. Less blood removes all of the blood and keeps the horror. Later that day the massacre card was given the patient's own words: their thanks from the counter, twisted and breaking into a shaking laugh (the owner wanted it mad, not AI-sounding and not flat). [Shots, endings and checks](docs/development/closing-shift/film.md) · [Watch night K](docs/development/closing-shift/film-night-K-zh.mp4). No person has watched or heard it yet. At the end of K and L, note whether a player says who it is before the card does, whether they look away or skip the 44-second massacre, and whether it changes their next night's calls. Its local evidence is in `validation/2026-11-22/silhouette-film/`, `validation/2026-11-23/bloodier-massacre/` and `validation/2026-11-23/card-quote/`. The owner has reserved two-player intake and hands-on implant surgery for a later phase, with notes in [the surgery concept](docs/development/closing-shift/next-game.md).

The chart now has a FILE tab with the registration and a supporting slip for each of the ten characters. In Chinese teaching night K, compare Rook's location and Juno's name. Ask an outside player to show where they found the file, tell you how they reconciled one account and explain their decision after PRESS. The test fixtures cover typed wording, confirmed dictation and provider timeout. [Release evidence and next playtest](docs/development/play-loop-redesign/PROGRESS.md#cross-checking-the-intake-file)

Rules 15 and patient protocol 5 are on main. A committed push can reveal a physical tell, end the visit or do both. The fourth always ends it. The silhouette film plays after every shift, whether ordinary, empty or fatal. ENTER goes to the next chapter, ESC opens the report and R replays the film from any report page. [Pressure rules and the film](docs/development/closing-shift/release.md) · [Future solo and co-op ideas](docs/development/closing-shift/next-game.md)

One steady desk light indicates a possible next action based on what the patient has said. All tests remain available under the two-lamp rules. On K, watch where an unfamiliar player looks after Kip mentions his eyes. On L, Juno has no specific complaint. [Current desk guidance](docs/development/play-loop-redesign/PROGRESS.md#guidance-at-the-counter)

## Run the game

A configured checkout starts GPT-6 Luna on loopback. `-CheckPatient` verifies its connection in Godot at the title. A typed turn through the live local service, return visits, and reuse of complete history groups were checked in the [local cache evaluation](docs/development/live-model-results-2026-11-21.md#local-play-and-prompt-cache-reads).

During playtests, watch for repeated stock lines when the service times out and for questions about a previous remark that get a generic listed answer. Both occurred during automated Chinese play. [Chinese conversation check](docs/development/live-model-results-2026-11-21.md#chinese-dialogue-at-the-counter)

```powershell
.\run-game.ps1 -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient mock -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight L
```

## Working contract

Every appointment opens a new session. Keep identity and personality stable, maintain its ordered dialogue and actions, and send only already earned facts. The game owns which complaints, tests and notes exist. Every listed question is answered free. The character can use their own words for a complaint and the patient's authored sentence backs up failed wording or transport. A new instrument test, a funded first PRESS or a wrong contact code spends one examination lamp. All optional dialogue fits within the 16-reply limit.

All 11 engine relations and five paid language targets held. The 400 responses came from OpenAI GPT-6 Luna through the same HTTP service as the game, with a USD 0.0293384 standard-rate estimate. The public mock and forced-timeout Workers were checked after their single update and the public live kill switch is on. [Evidence and versions](docs/development/play-loop-redesign/PROGRESS.md)

## Next three tasks

1. The existing Braintrust action belongs to the student. Preserve the original item under “Next three tasks” in HANDOFF. No course post was sent.
2. Confirm the instructor’s required Worker foundation and November 23 rubric from the course. The paid checkpoint evidence and closed ledger are available in the build handoff.
3. Use the ten-minute acceptance sheet for night K, then observe outsiders on K and L. Record whether their next test followed a complaint, their one-cross decisions and shutter catches. Any paid human-session comparison has its own budget.

Current evidence is in `validation/2026-11-21/play-loop/`. The cloud probes are in `workers/`, and the closed L1–L5 ledger in `slim-live/`. Keep historical paid ledgers and local evidence in place.
