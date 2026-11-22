extends Node2D
## The closing film: the operating surgeon's headcam, played when the last appointment is over.
##
## Everyone the doctor admitted sits in the theatre chair exactly where and as large as they
## stood at the counter (the same rig, pose and habits), says the line they left the counter
## with and goes under. The camera pushes into the close-up the doctor examined at the counter
## (the hand on the grip bar, the eye under the light, the socket), the old part comes out and
## the new one goes in, the same for everyone. Then the new part is calibrated and the night's
## truth shows: the reading settles and the patient wakes and uses the part, or it does not, and
## the patient wakes on the table. Patients who were not admitted get a short recap at the
## counter, a death at the glass ends the film, and a night with nobody admitted ends on the
## empty chair.
##
## The film keeps its own clock (step()), so a capture at any frame rate shows the same story.
## Captions and stamps carry it with the sound off; every word goes through the catalogs.

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const CaseDB = preload("res://scripts/core/case_db.gd")
const PatientRig = preload("res://scripts/ui/patient_rig.gd")
const GoreLayer = preload("res://scripts/ui/gore_layer.gd")

signal finished
signal sound(cue: String, pitch: float, db: float)
signal loop_sound(cue: String, on: bool, db: float)

const SKIP := Rect2(518, 325, 110, 28)
const NEXT := Rect2(378, 325, 134, 28)
const BAND := Rect2(0, 298, 640, 62)
const PICTURE := Rect2(0, 0, 640, 298)
const C := Vector2(320, 150)               # the middle of the picture, above the caption band
const T_OFF := Vector2(108, 38)            # where every full-frame theatre layer goes, in view space
const T_SIZE := Vector2(344, 204)
const LAMP_AT := Vector2(356, 16)          # the lamp's pivot, in view space
const LAMP_PIVOT := Vector2(56, 0)         # ... and in lamp.png
const CLOSE_AT := Vector2(100, -20)        # the close-up (220 x 186 at twice the size) on the screen
const EYE_R := Vector2(60, 86)             # the eyes in the close-up, where scope_view has them
const EYE_L := Vector2(160, 86)
const GLOVE_TIP := Vector2(5, 5)           # the tool's tip in glove_*.png
const LIT_DIST := 38.0
const REACH := {"natural": Vector2(12, 4), "optic": Vector2(8, 5), "combat": Vector2(10, 3), "display": Vector2(11, 4)}
const PUPIL_WIDE := 9.0
const PUPIL_TIGHT := 4.0
const HAND_PART := Vector2(110, 52)        # the cartridge under the wrist hatch, in the close-up
const PRY_AT := Vector2(118, 96)           # where forceps try to open a hand that will not let go
const PORT_PART := Vector2(96, 86)
const VOICE_PART := Vector2(64, 88)
const VOICE_LED := Vector2(64, 127)
const ECG := Rect2(8, 8, 112, 46)
const READOUT := Rect2(222, 16, 196, 30)
const STAMP_AT := Vector2(488, 262)
## Where the headcam lies after a patient wakes: low and tilted, looking past the empty chair at
## the crew on the floor and the open back door. It lands rolled a little further and settles.
const FLOOR_F := Vector2(440, 195)
const FLOOR_Z := 1.6
const FLOOR_TH := 0.26
const FLOOR_ROLL := 0.1
const FLOOR_STAMP := Vector2(190, 252)    # over the chair, clear of the crew
const TEAM_POS := Vector2(104, 26)         # as clinic_view has the crew at the counter
const TEAM_OUT := 124.0
const BEACON_BEAT := 0.18
const BEACON_RED := Color(0.95, 0.1, 0.1)
const BEACON_BLUE := Color(0.15, 0.35, 1.0)

## The part each patient came in to have replaced, and so the close-up the film pushes into.
const SITES := {
	"rook": "hand", "maren": "hand", "bo": "hand", "ozzie": "hand", "vale": "hand",
	"kip": "eye_l", "priya": "eye_l", "dana": "eye_r", "lux": "port", "juno": "voice",
}
const TESTS := {"hand": "GRIP TEST", "eye_l": "LIGHT TEST", "eye_r": "LIGHT TEST", "port": "SIGNAL TEST", "voice": "VOICE TEST"}

## How each attack style sounds and lands on the lens: the scream's pitch, the kind of strike,
## the sound it bites with, the loop while the weapon is up, and the colour of its light.
const STYLE := {
	"saw": {"pitch": 0.6, "strike": "slash", "bite": "saw_grind", "loop": "saw_loop", "glow": ""},
	"torch": {"pitch": 1.12, "strike": "burn", "bite": "torch_burst", "loop": "torch_loop", "glow": "5ee6e0"},
	"lock": {"pitch": 1.28, "strike": "smash", "bite": "clang", "loop": "", "glow": ""},
	"fist": {"pitch": 0.76, "strike": "smash", "bite": "punch", "loop": "servo_loop", "glow": ""},
	"picks": {"pitch": 1.24, "strike": "claw", "bite": "scrape", "loop": "hum_loop", "glow": ""},
	"laser": {"pitch": 1.16, "strike": "burn", "bite": "laser_burst", "loop": "laser_loop", "glow": "ff4a4a"},
	"cleaver": {"pitch": 0.68, "strike": "slash", "bite": "chop", "loop": "", "glow": ""},
	"arc": {"pitch": 1.34, "strike": "burn", "bite": "zap", "loop": "arc_loop", "glow": "8a7cff"},
	"baton": {"pitch": 1.0, "strike": "smash", "bite": "baton_hit", "loop": "stun_loop", "glow": ""},
	"spike": {"pitch": 0.72, "strike": "smash", "bite": "spike", "loop": "piston_loop", "glow": ""},
}

## What a counter recap says once the moment has played, by outcome.
const COUNTER_LINES := {
	"referred_stable": "Sent to Trauma Team. Not admitted.",
	"referred_drifting": "Trauma Team took them in. Not admitted.",
	"caught": "The shutter held. Not admitted.",
	"locked_out": "Shut out before the attack. Not admitted.",
	"false_alarm": "Shutter down on a steady patient. Not admitted.",
	"walkout": "Walked out. Not admitted.",
	"gave_up": "Gave up waiting. Not admitted.",
}

var less_blood: bool = false
var shots: Array = []
var index: int = 0
var elapsed: float = 0.0

var _cases: Dictionary = {}
var _meta: Dictionary = {}
var _parts_db: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pt: float = -1.0
var _length: float = 5.0
var _kind: String = ""
var _shot: Dictionary = {}
var _loops: Dictionary = {}

# the layers, back to front
var _bg := ColorRect.new()
var _cam := Node2D.new()                   # everything the headcam frames; it zooms, pans and tilts
var _world := Node2D.new()                 # ... in view space, at twice the size
var _flat := Node2D.new()                  # ... in screen pixels (the booth round the window)
var _jump := Node2D.new()                  # ... a patient who comes at the lens, over everything
var _ccam := Node2D.new()                  # the close-up: it only shakes
var _close := Node2D.new()
var _drape: Sprite2D = null
var _crack: Sprite2D = null
var _gore: GoreLayer = null
var _fx := Node2D.new()
var _hud := Node2D.new()

# the camera: the point _f (in unzoomed screen pixels) is held at C, zoomed _z and tilted _th
var _z: float = 1.0
var _f := C
var _th: float = 0.0
var _shake: float = 0.0
var _cshake: float = 0.0
var _flash: float = 0.0
var _flash_col := Color.WHITE
var _static: float = 0.0
var _lost: bool = false
var _black: float = 0.0

# the words
var _place: String = ""
var _name_on: bool = false
var _caption: String = ""                  # translated already
var _stamp_text: String = ""
var _stamp_col := Gfx.STAMP_G
var _stamp_t: float = -1.0
var _stamp_at := STAMP_AT
var _talk_until: float = -1.0
var _blip_in: float = 0.0

# the heart monitor on the headcam
var _ecg_on: bool = false
var _ecg_alarm: bool = false
var _ecg_flat: bool = false
var _ecg_label: String = ""                # "" shows the heart rate
var _hr: float = 84.0
var _hr_to: float = 84.0
var _beat: float = 0.0
var _trace := PackedFloat32Array()
var _col: int = 0
var _sweep: float = 0.0

# the calibration readout
var _read_on: bool = false
var _read_name: String = ""
var _read_value: String = ""
var _read_bad: bool = false
var _verdict: String = ""
var _verdict_ok: bool = true
var _bar: float = -1.0
var _bar_bad: bool = false

# one shot's cast and props
var _rig: PatientRig = null
var _case_d: Dictionary = {}
var _rig_meta: Dictionary = {}
var _pid: String = ""
var _site: String = "hand"
var _style: String = "fist"
var _drift: bool = false
var _focus := C
var _face := C
var _cal_end: float = 5.2
var _lamp_on: bool = false
var _lamp_k: float = 0.0
var _swing_from: float = -1.0
var _dim: ColorRect = null
var _lamp: Sprite2D = null
var _lamp_lit: Sprite2D = null
var _glow: Sprite2D = null
var _door: Sprite2D = null
var _decal: Sprite2D = null
var _crew: Sprite2D = null
var _crew_down: Sprite2D = null
var _straps: Node2D = null
var _back_slot: Node2D = null
var _front_slot: Node2D = null
var _strap_zone := Rect2()
var _strap_state: String = "shut"
var _close_fx: Node2D = null
var _hand: Sprite2D = null
var _old: Sprite2D = null
var _new: Sprite2D = null
var _hole: Sprite2D = null
var _threads: Sprite2D = null
var _eyes: Array = []
var _eyes_front: Sprite2D = null
var _empty_eye: Sprite2D = null
var _beam: Sprite2D = null
var _driver: Sprite2D = null
var _forceps: Sprite2D = null
var _held_d: Sprite2D = null
var _held_f: Sprite2D = null
var _target := Vector2.ZERO
var _rings: Array = []

