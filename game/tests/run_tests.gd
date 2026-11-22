extends SceneTree
## Headless rule tests for the reference-sheet loop (case data version 3, rules version 9,
## sheet version 4, parts version 1, contacts version 1, nights version 1). The second decision is a call to
## Trauma Team; in the rules and the data its id is "refer". Rules version 4 added the hourly
## line, the patient who leaves when patience runs out, and the counter glass that remembers
## every blow for the rest of the shift. Rules version 5 lets the doctor pay, between patients,
## to have a layer of that glass refitted. Rules version 6 adds tonight's contacts and their
## codes, a CALM that costs credits, a line that right calls alone no longer hold, and the
## patient who snaps or flares. Rules version 7 moves the grip limit into the spec binder
## (data/parts.json): a patient is a set of parts, and the sheet is pulled for their models.
## Rules version 8 tells right and wrong only at closing, and a patient who gets through the
## window ends the night. Rules version 9 draws each night from the seed (who comes, who drifts,
## and which sign each row shows: any row of anyone can be the broken one), makes Trauma Team's
## bounty the patient's fee, paid on account at the counter, and puts the line at 400 an hour.
## Run from the repository root:  godot --headless --path game --script res://tests/run_tests.gd
## These check program rules only. They are not a playtest and say nothing about fun.

