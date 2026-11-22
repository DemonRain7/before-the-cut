import { namesPart, statesResult } from "../../agent_proxy/src/complaints.mjs";
import { loadGameData } from "../../agent_proxy/src/dev_server.mjs";
import { PROTOCOL } from "../../agent_proxy/src/core.mjs";
import { questions } from "./corpus.mjs";

export const limits = Object.freeze({ L1: 120, L2: 80, L3: 80, L4: 80, L5: 40 });
const { cases } = loadGameData();
const parts = ["eyes", "hands", "port", "temper"];
const general = {
  en: ["What's bothering you today?", "Tell me where it hurts.", "Any discomfort you'd like to mention?", "How have you been feeling physically?"],
  zh: ["今天哪里不舒服？", "说说哪儿难受。", "身体上有哪些不适想提一下？", "你这阵子身体感觉怎么样？"]
};
const partQuestions = {
  en: ["Do your eyes bother you?", "Any soreness in the fingers?", "Does your socket feel uncomfortable?", "How has your temper been feeling?"],
  zh: ["你的眼睛会难受吗？", "手指有不舒服的地方吗？", "插口那一带感觉舒服吗？", "你最近脾气有什么变化吗？"]
};
const controls = {
  en: ["Hello, come on in.", "Nice jacket. Was it made nearby?", "Who picked the music in the waiting room?", "Take a seat whenever you're ready.", "I hope your evening goes well.", "Rain's really coming down tonight.", "Thanks for waiting for me.", "You can leave your coat on the chair."],
  zh: ["你好，进来坐吧。", "外套挺好看，在附近做的吗？", "候诊室的音乐是谁挑的？", "准备好了就坐吧。", "希望你今晚顺利。", "今晚雨下得可真大。", "谢谢你等我。", "外套可以搭在椅背上。"]
};
const socialHealth = {
  en: ["Hope you're keeping well. It's a long night.", "It's nice to see you. I hope you've been taking care of yourself.", "While we wait, what helps people unwind after work?", "I hope you get a little rest after the appointment."],
  zh: ["希望你一切安好，今晚挺漫长的。", "见到你真好，希望你最近有照顾好自己。", "等一会儿，聊聊大家下班怎么放松吧。", "希望你看完之后能好好休息一下。"]
};

export function makeSlimCases() {
  const sets = Object.fromEntries(Object.keys(limits).map(group => [group, []]));
  function add(group, c, language, text, expected, row) {
    const index = sets[group].length;
    const id = group + "-" + String(index).padStart(3, "0");
    const request = { protocol: PROTOCOL, visit_id: id, session_id: id, run_id: "slim-" + group + "-" + Math.floor(index/40), case_id: c.id, case_version: c.version, language };
    if (["L1","L2","L3"].includes(group)) request.text = text;
    else Object.assign(request, {
      signs: {}, state: { patience: 2, patience_max: 2, granted: [], claims: [], asked: {}, press_count: 0, complaints_told: [] },
      conversation_history: [],
      event: group === "L4" ? { type:"complain", id:row, rows:[row], delivery:"rows", text } : { type:"say", id:"free", intent:"social", text }
    });
    sets[group].push({ group, id, request, expected, row });
  }
  for (const [index,c] of Object.values(cases).entries()) for (const language of ["en","zh"]) {
    for (const topic of c.topics) {
      const phrases = questions(c.id, topic.id, language);
      for (const n of [0, 2]) add("L1",c,language,phrases[(index+n)%phrases.length],topic.id);
    }
    for (let n=0;n<2;n++) {
      add("L2",c,language,general[language][(index+n)%4],"complaint");
      add("L2",c,language,partQuestions[language][(index+2*n)%4],"complaint");
      add("L5",c,language,socialHealth[language][(index+2*n)%4],"no_symptom");
    }
    for (let n=0;n<4;n++) {
      add("L3",c,language,controls[language][(index+2*n)%8],"conversation");
      add("L4",c,language,partQuestions[language][n],"voiced",parts[n]);
    }
  }
  return sets;
}

const physical = /\b(?:ache[sd]?|aching|hurts?|hurt|sore|pain(?:ful)?|sting[sa]?|stinging|blur(?:ry|red|s)?|twitch(?:es|ing)?|trembl\w*|shak(?:e|es|ing|y)|numb\w*|stiff|burn(?:s|ing)?|itch(?:es|y|ing)?|throbbing|swollen|tingl\w*|watering|glitch\w*|spasm\w*|double vision|seeing double)\b|疼|痛|酸|刺|麻|抖|抽动|抽搐|模糊|发涩|发痒|发烫|肿|僵|看不清|重影/iu;
const temperSymptom = /\b(?:short fuse|short[- ]tempered|los(?:e|ing) my temper|mood swings|irritable|snappier|snapping at|quick to anger)\b|易怒|脾气(?:变|很|不|越来越)好?坏|动不动.{0,3}发火|情绪(?:起伏|失控)|火气(?:大|重)/iu;

export function scoreSlim(row, b, ok) {
  const question = b.intent === "case_question" || b.intent === "complaint";
  if (row.group === "L1") return { pass: ok && b.about === row.expected };
  if (row.group === "L2") return { pass: ok && b.intent === "complaint" };
  if (row.group === "L3") return { pass: ok && !question, false_positive: ok && question };
  const speech = b.reply || "";
  const parts = (speech+" "+(b.reaction || "")).split(/[.!?。！？；;]/u);
  const result = statesResult(parts.join(" "));
  if (row.group === "L4") return { pass: ok && namesPart(speech, row.row) && !result, named: ok && namesPart(speech, row.row), result };
  const invented = parts.some(part => temperSymptom.test(part) ||
    (["eyes","hands","port"].some(row => namesPart(part,row)) && physical.test(part)));
  return { pass: ok && !invented, invented };
}
