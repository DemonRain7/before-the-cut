# Continue Before the Cut

Start with the [appointment memory checkpoint](HANDOFF.md#one-session-per-appointment), then read the [full build](HANDOFF.md#full-build-november-21) and [milestone record](docs/development/full-build-progress.md). The M1–M7 build is on `main`. The only pending M0 item is the account-dependent paid check of the deployed Worker. The version is rules 12, protocol 4. The student selected wear, the warned second PRESS, all repairs, pushing milestones and redeploying the three existing services.

## Run the game

```powershell
.\run-game.ps1 -Patient script -Language zh -Seed 41307 -TestNight I
.\run-game.ps1 -Patient mock -Language en -Seed 41307 -TestNight I
.\run-game.ps1 -Patient live -Language zh -Seed 41307 -TestNight J
```

The first command uses authored patients, the second uses labelled fixtures, and the third starts the game's local HTTP service and calls OpenAI GPT-6 Luna after the operator enters `LIVE`. SETTINGS starts with patient AI off. Its default endpoint is the permanent public mock. Night I shows physical wear and night J shows speech and temper wear. F10 pauses a night and opens the return-to-menu confirmation.

## Working contract

Use the patient's own identity, work, motive and voice on every generated turn. Handle free-form speech through the ten-class semantic router. Each appointment owns one session for the doctor, patient, visible reactions and observable actions. Keep the persona prefix stable and put the current event last. See the appointment memory entry in HANDOFF. Speech and temper cues enter only after their game-owned evidence gate opens. Godot owns physical state, patience, verdicts and payout. An inferred paid question shows its price before it spends a lamp. ASK uses case-authored answers. Optional arrival, after-check and idle turns share the 16 dialogue replies and have their own three-attempt limit. Late turns are dropped.

Keep the mock, forced-timeout and disabled-live Workers on their existing names in `demonrain777.workers.dev`. The separate local paid E1–E4 ledger contains 1,094 GPT-6 Luna attempts, with a conservative reservation of USD 0.595195. The evaluation left authored ASK in place. The post-evaluation schema and price confirmation have Godot and mock coverage. The public M6 probes passed and the live Worker replies with 503. See [service operations](agent_proxy/README.md) and [evaluation and the E6 sheet](tools/eval/README.md).

## Next three tasks

1. The existing Braintrust action belongs to the student. Preserve the original item under “Next three tasks” in HANDOFF. No course post was sent.
2. Once the owner confirms the monthly hard spend limit and enters the OpenAI key at Wrangler's hidden prompt, run the already-approved deployed checkpoint through the protected enable/disable block in the proxy runbook. Six visits, at most 24 dialogues, zero transcriptions and USD 0.01. Confirm disabled health again. The instructor's required Worker foundation and November 23 rubric still need confirmation from the course.
3. The student reads the 20 synthetic E2 replies per language. Recruit at least three outsiders for the scripted/live E6 comparison on both seeded nights with its own human-session budget. Nobody has played the new build. Review their measured decisions, shutter catches and follow-ups before changing the rules or the ASK default.

Current public deployment evidence is in `validation/2026-11-21/patient-agent/visit-session-cloud/`, local regression and bilingual frames in `visit-record-release/`, and computed play and the November 21 evaluation in `validation/2026-11-21/full-build/`. Keep raw samples and validation local. Credentials are managed by the service. Keep the historical November 15 ledger closed.
