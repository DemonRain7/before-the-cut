extends RefCounted
## Plays the real screen the way a person does. Every step goes through the director's own
## pointer and key entry points, at the positions a player would click, so a run exercises
## hit-testing and the input rules as well as the game rules.
## Shared by tests/run_ui_smoke.gd (headless checks) and tests/capture_shift.gd (screenshots).
## Used as: const PlayDriver = preload("res://tests/play_driver.gd")

const MainScript = preload("res://scripts/ui/main.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")
const ScopeView = preload("res://scripts/ui/scope_view.gd")

var tree: SceneTree = null
var main: MainScript = null


func _init(p_tree: SceneTree, p_main: MainScript) -> void:
	tree = p_tree
	main = p_main


# ------------------------------------------------------------------ time

## Game-time seconds. They pass faster when Engine.time_scale is raised.
func seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await tree.process_frame
		left -= main.get_process_delta_time()


## Waits until cond() is true, for at most `limit` game seconds. Returns whether it became true.
func until(cond: Callable, limit: float = 30.0) -> bool:
	var left := limit
	while left > 0.0:
		if bool(cond.call()):
			return true
		await tree.process_frame
		left -= main.get_process_delta_time()
	return bool(cond.call())


# ------------------------------------------------------------------ raw input

func move(pos: Vector2) -> void:
	main.pointer_move(pos)


func click(pos: Vector2) -> void:
	main.pointer_move(pos)
	main.pointer_down(pos, MOUSE_BUTTON_LEFT)
	main.pointer_up(pos, MOUSE_BUTTON_LEFT)


func right_click() -> void:
	main.pointer_down(main._mouse, MOUSE_BUTTON_RIGHT)
	main.pointer_up(main._mouse, MOUSE_BUTTON_RIGHT)


func key(code: int, unicode: int = 0) -> void:
	main.key_down(code, unicode)


## Types a sentence the way a keyboard does: one key per character, with what it prints.
## (Godot's key codes for printable ASCII are the upper-case ASCII codes.)
func type_text(text: String) -> void:
	for i in text.length():
		main.key_down(text[i].to_upper().unicode_at(0), text.unicode_at(i))


## Opens the typing line with T, types the sentence and says it with ENTER.
func say(text: String) -> void:
	key(KEY_T, 116)
	type_text(text)
	key(KEY_ENTER)
	await tree.process_frame


func key_release(code: int) -> void:
	main.key_up(code)


## A steady tone as a microphone would deliver it: `sound` seconds at the simulated card's rate.
func tone(sound: float, loudness: float = 0.3) -> PackedVector2Array:
	var rate: float = main.mic.simulated_rate
	var frames := PackedVector2Array()
	frames.resize(int(round(sound * rate)))
	for i in frames.size():
		var s: float = sin(TAU * 220.0 * float(i) / rate) * loudness
		frames[i] = Vector2(s, s)
	return frames


## Holds the speak key the way a player with a microphone does: key down, `sound` seconds heard
## at `loudness`, the key kept down for `hold` game seconds in all, key up.
## Only for a simulated microphone: a run never opens a device and never records anybody.
func speak(sound: float = 0.8, loudness: float = 0.3, hold: float = 0.6) -> void:
	if not main.mic.simulated:
		push_error("PlayDriver.speak() is for a simulated microphone only")
		return
	key(KEY_TAB)
	if main.mic.listening and sound > 0.0:
		main.mic.feed(tone(sound, loudness))
	await seconds(hold)
	key_release(KEY_TAB)
	await tree.process_frame


func pad_pos(id: String) -> Vector2:
	return main.desk.pad_rect(id).get_center()


func pad(id: String) -> void:
	click(pad_pos(id))


## A part of the patient, on the screen. The patient is drawn through the window at twice the size.
func zone_pos(zone: String) -> Vector2:
	return Gfx.to_screen(main.rig.zone_rect(zone).get_center()) if main.rig != null else Vector2.ZERO


## A point of a tool's close-up (given in its own 220 x 186 picture), on the screen.
func in_window(local: Vector2) -> Vector2:
	return ScopeView.ORIGIN + local * ScopeView.SCALE


# ------------------------------------------------------------------ the booth walls

func sheet_down() -> bool:
	return main.clipboard.sheet_open


func card_down() -> bool:
	return main.clipboard.card_open


func cam_on() -> bool:
	return main.clinic.cam_open


func list_down() -> bool:
	return main.clipboard.list_open


## Takes the reference sheet down from the left wall, the way a player does: a click on it.
## The sheet and tonight's contact list hang on one hook, so with the list down it is the
## swap tab under the list's own tab that brings the sheet.
func take_sheet() -> void:
	if sheet_down():
		return
	if list_down():
		swap()
	else:
		click(main.desk.object_rect("sheet").get_center())


## Takes tonight's contact list down (with the sheet down, through the swap tab).
func take_list() -> void:
	if list_down():
		return
	if sheet_down():
		swap()
	else:
		click(main.desk.object_rect("list").get_center())


