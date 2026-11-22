extends Node
## A layered patient portrait with a little life in it: blinking, a gaze habit, restless
## hands, a talking mouth and the authored reactions to pressure.
##
## The picture is split in two groups so the window sill can sit between them:
##   back  = body, pupils, head, brows, the "turn" overlay, mouth, eyelids
##   front = the hands on the counter (or the attack pose)
## Every layer is a 160 x 176 image with the same origin (see tools/art/gen_patients.py).
##
## When a patient turns, the rig also plays the assault: the face overlay, the screaming
## mouth, the three blows on the glass and the lunge out through the window. A patient who
## snaps or flares mid-exam first surges at the glass (`surge`): up against it in a blink, then
## back, or straight on into the attack.
##
## While an answer is on its way (`thinking`) each patient waits in their own way, with a
## small thought bubble by the head; while the doctor is speaking into the microphone
## (`listening`) they look at the doctor and their hands stop. Both come from the patient's
## idle habit, never from whether they are steady or drifting.

const Gfx = preload("res://scripts/ui/gfx.gd")

const PIVOT := Vector2(80, 160)   # where the patient meets the sill; lunges scale about it
const POP_SCALE := 1.6            # how big they are when they come through the window (on top of the window's own 2x)
const SLIDE_PX := 250.0           # how far `slide` 1 carries them: out of the window, behind the wall
const SURGE_IN := 0.09            # seconds to come up against the glass
const SURGE_OUT := 0.3            # seconds to sink back from it
const SURGE_SCALE := 0.22         # how much bigger they are against the glass

signal impact(strength: float)

var back := Node2D.new()
var front := Node2D.new()
var pid: String = ""
var case_data: Dictionary = {}
var meta: Dictionary = {}
var slide: float = 1.0            # 1 = out of the window to the right, 0 = at the counter
var talking: bool = false
var thinking: bool = false        # an answer is being worked out: the waiting pose and the thought bubble
var listening: bool = false       # the doctor is speaking into the microphone: eyes on the doctor, hands still
var frozen: bool = false          # the beat before an attack: nothing moves
var less_blood: bool = false      # use the face overlay, the scream and the blow poses that were drawn without blood
var pop: float = 0.0              # 0..1: out through the window, at the player
var pop_target := Vector2(280, 138)   # where the face ends up, in view space (the middle of the screen)

var _spr: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _gaze_kind: String = "soft"
var _hands_kind: String = "still"
var _blink_in: float = 2.0
var _blink_t: float = 0.0
var _gaze := Vector2.ZERO
var _gaze_in: float = 1.0
var _glyph_t: float = 0.0
var _hand_frame: String = "hands_a"
var _hand_in: float = 1.0
var _hand_burst: float = 0.0
var _talk_t: float = 0.0
var _talk_frame: int = 0
var _rest_brows: String = "neutral"
var _rest_mouth: String = "closed"
var _brows: String = "neutral"
var _mouth: String = "closed"
var _react_t: float = 0.0
var _react_hands: bool = false
var _hold_hands: bool = false
var _still_face: bool = false
var _attack: bool = false
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _lunge: float = 0.0
var _pose: String = "attack"
var _pose_alt: bool = false
var _pose_t: float = 0.0
var _scream_alt: bool = false
var _scream_t: float = 0.0
var _zoom: float = 1.0
var _zoom_to: float = 1.0
var _jerk: float = 0.0
var _thrash := Vector2.ZERO
var _thrash_t: float = 0.0
var _bubble := Node2D.new()       # the thought bubble, beside the head
var _minded: bool = false         # thinking or listening, as of the last frame
var _thought_in: float = 0.0
var _surge_t: float = -1.0        # seconds into a surge at the glass, or -1
var _surge_hold: float = 0.0