# the counter
var _c_rain: Sprite2D = null
var _c_door: Sprite2D = null
var _c_strobe: ColorRect = null
var _c_team: Node2D = null
var _c_red: Sprite2D = null
var _c_blue: Sprite2D = null
var _c_glass: Sprite2D = null
var _c_broken: Sprite2D = null
var _c_crack: Sprite2D = null
var _c_shutter: Sprite2D = null
var _team_k: float = 1.0
var _strobe_k: float = 0.0
var _shutter_k: float = 0.0
var _dent_flash: float = 0.0
var _dents: int = 0

# the hall camera
var _h_dim: ColorRect = null
var _queue: Array = []


func _ready() -> void:
	_bg.size = Gfx.SCREEN
	_bg.color = Gfx.INK0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	add_child(_cam)
	_world.position = Gfx.VIEW_POS
	_world.scale = Vector2(Gfx.VIEW_SCALE, Gfx.VIEW_SCALE)
	_cam.add_child(_world)
	_cam.add_child(_flat)
	_jump.position = Gfx.VIEW_POS
	_jump.scale = Vector2(Gfx.VIEW_SCALE, Gfx.VIEW_SCALE)
	_cam.add_child(_jump)
	add_child(_ccam)
	_close.position = CLOSE_AT
	_close.scale = Vector2(2, 2)
	_ccam.add_child(_close)
	_drape = Gfx.sprite(self, "theatre/drape.png")
	_drape.visible = false
	_crack = Gfx.sprite(self, "theatre/lens_crack.png")
	_crack.scale = Vector2(2, 2)
	_crack.visible = false
	_gore = GoreLayer.new()
	add_child(_gore)
	_gore.set_process(false)       # the film steps it, on its own clock
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_hud.draw.connect(_draw_hud)
	add_child(_hud)
	_trace.resize(100)


# ------------------------------------------------------------------ the shot list
## The film's shots for a night's settled appointments, in the order they were seen. Admitted
## patients go to the theatre; after one wakes on the table the relief crew takes the chair.
## A death at the glass ends the film, with the people still waiting shown only as a count on
## the hall camera. A night nobody was admitted on, and nobody died, ends on the empty chair.
static func plan(records: Array, unseen: int = 0) -> Array:
	var out: Array = []
	var admitted := 0
	var died := false
	var after := ""
	for r in records:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = r
		var id := str(rec.get("case_id", ""))
		var outcome := str(rec.get("outcome", ""))
		var shot := _shot_for("counter", rec)
		if outcome.begins_with("treated"):
			shot["kind"] = "theatre"
			shot["relief"] = after != ""
			shot["after"] = after
			admitted += 1
			out.append(shot)
			if outcome == "treated_drifting":
				after = id
		elif outcome == "hit":
			shot["kind"] = "death"
			out.append(shot)
			var hall := _shot_for("hall", {})
			hall["unseen"] = maxi(0, unseen)
			out.append(hall)
			died = true
			break
		else:
			out.append(shot)
	if admitted == 0 and not died:
		out.append(_shot_for("empty", {}))
	return out


static func _shot_for(kind: String, rec: Dictionary) -> Dictionary:
	var id := str(rec.get("case_id", ""))
	return {
		"kind": kind,
		"id": id,
		"name": str(rec.get("name", id.capitalize())),
		"outcome": str(rec.get("outcome", "")),
		"truth": str(rec.get("truth", "")),
		"title": str(rec.get("title", "")),
		"correct": bool(rec.get("correct", false)),
		"relief": false,
		"after": "",
		"unseen": 0,
	}


## records: the night's settlements (ShiftState.records). p_cases: tonight's composed cases by id;
## a patient missing from it is composed from the template. unseen: how many were still waiting.
func start(records: Array, clean: bool, p_cases: Dictionary = {}, p_meta: Dictionary = {}, unseen: int = 0) -> void:
	less_blood = clean
	_gore.less_blood = clean
	_cases = p_cases
	_meta = p_meta
	if _meta.is_empty():
		var m: Variant = CaseDB.load_json("res://assets/patients/meta.json")
		if typeof(m) == TYPE_DICTIONARY:
			_meta = m
	shots = plan(records, unseen)
	index = 0
	show()
	_begin()


func advance() -> void:
	if not visible or shots.is_empty():
		return
	if index + 1 < shots.size():
		index += 1
		_begin()
	else:
		finish()


func finish() -> void:
	if not visible:
		return
	_clear_shot()
	hide()
	finished.emit()


## One step of the film's own clock.
func step(delta: float) -> void:
	if not visible or shots.is_empty():
		return
	_pt = elapsed
	elapsed += delta
	_frame(delta)
	if elapsed >= _length:
		advance()


func _process(delta: float) -> void:
	step(delta)


# ------------------------------------------------------------------ helpers
func _at(x: float) -> bool:
	return _pt < x and elapsed >= x


func _k(a: float, b: float) -> float:
	if b <= a:
		return 1.0 if elapsed >= b else 0.0
	return clampf((elapsed - a) / (b - a), 0.0, 1.0)


static func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)


static func _ease_in(k: float) -> float:
	return k * k


static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## The camera, from (z0, f0, th0) at a to (z1, f1, th1) at b. Moves are applied in time order;
## the last one that has started holds the camera.
func _move(a: float, b: float, z0: float, z1: float, f0: Vector2, f1: Vector2, th0: float = 0.0, th1: float = 0.0) -> void:
	if elapsed < a:
		return
	var k := _smooth(_k(a, b))
	_z = lerpf(z0, z1, k)
	_f = f0.lerp(f1, k)
	_th = lerpf(th0, th1, k)


func _play(cue: String, pitch: float = 1.0, db: float = -6.0) -> void:
	if cue != "":
		sound.emit(cue, pitch, db)


func _loop(cue: String, on: bool, db: float = -6.0) -> void:
	if cue == "":
		return
	if on:
		_loops[cue] = true
	elif not _loops.has(cue):
		return
	else:
		_loops.erase(cue)
	loop_sound.emit(cue, on, db)


func _stop_loops() -> void:
	for cue in _loops.keys():
		loop_sound.emit(str(cue), false, 0.0)
	_loops.clear()


func _style_info() -> Dictionary:
	return STYLE.get(_style, STYLE["fist"])


func _stamp(title: String, color: Color, at := STAMP_AT) -> void:
	_stamp_text = title
	_stamp_col = color
	_stamp_at = at
	_stamp_t = 0.0
	_play("stamp", 1.0, -4.0)


func _stamp_color(outcome: String) -> Color:
	match outcome:
		"treated_ok", "referred_drifting", "caught", "locked_out":
			return Gfx.STAMP_G
		"treated_drifting", "hit":
			return Gfx.STAMP_R
	return Gfx.STAMP_A


## A patient's line, said with the mouth and the voice blips they had at the counter.
func _say(line: String) -> void:
	if line == "" or _rig == null:
		return
	_caption = "“%s”" % Lang.t(line)
	_rig.talking = true
	_talk_until = elapsed + clampf(0.05 * float(line.length()), 0.8, 1.5)
	_blip_in = 0.0


func _exit_line(key: String) -> String:
	var lines: Dictionary = _case_d.get("exit", {}) if typeof(_case_d.get("exit")) == TYPE_DICTIONARY else {}
	return str(lines.get(key, ""))


## The case as it was tonight: from tonight's composed cases, else composed from its template.
func _case(id: String, truth: String) -> Dictionary:
	if typeof(_cases.get(id)) == TYPE_DICTIONARY:
		return _cases[id]
	var t: Variant = CaseDB.load_json("res://data/cases/%s.json" % id)
	if typeof(t) != TYPE_DICTIONARY:
		return {"id": id, "name": id.capitalize()}
	var c: Dictionary = CaseDB.compose(t, {"truth": truth if truth != "" else "stable"})
	if c.is_empty():
		return {"id": id, "name": id.capitalize()}
	if _parts_db.is_empty():
		var p: Variant = CaseDB.load_json("res://data/parts.json")
		if typeof(p) == TYPE_DICTIONARY:
			_parts_db = p
	CaseDB.resolve_parts(c, _parts_db)
	return c


func _make_rig(c: Dictionary, back_parent: Node2D, front_parent: Node2D) -> void:
	_rig = PatientRig.new()
	add_child(_rig)
	_rig.set_process(false)        # the film steps it, on its own clock
	_rig.less_blood = less_blood
	_rig.slide = 0.0
	_rig.setup(c, _rig_meta)
	back_parent.add_child(_rig.back)
	front_parent.add_child(_rig.front)


## The patient leaves the frame they were in and comes at the lens, over everything.
func _take_rig() -> void:
	if _rig == null:
		return
	for n in [_rig.back, _rig.front]:
		var node: Node2D = n
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		_jump.add_child(node)


## A zone of the patient's picture (meta zones), in view space, with the patient at the counter.
func _zone(zone: String) -> Rect2:
	var zones: Dictionary = _rig_meta.get("zones", {}) if typeof(_rig_meta.get("zones")) == TYPE_DICTIONARY else {}
	var z: Variant = zones.get(zone)
	if typeof(z) != TYPE_ARRAY or (z as Array).size() < 4:
		return Rect2(Gfx.PATIENT_POS + Vector2(40, 60), Vector2(80, 20))
	var a: Array = z
	return Rect2(Gfx.PATIENT_POS + Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]), float(a[3])))


func _dry(path: String) -> String:
	if not less_blood:
		return path
	var clean := path.trim_suffix(".png") + "_clean.png"
	return clean if Gfx.has_tex(clean) else path


