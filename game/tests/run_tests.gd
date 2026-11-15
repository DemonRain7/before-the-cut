extends SceneTree
## Headless rule tests for the reference-sheet loop (case data version 2, rules version 3).
## The second decision is a call to Trauma Team; in the rules and the data its id is "refer".
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

const NOTE_MAX_PX := 186   # width of the note column on the patient record

var passed := 0
var failed := 0
var rules: Dictionary = {}
var cases: Dictionary = {}


class FakeClient:
	extends RefCounted
	var reply: Dictionary = {}
	var calls := 0
	func request_move(_payload: Dictionary) -> Dictionary:
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
	var db: Dictionary = CaseDB.load_all()
	eq(db["errors"], [], "shipped data validates")
	rules = db["rules"]
	cases = db["cases"]
	test_data()
	test_verdict_any_time()
	test_looks()
	test_checks()
	test_talk()
	test_press_and_attack()
	test_shutter()
	test_settlement_rows()
	test_shift()
	test_brain()
	await test_agent()
	await test_conversation()
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
		for z in c["looks"].keys():
			texts.append(str(c["looks"][z]))
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
			eq(v.settlement()["credits"], int(rules["scoring"]["refer_drifting"]), "%s: handover fee" % id)
			eq(v.settlement()["title"], "TAKEN IN", "%s: the slip names the handover" % id)


func test_looks() -> void:
	var v := visit("kip")
	for zone in ["eyes", "hands", "port"]:
		var r := v.look(zone)
		ok(bool(r["ok"]) and str(r["text"]) != "", "kip look %s returns text" % zone)
	eq(v.patience, v.patience_max, "looking costs no patience")
	eq((v.notes["eyes"] as Array).size(), 1, "look adds a record note")
	v.look("eyes")
	eq((v.notes["eyes"] as Array).size(), 1, "the same look is not noted twice")
	ok(v.row_seen("port"), "an exposed port is evidence by looking")
	ok(not v.row_seen("eyes"), "looking at eyes is not the penlight result")
	var m := visit("maren")
	var covered := m.look("port")
	ok(bool(covered["covered"]), "maren's port is covered")
	ok(not m.row_seen("port"), "a covered port shows nothing")
	ok(not m.port_visible(), "covered port is not visible before asking")