func setup(p_case: Dictionary, p_meta: Dictionary) -> void:
	case_data = p_case
	meta = p_meta
	pid = str(p_case.get("sprite", p_case.get("id", "")))
	_rng.seed = hash(pid) + 7
	var idle: Dictionary = p_case.get("idle", {})
	_gaze_kind = str(idle.get("gaze", "soft"))
	_hands_kind = str(idle.get("hands", "still"))
	var face: Dictionary = meta.get("face", {})
	_rest_brows = str(face.get("brows", "neutral"))
	_rest_mouth = str(face.get("mouth", "closed"))
	_brows = _rest_brows
	_mouth = _rest_mouth
	for key in ["body", "pupils", "head", "brows", "turn", "mouth", "lids"]:
		_add(back, key)
	_add(front, "hands")
	_add(front, "attack")
	_set_tex("body", "body")
	_set_tex("pupils", "pupils")
	_set_tex("head", "head")      # a port at the temple shows its threads on the head
	_set_tex("lids", "lids")
	_set_tex("attack", "attack")
	(_spr["lids"] as Sprite2D).visible = false
	(_spr["turn"] as Sprite2D).visible = false
	(_spr["attack"] as Sprite2D).visible = false
	# the thought bubble sits up and to the right of the head, found from where the eyes are
	var at := Vector2(116, 34)
	var eyes: Variant = (meta.get("zones", {}) as Dictionary).get("eyes")
	if typeof(eyes) == TYPE_ARRAY and (eyes as Array).size() >= 4:
		at = Vector2(float(eyes[0]) + float(eyes[2]) + 10.0, float(eyes[1]) - 28.0)
	_bubble.position = at
	_bubble.visible = false
	back.add_child(_bubble)
	_bubble.draw.connect(_draw_bubble)
	_blink_in = _next_blink()
	_apply_face()
	_apply_hands()
	_apply_pose()


func _add(parent: Node2D, key: String) -> void:
	var s := Sprite2D.new()
	s.centered = false
	parent.add_child(s)
	_spr[key] = s


func _has_layer(layer: String) -> bool:
	return Gfx.has_tex("patients/%s/%s.png" % [pid, layer])


func _set_tex(key: String, layer: String) -> void:
	var s: Sprite2D = _spr[key]
	var t := Gfx.tex("patients/%s/%s.png" % [pid, layer])
	if t != null:
		s.texture = t


func _next_blink() -> float:
	var b: Variant = meta.get("blink")
	if typeof(b) != TYPE_ARRAY:
		return -1.0
	var arr: Array = b
	if arr.size() < 2:
		return -1.0
	return _rng.randf_range(float(arr[0]), float(arr[1]))


func zone_rect(zone: String) -> Rect2:
	var zones: Dictionary = meta.get("zones", {})
	var z: Variant = zones.get(zone)
	if typeof(z) != TYPE_ARRAY:
		return Rect2()
	var a: Array = z
	return Rect2(back.position + Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]), float(a[3])))


func at_counter() -> bool:
	return absf(slide) <= 0.001


# ------------------------------------------------------------------ reactions
## The authored reaction to pressure: face and hands change in the same instant, or they
## pointedly do not.
func react(face: String, hands: String) -> void:
	_react_t = 2.8
	_still_face = false
	match face:
		"upset":
			_brows = "worried"
			_mouth = "upset"
			_rest_mouth = "upset"
		"angry":
			_brows = "angry"
			_mouth = "angry"
			_rest_brows = "angry"
		"flat", "blank":
			_brows = "neutral"
			_mouth = "closed"
			_still_face = true
			_gaze = Vector2.ZERO
	_react_hands = hands != ""
	_hold_hands = hands == "fist" or hands == "freeze"
	if _react_hands:
		_hand_frame = gesture_layer(hands)
	if hands == "slam":
		shake(3.0, 0.35)
		impact.emit(1.0)
	elif hands == "raise" or hands == "point":
		shake(1.0, 0.2)
	if face == "angry" and _has_layer("pupils_react"):
		_set_tex("pupils", "pupils_react")
	_apply_face()
	_apply_hands()


