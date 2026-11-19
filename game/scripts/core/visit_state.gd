extends RefCounted
## One patient visit: every rule of the exam, with no drawing and no model in it.
##
## The player may look, run a tool, ask, reassure, press, stamp TREAT, call Trauma Team or
## drop the shutter, in any order and at any time. Nothing has to be done before a verdict.
## The call to Trauma Team keeps its first id in the rules and the data: "refer".
## Tests, questions and pressure cost patience. At 0 the patient gives an ultimatum; if nobody
## decides or reassures them in time they leave by themselves (outcome "gave_up": no fee, no
## bill, no call). The wait is the director's clock; the rule and its length are here.
## CALM (reassure) is a calm-patch from the drawer: it costs credits as well as a use.
##
## Contacts (rules version 6): a visitor may be one of tonight's couriers. The player says the
## code line of an entry on the list; the right courier answers and hands over the package, and
## anyone else answers with their own puzzled line for a little patience, so a wrong code says
## nothing about who is a courier. Codes are game-owned: no model call, no history tag.
## Surprises (rules version 6): each action is rolled once. A drifting patient may snap and
## attack mid-exam; anyone may flare once a visit (a shout and a hand on the glass, never an
## attack, TEMPER evidence only). The training visit has neither.
## The result is told twice (rules version 8). At the counter only what does not depend on the
## truth: the fee, whoever the patient was, the drop and CALM, and words that hold either way
## (rules.json "counter"). Since rules version 9 the fee comes in for a patient Trauma Team took
## as well as for work done: the crew pays it on account. The rest comes in at closing, with the
## night's reports: whether the call was right, Trauma Team keeping what it paid or taking it
## back with the call-out, and the bill for work on a patient who drifted (credits_for() less
## counter_credits_for()).
## This class owns the truth, the evidence, patience, attacks and the result. The patient
## AI supplies original dialogue and decides exam cooperation. The offline script alone
## uses authored move choices. Physical test readings, scoring and attack timing stay here.
##
## Notes are written in the player's language as they are taken (scripts/core/lang.gd): the
## words a reading or a reply is filled into are translated first.
## Used as: const VisitState = preload("res://scripts/core/visit_state.gd")

const Lang = preload("res://scripts/core/lang.gd")

const ROWS := ["eyes", "hands", "port", "speech", "temper"]
const ZONES := ["eyes", "hands", "port"]
const TOOLS := ["penlight", "grip", "port"]
const TOOL_ROW := {"penlight": "eyes", "grip": "hands", "port": "port"}
const TOOL_NAME := {"penlight": "penlight", "grip": "grip bar", "port": "port check"}   # [shown] in "Declined the %s."
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
var attack_cause: String = ""    # "refer", "press" or "snap"
var blows_taken: int = 0         # blows that reached the glass before the shutter was down
var verdict_kind: String = ""    # "treat", "refer" or ""
var outcome: String = ""
var history: Array = []          # short tags, newest last (sent to the patient brain)
var contact: Dictionary = {}     # tonight's contact entry when this visitor is a courier, else {}
var dropped: bool = false        # the courier answered the code and handed the package over
var drop_pay: int = 0            # what the drop put in the till
var codes_tried: Dictionary = {} # entry id -> true: wrong codes already said to this visitor
var codes_wrong: int = 0
var calm_spent: int = 0          # credits CALM took off the till
var actions: int = 0             # actions rolled for a snap or a flare
var surprises: bool = true       # false on the training visit: nobody snaps or flares
var snapped: bool = false
var flared: bool = false


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


## Tonight's list says this visitor is a courier (an entry of data/contacts.json "pool").
func set_contact(entry: Dictionary) -> void:
	contact = entry.duplicate(true)


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


## Patience is gone and the visit is still open: the patient is about to leave.
func is_spent() -> bool:
	return phase == Phase.EXAM and patience <= 0


## How long a patient with no patience left waits before leaving, in ms. 0: they go at once.
func leave_ms() -> int:
	return maxi(0, int(_rule("patience", "leave_ms", 8000)))


## The player's own crosses on the record. Advice only: nothing scores or gates them.
func crossed() -> int:
	var n := 0
	for row in ROWS:
		if int(marks.get(row, 0)) == 2:
			n += 1
	return n


func ticked() -> int:
	var n := 0
	for row in ROWS:
		if int(marks.get(row, 0)) == 1:
			n += 1
	return n


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
		add_note(str(TOOL_ROW[tool]), "refuse:" + tool, Lang.tf("Declined the %s.", [Lang.t(str(TOOL_NAME[tool]))]))
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
		text = Lang.fill(text, {"t": "%.1f" % (release_ms() / 1000.0)})
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
	add_note("speech", key, Lang.tf("Says: %s", [Lang.t(reply)]))
	if reaction != "":
		add_note("temper", key, Lang.tf("Reaction: %s", [reaction]))
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


## What one CALM costs in credits: a calm-patch from the drawer.
func reassure_cost() -> int:
	return maxi(0, int(_rule("reassure", "cost", 0)))


