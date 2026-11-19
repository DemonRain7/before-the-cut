extends SceneTree
## Headless smoke test of the real screen. It loads scenes/main.tscn and plays nine shifts
## through the same pointer and key entry points a player uses (see tests/play_driver.gd).
## The first six check the counter itself under a few rules held still (no couriers, a free
## CALM, the old line, no snaps or flares, no training); the last three play the night as it
## is: the contact list and the paid CALM, the snaps and flares, and the first-night training.
## Right and wrong are told only at closing: the slip says what the counter did, and through the
## night the till holds what the counter took in. A blow that lands ends the night (shifts 2 and
## 4): there is no slip, and the report comes up out of the dark with the visitors nobody saw.
## Run from the repository root:
##   godot --headless --path game --script res://tests/run_ui_smoke.gd
##   godot --headless --path game --script res://tests/run_ui_smoke.gd -- --lang=zh   (in Chinese)
## Words are compared as the player reads them: the English line through Lang.t, Lang.tf or
## Lang.fill, the way the game shows it. In another language the run plays the same nine
## shifts in it and fails on any English that reached the screen untranslated.
## Exit code 0 = all passed, 1 = at least one check failed, 2 = the run did not finish.
## This is an automated run. It is not a playtest, and its log says so.

const MainScript = preload("res://scripts/ui/main.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const ShiftState = preload("res://scripts/core/shift_state.gd")
const CaseDB = preload("res://scripts/core/case_db.gd")
const PlayDriver = preload("res://tests/play_driver.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")

const SPEED := 4.0

var main: MainScript = null
var d: PlayDriver = null
var passed: int = 0
var failed: int = 0
var group: String = ""


## A patient service that takes its time and then has no answer. While it is asked, the patient
## is seen thinking the answer over; when it fails, the authored patient answers instead.
## It stands in for the network: nothing is sent anywhere.
class SlowClient:
	extends RefCounted
	var tree: SceneTree = null
	var hold: float = 2.0      # game seconds before it gives up

	func request_move(_payload: Dictionary) -> Dictionary:
		await tree.create_timer(hold, false).timeout
		return {"ok": false, "error": "held"}


func _initialize() -> void:
	# English, unless --lang=<code> asks for another language; a saved choice never reaches a run
	Lang.pin(Lang.asked("en"))
	Lang.record = Lang.code != "en"      # in another language: note the words that reach the screen untranslated
	# If a script error stops the run, nothing would ever call quit(). This makes sure something does.
	create_timer(900.0, true, false, true).timeout.connect(_on_watchdog)
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
	main.authored_order = true      # the checks below follow the listed order of patients
	root.add_child(main)
	await process_frame
	main.audio.set_muted(true)
	main.mic.simulated = true      # an automated run never opens a microphone
	d = PlayDriver.new(self, main)
	main.event_log.write("automated_run", {"runner": "tests/run_ui_smoke.gd"})
	# The first six shifts were written for the counter before tonight's contacts, the paid CALM,
	# the snaps and the training, and they count every credit and every patience lamp. They run
	# with those held still: nobody on the list, CALM for free, the old line of 120 an hour, no
	# surprises and no training box. Everything they check about the counter is the same either way.
	main.surprises_enabled = false
	main.training_enabled = false
	var real: Dictionary = pin_rules({"line": {"per_hour": 120}, "reassure": {"cost": 0}, "contacts": {"per_night": 0}})
	await shift_careful()
	await shift_reckless()
	await shift_odds_and_ends()
	await shift_line_and_glass()
	await shift_last_glass()
	await shift_walls_and_glass()
	var six: int = main.event_log.memory.size()
	restore_rules(real)
	await shift_couriers()
	main.surprises_enabled = true
	await shift_surprises()
	main.training_enabled = true
	await shift_training()
	voice_words()
	counter_words()
	check_log(six)
	untranslated_words()
	print("")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	await d.leave()
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


## The language buttons in the title card's corner: a click on the other language puts the
## game in it, the clinic's painted words with it, and a click on the first one puts it back.
## Nothing is saved: the run's language is pinned (Lang.pin), and Lang.save leaves it alone.
func languages() -> void:
	var first := Lang.code
	var other := "zh" if first == "en" else "en"
	var rects: Dictionary = main.screens.language_rects()
	check(rects.has("en") and rects.has("zh"), "the title card offers English and Chinese")
	d.click((rects[other] as Rect2).get_center())
	check(Lang.code == other and main.state == MainScript.State.TITLE, "a click on the other language switches to it on the title card")
	check(art(main.clinic._wall) == twin("booth", other) and art(main.clinic._hall) == twin("hall", other)
		and art(main.clinic._shutter) == twin("shutter", other), "the booth, the hall door and the shutter show their words in it")
	d.click((rects[first] as Rect2).get_center())
	check(Lang.code == first and art(main.clinic._wall) == twin("booth", first) and art(main.clinic._shutter) == twin("shutter", first),
		"a click on the first language puts everything back")


## The picture a painted name has in a language: booth in English, booth_zh in Chinese.
func twin(name: String, code: String) -> String:
	return name if code == "en" else name + "_" + code


## True when the strip shows exactly these words as the player reads them: the English line's
## translation in another language, broken into the strip's lines the way the strip breaks it.
func strip_says(box: Variant, text: String) -> bool:
	return box.lines == Gfx.wrap_text(text, box.TEXT_W)


func has_note_text(v: VisitState, row: String, part: String) -> bool:
	var list: Array = v.notes.get(row, [])
	for n in list:
		var note: Dictionary = n
		if str(note.get("text", "")).contains(part):
			return true
	return false


## One row of the sheet on the wall now (case_db sheet_for), or {}.
func wall_row(id: String) -> Dictionary:
	for row in main.clipboard.sheet.get("rows", []):
		var r: Dictionary = row
		if str(r.get("id", "")) == id:
			return r
	return {}


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


## The log's records of one type, oldest first.
func logged(type: String) -> Array:
	return main.event_log.memory.filter(func(r: Dictionary) -> bool: return str(r.get("type", "")) == type)


## Sets some of main.rules for a while ({"group": {"key": value}}) and returns what they were,
## for restore_rules(). The rules are one dictionary that the shift and every visit read as
## they go, so a change counts from the next thing that reads it.
func pin_rules(values: Dictionary) -> Dictionary:
	var was := {}
	for group in values.keys():
		var g: Dictionary = main.rules[group]
		var old := {}
		for k in (values[group] as Dictionary).keys():
			old[k] = g.get(k)
			g[k] = values[group][k]
		was[group] = old
	return was


func restore_rules(was: Dictionary) -> void:
	for group in was.keys():
		var g: Dictionary = main.rules[group]
		for k in (was[group] as Dictionary).keys():
			g[k] = was[group][k]


## A shift seed whose contact list is drawn for exactly these visitors (case ids), or -1.
func seed_for(cases: Array) -> int:
	var want: Array = cases.duplicate()
	want.sort()
	var order: Array = ShiftState.new(main.rules, []).order
	var pool := CaseDB.fair_contacts(main.contact_data, main.people, order)      # the entries the game draws from
	for s in range(1, 5001):
		var got: Array = []
		for e in ShiftState.draw_contacts(main.rules, pool, order, s, false):
			got.append(str((e as Dictionary).get("case", "")))
		got.sort()
		if got == want:
			return s
	return -1


## The records of one type written since the log held `from` records.
func logged_since(type: String, from: int) -> Array:
	return main.event_log.memory.slice(from).filter(func(r: Dictionary) -> bool: return str(r.get("type", "")) == type)


## True when the next patient to turn tonight would land blows at `blows_ms` after the warning
## and be through the window at `through_ms` (ShiftState.attack_plan(), from the glass left).
func plan_is(blows_ms: Array, through_ms: int) -> bool:
	var plan: Dictionary = main.shift.attack_plan()
	var due: Array = plan.get("blows_ms", [])
	if due.size() != blows_ms.size() or int(plan.get("through_ms", 0)) != through_ms:
		return false
	for i in due.size():
		if int(due[i]) != int(blows_ms[i]):
			return false
	return true


## Buzzes the next patient in and checks who it is. With `keep_guide`, a counter guide that
## opened by itself is left up for the caller.
func enter(id: String, keep_guide: bool = false) -> VisitState:
	var ok: bool = await d.buzz_in(keep_guide)
	check(ok, "%s comes to the counter" % id)
	var v: VisitState = main.visit
	check(v != null and str(v.case_data.get("id", "")) == id, "the visit is %s's" % id)
	return v


## The counter's words for a call (rules.json "counter"): the title the slip prints.
func counter_title(key: String) -> String:
	var words: Dictionary = (main.rules.get("counter", {}) as Dictionary).get(key, {})
	return str(words.get("title", ""))


## The slip prints with the counter's words for the call, the card keeps the doctor's own notes,
## the till shows what the counter took in, and taking the slip moves on.
func finish_visit(label: String) -> void:
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed, "%s: the result slip prints" % label)
	var key: String = main.visit.counter_key() if main.visit != null else ""
	check(key != "" and str(main._slip_data.get("counter_title", "")) == counter_title(key),
		"%s: the slip has the counter's words for the call, not whether it was right" % label)
	check(main.clipboard.mode == "exam", "%s: the card still shows the doctor's own notes" % label)
	check(main.clinic.till == main.shift.till(), "%s: the till shows what the counter took in" % label)
	var moved: bool = await d.take_slip()
	check(moved, "%s: taking the slip moves on" % label)
	check(main.visit == null and main.rig == null, "%s: the counter is clear afterwards" % label)


## A blow landed: the night ends with this visit. No slip prints; the report comes up out of the
## dark, names the visitors still in the hall, and nobody reads the meter.
func lights_out(label: String, unseen: Array) -> void:
	var up: bool = await d.wait_for_report(40.0)
	check(up and main.screens.mode == "report" and main.screens.fade > 0.5, "%s: the night ends here: the report comes up out of the dark" % label)
	check(main._slip_data.is_empty() and main._slip_mode == "hidden", "%s: no slip prints for it" % label)
	check(main.visit == null and main.rig == null, "%s: the counter is empty" % label)
	check(main.shift.died and main.shift.is_done() and main.shift.current_id() == "", "%s: nobody else comes in tonight" % label)
	check(main.shift.unseen() == unseen, "%s: still in the hall: %s" % [label, str(unseen)])
	var r: Dictionary = main.screens.report
	var said: Dictionary = main.rules.get("line_text", {})
	check(str(r.get("title", "")) == "LIGHTS OUT" and str(r.get("line_text", "")) == str(said.get("died", "-")),
		"%s: LIGHTS OUT, and nobody reads the meter" % label)
	var names: Array = []
	for id in unseen:
		names.append(str((main.cases.get(str(id), {}) as Dictionary).get("name", id)))
	var shown: PackedStringArray = r.get("unseen_names", PackedStringArray())
	check(Array(shown) == names, "%s: the report names whoever never came in" % label)
	var lit: bool = await d.until(func() -> bool: return main.screens.fade == 0.0, 4.0)
	check(lit and main.state == MainScript.State.REPORT, "%s: and the dark lifts off it" % label)


## The till at each of a report's hourly readings.
func tills_of(r: Dictionary) -> Array:
	var out: Array = []
	for item in r.get("readings", []):
		out.append(int((item as Dictionary).get("till", 0)))
	return out


## The report a page at a time: a page for each visit, then the night's totals. A click turns a
## page once it has been up for a moment, BACKSPACE and LEFT go back, ESC goes to the totals,
## and the jingle that says how the night went waits for them.
func report_pages(visits: int) -> void:
	section("Report pages: one for each visit, then the totals")
	check(main.screens.pages() == visits + 1 and main.screens.page == 0 and not main.screens.on_summary(),
		"the report opens on the first visit's page, of %d" % (visits + 1))
	check(not main._report_jingled, "the night's jingle waits for the totals")
	var early: bool = main.screens.age() < MainScript.REPORT_TURN
	d.click(Vector2(320, 200))
	check(not early or main.screens.page == 0, "a click as the page opens does not turn it yet")
	if not early:
		d.key(KEY_BACKSPACE)
	await d.until(func() -> bool: return main.screens.age() >= MainScript.REPORT_TURN + 0.05, 3.0)
	d.click(Vector2(320, 200))
	check(main.screens.page == 1, "a moment later a click turns to the next visit")
	d.key(KEY_BACKSPACE)
	check(main.screens.page == 0, "BACKSPACE goes back a page")
	d.key(KEY_LEFT)
	check(main.screens.page == 0, "and LEFT on the first page stays there")
	await d.until(func() -> bool: return main.screens.age() >= MainScript.REPORT_TURN + 0.05, 3.0)
	d.key(KEY_RIGHT)
	check(main.screens.page == 1, "RIGHT turns it too")
	var read: int = await d.read_report()
	check(main.screens.on_summary() and read == visits - 1, "page by page to the night's totals")
	check(main._report_jingled, "the totals play the jingle")
	d.click(Vector2(320, 200))
	check(main.state == MainScript.State.REPORT and main.screens.on_summary(), "a click the moment the totals open does not start a new night")
	d.key(KEY_BACKSPACE)
	check(main.screens.page == visits - 1, "BACKSPACE goes back from the totals to the last visit")
	d.key(KEY_ESCAPE)
	check(main.screens.on_summary(), "ESC goes straight to the totals")


# ================================================================ the opening and the guide