const CaseDB = preload("res://scripts/core/case_db.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const ShiftState = preload("res://scripts/core/shift_state.gd")
const ScriptedBrain = preload("res://scripts/core/scripted_brain.gd")
const PatientAgent = preload("res://scripts/core/patient_agent.gd")
const MoveValidator = preload("res://scripts/core/move_validator.gd")
const VoiceClip = preload("res://scripts/core/voice_clip.gd")
const VoiceInput = preload("res://scripts/core/voice_input.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Clipboard = preload("res://scripts/ui/clipboard.gd")
const MainScript = preload("res://scripts/ui/main.gd")
const ClinicView = preload("res://scripts/ui/clinic_view.gd")

const NOTE_MAX_PX := 186   # width of the note column on the patient record
## The layers every patient's bust carries (tools/art/gen_patients.py): the face and hands of
## the visit, and the turn and the three poses of the attack, each in a copy for --less-blood.
const BUST_LAYERS := ["body", "head", "lids", "pupils", "brows_angry", "brows_neutral", "brows_worried",
	"mouth_a", "mouth_b", "mouth_closed", "mouth_angry", "mouth_upset", "hands_a", "hands_b", "hands_react",
	"turn", "turn_clean", "mouth_turn", "mouth_turn_b", "mouth_turn_clean", "mouth_turn_b_clean",
	"attack", "attack_b", "attack_s1", "attack_s1_b", "attack_s2", "attack_s2_b",
	"attack_s1_clean", "attack_s1_b_clean", "attack_s2_clean", "attack_s2_b_clean"]
## Every patient's close-ups (tools/art/gen_scopes.py): the penlight, the grip and the port.
const SCOPE_FILES := ["eyes_back", "eyes_front", "iris_l", "iris_r", "grip_open", "grip_closed", "port", "port_threads"]
const SHEET_TEXT_ROOM := 182.0    # the sheet's text column (tools/art/measure_text.py "sheet")
const SHEET_TITLE_ROOM := 220.0   # the rule under the sheet's title

var passed := 0
var failed := 0
var rules: Dictionary = {}
var sheet: Dictionary = {}
var parts: Dictionary = {}
var cases: Dictionary = {}
var templates: Dictionary = {}
var contacts_data: Dictionary = {}


class FakeClient:
	extends RefCounted
	var reply: Dictionary = {}
	var calls := 0
	func request_move(_payload: Dictionary) -> Dictionary:
		calls += 1
		return reply


class IntentClient:
	extends RefCounted
	var reply := {"ok": true, "data": {"about": "none", "intent": "social"}}
	var calls := 0
	func request_intent(_payload: Dictionary) -> Dictionary:
		calls += 1
		return reply


## Stands in for the proxy's speech route. `hold` keeps the words back until `released` is
## emitted, the way a slow speech service would.
class VoiceClient:
	extends RefCounted
	signal released
	var reply: Dictionary = {}
	var calls := 0
	var last: Dictionary = {}
	var hold := false
	func is_configured() -> bool:
		return true
	func request_move(_payload: Dictionary) -> Dictionary:
		return {"ok": false, "error": "timeout"}
	func request_transcript(payload: Dictionary) -> Dictionary:
		calls += 1
		last = payload
		if hold:
			await released
		return reply


func ok(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func eq(a: Variant, b: Variant, label: String) -> void:
	if a == b:
		passed += 1
	else:
		failed += 1
		print("FAIL: %s (got %s, expected %s)" % [label, str(a), str(b)])


func visit(id: String) -> VisitState:
	return VisitState.new((cases[id] as Dictionary).duplicate(true), rules)


func brain_move(v: VisitState, kind: String, id: String, brain: ScriptedBrain = null) -> Dictionary:
	if brain == null:
		brain = ScriptedBrain.new(1)
	var legal: Array = v.legal_moves_for_check(id) if kind == "check" else v.legal_moves_for_ask(id)
	return brain.decide(v.case_data, {"type": kind, "id": id}, v.snapshot(), legal)


func _initialize() -> void:
	# English whatever language a player saved: the checks below read English words
	Lang.pin("en")
	var db: Dictionary = CaseDB.load_all()
	eq(db["errors"], [], "shipped data validates")
	rules = db["rules"]
	sheet = db["sheet"]
	parts = db["parts"]
	cases = db["cases"]
	templates = db["templates"]
	contacts_data = db["contacts"]
	test_data()
	test_art()
	test_parts()
	test_verdict_any_time()
	test_complaints()
	test_checks()
	test_talk()
	test_press_and_attack()
	test_shutter()
	test_patience_walkout()
	test_marks()
	test_settlement_rows()
	test_generated_speech_findings()
	await test_patient_rules_match()
	await test_patient_beats()
	test_counter_and_closing()
	test_shift()
	test_line()
	test_glass()
	test_repair()
	test_night_draw()
	test_wear_distribution()
	test_contacts()
	test_codes()
	test_surprises()
	test_brain()
	await test_agent()
	await test_conversation()
	await test_visit_intent_cache()
	test_visit_record()
	test_validator()
	await test_offline_say()
	await test_voice()
	test_note_room()
	test_bad_data()
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_data() -> void:
	eq(rules["shift_order"], ["kip", "rook", "vale", "juno", "maren"], "shift order")
	eq(cases.size(), 5, "five cases load")
	var drifting := 0
	for id in cases.keys():
		if str(cases[id]["truth"]) == "drifting":
			drifting += 1
	eq(drifting, 2, "two drifting patients, three stable")
	var font: Font = load("res://assets/fonts/counter.fnt")
	ok(font != null, "record font loads")
	if font == null:
		return
	for id in cases.keys():
		var c: Dictionary = cases[id]
		var texts: Array = []
		ok(not c.has("looks"), "no diagnostic look on the counter")
		for t in c["checks"].keys():
			texts.append(str(c["checks"][t]["note"]).replace("{t}", "0.0"))
		for t in c["topics"]:
			texts.append(str(t["note"]))
		for k in c["claims"].keys():
			texts.append(str(c["claims"][k]["note"]))
		for p in c["press"]:
			if str(p.get("note", "")) != "":
				texts.append(str(p["note"]))
		for text in texts:
			var w: float = font.get_string_size(str(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			ok(w <= NOTE_MAX_PX, "%s note fits one record line (%d px): %s" % [id, int(w), str(text)])


## Any part of anyone can be the one that is wrong tonight, and anyone can turn, so every
## patient carries the art for all of it: the bust's layers, a picture for each gesture the
## temper signs use, dark threads at the port wherever the bust shows the port, the close-ups,
## and the sounds and marks of the weapon.
func test_art() -> void:
	var loaded: Variant = CaseDB.load_json("res://assets/patients/meta.json")
	ok(typeof(loaded) == TYPE_DICTIONARY, "the patients' meta.json loads")
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var meta: Dictionary = loaded
	for id in templates.keys():
		var t: Dictionary = templates[id]
		var pid := str(t.get("sprite", id))
		ok(meta.has(pid), "%s has an entry in the patients' meta" % id)
		if not meta.has(pid):
			continue
		var pm: Dictionary = meta[pid]
		var layers: Array = pm.get("layers", [])
		var missing: Array = []
		for layer in BUST_LAYERS:
			if not layers.has(layer):
				missing.append(layer)
		eq(missing, [], "%s has every layer of the bust and of the attack" % id)
		var unfiled: Array = []
		for layer in layers:
			if not ResourceLoader.exists("res://assets/patients/%s/%s.png" % [pid, str(layer)]):
				unfiled.append(layer)
		eq(unfiled, [], "%s: every layer the meta lists has its picture" % id)
		ok(ResourceLoader.exists("res://assets/patients/%s/hallcam.png" % pid), "%s has a hall-camera silhouette" % id)
		# the weapon
		var attack: Dictionary = pm.get("attack", {})
		var style := str(attack.get("style", ""))
		ok(MainScript.ATTACK_STYLES.has(style), "%s's weapon, '%s', is one the game plays" % [id, style])
		for key in ["hand", "tool", "head", "face"]:
			ok((attack.get(key, []) as Array).size() == 2, "%s's attack says where the %s is" % [id, key])
		# a picture for every gesture of the temper signs
		var gestures: Dictionary = pm.get("gestures", {})
		var used: Array = []
		var temper: Dictionary = (t.get("signs", {}) as Dictionary).get("temper", {})
		for state in ["normal", "broken"]:
			for s in temper.get(state, []):
				for when in ["press", "flare"]:
					var g := str(((s as Dictionary).get(when, {}) as Dictionary).get("hands", ""))
					if g != "" and not used.has(g):
						used.append(g)
		ok(not used.is_empty(), "%s's temper signs move the hands" % id)
		for g in used:
			var named := str(gestures.get(g, ""))
			ok(layers.has(named), "%s's '%s' gesture names its picture (%s)" % [id, g, named])
		# dark threads at the port, wherever the bust shows it
		var any_threads := false
		var hand_threads := false
		for layer in layers:
			if str(layer).ends_with("_t"):
				any_threads = true
				hand_threads = hand_threads or str(layer).begins_with("hands_")
		if not bool((t.get("port", {}) as Dictionary).get("covered", false)):
			ok(any_threads, "%s's port shows on the bust, and the bust can show threads at it" % id)
		if hand_threads:
			var plain: Array = []
			var hand_layers: Array = ["hands_a", "hands_b", "hands_react"]
			for g in used:
				hand_layers.append(str(gestures.get(g, "")))
			for layer in hand_layers:
				if str(layer).begins_with("hands_") and not layers.has(str(layer) + "_t") and not plain.has(layer):
					plain.append(layer)
			eq(plain, [], "%s's port is on the hands, so every picture of the hands can show threads at it" % id)
		# the close-ups
		var gone: Array = []
		for f in SCOPE_FILES:
			if not ResourceLoader.exists("res://assets/scope/%s/%s.png" % [pid, f]):
				gone.append(f)
		eq(gone, [], "%s has every close-up, the port with threads included" % id)
	# every weapon's sounds and marks
	for style in MainScript.ATTACK_STYLES.keys():
		var s: Dictionary = MainScript.ATTACK_STYLES[style]
		var files: Array = ["fx/%s.png" % str(s["mark"])]
		if str(s["strike"]) == "burn":      # a weapon that burns also leaves the mark still glowing
			files.append("fx/%s_hot.png" % str(s["mark"]))
		for key in ["loop", "bite", "knock"]:
			if str(s[key]) != "":
				files.append("audio/%s.wav" % str(s[key]))
		var cut := str(s["cut"])
		if cut != "":
			ok(ClinicView.CUT_ART.has(cut) and MainScript.CUT_AT.has(cut), "the %s's cut, '%s', has its pictures and its place" % [style, cut])
			for path in (ClinicView.CUT_ART.get(cut, {}) as Dictionary).values():
				if typeof(path) == TYPE_STRING:      # the pictures, not the places it bites ("spans", "holes")
					files.append(str(path))
		for i in 3:
			files.append(("fx/dent_deep_%d.png" if bool(s["deep"]) else "fx/dent_%d.png") % i)
		var absent: Array = []
		for f in files:
			if not ResourceLoader.exists("res://assets/" + str(f)):
				absent.append(f)
		eq(absent, [], "the %s's sounds and marks are all there" % style)


## The spec binder (rules version 7, data/parts.json): a patient is a set of parts, one model
## per slot, and the reference sheet on the wall is pulled from the binder for those models.
func test_parts() -> void:
	eq(CaseDB.validate_parts(parts), [], "the shipped spec binder validates")
	# between patients: the baseline body
	var s: Dictionary = CaseDB.sheet_for({}, sheet, parts)
	eq(s["title"], sheet["title_none"], "with nobody at the counter the sheet is headed as the baseline")
	eq([sheet_row(s, "eyes")["tag"], sheet_row(s, "hands")["tag"], sheet_row(s, "port")["tag"]], ["NATURAL", "NATURAL", "STREET"],
		"the baseline body: natural eyes and hands, a street port")
	ok(is_equal_approx(float(s["limit_s"]), 1.0), "and a natural hand's 1 s limit")
	eq(sheet_row(s, "hands")["normal"], "Lets go on 'release' inside 1.0 s.", "the hands normal is filled with that limit")
	eq(sheet_row(s, "temper")["fine"], "Anger, swearing, walking out.", "temper has no part: its line is the sheet's own")
	eq(int(s["threshold"]), int(sheet["threshold"]), "the house rule comes along")
	# each patient's sheet
	s = CaseDB.sheet_for(cases["kip"], sheet, parts)
	eq(s["title"], "REFERENCE SHEET: KIP MARLOW", "a patient's sheet is headed with their name")
	eq(sheet_row(s, "eyes")["tag"], "L KITE", "Kip: a KITE optic in the left eye, a natural right")
	eq(sheet_row(s, "eyes")["normal"], "L: no pupil. R: tightens. Both follow.", "two different eyes: each one's part")
	eq(sheet_row(s, "eyes")["fine"], "L: scuffs, cracks. R: red rims.", "and each one's ordinary")
	s = CaseDB.sheet_for(cases["rook"], sheet, parts)
	eq([sheet_row(s, "hands")["tag"], sheet_row(s, "hands")["normal"]], ["LOADER", "Lets go on 'release' inside 1.5 s."],
		"Rook's LOADER rig is allowed 1.5 s")
	ok(is_equal_approx(float(s["limit_s"]), 1.5), "and the close-up's LIMIT mark goes with it")
	eq(sheet_row(s, "port")["tag"], "WORK", "a work port")
	s = CaseDB.sheet_for(cases["vale"], sheet, parts)
	eq([sheet_row(s, "eyes")["tag"], sheet_row(s, "eyes")["normal"]], ["TALON", "Shutters snap tight in light. Both follow."],
		"Vale: both eyes TALON, so the model's own line")
	eq(sheet_row(s, "port")["normal"], "Calm skin at the plate. No dark threads.", "a MIL-SPEC port gives a normal of its own")
	ok(is_equal_approx(float(s["limit_s"]), 0.3), "REFLEX hands: 0.3 s")
	s = CaseDB.sheet_for(cases["juno"], sheet, parts)
	eq([sheet_row(s, "eyes")["tag"], sheet_row(s, "hands")["tag"], sheet_row(s, "speech")["tag"]], ["IRIS", "DEFT", "VX-9"],
		"Juno: IRIS eyes, DEFT hands, a VX-9 voice box")
	eq(sheet_row(s, "speech")["fine"], "A st-stutter, a skipped word, nerves.", "the voice box's stutter is ordinary for its model")
	ok(is_equal_approx(float(CaseDB.sheet_for(cases["maren"], sheet, parts)["limit_s"]), 0.8), "Maren: SEAM hands, 0.8 s")
	# the sheet follows the parts, not the person
	var other := {"name": "Somebody Else", "parts": (cases["kip"]["parts"] as Dictionary).duplicate()}
	eq(CaseDB.sheet_for(other, sheet, parts)["rows"], CaseDB.sheet_for(cases["kip"], sheet, parts)["rows"],
		"two patients with the same models get the same rows")
	eq([eyes_tag("natural", "talon"), eyes_tag("iris", "natural"), eyes_tag("kite", "iris")], ["R TALON", "L IRIS", "MIXED"],
		"an implant beside a natural eye is named by its side; two different implants are MIXED")
	# loading writes what the models mean into each case
	var vale_l: Dictionary = cases["vale"]["eyes"]["left"]
	eq([vale_l["model"], vale_l["kind"], vale_l["pupil"], vale_l["tag"]], ["talon", "combat", "shutter", "TALON"],
		"each eye gets its model, art family, pupil and tag")
	eq([cases["kip"]["eyes"]["left"]["kind"], cases["kip"]["eyes"]["right"]["kind"]], ["optic", "natural"], "Kip's KITE is drawn as an optic")
	eq([cases["rook"]["grip"]["tag"], int(cases["rook"]["grip"]["limit_ms"])], ["LOADER", 1500], "and the grip gets its hands model's limit")
	# cases checked against the binder
	var c: Dictionary = (cases["kip"] as Dictionary).duplicate(true)
	ok(has_error(CaseDB.validate_case(c, rules, sheet), "no spec binder"), "a case is never passed without the binder")
	c["parts"]["eye_l"] = "hawk"
	ok(has_error(CaseDB.validate_case(c, rules, sheet, parts), "'hawk', which parts.json eyes does not have"), "a model the binder does not have is caught")
	c = (cases["kip"] as Dictionary).duplicate(true)
	c["parts"].erase("voice")
	ok(has_error(CaseDB.validate_case(c, rules, sheet, parts), "parts.voice is missing"), "so is an empty slot")
	c = (cases["juno"] as Dictionary).duplicate(true)
	c["eyes"]["left"]["tightens"] = true
	ok(has_error(CaseDB.validate_case(c, rules, sheet, parts), "cannot tighten"), "an IRIS screen has no pupil to tighten")
	c = (cases["vale"] as Dictionary).duplicate(true)
	for side in ["left", "right"]:
		c["eyes"][side]["tightens"] = true
		c["eyes"][side]["follows"] = true
	ok(has_error(CaseDB.validate_case(c, rules, sheet, parts), "rows.eyes.ok"), "TALON shutters that snap and follow are steady eyes, so the row must say so")
	c = (cases["rook"] as Dictionary).duplicate(true)
	c["parts"]["hands"] = "natural"
	ok(has_error(CaseDB.validate_case(c, rules, sheet, parts), "hands model's limit (1000 ms)"), "Rook's 1.2 s is too slow for natural hands: that row would break")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["parts"]["hands"] = "loader"
	ok(not has_error(CaseDB.validate_case(c, rules, sheet, parts), "rows.hands.ok"), "Maren's 1.7 s is too slow even for a LOADER")
	# a bad binder
	var bad: Dictionary = parts.duplicate(true)
	bad["eyes"]["kite"].erase("pupil")
	ok(has_error(CaseDB.validate_parts(bad), "eyes.kite.pupil"), "an eye model must say what light does to it")
	bad = parts.duplicate(true)
	bad["eyes"]["iris"]["kind"] = "laser"
	ok(has_error(CaseDB.validate_parts(bad), "eyes.iris.kind"), "and which close-up draws it")
	bad = parts.duplicate(true)
	bad["eyes"]["talon"].erase("fine_one")
	ok(has_error(CaseDB.validate_parts(bad), "eyes.talon needs 'fine_one'"), "and its part of a mixed pair")
	bad = parts.duplicate(true)
	bad["hands"]["deft"].erase("limit_ms")
	ok(has_error(CaseDB.validate_parts(bad), "hands.deft.limit_ms"), "a hands model needs its limit")
	bad = parts.duplicate(true)
	bad["ports"]["street"].erase("tag")
	ok(has_error(CaseDB.validate_parts(bad), "ports.street needs 'tag'"), "every model has a code name")
	bad = parts.duplicate(true)
	bad["ports"] = {}
	ok(has_error(CaseDB.validate_parts(bad), "'ports' must list"), "a group with no models is caught")
	bad = parts.duplicate(true)
	bad.erase("eyes_mixed")
	ok(has_error(CaseDB.validate_parts(bad), "eyes_mixed"), "so is a binder that cannot print two different eyes")
	bad = parts.duplicate(true)
	bad["baseline"]["voice"] = "choir"
	ok(has_error(CaseDB.validate_parts(bad), "baseline.voice is 'choir'"), "the baseline body is made of the binder's own models")
	# a bad sheet
	var bad_sheet: Dictionary = sheet.duplicate(true)
	bad_sheet["rows"][1]["normal"] = "Lets go on 'release' quickly."
	ok(has_error(CaseDB.validate_sheet(bad_sheet), "{limit}"), "the hands normal must carry the model's limit")
	bad_sheet = sheet.duplicate(true)
	bad_sheet["title"] = "REFERENCE SHEET"
	ok(has_error(CaseDB.validate_sheet(bad_sheet), "{name}"), "a patient's sheet is headed with their name")
	bad_sheet = sheet.duplicate(true)
	bad_sheet.erase("title_none")
	ok(has_error(CaseDB.validate_sheet(bad_sheet), "title_none"), "and the sheet between patients has a heading of its own")
	bad_sheet = sheet.duplicate(true)
	bad_sheet["rows"][4].erase("ordinary")
	ok(has_error(CaseDB.validate_sheet(bad_sheet), "'temper' needs 'ordinary'"), "temper has no model, so the sheet gives its fine line")
	# every line the binder can put on the sheet fits the paper, in the font the game draws
	var label_room := Clipboard.SHEET_TEXT_X - 408.0 - 3.0
	var fine_x := Gfx.text_w(Clipboard.SHEET_FINE + " ")
	var too_wide: Array = []
	var count := 0
	for each in every_sheet():
		var one: Dictionary = each
		count += 1
		if Gfx.text_w(str(one["title"]), true) > SHEET_TITLE_ROOM:
			too_wide.append(str(one["title"]))
		for r in one["rows"]:
			var row: Dictionary = r
			if Gfx.text_w(str(row["label"]), true) > label_room or Gfx.text_w(str(row["tag"])) > label_room:
				too_wide.append("%s / %s" % [str(row["label"]), str(row["tag"])])
			if Gfx.text_w(str(row["normal"])) > SHEET_TEXT_ROOM:
				too_wide.append(str(row["normal"]))
			if fine_x + Gfx.text_w(str(row["fine"])) > SHEET_TEXT_ROOM:
				too_wide.append("%s %s" % [Clipboard.SHEET_FINE, str(row["fine"])])
	ok(count >= 1 + cases.size() + 16, "the width check covers the baseline, every patient and every pair of eyes (%d sheets)" % count)
	eq(too_wide, [], "every line the binder can print fits the sheet")


## One row of an assembled sheet (CaseDB.sheet_for), or {}.
func sheet_row(s: Dictionary, id: String) -> Dictionary:
	for r in s.get("rows", []):
		if str(r.get("id", "")) == id:
			return r
	return {}


## The eyes row's tag for a patient with these two eye models and the baseline otherwise.
func eyes_tag(left: String, right: String) -> String:
	var picks: Dictionary = (parts["baseline"] as Dictionary).duplicate()
	picks["eye_l"] = left
	picks["eye_r"] = right
	return str(sheet_row(CaseDB.sheet_for({"name": "x", "parts": picks}, sheet, parts), "eyes").get("tag", ""))


## Every sheet the binder can print for one change from the baseline body: the baseline, each
## patient, every pair of eye models, and each model of the other slots.
func every_sheet() -> Array:
	var out: Array = [CaseDB.sheet_for({}, sheet, parts)]
	for id in cases.keys():
		out.append(CaseDB.sheet_for(cases[id], sheet, parts))
	var base: Dictionary = parts["baseline"]
	var eye_ids: Array = (parts["eyes"] as Dictionary).keys()
	for l in eye_ids:
		for r in eye_ids:
			var picks: Dictionary = base.duplicate()
			picks["eye_l"] = l
			picks["eye_r"] = r
			out.append(CaseDB.sheet_for({"name": "Somebody Else", "parts": picks}, sheet, parts))
	for slot in ["hands", "port", "voice"]:
		for m in (parts[CaseDB.SLOTS[slot]] as Dictionary).keys():
			var picks: Dictionary = base.duplicate()
			picks[slot] = m
			out.append(CaseDB.sheet_for({"name": "Somebody Else", "parts": picks}, sheet, parts))
	return out


func test_verdict_any_time() -> void:
	for id in cases.keys():
		var stable := str(cases[id]["truth"]) == "stable"
		var v := visit(id)
		eq(v.verdict("treat")["next"], "done", "%s: treat works with nothing checked" % id)
		eq(v.outcome, "treated_ok" if stable else "treated_drifting", "%s: treat outcome follows truth" % id)
		eq(v.settlement()["correct"], stable, "%s: treat correctness" % id)
		eq(v.settlement()["credits"], int(cases[id]["fee"]) if stable else int(rules["scoring"]["treat_drifting"]),
			"%s: treat credits" % id)
		eq(v.verdict("refer")["next"], "", "%s: no second verdict" % id)
		v = visit(id)
		var next := str(v.verdict("refer")["next"])
		if stable:
			eq(v.outcome, "referred_stable", "%s: needless call to Trauma Team" % id)
			eq(v.settlement()["credits"], int(rules["scoring"]["false_call"]), "%s: the call-out is billed" % id)
			ok(v.settlement()["credits"] < 0, "%s: a needless call costs money" % id)
			ok(not v.settlement()["correct"], "%s: a needless call is not correct" % id)
			eq(v.settlement()["title"], "FALSE CALL", "%s: the slip names the false call" % id)
		elif bool(cases[id]["attack"]["on_refer"]):
			eq(next, "attack", "%s: the call triggers the authored attack" % id)
			eq(v.phase, VisitState.Phase.ATTACK, "%s: attack phase" % id)
		else:
			eq(v.outcome, "referred_drifting", "%s: quiet handover" % id)
			eq(v.settlement()["credits"], int(cases[id]["fee"]) + int(rules["scoring"]["refer_drifting"]), "%s: Trauma Team's bounty is the fee" % id)
			eq(v.settlement()["title"], "TAKEN IN", "%s: the slip names the handover" % id)


func test_complaints() -> void:
	var db := CaseDB.load_all()
	for seed_id in 40:
		var n := ShiftState.draw_night(db, seed_id, true)
		eq(n, ShiftState.draw_night(db, seed_id, true), "the complaint draw is repeatable")
		eq(n.visitors[0].complaints.size(), 1, "one protected opening clue")
		for pick in n.visitors:
			var v := VisitState.new(CaseDB.compose(templates[pick.id], pick), rules)
			var initial := v.snapshot()
			eq(v.patience, 2, "everyone starts with two lamps")
			for part in ["eyes", "hands", "port", "temper"]:
				var choice := v.complain(part)
				var mentioned: bool = part in pick.complaints
				eq(choice.rows, [part] if mentioned else [], "part questions only tell the drawn fact")
				eq(v.notes[part].size(), int(mentioned), "only a delivered fact gets a note")
				ok(not v.row_seen(part), "a complaint never earns a reading")
			eq(v.snapshot().patience, initial.patience, "talk costs no lamps")
			eq(v.actions, 0, "no surprise after talking")
			var fresh := VisitState.new(CaseDB.compose(templates[pick.id], pick), rules)
			var told := fresh.complain()
			eq(told.rows, pick.complaints.slice(0, 2), "general question follows the draw")
			fresh.complain()
			eq(fresh.complaints_told, pick.complaints, "two questions cover all four rows")
			eq(fresh.complain().rows, [], "exhausted list never creates a new note")


func test_checks() -> void:
	for id in templates:
		for tool in VisitState.TOOLS:
			var v := VisitState.new(CaseDB.compose(templates[id], {}), rules)
			for move in v.legal_moves_for_check(tool):
				var first := VisitState.new(v.case_data, rules)
				eq(first.apply_check(tool, move).result, "granted", "every authored reaction opens the instrument")
				eq(first.patience, 1, "every first test costs one lamp")
				ok(first.complete_check(tool).ok and first.row_seen(VisitState.TOOL_ROW[tool]), "completed instrument earns its row")
				eq(first.apply_check(tool, move).cost, 0, "reopening a test is free")
				eq(first.tests_in_order, [VisitState.TOOL_ROW[tool]], "one paid test in the record")


func test_talk() -> void:
	for id in templates:
		var v := VisitState.new(CaseDB.compose(templates[id], {}), rules)
		v.patience = 0
		for q in v.case_data.topics:
			var answer := v.apply_ask(q.id)
			eq(answer.line, q.a, "an authored listed question answers even at zero")
			ok(v.answered.has(q.id) and v.seen.has("ask:" + str(q.id)), "the question ticks only after answering")
			eq(v.apply_ask(q.id).cost, 0, "repeating a question is free")
		eq(v.actions, 0, "all listed questions leave the surprise counter untouched")


func test_press_and_attack() -> void:
	var v := visit("kip")
	eq([v.press_breaks(), v.press_cost()], [false, 1], "PRESS reads temper for one lamp")
	var r := v.press()
	eq(r["result"], "react", "first press is a reaction")
	eq(v.patience, 1, "pressure spends one lamp")
	eq([v.press_breaks(), v.press_cost()], [true, 1], "the next press breaks him, and costs every lamp left")
	ok(v.row_seen("temper"), "the reaction is temper evidence")
	eq(v.phase, VisitState.Phase.EXAM, "one press never ends a visit")
	r = v.press()
	eq(r["result"], "walkout", "a stable patient walks out on the second press")
	eq(v.patience, 0, "and the push that breaks him leaves no lamp lit")
	eq(v.outcome, "walkout", "walkout outcome")
	eq(v.settlement()["credits"], 0, "walkout earns nothing")
	ok(not v.settlement()["correct"], "walkout is not a correct call")
	eq(v.press()["result"], "closed", "no pressing after the visit")

	for id in ["vale", "maren"]:
		v = visit(id)
		eq(v.press()["result"], "react", "%s: first press is safe" % id)
		eq(v.press()["result"], "attack", "%s: second press brings the attack" % id)
		eq(v.patience, 0, "%s: the push that breaks them takes every lamp" % id)
		eq(v.attack_cause, "press", "%s: cause recorded" % id)
		eq(v.shutter()["result"], "caught", "%s: shutter stops it" % id)
		eq(v.settlement()["credits"], int(cases[id]["fee"]) + int(rules["scoring"]["refer_drifting"]) + int(rules["scoring"]["press_catch_bonus"]), "%s: caught pays the bounty and the PRESS bonus" % id)
		ok(v.settlement()["correct"], "%s: caught counts as right" % id)
		v = visit(id)
		v.press()
		v.press()
		eq(v.attack_timeout()["result"], "hit", "%s: too slow" % id)
		eq(v.settlement()["credits"], int(rules["scoring"]["hit"]), "%s: hit penalty" % id)
		ok(v.settlement()["injured"], "%s: injury recorded" % id)
		ok(not v.settlement()["correct"], "%s: provoked and hit is not a right call" % id)

	v = visit("vale")
	v.verdict("refer")
	eq(v.attack_timeout()["result"], "hit", "vale: the attack after the call can land")
	ok(v.settlement()["correct"], "the call itself was right")
	v = visit("vale")
	v.verdict("refer")
	eq(v.shutter()["result"], "caught", "vale: the attack after the call is blocked")
	eq(visit("kip").attack_timeout()["result"], "", "no attack, no timeout")
	for id in ["kip", "rook", "juno"]:
		v = visit(id)
		v.press()
		v.press()
		v.press()
		ok(v.phase != VisitState.Phase.ATTACK, "%s: a stable patient never attacks" % id)


func test_shutter() -> void:
	var v := visit("juno")
	eq(v.shutter()["result"], "false_alarm", "shutter on a stable patient is a false alarm")
	eq(v.settlement()["credits"], int(rules["scoring"]["false_alarm"]), "false alarm penalty")
	v = visit("maren")
	eq(v.shutter()["result"], "locked_out", "shutter on a drifting patient locks them out")
	eq(v.settlement()["credits"], 0, "locked out pays nothing")
	ok(v.settlement()["correct"], "locked out was the right side of the call")
	eq(v.shutter()["result"], "", "shutter does nothing after the visit")


## Patience (rules version 4): at 0 the patient gives an ultimatum and, unless the player decides
## or reassures them, leaves by themselves: no fee, no bill, no call. The director runs the
## clock; these check the rule.
func test_patience_walkout() -> void:
	for id in templates:
		var v := VisitState.new(CaseDB.compose(templates[id], {}), rules)
		v.apply_check("port", "comply")
		v.apply_check("grip", "comply")
		ok(v.is_spent() and v.press_breaks(), "BREAK reachable even without a prior PRESS")
		eq(v.leave_ms(), 30000, "empty bar waits thirty idle seconds")
		eq(v.apply_check("penlight", "comply").result, "spent", "no new test after two")
		eq(v.apply_check("port", "comply").cost, 0, "reopen while empty")
		eq(v.give_up().result, "gave_up", "empty visitor can leave")
		eq(v.settlement().credits, 0, "gave up is unpaid")


## The player's own ticks and crosses, and the house rule they are counted against (sheet
## version 3). The count is advice: it never scores, gates or changes anything.
func test_marks() -> void:
	var threshold := int(sheet["threshold"])
	eq(threshold, 2, "the house rule asks for two broken lines")
	ok(str(sheet["footer"][0]).to_lower().contains("two broken lines"), "and the sheet prints it")
	for id in cases.keys():
		var broken := 0
		for row in VisitState.ROWS:
			if not bool(cases[id]["rows"][row]["ok"]):
				broken += 1
		if str(cases[id]["truth"]) == "drifting":
			ok(broken >= threshold, "%s: a drifting patient breaks at least the house rule's number of lines (%d)" % [id, broken])
		else:
			eq(broken, 0, "%s: a steady patient breaks none" % id)
	var v := visit("maren")
	eq([v.crossed(), v.ticked()], [0, 0], "a new record has no marks")
	v.cycle_mark("eyes")
	eq([v.crossed(), v.ticked()], [0, 1], "first click: a tick")
	v.cycle_mark("eyes")
	eq([v.crossed(), v.ticked()], [1, 0], "second click: a cross")
	v.cycle_mark("hands")
	v.cycle_mark("hands")
	eq(v.crossed(), 2, "two crossed lines are counted")
	v.cycle_mark("hands")
	eq(v.crossed(), 1, "a third click clears the mark again")
	v.cycle_mark("hands")
	v.cycle_mark("hands")
	eq(v.cycle_mark("nose"), 0, "a row that is not on the sheet cannot be marked")
	eq(v.patience, v.patience_max, "marking costs no patience")
	ok(v.seen.is_empty(), "and is not evidence")
	eq(v.verdict("treat")["next"], "done", "two crosses do not stop a TREAT stamp")
	var s := v.settlement()
	eq(s["crossed"], 2, "the slip carries the count")
	eq(s["credits"], int(rules["scoring"]["treat_drifting"]), "and the marks changed nothing about the result")


func test_settlement_rows() -> void:
	var v := visit("maren")
	v.apply_check("penlight", "comply")
	v.complete_check("penlight")
	v.cycle_mark("eyes")
	v.cycle_mark("eyes")
	v.verdict("refer")
	var s := v.settlement()
	eq(s["title"], "TAKEN IN", "outcome title from the case")
	var rows: Array = s["rows"]
	eq(rows.size(), 5, "five rows on the report")
	ok(not bool(rows[0]["ok"]) and bool(rows[0]["seen"]), "eyes: broken and seen")
	eq(int(rows[0]["mark"]), 2, "player mark is carried to the report")
	ok(not bool(rows[1]["ok"]) and not bool(rows[1]["seen"]), "hands: broken, not checked")
	ok(bool(rows[2]["ok"]), "maren's port is fine")


## Right and wrong are told at closing (rules version 8): the slip's words, its sound and the
## counter's money are the same whoever the patient was; the rest comes in with the night's
## reports. Every visit's counter money and closing money make the whole of it.
func test_counter_and_closing() -> void:
	var counter: Dictionary = rules["counter"]
	for key in ["treated", "referred", "caught", "shutter", "walkout", "gave_up"]:
		var entry: Dictionary = counter.get(key, {})
		ok(str(entry.get("title", "")) != "" and str(entry.get("text", "")).contains("{name}"), "the slip has words for '%s'" % key)
	var fee_kip := int(cases["kip"]["fee"])
	var fee_maren := int(cases["maren"]["fee"])
	# treated: the steady and the drifting print the same slip and pay the same way
	var steady := visit("kip")
	steady.verdict("treat")
	var drifting := visit("maren")
	drifting.verdict("treat")
	var a := steady.settlement()
	var b := drifting.settlement()
	eq([a["counter_title"], a["counter_text"], a["call"]], [b["counter_title"], b["counter_text"], b["call"]],
		"treating somebody steady and somebody drifting prints the same slip")
	eq([a["counter_fee"], b["counter_fee"]], [fee_kip, fee_maren], "and the counter takes the fee from both")
	eq([a["closing"], b["closing"]], [0, int(rules["scoring"]["treat_drifting"]) - fee_maren],
		"at closing the work on somebody who drifted is billed, and takes the fee back")
	# called in: the crew pays the fee on account either way (rules version 9); at closing it keeps
	# it as the bounty, or takes it back and bills the call-out
	var called_steady := visit("kip")
	called_steady.verdict("refer")
	var called_drifting := visit("maren")
	called_drifting.verdict("refer")
	var c := called_steady.settlement()
	var d := called_drifting.settlement()
	eq([c["counter_title"], c["counter"], d["counter"]], [d["counter_title"], fee_kip, fee_maren],
		"a call to the crew prints the same slip and takes the fee in on account, from either")
	eq([c["closing"], d["closing"]], [int(rules["scoring"]["false_call"]) - fee_kip, int(rules["scoring"]["refer_drifting"])],
		"at closing the fee is taken back with the call-out bill, or kept as the bounty")
	eq([a["counter"], b["counter"]], [c["counter"], d["counter"]], "a treat and a call bring in the same at the counter")
	# the shutter before any attack: the same slip for a false alarm and a lock-out
	var shut_steady := visit("kip")
	shut_steady.shutter()
	var shut_drifting := visit("maren")
	shut_drifting.shutter()
	var e := shut_steady.settlement()
	var f := shut_drifting.settlement()
	eq([e["outcome"], f["outcome"]], ["false_alarm", "locked_out"], "a shutter on the steady is a false alarm, on the drifting a lock-out")
	eq([e["counter_title"], e["call"], e["counter"]], [f["counter_title"], f["call"], f["counter"]], "and the slip cannot tell them apart")
	eq([e["closing"], f["closing"]], [int(rules["scoring"]["false_alarm"]), 0], "the false alarm is billed at closing")
	# a drop and the calm-patches are counter money, whoever the patient was
	var courier_visit := visit("kip")
	var entry := courier("kip")
	courier_visit.set_contact(entry)
	courier_visit.say_code(entry)
	courier_visit.verdict("refer")
	var g := courier_visit.settlement()
	eq([g["counter"], g["counter_fee"], g["closing"]], [int(rules["contacts"]["pay"]) + fee_kip, fee_kip, int(rules["scoring"]["false_call"]) - fee_kip],
		"a drop is paid at the counter, with the fee on account; the call-out still waits for closing")
	for s in [a, b, c, d, e, f, g]:
		eq(int(s["counter"]) + int(s["closing"]), int(s["credits"]), "%s %s: the counter and closing make the whole visit" % [s["case_id"], s["outcome"]])
	# the till through the night is counter money; at closing it is everything
	var shift := ShiftState.new(rules, ["kip", "maren"])
	shift.record(b)
	shift.advance()
	eq([shift.till(), shift.total(), shift.reading()["till"]], [fee_maren, int(rules["scoring"]["treat_drifting"]), fee_maren],
		"after treating somebody who drifted, the meter shows the fee: the bill is still to come")
	shift.record(a)
	shift.advance()
	eq([shift.till(), shift.total(), shift.reading()["till"], shift.reading()["last"]],
		[fee_maren + fee_kip, int(rules["scoring"]["treat_drifting"]) + fee_kip, int(rules["scoring"]["treat_drifting"]) + fee_kip, true],
		"at closing the reports are in: the till holds what the counter took, the last reading counts the bill")
	var rep := shift.report()
	eq(int(rep["counter_total"]) + int(rep["closing_total"]) - int(rep["repair_total"]), int(rep["total"]),
		"the report's counter money and closing money, less the glass, make the till")


## Compare both patient modes using the actual request builder and visit transitions.
func test_patient_beats() -> void:
	var fake := FakeClient.new()
	var agent := PatientAgent.new(rules, fake, 3)
	var v := VisitState.new(cases.kip, rules)
	agent.begin_visit(v, "beat-test", 3)
	var before := v.snapshot()
	eq(await agent.beat("arrive", "", before, {}), {}, "offline beats are silent")
	agent.set_mode("model")
	fake.reply = {"ok":true,"data":{"reply":"","reaction":""}}
	eq(await agent.beat("idle", "", before, {}), {}, "the model may stay silent")
	fake.reply = {"ok":false,"error":"timeout"}
	eq(await agent.beat("idle", "", before, {}), {}, "a failed beat is silent")
	ok(not agent.can_beat("idle") and agent.can_beat("after_check"), "idle cap is two")
	fake.reply = {"ok":true,"data":{"reply":"A moment, doctor.","reaction":""}}
	eq((await agent.beat("after_check", "grip", before, {})).get("reply"), "A moment, doctor.", "a timely beat is available to the director")
	ok(not agent.can_beat("arrive") and agent.calls_this_visit == 3 and agent.last.is_empty(), "three optional turns consume three shared replies and leave the foreground untouched")
	eq(v.snapshot(), before, "beats change no rule, evidence or lamp")
	var old: Array = agent.record.entries.duplicate(true)
	agent.record.append("patient", "A moment, doctor.")
	ok(agent.record.entries.size() == old.size()+1, "only a displayed beat becomes a memory")
	agent.begin_visit(visit("rook"), "another-seat", 4)
	ok(not str(agent.record.entries).contains("A moment, doctor.") and agent.beats_this_visit == 0, "new visitors forget the previous conversation and reset both budgets")
	agent.calls_this_visit = 16
	ok(not agent.can_beat("arrive"), "the shared sixteen always wins")


func test_patient_rules_match() -> void:
	var outside := 0
	for id in templates:
		var template: Dictionary = templates[id]
		var normal := CaseDB.compose(template, {})
		var broken := CaseDB.compose(template, {"truth": "drifting", "signs": {"speech": template.signs.speech.broken[0].id,
			"temper": template.signs.temper.broken[0].id}})
		for case_data in [normal, broken]:
			var agent := PatientAgent.new(rules, FakeClient.new(), 123)
			var probe := VisitState.new(case_data, rules)
			agent.begin_visit(probe, "same-visit", 123)
			var temper_id: String = case_data.signs.temper
			eq(probe.open_signs(), {}, "%s with no earned sign" % id)
			probe.seen["flare"] = true
			eq(probe.open_signs(), {"temper": temper_id}, "a flare opens only TEMPER")
			for topic in case_data.topics:
				var offline := VisitState.new(case_data, rules)
				var online := VisitState.new(case_data, rules)
				var readers := [PatientAgent.new(rules, FakeClient.new(), 7), PatientAgent.new(rules, FakeClient.new(), 7)]
				var randoms := [RandomNumberGenerator.new(), RandomNumberGenerator.new()]
				for i in 2:
					readers[i].begin_visit(offline if i == 0 else online, "test-ask", 7)
					readers[i].set_mode("script" if i == 0 else "model")
					randoms[i].seed = 77
				for turn in 2:
					var event := {"type": "ask", "id": topic.id, "text": Lang.t(str(topic.q))}
					var legal := offline.legal_moves_for_ask(str(topic.id))
					event.outcome = readers[0].scripted.choose_move(case_data, event, offline.snapshot(), legal)
					var earned := offline.open_signs(event)
					if event.outcome == "deflect":
						eq(earned, {}, "a first dodge opens no gate")
					elif not case_data.rows.speech.evidence.has("ask:" + str(topic.id)):
						if not offline.answered.has(topic.id):
							outside += 1
							var steady := VisitState.new(normal, rules)
							if turn > 0:
								steady.apply_ask(topic.id, "deflect")
							eq(str(topic.a), str(steady.topic(topic.id).a), "unrevealing questions use the same authored answer")
							eq(agent.build_payload(event, offline.snapshot(), earned), agent.build_payload(event, steady.snapshot(), steady.open_signs(event)), "no request field reveals the broken sign")
					else:
						eq(earned, {"speech": case_data.signs.speech}, "the question opens only tonight's SPEECH")
					for i in 2:
						var v: VisitState = offline if i == 0 else online
						var reader: PatientAgent = readers[i]
						var d: Dictionary = await reader.decide(event, v.snapshot(), [event.outcome], v.open_signs(event))
						display_answer(reader, d)
						v.apply_ask(topic.id, str(d.move), str(d.line))
						v.roll_action(randoms[i], 0)
					eq([offline.patience, offline.seen, offline.notes, offline.last_recorded_speech, offline.actions, randoms[0].state],
						[online.patience, online.seen, online.notes, online.last_recorded_speech, online.actions, randoms[1].state], "ASK has the same price, proof, quote and random draws")
					eq(readers[0].record.entries, readers[1].record.entries, "authored ASK reaches both conversation histories")
					eq(readers[1].calls_this_visit, 0, "authored ASK spends no generated reply")
				var fresh := VisitState.new(case_data, rules)
				fresh.patience = 0
				ok(fresh.open_signs({"type":"ask", "id":topic.id, "outcome":"answer"}).has("speech"), "a free answer opens speech without a lamp")
			for tool in VisitState.TOOLS:
				var script := VisitState.new(case_data, rules)
				var model := VisitState.new(case_data, rules)
				for turn in 3:
					var legal := script.legal_moves_for_check(tool)
					var action := {"type": "check", "id": tool}
					var move := agent.scripted.choose_move(case_data, action, script.snapshot(), legal)
					var a := script.apply_check(tool, move)
					var b := model.apply_check(tool, move, true)
					if a.result == "granted":
						script.complete_check(tool)
						model.complete_check(tool)
					eq([a.result, a.cost, script.notes, script.seen, script.patience], [b.result, b.cost, model.notes, model.seen, model.patience], "matching tool decisions have the same price and proof")
				var settled := VisitState.new(case_data, rules)
				eq(settled.apply_check(tool, "stall", true).result, "granted", "hesitation is flavour in both modes")
	eq(outside, 9, "all nine questions outside a broken sign are indistinguishable")


## A generated answer can hide the authored speech clue. Feedback must describe what was heard.
func test_generated_speech_findings() -> void:
	var v := visit("vale")
	var actual := "I prefer to discuss the repair, doctor."
	v.apply_ask("sleep", "answer", "I slept through it.")
	var repeated := v.apply_ask("sleep", "answer", actual)
	eq([repeated.cost, v.notes.speech.size(), v.notes.speech.back().text], [0, 1, Lang.tf("Says: %s", [actual])], "a free repeat updates the one note for that topic")
	v.verdict("refer")
	v.shutter()
	var s := v.settlement()
	var speech: Dictionary = s.rows[3]
	eq(speech.has("assessment"), false, "generated speech receives normal grading")
	eq(speech.get("ok"), cases.vale.rows.speech.ok, "the composed case supplies the grade")
	eq(speech.text, actual, "feedback retains the answer actually heard")
	ok(speech.text != cases.vale.rows.speech.text, "feedback does not substitute the authored sleep quote")
	ok(bool(speech.seen), "the recorded answer was heard")
	eq([s.truth, s.outcome, s.credits], ["drifting", "caught", int(cases.vale.fee) + int(rules.scoring.refer_drifting)], "dialogue does not alter truth, attack or payment")
	eq([s.rows[0].ok, s.rows[2].ok], [false, false], "physical findings remain fixed")
	var free := visit("kip")
	eq(free.apply_ask("free", "answer").result, "closed", "small talk is not a question")
	free.verdict("treat")
	ok(not bool(free.settlement().rows[3].seen), "small talk leaves SPEECH unseen")
	eq([free.settlement().truth, free.settlement().credits], ["stable", 250], "free dialogue does not change the diagnosis or fee")
	var mixed := visit("vale")
	mixed.apply_ask("why", "answer", "A generated reply.")
	mixed.apply_ask("sleep", "answer")
	mixed.verdict("treat")
	eq(mixed.settlement().rows[3].text, str(mixed.topic("sleep").a), "a later scripted fallback is recorded accurately")
	var offline := visit("vale")
	offline.apply_ask("sleep", "answer")
	offline.verdict("treat")
	ok(not offline.settlement().rows[3].has("assessment"), "the scripted comparison keeps its authored findings")
	eq(offline.settlement().rows[3].text, offline.topic("sleep").a, "offline feedback still matches its actual script")


## calls: case id -> "treat" | "refer" | "shutter" | "gave_up" (patience spent, nobody decided).
## A patient who turns on the call is shut out in time, unless their id is in `slow`: then the
## shutter never comes and the blow lands. Visitors in `drops` are couriers tonight and the
## code is said to them, rightly, before the call. night_cases: the composed cases of another
## night than A (CaseDB.compose_night), for a shift given that night's order.
func play(shift: ShiftState, calls: Dictionary, slow: Array = [], drops: Array = [], night_cases: Dictionary = {}) -> void:
	while not shift.is_done():
		var id := shift.current_id()
		var v := visit(id) if night_cases.is_empty() else VisitState.new((night_cases[id] as Dictionary).duplicate(true), rules)
		if drops.has(id):
			var entry := courier(id)
			v.set_contact(entry)
			v.say_code(entry)
		var call := str(calls[id])
		if call == "shutter":
			v.shutter()
		elif call == "gave_up":
			v.patience = 0
			v.give_up()
		elif str(v.verdict(call)["next"]) == "attack":
			if slow.has(id):
				v.attack_timeout()
			else:
				v.shutter()
		shift.record(v.settlement())
		shift.advance()


## The first pool entry for a visitor: tonight, they are a courier. A night gives each entry an
## alias and a code (ShiftState.name_contacts); here an entry takes the ones at its place in the
## pool, so two visitors' entries never share them.
func courier(id: String) -> Dictionary:
	var pool: Array = contacts_data["pool"]
	var aliases: Array = contacts_data["aliases"]
	var codes: Array = contacts_data["codes"]
	for i in pool.size():
		if str(pool[i]["case"]) == id:
			var e: Dictionary = (pool[i] as Dictionary).duplicate(true)
			e["alias"] = str(aliases[i % aliases.size()])
			e["say"] = str(codes[i % codes.size()]["say"])
			e["answer"] = str(codes[i % codes.size()]["answer"])
			return e
	return {}


## The words of a text: its runs of letters, lower case.
func letter_words(text: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("[a-z]+")
	for m in re.search_all(text.to_lower()):
		out.append(m.get_string())
	return out


func test_shift() -> void:
	var shift := ShiftState.new(rules)
	eq(shift.current_id(), "kip", "shift starts with kip")
	eq(shift.upcoming_id(), "rook", "rook is next")
	var pay := int(rules["contacts"]["pay"])
	play(shift, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"})
	var rep := shift.report()
	eq(rep["total"], 1900, "perfect calls alone: 1900, the night's fees")
	eq(rep["correct"], 5, "perfect shift calls")
	eq(rep["line"], 5 * int(rules["line"]["per_hour"]), "five hours put the line at five times the hourly figure")
	eq(rep["line"], 2000, "which is 2000")
	ok(not bool(rep["line_held"]), "right calls alone no longer hold the line: the night needs a drop")
	eq(rep["title"], "THE CUT", "and a night of right calls with no drop is the cut")
	eq([rep["drops"], rep["drop_total"]], [0, 0], "no drop was made")
	shift = ShiftState.new(rules)
	play(shift, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"}, [], ["kip"])
	rep = shift.report()
	eq([rep["total"], rep["drops"], rep["drop_total"]], [1900 + pay, 1, pay], "perfect calls and one drop")
	ok(bool(rep["line_held"]), "perfect calls and one drop hold the line")
	eq(rep["title"], "STEADY HANDS", "perfect shift title")
	shift = ShiftState.new(rules)
	play(shift, {"kip": "treat", "rook": "treat", "vale": "treat", "juno": "treat", "maren": "treat"})
	rep = shift.report()
	eq(rep["total"], 100, "treat-everyone total")
	eq(rep["correct"], 3, "treat-everyone calls")
	ok(not bool(rep["line_held"]), "treat-everyone ends under the line")
	eq(rep["title"], "THE CUT", "and a night under the line has one name")
	shift = ShiftState.new(rules)
	play(shift, {"kip": "refer", "rook": "refer", "vale": "refer", "juno": "refer", "maren": "refer"})
	rep = shift.report()
	eq(rep["total"], 550, "call-everyone total: two bounties, less three call-outs")
	eq(rep["correct"], 2, "call-everyone calls")
	ok(not bool(rep["line_held"]), "call-everyone ends under the line")
	eq(rep["title"], "THE CUT", "call-everyone title")
	# with both drops one needless call can be afforded; with one drop it cannot, nor can two calls
	var one := ShiftState.new(rules)
	play(one, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "refer", "maren": "refer"}, [], ["kip", "rook"])
	eq(one.report()["total"], 1400 + 2 * pay, "one false call and two drops: exactly the line")
	eq(one.report()["correct"], 4, "one false call leaves four right calls")
	ok(bool(one.report()["line_held"]), "one false call and both drops still hold the line")
	var one_drop := ShiftState.new(rules)
	play(one_drop, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "refer", "maren": "refer"}, [], ["kip"])
	ok(not bool(one_drop.report()["line_held"]), "one false call and one drop do not")
	var two := ShiftState.new(rules)
	play(two, {"kip": "treat", "rook": "refer", "vale": "refer", "juno": "refer", "maren": "refer"}, [], ["kip", "rook"])
	eq(two.report()["total"], 950 + 2 * pay, "two false calls and two drops")
	ok(not bool(two.report()["line_held"]), "two false calls end under the line, drops or not")
	# the report says in words what the till means, and its title reads the whole night
	eq(str(rep["line_text"]), str(rules["line_text"]["short"]), "a night under the line says so")
	eq(str(one.report()["line_text"]), str(rules["line_text"]["held"]), "a night over the line says so")
	ok(str(rules["line_text"]["short"]) != "" and str(rules["line_text"]["held"]) != "", "both meter lines are written")
	eq(one.report()["title"], "A GOOD NIGHT'S WORK", "four right calls, nobody hurt, line held: a good night's work")
	eq(two.report()["title"], "THE CUT", "three right calls under the line: the cut")
	# a patient who gets through the window kills the doctor: the night ends with that visit
	var hurt := ShiftState.new(rules)
	play(hurt, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"}, ["vale"], ["kip", "juno"])
	var hurt_rep := hurt.report()
	ok(hurt.died and hurt.is_done() and hurt.current_id() == "" and hurt.upcoming_id() == "",
		"a patient who gets through the window ends the night: nobody else comes to the counter")
	eq([hurt.records.size(), hurt_rep["unseen"]], [3, ["juno", "maren"]], "the visit it happened in is the last one; the rest go home unseen")
	eq(hurt_rep["correct"], 3, "a right call that ended in a blow is still a right call")
	eq(hurt_rep["injuries"], 1, "and the blow is counted")
	eq([hurt_rep["counter_total"], hurt_rep["closing_total"], hurt_rep["total"]], [250 + pay + 300, -300, 250 + pay],
		"the counter took two fees and a drop, the blow is billed at closing, and Juno's drop never came")
	eq(hurt_rep["title"], "LIGHTS OUT", "and the night is lights out, whatever else went right")
	eq(str(hurt_rep["line_text"]), str(rules["line_text"]["died"]), "nobody reads the meter for a doctor who died")
	ok(not bool(hurt_rep["line_held"]), "so the line is not held")
	eq([hurt_rep["readings"].size(), hurt_rep["hours_under"]], [2, 0], "the hour it happened in is never read; the two before it were over the line")
	# dead on the first visit: the whole hall goes home, and no reading was ever taken
	var first_blow := ShiftState.new(rules, ["vale", "kip", "rook", "juno", "maren"])
	play(first_blow, {"vale": "refer"}, ["vale"])
	var first_rep := first_blow.report()
	eq([first_rep["unseen"], first_rep["readings"], first_rep["hours_under"], first_rep["title"]], [["kip", "rook", "juno", "maren"], [], 0, "LIGHTS OUT"],
		"killed by the first patient: four unseen, no reading taken, lights out")
	eq([first_rep["counter_total"], first_rep["closing_total"], first_rep["total"]], [0, int(rules["scoring"]["hit"]), int(rules["scoring"]["hit"])],
		"and the only money of the night is the bill for the blow")
	# a hit on a patient nobody called the crew for (one who snapped) is no call at all
	var snap := visit("vale")
	snap.snap()
	snap.attack_timeout()
	ok(not bool(snap.settlement()["correct"]) and str(snap.settlement()["call"]) == "hit", "a snap that gets through is nobody's right call")
	var thin := ShiftState.new(rules)
	play(thin, {"kip": "treat", "rook": "treat", "vale": "treat", "juno": "treat", "maren": "shutter"}, [], ["kip", "rook"])
	var thin_rep := thin.report()
	eq(thin_rep["correct"], 4, "treating Vale is the one wrong call; locking Maren out is a right one")
	eq(thin_rep["total"], 500 + 2 * pay, "four right calls and both drops can still leave 1100 in the till")
	ok(not bool(thin_rep["line_held"]), "which is under the line")
	eq(thin_rep["title"], "THE CUT", "four right calls under the line are still the cut")
	var sore := ShiftState.new(rules)
	for row in [[250 + pay, true, false], [300 + pay, true, false], [600, true, false], [350, true, false], [0, false, true]]:
		sore.record({"credits": row[0], "correct": row[1], "injured": row[2]})
		sore.advance()
	ok(bool(sore.report()["line_held"]) and int(sore.report()["correct"]) == 4, "four right calls, line held, one blow taken")
	eq(sore.report()["title"], "OPEN, BARELY",
		"should a blow ever not end the night, a night that hurt you is still not called a good one")
	# with the line held, fewer right calls keep their own names; patients who left earn nothing.
	# At 400 an hour night A holds the line only with four right calls or five (the best three make
	# 1950; see below), so these titles are read against the old line of 240 an hour
	var old_line := rules.duplicate(true)
	old_line["line"]["per_hour"] = 240
	var three := ShiftState.new(old_line)
	play(three, {"kip": "treat", "rook": "treat", "vale": "gave_up", "juno": "treat", "maren": "gave_up"}, [], ["kip", "rook"])
	var three_rep := three.report()
	eq([three_rep["total"], three_rep["correct"], three_rep["line_held"]], [900 + 2 * pay, 3, true], "three treated, two left unanswered, two drops: line held")
	eq(three_rep["title"], "OPEN, BARELY", "three right calls over the line: open, barely")
	var low := ShiftState.new(old_line)
	play(low, {"kip": "treat", "rook": "gave_up", "vale": "gave_up", "juno": "treat", "maren": "gave_up"}, [], ["kip", "juno"])
	var low_rep := low.report()
	eq([low_rep["total"], low_rep["correct"], low_rep["line_held"]], [1200, 2, true], "a till exactly on the line holds it")
	eq(low_rep["title"], "ON NOTICE", "two right calls over the line: on notice")
	eq(low_rep["hours_under"], 1, "though one of its readings on the way was under (550 against 720)")
	# every possible night gets a title, and THE CUT is exactly the nights that end under the line,
	# with no drop and with two
	var every_night_named := true
	var cut_is_under := true
	var some_held := false
	var held_needs_four := true
	var options := ["treat", "refer", "shutter", "gave_up"]
	for drops in [[], ["kip", "juno"]]:
		for n in int(pow(options.size(), 5)):
			var calls := {}
			var code := n
			for id in rules["shift_order"]:
				calls[id] = options[code % options.size()]
				code /= options.size()
			var night := ShiftState.new(rules)
			play(night, calls, [], drops)
			var night_rep := night.report()
			every_night_named = every_night_named and str(night_rep["title"]) != "" and str(night_rep["text"]) != ""
			cut_is_under = cut_is_under and ((str(night_rep["title"]) == "THE CUT") == (not bool(night_rep["line_held"])))
			some_held = some_held or bool(night_rep["line_held"])
			held_needs_four = held_needs_four and (not bool(night_rep["line_held"]) or int(night_rep["correct"]) >= 4)
	ok(every_night_named, "all 2 x 1024 combinations of calls end in a titled report")
	ok(cut_is_under, "THE CUT is given to every night under the line and to no other")
	ok(some_held, "and with drops some nights hold the line")
	ok(held_needs_four, "at 400 an hour night A holds the line only with four right calls or five")
	# The newer five are dearer. On test night D (Dana, Priya, Ozzie, Lux and Kip; fees 1970) Dana
	# treated and Priya and Lux handed over make 1500, and with both drops 2100: three right calls
	# can hold the line there, OPEN, BARELY. Two never can, on any night: the roster's two dearest
	# fees and every drop of a night come to less than the line.
	var db := CaseDB.load_all()
	var d_night: Dictionary = (db["nights"] as Dictionary)["D"]
	var d_cases := CaseDB.compose_night(templates, d_night, parts)
	var d_order := CaseDB.night_order(d_night)
	var barely := ShiftState.new(rules, d_order)
	play(barely, {"dana": "treat", "priya": "refer", "ozzie": "gave_up", "lux": "refer", "kip": "gave_up"}, [], ["ozzie", "kip"], d_cases)
	var barely_rep := barely.report()
	eq([barely_rep["total"], barely_rep["correct"], barely_rep["line_held"], barely_rep["title"]], [1500 + 2 * pay, 3, true, "OPEN, BARELY"],
		"night D: three right calls and both drops, from the two who walked out, hold the line: open, barely")
	var held_by_three := false
	var held_needs_three := true
	var d_named := true
	for drops in [[], ["ozzie", "kip"]]:
		for n in int(pow(options.size(), 5)):
			var calls := {}
			var code := n
			for id in d_order:
				calls[id] = options[code % options.size()]
				code /= options.size()
			var night := ShiftState.new(rules, d_order)
			play(night, calls, [], drops, d_cases)
			var night_rep := night.report()
			d_named = d_named and str(night_rep["title"]) != "" and ((str(night_rep["title"]) == "THE CUT") == (not bool(night_rep["line_held"])))
			held_by_three = held_by_three or (bool(night_rep["line_held"]) and int(night_rep["correct"]) == 3)
			held_needs_three = held_needs_three and (not bool(night_rep["line_held"]) or int(night_rep["correct"]) >= 3)
	ok(d_named, "night D: all 2 x 1024 combinations of calls end in a titled report, THE CUT exactly under the line")
	ok(held_by_three and held_needs_three, "night D holds the line with three right calls, never with two")
	var roster_fees := []
	for id in CaseDB.roster_of(rules):
		roster_fees.append(CaseDB.fees_of(db["people"], [id]))
	roster_fees.sort()
	ok(int(roster_fees[-1]) + int(roster_fees[-2]) + int(rules["contacts"]["per_night"]) * pay < 5 * int(rules["line"]["per_hour"]),
		"no night holds the line on two right calls or fewer: ON NOTICE stays out of reach")
	for entry in rules["titles"]:
		ok(str(entry["title"]) != "" and str(entry["text"]) != "", "report title '%s' has its text" % str(entry["title"]))
	var titles: Array = rules["titles"]
	var first_title: Dictionary = titles[0]
	ok(first_title.get("died") == true and int(first_title["min_correct"]) == 0 and not first_title.has("line_held"),
		"the first title is the night the doctor died, whatever else went right")
	var second_title: Dictionary = titles[1]
	ok(second_title.get("line_held") == false and int(second_title["min_correct"]) == 0 and not second_title.has("max_injuries"),
		"the second is the night under the line, whatever else went right")
	var asks_died := 0
	for entry in titles:
		if (entry as Dictionary).has("died"):
			asks_died += 1
	eq(asks_died, 1, "and only the first asks how the night ended")
	eq(int((rules["titles"] as Array).back()["min_correct"]), 0, "the last title fits any night over the line")
	ok(not (rules["titles"] as Array).back().has("max_injuries"), "and asks for no clean record")
	ok(int(rules["scoring"]["false_call"]) < int(rules["scoring"]["false_alarm"]),
		"calling an armed crew on a steady patient costs more than a false alarm")
	ok(shift.is_done() and shift.current_id() == "", "shift ends after five")


## The line (rules version 4): the lender's meter wants per_hour more in the till at every
## hourly reading. One finished visit is one hour. Only the last reading decides the night.
func test_line() -> void:
	var per := int(rules["line"]["per_hour"])
	ok(per > 0, "the line asks for something every hour")
	var shift := ShiftState.new(rules)
	eq(shift.line_per_hour(), per, "the hourly figure comes from the rules")
	eq([shift.line_at(0), shift.line_at(1), shift.line_at(5), shift.line_at(9)], [0, per, 5 * per, 5 * per],
		"hour n wants n times the hourly figure, and no hour comes after the last")
	eq(shift.hour(), 1, "the shift opens in hour one")
	eq([shift.reading()["hour"], shift.readings().size(), shift.hours_under()], [0, 0, 0], "no reading before the first visit ends")
	var right_calls := 0
	for id in cases.keys():
		right_calls += int(cases[id]["fee"]) + (0 if str(cases[id]["truth"]) == "stable" else int(rules["scoring"]["refer_drifting"]))
	ok(right_calls < 5 * per, "right calls alone fall short of the night's line")
	ok(right_calls + int(rules["contacts"]["pay"]) >= 5 * per, "one drop on top of them holds it")
	# right calls alone: the fees come in hour by hour, a call to the crew like a treat, and the
	# till trails the line at every reading by less than one drop
	var plain := ShiftState.new(rules)
	play(plain, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"})
	var trails := plain.readings().size() == 5
	for r in plain.readings():
		trails = trails and not bool(r["held"]) and int(r["margin"]) > -int(rules["contacts"]["pay"])
	ok(trails, "night A, right calls and no drop: under the line at every reading, by less than a drop")
	play(shift, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"}, [], ["kip"])
	var seen: Array = []
	for r in shift.readings():
		seen.append([r["hour"], r["till"], r["line"], r["held"]])
	eq(seen, [[1, 550, 400, true], [2, 850, 800, true], [3, 1450, 1200, true], [4, 1800, 1600, true], [5, 2200, 2000, true]],
		"a perfect night with an early drop: five readings, each over its line; Trauma Team pays its fees on account")
	eq(shift.hours_under(), 0, "no hour of it under")
	ok(bool(shift.reading()["last"]) and not bool(shift.reading(4)["last"]), "the fifth reading is the last one")
	eq(shift.hour(), 5, "the clock does not run past the shift")
	eq(shift.report()["readings"], shift.readings(), "the report carries the readings")
	# a patient who leaves unanswered puts the till one hour behind
	var slow := ShiftState.new(rules)
	play(slow, {"kip": "gave_up", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"}, [], ["rook", "juno"])
	eq([slow.readings()[0]["held"], slow.readings()[0]["margin"]], [false, -per], "a first patient who left: one hour under at the first reading")
	eq([slow.readings()[1]["held"], slow.readings()[1]["till"]], [false, 600], "a fee and a drop do not make up the lost hour at once")
	eq([slow.readings()[2]["held"], slow.readings()[2]["till"]], [true, 1200], "the fee Trauma Team pays for Vale on account brings the till back to the line")
	eq([slow.hours_under(), slow.report()["hours_under"]], [2, 2], "both hours under are counted")
	ok(bool(slow.report()["line_held"]), "and a reading on the way does not decide the night")
	eq(slow.report()["title"], "A GOOD NIGHT'S WORK", "four right calls, nobody hurt, line held at closing")
	# on the line counts as holding it; a short shift is read against its own hours
	var at_fee := rules.duplicate(true)
	at_fee["line"]["per_hour"] = int(cases["vale"]["fee"]) + int(rules["scoring"]["refer_drifting"])
	var even := ShiftState.new(at_fee, ["vale"])
	play(even, {"vale": "refer"})
	eq([even.reading()["held"], even.reading()["margin"], even.report()["line"]], [true, 0, int(at_fee["line"]["per_hour"])],
		"a till exactly on the line holds it")
	var none := rules.duplicate(true)
	none.erase("line")
	var free := ShiftState.new(none)
	play(free, {"kip": "refer", "rook": "refer", "vale": "treat", "juno": "refer", "maren": "treat"})
	eq([free.report()["line"], free.report()["line_held"], free.total() < 0], [0, false, true],
		"without a line the meter wants nothing, and a till below zero is still under it")


## The glass (rules version 4): the pane takes three blows a shift. Each blow that lands before
## the shutter is down uses one up, and the next attack comes through that much sooner.
func test_glass() -> void:
	var attack: Dictionary = rules["attack"]
	var window := int(attack["window_ms"])
	var shift := ShiftState.new(rules)
	eq([shift.glass, shift.glass_max(), shift.glass_out], [int(attack["glass"]), int(attack["glass"]), false], "a new shift has a whole pane")
	var plan := shift.attack_plan()
	eq(plan["blows_ms"], [540, 990, 1440], "a whole pane takes three blows, where the rules put them")
	eq(plan["through_ms"], window, "and the patient needs the full window to come through")
	ok(int(plan["blows_ms"][0]) >= 450, "the first blow leaves a quick player time for a clean stop")
	var windows: Array = [int(plan["through_ms"])]
	while shift.glass > 0:
		shift.glass_blow()
		plan = shift.attack_plan()
		eq((plan["blows_ms"] as Array).size(), shift.glass, "%d glass left: that many blows land" % shift.glass)
		ok((plan["blows_ms"] as Array).is_empty() or int((plan["blows_ms"] as Array).back()) < int(plan["through_ms"]),
			"%d glass left: every blow lands before the patient is through" % shift.glass)
		windows.append(int(plan["through_ms"]))
	eq(windows, [1800, 1440, 990, 650], "less glass, less time")
	eq(windows.min(), int(attack["min_window_ms"]), "but never less than the floor in the rules")
	eq(shift.glass_blow(), 0, "the glass cannot go below nothing")
	ok(not shift.glass_out, "cracked through is not broken out")
	shift.glass_break()
	plan = shift.attack_plan()
	eq([shift.glass, shift.glass_out, plan["out"], plan["through_ms"], plan["blows_ms"]], [0, true, true, 650, []],
		"once somebody has come through there is no pane: the next one has the shortest window")
	eq(shift.report()["glass"], 0, "the report knows what is left of the pane")
	eq(ShiftState.new(rules).glass, int(attack["glass"]), "the next shift opens with a new pane")
	# the visit counts the blows of its own attack and grades the shutter
	var v := visit("vale")
	eq(v.take_blow(), 0, "no blow counts before a patient has turned")
	v.verdict("refer")
	v.shutter()
	eq([v.settlement()["grade"], v.settlement()["blows"]], ["clean", 0], "shutter down before any blow: a clean stop")
	v = visit("vale")
	v.verdict("refer")
	v.take_blow()
	eq(v.take_blow(), 2, "blows are counted while the shutter is up")
	v.shutter()
	eq([v.settlement()["grade"], v.settlement()["blows"]], ["cracked", 2], "two blows first: stopped, but the glass paid")
	eq(v.settlement()["credits"], int(cases["vale"]["fee"]) + int(rules["scoring"]["refer_drifting"]), "a late stop is paid like a clean one: the glass is the cost")
	eq(v.take_blow(), 2, "nothing lands once the shutter is down")
	v = visit("maren")
	v.press()
	v.press()
	for i in 3:
		v.take_blow()
	v.attack_timeout()
	eq([v.settlement()["grade"], v.settlement()["blows"]], ["through", 3], "never down: they came through")
	var t := visit("kip")
	t.verdict("treat")
	eq(t.settlement()["grade"], "", "a visit with no attack has no shutter grade")


## Mending the glass (rules version 5): between patients the doctor can pay attack.repair_cost
## for one layer. The money leaves the till at once, the meter counts it at every reading after
## that, and a reading that was already taken never changes.
func test_repair() -> void:
	var cost := int(rules["attack"]["repair_cost"])
	var per := int(rules["line"]["per_hour"])
	ok(cost > 0, "a layer of glass has a price")
	ok(cost < per, "one layer costs less than an hour of the line")
	ok(cost * int(rules["attack"]["glass"]) <= per, "and a whole pane no more than one hour of it")
	var shift := ShiftState.new(rules)
	eq([shift.repair_cost(), shift.can_repair(), shift.repair_glass()], [cost, false, {}], "a whole pane has nothing to mend")
	eq([shift.total(), shift.repairs.size(), shift.report()["repairs"]], [0, 0, 0], "and asking costs nothing")
	shift.glass_blow()
	ok(shift.can_repair(), "one blow on the glass: a layer can be bought")
	var res := shift.repair_glass()
	eq([res["cost"], res["glass"], res["glass_max"], res["till"]], [cost, 3, 3, -cost],
		"the fitter's bill: one layer, a whole pane, and a till that may go into debt for it")
	eq([shift.glass, shift.total(), shift.repair_total(), shift.can_repair()], [3, -cost, cost, false],
		"the pane is whole again and the till has paid for it")
	eq(shift.attack_plan()["blows_ms"], [540, 990, 1440], "a mended pane takes all three blows again")
	eq(shift.attack_plan()["through_ms"], int(rules["attack"]["window_ms"]), "and gives the full window back")
	# the meter: a reading that was taken stays as it was, the next one counts the glass
	var night := ShiftState.new(rules)
	var v := visit("kip")
	v.verdict("treat")
	night.record(v.settlement())
	night.advance()
	night.glass_blow()
	var first: Dictionary = night.reading(1)
	night.repair_glass()
	eq([first["till"], night.reading(1)], [250, first], "glass bought after the first reading leaves that reading alone")
	eq(night.total(), 250 - cost, "though the till is lighter at once")
	eq(night.reading()["till"], 250, "and the latest reading is still the one that was taken")
	v = visit("rook")
	v.verdict("treat")
	night.record(v.settlement())
	night.advance()
	eq([night.reading(2)["till"], night.reading(2)["line"], night.reading(2)["margin"]], [550 - cost, 2 * per, 550 - cost - 2 * per],
		"the second reading counts the glass")
	eq(night.reading(1), first, "the first one still does not")
	# an empty frame: one layer puts glass back in it
	var broken := ShiftState.new(rules)
	broken.glass_break()
	eq([broken.glass, broken.glass_out, broken.can_repair()], [0, true, true], "a frame with no glass in it can be glazed")
	broken.repair_glass()
	var plan := broken.attack_plan()
	eq([broken.glass, broken.glass_out, plan["out"], plan["blows_ms"], plan["through_ms"]], [1, false, false, [540], 990],
		"one layer: one blow lands, and the patient is through where the second would have fallen")
	broken.repair_glass()
	broken.repair_glass()
	eq([broken.glass, broken.can_repair(), broken.repair_total()], [3, false, 3 * cost], "three layers make a whole pane, at three times the price")
	eq(broken.repair_glass(), {}, "and nobody sells a fourth")
	var rep := broken.report()
	eq([rep["repairs"], rep["repair_total"], rep["glass"], rep["total"]], [3, 3 * cost, 3, -3 * cost], "the report carries what the glass cost")
	# the glass comes out of the same till the line is read against
	var tight := ShiftState.new(rules)
	tight.glass_blow()
	tight.repair_glass()
	play(tight, {"kip": "treat", "rook": "gave_up", "vale": "gave_up", "juno": "treat", "maren": "gave_up"}, [], ["kip", "juno"])
	var tight_rep := tight.report()
	eq([tight_rep["total"], tight_rep["line_held"], tight_rep["title"]], [1200 - cost, false, "THE CUT"],
		"a night that was exactly on the line cannot afford a layer")
	eq(tight.readings()[0]["till"], 250 + int(rules["contacts"]["pay"]) - cost, "glass bought before the first patient is in the first reading")
	eq(tight_rep["correct"], 2, "paying for glass is not a call: the count of right calls is untouched")
	tight.glass_blow()
	ok(not tight.can_repair(), "after the last patient the fitter does not come")
	eq(tight.repair_glass(), {}, "and takes no money")
	# a rule set without a price: the glass stays as it is
	var none := rules.duplicate(true)
	none["attack"].erase("repair_cost")
	var plain := ShiftState.new(none)
	plain.glass_blow()
	eq([plain.repair_cost(), plain.can_repair(), plain.repair_glass(), plain.glass], [0, false, {}, 2], "without a price nobody mends glass")


## The night (rules version 9): who comes in, who of them drifts and which sign each sheet row
## shows are drawn from the shift seed. Every drawn night is one the rules allow and every case
## in it holds; the same seed gives the same night; the first night of a session opens with a
## steady visitor who can carry a fair contact; a broken row can be any row; and the test nights
## of nights.json are nights the draw could make.
func test_wear_distribution() -> void:
	var db := CaseDB.load_all()
	var pristine := db.duplicate(false)
	pristine.rules = rules.duplicate(true)
	pristine.rules.night.wear.chance = 0.0
	var total := 0
	var worn := 0
	var frequencies := {}
	var invariant := true
	for seed_value in range(1, 5001):
		var a: Array = ShiftState.draw_night(db, seed_value, false).visitors
		var b: Array = ShiftState.draw_night(pristine, seed_value, false).visitors
		for i in a.size():
			var drawn: Dictionary = a[i]
			var old: Dictionary = b[i]
			invariant = invariant and drawn.id == old.id and drawn.truth == old.truth
			if drawn.truth == "drifting":
				invariant = invariant and drawn == old
				continue
			total += 1
			var broken := 0
			for row in CaseDB.ROWS:
				var clean := CaseDB.find_sign(templates[drawn.id], row, old.signs[row])
				invariant = invariant and bool(clean.ok)
				if drawn.signs[row] != old.signs[row]:
					invariant = invariant and not CaseDB.find_sign(templates[drawn.id], row, drawn.signs[row]).ok
					broken += 1
					frequencies[row] = int(frequencies.get(row, 0)) + 1
			worn += int(broken > 0)
			invariant = invariant and broken <= 1
		if seed_value <= 500:
			var first: Dictionary = ShiftState.draw_night(db, seed_value, true).visitors[0]
			for row in CaseDB.ROWS:
				invariant = invariant and CaseDB.find_sign(templates[first.id], row, first.signs[row]).ok
	ok(invariant, "5000 paired seeds preserve visitors, truths and drifting signs; chance zero and protected first visitors stay clean")
	ok(float(worn) / total >= 0.45 and float(worn) / total <= 0.55, "half of steady visitors show one worn line: %d/%d" % [worn, total])
	for row in CaseDB.ROWS:
		var share := float(frequencies.get(row, 0)) / worn
		ok(share >= 0.17 and share <= 0.23, "one fifth of wear is %s: %.3f" % [row, share])
	for night in ["I", "J"]:
		var composed := CaseDB.compose_night(templates, db.nights[night], parts)
		for c in composed.values():
			if c.truth != "stable" or CaseDB.broken_count(c) != 1:
				continue
			var v := VisitState.new(c, rules)
			ok(not v.snap() and v.snap_chance() == 0.0, "wear cannot cause a snap")
			ok(v.verdict("refer").get("next") != "attack", "a worn patient never lunges at a call")
			v = VisitState.new(c, rules)
			v.press()
			v.patience = 0
			eq(v.press().result, "walkout", "a worn patient walks out on the breaking press")
			v = VisitState.new(c, rules)
			var rng := RandomNumberGenerator.new()
			rng.seed = 17
			var before := rng.state
			for repeat in 10:
				v.roll_action(rng, 0)
			ok(v.actions == 0 and rng.state == before, "ten free actions consume no roll")
			var seen := false
			for row in v.settlement().rows:
				if row.wear:
					seen = not row.ok and not row.seen and row.has("show_with")
			ok(seen, "closing distinguishes a missed worn line and names its check")
			var e := {"type":"say","text":"hello"}
			var model := PatientAgent.new(rules)
			model.begin_visit(v, "same-visit", 1)
			var got := model.build_payload(e, v.snapshot(), v.open_signs())
			var twin: Dictionary = c.duplicate(true)
			twin.truth = "drifting"
			var other := VisitState.new(twin, rules)
			model.begin_visit(other, "same-visit", 1)
			eq(model.build_payload(e, other.snapshot(), other.open_signs()), got, "equal open evidence gives identical model input across truths")
	var drift := visit("vale")
	drift.snap()
	drift.shutter()
	eq(drift.settlement().press_bonus, 0, "a snap earns no PRESS bonus")


func test_night_draw() -> void:
	var db: Dictionary = CaseDB.load_all()
	var people: Dictionary = db["people"]
	var templates: Dictionary = db["templates"]
	var roster: Array = CaseDB.roster_of(rules)
	var sorted_roster := roster.duplicate()
	sorted_roster.sort()
	var problems: Array = []
	var repeat_ok := true
	var orders := {}
	var drift_counts := {}
	var broken_counts := {}
	var first_steady := true
	var later_opens_drifting := false
	var broken_rows := {}
	var shown := {}
	for s in range(1, 501):
		var first := s % 2 == 1
		var n: Dictionary = ShiftState.draw_night(db, s, first)
		repeat_ok = repeat_ok and n == ShiftState.draw_night(db, s, first)
		var composed := CaseDB.compose_night(templates, n, parts)
		var ids := CaseDB.night_order(n)
		orders[JSON.stringify(ids)] = true
		if roster.size() == int(rules["night"]["visitors"]):
			var sorted_ids := ids.duplicate()
			sorted_ids.sort()
			if sorted_ids != sorted_roster:
				problems.append("seed %d: the night is not the whole roster (%s)" % [s, str(ids)])
		var drifting := 0
		for id in ids:
			if not composed.has(id):
				problems.append("seed %d: %s does not compose" % [s, id])
				continue
			var c: Dictionary = composed[id]
			for e in CaseDB.validate_case(c, rules, sheet, parts):
				problems.append("seed %d, %s: %s" % [s, id, str(e)])
			if str(c["truth"]) == "drifting":
				drifting += 1
				broken_counts[CaseDB.broken_count(c)] = true
				for row in CaseDB.ROWS:
					if not bool(c["rows"][row]["ok"]):
						broken_rows["%s:%s" % [id, row]] = true
			for row in CaseDB.ROWS:
				shown["%s:%s:%s" % [id, row, str(c["signs"][row])]] = true
		drift_counts[drifting] = true
		for e in CaseDB.night_drawable(rules, n, composed, people, contacts_data, first):
			problems.append("seed %d: %s" % [s, str(e)])
		if first:
			first_steady = first_steady and str(composed[ids[0]]["truth"]) == "stable"
		else:
			later_opens_drifting = later_opens_drifting or str(composed[ids[0]]["truth"]) == "drifting"
	for p in problems.slice(0, 8):
		print("  ", p)
	eq(problems.size(), 0, "500 drawn nights: each is one the rules allow, and every case in it holds")
	ok(repeat_ok, "the same seed always draws the same night")
	ok(orders.size() >= 30, "500 seeds give many orders (%d)" % orders.size())
	ok(first_steady, "the first night of a session opens with a steady visitor")
	ok(later_opens_drifting, "a later night may open with a drifting visitor")
	var drift_keys: Array = []
	for k in (rules["night"]["drifting"] as Dictionary).keys():
		drift_keys.append(int(k))
	var broken_keys: Array = []
	for k in (rules["night"]["broken"] as Dictionary).keys():
		broken_keys.append(int(k))
	var got_drift: Array = drift_counts.keys()
	var got_broken: Array = broken_counts.keys()
	for l in [drift_keys, broken_keys, got_drift, got_broken]:
		l.sort()
	eq(got_drift, drift_keys, "every number of drifting visitors the rules allow comes up, and no other")
	eq(got_broken, broken_keys, "every number of broken rows the rules allow comes up, and no other")
	var never_broken: Array = []
	for id in roster:
		for row in CaseDB.ROWS:
			if not broken_rows.has("%s:%s" % [str(id), row]):
				never_broken.append("%s:%s" % [str(id), row])
	eq(never_broken, [], "every row of every character is drawn broken on some night")
	var never_shown: Array = []
	for id in roster:
		for row in CaseDB.ROWS:
			for kind in ["normal", "broken"]:
				for sid in CaseDB.sign_ids(templates[str(id)], row, kind):
					if not shown.has("%s:%s:%s" % [str(id), row, str(sid)]):
						never_shown.append("%s:%s:%s" % [str(id), row, str(sid)])
	eq(never_shown, [], "every sign of every character is drawn on some night")
	# the money: a night's fees come under the line and within one drop of it
	var line := int(rules["line"]["per_hour"]) * int(rules["night"]["visitors"])
	var pay := int(rules["contacts"]["pay"])
	eq(CaseDB.fee_window(rules, 5), [line - pay, line - 1], "the fees of five visitors must come to %d-%d" % [line - pay, line - 1])
	eq(CaseDB.fees_of(people, rules["shift_order"]), 1900, "night A's fees: 1900")
	ok(CaseDB.fees_fit(rules, people, rules["shift_order"]), "and they fit the window")
	var lax := rules.duplicate(true)
	lax["night"]["fees_under_line"] = false
	ok(CaseDB.fee_window(lax, 5).is_empty() and CaseDB.fees_fit(lax, people, ["vale"]), "with the rule off any fees fit")
	# the test nights
	var nights: Dictionary = db["nights"]
	eq(CaseDB.validate_nights(nights, templates, rules, sheet, parts, people, contacts_data), [], "every test night is a night the draw could make")
	eq(CaseDB.night_coverage(nights, templates), [], "the test nights show every character steady and drifting, and every sign of every row")
	var a := CaseDB.compose_night(templates, nights["A"], parts)
	eq(CaseDB.night_order(nights["A"]), rules["shift_order"], "night A lists shift_order")
	eq(a.keys(), cases.keys(), "night A is what the game loads first")
	var truths := []
	var broken_a := []
	for id in CaseDB.night_order(nights["A"]):
		truths.append(str(a[id]["truth"]))
		broken_a.append(CaseDB.broken_count(a[id]))
	eq(truths, ["stable", "stable", "drifting", "stable", "drifting"], "night A: Vale and Maren drift, as written")
	eq(broken_a, [0, 0, 4, 0, 4], "night A: each of them shows four broken rows")
	eq([a["vale"]["rows"]["hands"]["ok"], a["vale"]["rows"]["port"]["ok"], a["maren"]["rows"]["hands"]["ok"], a["maren"]["rows"]["port"]["ok"]],
		[true, false, false, true], "night A: Vale's grip and Maren's port are the rows that look fine")
	# a night the draw could not make is caught
	var bad := (nights["A"] as Dictionary).duplicate(true)
	bad["visitors"][0]["truth"] = "drifting"
	bad["visitors"][0]["signs"] = {"eyes": "drags", "hands": "holds", "speech": "it"}
	bad["visitors"][3]["truth"] = "drifting"
	bad["visitors"][3]["signs"] = {"eyes": "stray", "speech": "we"}
	var bad_cases := CaseDB.compose_night(templates, bad, parts)
	var bad_errors := CaseDB.night_drawable(rules, bad, bad_cases, people, contacts_data)
	ok(has_error(bad_errors, "opens with a steady visitor"), "a first night that opens drifting is caught")
	ok(has_error(bad_errors, "never draws that many"), "four drifting visitors are caught")
	eq(CaseDB.night_drawable(rules, bad, bad_cases, people, contacts_data, false).size(), 1,
		"on a later night only the count of drifting visitors is wrong")
	var short := (nights["A"] as Dictionary).duplicate(true)
	(short["visitors"] as Array).pop_front()
	var short_errors := CaseDB.night_drawable(rules, short, CaseDB.compose_night(templates, short, parts), people, contacts_data)
	ok(has_error(short_errors, "asks for 5"), "a night of four visitors is caught")
	ok(has_error(short_errors, "fees add up to 1650"), "and so are its fees, out of the window for four hours")
	# bad draw rules are caught
	var wrong := rules.duplicate(true)
	wrong["night"]["visitors"] = (rules["roster"] as Array).size() + 1
	wrong["night"]["broken"] = {"1": 1, "x": 2}
	wrong["night"]["tries"] = 0
	var rule_errors := CaseDB.validate_rules(wrong, sheet)
	ok(has_error(rule_errors, "night.visitors must be from 1"), "more visitors than the roster holds is caught")
	var all_drift := rules.duplicate(true)
	all_drift["night"]["drifting"] = {"5": 1}
	ok(has_error(CaseDB.validate_rules(all_drift, sheet), "night.drifting: '5'"), "all five drifting, with a steady first visitor, is caught")
	ok(has_error(rule_errors, "night.broken: '1'") and has_error(rule_errors, "night.broken: 'x'"),
		"fewer broken rows than the house rule, or no number at all, is caught")
	ok(has_error(rule_errors, "night.tries"), "no tries is caught")
	# the shift plays the night it is given
	var drawn: Dictionary = ShiftState.draw_night(db, 7, true)
	var shift := ShiftState.new(rules, CaseDB.night_order(drawn))
	eq(shift.current_id(), str(CaseDB.night_order(drawn)[0]), "the shift follows the night it was given")
	eq(ShiftState.new(rules).current_id(), str(rules["shift_order"][0]), "given no order, a shift keeps night A's")


## Tonight's contacts (rules version 6, data/contacts.json): a fair list, drawn from the seed.
## Since rules version 9 fairness is a matter of the night: only the entries that are fair among
## tonight's visitors are drawn (CaseDB.fair_contacts).
func test_contacts() -> void:
	var people: Dictionary = CaseDB.load_all()["people"]
	eq(CaseDB.validate_contacts(contacts_data, people, rules), [], "the shipped contact list is sound")
	var clues: Dictionary = contacts_data["clues"]
	var alone_ok := true
	for cid in clues.keys():
		alone_ok = alone_ok and CaseDB.clue_matches(clues[cid], people).size() >= 2
	ok(alone_ok, "no clue alone points at one person of the roster")
	# The opening's Lanterns card shows a made-up list. Neither entry may fit anyone in the cast,
	# or the picture could be read as a real night's list.
	var intro: Dictionary = CaseDB.load_json("res://data/intro.json")
	var by_text := {}
	for cid in clues.keys():
		by_text[str(clues[cid]["text"])] = clues[cid]
	var card_entries: Array = []
	for card in intro.get("cards", []):
		if str(card.get("id", "")) == "lanterns":
			card_entries = card["labels"]["entries"]
	var made_up := card_entries.size() == 2
	for e in card_entries:
		var fits: Array = people.keys()
		for text in e["clues"]:
			made_up = made_up and by_text.has(str(text))
			if by_text.has(str(text)):
				var m: Array = CaseDB.clue_matches(by_text[str(text)], people)
				fits = fits.filter(func(id): return m.has(str(id)))
		made_up = made_up and fits.is_empty()
	ok(made_up, "the opening's Lanterns card: both made-up entries use the list's clues, and neither pair fits anyone in the cast")
	# night A's five visitors are half the roster: the entries of the other five cannot be drawn on it
	var pair_ok := true
	var per_case := {}
	var night_a_entries := 0
	for e in contacts_data["pool"]:
		per_case[str(e["case"])] = int(per_case.get(str(e["case"]), 0)) + 1
		if not cases.has(str(e["case"])):
			continue
		night_a_entries += 1
		var fits: Array = CaseDB.clue_matches(clues[str(e["clues"][0])], cases)
		var both: Array = []
		for f in CaseDB.clue_matches(clues[str(e["clues"][1])], cases):
			if fits.has(f):
				both.append(f)
		pair_ok = pair_ok and both == [str(e["case"])]
	eq(night_a_entries, 10, "ten entries are for night A's five visitors")
	ok(pair_ok, "on night A every entry of its visitors has two clues that together point at that visitor only")
	eq(CaseDB.fair_contacts(contacts_data, people, rules["shift_order"]).size(), night_a_entries,
		"so on night A every entry of its visitors is fair, and no other")
	for id in people.keys():
		ok(int(per_case.get(id, 0)) >= 2, "%s can be a courier under two different entries" % id)
	# fairness is a matter of who comes in
	var without_juno: Array = []
	for e in CaseDB.fair_contacts(contacts_data, people, ["kip", "rook", "vale", "maren"]):
		without_juno.append(str(e["id"]))
	ok(not without_juno.has("kip_a") and not without_juno.has("kip_b") and without_juno.has("rook_a"),
		"with Juno away, 'Under thirty.' and 'Here to swap a part.' each point at Kip alone: neither of his entries is used, Rook's is")
	var loose := contacts_data.duplicate(true)
	loose["pool"][0]["clues"] = ["under_thirty", "fee_low"]
	var loose_ids: Array = []
	for e in CaseDB.fair_contacts(loose, people, rules["shift_order"]):
		loose_ids.append(str(e["id"]))
	ok(not loose_ids.has("kip_a") and loose_ids.size() == night_a_entries - 1,
		"an entry whose two clues fit Kip and Juno both is not used on a night they both come")
	eq(CaseDB.fair_couriers(contacts_data, people, ["juno", "maren", "kip", "rook"]), ["kip", "rook"],
		"with Juno, Maren, Kip and Rook in, only Kip and Rook can carry a fair contact, in the order they come")
	eq(CaseDB.clue_matches({"eyes": "implants_both"}, cases), ["juno", "vale"], "implants in both eyes: Juno and Vale (Kip keeps one natural eye)")
	eq(CaseDB.clue_matches({"request_starts": "Swap"}, cases), ["juno", "kip"], "the swaps: Juno and Kip")
	# bad lists are caught
	var bad: Dictionary = contacts_data.duplicate(true)
	bad["clues"]["over_forty"]["age_min"] = 50
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "gives one away"), "a clue that fits one visitor alone is caught")
	bad = contacts_data.duplicate(true)
	bad["pool"][0]["clues"] = ["over_forty", "fee_low"]
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "does not fit its own courier"), "an entry whose clue does not fit its own courier is caught")
	bad = contacts_data.duplicate(true)
	bad["codes"][1]["say"] = bad["codes"][0]["say"]
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "code line"), "two codes with one line are caught")
	bad = contacts_data.duplicate(true)
	bad["aliases"][1] = bad["aliases"][0]
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "used twice"), "an alias listed twice is caught")
	bad = contacts_data.duplicate(true)
	bad["pool"][0]["alias"] = "LADLE"
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "has its own"), "an entry with an alias of its own is caught: each night draws one")
	bad = contacts_data.duplicate(true)
	bad["aliases"] = [bad["aliases"][0]]
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "aliases are listed"), "fewer aliases than contacts a night are caught")
	bad = contacts_data.duplicate(true)
	bad["codes"] = [bad["codes"][0]]
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "codes are listed"), "fewer codes than contacts a night are caught")
	bad = contacts_data.duplicate(true)
	bad["pool"][0]["case"] = "ghost"
	ok(has_error(CaseDB.validate_contacts(bad, cases, rules), "unknown visitor"), "an entry for nobody is caught")
	var greedy := rules.duplicate(true)
	greedy["contacts"]["per_night"] = 9
	ok(has_error(CaseDB.validate_contacts(contacts_data, cases, greedy), "contacts a night"), "more contacts a night than visitors is caught")
	# the draw
	var pool: Array = contacts_data["pool"]
	var order: Array = rules["shift_order"]
	var per := int(rules["contacts"]["per_night"])
	var all_ok := true
	var first_varies := {}
	for s in range(1, 41):
		var list := ShiftState.draw_contacts(rules, pool, order, s)
		var again := ShiftState.draw_contacts(rules, pool, order, s)
		var seen_cases := {}
		for e in list:
			seen_cases[str(e["case"])] = true
		all_ok = all_ok and list.size() == per and seen_cases.size() == per and list == again
		first_varies[str(list[0]["id"])] = true
		var trained := ShiftState.draw_contacts(rules, pool, order, s, true)
		var has_first := false
		for e in trained:
			has_first = has_first or str(e["case"]) == str(order[int(rules.contacts.training_slot) - 1])
		all_ok = all_ok and has_first and trained.size() == per
	ok(all_ok, "40 seeds: the same list for the same seed, %d couriers, all different, and the training night lists the second visitor" % per)
	ok(first_varies.size() > 3, "different seeds give different lists")
	# tonight's words (contacts.json version 2): each entry is given an alias and a code of the
	# lists, none twice in a night, from the shift seed; who is on the list does not change
	var aliases: Array = contacts_data["aliases"]
	var says: Array = []
	for code in contacts_data["codes"]:
		says.append(str(code["say"]))
	var words_ok := true
	var kip_aliases := {}
	var kip_says := {}
	for s in range(1, 41):
		var bare := ShiftState.draw_contacts(rules, pool, order, s)
		var named := ShiftState.draw_contacts(rules, pool, order, s, false, contacts_data)
		var named_again := ShiftState.draw_contacts(rules, pool, order, s, false, contacts_data)
		words_ok = words_ok and named.size() == bare.size() and named == named_again
		var night_aliases := {}
		var night_says := {}
		for i in named.size():
			var e: Dictionary = named[i]
			var at := says.find(str(e.get("say", "")))
			words_ok = words_ok and str(e["id"]) == str(bare[i]["id"]) and aliases.has(str(e.get("alias", ""))) and at >= 0
			words_ok = words_ok and str(e.get("answer", "")) == str(contacts_data["codes"][maxi(at, 0)]["answer"])
			night_aliases[str(e.get("alias", ""))] = true
			night_says[str(e.get("say", ""))] = true
			if str(e["case"]) == "kip":
				kip_aliases[str(e.get("alias", ""))] = true
				kip_says[str(e.get("say", ""))] = true
		words_ok = words_ok and night_aliases.size() == named.size() and night_says.size() == named.size()
	ok(words_ok, "40 seeds: each entry gets an alias and a code of the lists, none twice a night, the same for the same seed, and the entries are the ones drawn without them")
	ok(kip_aliases.size() > 3 and kip_says.size() > 3, "Kip carries other aliases and other codes on other nights")
	# the words give nobody away: no alias is a word of any visitor's file, no code line uses a
	# word (of four letters or more) of anyone's name, job or request, and the opening's made-up
	# entries (KESTREL, COPPER) use neither list
	var file_words := {}
	var card_words := {}
	for id in people.keys():
		for w in letter_words(FileAccess.get_file_as_string("res://data/cases/%s.json" % str(id))):
			file_words[w] = true
		var person: Dictionary = people[id]
		for w in letter_words("%s %s %s" % [person.get("name", ""), person.get("role", ""), person.get("request", "")]):
			if str(w).length() >= 4:
				card_words[w] = true
	var aliases_clear := file_words.size() > 100
	for a in aliases:
		for w in letter_words(str(a)):
			aliases_clear = aliases_clear and not file_words.has(w)
	ok(aliases_clear, "no alias is a word of any visitor's file")
	var codes_clear := card_words.size() > 20
	for say in says:
		for w in letter_words(str(say)):
			codes_clear = codes_clear and not card_words.has(w)
	ok(codes_clear, "no code line uses a word of anyone's name, job or request")
	var made_up_apart := card_entries.size() == 2
	for e in card_entries:
		made_up_apart = made_up_apart and not aliases.has(str(e.get("alias", ""))) and not says.has(str(e.get("code", "")))
	ok(made_up_apart, "the opening's made-up entries use no alias and no code of the list")
	var short_night := ShiftState.draw_contacts(rules, pool, ["maren"], 3)
	eq([short_night.size(), str(short_night[0]["case"])], [1, "maren"], "only tonight's visitors are drawn")
	var off := rules.duplicate(true)
	off["contacts"]["per_night"] = 0
	eq(ShiftState.draw_contacts(off, pool, order, 3), [], "per_night 0: no list")
	var shift := ShiftState.new(rules)
	shift.contacts = ShiftState.draw_contacts(rules, pool, order, 7)
	var listed: String = str(shift.contacts[0]["case"])
	eq(str(shift.contact_for(listed)["id"]), str(shift.contacts[0]["id"]), "contact_for finds a listed visitor")
	var unlisted := ""
	for id in order:
		if shift.contact_for(str(id)).is_empty():
			unlisted = str(id)
	ok(unlisted != "" and shift.contact_for(unlisted).is_empty(), "and nothing for one who is not on the list")
	eq(shift.report()["contacts"], per, "the report knows how many couriers the night had")


