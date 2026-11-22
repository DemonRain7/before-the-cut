# Continue Before the Cut

Rules 13 and patient protocol 5 are released on main. Each visitor has two lamps. Asking what hurts tags possible tests. Talk is free, and only a fresh test or PRESS can trigger a surprise. The warning before BREAK names SPACE. The first visitor teaches the loop and the second teaches the contact list. [Full release, measurements and acceptance sheet](docs/development/play-loop-redesign/PROGRESS.md)

One steady desk light indicates a possible next action based on what the patient has said. All tests remain available under the two-lamp rules. On K, watch where an unfamiliar player looks after Kip mentions his eyes. On L, Juno has no specific complaint. [Current desk guidance](docs/development/play-loop-redesign/PROGRESS.md#guidance-at-the-counter)

## Run the game

A configured checkout starts GPT-6 Luna on loopback. `-CheckPatient` verifies its connection in Godot at the title. A typed turn through the live local service, return visits, and reuse of complete history groups were checked in the [local cache evaluation](docs/development/live-model-results-2026-11-21.md#local-play-and-prompt-cache-reads).

```powershell
.\run-game.ps1 -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient mock -Language zh -Seed 41307 -TestNight K
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight L
```

## Working contract

Every appointment opens a new session. Keep identity and personality stable, maintain its ordered dialogue and actions, and send only already earned facts. The game owns which complaints, tests and notes exist. Every listed question is answered free. The character can use their own words for a complaint and the patient's authored sentence backs up failed wording or transport. Only an actual test or PRESS spends an examination lamp, and a wrong contact code costs one. All optional dialogue fits within the 16-reply limit.

All 11 engine relations and five paid language targets held. The 400 responses came from OpenAI GPT-6 Luna through the same HTTP service as the game, with a USD 0.0293384 standard-rate estimate. The public mock and forced-timeout Workers were checked after their single update and the public live kill switch is on. [Evidence and versions](docs/development/play-loop-redesign/PROGRESS.md)

## Next three tasks

1. The existing Braintrust action belongs to the student. Preserve the original item under “Next three tasks” in HANDOFF. No course post was sent.
2. Confirm the instructor’s required Worker foundation and November 23 rubric from the course. The paid checkpoint evidence and closed ledger are available in the build handoff.
3. Use the ten-minute acceptance sheet for night K, then observe outsiders on K and L. Record whether their next test followed a complaint, their one-cross decisions and shutter catches. Any paid human-session comparison has its own budget.

Current evidence is in `validation/2026-11-21/play-loop/`. The cloud probes are in `workers/`, and the closed L1–L5 ledger in `slim-live/`. Keep historical paid ledgers and local evidence in place.
