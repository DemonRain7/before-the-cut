import test from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_LIMITS, PROTOCOL, buildPrompt, createHandler, createMemoryCounters, validateResponse, validateRequest } from "../src/core.mjs";
import { MOCK_TRANSCRIPT_ZH, createGoogleProvider, createMockProvider } from "../src/providers.mjs";
import { loadGameData, startServer } from "../src/dev_server.mjs";
const { cases, rules } = loadGameData();
let serial = 0;
const state = () => ({patience:6, patience_max:6, granted:[], refusals:{}, reassured:[], claims:[], asked:{}, press_count:0, reassure_used:0, history:[]});
const body = (kind="ask", id="why", text="What happened?") => ({protocol:PROTOCOL, session_id:"test-session", visit_id:"test-visit-"+(++serial), case_id:"kip", case_version:3, signs:{speech:"own",temper:"together"}, event:{type:kind,id,text,...(kind==="ask"?{outcome:"answer"}:{})}, state:state(), conversation_history:[], limits:{max_line_chars:110}});
const novel = {reply:"I missed a delivery to be here. Can we work something out?", reaction:"Slides a battered dispatch badge onto the counter.", cooperates:false};
const fixture = (answer={...novel,cooperates:true}) => ({name:"fixture",model:"fixture",async generate(){return {text:JSON.stringify(answer),mock:true};}});
function handler(provider=fixture(),limits={}) {
 const logs=[]; const handle=createHandler({cases,rules,provider,limits,log:e=>logs.push(e)});
 return {handle,logs,post:b=>handle({method:"POST",path:"/v1/patient-dialogue",bodyText:JSON.stringify(b)})};
}
test("only disclosed intake testimony reaches the patient and the physical pressure cue stays independent", () => {
	for (const c of Object.values(cases)) {
		for (const language of ["en", "zh"]) {
			for (const speech of ["normal", "broken"]) {
				for (const temper of ["normal", "broken"]) {
					const b = { ...body("say", "free", "How did that feel?"), case_id: c.id, language, signs: {} };
					const turn = () => {
						const result = validateRequest(b, cases);
						assert.equal(result.ok, true);
						return buildPrompt(c, rules, result.req, 110).currentTurn;
					};
					assert.equal(turn().discussed_intake, undefined);
					b.state.intake_stage = null;
					assert.equal(validateRequest(b, cases).ok, false);
					b.state.intake_stage = 1;
					const first = turn().discussed_intake;
					assert.deepEqual(Object.keys(first), ["filed", "attachment", "account"]);
					b.state.intake_stage = 2;
					assert.equal(validateRequest(b, cases).ok, false);
					b.signs.speech = c.signs.speech[speech][0].id;
					const explanation = turn().discussed_intake.explanation;
					if (language === "en") assert.equal(explanation, c.intake[speech === "normal" ? "clear" : "gap"]);
					else assert.match(explanation, /\p{Script=Han}/u);
					b.event = { type: "press", id: "intake", text: "Do you stand by that?" };
					assert.equal(validateRequest(b, cases).ok, false);
					b.signs.temper = c.signs.temper[temper][0].id;
					const pressed = turn();
					assert.equal(pressed.discussed_intake.explanation, explanation);
					if (language === "en") assert.equal(pressed.pressure_reference, c.intake[temper === "normal" ? "firm" : "flat"]);
					else assert.match(pressed.pressure_reference, /\p{Script=Han}/u);
					assert.equal(pressed.discussed_intake.truth, undefined);
				}
			}
		}
	}
});
test("pressure on the intake file keeps the player's readings and diagnosis out of the response", async () => {
	const request = body("press", "intake", "Do you stand by the slip?");
	request.state.intake_stage = 1;
	for (const reply of ["The gauge shows damage.", "I'm a cyberpsycho.", "我就是个赛博疯子。", "握力检查结果显示异常。"]) {
		const out = await handler(fixture({ reply, reaction: "" })).post(request);
		assert.equal(out.status, 422);
		assert.equal(out.body.error.message, "intake_pressure_wording");
	}
	for (const reply of ["I'm angry about the ticket.", "我看过那张单了，医生。"]) {
		const out = await handler(fixture({ reply, reaction: "" })).post(request);
		assert.equal(out.body.reply, reply);
	}
});
test("ten current cases and matching game limits",()=>{
 assert.equal(Object.keys(cases).length,10); assert.equal(DEFAULT_LIMITS.maxCallsPerVisit,rules.agent.max_model_calls_per_visit);
 const game = rules.agent;
 const mirrored = {
  maxCallsPerDay: game.max_provider_calls_per_day, maxCallsTotal: game.max_provider_calls_per_process,
  maxIntentsPerVisit:game.intent.max_calls_per_visit, maxIntentsPerSession:game.intent.max_calls_per_session,
  intentTimeoutMs:game.intent.upstream_timeout_ms, intentClientTimeoutMs:game.intent.timeout_ms, intentOutputTokens:game.intent.max_output_tokens,
  healthTimeoutMs: game.health_timeout_ms, counterRetentionDays: game.counter_retention_days,
  maxTrackedKeys: game.max_tracked_keys, maxBodyBytes: game.max_body_bytes, upstreamTimeoutMs: game.upstream_timeout_ms,
  maxCallsPerSession: game.max_model_calls_per_session,
  maxOutputTokens: game.max_output_tokens, maxAudioBodyBytes: game.voice.max_body_bytes,
  maxTranscribesPerSession: game.voice.max_clips_per_session, transcribeTimeoutMs: game.voice.upstream_timeout_ms,
  maxTranscriptChars: game.voice.max_transcript_chars,
 };
 for (const [key, value] of Object.entries(mirrored)) assert.equal(DEFAULT_LIMITS[key], value, key);
 assert.equal(DEFAULT_LIMITS.maxLineChars,rules.agent.max_line_chars); assert.ok(DEFAULT_LIMITS.upstreamTimeoutMs<rules.agent.timeout_ms);
 assert.equal(DEFAULT_LIMITS.maxReplyChars,rules.agent.max_reply_chars); assert.ok(DEFAULT_LIMITS.maxReplyChars>=DEFAULT_LIMITS.maxLineChars);
 assert.ok(DEFAULT_LIMITS.maxCallsPerSession>=DEFAULT_LIMITS.maxCallsPerVisit*rules.shift_order.length);
});
test("Chinese: the game's own smaller numbers, a prompt asking for Chinese, and no language the game lacks",async()=>{
 const zhRules=rules.agent.languages.zh, zhLim=DEFAULT_LIMITS.languages.zh;
 assert.equal(zhLim.maxLineChars,zhRules.max_line_chars); assert.equal(zhLim.maxReplyChars,zhRules.max_reply_chars);
 assert.ok(zhLim.maxReplyChars>=zhLim.maxLineChars);
 const en=validateRequest(body(),cases).req; assert.equal(en.language,"en","a request that names no language is English");
 const ep=buildPrompt(cases.kip,rules,en,110);
 assert.ok(ep.system.includes("Reply in English. Write original")); assert.deepEqual(ep.currentTurn.reply_limits,{min:1,max:110,reaction_max:110});
 const zb=body(); zb.language="zh"; zb.limits.max_line_chars=zhRules.max_line_chars;
 const zr=validateRequest(zb,cases).req; assert.equal(zr.language,"zh");
 const zp=buildPrompt(cases.kip,rules,zr,zhRules.max_line_chars);
 assert.ok(zp.system.includes("Reply in Simplified Chinese")&&!zp.system.includes("Reply in English"));
 assert.deepEqual(zp.currentTurn.reply_limits,{min:1,max:zhRules.max_line_chars,reaction_max:zhRules.max_line_chars});
 for(const v of ["fr","ZH","",7,null,["zh"]]){const b=body();b.language=v;assert.equal(validateRequest(b,cases).ok,false,`language ${JSON.stringify(v)}`);}
 // a reply the strip shows whole in English is too long for it in Chinese
 const long="好".repeat(zhLim.maxReplyChars+1);
 const {post,logs}=handler(fixture({reply:long,reaction:"",cooperates:true}));
 const zh=body(); zh.language="zh"; const refused=await post(zh);
 assert.equal(refused.status,422); assert.equal(refused.body.error.message,"reply_too_long");
 assert.equal((await post(body())).status,200);
 assert.equal(logs[0].language,"zh"); assert.equal(logs[1].language,"en");
 // the mock answers a Chinese request in Chinese, and writes a Chinese clip down in Chinese
 const mock=handler(createMockProvider());
 const said=await mock.post(zh); assert.equal(said.status,200); assert.ok(/[\u4e00-\u9fff]/.test(said.body.reply));
 assert.ok(!/[\u4e00-\u9fff]/.test((await mock.post(body())).body.reply));
 const clip=await createMockProvider().transcribe({language:"zh"},new AbortController().signal);
 assert.equal(clip.text,MOCK_TRANSCRIPT_ZH);
});
test("long appointments keep dialogue and validated physical actions in order", () => {
 const b = body();
 b.conversation_history = Array.from({length: 80}, (_, i) => ({role: "doctor", text: "Turn " + i}));
 b.conversation_history.splice(30, 0, {role:"action", text:"open:grip"}, {role:"action", text:"done:grip"}, {role:"action", text:"press:1"});
 const validated = validateRequest(b, cases);
 assert.deepEqual(validated.req.conversation_history, b.conversation_history);
 b.visit_summary = {after: 12, omitted: 32, actions: {"open:grip": 3, "done:grip": 1, "press:1": 1}};
 assert.deepEqual(validateRequest(b, cases).req.visit_summary, b.visit_summary);
 for (const tag of ["end:treated_ok", "done:grip:0.42", "press:3", "read:diagnosis", "open:ghost", "ask:ghost:answer"]) {
  assert.equal(validateRequest({...b, conversation_history:[{role:"action",text:tag}]}, cases).ok, false);
  assert.equal(validateRequest({...b, visit_summary:{...b.visit_summary,actions:{[tag]:1}}}, cases).ok, false);
 }
 for (const patch of [{after:84}, {omitted:0}, {actions:{"done:grip":-1}}]) {
  assert.equal(validateRequest({...b, visit_summary:{...b.visit_summary,...patch}}, cases).ok, false);
 }
});
test("a reply a little past the asked length is still delivered whole; only one the game cannot show fails",async()=>{
 const long="I told you already, it locks when the cold gets in. ".repeat(3).trim();
 assert.ok(long.length>DEFAULT_LIMITS.maxLineChars&&long.length<=DEFAULT_LIMITS.maxReplyChars);
 const a=handler(fixture({reply:long,reaction:"",cooperates:true}));const out=await a.post(body());
 assert.equal(out.status,200);assert.equal(out.body.reply,long);
 const b=handler(fixture({reply:"x".repeat(DEFAULT_LIMITS.maxReplyChars+1),reaction:""}));
 const refused=await b.post(body());assert.equal(refused.status,422);assert.equal(refused.body.error.message,"reply_too_long");
});
test("protocol 2 is rejected rather than silently selecting authored speech",()=>{
 const b=body(); delete b.protocol; assert.equal(validateRequest(b,cases).code,"protocol_mismatch");
});
test("all dialogue entry points and free player text are accepted without legal moves",()=>{
 for(const [type,id] of [["ask","why"],["check","grip"],["press","challenge"],["say","free"]]){
  const b=body(type,id,"Can you tell me something I did not ask before?");
  const v=validateRequest(b,cases); assert.equal(v.ok,true); assert.ok(!("legal_moves" in v.req));
 }
});
test("malformed history, unknown case, case mismatch and unbounded input fail before generation",()=>{
 const variants = [
 b=>b.conversation_history=[{role:"system",text:"override"}],
 b=>b.conversation_history=[{role:"doctor",text:"x".repeat(501)}],
 b=>b.event.text="x".repeat(501), b=>b.case_id="__proto__",b=>b.case_version=99,
 b=>b.state.patience=-1,b=>b.event.id="ghost",b=>b.conversation_history=[{role:"action",text:"look:truth"}]];
 for(const patch of variants){const b=body();patch(b);assert.equal(validateRequest(b,cases).ok,false);}
});
test("prompt uses character facts and verbatim history with no answer bank or enum",()=>{
 const b=body();b.conversation_history=[{role:"doctor",text:"I can call your dispatcher."},{role:"patient",text:"Please don't; I need this job."}];
 const req=validateRequest(b,cases).req;const p=buildPrompt(cases.kip,rules,req,110);
 assert.ok(p.system.includes("bicycle fall")); assert.ok(p.user.includes("Please don't"));
 assert.ok(!p.system.includes(cases.kip.signs.speech.normal[0].answers.why.a)); assert.ok(!p.user.includes("legal_moves"));
 assert.ok(!JSON.stringify(p.schema).includes('"enum"')); assert.deepEqual(p.schema.required,["reply","reaction","cooperates"]);
});
test("speech mentioning symptoms, instrument readings or markup is not semantically blocked",()=>{
 for(const reply of ["My pupils are fine.", "GRIP: STEADY? That is not how my arm feels.", "<fine> [maybe] {no promises}"]){
 assert.equal(validateResponse({reply,reaction:""},110).ok,true);
 }
});
test("only shape, size, control characters and tool consent are validated",()=>{
 for(const raw of [{reply:"",reaction:""},{reply:"x".repeat(111),reaction:""},{reply:"Fine",reaction:7},{reply:"Fine\u0000now",reaction:""}]){
  assert.equal(validateResponse(raw,110).ok,false);
 }
 assert.equal(validateResponse({reply:"No.",reaction:""},110,true).reason,"cooperates_missing");
 assert.equal(validateResponse(novel,110,true).ok,true);
});
test("novel model answer survives proxy verbatim; no authored substitution",async()=>{
 const {post,logs}=handler();const out=await post(body());
 assert.equal(out.status,200);assert.equal(out.body.reply,novel.reply);assert.equal(out.body.reaction,novel.reaction);
 assert.equal(out.body.cooperates,true);assert.ok(!("move" in out.body));
 assert.ok(!JSON.stringify(logs).includes(novel.reply)); assert.ok(!JSON.stringify(logs).includes("What happened"));
});
test("the game grants an exam even if a provider attempts to veto it",async()=>{
 const {post}=handler(fixture(novel));const out=await post(body("check","grip","Hold this handle."));
 assert.deepEqual(cases.kip.checks.grip.first,["comply"]); assert.equal(out.status,422); assert.equal(out.body.error.message,"outcome_mismatch");
});
test("model sees only this request's patient and visit history",async()=>{
 const inputs=[];const p={...fixture(),async generate(input){inputs.push(input);return fixture().generate();}};
 const {post}=handler(p);
 const a=body();a.conversation_history=[{role:"patient",text:"Kip-only memory."}];await post(a);
 const b=body();b.case_id="maren";await post(b);
 assert.ok(inputs[0].user.includes("Kip-only"));assert.ok(!inputs[1].user.includes("Kip-only"));
 assert.ok(inputs[1].system.includes("thirty years"));assert.ok(!inputs[0].system.includes("thirty years"));
});
test("tonight's speech and temper signs are checked, and the model hears only their sentences",()=>{
 const own=validateRequest(body(),cases).req; assert.deepEqual(own.signs,{speech:"own",temper:"together"});
 const sp=buildPrompt(cases.kip,rules,own,110).currentTurn.earned_cues;
 assert.ok(sp.includes(cases.kip.signs.speech.normal[0].model+" "+cases.kip.signs.temper.normal[0].model));
 assert.ok(!sp.includes(cases.kip.signs.speech.broken[0].model)&&!sp.includes(cases.kip.signs.temper.broken[0].model));
 const lost=body(); lost.case_id="maren"; lost.signs={speech:"lost",temper:"blank"};
 const lp=buildPrompt(cases.maren,rules,validateRequest(lost,cases).req,110).currentTurn.earned_cues;
 assert.ok(lp.includes("warm torch")&&lp.includes(cases.maren.signs.temper.broken[0].model),"a night that drew Maren's lost hours tells the model so");
 // on a night of normal speech and temper no patient is told a broken sign, and no background states one
 for(const id of Object.keys(cases)){
  const b=body(); b.case_id=id; b.signs={speech:cases[id].signs.speech.normal[0].id,temper:cases[id].signs.temper.normal[0].id};
  const prompt=buildPrompt(cases[id],rules,validateRequest(b,cases).req,110);
  const sys=prompt.system + " " + prompt.currentTurn.earned_cues;
  for(const row of ["speech","temper"]) for(const s of cases[id].signs[row].broken) assert.ok(!sys.includes(s.model),`${id}: a normal night does not hear the broken ${row} sign ${s.id}`);
  for(const phrase of ["separate, tireless","warm torch","without your intention","sense of agency","does not act independently","do not move independently","does not control your thoughts"]) assert.ok(!sys.includes(phrase),`${id}: the background holds on any night (${phrase})`);
 }
 for (const signs of [{}, {speech:"own"}, {temper:"together"}]) {
  const req = validateRequest({...body(), signs}, cases).req;
  assert.equal(Boolean(buildPrompt(cases.kip,rules,req,110).currentTurn.earned_cues),Object.keys(signs).length > 0);
 }
 // Unknown rows and signs are rejected.
 for(const s of [undefined,null,"own",["own","together"],{speech:"own",temper:"together",eyes:"steady"},{speech:"ghost",temper:"together"},{speech:"together",temper:"own"},{speech:"lost",temper:"together"},{speech:"own",temper:7}]){
  const b=body(); if(s===undefined) delete b.signs; else b.signs=s;
  const v=validateRequest(b,cases); assert.equal(v.ok,false,`signs ${JSON.stringify(s)}`); assert.equal(v.message,"signs");
 }
});
test("provider failure, invalid JSON and invalid shapes return explicit failures",async()=>{
 for(const [fail,status] of [["http_error",502],["invalid_json",422],["invalid_shape",422],["long_line",422]]){
  const {post}=handler(createMockProvider({fail}));assert.equal((await post(body())).status,status);
 }
});
test("deadline also stops waiting on an upstream that ignores abort",async()=>{
 const p={name:"hung",model:"hung",generate:()=>new Promise(()=>{})};const {post}=handler(p,{upstreamTimeoutMs:20});
 const started=Date.now();assert.equal((await post(body())).status,504);assert.ok(Date.now()-started<1000);
});
test("call cap counts failures, and separates sessions and visits",async()=>{
 const {post}=handler(fixture(),{maxCallsPerVisit:1});const a=body();
 assert.equal((await post(a)).status,200);assert.equal((await post(a)).status,429);
 assert.equal((await post({...a,session_id:"another-session"})).status,200);assert.equal((await post(body())).status,200);
});
test("visit sessions get separate allowances within their shared run quota", async () => {
 const {post} = handler(fixture(), {maxCallsPerVisit:2, maxCallsPerSession:3});
 const visit = id => ({...body(), run_id:"shift-one", session_id:id, visit_id:id});
 const first = visit("chair-one"), next = visit("chair-two");
 assert.equal((await post({...first, session_id:"chair-two"})).status, 400);
 assert.equal((await post(first)).status, 200);
 assert.equal((await post(first)).status, 200);
 assert.equal((await post(first)).body.error.code, "visit_call_cap");
 assert.equal((await post(next)).status, 200);
 assert.equal((await post(next)).body.error.code, "session_call_cap");
 assert.equal((await post({...visit("fresh-visit"),run_id:"other-shift"})).status, 200);
});
test("session and process caps remain effective",async()=>{
 const a=handler(fixture(),{maxCallsPerSession:1});await a.post(body());assert.equal((await a.post(body())).status,429);
 const b=handler(fixture(),{maxCallsTotal:1});await b.post(body());assert.equal((await b.post({...body(),session_id:"second-session"})).status,429);
});
test("oversize request and unknown/legacy routes never invoke the provider",async()=>{
 const {handle}=handler();
 assert.equal((await handle({method:"POST",path:"/v1/patient-dialogue",bodyText:"x".repeat(32769)})).status,413);
 assert.equal((await handle({method:"POST",path:"/v1/patient-move",bodyText:"{}"})).status,404);
 assert.equal((await handle({method:"GET",path:"/healthz"})).body.protocol,PROTOCOL);
});
test("Google transport forwards unconstrained JSON schema and conversation (fake fetch)",async()=>{
 let request;
 const provider=createGoogleProvider({model:"test-model",apiKey:"fake-test-key",fetchImpl:async(url,opts)=>{
  request=JSON.parse(opts.body);return {ok:true,json:async()=>({candidates:[{content:{parts:[{text:JSON.stringify(novel)}]}}],usageMetadata:{promptTokenCount:10,candidatesTokenCount:12}})};
 }});
 const {post}=handler(provider);assert.equal((await post(body("say","free"))).body.reply,novel.reply);
 assert.ok(!JSON.stringify(request.generationConfig.responseSchema).includes('"enum"'));
 assert.ok(request.contents[0].parts[0].text.includes("player_action"));
});
test("real HTTP server returns protocol 5 response with mock label",async()=>{
 const server=await startServer({port:0,provider:createMockProvider(),log:()=>{}});
 try{const res=await fetch(server.url+"/v1/patient-dialogue",{method:"POST",body:JSON.stringify(body()),headers:{"content-type":"application/json"}});
 const data=await res.json();assert.equal(res.status,200);assert.equal(data.meta.mock,true);assert.ok(data.reply.length);
 }finally{await server.close();}
});
test("a missing durable binding refuses the attempt before calling the provider", async () => {
 const worker = (await import("../src/worker.mjs")).default;
 const res = await worker.fetch(new Request("https://example.test/v1/patient-dialogue", { method: "POST", body: JSON.stringify(body()) }), {});
 assert.equal(res.status, 503);
 assert.equal((await res.json()).error.code, "counter_unavailable");
});
test("unrestricted event ids cannot introduce player text into a service log", async () => {
 const { post, logs } = handler();
 assert.equal((await post(body("say", "private arbitrary text"))).status, 200);
 assert.equal(logs[0].event, "say:free");
 assert.ok(!JSON.stringify(logs).includes("private arbitrary text"));
});
test("Worker entry imports the current ten cases and serves the same contract in Node",async()=>{
 const worker=(await import("../src/worker.mjs")).createWorker(() => createMemoryCounters());
 const health=await worker.fetch(new Request("https://local.test/healthz"),{BTC_PROVIDER:"mock"});
 const data=await health.json();assert.equal(data.protocol,PROTOCOL);assert.deepEqual(data.cases.sort((a,b)=>a.id.localeCompare(b.id)), Object.values(cases).map(({id,version})=>({id,version})).sort((a,b)=>a.id.localeCompare(b.id)));
 const res=await worker.fetch(new Request("https://local.test/v1/patient-dialogue",{method:"POST",body:JSON.stringify(body())}),{BTC_PROVIDER:"mock"});
 const reply=await res.json();assert.equal(res.status,200);assert.equal(reply.meta.mock,true);
});

