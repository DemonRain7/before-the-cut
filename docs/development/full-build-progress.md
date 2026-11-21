# Finishing the build: progress

The November 21 full build follows KICKOFF. The results below are from this checkout and the three permanent services. [Full report and reproduction commands](../../HANDOFF.md#full-build-november-21)

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

- [x] **M0 baseline.** `4bc8697`. Re-ran all checks on `06714b8` with the existing November 21 edits, including the empty import, both boots, guard (7), six mock visits (24 dialogues) and hidden captures. Commands and logs are in `validation/2026-11-21/patient-agent/finish-M0/`.
- [ ] **M0 paid cloud check.** All three permanent Workers were deployed to the student's account. The live service is disabled. Wrangler lists zero OpenAI secrets in that environment. The message provides an API key and an evaluation ceiling. It does not specify a configured monthly hard limit in the API project.
- [x] **M1 November 21 work.** Flow changes are `d4bb069`. The review, phase briefs and earlier handoffs are `634be3b`. M0 (`4bc8697`) verified these exact game files.
- [x] **M2 play logic.** `642b2ba`. Rules 12, R1–R7, nights I/J, bilingual teaching, report and captures. Rules 2,074; scenes 1,232 / 1,233 / 1,232; proxy 52; guard 7; HTTP / wire 334 / 100; 1,623 text measurements per language; 460 drawn frames each. Every check passed. See `validation/2026-11-21/patient-agent/finish-M2-green/` and the 5,000-night measurements in `validation/2026-11-21/full-build/play-logic/`.
- [x] **M3 P2 and character continuity.** `ee5559a`. Authored openings, optional arrival / instrument / idle lines, ten intent classes and per-patient identity. Rules 2,084; scenes 1,232 / 1,233 / 1,232; proxy 54; guard 7; HTTP / wire 342 / 100; text 1,623 per language; drawn 461 per language. Separate slow successful replies verified cancellation on input. Evidence in `finish-M3-green`.
- [x] **M4 P3 evaluation.** `cfba5cc`. The mock completed all 1,102 calls. The game's loopback service sent 1,094 live GPT-6 Luna requests under a USD 50 ceiling. Eight unavailable E2 answers had no text to judge. The conservative reservation for all attempts was USD 0.595195. E1 returned zero erroneous charges on 160 controls but missed 81/240 questions. Of the 37 unavailable classifications, 33 were questions and four were free controls. The shipped classifier uses one unambiguous output enum and shows the inferred question and lamp charge before accepting it. This correction was tested with the mock and Godot. E2's 49/120 normal and 68/84 broken graded answers leave ASK authored. Local E2 reading set holds 20 replies per language. E3 flagged zero of 118 valid replies by the phrase screen. E4 refused civil / neutral / rude 0 / 1 / 0 times out of 58 each. E5 real medians and p90 were 754/1,001 ms for intent and 1,293/1,637 ms for dialogue. E6's balanced human kit is in `tools/eval/README.md`. Evidence in `validation/2026-11-21/full-build/eval/`.
- [x] **M5 Two loose ends.** `9758b0d`. F10 pauses the night with a bilingual loss confirmation. Cancel resumes the same visit. LIGHTS OUT mentions the hall only when a visitor is waiting. Rules 2,084, scenes 1,246 / 1,247 / 1,246, proxy 54, guard 7, evaluation guard 2, HTTP / wire 345 / 100, 1,624 lines and 463 drawn frames in each language. The fresh import, boots, settings and mock checkpoint passed. Evidence in `finish-M5-green`.
- [x] **M6 Permanent services.** `c85d5b3`. Mock `49c7b037`, timeout `966dcbdc`, disabled live `fb32716c`. The menu defaults to the public mock address. Fresh public Godot launches, six mock visits (24/24), session isolation, optional-turn caps, HTTP 504 at 3,883 ms, Godot fallback at 3,823 ms and live HTTP 503 passed. The menu with no explicit URL reached the public mock. Results in `finish-M6`. The offline scene fixture explicitly clears its address for the no-address branch. `finish-M6-green` passed 2,084 rules, 1,246 / 1,247 / 1,246 scenes, 54 proxy and 7 + 2 guard tests, 345 / 100 HTTP and wire, 1,624 lines and 463 drawn frames per language.
- [x] **M7 Finish.** The commit titled *Verify and document the full patient-agent build*. Every acceptance category passed. Results in `finish-M7/`, guard results in `finish-M7-guards.log`, and the final six public mock visits in `final-public-mock/`. Both sets of 464 actual frames include the second PRESS warning. The unmodified live launcher and real headless Chinese title also connected to the configured OpenAI service, including its voice capability, with zero provider calls. The handoff, next three tasks, player guide, service README and character contract reflect the final build.

## Counts

| Check | Baseline (start of the run) | End of the run |
| --- | ---: | ---: |
| Rules | 2,025 | 2,084 |
| Scene test, English / Chinese / less blood | 1,184 / 1,185 / 1,184 | 1,246 / 1,247 / 1,246 |
| Proxy / historical guard / evaluation tests | 52 / 7 / — | 54 / 7 / 2 |
| Godot HTTP / wire assertions | 334 / 100 | 345 / 100 |
| Lines measured, English / Chinese | 1,623 / 1,623 | 1,624 / 1,624 |
| Drawn captures, English / Chinese | 447 / 447 | 464 / 464 |

## Decisions taken by default in this run

The student chose A, the warned second PRESS, all repairs, milestone publication and deployment. D5 keeps graded ASK authored after E2 missed the threshold. Twenty synthetic answers per language await the student. D6 allows three optional beats and two idle beats. D7 permits private synthetic evaluation samples. D8 leaves cross-night memory off. D9 keeps patient AI opt-in. E1–E4 use the published test sets and standard-tier GPT-6 Luna under the student's USD 50 ceiling.

## Where a brief was wrong

- The review predicted the isolated effect of wear within 0.36 percentage points. With all repairs, the instruments / ASK / PRESS routine reached 95.47% versus the review's 98.03%. The shipped timing and lamp rules explain the difference.
- Reopening LIGHT ten times is worth exactly the solitary LIGHT with the same threshold. Requiring two observed lines is a different decision rule and yields 60.06%.
- The evaluation matrix allows 1,102 provider requests. Eight E2 candidates failed validation, leaving 196 usable candidate/judge pairs and 1,094 actual attempts. Missing answers stay in the denominators.
- E1 showed incompatible class/topic pairs and missed questions. One closed choice and an explicit price-confirmation screen shipped. E2 judged too few answers correctly to replace authored evidence. E4's equal zero civil and rude refusals provided no tone distinction.

## Needs the student

1. In the OpenAI project open Limits, enter a monthly spend amount and enable hard enforcement. From `agent_proxy` use `npx --yes wrangler@4.166.0 secret put OPENAI_API_KEY --env live` at the hidden prompt. The missing one-line confirmation is “已在 OpenAI 项目启用每月 X 美元硬上限，并在 live Worker 的隐藏提示中配置了项目密钥。” Then use the protected block for `node ../tools/check_patient_checkpoint.mjs live $liveOrigin ../validation/2026-11-21/patient-agent/approved-live`. This six-visit, 24-dialogue, zero-transcription, USD 0.01 checkpoint was already approved. [Runbook](../../agent_proxy/README.md#deployment-and-rollback)
2. Read the 20 E2 replies per language. The E6 comparison needs at least three outside players and a separate human-session budget. No one has played this build. The instructor's required Worker foundation and November 23 rubric remain unconfirmed. [Comparison kit](../../tools/eval/README.md)
