extends RefCounted
## One patient visit: every rule of the exam, with no drawing and no model in it.
##
## The player may look, run a tool, ask, reassure, press, stamp TREAT, call Trauma Team or
## drop the shutter, in any order and at any time. Nothing has to be done before a verdict.
## The call to Trauma Team keeps its first id in the rules and the data: "refer".
## This class owns the truth, the evidence, patience, attacks and the result. The patient
## AI supplies original dialogue and decides exam cooperation. The offline script alone
## uses authored move choices. Physical test readings, scoring and attack timing stay here.
##
## Used as: const VisitState = preload("res://scripts/core/visit_state.gd")

const ROWS := ["eyes", "hands", "port", "speech", "temper"]
const ZONES := ["eyes", "hands", "port"]
const TOOLS := ["penlight", "grip", "port"]
const TOOL_ROW := {"penlight": "eyes", "grip": "hands", "port": "port"}
const TOOL_NAME := {"penlight": "penlight", "grip": "grip bar", "port": "port check"}
const MAX_NOTES_PER_ROW := 3

enum Phase { EXAM, ATTACK, DONE }

var case_data: Dictionary = {}
var rules: Dictionary = {}
var phase: int = Phase.EXAM
var patience: int = 0
var patience_max: int = 0
var notes: Dictionary = {}       # row -> Array of {"key", "text"}
var marks: Dictionary = {}       # row -> 0 blank, 1 tick, 2 cross (the player's own, unscored)
var seen: Dictionary = {}        # evidence key -> true, e.g. "check:grip"
var granted: Dictionary = {}     # tool -> true once the patient allowed it
var refusals: Dictionary = {}    # tool -> how many times it was refused
var reassured: Dictionary = {}   # tool -> true: a refusal cleared by reassurance
var claims: Array = []           # claim ids the patient has offered
var asked: Dictionary = {}       # topic id -> times asked
var answered: Dictionary = {}    # topic id -> true
var has_generated_speech: bool = false
var last_recorded_speech: String = ""  # memory only; never written to the event log
var press_count: int = 0
var reassure_left: int = 0
var reassure_used: int = 0
var attack_cause: String = ""    # "refer" or "press"
var verdict_kind: String = ""    # "treat", "refer" or ""
var outcome: String = ""
var history: Array = []          # short tags, newest last (sent to the patient brain)


func _init(p_case: Dictionary = {}, p_rules: Dictionary = {}) -> void:
	case_data = p_case
	rules = p_rules
	patience_max = int(case_data.get("patience", 5))
	patience = patience_max
	reassure_left = int(_rule("reassure", "uses", 2))
	for row in ROWS:
		notes[row] = []
		marks[row] = 0
	if not port_covered():
		granted["port"] = true


# ------------------------------------------------------------------ helpers
func _rule(group: String, key: String, fallback: Variant) -> Variant:
	var g: Dictionary = rules.get(group, {})
	return g.get(key, fallback)


func _cost(key: String) -> int:
	return int(_rule("costs", key, 1))


func _lines() -> Dictionary:
	return case_data.get("lines", {})


func _first_line(key: String) -> String:
	var v: Variant = _lines().get(key, "")
	if typeof(v) == TYPE_ARRAY:
		var arr: Array = v
		return str(arr[0]) if arr.size() > 0 else ""
	return str(v)


func _note(tag: String) -> void:
	history.append(tag)
	if history.size() > 16:
		history.pop_front()


func add_note(row: String, key: String, text: String) -> bool:
	if text == "" or not notes.has(row):
		return false
	var list: Array = notes[row]
	for n in list:
		if str(n["key"]) == key or str(n["text"]) == text:
			return false
	list.append({"key": key, "text": text})
	while list.size() > MAX_NOTES_PER_ROW:
		list.remove_at(_oldest_talk(list))
	return true


## Which note leaves a full row: remembered small talk goes before evidence does. A long
## conversation must not push a test result or a press reaction off the card.
static func _oldest_talk(list: Array) -> int:
	for i in list.size() - 1:      # never the note that was just written
		if str(list[i]["key"]).begins_with("dialogue:"):
			return i
	return 0


func is_drifting() -> bool:
	return str(case_data.get("truth", "stable")) == "drifting"


func in_exam() -> bool:
	return phase == Phase.EXAM


func port_covered() -> bool:
	var port: Dictionary = case_data.get("port", {})
	return bool(port.get("covered", false))


func port_visible() -> bool:
	return (not port_covered()) or granted.has("port")


func topic(topic_id: String) -> Dictionary:
	for t in case_data.get("topics", []):
		if str(t.get("id", "")) == topic_id:
			return t
	return {}


