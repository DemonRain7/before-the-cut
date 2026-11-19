extends Node2D
## The close-up that fills the window while a tool is in use.
##   penlight: sweep the light over the eyes; pupils tighten and eyes follow, or they do not
##   grip:     hold the mouse so they squeeze, let go to say "release", watch the hand
##   port:     a close look at the socket
## It shows what the case data says and nothing else. It never judges what it shows: when
## the interaction has run its course it emits `completed` and the director writes the note.
## What it can do is hold the sheet up beside the picture: the sheet's normal line for this
## tool runs along the bottom (`standard`), the grip timer marks the sheet's limit, and each
## eye, once it has had the light long enough, gets a plain readout of what it did.
##
## If the patient lunges or slams the glass while it is up, the director tears it away
## (`tear`): the picture jolts, drops and is gone, and takes no more input.
##
## The picture is 220 x 186 and is shown at twice its size, like everything else beyond the
## glass, cut off at the edges of the window. What the instrument says (the caption, the grip
## meter) is lettered over it in screen pixels.

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")

signal completed(tool: String)

const ORIGIN := Vector2(100, -20)    # where the picture's top-left corner is on the screen
const SCALE := 2.0
const EYE_R := Vector2(60, 86)       # the patient's right eye, on the left of the screen
const EYE_L := Vector2(160, 86)
const WINDOW := Rect2(5, 12, 210, 146)   # where the pointer can go, in the picture's own pixels
const PLATE := Color(0.027, 0.035, 0.047, 0.84)
const REACH := {
	"natural": Vector2(12, 4), "optic": Vector2(8, 5), "combat": Vector2(10, 3), "display": Vector2(11, 4),
}
const LIT_DIST := 38.0
const LIT_NEEDED := 0.55
const PUPIL_WIDE := 9.0
const PUPIL_TIGHT := 4.0
const FORCE_TIME := 0.55
const TEAR_TIME := 0.24

enum Grip { IDLE, SQUEEZE, HOLDING_ON, OPEN }

var tool: String = ""
var audio: Node = null
var caption: String = ""
var result: String = ""
var done: bool = false
var standard: String = ""         # the sheet's normal line for this tool (set before open)
var limit_s: float = 1.0          # the release the sheet allows: the hands model's limit (set before open)

var _case: Dictionary = {}
var _pid: String = ""
var _mouse := Vector2(110, 60)
var _down: bool = false
var _t: float = 0.0
var _clip := Control.new()
var _layers := Node2D.new()
var _hud := Node2D.new()
var _light: Sprite2D = null
var _eyes: Array = []
var _hand: Sprite2D = null
var _threads: Sprite2D = null
var _grip: int = Grip.IDLE
var _force: float = 0.0
var _timer: float = 0.0
var _release_s: float = 0.4
var _tremor: int = 0
var _shown_time: float = -1.0
var _port_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tear_t: float = 0.0


func _ready() -> void:
	_clip.position = Gfx.WINDOW.position
	_clip.size = Gfx.WINDOW.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_layers.position = ORIGIN - Gfx.WINDOW.position
	_layers.scale = Vector2(SCALE, SCALE)
	_clip.add_child(_layers)
	add_child(_hud)
	_hud.draw.connect(_draw_hud)
	visible = false


## Up and taking input. A close-up being torn away is no longer open.
func is_open() -> bool:
	return tool != "" and _tear_t <= 0.0


func open(p_tool: String, p_case: Dictionary, already_done: bool, p_result: String) -> void:
	close()
	tool = p_tool
	_case = p_case
	_pid = str(p_case.get("sprite", p_case.get("id", "")))
	done = already_done
	result = p_result if already_done else ""
	_t = 0.0
	_down = false
	_rng.seed = hash(_pid + p_tool)
	match tool:
		"penlight":
			_build_eyes()
			caption = "Shine it on each eye."
		"grip":
			_build_grip()
			caption = "Hold the mouse: they squeeze."
		"port":
			_build_port()
			caption = ""
	visible = true
	_hud.queue_redraw()


