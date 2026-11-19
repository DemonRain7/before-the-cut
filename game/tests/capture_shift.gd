extends SceneTree
## Plays the game on the real renderer and saves what is actually on screen at key moments.
## These are automated captures for inspecting the build. They are not a playtest.
## Run with a graphics driver (not --headless) from the repository root:
##   godot --path game --script res://tests/capture_shift.gd -- --out=validation/captures
## --out is relative to the repository root (or absolute). Frames are saved at the game's own 640 x 360.
## That command opens the game window on your screen. To draw the same frames without anything
## appearing on screen (Windows), start it through tools/run_hidden.py; its header has the command.
##
## Under --headless nothing is drawn, so the run becomes a dry run: it walks every step, prints the
## name of each frame it would save and where the visit stands, saves nothing, and exits 1 if a
## moment it waits for never came. Use it to check this script without opening a window:
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd
##
## Five shifts are played, so that the opening, the first night's training, tonight's contact
## list and its codes, the guide, the booth walls, the hourly meter, the doctor's own marks, a
## flare, a snap, a patient who runs out of patience, every way an attack can end, a night that
## ends with the doctor and the glass fitter are all seen:
##   shift 1: the opening cards, then the first night's training, one frame a tip: tonight's list
##            and how to read it, the hall camera's two monitors, Kip's intake card, his code and
##            his package, the reference sheet, the three tools with what the sheet expects drawn
##            into each close-up, the talk pads with CALM's price, the doctor's tick, the decision
##            and, on the slip, the last tip. Kip is also looked at, asked, pressed, calmed (paid),
##            spoken to on the typing line and through push-to-talk (staged). Rook's temper gets
##            one cross, and the counter guide is opened with H at his arrival; Vale gets two
##            crosses, is called in, turns, and is stopped after the second blow (saw); Juno is
##            given the other courier's code on purpose and is seen thinking (staged); Maren hands
##            her package over and then gets through what is left of the glass (torch): the night
##            ends in the dark with her, and the report comes up out of it
##   shift 2: Kip flares over the light and the doctor drops the shutter anyway: a false alarm,
##            and the first hour under the line; Trauma Team takes Rook away; Vale gets through
##            whole glass (saw) and the night ends with him: the report names Juno and Maren, who
##            were never seen
##   shift 3: Kip runs out of patience, is held once and then leaves by himself; Vale snaps in the
##            middle of a test and is stopped before the first blow (saw); Maren is stopped after
##            the third, with the glass gone (torch)
##   shift 4: Vale takes all three blows out of the pane before the shutter stops him, and the
##            pane drops out of its frame; Juno is seen behind the broken window; Maren is stopped
##            in time with no glass left (torch)
##   shift 5: Vale breaks the pane again; between patients the till buys it back, one layer at a
##            time; Maren turns behind the mended glass and has the whole bar again; the report
##            says what the glass cost
## The glass belongs to the shift: a blow that lands in one attack leaves less time in the next.
## That is why the same two patients are seen with three blows, one blow and none.
## Right and wrong are told only on the report. A slip says what the counter did, and each report
## is read the way a player reads it: a frame of the first visit's page, one of the last visit's
## page and one of the night's totals.
##
## The night is played under the game's own rules: the line of 240 an hour, two couriers on
## each night's list, CALM at 30 credits. Each night's seed is fixed (seed_for()), so that the
## list is the same in every run: Kip and Maren on the first night, Rook and Juno afterwards.
## Snaps and flares are switched off for the run, since a random one would cut into a staged
## scene. The flare of shift 2 and the snap of shift 3 are cued instead: their rules are pinned
## for one action, as tests/run_ui_smoke.gd does.
##
## The push-to-talk frames and the thinking frames are staged: a stand-in answers in place of the
## patient AI service and the microphone is simulated. No device is opened, nobody is recorded and
## no service is called. On the push-to-talk frames the words on the line are the mock sentence,
## and the strip says so. On the thinking frames the stand-in keeps the answer back for three
## seconds and then has none, so the authored patient answers after all.
## Options after the "--":
##   --attacks-only   skip the opening, the training, the guide and the examination shots, keep
##                    the attack scenes (the snap among them) and the glass fitter. The training is
##                    switched off for it, so the guide opens by itself at the first patient, as
##                    with --no-training, and is closed with ESC
##   --less-blood     passed on to the game: the same scenes without the blood

