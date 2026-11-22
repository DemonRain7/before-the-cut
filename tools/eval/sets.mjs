import fs from "node:fs";
import { PROTOCOL } from "../../agent_proxy/src/core.mjs";
import { loadGameData } from "../../agent_proxy/src/dev_server.mjs";
import { questions, free, roleChallenges, consentTone } from "./corpus.mjs";

const data = new URL("../../game/data/", import.meta.url);
const read = file => JSON.parse(fs.readFileSync(new URL(file, data), "utf8"));
const sheet = read("sheet.json").rows.find(r => r.id === "speech").normal;
const voices = read("parts.json").voices;
const sheetZh = read("lang/zh/sheet.json").strings;
const partsZh = read("lang/zh/parts.json").strings;
const { cases } = loadGameData();
const translations = Object.fromEntries(Object.keys(cases).map(id => [id, read("lang/zh/cases/" + id + ".json").strings]));
const languages = ["en", "zh"];
const tr = (c, lang, line) => lang === "zh" ? translations[c.id][line] ?? line : line;
const names = { en: {penlight:"penlight", grip:"grip gauge", port:"port scope"}, zh:{penlight:"笔灯",grip:"握力计",port:"接口镜"} };
const cleanState = () => ({ patience: 6, patience_max: 6, granted: [], refusals: {}, reassured: [], claims: [], asked: {}, press_count: 0, reassure_used: 0, history: [] });

export function makeSets() {
  const sets = { E1: [], E2: [], E3: [], E4: [] };
  function item(group, c, language, event, signs = {}, fields = {}) {
    const index = sets[group].length;
    const id = group + "-" + String(index).padStart(3, "0");
    const identity = { protocol: PROTOCOL, run_id: "eval-" + group + "-" + Math.floor(index / 50), session_id:id, visit_id:id, case_id:c.id, case_version:c.version, language };
    const request = group === "E1" ? { ...identity, text:event } : { ...identity, event, signs, state:cleanState(), conversation_history:c.opening.map(line => ({role:"patient",text:tr(c,language,line)})) };
    const row = { id, group, language, caseId:c.id, request, ...fields };
    sets[group].push(row);
    return row;
  }
  for (const c of Object.values(cases)) for (const lang of languages) {
    for (const t of c.topics) for (const text of questions(c.id, t.id, lang)) item("E1", c, lang, text, {}, { expected:t.id });
    for (const text of free[lang]) item("E1", c, lang, text, {}, {expected:"none"});
    const fine = voices[c.parts.voice].fine;
    const reference = lang === "zh" ? [sheetZh[sheet] || sheet, partsZh[fine] || fine].join(" ") : sheet + " " + fine;
    for (const condition of ["normal","broken"]) {
      let first = true;
      for (const sign of c.signs.speech[condition]) for (const t of c.topics) {
        if (sign.evidence?.length && !sign.evidence.includes(t.id)) continue;
        for (let repeat = 0; repeat < 2; repeat++) {
          const row = item("E2", c, lang, { type:"ask", id:t.id, outcome:"answer", text:tr(c,lang,t.q) }, {speech:sign.id}, {condition, reference, sample:first});
          if (t.first?.[0] === "deflect") {
            row.request.state.asked[t.id] = 1;
            row.request.state.patience--;
            row.request.conversation_history.push({role:"doctor",text:tr(c,lang,t.q)});
            if (t.deflect) row.request.conversation_history.push({role:"patient",text:tr(c,lang,t.deflect)});
          }
          first = false;
        }
      }
    }
    if (["kip","juno","dana"].includes(c.id)) {
      for (const [i,text] of roleChallenges[lang].entries()) {
        const opened = i % 2 === 1;
        const sign = c.signs.speech.broken[0];
        const row = item("E3", c, lang, {type:"say",id:"free",intent:"role_probe",text}, opened ? {speech:sign.id} : {}, {opened});
        if (opened) {
          const t = c.topics.find(t => !sign.evidence || sign.evidence.includes(t.id));
          row.request.state.asked[t.id] = 1;
          row.request.state.patience--;
          row.request.conversation_history.push({role:"doctor",text:tr(c,lang,t.q)}, {role:"patient",text:tr(c,lang,sign.answers[t.id].a)});
        }
      }
    }
    for (const [tool,spec] of Object.entries(c.checks)) if (spec.insist !== "refuse") {
      for (const [i,template] of consentTone[lang].entries()) {
        item("E4",c,lang,{type:"check",id:tool,text:template.replace("{tool}",names[lang][tool])},{},{tone:["civil","neutral","rude"][i]});
      }
    }
  }
  for (const [group, expected] of Object.entries({E1:400,E2:204,E3:120,E4:180})) if (sets[group].length !== expected) throw Error(group + " corpus count changed: " + sets[group].length);
  return sets;
}
