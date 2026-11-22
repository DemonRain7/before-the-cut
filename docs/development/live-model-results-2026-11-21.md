# Patient-agent model checkpoints, November 21, 2026

## Local play and prompt-cache reads

Godot can reach GPT-6 Luna through the game's loopback service. A configured checkout starts that service with the normal Windows launcher. The shared performance instructions precede the selected language and case soul. Each appointment supplies its own chronological history. New speech and changing visit state sit beyond the explicit cache boundaries. [Shared rules](../../agent_proxy/src/patient_instructions.mjs) · [OpenAI transport](../../agent_proxy/src/providers.mjs) · [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)

The owner approved a fresh local evaluation with a USD 0.05 total ceiling. All 14 production-route requests returned HTTP 200 and reported actual OpenAI usage. The first eight dialogue calls covered Rook in Chinese, Kip in English and a new Chinese visit by Rook. Seven had a cache read. The first English Kip call began with empty history and read 1,101 cached tokens. The returning Rook also began with empty history and read 1,288. The shared rules and the static character were reusable independently of a previous visit's conversation.

| Route | Requests with an OpenAI cache read | Cached / total input tokens |
| --- | ---: | ---: |
| Dialogue | 12 / 13 (92.3%) | 15,483 / 19,236 (80.49%) |
| Intent | 0 / 1 | 0 / 399 |
| Combined | 12 / 14 (85.7%) | 15,483 / 19,635 (78.85%) |

Four English Rook calls exercised history groups. The visit started with eight entries drawn from his authored opening and two answered questions. After subsequent real model replies and another authored exchange, the requests carried 8, 10, 16 and 18 history entries. Their cache reads were 1,101, 1,398, 1,398 and 1,563 tokens respectively. The last two requests reused the earlier complete group while writing the next one, then read the longer prefix.

The last two provider requests came from a headless Godot visit. The driver opened the typing control, entered a social question and verified that OpenAI's reply appeared in the patient's displayed history. A repeat lookup of the same doctor's sentence returned from the local intent cache. Total reported output was 542 tokens, with 1,890 input cache-write tokens. Standard pricing gives an estimated USD 0.00088828. The ledger reserved at most USD 0.049979694 in total. This repeat-visit sample measures the selected turns. The earlier 400-request evaluation used independent short cases. [Measurement client](../../tools/eval/visit_cache.mjs) · [Godot scene check](../../game/tests/run_proxy_integration.gd) · [GPT-6 Luna prices](https://developers.openai.com/api/docs/models/gpt-6-luna)

## Deployed Worker checkpoint

At 6:06 p.m. New York time on November 21, the game's permanent Cloudflare Worker completed **24 out of 24 real OpenAI GPT-6 Luna dialogue requests**. The automated client used the game's public HTTPS dialogue route, with a private bearer for the duration of the check. Kip, Ozzie and Dana each received four turns in English. Priya, Lux and Bo each received four in Chinese. Each appointment exercised a GRIP request, ASK, conversation and PRESS. Each response carried a distinct request ID, the OpenAI provider and model, and token usage. Voice and intent received zero provider calls. [Checkpoint client](../../tools/check_patient_checkpoint.mjs)

| Measured on the deployed service | Result |
| --- | ---: |
| End-to-end response latency, median / p90 / maximum | 1.524 / 2.063 / 2.539 s |
| Input / output tokens | 26,613 / 1,666 |
| Cached input / cache writes | 3,149 / 16,652 tokens |
| Replies with a cache read | 3 of 24 |
| Estimated standard-tier OpenAI usage | USD 0.00362719 |
| Conservative cost bound / approved ceiling | USD 0.004588894 / USD 0.01 |