const MainScript = preload("res://scripts/ui/main.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const ShiftState = preload("res://scripts/core/shift_state.gd")
const PlayDriver = preload("res://tests/play_driver.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")

const REST := Vector2(200, 262)    # a place for the pointer where it rests on nothing: the hall, left of the visitor
const REST_RIGHT := Vector2(470, 262)   # the same on the other side, for when the big screen is on

var main: MainScript = null
var d: PlayDriver = null
var output_dir: String = ""
var count: int = 0
var attacks_only: bool = false
var dry: bool = false              # headless: nothing is drawn, so nothing is saved
var missed: int = 0                # moments a shot waited for that never came


## Stands in for the patient AI service in the staged frames. It never answers as a patient: a
## line said to it fails, after `hold` seconds when that is set, and the authored patient answers
## instead. It answers a clip, and only when told to, with the sentence the proxy's mock
## transport uses.
class StandInClient:
	extends RefCounted
	signal released

	var tree: SceneTree = null
	var hold: float = 0.0          # seconds a patient's answer is kept back before it fails

	func is_configured() -> bool:
		return true

	func request_move(_payload: Dictionary) -> Dictionary:
		if hold > 0.0 and tree != null:
			await tree.create_timer(hold, false).timeout
		return {"ok": false, "error": "stand_in"}

	func request_transcript(_payload: Dictionary) -> Dictionary:
		await released
		# what the doctor "said", so in the doctor's language (agent_proxy providers.mjs: MOCK_TRANSCRIPT, _ZH)
		var said := "这是模拟转写，没有语音服务听到你说话。" if Lang.code == "zh" else "This is a mock transcript. No speech service heard you."
		return {"ok": true, "http_code": 200, "data": {"text": said, "meta": {"mock": true, "provider": "stand-in"}}}


func _initialize() -> void:
	# English, unless --lang=<code> asks for another language; a saved choice never reaches a run
	Lang.pin(Lang.asked("en"))
	output_dir = ProjectSettings.globalize_path("res://../validation/captures")
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--out="):
			var path := a.substr(6)
			output_dir = path if path.is_absolute_path() else ProjectSettings.globalize_path("res://../" + path)
		elif a == "--attacks-only":
			attacks_only = true
	dry = DisplayServer.get_name() == "headless"
	if not dry:
		DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(1500.0, true, false, true).timeout.connect(_on_watchdog)
	_run()


func _on_watchdog() -> void:
	print("RESULT: the capture run did not finish (%d frames saved)." % count)
	quit(2)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate() as MainScript
	main.authored_order = true      # the scenes below follow the listed order of patients
	root.add_child(main)
	await process_frame
	main.set_process_input(false)      # only the driver moves the pointer during a capture run
	main.audio.set_muted(true)
	main.mic.simulated = true          # a capture run never opens a microphone
	d = PlayDriver.new(self, main)
	main.event_log.write("automated_run", {"runner": "tests/capture_shift.gd"})
	main.surprises_enabled = false     # a random snap or flare would cut into a staged scene; two are cued below
	if attacks_only:
		main.training_enabled = false  # its box would sit over the first night's frames
	var first_night := seed_for(["kip", "maren"], main.training_enabled)
	var later_nights := seed_for(["rook", "juno"], false)
	reached(first_night > 0 and later_nights > 0, "a seed is found for each night's contact list")
	main.fixed_seed = first_night
	main.has_fixed_seed = true
	d.move(Vector2(330, 250))
	await d.seconds(0.6)
	# ---------------------------------------------------------------- shift 1
	if attacks_only:
		await d.open_counter()
		await d.settle()
		await quick("treat")
		await quick("treat")
		await vale_stopped(true)
		await quick("treat", "juno-behind-cracked-glass")
		await maren_gets_through(true)
	else:
		await shot("title")
		await opening_cards()
		await d.settle()
		await training_wait()
		await kip()
		await rook()
		await vale_stopped(false)
		await juno()
		await maren_gets_through(false)
	await report_shot("report")
	# ---------------------------------------------------------------- shift 2
	main.fixed_seed = later_nights
	await d.open_counter()
	if attacks_only:
		await quick("treat")
		await quick("treat", "rook-clean-window")
	else:
		await kip_false_alarm()
		await team_takes("rook", "rook-clean-window")
	await vale_gets_through()      # the night ends with him: Juno and Maren are never seen
	await report_shot("report-2")
	# ---------------------------------------------------------------- shift 3
	await d.open_counter()
	if attacks_only:
		await quick("treat")
	else:
		await kip_runs_out()
	await quick("treat")
	await vale_snaps()
	await quick("treat", "juno-behind-whole-glass")
	await maren_stopped_late()
	await report_shot("report-3")
	# ---------------------------------------------------------------- shift 4
	await d.open_counter()
	await quick("treat")
	await quick("treat")
	await vale_breaks_the_pane("vale-4")
	await quick("treat", "juno-behind-broken-window")
	await maren_stopped_bare()
	await report_shot("report-4")
	# ---------------------------------------------------------------- shift 5
	await d.open_counter()
	await quick("treat")
	await quick("treat")
	await vale_breaks_the_pane("vale-5")
	await glass_fitter()
	await quick("treat", "juno-behind-mended-glass")
	await maren_whole_bar()
	await report_shot("report-5")
	if dry:
		print("DRY RUN: %d frames would be captured, %d moments missed. Nothing was drawn or saved." % [count, missed])
	else:
		print("Captured %d frames to %s (%d moments missed)" % [count, output_dir, missed])
	await d.leave()
	quit(0 if missed == 0 else 1)


## The end-of-shift report, read the way a player reads it: the first visit's page, the last
## visit's page (ESC to the totals, BACKSPACE back one) and the night's totals, with the pointer
## beside the paper so that it covers none of the words. After a night that ended in the dark,
## the dark has lifted first.
func report_shot(stem: String) -> void:
	reached(await d.wait_for_report(10.0), stem + ": the report is up")
	reached(await d.until(func() -> bool: return main.screens.fade == 0.0, 4.0), stem + ": nothing covers it")
	reached(main.screens.page == 0 and not main.screens.on_summary(), stem + ": it opens on the first visit's page")
	# the line that asks for a click blinks; each frame waits for it to be lit
	var lit := func() -> bool: return fmod(main.screens._t, 1.0) < 0.5
	d.move(Vector2(580, 318))
	await d.seconds(0.8)
	await d.until(lit, 2.0)
	await shot(stem + "-first-visit")
	d.key(KEY_ESCAPE)
	d.key(KEY_BACKSPACE)
	reached(main.screens.page == main.screens.pages() - 2, stem + ": BACKSPACE from the totals is the last visit's page")
	await d.seconds(0.5)
	await d.until(lit, 2.0)
	await shot(stem + "-last-visit")
	d.key(KEY_ESCAPE)
	reached(main.screens.on_summary(), stem + ": ESC goes to the night's totals")
	await d.until(func() -> bool: return main.screens.age() > 0.85 and lit.call(), 3.0)
	await shot(stem)


## A moment a shot waits for. A miss is printed and counted, so a dry run shows a broken step.
func reached(ok: bool, what: String) -> void:
	if not ok:
		missed += 1
		print("MISSED %s" % what)


## Sets some rules for a moment (as tests/run_ui_smoke.gd does) and returns what they were,
## for restore_rules().
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


## A shift seed whose contact list holds exactly these cases, drawn the way the game draws it
## (with `training`, the first visitor is always on the list). -1 if none of the first 5000 does.
func seed_for(cases: Array, training: bool) -> int:
	var want: Array = cases.duplicate()
	want.sort()
	var order: Array = ShiftState.new(main.rules, []).order
	for s in range(1, 5001):
		var got: Array = []
		for e in ShiftState.draw_contacts(main.rules, main.contact_data.get("pool", []), order, s, training):
			got.append(str((e as Dictionary).get("case", "")))
		got.sort()
		if got == want:
			return s
	return -1


## The id of tonight's list entry for a case, or "" if that case is not on the list.
func entry_of(case_id: String) -> String:
	for e in main.shift.contacts:
		if str((e as Dictionary).get("case", "")) == case_id:
			return str((e as Dictionary).get("id", ""))
	return ""


## Puts the pointer where it rests on nothing: the hall beside the visitor, on whichever side the
## training box and the big screen leave clear (failing both, the top of the window).
func rest() -> void:
	for p in [REST, REST_RIGHT, Vector2(320, 8)]:
		if main.coach.is_showing() and main.coach.box().grow(6.0).has_point(p):
			continue
		if d.cam_on() and Gfx.CAM.has_point(p):
			continue
		d.move(p)
		return
	d.move(Vector2(320, 8))


## A click on something behind the training box would land on the box instead: the run says so.
func clear_of_box(pos: Vector2, what: String) -> void:
	reached(main.coach.button_at(pos) == "", what + ": the training box is not in front of it")


## Closes the close-up that is open, if one is (a right-click with nothing open would hang the
## papers back instead).
func close_scope() -> void:
	if main.clinic.scope.is_open():
		await d.put_away()


## Where the run stands, for the dry run's list: the state, and what is left of the patience,
## the glass and the till.
func _where() -> String:
	var out := str(MainScript.State.keys()[main.state])
	if main.visit != null:
		out += ", patience %d/%d" % [main.visit.patience, main.visit.patience_max]
	if main.shift != null:
		out += ", glass %d, till %d" % [main.shift.glass, main.clinic.till]
	return out


func shot(stem: String) -> void:
	count += 1
	await process_frame
	var file := "%03d-%s.png" % [count, stem]
	if dry:
		print("DRY %s   [%s]" % [file, _where()])
		return
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var status: int = frame.save_png(output_dir.path_join(file))
	if status != OK:
		push_error("Could not save " + file)
		quit(1)
		return
	print("CAPTURE %s  %dx%d" % [file, frame.get_width(), frame.get_height()])


func hold_grip(stem: String) -> void:
	var p := d.in_window(Vector2(110, 100))
	main.pointer_move(p)
	main.pointer_down(p, MOUSE_BUTTON_LEFT)
	await d.seconds(0.75)
	if stem != "":
		await shot(stem)
	main.pointer_up(p, MOUSE_BUTTON_LEFT)
	await d.until(func() -> bool: return main.visit != null and main.visit.seen.has("check:grip"), 5.0)
	await d.seconds(0.4)


## A visit with no examination at all: buzz in, decide ("treat" or "refer"), take the slip.
func quick(kind: String, stem: String = "") -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	if stem != "":
		await d.seconds(0.3)
		await shot(stem)
	await d.stamp(kind)
	await d.wait_for_slip()
	await d.take_slip()


## Tears the slip off and catches the lender's meter reading the hour that just ended.
func slip_then_meter(stem: String) -> void:
	d.click(MainScript.SLIP_CLIP.get_center())
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "METER" and not main.dialogue.typing, 15.0),
		stem + ": the meter reads the hour")
	await d.seconds(0.2)
	await shot(stem)
	reached(await d.until(func() -> bool: return main.state == MainScript.State.WAIT and main.clinic.cam_prompt, 15.0),
		stem + ": the next patient is on the camera")