# ------------------------------------------------------------------ one shot
func _clear_shot() -> void:
	for layer in [_world, _flat, _jump, _close]:
		var node: Node = layer
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
	if _rig != null:
		remove_child(_rig)
		_rig.queue_free()
		_rig = null
	_stop_loops()
	_gore.clear()
	_eyes.clear()
	_rings.clear()
	_queue.clear()
	for k in ["_dim", "_lamp", "_lamp_lit", "_glow", "_door", "_decal", "_crew", "_crew_down", "_straps", "_back_slot", "_front_slot",
			"_close_fx", "_hand", "_old", "_new", "_hole", "_threads", "_eyes_front", "_empty_eye", "_beam",
			"_driver", "_forceps", "_held_d", "_held_f", "_c_rain", "_c_door", "_c_strobe", "_c_team",
			"_c_red", "_c_blue", "_c_glass", "_c_broken", "_c_crack", "_c_shutter", "_h_dim"]:
		set(k, null)
	_crack.visible = false
	_drape.visible = false
	_drape.modulate = Color.WHITE
	_close.visible = false
	_close.modulate = Color.WHITE
	_cam.visible = true
	_z = 1.0
	_f = C
	_th = 0.0
	_shake = 0.0
	_cshake = 0.0
	_flash = 0.0
	_static = 0.0
	_lost = false
	_black = 0.0
	_place = ""
	_name_on = false
	_caption = ""
	_stamp_text = ""
	_stamp_t = -1.0
	_talk_until = -1.0
	_ecg_on = false
	_ecg_alarm = false
	_ecg_flat = false
	_ecg_label = ""
	_hr = 84.0
	_hr_to = 84.0
	_beat = 0.0
	_trace.fill(0.0)
	_col = 0
	_sweep = 0.0
	_read_on = false
	_read_name = ""
	_read_value = ""
	_read_bad = false
	_verdict = ""
	_bar = -1.0
	_bar_bad = false
	_lamp_on = false
	_lamp_k = 0.0
	_swing_from = -1.0
	_strap_zone = Rect2()
	_strap_state = "shut"
	_team_k = 1.0
	_strobe_k = 0.0
	_shutter_k = 0.0
	_dent_flash = 0.0
	_dents = 0
	_drift = false


func _begin() -> void:
	_clear_shot()
	_shot = shots[index]
	_kind = str(_shot.get("kind", ""))
	var seed_value := hash(str(_shot.get("id", ""))) + index * 31 + 5
	_rng.seed = seed_value
	_gore._rng.seed = seed_value + 1
	_pt = -1.0
	elapsed = 0.0
	match _kind:
		"theatre":
			_build_theatre()
		"counter", "death":
			_build_counter()
		"hall":
			_build_hall()
		_:
			_build_empty()
	_frame(0.0)


func _frame(delta: float) -> void:
	match _kind:
		"theatre":
			_theatre_frame(delta)
		"counter":
			_counter_frame(delta)
		"death":
			_death_frame(delta)
		"hall":
			_hall_frame(delta)
		_:
			_empty_frame(delta)
	if _rig != null:
		if _rig.talking and _talk_until >= 0.0:
			if elapsed >= _talk_until:
				_rig.talking = false
				_talk_until = -1.0
			else:
				_blip_in -= delta
				if _blip_in <= 0.0:
					var voice: Dictionary = _case_d.get("voice", {}) if typeof(_case_d.get("voice")) == TYPE_DICTIONARY else {}
					var rate := maxf(0.4, float(voice.get("rate", 1.0)))
					_blip_in = 2.0 / (44.0 * rate)
					var cue := "blip_glitch" if bool(voice.get("glitch", false)) else "blip"
					_play(cue, float(voice.get("pitch", 1.0)) * _rng.randf_range(0.96, 1.05), -7.0)
		_rig._process(delta)
	_gore._process(delta)
	_ecg_step(delta)
	if _stamp_t >= 0.0:
		_stamp_t += delta
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	_shake = move_toward(_shake, 0.0, delta * 14.0)
	_cshake = move_toward(_cshake, 0.0, delta * 6.0)
	if _dent_flash > 0.0:
		_dent_flash = maxf(0.0, _dent_flash - delta)
	var sh := Vector2.ZERO
	if _shake > 0.05:
		sh = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake) * 0.6)
	_cam.scale = Vector2(_z, _z)
	_cam.rotation = _th
	_cam.position = (C - (_f * _z).rotated(_th) + sh).round()
	var csh := Vector2.ZERO
	if _cshake > 0.05:
		csh = Vector2(_rng.randf_range(-_cshake, _cshake), _rng.randf_range(-_cshake, _cshake))
	_ccam.position = csh.round()
	if _straps != null:
		_straps.queue_redraw()
	if _close_fx != null:
		_close_fx.queue_redraw()
	_fx.queue_redraw()
	_hud.queue_redraw()


# ------------------------------------------------------------------ the theatre
func _build_theatre() -> void:
	var id := str(_shot.get("id", ""))
	_case_d = _case(id, str(_shot.get("truth", "")))
	_pid = str(_case_d.get("sprite", id))
	_rig_meta = _meta.get(_pid, {}) if typeof(_meta.get(_pid)) == TYPE_DICTIONARY else {}
	_site = str(SITES.get(id, "hand"))
	var attack: Dictionary = _rig_meta.get("attack", {}) if typeof(_rig_meta.get("attack")) == TYPE_DICTIONARY else {}
	_style = str(attack.get("style", "fist"))
	_drift = str(_shot.get("outcome", "")) == "treated_drifting"
	var relief := bool(_shot.get("relief", false))
	_place = "THEATRE HEADCAM"
	_ecg_on = true
	_hr = 84.0
	_hr_to = 84.0
	_build_room(relief, str(_shot.get("after", "")))
	_make_rig(_case_d, _back_slot, _front_slot)
	_strap_zone = _zone("hands")
	var hands := _zone("hands")
	var eyes := _zone("eyes")
	match _site:
		"hand":
			_focus = Gfx.to_screen(hands.get_center())
		"eye_l":
			_focus = Gfx.to_screen(Vector2(eyes.position.x + eyes.size.x * 0.75, eyes.get_center().y))
		"eye_r":
			_focus = Gfx.to_screen(Vector2(eyes.position.x + eyes.size.x * 0.25, eyes.get_center().y))
		_:
			_focus = Gfx.to_screen(_zone("port").get_center())
	_face = Gfx.to_screen(eyes.get_center())
	_build_close(relief)
	if _site == "hand":
		var grip: Dictionary = _case_d.get("grip", {}) if typeof(_case_d.get("grip")) == TYPE_DICTIONARY else {}
		var limit := maxf(0.3, float(int(grip.get("limit_ms", 1000))) / 1000.0)
		_cal_end = 4.75 + (limit if _drift else minf(maxf(0.55 * limit, 0.25), 0.8 * limit))
	elif _site == "eye_l" or _site == "eye_r":
		_cal_end = 5.2 if _drift else 5.6
	else:
		_cal_end = 5.2
	_length = _cal_end + (5.4 if _drift else 3.4)


## The room and its props, in view space. back_slot and front_slot are where a patient goes:
## behind the armrest and in front of it.
func _build_room(relief: bool, after: String) -> void:
	Gfx.sprite(_world, "theatre/room.png", T_OFF)
	_door = Gfx.sprite(_world, "theatre/door_open.png", T_OFF)
	_door.visible = false
	var scorch := less_blood
	if after != "":
		var meta_after: Dictionary = _meta.get(after, {}) if typeof(_meta.get(after)) == TYPE_DICTIONARY else {}
		var a: Dictionary = meta_after.get("attack", {}) if typeof(meta_after.get("attack")) == TYPE_DICTIONARY else {}
		var st: Dictionary = STYLE.get(str(a.get("style", "fist")), STYLE["fist"])
		scorch = scorch or str(st["strike"]) == "burn"
	_decal = Gfx.sprite(_world, "theatre/decal_scorch.png" if scorch else "theatre/decal_blood.png", T_OFF)
	_decal.visible = relief
	_crew = Gfx.sprite(_world, "theatre/crew_relief.png" if relief else "theatre/crew.png", T_OFF)
	_crew_down = Gfx.sprite(_world, "theatre/crew_down_relief.png" if relief else "theatre/crew_down.png", T_OFF)
	_crew_down.visible = false
	Gfx.sprite(_world, "theatre/chair.png", T_OFF)
	_back_slot = Node2D.new()
	_world.add_child(_back_slot)
	Gfx.sprite(_world, "theatre/armrest.png", T_OFF)
	_front_slot = Node2D.new()
	_world.add_child(_front_slot)
	_straps = Node2D.new()
	_world.add_child(_straps)
	_straps.draw.connect(_draw_straps)
	Gfx.sprite(_world, "theatre/tray.png", T_OFF)
	_dim = ColorRect.new()
	_dim.position = T_OFF
	_dim.size = T_SIZE
	_dim.color = Color(Gfx.INK0, 0.86)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_dim)
	_lamp = Gfx.sprite(_world, "theatre/lamp.png", LAMP_AT)
	_lamp.offset = -LAMP_PIVOT
	_lamp_lit = Gfx.sprite(_lamp, "theatre/lamp_lit.png")
	_lamp_lit.offset = -LAMP_PIVOT
	_lamp_lit.visible = false
	_glow = Gfx.sprite(_world, "theatre/lamp_glow.png", T_OFF)
	_glow.material = Gfx.additive()
	_glow.modulate = Color(1, 1, 1, 0.0)
	_apply_lamp()


func _apply_lamp() -> void:
	if _dim != null:
		_dim.color = Color(Gfx.INK0, lerpf(0.86, 0.06, _lamp_k))
	if _lamp != null:
		var v := lerpf(0.25, 1.0, _lamp_k)
		_lamp.modulate = Color(v, v, v, 1.0)
		_lamp_lit.visible = _lamp_k > 0.5
	if _glow != null:
		_glow.modulate = Color(1, 1, 1, 0.55 * _lamp_k)