## The cards between the title and the first shift: what a key or a click does on them, and
## that skipping them starts the shift.
func the_opening() -> void:
	section("Opening cards")
	var up: bool = await d.open_counter(true)
	check(up and d.in_intro() and main.intro.is_running(), "the first click on the title brings up the opening cards")
	check(main.shift == null and main.visit == null, "no shift has started behind them")
	check(main.intro.count() == 6, "there are six cards")
	var fits := 0
	var drawn := 0
	for i in main.intro.count():
		var rows: int = main.intro.lines_of(i).size()
		if rows >= 1 and rows <= main.intro.TEXT_LINES:
			fits += 1
		else:
			print("  card %d takes %d lines" % [i + 1, rows])
		var art := str((main.intro._cards[i] as Dictionary).get("art", ""))
		if main.intro.ARTS.has(art):
			drawn += 1
		else:
			print("  card %d asks for a picture nobody draws: '%s'" % [i + 1, art])
	check(fits == main.intro.count(), "every card's text fits under its picture")
	check(drawn == main.intro.count(), "every card names one of the pictures the opening draws")
	var shown: bool = await d.until(func() -> bool: return main.intro._phase == "show" and main.intro.index == 0, 3.0)
	check(shown and main.intro._typed < float(main.intro._total), "the first card opens and starts typing its text")
	d.key(KEY_ENTER)
	check(main.intro.index == 0 and main.intro._typed >= float(main.intro._total), "ENTER first shows the rest of the text at once")
	d.key(KEY_ENTER)
	shown = await d.until(func() -> bool: return main.intro._phase == "show" and main.intro.index == 1, 3.0)
	check(shown, "ENTER again turns to the second card")
	d.click(Vector2(320, 100))
	check(main.intro.index == 1 and main.intro._typed >= float(main.intro._total), "a click does the same: the text first")
	d.click(Vector2(320, 100))
	shown = await d.until(func() -> bool: return main.intro._phase == "show" and main.intro.index == 2, 3.0)
	check(shown, "then the third card")
	d.key(KEY_SPACE)
	check(d.in_intro() and main.intro.index == 2 and main._armed <= 0.0, "SPACE is a page key here, not the shutter")
	d.key(KEY_ESCAPE)
	check(main.intro.skipped and not d.in_intro(), "ESC skips the rest")
	var open: bool = await d.wait_for_counter()
	check(open and main.shift != null and main.shift_number == 1, "and the first shift starts")
	check(not main.intro.is_running() and not main.intro.visible, "the cards are gone from the screen")
	var ends: Array = logged("intro_end")
	check(logged("intro").size() == 1 and ends.size() == 1 and bool(ends[0].get("skipped", false)) and int(ends[0].get("reached", 0)) == 3,
		"the log says the opening was skipped at the third card")


## The counter guide at the first patient of a session: it opens by itself before the patient
## says a word; each of its four pages lights one part of the booth and frames the things it
## explains where those things are; its pages turn and close on the keys and the mouse, and
## nothing under it is pressed meanwhile. Returns the visit it opened over.
func the_guide() -> VisitState:
	section("Counter guide")
	var ok: bool = await d.buzz_in(true)
	check(ok, "kip comes to the counter")
	var v: VisitState = main.visit
	check(v != null and str(v.case_data.get("id", "")) == "kip", "the visit is kip's")
	check(main.guide.is_open() and main.guide.page == 0, "the guide opens by itself at the first patient of a session")
	var ids: Array = []
	for i in main.guide.count():
		ids.append(main.guide.id_of(i))
	check(ids == ["window", "left", "right", "desk"], "it has four pages: the window, the left wall, the right wall, the desk")
	await d.seconds(0.6)
	check(main.dialogue.speaker == "" and not main.dialogue.typing, "the patient waits with his first words until it is closed")
	check(not d.sheet_down() and not d.card_down() and not d.cam_on(), "while it is open everything hangs on the walls, where it points")
	guide_layout()
	d.pad("treat")
	check(main.guide.page == 1 and main._held == "", "a click turns the page and presses nothing under it")
	d.key(KEY_LEFT)
	check(main.guide.page == 0, "LEFT goes back a page")
	d.click(main.desk.object_rect("sheet").get_center())
	check(main.guide.page == 1 and not main._sheet_wanted and not d.sheet_down(), "a click on the wall sheet turns the page too: the sheet stays where it hangs")
	d.key(KEY_SPACE)
	check(main.guide.page == 2 and main._armed <= 0.0, "SPACE turns the page and does not arm the shutter")
	for code in [KEY_R, KEY_L, KEY_N, KEY_C, KEY_G, KEY_T]:
		d.key(int(code))
	check(main.guide.page == 2 and not main._sheet_wanted and not main._list_wanted and not main._card_wanted and not main._cam_wanted
		and not main.dialogue.input_open, "the keys of the papers, the camera, the glass and the typing line do nothing under it")
	d.key(KEY_ENTER)
	check(main.guide.page == 3 and main.guide.is_open(), "ENTER turns to the last page")
	d.key(KEY_ENTER)
	check(not main.guide.is_open(), "and after the last page the guide closes")
	check(v.in_exam() and v.patience == v.patience_max and v.seen.is_empty(), "reading it cost nothing and checked nothing")
	var spoke: bool = await d.until(func() -> bool: return main.dialogue.speaker != "" and main.dialogue.typing, 3.0)
	check(spoke, "now the patient says his first words")
	d.key(KEY_H)
	check(main.guide.is_open() and main.guide.page == 0, "H opens the guide again, from its first page")
	d.right_click()
	check(not main.guide.is_open(), "the right button closes it")
	d.key(KEY_F1)
	check(main.guide.is_open(), "F1 opens it too")
	d.key(KEY_ESCAPE)
	check(not main.guide.is_open() and v.in_exam(), "ESC closes it, and the exam is where it was")
	var opened: Array = logged("guide")
	check(opened.size() == 3 and not bool(opened[0].get("asked", true)) and bool(opened[2].get("asked", false)),
		"the log tells the guide that opened by itself from the two that were asked for")
	return v


## Where the guide points. Every page's list is on the screen; every frame is in the part of
## the screen its page lights, clear of the list, and round the thing it names.
func guide_layout() -> void:
	var screen := Rect2(Vector2.ZERO, Gfx.SCREEN)
	var fits := 0
	var keys := 0
	var placed := 0
	for i in main.guide.count():
		var box: Rect2 = main.guide.box_of(i)
		if box.size.y > 0.0 and screen.encloses(box):
			fits += 1
		else:
			print("  guide page %d does not fit: %s" % [i + 1, str(box)])
		var lit: Rect2 = main.guide.LIT.get(main.guide.id_of(i), Rect2())
		for key in main.guide.keys_of(i):
			keys += 1
			var area: Rect2 = main.guide.AREAS.get(key, Rect2())
			if area.size.x > 0.0 and lit.encloses(area) and not box.intersects(area):
				placed += 1
			else:
				print("  guide item '%s' is outside the lit part of its page, or under the list: %s" % [key, str(area)])
	check(fits == main.guide.count(), "every page's list fits on the screen")
	check(keys == 16 and placed == keys, "the sixteen things it explains are framed in the lit part of their page, clear of the list")
	var buttons: Rect2 = main.dialogue.chip_rect("type")
	var speak: Rect2 = main.dialogue.chip_rect("speak")
	if speak.size.x > 0.0:
		buttons = buttons.merge(speak)
	var real := {
		"patience": main.clinic.patience_plate(),
		"glass": main.clinic.glass_plate(),
		"sheet": main.desk.object_rect("sheet"),
		"list": main.desk.object_rect("list"),
		"booklet": main.desk.object_rect("guide"),
		"till": Gfx.METER,
		"camera": Gfx.THUMB,
		"record": main.desk.object_rect("card"),
		"treat": main.desk.pad_rect("treat"),
		"team": main.desk.pad_rect("refer"),
		"shutter": main.desk.pad_rect("shutter"),
		"mend": main.desk.pad_rect("glass"),
		"tools": main.desk.pad_rect("penlight").merge(main.desk.pad_rect("port")),
		"talk": main.desk.pad_rect("ask").merge(main.desk.pad_rect("press")),
		"say": buttons,
	}
	var around := 0
	for key in real.keys():
		var thing: Rect2 = real[key]
		var frame: Rect2 = main.guide.AREAS.get(key, Rect2())
		if thing.size.x > 0.0 and frame.grow(1.0).encloses(thing):
			around += 1
		else:
			print("  the guide's frame for '%s' %s is not round %s" % [str(key), str(frame), str(thing)])
	check(around == real.size(), "each frame is round the thing itself: the lamps, what hangs on the walls, the keys, the pads, the buttons")
	var visitor: Rect2 = main.guide.AREAS.get("patient", Rect2())
	var parts := 0
	var held := 0
	for who in main.meta.keys():
		var sprite: Dictionary = main.meta[who]
		var zones: Dictionary = sprite.get("zones", {})
		for zone in zones.keys():
			var a: Array = zones[zone]
			var spot: Rect2 = Gfx.rect_to_screen(Rect2(Gfx.PATIENT_POS + Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]), float(a[3]))))
			parts += 1
			if visitor.has_point(spot.get_center()):
				held += 1
			else:
				print("  %s's %s is outside the guide's frame for the visitor: %s" % [str(who), str(zone), str(spot)])
	check(parts == 15 and held == parts, "the frame round the visitor holds the eyes, the hands and the port of all five")


# ================================================================ shift 1

