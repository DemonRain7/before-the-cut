// Exercise real appointment history through the game's local HTTP route. Only usage is retained.
import assert from "node:assert/strict";
import fs from "node:fs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import { PROTOCOL } from "../../agent_proxy/src/core.mjs";
import { loadGameData, startServer } from "../../agent_proxy/src/dev_server.mjs";
import { createMockProvider, providerFromSettings } from "../../agent_proxy/src/providers.mjs";
import { openLedger } from "./ledger.mjs";

const mode = process.argv[2];
const phase = process.argv[3] || "visits";
if (!["mock", "live"].includes(mode) || !["visits","history","game"].includes(phase) || process.argv.length > 4)
	throw Error("Expected mock or separately approved live, with optional visits, history or game");
const live = mode === "live";
const root = fileURLToPath(new URL("../../validation/2026-11-21/patient-cache/", import.meta.url));
fs.mkdirSync(root, {recursive:true});
const dir = live ? root + "live" : fs.mkdtempSync(root + "mock-");
const base = live ? providerFromSettings({...process.env, BTC_PROVIDER:"openai", BTC_MODEL:"gpt-6-luna", BTC_REASONING_EFFORT:"none"}) : createMockProvider();
const ledger = openLedger(dir, live, "cache");
const extended = phase === "history";
const game = phase === "game";
const group = {visits:"C", history:"H", game:"G"}[phase];
const visitsByPhase = {
	visits: [
		["rook", "zh", ["你下班后想做什么？", "上班时你和谁最谈得来？", "愿意多说一句吗？", "你希望今天什么时候离开？"]],
		["kip", "en", ["What are you in a hurry to get back to?", "How do you feel about the wait?"]],
		["rook", "zh", ["今天来这儿之前你在哪儿？", "你还惦记着工作吗？"]],
	],
	history: [["rook", "en", ["What matters most to you about the job?", "Do the people on your shift understand that?",
		"What would you like them to understand?", "What are you hoping to get back to today?"]]],
	game: [],
};
const { cases } = loadGameData();
function appendListed(history, state, c, topic) {
	const answer = c.signs.speech.normal[0].answers[topic.id].a;
	history.push({role:"doctor", text:topic.q}, {role:"action", text:"ask:" + topic.id + ":answer"}, {role:"patient", text:answer});
	state.asked[topic.id] = 1;
}
let step = 0;
let phaseUpper = 0;
let service;
try {
	if (ledger.attempts.has(group + "-1")) throw Error("This checkpoint already reserved calls. See its ledger.");
	const provider = {...base, transcribe: undefined, async generate(input, signal) {
		if (game) {
			step++;
			assert.ok(step === 1 ? input.intent === true : step === 2 && input.req.event?.type === "say");
		} else assert.ok(!input.intent && input.req.event.type === "say");
		phaseUpper += ledger.reserve(group + "-" + step, input);
		return base.generate(input, signal);
	}};
	const logs = [];
	service = await startServer({host:"127.0.0.1", port:0, provider, transcribeEnabled:false, log:entry => {
		logs.push(entry);
		if (game && ["intent","dialogue"].includes(entry.route)) ledger.append({stage:"response", id:"G-" + step, route:entry.route,
			status:entry.status, input:entry.input_tokens ?? null, output:entry.output_tokens ?? null,
			read:entry.cached_input_tokens ?? null, written:entry.cache_write_tokens ?? null});
	}});
	const health = await (await fetch(service.url + "/healthz")).json();
	assert.equal(health.provider, live ? "openai" : "mock");
	assert.equal(health.model, base.model);
	assert.equal(health.protocol, PROTOCOL);
	assert.equal(health.disabled, false);
	if (game) {
		const project = fileURLToPath(new URL("../../game/", import.meta.url));
		const {stdout} = await promisify(execFile)(process.env.GODOT_BIN || "godot",
			["--headless","--audio-driver","Dummy","--path",project,"--script","res://tests/run_proxy_integration.gd","--",
				"--launch-check=cache-turn","--expected-provider=" + base.name,"--agent-url=" + service.url,"--model","--mute","--no-surprises","--test-night=K","--lang=en"],
			{timeout:60000, windowsHide:true});
		assert.match(stdout, /CACHE TURN: 4 passed, 0 failed/);
		console.log("Godot displayed the provider reply and reused the classification.");
	}
	for (const [index, [id, language, questions]] of visitsByPhase[phase].entries()) {
		const visit = "cache-appointment-" + group + "-" + index;
		const history = [];
		const c = cases[id];
		const state = {patience:2, patience_max:2, granted:[], claims:[], asked:{}, press_count:0, complaints_told:[]};
		if (extended) {
			for (const text of c.opening) history.push({role:"patient", text});
			for (const topic of c.topics.slice(0,2)) appendListed(history, state, c, topic);
			assert.equal(history.length, 8);
		}
		for (const text of questions) {
			step++;
			if (extended && step === 3) {
				appendListed(history, state, c, c.topics[2]);
				history.push({role:"action", text:"look:hands"});
				assert.ok(history.length >= 16);
			}
			const body = {protocol:PROTOCOL, run_id:"cache-check", session_id:visit, visit_id:visit, case_id:id,
				case_version:c.version, language, signs:extended ? {speech:c.signs.speech.normal[0].id} : {}, conversation_history:history, state,
				event:{type:"say", id:"free", intent:history.length ? "follow_up" : "personal", text}};
			const response = await fetch(service.url + "/v1/patient-dialogue", {method:"POST", headers:{"content-type":"application/json"},
				body:JSON.stringify(body), signal:AbortSignal.timeout(6500)});
			const result = await response.json();
			const log = logs.at(-1);
			ledger.append({stage:"response", id:group + "-" + step, visit, history_entries:history.length, status:response.status,
				input:log.input_tokens ?? null, output:log.output_tokens ?? null, read:log.cached_input_tokens ?? null, written:log.cache_write_tokens ?? null});
			if (!response.ok) throw Error("Turn " + step + " returned " + response.status + " " + result.error?.code);
			assert.equal(result.meta.provider, base.name);
			assert.equal(result.meta.mock, !live);
			history.push({role:"doctor", text});
			if (result.reaction) history.push({role:"reaction", text:result.reaction});
			history.push({role:"patient", text:result.reply});
		}
	}
} finally {
	if (service) await service.close();
	const rows = ledger.events.filter(row => row.stage === "response");
	const reports = rows.filter(row => Number.isSafeInteger(row.read) && Number.isSafeInteger(row.input));
	const sum = (items,key) => items.reduce((total,row) => total + row[key], 0);
	const usage = {mode, provider:base.name, model:base.model, attempts:ledger.attempts.size, responses:rows.length,
		reads_reported:reports.length, hits:reports.length ? reports.filter(row => row.read > 0).length : null,
		cached_input:reports.length ? sum(reports,"read") : null, input_with_read_report:reports.length ? sum(reports,"input") : null,
		phase_upper_usd:phaseUpper/1e9, reserved_upper_usd:ledger.bound/1e9};
	if (reports.length && reports.every(row => Number.isSafeInteger(row.written) && Number.isSafeInteger(row.output))) {
		const written = sum(reports, "written"), output = sum(reports, "output");
		usage.estimated_reported_usd = ((usage.input_with_read_report - usage.cached_input - written)*100
			+ usage.cached_input*10 + written*125 + output*500)/1e9;
	}
	fs.writeFileSync(dir + "/summary.json", JSON.stringify(usage,null,2) + "\n");
	console.log(JSON.stringify(usage));
	ledger.close();
}
