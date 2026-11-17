extends RefCounted
## Loads rules.json, sheet.json and the case files, and checks them before the game uses them.
## A data mistake is reported as a readable list instead of a broken visit.
## Used as: const CaseDB = preload("res://scripts/core/case_db.gd")

const DATA_DIR := "res://data"
const ROWS := ["eyes", "hands", "port", "speech", "temper"]
const ZONES := ["eyes", "hands", "port"]
const TOOLS := ["penlight", "grip", "port"]
const EYE_KINDS := ["natural", "optic", "combat", "display"]


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Returns {"rules", "sheet", "cases": {id: case}, "errors": [String]}.
static func load_all(dir: String = DATA_DIR) -> Dictionary:
	var out := {"rules": {}, "sheet": {}, "cases": {}, "errors": []}
	var errors: Array = out["errors"]
	var rules: Variant = load_json(dir + "/rules.json")
	if typeof(rules) != TYPE_DICTIONARY:
		errors.append("rules.json is missing or is not valid JSON.")
		return out
	out["rules"] = rules
	errors.append_array(validate_rules(rules))
	var sheet: Variant = load_json(dir + "/sheet.json")
	if typeof(sheet) != TYPE_DICTIONARY:
		errors.append("sheet.json is missing or is not valid JSON.")
	else:
		out["sheet"] = sheet
		errors.append_array(validate_sheet(sheet))
	for id in rules.get("shift_order", []):
		var path := "%s/cases/%s.json" % [dir, str(id)]
		var c: Variant = load_json(path)
		if typeof(c) != TYPE_DICTIONARY:
			errors.append("cases/%s.json is missing or is not valid JSON." % str(id))
			continue
		for e in validate_case(c, rules, out["sheet"]):
			errors.append("%s: %s" % [str(id), str(e)])
		out["cases"][str(id)] = c
	return out


static func validate_rules(rules: Dictionary) -> Array:
	var errors: Array = []
	var order: Variant = rules.get("shift_order")
	if typeof(order) != TYPE_ARRAY or (order as Array).is_empty():
		errors.append("rules.json: shift_order must list at least one case id.")
	for group in ["costs", "reassure", "attack", "scoring", "grip", "line", "patience"]:
		if typeof(rules.get(group)) != TYPE_DICTIONARY:
			errors.append("rules.json: '%s' must be an object." % group)
	if typeof(rules.get("attack")) == TYPE_DICTIONARY:
		errors.append_array(_validate_attack(rules["attack"]))
	if typeof(rules.get("line")) == TYPE_DICTIONARY and int(rules["line"].get("per_hour", -1)) < 0:
		errors.append("rules.json: line.per_hour must be 0 or more.")
	if typeof(rules.get("patience")) == TYPE_DICTIONARY and int(rules["patience"].get("leave_ms", -1)) < 0:
		errors.append("rules.json: patience.leave_ms must be 0 or more.")
	return errors


## The shutter window and the glass. blow_at places each blow inside window_ms; the pane takes
## `glass` of them in a shift; however little glass is left, the player gets min_window_ms.
## repair_cost is what one layer costs to refit between patients (0 or absent: nobody mends it).
static func _validate_attack(attack: Dictionary) -> Array:
	var errors: Array = []
	var window := int(attack.get("window_ms", 0))
	if window < 500:
		errors.append("rules.json: attack.window_ms must be at least 500.")
	var marks: Variant = attack.get("blow_at")
	if typeof(marks) != TYPE_ARRAY or (marks as Array).is_empty():
		errors.append("rules.json: attack.blow_at must list at least one blow.")
		return errors
	var last := 0.0
	for m in marks:
		var at := float(m)
		if at <= last or at >= 1.0:
			errors.append("rules.json: attack.blow_at must rise, each value between 0 and 1.")
			break
		last = at
	var glass := int(attack.get("glass", 0))
	if glass < 1 or glass > (marks as Array).size():
		errors.append("rules.json: attack.glass must be between 1 and the number of blows.")
	var floor_ms := int(attack.get("min_window_ms", 0))
	if floor_ms < 300 or floor_ms > window:
		errors.append("rules.json: attack.min_window_ms must be between 300 and window_ms.")
	if int(attack.get("repair_cost", 0)) < 0:
		errors.append("rules.json: attack.repair_cost must be 0 or more (0: the glass cannot be mended).")
	return errors


