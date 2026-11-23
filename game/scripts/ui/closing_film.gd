extends Node2D
## The closing film: one short scene in the back room, played when the last appointment is over.
##
## The room is dim and everyone in it is a silhouette against the theatre lamp. The film picks
## one patient the doctor admitted tonight. If any of them was drifting, it is one of those: the
## surgeon swaps the part in close-up, the calibration goes wrong and the lamp bursts. In the red
## of the emergency light the patient kills the crew, one blow each time the dead tube catches,
## then comes for the lens a step at a time. Their face is the last thing on screen, for a few
## frames, so the player knows whom they let in. If everyone admitted was steady, the new part
## holds and the patient opens their eyes under the lamp. A doctor killed at the glass ends on the
## crew waiting in the back for someone who never comes, and a night with nobody admitted ends on
## the empty chair.
##
## The film keeps its own clock (step()) and draws every frame from that clock alone, so a
## capture at any frame rate shows the same frames and ENTER can jump between chapters. The
## caption and the end card carry the story with the sound off; every word goes through the
## catalogs.

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const CaseDB = preload("res://scripts/core/case_db.gd")

signal finished
signal sound(cue: String, pitch: float, db: float)
signal loop_sound(cue: String, on: bool, db: float)

const SKIP := Rect2(530, 12, 98, 22)
const NEXT := Rect2(404, 12, 120, 22)
const C := Vector2(320, 180)                   # the middle of the screen
const PICTURE := Rect2(0, 46, 640, 268)        # the picture, between the letterbox bars

# the back room, in its own world (the camera frames a part of it)
const ROOM_AT := Vector2(-40, 16)              # room.png
const CHAIR_AT := Vector2(190, 104)
const PATIENT_AT := Vector2(240, 94)           # the patient's canvas (160 x 176) in the chair
const DRAPE_AT := Vector2(-30, 228)
const NECK := Vector2(80, 110)                 # where the head turns, in the patient's canvas
const LEGS_AT := 150.0                         # the canvas row legs.png hangs from when they stand
const LAMP := Vector2(320, 84)                 # the lamp's dish
const MONITOR := Rect2(550, 140, 68, 44)       # the heart monitor's screen
const WINDOW := Rect2(54, 120, 42, 46)         # the wired window in the door
const HIP := Vector2(78, 196)                  # where a crew pose stands in crew_*.png
const HIPS := {"crew_recoil": Vector2(84, 198), "crew_fall": Vector2(130, 212)}
const SURGEON := Vector2(186, 272)             # the crew's hips in the room
const ASSISTANT := Vector2(470, 272)
const TOOL_TIP := Vector2(258, 180)            # the surgeon's working hand, in the room
const INS := Vector2(1200, 0)                  # the close-up of the part, a set of its own
const INS_SIZE := Vector2(440, 372)            # ... its picture (220 x 186 at twice the size)
const FACE_SET := Vector2(2400, 0)             # the face, lit for its last frames
const EXIT_LAMP := Vector2(420, 50)            # the red emergency light, high on the back wall
const STAND_AT := Vector2(240, 48)             # the patient's canvas, standing by the chair
const BODIES := [Vector2(14, 242), Vector2(626, 244)]   # the crew where they fell (the assistant mirrored)
const POOLS := [Vector2(128, 311), Vector2(506, 313)]   # ... the blood spreading under them
const BODY_SCALE := 0.55                       # body_floor.png at the crew's size

# the clock of each film, in seconds
const LENGTH := {"massacre": 44.0, "repair": 26.0, "waiting": 18.0, "empty": 12.0}
const CHAPTERS := {"massacre": [8.0, 17.5, 25.5, 32.5, 38.0, 39.0], "repair": [8.0, 16.0, 22.0], "waiting": [6.0, 14.0], "empty": [8.5]}
const CARD_AT := {"massacre": 39.0, "repair": 22.0, "waiting": 14.0, "empty": 8.5}
const BEATS := [26.2, 27.4, 28.9, 30.4]       # the dead tube catches: one blow each
const BOOMS := [35.0, 35.9, 36.8]             # it comes for the lens, a step each
## Where it is after each step: its size, and where its eyes are in the room.
const STEPS := [[1.6, Vector2(318, 140)], [2.4, Vector2(322, 152)], [3.6, Vector2(320, 166)]]
const GATES := [[0.0, 0.05], [0.17, 0.21], [0.48, 0.66], [0.86, 0.9], [1.05, 1.2]]   # the lamp catching, from 1.6
const BROWNOUT := [[0.0, 0.12, 0.25], [0.3, 0.36, 0.45], [1.1, 1.3, 0.6], [1.9, 1.95, 0.3]]   # from 15.2: from, to, level

# light
const AMB := Vector3(0.045, 0.05, 0.065)
const WARM := Color(1.0, 0.82, 0.6)
const COLD := Color(0.62, 0.72, 0.95)
const ALARM_RED := Color(1.0, 0.16, 0.12)
const EYE_RED := Color(1.0, 0.1, 0.12)
const STROBE := Color(0.8, 0.86, 1.0)          # the dead tube arcing
const MON_TEAL := Color(0.3, 0.85, 0.78)
const GREEN := Color(0.4, 1.0, 0.45)
const SPARK := Color(1.0, 0.85, 0.6)
const FILL := Color(0.02, 0.025, 0.03)

# the close-up (220 x 186, shown at twice the size), as the counter's scopes have it
const EYE_R := Vector2(60, 86)
const EYE_L := Vector2(160, 86)
const GLOVE_TIP := Vector2(5, 5)               # the tool's tip in glove_*.png
const LIT_DIST := 38.0
const REACH := {"natural": Vector2(12, 4), "optic": Vector2(8, 5), "combat": Vector2(10, 3), "display": Vector2(11, 4)}
const PUPIL_WIDE := 9.0
const PUPIL_TIGHT := 4.0
const HAND_PART := Vector2(110, 52)            # the cartridge under the wrist hatch
const PORT_PART := Vector2(96, 86)
const VOICE_PART := Vector2(64, 88)
const VOICE_LED := Vector2(64, 127)

## The part each patient came in to have replaced, and so the close-up the film cuts to.
const SITES := {
	"rook": "hand", "maren": "hand", "bo": "hand", "ozzie": "hand", "vale": "hand",
	"kip": "eye_l", "priya": "eye_l", "dana": "eye_r", "lux": "port", "juno": "voice",
}

## How each attack style sounds: the scream's pitch, the sound it bites with, the loop while the
## weapon is up, and the colour of its light.
const STYLE := {
	"saw": {"pitch": 0.6, "bite": "saw_grind", "loop": "saw_loop", "glow": ""},
	"torch": {"pitch": 1.12, "bite": "torch_burst", "loop": "torch_loop", "glow": "5ee6e0"},
	"lock": {"pitch": 1.28, "bite": "clang", "loop": "", "glow": ""},
	"fist": {"pitch": 0.76, "bite": "punch", "loop": "servo_loop", "glow": ""},
	"picks": {"pitch": 1.24, "bite": "scrape", "loop": "hum_loop", "glow": ""},
	"laser": {"pitch": 1.16, "bite": "laser_burst", "loop": "laser_loop", "glow": "ff4a4a"},
	"cleaver": {"pitch": 0.68, "bite": "chop", "loop": "", "glow": ""},
	"arc": {"pitch": 1.34, "bite": "zap", "loop": "arc_loop", "glow": "8a7cff"},
	"baton": {"pitch": 1.0, "bite": "baton_hit", "loop": "stun_loop", "glow": ""},
	"spike": {"pitch": 0.72, "bite": "spike", "loop": "piston_loop", "glow": ""},
}

## Everything in the room is lit by this: up to eight round lights (in screen pixels), a little
## ambient, and the result stepped to a few levels with an ordered dither, so the dark keeps its
## grain. flat_tex draws the texture's shape in white (the rim light round a silhouette).
const LIT_CODE := """
shader_type canvas_item;

uniform vec4 lp[8];
uniform vec4 lc[8];
uniform int n = 0;
uniform vec3 amb = vec3(0.0);
uniform float levels = 6.0;
uniform bool flat_tex = false;
uniform float gain = 1.0;
uniform float alpha = 1.0;

varying vec2 wp;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (flat_tex) {
		t = vec4(1.0, 1.0, 1.0, step(0.5, t.a));
	}
	vec3 l = amb;
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		vec2 d = wp - lp[i].xy;
		d.y /= max(lc[i].a, 0.1);
		float k = clamp(1.0 - length(d) / max(lp[i].z, 1.0), 0.0, 1.0);
		l += lc[i].rgb * (lp[i].w * k * k);
	}
	l *= gain;
	int cx = int(FRAGCOORD.x) % 4;
	int cy = int(FRAGCOORD.y) % 4;
	float b = (BAYER[cy * 4 + cx] + 0.5) / 16.0 - 0.5;
	float L = max(l.r, max(l.g, l.b));
	float q = min(floor(L * levels + b + 0.5) / levels, 1.6);
	l *= q / max(L, 0.0001);
	COLOR = vec4(t.rgb * l, t.a * alpha);
}
"""

## A silhouette's fill, or a shadow (dith: its alpha as dither density).
const FLAT_CODE := """
shader_type canvas_item;

uniform vec4 tint = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool dith = false;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	float a = tint.a;
	if (dith) {
		int cx = int(FRAGCOORD.x) % 4;
		int cy = int(FRAGCOORD.y) % 4;
		a = step((BAYER[cy * 4 + cx] + 0.5) / 16.0, tint.a);
	}
	COLOR = vec4(tint.rgb, a * step(0.5, texture(TEXTURE, UV).a));
}
"""

## The picture tearing: the red slips sideways off the rest and rows of the picture jump
## sideways. Only the red moves, so a slip leaves red and cyan edges and no other colours.
const POST_CODE := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float split = 0.0;
uniform float slices = 0.0;
uniform float seed = 0.0;