## Codes (rules version 6): the right courier answers for free and hands over the package; a
## wrong code costs patience and sounds the same to a courier as to anyone else.
func test_codes() -> void:
	var cost := int(rules["contacts"]["wrong_cost"])
	var pay := int(rules["contacts"]["pay"])
	var mine := courier("kip")
	var other := courier("juno")
	var v := visit("kip")
	v.set_contact(mine)
	var history_before: Array = v.record.entries.duplicate()
	var p := v.patience
	var res := v.say_code(other)
	eq([res["result"], res["cost"], v.patience, res["line"]], ["blank", cost, p - cost, str(cases["kip"]["lines"]["code"])],
		"another courier's code: their own puzzled line, and it costs patience")
	var stranger := visit("kip")
	var res_stranger := stranger.say_code(other)
	eq([res_stranger["result"], res_stranger["cost"], res_stranger["line"]], [res["result"], res["cost"], res["line"]],
		"a courier given the wrong code sounds exactly like a visitor who is not one")
	eq(v.say_code(other)["result"], "tried", "the same wrong code twice: nothing happens")
	eq(v.patience, p - cost, "and it costs nothing")
	res = v.say_code(mine)
	eq([res["result"], res["cost"], res["pay"], res["line"], res["package"]], ["drop", 0, pay, str(mine["answer"]), str(mine["package"])],
		"the right code: the answer, the package and the pay, for free")
	eq(v.patience, p - cost, "a right code costs no patience")
	eq(v.till_change(), pay, "the drop is in the till before the visit ends")
	eq(v.say_code(mine)["result"], "done", "a second code after the drop: the drop is done")
	eq(v.record.entries, history_before, "codes leave nothing in the patient's history")
	v.verdict("treat")
	var s := v.settlement()
	eq([s["credits"], s["outcome_credits"], s["drop"], s["dropped"], s["missed_drop"], s["codes_wrong"], s["contact"], s["alias"]],
		[int(cases["kip"]["fee"]) + pay, int(cases["kip"]["fee"]), pay, true, false, 1, true, str(mine["alias"])],
		"the slip pays the fee and the drop, and knows the courier")
	eq([s["correct"], s["outcome"]], [true, "treated_ok"], "a drop changes no call")
	# a courier who is not given the code takes the package home
	var missed := visit("vale")
	missed.set_contact(courier("vale"))
	missed.verdict("refer")
	missed.shutter()
	var ms := missed.settlement()
	eq([ms["missed_drop"], ms["drop"], ms["credits"]], [true, 0, int(cases["vale"]["fee"]) + int(rules["scoring"]["refer_drifting"])], "no code, no drop")
	# a drifting courier still drifts: the drop and the call are separate
	var risky := visit("maren")
	risky.set_contact(courier("maren"))
	eq(risky.say_code(courier("maren"))["result"], "drop", "a drifting courier still hands over the package")
	risky.verdict("treat")
	eq([risky.settlement()["outcome"], risky.settlement()["credits"]], ["treated_drifting", int(rules["scoring"]["treat_drifting"]) + pay],
		"and treating her is still the wrong call")
	# out of patience: no code is heard, right or wrong
	var gone := visit("kip")
	gone.set_contact(mine)
	gone.patience = 0
	eq([gone.say_code(mine)["result"], gone.say_code(other)["result"], gone.dropped], ["short", "short", false],
		"a patient on the way out hears no code: none can be tried for free")
	var closed := visit("kip")
	closed.set_contact(mine)
	closed.verdict("treat")
	eq(closed.say_code(mine)["result"], "closed", "no code after the visit is over")