func test_checks() -> void:
	# cooperative patient
	var v := visit("kip")
	eq(v.legal_moves_for_check("penlight"), ["comply"], "kip allows the penlight")
	var r := v.apply_check("penlight", "comply")
	eq(r["result"], "granted", "penlight granted")
	eq(v.patience, 5, "a tool costs one patience")
	ok(not v.row_seen("eyes"), "granted is not yet seen")
	var done := v.complete_check("penlight")
	ok(bool(done["ok"]) and v.row_seen("eyes"), "finishing the penlight shows the evidence")
	eq(v.check_cost("penlight"), 0, "repeating a granted tool is free")
	v.apply_check("penlight", "comply")
	eq(v.patience, 5, "repeat did not charge")
	ok(str(v.complete_check("grip")["text"]) == "", "a tool that was not granted cannot complete")
	v.apply_check("grip", "comply")
	eq(str(v.complete_check("grip")["text"]), "Grip: jittery. Let go 0.3 s after 'release'.", "grip note carries the time")
	eq(v.check_status("port"), "open", "an exposed port needs no permission")

	# stall, then insist
	v = visit("rook")
	var pick := brain_move(v, "check", "grip")
	eq(pick["move"], "stall", "rook stalls the grip bar first")
	eq(pick["line"], "I didn't come here to hold hands.", "rook's stall line")
	r = v.apply_check("grip", str(pick["move"]))
	eq(r["result"], "refused", "stall refuses the tool")
	eq(v.patience, 4, "a refused request still costs")
	eq(v.check_status("grip"), "refused", "grip is marked refused")
	eq(v.check_cost("grip"), 2, "insisting costs more")
	eq(v.legal_moves_for_check("grip"), ["comply"], "rook gives in when you insist")
	r = v.apply_check("grip", "stall")
	eq(r["result"], "granted", "an illegal stall is replaced by the legal move")
	eq(v.patience, 2, "insist charged two")
	ok(bool(r["insisted"]), "insist flag set")
	ok(not v.row_seen("hands"), "refusal revealed nothing")

	# stall, then reassure
	v = visit("rook")
	v.apply_check("grip", "stall")
	var re := v.reassure()
	eq(re["result"], "ok", "reassure works")
	eq(v.patience, 5, "reassure gives patience back")
	eq(v.check_cost("grip"), 1, "after reassurance the tool costs the normal price")
	eq(v.legal_moves_for_check("grip"), ["comply"], "after reassurance the patient complies")

	# a refusal that insisting cannot break
	v = visit("vale")
	eq(v.legal_moves_for_check("port"), ["stall"], "vale will not show the port at first")
	v.apply_check("port", "stall")
	eq(v.legal_moves_for_check("port"), ["stall"], "insisting does not open vale's collar")
	r = v.apply_check("port", "comply")
	eq(r["result"], "refused", "comply is not legal there, so it stays refused")
	ok(not v.row_seen("port"), "port still hidden")
	v.reassure()
	eq(v.legal_moves_for_check("port"), ["comply"], "reassurance opens it")
	v.apply_check("port", "comply")
	eq(str(v.complete_check("port")["text"]), "Neck socket: dark threads under the skin.", "port evidence is fixed")
	ok(v.row_seen("port") and v.port_visible(), "port now seen")
	eq(str(v.look("port")["text"]), "Neck socket: dark threads under the skin.", "looking again shows the same socket")

	# an explanation instead of the test
	v = visit("vale")
	pick = brain_move(v, "check", "penlight")
	eq(pick["move"], "explain:idle", "vale offers an explanation for the penlight")
	r = v.apply_check("penlight", str(pick["move"]))
	eq(r["result"], "explained", "explanation result")
	ok(v.claims.has("idle"), "claim recorded")
	eq(str((v.notes["eyes"] as Array)[0]["text"]), "Says his optics idle indoors.", "claim is noted as a statement")
	ok(not v.row_seen("eyes"), "a claim is not evidence")
	eq(v.legal_moves_for_check("penlight"), ["comply"], "insisting gets the penlight")
	v.apply_check("penlight", "comply")
	v.complete_check("penlight")
	ok(v.row_seen("eyes"), "the eye evidence cannot be refused for good")

	# out of patience
	v = visit("rook")
	v.patience = 0
	r = v.apply_check("penlight", "comply")
	eq(r["result"], "spent", "no patience: the request is not granted")
	ok(not v.granted.has("penlight"), "nothing was granted")
	eq(v.verdict("treat")["next"], "done", "a verdict is still possible at zero patience")


func test_talk() -> void:
	var v := visit("kip")
	var r := v.apply_ask("why", "answer")
	eq(r["result"], "answered", "kip answers")
	eq(v.patience, 5, "a question costs one patience")
	ok(v.row_seen("speech"), "an answer is speech evidence")
	eq(v.ask_cost("why"), 0, "asking again is free")
	v.apply_ask("why", "answer")
	eq(v.patience, 5, "repeat question did not charge")

	v = visit("rook")
	var pick := brain_move(v, "ask", "mood")
	eq(pick["move"], "deflect", "rook deflects the mood question first")
	eq(pick["line"], "What's that got to do with my arm?", "deflect line is the topic's own")
	r = v.apply_ask("mood", str(pick["move"]))
	eq(r["result"], "deflected", "deflected")
	ok(not v.row_seen("speech"), "a deflection is not evidence")
	eq(v.legal_moves_for_ask("mood"), ["answer"], "asked again, he answers")
	r = v.apply_ask("mood", "deflect")
	eq(r["result"], "answered", "second ask is answered")
	eq(v.patience, 3, "both asks cost")

	v = visit("vale")
	v.apply_ask("why", "answer")
	ok(not v.row_seen("speech"), "vale's polished answer is not his slip")
	v.apply_ask("sleep", "answer")
	ok(v.row_seen("speech"), "the sleep answer is the speech evidence")
	eq(str(v.apply_ask("nope", "answer")["result"]), "closed", "unknown topic is ignored")


