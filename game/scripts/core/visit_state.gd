extends RefCounted
## One patient visit: every rule of the exam, with no drawing and no model in it.
##
## The appointment owns the lamps, drawn complaints, chart, surprises and settlement.
## The patient voices the visit. Only the doctor can perform tests, mark rows or make a call.

const Lang = preload("res://scripts/core/lang.gd")
const VisitRecord = preload("res://scripts/core/visit_record.gd")

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
var complaints_told: Array = []
var tests_in_order: Array = []
var complaints_followed: Array = []
var pending_leads: Array = []
var idle_complaints: int = 0
var claims: Array = []           # claim ids the patient has offered
var asked: Dictionary = {}       # topic id -> times asked
var answered: Dictionary = {}    # topic id -> true
var last_recorded_speech: String = ""  # memory only; never written to the event log
var press_count: int = 0
var attack_cause: String = ""    # "refer", "press" or "snap"
var blows_taken: int = 0         # blows that reached the glass before the shutter was down
var verdict_kind: String = ""    # "treat", "refer" or ""
var outcome: String = ""
var record := VisitRecord.new()
var contact: Dictionary = {}     # tonight's contact entry when this visitor is a courier, else {}
var dropped: bool = false        # the courier answered the code and handed the package over
var drop_pay: int = 0            # what the drop put in the till
var codes_tried: Dictionary = {} # entry id -> true: wrong codes already said to this visitor
var codes_wrong: int = 0
var actions: int = 0             # actions rolled for a snap or a flare
var surprises: bool = true       # false on the training visit: nobody snaps or flares
var snapped: bool = false
var flared: bool = false


func _init(p_case: Dictionary = {}, p_rules: Dictionary = {}) -> void:
	case_data = p_case
	rules = p_rules
	patience_max = int(_rule("visit", "lamps", 2))
	patience = patience_max
	for row in ROWS:
		notes[row] = []
		marks[row] = 0


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
	record.append("action", tag)


func add_note(row: String, key: String, text: String) -> bool:
	if text == "" or not notes.has(row):
		return false
	var list: Array = notes[row]
	for n in list:
		if str(n["key"]) == key:
			if row == "speech":
				n["text"] = text  # A free repeat can yield a new quote for the same topic.
			return false
		if row != "speech" and str(n["text"]) == text:
			return false
	list.append({"key": key, "text": text})
	while list.size() > MAX_NOTES_PER_ROW:
		list.pop_front()
	return true


func is_drifting() -> bool:
	return str(case_data.get("truth", "stable")) == "drifting"


func in_exam() -> bool:
	return phase == Phase.EXAM


## Patience is gone and the visit is still open: the patient is about to leave.
func is_spent() -> bool:
	return phase == Phase.EXAM and patience <= 0


## How long a patient with no patience left waits before leaving, in ms. 0: they go at once.
func leave_ms() -> int:
	return maxi(0, int(_rule("patience", "leave_ms", 30000)))


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
		"complaints_told": complaints_told.duplicate(),
		"claims": claims.duplicate(),
		"asked": asked.duplicate(),
		"press_count": press_count,
	}


## Return authored lines in the current language. Only delivered facts enter the chart.
func complaint_offer(row: String = "", maximum: int = -1) -> Dictionary:
	if not in_exam():
		return {"rows": [], "line": ""}
	var drawn: Array = case_data.get("complaint_rows", [])
	var book: Dictionary = case_data.get("complaints", {})
	var deliver := []
	if row != "":
		if drawn.has(row):
			deliver.append(row)
	else:
		for candidate in drawn:
			if not complaints_told.has(candidate):
				deliver.append(candidate)
				if deliver.size() >= (maximum if maximum > 0 else int(_rule("complaints", "per_reply", 2))):
					break
	var lines := PackedStringArray()
	for part in deliver:
		var sentence := Lang.t(str(book[part]))
		lines.append(sentence)
	if lines.is_empty():
		lines.append(Lang.t(str(book.get("none", ""))) if row != "" or drawn.is_empty() else Lang.t("That's all I wanted to mention."))
	var delivery := "rows" if not deliver.is_empty() else ("none" if row != "" or drawn.is_empty() else "all")
	return {"rows":deliver, "delivery":delivery, "line":" ".join(lines)}


func record_complaint(result: Dictionary) -> void:
	for part in result.rows:
		if not complaints_told.has(part):
			complaints_told.append(part)
			pending_leads.append(part)
			var sentence := Lang.t(str(case_data.complaints[part]))
			add_note(part, "complaint:" + part, Lang.tf("Complains: %s", [sentence]))


func complain(row: String = "", maximum: int = -1) -> Dictionary:
	var result := complaint_offer(row, maximum)
	record_complaint(result)
	return result


func record_test(row: String) -> void:
	tests_in_order.append(row)
	if row in pending_leads:
		complaints_followed.append(row)
	pending_leads.clear()


# ------------------------------------------------------------------ tools
func check_status(tool: String) -> String:
	return "open" if granted.has(tool) else "fresh"


func check_cost(tool: String) -> int:
	return 0 if granted.has(tool) else _cost("check")


func legal_moves_for_check(tool: String) -> Array:
	return case_data.get("checks", {}).get(tool, {}).get("first", ["comply"])