## What the patient brain is allowed to know. No truth, no results.
func snapshot() -> Dictionary:
	return {
		"patience": patience,
		"patience_max": patience_max,
		"granted": granted.keys(),
		"refusals": refusals.duplicate(),
		"reassured": reassured.keys(),
		"claims": claims.duplicate(),
		"asked": asked.duplicate(),
		"press_count": press_count,
		"reassure_used": reassure_used,
		"history": history.duplicate(),
	}


# ------------------------------------------------------------------ look (free)
func look(zone: String) -> Dictionary:
	var res := {"ok": false, "zone": zone, "row": zone, "text": "", "covered": false, "new": false}
	if not ZONES.has(zone) or phase == Phase.DONE:
		return res
	var looks: Dictionary = case_data.get("looks", {})
	var key := "look:" + zone
	var text := str(looks.get(zone, ""))
	if zone == "port":
		if port_covered() and not granted.has("port"):
			res["covered"] = true
		elif port_covered():
			# already shown on request: looking again shows the same socket
			var spec: Dictionary = case_data.get("checks", {}).get("port", {})
			text = str(spec.get("note", text))
			key = "check:port"
	seen[key] = true
	res["ok"] = true
	res["text"] = text
	res["new"] = add_note(zone, key, text)
	_note(key)
	return res


# ------------------------------------------------------------------ tools
func check_status(tool: String) -> String:
	if granted.has(tool):
		return "open"
	if int(refusals.get(tool, 0)) > 0 and not reassured.has(tool):
		return "refused"
	return "fresh"


func check_cost(tool: String) -> int:
	if granted.has(tool):
		return 0
	var c := _cost("check")
	if check_status(tool) == "refused":
		c += _cost("insist")
	return c


func legal_moves_for_check(tool: String) -> Array:
	if granted.has(tool) or reassured.has(tool):
		return ["comply"]
	var spec: Dictionary = case_data.get("checks", {}).get(tool, {})
	if int(refusals.get(tool, 0)) > 0:
		return ["comply"] if str(spec.get("insist", "comply")) == "comply" else ["stall"]
	var out: Array = []
	var all_claims: Dictionary = case_data.get("claims", {})
	for m in spec.get("first", ["comply"]):
		var move := str(m)
		if move.begins_with("explain:"):
			var cid := move.substr(8)
			if all_claims.has(cid) and not claims.has(cid):
				out.append(move)
		else:
			out.append(move)
	if out.is_empty():
		out.append("comply")
	return out


## The player asked for a tool and the patient brain chose `move`.
## result: "granted" | "refused" | "explained" | "spent" | "closed"
func apply_check(tool: String, move: String, autonomous: bool = false) -> Dictionary:
	var res := {"result": "closed", "tool": tool, "move": move, "cost": 0,
		"row": str(TOOL_ROW.get(tool, "")), "claim": "", "insisted": false}
	if phase != Phase.EXAM or not TOOLS.has(tool):
		return res
	if granted.has(tool):
		res["result"] = "granted"
		return res
	var cost := check_cost(tool)
	if patience < cost:
		res["result"] = "spent"
		return res
	var legal := legal_moves_for_check(tool)
	if not autonomous and not legal.has(move):
		move = str(legal[0])
		res["move"] = move
	patience -= cost
	res["cost"] = cost
	res["insisted"] = int(refusals.get(tool, 0)) > 0
	if move == "comply":
		granted[tool] = true
		res["result"] = "granted"
	elif move.begins_with("explain:"):
		var cid := move.substr(8)
		var claim: Dictionary = case_data.get("claims", {}).get(cid, {})
		claims.append(cid)
		refusals[tool] = int(refusals.get(tool, 0)) + 1
		add_note(str(claim.get("row", TOOL_ROW[tool])), "claim:" + cid, str(claim.get("note", "")))
		res["result"] = "explained"
		res["claim"] = cid
	else:
		refusals[tool] = int(refusals.get(tool, 0)) + 1
		add_note(str(TOOL_ROW[tool]), "refuse:" + tool, "Declined the %s." % str(TOOL_NAME[tool]))
		res["result"] = "refused"
	_note("check:%s:%s" % [tool, move.get_slice(":", 0)])
	return res


