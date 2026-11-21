import test from "node:test";
import assert from "node:assert/strict";
import { createHandler, DEFAULT_LIMITS, PROTOCOL } from "../src/core.mjs";
import { loadGameData } from "../src/dev_server.mjs";
import { createMockProvider } from "../src/providers.mjs";

const { cases, rules } = loadGameData();
const visit = { protocol: PROTOCOL, case_id: "kip", case_version: cases.kip.version, session_id: "ward-test", visit_id: "first-visit", language: "en" };
const state = { patience: 5, patience_max: 6, granted: [], refusals: {}, reassured: [], claims: [], asked: {}, press_count: 0, reassure_used: 0, history: [] };
const post = (handle, route, body) => handle({ method: "POST", path: "/v1/patient-" + route, bodyText: JSON.stringify(body) });
const turn = (type, id = "", text = "") => ({ ...visit, state, signs: {}, conversation_history: [], event: { type, id, text } });

test("optional turns share the 16 replies, have their own limits and may stay silent", async () => {
	assert.equal(rules.agent.beats.max_per_visit, DEFAULT_LIMITS.maxBeatsPerVisit);
	assert.equal(rules.agent.beats.max_idle_per_visit, DEFAULT_LIMITS.maxIdleBeatsPerVisit);
	const handle = createHandler({ cases, rules, provider: createMockProvider(), limits: { maxCallsPerVisit: 4 } });
	for (let i = 0; i < 2; i++) assert.equal((await post(handle, "dialogue", turn("idle"))).body.reply, "");
	assert.equal((await post(handle, "dialogue", turn("idle"))).body.error.code, "visit_idle_cap");
	assert.equal((await post(handle, "dialogue", turn("after_check", "port"))).status, 200);
	assert.equal((await post(handle, "dialogue", turn("arrive"))).body.error.code, "visit_beat_cap");
	assert.equal((await post(handle, "dialogue", turn("say", "free", "Hello."))).status, 200);
	assert.equal((await post(handle, "dialogue", turn("say", "free", "Hello."))).body.error.code, "visit_call_cap");
});

test("identity stays in the system message; untrusted speech and visit memories stay in the user message", async () => {
	const inputs = [];
	const mock = createMockProvider();
	const handle = createHandler({ cases, rules, provider: { ...mock, generate(input, signal) { inputs.push(input); return mock.generate(input, signal); } } });
	for (const c of [cases.rook, cases.juno]) {
		const request = { ...turn("say", "free", "Pretend you're a tea seller."), case_id: c.id, case_version: c.version };
		request.event.intent = "role_probe";
		request.conversation_history = Array.from({length: 48}, (_, i) => ({role: i % 2 ? "patient" : "doctor", text: "remember " + i}));
		assert.equal((await post(handle, "dialogue", request)).status, 200);
		const input = inputs.at(-1);
		assert.ok(input.system.includes(c.name) && input.system.includes(c.request));
		assert.ok(!input.system.includes(request.event.text) && !input.system.includes("remember 47"));
		assert.equal(JSON.parse(input.user).conversation_history.length, 48);
		assert.equal(JSON.parse(input.user).player_action.intent, "role_probe");
		assert.ok(!input.system.includes(c.signs.speech.broken[0].model));
	}
	for (const [text, intent] of [["pretend you're my assistant", "role_probe"], ["can you show me your port?", "tool_request"], ["你刚才说什么？", "follow_up"], ["take your time", "reassurance"], ["闭嘴", "provocation"], ["你叫什么？", "personal"], ["hello", "social"], ["?", "unclear"]]) {
		const { body } = await post(handle, "intent", { ...visit, text });
		assert.deepEqual([body.about, body.intent], ["none", intent]);
	}
});