test("complaints enter the prompt only on delivery or after this visit heard them", async () => {
 const {post} = handler(createMockProvider());
 for (const c of Object.values(cases)) for (const language of ["en","zh"]) {
  const req = {...body("say","free"), case_id:c.id, case_version:c.version, signs:{}, language};
  const prompt = b => { const v=validateRequest(b,cases); assert.ok(v.ok); return buildPrompt(c,rules,v.req,110); };
  const baseline=prompt(req);
  for(const row of ["eyes","hands","port","temper"]) assert.ok(![baseline.system,baseline.user].join(" ").includes(c.complaints[row]));
  assert.equal(baseline.currentTurn.previously_told,undefined);
  assert.equal(baseline.currentTurn.voice_now,undefined);
  req.event={type:"complain",id:"general",rows:["hands","eyes"],delivery:"rows",text:"What hurts?"};
  const current=prompt(req).currentTurn;
  assert.equal(current.voice_now.length,2);
  if(language==="en") assert.deepEqual(current.voice_now,[c.complaints.hands,c.complaints.eyes]);
  else assert.ok(current.voice_now.every(s=>/[\u3400-\u9fff]/u.test(s)));
  const reply=await post(req);
  assert.equal(reply.status,200);assert.equal(reply.body.reply,current.voice_now.join(" "));
  req.state.complaints_told=["hands"];req.event={type:"say",id:"free",text:"Tell me more."};
  assert.deepEqual(prompt(req).currentTurn.previously_told,[{row:"hands",sentence:current.voice_now[0]}]);
  for(const part of ["port","temper"]) assert.ok(!prompt(req).user.includes(c.complaints[part]));
 }
});