func shift_careful() -> void:
	section("Title card")
	check(main.state == MainScript.State.TITLE and main.screens.mode == "title", "the game starts on the title card")
	check(main.data_errors.is_empty(), "the case data loaded without problems")
	check(main.screens.status_line == main.STATUS_OFFLINE, "the title card says who answers tonight: the authored patient")
	languages()
	await the_opening()

	section("Hall camera")
	check(main.clinic.cam_id == "kip", "the hall camera shows the first patient")
	check(not main.desk.is_enabled("penlight") and not main.desk.is_enabled("treat"), "the desk is off while nobody is at the counter")
	check(main.clipboard.mode == "blank", "the intake record is blank between patients")
	check(main.clinic.shutter_pos < 0.05, "the shutter is up before anyone is buzzed in")
	check(main.clinic.line == 120 and not main.clinic.line_under, "the meter shows what the first hour has to bring in")
	check(main.clinic.glass_left == 3 and main.clinic.glass_max == 3 and main.shift.glass == 3, "the glass is whole at the start of the night")
	check(int(main.sheet.get("threshold", 0)) == 2, "the reference sheet carries the house rule: two broken lines")
	check(str(main.clipboard.sheet.get("title", "")) == str(main.sheet.get("title_none", "")) and str(wall_row("eyes").get("tag", "")) == "NATURAL"
		and is_equal_approx(main._grip_limit_s(), 1.0), "with nobody at the counter the sheet on the wall is the binder's baseline body")
	check(not d.cam_on() and not d.sheet_down() and not d.card_down(), "nothing hangs in front of the window: the papers and the big screen are on the walls")
	check(main._base_hint == main.WAIT_HINT, "the hint says how to let the first one in")
	d.move(d.thumb_pos())
	await process_frame
	await process_frame
	check(main.clinic.thumb_hot and main._cursor_kind == "hand" and main._hover_hint == main.WAIT_HINT, "the small hall monitor lights up under the pointer")
	d.click(d.thumb_pos())
	check(d.cam_on() and main._cam_wanted and main.state == MainScript.State.WAIT and main.visit == null,
		"a click on it puts the hall on the big screen, and lets nobody in yet")
	check(main._base_hint == main.CAM_HINT, "the hint now points at the big screen")
	d.move(Gfx.MONITOR.get_center())
	await process_frame
	await process_frame
	check(main.clinic.monitor_hot and main._cursor_kind == "hand" and main._hover_hint == main.CAM_HINT, "the big screen lights up under the pointer too")
	d.right_click()
	check(not d.cam_on() and main._base_hint == main.WAIT_HINT, "the right button on it switches it off again")
	d.key(KEY_C)
	check(d.cam_on(), "C switches it on")
	d.key(KEY_ESCAPE)
	check(not d.cam_on() and main.state == MainScript.State.WAIT and main.visit == null, "and ESC off: nobody was buzzed in by any of it")

	var v: VisitState = await the_guide()

	section("Kip: look, test, talk, press and reassure, then TREAT")
	check(main.rig != null and main.rig.at_counter(), "he is standing at the counter")
	check(main.desk.is_enabled("treat") and main.desk.is_enabled("refer") and main.desk.is_enabled("shutter"),
		"the stamp, the call box and the shutter are available before anything has been checked")
	check(main.clipboard.mode == "exam" and main.clinic.show_patience, "the intake card and the patience lamps are showing")
	check(str(main.clipboard.sheet.get("title", "")) == Lang.fill("REFERENCE SHEET: {name}", {"name": "KIP MARLOW"})
		and str(wall_row("eyes").get("tag", "")) == Lang.fill("L {tag}", {"tag": "KITE"}) and str(wall_row("port").get("tag", "")) == "STREET",
		"the sheet on the wall is pulled for his models: a KITE beside a natural eye, a street port")
	d.move(d.zone_pos("eyes"))
	await process_frame
	await process_frame
	check(main.clipboard.highlight_row == "eyes" and main._cursor_kind == "look", "hovering his eyes highlights the EYES line")
	await d.look("eyes")
	check(v.seen.has("look:eyes") and v.patience == v.patience_max, "a look is free")
	check(note_count(v, "eyes") == 1, "the look is noted on the EYES row")
	check(main._coached.has("note") and main._base_hint == main.NOTE_COACH_HINT,
		"the first note of a session brings the tip about where the intake card hangs")
	await process_frame
	check(str(main.desk.badges.get("card", "")) == "1" and not d.card_down(), "and the card on the wall counts the note it has not shown yet")
	await d.look("hands")
	await d.look("port")
	check(v.seen.has("look:hands") and v.seen.has("look:port"), "hands and port can be looked at the same way")
	var status: String = await d.request_tool("penlight")
	check(status == "open", "the penlight close-up opens when he agrees")
	check(main.clinic.scope.standard == str(wall_row("eyes").get("normal", ""))
		and main.clinic.scope.standard == Lang.fill("L: {l}. R: {r}. Both follow.", {"l": "no pupil", "r": "tightens"}),
		"the close-up holds up the sheet's line for his two eyes")
	check(v.patience == v.patience_max - 1, "a first test costs one patience")
	check(not v.seen.has("check:penlight"), "agreeing is not evidence: nothing is written until the light is used")
	var done: bool = await d.sweep_eyes()
	check(done, "sweeping the light over both eyes writes the result")
	await d.put_away()
	check(not main.clinic.scope.is_open() and main.desk.active == "", "right-click puts the tool away")
	status = await d.request_tool("grip")
	check(status == "open", "the grip bar opens")
	check(is_equal_approx(main.clinic.scope.limit_s, 1.0), "a natural hand: the LIMIT mark is at 1 s")
	done = await d.squeeze_and_release()
	check(done, "hold and release writes the hand result")
	check(has_note_text(v, "hands", Lang.fill(str(v.case_data["checks"]["grip"]["note"]), {"t": "0.3"})),
		"the grip note carries the time the game measured")
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
	check(main._coached.has("lamp") and main._base_hint == main.LAMP_COACH_HINT,
		"with one lamp left, the hint says once what happens when it goes out")
	await d.settle()
	await d.reassure()
	check(v.reassure_left == 1 and v.patience == v.patience_max - 4, "reassurance gives one patience back")
	check(main._base_hint == "", "the tip is gone with the next action")
	await d.settle()
	check(main._card_unseen >= 3 and str(main.desk.badges.get("card", "")) == str(main._card_unseen) and not d.card_down(),
		"all this time the card hung on the wall, counting the notes written on it")
	d.mark("eyes")
	check(d.card_down() and main._card_wanted and not main.desk.badges.has("card"), "marking takes it down first, and its count is gone once it is read")
	check(int(v.marks.get("eyes", 0)) == 1 and v.ticked() == 1 and v.crossed() == 0, "clicking a mark box ticks it")
	d.mark("eyes")
	check(int(v.marks.get("eyes", 0)) == 2 and v.crossed() == 1, "a second click makes it a cross")
	check(main._base_hint == Lang.tf(main.CROSS_SOME_HINT, [1, 2]), "the hint counts the doctor's crosses against the house rule")
	d.mark("eyes")
	check(int(v.marks.get("eyes", 0)) == 0 and main._base_hint == "", "the mark cycles back to blank, and the count goes with it")
	check(v.in_exam() and v.patience == v.patience_max - 4, "marking the record costs nothing and decides nothing")
	d.pad("treat")
	await process_frame
	check(main._held == "treat" and main.clipboard.armed == "treat" and v.in_exam(), "picking the stamp up decides nothing yet")
	d.right_click()
	check(main._held == "" and v.in_exam(), "right-click puts the stamp back")
	await d.stamp("treat")
	check(v.verdict_kind == "treat" and v.outcome == "treated_ok", "stamping the card decides: TREAT")
	await finish_visit("Kip")
	check(main.shift.till() == 250 and main.clinic.till == 250, "his fee is in the till")
	check(main.clinic.cam_id == "rook", "the next patient is on the camera")
	check(main.clinic.line == 240 and not main.clinic.line_under, "the meter read the first hour as over the line, and now shows the second hour's")
	var meters: Array = logged("meter")
	check(meters.size() == 1 and bool(meters[0].get("held", false)) and int(meters[0].get("hour", 0)) == 1
		and int(meters[0].get("till", 0)) == 250 and int(meters[0].get("line", 0)) == 120, "the reading is logged: hour 1, 250 against 120")

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
	check(is_equal_approx(main.clinic.scope.limit_s, 1.5) and str(wall_row("hands").get("tag", "")) == "LOADER",
		"his LOADER rig has its own limit on the sheet and on the close-up: 1.5 s")
	done = await d.squeeze_and_release()
	check(done, "his grip result is written")
	var before: int = v.patience
	await d.ask(1)
	await d.settle()
	check(v.answered.has("mood") and v.patience == before - 1, "once reassured, he answers the question about his mood straight away")
	await d.ask(1)
	await d.settle()
	check(v.patience == before - 1, "hearing an answer again is free")
	check(d.card_down() and main._coached.has("note_open"), "the card is still down from Kip's visit, and a note written on it brought the tip about the mark boxes")
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
	check(main.clinic.bar_on and main.clinic.bar_text == "" and main.clinic.bar_blows.size() == 3
		and is_equal_approx(main.clinic.bar_through, 1.8), "the bar over the printer slot shows three blows to come and 1.8 s until he is through")
	var struck: bool = await d.until(func() -> bool: return main._blows >= 2, 4.0)
	check(struck and main.clinic.glass_state == 2, "two blows land and the glass cracks twice")
	check(main.clinic.decal_count() >= 1, "the saw leaves its mark on the glass")
	check(right_art(main.rig._spr["attack"], "attack_s2"), "the hand on the glass is the one for the blood setting")
	check(right_art(main.rig._spr["mouth"], "mouth_turn"), "the scream is the one for the blood setting")
	d.shutter_key()
	check(v.outcome == "caught", "one press of SPACE drops the shutter in time")
	check(v.shutter_grade() == "cracked" and v.blows_taken == 2, "two blows got in first: the stop is graded as cracked")
	check(main.shift.glass == 1 and main.clinic.glass_left == 1, "each blow cost the glass: one is left for the rest of the night")
	check(main.clinic.bar_on and main.clinic.bar_text == Lang.tf(main.STOP_BLOWS_LINE, 2), "the bar now says how the stop went")
	await process_frame
	await process_frame
	check(main._coached.has("glass") and main.dialogue.hint == main.GLASS_COACH_HINT,
		"after the first attack of a session the hint explains what the blows cost")
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed, "Vale: the result slip prints")
	check(str(main._slip_data.get("counter_title", "")) == counter_title("caught") and main.clinic.till == 1150,
		"the slip says the shutter held, and Trauma Team's fee is in the till, paid on account")
	check(not main.clinic.bar_on and main.clinic.bar_text == "", "the bar is gone when the slip prints out of its slot")
	check(plan_is([540], 990), "with one glass left, the next one to turn would be through in under a second")
	check(main.clinic.shutter_closed(), "the shutter is down")
	check(main.clinic.strobe == 0.0 and not main.clinic.team_in_sight(), "the crew's lights have come and gone outside")
	check(main.clinic.dent_count() == 3 and main.clinic.has_cut(), "the shutter took three hits and the saw came through it")
	check(right_art(main.clinic._cut, "cut_saw"), "the cut in the shutter is the one for the blood setting")
	check(main.clinic.glass_state == 2, "the cracks stay in the glass")
	check((main.clinic.drip_count() > 0) != main.less_blood, "blood ran out under the shutter")
	check(not main.audio._loops.has("alarm") and not main.audio._loops.has("saw_loop"), "the alarm and the saw are quiet")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 600 and int(last_record().get("counter", -1)) == 600,
		"a caught attack: Trauma Team pays his fee on account at the counter, and keeps it as the bounty at closing")
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
	check(str(last_record().get("title", "")) == "TAKEN IN" and int(last_record().get("credits", 0)) == 400 and int(last_record().get("counter", -1)) == 400,
		"the report will call it TAKEN IN: her fee, paid on account by the crew")

	section("Report")
	check(main.state == MainScript.State.REPORT and main.screens.mode == "report", "the last slip leads to the end-of-shift report")
	var r: Dictionary = main.screens.report
	check(int(r.get("correct", 0)) == 5 and int(r.get("total", 0)) == 1900 and bool(r.get("line_held", false)) and not bool(r.get("died", true)),
		"five right calls, 1900 at closing, over the line")
	check(int(r.get("counter_total", 0)) == 1900 and int(r.get("closing_total", 0)) == 0,
		"all of it came in at the counter, the two fees Trauma Team paid on account too; its report at closing kept them")
	check(int(r.get("line", 0)) == 600 and int(r.get("hours_under", -1)) == 0 and tills_of(r) == [250, 550, 1150, 1500, 1900],
		"the line was 600; each hour the meter read what the counter had taken, and at closing everything")
	check(str(r.get("title", "")) == "STEADY HANDS" and str(r.get("line_text", "")).contains("OVER THE LINE"), "the night gets its best name")
	check(int(r.get("glass", -1)) == 1 and int(r.get("glass_max", 0)) == 3, "the report knows what the glass took")
	check(main.clinic.till == 1900 and main.clinic.line == 600 and not main.clinic.line_under, "the meter on the wall shows the last reading, with the night's reports in")
	check(main.clinic.results == ["treat", "treat", "team", "treat", "team"], "its lamps show the doctor's calls, not whether they were right")
	await report_pages(5)


# ================================================================ shift 2

func shift_reckless() -> void:
	section("New shift")
	var opened: bool = await d.open_counter()
	check(opened, "a click on the report's totals starts a new shift")
	check(main.shift_number == 2 and main.shift.index == 0 and main.clinic.till == 0 and main.clinic.results.is_empty(),
		"the new shift starts from zero")
	check(main.shift.glass == 3 and not main.shift.glass_out and main.clinic.glass_left == 3, "a new night starts with whole glass")
	check(main.clinic.line == 120 and not main.clinic.line_under, "and with the first hour's line on the meter")
	check(logged("intro").size() == 1, "the opening does not play a second time")

	section("Kip: the shutter needs two presses during an ordinary exam")
	var v: VisitState = await enter("kip", true)
	check(not main.guide.is_open(), "the guide does not open by itself a second time")
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
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed, "Kip: the result slip prints")
	check(str(main._slip_data.get("counter_title", "")) == counter_title("shutter") and int(main._slip_data.get("counter", -1)) == 0,
		"Kip: the slip says only that the shutter came down: no fee, no call")
	check(main.clipboard.mode == "exam", "Kip: the card still shows the doctor's own notes")
	check(main.clinic.till == 0 and main.shift.till() == 0, "Kip: nothing is off the till yet: the fine waits for closing")
	d.click(MainScript.SLIP_CLIP.get_center())
	var reading_up: bool = await d.until(func() -> bool: return main.dialogue.speaker == "METER", 15.0)
	check(reading_up and main.clinic.queue_index == 0 and main.clinic.line == 120 and main.clinic.line_under,
		"while the meter reads the hour, the pinned notes still show that hour and its line, in red")
	var turned: bool = await d.until(func() -> bool: return main.state == MainScript.State.WAIT and main.clinic.cam_prompt, 15.0)
	check(turned and main.clinic.queue_index == 1, "then the notes turn to the second hour together")
	check(main.visit == null and main.rig == null, "Kip: the counter is clear afterwards")
	check(int(last_record().get("credits", 0)) == -100 and not bool(last_record().get("correct", true)), "the false alarm is billed at closing: 100")
	check(main.clinic.line_under and main.clinic.line == 240, "the meter reads the first hour as under the line")

	section("Rook: pressed twice, he walks out")
	v = await enter("rook")
	await d.press()
	check(v.in_exam() and v.press_count == 1, "the first insult only makes him angry")
	await d.settle()
	await d.press()
	check(v.outcome == "walkout", "the second insult ends the visit")
	await finish_visit("Rook")
	check(int(last_record().get("credits", 0)) == 0 and not bool(last_record().get("correct", true)), "a walkout pays nothing")

	section("Vale: Trauma Team called and no shutter: the night ends with him")
	v = await enter("vale")
	await d.call_team()
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "he turns")
	var broke: bool = await d.until(func() -> bool: return main.clinic.glass_state == 4, 6.0)
	check(broke and main._blows == 3, "three blows, and the glass gives")
	check(v.shutter_grade() == "through" and not main.clinic.bar_on, "the bar is gone: he is through")
	check(right_art(main.clinic._broken, "glass_broken"), "what is left of the pane is the one for the blood setting")
	var through: bool = await d.until(func() -> bool: return main.rig != null and main.rig.pop >= 1.0, 3.0)
	check(through and main.rig.back.get_parent() == main.gore.jump, "he comes through the window at the player")
	var bled: bool = await d.until(func() -> bool: return main.gore.splat_count() >= 6, 3.0)
	check(bled != main.less_blood, "blood lands on the player's view")
	await lights_out("Vale", ["juno", "maren"])
	check(v.outcome == "hit" and bool(last_record().get("injured", false)), "with no shutter the attack lands")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == -300, "the call was right, and it still cost 300")
	check(main.clinic.glass_state == 4 and main.shift.glass == 0 and main.shift.glass_out and main.clinic.glass_left == 0, "the window is broken out")
	check((main.clinic.stain_count() > 0) != main.less_blood, "the blood dries on the wall")
	check(main.gore.splat_count() == 0 and not main.gore.busy() and main.gore.vignette == 0.0, "what was on the player's view went with the dark")

	section("Report: LIGHTS OUT")
	var r: Dictionary = main.screens.report
	check(bool(r.get("died", false)) and str(r.get("title", "")) == "LIGHTS OUT" and not bool(r.get("line_held", true)),
		"the night is LIGHTS OUT, and no line is held by a dead doctor")
	check(int(r.get("total", 0)) == -400 and int(r.get("counter_total", -1)) == 0 and int(r.get("closing_total", 0)) == -400
		and int(r.get("correct", 0)) == 1 and int(r.get("injuries", 0)) == 1,
		"minus 400, all of it billed at closing: one right call, and the injury that ended the night")
	check((r.get("readings", []) as Array).size() == 2 and int(r.get("hours_under", 0)) == 2 and tills_of(r) == [0, 0],
		"two readings, both under the line, and none for the hour he came through")
	check((r.get("unseen", []) as Array) == ["juno", "maren"] and (r.get("unseen_names", PackedStringArray()) as PackedStringArray).size() == 2,
		"Juno and Maren were never seen")
	check(main.screens.pages() == 4, "a page for each of the three visits, then the totals")
	check(main.clinic.results == ["shutter", "none", "hit"], "the meter's lamps: the shutter, nothing, the blow")
	check(main.clinic.till == -400 and main.clinic.line == 360 and main.clinic.line_under,
		"the till on the wall shows the night's money; nobody reads the meter, so it stays at the third hour's line")


# ================================================================ shift 3

