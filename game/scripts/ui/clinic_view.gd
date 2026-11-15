extends Node2D
## The left side of the screen above the desk: the hall behind the counter window, whoever
## stands in it, the shutter, the wall with the hall camera and the pinboard, and the little
## readouts that live on them (patience lamps, till, queue).
##
## It also keeps the damage of the night: the glass cracks blow by blow and can be broken
## out, the shutter takes dents and cuts, blood dries where it ran. All of it stays until the
## next shift starts.
##
## The Trauma Team crew lives here too. It is scenery with two controls (team_to, strobe):
## the director decides when they come; nothing about them is decided by the patient model.

const Gfx = preload("res://scripts/ui/gfx.gd")
const ScopeView = preload("res://scripts/ui/scope_view.gd")

signal shutter_landed

# where an attacker hits the glass, in window coordinates (the same as tools/art/gen_gore.py)
const HIT_HAND := Vector2(170, 118)
const HIT_TOOL := Vector2(60, 126)
const HIT_HEAD := Vector2(110, 50)
# the slit a weapon opens in the shutter, inside its 96 x 40 picture
const CUT_PATH := [Vector2(4, 30), Vector2(20, 25), Vector2(38, 22), Vector2(55, 17), Vector2(74, 13), Vector2(92, 9)]
const CUT_SIZE := Vector2(96, 40)
const SEEP_Y := 200.0             # the lower edge of the window, where blood runs out from
# the crew's marks behind the patient, in window coordinates (the same as tools/art/gen_team.py),
# and how far to the right they wait, out of sight behind the wall
const TEAM_POS := Vector2(104, 26)
const TEAM_OUT := 124.0
const BEACON_BEAT := 0.18         # seconds of red, then as long of blue
const BEACON_RED := Color(0.95, 0.1, 0.1)
const BEACON_BLUE := Color(0.15, 0.35, 1.0)
# where the street gets into the hall, in window coordinates (the same as tools/art/gen_clinic.py):
# the glass in the street door, and the doorway once that door stands open
const DOOR_PANE := Rect2(167, 42, 38, 55)
const DOOR_GAP := Rect2(161, 33, 44, 153)
const DRIED := Color(0.7, 0.56, 0.58, 0.92)

var scope: ScopeView = null
var back_slot := Node2D.new()      # patient layers behind the sill
var front_slot := Node2D.new()     # patient hands, in front of the sill
var shutter_pos: float = 0.0       # 0 open, 1 closed
var cam_id: String = ""            # who the hall camera shows ("" = empty hall)
var cam_prompt: bool = false       # blink the "buzz in" prompt on the monitor
var monitor_hot: bool = false
var till: int = 0
var rent: int = 600
var queue_index: int = 0
var queue_count: int = 5
var results: Array = []            # one bool per finished visit: was the call right
var patience: int = 0
var patience_max: int = 0
var show_patience: bool = false
var corner_text: String = ""
var danger: float = 0.0            # 0..1: red light in the window
var glass_state: int = 0           # 0 whole, 1..3 cracked further with each blow, 4 broken out
var hall_dark: float = 0.0         # 0..1: the light in the hall fails
var flicker: float = 0.0           # 0..1: the lamp over the counter stutters
var under_glow: float = 0.0        # 0..1: torchlight under the closed shutter
var under_color := Color("5ee6e0")
var less_blood: bool = false
var strobe: float = 0.0            # 0..1: red and blue light from the street, through the hall
var team_k: float = 1.0            # 1 = the crew is out of sight, 0 = on their marks

var _hall: Sprite2D
var _door: Sprite2D
var _rain: Sprite2D
var _sill: Sprite2D
var _glow: Sprite2D
var _glass: Sprite2D
var _crack: Sprite2D
var _broken: Sprite2D
var _dark := ColorRect.new()
var _strobe := ColorRect.new()
var _beam_clip := Control.new()
var _beam := Node2D.new()          # the same light where it comes in: the door's glass, or the open doorway
var _beam_lit: bool = false
var _team := Node2D.new()
var _team_red: Sprite2D
var _team_blue: Sprite2D
var _sill_blood: Sprite2D
var _sill_glass: Sprite2D
var _decals := Node2D.new()
var _zone := Node2D.new()
var _shutter: Sprite2D
var _dmg := Node2D.new()
var _stains := Node2D.new()
var _seep := Node2D.new()
var _leak := Node2D.new()
var _tint := ColorRect.new()
var _wall: Sprite2D
var _cam := Node2D.new()
var _hud := Node2D.new()