## The hands for a temper gesture: the layer the patient's meta names for it (each patient's
## "gestures" map covers every gesture his or her signs use), else a picture of that name
## (hands_fist, hands_point, hands_slam), else the pressure hands. "freeze" holds them still.
func gesture_layer(gesture: String) -> String:
	var named := str((meta.get("gestures", {}) as Dictionary).get(gesture, ""))
	if named != "" and _has_layer(named):
		return named
	if gesture == "freeze":
		return "hands_a"
	if _has_layer("hands_" + gesture):
		return "hands_" + gesture
	return "hands_react"


func soften() -> void:
	# reassurance: shoulders drop, the face eases for a moment
	if _still_face:
		return
	_brows = "neutral" if _rest_brows != "angry" else _rest_brows
	_mouth = "closed"
	_react_t = 1.6
	_apply_face()


## The patient turns: the dark threads are over the face, the weapon is out.
func set_attack(on: bool) -> void:
	_attack = on
	var has := _has_layer("attack")
	(_spr["attack"] as Sprite2D).visible = on and has
	(_spr["hands"] as Sprite2D).visible = not (on and has)
	var turn: Sprite2D = _spr["turn"]
	turn.visible = false
	if not on:
		_zoom_to = 1.0
		return
	_brows = "angry" if _gaze_kind != "soft" else "worried"
	_mouth = "angry" if _gaze_kind != "soft" else "upset"
	_gaze = Vector2.ZERO
	(_spr["lids"] as Sprite2D).visible = false
	var layer := "turn_clean" if less_blood and _has_layer("turn_clean") else "turn"
	if _has_layer(layer):
		_set_tex("turn", layer)
		turn.visible = true
	_pose = "attack"
	_pose_t = 0.0
	_scream_t = 0.0
	_apply_face()
	_apply_attack_pose()
	_jerk = 1.0
	shake(3.0, 0.45)


## One of the three blows on the glass: 1 the open hand, 2 the weapon, 3 the forehead.
func blow(n: int) -> void:
	match n:
		1:
			_pose = "attack_s1"
			_zoom_to = 1.04
		2:
			_pose = "attack_s2"
			_zoom_to = 1.08
		_:
			_zoom_to = 1.14
	_zoom = _zoom_to
	_jerk = 1.0
	shake(2.0 + float(n), 0.3)
	_apply_attack_pose()


func attack_style() -> String:
	var a: Dictionary = meta.get("attack", {})
	return str(a.get("style", "saw"))


## Where a named point of the attack pose ("hand", "tool", "head", "face") is, in view space.
func attack_point(point: String) -> Vector2:
	return back.position + _attack_local(point) * back.scale


func _attack_local(point: String) -> Vector2:
	var a: Dictionary = meta.get("attack", {})
	var p: Variant = a.get(point)
	if typeof(p) == TYPE_ARRAY and (p as Array).size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return Vector2(80, 76)


func _apply_attack_pose() -> void:
	var layer := _pose + ("_b" if _pose_alt else "")
	if not _has_layer(layer):
		layer = _pose if _has_layer(_pose) else "attack"
	# --less-blood: the same pose with a dry palm, where one was drawn
	if less_blood and _has_layer(layer + "_clean"):
		layer += "_clean"
	_set_tex("attack", layer)


## They come at the glass all at once: up against it in a blink, held there `hold` seconds,
## then back. A snap holds until the attack pose has taken over; a flare comes straight back.
func surge(hold: float) -> void:
	_surge_t = 0.0
	_surge_hold = maxf(0.0, hold)
	shake(3.5, 0.3)


## 0 at rest, 1 against the glass.
func _surge_amount() -> float:
	if _surge_t < 0.0:
		return 0.0
	if _surge_t < SURGE_IN:
		return _surge_t / SURGE_IN
	if _surge_t < SURGE_IN + _surge_hold:
		return 1.0
	return clampf(1.0 - (_surge_t - SURGE_IN - _surge_hold) / SURGE_OUT, 0.0, 1.0)