## CALM (rules version 6) is a calm-patch from the drawer: credits as well as a use.
## Snaps and flares (rules version 6): a drifting patient may turn mid-exam, anyone may flare.
func test_surprises() -> void:
	var grace := int(rules["snap"]["grace"])
	var step := float(rules["snap"]["step"])
	var top := float(rules["snap"]["max"])
	var v := visit("vale")
	var odds: Array = []
	for i in 9:
		v.actions = i
		odds.append(snapped(v.snap_chance(), 0.0001))
	ok(odds[grace] == 0.0 and odds[0] == 0.0, "no snap in the first %d actions" % grace)
	ok(is_equal_approx(odds[grace + 1], step), "then step by step")
	ok(is_equal_approx(odds.max(), top), "never above the cap")
	var calm := visit("kip")
	var stable_never := true
	for i in 40:
		calm.actions = i
		stable_never = stable_never and calm.snap_chance() == 0.0
	ok(stable_never, "a steady patient never snaps, however long the exam")
	var trained := visit("maren")
	trained.surprises = false
	trained.actions = 20
	eq([trained.snap_chance(), trained.flare_chance()], [0.0, 0.0], "the training visit has no surprises")
	# many rolled visits: snaps only for the drifting, flares at most once a visit
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var stable_snaps := 0
	var drifting_snaps := 0
	var flares := 0
	var double_flare := false
	for n in 400:
		for id in ["kip", "vale"]:
			var w := visit(id)
			var got := 0
			for a in 8:
				var r := w.roll_action(rng)
				if r == "snap":
					if id == "kip":
						stable_snaps += 1
					else:
						drifting_snaps += 1
					break
				if r == "flare":
					got += 1
					w.flare()
			flares += got
			double_flare = double_flare or got > 1
	eq(stable_snaps, 0, "800 rolled visits: no steady patient snapped")
	ok(drifting_snaps > 0, "a drifting one did")
	ok(flares > 0 and not double_flare, "flares happen, never twice in a visit")
	# a snap is the ordinary attack, and the ordinary shutter answers it
	var s := visit("vale")
	ok(s.snap(), "a drifting patient can snap")
	eq([s.phase, s.attack_cause], [VisitState.Phase.ATTACK, "snap"], "a snap is an attack")
	s.shutter()
	var ss := s.settlement()
	eq([ss["outcome"], ss["correct"], ss["credits"], ss["snapped"], ss["cause"]], ["caught", true, int(cases["vale"]["fee"]) + int(rules["scoring"]["refer_drifting"]), true, "snap"],
		"caught in time: a right call, paid like one")
	var late := visit("maren")
	late.snap()
	late.attack_timeout()
	var ls := late.settlement()
	eq([ls["outcome"], ls["correct"], ls["credits"], ls["injured"]], ["hit", false, int(rules["scoring"]["hit"]), true],
		"not in time: no call, and it hurt")
	ok(not visit("kip").snap(), "a steady patient cannot be made to snap")
	var courier_lost := visit("vale")
	courier_lost.set_contact(courier("vale"))
	courier_lost.snap()
	courier_lost.shutter()
	eq(courier_lost.settlement()["missed_drop"], true, "a courier who snaps before the code takes the package with them")
	# a flare is never an attack, and its note is TEMPER evidence that agrees with the case
	for id in cases.keys():
		var f := visit(id)
		var fr := f.flare()
		ok(fr["ok"] and f.phase == VisitState.Phase.EXAM, "%s: a flare leaves the exam running" % id)
		ok(f.row_seen("temper"), "%s: and counts as seeing the temper" % id)
		var noted := false
		for note in f.notes["temper"]:
			noted = noted or str(note["key"]) == "flare"
		ok(noted, "%s: the flare is written on the TEMPER line" % id)
		eq(f.flare()["ok"], false, "%s: only once a visit" % id)
		f.verdict("treat")
		eq(f.settlement()["credits"], f.credits_for(f.outcome), "%s: a flare costs and pays nothing" % id)
	var plain := rules.duplicate(true)
	plain.erase("snap")
	plain.erase("flare")
	var quiet := VisitState.new((cases["vale"] as Dictionary).duplicate(true), plain)
	var never := true
	for a in 30:
		never = never and quiet.roll_action(rng) == ""
	ok(never, "a rule set without snaps or flares has neither")