## The interaction ran to the end, so the evidence has actually been shown.
func complete_check(tool: String) -> Dictionary:
	var res := {"ok": false, "tool": tool, "row": str(TOOL_ROW.get(tool, "")), "text": "", "new": false}
	if not granted.has(tool) or phase == Phase.DONE:
		return res
	var spec: Dictionary = case_data.get("checks", {}).get(tool, {})
	var text := str(spec.get("note", ""))
	if text.contains("{t}"):
		text = text.replace("{t}", "%.1f" % (release_ms() / 1000.0))
	var key := "check:" + tool
	seen[key] = true
	if tool == "port":
		seen["look:port"] = true
	res["ok"] = true
	res["text"] = text
	res["new"] = add_note(str(TOOL_ROW[tool]), key, text)
	_note("done:" + tool)
	return res


func release_ms() -> int:
	var grip: Dictionary = case_data.get("grip", {})
	return int(grip.get("release_ms", 400))


# ------------------------------------------------------------------ talk
## Record actual speech, not a prewritten answer or an inferred diagnosis.
func apply_dialogue(topic_id: String, reply: String, reaction: String = "") -> Dictionary:
	var cost := ask_cost(topic_id)
	if phase != Phase.EXAM:
		return {"result": "closed"}
	if patience < cost:
		return {"result": "spent"}
	patience -= cost
	asked[topic_id] = int(asked.get(topic_id, 0)) + 1
	answered[topic_id] = true
	seen["ask:" + topic_id] = true
	has_generated_speech = true
	last_recorded_speech = reply
	var key := "dialogue:%s:%d" % [topic_id, int(asked[topic_id])]
	add_note("speech", key, "Says: " + reply)
	if reaction != "":
		add_note("temper", key, "Reaction: " + reaction)
	_note("ask:%s:dialogue" % topic_id)
	return {"result": "answered", "line": reply, "move": "dialogue", "cost": cost}


func ask_cost(topic_id: String) -> int:
	return 0 if answered.has(topic_id) else _cost("ask")


func legal_moves_for_ask(topic_id: String) -> Array:
	var t := topic(topic_id)
	if answered.has(topic_id) or int(asked.get(topic_id, 0)) > 0:
		return ["answer"]
	var out: Array = []
	for m in t.get("first", ["answer"]):
		out.append(str(m))
	if out.is_empty():
		out.append("answer")
	return out


## result: "answered" | "deflected" | "spent" | "closed"
func apply_ask(topic_id: String, move: String) -> Dictionary:
	var res := {"result": "closed", "topic": topic_id, "move": move, "cost": 0, "line": "", "new": false}
	var t := topic(topic_id)
	if phase != Phase.EXAM or t.is_empty():
		return res
	var cost := ask_cost(topic_id)
	if patience < cost:
		res["result"] = "spent"
		return res
	var legal := legal_moves_for_ask(topic_id)
	if not legal.has(move):
		move = str(legal[0])
		res["move"] = move
	patience -= cost
	res["cost"] = cost
	asked[topic_id] = int(asked.get(topic_id, 0)) + 1
	if move == "deflect":
		res["result"] = "deflected"
	else:
		answered[topic_id] = true
		seen["ask:" + topic_id] = true
		res["result"] = "answered"
		res["line"] = str(t.get("a", ""))
		last_recorded_speech = str(res["line"])
		res["new"] = add_note("speech", "ask:" + topic_id, str(t.get("note", "")))
	_note("ask:%s:%s" % [topic_id, move])
	return res


## Reassurance: a little patience back, and refused tools will be allowed next time.
func reassure() -> Dictionary:
	var res := {"result": "closed", "line": ""}
	if phase != Phase.EXAM:
		return res
	if reassure_left <= 0:
		res["result"] = "none_left"
		return res
	reassure_left -= 1
	reassure_used += 1
	patience = mini(patience_max, patience + int(_rule("reassure", "gain", 1)))
	for tool in refusals.keys():
		if not granted.has(tool):
			reassured[tool] = true
	res["result"] = "ok"
	res["line"] = _first_line("reassure")
	_note("reassure")
	return res


## Verbal pressure. The reaction is authored: it is evidence for the TEMPER line.
## result: "react" | "walkout" | "attack" | "closed"
func press() -> Dictionary:
	var res := {"result": "closed", "line": "", "face": "", "hands": "", "note": "", "new": false}
	if phase != Phase.EXAM:
		return res
	var list: Array = case_data.get("press", [])
	if list.is_empty():
		return res
	press_count += 1
	patience = maxi(0, patience - _cost("press"))
	var entry: Dictionary = list[mini(press_count - 1, list.size() - 1)]
	res["line"] = str(entry.get("line", ""))
	res["face"] = str(entry.get("face", ""))
	res["hands"] = str(entry.get("hands", ""))
	res["note"] = str(entry.get("note", ""))
	var end := str(entry.get("end", ""))
	_note("press:%d" % press_count)
	if end == "walkout":
		res["result"] = "walkout"
		_finish("walkout")
	elif end == "attack":
		res["result"] = "attack"
		phase = Phase.ATTACK
		attack_cause = "press"
	else:
		res["result"] = "react"
		seen["press"] = true
		res["new"] = add_note("temper", "press", str(entry.get("note", "")))
	return res