func shake(amp: float, time: float) -> void:
	_shake_amp = amp
	_shake_t = time


func lunge(amount: float) -> void:
	_lunge = amount


# ------------------------------------------------------------------ per-frame life
func _process(delta: float) -> void:
	_t += delta
	var minded := (thinking or listening) and not frozen and not _attack and at_counter()
	if minded != _minded:
		_minded = minded
		_thought_in = 0.0
		if not minded:
			_gaze_in = 0.2            # and back to their own habit
	_bubble.visible = minded and thinking
	if _bubble.visible:
		_bubble.queue_redraw()
	if not frozen and not _attack:
		_update_blink(delta)
		if minded:
			_update_thought(delta)
		else:
			_update_gaze(delta)
		if not (minded and listening):
			_update_hands(delta)
	_update_mouth(delta)
	if _attack:
		_update_attack(delta)
	if _react_t > 0.0:
		_react_t -= delta
		if _react_t <= 0.0:
			_end_reaction()
	if _shake_t > 0.0:
		_shake_t -= delta
	if _surge_t >= 0.0:
		_surge_t += delta
		if _surge_t > SURGE_IN + _surge_hold + SURGE_OUT:
			_surge_t = -1.0
	_apply_pose()


func _update_blink(delta: float) -> void:
	var lids: Sprite2D = _spr["lids"]
	if _blink_t > 0.0:
		_blink_t -= delta
		if _blink_t <= 0.0:
			lids.visible = false
		return
	if _blink_in < 0.0 or _still_face:
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		lids.visible = true
		_blink_t = 0.11
		_blink_in = _next_blink()
		if _gaze_kind == "dart" and _rng.randf() < 0.35:
			_blink_in = 0.25      # a nervous double blink


func _update_gaze(delta: float) -> void:
	if _still_face:
		_gaze = Vector2.ZERO
		return
	_gaze_in -= delta
	if _gaze_in > 0.0:
		return
	match _gaze_kind:
		"dart":
			var spots := [Vector2(0, 0), Vector2(2, 0), Vector2(-2, 0), Vector2(2, -1), Vector2(0, 0), Vector2(1, 1)]
			_gaze = spots[_rng.randi_range(0, spots.size() - 1)]
			_gaze_in = _rng.randf_range(0.35, 1.1)
		"glare":
			if _gaze == Vector2.ZERO and _rng.randf() < 0.3:
				_gaze = Vector2(-1, 1)
				_gaze_in = 0.5
			else:
				_gaze = Vector2.ZERO
				_gaze_in = _rng.randf_range(2.5, 5.0)
		"wander":
			var drift := [Vector2(0, 0), Vector2(1, 0), Vector2(2, -1), Vector2(-1, 0), Vector2(-2, -1), Vector2(0, 1)]
			_gaze = drift[_rng.randi_range(0, drift.size() - 1)]
			_gaze_in = _rng.randf_range(1.2, 2.6)
			if _has_layer("pupils_b") and _react_t <= 0.0:
				_set_tex("pupils", "pupils_b" if _rng.randf() < 0.3 else "pupils")
		"soft":
			if _gaze == Vector2(0, 1):
				_gaze = Vector2.ZERO
				_gaze_in = _rng.randf_range(1.0, 1.8)
			else:
				_gaze = Vector2(0, 1)
				_gaze_in = _rng.randf_range(2.5, 4.5)
		_:
			_gaze = Vector2.ZERO
			_gaze_in = 10.0