func test_brain() -> void:
	var a := ScriptedBrain.new(7)
	var b := ScriptedBrain.new(7)
	var v := visit("kip")
	var ev := {"type": "check", "id": "port"}
	eq(a.decide(v.case_data, ev, v.snapshot(), ["comply"]), b.decide(v.case_data, ev, v.snapshot(), ["comply"]),
		"same seed, same scripted answer")
	v = visit("rook")
	eq(brain_move(v, "check", "grip").move, "stall", "Rook voices an authored hesitation")
	eq(brain_move(v, "ask", "mood").move, "answer", "listed questions always answered")
	v = visit("vale")
	eq(ScriptedBrain.authored_line(v.case_data, "answer", {"type": "ask", "id": "sleep"}),
		"It doesn't need much sleep. I take what's left.", "authored answer lookup")


func test_agent() -> void:
	var client := FakeClient.new()
	var policy := rules.duplicate(true)
	policy["agent"]["ask_answers"] = "model"
	var agent := PatientAgent.new(policy, client, 3)
	var v := visit("kip")
	eq(agent.max_calls, int(rules.agent.max_model_calls_per_visit), "call cap comes from the rules")
	ok(agent.max_calls >= 12, "the cap leaves room for a conversation, not four lines")
	agent.max_calls = 4      # the cap itself is tested with a small number
	agent.run_id = "test-session"
	agent.begin_visit(v, "test-visit", 3)
	var ev := {"type": "check", "id": "grip", "text": "Hold the handle."}
	var d: Dictionary = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d["source"], "script", "offline mode remains a comparison")
	eq(client.calls, 0, "offline mode does not call a provider")
	agent.set_mode("model")
	client.reply = {"ok": true, "data": {"reply": "Not until you explain the grip test.", "reaction": "Pulls a hand back.", "cooperates": true}}
	d = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d["source"], "model", "free response accepted")
	eq(d["move"], "comply", "hesitation in the line does not deny consent")
	var applied := v.apply_check("grip", str(d.move), true)
	eq(applied.result, "granted", "the patient cannot veto the instrument")
	display_answer(agent, d)
	var payload := agent.build_payload({"type": "say", "id": "free", "text": "What would reassure you?"}, v.snapshot())
	ok(not payload.has("legal_moves"), "no legal moves transmitted")
	eq(payload.signs, {}, "an unopened visit reveals neither sign")
	eq(v.open_signs(), {}, "a tool refusal opens no speech or temper gate")
	ok(not payload.has("truth") and not (payload.state as Dictionary).has("truth") and not JSON.stringify(payload).contains("drifting"),
		"and never names the patient's truth")
	var night_vale := PatientAgent.new(rules, client, 3)
	night_vale.begin_visit(visit("vale"), "test-vale", 3)
	eq(night_vale.build_payload({"type": "say", "id": "free", "text": "Go on."}, {}).get("signs"), {},
		"Vale also begins with both signs hidden")
	var bare := PatientAgent.new(rules, client, 3)
	bare.begin_visit(VisitState.new({"id": "kip", "version": 3}, rules), "test-bare", 3)
	eq(bare.build_payload({}, {}).signs, {}, "no signs are sent by default")
	ok(JSON.stringify(payload.conversation_history).contains("Not until"), "actual previous speech remembered")
	client.reply = {"ok": true, "data": {"reply": "My pupils look fine. Why are you worried?", "reaction": "Studies the doctor.", "cooperates": true}}
	d = await agent.decide({"type": "ask", "id": "why", "outcome": "answer", "text": "What happened?"}, v.snapshot(), ["answer"])
	eq(d.reply, "My pupils look fine. Why are you worried?", "novel answer and symptom words survive unchanged")
	applied = v.apply_ask("why", str(d.move), str(d.reply))
	eq(applied.line, d.reply, "visit records actual AI words")
	ok(JSON.stringify(v.notes.speech).contains("My pupils"), "record contains actual speech")
	ok(not JSON.stringify(v.notes.speech).contains("ate pavement"), "record has no phantom authored evidence")
	client.reply = {"ok": true, "data": {"reply": 7, "reaction": ""}}
	d = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d.fallback_reason, "invalid:reply_missing", "malformed response falls back explicitly")
	client.reply = {"ok": false, "error": "timeout"}
	d = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d.fallback_reason, "timeout", "timeout falls back")
	d = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d.fallback_reason, "call_cap", "cost cap enforced")
	agent.begin_visit(visit("maren"), "test-next", 4)
	ok(not JSON.stringify(agent.record.entries).contains("My pupils"), "history reset between patients")
	eq(agent.calls_this_visit, 0, "per-visit budget resets")


