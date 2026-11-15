**Autonomous-dialogue materials, November 14:** saved deck version 22 updates slides 5-7, their narration and the current design/configuration documents. The script has 543 spoken words, with an estimated 4:52 including transitions. Nine PDF pages match the reviewed slide renders; all three Word pages were reviewed. The earlier move-enum runtime is not changed or newly validated by this documentation update. New provider cost and latency remain unmeasured.

# Verification summary

These results describe local automated checks on November 12, 2026, of the earlier scan/re-check prototype. They do not verify the revised optional-examination design or establish player enjoyment.

| Check | Recorded result |
|---|---|
| Godot import and rendered main scene | Passed locally using Godot 4.7.2 |
| Game rule suite | 269 assertions passed |
| Main-scene flow suite | 141 assertions passed across four automated shifts |
| Patient proxy tests | 28 passed |
| Real Godot HTTP client with controlled local mocks | 73 checks passed |
| Complete evidence path through the mock proxy | 10 requests |
| Proxy-deadline fallback as seen by the game | 2,068 ms, controlled mock failure |
| Client-deadline fallback | 2,504 ms, controlled mock failure |
| Prompt size on the ten-request evidence path | 2,043–2,828 characters, mean 2,432; not provider token counts |

The development workspace retains the raw logs, test tools and screenshots. Those raw records remain local. No new game tests were run for repository publication or reorganization. The ongoing repository has been prepared for source transfer, which waits for the active writer to stop.

Not yet verified: the revised normal reference and optional actions/dialogue implementation now in progress; a real model call; real model latency/cost measurements; human playtesting; deployed proxy; standalone game export. The G1 recording and CourseWorks submission are separate and remain the student's tasks unless a later record establishes completion.