## Waiting for an answer, or being spoken to. The nervous one looks everywhere, the angry one
## looks away, the one who wanders looks up, the meek one looks down, and the one who never
## moves does not move now either. Spoken to, they all look at the doctor.
func _update_thought(delta: float) -> void:
	if _still_face or (listening and not thinking):
		_gaze = Vector2.ZERO
		return
	_thought_in -= delta
	if _thought_in > 0.0:
		return
	match _gaze_kind:
		"dart":
			var spots := [Vector2(2, 0), Vector2(-2, 0), Vector2(2, -1), Vector2(-2, -1), Vector2(1, 1), Vector2(-1, 1)]
			_gaze = spots[_rng.randi_range(0, spots.size() - 1)]
			_thought_in = _rng.randf_range(0.12, 0.3)
		"glare":
			_gaze = Vector2(-2, 1)
			_thought_in = 10.0
		"wander":
			_gaze = Vector2(1, -1) if _gaze == Vector2(2, -1) else Vector2(2, -1)
			_thought_in = _rng.randf_range(0.7, 1.3)
		"soft":
			_gaze = Vector2(0, 1)
			_thought_in = 10.0
		_:
			_gaze = Vector2.ZERO
			_thought_in = 10.0


## The thought bubble: three dots that count up while the answer is on its way. For the
## patient who never moves, the dots do not move either.
func _draw_bubble() -> void:
	var edge: Color = Gfx.TEAL7
	var ink: Color = Gfx.INK0
	_bubble.draw_rect(Rect2(1, 0, 21, 13), edge)
	_bubble.draw_rect(Rect2(0, 1, 23, 11), edge)
	_bubble.draw_rect(Rect2(2, 1, 19, 11), ink)
	_bubble.draw_rect(Rect2(1, 2, 21, 9), ink)
	_bubble.draw_rect(Rect2(-2, 13, 4, 4), edge)      # the tail, toward the head
	_bubble.draw_rect(Rect2(-1, 14, 2, 2), ink)
	_bubble.draw_rect(Rect2(-6, 18, 3, 3), edge)
	var shown := 3 if _gaze_kind == "fixed" else int(_t * 3.4) % 4
	for i in 3:
		_bubble.draw_rect(Rect2(4 + 6 * i, 5, 3, 3), Gfx.TEAL7 if i < shown else Gfx.TEAL3)


func _update_hands(delta: float) -> void:
	if _react_hands:
		return
	_hand_in -= delta
	if _hand_in > 0.0:
		return
	match _hands_kind:
		"drum":
			if _hand_burst > 0.0:
				_hand_frame = "hands_b" if _hand_frame == "hands_a" else "hands_a"
				_hand_in = 0.11
				_hand_burst -= 0.11
			else:
				_hand_frame = "hands_a"
				_hand_in = _rng.randf_range(0.4, 1.3)
				_hand_burst = _rng.randf_range(0.6, 1.6)
		"spasm":
			if _hand_frame == "hands_a":
				_hand_frame = "hands_b"
				_hand_in = 0.14
			else:
				_hand_frame = "hands_a"
				_hand_in = 0.2 if _rng.randf() < 0.3 else _rng.randf_range(2.2, 4.8)
		"tap":
			_hand_frame = "hands_b" if _hand_frame == "hands_a" else "hands_a"
			_hand_in = 0.16 if _hand_frame == "hands_b" else (0.38 if _rng.randf() < 0.8 else 1.4)
		"work":
			_hand_frame = "hands_b" if _hand_frame == "hands_a" else "hands_a"
			_hand_in = _rng.randf_range(1.0, 2.0)
		_:
			_hand_frame = "hands_a"
			_hand_in = 10.0
	_apply_hands()


## Saw teeth and torch flare flicker between two frames; the mouth works; the body thrashes.
func _update_attack(delta: float) -> void:
	_pose_t -= delta
	if _pose_t <= 0.0:
		_pose_t = 0.055
		_pose_alt = not _pose_alt
		_apply_attack_pose()
	_zoom = move_toward(_zoom, _zoom_to, delta * 2.0)
	_jerk = maxf(0.0, _jerk - delta * 6.0)
	_thrash_t -= delta
	if _thrash_t <= 0.0:
		_thrash_t = 0.045
		_thrash = Vector2(float(_rng.randi_range(-1, 1)), float(_rng.randi_range(-1, 0)))