## A typed or spoken conversation: many turns, each one carried to the next request.
func test_visit_record() -> void:
	var v := visit("kip")
	var a := PatientAgent.new(rules)
	a.run_id = "one-shift"
	a.begin_visit(v, "appointment-one", 11)
	v.record.append("patient", "I work nights.")
	var ev := {"type":"say", "id":"free", "text":"How about that grip test?"}
	for i in 180:
		v.record.append("doctor", str(i) + " 问一下握力和轮班的事。".repeat(25) + " \"OK?\"")
		if i == 85:
			v.apply_check("grip", "comply", true)
			v.complete_check("grip")
			v.press()
	v.record.append("patient", "My shift starts at nine.")
	var request := a.build_payload(ev, v.snapshot())
	var summary: Dictionary = request.visit_summary
	var excerpt: Array = request.conversation_history
	ok(JSON.stringify(request).to_utf8_buffer().size() <= int(rules.agent.max_body_bytes), "an oversized multilingual visit fits the real UTF-8 POST limit")
	eq(excerpt.front(), v.record.entries.front(), "opening words survive a long visit")
	eq(excerpt.back(), v.record.entries.back(), "the latest reply survives a long visit")
	eq(request.event, ev, "the current question is never compacted")
	eq(excerpt.size() + int(summary.omitted), v.record.entries.size(), "every entry is either present or counted in the missing span")
	eq(excerpt.slice(0, summary.after), v.record.entries.slice(0, summary.after), "the leading excerpt is in original order")
	eq(excerpt.slice(summary.after), v.record.entries.slice(summary.after + summary.omitted), "the recent excerpt is in original order")
	eq([summary.actions.get("done:grip"), summary.actions.get("press:1")], [1,1], "a completed grip and actual pressure survive even in the missing span")
	ok(not excerpt.has({"role":"action","text":"done:grip"}), "the test placed grip in the omitted middle")
	excerpt.front().text = "changed wire copy"
	eq(v.record.entries.front().text, "I work nights.", "a request cannot alter the original journal")
	var returning_patient := visit("kip")
	a.begin_visit(returning_patient, "appointment-two", 12)
	var return_request := a.build_payload(ev, returning_patient.snapshot())
	eq([request.run_id, request.session_id, request.visit_id], ["one-shift", "appointment-one", "appointment-one"], "one session includes every route for this visit")
	eq([return_request.run_id, return_request.session_id, return_request.visit_id], ["one-shift", "appointment-two", "appointment-two"], "the same patient on a return visit gets a new session inside the same run quota")
	ok(v.record.entries.is_empty() and return_request.conversation_history.is_empty() and not return_request.has("visit_summary"), "neither the prior words nor action totals follow the patient")
	a.end_visit()
	ok(a.record == null and a.visit_id.is_empty() and a.build_payload(ev, {}).is_empty(), "a closed appointment cannot build another patient request")


