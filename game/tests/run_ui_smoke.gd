extends SceneTree
## Headless smoke test of the real screen. It loads scenes/main.tscn and plays three shifts
## through the same pointer and key entry points a player uses (see tests/play_driver.gd).
## Run from the repository root:
##   godot --headless --path game --script res://tests/run_ui_smoke.gd
## Exit code 0 = all passed, 1 = at least one check failed, 2 = the run did not finish.
## This is an automated run. It is not a playtest, and its log says so.

const MainScript = preload("res://scripts/ui/main.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const PlayDriver = preload("res://tests/play_driver.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")

const SPEED := 4.0

var main: MainScript = null
var d: PlayDriver = null
var passed: int = 0
var failed: int = 0
var group: String = ""


func _initialize() -> void:
	# If a script error stops the run, nothing would ever call quit(). This makes sure something does.
	create_timer(300.0, true, false, true).timeout.connect(_on_watchdog)
	_run()


func _on_watchdog() -> void:
	print("RESULT: the smoke test did not finish (%d passed, %d failed so far, in '%s')." % [passed, failed, group])
	quit(2)


func _run() -> void:
	print("Before the Cut - UI smoke test (automated run, not a playtest)")
	Engine.time_scale = SPEED
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("RESULT: could not load scenes/main.tscn")
		quit(1)
		return
	main = packed.instantiate() as MainScript
	if main == null:
		print("RESULT: scenes/main.tscn does not use scripts/ui/main.gd")
		quit(1)
		return
	root.add_child(main)
	await process_frame
	main.audio.set_muted(true)
	main.mic.simulated = true      # an automated run never opens a microphone
	d = PlayDriver.new(self, main)
	main.event_log.write("automated_run", {"runner": "tests/run_ui_smoke.gd"})
	await shift_careful()
	await shift_reckless()
	await shift_odds_and_ends()
	voice_words()
	check_log()
	print("")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	main.event_log.stop()
	main.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)


# ================================================================ helpers

func section(title: String) -> void:
	group = title
	print("- " + title)


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("    FAILED: %s  [%s]" % [label, group])


func note_count(v: VisitState, row: String) -> int:
	var list: Array = v.notes.get(row, [])
	return list.size()


func has_note_text(v: VisitState, row: String, part: String) -> bool:
	var list: Array = v.notes.get(row, [])
	for n in list:
		var note: Dictionary = n
		if str(note.get("text", "")).contains(part):
			return true
	return false


func last_record() -> Dictionary:
	var records: Array = main.shift.records
	if records.is_empty():
		return {}
	var r: Dictionary = records[records.size() - 1]
	return r


func unseen_rows(s: Dictionary) -> int:
	var n := 0
	for row in s.get("rows", []):
		var r: Dictionary = row
		if not bool(r.get("seen", false)):
			n += 1
	return n


## The name of the picture a sprite is showing: "attack_s2_b_clean". "" when it shows none.
func art(sprite: Variant) -> String:
	var s := sprite as Sprite2D
	if s == null or s.texture == null:
		return ""
	return s.texture.resource_path.get_file().get_basename()


## True when a picture is the one the blood setting calls for: `plain` as drawn, or its
## "_clean" copy when the game was started with --less-blood.
func right_art(sprite: Variant, plain: String) -> bool:
	var shown := art(sprite)
	if main.less_blood:
		return shown.begins_with(plain) and shown.ends_with("_clean")
	return shown.begins_with(plain) and not shown.ends_with("_clean")


## Buzzes the next patient in and checks who it is.
func enter(id: String) -> VisitState:
	var ok: bool = await d.buzz_in()
	check(ok, "%s comes to the counter" % id)
	var v: VisitState = main.visit
	check(v != null and str(v.case_data.get("id", "")) == id, "the visit is %s's" % id)
	return v


## The slip prints, the record flips to findings, and taking the slip moves on.
func finish_visit(label: String) -> void:
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed, "%s: the result slip prints" % label)
	check(main.clipboard.mode == "findings", "%s: the record shows the findings" % label)
	check(main.clinic.till == main.shift.total(), "%s: the till matches the shift total" % label)
	var moved: bool = await d.take_slip()
	check(moved, "%s: taking the slip moves on" % label)
	check(main.visit == null and main.rig == null, "%s: the counter is clear afterwards" % label)


# ================================================================ shift 1