## The close-up the counter showed for this patient's part, with the part itself on top, built
## hidden: the gloves, what they hold and the calibration light come and go over it.
func _build_close(relief: bool) -> void:
	_close.visible = false
	match _site:
		"hand":
			Gfx.sprite(_close, "theatre/board.png")
			_hand = Gfx.sprite(_close, "scope/%s/grip_open.png" % _pid)
			Gfx.sprite(_close, "theatre/hatch.png", Vector2(91, 41))
			_old = Gfx.sprite(_close, "theatre/cart_old.png", Vector2(95, 46))
			_new = Gfx.sprite(_close, "theatre/cart_new.png", Vector2(95, 46))
			_new.visible = false
			_target = HAND_PART
		"eye_l", "eye_r":
			_build_eyes()
		"port":
			Gfx.sprite(_close, "scope/%s/port.png" % _pid)
			_hole = Gfx.sprite(_close, "theatre/jack_hole.png", Vector2(68, 58))
			_hole.visible = false
			_old = Gfx.sprite(_close, "theatre/jack_old.png", Vector2(68, 58))
			_new = Gfx.sprite(_close, "theatre/jack_new.png", Vector2(68, 58))
			_new.visible = false
			_add_threads()
			_target = PORT_PART
		_:
			Gfx.sprite(_close, "scope/%s/port.png" % _pid)
			_hole = Gfx.sprite(_close, "theatre/box_hole.png", Vector2(43, 43))
			_hole.visible = false
			_old = Gfx.sprite(_close, "theatre/box_old.png", Vector2(43, 43))
			_new = Gfx.sprite(_close, "theatre/box_new.png", Vector2(43, 43))
			_new.visible = false
			_add_threads()
			_target = VOICE_PART
	_close_fx = Node2D.new()
	_close_fx.material = Gfx.dither(true, 1.0, 2.0)
	_close.add_child(_close_fx)
	_close_fx.draw.connect(_draw_close_fx)
	Gfx.sprite(_close, "scope/vignette.png")
	var tint := "_relief" if relief else ""
	_driver = Gfx.sprite(_close, "theatre/glove_driver%s.png" % tint)
	_driver.visible = false
	_held_d = _held(_driver)
	_forceps = Gfx.sprite(_close, "theatre/glove_forceps%s.png" % tint)
	_forceps.visible = false
	_held_f = _held(_forceps)
	_glove(_driver, _target + Vector2(120, 120))
	_glove(_forceps, _target + Vector2(90, 130))


