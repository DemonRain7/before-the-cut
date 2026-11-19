extends RefCounted
## Loads rules.json, sheet.json, parts.json (the spec binder), the case files and contacts.json,
## and checks them before the game uses them. It also assembles each patient's reference sheet
## from the models they wear (sheet_for).
## A data mistake is reported as a readable list instead of a broken visit.
## Used as: const CaseDB = preload("res://scripts/core/case_db.gd")

const Lang = preload("res://scripts/core/lang.gd")

const DATA_DIR := "res://data"
const ROWS := ["eyes", "hands", "port", "speech", "temper"]
const ZONES := ["eyes", "hands", "port"]
const TOOLS := ["penlight", "grip", "port"]
# a patient's parts: one model per slot, from this group of parts.json
const SLOTS := {"eye_l": "eyes", "eye_r": "eyes", "hands": "hands", "port": "ports", "voice": "voices"}
const EYE_SLOT := {"left": "eye_l", "right": "eye_r"}
# the sheet rows one slot's model fills; the eyes row takes both eye slots, and temper has no part
const ROW_SLOT := {"hands": "hands", "port": "port", "speech": "voice"}
const EYE_KINDS := ["natural", "optic", "combat", "display"]   # the close-up's art families
const PUPILS := ["tightens", "shutter", "none"]               # what light should do to an eye model
# what a contact clue may test: data/contacts.json "clues"
const CLUE_TESTS := ["age_min", "age_max", "fee_min", "fee_max", "eyes", "request_starts"]
const EYE_CLUES := ["implants_both", "natural_any"]


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Returns {"rules", "sheet", "parts", "cases": {id: case}, "contacts", "errors": [String]}.
## Each case comes back with its models resolved (resolve_parts).
static func load_all(dir: String = DATA_DIR) -> Dictionary:
	var out := {"rules": {}, "sheet": {}, "parts": {}, "cases": {}, "contacts": {}, "errors": []}
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
	var parts: Variant = load_json(dir + "/parts.json")
	if typeof(parts) != TYPE_DICTIONARY:
		errors.append("parts.json is missing or is not valid JSON.")
	else:
		out["parts"] = parts
		errors.append_array(validate_parts(parts))
	for id in rules.get("shift_order", []):
		var path := "%s/cases/%s.json" % [dir, str(id)]
		var c: Variant = load_json(path)
		if typeof(c) != TYPE_DICTIONARY:
			errors.append("cases/%s.json is missing or is not valid JSON." % str(id))
			continue
		for e in validate_case(c, rules, out["sheet"], out["parts"]):
			errors.append("%s: %s" % [str(id), str(e)])
		resolve_parts(c, out["parts"])
		out["cases"][str(id)] = c
	var contacts: Variant = load_json(dir + "/contacts.json")
	if typeof(contacts) != TYPE_DICTIONARY:
		errors.append("contacts.json is missing or is not valid JSON.")
	else:
		out["contacts"] = contacts
		errors.append_array(validate_contacts(contacts, out["cases"], rules))
	return out


static func validate_rules(rules: Dictionary) -> Array:
	var errors: Array = []
	var order: Variant = rules.get("shift_order")
	if typeof(order) != TYPE_ARRAY or (order as Array).is_empty():
		errors.append("rules.json: shift_order must list at least one case id.")
	# the grip limit is no longer a rule: each hands model has its own (parts.json limit_ms)
	for group in ["costs", "reassure", "attack", "scoring", "line", "patience"]:
		if typeof(rules.get(group)) != TYPE_DICTIONARY:
			errors.append("rules.json: '%s' must be an object." % group)
	if typeof(rules.get("attack")) == TYPE_DICTIONARY:
		errors.append_array(_validate_attack(rules["attack"]))
	if typeof(rules.get("line")) == TYPE_DICTIONARY and int(rules["line"].get("per_hour", -1)) < 0:
		errors.append("rules.json: line.per_hour must be 0 or more.")
	if typeof(rules.get("patience")) == TYPE_DICTIONARY and int(rules["patience"].get("leave_ms", -1)) < 0:
		errors.append("rules.json: patience.leave_ms must be 0 or more.")
	if typeof(rules.get("reassure")) == TYPE_DICTIONARY and int(rules["reassure"].get("cost", 0)) < 0:
		errors.append("rules.json: reassure.cost must be 0 or more (CALM never pays the doctor).")
	errors.append_array(_validate_surprises(rules))
	if rules.has("contacts"):
		var contacts: Variant = rules["contacts"]
		if typeof(contacts) != TYPE_DICTIONARY:
			errors.append("rules.json: 'contacts' must be an object.")
		else:
			for key in ["per_night", "pay", "wrong_cost"]:
				if int(contacts.get(key, -1)) < 0:
					errors.append("rules.json: contacts.%s must be 0 or more." % key)
			if int(contacts.get("per_night", 0)) > 2:
				errors.append("rules.json: contacts.per_night is at most 2 (the list paper has room for two).")
	return errors