func shift_careful() -> void:
	section("Title and hall camera")
	check(main.state == MainScript.State.TITLE and main.screens.mode == "title", "the game starts on the title card")
	check(main.data_errors.is_empty(), "the case data loaded without problems")
	var opened: bool = await d.open_counter()
	check(opened, "a click opens the counter and the hall camera asks to buzz someone in")
	check(main.clinic.cam_id == "kip", "the hall camera shows the first patient")
	check(not main.desk.is_enabled("penlight") and not main.desk.is_enabled("treat"), "the desk is off while nobody is at the counter")
	check(main.clipboard.mode == "blank", "the intake record is blank between patients")
	check(main.clinic.shutter_pos < 0.05, "the shutter is up before anyone is buzzed in")

	section("Kip: look, test, talk, press and reassure, then TREAT")
	var v: VisitState = await enter("kip")
	check(main.rig != null and main.rig.at_counter(), "he is standing at the counter")
	check(main.desk.is_enabled("treat") and main.desk.is_enabled("refer") and main.desk.is_enabled("shutter"),
		"the stamp, the call box and the shutter are available before anything has been checked")
	check(main.clipboard.mode == "exam" and main.clinic.show_patience, "the intake card and the patience lamps are showing")
	d.move(d.zone_pos("eyes"))
	await process_frame
	await process_frame
	check(main.clipboard.highlight_row == "eyes" and main._cursor_kind == "look", "hovering his eyes highlights the EYES line")
	await d.look("eyes")
	check(v.seen.has("look:eyes") and v.patience == v.patience_max, "a look is free")
	check(note_count(v, "eyes") == 1, "the look is noted on the EYES row")
	await d.look("hands")
	await d.look("port")
	check(v.seen.has("look:hands") and v.seen.has("look:port"), "hands and port can be looked at the same way")
	var status: String = await d.request_tool("penlight")
	check(status == "open", "the penlight close-up opens when he agrees")
	check(v.patience == v.patience_max - 1, "a first test costs one patience")
	check(not v.seen.has("check:penlight"), "agreeing is not evidence: nothing is written until the light is used")
	var done: bool = await d.sweep_eyes()
	check(done, "sweeping the light over both eyes writes the result")
	await d.put_away()
	check(not main.clinic.scope.is_open() and main.desk.active == "", "right-click puts the tool away")
	status = await d.request_tool("grip")
	check(status == "open", "the grip bar opens")
	done = await d.squeeze_and_release()
	check(done, "hold and release writes the hand result")
	check(has_note_text(v, "hands", "0.3 s"), "the grip note carries the time the game measured")
	status = await d.request_tool("port")
	check(status == "open", "an uncovered port can be checked without asking")
	done = await d.watch_port()
	check(done, "the port close-up writes its note")
	await d.put_away()
	check(v.patience == v.patience_max - 2, "the port check was free")
	await d.ask(0)
	await d.settle()
	check(v.answered.has("why") and v.patience == v.patience_max - 3, "a question costs one patience and gets an answer")
	check(note_count(v, "speech") == 1, "the answer is noted on the SPEECH row")
	await d.press()
	check(v.press_count == 1 and v.seen.has("press") and v.in_exam(), "one provocative line gets a reaction and the exam goes on")
	check(v.patience == v.patience_max - 5, "pressing costs two patience")
	check(note_count(v, "temper") == 1, "the reaction is noted on the TEMPER row")
	await d.settle()
	await d.reassure()
	check(v.reassure_left == 1 and v.patience == v.patience_max - 4, "reassurance gives one patience back")
	await d.settle()
	d.click(Vector2(416, 232))
	check(int(v.marks.get("eyes", 0)) == 1, "clicking a mark box ticks it")
	d.click(Vector2(416, 232))
	d.click(Vector2(416, 232))
	check(int(v.marks.get("eyes", 0)) == 0, "the mark cycles back to blank")
	d.pad("treat")
	await process_frame
	check(main._held == "treat" and main.clipboard.armed == "treat" and v.in_exam(), "picking the stamp up decides nothing yet")
	d.right_click()
	check(main._held == "" and v.in_exam(), "right-click puts the stamp back")
	await d.stamp("treat")
	check(v.verdict_kind == "treat" and v.outcome == "treated_ok", "stamping the card decides: TREAT")
	await finish_visit("Kip")
	check(main.shift.total() == 250, "his fee is in the till")
	check(main.clinic.cam_id == "rook", "the next patient is on the camera")

	section("Rook: a refusal, then reassurance")
	v = await enter("rook")
	status = await d.request_tool("grip")
	check(status == "refused", "he stalls on the grip bar")
	check(v.patience == v.patience_max - 1 and not v.granted.has("grip"), "the request still cost one patience")
	check(main.desk.warn.has("grip") and str(main.desk.badges.get("grip", "")) == "-2", "the pad shows that insisting costs two")
	check(not main.clinic.scope.is_open(), "no close-up opens on a refusal")
	check(not v.seen.has("check:grip"), "a refusal is not evidence")
	await d.reassure()
	check(v.check_status("grip") == "fresh" and str(main.desk.badges.get("grip", "")) == "-1", "reassurance takes the edge off the refusal")
	await d.settle()
	status = await d.request_tool("grip")
	check(status == "open", "asked again, he agrees")
	done = await d.squeeze_and_release()
	check(done, "his grip result is written")
	var before: int = v.patience
	await d.ask(1)
	await d.settle()
	check(v.answered.has("mood") and v.patience == before - 1, "once reassured, he answers the question about his mood straight away")
	await d.ask(1)
	await d.settle()
	check(v.patience == before - 1, "hearing an answer again is free")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Rook")
	await finish_visit("Rook")

	section("Vale: an excuse, a covered port, the call to Trauma Team, and the shutter")
	v = await enter("vale")
	check(v.port_covered() and not v.granted.has("port"), "his port is covered")
	await d.look("port")
	check(not v.seen.has("check:port"), "looking at a covered port shows only the cover")
	status = await d.request_tool("penlight")
	check(status == "refused", "he gives a reason instead of following the light")
	check(v.claims.has("idle"), "his reason is kept as a claim")
	status = await d.request_tool("penlight")
	check(status == "open", "insisting opens the test")
	check(v.patience == v.patience_max - 3, "insisting cost two")
	done = await d.sweep_eyes()
	check(done, "the eye result is written")
	await d.put_away()
	status = await d.request_tool("port")
	check(status == "refused" and not v.granted.has("port"), "he will not show the port")
	d.pad("refer")
	await process_frame
	check(v.in_exam() and main._call_armed > 0.0 and main.desk.armed == "refer", "the first press on the call box only opens the line")
	check(main._alert_hint.begins_with("TRAUMA TEAM LINE OPEN"), "the hint says how to call and how to hang up")
	d.pad("refer")
	await process_frame
	check(main.state == MainScript.State.ATTACK and v.phase == VisitState.Phase.ATTACK, "the second press calls them, and the call turns him")
	check(v.verdict_kind == "refer" and main.clipboard.imprint == "refer", "the card carries the Trauma Team mark")
	check(main._call_armed <= 0.0 and main.desk.armed == "", "the line is no longer waiting")
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "the warning comes after a silent beat")
	check(main.desk.is_enabled("shutter") and main.desk.pulse == "shutter" and main.clinic.danger > 0.5, "everything points at the shutter")
	check(main.rig != null and main.rig._attack and (main.rig._spr["turn"] as Sprite2D).visible, "his face has turned")
	check(right_art(main.rig._spr["turn"], "turn"), "the turned face is the one for the blood setting")
	var struck: bool = await d.until(func() -> bool: return main._blows >= 2, 4.0)
	check(struck and main.clinic.glass_state == 2, "two blows land and the glass cracks twice")
	check(main.clinic.decal_count() >= 1, "the saw leaves its mark on the glass")
	check(right_art(main.rig._spr["attack"], "attack_s2"), "the hand on the glass is the one for the blood setting")
	check(right_art(main.rig._spr["mouth"], "mouth_turn"), "the scream is the one for the blood setting")
	d.shutter_key()
	check(v.outcome == "caught", "one press of SPACE drops the shutter in time")
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed, "Vale: the result slip prints")
	check(main.clinic.shutter_closed(), "the shutter is down")
	check(main.clinic.strobe == 0.0 and not main.clinic.team_in_sight(), "the crew's lights have come and gone outside")
	check(main.clinic.dent_count() == 3 and main.clinic.has_cut(), "the shutter took three hits and the saw came through it")
	check(right_art(main.clinic._cut, "cut_saw"), "the cut in the shutter is the one for the blood setting")
	check(main.clinic.glass_state == 2, "the cracks stay in the glass")
	check((main.clinic.drip_count() > 0) != main.less_blood, "blood ran out under the shutter")
	check(not main.audio._loops.has("alarm") and not main.audio._loops.has("saw_loop"), "the alarm and the saw are quiet")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 120, "a caught attack pays the handover fee")
	var moved: bool = await d.take_slip()
	check(moved, "Vale: taking the slip moves on")
	check(main.clinic.shutter_pos < 0.05, "the shutter is back up before the next patient is called")

	section("Juno: TREAT at once, with no examination at all")
	v = await enter("juno")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "a verdict needs no look, test or question first")
	check(unseen_rows(v.settlement()) == 5, "nothing had been checked")
	await finish_visit("Juno")

	section("Maren: a dodge, a pressed reaction, then the call to Trauma Team")
	v = await enter("maren")
	await d.ask(2)
	await d.settle()
	check(not v.answered.has("fear"), "she dodges the question")
	await d.ask(2)
	await d.settle()
	check(v.answered.has("fear"), "asked again, she answers")
	await d.press()
	check(v.press_count == 1 and v.in_exam() and note_count(v, "temper") == 1, "pressed once, she reacts and the exam goes on")
	await d.settle()
	var patience_before: int = v.patience
	d.pad("refer")
	await process_frame
	check(v.in_exam() and main._call_armed > 0.0, "the line opens")
	d.right_click()
	check(v.in_exam() and main._call_armed <= 0.0 and main.desk.armed == "" and main._alert_hint == "", "right-click hangs up")
	d.pad("refer")
	await d.seconds(3.9)
	check(v.in_exam() and main._call_armed <= 0.0 and main.desk.armed == "", "left alone, the line closes by itself")
	d.pad("refer")
	d.shutter_key()
	check(v.in_exam() and main._call_armed <= 0.0 and main._armed > 0.0, "arming the shutter hangs up the call")
	d.right_click()
	d.pad("refer")
	d.pad("treat")
	check(v.in_exam() and main._call_armed <= 0.0 and main._held == "treat", "picking up the stamp hangs up the call")
	d.right_click()
	check(v.in_exam() and v.patience == patience_before, "none of that decided anything or cost patience")
	await d.call_team()
	check(v.outcome == "referred_drifting" and main.state != MainScript.State.ATTACK, "the call hands her over without a fight")
	var came: bool = await d.until(func() -> bool: return main.clinic.team_in_sight() and not main.clinic.team_moving(), 25.0)
	check(came and main.rig != null and main.clinic.strobe > 0.5, "the crew comes in behind her with their lights in the hall")
	await finish_visit("Maren")
	check(not main.clinic.team_in_sight() and main.clinic.strobe == 0.0, "the crew and their lights are gone afterwards")
	check(str(last_record().get("title", "")) == "TAKEN IN" and int(last_record().get("credits", 0)) == 120, "the handover pays its small fee")

	section("Report")
	check(main.state == MainScript.State.REPORT and main.screens.mode == "report", "the last slip leads to the end-of-shift report")
	var r: Dictionary = main.screens.report
	check(int(r.get("correct", 0)) == 5 and int(r.get("total", 0)) == 1140 and bool(r.get("rent_paid", false)), "five right calls, 1140 in the till, rent paid")


