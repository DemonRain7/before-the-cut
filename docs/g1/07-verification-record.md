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

- The final recording combines the student's 22:24 take through **04:53** with the complete 22:39 final-slide take. It is **5:49.17**, 2560 by 1440, H.264/AAC. The student explicitly chose not to make duration edits; the assignment's three-to-five-minute criterion is therefore not claimed as met.
- The new take removes the development-assistant recommendation sentence. Its brief initial black screen was filled with its first visible frame while preserving the entire audio and the requested splice point. Original recordings were not changed.
- Full video decoding completed without errors. The base and ending were transcribed locally with Whisper base.en and read alongside sampled frames covering all nine slides. Automatic speech recognition is not a certified verbatim transcript or a claim of continuous manual listening.
- The saved deck is version **50**, preserving the student's edits. The updated PDF has nine pages. The changed ending and the all-slide montage were visually reviewed.
- The revised **419-word** script omits the removed sentence. Its three-page Word document was rendered and all pages were visually checked. It is a drafting script, not a transcript of the student's additional spoken explanations.
- The assignment and corrected announcement were rechecked in authenticated Chrome on November 14. G1 is due **November 15 at 23:59 New York**; two self-selected Braintrust replies are due **November 19 at 23:59**.
- The Initial GDD, Initial Configuration Document and Initial Project Plan opened through the public GitHub connector. The source inspection also found a newer Trauma Team call/dispatch/crew sequence; it has not been retested in this submission audit.
- CourseWorks posting remains pending the student's final review and Reply click. Repository publication and attachment upload are separate from posting.

## Earlier evidence

November 12 checks covered the earlier scan/re-check prototype: 269 game assertions, 141 UI assertions, 28 proxy tests and 73 controlled HTTP checks. Those are historical counts and should not be added to or substituted for the current suite.

Still unverified: live model relevance, latency and cost; human playtesting; deployed service; standalone game export; final course submission.