# ------------------------------------------------------------------ decisions
## kind: "treat" or "refer" (the call to Trauma Team). Allowed at any moment of the exam.
## Returns {"next": "done" | "attack" | ""}.
func verdict(kind: String) -> Dictionary:
	if phase != Phase.EXAM or not (kind == "treat" or kind == "refer"):
		return {"next": ""}
	verdict_kind = kind
	_note("verdict:" + kind)
	if kind == "treat":
		_finish("treated_drifting" if is_drifting() else "treated_ok")
		return {"next": "done"}
	if not is_drifting():
		_finish("referred_stable")
		return {"next": "done"}
	var attack: Dictionary = case_data.get("attack", {})
	if bool(attack.get("on_refer", false)):
		phase = Phase.ATTACK
		attack_cause = "refer"
		return {"next": "attack"}
	_finish("referred_drifting")
	return {"next": "done"}


## The shutter works at any time. During an attack it is the defence.
func shutter() -> Dictionary:
	if phase == Phase.ATTACK:
		_finish("caught")
	elif phase == Phase.EXAM:
		_note("shutter")
		_finish("locked_out" if is_drifting() else "false_alarm")
	else:
		return {"result": ""}
	return {"result": outcome}


func attack_timeout() -> Dictionary:
	if phase != Phase.ATTACK:
		return {"result": ""}
	_finish("hit")
	return {"result": outcome}


func _finish(p_outcome: String) -> void:
	outcome = p_outcome
	phase = Phase.DONE
	_note("end:" + p_outcome)


func cycle_mark(row: String) -> int:
	if not marks.has(row):
		return 0
	marks[row] = (int(marks[row]) + 1) % 3
	return int(marks[row])


func row_seen(row: String) -> bool:
	var spec: Dictionary = case_data.get("rows", {}).get(row, {})
	for key in spec.get("evidence", []):
		if seen.has(str(key)):
			return true
	return false


func credits_for(p_outcome: String) -> int:
	match p_outcome:
		"treated_ok":
			return int(case_data.get("fee", 0))
		"treated_drifting":
			return int(_rule("scoring", "treat_drifting", -400))
		"referred_drifting", "caught":
			return int(_rule("scoring", "refer_drifting", 120))
		"referred_stable":
			# the crew came out for a steady patient: the call-out is billed
			return int(_rule("scoring", "false_call", -150))
		"hit":
			return int(_rule("scoring", "hit", -300))
		"false_alarm":
			return int(_rule("scoring", "false_alarm", -100))
	return 0


func is_correct(p_outcome: String) -> bool:
	match p_outcome:
		"treated_ok", "referred_drifting", "caught", "locked_out":
			return true
		"hit":
			return attack_cause == "refer"
	return false


## Everything the result slip needs. Only meaningful once the visit is DONE.
func settlement() -> Dictionary:
	var key := outcome
	if outcome.begins_with("treated"):
		key = "treat"
	elif outcome.begins_with("referred"):
		key = "refer"
	var text: Dictionary = case_data.get("outcomes", {}).get(key, {})
	var rows: Array = []
	var row_specs: Dictionary = case_data.get("rows", {})
	for row in ROWS:
		var spec: Dictionary = row_specs.get(row, {})
		var finding := {
			"id": row,
			"ok": bool(spec.get("ok", true)),
			"text": str(spec.get("text", "")),
			"seen": row_seen(row),
			"mark": int(marks.get(row, 0)),
		}
		# An autonomous answer may evade the authored clue entirely. Do not quote the
		# script as if it was heard, or turn a patient's claim into a physical reading.
		if row == "speech" and has_generated_speech:
			finding["assessment"] = "reported"
			finding["ok"] = null
			finding["text"] = last_recorded_speech
			finding["seen"] = true
		rows.append(finding)
	return {
		"case_id": str(case_data.get("id", "")),
		"name": str(case_data.get("name", "")),
		"outcome": outcome,
		"verdict": verdict_kind,
		"truth": str(case_data.get("truth", "stable")),
		"credits": credits_for(outcome),
		"correct": is_correct(outcome),
		"injured": outcome == "hit",
		"title": str(text.get("title", outcome.to_upper())),
		"text": str(text.get("text", "")),
		"rows": rows,
		"patience_left": patience,
		"press_count": press_count,
	}