static func validate_sheet(sheet: Dictionary) -> Array:
	var errors: Array = []
	var rows: Variant = sheet.get("rows")
	if typeof(rows) != TYPE_ARRAY:
		return ["sheet.json: rows must be a list."]
	var ids: Array = []
	for r in rows:
		ids.append(str(r.get("id", "")))
		for key in ["label", "normal", "ordinary"]:
			if str(r.get(key, "")) == "":
				errors.append("sheet.json: row '%s' needs '%s'." % [str(r.get("id", "?")), key])
	if ids != ROWS:
		errors.append("sheet.json: rows must be exactly %s, in that order." % str(ROWS))
	var threshold := int(sheet.get("threshold", 0))
	if threshold < 1 or threshold > ROWS.size():
		errors.append("sheet.json: threshold must be between 1 and %d." % ROWS.size())
	return errors


static func _need_text(c: Dictionary, key: String, errors: Array) -> void:
	if typeof(c.get(key)) != TYPE_STRING or str(c[key]) == "":
		errors.append("'%s' must be a non-empty string." % key)


## `sheet` is only needed for its threshold: how many broken lines the house rule asks for.
static func validate_case(c: Dictionary, rules: Dictionary, sheet: Dictionary = {}) -> Array:
	var errors: Array = []
	for key in ["id", "name", "role", "request", "sprite", "teaser"]:
		_need_text(c, key, errors)
	var truth := str(c.get("truth", ""))
	if not (truth == "stable" or truth == "drifting"):
		errors.append("truth must be 'stable' or 'drifting'.")
	var drifting := truth == "drifting"
	if int(c.get("fee", 0)) <= 0:
		errors.append("fee must be positive.")
	if int(c.get("patience", 0)) < 1 or int(c.get("patience", 0)) > 9:
		errors.append("patience must be between 1 and 9.")
	if typeof(c.get("opening")) != TYPE_ARRAY or (c["opening"] as Array).is_empty():
		errors.append("opening must list at least one line.")

	# eyes, grip, port
	var eyes: Dictionary = c.get("eyes", {}) if typeof(c.get("eyes")) == TYPE_DICTIONARY else {}
	var eyes_ok := true
	for side in ["left", "right"]:
		var eye: Variant = eyes.get(side)
		if typeof(eye) != TYPE_DICTIONARY:
			errors.append("eyes.%s is missing." % side)
			continue
		if not EYE_KINDS.has(str(eye.get("kind", ""))):
			errors.append("eyes.%s.kind must be one of %s." % [side, str(EYE_KINDS)])
		if not bool(eye.get("follows", true)):
			eyes_ok = false
		if str(eye.get("kind", "")) == "natural" and not bool(eye.get("tightens", true)):
			eyes_ok = false
	var grip: Dictionary = c.get("grip", {}) if typeof(c.get("grip")) == TYPE_DICTIONARY else {}
	var release := int(grip.get("release_ms", 0))
	if release <= 0:
		errors.append("grip.release_ms must be positive.")
	var limit := int((rules.get("grip", {}) as Dictionary).get("limit_ms", 1000))
	if typeof(c.get("port")) != TYPE_DICTIONARY:
		errors.append("port must be an object with 'covered'.")

	# looks and checks
	var looks: Dictionary = c.get("looks", {}) if typeof(c.get("looks")) == TYPE_DICTIONARY else {}
	for zone in ZONES:
		if str(looks.get(zone, "")) == "":
			errors.append("looks.%s is missing." % zone)
	var claims: Dictionary = c.get("claims", {}) if typeof(c.get("claims")) == TYPE_DICTIONARY else {}
	var checks: Dictionary = c.get("checks", {}) if typeof(c.get("checks")) == TYPE_DICTIONARY else {}
	for tool in TOOLS:
		var spec: Variant = checks.get(tool)
		if typeof(spec) != TYPE_DICTIONARY:
			errors.append("checks.%s is missing." % tool)
			continue
		if str(spec.get("note", "")) == "":
			errors.append("checks.%s.note is missing." % tool)
		if not ["comply", "refuse"].has(str(spec.get("insist", ""))):
			errors.append("checks.%s.insist must be 'comply' or 'refuse'." % tool)
		var first: Variant = spec.get("first")
		if typeof(first) != TYPE_ARRAY or (first as Array).is_empty():
			errors.append("checks.%s.first must list at least one move." % tool)
			continue
		for m in first:
			var move := str(m)
			if move.begins_with("explain:"):
				if not claims.has(move.substr(8)):
					errors.append("checks.%s uses unknown claim '%s'." % [tool, move.substr(8)])
			elif not ["comply", "stall"].has(move):
				errors.append("checks.%s.first has unknown move '%s'." % [tool, move])
	for cid in claims.keys():
		var claim: Dictionary = claims[cid]
		if str(claim.get("line", "")) == "" or str(claim.get("note", "")) == "":
			errors.append("claims.%s needs 'line' and 'note'." % str(cid))
		if not ROWS.has(str(claim.get("row", ""))):
			errors.append("claims.%s.row must be a sheet row." % str(cid))

	# topics
	var topic_ids: Array = []
	var lines: Dictionary = c.get("lines", {}) if typeof(c.get("lines")) == TYPE_DICTIONARY else {}
	var topics: Variant = c.get("topics")
	if typeof(topics) != TYPE_ARRAY or (topics as Array).is_empty():
		errors.append("topics must list at least one question.")
	else:
		for t in topics:
			var tid := str(t.get("id", ""))
			topic_ids.append(tid)
			for key in ["id", "q", "a", "note"]:
				if str(t.get(key, "")) == "":
					errors.append("topic '%s' needs '%s'." % [tid, key])
			for m in t.get("first", ["answer"]):
				if not ["answer", "deflect"].has(str(m)):
					errors.append("topic '%s' has unknown move '%s'." % [tid, str(m)])
				if str(m) == "deflect" and str(t.get("deflect", "")) == "" and not lines.has("deflect"):
					errors.append("topic '%s' can deflect but has no deflect line." % tid)
	for key in ["comply", "stall", "refuse", "reassure", "spent"]:
		if not lines.has(key):
			errors.append("lines.%s is missing." % key)

	# scripted rules
	for r in c.get("script", []):
		var on := str(r.get("on", ""))
		var kind := on.get_slice(":", 0)
		var target := on.get_slice(":", 1)
		if kind == "check":
			if not TOOLS.has(target):
				errors.append("script rule '%s' names an unknown tool." % on)
		elif kind == "ask":
			if not topic_ids.has(target):
				errors.append("script rule '%s' names an unknown topic." % on)
		else:
			errors.append("script rule '%s' must start with check: or ask:." % on)
		if str(r.get("move", "")) == "":
			errors.append("script rule '%s' has no move." % on)

	# pressure and attacks
	var press: Variant = c.get("press")
	var press_attacks := false
	var press_walkout := false
	if typeof(press) != TYPE_ARRAY or (press as Array).is_empty():
		errors.append("press must list at least one reaction.")
	else:
		var first_press: Dictionary = press[0]
		if str(first_press.get("end", "")) != "":
			errors.append("the first press must be a reaction, not an ending.")
		if str(first_press.get("note", "")) == "" or str(first_press.get("line", "")) == "":
			errors.append("the first press needs 'line' and 'note'.")
		for p in press:
			var end := str(p.get("end", ""))
			if not ["", "walkout", "attack"].has(end):
				errors.append("press end '%s' is unknown." % end)
			if end == "attack":
				press_attacks = true
			if end == "walkout":
				press_walkout = true
	var attack: Dictionary = c.get("attack", {}) if typeof(c.get("attack")) == TYPE_DICTIONARY else {}
	var on_refer := bool(attack.get("on_refer", false))
	var can_attack := on_refer or press_attacks
	if not drifting and can_attack:
		errors.append("a stable patient must never attack.")
	if can_attack and str(attack.get("telegraph", "")) == "":
		errors.append("an attack needs a visible telegraph text.")

	# sheet rows: the fixed truth
	var rows: Dictionary = c.get("rows", {}) if typeof(c.get("rows")) == TYPE_DICTIONARY else {}
	var broken := 0
	var broken_reachable := false
	for row in ROWS:
		var spec: Variant = rows.get(row)
		if typeof(spec) != TYPE_DICTIONARY:
			errors.append("rows.%s is missing." % row)
			continue
		if str(spec.get("text", "")) == "":
			errors.append("rows.%s.text is missing." % row)
		var ok := bool(spec.get("ok", true))
		var evidence: Variant = spec.get("evidence")
		if typeof(evidence) != TYPE_ARRAY or (evidence as Array).is_empty():
			errors.append("rows.%s.evidence must list at least one action." % row)
			continue
		var reachable := false
		for e in evidence:
			var key := str(e)
			var k := key.get_slice(":", 0)
			var target := key.get_slice(":", 1)
			if key == "press":
				reachable = true
			elif k == "look" and ZONES.has(target):
				reachable = true
			elif k == "ask" and topic_ids.has(target):
				reachable = true
			elif k == "check" and TOOLS.has(target):
				var spec_check: Dictionary = checks.get(target, {})
				if str(spec_check.get("insist", "")) == "comply":
					reachable = true
			else:
				errors.append("rows.%s has unknown evidence '%s'." % [row, key])
		if not ok:
			broken += 1
			if reachable:
				broken_reachable = true
	if drifting and broken == 0:
		errors.append("a drifting patient needs at least one broken sheet line.")
	var threshold := int(sheet.get("threshold", 1))
	if drifting and broken > 0 and broken < threshold:
		errors.append("a drifting patient needs at least %d broken sheet lines (sheet.json threshold)." % threshold)
	if not drifting and broken > 0:
		errors.append("a stable patient must have no broken sheet line.")
	if drifting and broken > 0 and not broken_reachable:
		errors.append("at least one broken line must be impossible to refuse for good.")
	if rows.has("eyes") and bool(rows["eyes"].get("ok", true)) != eyes_ok:
		errors.append("rows.eyes.ok does not match the eye data.")
	if rows.has("hands") and release > 0 and bool(rows["hands"].get("ok", true)) != (release <= limit):
		errors.append("rows.hands.ok does not match grip.release_ms.")

	# outcome texts
	var outcomes: Dictionary = c.get("outcomes", {}) if typeof(c.get("outcomes")) == TYPE_DICTIONARY else {}
	var needed: Array = ["treat", "refer", "gave_up"]      # anyone can run out of patience
	if drifting:
		needed.append("locked_out")
	else:
		needed.append("false_alarm")
	if press_walkout:
		needed.append("walkout")
	if can_attack:
		needed.append_array(["caught", "hit"])
	for key in needed:
		var o: Variant = outcomes.get(key)
		if typeof(o) != TYPE_DICTIONARY or str(o.get("title", "")) == "" or str(o.get("text", "")) == "":
			errors.append("outcomes.%s needs 'title' and 'text'." % str(key))
	var exit_lines: Dictionary = c.get("exit", {}) if typeof(c.get("exit")) == TYPE_DICTIONARY else {}
	for key in ["treat", "refer", "gave_up"]:
		if str(exit_lines.get(key, "")) == "":
			errors.append("exit.%s is missing." % key)
	return errors
