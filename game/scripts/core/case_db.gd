extends RefCounted
## Loads rules.json, sheet.json, parts.json (the spec binder), the characters (cases/<id>.json),
## the test nights (nights.json) and contacts.json, and checks them before the game uses them.
## It also assembles each patient's reference sheet from the models they wear (sheet_for).
## A data mistake is reported as a readable list instead of a broken visit.
##
## A character file (version 3) is a template: who the patient is, which never changes, and for
## each sheet row the ways that part of them can be on a night ("signs": normal ones and broken
## ones). A night gives each visitor a truth and one sign per row (ShiftState.draw_night, or a
## test night of nights.json); compose() turns template and pick into the case a visit plays,
## in the shape every other script reads. Every pick a night could make is composed and checked
## when the data loads (validate_template).
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


## Returns {"rules", "sheet", "parts", "templates": {id: template}, "nights": {name: night},
## "people": {id: case}, "cases": {id: case}, "contacts", "errors": [String]}.
## templates are the characters of rules.json `roster` as written. people is each of them
## composed steady with every part normal: what no night changes (age, fee, request, models),
## for the contact clues. cases is test night A composed (the night as it was written before
## the signs were drawn), in the order rules.json `shift_order` lists it. Every case comes back
## with its models resolved (resolve_parts).
static func load_all(dir: String = DATA_DIR) -> Dictionary:
	var out := {"rules": {}, "sheet": {}, "parts": {}, "templates": {}, "nights": {}, "people": {},
		"cases": {}, "contacts": {}, "errors": []}
	var errors: Array = out["errors"]
	var rules: Variant = load_json(dir + "/rules.json")
	if typeof(rules) != TYPE_DICTIONARY:
		errors.append("rules.json is missing or is not valid JSON.")
		return out
	out["rules"] = rules
	var sheet: Variant = load_json(dir + "/sheet.json")
	if typeof(sheet) != TYPE_DICTIONARY:
		errors.append("sheet.json is missing or is not valid JSON.")
	else:
		sheet["threshold"] = int(rules.get("visit", {}).get("threshold", sheet.get("threshold", 2)))
		out["sheet"] = sheet
		errors.append_array(validate_sheet(sheet))
	errors.append_array(validate_rules(rules, out["sheet"]))
	var parts: Variant = load_json(dir + "/parts.json")
	if typeof(parts) != TYPE_DICTIONARY:
		errors.append("parts.json is missing or is not valid JSON.")
	else:
		out["parts"] = parts
		errors.append_array(validate_parts(parts))
	for id in roster_of(rules):
		var path := "%s/cases/%s.json" % [dir, str(id)]
		var t: Variant = load_json(path)
		if typeof(t) != TYPE_DICTIONARY:
			errors.append("cases/%s.json is missing or is not valid JSON." % str(id))
			continue
		for e in validate_template(t, rules, out["sheet"], out["parts"]):
			errors.append("%s: %s" % [str(id), str(e)])
		var zh: Variant = load_json("%s/lang/zh/cases/%s.json" % [dir, id])
		if typeof(zh) != TYPE_DICTIONARY:
			zh = {}
		for row in ["eyes", "hands", "port", "temper", "none"]:
			var line := str(t.get("complaints", {}).get(row, ""))
			var translation := str(zh.get("strings", {}).get(line, ""))
			if line.is_empty() or line.length() > 90 or translation.is_empty() or translation.length() > 45:
				errors.append("%s: invalid bilingual complaint for %s." % [id, row])
		out["templates"][str(id)] = t
		var person := compose(t, {"truth": "stable"})
		if not person.is_empty():
			resolve_parts(person, out["parts"])
			out["people"][str(id)] = person
	var nights: Variant = load_json(dir + "/nights.json")
	if typeof(nights) != TYPE_DICTIONARY or typeof(nights.get("nights")) != TYPE_DICTIONARY:
		errors.append("nights.json is missing, is not valid JSON or has no 'nights'.")
	else:
		out["nights"] = nights["nights"]
	var contacts: Variant = load_json(dir + "/contacts.json")
	if typeof(contacts) != TYPE_DICTIONARY:
		errors.append("contacts.json is missing or is not valid JSON.")
	else:
		out["contacts"] = contacts
		errors.append_array(validate_contacts(contacts, out["people"], rules))
	errors.append_array(validate_nights(out["nights"], out["templates"], rules, out["sheet"], out["parts"],
		out["people"], out["contacts"]))
	var night_a: Variant = (out["nights"] as Dictionary).get("A")
	if typeof(night_a) == TYPE_DICTIONARY:
		out["cases"] = compose_night(out["templates"], night_a, out["parts"])
		var order: Variant = rules.get("shift_order")
		if typeof(order) == TYPE_ARRAY and night_order(night_a) != _strings(order):
			errors.append("nights.json: night A must list rules.json shift_order, in that order.")
	else:
		errors.append("nights.json: night A (the night as written, for --authored-order) is missing.")
	return out


## The items of a list as strings.
static func _strings(list: Array) -> Array:
	var out: Array = []
	for v in list:
		out.append(str(v))
	return out