# ================================================================ the opening and the guide

## The cards between the title and the first shift: one frame each with the words all out and
## the picture at rest, the first card also while it is still typing, and the line the shift
## opens with.
func opening_cards() -> void:
	reached(await d.open_counter(true), "the opening cards come up after the title")
	for i in main.intro.count():
		reached(await d.until(func() -> bool: return main.intro._phase == "show" and main.intro.index == i, 4.0),
			"opening card %d opens" % (i + 1))
		var id := str(main.intro._cards[i].get("id", "card"))
		if i == 0:
			await d.seconds(1.4)
			await shot("intro-1-%s-typing" % id)
		else:
			await d.seconds(0.6)
		d.key(KEY_ENTER)               # the rest of the words at once; the picture hurries to its end
		await d.seconds(1.5)
		await shot("intro-%d-%s" % [i + 1, id])
		d.key(KEY_ENTER)
	var read_out := func() -> bool:
		return (main.state == MainScript.State.WAIT and not main.intro.is_running()
			and not main.dialogue.typing and not main.dialogue.lines.is_empty())
	reached(await d.until(read_out, 8.0), "the shift's first line is read out")
	await shot("night-shift-line")
	reached(await d.wait_for_counter(), "the hall camera asks for the first patient")


## The first night's training while the first visitor waits: tonight's list on the left wall and
## how to read it, then the hall camera. One frame a tip, and the hall on the big screen.
func training_wait() -> void:
	await process_frame
	await process_frame
	reached(main.coach.is_showing() and main.coach.current() == "list" and not main.guide.is_open(),
		"training: the first tip is up, tonight's list, and the guide stays shut")
	rest()
	await d.seconds(0.5)
	await shot("training-1-list")
	d.move(main.desk.object_rect("list").get_center())
	await d.seconds(0.3)
	await shot("wall-list-hover")
	d.take_list()
	rest()
	await d.until(func() -> bool: return main.clipboard._list_k >= 1.0, 3.0)
	await d.seconds(0.4)
	reached(d.list_down() and main.coach.current() == "clues", "training: the list is down, and the next tip says how to read it")
	await shot("training-2-clues")
	d.click(main.coach.next_rect().get_center())
	reached(main.coach.current() == "buzz", "training: NEXT moves on to the hall camera")
	# the small monitor on the left wall puts the hall on the big screen; a press on that lets them in
	d.move(d.thumb_pos())
	await d.seconds(0.4)
	await shot("training-3-camera")
	d.click(d.thumb_pos())
	d.move(Gfx.MONITOR.get_center() + Vector2(34, 22))
	await d.seconds(0.5)
	reached(d.cam_on() and main.state == MainScript.State.WAIT, "training: the hall is on the big screen, and nobody is let in yet")
	await shot("hall-camera-big-screen")
	clear_of_box(Gfx.MONITOR.get_center(), "training: the big screen")
	await d.buzz_in()
	reached(main.coach.current() == "card" and not main.guide.is_open(),
		"training: buzzing the visitor in moves on to the intake card, and the guide does not open by itself")


## The counter guide, opened with H: one frame a page (the window, the left wall, the right
## wall, the desk). It opens by itself only on a first night without the training.
func guide_pages(who: String) -> void:
	d.key(KEY_H)
	reached(main.guide.is_open(), who + ": H opens the counter guide")
	d.move(Vector2(176, 250))      # in the hall, left of the visitor: no page of the guide has words or a frame there
	for i in main.guide.count():
		if not main.guide.is_open():
			break
		await d.seconds(0.35)
		await shot("guide-%d-%s" % [i + 1, main.guide.id_of(i)])
		d.key(KEY_ENTER)
	reached(not main.guide.is_open(), who + ": the guide closes after its last page")


# ================================================================ the attack scenes

## How many blows the glass that is left tonight takes before they are through it.
func blows_due() -> int:
	var plan: Dictionary = main.shift.attack_plan()
	var blows: Array = plan.get("blows_ms", [])
	return blows.size()


