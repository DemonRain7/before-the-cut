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
		event: { type: "ask", outcome: "answer", id: c.topics[0].id, text: c.topics[0].q },
		conversation_history: [{ role: "doctor", text: "history-" + session }],
		state: { patience: 2, patience_max: 2, granted: [], complaints_told: [], claims: [],
			asked: {}, press_count: 0, history: [] },
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
	if (scenario === "complaints") {
		let posts=0;
		for (const [language,row,partText] of [["en","eyes","Do your eyes hurt?"],["zh","hands","你的手指疼吗？"]]) {
			const patientCase=cases.kip;
			const id=randomUUID();
			const request={...patient("kip",language,id,id),run_id:run,signs:{},conversation_history:[]};
			for (const text of [language==="en"?"What hurts?":"哪里不舒服？",partText]) {
				const intent=await send("/v1/patient-intent",JSON.stringify({...request,text}));
				assert.equal(intent.body.intent,"complaint");posts++;
			}
			request.event={type:"complain",id:row,rows:[row],delivery:"rows",text:partText};
			const reply=await post(request);accepted(reply,language);posts++;
			assert.ok(language==="en"?reply.body.reply===patientCase.complaints[row]:reply.body.reply.includes("指"));
		}
		return {posts, languages:2, status:200};
	}
	if (scenario === "visit") {
		const first = { ...a, run_id: run, visit_id: a.session_id };
		const next = { ...b, run_id: run, session_id: "return-" + run, visit_id: "return-" + run,
			case_id: first.case_id, case_version: first.case_version, event: first.event, signs: {}, conversation_history: [] };
		first.conversation_history = Array.from({length:64}, (_, i) => ({role:"doctor", text:"First appointment " + i}));
		first.conversation_history.push({role:"action", text:"open:grip"}, {role:"action", text:"done:grip"}, {role:"action", text:"press:1"});
		first.state = {...a.state, granted:["grip"], press_count:1};
		first.visit_summary = {after:8, omitted:31, actions:{"open:grip":2,"done:grip":1,"press:1":1}};
		accepted(await post(first), "en");
		accepted(await post(next), "zh");
		refused(await post({...next, session_id:first.session_id}), 400, "bad_request");
		return {visits:2, same_case:true, history_entries:first.conversation_history.length, omitted:first.visit_summary.omitted, return_entries:0, mismatched_session_status:400};
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
