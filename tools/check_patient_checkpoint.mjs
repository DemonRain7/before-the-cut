// A six-visit checkpoint. Use the mock first. The live run is restricted to the private Worker.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { buildPrompt, DEFAULT_LIMITS, PROTOCOL, validateRequest } from "../agent_proxy/src/core.mjs";
import { openAIInput } from "../agent_proxy/src/providers.mjs";
import { loadGameData } from "../agent_proxy/src/dev_server.mjs";

const [mode, address, directory] = process.argv.slice(2);
if (!["mock", "live"].includes(mode) || !address || !directory) throw Error("Expected mock|live <service-address> <new-evidence-directory>");
const base = new URL(address);
const live = mode === "live";
if (base.username || base.password || base.search || base.hash || base.pathname !== "/") throw Error("Use a plain service origin.");
if (live && (base.protocol !== "https:" || !/^before-the-cut-agent-live\.[a-z0-9-]+\.workers\.dev$/.test(base.hostname)))
	throw Error("The live checkpoint requires the deployed live Worker.");
const token = live ? process.env.BTC_CHECK_TOKEN : "";
if (live && !/^[a-f0-9]{64}$/.test(token || "")) throw Error("Set the private checkpoint token in the operator environment.");
const root = path.resolve(directory);
const approved = fileURLToPath(new URL("../validation/2026-11-21/patient-agent/approved-live", import.meta.url));
if (live && path.relative(approved, root) !== "") throw Error("Use the existing November 21 authorization directory: validation/2026-11-21/patient-agent/approved-live");
fs.mkdirSync(root, { recursive: true });
const ledger = path.join(root, "checkpoint.jsonl");
async function readyService() {
	const deadline = Date.now() + 45000;
	while (true) {
		const health = await fetch(new URL("/healthz", base), { cache:"no-store", redirect:"error", signal:AbortSignal.timeout(10000) });
		assert.equal(health.status, 200);
		const info = await health.json();
		assert.equal(info.protocol, PROTOCOL);
		assert.equal(info.provider, live ? "openai" : "mock");
		if (!live) {
			assert.equal(info.disabled, false);
			return info;
		}
		assert.equal(info.model, "gpt-6-luna");
		assert.equal(info.speech_to_text, false);
		if (!info.disabled) {
			// This anonymous malformed request cannot reach the model. During propagation
			// a POST can still hit the disabled version after health sees the enabled one.
			const gate = await fetch(new URL("/v1/patient-dialogue", base), { method:"POST", body:"{", redirect:"error", signal:AbortSignal.timeout(8000) });
			const code = (await gate.json()).error?.code;
			if (gate.status === 401 && code === "checkpoint_unauthorized") return info;
			assert.ok(gate.status === 503 && code === "service_disabled", "the paid environment must reject anonymous POSTs");
		}
		if (Date.now() >= deadline) throw Error("The private checkpoint deployment is still disabled.");
		await new Promise(resolve => setTimeout(resolve, 1000));
	}
}
const info = await readyService();
const { cases, rules } = loadGameData();
const translations = {};
for (const id of Object.keys(cases)) {
	const catalog = new URL("../game/data/lang/zh/cases/" + id + ".json", import.meta.url);
	Object.assign(translations, JSON.parse(fs.readFileSync(catalog, "utf8")).strings);
}
const visits = [["kip","en"],["priya","zh"],["ozzie","en"],["lux","zh"],["dana","en"],["bo","zh"]];
const session = randomUUID();
const usage = [], casesSeen = [];
let reserved = 0, spentBound = 0;
const maxNanoUsd = 10_000_000; // USD 0.01 in billionths of a dollar
// The highest standard input rate is a cache write ($0.125/M). Reserve a further 10% for regional pricing.
const inputNanoUsd = 138;
const outputNanoUsd = 550;
const fd = fs.openSync(ledger, "wx"); // Reserve a fresh ledger exclusively. A rerun cannot reset it.
function record(row) { fs.writeSync(fd, JSON.stringify(row) + "\n"); fs.fsyncSync(fd); }
try {
	for (const [i, [id, language]] of visits.entries()) {
		const c = cases[id], zh = language === "zh";
		const q = c.topics.find(t => t.id === "sleep") || c.topics[0];
		const speech = c.signs.speech[i % 2 ? "broken" : "normal"][0];
		const temper = c.signs.temper[i % 3 ? "normal" : "broken"][0];
		const hearing = { patience: rules.visit.lamps, patience_max: rules.visit.lamps, granted: [], refusals: {}, reassured: [], claims: [], asked: {}, press_count: 0, reassure_used: 0, history: [] };
		const history = c.opening.map(text => ({ role:"patient", text:zh ? (translations[text] || text) : text }));
		const actions = [
			{ type:"check", id:"grip", text:zh ? "请握一下把手。" : "Please hold the handle." },
			{ type:"ask", id:q.id, outcome:"answer", text:zh ? (translations[q.q] || q.q) : q.q },
			{ type:"say", id:"free", text:zh ? "想聊聊音乐吗？" : "Would you like to talk about music?" },
			{ type:"press", id:"challenge", text:zh ? "请你说清楚。" : "Give me a straight answer." },
		];
		const signs = {};
		for (const [j, event] of actions.entries()) {
			if (event.outcome === "answer") signs.speech = !speech.evidence?.length || speech.evidence.includes(q.id) ? speech.id : c.signs.speech.normal[0].id;
			if (event.type === "press") signs.temper = temper.id;
			const visit = session + "-" + i;
			const body = { protocol:PROTOCOL, run_id:session, session_id:visit, visit_id:visit, case_id:id, case_version:c.version,
				language, state:hearing, signs, event, conversation_history:history };
			const checked = validateRequest(body, cases);
			assert.ok(checked.ok);
			const prompt = buildPrompt(c,rules,checked.req,zh ? 55 : 110);
			// Each UTF-8 byte can take at most one token. Include the schema and framing, then reserve the full output limit.
			const inputBound = Buffer.byteLength(JSON.stringify([openAIInput({...prompt, req:checked.req}, true), prompt.schema])) + 1024;
			const worst = inputBound * inputNanoUsd + DEFAULT_LIMITS.maxOutputTokens * outputNanoUsd;
			if (reserved >= 24 || spentBound + worst > maxNanoUsd) throw Error("Authorized checkpoint limit reached.");
			const meta = { index:++reserved, case_id:id, language, event:event.type };
			record({ ...meta, stage:"reserved", max_nano_usd:worst });
			const started = performance.now();
			const response = await fetch(new URL("/v1/patient-dialogue",base), { method:"POST", redirect:"error",
				headers:{ "content-type":"application/json", ...(live ? {authorization:"Bearer " + token} : {}) },
				body:JSON.stringify(body), signal:AbortSignal.timeout(9000) });
			const data = await response.json();
			const latency = Math.round(performance.now() - started);
			const input = data.meta?.usage?.input_tokens, output = data.meta?.usage?.output_tokens;
			const cached = data.meta?.usage?.cached_input_tokens, written = data.meta?.usage?.cache_write_tokens;
			const measured = Number.isSafeInteger(input) && input >= 0 && Number.isSafeInteger(output) && output >= 0;
			const reads = measured && Number.isSafeInteger(cached) && cached >= 0 && cached <= input ? cached : null;
			const writes = measured && Number.isSafeInteger(written) && written >= 0 && written <= input - (reads ?? 0) ? written : null;
			spentBound += measured ? input * inputNanoUsd + output * outputNanoUsd : worst;
			record({ ...meta, stage:"response", status:response.status, code:response.ok ? "ok" : data.error?.code, latency_ms:latency,
				request_id:data.meta?.request_id, input_tokens:input ?? null, output_tokens:output ?? null,
				cached_input_tokens:reads, cache_write_tokens:writes,
				...(response.ok ? {provider:data.meta?.provider, model:data.meta?.model, mock:data.meta?.mock}
					: /^[a-z][a-z0-9_]{0,39}$/.test(data.error?.message ?? "") ? {detail:data.error.message} : {}) });
			if (!response.ok) throw Error("Checkpoint stopped after HTTP " + response.status + " (" + (data.error?.code || "unknown") + ").");
			assert.equal(data.meta.mock, !live);
			assert.equal(data.meta.provider, info.provider);
			assert.ok(measured);
			assert.ok(typeof data.reply === "string" && data.reply.length > 0);
			usage.push({ latency, input, output, cached:reads, written:writes });
			history.push({role:"doctor",text:event.text});
			if (data.reaction) history.push({role:"reaction",text:data.reaction});
			history.push({role:"patient",text:data.reply});
			if (j === 0) {
				hearing.patience -= rules.costs.check;
				if (data.cooperates) hearing.granted.push("grip"); else hearing.refusals.grip = 1;
			} else if (j === 1) {
				hearing.asked[q.id] = 1;
			}
		}
		casesSeen.push(id);
	}
	const latencies = usage.map(r=>r.latency).sort((a,b)=>a-b);
	const input = usage.reduce((n,r)=>n+r.input,0), output = usage.reduce((n,r)=>n+r.output,0);
	const reads = usage.filter(r => r.cached !== null), writes = usage.filter(r => r.written !== null);
	const cached = reads.reduce((n,r)=>n+r.cached,0), written = writes.reduce((n,r)=>n+r.written,0);
	const summary = { mode, protocol:PROTOCOL, provider:info.provider, model:info.model, dialogue:reserved, transcriptions:0, cases:casesSeen,
		input_tokens:input, output_tokens:output, cache_read_reports:reads.length, cache_write_reports:writes.length,
		cached_input_tokens:reads.length ? cached : null, cache_write_tokens:writes.length ? written : null,
		estimated_usd:((input-cached-written)*100+cached*10+written*125+output*500)/1e9, conservative_usd:spentBound/1e9,
		median_ms:(latencies[11]+latencies[12])/2, p90_ms:latencies[21], max_ms:latencies.at(-1) };
	fs.writeFileSync(path.join(root,"summary.json"), JSON.stringify(summary,null,2) + "\n");
	console.log(JSON.stringify(summary));
} finally {
	fs.closeSync(fd);
}