## The patient who snaps (drifting only) and the one who flares (anyone). Both groups are
## optional: a rule set without them has nobody snap or flare.
static func _validate_surprises(rules: Dictionary) -> Array:
	var errors: Array = []
	for group in ["snap", "flare"]:
		if not rules.has(group):
			continue
		var g: Variant = rules[group]
		if typeof(g) != TYPE_DICTIONARY:
			errors.append("rules.json: '%s' must be an object." % group)
			continue
		if int(g.get("grace", -1)) < 0:
			errors.append("rules.json: %s.grace must be 0 or more." % group)
		var lo := int(g.get("delay_min_ms", -1))
		var hi := int(g.get("delay_max_ms", -1))
		if lo < 0 or hi < lo:
			errors.append("rules.json: %s.delay_min_ms must be 0 or more and no more than delay_max_ms." % group)
		var odds: Array = ["step", "max"] if group == "snap" else ["chance"]
		for key in odds:
			var v := float(g.get(key, -1.0))
			if v < 0.0 or v > 1.0:
				errors.append("rules.json: %s.%s must be between 0 and 1." % [group, key])
		if group == "snap" and int(g.get("lead_ms", -1)) < 0:
			errors.append("rules.json: snap.lead_ms must be 0 or more.")
	return errors


## Whether this rule set lets a drifting patient snap mid-exam.
static func snaps_on(rules: Dictionary) -> bool:
	var g: Variant = rules.get("snap")
	return typeof(g) == TYPE_DICTIONARY and float(g.get("max", 0.0)) > 0.0 and float(g.get("step", 0.0)) > 0.0


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


## sheet.json holds only what no model changes: the labels, the normals a model may replace,
## the temper row (it has no part, so its fine line lives here as "ordinary"), the titles, the
## house rule and the footer. The eyes row is all models.
static func validate_sheet(sheet: Dictionary) -> Array:
	var errors: Array = []
	var rows: Variant = sheet.get("rows")
	if typeof(rows) != TYPE_ARRAY:
		return ["sheet.json: rows must be a list."]
	var ids: Array = []
	for r in rows:
		var id := str(r.get("id", ""))
		ids.append(id)
		var need: Array = ["label"]
		if id != "eyes":
			need.append("normal")
		if id != "eyes" and not ROW_SLOT.has(id):
			need.append("ordinary")
		for key in need:
			if str(r.get(key, "")) == "":
				errors.append("sheet.json: row '%s' needs '%s'." % [id if id != "" else "?", key])
		if id == "hands" and not str(r.get("normal", "")).contains("{limit}"):
			errors.append("sheet.json: the hands normal must say the model's {limit}.")
	if ids != ROWS:
		errors.append("sheet.json: rows must be exactly %s, in that order." % str(ROWS))
	if not str(sheet.get("title", "")).contains("{name}"):
		errors.append("sheet.json: title must name the patient ({name}).")
	if str(sheet.get("title_none", "")) == "":
		errors.append("sheet.json: title_none (the sheet between patients) is missing.")
	var threshold := int(sheet.get("threshold", 0))
	if threshold < 1 or threshold > ROWS.size():
		errors.append("sheet.json: threshold must be between 1 and %d." % ROWS.size())
	return errors


