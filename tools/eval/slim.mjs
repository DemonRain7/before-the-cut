import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { startServer } from "../../agent_proxy/src/dev_server.mjs";
import { PROTOCOL } from "../../agent_proxy/src/core.mjs";
import { createMockProvider, providerFromSettings } from "../../agent_proxy/src/providers.mjs";
import { openLedger } from "./ledger.mjs";
import { limits, makeSlimCases, scoreSlim } from "./slim_cases.mjs";

const mode = process.argv[2];
if (!["mock","live"].includes(mode) || process.argv.length !== 3) throw Error("Expected exactly mock or live");
const live = mode === "live";
const dir = fileURLToPath(new URL("../../validation/2026-11-21/play-loop/slim-" + mode + "/",import.meta.url));
const rows = makeSlimCases();
for (const [group, cases] of Object.entries(rows)) {
  if (cases.length !== limits[group] || cases.filter(r=>r.request.language==="zh").length !== limits[group]/2)
    throw Error("Unbalanced matrix: " + group);
}
const provider = live ? providerFromSettings({ ...process.env, BTC_PROVIDER:"openai", BTC_MODEL:"gpt-6-luna", BTC_REASONING_EFFORT:"none" }) : createMockProvider();
const ledger = openLedger(dir, live, "slim");
let service, stopped = "";
const count = (list, pred) => list.filter(pred).length;
function report() {
  const scores = ledger.events.filter(e => e.stage === "score");
  const reservations = ledger.events.filter(e => e.stage === "reserve");
  const groups = {};
  for (const [group, target] of Object.entries(limits)) {
    const g = scores.filter(e => e.group === group);
    const good = count(g,r => r.pass);
    const complete = g.length === target;
    const threshold = {L1:.85,L2:.85,L3:.90,L4:.95,L5:.95}[group];
    const named = count(g,r=>r.named), results = count(g,r=>r.result), invented = count(g,r=>r.invented);
    groups[group] = {target, attempts:ledger.counts[group], scored:g.length, valid:count(g,r=>r.status===200), pass:good,
      by_language:Object.fromEntries(["en","zh"].map(lang=>[lang,count(g,r=>r.language===lang && r.pass)])),
      ...(group==="L3"? {false_positive:count(g,r=>r.false_positive)} : {}),
      ...(group==="L4"? {named,stated_result:results} : {}), ...(group==="L5"? {invented} : {}),
      held:complete && good/target >= threshold && (group!=="L4" || results===0)};
  }
  const withUsage = scores.filter(s => Number.isFinite(s.input) && Number.isFinite(s.output));
  const usage = key => withUsage.reduce((sum,r)=>sum+(r[key]||0),0);
  // The unit of each rate below is nanodollars per token. Missing usage stays covered by its reservation.
  let estimated = 0;
  for (const row of withUsage) {
    const cached = row.cached_input || 0, writes = row.cache_write || 0;
    estimated += Math.max(0,row.input-cached-writes)*100 + cached*10 + writes*125 + row.output*500;
  }
  const known = new Set(withUsage.map(s=>s.id));
  const pending = reservations.filter(r=>!known.has(r.id)).reduce((sum,r)=>sum+r.nano,0);
  const byStatus = {};
  for (const s of scores) byStatus[s.status]=(byStatus[s.status]||0)+1;
  const percentile = (a,p) => a.length ? a[Math.ceil(a.length*p)-1] : null;
  const latency = Object.fromEntries(["intent","dialogue"].map(route=>{
    const ms=scores.filter(s=>s.route===route && s.status===200).map(s=>s.ms).sort((a,b)=>a-b);
    return [route, {n:ms.length, median_ms:percentile(ms,.5),p90_ms:percentile(ms,.9)}];
  }));
  const summary={mode,date_utc:new Date().toISOString(),protocol:PROTOCOL,provider:provider.name,model:provider.model,attempts:reservations.length,authorized:live?5:0,
    reserved_upper_usd:ledger.bound/1e9,standard_rate_estimate_usd:estimated/1e9,unreported_upper_usd:pending/1e9,
    usage:{input:usage("input"),output:usage("output"),cached_input:usage("cached_input"),cache_write:usage("cache_write")}, latency,byStatus,groups,stopped:stopped||null};
  fs.writeFileSync(path.join(dir,"results.json"),JSON.stringify(summary,null,2)+"\n");
  return summary;
}
async function one(row) {
  const route = row.group <= "L3" ? "intent" : "dialogue";
  if (ledger.attempts.has(row.id)) return;
  const start = performance.now();
  let b = {}, status = 0;
  try {
    const res = await fetch(service.url+"/v1/patient-"+route,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(row.request),signal:AbortSignal.timeout(6500)});
    status=res.status;b=await res.json();
  } catch { /* Keep the durable reservation even when a transport dies. */ }
  if (status===200 && (b.meta?.provider!==provider.name || live && b.meta?.model!==provider.model && !/^gpt-6-luna-\d{4}-\d{2}-\d{2}$/.test(b.meta?.model || "") || b.meta?.mock!==!live)) throw Error("Response provenance mismatch");
  const safe = String(b.error?.message || "");
  if (!ledger.attempts.has(row.id) || (status===502 && /^http_(401|403|404|429)$/.test(safe)))
    stopped = /^(http_\d{3}|eval_call_cap|eval_cost_cap)$/.test(safe) ? safe : "service_before_reservation";
  const u=b.meta?.usage||{};
  ledger.append({stage:"score",id:row.id,group:row.group,language:row.request.language,case_id:row.request.case_id,row:row.row,
    expected:row.expected,about:b.about,intent:b.intent,route,status,ms:Math.round(performance.now()-start),
    input:u.input_tokens,output:u.output_tokens,cached_input:u.cached_input_tokens,cache_write:u.cache_write_tokens,...scoreSlim(row,b,status===200)});
}
try {
  service = await startServer({port:0,host:"127.0.0.1",provider:ledger.wrap(provider),transcribeEnabled:false,log:()=>{}});
  const h = await (await fetch(service.url+"/healthz")).json();
  if (h.protocol!==PROTOCOL || h.disabled || h.model!==provider.model || h.provider!==provider.name) throw Error("Unexpected service");
  for (const [group, cases] of Object.entries(rows)) {
    const todo = cases.filter(r=>!ledger.attempts.has(r.id));
    if (todo.length) await one(todo.shift());
    let next=0;
    await Promise.all(Array.from({length:4},async()=>{while (!stopped && next<todo.length) await one(todo[next++]);}));
    const partial=report();
    console.log(group, JSON.stringify(partial.groups[group]));
    if (stopped) break;
  }
} finally {
  report();
  if (service) await service.close();
  ledger.close();
}
if (stopped) process.exitCode=2;