## Who can come in on a night: rules.json `roster`, or the authored `shift_order` when a rule
## set has no roster.
static func roster_of(rules: Dictionary) -> Array:
	var r: Variant = rules.get("roster")
	if typeof(r) == TYPE_ARRAY and not (r as Array).is_empty():
		return (r as Array).duplicate()
	return (rules.get("shift_order", []) as Array).duplicate()


# ------------------------------------------------------------------ characters and nights
# the tool that tests a row (speech and temper have none: a question, a push)
const ROW_TOOL := {"eyes": "penlight", "hands": "grip", "port": "port"}


## A dictionary inside `d` under `key`, made when it is missing or is not a dictionary.
static func _dict(d: Dictionary, key: String) -> Dictionary:
	if typeof(d.get(key)) != TYPE_DICTIONARY:
		d[key] = {}
	return d[key]


## One sign of a template's row: {"sign": {...}, "ok": true for a normal one}, or {} when the row
## has no sign with that id. An empty id is the row's first normal sign.
static func find_sign(t: Dictionary, row: String, id: String = "") -> Dictionary:
	var signs: Variant = t.get("signs")
	if typeof(signs) != TYPE_DICTIONARY or typeof(signs.get(row)) != TYPE_DICTIONARY:
		return {}
	for kind in ["normal", "broken"]:
		var list: Variant = signs[row].get(kind)
		if typeof(list) != TYPE_ARRAY:
			continue
		for s in list:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			if str(s.get("id", "")) == id or (id == "" and kind == "normal"):
				return {"sign": s, "ok": kind == "normal"}
	return {}


## The ids of one row's signs of one kind ("normal" or "broken"), in file order.
static func sign_ids(t: Dictionary, row: String, kind: String) -> Array:
	var out: Array = []
	var signs: Variant = t.get("signs")
	if typeof(signs) != TYPE_DICTIONARY or typeof(signs.get(row)) != TYPE_DICTIONARY:
		return out
	var list: Variant = signs[row].get(kind)
	if typeof(list) == TYPE_ARRAY:
		for s in list:
			if typeof(s) == TYPE_DICTIONARY:
				out.append(str(s.get("id", "")))
	return out


## The rows on which a broken sign of this character can be found whatever the patient says:
## the eyes and the grip when insisting gets the test done, the port when it shows or insisting
## gets it checked, and speech and temper always.
static func reachable_rows(t: Dictionary) -> Array:
	var out := []
	for row in ROWS:
		if not sign_ids(t, row, "broken").is_empty():
			out.append(row)
	return out


## The case one night plays: the character's template with the night's truth and one sign per
## row put in, in the shape the visit, the patient, the close-ups and the report read (a case of
## version 2 had all of it written out). pick is {"truth": "stable" or "drifting",
## "signs": {row: sign id}}; a row the pick leaves out takes its first normal sign. Returns {}
## when the pick names a sign the template does not have. The case lists the signs it was made
## with in "signs" ({row: id}), and a port sign with dark threads sets port.threads.
static func compose(t: Dictionary, pick: Dictionary) -> Dictionary:
	var truth := str(pick.get("truth", "stable"))
	var drifting := truth == "drifting"
	var chosen: Dictionary = pick.get("signs", {}) if typeof(pick.get("signs")) == TYPE_DICTIONARY else {}
	var c: Dictionary = t.duplicate(true)
	for key in ["signs", "outcomes", "press_end"]:
		c.erase(key)
	c["truth"] = truth
	c["complaint_rows"] = (pick.get("complaints", []) as Array).duplicate()
	var checks := _dict(c, "checks")
	var lines := _dict(c, "lines")
	var rows := {}
	var used := {}
	for row in ROWS:
		var found := find_sign(t, row, str(chosen.get(row, "")))
		if found.is_empty():
			return {}
		var sign: Dictionary = (found["sign"] as Dictionary).duplicate(true)
		used[row] = str(sign.get("id", ""))
		var evidence: Array = []
		match row:
			"eyes":
				var eyes := _dict(c, "eyes")
				var own: Dictionary = sign.get("eyes", {}) if typeof(sign.get("eyes")) == TYPE_DICTIONARY else {}
				for side in EYE_SLOT.keys():
					if typeof(own.get(side)) == TYPE_DICTIONARY:
						_dict(eyes, side).merge(own[side], true)
				evidence = ["check:penlight"]
			"hands":
				c["grip"] = sign.get("grip", {})
				if sign.has("after"):
					lines["after:grip"] = sign["after"]
				evidence = ["check:grip"]
			"port":
				var port := _dict(c, "port")
				if bool(sign.get("threads", false)):
					port["threads"] = true
				evidence = ["check:port"]
			"speech":
				var answers: Dictionary = sign.get("answers", {}) if typeof(sign.get("answers")) == TYPE_DICTIONARY else {}
				var asked: Array = []
				for topic in c.get("topics", []):
					if typeof(topic) != TYPE_DICTIONARY:
						continue
					var tid := str(topic.get("id", ""))
					asked.append(tid)
					var said: Dictionary = answers.get(tid, {}) if typeof(answers.get(tid)) == TYPE_DICTIONARY else {}
					topic["a"] = str(said.get("a", ""))
					topic["note"] = str(said.get("note", ""))
				var told: Variant = sign.get("evidence")
				if typeof(told) == TYPE_ARRAY and not (told as Array).is_empty():
					asked = told as Array
				for tid in asked:
					evidence.append("ask:" + str(tid))
			"temper":
				var ends: Dictionary = t.get("press_end", {}) if typeof(t.get("press_end")) == TYPE_DICTIONARY else {}
				var end := "attack" if drifting else "walkout"
				c["press"] = [sign.get("press", {}), {"line": str(ends.get(end, "")), "end": end}]
				c["flare"] = sign.get("flare", {})
				evidence = ["press"]
		if ROW_TOOL.has(row) and typeof(checks.get(ROW_TOOL[row])) == TYPE_DICTIONARY:
			checks[ROW_TOOL[row]]["note"] = str(sign.get("note", ""))
		rows[row] = {"ok": bool(found["ok"]), "text": str(sign.get("text", "")), "evidence": evidence}
	c["rows"] = rows
	c["signs"] = used
	c["normal_speech_sign"] = str(find_sign(t, "speech").get("sign", {}).get("id", ""))
	if not drifting:
		c["attack"] = {"on_refer": false, "telegraph": "", "line": ""}
	var outcomes: Variant = t.get("outcomes")
	c["outcomes"] = {}
	if typeof(outcomes) == TYPE_DICTIONARY and typeof(outcomes.get(truth)) == TYPE_DICTIONARY:
		c["outcomes"] = (outcomes[truth] as Dictionary).duplicate(true)
	return c