func _held(glove: Sprite2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.show_behind_parent = true
	s.visible = false
	glove.add_child(s)
	return s


func _hold(holder: Sprite2D, tex: Texture2D) -> void:
	holder.texture = tex
	holder.visible = tex != null
	if tex != null:
		holder.position = (GLOVE_TIP - tex.get_size() / 2.0).round()


func _glove(glove: Sprite2D, tip: Vector2) -> void:
	glove.position = (tip - GLOVE_TIP).round()


func _add_threads() -> void:
	var path := "scope/%s/port_threads.png" % _pid
	if Gfx.has_tex(path):
		_threads = Gfx.sprite(_close, path)
		_threads.modulate = Color(1, 1, 1, 0.0)


func _build_eyes() -> void:
	Gfx.sprite(_close, "scope/%s/eyes_back.png" % _pid)
	var eyes: Dictionary = _case_d.get("eyes", {}) if typeof(_case_d.get("eyes")) == TYPE_DICTIONARY else {}
	var site_side := "left" if _site == "eye_l" else "right"
	for side in ["right", "left"]:
		var spec: Dictionary = eyes.get(side, {}) if typeof(eyes.get(side)) == TYPE_DICTIONARY else {}
		var pos: Vector2 = EYE_R if side == "right" else EYE_L
		var kind := str(spec.get("kind", "natural"))
		var react := str(spec.get("pupil", "tightens" if kind == "natural" else "none"))
		var tightens := bool(spec.get("tightens", react != "none"))
		var iris := Gfx.sprite(_close, "scope/%s/iris_%s.png" % [_pid, "r" if side == "right" else "l"], pos - Vector2(24, 24))
		var pupil: Sprite2D = null
		if react == "tightens" or (react == "shutter" and tightens):
			pupil = Gfx.sprite(_close, "scope/pupil_9.png", pos - Vector2(12, 12))
		_eyes.append({"pos": pos, "kind": kind, "tightens": tightens, "follows": bool(spec.get("follows", true)),
			"iris": iris, "pupil": pupil, "off": Vector2.ZERO, "size": PUPIL_WIDE, "site": side == site_side})
	_eyes_front = Gfx.sprite(_close, "scope/%s/eyes_front.png" % _pid)
	_target = EYE_L if _site == "eye_l" else EYE_R
	_empty_eye = Gfx.sprite(_close, "theatre/eye_empty.png", _target - Vector2(24, 24))
	_empty_eye.visible = false
	# the other eye is covered while the light is on this one
	Gfx.sprite(_close, "theatre/gauze.png", Vector2(32, 62) if _site == "eye_l" else Vector2(132, 62))
	_beam = Gfx.sprite(_close, "scope/light.png")
	_beam.material = Gfx.additive()
	_beam.modulate = Color(1, 1, 1, 0.85)
	_beam.visible = false


func _site_eye() -> Dictionary:
	for e in _eyes:
		var eye: Dictionary = e
		if bool(eye["site"]):
			return eye
	return {}


func _theatre_frame(delta: float) -> void:
	var c := _cal_end
	# the lamp comes on with a stutter over a patient already in the chair
	if _at(0.08):
		_lamp_on = true
		_play("light_on", 1.0, -4.0)
	if _at(0.14):
		_lamp_on = false
	if _at(0.22):
		_lamp_on = true
	if _at(0.26):
		_lamp_on = false
	if _at(0.34):
		_lamp_on = true
	_lamp_k = 1.0 if _lamp_on else 0.0
	_apply_lamp()
	if _at(0.6):
		_say(_exit_line("treat"))
	if _at(0.9):
		_name_on = true
	if _at(1.9):
		_play("hiss", 1.0, -8.0)
	if _at(2.1):
		_rig.sleeping = true
		_hr_to = 64.0
	if _at(2.2):
		_caption = Lang.t(str(_case_d.get("request", "")))
	_move(2.4, 2.95, 1.0, 2.4, C, _focus)
	if _at(3.0):
		_cam.visible = false
		_close.visible = true
		_drape.visible = true
		_driver.visible = true
		_forceps.visible = true
	if elapsed >= 3.0 and elapsed < c + 0.3:
		var k := _ease_out(_k(3.0, 3.2))
		var s := lerpf(3.2, 2.0, k)
		_drape.scale = Vector2(s, s)
		_drape.position = (Vector2(320, 156) - s * Vector2(160, 78)).round()
		_drape.modulate.a = lerpf(0.3, 1.0, k)
	_swap(delta)
	_calibrate(delta)
	if _drift:
		_wakes(delta)
	else:
		_holds(delta)


## The same for everyone: the old part out with the driver, the new one in with the forceps.
func _swap(_delta: float) -> void:
	var t := _target
	if elapsed >= 3.0 and elapsed < 3.3:
		_glove(_driver, (t + Vector2(120, 120)).lerp(t, _ease_out(_k(3.0, 3.3))))
	elif elapsed >= 3.3 and elapsed < 3.6:
		_glove(_driver, t + Vector2(_rng.randi_range(-1, 1), _rng.randi_range(-1, 1)))
	elif elapsed >= 3.6 and elapsed < 3.95:
		_glove(_driver, t.lerp(t + Vector2(110, 110), _ease_in(_k(3.6, 3.9))))
	if _at(3.3):
		_play("driver", 1.0, -6.0)
	if _at(3.32) or _at(3.45):
		_gore.sparks(Gfx.to_view(CLOSE_AT + t * 2.0), 6, Vector2(1, -1), 1.0, 40.0, 120.0)
	if _at(3.55):
		_lift_old()
	if elapsed >= 3.9 and elapsed < 4.1:
		_glove(_forceps, (t + Vector2(90, 130)).lerp(t + Vector2(6, -8), _ease_out(_k(3.9, 4.1))))
	elif elapsed >= 4.1 and elapsed < 4.45:
		_glove(_forceps, (t + Vector2(6, -8)).lerp(t, _smooth(_k(4.1, 4.45))))
	elif elapsed >= 4.5 and elapsed < 4.75:
		_glove(_forceps, t.lerp(t + Vector2(90, 130), _ease_in(_k(4.5, 4.7))))
	if _at(4.45):
		_seat_new()


func _lift_old() -> void:
	if _site == "hand" or _site == "port" or _site == "voice":
		_hold(_held_d, _old.texture)
		_old.visible = false
		if _hole != null:
			_hole.visible = true
		_hold(_held_f, _new.texture)
	else:
		var eye := _site_eye()
		if eye.is_empty():
			return
		var iris: Sprite2D = eye["iris"]
		_hold(_held_d, iris.texture)
		iris.visible = false
		var pupil: Sprite2D = eye["pupil"]
		if pupil != null:
			pupil.visible = false
		_empty_eye.visible = true
		var fixed := "theatre/dana/iris_fixed.png" if _pid == "dana" else ""
		_hold(_held_f, Gfx.tex(fixed) if fixed != "" else iris.texture)
	_play("click", 0.8, -8.0)


func _seat_new() -> void:
	_play("seat", 1.0, -4.0)
	_held_f.visible = false
	if _site == "hand" or _site == "port" or _site == "voice":
		_new.visible = true
		if _hole != null:
			_hole.visible = false
		return
	var eye := _site_eye()
	if eye.is_empty():
		return
	var iris: Sprite2D = eye["iris"]
	if _pid == "dana" and Gfx.has_tex("theatre/dana/iris_fixed.png"):
		iris.texture = Gfx.tex("theatre/dana/iris_fixed.png")
	iris.visible = true
	var pupil: Sprite2D = eye["pupil"]
	if pupil != null:
		pupil.visible = true
	_empty_eye.visible = false
	if _pid == "kip" and Gfx.has_tex("theatre/kip/eyes_front_fixed.png"):
		_eyes_front.texture = Gfx.tex("theatre/kip/eyes_front_fixed.png")


## The new part is tested the way the counter tested it, and the reading says what tonight is.
func _calibrate(delta: float) -> void:
	var c := _cal_end
	if _at(4.7):
		_read_on = true
		_read_name = str(TESTS.get(_site, "GRIP TEST"))
		_verdict = ""
	match _site:
		"hand":
			var grip: Dictionary = _case_d.get("grip", {}) if typeof(_case_d.get("grip")) == TYPE_DICTIONARY else {}
			var limit := maxf(0.3, float(int(grip.get("limit_ms", 1000))) / 1000.0)
			if _at(4.75):
				_hand.texture = Gfx.tex("scope/%s/grip_closed.png" % _pid)
				_play("grip_squeeze", 1.0, -6.0)
			if elapsed >= 4.7:
				var held := maxf(0.0, elapsed - 4.75)
				if not _drift:
					held = minf(held, c - 4.75)
				elif elapsed >= c + 0.9:
					held = c + 0.9 - 4.75
				_read_value = Lang.tf("%.1f s / %.1f s", [held, limit])
				_read_bad = _drift and held > limit
			if not _drift and _at(c):
				_hand.texture = Gfx.tex("scope/%s/grip_open.png" % _pid)
				_hand.position = Vector2.ZERO
				_play("grip_release", 1.0, -6.0)
			if _drift and elapsed >= 4.75 + 0.6 * limit and elapsed < c + 0.9:
				if int(elapsed * 24.0) != int(_pt * 24.0):
					_hand.position = Vector2(_rng.randi_range(-1, 1), 0)
		"eye_l", "eye_r":
			if _at(4.7):
				_beam.visible = true
			var e := _target
			var a := Vector2(e.x - 70, e.y - 30)
			var b := Vector2(e.x + 50, e.y - 10)
			var light := a
			if elapsed >= 5.1:
				light = e.lerp(b, _smooth(_k(5.1, 5.6)))
			elif elapsed >= 4.7:
				light = a.lerp(e, _smooth(_k(4.7, 5.1)))
			if _beam.visible:
				_beam.position = (light - Vector2(55, 55)).round()
			if elapsed >= 4.7:
				_eyes_step(delta, light, _drift and elapsed >= 5.0)
			if not _drift and _at(c):
				_beam.visible = false
		"port":
			if elapsed >= 4.75:
				if _drift:
					if _threads != null:
						_threads.modulate.a = _k(4.75, 5.2) * (0.8 + 0.2 * sin(elapsed * 9.0))
					_bar = clampf(0.55 + 0.4 * sin(elapsed * 23.0) * minf(1.0, (elapsed - 4.75) * 3.0), 0.0, 1.0)
					_bar_bad = elapsed >= 4.95
				else:
					_bar = _ease_out(_k(4.75, 5.2)) * 0.62
					_bar_bad = false
				var period := 0.35
				var pinging := elapsed < c + (0.7 if _drift else 0.0)
				if pinging and (int((elapsed - 4.75) / period) != int((_pt - 4.75) / period) or _at(4.75)):
					_rings.append(elapsed)
					_play("blip", 1.6 if not _drift else 0.7, -14.0)
		_:
			if not _drift:
				if _at(4.9) or _at(5.05):
					_play("note", 1.0 if elapsed < 5.0 else 1.26, -6.0)
			elif elapsed >= 4.75 and elapsed < c + 0.7:
				if _threads != null:
					_threads.modulate.a = _k(4.75, 5.2) * (0.8 + 0.2 * sin(elapsed * 9.0))
				var n := int((elapsed - 4.75) / 0.2)
				if n != int((_pt - 4.75) / 0.2) or _at(4.75):
					_play("note", [1.0, 1.26, 0.84][n % 3], -6.0)


func _eyes_step(delta: float, light: Vector2, stare: bool) -> void:
	for e in _eyes:
		var eye: Dictionary = e
		var pos: Vector2 = eye["pos"]
		var d := light - pos
		var reach: Vector2 = REACH.get(str(eye["kind"]), Vector2(10, 4))
		var target := Vector2.ZERO
		if bool(eye["follows"]):
			target = Vector2(clampf(d.x * 0.2, -reach.x, reach.x), clampf(d.y * 0.16, -reach.y, reach.y))
		var site := bool(eye["site"])
		if stare and site:
			target = Vector2(float(_rng.randi_range(-1, 1)), 0.0)      # it stops following: it looks at the lens
		var off: Vector2 = eye["off"]
		off = off.lerp(target, 1.0 - exp(-delta * (30.0 if stare and site else 9.0)))
		eye["off"] = off
		var size: float = eye["size"]
		var want := PUPIL_WIDE
		if d.length() < LIT_DIST and bool(eye["tightens"]) and not (stare and site):
			want = PUPIL_TIGHT
		size = move_toward(size, want, delta * (15.0 if want < size else 7.0))
		eye["size"] = size
		var iris: Sprite2D = eye["iris"]
		iris.position = (pos - Vector2(24, 24) + off).round()
		var pupil: Sprite2D = eye["pupil"]
		if pupil != null:
			pupil.position = (pos - Vector2(12, 12) + off).round()
			pupil.texture = Gfx.tex("scope/pupil_%d.png" % clampi(roundi(size), 4, 10))


## The reading settles: back out, the patient wakes and uses the part, and leaves.
func _holds(_delta: float) -> void:
	var c := _cal_end
	if _at(c):
		_verdict = "IN SPEC"
		_verdict_ok = true
		_play("cal_ok", 1.0, -4.0)
		_caption = Lang.t("The repair holds.")
	if _at(c + 0.3):
		_cam.visible = true
		_read_on = false
	if elapsed >= c + 0.3 and elapsed < c + 0.65:
		var fade := 1.0 - _k(c + 0.3, c + 0.6)
		_close.modulate.a = fade
		_drape.modulate.a = fade
	if _at(c + 0.62):
		_close.visible = false
		_drape.visible = false
	_move(c + 0.4, c + 0.95, 2.4, 1.0, _focus, C)
	if _at(c + 0.7):
		_rig.wake()
		_hr_to = 80.0
	if _at(c + 0.8):
		match _site:
			"hand":
				_rig.react("", "fist")
			"eye_l", "eye_r":
				_rig.blink()
				_rig.glance(Vector2(2, 0), 0.8)
			"port":
				_rig.blink()
			_:
				_rig.talking = true
				_talk_until = -1.0
	if _site == "hand" and _at(c + 1.3):
		_rig.release_hands()
	if _site == "voice":
		var notes := [[0.8, 1.0], [0.95, 1.12], [1.1, 1.26], [1.25, 1.5]]
		for n in notes:
			if _at(c + float(n[0])):
				_play("note", float(n[1]), -5.0)
		if _at(c + 1.45):
			_rig.talking = false
	if _at(c + 1.2):
		_stamp(str(_shot.get("title", "")), Gfx.STAMP_G)
	if _at(c + 1.7):
		_strap_state = "open"
		_play("strap", 1.0, -6.0)
	if elapsed >= c + 1.8:
		_rig.slide = -_ease_in(_k(c + 1.8, c + 3.2))      # off to the left, the way out
	for s in [1.9, 2.3, 2.7]:
		if _at(c + float(s)):
			_play("step", 1.0, -10.0)


## The reading never settles: the patient wakes on the table.
func _wakes(_delta: float) -> void:
	var c := _cal_end
	if _at(c):
		_verdict = "OUT OF SPEC"
		_verdict_ok = false
		_play("cal_bad", 1.0, -4.0)
		_loop("alarm", true, -8.0)
		_hr_to = 150.0
		_ecg_alarm = true
		_caption = Lang.t("The reading will not settle.")
		_cshake = 2.0
	if _site == "hand" and elapsed >= c and elapsed < c + 0.8:
		# forceps try to open the hand; it closes on them
		if elapsed < c + 0.15:
			_glove(_forceps, (_target + Vector2(90, 130)).lerp(PRY_AT, _ease_out(_k(c, c + 0.15))))
		elif elapsed < c + 0.6:
			_glove(_forceps, PRY_AT + Vector2(_rng.randi_range(-2, 2), _rng.randi_range(-2, 2)))
		else:
			_glove(_forceps, PRY_AT.lerp(PRY_AT + Vector2(150, 60), _ease_in(_k(c + 0.6, c + 0.75))))
		if _at(c + 0.6):
			_play("crunch", 1.0, -2.0)
			_cshake = 4.0
			_gore.sparks(Gfx.to_view(CLOSE_AT + PRY_AT * 2.0), 10, Vector2(1, -1), 1.4, 60.0, 180.0)
	if _at(c + 0.7):
		_loop("alarm", false)
		_play("tinnitus", 1.0, -4.0)
	if _at(c + 0.9):
		# the surgeon looks up
		_rig.wake()
		_rig.frozen = true
		_close.visible = false
		_drape.visible = false
		_cam.visible = true
		_read_on = false
		_ecg_alarm = true
	_move(c + 0.9, c + 1.3, 2.4, 2.2, _focus, _face)
	if _at(c + 1.3):
		_play("heartbeat", 1.0, 0.0)
	if _at(c + 1.7):
		_rig.frozen = false
		_rig.set_attack(true)
		_strap_state = "torn"
		_play("tear", 1.0, -2.0)
		_play("strap", 0.7, -4.0)
		_loop(str(_style_info()["loop"]), true, -6.0)
		_shake = 3.0
	_move(c + 1.7, c + 1.95, 2.2, 1.0, _face, C)
	if _at(c + 1.95):
		_take_rig()
		_rig.pop_target = Gfx.to_view(C + Vector2(0, 10))
		_play("scream", float(_style_info()["pitch"]), -2.0)
	if elapsed >= c + 1.95 and elapsed < c + 2.4:
		_rig.pop = 1.1 * _ease_in(_k(c + 1.95, c + 2.3))
	if _at(c + 2.3):
		_strike(Vector2(320, 160))
	if elapsed >= c + 2.4 and elapsed < c + 2.9:
		_static = 1.0
		_lost = true
	if _at(c + 2.4):
		_play("static", 1.0, -6.0)
		_caption = Lang.t("Headcam signal lost.")
		_rig.back.visible = false
		_rig.front.visible = false
		_stop_loops()
		_ecg_flat = true
	if _at(c + 2.9):
		# the headcam on the floor
		_lost = false
		_crew.visible = false
		_crew_down.visible = true
		_door.visible = true
		_decal.texture = Gfx.tex("theatre/decal_scorch.png" if less_blood or str(_style_info()["strike"]) == "burn" else "theatre/decal_blood.png")
		_decal.visible = true
		_strap_state = "torn"
		_swing_from = elapsed
		_play("flatline", 1.0, -14.0)
		_caption = Lang.tf("%s left by the back door.", [str(_shot.get("name", ""))])
	if elapsed >= c + 2.9:
		# it rolls to a stop on its side
		_th = FLOOR_TH + FLOOR_ROLL * (1.0 - _ease_out(_k(c + 2.9, c + 3.4)))
		_z = FLOOR_Z
		_f = FLOOR_F
		_static = 1.0 - _k(c + 2.9, c + 3.15)
		for g in [3.8, 4.6]:
			var at := c + float(g)
			if elapsed >= at and elapsed < at + 0.08:
				_static = 0.8
			if _at(at):
				_play("static", 1.0, -14.0)
		if _swing_from >= 0.0 and _lamp != null:
			var since := elapsed - _swing_from
			_lamp.rotation = 0.22 * sin(2.4 * since) * exp(-0.35 * since)
	if _at(c + 3.6):
		_stamp(str(_shot.get("title", "")), Gfx.STAMP_R, FLOOR_STAMP)


## The blow that lands on the lens, in the attacker's own way.
func _strike(at: Vector2) -> void:
	var st := _style_info()
	var glow_hex := str(st["glow"])
	var glow := Color(glow_hex) if glow_hex != "" else Gfx.WARM7
	match str(st["strike"]):
		"burn":
			_gore.bloom(at, glow, 300.0, 0.5)
			_gore.afterimage(at, 60.0)
			_flash = 0.9
			_flash_col = glow
		"claw":
			for i in 5:
				var a := at + Vector2(-150.0 + 60.0 * float(i), -110.0)
				var b := a + Vector2(70, 230)
				_gore.slash(a, b, 0.6)
				_gore.gash(a, b, 0.05 * float(i), 0.6)
			_flash = 0.35
			_flash_col = Color.WHITE
		"smash":
			_gore.impact(at, 180.0, 0.5)
			_flash = 0.8
			_flash_col = Color.WHITE
		_:
			var a := at + Vector2(-260, -120)
			var b := at + Vector2(240, 110)
			_gore.slash(a, b, 1.0)
			_gore.gash(a, b, 0.05, 1.0)
			_flash = 0.4
			_flash_col = Color.WHITE
	_gore.splat(at + Vector2(-60, -20), "l", 1.0, 0.0)
	_gore.splat(at + Vector2(90, 30), "m", 1.0, 0.05)
	_gore.splat(at + Vector2(-150, 70), "s", 1.0, 0.1)
	_crack.visible = true
	_shake = 7.0
	_play("hit", 1.0, -2.0)
	_play(str(st["bite"]), float(st["pitch"]), -4.0)


# ------------------------------------------------------------------ the counter
func _build_counter() -> void:
	var id := str(_shot.get("id", ""))
	_case_d = _case(id, str(_shot.get("truth", "")))
	_pid = str(_case_d.get("sprite", id))
	_rig_meta = _meta.get(_pid, {}) if typeof(_meta.get(_pid)) == TYPE_DICTIONARY else {}
	var attack: Dictionary = _rig_meta.get("attack", {}) if typeof(_rig_meta.get("attack")) == TYPE_DICTIONARY else {}
	_style = str(attack.get("style", "fist"))
	_place = "COUNTER CAMERA"
	var origin := Gfx.HOLE.position
	Gfx.sprite(_world, "clinic/hall.png", origin)
	_c_rain = Gfx.sprite(_world, "clinic/rain_0.png", Vector2(337, 56))
	_c_door = Gfx.sprite(_world, "clinic/door_open.png", origin)
	_c_door.visible = false
	_c_strobe = ColorRect.new()
	_c_strobe.position = origin
	_c_strobe.size = Gfx.HOLE.size
	_c_strobe.color = Color(0, 0, 0, 0)
	_c_strobe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_c_strobe)
	_c_team = Node2D.new()
	_c_team.visible = false
	_world.add_child(_c_team)
	Gfx.sprite(_c_team, "clinic/team.png")
	Gfx.sprite(_c_team, "clinic/team_lights.png")
	_c_red = Gfx.sprite(_c_team, "clinic/team_red.png")
	_c_blue = Gfx.sprite(_c_team, "clinic/team_blue.png")
	var back_slot := Node2D.new()
	_world.add_child(back_slot)
	Gfx.sprite(_world, "clinic/sill.png", Vector2(origin.x, 185))
	var front_slot := Node2D.new()
	_world.add_child(front_slot)
	var glow := Gfx.sprite(_world, "clinic/lamp_glow.png", Vector2(170, 18))
	glow.material = Gfx.additive()
	glow.modulate = Color(1, 1, 1, 0.5)
	_c_glass = Gfx.sprite(_world, "clinic/glass.png", origin)
	_c_glass.modulate = Color(1, 1, 1, 0.42)
	_c_broken = Gfx.sprite(_world, _dry("fx/glass_broken.png"), origin)
	_c_broken.visible = false
	_c_crack = Gfx.sprite(_world, "fx/crack_1.png", origin)
	_c_crack.visible = false
	_c_shutter = Gfx.sprite(_world, "clinic/shutter.png", Vector2(origin.x, origin.y - 190.0))
	Gfx.sprite(_flat, "clinic/booth.png")
	_make_rig(_case_d, back_slot, front_slot)
	_length = 5.2 if _kind == "death" else 3.4


