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
## name of each frame it would save, saves nothing, and exits 1 if a moment it waits for never came.
## Use it to check this script without opening a window:
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd
##
## Two shifts are played so that both attackers are seen both ways:
##   shift 1: Kip is examined, spoken to on the typing line and through push-to-talk (staged);
##            Vale is stopped by the shutter (saw), Maren gets through (torch)
##   shift 2: Trauma Team takes Rook away, Vale gets through (saw), Maren is stopped by the shutter (torch)
## The push-to-talk frames are staged: a stand-in answers in place of the patient AI service and the
## microphone is simulated. No device is opened, nobody is recorded and no service is called; the
## words on the line are the mock sentence, and the strip says so.
## Options after the "--":
##   --attacks-only   skip the detailed examination shots, keep the attack scenes
##   --less-blood     passed on to the game: the same scenes without the blood

const MainScript = preload("res://scripts/ui/main.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const PlayDriver = preload("res://tests/play_driver.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")

var main: MainScript = null
var d: PlayDriver = null
var output_dir: String = ""
var count: int = 0
var attacks_only: bool = false
var dry: bool = false              # headless: nothing is drawn, so nothing is saved
var missed: int = 0                # moments a new shot waited for that never came


## Stands in for the patient AI service in the staged push-to-talk frames. It answers a clip, and
## only when told to, with the sentence the proxy's mock transport uses. It never answers as a patient.
class StandInClient:
	extends RefCounted
	signal released

	func is_configured() -> bool:
		return true

	func request_move(_payload: Dictionary) -> Dictionary:
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
	create_timer(900.0, true, false, true).timeout.connect(_on_watchdog)
	_run()


func _on_watchdog() -> void:
	print("RESULT: the capture run did not finish (%d frames saved)." % count)
	quit(2)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate() as MainScript
	main.authored_order = true      # the checks below follow the listed order of patients
	root.add_child(main)
	await process_frame
	main.set_process_input(false)      # only the driver moves the pointer during a capture run
	main.audio.set_muted(true)
	main.mic.simulated = true          # a capture run never opens a microphone
	d = PlayDriver.new(self, main)
	main.event_log.write("automated_run", {"runner": "tests/capture_shift.gd"})
	d.move(Vector2(330, 250))
	await d.seconds(0.6)
	if not attacks_only:
		await shot("title")
	# ---------------------------------------------------------------- shift 1
	await d.open_counter()
	await d.settle()
	if attacks_only:
		await quick("treat")
		await quick("treat")
		await vale_stopped(true)
		await quick("treat", "juno-behind-cracked-glass")
		await maren_gets_through(true)
	else:
		await shot("hall-camera")
		await kip()
		await rook()
		await vale_stopped(false)
		await juno()
		await maren_gets_through(false)
	await d.seconds(1.2)
	await shot("report")
	# ---------------------------------------------------------------- shift 2
	await d.open_counter()
	if attacks_only:
		await quick("treat")
	else:
		# the armed shutter and a false alarm
		await d.buzz_in()
		await d.settle()
		d.shutter_key()
		await d.seconds(0.3)
		await shot("kip-shutter-armed")
		d.shutter_key()
		await d.wait_for_slip()
		await shot("kip-false-alarm")
		await d.take_slip()
	if attacks_only:
		await quick("treat", "rook-clean-window")
	else:
		await team_takes("rook", "rook-clean-window")
	await vale_gets_through()
	await quick("treat", "juno-behind-broken-window")
	await maren_stopped()
	await d.seconds(1.2)
	await shot("report-2")
	if dry:
		print("DRY RUN: %d frames would be captured, %d moments missed. Nothing was drawn or saved." % [count, missed])
	else:
		print("Captured %d frames to %s (%d moments missed)" % [count, output_dir, missed])
	main.event_log.stop()
	main.queue_free()
	await process_frame
	quit(0 if missed == 0 else 1)


## A moment a shot waits for. A miss is printed and counted, so a dry run shows a broken step.
func reached(ok: bool, what: String) -> void:
	if not ok:
		missed += 1
		print("MISSED %s" % what)


func shot(stem: String) -> void:
	count += 1
	await process_frame
	var file := "%02d-%s.png" % [count, stem]
	if dry:
		print("DRY %s" % file)
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


# ================================================================ the attack scenes

## The silent beat, the turn, and the blows on the glass up to blow `upto`.
func turn_shots(who: String, upto: int) -> void:
	await d.until(func() -> bool: return main.state == MainScript.State.ATTACK and main.clinic.flicker > 0.0, 20.0)
	await d.seconds(0.3)
	await shot(who + "-beat")
	await d.wait_for_telegraph()
	await d.seconds(0.04)
	await shot(who + "-turns")
	for n in range(1, upto + 1):
		await d.until(func() -> bool: return main._blows >= n, 4.0)
		await d.seconds(0.05)
		await shot("%s-blow-%d" % [who, n])
		if n == 2:
			await d.seconds(0.25)
			await shot(who + "-weapon-on-glass")


## The shutter is dropped now: what it lands on, the dents, and the weapon coming through.
func stopped_shots(who: String) -> void:
	d.shutter_key()
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
	await d.wait_for_slip()
	await shot(who + "-stopped-slip")
	await d.take_slip()


## Nobody drops the shutter: the pane goes and they come through it.
func through_shots(who: String) -> void:
	await d.until(func() -> bool: return main.state != MainScript.State.ATTACK, 6.0)
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
	await d.wait_for_slip()
	await shot(who + "-hit-slip")
	await d.take_slip()
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
## words are on their way, and when they are on the line for the doctor to check. Nothing is said to
## the patient: ESC takes the sentence back, and the visit goes on as the offline comparison.
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


# ================================================================ the five visits

func kip() -> void:
	await d.buzz_in()
	await d.seconds(0.5)
	await shot("kip-arrives")
	d.move(d.zone_pos("eyes"))
	await d.seconds(0.25)
	await shot("kip-hover-eyes")
	await d.look("eyes")
	await d.settle()
	await d.seconds(0.3)
	await shot("kip-look-eyes")
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
	d.move(Vector2(120, 255))
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
	await d.reassure()
	await d.settle()
	await shot("kip-reassured")
	await typed_line("kip", "Is the night shift hard on you?")
	await staged_voice("kip")
	d.pad("treat")
	await process_frame
	d.move(Vector2(560, 222))
	await d.seconds(0.25)
	await shot("kip-stamp-in-hand")
	d.click(main.clipboard.DECISION.get_center())
	await d.seconds(0.3)
	await shot("kip-stamped")
	await d.wait_for_slip()
	await shot("kip-slip")
	await d.take_slip()


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
	d.pad("refer")
	await d.seconds(0.3)
	await shot("vale-call-line-open")
	d.pad("refer")
	await d.seconds(0.3)
	await shot("vale-team-called")
	await turn_shots("vale", 2)
	await stopped_shots("vale")


## Trauma Team is called on Vale again in the second shift and nobody touches the shutter.
func vale_gets_through() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.call_team()
	await turn_shots("vale-2", 3)
	await through_shots("vale")


func juno() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await shot("juno-arrives")
	await d.look("eyes")
	await d.settle()
	await shot("juno-look-eyes")
	await d.request_tool("penlight")
	await d.sweep_eyes()
	await d.seconds(0.4)
	await shot("juno-penlight")
	await d.put_away()
	await d.ask(1)
	await d.settle()
	await shot("juno-deflects")
	await d.ask(1)
	await d.settle()
	await d.press()
	await d.seconds(0.4)
	await shot("juno-press")
	await d.settle()
	await d.stamp("treat")
	await d.wait_for_slip()
	await shot("juno-slip")
	await d.take_slip()


## Maren is pressed twice, turns, and nobody touches the shutter.
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
	await d.press()
	await turn_shots("maren", 3)
	await through_shots("maren")


## Maren is pressed twice in the second shift and the shutter comes down after the third blow.
func maren_stopped() -> void:
	await d.settle()
	await d.buzz_in()
	await d.settle()
	await d.press()
	await d.settle()
	await d.press()
	await turn_shots("maren-2", 3)
	await stopped_shots("maren")
