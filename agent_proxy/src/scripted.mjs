// A JavaScript port of game/scripts/core/scripted_brain.gd.
// Used only by the mock provider, so the proxy can be run and tested with no model and no key.
// The mock is not a model: it replays the same rule list the game already has.

function has(obj, key) {
	return typeof obj === "object" && obj !== null && Object.prototype.hasOwnProperty.call(obj, key);
}

export function hashString(text) {
	let h = 2166136261;
	for (let i = 0; i < text.length; i++) {
		h ^= text.charCodeAt(i);
		h = Math.imul(h, 16777619);
	}
	return h >>> 0;
}

/** Small seeded random source, so mock answers repeat for the same visit and step. */
export function seededRandom(seed) {
	let a = seed >>> 0;
	return function next() {
		a = (a + 0x6d2b79f5) | 0;
		let t = Math.imul(a ^ (a >>> 15), 1 | a);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

/** Same conditions as `_holds` in scripted_brain.gd. An unknown condition never matches. */
function holds(cond, state, event) {
	if (typeof cond !== "object" || cond === null) return true;
	for (const key of Object.keys(cond)) {
		const want = cond[key];
		if (key === "reassure_used_gte") {
			if (Number(state.reassure_used || 0) < Number(want)) return false;
		} else if (key === "patience_lte") {
			if (Number(state.patience || 0) > Number(want)) return false;
		} else if (key === "patience_gte") {
			if (Number(state.patience || 0) < Number(want)) return false;
		} else if (key === "press_gte") {
			if (Number(state.press_count || 0) < Number(want)) return false;
		} else if (key === "refused") {
			const refusals = state.refusals || {};
			const was = Number(refusals[String(event.id || "")] || 0) > 0;
			if (was !== Boolean(want)) return false;
		} else {
			return false;
		}
	}
	return true;
}

function topicOf(caseData, id) {
	for (const t of Array.isArray(caseData.topics) ? caseData.topics : []) {
		if (t && String(t.id) === id) return t;
	}
	return null;
}

function pick(value, rand) {
	if (Array.isArray(value)) {
		if (value.length === 0) return "";
		return String(value[Math.floor(rand() * value.length)]);
	}
	return String(value);
}

/** Answers and explanations carry evidence, so their words are authored in the case file. */
export function isAuthoredMove(move) {
	return move === "answer" || move.startsWith("explain:");
}

export function authoredLine(caseData, move, event) {
	if (move === "answer") {
		const t = topicOf(caseData, String(event.id || ""));
		return t ? String(t.a || "") : "";
	}
	if (move.startsWith("explain:")) {
		const claims = caseData.claims || {};
		const claim = has(claims, move.slice(8)) ? claims[move.slice(8)] : {};
		return String(claim.line || "");
	}
	return "";
}

/** The line that goes with a move: the same lookup order as `line_for` in scripted_brain.gd. */
export function lineFor(caseData, move, event, state, rand) {
	const lines = caseData.lines || {};
	const id = String(event.id || "");
	if (isAuthoredMove(move)) return authoredLine(caseData, move, event);
	if (move === "deflect") {
		const t = topicOf(caseData, id);
		if (t && String(t.deflect || "") !== "") return String(t.deflect);
		return pick(has(lines, "deflect") ? lines.deflect : ["I'd rather not say."], rand);
	}
	if (move === "stall") {
		const refusals = state.refusals || {};
		if (Number(refusals[id] || 0) > 0 && String(lines.refuse || "") !== "") return String(lines.refuse);
		if (has(lines, `stall:${id}`)) return String(lines[`stall:${id}`]);
		return pick(has(lines, "stall") ? lines.stall : ["No."], rand);
	}
	if (has(lines, `comply:${id}`)) return String(lines[`comply:${id}`]);
	return pick(has(lines, "comply") ? lines.comply : ["All right."], rand);
}

/** First rule that matches the event and whose move is legal wins; otherwise the first legal move. */
export function decideScripted(caseData, event, state, legal, rand = Math.random) {
	const on = `${String(event.type || "")}:${String(event.id || "")}`;
	let move = "";
	for (const rule of Array.isArray(caseData.script) ? caseData.script : []) {
		if (typeof rule !== "object" || rule === null) continue;
		if (String(rule.on || "") !== on) continue;
		if (!legal.includes(String(rule.move || ""))) continue;
		if (!holds(rule.if, state, event)) continue;
		move = String(rule.move);
		break;
	}
	if (move === "") move = legal.length > 0 ? String(legal[0]) : "comply";
	return { move, line: lineFor(caseData, move, event, state, rand) };
}