# ================================================================ shift 2

func shift_reckless() -> void:
	section("New shift")
	var opened: bool = await d.open_counter()
	check(opened, "a click on the report starts a new shift")
	check(main.shift_number == 2 and main.shift.index == 0 and main.clinic.till == 0 and main.clinic.results.is_empty(),
		"the new shift starts from zero")

	section("Kip: the shutter needs two presses during an ordinary exam")
	var v: VisitState = await enter("kip")
	d.shutter_key()
	check(v.in_exam() and main._armed > 0.0 and main.desk.pulse == "shutter", "the first SPACE only arms the shutter")
	await d.seconds(2.6)
	check(v.in_exam() and main._armed <= 0.0 and main.desk.pulse == "", "left alone, it disarms")
	d.shutter_key()
	d.right_click()
	check(v.in_exam() and main._armed <= 0.0, "right-click disarms it")
	d.shutter_key()
	d.shutter_key()
	check(v.outcome == "false_alarm", "a second press drops it: a false alarm on a steady patient")
	await finish_visit("Kip")
	check(int(last_record().get("credits", 0)) == -100 and not bool(last_record().get("correct", true)), "the false alarm costs 100")

	section("Rook: pressed twice, he walks out")
	v = await enter("rook")
	await d.press()
	check(v.in_exam() and v.press_count == 1, "the first insult only makes him angry")
	await d.settle()
	await d.press()
	check(v.outcome == "walkout", "the second insult ends the visit")
	await finish_visit("Rook")
	check(int(last_record().get("credits", 0)) == 0 and not bool(last_record().get("correct", true)), "a walkout pays nothing")

	section("Vale: Trauma Team called and no shutter")
	v = await enter("vale")
	await d.call_team()
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "he turns")
	var broke: bool = await d.until(func() -> bool: return main.clinic.glass_state == 4, 6.0)
	check(broke and main._blows == 3, "three blows, and the glass gives")
	check(right_art(main.clinic._broken, "glass_broken"), "what is left of the pane is the one for the blood setting")
	var through: bool = await d.until(func() -> bool: return main.rig != null and main.rig.pop >= 1.0, 3.0)
	check(through and main.rig.back.get_parent() == main.gore.jump, "he comes through the window at the player")
	var bled: bool = await d.until(func() -> bool: return main.gore.splat_count() >= 6, 3.0)
	check(bled != main.less_blood, "blood lands on the player's view")
	await finish_visit("Vale")
	check(v.outcome == "hit" and bool(last_record().get("injured", false)), "with no shutter the attack lands")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == -300, "the call was right and it still cost 300")
	check(main.clinic.glass_state == 4, "the window stays broken")
	check((main.clinic.stain_count() > 0) != main.less_blood, "the blood dries on the wall")
	check(main.gore.splat_count() == 0 and not main.gore.busy() and main.gore.vignette == 0.0, "the player's view is clear again")

	section("Juno: Trauma Team called on a steady patient")
	v = await enter("juno")
	await d.call_team()
	check(v.outcome == "referred_stable", "the call goes through")
	var came: bool = await d.until(func() -> bool: return main.clinic.team_in_sight(), 25.0)
	check(came and main.rig != null, "the crew comes for her anyway")
	await finish_visit("Juno")
	check(not bool(last_record().get("correct", true)) and int(last_record().get("credits", 0)) == -150, "it was the wrong call and the call-out is billed")
	check(str(last_record().get("title", "")) == "FALSE CALL", "the slip calls it a false call")
	check(not main.clinic.team_in_sight() and main.clinic.strobe == 0.0, "the crew has left")

	section("Maren: TREAT on a drifting patient")
	v = await enter("maren")
	await d.stamp("treat")
	check(v.outcome == "treated_drifting", "the treatment goes ahead")
	await finish_visit("Maren")
	check(int(last_record().get("credits", 0)) == -400, "it costs 400")

	section("Report after a bad night")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == -950 and not bool(r.get("rent_paid", true)) and int(r.get("injuries", 0)) == 1,
		"minus 950, rent unpaid, one injury")


