# Finishing the build: progress

One file for whoever is working, so that another agent can take over at any point. The run is
defined in `docs/development/patient-agent-handoff/KICKOFF.md`. Tick a box when its milestone
is committed, and write the commit and the counts beside it. Keep this file short: the detail
goes into `HANDOFF.md`.

## State when this file was written

November 21, 2026, about 15:50 New York, by Claude (Fable). Read from the repository and not
re-run.

- `origin/main` is `06714b8`. P0 is `5afe1f3` and P1 is `06714b8`, both by Codex: rules version
  11, protocol 4, fix 4 of the review built. Counts are in `HANDOFF.md`, first section.
- **Still uncommitted,** from the earlier sessions of November 21: four flow fixes (`game/`,
  `tools/art/measure_text.py`), the play-logic review and its brief, the patient-agent handoff
  folder, those sessions' entries in `HANDOFF.md` and `NEXT_AGENT_PROMPT.md`, and the three
  files of this run (`KICKOFF.md` rewritten, `play-logic-build.md`, this file).
- `validation/2026-11-21/patient-agent/p2/account-deploy.json` records three deployments at
  20:36 UTC with exit code 0. The handoff files do not mention them yet. Not checked by the
  writer of this file.
- The paid check that is approved (OpenAI `gpt-6-luna`, at most 24 dialogues, 0
  transcriptions, USD 0.01) had not been run according to `HANDOFF.md`.
- Nothing of the play-logic build, P2 or P3 exists.
- The item-by-item audit of the review against its brief was not done. The student said on
  November 21 that it can wait. Milestone M2 measures the built rules again.
- Nobody has played the build.

## Checklist

- [x] **M0 baseline.** Re-ran all checks on `06714b8` with the existing November 21 edits, including the empty import, both boots, guard (7), six mock visits (24 dialogues) and hidden captures. Commands and logs are in `validation/2026-11-21/patient-agent/finish-M0/`.
- [ ] **M0 paid cloud check.** All three permanent Workers were deployed to the student's account. The live service is disabled. Wrangler lists zero OpenAI secrets in that environment. The message provides an API key and an evaluation ceiling. It does not specify a configured monthly hard limit in the API project.
- [x] **M1 November 21 work.** Flow changes are `d4bb069`. The review and phase briefs follow in the documentation commit. M0 (`4bc8697`) verified these exact game files.
- [x] **M2 play logic.** `642b2ba`. Rules 12, R1–R7, nights I/J, bilingual teaching, report and captures. Rules 2,074; scenes 1,232 / 1,233 / 1,232; proxy 52; guard 7; HTTP / wire 334 / 100; 1,623 text measurements per language; 460 drawn frames each. Every check passed. See `validation/2026-11-21/patient-agent/finish-M2-green/` and the 5,000-night measurements in `validation/2026-11-21/full-build/play-logic/`.
- [x] **M3 P2 and character continuity.** Authored openings, optional arrival / instrument / idle lines, ten intent classes and per-patient identity. Rules 2,084; scenes 1,232 / 1,233 / 1,232; proxy 54; guard 7; HTTP / wire 342 / 100; text 1,623 per language; drawn 461 per language. Separate slow successful replies verified cancellation on input. Evidence in `finish-M3-green`.
- [ ] **M4 P3, evaluation** (`02-phases.md`, section 7).
  - [ ] Scripts in `tools/eval/`, each set run against the mock. Commit:
  - [ ] Live runs E1 to E4: only with the student's yes. Result, or "not approved":
  - [ ] The kit for E6 (two launch commands, seeded nights, a count sheet). Commit:
- [ ] **M5 Two loose ends.** The LIGHTS OUT line when nobody was waiting; a way back to the
      menu during a night, behind a confirm. Commit:
- [ ] **M6 The deployed services** match the build, if redeploying is approved. Otherwise
      "Needs the student". Result:
- [ ] **M7 Finish.** Every check in both languages, drawn captures looked at, `HANDOFF.md`
      and `NEXT_AGENT_PROMPT.md` updated, the report to the student in Chinese.

## Counts

| Check | Baseline (start of the run) | End of the run |
| --- | ---: | ---: |
| Rules | 2,025 | |
| Scene test, English / Chinese / less blood | 1,184 / 1,185 / 1,184 | |
| Proxy tests | 52 | |
| Godot HTTP / wire assertions | 334 / 100 | |
| Lines measured per language | 1,623 / 1,623 | |
| Captures, English / Chinese | 447 / 447 | |

## Decisions taken by default in this run

The student chose A, the warned second PRESS, all repairs, milestone publication and deployment. D5 uses authored graded answers pending E2 and human review. D6 allows three optional beats and two idle beats. D7 permits private synthetic evaluation samples. D8 leaves cross-night memory off. D9 keeps patient AI opt-in. E1–E4 use the published test sets and standard-tier GPT-6 Luna under the student's USD 50 ceiling.

## Where a brief was wrong

Write one line for each: what the brief said, what the code or the measurement said, what was
built.

## Needs the student

The project owner must enable monthly hard enforcement in OpenAI project Settings > Limits and enter the project key at `npx --yes wrangler@4.166.0 secret put OPENAI_API_KEY --env live` from `agent_proxy`. Then execute the already-approved 24-dialogue private checkpoint and restore the kill switch. No additional spending approval is needed for that run.

## Stopped here

If the run stops before M7: the last green commit, the step that was in hand, and the next
step.
