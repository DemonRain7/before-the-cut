import test from "node:test";
import assert from "node:assert/strict";
import { setTimeout as delay } from "node:timers/promises";
import { createHandler, createMemoryCounters, DEFAULT_LIMITS, serviceSettings } from "../src/core.mjs";
import { createMockProvider } from "../src/providers.mjs";
import { loadGameData } from "../src/dev_server.mjs";
import worker from "../src/worker.mjs";
import { probe } from "../probe.mjs";

test("two interleaved sessions keep their own prompts, visit counts and logged ids with asynchronous storage", async () => {
	const memory = createMemoryCounters();
	const counters = {
		async takeSession(...args) { await delay(2); return memory.takeSession(...args); },
		async takeDay(...args) { await delay(1); return memory.takeDay(...args); },
	};
	const mock = createMockProvider();
	const sessions = new Set();
	const logs = [];
	const provider = { ...mock, async generate(input, signal) {
		const { req, user, system } = input;
		sessions.add(req.session_id);
		assert.ok(user.includes("history-" + req.session_id));
		assert.ok(!user.includes("history-" + (req.language === "en" ? "b-" : "a-")));
		assert.ok(system.includes(req.language === "en" ? "Reply in English." : "Reply in Simplified Chinese"));
		assert.equal(input.caseData.id, req.language === "en" ? "kip" : "maren");
		return mock.generate(input, signal);
	} };
	const handle = createHandler({ ...loadGameData(), provider, counters, log: e => logs.push(e) });
	await probe(async (path, body) => handle({ path, method: body === undefined ? "GET" : "POST",
		bodyText: body instanceof ReadableStream ? await new Response(body).text() : body }));
	assert.equal(sessions.size, 2);
	for (const id of sessions) {
		const a = id.startsWith("a-");
		const mine = logs.filter(e => e.session_id === id);
		assert.equal(mine.length, a ? 17 : 2);
		assert.ok(mine.every(e => e.visit_id === id.slice(2) && e.case_id === (a ? "kip" : "maren") && e.language === (a ? "en" : "zh")));
	}
	assert.ok(!JSON.stringify(logs).includes("history-"));
});

test("a returning patient starts with a fresh session and no words or actions from their last visit", async () => {
	const mock = createMockProvider(), inputs = [];
	const handle = createHandler({...loadGameData(), provider:{...mock, async generate(input, signal) {
		inputs.push(input); return mock.generate(input, signal);
	}}});
	const result = await probe((path, bodyText) => handle({path, method:bodyText ? "POST" : "GET", bodyText}), "visit");
	assert.equal(result.history_entries, 67);
	assert.equal(inputs.length, 2);
	const [a,b] = inputs;
	assert.equal(a.req.run_id, b.req.run_id);
	assert.notEqual(a.req.session_id, b.req.session_id);
	assert.deepEqual(b.req.conversation_history, []);
	assert.equal(b.req.visit_summary, undefined);
	assert.ok(!b.user.includes("First appointment"));
	assert.deepEqual(JSON.parse(a.user).visit_summary.actions, {"open:grip":2,"done:grip":1,"press:1":1});
});

test("the kill switch and voice switch answer before reading or counting", async () => {
	const unexpected = () => assert.fail("body or counters touched");
	for (const disabled of [true, false]) {
		const handle = createHandler({ ...loadGameData(), provider: createMockProvider(), disabled, transcribeEnabled: false,
			counters: { takeSession: unexpected, takeDay: unexpected } });
		const health = await handle({ path: "/healthz", method: "GET" });
		assert.equal(health.body.disabled, disabled);
		assert.equal(health.body.speech_to_text, false);
		for (const path of disabled ? ["/v1/patient-dialogue", "/v1/transcribe", "/healthz", "/other"] : ["/v1/transcribe"]) {
			const res = await handle({ path, method: "POST", readBody: unexpected });
			assert.equal(res.status, disabled ? 503 : 501);
		}
	}
});

test("the checkpoint window authorizes only its operator's dialogue and fails closed", async () => {
	const token = "a".repeat(64);
	const env = { BTC_CHECK_ONLY: "1", BTC_CHECK_TOKEN: token };
	const post = (route, auth, vars) => worker.fetch(new Request("https://example.test" + route, { method: "POST", body: "{",
		headers: auth ? { authorization: "Bearer " + auth } : {} }), vars);
	assert.equal((await post("/v1/patient-dialogue", "", { ...env, BTC_DISABLED: "1" })).status, 503);
	assert.equal((await post("/v1/patient-dialogue", token, { BTC_CHECK_ONLY: "1" })).status, 503);
	assert.equal((await post("/v1/patient-dialogue", "", env)).status, 401);
	assert.equal((await post("/v1/patient-dialogue", "b".repeat(64), env)).status, 401);
	assert.equal((await post("/v1/patient-intent", token, env)).status, 403);
	assert.equal((await post("/v1/transcribe", token, env)).status, 403);
	assert.equal((await post("/v1/patient-dialogue", token, env)).status, 400);
});

test("the Worker cancels a chunked body as soon as it exceeds its cap, despite a short declared length", async () => {
	let cancelled = false;
	let reads = 0;
	const stream = new ReadableStream({
		pull(controller) { reads++; controller.enqueue(new Uint8Array(DEFAULT_LIMITS.maxBodyBytes + 1)); },
		cancel() { cancelled = true; },
	}, { highWaterMark: 0 });
	const res = await worker.fetch(new Request("https://example.test/v1/patient-dialogue", {
		method: "POST", headers: { "content-length": "1" }, body: stream, duplex: "half" }), {});
	assert.equal(res.status, 413);
	assert.ok(cancelled);
	assert.equal(reads, 1);
});

test("zero daily allowance and malformed deployment limits never remove a ceiling", () => {
	assert.equal(serviceSettings({ BTC_DAILY_BUDGET: "0" }).limits.maxCallsPerDay, 0);
	assert.ok(serviceSettings({ BTC_DISABLED: "1", BTC_DAILY_BUDGET: "invalid" }).disabled);
	for (const value of ["", "-1", "Infinity", "1.5", "words"]) assert.throws(() => serviceSettings({ BTC_DAILY_BUDGET: value }));
	assert.throws(() => serviceSettings({ BTC_UPSTREAM_TIMEOUT_MS: "0" }));
});