func shift_odds_and_ends() -> void:
	section("Third shift")
	var opened: bool = await d.open_counter()
	check(opened, "a third shift starts")
	check(main.clinic.glass_state == 0 and main.clinic.stain_count() == 0 and main.clinic.dent_count() == 0
		and main.clinic.drip_count() == 0 and main.clinic.decal_count() == 0, "the window, the wall and the shutter are whole again")
	check(main.shift.glass == 3 and not main.shift.glass_out and main.clinic.glass_left == 3 and plan_is([540, 990, 1440], 1800),
		"and so is the glass: a new pane every night")
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
	check(main._base_hint == main.SHORT_HINT, "the hint says why")
	check(not v.is_spent() and not main._leave_said, "one lamp is still lit: he is not leaving yet")
	check(v.in_exam() and main.desk.is_enabled("treat") and main.desk.is_enabled("refer"), "both decisions still work when patience cannot pay")
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
	main.audio.set_muted(false)      # the players must run for a fade to be seen; the dummy driver is silent
	await d.press()
	check(main.state == MainScript.State.ATTACK and v.attack_cause == "press", "the second line turns him")
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "the warning comes")
	check(main.audio.trim_db == main.ATTACK_TRIM_DB, "the attack's sounds start %.0f dB under the exam's" % -main.ATTACK_TRIM_DB)
	d.click(d.pad_pos("shutter"))
	check(v.outcome == "caught", "one click on the lever drops the shutter")
	check(v.shutter_grade() == "clean" and v.blows_taken == 0 and main.shift.glass == 3, "before the first blow: a clean stop, and the glass is untouched")
	check(main.clinic.bar_on and main.clinic.bar_text == main.STOP_CLEAN_LINE, "the bar says so")
	check(main.audio.fading() > 0, "the warning whine is faded out, not cut dead, when the shutter drops on it")
	await finish_visit("Vale")
	check(main.audio.trim_db == 0.0 and main.audio.fading() == 0, "the trim is gone once the slip has printed, and so is the fade")
	main.audio.set_muted(true)

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
	# the patient need not finish answering: looking and deciding go ahead meanwhile
	await d.settle()
	main.act_reassure()
	check(main._lock and not main._thinking and main.dialogue.speaker == "YOU", "a reassuring line is on its way")
	var seq: int = main._seq
	main.act_look("eyes")
	check(main._lock and main._seq == seq and v.seen.has("look:eyes") and main.dialogue.speaker == "EYES",
		"a look while that line is still out happens, and does not cancel it")
	main.act_pick_stamp("treat")
	check(main._held == "treat" and main._lock, "neither does picking up the stamp")
	main.act_stamp_record()
	check(v.outcome == "treated_ok" and not main._lock and not main._thinking and v.reassure_used == 0,
		"TREAT does not wait for the answer, and the dropped answer changed nothing")
	var dropped: Array = main.event_log.memory.filter(func(r: Dictionary) -> bool: return str(r.get("type", "")) == "reply_dropped")
	check(dropped.size() == 1 and str(dropped[0].get("stage", "")) == "line" and str(dropped[0].get("by", "")) == "treat",
		"the dropped answer is logged once, with its stage")
	await finish_visit("Juno")

	section("Maren: the shutter during the exam")
	v = await enter("maren")
	d.shutter_key()
	d.shutter_key()
	check(v.outcome == "locked_out", "locking a drifting patient out ends the visit")
	var dents_before: int = main.clinic.dent_count()
	await finish_visit("Maren")
	check(main.clinic.dent_count() == dents_before, "nothing hits the shutter from the far side: that would tell who she was")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 0, "it counts as a right call and pays nothing")
	var r: Dictionary = main.screens.report
	check(main.state == MainScript.State.REPORT and int(r.get("total", 0)) == 1500 and int(r.get("correct", 0)) == 5, "the third report adds up")


# ================================================================ shift 4

## The hourly line, a patient who runs out of patience, the doctor's own crosses against the
## house rule, the glass wearing down over two attacks, and a patient thinking an answer over.
func shift_line_and_glass() -> void:
	section("Fourth shift")
	var opened: bool = await d.open_counter()
	check(opened, "a fourth shift starts")
	check(main.shift.glass == 3 and main.clinic.line == 120 and not main.clinic.line_under, "whole glass, and the first hour's line")

	section("Kip: the last lamp goes out, he is held once, then he leaves by himself")
	var v: VisitState = await enter("kip")
	await d.settle()
	await d.press()
	await d.settle()
	await d.ask(0)
	await d.settle()
	var status: String = await d.request_tool("penlight")
	check(status == "open", "the penlight opens")
	await d.put_away()
	status = await d.request_tool("grip")
	check(status == "open" and v.patience == 1, "after a press, a question and two tests one lamp is left")
	await d.put_away()
	await d.ask(1)
	check(v.is_spent() and v.in_exam(), "one more question puts the last lamp out, and the exam is still open")
	check(main.desk.is_enabled("treat") and main.desk.is_enabled("refer") and main.desk.is_enabled("shutter") and main.desk.is_enabled("calm"),
		"both decisions, the shutter and CALM still work")
	check(not main._leave_said and main.clinic.leaving < 0.0, "he finishes his answer first")
	var said: bool = await d.until(func() -> bool: return main._leave_said, 8.0)
	check(said and strip_says(main.dialogue, str(v.case_data["lines"]["spent"])), "then he says he has to go")
	await process_frame
	await process_frame
	check(main.clinic.leaving > 0.0 and main.clinic.leaving <= 1.0, "the lamps turn into the time that is left")
	check(main.dialogue.hint == (main.LEAVING_HINT if v.reassure_cost() > 0 else main.LEAVING_FREE_HINT), "the hint says what can still be done")
	var calm_hint: String = main._pad_hint("calm")
	check(calm_hint == Lang.tf(main.CALM_FREE_HOLD_HINT, [1, 2]) and calm_hint.begins_with(Lang.t("CALM"))
		and Gfx.text_w(calm_hint) <= main.dialogue.TEXT_W,
		"CALM says that it would hold him, under the name printed on the pad, in words that fit the hint row")
	check(main.LEAVING_HINT.contains("CALM") and main.LEAVING_FREE_HINT.contains("CALM") and main.SHORT_HINT.contains("CALM"),
		"the hints that send the player to that pad call it by the name printed on it")
	var left: float = main._leave_t
	d.key(KEY_H)
	check(main.guide.is_open(), "the guide can be opened while he waits")
	await d.seconds(1.0)
	check(is_equal_approx(main._leave_t, left), "the wait stands still while the guide is up")
	d.key(KEY_ESCAPE)
	await d.reassure()
	await process_frame
	await process_frame
	check(v.patience == 1 and v.reassure_left == 1 and v.in_exam(), "reassurance lights one lamp again")
	check(not main._leave_said and main.clinic.leaving < 0.0, "and he stays")
	var calms: Array = logged("reassure")
	check(not calms.is_empty() and bool(calms[calms.size() - 1].get("held", false)), "the log says the reassurance held him")
	await d.settle()
	await d.ask(2)
	check(v.is_spent() and v.in_exam(), "another question, and the lamps are out again")
	said = await d.until(func() -> bool: return main._leave_said, 8.0)
	check(said, "he says it again")
	calm_hint = main._pad_hint("calm")
	check(calm_hint == Lang.tf(main.CALM_FREE_HOLD_HINT, [1, 1]) and Gfx.text_w(calm_hint) <= main.dialogue.TEXT_W, "one reassurance is left")
	var gone: bool = await d.until(func() -> bool: return v.outcome == "gave_up", 14.0)
	check(gone and v.verdict_kind == "", "left alone for the whole wait, he walks out, and nobody decided anything")
	await finish_visit("Kip")
	check(str(last_record().get("title", "")) == "OUT OF PATIENCE" and int(last_record().get("credits", 0)) == 0
		and not bool(last_record().get("correct", true)), "the record says OUT OF PATIENCE: no fee, no fine, not a right call")
	check(main.clinic.line_under and main.clinic.line == 240, "an hour with nothing in the till reads as under the line")
	var meters: Array = logged("meter")
	var reading: Dictionary = meters[meters.size() - 1]
	check(not bool(reading.get("held", true)) and int(reading.get("till", -1)) == 0 and int(reading.get("line", 0)) == 120,
		"the reading is logged: 0 against 120")

	section("Rook: the doctor's own crosses reach the house rule, and the doctor decides anyway")
	v = await enter("rook")
	await d.settle()
	d.mark("eyes")
	d.mark("eyes")
	check(v.crossed() == 1 and main._base_hint == Lang.tf(main.CROSS_SOME_HINT, [1, 2]), "one cross: the hint says one alone can be ordinary")
	d.mark("hands")
	check(v.ticked() == 1 and v.crossed() == 1 and main._base_hint == Lang.tf(main.CROSS_SOME_HINT, [1, 2]), "a tick on another row does not change the count")
	d.mark("hands")
	check(v.crossed() == 2 and main._base_hint == Lang.tf(main.CROSS_RULE_HINT, 2), "two crosses: the hint names the house rule")
	check(v.in_exam() and main.desk.is_enabled("treat") and v.patience == v.patience_max, "the rule is advice: nothing is decided, locked or paid for")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT against his own marks")
	await finish_visit("Rook")
	check(int(last_record().get("crossed", 0)) == 2 and bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 300,
		"the game scores the call, not the marks: TREAT was right for Rook, as the report will say")
	check(not main.clinic.line_under and main.clinic.line == 360, "300 against 240: back over the line")

	section("Vale: the shutter after the first blow")
	v = await enter("vale")
	check(plan_is([540, 990, 1440], 1800), "whole glass: three blows to come, 1.8 s")
	await d.call_team()
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "the call turns him")
	var struck: bool = await d.until(func() -> bool: return main._blows >= 1, 3.0)
	check(struck, "the first blow lands")
	d.shutter_key()
	check(v.outcome == "caught" and v.shutter_grade() == "cracked" and v.blows_taken == 1, "stopped after one blow")
	check(main.clinic.bar_text == Lang.tf(main.STOP_BLOW_LINE, 1), "the bar counts it")
	check(main.shift.glass == 2 and main.clinic.glass_left == 2 and not main.shift.glass_out, "the glass is down to two")
	await finish_visit("Vale")
	check(int(last_record().get("credits", 0)) == 600 and str(last_record().get("grade", "")) == "cracked", "the record keeps the grade of the stop, and Trauma Team's fee")

	section("Juno: a patient who takes time to answer is seen thinking")
	v = await enter("juno")
	await d.settle()
	var slow := SlowClient.new()
	slow.tree = self
	main.agent.client = slow
	main.agent.set_mode("model")
	check(main.agent.mode == "model" and main._mic_why_not() == "no_service", "a stand-in service that answers slowly, and cannot hear")
	d.pad("ask")
	await process_frame
	d.click(main.dialogue.menu_point(0))
	d.move(Gfx.DIALOGUE.position + Vector2(200, 38))      # off the list, on nothing that can be pressed
	var pondering: bool = await d.until(func() -> bool: return main.rig != null and main.rig.thinking and main.rig._bubble.visible, 2.0)
	check(pondering, "while the answer is on its way she is seen thinking, with a thought bubble by her head")
	check(main.rig._gaze == Vector2(2, -1) or main.rig._gaze == Vector2(1, -1), "in her own way: she looks up and away")
	check(main._thinking and main._lock and main.desk.is_enabled("treat") and main.desk.is_enabled("refer"), "the decisions do not wait for the answer")
	var told: bool = await d.until(func() -> bool: return main.dialogue.hint == main.THINK_HINT, 2.0)
	check(told, "after a moment the hint says so")
	var answered: bool = await d.until(func() -> bool: return not main._thinking and not main._lock, 6.0)
	await process_frame
	await process_frame
	check(answered and not main.rig.thinking and not main.rig._bubble.visible, "the pose and the bubble end when the answer comes")
	check(str(main.agent.last.get("source", "")) == "fallback" and main.agent.fallbacks_this_visit == 1,
		"the service had no answer: the authored patient answered instead")
	main.agent.set_mode("script")
	main.agent.client = null
	await d.settle()
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Juno")
	await finish_visit("Juno")

	section("Maren: less glass, less time")
	v = await enter("maren")
	check(plan_is([540, 990], 1440), "two left: two blows to come, and 1.44 s")
	await d.settle()
	await d.press()
	check(v.in_exam() and v.press_count == 1, "the first line gets a reaction")
	await d.settle()
	await d.press()
	check(main.state == MainScript.State.ATTACK and v.attack_cause == "press", "the second line turns her")
	warned = await d.wait_for_telegraph()
	check(warned and main.clinic.bar_blows.size() == 2 and is_equal_approx(main.clinic.bar_through, 1.44),
		"the bar shows the shorter time, with two marks on it")
	var hit: bool = await d.until(func() -> bool: return v.outcome == "hit", 4.0)
	check(hit and main._blows == 2 and v.blows_taken == 2 and v.shutter_grade() == "through", "with no shutter she is through after two blows")
	check(main.shift.glass_out and main.shift.glass == 0 and main.clinic.glass_left == 0 and main.clinic.glass_state == 4, "the pane is gone")
	await lights_out("Maren", [])
	check(int(last_record().get("credits", 0)) == -300 and not bool(last_record().get("correct", true)) and bool(last_record().get("injured", false)),
		"she was pushed into it: an injury, 300, and not a right call")

	section("Report: the last visitor of the night came through the window")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == 950 and int(r.get("correct", 0)) == 3 and int(r.get("injuries", 0)) == 1, "950 at closing, three right calls, one injury")
	check(bool(r.get("died", false)) and str(r.get("title", "")) == "LIGHTS OUT" and not bool(r.get("line_held", true))
		and (r.get("unseen", []) as Array).is_empty(), "nobody was left to see, and it is still LIGHTS OUT: nobody reads the meter")
	var held: Array = []
	for item in r.get("readings", []):
		var one: Dictionary = item
		held.append(bool(one.get("held", false)))
	check(held == [false, true, true, true] and int(r.get("hours_under", 0)) == 1,
		"the meter: under, over, over (Trauma Team paid Vale's fee on account), over, and no reading for the hour she came through")


# ================================================================ shift 5