func close() -> void:
	tool = ""
	visible = false
	_tear_t = 0.0
	modulate = Color.WHITE
	_layers.position = ORIGIN - Gfx.WINDOW.position
	for c in _layers.get_children():
		_layers.remove_child(c)
		c.queue_free()
	_eyes.clear()
	_light = null
	_hand = null
	_threads = null


func set_result(text: String) -> void:
	result = text
	done = true


## The patient came at the glass: the close-up is knocked out of the doctor's hands. It jolts,
## slips down and fades, then closes itself. Nothing it was doing completes.
func tear() -> void:
	if not is_open():
		return
	_tear_t = TEAR_TIME
	_down = false
	_play("tool_put", 0.7)
	_hud.queue_redraw()


## The pointer, in the picture's own pixels.
func pointer(local: Vector2) -> void:
	_mouse = Vector2(clampf(local.x, WINDOW.position.x, WINDOW.end.x), clampf(local.y, WINDOW.position.y, WINDOW.end.y))


## The pointer, given where it is on the screen.
func pointer_screen(pos: Vector2) -> void:
	pointer((pos - ORIGIN) / SCALE)


func button(down: bool) -> void:
	if tool != "grip":
		_down = down
		return
	if down and not _down:
		if _grip == Grip.IDLE or _grip == Grip.OPEN:
			_grip = Grip.SQUEEZE
			_force = 0.0
			_shown_time = -1.0
			_set_hand(true)
			_play("grip_squeeze")
			caption = "Keep holding..."
	elif not down and _down:
		if _grip == Grip.SQUEEZE:
			if _force >= 1.0:
				_grip = Grip.HOLDING_ON
				_timer = 0.0
				_play("beep", 1.25)
				caption = "\"Release.\""
			else:
				_grip = Grip.IDLE
				_set_hand(false)
				caption = "Hold a little longer."
	_down = down


func _play(sound: String, pitch: float = 1.0, db: float = 0.0) -> void:
	if audio != null:
		audio.call("play", sound, pitch, db)