## The spec binder (data/parts.json): every model of every slot, the pieces a sheet with two
## different eyes is made of, and the baseline body the sheet shows between patients.
static func validate_parts(parts: Dictionary) -> Array:
	var errors: Array = []
	for group in ["eyes", "hands", "ports", "voices"]:
		var models: Variant = parts.get(group)
		if typeof(models) != TYPE_DICTIONARY or (models as Dictionary).is_empty():
			errors.append("parts.json: '%s' must list at least one model." % group)
			continue
		for id in (models as Dictionary).keys():
			var m: Variant = models[id]
			var where := "parts.json: %s.%s" % [group, str(id)]
			if typeof(m) != TYPE_DICTIONARY:
				errors.append(where + " must be an object.")
				continue
			var need: Array = ["tag", "fine"]
			if group == "eyes":
				need.append_array(["both", "one", "fine_one"])
				if not EYE_KINDS.has(str(m.get("kind", ""))):
					errors.append("%s.kind must be one of %s." % [where, str(EYE_KINDS)])
				if not PUPILS.has(str(m.get("pupil", ""))):
					errors.append("%s.pupil must be one of %s." % [where, str(PUPILS)])
			if group == "hands" and int(m.get("limit_ms", 0)) <= 0:
				errors.append(where + ".limit_ms must be positive.")
			for key in need:
				if str(m.get(key, "")) == "":
					errors.append("%s needs '%s'." % [where, key])
	var mixed: Variant = parts.get("eyes_mixed")
	if typeof(mixed) != TYPE_DICTIONARY:
		errors.append("parts.json: eyes_mixed must be an object.")
	else:
		for key in ["normal", "fine", "tag_l", "tag_r", "tag_two"]:
			if str(mixed.get(key, "")) == "":
				errors.append("parts.json: eyes_mixed needs '%s'." % key)
	if typeof(parts.get("baseline")) != TYPE_DICTIONARY:
		errors.append("parts.json: baseline must name a model for every slot.")
	else:
		errors.append_array(_check_slots(parts["baseline"], parts, "parts.json: baseline"))
	return errors


## Every slot names a model the binder has.
static func _check_slots(picks: Dictionary, parts: Dictionary, where: String) -> Array:
	var errors: Array = []
	for slot in SLOTS.keys():
		var model := str(picks.get(slot, ""))
		if model == "":
			errors.append("%s.%s is missing." % [where, slot])
		elif _model(parts, SLOTS[slot], model).is_empty():
			errors.append("%s.%s is '%s', which parts.json %s does not have." % [where, slot, model, SLOTS[slot]])
	return errors


## One model of one group of the binder, or {}.
static func _model(parts: Dictionary, group: String, id: String) -> Dictionary:
	var models: Variant = parts.get(group)
	if typeof(models) != TYPE_DICTIONARY or typeof(models.get(id)) != TYPE_DICTIONARY:
		return {}
	return models[id]


## Writes what the patient's models mean into the case, for the parts of the game that draw or
## time them: each eye gets its model, art kind, pupil and tag, and the grip its model, tag and
## limit_ms. load_all calls it once a case has been checked.
static func resolve_parts(c: Dictionary, parts: Dictionary) -> void:
	var picks: Dictionary = c.get("parts", {}) if typeof(c.get("parts")) == TYPE_DICTIONARY else {}
	var eyes: Dictionary = c.get("eyes", {}) if typeof(c.get("eyes")) == TYPE_DICTIONARY else {}
	for side in EYE_SLOT.keys():
		if typeof(eyes.get(side)) != TYPE_DICTIONARY:
			continue
		var id := str(picks.get(EYE_SLOT[side], ""))
		var m := _model(parts, "eyes", id)
		var eye: Dictionary = eyes[side]
		eye["model"] = id
		eye["kind"] = str(m.get("kind", "natural"))
		eye["pupil"] = str(m.get("pupil", "tightens"))
		eye["tag"] = str(m.get("tag", ""))
	if typeof(c.get("grip")) == TYPE_DICTIONARY:
		var id := str(picks.get("hands", ""))
		var h := _model(parts, "hands", id)
		var grip: Dictionary = c["grip"]
		grip["model"] = id
		grip["tag"] = str(h.get("tag", ""))
		grip["limit_ms"] = int(h.get("limit_ms", 1000))