var _t: float = 0.0
var _rain_frame: int = 0
var _zone_rect := Rect2()
var _zone_label: String = ""
var _sh_from: float = 0.0
var _sh_to: float = 0.0
var _sh_time: float = 0.0
var _sh_t: float = 0.0
var _sh_moving: bool = false
var _cam_age: float = 9.0
var _till_shown: float = 0.0
var _lost_from: int = 0
var _lost_t: float = 0.0
var _dent_flash: float = 0.0
var _rng := RandomNumberGenerator.new()
var _dark_a: float = 0.0
var _flick_t: float = 0.0
var _flick_on: bool = true
var _fading: Array = []            # [sprite, alpha lost per second]
var _drips: Array = []             # blood that ran out under the shutter
var _dent_count: int = 0
var _splash_count: int = 0
var _gore_count: int = 0
var _cut: Sprite2D = null
var _cut_hot: Sprite2D = null
var _tooth: Sprite2D = null
var _cut_kind: String = ""
var _cut_k: float = 1.0
var _cut_time: float = 1.0
var _cut_hold: float = 0.0
var _team_from: float = 1.0
var _team_to: float = 1.0
var _team_time: float = 1.0
var _team_t: float = 0.0
var _team_moving: bool = false


func _ready() -> void:
	var origin := Gfx.HOLE.position
	_hall = Gfx.sprite(self, "clinic/hall.png", origin)
	_rain = Gfx.sprite(self, "clinic/rain_0.png", Vector2(337, 56))
	_door = Gfx.sprite(self, "clinic/door_open.png", origin)
	_door.visible = false
	_dark.position = origin
	_dark.size = Gfx.HOLE.size
	_dark.color = Color(0.016, 0.0, 0.024, 0.0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)
	_strobe.position = origin
	_strobe.size = Gfx.HOLE.size
	_strobe.color = Color(0, 0, 0, 0)
	_strobe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strobe)
	_beam_clip.position = origin
	_beam_clip.size = Gfx.HOLE.size
	_beam_clip.clip_contents = true
	_beam_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beam_clip)
	_beam.material = Gfx.dither(true, 0.8)
	_beam_clip.add_child(_beam)
	_beam.draw.connect(_draw_beam)
	# the crew stands behind whoever is at the counter
	_team.visible = false
	add_child(_team)
	Gfx.sprite(_team, "clinic/team.png")
	Gfx.sprite(_team, "clinic/team_lights.png")
	_team_red = Gfx.sprite(_team, "clinic/team_red.png")
	_team_blue = Gfx.sprite(_team, "clinic/team_blue.png")
	add_child(back_slot)
	_sill = Gfx.sprite(self, "clinic/sill.png", Vector2(origin.x, 185))
	_sill_blood = Gfx.sprite(self, "fx/sill_blood.png", Vector2(origin.x, 185))
	_sill_blood.visible = false
	_sill_glass = Gfx.sprite(self, "fx/sill_glass.png", Vector2(origin.x, 185))
	_sill_glass.visible = false
	add_child(front_slot)
	_glow = Gfx.sprite(self, "clinic/lamp_glow.png", Vector2(170, 18))
	_glow.material = Gfx.additive()
	_glow.modulate = Color(1, 1, 1, 0.5)
	_glass = Gfx.sprite(self, "clinic/glass.png", origin)
	_glass.modulate = Color(1, 1, 1, 0.42)
	_broken = Gfx.sprite(self, "fx/glass_broken.png", origin)
	_broken.visible = false
	_decals.position = origin
	add_child(_decals)
	_crack = Gfx.sprite(self, "fx/crack_1.png", origin)
	_crack.visible = false
	add_child(_zone)
	_zone.draw.connect(_draw_zone)
	_shutter = Gfx.sprite(self, "clinic/shutter.png", Vector2(origin.x, origin.y - 190.0))
	_shutter.add_child(_dmg)
	_tint.position = origin
	_tint.size = Gfx.HOLE.size
	_tint.color = Color(0.9, 0.08, 0.08, 0.0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_wall = Gfx.sprite(self, "clinic/wall.png")
	add_child(_stains)
	add_child(_seep)
	_seep.draw.connect(_draw_seep)
	_leak.material = Gfx.additive()
	add_child(_leak)
	_leak.draw.connect(_draw_leak)
	add_child(_cam)
	_cam.draw.connect(_draw_cam)
	add_child(_hud)
	_hud.draw.connect(_draw_hud)
	scope = ScopeView.new()
	scope.position = origin
	add_child(scope)
	_rng.randomize()
	_apply_shutter()


# ------------------------------------------------------------------ controls
func set_zone(rect: Rect2, label: String) -> void:
	_zone_rect = rect
	_zone_label = label


func clear_zone() -> void:
	_zone_rect = Rect2()
	_zone_label = ""


func set_cam(id: String) -> void:
	if cam_id != id:
		cam_id = id
		_cam_age = 0.0


func set_patience(value: int, maximum: int) -> void:
	if value < patience and maximum == patience_max:
		_lost_from = patience
		_lost_t = 0.6
	patience = value
	patience_max = maximum


func door(open: bool) -> void:
	_door.visible = open


func shutter_to(target: float, time: float) -> void:
	_sh_from = shutter_pos
	_sh_to = target
	_sh_time = maxf(0.01, time)
	_sh_t = 0.0
	_sh_moving = true


func shutter_closed() -> bool:
	return shutter_pos >= 0.999


## The crew walks in from the hall door (target 0) or back out through it (target 1).
func team_to(target: float, time: float) -> void:
	_team_from = team_k
	_team_to = clampf(target, 0.0, 1.0)
	_team_time = maxf(0.01, time)
	_team_t = 0.0
	_team_moving = true


func team_in_sight() -> bool:
	return team_k < 0.999


func team_moving() -> bool:
	return _team_moving


## Nobody was called: no crew, no lights.
func team_clear() -> void:
	team_k = 1.0
	_team_moving = false
	strobe = 0.0
	_team.visible = false


# ------------------------------------------------------------------ damage
## 0 whole, 1..3 cracked further with each blow, 4 broken out of the frame.
func set_glass(stage: int) -> void:
	glass_state = clampi(stage, 0, 4)
	_crack.visible = glass_state >= 1 and glass_state <= 3
	if _crack.visible:
		_crack.texture = Gfx.tex("fx/crack_%d.png" % glass_state)
	_broken.visible = glass_state == 4
	_glass.visible = glass_state < 4
	_sill_glass.visible = glass_state == 4
	if glass_state == 4:
		_broken.texture = Gfx.tex(_dry("fx/glass_broken.png"))
		clear_decals()      # whatever was on the pane went with it


func sill_blood(on: bool) -> void:
	_sill_blood.visible = on and not less_blood


## A mark on the glass, centred at a window position. A fading mark cools and goes. A wet
## one is still running: it is gone by the time the shutter goes back up, so the next patient
## is not standing behind it (see clear_wet).
func add_decal(path: String, center: Vector2, glowing: bool = false, fade: float = 0.0, wet: bool = false) -> void:
	var t := Gfx.tex(path)
	if t == null or glass_state == 4:
		return
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.position = (center - t.get_size() / 2.0).round()
	if glowing:
		sp.material = Gfx.additive()
	if wet:
		sp.set_meta("wet", true)
	_decals.add_child(sp)
	if fade > 0.0:
		_fading.append([sp, 1.0 / fade])


func decal_count() -> int:
	return _decals.get_child_count()


func clear_decals() -> void:
	for c in _decals.get_children():
		c.queue_free()


## What was still wet on the glass has run off it. Call this while the shutter hides the pane.
func clear_wet() -> void:
	for c in _decals.get_children():
		if c.has_meta("wet"):
			c.queue_free()


## Something hits the far side of the closed shutter: it bulges and jumps.
func shutter_dent(local: Vector2) -> void:
	var t := Gfx.tex("fx/dent_%d.png" % (_dent_count % 3))
	_dent_count += 1
	_dent_flash = 0.25
	if t == null:
		return
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.position = (local - t.get_size() / 2.0).round()
	_dmg.add_child(sp)


func dent_count() -> int:
	return _dent_count


func shutter_kick() -> void:
	_dent_flash = 0.25


## Blood thrown up the slats from whatever the bottom bar landed on.
func shutter_splash() -> void:
	var t := Gfx.tex("fx/shutter_splash.png")
	if less_blood or t == null:
		return
	var sp := Gfx.sprite(_dmg, "fx/shutter_splash.png", Vector2(0, 190.0 - float(t.get_height())))
	sp.flip_h = _splash_count % 2 == 1      # a second time tonight, it is the other arm
	_splash_count += 1


## An attack that got through: what is on our side of the emergency shutter afterwards.
## It rolls up with the shutter and is there again every time it comes down.
func shutter_gore() -> void:
	if less_blood or _gore_count >= 2:
		return
	var sp := Gfx.sprite(_dmg, "fx/shutter_gore.png", Vector2.ZERO)
	sp.flip_h = _gore_count % 2 == 1
	_gore_count += 1


func gore_count() -> int:
	return _gore_count


## A weapon comes through the shutter: "saw" opens a ragged slit, "torch" burns a line.
## `local` is the top-left corner of the 96 x 40 cut; it opens over `time` seconds.
func shutter_cut(kind: String, local: Vector2, time: float) -> void:
	_cut_kind = kind
	_cut_k = 0.0
	_cut_time = maxf(0.05, time)
	_cut_hold = 0.35
	_cut = Gfx.sprite(_dmg, _dry("fx/cut_saw.png") if kind == "saw" else "fx/burn.png", local)
	_cut.region_enabled = true
	_cut.region_rect = Rect2(0, 0, 1, CUT_SIZE.y)
	_cut_hot = null
	_tooth = null
	if kind == "saw":
		_tooth = Gfx.sprite(_dmg, _dry("fx/saw_tooth.png"), local)
	else:
		_cut_hot = Gfx.sprite(_dmg, "fx/burn_hot.png", local)
		_cut_hot.material = Gfx.additive()
		_cut_hot.region_enabled = true
		_cut_hot.region_rect = Rect2(0, 0, 1, CUT_SIZE.y)


## With the --less-blood option: the copy of a picture that was drawn without the blood, where
## there is one ("fx/cut_saw.png" -> "fx/cut_saw_clean.png").
func _dry(path: String) -> String:
	if not less_blood:
		return path
	var clean := path.trim_suffix(".png") + "_clean.png"
	return clean if Gfx.has_tex(clean) else path


func cut_active() -> bool:
	return _cut != null and _cut_k < 1.0


func has_cut() -> bool:
	return _cut != null


## Where the weapon is biting through right now, on the screen.
func cut_point() -> Vector2:
	if _cut == null:
		return Vector2.ZERO
	return _shutter.position + _cut.position + _path_at(_cut_k)


func _path_at(k: float) -> Vector2:
	var f := clampf(k, 0.0, 1.0) * float(CUT_PATH.size() - 1)
	var i := mini(int(f), CUT_PATH.size() - 2)
	var a: Vector2 = CUT_PATH[i]
	var b: Vector2 = CUT_PATH[i + 1]
	return a.lerp(b, f - float(i))


func clear_shutter_damage() -> void:
	for c in _dmg.get_children():
		c.queue_free()
	_cut = null
	_cut_hot = null
	_tooth = null
	_cut_k = 1.0
	_dent_count = 0
	_splash_count = 0
	_gore_count = 0


## Blood finds its way under the shutter and runs down the front of the counter.
## heavy: a lot of it, in wide runs that reach the bottom of the counter front.
func seep(count: int, heavy: bool = false) -> void:
	if less_blood:
		return
	for i in count:
		_drips.append({
			"x": float(_rng.randi_range(177, 381)),
			"len": 0.0,
			"max": float(_rng.randi_range(9, 23) if heavy else _rng.randi_range(4, 21)),
			"speed": _rng.randf_range(5.0, 15.0) * (1.6 if heavy else 1.0),
			"wait": _rng.randf_range(0.0, 1.8),
			"w": 2.0 if _rng.randf() < (0.6 if heavy else 0.3) else 1.0,
			"pool": float(_rng.randi_range(5, 15) if heavy else _rng.randi_range(2, 6)),
		})


func drip_count() -> int:
	return _drips.size()


## Dried blood on the wall, centred at a screen position.
func add_stain(path: String, center: Vector2, tone: Color = DRIED) -> void:
	if less_blood:
		return
	var t := Gfx.tex(path)
	if t == null:
		return
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.position = (center - t.get_size() / 2.0).round()
	sp.modulate = tone
	_stains.add_child(sp)


func stain_count() -> int:
	return _stains.get_child_count()


## A new shift: the glazier and the cleaners have been.
func reset_damage() -> void:
	set_glass(0)
	clear_decals()
	clear_shutter_damage()
	_fading.clear()
	_drips.clear()
	_seep.queue_redraw()
	for c in _stains.get_children():
		c.queue_free()
	sill_blood(false)
	under_glow = 0.0
	hall_dark = 0.0
	flicker = 0.0
	team_clear()


func snap_till() -> void:
	_till_shown = float(till)


func _apply_shutter() -> void:
	var y := roundf(Gfx.HOLE.position.y - 190.0 + 190.0 * shutter_pos)
	if _dent_flash > 0.0:
		y += roundf(_dent_flash * 8.0)      # the shutter jumps when something hits it
	_shutter.position = Vector2(Gfx.HOLE.position.x, y)


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	_t += delta
	_cam_age += delta
	var frame := int(_t / 0.11) % 3
	if frame != _rain_frame:
		_rain_frame = frame
		_rain.texture = Gfx.tex("clinic/rain_%d.png" % frame)
	if _sh_moving:
		_sh_t += delta
		var k := clampf(_sh_t / _sh_time, 0.0, 1.0)
		var eased := k * k if _sh_to > _sh_from else k      # falls faster and faster; rises evenly
		shutter_pos = lerpf(_sh_from, _sh_to, eased)
		if k >= 1.0:
			_sh_moving = false
			shutter_pos = _sh_to
			if _sh_to >= 1.0:
				shutter_landed.emit()
	if _dent_flash > 0.0:
		_dent_flash -= delta
	_apply_shutter()
	_update_damage(delta)
	_tint.color.a = danger * (0.16 + 0.12 * (0.5 + 0.5 * sin(_t * 12.0)))
	_update_team(delta)
	var glow_a := 0.5 + 0.02 * sin(_t * 1.7) + (0.03 if int(_t * 9.0) % 31 == 0 else 0.0)
	if flicker > 0.0:
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = _rng.randf_range(0.03, 0.15)
			_flick_on = _rng.randf() > 0.6 * flicker
		if not _flick_on:
			glow_a *= 0.12
	else:
		_flick_on = true
	_glow.modulate.a = glow_a
	_dark_a = move_toward(_dark_a, hall_dark, delta * 4.0)
	_dark.color.a = clampf(_dark_a * (1.0 if _flick_on else 1.3), 0.0, 0.95)
	_till_shown = move_toward(_till_shown, float(till), maxf(60.0, absf(float(till) - _till_shown) * 4.0) * delta)
	if _lost_t > 0.0:
		_lost_t -= delta
	_zone.queue_redraw()
	_cam.queue_redraw()
	_hud.queue_redraw()


func _update_team(delta: float) -> void:
	if _team_moving:
		_team_t += delta
		var k := clampf(_team_t / _team_time, 0.0, 1.0)
		# they come in fast and stop hard; going out they keep the patient's pace
		var eased := 1.0 - (1.0 - k) * (1.0 - k) if _team_to < _team_from else k * k
		team_k = lerpf(_team_from, _team_to, eased)
		if k >= 1.0:
			_team_moving = false
			team_k = _team_to
	var red := fmod(_t, BEACON_BEAT * 2.0) < BEACON_BEAT
	_team.visible = team_k < 0.999
	if _team.visible:
		var walking := team_k > 0.001 and team_k < 0.999
		var step := roundf(absf(sin(_t * 13.0))) if walking else 0.0      # boots on the floor
		_team.position = Gfx.HOLE.position + TEAM_POS + Vector2(roundf(team_k * TEAM_OUT), -step)
		_team_red.visible = red
		_team_blue.visible = not red
	if strobe > 0.0:
		# each flash is brightest as it starts, like a beacon swinging past the door
		var fall := 1.0 - fmod(_t, BEACON_BEAT) / BEACON_BEAT
		var c := BEACON_RED if red else BEACON_BLUE
		_strobe.color = Color(c.r, c.g, c.b, strobe * (0.05 + 0.11 * fall))
	else:
		_strobe.color.a = 0.0
	if strobe > 0.0 or _beam_lit:
		_beam_lit = strobe > 0.0
		_beam.queue_redraw()


## The crew's beacons where they get in. With the street door shut they show in its glass and
## spill a little way along the wall; once it stands open the whole doorway throws them down
## the hall. Everything in front of it (the patient, the crew) is drawn later and stays dark.
func _draw_beam() -> void:
	if strobe <= 0.0:
		return
	var red := fmod(_t, BEACON_BEAT * 2.0) < BEACON_BEAT
	var fall := 1.0 - fmod(_t, BEACON_BEAT) / BEACON_BEAT
	var c := BEACON_RED if red else BEACON_BLUE
	var k := strobe * (0.5 + 0.5 * fall)
	if _door.visible:
		_beam.draw_rect(DOOR_GAP, Color(c.r, c.g, c.b, 0.7 * k))
		Gfx.soft_disc(_beam, DOOR_GAP.position + Vector2(20, 72), 215.0, c, k, 0.16)
	else:
		_beam.draw_rect(DOOR_PANE, Color(c.r, c.g, c.b, k))
		Gfx.soft_disc(_beam, DOOR_PANE.get_center(), 130.0, c, 0.85 * k, 0.1)


func _update_damage(delta: float) -> void:
	# marks that cool: hot glass, hot metal
	var i := _fading.size() - 1
	while i >= 0:
		var item: Array = _fading[i]
		var sp: Variant = item[0]
		if not is_instance_valid(sp):
			_fading.remove_at(i)
		else:
			var node: Sprite2D = sp
			node.modulate.a -= float(item[1]) * delta
			if node.modulate.a <= 0.0:
				node.queue_free()
				_fading.remove_at(i)
		i -= 1
	# the cut opens along its path
	if _cut != null and _cut_k < 1.0:
		_cut_k = minf(1.0, _cut_k + delta / _cut_time)
		var tip := _path_at(_cut_k)
		var w := ceilf(tip.x + 4.0) if _cut_k < 1.0 else CUT_SIZE.x
		_cut.region_rect = Rect2(0, 0, w, CUT_SIZE.y)
		if _cut_hot != null:
			_cut_hot.region_rect = Rect2(0, 0, w, CUT_SIZE.y)
			if _cut_k >= 1.0:
				_fading.append([_cut_hot, 1.0 / 5.0])
				_cut_hot = null
		if _tooth != null:
			var jit := Vector2(float(_rng.randi_range(-1, 1)), float(_rng.randi_range(-1, 1)))
			_tooth.position = (_cut.position + tip - Vector2(13, 13) + jit).round()
			_tooth.flip_h = int(_t * 30.0) % 2 == 0
	elif _tooth != null:
		_cut_hold -= delta
		_tooth.flip_h = int(_t * 30.0) % 2 == 0
		if _cut_hold <= 0.0:
			_tooth.queue_free()      # the blade is pulled back out
			_tooth = null
	# blood runs down the counter front, then dries where it stopped
	var moving := false
	for d in _drips:
		var drip: Dictionary = d
		if float(drip["wait"]) > 0.0:
			drip["wait"] = float(drip["wait"]) - delta
			moving = true
		elif float(drip["len"]) < float(drip["max"]):
			var left := 1.0 - float(drip["len"]) / float(drip["max"])
			drip["len"] = minf(float(drip["max"]), float(drip["len"]) + float(drip["speed"]) * (0.25 + left) * delta)
			moving = true
	if moving:
		_seep.queue_redraw()
	_leak.queue_redraw()


func _draw_seep() -> void:
	for d in _drips:
		var drip: Dictionary = d
		if float(drip["wait"]) > 0.0:
			continue
		var x := float(drip["x"])
		var w := float(drip["w"])
		var n := floorf(float(drip["len"]))
		var pool := float(drip["pool"])
		_seep.draw_rect(Rect2(x - floorf(pool / 2.0), SEEP_Y, pool + w, 1), Color("5a1418"))
		if n <= 0.0:
			continue
		_seep.draw_rect(Rect2(x, SEEP_Y, w, n), Color("a02024"))
		if w > 1.0:
			_seep.draw_rect(Rect2(x, SEEP_Y, 1, n), Color("5a1418"))
		var running := float(drip["len"]) < float(drip["max"])
		_seep.draw_rect(Rect2(x, SEEP_Y + n - 1.0, w, 2), Color("e23b3b") if running else Color("a02024"))


func _draw_leak() -> void:
	if strobe > 0.01 and shutter_pos > 0.9:
		# the crew's lights in the hall, seen under the closed shutter
		var red := fmod(_t, BEACON_BEAT * 2.0) < BEACON_BEAT
		var fall := 1.0 - fmod(_t, BEACON_BEAT) / BEACON_BEAT
		var c := BEACON_RED if red else BEACON_BLUE
		for i in 5:
			var sa := strobe * (0.25 + 0.5 * fall) * (1.0 - 0.18 * float(i))
			_leak.draw_rect(Rect2(Gfx.HOLE.position.x + 2.0, SEEP_Y - 1.0 + float(i), Gfx.HOLE.size.x - 4.0, 1), Color(c, sa))
	if under_glow <= 0.01:
		return
	var f := under_glow * (0.45 + 0.55 * absf(sin(_t * 23.0) * sin(_t * 7.3)))
	for i in 6:
		var a := f * (0.55 - 0.09 * float(i))
		_leak.draw_rect(Rect2(Gfx.HOLE.position.x + 2.0, SEEP_Y - 1.0 + float(i), Gfx.HOLE.size.x - 4.0, 1), Color(under_color, a))


func _draw_zone() -> void:
	if _zone_rect.size.x <= 0.0:
		return
	var r := _zone_rect.grow(2.0)
	var col: Color = Gfx.WARM7
	var a := 4.0
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	for corner in [[x0, y0, 1.0, 1.0], [x1, y0, -1.0, 1.0], [x0, y1, 1.0, -1.0], [x1, y1, -1.0, -1.0]]:
		var cx: float = corner[0]
		var cy: float = corner[1]
		var sx: float = corner[2]
		var sy: float = corner[3]
		_zone.draw_rect(Rect2(minf(cx, cx + sx * a), cy if sy > 0.0 else cy - 1.0, a, 1), col)
		_zone.draw_rect(Rect2(cx if sx > 0.0 else cx - 1.0, minf(cy, cy + sy * a), 1, a), col)
	if _zone_label != "":
		var w := Gfx.text_w(_zone_label) + 6.0
		var lx := clampf(x0, Gfx.HOLE.position.x + 2.0, Gfx.HOLE.end.x - w - 2.0)
		var ly := maxf(Gfx.HOLE.position.y + 2.0, y0 - 12.0)
		_zone.draw_rect(Rect2(lx, ly, w, 11), Color(Gfx.INK0, 0.85))
		Gfx.text(_zone, Vector2(lx + 3.0, ly + 1.0), _zone_label, col)


func _draw_cam() -> void:
	var m := Gfx.MONITOR
	var bg := Gfx.tex("clinic/hall_cam.png")
	if bg != null:
		_cam.draw_texture(bg, m.position)
	if cam_id != "":
		var sil := Gfx.tex("patients/%s/hallcam.png" % cam_id)
		if sil != null:
			var a := clampf(_cam_age / 0.5, 0.0, 1.0)
			if _cam_age < 0.5 and int(_cam_age * 30.0) % 3 == 0:
				a *= 0.4
			var sway := roundf(sin(_t * 0.9) * 1.0)
			var pos := Vector2(m.position.x + floorf((m.size.x - sil.get_width()) / 2.0) + 12.0 + sway,
				m.end.y - sil.get_height())
			_cam.draw_texture(sil, pos, Color(1, 1, 1, a))
		Gfx.text(_cam, m.position + Vector2(10, 4), "1 WAITING", Gfx.GRN4)
	else:
		Gfx.text(_cam, m.position + Vector2(10, 4), "HALL EMPTY", Gfx.GRN3)
	if fmod(_t, 1.2) < 0.7:
		Gfx.text_right(_cam, m.end.x - 11.0, m.position.y + 4.0, "● REC", Gfx.GRN4)
	if cam_prompt and fmod(_t, 0.9) < 0.6:
		var label := "► BUZZ THEM IN"
		var w := Gfx.text_w(label) + 8.0
		var x := m.position.x + floorf((m.size.x - w) / 2.0)
		_cam.draw_rect(Rect2(x, m.end.y - 16.0, w, 12), Color(Gfx.INK0, 0.8))
		Gfx.text(_cam, Vector2(x + 4.0, m.end.y - 15.0), label, Gfx.GRN5)
	var overlay := Gfx.tex("clinic/crt_overlay.png")
	if overlay != null:
		_cam.draw_texture(overlay, m.position)
	if monitor_hot:
		_cam.draw_rect(m.grow(1.0), Gfx.CYAN2, false, 1.0)


func _draw_hud() -> void:
	# pinned note: the till
	var l := Gfx.NOTE_L
	Gfx.text(_hud, l.position + Vector2(5, 5), "TILL", Gfx.PRINT)
	var shown := int(roundf(_till_shown))
	var col: Color = Gfx.INKT if shown >= 0 else Gfx.RED1
	Gfx.big(_hud, l.position + Vector2(5, 14), str(shown), col)
	Gfx.text(_hud, l.position + Vector2(5, 37), "rent %d" % rent, Gfx.INKS)
	# pinned note: the queue
	var r := Gfx.NOTE_R
	Gfx.text(_hud, r.position + Vector2(5, 5), "PATIENT", Gfx.PRINT)
	Gfx.big(_hud, r.position + Vector2(5, 14), "%d/%d" % [mini(queue_index + 1, queue_count), queue_count], Gfx.INKT)
	for i in results.size():
		var ok := bool(results[i])
		Gfx.text(_hud, r.position + Vector2(5 + 10 * i, 37), "✓" if ok else "✗", Gfx.GRN2 if ok else Gfx.RED1)
	# patience lamps on the counter edge
	if show_patience and patience_max > 0:
		Gfx.text(_hud, Vector2(8, 210), "PATIENCE", Gfx.WARM7)
		var on := Gfx.tex("ui/pip_on.png")
		var off := Gfx.tex("ui/pip_off.png")
		for i in patience_max:
			var pos := Vector2(62 + 9 * i, 211)
			var lit := i < patience
			if not lit and _lost_t > 0.0 and i < _lost_from and fmod(_lost_t, 0.2) < 0.1:
				_hud.draw_rect(Rect2(pos.x + 1.0, pos.y + 1.0, 5, 5), Gfx.RED2)
			elif lit and on != null:
				_hud.draw_texture(on, pos)
			elif off != null:
				_hud.draw_texture(off, pos)
	if corner_text != "":
		Gfx.text(_hud, Vector2(4, 1), corner_text, Gfx.TEAL3)