## The two ways a stop is told once the glass has nothing left to give: the shutter after the
## blow that takes the last of it, and the shutter on a patient who turns when there is none.
func shift_last_glass() -> void:
	section("Fifth shift")
	var opened: bool = await d.open_counter()
	check(opened, "a fifth shift starts")
	check(main.shift_number == 5 and main.shift.glass == 3 and not main.shift.glass_out and main.clinic.glass_state == 0,
		"with a new pane")

	section("Kip and Rook: treated at once")
	var v: VisitState = await enter("kip")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Kip")
	await finish_visit("Kip")
	v = await enter("rook")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "and for Rook")
	await finish_visit("Rook")
	check(not main.clinic.line_under and main.clinic.line == 360, "two hours in, the till is over the line")

	section("Vale: the shutter after the blow that takes the last of the glass")
	v = await enter("vale")
	await d.call_team()
	var warned: bool = await d.wait_for_telegraph()
	check(warned, "the call turns him")
	var struck: bool = await d.until(func() -> bool: return main._blows >= 3, 4.0)
	check(struck and main.state == MainScript.State.ATTACK and main.clinic.glass_state == 3,
		"all three blows land: the pane is cracked through, and he is not through it yet")
	check(main.shift.glass == 0 and main.clinic.glass_left == 0 and not main.shift.glass_out, "the last glass lamp is out")
	d.shutter_key()
	check(v.outcome == "caught" and v.shutter_grade() == "cracked" and v.blows_taken == 3, "the shutter still stops him")
	check(main.clinic.bar_on and main.clinic.bar_text == main.STOP_LAST_LINE, "the bar says what the stop cost")
	var dropped: bool = await d.until(func() -> bool: return main.shift.glass_out and main.clinic.glass_state == 4, 4.0)
	check(dropped, "behind the shutter the pane drops out of its frame")
	await finish_visit("Vale")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 600 and int(last_record().get("blows", 0)) == 3,
		"the call was right: the record keeps Trauma Team's fee, and the three blows")
	check(plan_is([], 650), "whoever turns next has only the time on the bar: 0.65 s")

	section("Juno: Trauma Team called on a steady patient")
	v = await enter("juno")
	await d.call_team()
	check(v.outcome == "referred_stable" and main.state != MainScript.State.ATTACK, "the call goes through, and she goes quietly")
	var came: bool = await d.until(func() -> bool: return main.clinic.team_in_sight(), 25.0)
	check(came and main.rig != null, "the crew comes for her anyway")
	await finish_visit("Juno")
	check(not bool(last_record().get("correct", true)) and int(last_record().get("credits", 0)) == -150 and int(last_record().get("counter", -1)) == 350
		and int(last_record().get("closing", 0)) == -500,
		"the wrong call: the crew pays her fee on account at the counter, and takes it back at closing with the call-out")
	check(str(last_record().get("title", "")) == "FALSE CALL", "the report will call it a false call")
	check(not main.clinic.team_in_sight() and main.clinic.strobe == 0.0, "the crew has left")

	section("Maren: stopped in time with no glass left")
	v = await enter("maren")
	await d.settle()
	await d.press()
	check(v.in_exam() and v.press_count == 1, "the first line gets a reaction")
	await d.settle()
	await d.press()
	check(main.state == MainScript.State.ATTACK and v.attack_cause == "press", "the second line turns her")
	warned = await d.wait_for_telegraph()
	check(warned and main.clinic.bar_on and main.clinic.bar_blows.is_empty() and is_equal_approx(main.clinic.bar_through, 0.65),
		"the bar has no mark on it: 0.65 s, and nothing for her to break first")
	d.shutter_key()
	check(v.outcome == "caught" and v.shutter_grade() == "clean" and v.blows_taken == 0, "the shutter is down before she is through")
	check(main.clinic.bar_on and main.clinic.bar_text == main.STOP_BARE_LINE, "the bar does not say that the glass held: there was none")
	var stops: Array = logged("shutter")
	var stop: Dictionary = stops[stops.size() - 1]
	check(str(stop.get("outcome", "")) == "caught" and str(stop.get("grade", "")) == "clean" and int(stop.get("glass_left", -1)) == 0,
		"the log has the stop: clean, with no glass left")
	await finish_visit("Maren")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 400 and int(last_record().get("counter", -1)) == 400,
		"a caught attack: Trauma Team pays her fee on account at the counter, and keeps it as the bounty at closing")
	check(main.clinic.glass_state == 4 and main.shift.glass_out, "the frame stays empty")

	section("Report: one wrong call, and the pane lost on the way")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == 1400 and int(r.get("correct", 0)) == 4 and int(r.get("injuries", -1)) == 0, "1400 at closing, four right calls, nobody hurt")
	check(bool(r.get("line_held", false)) and int(r.get("hours_under", -1)) == 0 and str(r.get("title", "")) == "A GOOD NIGHT'S WORK",
		"over the line every hour with one call wrong: A GOOD NIGHT'S WORK")
	check(tills_of(r) == [250, 550, 1150, 1500, 1400],
		"through the night the fees as they came in, Juno's too; at closing the crew took hers back and billed the call-out")
	check(int(r.get("glass", -1)) == 0 and int(r.get("glass_max", 0)) == 3, "and the report knows the glass is gone")


# ================================================================ shift 6

## The booth walls and the glass fitter. The papers and the big screen come down and go back
## on clicks and keys, cover what is behind them, step aside for a close-up and stay out of the
## way of a patient who has turned; and between patients the till buys the glass back, one
## layer at a time, even after the pane has dropped out of its frame.
func shift_walls_and_glass() -> void:
	section("Sixth shift: the walls, with nobody at the counter")
	var opened: bool = await d.open_counter()
	check(opened, "a sixth shift starts")
	check(main.shift_number == 6 and main.shift.glass == 3 and main.clinic.glass_state == 0, "with a new pane")
	check(not d.sheet_down() and not d.card_down() and not d.cam_on(), "and with everything back on the walls")
	check(main.desk.nudge.has("sheet") and not main._sheet_seen, "the reference sheet has not been down all session, and still asks to be looked at")
	check(not main.desk.is_enabled("glass") and not main.desk.badges.has("glass"), "the GLASS key is dark while the pane is whole")
	d.move(d.pad_pos("glass"))
	await process_frame
	await process_frame
	check(main._hover_hint == main.GLASS_WHOLE_HINT and main._cursor_kind == "point" and main.desk.hover == "",
		"pointing at it says there is nothing to mend")
	d.pad("glass")
	d.key(KEY_G)
	check(main.shift.repairs.is_empty() and main.shift.total() == 0 and logged("glass_repair").is_empty(), "and neither a click nor G buys anything")
	d.key(KEY_R)
	check(d.sheet_down() and bool(main.desk.taken.get("sheet", false)), "R takes the reference sheet down: its place on the wall is empty")
	check(main._sheet_seen and not main.desk.nudge.has("sheet"), "and it stops asking")
	d.key(KEY_N)
	check(d.card_down() and main.clipboard.mode == "blank", "N takes the intake card down: blank, with nobody at the counter")
	d.key(KEY_C)
	check(d.cam_on() and main.state == MainScript.State.WAIT, "C puts the hall on the big screen")
	d.key(KEY_ESCAPE)
	check(not d.cam_on() and d.card_down() and d.sheet_down(), "ESC puts things back one at a time: the big screen first")
	d.key(KEY_ESCAPE)
	check(not d.card_down() and d.sheet_down(), "then the card")
	d.key(KEY_ESCAPE)
	check(not d.sheet_down() and main.state == MainScript.State.WAIT and main.visit == null, "then the sheet, and nobody was let in by any of it")
	d.key(KEY_C)
	d.key(KEY_C)
	check(main.state == MainScript.State.ENTER and not d.cam_on(), "C on the lit screen buzzes them in, and the screen goes dark as the door opens")
	var arrived: bool = await d.until(func() -> bool: return main.state == MainScript.State.EXAM, 12.0)
	var v: VisitState = main.visit
	check(arrived and v != null and str(v.case_data.get("id", "")) == "kip", "kip comes to the counter")

	section("Kip: what hangs on the walls, and what it covers")
	await d.settle()
	var lit := 0
	for item in ["sheet", "list", "guide", "card"]:
		var id := str(item)
		d.move(main.desk.object_rect(id).get_center())
		await process_frame
		await process_frame
		if main.desk.hover == id and main._cursor_kind == "hand" and main._hover_hint == str(main.OBJECT_HINT[id]):
			lit += 1
		else:
			print("  '%s' on the wall: hover '%s', cursor '%s', hint '%s'" % [id, main.desk.hover, main._cursor_kind, main._hover_hint])
	check(lit == 4, "the sheet, the contact list, the booklet and the card each light up under the pointer and say what they are")
	var before: int = logged("panel").size()
	d.take_sheet()
	check(d.sheet_down() and bool(main.desk.taken.get("sheet", false)), "a click takes the sheet down")
	var panels: Array = logged("panel")
	var last: Dictionary = panels[panels.size() - 1]
	check(panels.size() == before + 1 and str(last.get("panel", "")) == "sheet" and bool(last.get("open", false)), "the log has it: the sheet, down")
	d.click(main.desk.object_rect("list").get_center())
	check(d.sheet_down() and not d.list_down(), "the sheet covers the contact list's place on the wall: a click on the paper is not passed on")
	d.take_card()
	d.click(main.desk.object_rect("guide").get_center())
	check(d.card_down() and not main.guide.is_open(), "the card covers the booklet behind it on the right wall")
	d.hang_card()
	d.key(KEY_C)
	check(d.cam_on() and main.state == MainScript.State.EXAM, "C looks into the hall while he stands there")
	var over: Rect2 = Gfx.CAM.intersection(Gfx.rect_to_screen(main.rig.zone_rect("hands")))
	var both: Vector2 = over.get_center()
	check(over.size.x > 0.0 and main._zone_at(both) == "hands" and main._panel_at(both) == "cam", "the big screen stands in front of part of his hands")
	d.move(both)
	await process_frame
	await process_frame
	check(main.clinic.monitor_hot and main._cursor_kind == "hand" and main._hover_hint == main.CAM_OFF_HINT, "there the pointer is on the screen, not on him")
	d.click(both)
	check(not d.cam_on() and not v.seen.has("look:hands"), "a click there switches the screen off and looks at nothing")
	d.click(both)
	await process_frame
	check(v.seen.has("look:hands"), "with the screen off, the same click is a look at his hands")
	await d.settle()
	d.move(main.clipboard.sheet_tab().get_center())
	await process_frame
	await process_frame
	check(main.clipboard.tab_hover == "sheet" and main._hover_hint == str(main.TAB_HINT["sheet"]), "the tab on the sheet's edge says it hangs the sheet back")
	d.hang_sheet()
	check(not d.sheet_down() and not bool(main.desk.taken.get("sheet", false)), "and a click on it does")
	d.take_card()
	check(d.card_down() and main._card_wanted, "a click takes the intake card down")
	d.move(Gfx.RECORD.get_center())
	d.right_click()
	check(not d.card_down() and not main._card_wanted, "the right button on a paper hangs it back")
	d.pad("treat")
	await process_frame
	check(main._held == "treat" and d.card_down() and not main._card_wanted, "with the stamp in hand the card comes down by itself")
	d.key(KEY_N)
	check(d.card_down(), "N cannot hang it back while the stamp needs it")
	d.hang_card()
	check(d.card_down() and main._held == "treat", "nor can its tab")
	d.right_click()
	check(main._held == "" and not d.card_down(), "putting the stamp back sends the card back to the wall with it")
	d.take_sheet()
	d.take_card()
	check(d.sheet_down() and d.card_down(), "both papers can be down at once")
	var status: String = await d.request_tool("penlight")
	check(status == "open", "the penlight close-up opens")
	check(not d.sheet_down() and not d.card_down() and main._sheet_back and main._card_back, "the papers step aside: a close-up has the whole window")
	await d.put_away()
	check(not main.clinic.scope.is_open() and d.sheet_down() and d.card_down(), "and they come back when the tool is put away")
	d.key(KEY_H)
	check(main.guide.is_open() and not d.sheet_down() and not d.card_down() and main._sheet_wanted and main._card_wanted,
		"the guide points at the walls, so the papers hang there while it is open")
	d.key(KEY_ESCAPE)
	check(not main.guide.is_open() and d.sheet_down() and d.card_down(), "and they are down again when it closes")
	d.hang_card()
	d.click(main.desk.object_rect("guide").get_center())
	check(main.guide.is_open() and main.guide.page == 0, "with the card back on the wall, a click on the booklet opens the guide")
	d.right_click()
	check(not main.guide.is_open(), "and the right button closes it")
	d.move(d.thumb_pos())
	await process_frame
	await process_frame
	check(main.clinic.thumb_hot and main._hover_hint == main.CAM_PEEK_HINT, "during a visit the small monitor offers a look at the hall")
	d.click(d.thumb_pos())
	await process_frame
	await process_frame
	check(d.cam_on() and main.state == MainScript.State.EXAM and main._hover_hint == main.CAM_OFF_HINT, "a click puts the hall on the big screen, and lets nobody in")
	d.key(KEY_C)
	check(not d.cam_on(), "C switches it off")
	d.take_sheet()
	d.hang_card()
	check(d.sheet_down() and not d.card_down(), "the sheet down, the card on the wall")
	await d.settle()
	await d.stamp("treat")
	check(v.outcome == "treated_ok" and d.card_down() and not main._card_wanted, "TREAT: the card came down for the stamp, and stays to show it")
	await finish_visit("Kip")
	check(not d.card_down() and d.sheet_down(), "with the slip taken, the card is back on the wall by itself and the sheet is where it was left")

	section("Rook: ENTER at the door")
	d.key(KEY_ENTER)
	check(main.state == MainScript.State.ENTER and not d.cam_on(), "ENTER buzzes them in without the big screen")
	arrived = await d.until(func() -> bool: return main.state == MainScript.State.EXAM, 12.0)
	v = main.visit
	check(arrived and v != null and str(v.case_data.get("id", "")) == "rook", "rook comes to the counter")
	check(d.sheet_down() and not d.card_down(), "the sheet is still down from the last patient")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Rook")
	await finish_visit("Rook")
	check(main.shift.till() == 550 and main.clinic.till == 550, "550 in the till")

	section("Vale: nothing hangs in front of a patient who has turned")
	v = await enter("vale")
	d.take_card()
	check(d.sheet_down() and d.card_down(), "both papers are down while he stands there")
	await d.call_team()
	await process_frame
	check(main.state == MainScript.State.ATTACK and not main._telegraphed and d.sheet_down() and d.card_down(),
		"the call turns him, and until he shows it the papers hang as they did: they give nothing away")
	var warned: bool = await d.wait_for_telegraph()
	await process_frame
	check(warned and main._panels_hold and not d.sheet_down() and not d.card_down() and not d.cam_on(),
		"the moment he shows it they are out of the way: the whole window is his")
	d.key(KEY_R)
	d.click(main.desk.object_rect("card").get_center())
	check(not d.sheet_down() and not d.card_down() and main._sheet_wanted, "and nothing comes down again while he is at the glass")
	var struck: bool = await d.until(func() -> bool: return main._blows >= 3, 4.0)
	check(struck and main.state == MainScript.State.ATTACK and main.shift.glass == 0, "all three blows land: the last glass lamp is out")
	d.shutter_key()
	check(v.outcome == "caught" and v.shutter_grade() == "cracked", "the shutter still stops him")
	var dropped: bool = await d.until(func() -> bool: return main.shift.glass_out and main.clinic.glass_state == 4, 4.0)
	check(dropped, "behind the shutter the pane drops out of its frame")
	var over_now: bool = await d.until(func() -> bool: return main.state == MainScript.State.SLIP, 40.0)
	check(over_now and d.sheet_down() and d.card_down(), "when it is over the sheet hangs where it was, and the card still holds the doctor's notes")
	await finish_visit("Vale")

	section("Between patients: the till buys the glass back")
	await process_frame
	check(main.shift.glass == 0 and main.shift.glass_out and main.clinic.glass_state == 4 and plan_is([], 650),
		"the frame is empty: whoever turns next has only the time on the bar")
	var meters: Array = logged("meter")
	var reading: Dictionary = meters[meters.size() - 1]
	check(int(reading.get("hour", 0)) == 3 and int(reading.get("till", 0)) == 1150 and bool(reading.get("held", false)) and main.shift.till() == 1150,
		"the meter read the third hour before anything was bought: 1150, with Trauma Team's fee for Vale")
	check(main.desk.is_enabled("glass") and str(main.desk.badges.get("glass", "")) == "-40", "the GLASS key is lit, and shows its price")
	d.move(d.pad_pos("glass"))
	await process_frame
	await process_frame
	check(main.desk.hover == "glass" and main._cursor_kind == "hand" and main._hover_hint == Lang.tf(main.GLASS_HINT, 40),
		"pointing at it says what a layer costs and what it buys")
	d.pad("glass")
	check(main.shift.glass == 1 and not main.shift.glass_out and main.clinic.glass_left == 1, "a click buys one layer: there is a pane in the frame again")
	check(main.clinic.glass_state == 2, "it shows the cracks of the two layers still missing")
	check(main.shift.till() == 1110 and main.clinic.till == 1110, "40 credits are off the till")
	check(plan_is([540], 990), "and the next patient who turns has to break it first: 0.99 s")
	check(main.dialogue.speaker == "GLASS" and strip_says(main.dialogue, Lang.tf(main.GLASS_LINE, [40, 1, 3])), "the strip says what was done and what it cost")
	d.key(KEY_G)
	check(main.shift.glass == 2 and main.clinic.glass_state == 1 and main.shift.till() == 1070 and plan_is([540, 990], 1440),
		"G buys the next one at once: two layers, 1070 in the till, 1.44 s")
	var bought: Array = logged("glass_repair")
	check(bought.size() == 2 and int(bought[1].get("cost", 0)) == 40 and int(bought[1].get("glass_left", 0)) == 2
		and int(bought[1].get("glass_max", 0)) == 3 and int(bought[1].get("till", 0)) == 1070, "both are logged, with the price and what is left")
	check(int(main.shift.reading(3).get("till", 0)) == 1150, "the reading already taken for the third hour does not change")
	check(main.desk.is_enabled("glass") and str(main.desk.badges.get("glass", "")) == "-40", "one layer is still missing, and the key stays lit")
	var hall: bool = await d.until(func() -> bool: return main.dialogue.speaker == "HALL CAMERA", 12.0)
	check(hall and main.state == MainScript.State.WAIT and main.clinic.cam_prompt, "then the strip goes back to who is waiting in the hall")
	check(main.clinic.decal_count() == 0, "the fitter's arm wiped the pane as it went")

	section("Juno: the fitter does not come while somebody is at the counter")
	v = await enter("juno")
	await process_frame
	check(not main.desk.is_enabled("glass") and not main.desk.badges.has("glass"), "the GLASS key is dark during a visit")
	d.move(d.pad_pos("glass"))
	await process_frame
	await process_frame
	check(main._hover_hint == main.GLASS_BUSY_HINT and main.desk.hover == "", "pointing at it says why")
	d.pad("glass")
	d.key(KEY_G)
	check(main.shift.glass == 2 and main.shift.till() == 1070 and logged("glass_repair").size() == 2, "and neither a click nor G buys anything now")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Juno")
	await finish_visit("Juno")
	check(main.shift.till() == 1420, "her fee on top of what the glass cost: 1420 in the till")

	section("Between patients again: the last layer")
	meters = logged("meter")
	reading = meters[meters.size() - 1]
	check(int(reading.get("hour", 0)) == 4 and int(reading.get("till", 0)) == 1420 and int(reading.get("line", 0)) == 480 and bool(reading.get("held", false)),
		"the fourth reading counts what the glass cost: 1420 against 480, still over the line")
	d.key(KEY_G)
	check(main.shift.glass == 3 and main.clinic.glass_left == 3 and main.clinic.glass_state == 0 and main.shift.till() == 1380,
		"G buys the third layer: the pane is whole again, 1380 in the till")
	check(plan_is([540, 990, 1440], 1800), "and it gives all of its time back: 1.8 s")
	check(not main.desk.is_enabled("glass") and not main.desk.badges.has("glass") and main._glass_hint() == main.GLASS_WHOLE_HINT,
		"nothing is left to mend, and the key goes dark")
	d.key(KEY_G)
	d.pad("glass")
	check(main.shift.repairs.size() == 3 and main.shift.till() == 1380, "more glass than the frame holds cannot be bought")

	section("Maren: the mended glass gives the whole bar back")
	v = await enter("maren")
	await d.settle()
	await d.press()
	check(v.in_exam() and v.press_count == 1, "the first line gets a reaction")
	await d.settle()
	await d.press()
	check(main.state == MainScript.State.ATTACK and v.attack_cause == "press", "the second line turns her")
	warned = await d.wait_for_telegraph()
	check(warned and main.clinic.bar_on and main.clinic.bar_blows.size() == 3 and is_equal_approx(main.clinic.bar_through, 1.8),
		"the bar has all three marks again: 1.8 s")
	d.shutter_key()
	check(v.outcome == "caught" and v.shutter_grade() == "clean" and v.blows_taken == 0 and main.shift.glass == 3, "stopped clean: the new glass is untouched")
	check(main.clinic.bar_on and main.clinic.bar_text == main.STOP_CLEAN_LINE, "and the bar says the glass holds")
	await finish_visit("Maren")

	section("Report: what the glass cost is on the bill")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == 1780 and int(r.get("correct", 0)) == 5 and int(r.get("injuries", -1)) == 0, "1780 in the till, five right calls, nobody hurt")
	check(int(r.get("repairs", 0)) == 3 and int(r.get("repair_total", 0)) == 120, "three layers of glass: 120 credits")
	check(int(r.get("glass", -1)) == 3 and int(r.get("glass_max", 0)) == 3, "and the pane is whole at closing")
	check(bool(r.get("line_held", false)) and int(r.get("hours_under", -1)) == 0 and str(r.get("title", "")) == "STEADY HANDS",
		"over the line every hour, glass and all: STEADY HANDS")
	var tills: Array = []
	for item in r.get("readings", []):
		var one: Dictionary = item
		tills.append(int(one.get("till", 0)))
	check(tills == [250, 550, 1150, 1420, 1780], "hour by hour, the meter counted the glass from the hour it was paid in")
	var ends: Array = logged("shift_end")
	var end: Dictionary = ends[ends.size() - 1]
	check(int(end.get("glass_paid", 0)) == 120 and int(end.get("glass_left", 0)) == 3 and int(end.get("total", 0)) == 1780,
		"the log's last line of the night says what was paid for glass")