## The silent beat, the turn with the bar over the printer slot, and the blows on the glass up
## to blow `upto` (0: none is waited for).
func turn_shots(who: String, upto: int) -> void:
	reached(await d.until(func() -> bool: return main.state == MainScript.State.ATTACK and main.clinic.flicker > 0.0, 20.0),
		who + ": the patient turns")
	reached(blows_due() >= upto, "%s: the glass has %d blows left in it (it has %d)" % [who, upto, blows_due()])
	await d.seconds(0.3)
	await shot(who + "-beat")
	await d.wait_for_telegraph()
	await d.seconds(0.04)
	await shot(who + "-turns")
	for n in range(1, upto + 1):
		reached(await d.until(func() -> bool: return main._blows >= n, 4.0), "%s: blow %d lands" % [who, n])
		await d.seconds(0.05)
		await shot("%s-blow-%d" % [who, n])
		if n == 2:
			await d.seconds(0.25)
			await shot(who + "-weapon-on-glass")


## The shutter is dropped now: the plate that says how the stop went, what the shutter lands
## on, the dents, and the weapon coming through.
func stopped_shots(who: String) -> void:
	d.shutter_key()
	reached(main.visit != null and main.visit.outcome == "caught", who + ": the shutter is in time")
	await d.seconds(0.1)
	await shot(who + "-shutter-falling")
	await d.until(func() -> bool: return main.clinic.shutter_closed(), 2.0)
	await d.seconds(0.06)
	await shot(who + "-shutter-lands")
	await d.until(func() -> bool: return main.clinic.dent_count() >= 2, 4.0)
	await d.seconds(0.04)
	await shot(who + "-shutter-dents")
	await d.until(func() -> bool: return main.clinic.cut_active(), 4.0)
	await d.seconds(0.45)
	await shot(who + "-cuts-through")
	await d.until(func() -> bool: return main.clinic.has_cut() and not main.clinic.cut_active(), 4.0)
	await d.seconds(0.6)
	await shot(who + "-shutter-after")
	reached(await d.wait_for_slip(), who + ": the slip prints")
	await shot(who + "-stopped-slip")
	await d.take_slip()


## Nobody drops the shutter: the pane goes and they come through it, and the night ends in the
## dark with them. No slip prints: the report comes up out of the dark (report_shot has its frames).
func through_shots(who: String) -> void:
	await d.until(func() -> bool: return main.state != MainScript.State.ATTACK, 6.0)
	reached(main.visit != null and main.visit.outcome == "hit", who + ": they are through")
	await d.seconds(0.08)
	await shot(who + "-glass-goes")
	await d.until(func() -> bool: return main.rig != null and main.rig.pop >= 1.0, 3.0)
	await shot(who + "-through")
	await d.seconds(0.09)
	await shot(who + "-strike")
	await d.seconds(0.25)
	await shot(who + "-blood")
	await d.until(func() -> bool: return main.rig == null or main.rig.pop > 1.02, 3.0)
	await d.seconds(0.1)
	await shot(who + "-again")
	await d.seconds(0.2)
	await shot(who + "-closer")
	await d.until(func() -> bool: return main.rig == null or main.rig.pop > 1.6, 3.0)
	await d.seconds(0.06)
	await shot(who + "-third")
	await d.seconds(0.12)
	await shot(who + "-last")
	# the dark: no slip prints and nobody else comes in; the report comes up out of it
	reached(await d.until(func() -> bool: return main.screens.fade >= 1.0, 6.0), who + ": the lights go out")
	reached(await d.wait_for_report(10.0), who + ": the night ends: the report comes up out of the dark")
	reached(main._slip_mode == "hidden" and main.shift.died and main.shift.is_done(), who + ": no slip prints, and nobody else comes in")
	await d.until(func() -> bool: return main.screens.fade <= 0.5, 3.0)
	await shot(who + "-lights-out")


# ================================================================ the doctor's own words

## The typing line: T opens it, the sentence is typed, ENTER says it, the patient answers.
## A default run is the offline comparison, so the answer is the authored one.
func typed_line(who: String, sentence: String) -> void:
	await d.settle()
	d.key(KEY_T, 116)
	reached(main.dialogue.input_open, who + ": T opens the typing line")
	d.type_text(sentence)
	await d.seconds(0.3)
	await shot(who + "-typing-line")
	d.key(KEY_ENTER)
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "YOU" and not main.dialogue.typing, 4.0),
		who + ": the typed sentence is on the strip")
	await shot(who + "-typed-line-said")
	reached(await d.until(func() -> bool: return main.dialogue.speaker != "YOU" and not main._thinking, 12.0),
		who + ": the patient answers the typed sentence")
	await d.settle()
	await d.seconds(0.2)
	await shot(who + "-typed-line-answer")


## The push-to-talk strip, staged (see the header): what it draws while the key is held, while the
## words are on their way, and when they are on the line for the doctor to check, and the patient
## looking up while the doctor speaks. Nothing is said to the patient: ESC takes the sentence
## back, and the visit goes on as the offline comparison.
func staged_voice(who: String) -> void:
	await d.settle()
	var real_client: Variant = main.agent.client
	var real_mode: String = main.agent.mode
	var stand_in := StandInClient.new()
	main.agent.client = stand_in
	main.agent.set_mode("model")
	await d.seconds(0.2)
	reached(main._mic_why_not() == "", who + ": push-to-talk is offered to the stand-in")
	await shot(who + "-staged-speak-button")
	d.key(KEY_TAB)
	reached(main._mic_state == "listening", who + ": holding TAB opens the simulated microphone")
	if main._mic_state == "listening":
		main.mic.feed(d.tone(0.5, 0.3))
		await d.seconds(0.4)
		main.mic.feed(d.tone(0.3, 0.2))
		await d.seconds(0.15)
		reached(main.rig != null and main.rig.listening, who + ": the patient listens while the doctor speaks")
		await shot(who + "-staged-listening")
		d.key_release(KEY_TAB)
		reached(main._mic_state == "transcribing", who + ": letting go sends the clip to the stand-in")
		await d.seconds(0.35)
		await shot(who + "-staged-writing-down")
		stand_in.released.emit()
		reached(await d.until(func() -> bool: return main._mic_state == "" and main.dialogue.input_text != "", 5.0),
			who + ": the mock sentence arrives on the typing line")
		await d.seconds(0.25)
		await shot(who + "-staged-transcript")
		d.key(KEY_ESCAPE)
	reached(not main.dialogue.input_open, who + ": ESC takes the staged sentence back")
	main.agent.client = real_client
	main.agent.set_mode(real_mode)
	await d.seconds(0.2)
	reached(main.agent.mode == real_mode, who + ": the visit goes on as it was")


