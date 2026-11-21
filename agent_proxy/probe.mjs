// Synthetic calls only. This probe refuses a service whose health does not name the mock.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { pathToFileURL } from "node:url";
import { loadGameData } from "./src/dev_server.mjs";
import { DEFAULT_LIMITS, PROTOCOL } from "./src/core.mjs";

const { cases } = loadGameData();
const route = "/v1/patient-dialogue";

function patient(id, language, session, visit) {
	const c = cases[id];
	return {
		protocol: PROTOCOL, session_id: session, visit_id: visit, case_id: id, case_version: c.version, language,
		signs: { speech: c.signs.speech.normal[0].id, temper: c.signs.temper.normal[0].id },
		event: { type: "ask", id: c.topics[0].id, text: c.topics[0].q },
		conversation_history: [{ role: "doctor", text: "history-" + session }],
		state: { patience: 5, patience_max: 6, granted: [], refusals: {}, reassured: [], claims: [],
			asked: {}, press_count: 0, reassure_used: 0, history: [] },
	};
}

export async function probe(send, scenario = "isolation") {
	const health = await send("/healthz");
	assert.equal(health.status, 200);
	assert.equal(health.body.provider, "mock");
	assert.equal(health.body.protocol, PROTOCOL);
	const run = randomUUID();
	const a = patient("kip", "en", "a-" + run, run);
	const b = patient("maren", "zh", "b-" + run, run); // Deliberately share the same visit id.
	const post = (body) => send(route, JSON.stringify(body));
	function accepted(r, language) {
		assert.equal(r.status, 200);
		assert.equal(r.body.meta?.mock, true);
		assert.equal(/\p{Script=Han}/u.test(r.body.reply), language === "zh");
	}
	function refused(r, status, code) {
		assert.equal(r.status, status);
		assert.equal(r.body.error?.code, code);
	}
	if (scenario === "disabled") {
		assert.equal(health.body.disabled, true);
		for (const path of [route, "/v1/transcribe", "/unknown"]) refused(await send(path, "{"), 503, "service_disabled");
		return { posts: 3, status: 503 };
	}
	assert.equal(health.body.disabled, false);
	if (scenario === "timeout") {
		const start = performance.now();
		refused(await post(a), 504, "upstream_timeout");
		return { posts: 1, status: 504, elapsed_ms: Math.round(performance.now() - start) };
	}
	if (scenario === "budget") {
		const results = await Promise.all([post(a), post(b), post(a), post(b)]);
		assert.equal(results.filter(r => r.status === 200 && r.body.meta?.mock).length, 3);
		const over = results.filter(r => r.status !== 200);
		assert.equal(over.length, 1);
		refused(over[0], 429, "budget_exhausted");
		return { accepted: 3, denied: 1 };
	}
	assert.equal(scenario, "isolation");
	const [first, second] = await Promise.all([post(a), post(b)]);
	accepted(first, "en");
	accepted(second, "zh");
	for (let count = 2; count <= DEFAULT_LIMITS.maxCallsPerVisit; count++) accepted(await post(a), "en");
	const [capped, continuing] = await Promise.all([post(a), post(b)]);
	refused(capped, 429, "visit_call_cap");
	accepted(continuing, "zh");
	// Stream without declaring its length, so the transport must enforce the actual byte cap.
	const large = new ReadableStream({ start(controller) {
		controller.enqueue(new Uint8Array(DEFAULT_LIMITS.maxBodyBytes));
		controller.enqueue(new Uint8Array(1));
		controller.close();
	} });
	refused(await send(route, large), 413, "body_too_large");
	return { visits: 2, accepted_a: 16, refused_a: 17, accepted_b: 2, oversized_status: 413 };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	const base = new URL(process.argv[2]);
	const send = async (path, body) => {
		const res = await fetch(base.href.replace(/\/+$/, "") + path, { method: body === undefined ? "GET" : "POST",
			body, duplex: "half", redirect: "error", headers: { "content-type": "application/json" }, signal: AbortSignal.timeout(10000) });
		return { status: res.status, body: await res.json() };
	};
	console.log(JSON.stringify(await probe(send, process.argv[3])));
}