func display_answer(agent: PatientAgent, answer: Dictionary) -> void:
	agent.record.append("reaction", Lang.t(str(answer.get("reaction", ""))))
	agent.record.append("patient", Lang.t(str(answer.reply)))


func test_visit_intent_cache() -> void:
	var language := Lang.code
	Lang.pin("en")
	var client := IntentClient.new()
	var agent := PatientAgent.new(rules, client)
	var v := visit("rook")
	agent.begin_visit(v, "one", 1)
	agent.set_mode("model")
	var line := "May I ask you about the docks?"
	var result: Dictionary = await agent.classify(str(v.case_data.topics[0].q))
	eq([result.source, client.calls], ["listed", 0], "an exact listed question needs no classifier")
	result = await agent.classify(line)
	eq([result.source, client.calls], ["model", 1], "a new free line uses the classifier")
	result.intent = "other"
	result = await agent.classify(line)
	eq([result.source, result.intent, client.calls], ["cache", "social", 1], "a cached classification is independent of the caller's dictionary")
	Lang.pin("zh")
	result = await agent.classify(Lang.t(str(v.case_data.topics[0].q)))
	eq([result.source, client.calls], ["listed", 1], "the displayed Chinese question also skips classification")
	result = await agent.classify(line)
	eq([result.source, client.calls], ["model", 2], "each language has its own routing result")
	agent.max_intents = 2
	result = await agent.classify(line)
	eq([result.source, agent.intents_this_visit], ["cache", 2], "reusing a result spends no visit quota")
	agent.begin_visit(visit("rook"), "two", 2)
	client.reply = {"ok": false, "error": "timeout"}
	result = await agent.classify(line)
	eq([result.reason, client.calls], ["timeout", 3], "a returning patient starts cold")
	client.reply = {"ok": true, "data": {"about": "mood"}}
	result = await agent.classify(line)
	eq([result.source, result.topic, client.calls], ["model", "mood", 4], "a failed classification can be retried")
	agent.end_visit()
	ok(agent._intent_cache.is_empty(), "closing clears the visit's routing results")
	Lang.pin(language)


func test_conversation() -> void:
	var client := FakeClient.new()
	var agent := PatientAgent.new(rules, client, 5)
	var v := visit("rook")
	agent.run_id = "test-session"
	agent.begin_visit(v, "test-talk", 5)
	agent.set_mode("model")
	for line in v.case_data.opening:
		v.record.append("patient", Lang.t(str(line)))
	var opening: int = agent.record.entries.size()
	for i in agent.max_calls:
		client.reply = {"ok": true, "data": {"reply": "Answer number %d, in my own words." % i, "reaction": "Shifts weight, turn %d." % i}}
		var ev := {"type": "say", "id": "free", "text": "Doctor line %d?" % i}
		var d: Dictionary = await agent.decide(ev, v.snapshot(), [])
		eq(d.source, "model", "turn %d answered by the patient model" % i)
		display_answer(agent, d)
	eq(client.calls, agent.max_calls, "one model call per line said")
	eq(agent.calls_this_visit, agent.max_calls, "every line counted against the visit")
	var payload := agent.build_payload({"type": "say", "id": "free", "text": "And now?"}, v.snapshot())
	var sent := JSON.stringify(payload.conversation_history)
	eq(payload.conversation_history, v.record.entries, "the whole appointment fits in the request, including its opening")
	ok(payload.conversation_history.size() > 48 and sent.contains("Doctor line 0?"), "the first words survive sixteen model calls")
	ok(sent.contains("Doctor line %d?" % (agent.max_calls - 1)) and sent.contains("Answer number %d," % (agent.max_calls - 1)),
		"the latest exchange is in the next request")
	ok(sent.contains("Answer number 1,"), "an early exchange is still remembered at the cap")
	ok(opening > 0 and agent.record.entries.size() == opening + 3 * agent.max_calls,
		"doctor line, reaction and reply are all remembered")
	eq(int(v.asked.get("free", 0)), 0, "conversation history and question counts are separate")
	eq(v.patience, v.patience_max, "small talk never costs patience")
	var d2: Dictionary = await agent.decide({"type": "say", "id": "free", "text": "One more?"}, v.snapshot(), [])
	eq(d2.fallback_reason, "call_cap", "past the cap the model is not called")
	eq(client.calls, agent.max_calls, "and no request leaves the game")
	ok(str(d2.reply) != "", "the capped line still gets a spoken fallback")
	# a reply a little over the asked length is kept whole; only an unshowable one fails
	agent.begin_visit(v, "test-talk-2", 6)
	var longish := "I told you already, it locks when the cold gets in. ".repeat(3).strip_edges()
	ok(longish.length() > agent.max_line_chars and longish.length() <= agent.max_reply_chars, "test line sits between the two limits")
	client.reply = {"ok": true, "data": {"reply": longish, "reaction": ""}}
	var d3: Dictionary = await agent.decide({"type": "say", "id": "free", "text": "Go on."}, v.snapshot(), [])
	eq(d3.reply, longish, "a reply past the asked length is delivered unchanged")
	client.reply = {"ok": true, "data": {"reply": "x".repeat(agent.max_reply_chars + 1), "reaction": ""}}
	d3 = await agent.decide({"type": "say", "id": "free", "text": "Go on."}, v.snapshot(), [])
	eq(d3.fallback_reason, "invalid:reply_too_long", "a reply the strip cannot show falls back")
	eq(agent.max_reply_chars, int(rules.agent.max_reply_chars), "display bound comes from the rules")
	# in Chinese the request names the language and asks for Chinese lengths, and a reply is held
	# to what the strip shows of Chinese
	Lang.pin("zh")
	var zh := agent.build_payload({"type": "say", "id": "free", "text": "还疼吗？"}, v.snapshot())
	eq(str(zh.get("language", "")), "zh", "a game in Chinese says so to the proxy")
	eq(int(zh.limits.max_line_chars), int(rules.agent.languages.zh.max_line_chars), "and asks for a Chinese line's length")
	eq(agent.reply_chars(), int(rules.agent.languages.zh.max_reply_chars), "a Chinese reply has the Chinese bound")
	eq(str(agent.build_voice_payload(PackedByteArray([0, 0, 0, 0])).get("language", "")), "zh", "a clip says which language it is spoken in")
	client.reply = {"ok": true, "data": {"reply": "好".repeat(agent.reply_chars() + 1), "reaction": ""}}
	d3 = await agent.decide({"type": "say", "id": "free", "text": "说下去。"}, v.snapshot(), [])
	eq(d3.fallback_reason, "invalid:reply_too_long", "a Chinese reply the strip cannot show falls back")
	Lang.pin("en")
	var en := agent.build_payload({"type": "say", "id": "free", "text": "Go on."}, v.snapshot())
	eq(str(en.get("language", "")), "en", "English says so too")
	eq(int(en.limits.max_line_chars), agent.max_line_chars, "with the English length")
	eq(agent.reply_chars(), agent.max_reply_chars, "and the English bound")


## Offline only: a sentence in the doctor's own words finds the question the script knows.
func test_offline_say() -> void:
	var said := {
		"kip": {"How did you crack that lens?": "why", "Are you sleeping all right?": "sleep", "Does the implant ever glitch?": "implant"},
		"rook": {"When did it begin?": "why", "Why are you so angry with me?": "mood", "Has the arm been moving without you?": "implant"},
		"vale": {"Why do you want the limiter removed?": "why", "Any blackouts or missing time?": "lapses", "How much rest do you get?": "sleep"},
		"juno": {"Tell me about your voice.": "why", "Is any of that chrome acting strange?": "chrome", "Do you sleep?": "sleep"},
		"maren": {"What do you mean, they keep working?": "why", "Are you scared of your own hands?": "fear", "Getting any sleep?": "sleep"},
	}
	for id in said.keys():
		var c: Dictionary = cases[id]
		var lines: Dictionary = said[id]
		for line in lines.keys():
			eq(ScriptedBrain.topic_for_text(c, str(line)), str(lines[line]), "%s: \"%s\"" % [id, line])
		for t in c.topics:
			eq(ScriptedBrain.topic_for_text(c, str(t.q)), str(t.id), "%s: its own question \"%s\" finds its topic" % [id, t.q])
			ok(typeof(t.get("keys")) == TYPE_ARRAY and not (t.keys as Array).is_empty(), "%s/%s has words for the offline matcher" % [id, t.id])
		eq(ScriptedBrain.topic_for_text(c, "Nice weather tonight."), "", id + ": small talk matches nothing")
		eq(ScriptedBrain.topic_for_text(c, ""), "", id + ": silence matches nothing")
		eq(ScriptedBrain.topic_for_text(c, "?!... 123"), "", id + ": no words, no match")
	# in Chinese the catalogs add words of their own (data/lang/zh: topics.json for every patient,
	# a case catalog's "<case>:<topic>" for one): the doctor's own Chinese finds the same questions,
	# and so does each authored question's translation
	Lang.pin("zh")
	var said_zh := {
		"kip": {"你的镜片是怎么裂的？": "why", "最近睡得好吗？": "sleep", "这东西会自己乱动吗？": "implant"},
		"rook": {"胳膊什么时候开始卡的？": "why", "你为什么这么生气？": "mood", "它会不会不听使唤？": "implant"},
		"vale": {"为什么想拆掉它？": "why", "你会不会断片？": "lapses", "你每天睡多久？": "sleep"},
		"juno": {"你的声音出了什么事？": "why", "这些改装有没有故障？": "chrome", "晚上能睡着吗？": "sleep"},
		"maren": {"它们停不下来是什么意思？": "why", "你害怕它们吗？": "fear", "最近累不累？": "sleep"},
	}
	for id in said_zh.keys():
		var c: Dictionary = cases[id]
		var lines: Dictionary = said_zh[id]
		for line in lines.keys():
			eq(ScriptedBrain.topic_for_text(c, str(line)), str(lines[line]), "zh %s: \"%s\"" % [id, line])
		for t in c.topics:
			var q := Lang.t(str(t.q))
			ok(Lang.has_cjk(q), "zh %s/%s: the question is translated" % [id, t.id])
			eq(ScriptedBrain.topic_for_text(c, q), str(t.id), "zh %s: its own question \"%s\" finds its topic" % [id, q])
		for line in ["今晚天气不错。", "你叫什么名字？", "我们开始吧。"]:
			eq(ScriptedBrain.topic_for_text(c, line), "", "zh %s: small talk \"%s\" matches nothing" % [id, line])
	Lang.pin("en")
	# the offline patient declines a sentence it has no answer for, in its own voice
	for id in cases.keys():
		var v := visit(id)
		var agent := PatientAgent.new(rules, null, 2)
		agent.begin_visit(v, "offline-say", 2)
		var d: Dictionary = await agent.decide({"type": "say", "id": "free", "text": "Nice weather tonight."}, v.snapshot(), [])
		eq(d.source, "script", id + ": offline say stays offline")
		ok(not str(d.reply).is_empty(), id + ": the offline patient has a conversation fallback")