func _counter_common(_delta: float) -> void:
	var frame := int(elapsed / 0.11) % 3
	_c_rain.texture = Gfx.tex("clinic/rain_%d.png" % frame)
	var red := fmod(elapsed, BEACON_BEAT * 2.0) < BEACON_BEAT
	_c_team.visible = _team_k < 0.999
	_c_door.visible = _c_team.visible
	if _c_team.visible:
		var walking := _team_k > 0.001 and _team_k < 0.999
		var step_up := roundf(absf(sin(elapsed * 13.0))) if walking else 0.0
		_c_team.position = Gfx.HOLE.position + TEAM_POS + Vector2(roundf(_team_k * TEAM_OUT), -step_up)
		_c_red.visible = red
		_c_blue.visible = not red
	if _strobe_k > 0.0:
		var fall := 1.0 - fmod(elapsed, BEACON_BEAT) / BEACON_BEAT
		var col := BEACON_RED if red else BEACON_BLUE
		_c_strobe.color = Color(col.r, col.g, col.b, _strobe_k * (0.05 + 0.11 * fall))
	else:
		_c_strobe.color = Color(0, 0, 0, 0)
	var y := roundf(Gfx.HOLE.position.y - 190.0 + 190.0 * _shutter_k + _dent_flash * 8.0)
	_c_shutter.position = Vector2(Gfx.HOLE.position.x, y)


## Something hits the far side of the shutter.
func _dent(local: Vector2, deep: bool) -> void:
	var t := Gfx.tex(("fx/dent_deep_%d.png" if deep else "fx/dent_%d.png") % (_dents % 3))
	_dents += 1
	_dent_flash = 0.4 if deep else 0.25
	if t == null:
		return
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.position = (local - t.get_size() / 2.0).round()
	_c_shutter.add_child(sp)


func _counter_frame(delta: float) -> void:
	var o := str(_shot.get("outcome", ""))
	var line := str(COUNTER_LINES.get(o, ""))
	if _at(0.15):
		_name_on = true
	match o:
		"referred_stable", "referred_drifting":
			if _at(0.2):
				_say(_exit_line("refer" if o == "referred_stable" else "taken"))
			if _at(0.6):
				_strobe_k = 1.0
				_play("siren", 1.0, -10.0)
			if elapsed < 1.8:
				_team_k = 1.0 - _ease_out(_k(0.6, 1.0))
			else:
				_team_k = _ease_in(_k(1.8, 2.6))
				_rig.slide = _ease_in(_k(1.8, 2.6))
			if o == "referred_drifting":
				if _at(1.1):
					_rig.set_attack(true)
					_play("sting", 1.0, -6.0)
				if _at(1.28):
					_rig.set_attack(false)
					_rig.react("upset", "")
			elif _at(1.2):
				_rig.react("upset", "")
			if _at(1.7):
				_caption = Lang.t(line)
		"caught":
			if _at(0.1):
				_rig.set_attack(true)
				_loop(str(_style_info()["loop"]), true, -10.0)
			_shutter_k = _ease_in(_k(0.4, 0.6))
			if _at(0.6):
				_play("shutter_slam", 1.0, -2.0)
				_shake = 4.0
				_stop_loops()
			var dents := [[0.9, Vector2(78, 100)], [1.3, Vector2(142, 88)], [1.7, Vector2(110, 128)]]
			for d in dents:
				if _at(float(d[0])):
					_dent(d[1], true)
					_play("bang", 0.9, -4.0)
					_shake = 2.0
			if _at(0.3):
				_caption = Lang.t(line)
		"locked_out":
			if _at(0.6):
				_play("shutter_roll", 1.0, -6.0)
			_shutter_k = _k(0.6, 1.4)
			if _at(1.9):
				_dent(Vector2(110, 110), false)
				_play("bang", 0.7, -14.0)
			if _at(0.3):
				_caption = Lang.t(line)
		"false_alarm":
			if _at(0.3):
				_rig.react("upset", "")
				_caption = Lang.t(line)
			_shutter_k = _ease_in(_k(0.3, 0.5))
			if _at(0.5):
				_play("shutter_slam", 1.0, -4.0)
				_shake = 3.0
		"walkout":
			if _at(0.3):
				_caption = Lang.t(line)
			if _at(0.4):
				_rig.react("angry", "slam")
				_play("bang", 1.0, -4.0)
			if elapsed >= 0.9:
				_rig.slide = _ease_in(_k(0.9, 1.9))
			for s in [1.0, 1.35, 1.7]:
				if _at(float(s)):
					_play("step", 1.0, -10.0)
		_:
			if _at(0.2):
				_say(_exit_line("gave_up"))
			if elapsed >= 1.4:
				_rig.slide = _ease_in(_k(1.4, 2.4))
			for s in [1.5, 1.85, 2.2]:
				if _at(float(s)):
					_play("step", 1.0, -10.0)
			if _at(1.7):
				_caption = Lang.t(line if line != "" else "Gave up waiting. Not admitted.")
	if _at(2.0):
		_stamp(str(_shot.get("title", "")), _stamp_color(o))
	_counter_common(delta)


