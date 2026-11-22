extends SceneTree
## Plays one test night through the real game at normal speed, for a screen recording. The
## pointer glides to each control before it clicks, every visitor is examined on the part they
## complain about, and the night ends the way any night does: the closing film plays by itself,
## then the report. This is an agent-operated run with scripted inputs, not a playtest.
##   -- --test-night=K --plan=treat,treat,treat,refer,treat [--lang=zh] [--less-blood]
## --plan is the doctor's call for each visitor in order: treat (stamp the card), refer (call
## Trauma Team, and drop the shutter on the first warning if the visitor turns on the call) or
## press (push until the visit ends, and never drop the shutter: a drifting visitor then kills the
## doctor at the glass and the night ends there). The game reads --test-night,
## --lang and --less-blood itself.
## Record it with Godot's Movie Maker on a hidden desktop (Windows), from the repository root:
##   python tools/run_hidden.py --timeout 900 -- <Godot GUI executable> --fixed-fps 30
##       --write-movie <absolute path>.avi --path game --script res://tests/record_night.gd
##       -- --test-night=K --plan=treat,treat,treat,refer,treat --lang=zh
## Without --write-movie (and with --headless) it plays the same night and prints what happened.
const MainScript = preload("res://scripts/ui/main.gd")
const Driver = preload("res://tests/play_driver.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")

var main: MainScript = null
var d: Driver = null
var ok := true


func _initialize() -> void:
	call_deferred("_record")


func _record() -> void:
	var plan: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			plan = arg.trim_prefix("--plan=").split(",", false)
	main = load("res://scenes/main.tscn").instantiate()
	main.training_enabled = false
	main.surprises_enabled = false
	main.beats_enabled = false
	root.add_child(main)
	await process_frame
	if main._patient_status == "checking":
		await main.patient_check_finished
	d = Driver.new(self, main)
	await d.seconds(1.5)                                  # the title card
	await glide(main.screens.menu_rect(main.screens.MENU.find("start")).get_center())
	_need(await d.open_counter(), "the counter opens")
	if main.shift == null:
		quit(1)
		return
	var i := 0
	while ok and main.state != MainScript.State.AFTERMATH and main.state != MainScript.State.REPORT:
		if i >= plan.size():
			_need(false, "--plan has a call for every visitor who comes in")
			break
		await visit(str(plan[i]))
		i += 1
	if ok:
		# the closing film runs by itself at normal speed, as it does after every last slip
		_need(main.state == MainScript.State.AFTERMATH or main.state == MainScript.State.REPORT, "the closing film starts when the night ends")
		var shots: Array = []
		for shot in main.reel.shots:
			shots.append("%s %s %s" % [shot.kind, shot.id, shot.get("outcome", "")])
		print("Film: ", ", ".join(shots))
		_need(await d.wait_through_film(), "the report comes up after the film")
		await d.seconds(2.5)
		# read the report: each visitor's page, then the night's totals
		var turned := 0
		while main.state == MainScript.State.REPORT and not main.screens.on_summary() and turned < 8:
			await glide(Vector2(320, 200), 0.2)
			d.click(Vector2(320, 200))
			turned += 1
			await d.seconds(1.6)
		await d.seconds(2.5)
	for rec in main.shift.records:
		print("%s: %s, %s" % [rec.get("case_id", ""), rec.get("outcome", ""), "right" if rec.get("correct", false) else "wrong"])
	print("RESULT: ", "the night was played to the report" if ok else "the run stopped early")
	await d.leave()
	quit(0 if ok else 1)