func test_press_and_attack() -> void:
	var v := visit("kip")
	var r := v.press()
	eq(r["result"], "react", "first press is a reaction")
	eq(v.patience, 4, "pressure costs two patience")
	ok(v.row_seen("temper"), "the reaction is temper evidence")
	eq(v.phase, VisitState.Phase.EXAM, "one press never ends a visit")
	r = v.press()
	eq(r["result"], "walkout", "a stable patient walks out on the second press")
	eq(v.outcome, "walkout", "walkout outcome")
	eq(v.settlement()["credits"], 0, "walkout earns nothing")
	ok(not v.settlement()["correct"], "walkout is not a correct call")
	eq(v.press()["result"], "closed", "no pressing after the visit")

	for id in ["vale", "maren"]:
		v = visit(id)
		eq(v.press()["result"], "react", "%s: first press is safe" % id)
		eq(v.press()["result"], "attack", "%s: second press brings the attack" % id)
		eq(v.attack_cause, "press", "%s: cause recorded" % id)
		eq(v.shutter()["result"], "caught", "%s: shutter stops it" % id)
		eq(v.settlement()["credits"], int(rules["scoring"]["refer_drifting"]), "%s: caught pays the handover fee" % id)
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
	eq(rows.size(), 5, "five rows on the slip")
	ok(not bool(rows[0]["ok"]) and bool(rows[0]["seen"]), "eyes: broken and seen")
	eq(int(rows[0]["mark"]), 2, "player mark is carried to the slip")
	ok(not bool(rows[1]["ok"]) and not bool(rows[1]["seen"]), "hands: broken, not checked")
	ok(bool(rows[2]["ok"]), "maren's port is fine")


## calls: case id -> "treat" | "refer" | "shutter". A patient who turns on the call is shut out in
## time, unless their id is in `slow`: then the shutter never comes and the blow lands.
func play(shift: ShiftState, calls: Dictionary, slow: Array = []) -> void:
	while not shift.is_done():
		var id := shift.current_id()
		var v := visit(id)
		var call := str(calls[id])
		if call == "shutter":
			v.shutter()
		elif str(v.verdict(call)["next"]) == "attack":
			if slow.has(id):
				v.attack_timeout()
			else:
				v.shutter()
		shift.record(v.settlement())
		shift.advance()


