import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { openLedger } from "./ledger.mjs";
import { makeSets } from "./sets.mjs";

test("synthetic matrix is balanced and keeps truth outside provider requests", () => {
  const s = makeSets();
  for (const [key, count] of Object.entries({E1:400,E2:204,E3:120,E4:174})) {
    assert.equal(s[key].length,count);
    assert.equal(s[key].filter(r=>r.language==="zh").length,count/2);
    for (const row of s[key]) assert.equal("truth" in row.request,false);
  }
  assert.equal(s.E2.filter(r=>r.sample).length,40);
  assert.equal(s.E3.filter(r=>r.opened).length,60);
  assert.equal(s.E4.filter(r=>r.tone==="rude").length,58);
});
test("reservations survive restart and refuse concurrent writers, over-budget work and duplicate calls", t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(),"btc-eval-"));
  t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
  const input={system:"a",user:"b",schema:{},maxOutputTokens:32};
  let l = openLedger(dir,true);
  assert.throws(()=>openLedger(dir,true));
  assert.throws(()=>l.reserve("E4-000",{...input,maxOutputTokens:1e8}));
  l.reserve("E1-000",input);
  const bound=l.bound;
  l.close();
  l=openLedger(dir,true);
  assert.equal(l.counts.E1,1);
  assert.equal(l.bound,bound);
  assert.throws(()=>l.reserve("E1-000",input));
  assert.throws(()=>l.reserve("voice-000",input));
  assert.throws(()=>l.wrap({name:"mock",model:"mock"}));
  l.close();
});
