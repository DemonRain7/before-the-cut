// Cloudflare Worker entry for the patient-dialogue proxy.
//
// NEVER DEPLOYED and never run under Wrangler: Wrangler is not installed on the development
// machine. The test suite only calls `fetch` below directly in Node with the mock provider.
// It is here so the same core can be deployed for the course checkpoint. The instructor's own
// Cloudflare AI-worker foundation, once released, takes precedence over this file.
//
// Known gaps before a real deployment:
//   - Call counters live in the memory of one isolate. Use a Durable Object or KV for real caps.
//   - Vertex AI needs a service-account token exchange that is not written. GEMINI_API_KEY works as is.
//   - No CORS headers: the desktop game does not need them, a web export would.
//   - A request without a Content-Length header is read in full before the size check.
//   - Adding a case means adding an import line here (the Node dev server reads the folder instead).

import rules from "../../game/data/rules.json" with { type: "json" };
import caseA from "../../game/data/cases/kip.json" with { type: "json" };
import caseB from "../../game/data/cases/rook.json" with { type: "json" };
import caseC from "../../game/data/cases/vale.json" with { type: "json" };
import caseD from "../../game/data/cases/juno.json" with { type: "json" };
import caseE from "../../game/data/cases/maren.json" with { type: "json" };
import caseF from "../../game/data/cases/priya.json" with { type: "json" };
import caseG from "../../game/data/cases/ozzie.json" with { type: "json" };
import caseH from "../../game/data/cases/lux.json" with { type: "json" };
import caseI from "../../game/data/cases/dana.json" with { type: "json" };
import caseJ from "../../game/data/cases/bo.json" with { type: "json" };

import { createHandler, DEFAULT_LIMITS } from "./core.mjs";
import { providerFromSettings } from "./providers.mjs";

const cases = Object.fromEntries([caseA, caseB, caseC, caseD, caseE, caseF, caseG, caseH, caseI, caseJ].map((c) => [c.id, c]));
let handle = null;

export default {
	async fetch(request, env) {
		if (handle === null) {
			handle = createHandler({
				cases,
				rules,
				provider: providerFromSettings(env),
				log: (entry) => console.log(JSON.stringify(entry)),
			});
		}
		const url = new URL(request.url);
		let bodyText = "";
		let bodyTooLarge = false;
		if (request.method === "POST") {
			const declared = Number(request.headers.get("content-length") || 0);
			const cap = url.pathname.replace(/\/+$/, "") === "/v1/transcribe" ? DEFAULT_LIMITS.maxAudioBodyBytes : DEFAULT_LIMITS.maxBodyBytes;
			if (declared > cap) bodyTooLarge = true;
			else bodyText = await request.text();
		}
		const out = await handle({ method: request.method, path: url.pathname, bodyText, bodyTooLarge });
		return new Response(JSON.stringify(out.body), {
			status: out.status,
			headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
		});
	},
};