## A patient who takes a moment over an answer, staged (see the header): question `question` of
## the list is asked while a stand-in keeps the answer back. The waiting pose and the thought
## bubble, then the hint that says the doctor does not have to wait.
func staged_thinking(who: String, question: int) -> void:
	await d.settle()
	var real_client: Variant = main.agent.client
	var real_mode: String = main.agent.mode
	var stand_in := StandInClient.new()
	stand_in.tree = self
	stand_in.hold = 3.0
	main.agent.client = stand_in
	main.agent.set_mode("model")
	if not main.dialogue.has_menu():
		d.pad("ask")
		await process_frame
	d.click(main.dialogue.menu_point(question))
	d.move(REST)
	reached(await d.until(func() -> bool: return main.rig != null and main.rig.thinking, 2.0), who + ": the patient is seen thinking")
	await d.seconds(0.3)
	await shot(who + "-staged-thinking")
	reached(await d.until(func() -> bool: return main.dialogue.hint == main.THINK_HINT, 2.0),
		who + ": the hint says the answer is still on its way")
	await d.seconds(0.4)
	await shot(who + "-staged-thinking-hint")
	reached(await d.until(func() -> bool: return not main._thinking and not main._lock, 10.0),
		who + ": the authored patient answers after all")
	main.agent.client = real_client
	main.agent.set_mode(real_mode)
	reached(main.agent.mode == real_mode, who + ": the visit goes on as it was")


## Trauma Team is called on a patient who does not fight: the line opens, dispatch answers, the
## siren and the lights, the crew in the hall, and the patient walked out between them.
func team_takes(who: String, stem: String = "") -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	if stem != "":
		await d.seconds(0.3)
		await shot(stem)
	d.pad("refer")
	await d.seconds(0.3)
	await shot(who + "-call-line-open")
	d.pad("refer")
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "DISPATCH", 4.0), who + ": dispatch answers the call")
	await d.seconds(0.5)
	await shot(who + "-dispatch-answers")
	reached(await d.until(func() -> bool: return main.clinic.strobe > 0.5 and not main.clinic.team_in_sight(), 25.0),
		who + ": their lights are in the street")
	await d.seconds(0.4)
	await shot(who + "-siren-outside")
	reached(await d.until(func() -> bool: return main.clinic.team_in_sight() and not main.clinic.team_moving(), 6.0),
		who + ": the crew is in the hall")
	await d.seconds(0.15)
	await shot(who + "-team-arrives")
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "TRAUMA TEAM", 4.0), who + ": the crew speaks")
	await d.seconds(0.6)
	await shot(who + "-team-speaks")
	reached(await d.until(func() -> bool: return main.rig != null and main.rig.slide > 0.25, 25.0), who + ": the patient is walked out")
	await shot(who + "-walked-out")
	reached(await d.wait_for_slip(), who + ": the slip prints")
	await shot(who + "-team-slip")
	await d.take_slip()


# ================================================================ shift 1