func test_shift() -> void:
	var shift := ShiftState.new(rules)
	eq(shift.current_id(), "kip", "shift starts with kip")
	eq(shift.upcoming_id(), "rook", "rook is next")
	play(shift, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"})
	var rep := shift.report()
	eq(rep["total"], 1140, "perfect shift total")
	eq(rep["correct"], 5, "perfect shift calls")
	eq(rep["title"], "STEADY HANDS", "perfect shift title")
	ok(bool(rep["rent_paid"]), "perfect shift pays rent")
	shift = ShiftState.new(rules)
	play(shift, {"kip": "treat", "rook": "treat", "vale": "treat", "juno": "treat", "maren": "treat"})
	rep = shift.report()
	eq(rep["total"], 100, "treat-everyone total")
	eq(rep["correct"], 3, "treat-everyone calls")
	ok(not bool(rep["rent_paid"]), "treat-everyone misses rent")
	shift = ShiftState.new(rules)
	play(shift, {"kip": "refer", "rook": "refer", "vale": "refer", "juno": "refer", "maren": "refer"})
	rep = shift.report()
	eq(rep["total"], -210, "call-everyone total: three call-outs billed")
	eq(rep["correct"], 2, "call-everyone calls")
	ok(not bool(rep["rent_paid"]), "call-everyone misses rent")
	eq(rep["title"], "LICENCE UNDER REVIEW", "call-everyone title")
	# one needless call can be afforded, two cannot
	var one := ShiftState.new(rules)
	play(one, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "refer", "maren": "refer"})
	eq(one.report()["total"], 640, "one false call total")
	eq(one.report()["correct"], 4, "one false call leaves four right calls")
	ok(bool(one.report()["rent_paid"]), "one false call still pays rent")
	var two := ShiftState.new(rules)
	play(two, {"kip": "treat", "rook": "refer", "vale": "refer", "juno": "refer", "maren": "refer"})
	eq(two.report()["total"], 190, "two false calls total")
	ok(not bool(two.report()["rent_paid"]), "two false calls miss rent")
	# the report says in words what the till means, and its title reads the whole night
	eq(str(rep["rent_text"]), str(rules["rent_text"]["short"]), "a night that misses rent says the rent is short")
	eq(str(one.report()["rent_text"]), str(rules["rent_text"]["paid"]), "a night that covers rent says the rent is paid")
	eq(one.report()["title"], "A GOOD NIGHT'S WORK", "four right calls, nobody hurt, rent paid: a good night's work")
	eq(two.report()["title"], "OPEN, BARELY", "three right calls: open, barely")
	var hurt := ShiftState.new(rules)
	play(hurt, {"kip": "treat", "rook": "treat", "vale": "refer", "juno": "treat", "maren": "refer"}, ["vale"])
	var hurt_rep := hurt.report()
	eq(hurt_rep["correct"], 5, "a right call that ended in a blow is still a right call")
	eq(hurt_rep["injuries"], 1, "and the blow is counted")
	eq(hurt_rep["total"], 720, "right every time but hurt once: 720 in the till")
	eq(hurt_rep["title"], "RIGHT THE HARD WAY", "five right calls with an injury are not called steady hands")
	var thin := ShiftState.new(rules)
	play(thin, {"kip": "treat", "rook": "treat", "vale": "treat", "juno": "treat", "maren": "shutter"})
	var thin_rep := thin.report()
	eq(thin_rep["correct"], 4, "treating Vale is the one wrong call; locking Maren out is a right one")
	eq(thin_rep["total"], 500, "four right calls can still leave 500 in the till")
	ok(not bool(thin_rep["rent_paid"]), "which does not cover the rent")
	eq(thin_rep["title"], "OPEN, BARELY", "four right calls that miss rent are not called a good night")
	var sore := ShiftState.new(rules)
	for row in [[250, true, false], [300, true, false], [350, true, false], [120, true, false], [-300, false, true]]:
		sore.record({"credits": row[0], "correct": row[1], "injured": row[2]})
		sore.advance()
	ok(bool(sore.report()["rent_paid"]) and int(sore.report()["correct"]) == 4, "four right calls, rent paid, one blow taken")
	eq(sore.report()["title"], "OPEN, BARELY", "a night that hurt you is not called a good night either")
	for entry in rules["titles"]:
		ok(str(entry["title"]) != "" and str(entry["text"]) != "", "report title '%s' has its text" % str(entry["title"]))
	eq(int((rules["titles"] as Array).back()["min_correct"]), 0, "the last title fits any night")
	ok(not (rules["titles"] as Array).back().has("max_injuries") and not (rules["titles"] as Array).back().has("rent_paid"),
		"and asks for nothing else")
	ok(int(rules["scoring"]["false_call"]) < int(rules["scoring"]["false_alarm"]),
		"calling an armed crew on a steady patient costs more than a false alarm")
	ok(shift.is_done() and shift.current_id() == "", "shift ends after five")


