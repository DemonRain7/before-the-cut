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