# ================================================================ shift 3

func shift_odds_and_ends() -> void:
	section("Third shift")
	var opened: bool = await d.open_counter()
	check(opened, "a third shift starts")
	check(main.clinic.glass_state == 0 and main.clinic.stain_count() == 0 and main.clinic.dent_count() == 0
		and main.clinic.drip_count() == 0 and main.clinic.decal_count() == 0, "the window, the wall and the shutter are whole again")
	var v: VisitState = await enter("kip")
	await typing_line(v)
	await d.stamp("treat")
	await finish_visit("Kip")

	section("Rook: running out of patience")
	v = await enter("rook")
	var status: String = await d.request_tool("grip")
	check(status == "refused" and v.patience == 4, "he stalls")
	await d.press()
	await d.settle()
	await d.ask(1)
	await d.settle()
	check(not v.answered.has("mood") and int(v.asked.get("mood", 0)) == 1, "not reassured, he dodges the question about his mood")
	check(v.patience == 1, "one patience left")
	status = await d.request_tool("grip")
	check(status == "refused" and v.patience == 1 and not v.granted.has("grip"), "insisting needs two: nothing happens")
	check(main._base_hint.begins_with("Out of patience"), "the hint says why")
	check(v.in_exam() and main.desk.is_enabled("treat") and main.desk.is_enabled("refer"), "both decisions still work with no patience")
	await d.settle()
	await d.reassure()
	await d.settle()
	status = await d.request_tool("grip")
	check(status == "open" and v.patience == 1, "after reassurance the test opens")
	var done: bool = await d.squeeze_and_release()
	check(done, "the result is written")
	await d.stamp("treat")
	await finish_visit("Rook")

	section("Vale: pressed twice, then the lever")
	v = await enter("vale")
	await d.press()
	check(v.in_exam() and note_count(v, "temper") == 1, "the first line gets a flat reaction")
	await d.settle()
	await d.press()
	check(main.state == MainScript.State.ATTACK and v.attack_cause == "press", "the second line turns him")
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "the warning comes")
	d.click(d.pad_pos("shutter"))
	check(v.outcome == "caught", "one click on the lever drops the shutter")
	await finish_visit("Vale")

	section("Juno: the question list opens and closes")
	v = await enter("juno")
	d.pad("ask")
	await process_frame
	check(main.dialogue.has_menu() and main.dialogue.menu.size() == 3, "ASK lists three questions")
	d.right_click()
	check(not main.dialogue.has_menu() and v.patience == v.patience_max, "closing the list costs nothing")
	await d.ask(1)
	await d.settle()
	await d.ask(1)
	await d.settle()
	check(v.answered.has("chrome"), "her dodge and her answer both play")
	await d.stamp("treat")
	await finish_visit("Juno")

	section("Maren: the shutter during the exam")
	v = await enter("maren")
	d.shutter_key()
	d.shutter_key()
	check(v.outcome == "locked_out", "locking a drifting patient out ends the visit")
	var dents_before: int = main.clinic.dent_count()
	await finish_visit("Maren")
	check(main.clinic.dent_count() == dents_before + 3, "she hits the shutter three times from the far side")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 0, "it counts as a right call and pays nothing")
	var r: Dictionary = main.screens.report
	check(main.state == MainScript.State.REPORT and int(r.get("total", 0)) == 1020 and int(r.get("correct", 0)) == 5, "the third report adds up")