func test_brain() -> void:
	var a := ScriptedBrain.new(7)
	var b := ScriptedBrain.new(7)
	var v := visit("kip")
	var ev := {"type": "check", "id": "port"}
	eq(a.decide(v.case_data, ev, v.snapshot(), ["comply"]), b.decide(v.case_data, ev, v.snapshot(), ["comply"]),
		"same seed, same scripted answer")
	# stateful: a reassured Rook does not stall
	v = visit("rook")
	v.reassure()
	eq(brain_move(v, "check", "grip")["move"], "comply", "rook complies at once if reassured first")
	eq(brain_move(v, "ask", "mood")["move"], "answer", "rook answers at once if reassured first")
	# a scripted move that is not legal is never returned
	v = visit("vale")
	v.apply_check("penlight", "explain:idle")
	eq(brain_move(v, "check", "penlight")["move"], "comply", "claim cannot be offered twice")
	eq(ScriptedBrain.authored_line(v.case_data, "answer", {"type": "ask", "id": "sleep"}),
		"It doesn't need much sleep. I take what's left.", "authored answer lookup")


func test_agent() -> void:
	var client := FakeClient.new()
	var agent := PatientAgent.new(rules, client, 3)
	var v := visit("kip")
	eq(agent.max_calls, int(rules.agent.max_model_calls_per_visit), "call cap comes from the rules")
	ok(agent.max_calls >= 12, "the cap leaves room for a conversation, not four lines")
	agent.max_calls = 4      # the cap itself is tested with a small number
	agent.session_id = "test-session"
	agent.begin_visit(v.case_data, "test-visit", 3)
	var ev := {"type": "check", "id": "grip", "text": "Hold the handle."}
	var d: Dictionary = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d["source"], "script", "offline mode remains a comparison")
	eq(client.calls, 0, "offline mode does not call a provider")
	agent.set_mode("model")
	client.reply = {"ok": true, "data": {"reply": "Not until you explain the grip test.", "reaction": "Pulls a hand back.", "cooperates": false}}
	d = await agent.decide(ev, v.snapshot(), ["comply"])
	eq(d["source"], "model", "free response accepted")
	eq(d["move"], "stall", "model can refuse outside authored cooperation options")
	var applied := v.apply_check("grip", str(d.move), true)
	eq(applied.result, "refused", "refusal is not coerced into scripted comply")
	agent.remember_exchange(ev, d)
	var payload := agent.build_payload({"type": "say", "id": "free", "text": "What would reassure you?"}, v.snapshot())
	ok(not payload.has("legal_moves"), "no legal moves transmitted")
	ok(JSON.stringify(payload.conversation_history).contains("Not until"), "actual previous speech remembered")
	client.reply = {"ok": true, "data": {"reply": "My pupils look fine. Why are you worried?", "reaction": "Studies the doctor."}}
	d = await agent.decide({"type": "ask", "id": "why", "text": "What happened?"}, v.snapshot(), ["answer"])
	eq(d.reply, "My pupils look fine. Why are you worried?", "novel answer and symptom words survive unchanged")
	applied = v.apply_dialogue("why", str(d.reply), str(d.reaction))
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
	agent.begin_visit(cases["maren"], "test-next", 4)
	ok(not JSON.stringify(agent.conversation_history).contains("My pupils"), "history reset between patients")
	eq(agent.calls_this_visit, 0, "per-visit budget resets")