## A pick in a few words, for the error list: "steady" or "drifting: eyes dead, speech it".
static func describe_pick(pick: Dictionary) -> String:
	var signs: Dictionary = pick.get("signs", {}) if typeof(pick.get("signs")) == TYPE_DICTIONARY else {}
	var parts_said: Array = []
	for row in ROWS:
		if signs.has(row):
			parts_said.append("%s %s" % [row, str(signs[row])])
	var head := "steady" if str(pick.get("truth", "")) == "stable" else str(pick.get("truth", ""))
	return head if parts_said.is_empty() else "%s: %s" % [head, ", ".join(parts_said)]


## Enough of the picks a night could make for one character to check every sign in its place:
## steady with each normal sign, drifting with each set of broken rows a night may draw (at least
## `threshold` of them on rows the doctor can reach, reachable_rows) and drifting with each
## further broken sign.
static func check_picks(t: Dictionary, threshold: int) -> Array:
	var picks: Array = [{"truth": "stable", "signs": {}}]
	for row in ROWS:
		for id in sign_ids(t, row, "normal").slice(1):
			picks.append({"truth": "stable", "signs": {row: id}})
	var reach := reachable_rows(t)
	for mask in range(1, 1 << ROWS.size()):
		var signs := {}
		var reached := 0
		for i in ROWS.size():
			if mask & (1 << i):
				var ids := sign_ids(t, ROWS[i], "broken")
				signs[ROWS[i]] = str(ids[0]) if not ids.is_empty() else ""
				if reach.has(ROWS[i]):
					reached += 1
		if reached >= threshold:
			picks.append({"truth": "drifting", "signs": signs})
	for row in ROWS:
		for id in sign_ids(t, row, "broken").slice(1):
			var signs := {row: id}
			var reached := 1 if reach.has(row) else 0
			for other in reach:
				if reached >= threshold:
					break
				var ids := sign_ids(t, str(other), "broken")
				if str(other) == row or ids.is_empty():
					continue
				signs[str(other)] = str(ids[0])
				reached += 1
			picks.append({"truth": "drifting", "signs": signs})
	return picks