func hang_list() -> void:
	if list_down():
		click(main.clipboard.list_tab().get_center())


## The tab under the sheet's or the list's: trades the one that is down for the other.
func swap() -> void:
	click(main.clipboard.swap_tab().get_center())


## Where the SAY button of one of tonight's entries is, or (-1, -1) if it is not on the list.
func say_pos(entry_id: String) -> Vector2:
	for i in main.clipboard.contacts.size():
		if str((main.clipboard.contacts[i] as Dictionary).get("id", "")) == entry_id:
			return main.clipboard.say_rect(i).get_center()
	return Vector2(-1, -1)


## Says an entry's code: the list comes down, and once it is all the way out the SAY button
## beside the entry is pressed. Returns once the exchange is over.
func say_code(entry_id: String) -> void:
	take_list()
	await until(func() -> bool: return main.clipboard._list_k >= 1.0, 3.0)
	click(say_pos(entry_id))
	await tree.process_frame
	await until(func() -> bool: return not main._lock, 10.0)


## Takes the intake card down from the right wall.
func take_card() -> void:
	if not card_down():
		click(main.desk.object_rect("card").get_center())


## Hangs a paper back with the tab on its edge.
func hang_sheet() -> void:
	if sheet_down():
		click(main.clipboard.sheet_tab().get_center())


func hang_card() -> void:
	if card_down():
		click(main.clipboard.card_tab().get_center())


## The small hall monitor on the left wall.
func thumb_pos() -> Vector2:
	return Gfx.THUMB.get_center()


## Hangs back whatever paper or screen is in front of a point, as a player has to before
## clicking what is behind it.
func uncover(pos: Vector2) -> void:
	match main._panel_at(pos):
		"sheet":
			hang_sheet()
		"list":
			hang_list()
		"card":
			hang_card()
		"cam":
			key(KEY_C)


## The player's own tick-or-cross box beside a row of the intake record.
func mark_pos(row: String) -> Vector2:
	return main.clipboard.mark_point(row)


## One click on that box: blank -> tick -> cross -> blank. The card has to be down from the
## wall for that, so it is taken down first if it is still hanging there.
func mark(row: String) -> void:
	take_card()
	click(mark_pos(row))


# ------------------------------------------------------------------ the shift

func in_exam() -> bool:
	return main.state == MainScript.State.EXAM


## Title or report card -> the hall camera is asking to buzz the first patient in.
## The title card's menu is left by its START, after ESC back to the menu from HOW TO PLAY or
## SETTINGS. The report opens on the first visit's page; ESC goes straight to the night's
## totals, the way a player skips it, and a click there starts the next night.
## The opening cards play once a session after the title. They are skipped here the way a
## player skips them, with ESC. With `watch_intro` the call returns as soon as the cards are
## up: the caller steps through them and then waits with wait_for_counter().
func open_counter(watch_intro: bool = false) -> bool:
	if main.state == MainScript.State.TITLE:
		if main.screens.mode != "title":
			key(KEY_ESCAPE)
			await tree.process_frame
		click(main.screens.menu_rect(main.screens.MENU.find("start")).get_center())
	else:
		if main.state == MainScript.State.REPORT:
			if not main.screens.on_summary():
				key(KEY_ESCAPE)
				await tree.process_frame
			await until(func() -> bool: return main.screens.age() >= 0.85, 3.0)
		click(Vector2(320, 300))
	await tree.process_frame
	if in_intro():
		if watch_intro:
			return true
		key(KEY_ESCAPE)
	return await wait_for_counter()


func in_intro() -> bool:
	return main.state == MainScript.State.INTRO


func wait_for_counter(limit: float = 12.0) -> bool:
	return await until(func() -> bool: return main.state == MainScript.State.WAIT and main.clinic.cam_prompt, limit)


## Buzzes in whoever is on the hall camera. The counter guide opens by itself at a session's
## first patient when the first-night training is off; it is closed here the way a player
## closes it, with ESC, unless `keep_guide` is set (the caller then turns its pages).
func buzz_in(keep_guide: bool = false) -> bool:
	# the small monitor puts the hall on the big screen; a press on that buzzes them in
	if not cam_on():
		click(thumb_pos())
	click(Gfx.MONITOR.get_center())
	var ok: bool = await until(func() -> bool: return main.state == MainScript.State.EXAM, 12.0)
	if ok and not keep_guide and main.guide.is_open():
		key(KEY_ESCAPE)
		await tree.process_frame
	return ok


## Lets the lines on screen finish.
func settle(limit: float = 12.0) -> void:
	await until(func() -> bool: return not main.dialogue.typing and not main._thinking and not main._lock, limit)


func look(zone: String) -> void:
	uncover(zone_pos(zone))
	click(zone_pos(zone))
	await tree.process_frame