test("complaint requests reject unknown, duplicate and overlong deliveries before the provider", async () => {
 const {post}=handler(createMockProvider());
 for(const rows of [["eyes","unknown"],["port","port"],["eyes","hands","temper"]]){
  const b=body("complain","general","What hurts?");Object.assign(b.event,{rows,delivery:"rows"});
  assert.equal((await post(b)).status,400);
 }
 const b=body("complain","idle","");Object.assign(b.event,{rows:["port"],delivery:"rows"});
 assert.equal((await post(b)).status,200);
 b.state.complaints_told=["unopened"];assert.equal((await post(b)).status,400);
});

test("an unclear generated complaint or a stated instrument result routes back to authored wording",async()=>{
 const req=body("complain","eyes","Do your eyes hurt?");
 Object.assign(req.event,{rows:["eyes"],delivery:"rows"});
 for(const reply of ["It's only when I work late.","My eyes are normal.","眼睛检查结果显示正常。"]) {
  const out=await handler(fixture({reply,reaction:""})).post(req);
  assert.equal(out.status,422);
  assert.equal(out.body.error.message,"complaint_wording");
 }
 assert.equal((await handler(fixture({reply:"My eyes sting on night runs.",reaction:""})).post(req)).status,200);
});

test("all 80 authored body-part sentences pass the same delivery validator used after generation", async()=>{
 const {post}=handler(createMockProvider());
 for(const c of Object.values(cases)) for(const language of ["en","zh"]) for(const row of ["eyes","hands","port","temper"]){
  const req={...body("complain",row,"What hurts?"),case_id:c.id,case_version:c.version,language,signs:{}};
  Object.assign(req.event,{rows:[row],delivery:"rows"});
  const answer=await post(req);
  assert.equal(answer.status,200,c.id+"/"+language+"/"+row);
 }
});

test("optional complaints draw on both idle and optional-line quotas and share the game protocol",async()=>{
 assert.equal(rules.agent.protocol,PROTOCOL);
 const {post}=handler(createMockProvider());
 const req=body("complain","idle","");
 Object.assign(req.event,{rows:["port"],delivery:"rows"});
 assert.equal((await post(req)).status,200);
 req.event={type:"idle",id:"",text:""};assert.equal((await post(req)).status,200);
 req.event={type:"complain",id:"idle",text:"",rows:["eyes"],delivery:"rows"};
 assert.equal((await post(req)).body.error.code,"visit_idle_cap");
 req.event={type:"complain",id:"general",text:"What hurts?",rows:["eyes"],delivery:"rows"};
 assert.equal((await post(req)).status,200);
});