OpenAI reported reads and writes on all 24 responses, including zero counts. The estimate values ordinary input, reads, writes and output separately. The conservative figure charges every input token at the upper input rate. Both figures use reported token counts. [OpenAI model pricing](https://developers.openai.com/api/docs/models/gpt-6-luna) · [Prompt cache accounting](https://developers.openai.com/api/docs/guides/prompt-caching)

The owner confirmed the project spending limit. The existing application credential was bound to the live Worker through Wrangler's secret input. During the check an anonymous dialogue POST received 401, and authenticated intent and voice POSTs received 403. One preliminary propagation check encountered the prior disabled edge version and spent zero provider calls. The runner now waits for the private gate before creating its paid ledger.

At 6:07 p.m. New York time, the live service again reported disabled and a dialogue POST returned 503 `service_disabled`. The temporary bearer was removed. The OpenAI project secret remains bound on the live Worker. Its final deployment serves version `efe51909-6088-42ba-9a3e-e0cce995e262` at 100% traffic. The single-use ledger and summary are in `validation/2026-11-21/patient-agent/approved-live/`, and deployment checks are in `cloud-acceptance-ops/` beside it. [Current live health](https://before-the-cut-agent-live.demonrain777.workers.dev/healthz)

The accompanying release passed all 23 local regression groups and nine guard and evaluation tests. Both language captures produced 464 frames. The public mock also completed 24/24 in a separate rehearsal. Local check logs are under `validation/2026-11-21/patient-agent/m0-cloud-green/`.

## Earlier public checks

At 21:52 UTC the permanent account deployment was updated. Its public mock passed 24 dialogues and session isolation. The timeout returned 504 and the game displayed fallback after 3,823 ms. A separate bilingual evaluation had used the game's local service for 1,094 real GPT-6 Luna attempts, with USD 0.595195 reserved. [Full build results](../../HANDOFF.md#full-build-november-21)

The material below records the earlier one-hour preview.

## Public preview

Wrangler 4.166.0 deployed protocol 4 at approximately 11:28 a.m. EST on November 21. All three health endpoints reported ten current cases and speech input off. Cloudflare removes an unclaimed preview after one hour, approximately 12:28 p.m. EST for this run. Use the authenticated deployment commands for a persistent public address. [Cloudflare preview lifetime](https://developers.cloudflare.com/workers/platform/claim-deployments/)

| Environment | Observed against the public Worker |
| --- | --- |
| [Mock health](https://before-the-cut-agent.patch-adjustment.workers.dev/healthz) | Concurrent English and Chinese visits shared the same visit id in separate sessions. A received 16 replies, then HTTP 429 on attempt 17. B received its second reply. A streamed 32,769-byte request got 413. Godot showed its first mock reply after 373 ms. |
| [Timeout health](https://before-the-cut-agent-timeout.patch-adjustment.workers.dev/healthz) | The HTTP probe got 504 `upstream_timeout` after 3,773 ms. In a separate headless Godot visit, the corner showed OFFLINE FALLBACK at 3,836 ms. The scripted reply and reason appeared, and the visit finished at the slip. |
| [Disabled live health](https://before-the-cut-agent-live.patch-adjustment.workers.dev/healthz) | Health reported `openai`, `gpt-6-luna`, protocol 4 and `disabled: true`. A POST got 503 `service_disabled`. |

The six-visit checkpoint sent four dialogue requests per visit through the public mock. Kip, Ozzie and Dana used English. Priya, Lux and Bo used Chinese. Both broken sign types were represented. All 24 mock replies arrived. The public mock's measured median/p90/maximum were 95.5/126/296 ms. These times include the network trip to Cloudflare. The same fixtures also passed on local Node and local Wrangler.

## Account deployment

The three permanent Workers deployed successfully under `demonrain777.workers.dev` at 20:36 UTC. The default service completed a fresh six-visit public mock check. At that point the live service was disabled and its secret list was empty. The deployed checkpoint above records the subsequent binding and paid results. Account deployment metadata is in `validation/2026-11-21/patient-agent/p2/account-deploy.json`.

## Approved paid check

The student approved both mock deployments, disabled live setup and redeployment for the check. The approved provider is OpenAI, standard-tier `gpt-6-luna`, reasoning off. The allowance is six visits, up to 24 dialogues, zero transcriptions and a ceiling of USD 0.01. At the quoted rates, the earlier estimate was USD 0.00231. The deployed checkpoint above records the observed latency, token usage and cost estimate. [Model prices](https://developers.openai.com/api/docs/models/gpt-6-luna)

The first permanent deployment attempt encountered an expired Wrangler sign-in. The subsequent authenticated deployment and completed checkpoint are recorded above. The single-use ledger reserves a conservative amount before each paid attempt. [Deployment and private-run commands](../../agent_proxy/README.md#deployment-and-rollback)

The executable evidence is under `validation/2026-11-21/patient-agent/`, including `p1/public-checks.json`, `p1/public-game-{mock,timeout}.log`, `p1/temporary-deploy.json`, `p1/worker/results.json` and `p1-verified/checks.json`. All game input was automated. Human play and real microphone input are unverified.