void fragment() {
	float row = floor(FRAGCOORD.y / 6.0);
	float r = fract(sin(row * 12.9898 + seed * 78.233) * 43758.5453);
	float off = r > 1.0 - slices * 0.35 ? (r - 0.5) * 40.0 * slices : 0.0;
	vec2 uv = SCREEN_UV + vec2(off * SCREEN_PIXEL_SIZE.x, 0.0);
	vec2 s = vec2(split * SCREEN_PIXEL_SIZE.x, 0.0);
	COLOR = vec4(texture(screen, uv + s).r, texture(screen, uv).gb, 1.0);
}
"""


## A figure as the film draws it: each part twice, once as a lit rim pushed a pixel towards the
## light and once as a flat black fill over it, so only the edge facing the light shows.
class Shade extends Node2D:
	var rims := Node2D.new()
	var fills := Node2D.new()
	var parts: Dictionary = {}
	var tilt: float = 0.0

	func _init(rim_mat: Material, fill_mat: Material) -> void:
		rims.material = rim_mat
		rims.visible = rim_mat != null
		fills.material = fill_mat
		add_child(rims)
		add_child(fills)

	## Sets one part (made on first use, so the first call fixes the drawing order). rot turns
	## it about pivot, both in the figure's own space.
	func part(key: String, tex: Texture2D, pos: Vector2 = Vector2.ZERO, rot: float = 0.0, pivot: Vector2 = Vector2.ZERO) -> void:
		if not parts.has(key):
			var pair: Array = []
			for layer in [rims, fills]:
				var s := Sprite2D.new()
				s.centered = false
				s.use_parent_material = true
				(layer as Node2D).add_child(s)
				pair.append(s)
			parts[key] = pair
		var at := pivot + (pos - pivot).rotated(rot)
		for s in parts[key]:
			var sp: Sprite2D = s
			sp.texture = tex
			sp.visible = tex != null
			sp.position = at
			sp.rotation = rot

	## Where the rim sits, as an offset in the room (it does not grow with the figure).
	func rim(world_off: Vector2) -> void:
		rims.position = Vector2(world_off.x / scale.x, world_off.y / scale.y)


var less_blood: bool = false
var shots: Array = []
var index: int = 0
var elapsed: float = 0.0

var _cases: Dictionary = {}
var _meta: Dictionary = {}
var _parts_db: Dictionary = {}
var _pt: float = -1.0
var _length: float = 12.0
var _chapters: Array = []
var _card_t: float = 12.0
var _kind: String = ""
var _shot: Dictionary = {}
var _loops: Dictionary = {}                # film loops playing: cue -> the level they play at
var _want: Dictionary = {}                 # ... the loops this frame asks for
var _ambs: Dictionary = {}                 # the game's ambience, as the film last set it
var _rain_db: float = -34.0
var _drone_db: float = -20.0

# layers, back to front: _cam holds the world the camera frames
var _bg := ColorRect.new()
var _cam := Node2D.new()
var _lit := Node2D.new()                   # lit sprites: the room, the chair, the close-up, the face
var _props := Node2D.new()                 # the lamp's arm and the blood, coloured by the lights
var _glow := Node2D.new()                  # light in the air: glare, the cone, the monitor, sparks
var _sil := Node2D.new()                   # the silhouettes
var _front := Node2D.new()                 # the drape, nearest the camera
var _vig := Node2D.new()
var _fxpost := ColorRect.new()             # the picture tearing
var _glow2 := Node2D.new()                 # the eyes: framed like _cam, but over the tearing
var _post := Node2D.new()                  # black, flash, grain, bars, caption, card
var _post_glow := Node2D.new()             # the eyes' afterimage on the card

# materials
var _lit_shader := Shader.new()
var _flat_shader := Shader.new()
var _mats: Array = []                      # [lit material, plane]
var _m_room: ShaderMaterial = null
var _m_mid: ShaderMaterial = null
var _m_pat: ShaderMaterial = null
var _m_front: ShaderMaterial = null
var _m_rim: ShaderMaterial = null
var _m_face: ShaderMaterial = null
var _m_ins: ShaderMaterial = null
var _m_threads: ShaderMaterial = null
var _m_fill: ShaderMaterial = null
var _m_post: ShaderMaterial = null

# the camera, set again every frame
var _set: String = "room"
var _z: float = 1.0
var _f := C
var _th: float = 0.0
var _par := Vector2.ZERO                   # how far the camera has moved, for the parallax
var _ro := Vector2.ZERO                    # ... the back wall's offset
var _fo := Vector2.ZERO                    # ... the drape's offset
var _shake: float = 0.0
var _split: float = 0.0
var _slices: float = 0.0
var _post_seed: float = 0.0
var _flash: float = 0.0
var _flash_col := Color.WHITE
var _black: float = 0.0
var _cam_on: bool = true
var _card_on: bool = false

# light, set again every frame
var _lights: Array = []                    # [position in the world, radius, strength, colour, squash]
var _amb_col := AMB
var _lamp: float = 0.0
var _lamp_at := LAMP

# the scene
var _room: Sprite2D = null
var _chair: Sprite2D = null
var _drape: Sprite2D = null
var _pat: Shade = null
var _surgeon: Shade = null
var _assistant: Shade = null
var _bodies: Array = []                    # the crew on the floor, after a massacre: surgeon, assistant
var _straps: Node2D = null
var _passer: Node2D = null
var _pc: Node2D = null                     # the patient in colour, waking after a repair
var _pcs: Dictionary = {}
var _fs: Node2D = null                     # the face, for the last frames
var _fss: Dictionary = {}
var _bursts: Array = []                    # sparks: [start, where, how many, direction, speed]
var _trail: Array = []                     # where the eyes were: [time, [left, right]]
var _grain := RandomNumberGenerator.new()

# the patient
var _case_d: Dictionary = {}
var _rig_meta: Dictionary = {}
var _pid: String = ""
var _site: String = "hand"
var _style: String = "fist"
var _drift: bool = false
var _ins_end: float = 16.0
var _eye_l := Vector2(68, 75)              # the eyes in the patient's canvas
var _eye_r := Vector2(92, 75)
var _blinks: bool = true

# the heart monitor
var _ecg_on: bool = false
var _ecg_alarm: bool = false
var _ecg_flat: bool = false
var _hr: float = 66.0
var _hr_to: float = 66.0
var _beat: float = 0.0
var _trace := PackedFloat32Array()
var _col: int = 0
var _sweep: float = 0.0

# the close-up of the part
var _close: Node2D = null
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
var _swap_phase: int = -1


func _ready() -> void:
	_lit_shader.code = LIT_CODE
	_flat_shader.code = FLAT_CODE
	_m_room = _lit_mat(1)
	_m_mid = _lit_mat(0)
	_m_pat = _lit_mat(0)
	_m_front = _lit_mat(2)
	_m_rim = _lit_mat(0, true, 3.0)
	_m_face = _lit_mat(0)
	_m_ins = _lit_mat(0)
	_m_threads = _lit_mat(0)
	_m_fill = _flat_mat(FILL, false)
	var post := Shader.new()
	post.code = POST_CODE
	_m_post = ShaderMaterial.new()
	_m_post.shader = post
	_bg.size = Gfx.SCREEN
	_bg.color = Color.BLACK
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	add_child(_cam)
	for layer in [_lit, _props, _glow, _sil, _front]:
		_cam.add_child(layer as Node2D)
	_glow.material = Gfx.dither(true)
	_glow2.material = Gfx.dither(true)
	_vig.material = Gfx.dither(false)
	add_child(_vig)
	_fxpost.size = Gfx.SCREEN
	_fxpost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fxpost.material = _m_post
	_fxpost.visible = false
	add_child(_fxpost)
	# the eyes go over the tearing, so its colours never slip off them
	add_child(_glow2)
	add_child(_post)
	_post_glow.material = Gfx.dither(true)
	add_child(_post_glow)
	_props.draw.connect(_draw_props)
	_glow.draw.connect(_draw_glow)
	_glow2.draw.connect(_draw_glow2)
	_vig.draw.connect(_draw_vig)
	_post.draw.connect(_draw_post)
	_post_glow.draw.connect(_draw_post_glow)
	_trace.resize(64)


func _lit_mat(plane: int, flat: bool = false, gain: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _lit_shader
	m.set_shader_parameter("flat_tex", flat)
	m.set_shader_parameter("gain", gain)
	_mats.append([m, plane])
	return m


func _flat_mat(tint: Color, dith: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _flat_shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("dith", dith)
	return m


# ------------------------------------------------------------------ which film
## The night's one film, from its settlements. A drifting patient who was admitted takes the
## chair (one of them, the same one every time for the same night). Otherwise a doctor killed at
## the glass leaves the crew waiting in the back. Otherwise a steady admission shows the repair,
## and a night nobody was admitted on ends on the empty chair.
static func plan(records: Array, unseen: int = 0) -> Array:
	var bad: Array = []
	var good: Array = []
	var killer: Dictionary = {}
	var ids := PackedStringArray()
	for r in records:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = r
		var outcome := str(rec.get("outcome", ""))
		ids.append(str(rec.get("case_id", "")))
		if outcome == "treated_drifting":
			bad.append(rec)
		elif outcome == "treated_ok":
			good.append(rec)
		elif outcome == "hit" and killer.is_empty():
			killer = rec
	var pick := absi(hash(",".join(ids)))
	var shot: Dictionary
	if not bad.is_empty():
		shot = _shot_for("massacre", bad[pick % bad.size()])
	elif not killer.is_empty():
		shot = _shot_for("waiting", killer)
		shot["unseen"] = maxi(0, unseen)
	elif not good.is_empty():
		shot = _shot_for("repair", good[pick % good.size()])
	else:
		shot = _shot_for("empty", {})
	shot["died"] = not killer.is_empty()
	shot["admitted"] = good.size() + bad.size()
	return [shot]


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
		"died": false,
		"admitted": 0,
		"unseen": 0,
	}


## records: the night's settlements (ShiftState.records). p_cases: tonight's composed cases by id;
## a patient missing from it is composed from the template. unseen: how many were still waiting.
func start(records: Array, clean: bool, p_cases: Dictionary = {}, p_meta: Dictionary = {}, unseen: int = 0) -> void:
	less_blood = clean
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


## ENTER: the next chapter of the film, or the report after the last one.
func advance() -> void:
	if not visible or shots.is_empty():
		return
	for c in _chapters:
		if float(c) > elapsed + 0.05:
			_seek(float(c))
			return
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
		finish()


func _process(delta: float) -> void:
	step(delta)


func _seek(t: float) -> void:
	_pt = t - 0.001
	elapsed = t
	_trail.clear()
	_frame(0.0)
	_hr = _hr_to


func _begin() -> void:
	_clear_shot()
	_shot = shots[index]
	_kind = str(_shot.get("kind", "empty"))
	_length = float(LENGTH.get(_kind, 12.0))
	_chapters = CHAPTERS.get(_kind, [])
	_card_t = float(CARD_AT.get(_kind, _length))
	_pt = -1.0
	elapsed = 0.0
	_build()
	_frame(0.0)


func _build() -> void:
	var id := str(_shot.get("id", ""))
	_case_d = _case(id, str(_shot.get("truth", "")))
	_pid = str(_case_d.get("sprite", id))
	_rig_meta = _meta.get(_pid, {}) if typeof(_meta.get(_pid)) == TYPE_DICTIONARY else {}
	var attack: Dictionary = _rig_meta.get("attack", {}) if typeof(_rig_meta.get("attack")) == TYPE_DICTIONARY else {}
	_style = str(attack.get("style", "fist"))
	if not STYLE.has(_style):
		_style = "fist"
	_site = str(SITES.get(_pid, "hand"))
	_blinks = _rig_meta.get("blink") != null
	_eye_spots()
	_drift = _kind == "massacre"
	_ins_end = 17.5 if _drift else 16.0
	_build_room()
	if _kind == "massacre" or _kind == "repair":
		_build_patient()
		_build_close()
		_theatre_bursts()
	if _drift:
		_build_bodies()
		_build_face()


func _clear_shot() -> void:
	for layer in [_lit, _sil, _front]:
		for child in (layer as Node2D).get_children():
			(child as Node).free()
	_stop_loops()
	_ambs.clear()
	_eyes.clear()
	_trail.clear()
	_bursts.clear()
	_pcs = {}
	_fss = {}
	_room = null
	_chair = null
	_drape = null
	_pat = null
	_surgeon = null
	_assistant = null
	_bodies.clear()
	_straps = null
	_passer = null
	_pc = null
	_fs = null
	_close = null
	_close_fx = null
	_hand = null
	_old = null
	_new = null
	_hole = null
	_threads = null
	_eyes_front = null
	_empty_eye = null
	_beam = null
	_driver = null
	_forceps = null
	_held_d = null
	_held_f = null
	_swap_phase = -1
	_ecg_on = false
	_ecg_alarm = false
	_ecg_flat = false
	_hr = 66.0
	_hr_to = 66.0
	_trace.fill(0.0)
	_fxpost.visible = false


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


## A steady random number in [0, 1) for a cell of time (x) and a use (y).
static func _hash(x: float, y: float = 0.0) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


## 1 at t0, falling away to 0 over dur: what is left of a blow.
func _kick(t0: float, dur: float) -> float:
	if elapsed < t0 or elapsed >= t0 + dur:
		return 0.0
	var k := 1.0 - (elapsed - t0) / dur
	return k * k


## 1 between a and b, coming in and going out over 0.35 s.
func _fade(a: float, b: float) -> float:
	return minf(_k(a, a + 0.35), 1.0 - _k(b - 0.35, b))


func _play(cue: String, pitch: float = 1.0, db: float = -6.0) -> void:
	if cue != "":
		sound.emit(cue, pitch, db)


## A film loop that should be playing this frame, at this level. _sync_loops starts, sets and
## stops them once the frame is worked out.
func _loop(cue: String, db: float) -> void:
	if cue != "":
		_want[cue] = db


func _sync_loops() -> void:
	for cue in _want.keys():
		var db := float(_want[cue])
		if not _loops.has(cue) or absf(float(_loops[cue]) - db) > 0.5:
			_loops[cue] = db
			loop_sound.emit(str(cue), true, db)
	for cue in _loops.keys():
		if not _want.has(cue):
			_loops.erase(cue)
			loop_sound.emit(str(cue), false, 0.0)
	_want.clear()


func _stop_loops() -> void:
	for cue in _loops.keys():
		loop_sound.emit(str(cue), false, 0.0)
	_loops.clear()
	_want.clear()


## The game's rain and drone, turned down or up for the film (main puts them back after it).
func _sync_amb() -> void:
	for pair in [["amb_rain", _rain_db], ["amb_drone", _drone_db]]:
		var cue: String = pair[0]
		var db: float = pair[1]
		if not _ambs.has(cue) or absf(float(_ambs[cue]) - db) > 0.5:
			_ambs[cue] = db
			loop_sound.emit(cue, true, db)


## The case as it was tonight: from tonight's composed cases, else composed from its template.
func _case(id: String, truth: String) -> Dictionary:
	if id == "":
		return {}
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


func _dry(path: String) -> String:
	if not less_blood:
		return path
	var clean := path.trim_suffix(".png") + "_clean.png"
	return clean if Gfx.has_tex(clean) else path


func _ptex(path: String) -> Texture2D:
	return Gfx.tex(path) if path != "" and Gfx.has_tex(path) else null


## A sprite that takes its parent's material.
func _layer(parent: Node, path: String, pos: Vector2 = Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.use_parent_material = true
	s.position = pos
	s.texture = _ptex(path)
	parent.add_child(s)
	return s


func _lit_sprite(parent: Node, path: String, pos: Vector2, mat: Material) -> Sprite2D:
	var s := _layer(parent, path, pos)
	s.use_parent_material = false
	s.material = mat
	return s


## Where the patient's eyes are in their own canvas (from the meta zones): left, right.
func _eye_spots() -> void:
	var zones: Dictionary = _rig_meta.get("zones", {}) if typeof(_rig_meta.get("zones")) == TYPE_DICTIONARY else {}
	var z: Variant = zones.get("eyes")
	var a: Array = [56, 66, 48, 18]
	if typeof(z) == TYPE_ARRAY and (z as Array).size() >= 4:
		a = z
	var zx := float(a[0])
	var zy := float(a[1])
	var zw := float(a[2])
	var zh := float(a[3])
	_eye_l = Vector2(zx + zw * 0.25, zy + zh / 2.0)
	_eye_r = Vector2(zx + zw * 0.75, zy + zh / 2.0)


## The eyes' height in the room, with the patient seated.
func _eye_mid_y() -> float:
	return PATIENT_AT.y + 2.0 + (_eye_l.y + _eye_r.y) / 2.0


## The eyes of a figure (or a colour stack) in the room, with its head turned by tilt.
func _eye_pts(node: Node2D, tilt: float) -> Array:
	var out: Array = []
	for e in [_eye_l, _eye_r]:
		out.append(node.transform * (NECK + ((e as Vector2) - NECK).rotated(tilt)))
	return out


func _eye_mid(node: Node2D, tilt: float) -> Vector2:
	var pts := _eye_pts(node, tilt)
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


# ------------------------------------------------------------------ figures
## An attack layer of the patient's, with its second frame every other 0.12 s.
func _front_tex(stage: String) -> String:
	var base := "patients/%s/%s" % [_pid, stage]
	var path := base + ".png"
	if int(elapsed / 0.12) % 2 == 1 and Gfx.has_tex(base + "_b.png"):
		path = base + "_b.png"
	return _dry(path)


## A patient's silhouette, back to front: the legs (when they stand), the body, the head turned
## by tilt about the neck, the face they turn with, and an attack layer.
func _patient_parts(sh: Shade, tilt: float, front: String, legs: bool, turned: bool) -> void:
	var base := "patients/%s/" % _pid
	sh.tilt = tilt
	sh.part("legs", _ptex("film/legs.png") if legs else null, Vector2(0, LEGS_AT))
	sh.part("body", _ptex(base + "body.png"))
	sh.part("head", _ptex(base + "head.png"), Vector2.ZERO, tilt, NECK)
	sh.part("turn", _ptex(_dry(base + "turn.png")) if turned else null, Vector2.ZERO, tilt, NECK)
	sh.part("front", _ptex(_front_tex(front)) if front != "" else null)


## The patient in colour, layer by layer in the counter's order. turned: the face they turn
## with (angry brows, the turned mouth and its overlay).
func _stack(parent: Node2D, turned: bool) -> Dictionary:
	var base := "patients/%s/" % _pid
	var face: Dictionary = _rig_meta.get("face", {}) if typeof(_rig_meta.get("face")) == TYPE_DICTIONARY else {}
	var brows := "brows_angry.png" if turned else "brows_%s.png" % str(face.get("brows", "neutral"))
	var mouth := "mouth_turn.png" if turned else "mouth_%s.png" % str(face.get("mouth", "closed"))
	var st := {}
	st["body"] = _layer(parent, base + "body.png")
	var group := Node2D.new()
	group.use_parent_material = true
	parent.add_child(group)
	st["group"] = group
	st["pupils"] = _layer(group, base + "pupils.png")
	st["head"] = _layer(group, base + "head.png")
	st["brows"] = _layer(group, base + brows)
	st["turn"] = _layer(group, _dry(base + "turn.png") if turned else "")
	st["mouth"] = _layer(group, _dry(base + mouth))
	var lids := _layer(group, base + "lids.png")
	lids.visible = false
	st["lids"] = lids
	return st


## A crew member in a pose, standing with the pose's hip at hip (the assistant is mirrored).
func _crew(sh: Shade, pose: String, hip: Vector2) -> void:
	if pose == "":
		sh.visible = false
		return
	sh.visible = true
	var hl: Vector2 = HIPS.get(pose, HIP)
	sh.part("body", _ptex("film/%s.png" % pose))
	if sh.scale.x < 0.0:
		sh.position = Vector2(hip.x + hl.x, hip.y - hl.y)
	else:
		sh.position = hip - hl


# ------------------------------------------------------------------ building a film
func _build_room() -> void:
	_room = _lit_sprite(_lit, "film/room.png", ROOM_AT, _m_room)
	_chair = _lit_sprite(_lit, "film/chair.png", CHAIR_AT, _m_mid)
	_pat = Shade.new(_m_rim, _m_fill)
	_pat.visible = false
	_sil.add_child(_pat)
	_straps = Node2D.new()
	_sil.add_child(_straps)
	_straps.draw.connect(_draw_straps)
	_passer = Node2D.new()
	_sil.add_child(_passer)
	_passer.draw.connect(_draw_passer)
	_assistant = Shade.new(_m_rim, _m_fill)
	_assistant.scale = Vector2(-1, 1)
	_sil.add_child(_assistant)
	_surgeon = Shade.new(_m_rim, _m_fill)
	_sil.add_child(_surgeon)
	if _kind == "massacre" or _kind == "repair":
		_drape = _lit_sprite(_front, "film/drape.png", DRAPE_AT, _m_front)


func _build_patient() -> void:
	_pc = Node2D.new()
	_pc.material = _m_pat
	_pc.visible = false
	_lit.add_child(_pc)
	_pcs = _stack(_pc, false)
	(_pcs["lids"] as Sprite2D).visible = true
	_patient_parts(_pat, 0.0, "", false, false)


func _build_face() -> void:
	_fs = Node2D.new()
	_fs.material = _m_face
	_fs.position = FACE_SET
	_lit.add_child(_fs)
	_fss = _stack(_fs, true)


## The crew where they fall, for the end of a massacre: the surgeon on the floor to the left, the
## assistant (mirrored) to the right, both behind the patient.
func _build_bodies() -> void:
	for i in BODIES.size():
		var b := Shade.new(_m_rim, _m_fill)
		b.part("body", _ptex("film/body_floor.png"))
		b.scale = Vector2(-BODY_SCALE if i == 1 else BODY_SCALE, BODY_SCALE)
		b.position = BODIES[i]
		b.visible = false
		_sil.add_child(b)
		_sil.move_child(b, 0)
		_bodies.append(b)


## The close-up of the part, as the doctor examined it at the counter, lit by the work light.
func _build_close() -> void:
	_close = Node2D.new()
	_close.position = INS
	_close.scale = Vector2(2, 2)
	_close.material = _m_ins
	_lit.add_child(_close)
	match _site:
		"hand":
			_cs("film/board.png")
			_hand = _cs("scope/%s/grip_open.png" % _pid)
			_cs("film/hatch.png", Vector2(91, 41))
			_old = _cs("film/cart_old.png", Vector2(95, 46))
			_new = _cs("film/cart_new.png", Vector2(95, 46))
			_target = HAND_PART
		"eye_l", "eye_r":
			_build_eyes()
		"port":
			_cs("scope/%s/port.png" % _pid)
			_hole = _cs("film/jack_hole.png", Vector2(68, 58))
			_old = _cs("film/jack_old.png", Vector2(68, 58))
			_new = _cs("film/jack_new.png", Vector2(68, 58))
			_add_threads()
			_target = PORT_PART
		_:
			_cs("scope/%s/port.png" % _pid)
			_hole = _cs("film/box_hole.png", Vector2(43, 43))
			_old = _cs("film/box_old.png", Vector2(43, 43))
			_new = _cs("film/box_new.png", Vector2(43, 43))
			_add_threads()
			_target = VOICE_PART
	_close_fx = Node2D.new()
	_close_fx.material = Gfx.dither(true, 1.0, 2.0)
	_close.add_child(_close_fx)
	_close_fx.draw.connect(_draw_close_fx)
	_driver = _cs("film/glove_driver.png")
	_held_d = _held(_driver)
	_forceps = _cs("film/glove_forceps.png")
	_held_f = _held(_forceps)
	_driver.visible = false
	_forceps.visible = false
	_set_phase(0)


func _cs(path: String, pos: Vector2 = Vector2.ZERO) -> Sprite2D:
	return _layer(_close, path, pos)


func _held(glove: Sprite2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.show_behind_parent = true
	s.use_parent_material = true
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
		_threads = _cs(path)
		_threads.use_parent_material = false
		_threads.material = _m_threads
		_m_threads.set_shader_parameter("alpha", 0.0)


func _build_eyes() -> void:
	_cs("scope/%s/eyes_back.png" % _pid)
	var eyes: Dictionary = _case_d.get("eyes", {}) if typeof(_case_d.get("eyes")) == TYPE_DICTIONARY else {}
	var site_side := "left" if _site == "eye_l" else "right"
	for side in ["right", "left"]:
		var spec: Dictionary = eyes.get(side, {}) if typeof(eyes.get(side)) == TYPE_DICTIONARY else {}
		var pos: Vector2 = EYE_R if side == "right" else EYE_L
		var kind := str(spec.get("kind", "natural"))
		var react := str(spec.get("pupil", "tightens" if kind == "natural" else "none"))
		var tightens := bool(spec.get("tightens", react != "none"))
		var iris := _cs("scope/%s/iris_%s.png" % [_pid, "r" if side == "right" else "l"], pos - Vector2(24, 24))
		var pupil: Sprite2D = null
		if react == "tightens" or (react == "shutter" and tightens):
			pupil = _cs("scope/pupil_9.png", pos - Vector2(12, 12))
		_eyes.append({"pos": pos, "kind": kind, "tightens": tightens, "follows": bool(spec.get("follows", true)),
			"iris": iris, "old": iris.texture, "pupil": pupil, "off": Vector2.ZERO, "size": PUPIL_WIDE, "site": side == site_side})
	_eyes_front = _cs("scope/%s/eyes_front.png" % _pid)
	_target = EYE_L if _site == "eye_l" else EYE_R
	_empty_eye = _cs("film/eye_empty.png", _target - Vector2(24, 24))
	_empty_eye.visible = false
	# the other eye is covered while the light is on this one
	_cs("film/gauze.png", Vector2(32, 62) if _site == "eye_l" else Vector2(132, 62))
	_beam = Sprite2D.new()
	_beam.centered = false
	_beam.texture = _ptex("scope/light.png")
	_beam.material = Gfx.additive()
	_beam.modulate = Color(1, 1, 1, 0.85)
	_beam.visible = false
	_close.add_child(_beam)


func _site_eye() -> Dictionary:
	for e in _eyes:
		var eye: Dictionary = e
		if bool(eye["site"]):
			return eye
	return {}


## The part on the table: 0 the old one in place, 1 out (the driver holds it, the forceps hold
## the new one), 2 the new one seated.
func _set_phase(phase: int) -> void:
	_swap_phase = phase
	if _site == "eye_l" or _site == "eye_r":
		var eye := _site_eye()
		if eye.is_empty():
			return
		var iris: Sprite2D = eye["iris"]
		var old_tex: Texture2D = eye["old"]
		iris.texture = _new_iris(old_tex) if phase == 2 else old_tex
		iris.visible = phase != 1
		var pupil: Sprite2D = eye["pupil"]
		if pupil != null:
			pupil.visible = phase != 1
		_empty_eye.visible = phase == 1
		if _pid == "kip":
			var front := _ptex("film/kip/eyes_front_fixed.png" if phase == 2 else "scope/kip/eyes_front.png")
			if front != null:
				_eyes_front.texture = front
		_hold(_held_d, old_tex if phase >= 1 else null)
		_hold(_held_f, _new_iris(old_tex) if phase == 1 else null)
		return
	_old.visible = phase == 0
	if _hole != null:
		_hole.visible = phase == 1
	_new.visible = phase == 2
	_hold(_held_d, _old.texture if phase >= 1 else null)
	_hold(_held_f, _new.texture if phase == 1 else null)


func _new_iris(old_tex: Texture2D) -> Texture2D:
	if _pid == "dana":
		var fixed := _ptex("film/dana/iris_fixed.png")
		if fixed != null:
			return fixed
	return old_tex


## The sparks of tonight's film: [start, where in the world, how many, direction, speed].
## _draw_sparks draws them from the clock alone.
func _theatre_bursts() -> void:
	var tip := INS + _target * 2.0
	_bursts = [
		[6.4, TOOL_TIP, 9, Vector2(1, -1), 80.0],
		[6.62, TOOL_TIP, 5, Vector2(1, -1), 60.0],
		[8.95, tip, 14, Vector2(-1, -1), 160.0],
		[9.2, tip, 10, Vector2(-1, -1), 170.0],
		[9.45, tip, 12, Vector2(-1, -1), 165.0],
	]
	if not _drift:
		return
	if _site == "hand":
		_bursts.append([15.6, tip, 16, Vector2(-1, -1), 180.0])
	_bursts.append([23.5, LAMP + Vector2(0, 4), 30, Vector2(0, 1), 140.0])
	for b in BEATS:
		_bursts.append([float(b), LAMP + Vector2(6, 4), 8, Vector2(0, 1), 110.0])


# ------------------------------------------------------------------ one frame
## Works the whole frame out from the clock: the camera, the light, the figures and the sound.
func _frame(delta: float) -> void:
	_lights.clear()
	_amb_col = AMB
	_lamp = 0.0
	_lamp_at = LAMP
	_set = "room"
	_z = 1.0
	_f = C
	_th = 0.0
	_par = Vector2.ZERO
	_shake = 0.0
	_split = 0.0
	_slices = 0.0
	_flash = 0.0
	_flash_col = Color.WHITE
	_black = 0.0
	_post_seed = floorf(elapsed * 15.0)
	_cam_on = true
	_card_on = false
	_rain_db = -34.0
	_drone_db = -20.0
	match _kind:
		"massacre", "repair":
			_theatre(delta)
		"waiting":
			_waiting()
		_:
			_empty()
	if elapsed >= _card_t:
		_card_on = true
		_cam_on = false
	_ecg_step(delta)
	_sync_loops()
	_sync_amb()
	_place_planes()
	_apply_cam()
	_push_lights()
	_fxpost.visible = _cam_on and (_split > 0.05 or _slices > 0.02)
	if _fxpost.visible:
		_m_post.set_shader_parameter("split", _split)
		_m_post.set_shader_parameter("slices", _slices)
		_m_post.set_shader_parameter("seed", _post_seed)
	for ci in [_props, _glow, _glow2, _vig, _post, _post_glow, _straps, _passer, _close_fx]:
		if ci != null:
			(ci as CanvasItem).queue_redraw()


## The theatre: the patient in the chair, the swap in close-up, and what follows it.
func _theatre(delta: float) -> void:
	var t := elapsed
	_theatre_cam()
	_lamp = _lamp_level()
	if _drift and t >= 23.5:
		# the dead lamp swings on its arm
		var a := t - 23.5
		_lamp_at.x += roundf(sin(a * 2.6) * 5.0 * exp(-a * 0.25))
	_black = 1.0 - _k(0.0, 1.4)
	if not _drift:
		_black = maxf(_black, _k(21.3, 22.0))
	_ecg_on = true
	_ecg_alarm = false
	_ecg_flat = false
	_hr_to = 66.0
	_swap()
	_calibrate(delta)
	_pose_crew()
	_pose_patient()
	_pose_stack()
	if _drape != null:
		_drape.visible = not (_drift and t >= 27.4)
	_theatre_sounds()
	if _drift:
		_massacre()
	_theatre_lights()
	if _drift and _set == "room" and t >= 20.5 and t < 32.5 and _pat.visible:
		_push_trail(_eye_pts(_pat, _pat.tilt))


## Where the camera is. It starts wide on the room at eye level and creeps across it while the
## lamp catches, then looks down on the part for the swap, framed so the close-up fills the
## picture. It comes back close on the patient and tilts slowly up from the straps to the face.
## After a wrong admission it cuts wide and stays there, held by hand, for the strobe: nobody
## can stop what it shows. While the thing comes for it the camera sinks a little, so it looms,
## and the film ends on the face.
func _theatre_cam() -> void:
	var t := elapsed
	if t < 8.0:
		_f = Vector2(lerpf(300.0, 340.0, _smooth(_k(1.6, 8.0))), 180.0)
		_par = _f - C
	elif t < _ins_end:
		_set = "ins"
		_z = 1.5
		_f = _clamp_view(INS + _target * 2.0 + Vector2(-6, 4).lerp(Vector2(6, -3), _k(8.0, _ins_end)), Rect2(INS, INS_SIZE))
	elif not _drift:
		_z = 2.0
		_f = Vector2(320.0, lerpf(236.0, _eye_mid_y() + 8.0, _smooth(_k(16.0, 18.4))))
	elif t < 25.5:
		_z = 2.0
		_f = Vector2(320.0, lerpf(236.0, _eye_mid_y() + 6.0, _smooth(_k(17.5, 20.3))))
	elif t < 37.6:
		var sink := roundf(16.0 * _smooth(_k(31.0, 35.0)))
		_f = C + Vector2(roundf(sin(t * 0.7) * 2.0), roundf(sin(t * 0.45)) + sink)
	elif t < 39.0:
		_set = "face"
		_face_cam()
	else:
		_cam_on = false


## Keeps the picture inside r (a set's own picture), so its edge never shows, with a little to
## spare for the shake. A set narrower than the picture is centred.
func _clamp_view(f: Vector2, r: Rect2) -> Vector2:
	var half := Vector2(PICTURE.size.x / 2.0, PICTURE.size.y / 2.0) / _z + Vector2(3, 3)
	var lo := r.position + half
	var hi := r.end - half
	var x := clampf(f.x, lo.x, hi.x) if hi.x >= lo.x else r.get_center().x
	var y := clampf(f.y, lo.y, hi.y) if hi.y >= lo.y else r.get_center().y
	return Vector2(x, y)


## The face, twice and briefly: once in the flash, once screaming. Black in between.
func _face_cam() -> void:
	var t := elapsed
	var mid := (_eye_l + _eye_r) / 2.0
	if t >= 38.0 and t < 38.45:
		_z = 4.0
		_f = FACE_SET + mid + Vector2(0, 8)
	elif t >= 38.6 and t < 39.0:
		_z = 5.0
		_f = FACE_SET + mid + Vector2(0, 3)
	else:
		_cam_on = false


## The theatre lamp: it catches at 1.6, then burns steady with a faint flicker. Each film puts
## it out its own way: a brownout and a burst, a slow dimming, a failing circuit, a switch.
func _lamp_level() -> float:
	var t := elapsed
	if t < 1.6:
		return 0.0
	var v := 0.97 + 0.03 * _hash(floorf(t * 12.0), 3.0)
	if t < 2.85:
		v = 0.0
		for g in GATES:
			if t - 1.6 >= float(g[0]) and t - 1.6 < float(g[1]):
				v = 0.85
	match _kind:
		"massacre":
			if t >= 23.5:
				return 0.0
			if t >= 23.38:
				return 1.6
			if t >= 17.5:
				# weak and failing, with a dip now and then
				var dim := lerpf(0.62, 0.42, _k(17.5, 23.3))
				v *= dim if _hash(floorf(t * 9.0), 7.0) > 0.12 else dim * 0.4
			elif t >= 15.2:
				for b in BROWNOUT:
					if t - 15.2 >= float(b[0]) and t - 15.2 < float(b[1]):
						v *= float(b[2])
		"repair":
			v *= lerpf(1.0, 0.3, _k(21.0, 22.0))
		"waiting":
			if t >= 10.5:
				return 0.0
			if t >= 10.0:
				v *= 1.0 if _hash(floorf(t * 20.0), 5.0) > 0.5 else 0.3
		"empty":
			if t >= 7.5:
				return 0.0
	return v


# ------------------------------------------------------------------ the figures
func _pose_crew() -> void:
	var t := elapsed
	var sp := "crew_scrub"
	var s_at := SURGEON
	if t >= 5.4 and t < 13.0:
		sp = "crew_work"
		s_at = SURGEON + Vector2(10, 0)
	var ap := "crew_tray"
	var a_at := ASSISTANT
	if _drift:
		# each catch of the dead tube shows the next blow; in the red between them they go on
		# falling, slowly
		if t >= 28.9:
			sp = ""
		elif t >= 27.4:
			sp = "crew_fall"
			s_at = SURGEON + Vector2(-40, 10) + (Vector2(-8, 6) * _k(27.4, 28.9)).round()
		elif t >= 26.2:
			sp = "crew_recoil"
			s_at = SURGEON + Vector2(-8, 0)
		if t >= 30.4:
			ap = ""
		elif t >= 28.9:
			ap = "crew_fall"
			a_at = ASSISTANT + Vector2(40, 12) + (Vector2(8, 6) * _k(28.9, 30.4)).round()
		elif t >= 27.4:
			ap = "crew_recoil"
			a_at = ASSISTANT + Vector2(10, 0)
	_crew(_surgeon, sp, s_at)
	_crew(_assistant, ap, a_at)
	_surgeon.rim(Vector2(1, -1) / _z)
	_assistant.rim(Vector2(-1, -1) / _z)
	for i in _bodies.size():
		var b: Shade = _bodies[i]
		b.visible = _set == "room" and t >= (28.9 if i == 0 else 30.4) and t < 37.6
		b.rim(Vector2(0, -1))


## The patient in the chair. After a wrong admission they wake with the lamp dying and turn their
## head to the camera. Each time the dead tube catches they are somewhere else: up out of the
## straps, on the surgeon, on the assistant, alone among the bodies. Then they come for the lens.
func _pose_patient() -> void:
	var t := elapsed
	var on := (_drift and t < 37.6) or (not _drift and t < 16.0)
	_pat.visible = on
	_pat.scale = Vector2.ONE
	if not on:
		return
	var at := PATIENT_AT + Vector2(0, roundf(2.0 * _ease_out(_k(5.9, 6.6))))
	var turned := _drift and t >= 20.5
	var tilt := 0.0
	if turned:
		tilt = deg_to_rad(8.0) * _smooth(_k(22.4, 24.2))
	var front := ""
	var legs := false
	if _drift:
		if t >= 32.5:
			_approach_pose()
			return
		if t >= 30.4:
			at = STAND_AT
			front = "attack_s1"
			legs = true
			tilt = deg_to_rad(-5.0)
		elif t >= 28.9:
			at = Vector2(332, 58) + Vector2(roundf(4.0 * _k(28.9, 30.4)), 0)
			front = "attack_s2"
			legs = true
		elif t >= 27.4:
			at = Vector2(124, 58) - Vector2(roundf(6.0 * _k(27.4, 28.9)), 0)
			front = "attack"
			legs = true
		elif t >= 26.2:
			at += Vector2(0, -6)
			front = "attack_s1"
	_pat.position = at
	_patient_parts(_pat, tilt, front, legs, turned)
	# the edge that faces the lamp catches its light
	var rx := 0.0
	var dx := _lamp_at.x - (at.x + 80.0)
	if absf(dx) > 12.0:
		rx = signf(dx)
	_pat.rim(Vector2(rx, -1) / _z)


## It comes for the lens: it stands among the bodies and cocks its head, and at each boom, in
## the blink of the red light, it is nearer, its eyes held near the camera's height.
func _approach_pose() -> void:
	var t := elapsed
	var tilt := lerpf(deg_to_rad(-5.0), deg_to_rad(12.0), _smooth(_k(33.5, 34.6)))
	var s := 1.0
	var eyes := Vector2.ZERO
	for i in BOOMS.size():
		if t >= float(BOOMS[i]):
			s = float((STEPS[i] as Array)[0])
			eyes = (STEPS[i] as Array)[1]
	var mid := (_eye_l + _eye_r) / 2.0
	var m := NECK + (mid - NECK).rotated(tilt)
	_pat.scale = Vector2(s, s)
	_pat.position = STAND_AT if s == 1.0 else eyes - m * s
	_patient_parts(_pat, tilt, "attack" if s >= 3.0 else "attack_s1", true, true)
	_pat.rim(Vector2(0, -1))


## After a repair: the patient in colour, coming round under the lamp, eyes open, looking about.
func _pose_stack() -> void:
	if _pc == null:
		return
	var t := elapsed
	_pc.visible = not _drift and t >= 16.0
	if not _pc.visible:
		return
	_pc.position = PATIENT_AT + Vector2(0, 2)
	_m_pat.set_shader_parameter("gain", _smooth(_k(16.0, 18.0)))
	var lids: Sprite2D = _pcs.get("lids")
	if lids != null:
		lids.visible = t < 18.6 or (_blinks and t >= 20.2 and t < 20.34)
	var pupils: Sprite2D = _pcs.get("pupils")
	if pupils != null:
		var dx := 0.0
		if t >= 19.0 and t < 19.6:
			dx = -1.0
		elif t >= 19.6 and t < 20.0:
			dx = 1.0
		pupils.position = Vector2(dx, 0)


# ------------------------------------------------------------------ sound
## The room itself: a drip in the dark, the lamp catching, its hum while it burns.
func _room_sounds() -> void:
	if _at(0.5) or _at(1.25):
		_play("drip", 1.0, -16.0)
	if _at(1.6):
		_play("flicker", 1.0, -8.0)
	if elapsed >= 2.85 and _lamp > 0.05 and elapsed < _card_t:
		_loop("lamp_loop", -26.0 if _lamp > 0.5 else -32.0)


func _theatre_sounds() -> void:
	_room_sounds()
	if _at(5.9):
		_play("hiss", 0.9, -12.0)
	if _at(6.4):
		_play("driver", 0.85, -18.0)
	if _drift:
		return
	if _at(14.6):
		_play("cal_ok", 1.0, -8.0)
	if _at(16.6):
		_play("breath", 1.15, -16.0)
	if _at(22.0):
		_play("seat", 0.8, -12.0)


## A wrong admission, from the failed calibration to the face.
func _massacre() -> void:
	var t := elapsed
	var info: Dictionary = STYLE.get(_style, STYLE["fist"])
	# the calibration fails and the lamp browns out
	if _at(14.6):
		_play("cal_bad", 1.0, -6.0)
	_ecg_alarm = t >= 14.8
	_ecg_flat = t >= 29.5
	if t >= 14.8:
		_hr_to = 150.0
	if t >= 14.8 and t < 23.5:
		_loop("alarm", -16.0)
	if _at(15.2):
		_play("flicker", 0.8, -8.0)
	# close on the patient: breathing, the eyes catch
	if _at(18.2) or _at(21.8):
		_play("breath", 0.8, -14.0)
	if _at(20.5):
		_play("whine", 0.8, -12.0)
	# the lamp bursts, and in the dark the straps go
	if _at(23.5):
		_play("bang", 1.0, -2.0)
		_play("glass_crack", 1.0, -4.0)
	if _at(24.3) or _at(24.9):
		_play("strap", 1.0, -6.0)
	if _at(25.5):
		_play("static", 0.8, -14.0)
	# the dead tube catches, and each time it shows what happened
	if _at(26.2):
		_play("zap", 1.0, -8.0)
		_play("strap", 0.8, -8.0)
	if _at(27.4):
		_play(str(info.get("bite", "")), 1.0, -2.0)
		_play("scream_far", 1.0, -8.0)
		if not less_blood:
			_play("splat", 1.0, -6.0)
	if _at(28.9):
		_play(str(info.get("bite", "")), 0.9, -4.0)
		_play("scream_far", 0.8, -10.0)
		if not less_blood:
			_play("splat", 0.9, -8.0)
	if _at(29.1):
		_play("clang", 1.0, -8.0)
	if _at(30.4):
		_play("boom", 0.6, -10.0)
	if t >= 26.2 and t < 32.5:
		_loop(str(info.get("loop", "")), -18.0)
	if t >= 29.5 and t < 37.6:
		_loop("flatline", -16.0 if t < 32.5 else -26.0)
	# it comes for the lens, a step at a time
	if t >= 32.5 and t < 37.6:
		_loop("heartbeat", -8.0)
	if _at(33.5):
		_play("breath", 0.7, -10.0)
	if _at(34.5):
		_play("riser", 1.0, -10.0)
	for b in BOOMS:
		if _at(float(b)):
			_play("boom", 1.0, -2.0)
	# the face
	if _at(38.0):
		_play("turn_hit", 1.0, 0.0)
		_play("sting", 1.0, -2.0)
	if _at(38.6):
		_play("scream", float(info.get("pitch", 1.0)), 0.0)
		_play("static", 1.2, -6.0)
	if _at(39.0):
		_play("tinnitus", 1.0, -10.0)
	# the game's own rain and drone: louder in the dark, gone for the face
	if t >= 23.5:
		_drone_db = -14.0
	if t >= 37.6:
		_rain_db = -80.0
		_drone_db = -80.0
	if t >= 39.0:
		_drone_db = -30.0
	# the picture takes the blows
	_shake = 4.0 * maxf(_kick(23.5, 0.6), maxf(_kick(24.3, 0.3), _kick(24.9, 0.3)))
	_flash = 0.7 * _kick(23.5, 0.25)
	_split = 1.5 * _kick(23.5, 0.5)
	_slices = 0.6 * _kick(25.5, 0.4)
	for b in BEATS:
		var kb := _kick(float(b), 0.35)
		_shake = maxf(_shake, 3.0 * kb)
		_split = maxf(_split, 1.0 * kb)
	for b in BOOMS:
		var kb := _kick(float(b), 0.45)
		_shake = maxf(_shake, 6.0 * kb)
		_split = maxf(_split, 2.0 * kb)
		_slices = maxf(_slices, 0.4 * kb)
	if t >= 38.6 and t < 39.0:
		var n := floorf(t * 20.0)
		_shake = 3.0
		_split = 2.0 + 1.5 * _hash(n, 1.0)
		_slices = 0.6 + 0.4 * _hash(n, 2.0)
		_post_seed = n
	if t >= 38.0 and t < 38.08:
		_flash = 0.5
		_flash_col = COLD
	if t >= 37.6 and t < 39.0:
		_face_pose()


## The face: still in the flash, then screaming.
func _face_pose() -> void:
	if _fss.is_empty():
		return
	var mouth: Sprite2D = _fss.get("mouth")
	if mouth == null:
		return
	var stage := "mouth_turn.png"
	if elapsed >= 38.6 and int(elapsed / 0.08) % 2 == 1:
		stage = "mouth_turn_b.png"
	var tex := _ptex(_dry("patients/%s/%s" % [_pid, stage]))
	if tex != null:
		mouth.texture = tex


# ------------------------------------------------------------------ light
func _theatre_lights() -> void:
	var t := elapsed
	match _set:
		"room":
			_light(_lamp_at + Vector2(0, 90), 210.0, 1.05 * _lamp, WARM, 0.8)
			_light(Vector2(300, 200), 90.0, 0.5 * _lamp, WARM)
			_monitor_light()
			if _drift and _pat.visible:
				var s := _pat.scale.x
				_light(_eye_mid(_pat, _pat.tilt) + Vector2(0, 24.0 * s), 70.0 * s, 0.55 * _eye_k(), EYE_RED)
			if _drift and t >= 23.5:
				_amb_col = AMB * 0.7
				var st := _strobe()
				_light(_lamp_at + Vector2(0, 50), 290.0, 1.3 * st, STROBE, 0.85)
				# the red backs off while the tube catches, so each catch shows white
				var red := _emergency() * (1.0 - 0.85 * st)
				_light(EXIT_LAMP + Vector2(-50, 80), 330.0, 1.5 * red, ALARM_RED, 0.8)
				# its spill across the floor, where the crew fall, so their shapes show against it
				for p in POOLS:
					_light((p as Vector2) + Vector2(0, 7), 210.0, 1.8 * red, ALARM_RED, 0.45)
				var glow := str((STYLE.get(_style, STYLE["fist"]) as Dictionary).get("glow", ""))
				for b in [27.4, 28.9]:
					if glow != "" and t >= b and t < b + 0.9:
						_light(_pat.position + Vector2(80, 70), 120.0, 0.9 * (1.0 - _k(b, b + 0.9)), Color.html(glow))
		"ins":
			_amb_col = Vector3(0.05, 0.055, 0.07)
			var tip := INS + _target * 2.0
			_light(tip + Vector2(-20, -40), 260.0, 1.2 * _lamp, WARM)
			if _drift:
				if t >= 14.8:
					_light(INS + Vector2(440, 110), 320.0, 0.5 + 0.3 * sin(t * 9.0), ALARM_RED)
				if t >= 14.2:
					_light(tip, 70.0, 0.8 * _k(14.2, 14.6), ALARM_RED)
			else:
				_light(tip, 80.0, 0.5 * _fade(14.6, 16.0), GREEN)
		"face":
			_amb_col = Vector3(0.03, 0.02, 0.03)
			var fm := FACE_SET + (_eye_l + _eye_r) / 2.0
			_light(fm + Vector2(0, 80), 130.0, 1.15, EYE_RED)
			var key := 1.5 * (1.0 - _k(38.0, 38.45))
			if t >= 38.6:
				key = 0.6 * _hash(floorf(t * 30.0), 9.0)
			_light(fm + Vector2(-60, -50), 170.0, key, COLD)
	_spark_lights()


## The heart monitor's screen lights the wall round it: teal, or red when it alarms.
func _monitor_light() -> void:
	var at := Vector2(584, 162)
	if _ecg_alarm or _ecg_flat:
		_light(at, 120.0, 0.35 + 0.35 * (1.0 - fmod(elapsed, 0.6) / 0.6), ALARM_RED)
	else:
		_light(at, 90.0, 0.28 if _ecg_on else 0.14, MON_TEAL)


## The dead lamp arcing: at each beat it catches for an eighth of a second and stutters three
## times after, long enough to see what it shows, and now and then a stray flicker in between.
func _strobe() -> float:
	var t := elapsed
	if not _drift or t < 25.5 or t >= 32.5:
		return 0.0
	for b in BEATS:
		var a := t - float(b)
		if a >= 0.0 and a < 0.12:
			return 1.0
		if a >= 0.16 and a < 0.24:
			return 0.6
		if a >= 0.32 and a < 0.38:
			return 0.75
		if a >= 0.5 and a < 0.56:
			return 0.3
	if _hash(floorf(t * 10.0), 4.0) > 0.94:
		return 0.22
	return 0.0


## The red emergency light high on the back wall, from 0 to 1: it stutters on in the dark after
## the lamp bursts and then breathes slowly. At each step the thing takes towards the lens it is
## out for a blink.
func _emergency() -> float:
	var t := elapsed
	if not _drift or t < 25.2 or t >= 37.6:
		return 0.0
	if t < 25.6:
		return 0.7 if _hash(floorf(t * 24.0), 8.0) > 0.45 else 0.0
	for b in BOOMS:
		if t >= float(b) - 0.06 and t < float(b) + 0.12:
			return 0.0
	return 0.75 + 0.25 * sin((t - 25.6) * TAU / 1.8)


## How strongly a drifting patient's eyes burn: they catch at 20.5 with a stutter, then stay.
func _eye_k() -> float:
	var t := elapsed
	if t < 20.5:
		return 0.0
	if t < 21.2:
		return _smooth(_k(20.5, 21.2)) * (1.0 if _hash(floorf(t * 14.0), 6.0) > 0.35 else 0.2)
	return 1.0


## A round light in the world: where, how far it reaches, how strong, its colour, and how much
## flatter than round it is (squash > 1 reaches further up and down).
func _light(p: Vector2, r: float, s: float, col: Color, squash: float = 1.0) -> void:
	if s <= 0.005 or _lights.size() >= 8:
		return
	_lights.append([p, r, s, col, squash])


## Each burst of sparks lights its surroundings for a moment.
func _spark_lights() -> void:
	for b in _bursts:
		var age := elapsed - float(b[0])
		if age >= 0.0 and age < 0.15:
			_light(b[1], 80.0, 1.2 * (1.0 - age / 0.15), SPARK)


## Hands the lights to every lit material in screen pixels, each plane moved by its parallax.
func _push_lights() -> void:
	var xf := (get_global_transform() if is_inside_tree() else transform) * _cam.transform
	for pair in _mats:
		var m: ShaderMaterial = pair[0]
		var off := _plane_off(int(pair[1]))
		var lp := PackedColorArray()
		var lc := PackedColorArray()
		lp.resize(8)
		lc.resize(8)
		for i in _lights.size():
			var l: Array = _lights[i]
			var p: Vector2 = xf * ((l[0] as Vector2) + off)
			lp[i] = Color(p.x, p.y, float(l[1]) * _z, float(l[2]))
			var col: Color = l[3]
			lc[i] = Color(col.r, col.g, col.b, float(l[4]))
		m.set_shader_parameter("lp", lp)
		m.set_shader_parameter("lc", lc)
		m.set_shader_parameter("n", _lights.size())
		m.set_shader_parameter("amb", _amb_col)


## The light at a point of the world, as the shader works it out (without its steps): for the
## shapes the film draws itself.
func _light_at(p: Vector2) -> Vector3:
	var l := _amb_col
	for x in _lights:
		var lt: Array = x
		var d := p - (lt[0] as Vector2)
		d.y /= maxf(float(lt[4]), 0.1)
		var k := clampf(1.0 - d.length() / maxf(float(lt[1]), 1.0), 0.0, 1.0)
		var col: Color = lt[3]
		l += Vector3(col.r, col.g, col.b) * (float(lt[2]) * k * k)
	return l


func _lit_col(base: Color, p: Vector2) -> Color:
	var l := _light_at(p)
	return Color(minf(base.r * l.x, 1.0), minf(base.g * l.y, 1.0), minf(base.b * l.z, 1.0), base.a)


# ------------------------------------------------------------------ the camera
func _apply_cam() -> void:
	var s := Vector2.ZERO
	if _shake > 0.05:
		var b := floorf(elapsed * 30.0)
		s = Vector2(_hash(b, 61.0) - 0.5, _hash(b, 62.0) - 0.5) * 2.0 * _shake
	_cam.visible = _cam_on
	_cam.scale = Vector2(_z, _z)
	_cam.rotation = _th
	_cam.position = (C - (_f * _z).rotated(_th) + s).round()
	_glow2.visible = _cam_on
	_glow2.transform = _cam.transform


## The parallax: the back wall moves less than the chair as the camera creeps, the drape more.
func _place_planes() -> void:
	_ro = (_par * 0.4).round()
	_fo = (-_par * 0.5).round()
	if _room != null:
		_room.position = ROOM_AT + _ro
	if _drape != null:
		_drape.position = DRAPE_AT + _fo


func _plane_off(plane: int) -> Vector2:
	match plane:
		1:
			return _ro
		2:
			return _fo
	return Vector2.ZERO


## Where the eyes have been, for the red smear they leave when they move fast.
func _push_trail(pts: Array) -> void:
	if not _trail.is_empty():
		var last: Array = (_trail[_trail.size() - 1] as Array)[1]
		if ((last[0] as Vector2) - (pts[0] as Vector2)).length() < 0.5:
			return
	_trail.append([elapsed, pts])
	while _trail.size() > 12:
		_trail.pop_front()


# ------------------------------------------------------------------ the other films
## A doctor killed at the glass: in the back the crew wait for a patient who never comes. A
## bang and a scream from the front, a siren outside, the lamp fails, and someone walks past
## the door's window and stops to look in.
func _waiting() -> void:
	var t := elapsed
	_f = Vector2(lerpf(316.0, 328.0, _smooth(_k(0.0, 14.0))), 180.0)
	_par = _f - C
	_black = maxf(1.0 - _k(0.0, 1.4), _k(13.4, 14.0))
	_lamp = _lamp_level()
	_room_sounds()
	if _at(6.0):
		_play("bang", 0.7, -14.0)
	if _at(6.4):
		_play("scream_far", 1.0, -12.0)
	if t >= 7.3 and t < 9.5 and floori((t - 7.3) / 0.45) != floori((_pt - 7.3) / 0.45):
		_play("step", 1.0, -18.0)
	if _at(8.0):
		_play("siren", 0.8, -22.0)
	if _at(10.0):
		_play("flicker", 0.7, -8.0)
	var holding := t >= 12.0 and t < 12.9
	if t >= 11.0 and t < 13.4 and not holding and floori((t - 11.0) / 0.5) != floori((_pt - 11.0) / 0.5):
		_play("step", 0.7, -12.0)
	if _at(12.2):
		_play("whine", 0.7, -12.0)
	if _at(14.0):
		_play("sting", 0.8, -12.0)
	if t >= 10.5:
		_drone_db = -16.0
	_crew(_surgeon, "crew_look" if t >= 6.8 else "crew_scrub", SURGEON)
	_crew(_assistant, "crew_scrub" if t >= 7.3 else "crew_tray", Vector2(lerpf(ASSISTANT.x, 404.0, _smooth(_k(7.3, 9.5))), ASSISTANT.y))
	if t >= 10.5:
		# only the siren in the window lights them now, from the left
		_surgeon.rim(Vector2(-1, 0))
		_assistant.rim(Vector2(-1, 0))
	else:
		_surgeon.rim(Vector2(1, -1))
		_assistant.rim(Vector2(-1, -1))
	_light(_lamp_at + Vector2(0, 90), 210.0, 1.05 * _lamp, WARM, 0.8)
	_light(Vector2(300, 200), 90.0, 0.5 * _lamp, WARM)
	_monitor_light()
	_light(WINDOW.get_center() + Vector2(10, 40), 200.0, 0.6 * _window_red(), ALARM_RED, 1.3)
	if t >= 10.5:
		_amb_col = AMB * 0.75


## The siren outside, through the door's window: it starts at 8.0 and settles to a slow throb.
func _window_red() -> float:
	var t := elapsed
	if _kind != "waiting" or t < 8.0:
		return 0.0
	if t >= 10.0:
		return 0.75 + 0.25 * sin(t * 5.0)
	return 1.0 if fmod(t - 8.0, 0.5) < 0.22 else 0.15


## Where the one in the corridor has got to: the left of their canvas at half size. They come
## into the window, stop in it, then go.
func _passer_x() -> float:
	var x0 := WINDOW.position.x - 84.0
	var xc := WINDOW.position.x + WINDOW.size.x / 2.0 - 40.0
	var x1 := WINDOW.end.x + 4.0
	var t := elapsed
	if t < 12.0:
		return lerpf(x0, xc, _smooth(_k(11.0, 12.0)))
	if t < 12.9:
		return xc
	return lerpf(xc, x1, _ease_in(_k(12.9, 13.4)))


## Nobody admitted: the crew wait by the empty chair, give up, and the lamp goes off.
func _empty() -> void:
	_f = Vector2(lerpf(326.0, 314.0, _smooth(_k(0.0, 8.5))), 180.0)
	_par = _f - C
	_black = maxf(1.0 - _k(0.0, 1.4), _k(7.9, 8.5))
	_lamp = _lamp_level()
	_room_sounds()
	if _at(5.0) or _at(5.12) or _at(6.0):
		_play("click", 0.6, -8.0)
	if _at(7.5):
		_play("flicker", 0.7, -8.0)
	_crew(_surgeon, "crew_scrub", SURGEON)
	_crew(_assistant, "crew_tray", ASSISTANT)
	_surgeon.rim(Vector2(1, -1))
	_assistant.rim(Vector2(-1, -1))
	_light(_lamp_at + Vector2(0, 90), 210.0, 1.05 * _lamp, WARM, 0.8)
	_light(Vector2(300, 200), 90.0, 0.5 * _lamp, WARM)
	_monitor_light()


# ------------------------------------------------------------------ the close-up
## The swap: the driver backs the old part out, the forceps bring the new one in and seat it.
func _swap() -> void:
	if _driver == null:
		return
	var t := elapsed
	_driver.visible = t >= 8.5 and t < 10.2
	if _driver.visible:
		var tip := _target
		if t < 8.9:
			tip = (_target + Vector2(120, 120)).lerp(_target, _ease_out(_k(8.5, 8.9)))
		elif t < 9.7:
			var b := floorf(t * 30.0)
			tip = _target + Vector2(roundf((_hash(b, 41.0) - 0.5) * 2.0), roundf((_hash(b, 42.0) - 0.5) * 2.0))
		else:
			tip = _target.lerp(_target + Vector2(110, 110), _ease_in(_k(9.7, 10.2)))
		_glove(_driver, tip)
	_forceps.visible = t >= 10.4 and t < 13.0
	if _forceps.visible:
		var tip := _target
		if t < 10.9:
			tip = (_target + Vector2(90, 130)).lerp(_target + Vector2(6, -8), _ease_out(_k(10.4, 10.9)))
		elif t < 12.3:
			tip = (_target + Vector2(6, -8)).lerp(_target, _smooth(_k(10.9, 12.3)))
		elif t >= 12.6:
			tip = _target.lerp(_target + Vector2(90, 130), _ease_in(_k(12.6, 13.0)))
		_glove(_forceps, tip)
	var phase := 0
	if t >= 12.4:
		phase = 2
	elif t >= 9.7:
		phase = 1
	if phase != _swap_phase:
		_set_phase(phase)
	if _at(8.9):
		_play("driver", 1.0, -6.0)
	if _at(9.7):
		_play("click", 0.8, -8.0)
	if _at(12.4):
		_play("seat", 1.0, -4.0)


## The new part is tested the way the counter tested it: the grip held, the light in the eye,
## the port pinged, the voice box sounded. A drifting part fails the test.
func _calibrate(delta: float) -> void:
	var t := elapsed
	match _site:
		"hand":
			if _hand == null:
				return
			var grip: Dictionary = _case_d.get("grip", {}) if typeof(_case_d.get("grip")) == TYPE_DICTIONARY else {}
			var hold := clampf(float(grip.get("limit_ms", 800)) / 1000.0, 0.4, 1.2)
			var closed := t >= 13.3 and (_drift or t < 13.3 + hold)
			var tex := _ptex("scope/%s/%s.png" % [_pid, "grip_closed" if closed else "grip_open"])
			if tex != null:
				_hand.texture = tex
			_hand.position = Vector2.ZERO
			if _drift and t >= 13.8 and t < _ins_end:
				# it will not let go: the grip shakes, then crushes the cartridge
				var amp := 2.0 if t >= 15.6 else 1.0
				var b := floorf(t * 24.0)
				_hand.position = Vector2(roundf((_hash(b, 43.0) - 0.5) * 2.0 * amp), roundf((_hash(b, 44.0) - 0.5) * amp))
			if _at(13.3):
				_play("grip_squeeze", 1.0, -6.0)
			if not _drift and _at(13.3 + hold):
				_play("grip_release", 1.0, -6.0)
			if _drift and _at(15.6):
				_play("crunch", 1.0, -4.0)
		"eye_l", "eye_r":
			if _beam == null:
				return
			_beam.visible = t >= 13.2 and t < (_ins_end if _drift else 15.2)
			var e := _target
			var a := e + Vector2(-70, -30)
			var b := e + Vector2(50, -10)
			var light := a.lerp(e, _smooth(_k(13.2, 13.9)))
			if _drift and t >= 15.0:
				light = b.lerp(e, _smooth(_k(15.0, 15.6)))
			elif t >= 14.4:
				light = e.lerp(b, _smooth(_k(14.4, 15.0)))
			_beam.position = (light - Vector2(55, 55)).round()
			if _at(13.2):
				_play("click", 1.4, -10.0)
			_eyes_step(delta, light if _beam.visible else Vector2(-999, -999), _drift and t >= 14.0)
		"port":
			if _threads != null:
				_m_threads.set_shader_parameter("alpha", _k(13.6, 14.4) * (0.8 + 0.2 * sin(t * 9.0)) if _drift else 0.0)
			_port_pings()
		_:
			if _drift:
				if _threads != null:
					_m_threads.set_shader_parameter("alpha", _k(13.6, 14.4) * (0.8 + 0.2 * sin(t * 9.0)))
				if t >= 13.4 and t < _ins_end:
					var n := floori((t - 13.4) / 0.2)
					if n != floori((_pt - 13.4) / 0.2):
						_play("note", float([1.0, 1.26, 0.84, 1.5][n % 4]) * (1.0 + 0.02 * float(n)), -6.0)
			else:
				if _at(13.4):
					_play("note", 1.0, -6.0)
				if _at(13.6):
					_play("note", 1.26, -6.0)


## The eyes in the close-up follow the light and tighten when it is close; a drifting eye stops
## following and stares at the lens.
func _eyes_step(delta: float, light: Vector2, stare: bool) -> void:
	for e in _eyes:
		var eye: Dictionary = e
		var pos: Vector2 = eye["pos"]
		var d := light - pos
		var reach: Vector2 = REACH.get(str(eye["kind"]), Vector2(10, 4))
		var target := Vector2.ZERO
		if bool(eye["follows"]) and light.x > -500.0:
			target = Vector2(clampf(d.x * 0.2, -reach.x, reach.x), clampf(d.y * 0.16, -reach.y, reach.y))
		var site := bool(eye["site"])
		if stare and site:
			target = Vector2(roundf((_hash(floorf(elapsed * 20.0), 45.0) - 0.5) * 2.0), 0.0)
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
			var ptex := _ptex("scope/pupil_%d.png" % clampi(roundi(size), 4, 10))
			if ptex != null:
				pupil.texture = ptex


## The port is pinged every 0.35 s from 13.2; a ring goes out each time.
func _ping_times() -> Array:
	var out: Array = []
	var end := _ins_end if _drift else 14.6
	var p := 13.2
	while p < end:
		out.append(p)
		p += 0.35
	return out


func _port_pings() -> void:
	for p in _ping_times():
		if _at(float(p)):
			var bad := _drift and float(p) >= 14.2
			_play("blip", 0.7 if bad else 1.6, -14.0)


# ------------------------------------------------------------------ drawing
## The lamp's arm and dish, the emergency light's box, and the blood on the wall: shapes the
## film draws, coloured by the lights so they sit in the room.
func _draw_props() -> void:
	if _set != "room":
		return
	_draw_lamp()
	var box := Rect2(EXIT_LAMP + _ro + Vector2(-8, -5), Vector2(16, 9))
	_props.draw_rect(box, Color(0.035, 0.04, 0.045))
	_props.draw_rect(Rect2(box.position + Vector2(3, 3), Vector2(10, 4)), _lit_col(Color(0.45, 0.07, 0.06), box.get_center()))
	_props.draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), _lit_col(Color(0.6, 0.62, 0.65), box.position))
	if _drift and not less_blood:
		# the surgeon's, then the assistant's
		if elapsed >= 27.4 and elapsed < 37.6:
			_draw_splat(Vector2(150, 196), 27.4, 0.0)
		if elapsed >= 28.9 and elapsed < 37.6:
			_draw_splat(Vector2(498, 188), 28.9, 40.0)
			_draw_pool(POOLS[0], 28.9, 0.0)
		if elapsed >= 30.4 and elapsed < 37.6:
			_draw_pool(POOLS[1], 30.4, 40.0)


func _draw_lamp() -> void:
	var at := _lamp_at
	var dark := Color(0.035, 0.04, 0.045)
	_props.draw_line(Vector2(362, 38), Vector2(356, 56), dark, 2.0)
	_props.draw_line(Vector2(356, 56), at + Vector2(0, -8), dark, 2.0)
	var dish := PackedVector2Array([at + Vector2(-22, 4), at + Vector2(-14, -8), at + Vector2(14, -8), at + Vector2(22, 4)])
	_props.draw_colored_polygon(dish, dark)
	_props.draw_line(at + Vector2(-14, -8), at + Vector2(14, -8), _lit_col(Color(0.7, 0.72, 0.75), at + Vector2(0, -8)), 1.0)


## Blood thrown on the wall at t0, round at, running down after. salt keeps two splats apart.
func _draw_splat(at: Vector2, t0: float, salt: float) -> void:
	var k := _ease_out(_k(t0, t0 + 0.3))
	var base := Color(0.32, 0.02, 0.03)
	for i in 14:
		var h := float(i) + salt
		var a := _hash(h, 21.0) * TAU
		var r := (6.0 + 30.0 * _hash(h, 22.0)) * k
		var p := (at + Vector2(cos(a), sin(a) * 0.6) * r).round()
		var d := 1.0 + floorf(3.0 * _hash(h, 23.0))
		_props.draw_rect(Rect2(p, Vector2(d, d)), _lit_col(base, p))
	for i in 5:
		var h := float(i) + salt
		var p := (at + Vector2(-14.0 + 28.0 * _hash(h, 24.0), -6.0 + 14.0 * _hash(h, 25.0))).round()
		var drop := roundf((4.0 + 18.0 * _hash(h, 26.0)) * _k(t0 + 0.2, t0 + 5.0))
		_props.draw_rect(Rect2(p, Vector2(1, drop + 1.0)), _lit_col(base, p))


## Blood spreading on the floor from under a body that fell at t0: a flat ragged pool, dark,
## with a wet edge that catches the red light. salt keeps two pools apart.
func _draw_pool(at: Vector2, t0: float, salt: float) -> void:
	var k := _ease_out(_k(t0 + 0.4, t0 + 4.5))
	if k <= 0.01:
		return
	var rx := 20.0 + 56.0 * k
	var ry := 3.0 + 8.0 * k
	var pts := PackedVector2Array()
	var n := 22
	for i in n:
		var a := TAU * float(i) / float(n)
		var j := 0.8 + 0.35 * _hash(float(i) + salt, 27.0)
		pts.append((at + Vector2(cos(a) * rx * j, sin(a) * ry * j)).round())
	_props.draw_colored_polygon(pts, _lit_col(Color(0.2, 0.008, 0.012), at))
	# the near edge, from a little right of the middle round to a little left of it
	var wet := _lit_col(Color(0.75, 0.06, 0.05), at + Vector2(0, ry))
	for i in range(2, 9):
		_props.draw_line(pts[i], pts[i + 1], wet, 1.0)


## Light in the air, added over the room: the lamp's glare and its cone, the dead lamp arcing,
## the emergency light, the heart monitor, the siren in the door's window, sparks.
func _draw_glow() -> void:
	if _set == "room":
		var lamp := minf(_lamp, 1.0)
		if lamp > 0.02:
			Gfx.soft_disc(_glow, _lamp_at + Vector2(0, 4), 40.0, Gfx.WARM6, 0.55 * lamp)
			_glow.draw_rect(Rect2(_lamp_at.x - 12.0, _lamp_at.y + 3.0, 24, 2), Color(Gfx.WARM7, lamp))
			_draw_cone(lamp)
		var s := _strobe()
		if s > 0.02:
			Gfx.soft_disc(_glow, _lamp_at + Vector2(0, 6), 36.0, Color(0.93, 0.96, 1.0), 0.6 * s)
			_glow.draw_rect(Rect2(_lamp_at.x - 10.0, _lamp_at.y + 3.0, 20, 2), Color(1, 1, 1, s))
		var e := _emergency()
		if e > 0.02:
			var at := EXIT_LAMP + _ro
			Gfx.soft_disc(_glow, at, 30.0, Gfx.RED1, 0.6 * e, 0.0)
			Gfx.soft_disc(_glow, at, 11.0, Gfx.RED2, 0.85 * e)
			_glow.draw_rect(Rect2(at + Vector2(-5, -2), Vector2(10, 4)), Color(1.0, 0.45, 0.35, e))
		_draw_monitor()
		var wr := _window_red()
		if wr > 0.02:
			var win := Rect2(WINDOW.position + _ro, WINDOW.size)
			_glow.draw_rect(win, Color(Gfx.RED2, 0.5 * wr))
			Gfx.soft_disc(_glow, win.get_center(), 60.0, Gfx.RED1, 0.4 * wr)
	_draw_sparks()


## The lamp's light in the dusty air: a cone of sparse warm grain.
func _draw_cone(k: float) -> void:
	var a := _lamp_at
	var top := Color(Gfx.WARM5, 0.13 * k)
	var bottom := Color(Gfx.WARM5, 0.0)
	var pts := PackedVector2Array([a + Vector2(-20, 5), a + Vector2(20, 5), a + Vector2(120, 215), a + Vector2(-120, 215)])
	_glow.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func _draw_monitor() -> void:
	var r := Rect2(MONITOR.position + _ro, MONITOR.size)
	var col := Gfx.RED2 if _ecg_alarm or _ecg_flat else Gfx.GRN4
	_glow.draw_rect(r, Color(col, 0.08))
	var base := r.position.y + 26.0
	if not _ecg_on:
		_glow.draw_line(Vector2(r.position.x + 2.0, base), Vector2(r.end.x - 2.0, base), Color(col, 0.5), 1.0)
		return
	var n := _trace.size()
	for i in n - 1:
		# a gap runs ahead of the sweep
		var ahead := (i - _col + n) % n
		var ahead2 := (i + 1 - _col + n) % n
		if (ahead >= 1 and ahead <= 4) or (ahead2 >= 1 and ahead2 <= 4):
			continue
		var a := Vector2(r.position.x + 2.0 + float(i), base + _trace[i] * 1.3)
		var b := Vector2(r.position.x + 3.0 + float(i), base + _trace[i + 1] * 1.3)
		_glow.draw_line(a, b, col, 1.0)


## Sparks, from the clock alone: each flies out of its burst, falls and goes out.
func _draw_sparks() -> void:
	for bi in _bursts.size():
		var b: Array = _bursts[bi]
		var age := elapsed - float(b[0])
		if age < 0.0 or age > 0.8:
			continue
		var at: Vector2 = b[1]
		var dir := (b[3] as Vector2).normalized()
		var speed := float(b[4])
		for i in int(b[2]):
			var h := float(bi * 97 + i)
			var life := 0.3 + 0.5 * _hash(h, 31.0)
			if age > life:
				continue
			var ang := dir.angle() + (_hash(h, 32.0) - 0.5) * 1.6
			var v := Vector2(cos(ang), sin(ang)) * speed * (0.4 + 0.6 * _hash(h, 33.0))
			var back := maxf(0.0, age - 0.03)
			var p := at + v * age + Vector2(0, 65.0 * age * age)
			var q := at + v * back + Vector2(0, 65.0 * back * back)
			var fade := 1.0 - age / life
			_glow.draw_line(q.round(), p.round(), Color(Gfx.WARM6, 0.8 * fade), 1.0)
			_glow.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(Gfx.WARM7, fade))


## The chair's straps: shut on a patient, torn when they break loose, hanging open on an empty
## chair. Dark like the silhouettes, with the edge that faces the light picked out.
func _draw_straps() -> void:
	if _set != "room":
		return
	var t := elapsed
	var open := _kind == "waiting" or _kind == "empty"
	for a in [[Rect2(216, 228, 16, 12), 24.3], [Rect2(408, 228, 16, 12), 24.9]]:
		var r: Rect2 = a[0]
		if open or (_drift and t >= float(a[1])):
			_strap_ends(r, 10.0)
		else:
			_strap(r)
	var chest := Rect2(246, 222, 148, 5)
	if open or (_drift and t >= 26.2):
		_strap_ends(chest, 16.0)
		return
	_strap(chest)
	var buckle := Rect2(chest.get_center().x - 3.0, chest.position.y - 1.0, 6, 7)
	_straps.draw_rect(buckle, FILL)
	_straps.draw_rect(Rect2(buckle.position, Vector2(buckle.size.x, 1)), _lit_col(Color(1.0, 0.85, 0.5), buckle.position))


func _strap(r: Rect2) -> void:
	_straps.draw_rect(r, FILL)
	_straps.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), _lit_col(Color(0.9, 0.75, 0.6), r.get_center()))


## A strap torn through or left open: its two ends hang from where it was fastened.
func _strap_ends(r: Rect2, drop: float) -> void:
	var edge := _lit_col(Color(0.9, 0.75, 0.6), r.get_center())
	for x in [r.position.x, r.end.x - 3.0]:
		var end := Rect2(float(x), r.position.y, 3, r.size.y + drop)
		_straps.draw_rect(end, FILL)
		_straps.draw_rect(Rect2(end.position, Vector2(1, end.size.y)), edge)


## The one walking past the door's window: a black shape at half size, seen only through the
## wired glass.
func _draw_passer() -> void:
	var t := elapsed
	if _kind != "waiting" or _set != "room" or t < 11.0 or t >= 13.4:
		return
	var win := Rect2(WINDOW.position + _ro, WINDOW.size)
	var o := Vector2(_passer_x() + _ro.x, win.position.y - 16.0)
	var dest := Rect2(o, Vector2(80, 88)).intersection(win)
	if dest.size.x < 1.0 or dest.size.y < 1.0:
		return
	var src := Rect2((dest.position - o) * 2.0, dest.size * 2.0)
	for layer in ["body.png", "head.png"]:
		var tex := _ptex("patients/%s/%s" % [_pid, layer])
		if tex != null:
			_passer.draw_texture_rect_region(tex, dest, src, Color.BLACK)
	# the wire in the glass, over them
	var wire := Color(0.05, 0.055, 0.06)
	var x := win.position.x + 7.0
	while x < win.end.x:
		if x >= dest.position.x and x < dest.end.x:
			_passer.draw_rect(Rect2(x, dest.position.y, 1, dest.size.y), wire)
		x += 7.0
	var y := win.position.y + 7.0
	while y < win.end.y:
		if y >= dest.position.y and y < dest.end.y:
			_passer.draw_rect(Rect2(dest.position.x, y, dest.size.x, 1), wire)
		y += 7.0


## The eyes, over everything.
func _draw_glow2() -> void:
	var t := elapsed
	match _kind:
		"massacre":
			match _set:
				"room":
					if t >= 20.5 and _pat != null and _pat.visible:
						var size := (1.0 if _z < 1.5 else 0.7) * (0.5 + 0.5 * _pat.scale.x)
						_draw_trail(_glow2, size)
						_draw_eyes(_glow2, _eye_pts(_pat, _pat.tilt), _eye_k(), size)
				"face":
					if _cam_on and _fs != null:
						_draw_eyes(_glow2, _eye_pts(_fs, 0.0), 1.25, 0.48 if _z > 4.5 else 0.55)
		"waiting":
			if t >= 12.2 and t < 13.2:
				var k := _smooth(_k(12.2, 12.5)) * (1.0 - _k(12.95, 13.2))
				var o := Vector2(_passer_x() + _ro.x, WINDOW.position.y + _ro.y - 16.0)
				_draw_eyes(_glow2, [o + _eye_l * 0.5, o + _eye_r * 0.5], k, 0.4, false)


## A drifting patient's eyes as the film draws them: a white-hot slit in a deep red bloom, a long
## thin streak of red drawn out sideways as light smears across a cheap lens, a short upright
## glint, and a ring going out now and then. They flicker, and drop out for a frame now and
## then; now and then they overload, the bloom swells and a red line runs the width of the
## picture at their height. flare: false keeps the overload out (small eyes, the end card).
func _draw_eyes(ci: CanvasItem, pts: Array, k: float, size: float, flare: bool = true) -> void:
	if k <= 0.01:
		return
	var t := elapsed
	k *= 0.85 + 0.15 * _hash(floorf(t * 20.0), 11.0)
	if _hash(floorf(t * 7.0), 12.0) > 0.965:
		k *= 0.35
	var over := flare and _hash(floorf(t / 0.7), 13.0) > 0.7 and fposmod(t, 0.7) < 0.09
	var bloom := 1.6 if over else 1.0
	var ph := fposmod(t, 0.75) / 0.5
	var h := maxf(1.0, roundf(size))
	var reach := 60.0 * size
	var streak := Color(1.0, 0.25, 0.2)
	for e in pts:
		var p: Vector2 = e
		Gfx.soft_disc(ci, p, 16.0 * size * bloom, Gfx.RED1, 0.55 * k, 0.0)
		Gfx.soft_disc(ci, p, 7.0 * size * bloom, Gfx.RED2, 0.95 * k)
		Gfx.soft_band(ci, Rect2(p.x - reach, p.y - h / 2.0, reach, h), streak, 0.7 * k, true)
		Gfx.soft_band(ci, Rect2(p.x, p.y - h / 2.0, reach, h), streak, 0.7 * k, false)
		_vstreak(ci, p, 7.0 * size, maxf(1.0, roundf(0.6 * size)), Color(1.0, 0.6, 0.5), 0.6 * k)
		if ph < 1.0:
			ci.draw_arc(p, (2.0 + 16.0 * ph) * size, 0.0, TAU, 28, Color(Gfx.RED2, (1.0 - ph) * 0.5 * k), maxf(1.0, 0.6 * size))
		var c := Vector2(maxf(2.0, roundf(3.0 * size)), maxf(1.0, roundf(0.8 * size)))
		ci.draw_rect(Rect2((p - c / 2.0).round(), c), Color(1.0, 0.93, 0.86, minf(1.0, k)))
	if over and pts.size() >= 2:
		var y := ((pts[0] as Vector2).y + (pts[1] as Vector2).y) / 2.0
		var w := PICTURE.size.x / _z + 20.0
		ci.draw_rect(Rect2(_f.x - w / 2.0, y - 0.5 / _z, w, 1.0 / _z), Color(Gfx.RED2, 0.6 * k))


## A thin upright glint through p, fading out above and below it.
func _vstreak(ci: CanvasItem, p: Vector2, reach: float, w: float, col: Color, a: float) -> void:
	if a <= 0.03 or reach < 1.0:
		return
	var strong := Color(col, a)
	var gone := Color(col, 0.0)
	var x0 := p.x - w / 2.0
	var x1 := p.x + w / 2.0
	ci.draw_polygon(PackedVector2Array([Vector2(x0, p.y - reach), Vector2(x1, p.y - reach), Vector2(x1, p.y), Vector2(x0, p.y)]),
		PackedColorArray([gone, gone, strong, strong]))
	ci.draw_polygon(PackedVector2Array([Vector2(x0, p.y), Vector2(x1, p.y), Vector2(x1, p.y + reach), Vector2(x0, p.y + reach)]),
		PackedColorArray([strong, strong, gone, gone]))


## The red smear the eyes leave when they move fast.
func _draw_trail(ci: CanvasItem, size: float) -> void:
	for i in range(1, _trail.size()):
		var a: Array = _trail[i - 1]
		var b: Array = _trail[i]
		var age := elapsed - float(b[0])
		if age > 0.45:
			continue
		var fade := 1.0 - age / 0.45
		for j in 2:
			ci.draw_line((a[1] as Array)[j], (b[1] as Array)[j], Color(Gfx.RED2, 0.75 * fade), maxf(1.0, 2.0 * size))


## On the card, the eyes linger a moment where they were.
func _draw_post_glow() -> void:
	if _kind != "massacre" or elapsed < 39.0 or elapsed >= 39.9:
		return
	var mid := (_eye_l + _eye_r) / 2.0 + Vector2(0, 3)
	var pts: Array = []
	for e in [_eye_l, _eye_r]:
		pts.append(C + ((e as Vector2) - mid) * 5.0)
	_draw_eyes(_post_glow, pts, 0.8 * (1.0 - _k(39.0, 39.9)), 2.4, false)


func _draw_vig() -> void:
	if not _cam_on:
		return
	Gfx.soft_band(_vig, Rect2(0, 46, 130, 268), Color.BLACK, 0.7, false)
	Gfx.soft_band(_vig, Rect2(510, 46, 130, 268), Color.BLACK, 0.7, true)
	_vband(46.0, 100.0, 0.55, 0.0)
	_vband(260.0, 314.0, 0.0, 0.55)


## A band of the vignette across the picture, from top to bottom, with its strength at each.
func _vband(top: float, bottom: float, top_a: float, bottom_a: float) -> void:
	var a := Color(0, 0, 0, top_a)
	var b := Color(0, 0, 0, bottom_a)
	var pts := PackedVector2Array([Vector2(0, top), Vector2(640, top), Vector2(640, bottom), Vector2(0, bottom)])
	_vig.draw_polygon(pts, PackedColorArray([a, a, b, b]))


## Over the picture: black, the flash, the grain, the letterbox bars, the caption or the end
## card, and the controls.
func _draw_post() -> void:
	if not _cam_on:
		_post.draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color.BLACK)
	else:
		if _black > 0.002:
			_post.draw_rect(PICTURE, Color(0, 0, 0, clampf(_black, 0.0, 1.0)))
		if _flash > 0.01:
			_post.draw_rect(PICTURE, Color(_flash_col, clampf(_flash, 0.0, 1.0)))
		_draw_grain()
	_post.draw_rect(Rect2(0, 0, 640, 46), Color.BLACK)
	_post.draw_rect(Rect2(0, 314, 640, 46), Color.BLACK)
	if _card_on:
		_draw_card()
	else:
		var cap := _caption()
		if str(cap[0]) != "" and float(cap[2]) > 0.01:
			Gfx.text_center(_post, 320, 330, str(cap[0]), Color(cap[1] as Color, float(cap[2])))
	Gfx.text_right(_post, NEXT.end.x - 4.0, NEXT.position.y + 6.0, "Next [ENTER]", Color(Gfx.TEAL4, 0.85))
	Gfx.text_right(_post, SKIP.end.x - 4.0, SKIP.position.y + 6.0, "Skip [ESC]", Color(Gfx.TEAL4, 0.85))


## Film grain: a few light and dark specks, new every 1/24 s.
func _draw_grain() -> void:
	_grain.seed = floori(elapsed * 24.0) * 7919 + 13
	for i in 160:
		var p := Vector2(_grain.randi_range(0, 639), _grain.randi_range(46, 313))
		_post.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1, _grain.randf_range(0.03, 0.1)))
	for i in 60:
		var p := Vector2(_grain.randi_range(0, 639), _grain.randi_range(46, 313))
		_post.draw_rect(Rect2(p, Vector2(1, 1)), Color(0, 0, 0, 0.35))


## The line under the picture: [text, colour, how far it has faded in].
func _caption() -> Array:
	var t := elapsed
	if t >= 3.2 and t < 6.8:
		return ["The back room, after closing.", Gfx.TEAL6, _fade(3.2, 6.8)]
	if _kind == "massacre" or _kind == "repair":
		if t >= 13.0 and t < 14.6:
			var col := Gfx.TEAL6
			if _drift and t >= 14.2 and _hash(floorf(t * 16.0), 15.0) > 0.5:
				col = Gfx.RED2
			return ["Calibration...", col, _fade(13.0, 14.95)]
		if t >= 14.6 and t < _ins_end:
			if _drift:
				return ["Out of spec.", Gfx.RED2, _fade(14.25, _ins_end)]
			return ["In spec.", Gfx.GRN4, _fade(14.25, _ins_end)]
	return ["", Gfx.TEAL6, 0.0]


## The end card: whom the film was about, what came of them, and what it means.
func _draw_card() -> void:
	var age := elapsed - _card_t
	var who := str(_shot.get("name", ""))
	var title := str(_shot.get("title", ""))
	match _kind:
		"massacre":
			_card_name(who, 168.0, Gfx.RED2, _card_k(age, 0.6))
			_card_rule(194.0, Gfx.RED1, _card_k(age, 0.9))
			_card_line(title, 202.0, Gfx.RED3, _card_k(age, 1.2))
			_card_line("You let them in.", 226.0, Gfx.TEAL6, _card_k(age, 2.0))
		"repair":
			_card_name(who, 168.0, Gfx.GRN4, _card_k(age, 0.3))
			_card_rule(194.0, Gfx.GRN2, _card_k(age, 0.5))
			_card_line(title, 202.0, Gfx.TEAL7, _card_k(age, 0.8))
			_card_line("Admitted tonight. The part held.", 226.0, Gfx.TEAL6, _card_k(age, 1.4))
		"waiting":
			_card_name(who, 160.0, Gfx.RED2, _card_k(age, 0.4))
			_card_rule(186.0, Gfx.RED1, _card_k(age, 0.6))
			_card_line(title, 194.0, Gfx.RED3, _card_k(age, 0.9))
			_card_line("No one came back from the counter.", 218.0, Gfx.TEAL6, _card_k(age, 1.5))
			var k := _card_k(age, 2.1)
			if k > 0.0:
				Gfx.text_center_raw(_post, 320, 236, _unseen_line(), Color(Gfx.TEAL5, k))
		_:
			_card_line("No one was admitted tonight.", 174.0, Gfx.TEAL6, _card_k(age, 0.4))


func _card_k(age: float, at: float) -> float:
	return clampf((age - at) / 0.4, 0.0, 1.0)


func _card_name(s: String, y: float, col: Color, k: float) -> void:
	if k > 0.0 and s != "":
		Gfx.big_center(_post, 320, y, s, Color(col, k))


func _card_rule(y: float, col: Color, k: float) -> void:
	if k > 0.0:
		_post.draw_rect(Rect2(300, y, 40, 1), Color(col, k))


func _card_line(s: String, y: float, col: Color, k: float) -> void:
	if k > 0.0 and s != "":
		Gfx.text_center(_post, 320, y, s, Color(col, k))


func _unseen_line() -> String:
	var n := int(_shot.get("unseen", 0))
	if n > 1:
		return Lang.t("%d more were waiting.") % n
	if n == 1:
		return Lang.t("One more was waiting.")
	return Lang.t("No one else was waiting.")


## Light in the close-up: the verdict on the part, a red pulse where it fails and green where
## it holds, and the port's pings going out.
func _draw_close_fx() -> void:
	if _set != "ins":
		return
	var t := elapsed
	var ok := 0.6 * _fade(14.6, 16.0) if not _drift else 0.0
	match _site:
		"eye_l", "eye_r":
			var eye := _site_eye()
			if eye.is_empty():
				return
			var at: Vector2 = (eye["pos"] as Vector2) + (eye["off"] as Vector2)
			if _drift and t >= 14.0 and t < _ins_end:
				var pulse := 0.5 + 0.5 * sin(t * 14.0)
				Gfx.soft_disc(_close_fx, at, 10.0 + 4.0 * pulse, Gfx.RED2, 0.6 + 0.4 * pulse, 0.2)
			Gfx.soft_disc(_close_fx, at, 14.0, Gfx.GRN3, ok, 0.25)
		"port":
			for p in _ping_times():
				var age := t - float(p)
				if age < 0.0 or age > 0.6:
					continue
				var col := Gfx.RED2 if _drift and float(p) >= 14.2 else Gfx.CYAN2
				_close_fx.draw_arc(PORT_PART, 6.0 + age * 60.0, 0.0, TAU, 32, Color(col, 1.0 - age / 0.6), 2.0)
			_part_pulse(PORT_PART, 20.0)
			Gfx.soft_disc(_close_fx, PORT_PART, 16.0, Gfx.GRN3, ok, 0.25)
		"voice":
			_part_pulse(VOICE_LED, 9.0)
			if not _drift and ((t >= 13.4 and t < 13.5) or (t >= 13.6 and t < 13.75)):
				Gfx.soft_disc(_close_fx, VOICE_LED, 12.0, Gfx.CYAN2, 0.9, 0.25)
			Gfx.soft_disc(_close_fx, VOICE_LED, 10.0, Gfx.GRN3, ok, 0.25)
		_:
			_part_pulse(HAND_PART, 14.0)
			Gfx.soft_disc(_close_fx, HAND_PART, 14.0, Gfx.GRN3, ok, 0.25)


## A failing part throbs red, from the moment the test turns until the cut.
func _part_pulse(at: Vector2, r: float) -> void:
	var t := elapsed
	if not _drift or t < 14.2 or t >= _ins_end:
		return
	var pulse := 0.5 + 0.5 * sin(t * 12.0)
	Gfx.soft_disc(_close_fx, at, r * (1.0 + 0.4 * pulse), Gfx.RED2, 0.5 + 0.3 * pulse, 0.2)


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
