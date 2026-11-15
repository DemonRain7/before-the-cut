extends RefCounted
## Plays the real screen the way a person does. Every step goes through the director's own
## pointer and key entry points, at the positions a player would click, so a run exercises
## hit-testing and the input rules as well as the game rules.
## Shared by tests/run_ui_smoke.gd (headless checks) and tests/capture_shift.gd (screenshots).
## Used as: const PlayDriver = preload("res://tests/play_driver.gd")

const MainScript = preload("res://scripts/ui/main.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")

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


func zone_pos(zone: String) -> Vector2:
	return main.rig.zone_rect(zone).get_center() if main.rig != null else Vector2.ZERO


func in_window(local: Vector2) -> Vector2:
	return Gfx.HOLE.position + local


# ------------------------------------------------------------------ the shift

func in_exam() -> bool:
	return main.state == MainScript.State.EXAM


## Title or report card -> the hall camera is asking to buzz the first patient in.
func open_counter() -> bool:
	if main.state == MainScript.State.REPORT:
		await until(func() -> bool: return main.screens.age() >= 0.85, 3.0)
	click(Vector2(320, 300))
	return await until(func() -> bool: return main.state == MainScript.State.WAIT and main.clinic.cam_prompt, 12.0)


func buzz_in() -> bool:
	click(Gfx.MONITOR.get_center())
	return await until(func() -> bool: return main.state == MainScript.State.EXAM, 12.0)


## Lets the lines on screen finish.
func settle(limit: float = 12.0) -> void:
	await until(func() -> bool: return not main.dialogue.typing and not main._thinking and not main._lock, limit)


func look(zone: String) -> void:
	click(zone_pos(zone))
	await tree.process_frame


## Picks a tool up. Returns "open" when the close-up opened, otherwise the tool's status
## after the patient's answer: "refused" or "fresh".
func request_tool(tool: String) -> String:
	pad(tool)
	await tree.process_frame
	await until(func() -> bool: return not main._thinking and main.dialogue.speaker != "YOU", 12.0)
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
	click(Vector2(120.0, 240.0 + 10.0 * float(index) + 5.0))
	await tree.process_frame
	await until(func() -> bool: return not main._thinking and main.dialogue.speaker != "YOU", 12.0)


func reassure() -> void:
	pad("calm")
	await tree.process_frame
	await until(func() -> bool: return not main._lock, 8.0)


## Says the provocative line and waits for the reaction to begin.
func press() -> void:
	pad("press")
	await tree.process_frame
	await until(func() -> bool: return not main._lock, 10.0)
	await tree.process_frame


## Picks the TREAT stamp up from the desk and brings it down on the intake card.
## The other decision is not a stamp: stamp("refer") goes to the call box instead.
func stamp(kind: String) -> void:
	if kind == "refer":
		await call_team()
		return
	pad(kind)
	await tree.process_frame
	click(main.clipboard.DECISION.get_center())
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


## Tears the slip off. Returns once the next patient is on the camera or the report is up.
func take_slip() -> bool:
	click(Vector2(280, 300))
	return await until(func() -> bool:
		return (main.state == MainScript.State.WAIT and main.clinic.cam_prompt) or main.state == MainScript.State.REPORT, 15.0)