## One appointment: buzz the visitor in, hear the complaint, test the part they name, make the
## call and tear off the slip (unless the visitor ended the night at the glass).
func visit(call: String) -> void:
	await d.seconds(0.8)
	if not d.cam_on():
		await glide(d.thumb_pos())
		d.click(d.thumb_pos())
		await d.seconds(0.6)
	await glide(Gfx.MONITOR.get_center())
	_need(await d.buzz_in(), "a visitor comes to the counter")
	if not ok:
		return
	var v = main.visit
	await d.settle(30.0)
	await d.seconds(1.0)
	await glide(d.pad_pos("complain"))
	d.pad("complain")
	await d.settle(30.0)
	await d.seconds(1.2)
	for row in v.complaints_told.duplicate():
		if v.patience <= 0 or not v.in_exam():
			break
		await examine(str(row))
	await d.seconds(0.8)
	if call == "press":
		await push_until_it_ends()
	elif call == "refer":
		await glide(d.pad_pos("refer"))
		d.pad("refer")
		await d.seconds(0.7)
		d.pad("refer")
		# some turn on the call: the shutter comes down at the first warning, as the guide teaches
		if await d.until(func() -> bool: return main._telegraphed or main.state == MainScript.State.SLIP, 15.0) and main._telegraphed:
			await d.seconds(0.3)
			d.shutter_key()
	else:
		await glide(d.pad_pos("treat"))
		d.pad("treat")
		await d.seconds(0.5)
		await glide(main.clipboard.decision_rect().get_center())
		d.click(main.clipboard.decision_rect().get_center())
	# a lunge that nobody stops ends the night at the glass; anything else prints a slip
	_need(await d.until(func() -> bool:
		return main.state == MainScript.State.AFTERMATH or (main.state == MainScript.State.SLIP and main._slip_age > 0.6), 60.0), "the visit is settled")
	if main.state != MainScript.State.SLIP:
		return
	await d.seconds(1.8)
	await glide(MainScript.SLIP_CLIP.get_center())
	# after the last slip this waits through the closing film; stop at its start instead
	d.click(MainScript.SLIP_CLIP.get_center())
	_need(await d.until(func() -> bool:
		return (main.state == MainScript.State.WAIT and main.clinic.cam_prompt) or main.state in [MainScript.State.REPORT, MainScript.State.AFTERMATH], 40.0), "the slip is taken")


## Pushes until the visit ends, the way a doctor who will not let go does. The fourth push always
## ends it; the game asks for a confirmation first, and it is given.
func push_until_it_ends() -> void:
	for n in 6:
		if main.visit == null or not main.visit.in_exam():
			return
		await glide(d.pad_pos("press"))
		await d.press()
		await d.settle(30.0)
		await d.seconds(1.0)


## Tests one complained-about part with its own tool, slowly enough to be seen.
func examine(row: String) -> void:
	var tool: String = main.CaseDB.ROW_TOOL.get(row, "")
	if tool == "" or tool == "press" or tool == "ask":
		return
	await glide(d.pad_pos(tool))
	if await d.request_tool(tool) != "open":
		await d.settle()
		return
	await d.seconds(0.5)
	match tool:
		"penlight":
			await glide(d.in_window(Vector2(60, 86)), 0.4)
			await d.seconds(0.9)
			await glide(d.in_window(Vector2(160, 86)), 0.5)
			await d.seconds(0.9)
		"grip":
			var p: Vector2 = d.in_window(Vector2(110, 100))
			await glide(p, 0.4)
			main.pointer_down(p, MOUSE_BUTTON_LEFT)
			await d.seconds(1.2)
			main.pointer_up(p, MOUSE_BUTTON_LEFT)
			await d.seconds(0.6)
		"port":
			await glide(d.in_window(Vector2(110, 90)), 0.5)
			await d.seconds(1.6)
	await d.seconds(1.0)
	await d.put_away()
	await d.settle()
	await d.seconds(0.4)


## Moves the game's pointer to `to` over `time` seconds, as a hand would.
func glide(to: Vector2, time: float = 0.3) -> void:
	var from: Vector2 = main._mouse
	var t := 0.0
	while t < time:
		await process_frame
		t += main.get_process_delta_time()
		var k := clampf(t / time, 0.0, 1.0)
		main.pointer_move(from.lerp(to, k * k * (3.0 - 2.0 * k)))
	main.pointer_move(to)


func _need(value: bool, what: String) -> void:
	if not value:
		ok = false
		push_error("record_night: missed: " + what)