## Reassurance: a little patience back, and refused tools will be allowed next time. It costs
## reassure_cost() credits; the till may go below zero for it.
func reassure() -> Dictionary:
	var res := {"result": "closed", "line": "", "cost": 0}
	if phase != Phase.EXAM:
		return res
	if reassure_left <= 0:
		res["result"] = "none_left"
		return res
	reassure_left -= 1
	reassure_used += 1
	calm_spent += reassure_cost()
	res["cost"] = reassure_cost()
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


# ------------------------------------------------------------------ contacts
func is_contact() -> bool:
	return not contact.is_empty()


## The patience a wrong code costs. A code of any kind needs at least this much patience left
## (and some patience at all), so a patient on the way out cannot be sounded for free.
func code_cost() -> int:
	return maxi(0, int(_rule("contacts", "wrong_cost", 1)))


## The player says the code line of one entry of tonight's list.
## result: "drop" (the right courier: the answer, the package and the pay; free) |
##   "blank" (anyone else, or another courier's code: their own puzzled line, code_cost()) |
##   "tried" (that code was already said to them: nothing happens, free) |
##   "done" (the drop is made already) | "short" (no patience left to listen) | "closed"
func say_code(entry: Dictionary) -> Dictionary:
	var id := str(entry.get("id", ""))
	var res := {"result": "closed", "id": id, "cost": 0, "line": "", "pay": 0, "package": ""}
	if phase != Phase.EXAM or id == "":
		return res
	if dropped:
		res["result"] = "done"
		return res
	if codes_tried.has(id):
		res["result"] = "tried"
		return res
	var cost := code_cost()
	if patience <= 0 or patience < cost:
		res["result"] = "short"
		return res
	if is_contact() and str(contact.get("id", "")) == id:
		dropped = true
		drop_pay = maxi(0, int(_rule("contacts", "pay", 0)))
		res["result"] = "drop"
		res["line"] = str(contact.get("answer", ""))
		res["pay"] = drop_pay
		res["package"] = str(contact.get("package", ""))
		return res
	patience -= cost
	codes_tried[id] = true
	codes_wrong += 1
	res["result"] = "blank"
	res["cost"] = cost
	res["line"] = _first_line("code")
	return res


## What this visit has done to the till so far, before its outcome is known: the drop in,
## CALM out.
func till_change() -> int:
	return drop_pay - calm_spent


# ------------------------------------------------------------------ surprises
## The chance that the action just counted is the one a drifting patient snaps on.
func snap_chance() -> float:
	if not surprises or not is_drifting():
		return 0.0
	var grace := int(_rule("snap", "grace", 3))
	var step := float(_rule("snap", "step", 0.0))
	var top := float(_rule("snap", "max", 0.0))
	return clampf(float(actions - grace) * step, 0.0, top)


## The chance that the action just counted brings the visit's one flare.
func flare_chance() -> float:
	if not surprises or flared or case_data.get("flare", {}).is_empty():
		return 0.0
	if actions <= int(_rule("flare", "grace", 1)):
		return 0.0
	return clampf(float(_rule("flare", "chance", 0.0)), 0.0, 1.0)


## One action of the player's: a tool, a question, pressure, CALM, a code or their own words.
## Looking is free and is not one. Counts it and rolls, with the director's generator, whether
## the patient snaps (drifting only) or flares (anyone, once a visit). Returns "snap", "flare"
## or "". Nothing happens yet: snap() and flare() do it when the director is ready.
func roll_action(rng: RandomNumberGenerator) -> String:
	if phase != Phase.EXAM:
		return ""
	actions += 1
	var s := snap_chance()
	if s > 0.0 and rng.randf() < s:
		return "snap"
	var f := flare_chance()
	if f > 0.0 and rng.randf() < f:
		return "flare"
	return ""


## A drifting patient turns mid-exam. What follows is the ordinary attack.
func snap() -> bool:
	if phase != Phase.EXAM or not is_drifting():
		return false
	phase = Phase.ATTACK
	attack_cause = "snap"
	snapped = true
	_note("snap")
	return true


## A shout and a hand slammed on the glass. Never an attack. The note is TEMPER evidence and
## agrees with the case: face and voice together for the steady, not for the drifting.
func flare() -> Dictionary:
	var res := {"ok": false, "line": "", "face": "", "hands": "", "note": "", "new": false}
	if phase != Phase.EXAM or flared:
		return res
	var spec: Dictionary = case_data.get("flare", {})
	if spec.is_empty():
		return res
	flared = true
	seen["flare"] = true
	res["ok"] = true
	res["line"] = str(spec.get("line", ""))
	res["face"] = str(spec.get("face", ""))
	res["hands"] = str(spec.get("hands", ""))
	res["note"] = str(spec.get("note", ""))
	res["new"] = add_note("temper", "flare", str(res["note"]))
	_note("flare")
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