func _update_mouth(delta: float) -> void:
	if _attack and _has_layer("mouth_turn"):
		_scream_t -= delta
		if _scream_t <= 0.0:
			_scream_t = 0.09
			_scream_alt = not _scream_alt
			var frame := "mouth_turn_b" if _scream_alt else "mouth_turn"
			# --less-blood: the same scream with nothing on the teeth or the chin
			if less_blood and _has_layer(frame + "_clean"):
				frame += "_clean"
			_set_tex("mouth", frame)
		_talk_frame = 0
		return
	if talking:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = 0.085
			_talk_frame = (_talk_frame + 1 + _rng.randi_range(0, 1)) % 3
			var frames := ["mouth_a", "mouth_b", "mouth_" + _mouth]
			_set_tex("mouth", frames[_talk_frame])
	elif _talk_frame != -1:
		_talk_frame = -1
		_set_tex("mouth", "mouth_" + _mouth)


func _end_reaction() -> void:
	_brows = _rest_brows
	_mouth = _rest_mouth
	if not _hold_hands:
		_react_hands = false
		_hand_frame = "hands_a"
		_hand_in = 0.6
	if _has_layer("pupils_react") and not _attack:
		_set_tex("pupils", "pupils")
	_apply_face()
	_apply_hands()


func _apply_face() -> void:
	_set_tex("brows", "brows_" + _brows)
	if not talking:
		_set_tex("mouth", "mouth_" + _mouth)


func _apply_hands() -> void:
	_set_tex("hands", _hand_frame)


## A layer with dark threads at the port (`<layer>_t`) on a night the port sign has them
## (case_db compose sets port.threads), when the picture shows the port and has that twin.
func _breath() -> float:
	if _still_face or frozen:
		return 0.0
	match _gaze_kind:
		"dart":
			return 1.0 if fmod(_t, 0.9) < 0.3 else 0.0
		"fixed":
			return 0.0
		"glare":
			return 1.0 if fmod(_t, 3.0) < 1.3 else 0.0
		"wander":
			return 1.0 if fmod(_t, 2.2) < 1.0 else 0.0
	return 1.0 if fmod(_t, 4.2) < 1.9 else 0.0


func _apply_pose() -> void:
	var off := Vector2(roundf(slide * SLIDE_PX), 0.0)
	var away := absf(slide)      # negative slide = walking off to the left, through to the chair
	if away > 0.001 and away < 0.999:
		off.y += roundf(absf(sin(away * PI * 6.0)) * 3.0)
	else:
		off.y += _breath()
	off.y += roundf(_lunge * 3.0)
	if _shake_t > 0.0:
		off.x += roundf(_rng.randf_range(-_shake_amp, _shake_amp))
		off.y += roundf(_rng.randf_range(-_shake_amp, _shake_amp) * 0.5)
	var s := 1.0
	if _attack:
		off += _thrash
		s = _zoom + _jerk * 0.035
	var surge := _surge_amount()
	if surge > 0.0:
		# up against the glass: bigger about the sill, and a little lower, as if nearer
		var k := 1.0 - (1.0 - surge) * (1.0 - surge)
		s *= 1.0 + SURGE_SCALE * k
		off.y += roundf(4.0 * k)
	var pos := Gfx.PATIENT_POS + off + PIVOT * (1.0 - s)
	if pop > 0.0:
		# through the window: the face swells to fill the screen, and keeps coming
		var k := clampf(pop, 0.0, 1.0)
		var big := lerpf(s, POP_SCALE, k) * (1.0 + 0.3 * maxf(0.0, pop - 1.0))
		var target := pop_target + off - _attack_local("face") * big
		pos = pos.lerp(target, k)
		s = big
	pos = pos.round()
	back.position = pos
	front.position = pos
	back.scale = Vector2(s, s)
	front.scale = Vector2(s, s)
	(_spr["pupils"] as Sprite2D).position = _gaze