## A typed or spoken conversation: many turns, each one carried to the next request.
func test_conversation() -> void:
	var client := FakeClient.new()
	var agent := PatientAgent.new(rules, client, 5)
	var v := visit("rook")
	agent.session_id = "test-session"
	agent.begin_visit(v.case_data, "test-talk", 5)
	agent.set_mode("model")
	var opening: int = agent.conversation_history.size()
	for i in agent.max_calls:
		client.reply = {"ok": true, "data": {"reply": "Answer number %d, in my own words." % i, "reaction": "Shifts weight, turn %d." % i}}
		var ev := {"type": "say", "id": "free", "text": "Doctor line %d?" % i}
		var d: Dictionary = await agent.decide(ev, v.snapshot(), [])
		eq(d.source, "model", "turn %d answered by the patient model" % i)
		agent.remember_exchange(ev, d)
		v.apply_dialogue("free", str(d.reply), str(d.reaction))
	eq(client.calls, agent.max_calls, "one model call per line said")
	eq(agent.calls_this_visit, agent.max_calls, "every line counted against the visit")
	var payload := agent.build_payload({"type": "say", "id": "free", "text": "And now?"}, v.snapshot())
	var sent := JSON.stringify(payload.conversation_history)
	ok(payload.conversation_history.size() <= PatientAgent.MAX_HISTORY, "history sent stays within the proxy's limit")
	ok(sent.contains("Doctor line %d?" % (agent.max_calls - 1)) and sent.contains("Answer number %d," % (agent.max_calls - 1)),
		"the latest exchange is in the next request")
	ok(sent.contains("Answer number 1,"), "an early exchange is still remembered at the cap")
	ok(opening > 0 and agent.conversation_history.size() == mini(PatientAgent.MAX_HISTORY, opening + 3 * agent.max_calls),
		"doctor line, reaction and reply are all remembered")
	eq(int(v.asked.get("free", 0)), agent.max_calls, "the visit counts free lines")
	eq(v.ask_cost("free"), 0, "only the first free line costs patience")
	var d2: Dictionary = await agent.decide({"type": "say", "id": "free", "text": "One more?"}, v.snapshot(), [])
	eq(d2.fallback_reason, "call_cap", "past the cap the model is not called")
	eq(client.calls, agent.max_calls, "and no request leaves the game")
	ok(str(d2.reply) != "", "the capped line still gets a spoken fallback")
	# a reply a little over the asked length is kept whole; only an unshowable one fails
	agent.begin_visit(v.case_data, "test-talk-2", 6)
	var longish := "I told you already, it locks when the cold gets in. ".repeat(3).strip_edges()
	ok(longish.length() > agent.max_line_chars and longish.length() <= agent.max_reply_chars, "test line sits between the two limits")
	client.reply = {"ok": true, "data": {"reply": longish, "reaction": ""}}
	var d3: Dictionary = await agent.decide({"type": "say", "id": "free", "text": "Go on."}, v.snapshot(), [])
	eq(d3.reply, longish, "a reply past the asked length is delivered unchanged")
	client.reply = {"ok": true, "data": {"reply": "x".repeat(agent.max_reply_chars + 1), "reaction": ""}}
	d3 = await agent.decide({"type": "say", "id": "free", "text": "Go on."}, v.snapshot(), [])
	eq(d3.fallback_reason, "invalid:reply_too_long", "a reply the strip cannot show falls back")
	eq(agent.max_reply_chars, int(rules.agent.max_reply_chars), "display bound comes from the rules")


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
	# the offline patient declines a sentence it has no answer for, in its own voice
	for id in cases.keys():
		var v := visit(id)
		var agent := PatientAgent.new(rules, null, 2)
		agent.begin_visit(v.case_data, "offline-say", 2)
		var d: Dictionary = await agent.decide({"type": "say", "id": "free", "text": "Nice weather tonight."}, v.snapshot(), [])
		eq(d.source, "script", id + ": offline say stays offline")
		var pool: Array = v.case_data.lines.deflect if typeof(v.case_data.lines.deflect) == TYPE_ARRAY else [v.case_data.lines.deflect]
		ok(pool.has(d.reply), id + ": unknown sentence gets that patient's own deflection")


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
	agent.session_id = "test-session"
	var v := visit("kip")
	agent.begin_visit(v.case_data, "voice-visit", 9)
	eq(agent.max_voice_clips, int(voice.max_clips_per_visit), "the clip cap comes from the rules")
	var said := VoiceClip.make_wav(PackedByteArray([1, 0, 2, 0, 255, 127]))
	var r: Dictionary = await agent.transcribe(said)
	eq([r.get("ok"), r.get("error"), client.calls], [false, "not_configured", 0], "the offline comparison sends no clip anywhere")
	agent.set_mode("model")
	var history: int = agent.conversation_history.size()
	client.reply = {"ok": true, "data": {"text": "  Does the arm ever move by itself?  ", "meta": {"mock": true}}}
	r = await agent.transcribe(said)
	eq([r.get("ok"), r.get("text"), r.get("mock")], [true, "Does the arm ever move by itself?", true], "the words come back, marked when the transport is a mock")
	var sent: Dictionary = client.last
	var keys: Array = sent.keys()
	keys.sort()
	eq(keys, ["audio", "client", "protocol", "session_id", "visit_id"], "a clip travels with its session and visit: no case, state or history")
	eq([sent.protocol, sent.session_id, sent.visit_id, sent.audio.mime], ["3", "test-session", "voice-visit", "audio/wav"], "in protocol 3, as a WAV")
	eq(Marshalls.base64_to_raw(str(sent.audio.data)), said, "the samples arrive as they were")
	eq([agent.calls_this_visit, agent.conversation_history.size()], [0, history], "words written down are not a line said: no dialogue call, nothing remembered")
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
	agent.begin_visit(cases["maren"], "voice-next", 10)
	eq(agent.voice_clips_this_visit, 0, "the next patient starts a new count")
	agent.max_voice_clips = int(voice.max_clips_per_visit)
	# words that come back after the patient has gone belong to nobody
	client.hold = true
	client.reply = {"ok": true, "data": {"text": "Late words."}}
	var late: Array = []
	_hear(agent, said, late)
	eq([client.calls, late.size()], [before_cap + 1, 0], "a slow service keeps the game waiting")
	agent.begin_visit(cases["rook"], "voice-after", 11)
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
	deaf.begin_visit(v.case_data, "voice-deaf", 9)
	deaf.set_mode("model")
	r = await deaf.transcribe(said)
	eq([r.get("ok"), r.get("error")], [false, "not_configured"], "a client without a speech route is never asked")