# ================================================================ the doctor's own words

## Kip, offline: the typing line, its keys, and what the scripted patient makes of a sentence.
func typing_line(v: VisitState) -> void:
	section("Kip: typing a line of your own (offline patient)")
	await d.settle()
	var box = main.dialogue
	await process_frame
	check(box.chips.size() == 1 and not box.chips_dim, "the TYPE button is on the strip during an exam")
	var chip: Rect2 = box._chip_rects()[0]["rect"]
	check(Gfx.DIALOGUE.encloses(chip) and chip.position.y >= 226.0, "the button sits inside the strip")
	d.move(chip.get_center())
	await process_frame
	await process_frame
	check(box.chip_hover == "type" and main._cursor_kind == "hand" and main._hover_hint.begins_with("TYPE [T]"), "hovering it says what it does")
	d.click(chip.get_center())
	check(box.input_open and main._base_hint == main.SAY_HINT, "a click on it opens the typing line")
	check(box.chip_at(chip.get_center()) == "", "the button is put away while typing")
	d.key(KEY_ESCAPE)
	check(not box.input_open and main._base_hint == "", "ESC closes it again")
	# speaking needs the patient AI service: offline there is no SPEAK button, and TAB says why
	check(main._mic_why_not() == "no_service" and not main.screens.voice, "offline, speaking is not offered")
	d.key(KEY_TAB)
	check(not box.input_open and main._mic_state == "" and not main.mic.listening, "offline, the speak key opens no microphone")
	check(main._base_hint == main.MIC_HINTS["no_service"], "and the hint says what speaking needs")
	d.key_release(KEY_TAB)
	await process_frame
	check(main._mic_state == "" and not main._thinking and not box.input_open, "letting go of it does nothing either")
	d.key(KEY_T, 116)
	check(box.input_open and box.input_text == "", "T opens it, and the T is not typed")
	var muted: bool = main.audio.muted
	d.type_text("Slepe m")
	check(box.input_text == "Slepe m" and box.input_caret == 7, "keys become letters")
	check(main.audio.muted == muted, "M is a letter while typing, not the mute key")
	check(main._armed <= 0.0 and v.in_exam(), "SPACE is a space while typing, not the shutter")
	d.key(KEY_TAB, 9)
	d.key_release(KEY_TAB)
	check(box.input_open and box.input_text == "Slepe m" and box.input_status == "" and not main.mic.listening,
		"offline, TAB leaves a sentence being typed alone")
	for i in 4:
		d.key(KEY_BACKSPACE)
	d.type_text("ep")
	check(box.input_text == "Sleep", "BACKSPACE takes letters back")
	d.key(KEY_HOME)
	d.type_text("X")
	d.key(KEY_RIGHT)
	d.key(KEY_LEFT)
	d.key(KEY_LEFT)
	d.key(KEY_DELETE)
	check(box.input_text == "Sleep" and box.input_caret == 0, "the caret moves, and DELETE removes what is under it")
	d.key(KEY_END)
	check(box.input_caret == 5, "END goes to the end")
	d.key(KEY_UNKNOWN, 0x4E2D)
	d.key(KEY_UNKNOWN, 0xE9)
	d.key(KEY_SHIFT)
	d.key(KEY_F5)
	check(box.input_text == "Sleep", "keys the counter font cannot draw type nothing")
	d.type_text("?".repeat(200))
	check(box.input_text.length() <= box.INPUT_MAX and box._rows.size() <= box.INPUT_LINES, "the line stops when it is full")
	check(main._base_hint == main.SAY_FULL_HINT, "and the hint says so")
	d.key(KEY_BACKSPACE)
	check(main._base_hint == main.SAY_HINT, "taking a letter back clears that warning")
	var patience: int = v.patience
	d.right_click()
	check(not box.input_open and v.patience == patience and int(v.asked.get("free", 0)) == 0, "right-click takes the sentence back unsaid")
	d.key(KEY_ENTER)
	check(box.input_open, "on a quiet strip ENTER starts a sentence too")
	d.key(KEY_ENTER)
	check(not box.input_open and v.patience == patience and not main._thinking, "ENTER on an empty line says nothing")
	# a sentence the script can place: the doctor's own words are what is said
	var typed := "How did you crack that lens?"
	await d.say(typed)
	check(not box.input_open, "ENTER sends the sentence and closes the line")
	check(box.speaker == "YOU" and " ".join(box.lines) == typed, "the doctor says exactly what was typed")
	var answered: bool = await d.until(func() -> bool: return v.answered.has("why") and box.speaker != "YOU", 12.0)
	check(answered and v.patience == patience - 1, "offline, a sentence about the eye gets the eye answer and costs one patience")
	check(has_note_text(v, "speech", "pavement"), "the answer is noted like any other")
	await d.settle()
	# the same question again: nothing new to charge for
	await d.say("So what happened to your eye, again?")
	await d.until(func() -> bool: return box.speaker != "YOU" and not main._thinking, 12.0)
	await d.settle()
	check(v.patience == patience - 1, "asking it again in other words is free")
	# a sentence the script has no answer for
	var notes_before: int = note_count(v, "speech") + note_count(v, "temper")
	await d.say("Nice weather tonight.")
	var dodged: bool = await d.until(func() -> bool: return box.speaker != "YOU" and not main._thinking, 12.0)
	check(dodged and " ".join(box.lines) == "Uh. Can we skip that one?", "small talk gets his own way of declining")
	check(v.patience == patience - 1 and int(v.asked.get("free", 0)) == 0, "an unanswered sentence costs nothing")
	check(note_count(v, "speech") + note_count(v, "temper") == notes_before, "and writes nothing on the card")
	check(main._base_hint == main.SAY_OFFLINE_HINT, "the hint explains that the offline patient only knows its script")
	await d.settle()
	# other actions put the sentence away
	d.key(KEY_T, 116)
	d.type_text("half a thou")
	d.pad("ask")
	await process_frame
	check(not box.input_open and box.has_menu(), "opening the question list puts the typing line away")
	d.right_click()
	d.key(KEY_T, 116)
	d.type_text("unsaid")
	d.pad("treat")
	await process_frame
	check(not box.input_open and main._held == "treat", "so does picking up the stamp")
	d.right_click()
	check(main._held == "" and v.in_exam() and v.patience == patience - 1, "none of that cost anything")
	# a spoken line too long for the strip turns its pages, by itself and by a click
	var long_line: String = "One two three four five six seven eight nine ten."
	while Gfx.wrap_text(long_line, box.TEXT_W).size() <= 2 * box.PAGE_LINES:      # three pages or more
		long_line += " One two three four five six seven eight nine ten."
	var quiet_spot := Vector2(200, 262)            # on the strip, on nothing that can be pressed
	main._patient_line(long_line, main._begin_action(), 0.0)
	await process_frame
	check(box.lines.size() > 2 * box.PAGE_LINES and box.more and box.typing, "a line too long for the strip is paged")
	check(" ".join(box.lines) == long_line, "and no word of it is lost in the breaking")
	d.click(quiet_spot)
	await process_frame
	await process_frame
	check(box.shown == box.total and box.typing and box.more and box._page == 0, "a click shows the whole page, which then waits")
	check(not box.is_revealing(), "and the mouth stops while the page is held")
	d.click(quiet_spot)
	await process_frame
	await process_frame
	check(box._page == box.PAGE_LINES and box.shown < box.total and box.typing, "the next click turns the page")
	var turned: bool = await d.until(func() -> bool: return not box.typing, 60.0)
	check(turned and not box.more and box._page > box.PAGE_LINES and box._page + box.PAGE_LINES >= box.lines.size()
		and box.shown == box.total, "left alone, the pages turn by themselves to the end")
	check(v.patience == patience - 1 and v.in_exam(), "reading it cost nothing")
	await d.settle()
	box.clear()