## A character file (version 3): what every night shares, then the picks of check_picks(),
## each composed and checked as the case it would be (validate_case). An error found in several
## picks is listed once, with the first pick it was found in.
static func validate_template(t: Dictionary, rules: Dictionary, sheet: Dictionary = {}, parts: Dictionary = {}) -> Array:
	var errors: Array = []
	var intake: Variant = t.get("intake")
	if typeof(intake) != TYPE_DICTIONARY or intake.get("part") not in ["eyes", "hands", "voice", "port", "reflex"]:
		errors.append("intake.part needs the implant named in the registration.")
	if typeof(intake) != TYPE_DICTIONARY or typeof(intake.get("terms")) != TYPE_ARRAY or intake.terms.is_empty():
		errors.append("intake.terms needs the names players can quote from the documents.")
	for key in ["filed", "slip", "account", "clear", "gap", "firm", "flat"]:
		if typeof(intake) != TYPE_DICTIONARY or typeof(intake.get(key)) != TYPE_STRING or str(intake[key]).strip_edges().is_empty():
			errors.append("intake.%s needs a line for the patient's file." % key)
	if int(t.get("version", 0)) != 3:
		errors.append("version must be 3 (a character whose signs each night draws).")
	if t.has("truth"):
		errors.append("a character has no truth of its own: each night gives one.")
	var signs: Variant = t.get("signs")
	if typeof(signs) != TYPE_DICTIONARY:
		errors.append("signs must give each sheet row its normal and broken signs.")
		return errors
	var covered := typeof(t.get("port")) == TYPE_DICTIONARY and bool(t["port"].get("covered", false))
	for row in ROWS:
		var spec: Variant = signs.get(row)
		if typeof(spec) != TYPE_DICTIONARY:
			errors.append("signs.%s is missing." % row)
			continue
		var seen: Array = []
		for kind in ["normal", "broken"]:
			var list: Variant = spec.get(kind)
			if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
				errors.append("signs.%s.%s must list at least one sign: any part can be fine or broken on a night." % [row, kind])
				continue
			for s in list:
				var id := str(s.get("id", "")) if typeof(s) == TYPE_DICTIONARY else ""
				if id == "":
					errors.append("signs.%s.%s: every sign needs an id." % [row, kind])
					continue
				if seen.has(id):
					errors.append("signs.%s: sign id '%s' is used twice." % [row, id])
				seen.append(id)
				if row == "port" and kind == "normal" and bool(s.get("threads", false)):
					errors.append("signs.port.%s: a normal port has no dark threads." % id)
				if row == "port" and covered and s.has("look"):
					errors.append("signs.port.%s: the port is covered, so a glance cannot show it (no 'look')." % id)
	var words: Variant = t.get("press_words")
	for stage in ["push", "warning"]:
		if typeof(words) != TYPE_DICTIONARY or typeof(words.get(stage)) != TYPE_STRING or str(words[stage]).strip_edges().is_empty():
			errors.append("press_words.%s needs a line shared by both diagnoses." % stage)
	var ends: Variant = t.get("press_end")
	for end in ["walkout", "attack"]:
		if typeof(ends) != TYPE_DICTIONARY or str(ends.get(end, "")) == "":
			errors.append("press_end.%s is missing for the final push." % end)
	var outcomes: Variant = t.get("outcomes")
	for truth in ["stable", "drifting"]:
		if typeof(outcomes) != TYPE_DICTIONARY or typeof(outcomes.get(truth)) != TYPE_DICTIONARY:
			errors.append("outcomes.%s is missing." % truth)
	var attack: Variant = t.get("attack")
	if typeof(attack) != TYPE_DICTIONARY or str(attack.get("telegraph", "")) == "" or str(attack.get("line", "")) == "":
		errors.append("attack needs 'telegraph' and 'line': on a night this character drifts, they can turn.")
	var threshold := maxi(1, int(sheet.get("threshold", 1)))
	var reach := reachable_rows(t)
	if reach.size() < threshold:
		errors.append("only %d rows (%s) can be tested whatever the patient says; a drifting night needs %d." % [reach.size(), ", ".join(reach), threshold])
	if not errors.is_empty():
		return errors
	var found := {}
	for pick in check_picks(t, int(sheet.get("threshold", 1))):
		var c := compose(t, pick)
		if c.is_empty():
			errors.append("the pick (%s) names a sign the file does not have." % describe_pick(pick))
			continue
		for e in validate_case(c, rules, sheet, parts):
			if not found.has(e):
				found[e] = true
				errors.append("%s (%s)" % [str(e), describe_pick(pick)])
	return errors


## A night's cases in the order its visitors come: {id: case}, each composed and resolved.
## night is {"visitors": [{"id", "truth", "signs"?}]} (nights.json or ShiftState.draw_night).
static func compose_night(templates: Dictionary, night: Dictionary, parts: Dictionary) -> Dictionary:
	var out := {}
	for v in night.get("visitors", []):
		if typeof(v) != TYPE_DICTIONARY or not templates.has(str(v.get("id", ""))):
			continue
		var c := compose(templates[str(v["id"])], v)
		if c.is_empty():
			continue
		resolve_parts(c, parts)
		out[str(v["id"])] = c
	return out


## The ids of a night's visitors, in order.
static func night_order(night: Dictionary) -> Array:
	var out: Array = []
	for v in night.get("visitors", []):
		if typeof(v) == TYPE_DICTIONARY:
			out.append(str(v.get("id", "")))
	return out


## The test nights of nights.json: each lists its visitors in order, each with a truth and, for
## any row that should show a particular sign, that sign. Each visitor is composed and checked as
## the case it would be, so a drifting one shows at least the house rule's count of broken lines
## the doctor can reach and a steady one shows none. With rules.json `night` and the people of
## the roster, each test night must also be one the draw could make on the first night of a
## session (night_drawable): a test night is a night of the game, only not left to chance.
static func validate_nights(nights: Dictionary, templates: Dictionary, rules: Dictionary, sheet: Dictionary = {},
		parts: Dictionary = {}, people: Dictionary = {}, contacts: Dictionary = {}) -> Array:
	var errors: Array = []
	for night_name in nights.keys():
		var where := "nights.json: night %s" % str(night_name)
		var night: Variant = nights[night_name]
		var visitors: Variant = night.get("visitors") if typeof(night) == TYPE_DICTIONARY else null
		if typeof(visitors) != TYPE_ARRAY or (visitors as Array).is_empty():
			errors.append(where + " must list its visitors.")
			continue
		var seen: Array = []
		var composed := {}
		var sound := true
		for v in visitors:
			var id := str(v.get("id", "")) if typeof(v) == TYPE_DICTIONARY else ""
			if not templates.has(id):
				errors.append("%s: visitor '%s' is not on the roster." % [where, id])
				sound = false
				continue
			if seen.has(id):
				errors.append("%s: %s comes twice." % [where, id])
				sound = false
			seen.append(id)
			var truth := str(v.get("truth", ""))
			if not (truth == "stable" or truth == "drifting"):
				errors.append("%s: %s needs truth 'stable' or 'drifting'." % [where, id])
				sound = false
				continue
			if v.has("complaints"):
				var unique := {}
				if typeof(v.complaints) != TYPE_ARRAY:
					errors.append(where + ": complaints must be a list.")
				else:
					for row in v.complaints:
						if row not in ["eyes", "hands", "port", "temper"] or unique.has(row):
							errors.append(where + ": invalid or duplicate complaint.")
						unique[row] = true
					if seen.size() == 1 and unique.size() != 1:
						errors.append(where + ": opening visitor needs exactly one complaint.")
			var pick := {"truth": truth, "signs": v.get("signs", {})}
			var c := compose(templates[id], pick)
			if c.is_empty():
				errors.append("%s: %s names a sign its file does not have (%s)." % [where, id, describe_pick(pick)])
				sound = false
				continue
			resolve_parts(c, parts)
			composed[id] = c
			for e in validate_case(c, rules, sheet, parts):
				errors.append("%s: %s: %s" % [where, id, str(e)])
		if sound and not people.is_empty():
			for e in night_drawable(rules, night, composed, people, contacts):
				errors.append("%s: %s" % [where, str(e)])
	return errors


