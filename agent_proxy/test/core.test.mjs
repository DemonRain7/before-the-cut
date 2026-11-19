import test from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_LIMITS, PROTOCOL, buildPrompt, createHandler, validateResponse, validateRequest } from "../src/core.mjs";
import { MOCK_TRANSCRIPT_ZH, createGoogleProvider, createMockProvider } from "../src/providers.mjs";
import { loadGameData, startServer } from "../src/dev_server.mjs";
const { cases, rules } = loadGameData();
let serial = 0;
const state = () => ({patience:6, patience_max:6, granted:[], refusals:{}, reassured:[], claims:[], asked:{}, press_count:0, reassure_used:0, history:[]});
const body = (kind="ask", id="why", text="What happened?") => ({protocol:PROTOCOL, session_id:"test-session", visit_id:"test-visit-"+(++serial), case_id:"kip", case_version:3, signs:{speech:"own",temper:"together"}, event:{type:kind,id,text}, state:state(), conversation_history:[], limits:{max_line_chars:110}});
const novel = {reply:"I missed a delivery to be here. Can we work something out?", reaction:"Slides a battered dispatch badge onto the counter.", cooperates:false};
const fixture = (answer=novel) => ({name:"fixture",model:"fixture",async generate(){return {text:JSON.stringify(answer),mock:true};}});
function handler(provider=fixture(),limits={}) {
 const logs=[]; const handle=createHandler({cases,rules,provider,limits,log:e=>logs.push(e)});
 return {handle,logs,post:b=>handle({method:"POST",path:"/v1/patient-dialogue",bodyText:JSON.stringify(b)})};
}
test("ten current cases and matching game limits",()=>{
 assert.equal(Object.keys(cases).length,10); assert.equal(DEFAULT_LIMITS.maxCallsPerVisit,rules.agent.max_model_calls_per_visit);
 assert.equal(DEFAULT_LIMITS.maxLineChars,rules.agent.max_line_chars); assert.ok(DEFAULT_LIMITS.upstreamTimeoutMs<rules.agent.timeout_ms);
 assert.equal(DEFAULT_LIMITS.maxReplyChars,rules.agent.max_reply_chars); assert.ok(DEFAULT_LIMITS.maxReplyChars>=DEFAULT_LIMITS.maxLineChars);
 assert.ok(DEFAULT_LIMITS.maxCallsPerSession>=DEFAULT_LIMITS.maxCallsPerVisit*rules.shift_order.length);
});
test("Chinese: the game's own smaller numbers, a prompt asking for Chinese, and no language the game lacks",async()=>{
 const zhRules=rules.agent.languages.zh, zhLim=DEFAULT_LIMITS.languages.zh;
 assert.equal(zhLim.maxLineChars,zhRules.max_line_chars); assert.equal(zhLim.maxReplyChars,zhRules.max_reply_chars);
 assert.ok(zhLim.maxReplyChars>=zhLim.maxLineChars);
 const en=validateRequest(body(),cases).req; assert.equal(en.language,"en","a request that names no language is English");
 const ep=buildPrompt(cases.kip,rules,en,110).system;
 assert.ok(ep.includes("Reply in English. Write original")&&ep.includes("reply: 1-110 characters; reaction: 0-110 characters"));
 const zb=body(); zb.language="zh"; zb.limits.max_line_chars=zhRules.max_line_chars;
 const zr=validateRequest(zb,cases).req; assert.equal(zr.language,"zh");
 const zp=buildPrompt(cases.kip,rules,zr,zhRules.max_line_chars).system;
 assert.ok(zp.includes("Reply in Simplified Chinese")&&!zp.includes("Reply in English"));
 assert.ok(zp.includes(`reply: 1-${zhRules.max_line_chars} characters; reaction: 0-${zhRules.max_line_chars} characters`));
 for(const v of ["fr","ZH","",7,null,["zh"]]){const b=body();b.language=v;assert.equal(validateRequest(b,cases).ok,false,`language ${JSON.stringify(v)}`);}
 // a reply the strip shows whole in English is too long for it in Chinese
 const long="好".repeat(zhLim.maxReplyChars+1);
 const {post,logs}=handler(fixture({reply:long,reaction:""}));
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
test("a whole visit of conversation fits: history up to the cap is accepted, one more turn is not",()=>{
 const full=body();full.conversation_history=new Array(DEFAULT_LIMITS.maxHistoryTurns).fill({role:"patient",text:"Hi"});
 assert.equal(validateRequest(full,cases).ok,true);
 const over=body();over.conversation_history=new Array(DEFAULT_LIMITS.maxHistoryTurns+1).fill({role:"patient",text:"Hi"});
 assert.equal(validateRequest(over,cases).ok,false);
});
test("a reply a little past the asked length is still delivered whole; only one the game cannot show fails",async()=>{
 const long="I told you already, it locks when the cold gets in. ".repeat(3).trim();
 assert.ok(long.length>DEFAULT_LIMITS.maxLineChars&&long.length<=DEFAULT_LIMITS.maxReplyChars);
 const a=handler(fixture({reply:long,reaction:""}));const out=await a.post(body());
 assert.equal(out.status,200);assert.equal(out.body.reply,long);
 const b=handler(fixture({reply:"x".repeat(DEFAULT_LIMITS.maxReplyChars+1),reaction:""}));
 const refused=await b.post(body());assert.equal(refused.status,422);assert.equal(refused.body.error.message,"reply_too_long");
});
test("protocol 2 is rejected rather than silently selecting authored speech",()=>{
 const b=body(); delete b.protocol; assert.equal(validateRequest(b,cases).code,"protocol_mismatch");
});
test("all dialogue entry points and free player text are accepted without legal moves",()=>{
 for(const [type,id] of [["ask","why"],["check","grip"],["press","challenge"],["reassure","calm"],["say","free"]]){
  const b=body(type,id,"Can you tell me something I did not ask before?");
  const v=validateRequest(b,cases); assert.equal(v.ok,true); assert.ok(!("legal_moves" in v.req));
 }
});
test("malformed history, unknown case, case mismatch and unbounded input fail before generation",()=>{
 const variants = [
 b=>b.conversation_history=[{role:"system",text:"override"}],
 b=>b.conversation_history=[{role:"doctor",text:"x".repeat(501)}],
 b=>b.event.text="x".repeat(501), b=>b.case_id="__proto__",b=>b.case_version=99,
 b=>b.state.patience=-1,b=>b.event.id="ghost",b=>b.conversation_history=new Array(49).fill({role:"patient",text:"Hi"})];
 for(const patch of variants){const b=body();patch(b);assert.equal(validateRequest(b,cases).ok,false);}
});
test("prompt uses character facts and verbatim history with no answer bank or enum",()=>{
 const b=body();b.conversation_history=[{role:"doctor",text:"I can call your dispatcher."},{role:"patient",text:"Please don't; I need this job."}];
 const req=validateRequest(b,cases).req;const p=buildPrompt(cases.kip,rules,req,110);
 assert.ok(p.system.includes("bicycle fall")); assert.ok(p.user.includes("Please don't"));
 assert.ok(!p.system.includes(cases.kip.signs.speech.normal[0].answers.why.a)); assert.ok(!p.user.includes("legal_moves"));
 assert.ok(!JSON.stringify(p.schema).includes('"enum"')); assert.deepEqual(p.schema.required,["reply","reaction"]);
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
 assert.equal(out.body.cooperates,false);assert.ok(!("move" in out.body));
 assert.ok(!JSON.stringify(logs).includes(novel.reply)); assert.ok(!JSON.stringify(logs).includes("What happened"));
});
test("AI can refuse an exam even if the authored case only permits comply",async()=>{
 const {post}=handler();const out=await post(body("check","grip","Hold this handle."));
 assert.deepEqual(cases.kip.checks.grip.first,["comply"]); assert.equal(out.body.cooperates,false);
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
 const sp=buildPrompt(cases.kip,rules,own,110).system;
 assert.ok(sp.includes("Tonight: "+cases.kip.signs.speech.normal[0].model+" "+cases.kip.signs.temper.normal[0].model));
 assert.ok(!sp.includes(cases.kip.signs.speech.broken[0].model)&&!sp.includes(cases.kip.signs.temper.broken[0].model));
 const lost=body(); lost.case_id="maren"; lost.signs={speech:"lost",temper:"blank"};
 const lp=buildPrompt(cases.maren,rules,validateRequest(lost,cases).req,110).system;
 assert.ok(lp.includes("warm torch")&&lp.includes(cases.maren.signs.temper.broken[0].model),"a night that drew Maren's lost hours tells the model so");
 // on a night of normal speech and temper no patient is told a broken sign, and no background states one
 for(const id of Object.keys(cases)){
  const b=body(); b.case_id=id; b.signs={speech:cases[id].signs.speech.normal[0].id,temper:cases[id].signs.temper.normal[0].id};
  const sys=buildPrompt(cases[id],rules,validateRequest(b,cases).req,110).system;
  for(const row of ["speech","temper"]) for(const s of cases[id].signs[row].broken) assert.ok(!sys.includes(s.model),`${id}: a normal night does not hear the broken ${row} sign ${s.id}`);
  for(const phrase of ["separate, tireless","warm torch","without your intention","sense of agency","does not act independently","do not move independently","does not control your thoughts"]) assert.ok(!sys.includes(phrase),`${id}: the background holds on any night (${phrase})`);
 }
 // signs are required, exactly these two rows, each a sign of this patient's own rows
 for(const s of [undefined,null,"own",["own","together"],{speech:"own"},{speech:"own",temper:"together",eyes:"steady"},{speech:"ghost",temper:"together"},{speech:"together",temper:"own"},{speech:"lost",temper:"together"},{speech:"own",temper:7}]){
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
test("session and process caps remain effective",async()=>{
 const a=handler(fixture(),{maxCallsPerSession:1});await a.post(body());assert.equal((await a.post(body())).status,429);
 const b=handler(fixture(),{maxCallsTotal:1});await b.post(body());assert.equal((await b.post({...body(),session_id:"second-session"})).status,429);
});
test("oversize request and unknown/legacy routes never invoke the provider",async()=>{
 const {handle}=handler();
 assert.equal((await handle({method:"POST",path:"/v1/patient-dialogue",bodyText:"x".repeat(32769)})).status,413);
 assert.equal((await handle({method:"POST",path:"/v1/patient-move",bodyText:"{}"})).status,404);
 assert.equal((await handle({method:"GET",path:"/healthz"})).body.protocol,"3");
});
test("Google transport forwards unconstrained JSON schema and conversation (fake fetch)",async()=>{
 let request;
 const provider=createGoogleProvider({model:"test-model",apiKey:"fake-test-key",fetchImpl:async(url,opts)=>{
  request=JSON.parse(opts.body);return {ok:true,json:async()=>({candidates:[{content:{parts:[{text:JSON.stringify(novel)}]}}],usageMetadata:{promptTokenCount:10,candidatesTokenCount:12}})};
 }});
 const {post}=handler(provider);assert.equal((await post(body())).body.reply,novel.reply);
 assert.ok(!JSON.stringify(request.generationConfig.responseSchema).includes('"enum"'));
 assert.ok(request.contents[0].parts[0].text.includes("player_action"));
});
test("real HTTP server returns protocol 3 response with mock label",async()=>{
 const server=await startServer({port:0,provider:createMockProvider(),log:()=>{}});
 try{const res=await fetch(server.url+"/v1/patient-dialogue",{method:"POST",body:JSON.stringify(body()),headers:{"content-type":"application/json"}});
 const data=await res.json();assert.equal(res.status,200);assert.equal(data.meta.mock,true);assert.ok(data.reply.length);
 }finally{await server.close();}
});
test("Worker entry imports the current ten cases and serves the same contract in Node",async()=>{
 const worker=(await import("../src/worker.mjs")).default;
 const health=await worker.fetch(new Request("https://local.test/healthz"),{BTC_PROVIDER:"mock"});
 const data=await health.json();assert.equal(data.protocol,"3");assert.equal(data.cases.length,10);
 const res=await worker.fetch(new Request("https://local.test/v1/patient-dialogue",{method:"POST",body:JSON.stringify(body())}),{BTC_PROVIDER:"mock"});
 const reply=await res.json();assert.equal(res.status,200);assert.equal(reply.meta.mock,true);
});
