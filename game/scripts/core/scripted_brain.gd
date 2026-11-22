extends RefCounted
## The scripted patient: a small stateful rule list per case. It is the default brain, the
## offline mode, the fallback when a model answer is late or invalid, and the baseline a model
## run can be compared with.
##
## It is asked the same question as a model would be: "here is what just happened, here is what
## you already did, here are your legal moves: pick one and say one line."
##
## Used as: const ScriptedBrain = preload("res://scripts/core/scripted_brain.gd")

const Lang = preload("res://scripts/core/lang.gd")

var rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	rng.seed = p_seed


func reseed(p_seed: int) -> void:
	rng.seed = p_seed


## event: {"type": "check" | "ask", "id": tool or topic id}
func decide(case_data: Dictionary, event: Dictionary, state: Dictionary, legal: Array) -> Dictionary:
	var chosen := choose_move(case_data, event, state, legal)
	return {"move": chosen, "line": line_for(case_data, chosen, event, state)}


func choose_move(case_data: Dictionary, event: Dictionary, state: Dictionary, legal: Array) -> String:
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
	return move


func _holds(cond: Dictionary, state: Dictionary, _event: Dictionary) -> bool:
	for key in cond.keys():
		var want: Variant = cond[key]
		match str(key):
			"patience_lte":
				if int(state.get("patience", 0)) > int(want):
					return false
			"patience_gte":
				if int(state.get("patience", 0)) < int(want):
					return false
			"press_gte":
				if int(state.get("press_count", 0)) < int(want):
					return false
			_:
				return false   # unknown condition: never match, so data mistakes are visible
	return true


## Authored lines for offline comparison/fallback only. Model speech never passes here.
func line_for(case_data: Dictionary, move: String, event: Dictionary, _state: Dictionary) -> String:
	var lines: Dictionary = case_data.get("lines", {})
	var id := str(event.get("id", ""))
	if is_authored_move(move):
		return authored_line(case_data, move, event)
	if move == "stall":
		if lines.has("stall:" + id):
			return str(lines["stall:" + id])
		return _pick(lines.get("stall", ["No."]))
	if lines.has("comply:" + id):
		return str(lines["comply:" + id])
	return _pick(lines.get("comply", ["All right."]))


## Offline comparison only. The scripted patient cannot answer a sentence it has never seen,
## so a typed or spoken line is matched to the questions its case knows, through each
## topic's "keys" words. Returns the topic id, or "" when nothing fits. A failed intent call also
## uses these keys when the remote classifier is unavailable.
## In another language the catalog adds words of its own (data/lang/<code>: "topics", under the
## topic id for every case and under "<case>:<topic>" for one case). Chinese leaves no spaces
## between words, so those are looked for anywhere in the sentence.
static var intent_cues: Dictionary = {}


static var part_words: Dictionary = {}
static var complaint_questions: Array = []


static func part_for_text(text: String) -> String:
	if part_words.is_empty():
		for file in ["res://data/sheet.json", "res://data/lang/zh/sheet.json"]:
			var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
			complaint_questions.append_array(catalog.get("complaint_questions", []))
			for row in catalog.part_words:
				if not part_words.has(row):
					part_words[row] = []
				part_words[row].append_array(catalog.part_words[row])
	var line := text.to_lower()
	var words := PackedStringArray()
	var word := ""
	for letter in line + " ":
		if letter >= "a" and letter <= "z":
			word += letter
		elif word != "":
			words.append(word)
			word = ""
	for row in part_words:
		for term in part_words[row]:
			if (Lang.has_cjk(term) and line.contains(term)) or term in words:
				return row
	return ""


static func is_part_name(text: String, part: String) -> bool:
	var word := text.strip_edges().to_lower().trim_suffix("?").trim_suffix("？").trim_suffix(".").trim_suffix("。").strip_edges()
	return part != "" and (word in part_words.get(part, []) or (Lang.has_cjk(word) and word.length() <= 3))


static func is_complaint(text: String) -> bool:
	if part_words.is_empty():
		part_for_text("")
	for term in complaint_questions:
		if text.to_lower().contains(term):
			return true
	return false


static func intent_for_text(case_data: Dictionary, text: String) -> Dictionary:
	if intent_cues.is_empty():
		var file := FileAccess.open("res://data/patient_intents.json", FileAccess.READ)
		if file != null:
			intent_cues = JSON.parse_string(file.get_as_text())
	var line := text.strip_edges().to_lower()
	for kind in intent_cues:
		if kind == "complaint":
			continue
		for phrase in intent_cues[kind]:
			if line.contains(phrase):
				return {"topic":"", "intent":kind}
	var topic := topic_for_text(case_data, text)
	var question := line.ends_with("?") or line.ends_with("？") or line.get_slice(" ", 0) in ["how", "what", "does", "do", "any", "is", "are"]
	var part := part_for_text(line)
	if is_part_name(line, part) or is_complaint(line) or (topic == "" and question and part != ""):
		return {"topic":"", "intent":"complaint"}
	return {"topic":topic, "intent":"case_question" if topic != "" else ("unclear" if line.length() < 4 else "other")}


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
	var case_id := str(case_data.get("id", ""))
	var lowered := text.to_lower()
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
		var id := str(topic.get("id", ""))
		var own: Array = []
		own.append_array(Lang.topic_keys.get(id, []))
		own.append_array(Lang.topic_keys.get(case_id + ":" + id, []))
		for k in own:
			var key := str(k).to_lower()
			if key != "" and lowered.contains(key):
				score += 1
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
