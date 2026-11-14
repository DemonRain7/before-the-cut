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

The development workspace retains the raw logs, test tools and screenshots. Those files are not published in this documentation-only snapshot. No new game tests were run to publish these documents.

Unfinished: implementation of the revised normal reference and optional actions/dialogue; a real model call; real model latency/cost measurements; human playtesting; deployed proxy; standalone game export. The G1 recording and CourseWorks submission are separate and remain the student's tasks unless a later record establishes completion.