## Why the draw (ShiftState.draw_night) could not have made this night, or [] when it could:
## rules.json night.visitors visitors; a number of them drifting that night.drifting gives a
## weight; for each drifting one a number of broken rows that night.broken gives a weight; fees
## inside fee_window; at least contacts.per_night visitors who can carry a fair contact
## (fair_couriers); and on the first night of a session (first_of_session), with
## first_opens_steady, a steady first visitor who can carry one, so the training visit can show
## a code. cases is the night composed ({id: case}); people is CaseDB.people.
static func night_drawable(rules: Dictionary, night: Dictionary, cases: Dictionary, people: Dictionary, contacts: Dictionary,
		first_of_session: bool = true) -> Array:
	var errors: Array = []
	var spec: Variant = rules.get("night")
	if typeof(spec) != TYPE_DICTIONARY:
		return errors
	var ids := night_order(night)
	var want := int(spec.get("visitors", ids.size()))
	if ids.size() != want:
		errors.append("it has %d visitors, and rules.json night.visitors asks for %d." % [ids.size(), want])
	var drifting: Array = []
	for id in ids:
		if typeof(cases.get(id)) == TYPE_DICTIONARY and str(cases[id].get("truth", "")) == "drifting":
			drifting.append(id)
	var counts: Variant = spec.get("drifting")
	if typeof(counts) == TYPE_DICTIONARY and not (counts as Dictionary).has(str(drifting.size())):
		errors.append("%d of its visitors drift; rules.json night.drifting never draws that many." % drifting.size())
	for id in ids:
		if not drifting.has(id) and cases.has(id):
			var worn := broken_count(cases[id])
			if worn > 1 or (worn > 0 and first_of_session and id == ids[0] and spec.get("wear", {}).get("first_protected", true)):
				errors.append("%s has wear that cannot be drawn in this slot." % id)
	var broken: Variant = spec.get("broken")
	for id in drifting:
		var n := broken_count(cases[id])
		if typeof(broken) == TYPE_DICTIONARY and not (broken as Dictionary).has(str(n)):
			errors.append("%s shows %d broken rows; rules.json night.broken never draws that many." % [id, n])
	var couriers := fair_couriers(contacts, cases, ids)
	if couriers != fair_couriers(contacts, people, ids):
		errors.append("The composed signs changed a contact clue.")
	if first_of_session and bool(spec.get("first_opens_steady", false)) and not ids.is_empty():
		var first := str(ids[0])
		if drifting.has(first):
			errors.append("its first visitor, %s, drifts; the first night of a session opens with a steady visitor." % first)
		if not couriers.has(first):
			errors.append("its first visitor, %s, has no fair contact entry tonight, so the training visit could not show a code." % first)
	var window := fee_window(rules, ids.size())
	var fees := fees_of(people, ids)
	if not window.is_empty() and (fees < int(window[0]) or fees > int(window[1])):
		errors.append("its visitors' fees add up to %d; rules.json night.fees_under_line asks for %d to %d." % [fees, int(window[0]), int(window[1])])
	var per := 0
	if typeof(rules.get("contacts")) == TYPE_DICTIONARY:
		per = int(rules["contacts"].get("per_night", 0))
	if couriers.size() < mini(per, ids.size()):
		errors.append("only %d of its visitors can carry a fair contact; rules.json contacts.per_night asks for %d." % [couriers.size(), per])
	return errors


## How many sheet rows of a composed case show a broken sign.
static func broken_count(c: Dictionary) -> int:
	var n := 0
	var rows: Variant = c.get("rows")
	if typeof(rows) != TYPE_DICTIONARY:
		return n
	for row in ROWS:
		var r: Variant = rows.get(row)
		if typeof(r) == TYPE_DICTIONARY and not bool(r.get("ok", true)):
			n += 1
	return n


