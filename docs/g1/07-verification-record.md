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
- The rejected 249-word draft is superseded by 434 words based on local speech recognition of the actual recording and comparison with the sampled slides. At 95 to 105 words per minute with slide pauses, the estimate is about 4:26 to 4:52. A new timed rehearsal and recording remain pending.
- The revised three-page Word script was rendered and visually checked. Slides 4 and 9 were corrected to match the recorded reasons and explain the student/development-assistant distinction. The saved deck is version 27.
- The earlier video was sampled visually across all nine slides. Its narration was subsequently transcribed locally with Whisper base.en and read in full alongside sampled frames. The automatic transcript contains recognition errors and is not a verbatim certified transcript. Its technical loudness was low, so the replacement needs a microphone check.
- The assignment and corrected announcement were rechecked in authenticated Chrome on November 14. G1 is due November 15 at 23:59 New York; two self-selected Braintrust replies are due November 19 at 23:59.
- CourseWorks submission remains pending. Repository publication is not course submission.

## Earlier evidence

November 12 checks covered the earlier scan/re-check prototype: 269 game assertions, 141 UI assertions, 28 proxy tests and 73 controlled HTTP checks. Those are historical counts and should not be added to or substituted for the current suite.

Still unverified: live model relevance, latency and cost; human playtesting; deployed service; standalone game export; the replacement recording and final course submission.
