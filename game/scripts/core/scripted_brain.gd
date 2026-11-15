extends RefCounted
## The scripted patient: a small stateful rule list per case. It is the default brain, the
## offline mode, the fallback when a model answer is late or invalid, and the baseline a model
## run can be compared with.
##
## It is asked the same question as a model would be: "here is what just happened, here is what
## you already did, here are your legal moves: pick one and say one line."
##
## Used as: const ScriptedBrain = preload("res://scripts/core/scripted_brain.gd")

var rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	rng.seed = p_seed


func reseed(p_seed: int) -> void:
	rng.seed = p_seed


## event: {"type": "check" | "ask", "id": tool or topic id}
func decide(case_data: Dictionary, event: Dictionary, state: Dictionary, legal: Array) -> Dictionary:
	var on := "%s:%s" % [str(event.get("type", "")), str(event.get("id", ""))]
	var move := ""
	for r in case_data.get("script", []):
		var rule: Dictionary = r
		if str(rule.get("on", "")) != on:
			continue
		if not legal.has(str(rule.get("move", ""))):
			continue
		if not _holds(rule.get("if", {}), state, event):
			continue
		move = str(rule["move"])
		break
	if move == "":
		move = str(legal[0]) if legal.size() > 0 else "comply"
	return {"move": move, "line": line_for(case_data, move, event, state)}


func _holds(cond: Dictionary, state: Dictionary, event: Dictionary) -> bool:
	for key in cond.keys():
		var want: Variant = cond[key]
		match str(key):
			"reassure_used_gte":
				if int(state.get("reassure_used", 0)) < int(want):
					return false
			"patience_lte":
				if int(state.get("patience", 0)) > int(want):
					return false
			"patience_gte":
				if int(state.get("patience", 0)) < int(want):
					return false
			"press_gte":
				if int(state.get("press_count", 0)) < int(want):
					return false
			"refused":
				var refusals: Dictionary = state.get("refusals", {})
				var was := int(refusals.get(str(event.get("id", "")), 0)) > 0
				if was != bool(want):
					return false
			_:
				return false   # unknown condition: never match, so data mistakes are visible
	return true


## Authored lines for offline comparison/fallback only. Model speech never passes here.
func line_for(case_data: Dictionary, move: String, event: Dictionary, state: Dictionary) -> String:
	var lines: Dictionary = case_data.get("lines", {})
	var id := str(event.get("id", ""))
	if is_authored_move(move):
		return authored_line(case_data, move, event)
	if move == "deflect":
		for t in case_data.get("topics", []):
			if str(t.get("id", "")) == id and str(t.get("deflect", "")) != "":
				return str(t["deflect"])
		return _pick(lines.get("deflect", ["I'd rather not say."]))
	if move == "stall":
		var refusals: Dictionary = state.get("refusals", {})
		if int(refusals.get(id, 0)) > 0 and str(lines.get("refuse", "")) != "":
			return str(lines["refuse"])
		if lines.has("stall:" + id):
			return str(lines["stall:" + id])
		return _pick(lines.get("stall", ["No."]))
	if lines.has("comply:" + id):
		return str(lines["comply:" + id])
	return _pick(lines.get("comply", ["All right."]))


## Offline comparison only. The scripted patient cannot answer a sentence it has never seen,
## so a typed or spoken line is matched to the questions its case knows, through each
## topic's "keys" words. Returns the topic id, or "" when nothing fits. Model mode never
## comes through here: there the patient reads the doctor's own words.
static func topic_for_text(case_data: Dictionary, text: String) -> String:
	var words: Array = []
	var word := ""
	for i in text.length():
		var ch := text[i].to_lower()
		if ch >= "a" and ch <= "z":
			word += ch
		elif word != "":
			words.append(word)
			word = ""
	if word != "":
		words.append(word)
	var best := ""
	var best_score := 0
	for t in case_data.get("topics", []):
		var topic: Dictionary = t
		var score := 0
		for k in topic.get("keys", []):
			var key := str(k)
			for w in words:
				var heard := str(w)
				if heard == key or (key.length() >= 4 and heard.begins_with(key)):
					score += 1
					break
		if score > best_score:
			best_score = score
			best = str(topic.get("id", ""))
	return best


static func is_authored_move(move: String) -> bool:
	return move == "answer" or move.begins_with("explain:")


static func authored_line(case_data: Dictionary, move: String, event: Dictionary) -> String:
	if move == "answer":
		for t in case_data.get("topics", []):
			if str(t.get("id", "")) == str(event.get("id", "")):
				return str(t.get("a", ""))
		return ""
	if move.begins_with("explain:"):
		var claim: Dictionary = case_data.get("claims", {}).get(move.substr(8), {})
		return str(claim.get("line", ""))
	return ""


func _pick(v: Variant) -> String:
	if typeof(v) == TYPE_ARRAY:
		var arr: Array = v
		if arr.is_empty():
			return ""
		return str(arr[rng.randi_range(0, arr.size() - 1)])
	return str(v)