## What a night's fees must add up to under rules.json night.fees_under_line, as [low, high]:
## less than the line (line.per_hour for each visitor), and no less than the line less one drop
## (contacts.pay). So right calls alone never hold the line, and one drop can. [] when the rule
## is off.
static func fee_window(rules: Dictionary, visitors: int) -> Array:
	var spec: Variant = rules.get("night")
	if typeof(spec) != TYPE_DICTIONARY or not bool(spec.get("fees_under_line", false)):
		return []
	var line := 0
	if typeof(rules.get("line")) == TYPE_DICTIONARY:
		line = int(rules["line"].get("per_hour", 0)) * visitors
	var pay := 0
	if typeof(rules.get("contacts")) == TYPE_DICTIONARY:
		pay = int(rules["contacts"].get("pay", 0))
	return [line - pay, line - 1]


## Whether these visitors' fees fall inside fee_window (always, when the rule is off).
static func fees_fit(rules: Dictionary, people: Dictionary, ids: Array) -> bool:
	var window := fee_window(rules, ids.size())
	if window.is_empty():
		return true
	var fees := fees_of(people, ids)
	return fees >= int(window[0]) and fees <= int(window[1])


## What these visitors' fees add up to. people is CaseDB.people (or any {id: case}).
static func fees_of(people: Dictionary, ids: Array) -> int:
	var fees := 0
	for id in ids:
		var p: Variant = people.get(str(id))
		if typeof(p) == TYPE_DICTIONARY:
			fees += int(p.get("fee", 0))
	return fees


## What the test nights leave unseen: a character never steady or never drifting, or a sign
## never shown. The rule checks ask for nothing unseen, so every character's every look, and
## every attack, comes up on some test night.
static func night_coverage(nights: Dictionary, templates: Dictionary) -> Array:
	var seen := {}
	var wear := {}
	for night in nights.values():
		if typeof(night) != TYPE_DICTIONARY:
			continue
		for v in night.get("visitors", []):
			var id := str(v.get("id", "")) if typeof(v) == TYPE_DICTIONARY else ""
			if not templates.has(id):
				continue
			var c := compose(templates[id], {"truth": str(v.get("truth", "")), "signs": v.get("signs", {})})
			if c.is_empty():
				continue
			seen["%s:%s" % [id, str(c["truth"])]] = true
			for row in ROWS:
				seen["%s:%s:%s" % [id, row, str(c["signs"].get(row, ""))]] = true
				if c.truth == "stable" and not c.rows[row].ok:
					wear[row] = true
	var missing: Array = []
	for row in ROWS:
		if not wear.has(row):
			missing.append("no steady visitor shows wear on " + str(row))
	for id in templates.keys():
		for truth in ["stable", "drifting"]:
			if not seen.has("%s:%s" % [str(id), truth]):
				missing.append("%s is never %s" % [str(id), "steady" if truth == "stable" else truth])
		for row in ROWS:
			for kind in ["normal", "broken"]:
				for sid in sign_ids(templates[id], row, kind):
					if not seen.has("%s:%s:%s" % [str(id), row, str(sid)]):
						missing.append("%s's %s sign '%s' is never shown" % [str(id), row, str(sid)])
	return missing


## rules.json. sheet (sheet.json) gives the house rule's threshold, the fewest broken rows a
## drifting visitor may be drawn with.
static func validate_rules(rules: Dictionary, sheet: Dictionary = {}) -> Array:
	var errors: Array = []
	var order: Variant = rules.get("shift_order")
	if typeof(order) != TYPE_ARRAY or (order as Array).is_empty():
		errors.append("rules.json: shift_order must list at least one case id.")
	var roster: Variant = rules.get("roster")
	if rules.has("roster") and (typeof(roster) != TYPE_ARRAY or (roster as Array).is_empty()):
		errors.append("rules.json: roster must list at least one character id.")
	if rules.has("night"):
		errors.append_array(_validate_night(rules, maxi(1, int(sheet.get("threshold", 1)))))
	# the grip limit is no longer a rule: each hands model has its own (parts.json limit_ms)
	for group in ["visit", "complaints", "costs", "attack", "scoring", "line", "patience"]:
		if typeof(rules.get(group)) != TYPE_DICTIONARY:
			errors.append("rules.json: '%s' must be an object." % group)
	if typeof(rules.get("attack")) == TYPE_DICTIONARY:
		errors.append_array(_validate_attack(rules["attack"]))
	if typeof(rules.get("line")) == TYPE_DICTIONARY and int(rules["line"].get("per_hour", -1)) < 0:
		errors.append("rules.json: line.per_hour must be 0 or more.")
	if typeof(rules.get("patience")) == TYPE_DICTIONARY and int(rules["patience"].get("leave_ms", -1)) < 0:
		errors.append("rules.json: patience.leave_ms must be 0 or more.")
	if typeof(rules.get("patience")) == TYPE_DICTIONARY:
		var patience: Dictionary = rules.patience
		for key in ["end_chance", "tell_chance"]:
			var curve: Array = patience.get(key, []) if patience.get(key) is Array else []
			if curve.size() != 4 or int(patience.get("press_limit", 0)) != curve.size():
				errors.append("patience.%s needs one chance for each of four pushes." % key)
				continue
			var previous := 0.0
			for chance in curve:
				if typeof(chance) not in [TYPE_INT, TYPE_FLOAT] or float(chance) <= previous or float(chance) > 1.0:
					errors.append("patience.%s must rise on each push and stay within 1." % key)
					break
				previous = float(chance)
			if key == "end_chance" and curve.back() != 1.0:
				errors.append("The last push must end the visit.")
	if int(rules.get("visit", {}).get("lamps", 0)) < 1:
		errors.append("visit.lamps must be positive.")
	var leads: Dictionary = rules.get("complaints", {})
	for key in ["broken", "normal"]:
		if float(leads.get(key, -1)) < 0 or float(leads.get(key, 2)) > 1:
			errors.append("complaints.%s must be a probability." % key)
	if int(leads.get("per_reply", 0)) < 1:
		errors.append("complaints.per_reply must be positive.")
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