## The first patient of the session, the training visit, one frame a tip: his intake card, his
## code and his package, the reference sheet, the three tools with what the sheet expects drawn
## into each close-up, the talk pads with CALM's price, the doctor's own tick and the decision.
## Then the rest of what a visit offers: the hall seen during a visit, the looks, a question, a
## press, a paid CALM, the typing line and the staged push-to-talk, TREAT, the last tip on the
## slip, and the meter's first reading.
func kip() -> void:
	var kip_id := entry_of("kip")
	reached(main.visit != null and main.visit.is_contact() and kip_id != "", "kip: he is on tonight's list")
	await d.settle()
	rest()
	await d.seconds(0.4)
	reached(not d.cam_on() and main.coach.is_showing() and main.coach.current() == "card", "kip: he is in, and the tip points at his intake card")
	await shot("training-4-card")
	d.move(d.zone_pos("eyes"))
	await d.seconds(0.25)
	await shot("kip-hover-eyes")
	clear_of_box(d.zone_pos("eyes"), "kip: his eyes")
	await d.look("eyes")
	await d.settle()
	await d.seconds(0.3)
	reached(str(main.desk.badges.get("card", "")) == "1", "kip: the card on the wall counts the note it has not shown")
	await shot("kip-look-eyes")
	# the intake card comes down from the right wall, with the note already on it; the list is down on the left
	d.move(main.desk.object_rect("card").get_center())
	await d.seconds(0.3)
	await shot("kip-wall-card-hover")
	d.take_card()
	d.take_list()
	rest()
	await d.until(func() -> bool: return main.clipboard._list_k >= 1.0, 3.0)
	await d.seconds(0.4)
	reached(d.card_down() and d.list_down() and main.coach.current() == "code", "kip: card and list are down, and the tip says to hold one against the other")
	await shot("training-5-code")
	d.move(d.say_pos(kip_id))
	await d.seconds(0.3)
	reached(main.clipboard.say_hover == kip_id, "kip: the pointer is on the SAY beside his entry")
	await shot("kip-say-hover")
	clear_of_box(d.say_pos(kip_id), "kip: his entry's SAY")
	d.click(d.say_pos(kip_id))
	rest()
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "YOU" and not main.dialogue.typing, 5.0), "kip: the doctor says the code")
	await shot("kip-says-the-code")
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "PACKAGE" and not main.dialogue.typing, 8.0),
		"kip: he answers it, and the package comes over the counter")
	reached(main.visit.dropped and main.clipboard.entry_mark(kip_id) == "picked" and main.coach.current() == "drop",
		"kip: the drop is in the till, his entry is ticked off, and the tip says what it means")
	rest()
	await d.seconds(0.3)
	await shot("training-6-drop")
	d.click(main.coach.next_rect().get_center())
	reached(main.coach.current() == "sheet", "kip: NEXT moves on to the reference sheet")
	# the reference sheet comes down where the list is, through the tab under the list
	d.move(main.clipboard.swap_tab().get_center())
	await d.seconds(0.35)
	await shot("training-7-sheet")
	clear_of_box(main.clipboard.swap_tab().get_center(), "kip: the swap tab")
	d.swap()
	d.move(d.pad_pos("penlight"))
	await d.seconds(0.45)
	reached(d.sheet_down() and not d.list_down() and main.coach.current() == "light",
		"kip: the sheet is down where the list was, and the next tip is the penlight")
	await shot("training-8-light")
	reached(await d.request_tool("penlight") == "open", "kip: the penlight close-up opens")
	d.move(d.in_window(Vector2(60, 86)))
	await d.seconds(0.45)
	reached(not main.coach.is_showing(), "kip: the tips step aside while a close-up is open")
	await shot("kip-penlight-right-eye")
	await d.sweep_eyes()
	await d.seconds(0.4)
	await shot("kip-penlight-readouts")
	await close_scope()
	rest()
	await d.seconds(0.4)
	reached(main.coach.is_showing() and main.coach.current() == "grip", "kip: with the light away, the grip tip")
	await shot("training-9-grip")
	reached(await d.request_tool("grip") == "open", "kip: the grip close-up opens")
	await d.seconds(0.25)
	await shot("kip-grip-ready")
	await hold_grip("kip-grip-squeeze")
	await shot("kip-grip-result")
	await d.settle()
	await close_scope()
	rest()
	await d.seconds(0.4)
	reached(main.coach.is_showing() and main.coach.current() == "port", "kip: the port tip")
	await shot("training-10-port")
	reached(await d.request_tool("port") == "open", "kip: the port close-up opens")
	await d.watch_port()
	await d.seconds(0.4)
	await shot("kip-port")
	await close_scope()
	d.move(d.pad_pos("calm"))
	await d.seconds(0.45)
	reached(main.coach.is_showing() and main.coach.current() == "talk" and str(main.desk.badges.get("calm", "")) == Lang.tf("%dcr", [30]),
		"kip: the tip about talking, and CALM's price on its pad")
	await shot("training-11-talk")
	d.click(main.coach.next_rect().get_center())
	reached(main.coach.current() == "marks", "kip: NEXT moves on to the doctor's own marks")
	d.take_card()
	d.move(d.mark_pos("eyes"))
	await d.seconds(0.35)
	reached(d.card_down(), "kip: the card is down for the marks")
	await shot("training-12-marks")
	clear_of_box(d.mark_pos("eyes"), "kip: the mark box")
	d.mark("eyes")
	d.move(d.mark_pos("eyes") + Vector2(46, 18))      # off the box, so the tick is not under the hand
	await d.seconds(0.35)
	reached(main.visit != null and main.visit.ticked() == 1 and main.coach.current() == "decide",
		"kip: one click on the box ticks the row, and the last tip of the exam is the decision")
	await shot("training-13-decide")
	# the tab on a paper's edge hangs it back
	d.move(main.clipboard.sheet_tab().get_center())
	await d.seconds(0.3)
	await shot("kip-sheet-tab-hover")
	d.hang_sheet()
	d.hang_card()
	# a look into the hall while he stands there: it lets nobody in
	d.key(KEY_C)
	d.move(REST_RIGHT)
	await d.seconds(0.4)
	reached(d.cam_on() and main.state == MainScript.State.EXAM, "kip: C puts the hall on the big screen during a visit")
	await shot("kip-hall-peek")
	d.key(KEY_C)
	await d.seconds(0.2)
	clear_of_box(d.zone_pos("hands"), "kip: his hands")
	await d.look("hands")
	await d.settle()
	clear_of_box(d.zone_pos("port"), "kip: his port")
	await d.look("port")
	await d.settle()
	d.pad("ask")
	await d.seconds(0.15)
	d.move(main.dialogue.menu_point(1))
	await d.seconds(0.15)
	await shot("kip-ask-menu")
	await d.ask(1)
	await d.settle()
	await d.seconds(0.2)
	await shot("kip-answer")
	await d.press()
	await d.seconds(0.5)
	await shot("kip-press-reaction")
	await d.settle()
	await d.seconds(0.3)
	reached(main.visit != null and main.visit.patience == 1, "kip: one patience lamp is left after the press")
	await shot("kip-last-lamp-tip")
	await d.reassure()
	await d.settle()
	reached(main.visit != null and main.visit.calm_spent == 30, "kip: the calm-patch is paid for out of the till")
	await shot("kip-reassured")
	await typed_line("kip", "Is the night shift hard on you?")
	await staged_voice("kip")
	# the stamp is picked up from the wall plate, and the card comes down for it by itself
	d.pad("treat")
	await process_frame
	d.move(main.clipboard.decision_rect().get_center() + Vector2(-8, 34))
	await d.seconds(0.25)
	reached(main._held == "treat" and d.card_down(), "kip: with the stamp in hand the card is down")
	await shot("kip-stamp-in-hand")
	clear_of_box(main.clipboard.decision_rect().get_center(), "kip: the card's decision box")
	d.click(main.clipboard.decision_rect().get_center())
	d.move(REST_RIGHT)      # off the card, so that nothing on it is under the hand
	await d.seconds(0.3)
	await shot("kip-stamped")
	await d.wait_for_slip()
	await d.seconds(0.3)
	reached(main.coach.is_showing() and main.coach.current() == "after", "kip: with the slip, the training's last tip")
	await shot("kip-slip-last-tip")
	await slip_then_meter("meter-over-the-line")


## Rook refuses, loses his temper and gets one cross for it: one broken line alone can be ordinary.
## The training ends as he is buzzed in, and the counter guide is opened with H.
func rook() -> void:
	await d.settle()
	await shot("rook-camera")
	await d.buzz_in()
	await d.settle()
	reached(not main.coach.is_running() and not main.guide.is_open(), "rook: buzzing the second visitor in ends the training")
	await shot("rook-arrives")
	await guide_pages("rook")
	await d.settle()
	await d.request_tool("grip")
	d.move(d.pad_pos("grip"))
	await d.seconds(0.3)
	await shot("rook-refuses-grip")
	await d.press()
	await d.seconds(0.12)
	await shot("rook-slam")
	await d.settle()
	await shot("rook-angry")
	d.mark("temper")
	d.mark("temper")
	await d.seconds(0.35)
	reached(main.visit != null and main.visit.crossed() == 1, "rook: two clicks on the box cross the row")
	await shot("rook-one-cross")
	d.hang_card()
	await d.reassure()
	await d.settle()
	await d.request_tool("grip")
	await hold_grip("")
	await shot("rook-grip-result")
	await d.request_tool("penlight")
	await d.sweep_eyes()
	await d.seconds(0.3)
	await shot("rook-penlight")
	await d.put_away()
	await d.stamp("treat")
	d.move(REST_RIGHT)
	await d.wait_for_slip()
	await shot("rook-slip")
	await d.take_slip()


