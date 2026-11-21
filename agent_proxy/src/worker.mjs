// Desktop patient service. All isolates reserve quota in the same SQLite-backed objects.
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

import { createHandler, DEFAULT_LIMITS, serviceSettings } from "./core.mjs";
import { providerFromSettings } from "./providers.mjs";

const cases = Object.fromEntries([caseA, caseB, caseC, caseD, caseE, caseF, caseG, caseH, caseI, caseJ].map((c) => [c.id, c]));

// One object per session and one per UTC day. Only counter keys and integers are persisted.
export class SessionCounter {
	constructor(ctx) {
		this.storage = ctx.storage;
	}

	async fetch(request) {
		const entries = await request.json();
		const sql = this.storage.sql;
		const full = this.storage.transactionSync(() => {
			sql.exec("CREATE TABLE IF NOT EXISTS counts (key TEXT PRIMARY KEY, n INTEGER NOT NULL)");
			return entries.findIndex(([key, limit]) => {
				if (limit === 0) return true;
				return sql.exec(
					"INSERT INTO counts VALUES (?, 1) ON CONFLICT(key) DO UPDATE SET n = n + 1 WHERE n < ? RETURNING n",
					key, limit
				).toArray().length === 0;
			});
		});
		await this.storage.setAlarm(Date.now() + DEFAULT_LIMITS.counterRetentionDays * 86400000);
		return Response.json(full);
	}

	async alarm() {
		// A request arriving as an old alarm is delivered can renew this object's expiry.
		if (await this.storage.getAlarm() === null) await this.storage.deleteAll();
	}
}

function durableCounters(env) {
	async function take(name, entries) {
		const stub = env.SESSIONS.getByName(name);
		const response = await stub.fetch("https://counter/take", { method: "POST", body: JSON.stringify(entries) });
		if (!response.ok) throw new Error("counter_unavailable");
		const index = await response.json();
		if (!Number.isInteger(index) || index < -1 || index >= entries.length) throw new Error("counter_unavailable");
		return index;
	}
	return {
		takeSession: (id, entries) => take("session:" + id, entries),
		takeDay: async (day, limit) => await take("day:" + day, [["calls", limit]]) === -1,
	};
}

async function readCapped(request, cap) {
	const reader = request.body?.getReader();
	let bodyText = "";
	if (!reader) return { bodyText };
	let bytes = 0;
	const decoder = new TextDecoder();
	try {
		while (true) {
			const { value, done } = await reader.read();
			if (done) return { bodyText: bodyText + decoder.decode() };
			bytes += value.byteLength;
			if (bytes > cap) {
				reader.cancel().catch(() => {});
				return { bodyTooLarge: true };
			}
			bodyText += decoder.decode(value, { stream: true });
		}
	} finally {
		reader.releaseLock();
	}
}

export function createWorker(countersFor = durableCounters) {
	return {
		async fetch(request, env) {
			const options = serviceSettings(env);
			// Only the live environment opts in to provider billing, even with local env overrides.
			const settings = env.BTC_ALLOW_LIVE === "1" ? env : { BTC_PROVIDER: "mock", BTC_MOCK_FAIL: env.BTC_MOCK_FAIL };
			const provider = options.disabled
				? { name: settings.BTC_PROVIDER || "mock", model: settings.BTC_MODEL || "" }
				: providerFromSettings(settings);
			const handle = createHandler({ cases, rules, provider, ...options, counters: countersFor(env),
				log: (entry) => console.log(JSON.stringify(entry)) });
			const out = await handle({ method: request.method, path: new URL(request.url).pathname,
				readBody: (cap) => readCapped(request, cap) });
			return Response.json(out.body, { status: out.status, headers: { "cache-control": "no-store" } });
		},
	};
}

export default createWorker();
