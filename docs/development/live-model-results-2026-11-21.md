# Patient-agent cloud checkpoint, November 21, 2026

The permanent account deployment was updated on November 21 at 21:52 UTC. The public mock passed 24 dialogues and session isolation. The timeout returned 504 and the game displayed fallback after 3,823 ms. The public OpenAI Worker remained disabled and returned 503. Genuine *deployed* OpenAI calls in this checkpoint total zero. The separately authorized bilingual evaluation used the game's own local service for 1,094 real GPT-6 Luna attempts under USD 50. Its cost reservation was USD 0.595195. [Full results, deployment IDs and remaining account steps](../../HANDOFF.md#full-build-november-21)

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

The three permanent Workers deployed successfully under `demonrain777.workers.dev` at 20:36 UTC. The default service completed a fresh six-visit public mock check. The live service is disabled and its secret list has no OpenAI project key. The approved cloud check is pending the provider project hard limit and the hidden key entry. Account deployment metadata is in `validation/2026-11-21/patient-agent/p2/account-deploy.json`.

## Approved paid check

The student approved both mock deployments, disabled live setup and redeployment for the check. The approved provider is OpenAI, standard-tier `gpt-6-luna`, reasoning off. The allowance is six visits, up to 24 dialogues, zero transcriptions and a ceiling of USD 0.01. At the quoted rates, the earlier estimate was USD 0.00231. Actual live latency, usage and output quality remain unmeasured on this build. [Model prices](https://developers.openai.com/api/docs/models/gpt-6-luna)

The first attempt at permanent deployment returned a missing-credentials error. The interactive Wrangler session expired with the browser on Cloudflare's sign-in page. The remaining account steps are the student's Cloudflare login, project key at Wrangler's hidden prompt and monthly enforcement in the provider project. The temporary deployment contains no provider key. After those account steps, the operator can use the already-approved private run and restore the disabled Worker. The single-use ledger records metadata and reserves a conservative amount before each attempt. [Deployment and private-run commands](../../agent_proxy/README.md#deployment-and-rollback)

The executable evidence is under `validation/2026-11-21/patient-agent/`, including `p1/public-checks.json`, `p1/public-game-{mock,timeout}.log`, `p1/temporary-deploy.json`, `p1/worker/results.json` and `p1-verified/checks.json`. All game input was automated. Human play and real microphone input are unverified.