## The reference sheet for one patient, pulled from the spec binder for the models they wear:
## {"title", "rows": [{id, label, tag, normal, fine}], "threshold", "footer", "limit_s"}.
## With no patient (an empty case) it is the binder's baseline body under title_none.
## limit_s is the hands model's limit, in seconds.
static func sheet_for(c: Dictionary, sheet: Dictionary, parts: Dictionary) -> Dictionary:
	var picks: Dictionary = parts.get("baseline", {}) if typeof(parts.get("baseline")) == TYPE_DICTIONARY else {}
	var title := str(sheet.get("title_none", ""))
	if typeof(c.get("parts")) == TYPE_DICTIONARY:
		picks = c["parts"]
		title = _fill(str(sheet.get("title", "")), {"name": str(c.get("name", "")).to_upper()})
	var limit_ms := int(_model(parts, "hands", str(picks.get("hands", ""))).get("limit_ms", 1000))
	var rows: Array = []
	for r in sheet.get("rows", []):
		var base: Dictionary = r
		var id := str(base.get("id", ""))
		var row := {"id": id, "label": str(base.get("label", "")), "tag": "",
			"normal": str(base.get("normal", "")), "fine": str(base.get("ordinary", ""))}
		if id == "eyes":
			_eyes_row(row, picks, parts)
		elif ROW_SLOT.has(id):
			var slot: String = ROW_SLOT[id]
			var m := _model(parts, SLOTS[slot], str(picks.get(slot, "")))
			row["tag"] = str(m.get("tag", ""))
			row["fine"] = str(m.get("fine", ""))
			if str(m.get("normal", "")) != "":
				row["normal"] = str(m["normal"])
		row["normal"] = _fill(str(row["normal"]), {"limit": seconds(limit_ms)})
		rows.append(row)
	return {"title": title, "rows": rows, "threshold": int(sheet.get("threshold", 0)),
		"footer": sheet.get("footer", []), "limit_s": float(limit_ms) / 1000.0}


## The eyes row: one model's own lines when both eyes are that model, otherwise eyes_mixed
## filled with each eye's part (L is the patient's left eye).
static func _eyes_row(row: Dictionary, picks: Dictionary, parts: Dictionary) -> void:
	var l_id := str(picks.get("eye_l", ""))
	var r_id := str(picks.get("eye_r", ""))
	var l := _model(parts, "eyes", l_id)
	var r := _model(parts, "eyes", r_id)
	if l_id == r_id:
		row["tag"] = str(l.get("tag", ""))
		row["normal"] = str(l.get("both", ""))
		row["fine"] = str(l.get("fine", ""))
		return
	var mixed: Dictionary = parts.get("eyes_mixed", {}) if typeof(parts.get("eyes_mixed")) == TYPE_DICTIONARY else {}
	row["normal"] = _fill(str(mixed.get("normal", "")), {"l": str(l.get("one", "")), "r": str(r.get("one", ""))})
	row["fine"] = _fill(str(mixed.get("fine", "")), {"l": str(l.get("fine_one", "")), "r": str(r.get("fine_one", ""))})
	if str(r.get("kind", "")) == "natural":
		row["tag"] = _fill(str(mixed.get("tag_l", "")), {"tag": str(l.get("tag", ""))})
	elif str(l.get("kind", "")) == "natural":
		row["tag"] = _fill(str(mixed.get("tag_r", "")), {"tag": str(r.get("tag", ""))})
	else:
		row["tag"] = str(mixed.get("tag_two", ""))


## A limit as the sheet prints it: 1500 is "1.5".
static func seconds(ms: int) -> String:
	return "%.1f" % (float(ms) / 1000.0)


## The sheet's words with the patient's values put in, in the player's language: a sheet is
## pulled when a visit starts, and the language only changes on the title card.
static func _fill(text: String, values: Dictionary) -> String:
	return Lang.fill(text, values)


static func _need_text(c: Dictionary, key: String, errors: Array) -> void:
	if typeof(c.get(key)) != TYPE_STRING or str(c[key]) == "":
		errors.append("'%s' must be a non-empty string." % key)