# ================================================================ shift 7

## The night as it is played: two couriers on tonight's list, a CALM that costs credits, and the
## line of 400 an hour. The seed is picked so that Kip and Maren are the two on the list.
func shift_couriers() -> void:
	section("Seventh shift: tonight's contact list")
	var picked := seed_for(["kip", "maren"])
	check(picked > 0, "a night can be drawn with Kip and Maren on the list")
	main.fixed_seed = picked
	main.has_fixed_seed = true
	var opened: bool = await d.open_counter()
	main.has_fixed_seed = false
	check(opened and main.shift_number == 7, "a seventh shift starts")
	var kip_id := ""
	var maren_id := ""
	var maren_alias := ""
	for e in main.shift.contacts:
		var entry: Dictionary = e
		match str(entry.get("case", "")):
			"kip":
				kip_id = str(entry.get("id", ""))
			"maren":
				maren_id = str(entry.get("id", ""))
				maren_alias = str(entry.get("alias", ""))
	check(main.shift.contacts.size() == 2 and main.clipboard.contacts.size() == 2 and kip_id != "" and maren_id != "",
		"two couriers are on tonight's list, Kip's entry and Maren's, and the list on the wall has both")
	check(main.clinic.line == 400 and main.shift.line_per_hour() == 400, "the meter wants 400 an hour")
	check(main._shift_line() == Lang.tf(main.SHIFT_LIST_LINE, [5, 2, 400]), "the night opens by saying how many visitors are on the list")
	var lists: Array = logged("contacts")
	var listed: Dictionary = lists[lists.size() - 1]
	check(int(listed.get("entries", 0)) == 2 and (listed.get("ids", []) as Array).has(kip_id) and not bool(listed.get("training", true)),
		"the log has tonight's list by its entry ids, on a night with no training")
	await process_frame
	check(main.desk.nudge.has("list") and not main._list_seen, "the list asks to be looked at")

	section("Kip: the list, a wrong code, the right one, and a CALM that costs")
	var v: VisitState = await enter("kip")
	check(v.is_contact() and str(v.contact.get("id", "")) == kip_id, "Kip is tonight's courier SPARROW or PAPER CRANE")
	check(not v.surprises, "the surprises are still held for this night")
	await d.settle()
	var before: int = logged("panel").size()
	d.key(KEY_L)
	check(d.list_down() and bool(main.desk.taken.get("list", false)) and main._list_seen and not main.desk.nudge.has("list"),
		"L takes the list down: its place on the wall is empty, and it stops asking")
	var panels: Array = logged("panel")
	var last: Dictionary = panels[panels.size() - 1]
	check(panels.size() == before + 1 and str(last.get("panel", "")) == "list" and bool(last.get("open", false)), "the log has it: the list, down")
	d.move(main.clipboard.swap_tab().get_center())
	await process_frame
	await process_frame
	check(main.clipboard.tab_hover == "swap" and main._hover_hint == main.SWAP_SHEET_HINT, "the tab under the list's own offers the sheet")
	d.swap()
	check(d.sheet_down() and not d.list_down(), "a click on it brings the sheet down and puts the list back on the hook")
	await process_frame
	await process_frame
	check(main.clipboard.tab_hover == "swap" and main._hover_hint == main.SWAP_LIST_HINT, "under the sheet the same tab offers the list")
	d.swap()
	check(d.list_down() and not d.sheet_down(), "and a click trades them back")
	await d.until(func() -> bool: return main.clipboard._list_k >= 1.0, 3.0)
	d.move(d.say_pos(maren_id))
	await process_frame
	await process_frame
	check(main.clipboard.say_hover == maren_id and main._hover_hint == Lang.tf(main.SAY_CODE_HINT, 1), "the SAY button beside an entry says what a code does")
	var codes_before: int = logged("code").size()
	await d.say_code(maren_id)
	var codes: Array = logged("code")
	check(codes.size() == codes_before + 1 and str(codes[codes.size() - 1].get("result", "")) == "blank", "the log has the code: a blank")
	check(v.patience == v.patience_max - 1 and v.codes_wrong == 1 and not v.dropped and v.in_exam(), "Maren's code to Kip: a blank look, one patience")
	check(main._base_hint == Lang.tf(main.CODE_BLANK_HINT, 1), "the hint says a wrong code says nothing about the patient")
	await d.settle()
	d.click(d.say_pos(maren_id))
	await process_frame
	check(logged("code").size() == codes_before + 1 and v.patience == v.patience_max - 1, "the same code again does nothing: it was tried")
	await d.say_code(kip_id)
	codes = logged("code")
	check(str(codes[codes.size() - 1].get("result", "")) == "drop" and v.dropped and v.drop_pay == 300 and main.clinic.till == 300,
		"his own code: he answers it, and the drop puts 300 in the till before anything is decided")
	check(v.patience == v.patience_max - 1, "the right code is free")
	var shown: bool = await d.until(func() -> bool: return main.dialogue.speaker == "PACKAGE" and main._coached.has("drop"), 8.0)
	check(shown and main._base_hint == main.DROP_COACH_HINT, "the strip says what came over the counter, and a tip says it changes nothing about the exam")
	check(main.clipboard.entry_mark(kip_id) == "picked" and not main.clipboard.can_say(maren_id), "his entry is ticked off, and no more codes are said this visit")
	await d.settle()
	check(str(main.desk.badges.get("calm", "")) == Lang.tf("%dcr", [30]) and main._pad_hint("calm") == Lang.tf(main.CALM_HINT, [30, 1, 2]),
		"the CALM pad shows its price: a calm-patch is 30 credits")
	await d.reassure()
	var calms: Array = logged("reassure")
	check(v.patience == v.patience_max and v.calm_spent == 30 and main.clinic.till == 270, "CALM gives the lamp back, and takes 30 off the till")
	check(int(calms[calms.size() - 1].get("cost", 0)) == 30 and int(calms[calms.size() - 1].get("calm_spent", 0)) == 30, "the log has what it cost")
	await d.settle()
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Kip")
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed, "Kip: the result slip prints")
	var s: Dictionary = main._slip_data
	check(int(s.get("outcome_credits", 0)) == 250 and int(s.get("credits", 0)) == 520, "the call earns the fee; with the drop and less the patch, 520")
	check(main._slip_breakdown(s) == Lang.tf(main.SLIP_DROP, 300) + "  •  " + Lang.tf(main.SLIP_CALM, 30), "under the call the slip says what the drop brought and what CALM cost")
	check(main.clinic.till == main.shift.till() and main.shift.till() == 520, "the till matches: 520")
	var moved: bool = await d.take_slip()
	check(moved and main.clipboard.entry_mark(kip_id) == "picked", "Kip: taking the slip moves on, and his entry stays ticked off")

	section("Rook, Vale and Juno: nobody else on the list")
	v = await enter("rook")
	check(not v.is_contact(), "Rook is not on the list")
	await d.stamp("treat")
	await finish_visit("Rook")
	check(main.shift.till() == 820, "820 in the till")
	v = await enter("vale")
	await d.call_team()
	var warned: bool = await d.wait_for_telegraph()
	d.shutter_key()
	check(warned and v.outcome == "caught", "the call turns Vale, and the shutter stops him")
	await finish_visit("Vale")
	v = await enter("juno")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Juno")
	await finish_visit("Juno")
	check(main.shift.till() == 1770 and main.shift.total() == 1770,
		"1770 in the till, Trauma Team's fee for Vale on account; its report at closing will keep it")

	section("Maren: a courier who goes without her package")
	v = await enter("maren")
	check(v.is_contact() and str(v.contact.get("id", "")) == maren_id, "Maren is the other courier")
	await d.call_team()
	check(v.outcome == "referred_drifting", "the call hands her over without a fight")
	printed = await d.wait_for_slip(40.0)
	check(printed and main._slip_breakdown(main._slip_data) == Lang.tf(main.SLIP_NO_DROP, maren_alias), "the slip says her package never came over the counter")
	moved = await d.take_slip()
	check(moved and main.clipboard.entry_mark(maren_id) == "missed", "her entry is marked missed")

	section("Report: the drops are on the bill")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == 2170 and int(r.get("correct", 0)) == 5 and bool(r.get("line_held", false)) and str(r.get("title", "")) == "STEADY HANDS",
		"five right calls and one drop: 2170, over 400 an hour, STEADY HANDS")
	check(int(r.get("contacts", 0)) == 2 and int(r.get("drops", 0)) == 1 and int(r.get("drop_total", 0)) == 300 and int(r.get("calm_total", 0)) == 30,
		"one drop of the two on the list, and one calm-patch")
	var ends: Array = logged("shift_end")
	var end: Dictionary = ends[ends.size() - 1]
	check(int(end.get("drops", 0)) == 1 and int(end.get("drop_total", 0)) == 300 and int(end.get("calm_total", 0)) == 30, "the log's last line of the night has them too")