## Picks a tool up. Returns "open" when the close-up opened, otherwise the tool's status
## after the patient's answer: "refused" or "fresh".
func request_tool(tool: String) -> String:
	pad(tool)
	await tree.process_frame
	# The proxy timeout runs in real time even when the test speeds up the game clock.
	if not await until(func() -> bool: return not main._thinking and main.dialogue.speaker != "YOU"):
		return "stuck"
	if main.visit == null:
		return "gone"
	if main.visit.granted.has(tool):
		var opened: bool = await until(func() -> bool: return main.clinic.scope.is_open() and main.clinic.scope.tool == tool, 10.0)
		return "open" if opened else "stuck"
	await until(func() -> bool: return not main.dialogue.typing, 10.0)
	return main.visit.check_status(tool)


func sweep_eyes() -> bool:
	move(in_window(Vector2(60, 86)))
	await seconds(0.75)
	move(in_window(Vector2(160, 86)))
	await seconds(0.75)
	return await until(func() -> bool: return main.visit != null and main.visit.seen.has("check:penlight"), 3.0)


func squeeze_and_release(hold: float = 0.8) -> bool:
	var p := in_window(Vector2(110, 100))
	main.pointer_move(p)
	main.pointer_down(p, MOUSE_BUTTON_LEFT)
	await seconds(hold)
	main.pointer_up(p, MOUSE_BUTTON_LEFT)
	return await until(func() -> bool: return main.visit != null and main.visit.seen.has("check:grip"), 4.0)


func watch_port() -> bool:
	move(in_window(Vector2(110, 90)))
	return await until(func() -> bool: return main.visit != null and main.visit.seen.has("check:port"), 3.0)


func put_away() -> void:
	right_click()
	await tree.process_frame


## Opens the question list and picks the question at `index`.
func ask(index: int) -> void:
	if not main.dialogue.has_menu():
		pad("ask")
		await tree.process_frame
	click(main.dialogue.menu_point(index))
	await tree.process_frame
	await until(func() -> bool: return not main._thinking and main.dialogue.speaker != "YOU", 12.0)


func complain() -> void:
	main.act_complain()
	await settle(30.0)


## Says the provocative line and waits for the reaction to begin.
func press() -> void:
	pad("press")
	if main._break_confirmation:
		key(KEY_ENTER)
	await tree.process_frame
	await until(func() -> bool: return not main._lock, 10.0)
	await tree.process_frame


## Picks the TREAT stamp up from the wall plate and brings it down on the intake card, which
## comes down from the wall by itself while the stamp is in hand.
## The other decision is not a stamp: stamp("refer") goes to the call box instead.
func stamp(kind: String) -> void:
	if kind == "refer":
		await call_team()
		return
	pad(kind)
	await tree.process_frame
	click(main.clipboard.decision_rect().get_center())
	await tree.process_frame


## The Trauma Team call box: one press opens the line, the second sends the crew.
func call_team() -> void:
	pad("refer")
	await tree.process_frame
	pad("refer")
	await tree.process_frame


func shutter_key() -> void:
	key(KEY_SPACE)


func wait_for_telegraph(limit: float = 20.0) -> bool:
	return await until(func() -> bool: return main._telegraphed, limit)


func wait_for_slip(limit: float = 30.0) -> bool:
	return await until(func() -> bool: return main.state == MainScript.State.SLIP and main._slip_age > 0.6, limit)


## Ends a run the way the game closes its window: every sound stops, and the audio thread gets
## a moment of wall-clock time to let go of them (a run at a fixed frame rate turns frames far
## faster than a sound plays). A sound still playing when the engine shuts down is reported as
## leaked, although nothing is wrong with the game.
func leave() -> void:
	main.audio.set_muted(true)
	main.audio.stop_all()
	await tree.process_frame
	OS.delay_msec(250)
	main.event_log.stop()
	main.queue_free()
	await tree.process_frame


## Tears the slip off. Returns once the next patient is on the camera or the report is up.
func take_slip() -> bool:
	click(MainScript.SLIP_CLIP.get_center())
	return await until(func() -> bool:
		return (main.state == MainScript.State.WAIT and main.clinic.cam_prompt) or main.state == MainScript.State.REPORT, 38.0)


## Waits for the end-of-night report: after the last slip, or out of the dark when a blow
## landed and the night ended early.
func wait_for_report(limit: float = 30.0) -> bool:
	return await until(func() -> bool: return main.state == MainScript.State.REPORT, limit)


## Reads the report the way a player does: a click on each page once it has been up long
## enough to turn, until the night's totals. Returns how many pages were turned.
func read_report(limit: int = 12) -> int:
	var turned := 0
	while main.state == MainScript.State.REPORT and not main.screens.on_summary() and turned < limit:
		await until(func() -> bool: return main.screens.age() >= MainScript.REPORT_TURN + 0.05, 3.0)
		click(Vector2(320, 200))
		await tree.process_frame
		turned += 1
	return turned