## Trauma Team is called on Vale, he turns, and the shutter comes down after the second blow.
func vale_stopped(brief: bool) -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	if not brief:
		await shot("vale-arrives")
		await d.look("eyes")
		await d.settle()
		await d.look("hands")
		await d.settle()
		await d.look("port")
		await d.settle()
		await shot("vale-looks")
		await d.request_tool("penlight")
		await d.seconds(0.3)
		await shot("vale-explains")
		await d.request_tool("penlight")
		await d.sweep_eyes()
		await d.seconds(0.4)
		await shot("vale-penlight")
		await d.put_away()
		await d.request_tool("port")
		await d.seconds(0.3)
		await shot("vale-port-refused")
		await d.settle()
		# the doctor's own reading: two rows crossed, which is where the house rule says to call
		d.mark("eyes")
		d.mark("eyes")
		d.mark("port")
		d.mark("port")
		await d.seconds(0.35)
		reached(main.visit != null and main.visit.crossed() == 2, "vale: two rows are crossed")
		await shot("vale-crossed-rule")
	d.pad("refer")
	await d.seconds(0.3)
	await shot("vale-call-line-open")
	d.pad("refer")
	await d.seconds(0.3)
	await shot("vale-team-called")
	await turn_shots("vale", 2)
	await stopped_shots("vale")


## Juno's chrome looks worse than it is. She is given the other courier's code on purpose: a
## blank look, one patience. She is seen thinking an answer over (staged).
func juno() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	reached(d.card_down(), "juno: the card is still down from the last visit, with her name on it now")
	await shot("juno-arrives")
	var before: int = main.visit.patience if main.visit != null else 0
	await d.say_code(entry_of("maren"))
	await d.settle()
	rest()
	await d.seconds(0.3)
	reached(main.visit != null and main.visit.codes_wrong == 1 and main.visit.patience == before - 1 and not main.visit.dropped
		and main._base_hint == Lang.tf(MainScript.CODE_BLANK_HINT, [1]), "juno: Maren's code gets a blank look and costs a lamp")
	await shot("juno-wrong-code")
	d.hang_list()
	d.hang_card()
	await d.look("eyes")
	await d.settle()
	await shot("juno-look-eyes")
	await d.request_tool("penlight")
	await d.sweep_eyes()
	await d.seconds(0.4)
	await shot("juno-penlight")
	await d.put_away()
	await staged_thinking("juno", 1)
	await d.settle()
	await shot("juno-deflects")
	await d.press()      # her last lamps but one: the wrong code cost one of them
	await d.seconds(0.4)
	await shot("juno-press")
	await d.settle()
	await d.stamp("treat")
	d.move(REST_RIGHT)
	await d.wait_for_slip()
	await shot("juno-slip")
	await d.take_slip()


## Maren, the night's other courier, answers her code and hands her package over; then she is
## pressed twice, turns, and nobody touches the shutter. The glass Vale left has one blow in it,
## so she is through after one, and the night ends with her.
func maren_gets_through(brief: bool) -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await shot("maren-arrives")
	if not brief:
		var maren_id := entry_of("maren")
		await d.say_code(maren_id)
		reached(await d.until(func() -> bool: return main.dialogue.speaker == "PACKAGE" and not main.dialogue.typing, 8.0),
			"maren: her package comes over the counter")
		reached(main.visit != null and main.visit.dropped and main.clipboard.entry_mark(maren_id) == "picked",
			"maren: the drop is in the till, and her entry is ticked off")
		rest()
		await d.seconds(0.3)
		await shot("maren-drop")
		d.hang_list()
		await d.settle()
		await d.request_tool("grip")
		await hold_grip("")
		await shot("maren-grip-late")
		await d.settle()
		await d.request_tool("penlight")
		await d.sweep_eyes()
		await d.seconds(0.4)
		await shot("maren-penlight")
		await d.put_away()
		await d.request_tool("port")
		await d.watch_port()
		await d.seconds(0.3)
		await shot("maren-port")
		await d.put_away()
	await d.press()
	await d.seconds(0.5)
	if not brief:
		await shot("maren-press-blank")
	await d.settle()
	var due := blows_due()
	await d.press()
	await turn_shots("maren", due)
	await through_shots("maren")


# ================================================================ shift 2

## A flare: Kip loses his temper over the light, knocks the close-up out of the doctor's hand and
## slams the counter. No red bar comes up, and the first flare of a session brings the tip that
## says so. The doctor drops the shutter anyway: the armed shutter, and a false alarm on a steady
## patient. Nothing came in for the hour, so it is under the line, and the meter says so; the
## fine for the false alarm waits for the report.
func kip_false_alarm() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	# cued: a flare is due on the first action (see the header)
	var was: Dictionary = pin_rules({"flare": {"grace": 0, "chance": 1.0}})
	main.visit.surprises = true
	reached(await d.request_tool("penlight") == "open", "kip-2: the penlight close-up opens")
	d.move(d.in_window(Vector2(60, 86)))
	reached(await d.until(func() -> bool: return main.visit != null and main.visit.flared, 5.0), "kip-2: he flares over the light")
	restore_rules(was)
	if main.visit != null:
		main.visit.surprises = false
	await d.seconds(0.06)
	await shot("kip-2-flare-torn")
	await d.seconds(0.25)
	await shot("kip-2-flare-slam")
	reached(await d.until(func() -> bool: return main._base_hint == MainScript.FLARE_COACH_HINT, 6.0),
		"kip-2: the tip says a flare is only temper")
	await d.settle()
	reached(main.state == MainScript.State.EXAM and not main._telegraphed and not main.clinic.scope.is_open(),
		"kip-2: the close-up is gone, no red bar is up, and the exam goes on")
	rest()
	await d.seconds(0.3)
	await shot("kip-2-flare-tip")
	d.shutter_key()
	await d.seconds(0.3)
	await shot("kip-shutter-armed")
	d.shutter_key()
	await d.wait_for_slip()
	await shot("kip-false-alarm")
	await slip_then_meter("meter-under-the-line")


## Trauma Team is called on Vale behind whole glass and nobody touches the shutter: three blows,
## then he is through, and the night ends with him.
func vale_gets_through() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	var due := blows_due()
	await d.call_team()
	await turn_shots("vale-2", due)
	await through_shots("vale-2")


# ================================================================ shift 3