# ================================================================ shift 8

## The surprises: a flare (anybody, once a visit) and a snap (the drifting only). The rules are
## pinned for a moment so that each comes on cue; the rest of the night is as it is played.
func shift_surprises() -> void:
	section("Eighth shift: a flare and a snap")
	var from: int = main.event_log.memory.size()
	var opened: bool = await d.open_counter()
	check(opened and main.shift_number == 8, "an eighth shift starts")

	section("Kip: a flare knocks the light out of the doctor's hand, and the exam goes on")
	var v: VisitState = await enter("kip")
	check(v.surprises, "surprises are on tonight")
	await d.settle()
	var was: Dictionary = pin_rules({"flare": {"grace": 0, "chance": 1.0}})
	var temper: int = note_count(v, "temper")
	var status: String = await d.request_tool("penlight")
	check(status == "open", "the penlight close-up opens")
	var flared: bool = await d.until(func() -> bool: return v.flared, 5.0)
	restore_rules(was)
	var dues: Array = logged_since("surprise_due", from)
	check(flared and dues.size() == 1 and str(dues[0].get("kind", "")) == "flare" and logged_since("flare", from).size() == 1,
		"a flare comes up after the test, and comes a moment later; the log has both")
	await process_frame
	check(not main.clinic.scope.is_open() and main.desk.active == "", "the close-up is knocked out of the doctor's hand")
	check(main.state == MainScript.State.EXAM and v.in_exam() and not main._telegraphed and not main.clinic.bar_on, "it is not an attack: no red bar, and the exam goes on")
	check(note_count(v, "temper") == temper + 1, "it goes on the TEMPER line")
	var tip: bool = await d.until(func() -> bool: return main._coached.has("flare") and main._base_hint == main.FLARE_COACH_HINT, 6.0)
	check(tip, "the first flare of a session brings the tip: only the red bar needs the shutter")
	await d.settle()
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is still right for Kip")
	await finish_visit("Kip")

	section("Rook: TREAT")
	v = await enter("rook")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Rook")
	await finish_visit("Rook")

	section("Vale: he snaps in the middle of a test")
	v = await enter("vale")
	await d.settle()
	was = pin_rules({"flare": {"chance": 0.0}})
	status = await d.request_tool("penlight")
	check(status == "refused" and v.in_exam() and main.state == MainScript.State.EXAM, "he gives a reason instead of following the light, and does not snap yet")
	var snap_was: Dictionary = pin_rules({"snap": {"grace": 0, "step": 1.0, "max": 1.0}})
	status = await d.request_tool("penlight")
	check(status == "open", "insisting opens the test")
	var turned: bool = await d.until(func() -> bool: return main.state == MainScript.State.ATTACK, 5.0)
	restore_rules(snap_was)
	restore_rules(was)
	check(turned and v.attack_cause == "snap" and v.snapped, "a moment later he turns on the doctor: a snap")
	check(not main.clinic.scope.is_open() and main._panels_hold, "the close-up is knocked away, and nothing hangs in front of him")
	check(logged_since("snap", from).size() == 1, "the log has the snap")
	var warned: bool = await d.wait_for_telegraph()
	check(warned and main.clinic.bar_on, "the red bar comes up, as for any attack")
	d.shutter_key()
	check(v.outcome == "caught", "the shutter stops him")
	await finish_visit("Vale")
	check(bool(last_record().get("correct", false)) and int(last_record().get("credits", 0)) == 600 and bool(last_record().get("snapped", false)),
		"stopped after a snap: a right call, with Trauma Team's fee")

	section("Juno and Maren: two treatments that look the same at the counter")
	v = await enter("juno")
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Juno")
	await finish_visit("Juno")
	v = await enter("maren")
	await d.stamp("treat")
	check(v.outcome == "treated_drifting", "TREAT on Maren, who is drifting: the work goes ahead")
	var printed: bool = await d.wait_for_slip(40.0)
	var juno: Dictionary = main.shift.records[3]
	var slip: Dictionary = main._slip_data
	check(printed and str(slip.get("counter_title", "")) == str(juno.get("counter_title", "-"))
		and str(slip.get("counter_text", "")) == str(juno.get("counter_text", "-")) and str(slip.get("call", "")) == str(juno.get("call", "-")),
		"Maren's slip says what Juno's said: a treatment and its fee, nothing about how it will hold")
	check(int(slip.get("counter", 0)) == 400 and main.shift.till() == 1900 and main.clinic.till == 1900, "her fee is in the till: 1900")
	await finish_visit("Maren")

	section("Report: what the night's reports took back")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == 1100 and main.clinic.till == 1100 and int(r.get("correct", 0)) == 4,
		"Maren's treatment failed: her fee and the bill, 800, come off at closing, and 1100 is left")
	check(not bool(r.get("line_held", true)) and int(r.get("hours_under", 0)) == 5 and str(r.get("title", "")) == "THE CUT",
		"with no drop the fees trail 400 an hour all night, and the bill leaves 1100 under the line of 2000: THE CUT")
	check(tills_of(r) == [250, 550, 1150, 1500, 1100], "the meter: 250, 550, 1150 and 1500 through the night, 1100 once the reports were in")
	var missed := 0
	for e in main.shift.contacts:
		if main.clipboard.entry_mark(str((e as Dictionary).get("id", ""))) == "missed":
			missed += 1
	check(int(r.get("drops", -1)) == 0 and int(r.get("contacts", 0)) == 2 and missed == 2, "neither courier's package came over the counter")


# ================================================================ shift 9

## The first night of a session as a new player has it: the training box. The session's first
## night ran with it switched off, so it runs here, on the ninth.
func shift_training() -> void:
	section("Ninth shift: the first-night training")
	var from: int = main.event_log.memory.size()
	var opened: bool = await d.open_counter()
	check(opened and main.shift_number == 9, "a ninth shift starts")
	var trainings: Array = logged_since("training", from)
	check(trainings.size() == 1 and int(trainings[0].get("tips", 0)) == 14 and main.coach.count() == 14, "the training starts with the night: fourteen tips")
	var lists: Array = logged_since("contacts", from)
	var kip_id := ""
	for e in main.shift.contacts:
		if str((e as Dictionary).get("case", "")) == "kip":
			kip_id = str((e as Dictionary).get("id", ""))
	check(lists.size() == 1 and bool(lists[0].get("training", false)) and kip_id != "",
		"on a training night the first visitor is on the list, so the code comes up on the first exam")
	await process_frame
	await process_frame
	check(main.coach.is_running() and main.coach.is_showing() and main.coach.current() == "list", "the first tip is up: tonight's list")
	d.key(KEY_L)
	check(d.list_down() and main.coach.current() == "clues", "L takes it down, and the next tip says how to read it")
	await process_frame
	await process_frame
	d.move(main.coach.next_rect().get_center())
	await process_frame
	await process_frame
	check(main.coach.hover == "next" and main._hover_hint == main.TRAINING_NEXT_HINT, "the NEXT button says what it does")
	d.click(main.coach.next_rect().get_center())
	check(main.coach.current() == "buzz", "NEXT moves on: the hall camera")
	var v: VisitState = await enter("kip")
	check(main.coach.current() == "card", "buzzing Kip in ends that tip; the next is about his intake card")
	check(not v.surprises and main._training_visit, "on the training visit nobody snaps or flares")
	check(logged_since("guide", from).is_empty(), "and the guide does not open by itself: the tips stand in for it")
	var starts: Array = logged_since("visit_start", from)
	check(starts.size() == 1 and bool(starts[0].get("training", false)) and bool(starts[0].get("contact", false)), "the log says this is the training visit, and a courier's")
	await d.settle()
	d.key(KEY_N)
	check(d.card_down() and main.coach.current() == "code", "N takes the card down: next, the code")
	var dues: int = logged_since("surprise_due", from).size()
	var was: Dictionary = pin_rules({"flare": {"grace": 0, "chance": 1.0}})
	# the drop's own one-time tip was seen on the seventh night; it is put back for a moment to
	# see that the training, which has a tip of its own for it, keeps it off the hint row
	main._coached.erase("drop")
	await d.say_code(kip_id)
	check(v.dropped and main.coach.current() == "drop", "the right code: the package, and a tip about what it means")
	await d.settle()
	await d.seconds(1.0)
	check(logged_since("surprise_due", from).size() == dues and not v.flared, "with a flare due on every action, still nobody flares on the training visit")
	check(not main._coached.has("drop") and main._base_hint != main.DROP_COACH_HINT, "the drop's one-time tip stays off the hint row while the training explains it")
	main._coached["drop"] = true
	restore_rules(was)
	d.click(main.coach.next_rect().get_center())
	check(main.coach.current() == "sheet", "NEXT: on to the exam, and the reference sheet")
	d.take_sheet()
	check(d.sheet_down() and not d.list_down() and main.coach.current() == "light", "the swap tab brings the sheet down where the list was; next, the penlight")
	var status: String = await d.request_tool("penlight")
	await process_frame
	await process_frame
	check(status == "open", "the penlight opens")
	check(not main.coach.is_showing() and main.coach.is_running() and main.coach.current() == "light", "the tips step aside while a close-up is open")
	var done: bool = await d.sweep_eyes()
	check(done and main.coach.current() == "grip", "using the light ends its tip: next, the grip")
	await d.put_away()
	status = await d.request_tool("grip")
	check(status == "open", "the grip bar opens")
	done = await d.squeeze_and_release()
	check(done and main.coach.current() == "port", "next, the port")
	status = await d.request_tool("port")
	done = await d.watch_port()
	check(status == "open" and done and main.coach.current() == "talk", "next, talking")
	await d.put_away()
	await process_frame
	await process_frame
	check(main.coach.is_showing() and main.coach.area() == "talk", "with the tool away, the tip about talking is up")
	d.click(main.coach.next_rect().get_center())
	check(main.coach.current() == "marks", "NEXT: the marks")
	d.mark("eyes")
	check(int(v.marks.get("eyes", 0)) == 1 and main.coach.current() == "decide", "a tick: next, the decision")
	await d.settle()
	await d.stamp("treat")
	check(v.outcome == "treated_ok" and main.coach.current() == "after", "TREAT: the last tip waits for the slip")
	var printed: bool = await d.wait_for_slip(40.0)
	check(printed and main.coach.is_showing() and main.coach.current() == "after", "with the slip, the last tip: what can happen from now on")
	var moved: bool = await d.take_slip()
	check(moved and main.coach.is_running() and main.coach.current() == "after", "taking the slip at once leaves it up while the next one waits")
	var waiting: bool = await d.until(func() -> bool: return main.state == MainScript.State.WAIT, 12.0)
	await process_frame
	await process_frame
	if not (d.sheet_down() and d.card_down()):
		print("    (note: sheet down %s, card down %s between patients)" % [d.sheet_down(), d.card_down()])
	check(waiting and main.coach.is_showing() and not main.coach.box().intersects(Gfx.CAM),
		"between patients the box keeps clear of where the hall camera opens, whatever is down from the walls")

	section("Rook: after the training")
	v = await enter("rook")
	var ends: Array = logged_since("training_end", from)
	check(not main.coach.is_running() and ends.size() == 1 and not bool(ends[0].get("skipped", true)) and int(ends[0].get("reached", 0)) == 13,
		"buzzing the second visitor in ends the training, at its last tip, not skipped")
	check(v.surprises and not main._training_visit, "from the second visitor on the counter is the real one: surprises are back")
	# started again by hand, only to try its two ways out
	main.coach.start()
	await process_frame
	await process_frame
	check(main.coach.is_showing(), "(started again by hand) the box is up")
	d.key(KEY_K)
	ends = logged_since("training_end", from)
	check(not main.coach.is_running() and ends.size() == 2 and bool(ends[1].get("skipped", false)), "K ends it, as skipped")
	main.coach.start()
	await process_frame
	await process_frame
	d.move(main.coach.skip_rect().get_center())
	await process_frame
	await process_frame
	check(main.coach.hover == "skip" and main._hover_hint == main.TRAINING_SKIP_HINT, "the SKIP ALL button says what it does")
	d.click(main.coach.skip_rect().get_center())
	ends = logged_since("training_end", from)
	check(not main.coach.is_running() and ends.size() == 3 and bool(ends[2].get("skipped", false)), "and a click on it ends the training too")
	d.key(KEY_K)
	check(logged_since("training_end", from).size() == 3 and v.in_exam(), "K with no training running does nothing")
	await d.settle()
	await d.stamp("treat")
	check(v.outcome == "treated_ok", "TREAT is right for Rook")
	await finish_visit("Rook")

	section("Vale, Juno and Maren")
	v = await enter("vale")
	await d.call_team()
	var warned: bool = await d.wait_for_telegraph()
	d.shutter_key()
	check(warned and v.outcome == "caught", "the call turns Vale, and the shutter stops him")
	await finish_visit("Vale")
	v = await enter("juno")
	await d.stamp("treat")
	await finish_visit("Juno")
	v = await enter("maren")
	await d.call_team()
	check(v.outcome == "referred_drifting", "the call hands Maren over")
	await finish_visit("Maren")
	check(main.state == MainScript.State.REPORT, "the report is up")
	var r: Dictionary = main.screens.report
	check(int(r.get("total", 0)) == 2200 and bool(r.get("line_held", false)) and str(r.get("title", "")) == "STEADY HANDS" and int(r.get("drops", 0)) == 1,
		"the training night: five right calls and Kip's drop, 2200, STEADY HANDS")


# ================================================================ the doctor's own words