## `sheet` is only needed for its threshold: how many broken lines the house rule asks for.
## `parts` is the spec binder (data/parts.json) the patient's models come from.
static func validate_case(c: Dictionary, rules: Dictionary, sheet: Dictionary = {}, parts: Dictionary = {}) -> Array:
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

	# parts: one model per slot, all from the binder
	var picks: Dictionary = c.get("parts", {}) if typeof(c.get("parts")) == TYPE_DICTIONARY else {}
	if parts.is_empty():
		errors.append("there is no spec binder (parts.json) to check the parts against.")
	elif typeof(c.get("parts")) != TYPE_DICTIONARY:
		errors.append("parts must name a model for each of %s." % str(SLOTS.keys()))
	else:
		errors.append_array(_check_slots(picks, parts, "parts"))

	# eyes, grip, port: what the patient's own parts do, against what their models should
	var eyes: Dictionary = c.get("eyes", {}) if typeof(c.get("eyes")) == TYPE_DICTIONARY else {}
	var eyes_ok := true
	for side in EYE_SLOT.keys():
		var eye: Variant = eyes.get(side)
		if typeof(eye) != TYPE_DICTIONARY:
			errors.append("eyes.%s is missing." % side)
			continue
		var model := _model(parts, "eyes", str(picks.get(EYE_SLOT[side], "")))
		var pupil := str(model.get("pupil", "tightens"))
		var tightens := bool(eye.get("tightens", pupil != "none"))
		if pupil == "none" and tightens:
			errors.append("eyes.%s cannot tighten: a %s has no pupil." % [side, str(model.get("tag", "?"))])
		if not bool(eye.get("follows", true)):
			eyes_ok = false
		if pupil != "none" and not tightens:
			eyes_ok = false
	var grip: Dictionary = c.get("grip", {}) if typeof(c.get("grip")) == TYPE_DICTIONARY else {}
	var release := int(grip.get("release_ms", 0))
	if release <= 0:
		errors.append("grip.release_ms must be positive.")
	var limit := int(_model(parts, "hands", str(picks.get("hands", ""))).get("limit_ms", 0))
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
	for key in ["comply", "stall", "refuse", "reassure", "spent", "code"]:
		if not lines.has(key):
			errors.append("lines.%s is missing." % key)
	# the shout at the glass anyone may give once a visit (rules.json "flare")
	var flare: Variant = c.get("flare")
	if typeof(flare) != TYPE_DICTIONARY:
		errors.append("flare must be an object with 'line', 'note', 'face' and 'hands'.")
	else:
		for key in ["line", "note", "face", "hands"]:
			if str(flare.get(key, "")) == "":
				errors.append("flare.%s is missing." % key)

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
	# with snaps on, any drifting patient can turn mid-exam
	if drifting and snaps_on(rules):
		can_attack = true
		if str(attack.get("line", "")) == "":
			errors.append("a drifting patient can snap, so attack.line is needed.")
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
	if rows.has("hands") and release > 0 and limit > 0 and bool(rows["hands"].get("ok", true)) != (release <= limit):
		errors.append("rows.hands.ok does not match grip.release_ms and the hands model's limit (%d ms)." % limit)

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


# ------------------------------------------------------------------ contacts
## Whether one clue of data/contacts.json fits one case. Every test a clue names must hold.
## The eye tests read the eyes' kinds as resolve_parts wrote them.
static func clue_fits(clue: Dictionary, c: Dictionary) -> bool:
	var age := int(c.get("age", 0))
	var fee := int(c.get("fee", 0))
	if clue.has("age_min") and age < int(clue["age_min"]):
		return false
	if clue.has("age_max") and age > int(clue["age_max"]):
		return false
	if clue.has("fee_min") and fee < int(clue["fee_min"]):
		return false
	if clue.has("fee_max") and fee > int(clue["fee_max"]):
		return false
	if clue.has("request_starts") and not str(c.get("request", "")).begins_with(str(clue["request_starts"])):
		return false
	if clue.has("eyes"):
		var natural := 0
		var eyes: Dictionary = c.get("eyes", {}) if typeof(c.get("eyes")) == TYPE_DICTIONARY else {}
		for side in ["left", "right"]:
			var eye: Variant = eyes.get(side)
			if typeof(eye) == TYPE_DICTIONARY and str(eye.get("kind", "")) == "natural":
				natural += 1
		match str(clue["eyes"]):
			"implants_both":
				if natural > 0:
					return false
			"natural_any":
				if natural == 0:
					return false
			_:
				return false
	return true