## Kip's patience is spent on purpose. The last lamp goes out, he says he has to go and the
## lamps count down the wait he still gives; CALM holds him once; left alone the second
## time, he walks out by himself: no fee, no fine, and nothing in the till for the hour.
func kip_runs_out() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.press()
	await d.settle()
	await d.ask(0)
	await d.settle()
	await d.request_tool("penlight")
	await d.put_away()
	await d.request_tool("grip")
	await d.put_away()
	await d.settle()
	reached(main.visit != null and main.visit.patience == 1, "kip-3: one patience lamp is left")
	d.move(REST)
	await d.seconds(0.3)
	await shot("kip-3-last-lamp")
	await d.ask(1)
	reached(main.visit != null and main.visit.is_spent(), "kip-3: the last lamp goes out")
	reached(await d.until(func() -> bool: return main._leave_said and not main.dialogue.typing, 10.0), "kip-3: he says he has to go")
	d.move(REST)
	await d.seconds(0.5)
	await shot("kip-3-leaving")
	await d.reassure()
	await d.settle()
	reached(main.visit != null and main.visit.patience == 1 and not main._leave_said, "kip-3: CALM holds him")
	await shot("kip-3-held")
	await d.ask(2)
	d.move(REST)
	reached(await d.until(func() -> bool: return main._leave_said and main.clinic.leaving > 0.0 and main.clinic.leaving < 0.35, 16.0),
		"kip-3: the wait runs down a second time")
	await shot("kip-3-leaving-again")
	reached(await d.until(func() -> bool: return main.visit != null and main.visit.outcome == "gave_up", 8.0),
		"kip-3: he leaves by himself")
	await d.seconds(0.7)
	await shot("kip-3-walks-out")
	reached(await d.wait_for_slip(), "kip-3: the slip prints")
	await shot("kip-3-out-of-patience-slip")
	await slip_then_meter("meter-nothing-this-hour")


## A snap: nobody calls for Trauma Team. Vale gives a reason not to follow the light, the doctor
## insists, and in the middle of the test he comes at the glass: the close-up is knocked away, a
## short warning, then the red bar. The shutter comes down the moment it is up: no blow lands and
## the glass stays whole.
func vale_snaps() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	# cued: no flare at all, and then a snap due on the next action (see the header)
	main.visit.surprises = true
	var calm: Dictionary = pin_rules({"flare": {"chance": 0.0}})
	reached(await d.request_tool("penlight") == "refused", "vale-3: he gives a reason instead of following the light")
	await d.settle()
	var sure: Dictionary = pin_rules({"snap": {"grace": 0, "step": 1.0, "max": 1.0}})
	reached(await d.request_tool("penlight") == "open", "vale-3: insisting opens the penlight close-up")
	d.move(d.in_window(Vector2(60, 86)))
	await d.seconds(0.2)
	await shot("vale-3-insists")
	reached(await d.until(func() -> bool: return main.visit != null and main.visit.snapped, 6.0), "vale-3: he snaps in the middle of the test")
	restore_rules(sure)
	restore_rules(calm)
	if main.visit != null:
		main.visit.surprises = false
	await d.seconds(0.05)
	await shot("vale-3-snaps")
	await d.seconds(0.15)
	reached(main.state == MainScript.State.ATTACK and not main._telegraphed, "vale-3: the warning before the red bar")
	await shot("vale-3-snap-surge")
	reached(await d.wait_for_telegraph(), "vale-3: the red bar comes up")
	reached(blows_due() == 3, "vale-3: the glass is whole tonight")
	await d.seconds(0.04)
	await shot("vale-3-turns")
	await stopped_shots("vale-3")


## Maren is pressed twice behind whole glass and the shutter comes down after the third blow:
## stopped, but the pane has nothing left in it.
func maren_stopped_late() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.press()
	await d.settle()
	await d.press()
	await turn_shots("maren-3", 3)
	await stopped_shots("maren-3")


# ================================================================ shift 4

## Vale is called in behind whole glass and nobody touches the shutter until the third blow has
## landed: he is stopped, but the pane has nothing left in it and drops out behind the shutter.
## No frames: what comes after shows the empty frame.
func vale_breaks_the_pane(who: String) -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.call_team()
	reached(await d.wait_for_telegraph(), who + ": he turns")
	reached(await d.until(func() -> bool: return main._blows >= 3, 5.0), who + ": the third blow lands")
	d.shutter_key()
	reached(main.visit != null and main.visit.outcome == "caught", who + ": the shutter is in time")
	reached(await d.until(func() -> bool: return main.shift.glass_out, 6.0), who + ": the pane drops out behind the shutter")
	reached(await d.wait_for_slip(), who + ": the slip prints")
	await d.take_slip()


## Maren is pressed twice with no glass left: there is no blow to wait for and very little
## time, and the shutter comes down at once.
func maren_stopped_bare() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.press()
	await d.settle()
	reached(blows_due() == 0, "maren-4: no glass is left for this attack")
	await d.press()
	await turn_shots("maren-4", 0)
	await stopped_shots("maren-4")


# ================================================================ shift 5

## Between patients, with the frame empty: the GLASS key on the right wall is lit and shows its
## price, and each press has the fitter's arm bond one layer back. Three presses, a whole pane.
func glass_fitter() -> void:
	reached(await d.until(func() -> bool: return main.dialogue.speaker == "HALL CAMERA" and not main.dialogue.typing, 20.0),
		"glass: the strip is back to who waits in the hall")
	d.move(REST)
	await d.seconds(0.4)
	reached(main.shift.glass == 0 and main.shift.glass_out and main.desk.is_enabled("glass"), "glass: the frame is empty and the GLASS key is lit")
	await shot("glass-empty-frame")
	d.move(d.pad_pos("glass"))
	await d.seconds(0.3)
	await shot("glass-key-price")
	for layer in range(1, 4):
		if layer == 1:
			d.pad("glass")      # a click on the key
		else:
			d.key(KEY_G)        # or its letter
		reached(main.shift.glass == layer and not main.shift.glass_out, "glass: layer %d is bought" % layer)
		d.move(REST)
		reached(await d.until(func() -> bool: return main.dialogue.speaker == "GLASS" and not main.dialogue.typing, 6.0),
			"glass: the strip says what layer %d cost" % layer)
		await d.seconds(0.2)
		await shot("glass-layer-%d" % layer)
	d.move(d.pad_pos("glass"))
	await d.seconds(0.3)
	reached(not main.desk.is_enabled("glass") and main.shift.glass == main.shift.glass_max(), "glass: with the pane whole the key is dark")
	await shot("glass-key-nothing-to-mend")


## Maren is pressed twice behind the mended glass: the bar has all three marks again, and the
## shutter comes down before the first blow.
func maren_whole_bar() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.press()
	await d.settle()
	reached(blows_due() == 3, "maren-5: the mended glass has all three blows in it again")
	await d.press()
	reached(await d.wait_for_telegraph(), "maren-5: she turns")
	await d.seconds(0.04)
	await shot("maren-5-whole-bar")
	d.shutter_key()
	reached(main.visit != null and main.visit.outcome == "caught", "maren-5: the shutter is in time")
	reached(await d.wait_for_slip(), "maren-5: the slip prints")
	await shot("maren-5-stopped-slip")
	await d.take_slip()