## Kip, offline: the typing line, its keys, and what the scripted patient makes of a sentence.
func typing_line(v: VisitState) -> void:
	section("Kip: typing a line of your own (offline patient)")
	await d.settle()
	var box = main.dialogue
	await process_frame
	check(box.chips.size() == 1 and not box.chips_dim, "the TYPE button is on the strip during an exam")
	var chip: Rect2 = box.chip_rect("type")
	check(chip.size.x > 0.0 and Gfx.DIALOGUE.encloses(chip), "the button sits inside the strip")
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
	d.key(KEY_UNKNOWN, 0x1F600)
	d.key(KEY_UNKNOWN, 0x0E01)
	d.key(KEY_SHIFT)
	d.key(KEY_F5)
	check(box.input_text == "Sleep", "keys no font here can draw type nothing")
	# what an input method hands over: no key, one character each, drawn by the Chinese font
	d.key(KEY_NONE, 0x4E2D)
	d.key(KEY_NONE, 0xFF1F)
	check(box.input_text == "Sleep中？" and box.input_caret == 7, "characters an input method hands over are typed")
	box.input_compose("wen", 1)
	await d.seconds(0.05)
	check(box.input_text == "Sleep中？" and box.input_ime == "wen", "what it is still putting together is shown, not typed")
	var foot: Vector2 = box.caret_point()
	check(foot.y >= box.TEXT_Y + box.TEXT_PITCH and foot.x > box.TEXT_X + 20.0, "its list of candidates opens under the caret")
	box.input_compose("", 0)
	d.key(KEY_BACKSPACE)
	d.key(KEY_BACKSPACE)
	check(box.input_text == "Sleep" and box.input_ime == "", "and they are taken back like letters")
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
	check(dodged and strip_says(box, "Uh. Can we skip that one?"), "small talk gets his own way of declining")
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
	# a spoken line too long for the strip turns its pages, by itself and by a click. The line is
	# made up here, in the run's language: Chinese breaks between characters, with no space lost.
	var sentence: String = "一二三四五六七八九十。" if Lang.code == "zh" else "One two three four five six seven eight nine ten."
	var gap: String = "" if Lang.code == "zh" else " "
	var long_line: String = sentence
	while Gfx.wrap_text(long_line, box.TEXT_W).size() <= 2 * box.PAGE_LINES:      # three pages or more
		long_line += gap + sentence
	var quiet_spot := Gfx.DIALOGUE.position + Vector2(200, 38)      # on the strip, on nothing that can be pressed
	main._patient_line(long_line, main._begin_action(), 0.0)
	await process_frame
	check(box.lines.size() > 2 * box.PAGE_LINES and box.more and box.typing, "a line too long for the strip is paged")
	check(gap.join(box.lines) == long_line, "and no word of it is lost in the breaking")
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
		var text := Lang.t(str(h))
		if text != "" and Gfx.printable(text) == text and Gfx.text_w_raw(text) <= main.dialogue.TEXT_W:
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
	check(other.contains("http_502") and not other.contains("provider_error"), "any other failure shows its short code")
	check(Gfx.text_w(main.screens.HELP) <= 620.0 and Gfx.text_w(main.screens.HELP_VOICE) <= 620.0, "both title help lines fit the screen")
	var speak_w: float = Gfx.text_w("TAB", true) + Gfx.text_w("SPEAK") + 11.0
	var type_w: float = Gfx.text_w("T", true) + Gfx.text_w("TYPE") + 11.0
	check(speak_w + type_w + 8.0 < 120.0, "the SPEAK and TYPE buttons leave the strip to the patient's words")
	check(main.SPEAK_CHIPS.size() == 2 and str(main.SPEAK_CHIPS[1].id) == "type", "TYPE stays where it was when SPEAK joins it")


# ================================================================ the counter's own words

## Everything the line, the patience wait, the marks, the glass and the guide can put on the
## hint row, the bar over the printer slot, the title card and the two overlays fits where it
## is drawn.
func counter_words() -> void:
	section("The counter's words fit where they are drawn")
	var hints: Array = [main.FIRST_HINT, main.SHORT_HINT, main.LEAVING_HINT, main.LEAVING_LAST_HINT, main.NOTE_COACH_HINT,
		main.NOTE_OPEN_COACH_HINT, main.LAMP_COACH_HINT, main.GLASS_COACH_HINT, main.WAIT_HINT, main.CAM_HINT, main.CAM_PEEK_HINT,
		main.CAM_OFF_HINT, main.THINK_HINT, Lang.tf(main.GLASS_HINT, 40), Lang.tf(main.GLASS_HINT, 999), main.GLASS_BUSY_HINT, main.GLASS_WHOLE_HINT,
		main.GLASS_OFF_HINT, Lang.tf(main.CROSS_SOME_HINT, [1, 2]), Lang.tf(main.CROSS_SOME_HINT, [4, 5]), Lang.tf(main.CROSS_RULE_HINT, 2), Lang.tf(main.CROSS_RULE_HINT, 5)]
	hints.append_array(main.OBJECT_HINT.values())
	hints.append_array(main.TAB_HINT.values())
	# tonight's list, the paid CALM, the surprises and the training
	hints.append_array([main.LEAVING_FREE_HINT, Lang.tf(main.CALM_HINT, [30, 1, 2]), Lang.tf(main.CALM_HOLD_HINT, [30, 1, 2]), main.CALM_GONE_HINT,
		Lang.tf(main.CALM_FREE_HINT, [1, 2]), Lang.tf(main.CALM_FREE_HOLD_HINT, [1, 2]), Lang.tf(main.SAY_CODE_HINT, 1), Lang.tf(main.CODE_BLANK_HINT, 1),
		main.DROP_COACH_HINT, main.FLARE_COACH_HINT, main.TRAINING_SKIP_HINT, main.TRAINING_NEXT_HINT, main.SWAP_LIST_HINT,
		main.SWAP_SHEET_HINT])
	var fits := 0
	for h in hints:
		var text := Lang.t(str(h))
		if text != "" and Gfx.printable(text) == text and Gfx.text_w_raw(text) <= main.dialogue.TEXT_W:
			fits += 1
		else:
			print("  too wide or unprintable: ", text)
	check(fits == hints.size() and fits >= 43, "all %d hints about patience, marks, the walls, the list, CALM and the training fit the hint row" % hints.size())
	var plates: Array = [main.STOP_CLEAN_LINE, main.STOP_BARE_LINE, main.STOP_LAST_LINE, Lang.tf(main.STOP_BLOW_LINE, 1), Lang.tf(main.STOP_BLOWS_LINE, 2),
		Lang.tf(main.STOP_BLOWS_LINE, 3)]
	fits = 0
	for p in plates:
		var text := Lang.t(str(p))
		if Gfx.printable(text) == text and Gfx.text_w_raw(text, true) <= main.clinic.SLOT.size.x - 4.0:
			fits += 1
		else:
			print("  too wide for the bar: ", text)
	check(fits == plates.size(), "every way a stop can be told fits the bar over the printer slot")
	var title: Array = [main.STATUS_AI_VOICE, main.STATUS_AI_TYPE, main.STATUS_AI_NO_MIC, main.STATUS_OFFLINE]
	title.append_array(main.screens.TITLE_LINES)
	fits = 0
	for t in title:
		var text := Lang.t(str(t))
		if Gfx.printable(text) == text and Gfx.text_w_raw(text) <= 620.0:
			fits += 1
		else:
			print("  too wide for the title card: ", text)
	check(fits == title.size(), "the title card's lines fit the screen, whoever answers tonight")
	check(Gfx.text_w(main.intro.FOOT) <= main.intro.TEXT_W, "the opening's key line fits under its text")
	var narrow := 0
	for i in main.guide.count():
		if Gfx.text_w(main.guide.FOOT) <= main.guide.box_of(i).size.x - main.guide.PAD * 2.0:
			narrow += 1
	check(narrow == main.guide.count(), "the guide's key line fits every page's list")
	var worst_over: String = Lang.tf(main.METER_OVER_LINE, [5, 5, 3200, 2000])
	var worst_under: String = Lang.tf(main.METER_UNDER_LINE, [5, 5, -2000, 2000, 4000])
	check(Gfx.wrap_text(worst_over, main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES
		and Gfx.wrap_text(worst_under, main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES
		and Gfx.wrap_text(Lang.tf(main.SHIFT_LINE, [5, 400]), main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES,
		"the meter's readings and the shift's first line each fit one page of the strip")
	check(Gfx.wrap_text(Lang.tf(main.SHIFT_LIST_LINE, [5, 2, 400]), main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES,
		"the first line of a night with a contact list fits one page of the strip")
	var packages := 0
	var pool: Array = main.contact_data.get("pool", [])
	for e in pool:
		var line: String = Lang.tf(main.DROP_LINE, [Lang.t(str((e as Dictionary).get("package", ""))), 300])
		if Gfx.printable(line) == line and Gfx.wrap_text(line, main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES:
			packages += 1
		else:
			print("  a package that does not fit one page: ", line)
	check(pool.size() == 10 and packages == pool.size(), "what each of the ten couriers hands over fits one page of the strip")
	check(Gfx.wrap_text(Lang.tf(main.GLASS_LINE, [40, 3, 3]), main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES
		and Gfx.wrap_text(Lang.tf(main.GLASS_LINE, [999, 3, 3]), main.dialogue.TEXT_W).size() <= main.dialogue.PAGE_LINES,
		"what the glass fitter did fits one page of the strip")
	var glass_row: String = Lang.tf(main.screens.TILL_GLASS_ROW, 9999)
	check(Gfx.printable(glass_row) == glass_row and Gfx.text_w(glass_row) + Gfx.text_w("-99999") + 8.0 <= 352.0,
		"the report's till row has room to say what the glass cost")


# ================================================================ the other language

## In a language other than English (--lang=zh): every English line that reached the screen
## with no catalog line for it, and how often it was drawn. Each one fails the run: the player
## would read English in the middle of the other language. Names, code names and keys stay
## English on purpose and are not counted (scripts/core/lang.gd, _note_miss).
func untranslated_words() -> void:
	if Lang.code == "en":
		return
	section("Every line on the screen is in '%s'" % Lang.code)
	var left: Array = Lang.miss_list()
	for m in left:
		print("  shown in English (%d times): %s" % [int(m[1]), str(m[0])])
	check(left.is_empty(), "no English line reached the screen untranslated (%d did)" % left.size())


# ================================================================ log

func _count_types(records: Array) -> Dictionary:
	var types := {}
	for rec in records:
		var record: Dictionary = rec
		var t := str(record.get("type", ""))
		types[t] = int(types.get(t, 0)) + 1
	return types


## `six`: how many records the log held when the sixth shift was over. The first six shifts and
## the last three are counted apart, since they were played under different rules.
func check_log(six: int) -> void:
	section("Event log")
	var all: Dictionary = _count_types(main.event_log.memory)
	var types: Dictionary = _count_types(main.event_log.memory.slice(0, six))
	for t in ["session_start", "automated_run", "intro", "intro_end", "guide", "shift_start", "meter", "visit_start", "look", "check",
			"check_done", "ask", "reassure", "press", "say", "mark", "call_line_open", "verdict", "attack", "attack_hit", "shutter",
			"spent", "leaving", "gave_up", "agent_move", "visit_end", "shift_end", "panel", "glass_repair"]:
		check(types.has(t), "the log has '%s' records" % t)
	check(int(types.get("visit_start", 0)) == 28 and int(types.get("visit_end", 0)) == 28,
		"twenty-eight visits were logged from start to end in the first six shifts: two nights ended early")
	check(int(types.get("shift_end", 0)) == 6, "six shifts were logged")
	check(int(types.get("lights_out", 0)) == 2, "two of them ended with a blow that landed")
	check(int(types.get("meter", 0)) == 22, "the meter was read after every patient but the last of each night, and not for the hour the doctor died")
	check(int(types.get("glass_repair", 0)) == 3, "three layers of glass were bought, all in the sixth shift")
	var named := 0
	for rec in logged("panel").slice(0, int(types.get("panel", 0))):
		var record: Dictionary = rec
		if ["sheet", "card", "cam"].has(str(record.get("panel", ""))) and record.has("open"):
			named += 1
	check(named == int(types.get("panel", 0)) and named >= 20, "every paper taken down or hung back and every switch of the big screen is logged by its name")
	check(int(types.get("leaving", 0)) == 2 and int(types.get("gave_up", 0)) == 1, "one patient said twice that he was leaving, and left once")
	check(int(all.get("intro", 0)) == 1 and int(all.get("intro_end", 0)) == 1, "the opening played once in the session")
	check(int(all.get("voice", 0)) == 2, "the two refused presses of the speak key were logged, and nothing else of that kind")
	var later: Dictionary = _count_types(main.event_log.memory.slice(six))
	for t in ["contacts", "code", "snap", "flare", "surprise_due", "training", "training_end"]:
		check(later.has(t), "the last three shifts' log has '%s' records" % t)
	check(int(later.get("visit_start", 0)) == 15 and int(later.get("visit_end", 0)) == 15 and int(later.get("shift_end", 0)) == 3
		and int(later.get("meter", 0)) == 12, "the last three shifts: fifteen visits, three nights, twelve readings of the meter")
	check(int(later.get("contacts", 0)) == 3 and int(later.get("training", 0)) == 1 and int(later.get("training_end", 0)) == 3,
		"a list every night, one training, ended three times (once at its last tip, twice by hand)")
	check(int(later.get("code", 0)) == 3 and int(later.get("snap", 0)) == 1 and int(later.get("flare", 0)) == 1 and int(later.get("surprise_due", 0)) == 2,
		"three codes said (one blank, two drops), one snap and one flare, each logged when it came up")
	var listed := 0
	var lists := 0
	for rec in main.event_log.memory.slice(six):
		var record: Dictionary = rec
		if str(record.get("type", "")) != "panel":
			continue
		if ["sheet", "list", "card", "cam"].has(str(record.get("panel", ""))) and record.has("open"):
			listed += 1
		if str(record.get("panel", "")) == "list":
			lists += 1
	check(listed == int(later.get("panel", 0)) and lists >= 2, "the list taken down and hung back is logged by its name too")
	for rec in main.event_log.memory.slice(six):
		var record: Dictionary = rec
		if str(record.get("type", "")) == "code" and (record.has("say") or record.has("line") or record.has("answer")):
			check(false, "a code is logged by its entry id and result, never its words")
			break
	var worded := 0
	for rec in main.event_log.memory:
		var record: Dictionary = rec
		if str(record.get("type", "")) == "mark" and not (record.has("row") and record.has("value") and record.has("crossed")):
			worded += 1
	check(worded == 0, "a mark is logged as a row, a value and a count: the log holds no words")
