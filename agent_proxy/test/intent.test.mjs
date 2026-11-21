import assert from "node:assert/strict";
import test from "node:test";
import { createHandler, PROTOCOL } from "../src/core.mjs";
import { loadGameData } from "../src/dev_server.mjs";
import { createMockProvider } from "../src/providers.mjs";

const { cases, rules } = loadGameData();
const intent = (text, visit = "test-visit") => ({ protocol: PROTOCOL, session_id: "test-session",
	visit_id: visit, case_id: "kip", case_version: cases.kip.version, language: "en", text });
const post = (handle, route, body) => handle({ method: "POST", path: "/v1/" + route, bodyText: JSON.stringify(body) });
const read = (handle, body) => post(handle, "patient-intent", body);

test("intent carries only questions and the submitted line to a strict enum", async () => {
	const mock = createMockProvider(), logs = [], inputs = [];
	const provider = { ...mock, async generate(input, signal) { inputs.push(input); return mock.generate(input, signal); } };
	const handle = createHandler({ cases, rules, provider, log: e => logs.push(e) });
	for (const [text, expected, language] of [["How have you slept?", "sleep", "en"], ["昨晚睡得好吗？", "sleep", "zh"], ["Please show me the port.", "none", "en"], ["Hello.", "none", "en"]]) {
		const r = await read(handle, { ...intent(text), language, signs: { temper: "hidden" }, conversation_history: ["private"], state: { truth: "hidden" } });
		assert.equal(r.status, 200);
		assert.equal(r.body.about, expected);
		const input = inputs.at(-1);
		assert.deepEqual(JSON.parse(input.user), { line: text });
		assert.ok(input.system.includes(JSON.stringify(cases.kip.topics.map(({ id, q }) => ({ id, q })))));
		assert.deepEqual(input.schema.properties.choice.enum.filter(k => k.startsWith("ask_")), cases.kip.topics.map(t => "ask_" + t.id));
		assert.deepEqual(input.schema.required, ["choice"]);
		assert.equal(input.caseData, undefined);
		assert.ok(!JSON.stringify([input.system, input.user]).includes("hidden"));
		assert.ok(!JSON.stringify(logs).includes(text));
	}
});

test("intent rejects stale clients and bad input before spending, and rejects unknown model labels", async () => {
	const handle = createHandler({ cases, rules, provider: createMockProvider({ fail: "invalid_shape" }) });
	for (const [patch, status] of [[{ protocol: "3" }, 409], [{ text: "" }, 400], [{ text: "x".repeat(501) }, 400],
		[{ visit_id: "?" }, 400], [{ case_version: 99 }, 409], [{ language: "xx" }, 400], [{ case_id: "missing" }, 404]]) {
		assert.equal((await read(handle, { ...intent("Hello"), ...patch })).status, status);
	}
	assert.equal((await read(handle, intent("Hello"))).body.error.code, "invalid_model_output");
	const slow = createHandler({ cases, rules, provider: createMockProvider({ fail: "timeout" }), limits: { intentTimeoutMs: 20 } });
	assert.equal((await read(slow, intent("Hello"))).body.error.code, "upstream_timeout");
});

test("intent has distinct visit and session quotas and shares the day budget with dialogue", async () => {
	const handle = createHandler({ cases, rules, provider: createMockProvider(), limits: { maxIntentsPerVisit: 1, maxIntentsPerSession: 2, maxCallsPerDay: 3 } });
	const one = intent("Hi.");
	assert.equal((await read(handle, one)).status, 200);
	assert.equal((await read(handle, one)).body.error.code, "visit_intent_cap");
	assert.equal((await read(handle, intent("Hi.", "second-visit"))).status, 200);
	assert.equal((await read(handle, intent("Hi.", "third-visit"))).body.error.code, "session_intent_cap");
	const state = { patience: 5, patience_max: 6, granted: [], refusals: {}, reassured: [], claims: [], asked: {}, press_count: 0, reassure_used: 0, history: [] };
	const dialogue = { ...one, signs: {}, event: { type: "say", text: "Hi." }, state, conversation_history: [] };
	assert.equal((await post(handle, "patient-dialogue", dialogue)).status, 200);
	assert.equal((await post(handle, "patient-dialogue", dialogue)).body.error.code, "budget_exhausted");
});

test("a named outcome controls cooperation and inappropriate outcomes or question ids fail", async () => {
	const mock = createMockProvider();
	const handle = createHandler({ cases, rules, provider: mock });
	const forced = createHandler({ cases, rules, provider: { ...mock, generate: async () => ({ text: JSON.stringify({ reply: "Yes.", reaction: "", cooperates: true }) }) } });
	const body = { ...intent("Hello."), signs: {}, state: { patience: 5, patience_max: 6, granted: [], refusals: {}, reassured: [], claims: [], asked: {}, press_count: 0, reassure_used: 0, history: [] }, conversation_history: [] };
	for (const [type, id, outcome, value] of [["ask","sleep","answer",true],["ask","why","deflect",false],["check","grip","grant",true],["check","port","refuse",false]]) {
		const req = { ...body, event: { type, id, text: "Please.", outcome } };
		assert.equal((await post(handle, "patient-dialogue", req)).body.cooperates, value);
		if (!value) assert.equal((await post(forced, "patient-dialogue", req)).body.error.message, "outcome_mismatch");
	}
	for (const event of [{type:"ask",id:"why"}, {type:"ask",id:"why",outcome:"grant"}, {type:"say",outcome:"answer"}])
		assert.equal((await post(handle, "patient-dialogue", { ...body,event:{ ...event,text:"Hello." } })).status,400);
	assert.equal((await post(handle,"patient-dialogue",{ ...body, event:{type:"say",text:"Hi"},state:{ ...body.state,asked:{free:1} } })).status,400);
});
