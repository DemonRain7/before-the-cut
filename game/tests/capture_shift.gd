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
## Four shifts are played, so that the opening, the guide, the booth walls, the hourly meter,
## the doctor's own marks, a patient who runs out of patience, every way an attack can end and
## the glass fitter are all seen:
##   shift 1: the opening cards, the hall camera's two monitors and the counter guide; Kip is
##            examined with the reference sheet and the intake card taken down from the walls,
##            ticked on the card, spoken to on the typing line and through push-to-talk (staged);
##            Rook's temper gets one cross; Vale gets two, is called in, turns, and is stopped
##            after the second blow (saw); Juno is seen thinking (staged); Maren gets through
##            what is left of the glass (torch)
##   shift 2: a false alarm puts the first hour under the line; Trauma Team takes Rook away; Vale
##            gets through whole glass (saw); Maren is stopped in time with no glass left (torch)
##   shift 3: Kip runs out of patience, is held once and then leaves by himself; Vale is stopped
##            before the first blow (saw); Maren is stopped after the third, with the glass gone (torch)
##   shift 4: Vale takes all three blows out of the pane before the shutter stops him, and the
##            pane drops out of its frame; between patients the till buys it back, one layer at a
##            time; Maren turns behind the mended glass and has the whole bar again; the report
##            says what the glass cost
## The glass belongs to the shift: a blow that lands in one attack leaves less time in the next.
## That is why the same two patients are seen with three blows, one blow and none.
##
## The push-to-talk frames and the thinking frames are staged: a stand-in answers in place of the
## patient AI service and the microphone is simulated. No device is opened, nobody is recorded and
## no service is called. On the push-to-talk frames the words on the line are the mock sentence,
## and the strip says so. On the thinking frames the stand-in keeps the answer back for three
## seconds and then has none, so the authored patient answers after all.
## Options after the "--":
##   --attacks-only   skip the opening, the guide and the examination shots, keep the attack scenes
##                    and the glass fitter
##   --less-blood     passed on to the game: the same scenes without the blood

