# Verification summary

The current implementation evidence was recorded on November 14, 2026, in the active development workspace. These are automated checks with local mocks, not human playtests or live-model results. Game source has not yet been transferred to this public repository.

| Current check | Recorded result |
|---|---|
| Game checks | 260 passed |
| Main-scene UI checks | 246 passed |
| Proxy tests | 18 passed |
| Real Godot HTTP and scene checks with controlled mocks | 49 passed |
| Patient dialogue transport | Protocol 3; generated speech/reactions, no authored-answer substitution |
| Live model calls | 0 |
| Voice implementation | Not implemented; future handoff only |

The source hashes, logs and test output are retained in the local development verification record. No game code was changed or retested during this submission audit.

## Recording and document audit

- The first video is 7 minutes 14.54 seconds, exceeding the required 3 to 5 minutes. The student chose to rerecord, not speed it up.
- The replacement narration is 249 spoken words, synchronized with all nine slide notes. At 55 to 60 words per minute with brief slide changes, the estimate is 4:27 to 4:50; no replacement recording or timed rehearsal is claimed.
- The two-page Word script was rendered and visually checked. Slides 6 and 7 clarify the game-state boundary and dated budget assumptions. The saved deck is version 25.
- The earlier video was sampled visually across all nine slides. Its narration was not transcribed or fully listened to in this audit. Its technical loudness was low, so the replacement needs a microphone check.
- The assignment and corrected announcement were rechecked in authenticated Chrome on November 14. G1 is due November 15 at 23:59 New York; two self-selected Braintrust replies are due November 19 at 23:59.
- CourseWorks submission remains pending. Repository publication is not course submission.

## Earlier evidence

November 12 checks covered the earlier scan/re-check prototype: 269 game assertions, 141 UI assertions, 28 proxy tests and 73 controlled HTTP checks. Those are historical counts and should not be added to or substituted for the current suite.

Still unverified: live model relevance, latency and cost; human playtesting; deployed service; standalone game export; the replacement recording and final course submission.