## The case ids (of `cases`) that a clue fits, sorted.
static func clue_matches(clue: Dictionary, cases: Dictionary) -> Array:
	var out: Array = []
	for id in cases.keys():
		if clue_fits(clue, cases[id]):
			out.append(str(id))
	out.sort()
	return out


## The contact list must be fair: a clue alone never points at one visitor, the two clues of an
## entry together point at exactly its own, and no two entries share an alias or a code line.
static func validate_contacts(contacts: Dictionary, cases: Dictionary, rules: Dictionary) -> Array:
	var errors: Array = []
	var clues: Variant = contacts.get("clues")
	var pool: Variant = contacts.get("pool")
	if typeof(clues) != TYPE_DICTIONARY:
		errors.append("contacts.json: clues must be an object.")
		return errors
	if typeof(pool) != TYPE_ARRAY:
		errors.append("contacts.json: pool must be a list.")
		return errors
	for cid in (clues as Dictionary).keys():
		var clue: Variant = clues[cid]
		if typeof(clue) != TYPE_DICTIONARY or str(clue.get("text", "")) == "":
			errors.append("contacts.json: clue '%s' needs 'text'." % str(cid))
			continue
		var tests := 0
		for key in (clue as Dictionary).keys():
			if str(key) == "text":
				continue
			if not CLUE_TESTS.has(str(key)):
				errors.append("contacts.json: clue '%s' has unknown test '%s'." % [str(cid), str(key)])
			tests += 1
		if tests == 0:
			errors.append("contacts.json: clue '%s' tests nothing." % str(cid))
		if clue.has("eyes") and not EYE_CLUES.has(str(clue["eyes"])):
			errors.append("contacts.json: clue '%s' eyes must be one of %s." % [str(cid), str(EYE_CLUES)])
		if not cases.is_empty() and clue_matches(clue, cases).size() < 2:
			errors.append("contacts.json: clue '%s' fits fewer than two visitors, so alone it gives one away." % str(cid))
	var ids: Array = []
	var aliases: Array = []
	var says: Array = []
	var couriers: Dictionary = {}
	for e in pool:
		if typeof(e) != TYPE_DICTIONARY:
			errors.append("contacts.json: every pool entry must be an object.")
			continue
		var id := str(e.get("id", ""))
		for key in ["id", "case", "alias", "say", "answer", "package"]:
			if str(e.get(key, "")) == "":
				errors.append("contacts.json: entry '%s' needs '%s'." % [id, key])
		if ids.has(id):
			errors.append("contacts.json: entry id '%s' is used twice." % id)
		ids.append(id)
		var alias := str(e.get("alias", ""))
		if aliases.has(alias):
			errors.append("contacts.json: alias '%s' is used twice." % alias)
		aliases.append(alias)
		var say := str(e.get("say", ""))
		if says.has(say):
			errors.append("contacts.json: entry '%s' shares its code line with another." % id)
		says.append(say)
		var case_id := str(e.get("case", ""))
		if not cases.is_empty() and not cases.has(case_id):
			errors.append("contacts.json: entry '%s' names unknown visitor '%s'." % [id, case_id])
			continue
		couriers[case_id] = true
		var used: Variant = e.get("clues")
		if typeof(used) != TYPE_ARRAY or (used as Array).size() != 2:
			errors.append("contacts.json: entry '%s' must give exactly two clues." % id)
			continue
		var fits: Array = []
		for k in cases.keys():
			fits.append(str(k))
		var known := true
		for cl in used:
			if not (clues as Dictionary).has(str(cl)):
				errors.append("contacts.json: entry '%s' uses unknown clue '%s'." % [id, str(cl)])
				known = false
				continue
			var matched := clue_matches(clues[str(cl)], cases)
			var kept: Array = []
			for f in fits:
				if matched.has(str(f)):
					kept.append(str(f))
			fits = kept
		if known and not cases.is_empty() and (fits.size() != 1 or str(fits[0]) != case_id):
			errors.append("contacts.json: entry '%s' clues fit %s, not just '%s'." % [id, str(fits), case_id])
	var per_night := 0
	if typeof(rules.get("contacts")) == TYPE_DICTIONARY:
		per_night = int(rules["contacts"].get("per_night", 0))
	if per_night > couriers.size():
		errors.append("contacts.json: the rules ask for %d contacts a night but only %d visitors can be one." % [per_night, couriers.size()])
	return errors