## Small talk must never push evidence off a full row of the record.
func test_note_room() -> void:
	var v := visit("kip")
	ok(v.add_note("speech", "evidence:a", "Slurs the long words."), "evidence note written")
	for i in 8:
		v.apply_dialogue("free", "Chatter %d." % i, "")
	var keys: Array = []
	for n in v.notes.speech:
		keys.append(str(n.key))
	ok(keys.has("evidence:a"), "evidence survives a long conversation")
	eq(keys.size(), VisitState.MAX_NOTES_PER_ROW, "row stays at its size")
	ok(JSON.stringify(v.notes.speech).contains("Chatter 7."), "the latest line said is on the card")
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
	ok(has_error(CaseDB.validate_case(c, rules), "stable patient must have no broken"), "stable + broken line is caught")
	c = (cases["kip"] as Dictionary).duplicate(true)
	c["press"][1]["end"] = "attack"
	ok(has_error(CaseDB.validate_case(c, rules), "must never attack"), "stable attacker is caught")
	c = (cases["vale"] as Dictionary).duplicate(true)
	for row in ["eyes", "speech", "temper"]:
		c["rows"][row]["ok"] = true
	c["eyes"]["left"]["follows"] = true
	ok(has_error(CaseDB.validate_case(c, rules), "impossible to refuse"), "all-refusable drift evidence is caught")
	c = (cases["vale"] as Dictionary).duplicate(true)
	c["checks"]["penlight"]["first"] = ["explain:ghost"]
	ok(has_error(CaseDB.validate_case(c, rules), "unknown claim"), "unknown claim is caught")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["grip"]["release_ms"] = 400
	ok(has_error(CaseDB.validate_case(c, rules), "rows.hands.ok"), "grip data and sheet row must agree")
	c = (cases["maren"] as Dictionary).duplicate(true)
	c["eyes"]["left"]["tightens"] = true
	ok(has_error(CaseDB.validate_case(c, rules), "rows.eyes.ok"), "eye data and sheet row must agree")
	c = (cases["juno"] as Dictionary).duplicate(true)
	c["outcomes"].erase("false_alarm")
	ok(has_error(CaseDB.validate_case(c, rules), "outcomes.false_alarm"), "missing outcome text is caught")