## rules.json `night`, how a night is drawn (ShiftState.draw_night): a number of visitors the
## roster can fill; for how many of them drift and how many rows a drifting one shows broken,
## each number with a positive weight. A drifting visitor shows at least `threshold` broken rows
## (the house rule), at most one per row, and with first_opens_steady one visitor is left to
## open the night steady.
static func _validate_night(rules: Dictionary, threshold: int) -> Array:
	var errors: Array = []
	var spec: Variant = rules["night"]
	if typeof(spec) != TYPE_DICTIONARY:
		return ["rules.json: 'night' must be an object."]
	var visitors := int(spec.get("visitors", 0))
	var size := roster_of(rules).size()
	if visitors < 1 or visitors > size:
		errors.append("rules.json: night.visitors must be from 1 to the size of the roster (%d)." % size)
	var steady_first := bool(spec.get("first_opens_steady", false))
	for key in ["drifting", "broken"]:
		var w: Variant = spec.get(key)
		if typeof(w) != TYPE_DICTIONARY or (w as Dictionary).is_empty():
			errors.append("rules.json: night.%s must give at least one number and its weight." % key)
			continue
		var lo := threshold if key == "broken" else 0
		var hi := ROWS.size() if key == "broken" else visitors - (1 if steady_first else 0)
		for count in (w as Dictionary).keys():
			var n := int(str(count)) if str(count).is_valid_int() else -1
			if n < lo or n > hi or float(w[count]) <= 0.0:
				errors.append("rules.json: night.%s: '%s' must be a number from %d to %d with a positive weight." % [key, str(count), lo, hi])
	if spec.has("wear"):
		var wear: Dictionary = spec.wear
		var chance := float(wear.get("chance", -1.0))
		var total := 0.0
		for row in ROWS:
			var weight := float(wear.get("weights", {}).get(row, -1))
			if weight < 0:
				errors.append("night.wear weights must be nonnegative for each row.")
			total += maxf(weight, 0.0)
		if chance < 0 or chance > 1 or total <= 0:
			errors.append("night.wear needs a probability and at least one weighted row.")
	if int(spec.get("tries", 0)) < 1:
		errors.append("rules.json: night.tries must be at least 1.")
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

	# Reactions are flavour. Every completed test supplies a reading.
	var claims: Dictionary = c.get("claims", {}) if typeof(c.get("claims")) == TYPE_DICTIONARY else {}
	var checks: Dictionary = c.get("checks", {}) if typeof(c.get("checks")) == TYPE_DICTIONARY else {}
	for tool in TOOLS:
		var spec: Variant = checks.get(tool)
		if typeof(spec) != TYPE_DICTIONARY:
			errors.append("checks.%s is missing." % tool)
			continue
		if str(spec.get("note", "")) == "":
			errors.append("checks.%s.note is missing." % tool)
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
	for key in ["comply", "stall", "spent", "code"]:
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
	var broken_reachable := 0
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
			elif k == "ask" and topic_ids.has(target):
				reachable = true
			elif k == "check" and TOOLS.has(target):
				reachable = true
			else:
				errors.append("rows.%s has unknown evidence '%s'." % [row, key])
		if not ok:
			broken += 1
			if reachable:
				broken_reachable += 1
	if drifting and broken == 0:
		errors.append("a drifting patient needs at least one broken sheet line.")
	var threshold := int(sheet.get("threshold", 1))
	if drifting and broken > 0 and broken < threshold:
		errors.append("a drifting patient needs at least %d broken sheet lines (sheet.json threshold)." % threshold)
	if not drifting and broken > 1:
		errors.append("a stable patient can show at most one worn line.")
	if drifting and broken > 0 and broken_reachable == 0:
		errors.append("at least one broken line must be impossible to refuse for good.")
	elif drifting and broken >= threshold and broken_reachable < threshold:
		# the house rule must be reachable: a doctor who does everything can find enough lines
		errors.append("only %d broken lines can be found whatever the patient says; the house rule asks for %d." % [broken_reachable, threshold])
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