const MainScript = preload("res://scripts/ui/main.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const PlayDriver = preload("res://tests/play_driver.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")

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
		return {"ok": true, "http_code": 200, "data": {"text": "This is a mock transcript. No speech service heard you.",
			"meta": {"mock": true, "provider": "stand-in"}}}


func _initialize() -> void:
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
		await shot("hall-camera")
		await kip()
		await rook()
		await vale_stopped(false)
		await juno()
		await maren_gets_through(false)
	await report_shot("report")
	# ---------------------------------------------------------------- shift 2
	await d.open_counter()
	if attacks_only:
		await quick("treat")
		await quick("treat", "rook-clean-window")
	else:
		await kip_false_alarm()
		await team_takes("rook", "rook-clean-window")
	await vale_gets_through()
	await quick("treat", "juno-behind-broken-window")
	await maren_stopped_bare()
	await report_shot("report-2")
	# ---------------------------------------------------------------- shift 3
	await d.open_counter()
	if attacks_only:
		await quick("treat")
	else:
		await kip_runs_out()
	await quick("treat")
	await vale_stopped_clean()
	await quick("treat", "juno-behind-whole-glass")
	await maren_stopped_late()
	await report_shot("report-3")
	# ---------------------------------------------------------------- shift 4
	await d.open_counter()
	await quick("treat")
	await quick("treat")
	await vale_breaks_the_pane()
	await glass_fitter()
	await quick("treat", "juno-behind-mended-glass")
	await maren_whole_bar()
	await report_shot("report-4")
	if dry:
		print("DRY RUN: %d frames would be captured, %d moments missed. Nothing was drawn or saved." % [count, missed])
	else:
		print("Captured %d frames to %s (%d moments missed)" % [count, output_dir, missed])
	await d.leave()
	quit(0 if missed == 0 else 1)


## The end-of-shift report, with the pointer beside the paper so that it covers none of the words.
func report_shot(stem: String) -> void:
	d.move(Vector2(580, 318))
	await d.seconds(1.2)
	await shot(stem)


## A moment a shot waits for. A miss is printed and counted, so a dry run shows a broken step.
func reached(ok: bool, what: String) -> void:
	if not ok:
		missed += 1
		print("MISSED %s" % what)


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


## The counter guide, which opens by itself at the first patient of a session: one frame a page
## (the window, the left wall, the right wall, the desk).
func guide_pages(who: String) -> void:
	reached(main.guide.is_open(), who + ": the counter guide opens by itself at the first patient")
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


## Nobody drops the shutter: the pane goes and they come through it.
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
	await d.until(func() -> bool: return main._slip_mode == "print", 10.0)
	await shot(who + "-aftermath")
	reached(await d.wait_for_slip(), who + ": the slip prints")
	await shot(who + "-hit-slip")
	await d.take_slip()
	# the counter afterwards; after the last patient the report is up instead, and it has its own frame
	if main.state != MainScript.State.REPORT:
		await d.seconds(1.6)
		await shot(who + "-after-slip")


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

## The first patient of the session: the hall camera's two monitors, the guide, the papers
## taken down from the walls, every way of examining, the doctor's own tick, the one-time tips
## on the hint row, the typing line and the staged push-to-talk, then TREAT and the meter's
## first reading.
func kip() -> void:
	# the small monitor on the left wall puts the hall on the big screen; a press on that lets him in
	d.move(d.thumb_pos())
	await d.seconds(0.3)
	await shot("hall-camera-hover")
	d.click(d.thumb_pos())
	d.move(Gfx.MONITOR.get_center() + Vector2(34, 22))
	await d.seconds(0.5)
	reached(d.cam_on() and main.state == MainScript.State.WAIT, "kip: the hall is on the big screen, and nobody is let in yet")
	await shot("hall-camera-big-screen")
	await d.buzz_in(true)
	await guide_pages("kip")
	d.move(REST)
	await d.seconds(0.5)
	reached(not d.sheet_down() and not d.card_down() and not d.cam_on(), "kip: nothing hangs in front of the window")
	await shot("kip-arrives")
	d.move(d.zone_pos("eyes"))
	await d.seconds(0.25)
	await shot("kip-hover-eyes")
	await d.look("eyes")
	await d.settle()
	await d.seconds(0.3)
	reached(str(main.desk.badges.get("card", "")) == "1", "kip: the card on the wall counts the note it has not shown")
	await shot("kip-look-eyes")
	# the reference sheet comes down from the left wall; its row for what the pointer is on lights up
	d.move(main.desk.object_rect("sheet").get_center())
	await d.seconds(0.3)
	await shot("kip-wall-sheet-hover")
	d.take_sheet()
	d.move(d.zone_pos("eyes"))
	await d.seconds(0.4)
	reached(d.sheet_down(), "kip: a click takes the reference sheet down")
	await shot("kip-sheet-down")
	# and the intake card from the right wall, with the note already on it
	d.move(main.desk.object_rect("card").get_center())
	await d.seconds(0.3)
	await shot("kip-wall-card-hover")
	d.take_card()
	d.move(d.mark_pos("eyes"))
	await d.seconds(0.3)
	reached(d.sheet_down() and d.card_down(), "kip: both papers are down at once")
	await shot("kip-hover-mark-box")
	d.mark("eyes")
	d.move(d.mark_pos("eyes") + Vector2(46, 18))      # off the box, so the tick is not under the hand
	await d.seconds(0.3)
	reached(main.visit != null and main.visit.ticked() == 1, "kip: one click on the box ticks the row")
	await shot("kip-mark-tick")
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
	await d.look("hands")
	await d.settle()
	await d.look("port")
	await d.settle()
	d.move(d.pad_pos("penlight"))
	await d.seconds(0.25)
	await shot("kip-hover-penlight")
	await d.request_tool("penlight")
	d.move(d.in_window(Vector2(60, 86)))
	await d.seconds(0.45)
	await shot("kip-penlight-right-eye")
	await d.sweep_eyes()
	await d.seconds(0.4)
	await shot("kip-penlight-left-eye")
	await d.request_tool("grip")
	await d.seconds(0.25)
	await shot("kip-grip-ready")
	await hold_grip("kip-grip-squeeze")
	await shot("kip-grip-result")
	await d.settle()
	await d.request_tool("port")
	await d.watch_port()
	await d.seconds(0.4)
	await shot("kip-port")
	await d.put_away()
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
	d.click(main.clipboard.decision_rect().get_center())
	d.move(REST_RIGHT)      # off the card, so that nothing on it is under the hand
	await d.seconds(0.3)
	await shot("kip-stamped")
	await d.wait_for_slip()
	await shot("kip-slip")
	await slip_then_meter("meter-over-the-line")


## Rook refuses, loses his temper and gets one cross for it: one broken line alone can be ordinary.
func rook() -> void:
	await d.settle()
	await shot("rook-camera")
	await d.buzz_in()
	await d.settle()
	await shot("rook-arrives")
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


## Juno's chrome looks worse than it is. She is seen thinking an answer over (staged).
func juno() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	reached(d.card_down(), "juno: the card is still down from the last visit, with her name on it now")
	await shot("juno-arrives")
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
	await d.ask(1)
	await d.settle()
	await d.press()
	await d.seconds(0.4)
	await shot("juno-press")
	await d.settle()
	await d.stamp("treat")
	d.move(REST_RIGHT)
	await d.wait_for_slip()
	await shot("juno-slip")
	await d.take_slip()


## Maren is pressed twice, turns, and nobody touches the shutter. The glass Vale left has one
## blow in it, so she is through after one.
func maren_gets_through(brief: bool) -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await shot("maren-arrives")
	if not brief:
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

## The armed shutter and a false alarm on a steady patient. The fine puts the first hour under
## the line, and the meter says so.
func kip_false_alarm() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	d.shutter_key()
	await d.seconds(0.3)
	await shot("kip-shutter-armed")
	d.shutter_key()
	await d.wait_for_slip()
	await shot("kip-false-alarm")
	await slip_then_meter("meter-under-the-line")


## Trauma Team is called on Vale behind whole glass and nobody touches the shutter: three blows,
## then he is through, and the pane is gone for the rest of the night.
func vale_gets_through() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	var due := blows_due()
	await d.call_team()
	await turn_shots("vale-2", due)
	await through_shots("vale-2")


## Maren is pressed twice with no glass left: there is no blow to wait for and very little
## time, and the shutter comes down at once.
func maren_stopped_bare() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.press()
	await d.settle()
	reached(blows_due() == 0, "maren-2: no glass is left for this attack")
	await d.press()
	await turn_shots("maren-2", 0)
	await stopped_shots("maren-2")


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


## Trauma Team is called on Vale and the shutter comes down the moment he turns: no blow lands
## and the glass stays whole.
func vale_stopped_clean() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.call_team()
	await turn_shots("vale-3", 0)
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
func vale_breaks_the_pane() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.call_team()
	reached(await d.wait_for_telegraph(), "vale-4: he turns")
	reached(await d.until(func() -> bool: return main._blows >= 3, 5.0), "vale-4: the third blow lands")
	d.shutter_key()
	reached(main.visit != null and main.visit.outcome == "caught", "vale-4: the shutter is in time")
	reached(await d.until(func() -> bool: return main.shift.glass_out, 6.0), "vale-4: the pane drops out behind the shutter")
	reached(await d.wait_for_slip(), "vale-4: the slip prints")
	await d.take_slip()


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
	reached(blows_due() == 3, "maren-4: the mended glass has all three blows in it again")
	await d.press()
	reached(await d.wait_for_telegraph(), "maren-4: she turns")
	await d.seconds(0.04)
	await shot("maren-4-whole-bar")
	d.shutter_key()
	reached(main.visit != null and main.visit.outcome == "caught", "maren-4: the shutter is in time")
	reached(await d.wait_for_slip(), "maren-4: the slip prints")
	await shot("maren-4-stopped-slip")
	await d.take_slip()