# ================================================================ push-to-talk

## Everything push-to-talk can put on the hint row fits it. The exchange itself needs the patient
## AI service, so it is played in tests/run_proxy_integration.gd, with a simulated microphone.
func voice_words() -> void:
	section("Push-to-talk: its words fit the counter")
	var hints: Array = [main.SAY_VOICE_HINT, main.MIC_LISTEN_HINT, main.MIC_WAIT_HINT, main.MIC_DONE_HINT, main.MIC_MOCK_HINT,
		main.MIC_CUT_HINT, main.MIC_DEAF_HINT, main._chip_hint("speak"), main._mic_failure_hint("W".repeat(40))]
	hints.append_array(main.MIC_HINTS.values())
	for reason in ["http_502:provider_error", "network_13", "bad_json", "request_failed", "invalid", "http_413:audio_too_long"]:
		hints.append(main._mic_failure_hint(reason))
	var fits := 0
	for h in hints:
		var text := str(h)
		if text != "" and Gfx.printable(text) == text and Gfx.text_w(text) <= main.dialogue.TEXT_W:
			fits += 1
		else:
			print("  too wide or unprintable: ", text)
	check(fits == hints.size() and fits >= 25, "all %d push-to-talk hints fit the hint row" % hints.size())
	check(main._mic_failure_hint("http_422:no_speech") == main.MIC_HINTS["no_speech"], "a clip with no words in it is told as that")
	check(main._mic_failure_hint("http_429:visit_transcribe_cap") == main.MIC_HINTS["clip_cap"]
		and main._mic_failure_hint("clip_cap") == main.MIC_HINTS["clip_cap"], "the clip cap reads the same from either side")
	check(main._mic_failure_hint("timeout") == main.MIC_HINTS["slow"]
		and main._mic_failure_hint("http_504:upstream_timeout") == main.MIC_HINTS["slow"], "a slow service is told as slow")
	check(main._mic_failure_hint("http_429:budget_exhausted") == main.MIC_HINTS["budget"], "a spent budget is told as that")
	check(main._mic_failure_hint("http_501:transcription_unavailable") == main.MIC_DEAF_HINT, "a service that cannot hear is told as that")
	var other: String = main._mic_failure_hint("http_502:provider_error")
	check(other.contains("(http_502)") and not other.contains("provider_error"), "any other failure shows its short code")
	check(Gfx.text_w(main.screens.HELP) <= 620.0 and Gfx.text_w(main.screens.HELP_VOICE) <= 620.0, "both title help lines fit the screen")
	var speak_w: float = Gfx.text_w("TAB", true) + Gfx.text_w("SPEAK") + 11.0
	var type_w: float = Gfx.text_w("T", true) + Gfx.text_w("TYPE") + 11.0
	check(speak_w + type_w + 8.0 < 120.0, "the SPEAK and TYPE buttons leave the strip to the patient's words")
	check(main.SPEAK_CHIPS.size() == 2 and str(main.SPEAK_CHIPS[1].id) == "type", "TYPE stays where it was when SPEAK joins it")


# ================================================================ log

func check_log() -> void:
	section("Event log")
	var types := {}
	for rec in main.event_log.memory:
		var record: Dictionary = rec
		var t := str(record.get("type", ""))
		types[t] = int(types.get(t, 0)) + 1
	for t in ["session_start", "automated_run", "shift_start", "visit_start", "look", "check", "check_done", "ask",
			"reassure", "press", "say", "call_line_open", "verdict", "attack", "attack_hit", "shutter", "spent", "visit_end", "shift_end"]:
		check(types.has(t), "the log has '%s' records" % t)
	check(int(types.get("visit_start", 0)) == 15 and int(types.get("visit_end", 0)) == 15, "fifteen visits were logged from start to end")
	check(int(types.get("shift_end", 0)) == 3, "three shifts were logged")
	check(int(types.get("voice", 0)) == 2, "the two refused presses of the speak key were logged, and nothing else of that kind")