## The contact list as written: every clue fits at least two people of the roster, every entry's
## two clues both fit its own courier, and the aliases and codes that each night draws onto its
## entries (ShiftState.name_contacts) are all different and enough for a night. An entry has no
## alias or code of its own (contacts.json version 2). Whether an entry is fair on a night
## depends on who else comes in, so each night keeps only the fair ones (fair_contacts). `cases`
## is CaseDB.people (or any {id: case}).
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
	var couriers: Dictionary = {}
	for e in pool:
		if typeof(e) != TYPE_DICTIONARY:
			errors.append("contacts.json: every pool entry must be an object.")
			continue
		var id := str(e.get("id", ""))
		for key in ["id", "case", "package"]:
			if str(e.get(key, "")) == "":
				errors.append("contacts.json: entry '%s' needs '%s'." % [id, key])
		for key in ["alias", "say", "answer"]:
			if (e as Dictionary).has(key):
				errors.append("contacts.json: entry '%s' has its own '%s'; each night draws it from aliases and codes." % [id, key])
		if ids.has(id):
			errors.append("contacts.json: entry id '%s' is used twice." % id)
		ids.append(id)
		var case_id := str(e.get("case", ""))
		if not cases.is_empty() and not cases.has(case_id):
			errors.append("contacts.json: entry '%s' names unknown visitor '%s'." % [id, case_id])
			continue
		couriers[case_id] = true
		var used: Variant = e.get("clues")
		if typeof(used) != TYPE_ARRAY or (used as Array).size() != 2:
			errors.append("contacts.json: entry '%s' must give exactly two clues." % id)
			continue
		for cl in used:
			if not (clues as Dictionary).has(str(cl)):
				errors.append("contacts.json: entry '%s' uses unknown clue '%s'." % [id, str(cl)])
			elif cases.has(case_id) and not clue_fits(clues[str(cl)], cases[case_id]):
				errors.append("contacts.json: entry '%s' clue '%s' does not fit its own courier '%s'." % [id, str(cl), case_id])
	# the words each night draws onto its entries
	var aliases: Array = []
	if typeof(contacts.get("aliases")) != TYPE_ARRAY:
		errors.append("contacts.json: aliases must be a list.")
	else:
		for a in contacts["aliases"]:
			var alias := str(a).strip_edges()
			if alias == "":
				errors.append("contacts.json: an alias is empty.")
			elif aliases.has(alias):
				errors.append("contacts.json: alias '%s' is used twice." % alias)
			aliases.append(alias)
	var says: Array = []
	if typeof(contacts.get("codes")) != TYPE_ARRAY:
		errors.append("contacts.json: codes must be a list.")
	else:
		for code in contacts["codes"]:
			if typeof(code) != TYPE_DICTIONARY or str(code.get("say", "")) == "" or str(code.get("answer", "")) == "":
				errors.append("contacts.json: every code needs 'say' and 'answer'.")
				continue
			var say := str(code["say"])
			if says.has(say):
				errors.append("contacts.json: the code line '%s' is used twice." % say)
			says.append(say)
	var per_night := 0
	if typeof(rules.get("contacts")) == TYPE_DICTIONARY:
		per_night = int(rules["contacts"].get("per_night", 0))
	if per_night > couriers.size():
		errors.append("contacts.json: the rules ask for %d contacts a night but only %d visitors can be one." % [per_night, couriers.size()])
	if per_night > aliases.size():
		errors.append("contacts.json: the rules ask for %d contacts a night but only %d aliases are listed." % [per_night, aliases.size()])
	if per_night > says.size():
		errors.append("contacts.json: the rules ask for %d contacts a night but only %d codes are listed." % [per_night, says.size()])
	return errors


## The pool entries that are fair tonight, in list order: the courier comes in tonight (`ids`),
## each clue fits at least two of tonight's visitors, so alone it gives nobody away, and the two
## together fit the courier and nobody else who comes in. `people` is CaseDB.people.
static func fair_contacts(contacts: Dictionary, people: Dictionary, ids: Array) -> Array:
	var out: Array = []
	var clues: Variant = contacts.get("clues")
	var pool: Variant = contacts.get("pool")
	if typeof(clues) != TYPE_DICTIONARY or typeof(pool) != TYPE_ARRAY:
		return out
	var tonight := {}
	for id in ids:
		if people.has(str(id)):
			tonight[str(id)] = people[str(id)]
	for e in pool:
		if typeof(e) != TYPE_DICTIONARY or not tonight.has(str(e.get("case", ""))):
			continue
		var used: Variant = e.get("clues")
		if typeof(used) != TYPE_ARRAY or (used as Array).size() != 2:
			continue
		var fits: Array = tonight.keys()
		var fair := true
		for cl in used:
			if not (clues as Dictionary).has(str(cl)):
				fair = false
				break
			var matched := clue_matches(clues[str(cl)], tonight)
			if matched.size() < 2:
				fair = false
				break
			var kept: Array = []
			for f in fits:
				if matched.has(str(f)):
					kept.append(str(f))
			fits = kept
		if fair and fits.size() == 1 and str(fits[0]) == str(e["case"]):
			out.append(e)
	return out


## Tonight's visitors who can carry a fair contact (fair_contacts), in the order they come.
static func fair_couriers(contacts: Dictionary, people: Dictionary, ids: Array) -> Array:
	var have := {}
	for e in fair_contacts(contacts, people, ids):
		have[str((e as Dictionary).get("case", ""))] = true
	var out: Array = []
	for id in ids:
		if have.has(str(id)):
			out.append(str(id))
	return out