## The doctor's last moment: the patient through the glass, and the view goes over.
func _death_frame(delta: float) -> void:
	if _at(0.0):
		_name_on = true
		_rig.set_attack(true)
		_c_crack.texture = Gfx.tex("fx/crack_2.png")
		_c_crack.visible = true
		_loop(str(_style_info()["loop"]), true, -8.0)
	if _at(0.5):
		_rig.blow(3)
		_c_crack.texture = Gfx.tex("fx/crack_3.png")
		_gore.chips(Gfx.HOLE.get_center(), 14)
		_play("glass_crack", 1.0, -4.0)
		_shake = 3.0
	if _at(1.0):
		_play("glass_shatter", 1.0, -2.0)
		_gore.burst_shards(Gfx.HOLE, 64)
		_c_glass.visible = false
		_c_crack.visible = false
		_c_broken.visible = true
		_take_rig()
		_rig.pop_target = Gfx.to_view(Vector2(320, 176))
		_play("scream", float(_style_info()["pitch"]), -2.0)
	if elapsed >= 1.0 and elapsed < 1.6:
		_rig.pop = 1.25 * _ease_in(_k(1.0, 1.5))
	if _at(1.5):
		_strike(Vector2(320, 170))
		_gore.vignette = 1.0
		_play("crunch", 1.0, -2.0)
		_shake = 8.0
	_move(1.7, 2.6, 1.0, 1.15, C, C + Vector2(0, 30), 0.0, 1.35)
	if _at(2.0):
		_play("heartbeat", 1.0, 0.0)
	if _at(2.9):
		_play("heartbeat", 0.96, -6.0)
	if _at(4.0):
		_play("heartbeat", 0.92, -12.0)
	if elapsed >= 2.6:
		_black = _k(2.6, 3.0)
	if _at(2.6):
		_stop_loops()
	if _at(3.0):
		_caption = Lang.t("The doctor did not get up.")
	if _at(3.4):
		_stamp(str(_shot.get("title", "")), Gfx.STAMP_R)
	_counter_common(delta)


# ------------------------------------------------------------------ the hall camera
func _build_hall() -> void:
	_place = "HALL CAM"
	var at := Vector2(122, 10)
	var cam := Gfx.sprite(_flat, "clinic/hall_cam.png", at)
	cam.scale = Vector2(3, 3)
	var n := mini(int(_shot.get("unseen", 0)), 4)
	var xs := [152.0, 218.0, 284.0, 350.0]
	for i in n:
		var tex := Gfx.tex("theatre/queue_%d.png" % (i % 3))
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(3, 3)
		var feet := Vector2(float(xs[i]), 262.0 + 6.0 * float(i % 2))
		_flat.add_child(s)
		_queue.append({"s": s, "feet": feet, "start": 0.9 + 0.35 * float(n - 1 - i)})
	_h_dim = ColorRect.new()
	_h_dim.position = at
	_h_dim.size = Vector2(132, 94) * 3.0
	_h_dim.color = Color(Gfx.INK0, 0.0)
	_h_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flat.add_child(_h_dim)
	var crt := Gfx.sprite(_flat, "clinic/crt_overlay.png", at)
	crt.scale = Vector2(3, 3)
	_length = 4.4 if n > 0 else 3.0


func _hall_frame(_delta: float) -> void:
	var n := int(_shot.get("unseen", 0))
	if _at(0.3):
		if n >= 2:
			_caption = Lang.tf("%d more were waiting.", [n])
		elif n == 1:
			_caption = Lang.t("One more was waiting.")
		else:
			_caption = Lang.t("No one else was waiting.")
	if _at(0.5):
		_play("click", 0.7, -6.0)
	_h_dim.color = Color(Gfx.INK0, 0.5 * _k(0.5, 0.9))
	var door := Vector2(430, 175)
	for q in _queue:
		var item: Dictionary = q
		var s: Sprite2D = item["s"]
		var feet: Vector2 = item["feet"]
		var start := float(item["start"])
		var dist := feet.distance_to(door)
		var k := clampf((elapsed - start) * 140.0 / maxf(1.0, dist), 0.0, 1.0)
		var at := feet.lerp(door, k)
		var sc := lerpf(3.0, 1.6, k)
		var size := Vector2(20, 44) * sc
		s.scale = Vector2(sc, sc)
		var bob := roundf(absf(sin(elapsed * 9.0)) * 2.0) if k > 0.0 and k < 1.0 else 0.0
		s.position = (at - Vector2(size.x / 2.0, size.y + bob)).round()
		s.modulate = Color(1, 1, 1, 1.0 - _k(start + dist / 140.0 - 0.3, start + dist / 140.0))
		if _at(start + 0.05):
			_play("step", 0.8, -16.0)


# ------------------------------------------------------------------ the empty theatre
func _build_empty() -> void:
	_place = "THEATRE HEADCAM"
	_build_room(false, "")
	_strap_zone = Rect2(230, 183, 100, 18)
	_strap_state = "open"
	_ecg_on = true
	_ecg_flat = true
	_ecg_label = "NO PATIENT"
	_length = 5.0


func _empty_frame(_delta: float) -> void:
	if _at(0.2):
		_lamp_on = true
		_play("light_on", 1.0, -4.0)
	if _at(4.2):
		_lamp_on = false
		_play("click", 1.0, -6.0)
	_lamp_k = 1.0 if _lamp_on else 0.0
	_apply_lamp()
	_move(0.6, 3.6, 1.0, 1.12, C, C + Vector2(0, 14))
	if _at(0.8):
		_caption = Lang.t("No one was admitted tonight.")
	if _at(1.6):
		_stamp("EMPTY CHAIR", Gfx.STAMP_A)


# ------------------------------------------------------------------ the heart monitor
func _ecg_step(delta: float) -> void:
	if not _ecg_on:
		return
	_hr = move_toward(_hr, _hr_to, delta * 40.0)
	_sweep += delta * 50.0
	while _sweep >= 1.0:
		_sweep -= 1.0
		_col = (_col + 1) % _trace.size()
		var v := 0.0
		if not _ecg_flat:
			# four looks per column, keeping the one furthest from the line, so no spike is missed
			for i in 4:
				var before := fmod(_beat, 1.0)
				_beat += _hr / 60.0 / 50.0 / 4.0
				var f := fmod(_beat, 1.0)
				if before < 0.11 and f >= 0.11:
					_play("ecg", 1.4 if _ecg_alarm else 1.0, -18.0)
				var w := _wave(f)
				if absf(w) > absf(v):
					v = w
		_trace[_col] = v


static func _wave(f: float) -> float:
	if f < 0.05:
		return -1.0
	if f >= 0.09 and f < 0.11:
		return 2.0
	if f >= 0.11 and f < 0.14:
		return -11.0
	if f >= 0.14 and f < 0.17:
		return 4.0
	if f >= 0.32 and f < 0.42:
		return -2.0
	return 0.0


# ------------------------------------------------------------------ drawing
func _draw_straps() -> void:
	if _strap_zone.size == Vector2.ZERO:
		return
	var leather := Color("2a2018")
	var edge := Color("140e0c")
	var buckle := Color("d4a040")
	var z := _strap_zone
	for i in 2:
		var x := roundf(z.position.x + z.size.x * (0.2 if i == 0 else 0.8) - 4.0)
		var top := z.position.y - 2.0
		var h := z.size.y + 4.0
		match _strap_state:
			"shut":
				_straps.draw_rect(Rect2(x - 1, top, 10, h), edge)
				_straps.draw_rect(Rect2(x, top, 8, h), leather)
				_straps.draw_rect(Rect2(x, top + 1, 8, 1), Color("4a3828"))
				_straps.draw_rect(Rect2(x + 2, top + roundf(h * 0.45), 4, 4), buckle)
				_straps.draw_rect(Rect2(x + 3, top + roundf(h * 0.45) + 1, 2, 2), edge)
			"open":
				var dx := -9.0 if i == 0 else 9.0
				_straps.draw_rect(Rect2(x + dx - 1, top + 4, 10, h + 6), edge)
				_straps.draw_rect(Rect2(x + dx, top + 4, 8, h + 6), leather)
				_straps.draw_rect(Rect2(x + dx + 2, top + h + 4, 4, 4), buckle)
			_:
				_straps.draw_rect(Rect2(x - 1, top + h - 5, 10, 5), edge)
				_straps.draw_rect(Rect2(x, top + h - 4, 8, 4), leather)
				for j in 4:
					_straps.draw_rect(Rect2(x + 2 * j, top + h - 6 - float(j % 2), 1, 2), leather)