## A blow reached the glass while the shutter was still up. Returns how many have.
func take_blow() -> int:
	if phase == Phase.ATTACK:
		blows_taken += 1
	return blows_taken


## How the shutter was timed against a patient who turned: "clean" (down before any blow
## landed), "cracked" (blows landed first), "through" (not down in time), "" (no attack).
func shutter_grade() -> String:
	match outcome:
		"caught":
			return "clean" if blows_taken == 0 else "cracked"
		"hit":
			return "through"
	return ""


## Patience ran out and nobody decided: the patient leaves by themselves. Nothing is earned
## and nothing is billed, whoever they were. The director calls this when the wait is over.
func give_up() -> Dictionary:
	if not is_spent():
		return {"result": ""}
	_note("gave_up")
	_finish("gave_up")
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
	if row == "temper" and seen.has("flare"):
		return true      # a flare shows the temper as plainly as pressure does
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
			# Trauma Team's bounty: the patient's fee, plus refer_drifting (rules version 9)
			return int(case_data.get("fee", 0)) + int(_rule("scoring", "refer_drifting", 0))
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


## What an outcome pays at the counter, on the spot (rules version 9): the patient's fee, for
## work done or for a patient Trauma Team took, whoever the patient was. The crew pays the fee on
## account; its report at closing keeps it as the bounty for a drifting patient, or takes it back
## with the call-out for a steady one. A shutter, a walkout or a patient who gave up pays nothing
## here. So the readings through the night move with the work done, never with the truth.
func counter_credits_for(p_outcome: String) -> int:
	if p_outcome.begins_with("treated") or p_outcome.begins_with("referred") or p_outcome == "caught":
		return int(case_data.get("fee", 0))
	return 0


## What the same outcome adds at closing, when the night's reports are in: refer_drifting on top
## of the fee Trauma Team paid for a drifting patient; the fee back and the call-out for a steady
## one; the fee back and the bill for work on a patient who drifted; the cost of a shutter dropped
## on somebody steady.
func closing_credits_for(p_outcome: String) -> int:
	return credits_for(p_outcome) - counter_credits_for(p_outcome)


## The player's own call, as the meter's lamps show it through the night: "treat", "team"
## (Trauma Team was called, whether or not the patient then fought), "shutter" (the shutter
## came down on the patient before any call), "none" (they walked out or gave up), or "hit".
func call_kind() -> String:
	if outcome.begins_with("treated"):
		return "treat"
	if outcome.begins_with("referred"):
		return "team"
	match outcome:
		"caught":
			return "team" if attack_cause == "refer" else "shutter"
		"locked_out", "false_alarm":
			return "shutter"
		"hit":
			return "hit"
	return "none"


## Which entry of rules.json "counter" the slip prints: words that hold whoever the patient was.
func counter_key() -> String:
	if outcome.begins_with("treated"):
		return "treated"
	if outcome.begins_with("referred"):
		return "referred"
	if outcome == "locked_out" or outcome == "false_alarm":
		return "shutter"
	return outcome


## Everything the slip and the night's report need. Only meaningful once the visit is DONE.
## "credits" is what the visit puts in the till in all, by closing: the outcome's credits, the
## drop, less CALM. "counter" is the part of it that came in at the counter (the fee for work
## done, the drop, less CALM) and "closing" the part that waits for the night's reports. The
## slip shows only "counter_title", "counter_text" and "counter"; "title", "text", "truth",
## "correct" and the findings ("rows") are for the report at closing.
func settlement() -> Dictionary:
	var counter: Dictionary = _rule("counter", counter_key(), {})
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
		"role": str(case_data.get("role", "")),
		"age": int(case_data.get("age", 0)),
		"request": str(case_data.get("request", "")),
		"fee": int(case_data.get("fee", 0)),
		"outcome": outcome,
		"verdict": verdict_kind,
		"truth": str(case_data.get("truth", "stable")),
		"credits": credits_for(outcome) + till_change(),
		"outcome_credits": credits_for(outcome),
		"counter": counter_credits_for(outcome) + till_change(),
		"counter_fee": counter_credits_for(outcome),
		"closing": closing_credits_for(outcome),
		"counter_title": str(counter.get("title", "")),
		"counter_text": str(counter.get("text", "")),
		"call": call_kind(),
		"correct": is_correct(outcome),
		"injured": outcome == "hit",
		"title": str(text.get("title", outcome.to_upper())),
		"text": str(text.get("text", "")),
		"rows": rows,
		"patience_left": patience,
		"press_count": press_count,
		"crossed": crossed(),
		"blows": blows_taken,
		"grade": shutter_grade(),
		"cause": attack_cause,
		"contact": is_contact(),
		"contact_id": str(contact.get("id", "")),
		"alias": str(contact.get("alias", "")),
		"dropped": dropped,
		"drop": drop_pay,
		"package": str(contact.get("package", "")) if dropped else "",
		"missed_drop": is_contact() and not dropped,
		"calm_spent": calm_spent,
		"codes_wrong": codes_wrong,
		"snapped": snapped,
		"flared": flared,
	}
