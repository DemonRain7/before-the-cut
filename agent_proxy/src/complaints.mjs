// Authored bilingual wording. The prompt receives only rows delivered in this appointment.
import bo from "../../game/data/lang/zh/cases/bo.json" with { type: "json" };
import dana from "../../game/data/lang/zh/cases/dana.json" with { type: "json" };
import juno from "../../game/data/lang/zh/cases/juno.json" with { type: "json" };
import kip from "../../game/data/lang/zh/cases/kip.json" with { type: "json" };
import lux from "../../game/data/lang/zh/cases/lux.json" with { type: "json" };
import maren from "../../game/data/lang/zh/cases/maren.json" with { type: "json" };
import ozzie from "../../game/data/lang/zh/cases/ozzie.json" with { type: "json" };
import priya from "../../game/data/lang/zh/cases/priya.json" with { type: "json" };
import rook from "../../game/data/lang/zh/cases/rook.json" with { type: "json" };
import vale from "../../game/data/lang/zh/cases/vale.json" with { type: "json" };
import sheet from "../../game/data/sheet.json" with { type: "json" };
import chineseSheet from "../../game/data/lang/zh/sheet.json" with { type: "json" };

const chinese = { bo, dana, juno, kip, lux, maren, ozzie, priya, rook, vale };
export const rows = Object.freeze(["eyes", "hands", "port", "temper"]);

export function mentionedPart(text) {
	const line = text.toLowerCase();
	const words = line.match(/[a-z]+/g) || [];
	return rows.find(row => sheet.part_words[row].some(term => words.includes(term)) ||
		chineseSheet.part_words[row].some(term => line.includes(term))) || "";
}

export function complaintLine(c, language, row) {
	if (row === "all") return language === "zh" ? "我想说的就这些。" : "That's all I wanted to mention.";
	const sentence = c.complaints[row];
	return language === "zh" ? chinese[c.id].strings[sentence] : sentence;
}

const bodyWords = {
  eyes: /\b(eyes?|eyelids?|pupils?|optics?|sight|vision|lens|lenses|blinking)\b|眼|视[线力野觉]|看东西|瞳|镜片/iu,
  hands: /\b(hands?|fingers?|grip|knuckles?|palms?|wrists?|thumbs?)\b|手|指[尖节头]|掌|握力/iu,
  port: /\b(ports?|sockets?|jacks?|connector|plug[- ]?in)\b|接[口头]|插[口孔槽座]|端口|卡槽/iu,
  temper: /\b(temper|temperamental|mood|fuse|irritable|irritated|irritation|patience|short[- ]tempered|short[- ]fused|edgy|snap|snappy|snapping|anger|angry|testy|cranky|touchy)\b|脾气|情绪|心情|烦躁|火气|火大|易怒|发[火脾]|不耐烦|性子|急躁|心烦|冒火|压不住火/iu
};
const reading = /\b(?:test|gauge|scan|reading|measurement|pupil response|calibration|release time)\s+(?:shows?|proves?|reads?|says?|measures?|is normal|is abnormal|came back)|\b(?:my |the )?(?:eyes?|hands?|grip|port|socket|temper)\s+(?:is|are|tests? as|tested)\s+(?:completely |medically )?(?:normal|abnormal|broken|fine|within range)|\b\d+(?:\.\d+)?\s*(?:ms|milliseconds|seconds)\b|(?:检查|测量|读数|仪器|检测)(?:结果)?(?:显示|表明|证实|正常|异常)|(?:眼睛|瞳孔|握力|手部|接口|脾气)(?:是|都|完全)?(?:正常|异常|坏了|合格|超标)|\d+(?:\.\d+)?\s*(?:毫秒|秒)/iu;
export function namesPart(speech, row) {
  return bodyWords[row].test(speech);
}

export function statesResult(text) {
  return reading.test(text);
}