## Light in the close-up, dithered like the rest of the art.
func _draw_close_fx() -> void:
	match _site:
		"eye_l", "eye_r":
			if _drift and elapsed >= 5.0 and elapsed < _cal_end + 0.9:
				var eye := _site_eye()
				if not eye.is_empty():
					var at: Vector2 = (eye["pos"] as Vector2) + (eye["off"] as Vector2)
					var pulse := 0.5 + 0.5 * sin(elapsed * 14.0)
					Gfx.soft_disc(_close_fx, at, 10.0 + 4.0 * pulse, Gfx.RED2, 0.6 + 0.4 * pulse, 0.2)
		"port":
			for r in _rings:
				var age := elapsed - float(r)
				if age < 0.0 or age > 0.6:
					continue
				var col := Gfx.RED2 if _drift and float(r) >= 4.95 else Gfx.CYAN2
				_close_fx.draw_arc(PORT_PART, 6.0 + age * 60.0, 0.0, TAU, 32, Color(col, 1.0 - age / 0.6), 2.0)
			if _drift and elapsed >= 4.95 and elapsed < _cal_end + 0.9:
				var pulse := 0.5 + 0.5 * sin(elapsed * 12.0)
				Gfx.soft_disc(_close_fx, PORT_PART, 20.0 + 8.0 * pulse, Gfx.RED2, 0.5 + 0.3 * pulse, 0.2)
		"voice":
			if elapsed >= 4.75 and elapsed < _cal_end + 0.9:
				if _drift:
					var pulse := 0.5 + 0.5 * sin(elapsed * 16.0)
					Gfx.soft_disc(_close_fx, VOICE_LED, 9.0 + 4.0 * pulse, Gfx.RED2, 0.7 + 0.3 * pulse, 0.25)
				elif (elapsed >= 4.9 and elapsed < 5.0) or (elapsed >= 5.05 and elapsed < 5.2):
					Gfx.soft_disc(_close_fx, VOICE_LED, 12.0, Gfx.CYAN2, 0.9, 0.25)


func _draw_fx() -> void:
	if _black > 0.0:
		_fx.draw_rect(PICTURE, Color(0, 0, 0, _black))
	if _flash > 0.01:
		_fx.draw_rect(PICTURE, Color(_flash_col, clampf(_flash, 0.0, 1.0)))
	if _static > 0.01:
		_fx.draw_rect(PICTURE, Color(Gfx.INK0, 0.85 * _static))
		var n := int(520.0 * _static)
		for i in n:
			var g := _rng.randf_range(0.15, 0.75)
			var w := float(_rng.randi_range(4, 40))
			var at := Vector2(float(_rng.randi_range(0, 640)) - w / 2.0, float(_rng.randi_range(0, 297)))
			_fx.draw_rect(Rect2(at, Vector2(w, float(_rng.randi_range(1, 2)))), Color(g, g, g, 0.7 * _static))
	if _lost and fmod(elapsed, 0.5) < 0.34:
		Gfx.big_center(_fx, 320, 138, "SIGNAL LOST", Gfx.RED2)
	# scanlines: it is a camera feed
	for y in range(0, 298, 3):
		_fx.draw_rect(Rect2(0, y, 640, 1), Color(0, 0, 0, 0.07))


func _draw_hud() -> void:
	# the caption band
	_hud.draw_rect(BAND, Color(Gfx.INK0, 0.94))
	_hud.draw_rect(Rect2(BAND.position.x, BAND.position.y, BAND.size.x, 1), Gfx.TEAL3)
	var who := str(_shot.get("name", ""))
	if _name_on and who != "":
		Gfx.big(_hud, Vector2(16, 302), who, Gfx.TEAL7)
	if _caption != "":
		var y := 326.0
		var lines := Gfx.wrap_raw(_caption, 356)
		for i in mini(lines.size(), 2):
			Gfx.text_raw(_hud, Vector2(16, y), lines[i], Gfx.TEAL6)
			y += 12.0
	Gfx.outline(_hud, NEXT, Gfx.TEAL3)
	Gfx.outline(_hud, SKIP, Gfx.TEAL3)
	Gfx.text_right(_hud, NEXT.end.x - 6, 334, "Next shot [ENTER]", Gfx.TEAL5)
	Gfx.text_right(_hud, SKIP.end.x - 6, 334, "Skip film [ESC]", Gfx.TEAL5)
	# the feed's corner: where the camera is, and that it is recording
	if _place != "":
		var count := "%02d / %02d" % [index + 1, shots.size()]
		var place_w := Gfx.text_w(_place, true)
		var w := maxf(place_w, Gfx.text_w_raw("REC " + count) + 10.0)
		if bool(_shot.get("relief", false)) and _kind == "theatre":
			w = maxf(w, Gfx.text_w("RELIEF CREW"))
		var plate_h := 42.0 if bool(_shot.get("relief", false)) and _kind == "theatre" else 30.0
		_hud.draw_rect(Rect2(628 - w - 6, 4, w + 12, plate_h), Color(Gfx.INK0, 0.55))
		Gfx.text_right(_hud, 628, 8, _place, Gfx.TEAL7, true)
		var count_w := Gfx.text_w_raw(count)
		Gfx.text_raw(_hud, Vector2(628 - count_w, 20), count, Gfx.TEAL6)
		var rec_x := 628 - count_w - 6 - Gfx.text_w_raw("REC")
		Gfx.text_raw(_hud, Vector2(rec_x, 20), "REC", Gfx.RED2)
		if fmod(elapsed, 1.0) < 0.6:
			_hud.draw_rect(Rect2(rec_x - 9, 22, 6, 6), Gfx.RED2)
		if plate_h > 30.0:
			Gfx.text_right(_hud, 628, 32, "RELIEF CREW", Gfx.AMBER)
	if _ecg_on and not _lost:
		_draw_ecg()
	if _read_on and _cam_closed():
		_draw_readout()
	if _stamp_t >= 0.0 and _stamp_text != "":
		_draw_stamp()


func _cam_closed() -> bool:
	return _close.visible


func _draw_ecg() -> void:
	var r := ECG
	_hud.draw_rect(r, Color(Gfx.INK0, 0.8))
	Gfx.outline(_hud, r, Gfx.TEAL3)
	var bad := _ecg_alarm or _ecg_flat
	var col := Gfx.RED2 if bad else Gfx.GRN4
	var label := ""
	if _ecg_label != "":
		label = Lang.t(_ecg_label)
	elif _ecg_flat:
		label = Lang.t("HR") + " --"
	else:
		label = Lang.t("HR") + " " + str(int(roundf(_hr)))
	Gfx.text_raw(_hud, r.position + Vector2(5, 3), label, col)
	if bad and _ecg_label == "" and not _ecg_flat and fmod(elapsed, 0.4) < 0.2:
		_hud.draw_rect(Rect2(r.end.x - 11, r.position.y + 5, 6, 6), Gfx.RED2)
	var base := r.position.y + 34.0
	var n := _trace.size()
	for i in n - 1:
		# a gap runs ahead of the sweep
		var ahead := (i - _col + n) % n
		if ahead >= 1 and ahead <= 4:
			continue
		var a := Vector2(r.position.x + 4.0 + float(i), base + _trace[i])
		var b := Vector2(r.position.x + 5.0 + float(i), base + _trace[i + 1])
		if (i + 1 - _col + n) % n >= 1 and (i + 1 - _col + n) % n <= 4:
			continue
		_hud.draw_line(a, b, col, 1.0)


func _draw_readout() -> void:
	var r := READOUT
	_hud.draw_rect(r, Color(Gfx.INK0, 0.82))
	Gfx.outline(_hud, r, Gfx.TEAL3)
	Gfx.text(_hud, r.position + Vector2(6, 4), _read_name, Gfx.TEAL7, true)
	if _read_value != "":
		var w := Gfx.text_w_raw(_read_value)
		Gfx.text_raw(_hud, Vector2(r.end.x - 6 - w, r.position.y + 4), _read_value, Gfx.RED2 if _read_bad else Gfx.TEAL6)
	var y2 := r.position.y + 16.0
	if _verdict != "":
		Gfx.text(_hud, Vector2(r.position.x + 6, y2), _verdict, Gfx.GRN4 if _verdict_ok else Gfx.RED2, true)
	elif _bar >= 0.0:
		var bar := Rect2(r.position.x + 6, y2 + 2, r.size.x - 12, 6)
		_hud.draw_rect(bar, Gfx.TEAL2)
		_hud.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * _bar), bar.size.y)), Gfx.RED2 if _bar_bad else Gfx.CYAN2)
	else:
		var dots := int(elapsed * 6.0) % 4
		for i in 3:
			_hud.draw_rect(Rect2(r.position.x + 6 + 6 * i, y2 + 4, 3, 3), Gfx.TEAL7 if i < dots else Gfx.TEAL3)


func _draw_stamp() -> void:
	var font := Gfx.big_font()
	var title := Lang.t(_stamp_text)
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, Gfx.FS_BIG).x
	var size := Vector2(w + 24.0, 34.0)
	var k := clampf(_stamp_t / 0.12, 0.0, 1.0)
	var s := lerpf(1.6, 1.0, k * k)
	var centre := _stamp_at
	centre.x = clampf(centre.x, 8.0 + size.x / 2.0, 632.0 - size.x / 2.0)
	_hud.draw_set_transform(centre, -0.06, Vector2(s, s))
	var box := Rect2(-size / 2.0, size)
	_hud.draw_rect(box, Color(Gfx.INK0, 0.86))
	_hud.draw_rect(box, _stamp_col, false, 2.0)
	_hud.draw_rect(box.grow(-4.0), Color(_stamp_col, 0.6), false, 1.0)
	var at := Vector2(-w / 2.0, -10.0)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_hud.draw_string(font, at + (o as Vector2) + Vector2(0, font.get_ascent(Gfx.FS_BIG)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, Gfx.FS_BIG, Gfx.INK0)
	_hud.draw_string(font, at + Vector2(0, font.get_ascent(Gfx.FS_BIG)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, Gfx.FS_BIG, _stamp_col.lightened(0.25))
	_hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