## `count` identical stereo frames.
func level_frames(count: int, left: float, right: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(count)
	out.fill(Vector2(left, right))
	return out


func tone_frames(seconds: float, loudness: float, rate: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(int(round(seconds * rate)))
	for i in out.size():
		var s: float = sin(TAU * 220.0 * float(i) / rate) * loudness
		out[i] = Vector2(s, s)
	return out


func _hear(agent: PatientAgent, wav: PackedByteArray, into: Array) -> void:
	into.append(await agent.transcribe(wav))


## Push-to-talk below the screen: the clip, the microphone node and the request for its words.
## The microphone here is simulated. No device is opened and nothing is recorded.
func test_voice() -> void:
	var voice: Dictionary = rules.agent.voice
	ok(bool(voice.enabled), "push-to-talk is on in the rules")
	ok(float(voice.min_seconds) > 0.0 and float(voice.min_seconds) < float(voice.max_seconds), "a clip has a shortest and a longest length")
	ok(float(voice.max_seconds) <= 10.0, "the longest clip is one the proxy accepts")
	ok(float(voice.silence_peak) > 0.0 and float(voice.silence_peak) < 0.1, "the silence level is a quiet one")
	ok(int(voice.timeout_ms) > int(rules.agent.timeout_ms), "a clip may take longer to answer than a typed line")
	# any sound card rate comes out as one second of 16 kHz samples per second heard
	for rate in [48000.0, 44100.0, 22050.0, 16000.0, 8000.0]:
		var c := VoiceClip.new(rate, 10.0)
		var loud: float = c.push(level_frames(int(rate), 0.5, 0.5))
		ok(absi(c.count() - VoiceClip.RATE) <= 1, "%d Hz: one second in is one second out (%d samples)" % [int(rate), c.count()])
		ok(is_equal_approx(loud, 0.5) and is_equal_approx(c.peak, 0.5), "%d Hz: the loudest sample is reported" % int(rate))
		var steady := true
		for i in [0, 1, c.count() / 2, c.count() - 1]:
			steady = steady and absi(c.sample(i) - 16384) <= 1
		ok(steady, "%d Hz: the level survives the change of rate" % int(rate))
	# left and right are averaged; too loud is clipped, not wrapped
	var clip := VoiceClip.new(16000.0, 1.0)
	clip.push(level_frames(4, 1.0, -1.0))
	eq([clip.sample(0), clip.sample(3), clip.peak], [0, 0, 0.0], "opposite channels cancel")
	clip.push(level_frames(1, 0.8, 0.0))
	ok(absi(clip.sample(4) - 13107) <= 1, "one live channel is heard at half")
	var loudest: float = clip.push(level_frames(1, 2.0, 2.0))
	clip.push(level_frames(1, -2.0, -2.0))
	eq([clip.sample(5), clip.sample(6), loudest, clip.peak], [32767, -32767, 1.0, 1.0], "too loud is clipped")
	# three 48 kHz frames make one sample (their mean); one 8 kHz frame makes two
	clip = VoiceClip.new(48000.0, 1.0)
	clip.push(PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.6, 0.6), Vector2(0.9, 0.9)]))
	ok(clip.count() == 1 and absi(clip.sample(0) - 19660) <= 1, "going down in rate averages, it does not skip")
	clip = VoiceClip.new(8000.0, 1.0)
	clip.push(level_frames(1, 0.5, 0.5))
	ok(clip.count() == 2 and clip.sample(0) == clip.sample(1) and absi(clip.sample(0) - 16384) <= 1, "going up in rate repeats")
	# a clip stops at its longest length
	clip = VoiceClip.new(16000.0, 0.5)
	ok(not clip.full(), "an empty clip is not full")
	clip.push(level_frames(16000, 0.2, 0.2))
	ok(clip.full() and clip.count() == 8000 and is_equal_approx(clip.seconds(), 0.5), "a clip holds max_seconds and no more")
	clip.push(level_frames(100, 0.9, 0.9))
	ok(clip.count() == 8000 and is_equal_approx(clip.peak, 0.2), "what comes after the end is not heard")
	# the same sound gives the same clip however the card slices it
	var sound := tone_frames(0.3, 0.4, 44100.0)
	var whole := VoiceClip.new(44100.0, 2.0)
	whole.push(sound)
	var sliced := VoiceClip.new(44100.0, 2.0)
	var at := 0
	for size in [441, 1000, 37, 1, 4096, 99999]:
		var upto: int = mini(at + int(size), sound.size())
		sliced.push(sound.slice(at, upto))
		at = upto
	ok(at == sound.size() and whole.count() == 4800 and sliced.wav() == whole.wav(), "chunk sizes do not change the clip")
	# the clip as a file in memory
	var wav := whole.wav()
	eq(wav.size(), VoiceClip.HEADER + whole.count() * 2, "a 44-byte header, then two bytes a sample")
	eq([wav.slice(0, 4).get_string_from_ascii(), wav.slice(8, 16).get_string_from_ascii(), wav.slice(36, 40).get_string_from_ascii()],
		["RIFF", "WAVEfmt ", "data"], "RIFF, WAVE, fmt and data are where a reader expects them")
	eq([wav.decode_u32(4), wav.decode_u32(16), wav.decode_u16(20), wav.decode_u16(22), wav.decode_u32(24), wav.decode_u32(28),
		wav.decode_u16(32), wav.decode_u16(34), wav.decode_u32(40)],
		[36 + whole.count() * 2, 16, 1, 1, 16000, 32000, 2, 16, whole.count() * 2], "plain PCM, mono, 16 kHz, 16 bit")
	eq(wav.decode_s16(VoiceClip.HEADER + 2 * 100), whole.sample(100), "the samples follow the header untouched")
	eq(VoiceClip.new(48000.0, 1.0).wav().size(), VoiceClip.HEADER, "an empty clip is a header and nothing else")
	var longest := VoiceClip.new(48000.0, float(voice.max_seconds))
	longest.push(level_frames(int(48000.0 * float(voice.max_seconds)) + 48, 0.1, 0.1))
	ok(longest.full() and Marshalls.raw_to_base64(longest.wav()).length() + 512 <= 524288, "the longest clip fits the proxy's request size")

	# the microphone node, simulated: frames are handed to it and no device is opened
	var mic := VoiceInput.new()
	mic.simulated = true
	mic.max_seconds = 1.0
	var fills := [0]
	mic.filled.connect(func() -> void: fills[0] += 1)
	ok(mic.stop().is_empty() and not mic.listening and mic.seconds() == 0.0, "a closed microphone has nothing to hand over")
	mic.feed(tone_frames(0.2, 0.5, mic.simulated_rate))
	eq(mic.seconds(), 0.0, "and hears nothing")
	eq([mic.problem(), mic.start(), mic.listening], ["", "", true], "it opens on request")
	mic.feed(tone_frames(0.5, 0.3, mic.simulated_rate))
	eq(mic.start(), "", "opening it twice is harmless")
	ok(absf(mic.seconds() - 0.5) < 0.01, "and the clip it had is kept")
	ok(mic.level > 0.6 and mic.level <= 1.0, "speech fills most of the meter")
	var level_before: float = mic.level
	mic._process(0.25)
	ok(mic.level < level_before and mic.level > 0.0, "the meter falls back by itself")
	eq(fills[0], 0, "a clip that still has room is not announced as full")
	mic.feed(tone_frames(0.6, 0.3, mic.simulated_rate))
	ok(fills[0] >= 1, "a full clip is announced, so the game can stop by itself")
	var heard: Dictionary = mic.stop()
	ok(not mic.listening and is_equal_approx(float(heard.seconds), 1.0) and absf(float(heard.peak) - 0.3) < 0.01,
		"stopping hands over the clip: its length and its loudest moment")
	eq((heard.wav as PackedByteArray).size(), VoiceClip.HEADER + 32000, "and its samples")
	ok(mic.stop().is_empty(), "once")
	mic.start()
	mic.feed(tone_frames(0.3, 0.3, mic.simulated_rate))
	mic.cancel()
	ok(not mic.listening and mic.stop().is_empty() and mic.level == 0.0, "a cancelled clip is thrown away")
	mic.free()
	# a device that is slow to open (the real one takes about 450 ms): nothing is heard until it is ready
	var slow := VoiceInput.new()
	slow.simulated = true
	slow.simulated_open_seconds = 0.4
	eq([slow.start(), slow.listening, slow.opening], ["", true, true], "a slow microphone is asked for and is still opening")
	slow.feed(tone_frames(0.3, 0.3, slow.simulated_rate))
	eq(slow.seconds(), 0.0, "what is said while it opens is not heard")
	var early: Dictionary = slow.stop()
	ok(not slow.listening and not slow.opening and float(early.seconds) == 0.0 and (early.wav as PackedByteArray).is_empty(),
		"letting go while it opens hands over an empty clip")
	slow.start()
	slow._process(0.25)
	ok(slow.opening and slow.listening, "it is still opening after a quarter second")
	slow._process(0.25)
	ok(not slow.opening and slow.listening, "then it listens")
	slow.feed(tone_frames(0.5, 0.3, slow.simulated_rate))
	ok(absf(slow.seconds() - 0.5) < 0.01, "and hears from then on")
	slow.cancel()
	ok(not slow.listening and not slow.opening and slow.stop().is_empty(), "thrown away, nothing is left")
	slow.free()
	# the real microphone is only asked whether it could be opened: these tests never open it
	var real := VoiceInput.new()
	eq(bool(ProjectSettings.get_setting("audio/driver/enable_input", false)), true, "the project allows microphone input on request")
	eq(real.problem(), "", "the engine has the direct input calls the microphone needs")
	ok(not real.listening and real.stop().is_empty(), "and nothing is open until the speak key is held")
	real.free()
	ok(VoiceInput.meter(0.0) == 0.0 and VoiceInput.meter(1.0) == 1.0, "the meter runs from nothing to full")
	ok(VoiceInput.meter(float(voice.silence_peak)) < VoiceInput.meter(0.1) and VoiceInput.meter(0.1) < VoiceInput.meter(0.5), "and louder reads higher")

	# the request for a clip's words
	var client := VoiceClient.new()
	var agent := PatientAgent.new(rules, client, 9)
	agent.run_id = "test-session"
	var v := visit("kip")
	agent.begin_visit(v, "voice-visit", 9)
	eq(agent.max_voice_clips, int(voice.max_clips_per_visit), "the clip cap comes from the rules")
	var said := VoiceClip.make_wav(PackedByteArray([1, 0, 2, 0, 255, 127]))
	var r: Dictionary = await agent.transcribe(said)
	eq([r.get("ok"), r.get("error"), client.calls], [false, "not_configured", 0], "the offline comparison sends no clip anywhere")
	agent.set_mode("model")
	var history: int = agent.record.entries.size()
	client.reply = {"ok": true, "data": {"text": "  Does the arm ever move by itself?  ", "meta": {"mock": true}}}
	r = await agent.transcribe(said)
	eq([r.get("ok"), r.get("text"), r.get("mock")], [true, "Does the arm ever move by itself?", true], "the words come back, marked when the transport is a mock")
	var sent: Dictionary = client.last
	var keys: Array = sent.keys()
	keys.sort()
	eq(keys, ["audio", "client", "language", "protocol", "run_id", "session_id", "visit_id"],
		"a clip travels with its session, visit and language: no case, state or history")
	eq([sent.protocol, sent.run_id, sent.session_id, sent.visit_id, sent.audio.mime], ["5", "test-session", "voice-visit", "voice-visit", "audio/wav"], "in protocol 5, as a WAV")
	eq(Marshalls.base64_to_raw(str(sent.audio.data)), said, "the samples arrive as they were")
	eq([agent.calls_this_visit, agent.record.entries.size()], [0, history], "words written down are not a line said: no dialogue call, nothing remembered")
	client.reply = {"ok": true, "data": {"text": "Plain words."}}
	r = await agent.transcribe(said)
	eq([r.get("ok"), r.get("mock")], [true, false], "a real service is not marked as a mock")
	for bad in [{"ok": true, "data": {"text": "   "}}, {"ok": true, "data": {"text": 7}}, {"ok": true, "data": "words"}, {"ok": true}]:
		client.reply = bad
		r = await agent.transcribe(said)
		eq([r.get("ok"), r.get("error")], [false, "invalid"], "an answer without words is refused: %s" % JSON.stringify(bad))
	client.reply = {"ok": false, "error": "http_422:no_speech"}
	r = await agent.transcribe(said)
	eq([r.get("ok"), r.get("error")], [false, "http_422:no_speech"], "the proxy's reason is passed on")
	eq(agent.voice_clips_this_visit, client.calls, "every clip sent is counted, heard or not")
	agent.max_voice_clips = agent.voice_clips_this_visit + 1
	client.reply = {"ok": true, "data": {"text": "Last one."}}
	r = await agent.transcribe(said)
	var before_cap: int = client.calls
	var capped: Dictionary = await agent.transcribe(said)
	eq([r.get("ok"), capped.get("ok"), capped.get("error"), client.calls], [true, false, "clip_cap", before_cap], "past the cap no clip leaves the game")
	agent.begin_visit(visit("maren"), "voice-next", 10)
	eq(agent.voice_clips_this_visit, 0, "the next patient starts a new count")
	agent.max_voice_clips = int(voice.max_clips_per_visit)
	# words that come back after the patient has gone belong to nobody
	client.hold = true
	client.reply = {"ok": true, "data": {"text": "Late words."}}
	var late: Array = []
	_hear(agent, said, late)
	eq([client.calls, late.size()], [before_cap + 1, 0], "a slow service keeps the game waiting")
	agent.begin_visit(visit("rook"), "voice-after", 11)
	client.released.emit()
	ok(late.size() == 1 and (late[0] as Dictionary).is_empty(), "a transcript for the last patient is dropped")
	var same: Array = []
	_hear(agent, said, same)
	client.released.emit()
	ok(same.size() == 1 and bool((same[0] as Dictionary).get("ok", false)) and str((same[0] as Dictionary).get("text", "")) == "Late words.",
		"one for this patient is kept, however slow")
	client.hold = false
	# a client that cannot hear is reported, not called
	var deaf := PatientAgent.new(rules, FakeClient.new(), 9)
	deaf.begin_visit(v, "voice-deaf", 9)
	deaf.set_mode("model")
	r = await deaf.transcribe(said)
	eq([r.get("ok"), r.get("error")], [false, "not_configured"], "a client without a speech route is never asked")


## Small talk must never push evidence off a full row of the record.
func test_note_room() -> void:
	var v := visit("kip")
	ok(v.add_note("speech", "evidence:a", "Slurs the long words."), "evidence note written")
	for i in 8:
		eq(v.apply_ask("free", "answer", "Chatter %d." % i).result, "closed", "only case questions enter the card")
	var keys: Array = []
	for n in v.notes.speech:
		keys.append(str(n.key))
	ok(keys.has("evidence:a"), "evidence survives a long conversation")
	eq(keys.size(), 1, "small talk takes no room")
	ok(not JSON.stringify(v.notes.speech).contains("Chatter 7."), "the last small-talk line stays off the card")
	ok(not JSON.stringify(v.notes.speech).contains("Chatter 0."), "the oldest small talk made room")
	ok(v.add_note("speech", "evidence:b", "Second finding."), "second evidence note written")
	ok(v.add_note("speech", "evidence:c", "Third finding."), "third evidence note written")
	keys = []
	for n in v.notes.speech:
		keys.append(str(n.key))
	eq(keys, ["evidence:a", "evidence:b", "evidence:c"], "evidence replaces talk, in order")


func test_validator() -> void:
	ok(MoveValidator.validate({"reply": "My pupils are fine.", "reaction": ""}, 110)["ok"], "symptom words allowed")
	ok(MoveValidator.validate({"reply": "<b>Maybe</b> [not sure]", "reaction": ""}, 110)["ok"], "literal punctuation is not semantic filtering")
	eq(MoveValidator.validate({"reply": "", "reaction": ""}, 110)["reason"], "reply_empty", "empty reply")
	eq(MoveValidator.validate({"reply": "x".repeat(111), "reaction": ""}, 110)["reason"], "reply_too_long", "display size limit")
	eq(MoveValidator.validate("hello", 110)["reason"], "not_object", "non-object")
	eq(MoveValidator.validate({"reply": "Sure.", "reaction": ""}, 110, true)["reason"], "cooperates_missing", "tool consent is explicit")
	ok(MoveValidator.validate({"reply": "No.", "reaction": "Turns away.", "cooperates": false}, 110, true)["ok"], "refusal accepted")


func has_error(errors: Array, fragment: String) -> bool:
	for e in errors:
		if str(e).contains(fragment):
			return true
	return false


func test_bad_data() -> void:
	var c: Dictionary = (cases["kip"] as Dictionary).duplicate(true)
	c["rows"]["port"]["ok"] = false
	ok(not has_error(CaseDB.validate_case(c, rules, {}, parts), "at most one worn"), "one worn port is legal")
	c.rows.hands.ok = false
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "at most one worn"), "two worn lines on a stable visitor are rejected")
	c = (cases["kip"] as Dictionary).duplicate(true)
	c["press"][1]["end"] = "attack"
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "must never attack"), "stable attacker is caught")
	c = (cases["vale"] as Dictionary).duplicate(true)
	for row in ["eyes", "speech", "temper"]:
		c["rows"][row]["ok"] = true
	for side in ["left", "right"]:
		c["eyes"][side]["follows"] = true
		c["eyes"][side]["tightens"] = true
	ok(not CaseDB.validate_case(c, rules, sheet, parts).is_empty(), "one broken row cannot establish drift")
	c = (cases["vale"] as Dictionary).duplicate(true)
	c["checks"]["penlight"]["first"] = ["explain:ghost"]
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "unknown claim"), "unknown claim is caught")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["grip"]["release_ms"] = 400
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "rows.hands.ok"), "grip data and sheet row must agree")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["eyes"]["left"]["tightens"] = true
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "rows.eyes.ok"), "eye data and sheet row must agree")
	c = (cases["juno"] as Dictionary).duplicate(true)
	c["outcomes"].erase("false_alarm")
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "outcomes.false_alarm"), "missing outcome text is caught")
	# rules version 4 and later, sheet version 3 and later
	for id in cases.keys():
		eq(CaseDB.validate_case(cases[id], rules, sheet, parts), [], "%s validates against the sheet's house rule" % id)
	c = (cases["rook"] as Dictionary).duplicate(true)
	c["outcomes"].erase("gave_up")
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "outcomes.gave_up"), "every patient needs a slip for leaving unanswered")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["exit"].erase("gave_up")
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "exit.gave_up"), "and a parting line")
	c = (cases["vale"] as Dictionary).duplicate(true)
	for row in ["port", "speech", "temper"]:
		c["rows"][row]["ok"] = true
	ok(has_error(CaseDB.validate_case(c, rules, sheet, parts), "broken sheet lines"), "a drifting patient with fewer broken lines than the house rule is caught")
	ok(not has_error(CaseDB.validate_case(c, rules, {}, parts), "broken sheet lines"), "without a sheet, one broken line is all that is asked")
	c = (cases["juno"] as Dictionary).duplicate(true)
	c["lines"].erase("code")
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "lines.code"), "every visitor needs a reply to a wrong code")
	c = (cases["rook"] as Dictionary).duplicate(true)
	c.erase("flare")
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "flare must be"), "and a flare")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["attack"]["line"] = ""
	ok(has_error(CaseDB.validate_case(c, rules, {}, parts), "can snap"), "a drifting patient who can snap needs an attack line")
	eq(CaseDB.validate_rules(rules), [], "the shipped rules validate")
	eq(CaseDB.validate_sheet(sheet), [], "the shipped sheet validates")
	var bad_odds := rules.duplicate(true)
	bad_odds["snap"]["max"] = 1.5
	ok(has_error(CaseDB.validate_rules(bad_odds), "snap.max"), "a snap chance above one is caught")
	bad_odds = rules.duplicate(true)
	bad_odds["flare"]["delay_min_ms"] = 2000
	ok(has_error(CaseDB.validate_rules(bad_odds), "flare.delay_min_ms"), "a flare delay that ends before it starts is caught")
	bad_odds = rules.duplicate(true)
	bad_odds["complaints"]["normal"] = -0.1
	ok(has_error(CaseDB.validate_rules(bad_odds), "complaints.normal"), "a negative complaint probability is caught")
	bad_odds = rules.duplicate(true)
	bad_odds["contacts"]["per_night"] = 3
	ok(has_error(CaseDB.validate_rules(bad_odds), "at most 2"), "more couriers than the list paper holds is caught")
	var bad := rules.duplicate(true)
	bad["attack"]["blow_at"] = [0.5, 0.4, 0.8]
	ok(has_error(CaseDB.validate_rules(bad), "blow_at must rise"), "blows out of order are caught")
	bad = rules.duplicate(true)
	bad["attack"]["blow_at"] = []
	ok(has_error(CaseDB.validate_rules(bad), "at least one blow"), "an attack with no blows is caught")
	bad = rules.duplicate(true)
	bad["attack"]["glass"] = 4
	ok(has_error(CaseDB.validate_rules(bad), "attack.glass"), "more glass than blows is caught")
	bad = rules.duplicate(true)
	bad["attack"]["min_window_ms"] = 100
	ok(has_error(CaseDB.validate_rules(bad), "min_window_ms"), "a shutter window nobody could meet is caught")
	bad = rules.duplicate(true)
	bad["attack"]["repair_cost"] = -5
	ok(has_error(CaseDB.validate_rules(bad), "repair_cost"), "a fitter who pays the doctor is caught")
	bad = rules.duplicate(true)
	bad["attack"].erase("repair_cost")
	eq(CaseDB.validate_rules(bad), [], "rules without a repair price are still rules")
	bad = rules.duplicate(true)
	bad.erase("line")
	ok(has_error(CaseDB.validate_rules(bad), "'line' must be an object"), "rules without a line are caught")
	bad = rules.duplicate(true)
	bad["patience"]["leave_ms"] = -1
	ok(has_error(CaseDB.validate_rules(bad), "leave_ms"), "a negative wait is caught")
	var bad_sheet := sheet.duplicate(true)
	bad_sheet["threshold"] = 0
	ok(has_error(CaseDB.validate_sheet(bad_sheet), "threshold"), "a sheet without a house rule is caught")
	bad_sheet["threshold"] = 6
	ok(has_error(CaseDB.validate_sheet(bad_sheet), "threshold"), "and one asking for more lines than the sheet has")