func _layer(path: String, pos: Vector2 = Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Gfx.tex(path)
	s.centered = false
	s.position = pos
	_layers.add_child(s)
	return s


# ------------------------------------------------------------------ penlight
func _build_eyes() -> void:
	_layer("scope/%s/eyes_back.png" % _pid)
	var eyes: Dictionary = _case.get("eyes", {})
	for side in ["right", "left"]:
		var spec: Dictionary = eyes.get(side, {})
		var pos: Vector2 = EYE_R if side == "right" else EYE_L
		var kind := str(spec.get("kind", "natural"))
		# what light should do to this model (case_db resolve_parts): a natural pupil, a combat
		# shutter, or nothing to tighten
		var react := str(spec.get("pupil", "tightens" if kind == "natural" else "none"))
		var tightens := bool(spec.get("tightens", react != "none"))
		var iris := _layer("scope/%s/iris_%s.png" % [_pid, "r" if side == "right" else "l"], pos - Vector2(24, 24))
		var pupil: Sprite2D = null
		# a shutter that never snaps is drawn as the optic itself, the way its art has it
		if react == "tightens" or (react == "shutter" and tightens):
			pupil = _layer("scope/pupil_9.png", pos - Vector2(12, 12))
		_eyes.append({
			"pos": pos, "kind": kind, "react": react, "tag": str(spec.get("tag", "")),
			"tightens": tightens, "follows": bool(spec.get("follows", true)),
			"off": Vector2.ZERO, "size": PUPIL_WIDE, "lit": 0.0, "iris": iris, "pupil": pupil,
		})
	_layer("scope/%s/eyes_front.png" % _pid)
	_light = _layer("scope/light.png")
	_light.material = Gfx.additive()
	_light.modulate = Color(1, 1, 1, 0.85)
	_layer("scope/vignette.png")


func _update_eyes(delta: float) -> void:
	if _light != null:
		_light.position = (_mouse - Vector2(55, 55)).round()
	var all_lit := true
	for e in _eyes:
		var eye: Dictionary = e
		var pos: Vector2 = eye["pos"]
		var d := _mouse - pos
		var lit := d.length() < LIT_DIST
		var kind := str(eye["kind"])
		var reach: Vector2 = REACH.get(kind, Vector2(10, 4))
		var target := Vector2.ZERO
		if bool(eye["follows"]):
			target = Vector2(clampf(d.x * 0.2, -reach.x, reach.x), clampf(d.y * 0.16, -reach.y, reach.y))
		var off: Vector2 = eye["off"]
		off = off.lerp(target, 1.0 - exp(-delta * 9.0))
		eye["off"] = off
		var size: float = eye["size"]
		var want := PUPIL_WIDE
		if lit and bool(eye["tightens"]):
			want = PUPIL_TIGHT
		size = move_toward(size, want, delta * (15.0 if want < size else 7.0))
		eye["size"] = size
		if lit:
			eye["lit"] = float(eye["lit"]) + delta
		if float(eye["lit"]) < LIT_NEEDED:
			all_lit = false
		var iris: Sprite2D = eye["iris"]
		iris.position = (pos - Vector2(24, 24) + off).round()
		var pupil: Sprite2D = eye["pupil"]
		if pupil != null:
			pupil.position = (pos - Vector2(12, 12) + off).round()
			pupil.texture = Gfx.tex("scope/pupil_%d.png" % clampi(roundi(size), 4, 10))
	if all_lit and not done and not _eyes.is_empty():
		done = true
		completed.emit("penlight")


# ------------------------------------------------------------------ grip
func _build_grip() -> void:
	_layer("scope/grip_bg.png")
	_hand = _layer("scope/%s/grip_open.png" % _pid)
	_layer("scope/vignette.png")
	var grip: Dictionary = _case.get("grip", {})
	_release_s = float(int(grip.get("release_ms", 400))) / 1000.0
	_tremor = int(grip.get("tremor", 0))
	_grip = Grip.IDLE
	_force = 0.0
	_timer = 0.0
	_shown_time = -1.0


func _set_hand(closed: bool) -> void:
	if _hand != null:
		_hand.texture = Gfx.tex("scope/%s/%s.png" % [_pid, "grip_closed" if closed else "grip_open"])
		_hand.position = Vector2.ZERO


func _update_grip(delta: float) -> void:
	match _grip:
		Grip.SQUEEZE:
			var was := _force
			_force = minf(1.0, _force + delta / FORCE_TIME)
			if was < 1.0 and _force >= 1.0:
				_play("beep", 0.9)
				caption = "Let go to say \"release\"."
		Grip.HOLDING_ON:
			_timer += delta
			if _timer >= _release_s:
				_grip = Grip.OPEN
				_shown_time = _release_s
				_set_hand(false)
				_play("grip_release")
				if not done:
					done = true
					completed.emit("grip")
	if _hand != null and (_grip == Grip.SQUEEZE or _grip == Grip.HOLDING_ON):
		if _tremor > 0 and int(_t * 24.0) != int((_t - delta) * 24.0):
			_hand.position = Vector2(_rng.randi_range(-_tremor, _tremor), _rng.randi_range(-1, 1) if _tremor > 2 else 0)
		elif _tremor == 0:
			_hand.position = Vector2.ZERO


# ------------------------------------------------------------------ port
func _build_port() -> void:
	_layer("scope/%s/port.png" % _pid)
	# the dark threads are a sign of the night, not of the person: only a port sign with
	# threads (case_db compose sets port.threads) draws them
	var port: Dictionary = _case.get("port", {}) if typeof(_case.get("port")) == TYPE_DICTIONARY else {}
	if bool(port.get("threads", false)) and Gfx.has_tex("scope/%s/port_threads.png" % _pid):
		_threads = _layer("scope/%s/port_threads.png" % _pid)
	_light = _layer("scope/light.png")
	_light.material = Gfx.additive()
	_light.modulate = Color(1, 1, 1, 0.4)
	_layer("scope/vignette.png")
	_port_t = 0.0


func _update_port(delta: float) -> void:
	_port_t += delta
	if _light != null:
		_light.position = (_mouse - Vector2(55, 55)).round()
	if _threads != null:
		_threads.modulate = Color(1, 1, 1, 0.8 + 0.2 * sin(_t * 3.2))
	if _port_t >= 0.7 and not done:
		done = true
		completed.emit("port")


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	if tool == "":
		return
	_t += delta
	if _tear_t > 0.0:
		_tear_t -= delta
		var k := 1.0 - clampf(_tear_t / TEAR_TIME, 0.0, 1.0)
		var jolt := Vector2(roundf(_rng.randf_range(-5.0, 5.0) * (1.0 - k)), roundf(70.0 * k * k))
		_layers.position = ORIGIN - Gfx.WINDOW.position + jolt
		modulate = Color(1, 1, 1, 1.0 - k)
		if _tear_t <= 0.0:
			close()
		return
	match tool:
		"penlight":
			_update_eyes(delta)
		"grip":
			_update_grip(delta)
		"port":
			_update_port(delta)
	_hud.queue_redraw()


func _draw_hud() -> void:
	if tool == "" or _tear_t > 0.0:
		return
	var text := result if (done and result != "") else caption
	var col: Color = Gfx.WARM7 if (done and result != "") else Gfx.TEAL6
	var dots := tool == "penlight" and not done
	if text != "" or dots:
		# one line under the patience lamps, the width of the window
		var plate := Rect2(Gfx.WINDOW.position.x + 4.0, Gfx.WINDOW.position.y + 15.0, Gfx.WINDOW.size.x - 8.0, 12)
		_hud.draw_rect(plate, PLATE)
		Gfx.text(_hud, plate.position + Vector2(4, 1), text, col)
		if dots:
			for i in _eyes.size():
				var eye: Dictionary = _eyes[i]
				var ok := float(eye["lit"]) >= LIT_NEEDED
				Gfx.text(_hud, Vector2(plate.end.x - 22.0 + 9.0 * float(i), plate.position.y + 1.0), "●" if ok else "○", Gfx.WARM6 if ok else Gfx.TEAL4)
	if tool == "grip":
		_draw_grip_readout()
	if tool == "penlight":
		_draw_eye_readouts()
	if standard != "":
		# the sheet held up beside the picture: what a steady patient does here
		var sp := Rect2(Gfx.WINDOW.position.x + 4.0, Gfx.WINDOW.end.y - 32.0, Gfx.WINDOW.size.x - 8.0, 12)
		_hud.draw_rect(sp, PLATE)
		Gfx.text(_hud, sp.position + Vector2(4, 1), "SHEET", Gfx.AMBER, true)
		Gfx.text(_hud, sp.position + Vector2(10.0 + Gfx.text_w("SHEET", true), 1), standard, Gfx.TEAL7)


## Under each eye, once it has had the light long enough: which model it is, what its pupil or
## shutter did (some models have neither), and did the eye follow. It reports and never
## judges: the sheet says what this model should do. The patient's right eye is on the left of
## the screen.
func _draw_eye_readouts() -> void:
	for e in _eyes:
		var eye: Dictionary = e
		if float(eye["lit"]) < LIT_NEEDED:
			continue
		var pos: Vector2 = eye["pos"]
		var at := ORIGIN + pos * SCALE + Vector2(0, 54)
		var head := "RIGHT EYE" if pos == EYE_R else "LEFT EYE"
		var tag := str(eye["tag"])
		var what := ""
		match str(eye["react"]):
			"none":
				what = "NO PUPIL"
			"shutter":
				what = "SHUTTER SNAPS" if bool(eye["tightens"]) else "SHUTTER OPEN"
			_:
				what = "TIGHTENS" if bool(eye["tightens"]) else "STAYS WIDE"
		# each piece in the player's language: the catalogs have the pieces, not every pairing
		what = Lang.t(what) + Lang.t(", FOLLOWS" if bool(eye["follows"]) else ", DOESN'T FOLLOW")
		var head_w := Gfx.text_w(head, true)
		var tag_w := (Gfx.text_w(tag, true) + 5.0) if tag != "" else 0.0
		var w := maxf(head_w + tag_w, Gfx.text_w(what)) + 10.0
		var r := Rect2(roundf(at.x - w / 2.0), at.y, w, 23)
		_hud.draw_rect(r, PLATE)
		var x := roundf(at.x - (head_w + tag_w) / 2.0)
		Gfx.text(_hud, Vector2(x, r.position.y + 1.0), head, Gfx.TEAL5, true)
		if tag != "":
			Gfx.text(_hud, Vector2(x + head_w + 5.0, r.position.y + 1.0), tag, Gfx.AMBER, true)
		Gfx.text_center(_hud, at.x, r.position.y + 11.0, what, Gfx.WARM7)


func _draw_grip_readout() -> void:
	var r := Rect2(Gfx.WINDOW.position.x + 6.0, Gfx.WINDOW.position.y + 31.0, 64, 45)
	_hud.draw_rect(r, Gfx.INK0)
	_hud.draw_rect(r, Gfx.TEAL3, false, 1.0)
	var shown := 0.0
	var label := "READY"
	var col: Color = Gfx.GRN3
	match _grip:
		Grip.SQUEEZE:
			label = "SQUEEZE"
		Grip.HOLDING_ON:
			shown = _timer
			label = "RELEASE"
			col = Gfx.GRN5
		Grip.OPEN:
			shown = _shown_time
			label = "LET GO"
			col = Gfx.GRN5
	if _grip == Grip.SQUEEZE or _grip == Grip.IDLE:
		Gfx.text_center(_hud, r.position.x + 32.0, r.position.y + 3.0, label, col)
		# force gauge
		_hud.draw_rect(Rect2(r.position.x + 4.0, r.position.y + 16.0, 56, 6), Gfx.TEAL2)
		_hud.draw_rect(Rect2(r.position.x + 4.0, r.position.y + 16.0, roundf(56.0 * _force), 6), Gfx.GRN3)
		Gfx.text_center(_hud, r.position.x + 32.0, r.position.y + 28.0, "grip force", Gfx.TEAL4)
		return
	var late := shown > limit_s
	Gfx.big_center(_hud, r.position.x + 32.0, r.position.y + 2.0, "%.1fs" % shown, Gfx.RED3 if late else col)
	# a two-second scale with the sheet's limit marked on it; past the limit it runs red
	var x0 := r.position.x + 4.0
	var w := 56.0
	var at := roundf(w * clampf(limit_s / 2.0, 0.0, 1.0))
	var reach := roundf(w * clampf(shown / 2.0, 0.0, 1.0))
	_hud.draw_rect(Rect2(x0, r.position.y + 25.0, w, 5), Gfx.TEAL2)
	_hud.draw_rect(Rect2(x0, r.position.y + 25.0, minf(reach, at), 5), Gfx.GRN3)
	if reach > at:
		_hud.draw_rect(Rect2(x0 + at, r.position.y + 25.0, reach - at, 5), Gfx.RED2)
	_hud.draw_rect(Rect2(x0 + at, r.position.y + 23.0, 1, 9), Gfx.AMBER)
	# the mark carries its own value and the far end of the scale has none, so the one number
	# printed on the scale is the limit ("LIMIT 2s" at the end once read as a two-second limit)
	Gfx.text(_hud, Vector2(x0, r.position.y + 33.0), "0", Gfx.TEAL5)
	var tag := Lang.tf("LIMIT %ss", [("%.1f" % limit_s).trim_suffix(".0")])
	var half := Gfx.text_w(tag) * 0.5
	Gfx.text_center(_hud, clampf(x0 + at, x0 + 6.0 + half, x0 + w - half), r.position.y + 33.0, tag, Gfx.AMBER)