func apply_check(tool: String, move: String, _autonomous: bool = false) -> Dictionary:
	var result := {"result":"closed", "tool":tool, "move":move, "cost":0, "row":TOOL_ROW.get(tool, "")}
	if not in_exam() or not TOOLS.has(tool):
		return result
	var cost := check_cost(tool)
	if cost > patience:
		result.result = "spent"
		return result
	if not granted.has(tool):
		patience -= cost
		granted[tool] = true
		record_test(TOOL_ROW[tool])
		if move.begins_with("explain:"):
			claims.append(move.trim_prefix("explain:"))
		_note("check:%s:%s" % [tool, move.get_slice(":", 0)])
	result.cost = cost
	result.result = "granted"
	return result


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
	res["ok"] = true
	res["text"] = text
	res["new"] = add_note(str(TOOL_ROW[tool]), key, text)
	_note("done:" + tool)
	return res


func release_ms() -> int:
	var grip: Dictionary = case_data.get("grip", {})
	return int(grip.get("release_ms", 400))


# ------------------------------------------------------------------ talk
## Which signs a dialogue request has earned, including the action being answered now.
func open_signs(event: Dictionary = {}) -> Dictionary:
	var result := {}
	var signs: Dictionary = case_data.get("signs", {})
	var id := str(event.get("id", ""))
	var will_answer: bool = event.get("type") == "ask" and event.get("outcome") == "answer" and not topic(id).is_empty()
	var evidence: Array = case_data.get("rows", {}).get("speech", {}).get("evidence", [])
	if signs.has("speech") and (not answered.is_empty() or will_answer):
		result["speech"] = signs.speech if row_seen("speech") or (will_answer and evidence.has("ask:" + id)) else case_data.get("normal_speech_sign", "")
	if signs.has("temper") and (row_seen("temper") or event.get("type") == "press"):
		result["temper"] = signs.temper
	return result


func legal_moves_for_ask(_topic_id: String) -> Array:
	return ["answer"]


func apply_ask(topic_id: String, _move: String = "answer", spoken: String = "") -> Dictionary:
	var t := topic(topic_id)
	if not in_exam() or t.is_empty():
		return {"result":"closed", "cost":0}
	asked[topic_id] = int(asked.get(topic_id, 0)) + 1
	answered[topic_id] = true
	seen["ask:" + topic_id] = true
	last_recorded_speech = spoken if spoken != "" else str(t.a)
	var fresh := add_note("speech", "ask:" + topic_id, Lang.tf("Says: %s", [Lang.t(last_recorded_speech)]))
	_note("ask:%s:answer" % topic_id)
	return {"result":"answered", "topic":topic_id, "move":"answer", "cost":0, "line":last_recorded_speech, "new":fresh}


func press_breaks() -> bool:
	return seen.has("press") or patience <= 0


func press_cost() -> int:
	return patience if press_breaks() else _cost("press")


## Verbal pressure. The reaction is authored: it is evidence for the TEMPER line. The push that
## breaks the patient takes every lamp left (press_cost()).
## result: "react" | "walkout" | "attack" | "closed"
func press() -> Dictionary:
	var res := {"result": "closed", "line": "", "face": "", "hands": "", "note": "", "new": false}
	if phase != Phase.EXAM:
		return res
	var list: Array = case_data.get("press", [])
	if list.is_empty():
		return res
	var breaks := press_breaks()
	patience = 0 if breaks else maxi(0, patience - _cost("press"))
	press_count += 1
	var entry: Dictionary = list[list.size() - 1 if breaks else 0]
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
		record_test("temper")
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


## The package payment already in the till before the call.
func till_change() -> int:
	return drop_pay


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
func roll_action(rng: RandomNumberGenerator, cost: int = 1) -> String:
	if phase != Phase.EXAM or cost <= 0:
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


func press_bonus(p_outcome: String) -> int:
	return int(_rule("scoring", "press_catch_bonus", 0)) if p_outcome == "caught" and attack_cause == "press" and is_drifting() else 0


func credits_for(p_outcome: String) -> int:
	match p_outcome:
		"treated_ok":
			return int(case_data.get("fee", 0))
		"treated_drifting":
			return int(_rule("scoring", "treat_drifting", -400))
		"referred_drifting", "caught":
			# Trauma Team's bounty: the patient's fee, plus refer_drifting (rules version 9)
			return int(case_data.get("fee", 0)) + int(_rule("scoring", "refer_drifting", 0)) + press_bonus(p_outcome)
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
			"id": row, "complained":complaints_told.has(row), "tested":tests_in_order.has(row),
			"ok": bool(spec.get("ok", true)),
			"text": str(spec.get("text", "")),
			"seen": row_seen(row),
			"mark": int(marks.get(row, 0)),
		}
		if row == "speech" and last_recorded_speech != "":
			finding["text"] = last_recorded_speech
		finding["wear"] = not is_drifting() and not finding.ok
		if not finding.ok and not finding.seen and int(_rule("report", "missed_hints", 1)) > 0:
			var how := {"eyes": "LIGHT", "hands": "GRIP", "port": "PORT", "temper": "PRESS"}
			if row == "speech":
				var needed := str(spec.evidence[0]).trim_prefix("ask:")
				var question := Lang.t(str(topic(needed).get("q", "")))
				finding["show_with"] = Lang.tf("ASK: %s", [question])
				finding["other_question"] = not asked.is_empty()
			else:
				finding["show_with"] = Lang.t(str(how[row]))
		rows.append(finding)
	var usage := {}
	if int(_rule("report", "show_usage", 1)) > 0:
		for tool in TOOLS:
			usage[tool] = granted.has(tool)
		usage["ask"] = not asked.is_empty()
		usage["press"] = press_count > 0
	return {
		"complaints_told": complaints_told.duplicate(), "tests_in_order": tests_in_order.duplicate(), "complaints_followed": complaints_followed.duplicate(),
		"usage": usage, "press_bonus": press_bonus(outcome),
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
		"codes_wrong": codes_wrong,
		"snapped": snapped,
		"flared": flared,
	}
