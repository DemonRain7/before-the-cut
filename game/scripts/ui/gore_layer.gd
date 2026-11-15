extends Node2D
## Everything that leaves the counter window when a patient turns: flying glass, sparks, blood
## in the air, and blood on the player's own eyes. Drawn in screen space over the interface.
##
## Layers, back to front:
##   jump   - an attacker who has come through the window is re-parented here
##   parts  - glass shards and drops of blood in flight
##   glow   - sparks and the slash (additive)
##   light  - the weapon's flare and the torch bloom (additive, dithered: see Gfx.dither)
##   blot   - the holes a torch burns in the player's sight (dithered)
##   lens   - splats that land on the player's view and run
##   vig    - a red ring closing in from the edges
## Purely cosmetic: nothing here is read by the rules.

const Gfx = preload("res://scripts/ui/gfx.gd")
const PatientRig = preload("res://scripts/ui/patient_rig.gd")

signal splatted(size: float)

const RED0 := Color("5a1418")
const RED1 := Color("a02024")
const RED2 := Color("e23b3b")
const RED3 := Color("ff7a6a")
const GRAVITY := 520.0
const SPLAT_COUNT := {"s": 3, "m": 3, "l": 3, "a": 2}

var less_blood: bool = false
var vignette: float = 0.0          # 0..1: red closing in
var jump := Node2D.new()

var _parts := Node2D.new()
var _glow := Node2D.new()
var _light := Node2D.new()
var _blot := Node2D.new()
var _lens := Node2D.new()
var _vig: Sprite2D = null
var _shards: Array = []
var _drops: Array = []
var _sparks: Array = []
var _splats: Array = []
var _streaks: Array = []
var _blooms: Array = []
var _gashes: Array = []            # cuts across the player's view: they stay, and bleed
var _burns: Array = []             # the holes a torch leaves in the player's sight
var _flare_rig: PatientRig = null  # whose weapon is throwing light
var _flare_point: String = "tool"
var _flare_r: float = 0.0
var _flare_col := Color("5ee6e0")
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _vig_a: float = 0.0
var _dirty: bool = false


func _ready() -> void:
	_rng.randomize()
	add_child(jump)
	add_child(_parts)
	_parts.draw.connect(_draw_parts)
	_glow.material = Gfx.additive()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	_light.material = Gfx.dither(true)
	add_child(_light)
	_light.draw.connect(_draw_light)
	_blot.material = Gfx.dither(false)
	add_child(_blot)
	_blot.draw.connect(_draw_blot)
	add_child(_lens)
	_lens.draw.connect(_draw_lens)
	_vig = Gfx.sprite(self, "fx/vignette.png")
	_vig.modulate = Color(0.62, 0.03, 0.05, 0.0)
	_vig.visible = false


# ------------------------------------------------------------------ controls
func clear() -> void:
	_shards.clear()
	_drops.clear()
	_sparks.clear()
	_splats.clear()
	_streaks.clear()
	_blooms.clear()
	_gashes.clear()
	_burns.clear()
	flare_off()
	vignette = 0.0
	_vig_a = 0.0
	_vig.visible = false
	_dirty = true


func busy() -> bool:
	return not (_shards.is_empty() and _drops.is_empty() and _sparks.is_empty() and _streaks.is_empty()
		and _blooms.is_empty() and _burns.is_empty())


func splat_count() -> int:
	return _splats.size()


func gash_count() -> int:
	return _gashes.size()


## A light that rides one point of the attacker's pose (the torch tip, the saw on the glass)
## until it is put out. `radius` is in the patient's own pixels: it grows as they come closer.
func flare_follow(rig: PatientRig, point: String, radius: float, color: Color) -> void:
	_flare_rig = rig
	_flare_point = point
	_flare_r = radius
	_flare_col = color
	_dirty = true


func flare_off() -> void:
	_flare_rig = null
	_flare_r = 0.0
	_dirty = true


func flare_on() -> bool:
	return _flare_r > 0.0 and is_instance_valid(_flare_rig)


## The attacker leaves the window frame: from now on they are drawn over everything.
func take(rig: PatientRig) -> void:
	for n in [rig.back, rig.front]:
		var node: Node2D = n
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		jump.add_child(node)


## The pane goes: shards fly out of `rect` at the player, growing as they come.
func burst_shards(rect: Rect2, count: int, power: float = 1.0) -> void:
	var mid := rect.get_center()
	for i in count:
		var big := _rng.randf()
		var index := clampi(int(big * big * 8.0) if _rng.randf() < 0.6 else _rng.randi_range(3, 7), 0, 7)
		var tex := Gfx.tex("fx/shard_%d.png" % index)
		if tex == null:
			continue
		var pos := Vector2(_rng.randf_range(rect.position.x + 8.0, rect.end.x - 8.0),
			_rng.randf_range(rect.position.y + 8.0, rect.end.y - 8.0))
		var out := (pos - mid)
		out = out.normalized() if out.length() > 1.0 else Vector2.UP
		var speed := _rng.randf_range(50.0, 300.0) * power
		_shards.append({
			"tex": tex,
			"pos": pos,
			"vel": out * speed + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-190.0, -20.0) * power),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-11.0, 11.0),
			"scale": _rng.randf_range(0.8, 1.2),
			"grow": _rng.randf_range(0.6, 3.4) * power,
			"age": 0.0,
			"life": _rng.randf_range(0.55, 1.25),
		})
	_dirty = true


## A few chips knocked loose by a blow.
func chips(pos: Vector2, count: int) -> void:
	for i in count:
		var tex := Gfx.tex("fx/shard_%d.png" % _rng.randi_range(0, 4))
		if tex == null:
			continue
		var ang := _rng.randf_range(-PI, 0.0)
		_shards.append({
			"tex": tex,
			"pos": pos + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0)),
			"vel": Vector2(cos(ang), sin(ang)) * _rng.randf_range(30.0, 120.0),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-9.0, 9.0),
			"scale": 1.0,
			"grow": _rng.randf_range(0.0, 0.5),
			"age": 0.0,
			"life": _rng.randf_range(0.4, 0.8),
		})
	_dirty = true


## Drops of blood thrown from `pos` roughly along `dir`.
func droplets(pos: Vector2, count: int, dir: Vector2, spread: float, speed_lo: float, speed_hi: float, big: int = 2) -> void:
	if less_blood:
		return
	var base := dir.angle()
	for i in count:
		var ang := base + _rng.randf_range(-spread, spread)
		var size := float(_rng.randi_range(1, big))
		_drops.append({
			"pos": pos + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)),
			"vel": Vector2(cos(ang), sin(ang)) * _rng.randf_range(speed_lo, speed_hi),
			"size": size,
			"col": RED2 if _rng.randf() < 0.35 else RED1,
			"age": 0.0,
			"life": _rng.randf_range(0.45, 1.1),
		})
	_dirty = true


## Sparks off glass or steel.
func sparks(pos: Vector2, count: int, dir: Vector2, spread: float, speed_lo: float, speed_hi: float, hot: Color = Color("fbe9b5")) -> void:
	var base := dir.angle()
	for i in count:
		var ang := base + _rng.randf_range(-spread, spread)
		_sparks.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * _rng.randf_range(speed_lo, speed_hi),
			"col": hot,
			"age": 0.0,
			"life": _rng.randf_range(0.15, 0.5),
		})
	_dirty = true


## Blood lands on the player's view, centred at `pos`, and starts to run.
## kind: "s" small, "m" medium, "l" large, "a" a long thrown one. delay: seconds until it lands.
func splat(pos: Vector2, kind: String = "m", scale: float = 1.0, delay: float = 0.0) -> void:
	if less_blood:
		return
	var n := int(SPLAT_COUNT.get(kind, 3))
	var tex := Gfx.tex("fx/splat_%s%d.png" % [kind, _rng.randi_range(0, n - 1)])
	if tex == null:
		return
	var size := tex.get_size() * scale
	var runs: Array = []
	var count := _rng.randi_range(2, 4) if kind == "l" else (_rng.randi_range(1, 3) if kind != "s" else _rng.randi_range(0, 1))
	for i in count:
		runs.append({
			"x": roundf(_rng.randf_range(-size.x * 0.24, size.x * 0.24)),
			"y": roundf(_rng.randf_range(-size.y * 0.05, size.y * 0.18)),
			"len": 0.0,
			"max": _rng.randf_range(size.y * 0.35, size.y * 1.1),
			"speed": _rng.randf_range(26.0, 90.0),
			"w": maxf(1.0, roundf(scale * float(_rng.randi_range(1, 2)))),
			"wait": _rng.randf_range(0.05, 0.5),
		})
	_splats.append({
		"tex": tex,
		"pos": pos.round(),
		"scale": scale,
		"flip": _rng.randf() < 0.5,
		"age": -delay,
		"runs": runs,
		"size": size.x,
		"heard": false,
	})
	_dirty = true


## The saw comes across the player's view from `a` to `b`.
func slash(a: Vector2, b: Vector2) -> void:
	_streaks.append({"a": a, "b": b, "age": 0.0, "life": 0.3})
	_dirty = true


## A torch flare right in the player's face.
func bloom(pos: Vector2, color: Color, radius: float, life: float) -> void:
	_blooms.append({"pos": pos, "col": color, "r": radius, "age": 0.0, "life": life})
	_dirty = true


## What the blade leaves across the player's view once the streak has passed: an open line
## from `a` to `b` that stays where it is and runs.
func gash(a: Vector2, b: Vector2, delay: float = 0.0) -> void:
	if less_blood:
		return
	var n := maxi(4, int(a.distance_to(b) / 24.0))
	var normal := (b - a).orthogonal().normalized()
	var pts: Array = []
	for i in n + 1:
		var wob := 0.0 if (i == 0 or i == n) else _rng.randf_range(-3.5, 3.5)
		pts.append((a.lerp(b, float(i) / float(n)) + normal * wob).round())
	var runs: Array = []
	for i in _rng.randi_range(8, 11):
		var f := _rng.randf_range(0.06, 0.94) * float(n)
		var k := mini(int(f), n - 1)
		var at := (pts[k] as Vector2).lerp(pts[k + 1] as Vector2, f - float(k)).round()
		runs.append({
			"x": at.x,
			"y": at.y,
			"len": 0.0,
			"max": _rng.randf_range(16.0, 120.0),
			"speed": _rng.randf_range(40.0, 150.0),
			"w": float(_rng.randi_range(1, 3)),
			"wait": _rng.randf_range(0.0, 0.45),
		})
	_gashes.append({"pts": pts, "age": -delay, "runs": runs})
	_dirty = true


## The torch burns a hole in the player's sight: a dark blot that swims and slowly clears.
func afterimage(pos: Vector2, radius: float, life: float = 2.6) -> void:
	_burns.append({"pos": pos, "r": radius, "age": 0.0, "life": life})
	_dirty = true


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	_t += delta
	var moving := busy() or _dirty
	_dirty = false
	_step(_shards, delta, GRAVITY * 0.8)
	_step(_drops, delta, GRAVITY)
	_step(_sparks, delta, GRAVITY * 0.55)
	for list in [_streaks, _blooms, _burns]:
		var arr: Array = list
		var i := arr.size() - 1
		while i >= 0:
			var item: Dictionary = arr[i]
			item["age"] = float(item["age"]) + delta
			if float(item["age"]) >= float(item["life"]):
				arr.remove_at(i)
			i -= 1
	var lens_moving := not _burns.is_empty()
	for g in _gashes:
		var cut: Dictionary = g
		var was := float(cut["age"])
		cut["age"] = was + delta
		if was < 0.3:
			lens_moving = true
		if float(cut["age"]) < 0.0:
			continue
		for r in cut["runs"]:
			var run: Dictionary = r
			if float(run["wait"]) > 0.0:
				run["wait"] = float(run["wait"]) - delta
				lens_moving = true
			elif float(run["len"]) < float(run["max"]):
				var left := 1.0 - float(run["len"]) / float(run["max"])
				run["len"] = minf(float(run["max"]), float(run["len"]) + float(run["speed"]) * (0.2 + left) * delta)
				lens_moving = true
	for s in _splats:
		var sp: Dictionary = s
		var before := float(sp["age"])
		sp["age"] = before + delta
		if before < 0.25:
			lens_moving = true
		if float(sp["age"]) >= 0.0 and not bool(sp["heard"]):
			sp["heard"] = true
			splatted.emit(float(sp["size"]))
		if float(sp["age"]) < 0.0:
			continue
		for r in sp["runs"]:
			var run: Dictionary = r
			if float(run["wait"]) > 0.0:
				run["wait"] = float(run["wait"]) - delta
				lens_moving = true
			elif float(run["len"]) < float(run["max"]):
				var left := 1.0 - float(run["len"]) / float(run["max"])
				run["len"] = minf(float(run["max"]), float(run["len"]) + float(run["speed"]) * (0.2 + left) * delta)
				lens_moving = true
	var target := vignette * (0.78 + 0.22 * absf(sin(_t * 5.2)))
	_vig_a = move_toward(_vig_a, target, delta * 3.5)
	_vig.visible = _vig_a > 0.01
	_vig.modulate.a = _vig_a
	if moving or busy() or flare_on():
		_parts.queue_redraw()
		_glow.queue_redraw()
		_light.queue_redraw()
	if lens_moving or moving:
		_blot.queue_redraw()
		_lens.queue_redraw()


func _step(list: Array, delta: float, gravity: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var p: Dictionary = list[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			list.remove_at(i)
		else:
			var vel: Vector2 = p["vel"]
			vel.y += gravity * delta
			p["vel"] = vel
			p["pos"] = (p["pos"] as Vector2) + vel * delta
			if p.has("rot"):
				p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		i -= 1


func _draw_parts() -> void:
	for d in _drops:
		var drop: Dictionary = d
		var pos: Vector2 = drop["pos"]
		var vel: Vector2 = drop["vel"]
		var size := float(drop["size"])
		var col: Color = drop["col"]
		var tail := pos - vel * 0.014
		_parts.draw_rect(Rect2(tail.round(), Vector2(size, size)), RED0)
		_parts.draw_rect(Rect2(pos.round(), Vector2(size, size)), col)
	for s in _shards:
		var shard: Dictionary = s
		var tex: Texture2D = shard["tex"]
		var k := float(shard["age"]) / float(shard["life"])
		var sc := float(shard["scale"]) + float(shard["grow"]) * k
		var a := clampf((1.0 - k) * 4.0, 0.0, 1.0)
		_parts.draw_set_transform((shard["pos"] as Vector2).round(), float(shard["rot"]), Vector2(sc, sc))
		_parts.draw_texture(tex, -tex.get_size() / 2.0, Color(1, 1, 1, a))
	_parts.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The flare's size this frame, in screen pixels: a cutting flame never holds still.
func _flare_size() -> float:
	return _flare_r * _flare_rig.back.scale.x * (0.62 + 0.38 * absf(sin(_t * 43.0) * sin(_t * 12.7)))


func _draw_glow() -> void:
	if flare_on():
		# the hard streaks through the flare; its soft light is on the layer above
		var at := _flare_rig.attack_point(_flare_point).round()
		var r := _flare_size()
		var reach := roundf(r * 3.4)
		_glow.draw_rect(Rect2(at.x - reach, at.y, reach * 2.0, 1), Color(_flare_col, 0.5))
		_glow.draw_rect(Rect2(at.x - roundf(reach * 0.55), at.y - 1.0, roundf(reach * 1.1), 3), Color(_flare_col, 0.3))
		_glow.draw_rect(Rect2(at.x, at.y - roundf(reach * 0.5), 1, reach), Color(1, 1, 1, 0.45))
	for s in _sparks:
		var spark: Dictionary = s
		var pos: Vector2 = spark["pos"]
		var vel: Vector2 = spark["vel"]
		var k := float(spark["age"]) / float(spark["life"])
		var hot: Color = spark["col"]
		var col := hot.lerp(Color("dc5a1e"), k)
		col.a = 1.0 - k * k
		_glow.draw_line(pos.round(), (pos - vel * 0.022).round(), col, 1.0)
		_glow.draw_rect(Rect2(pos.round(), Vector2(1, 1)), Color(1, 1, 1, col.a))
	for st in _streaks:
		var streak: Dictionary = st
		var a0: Vector2 = streak["a"]
		var b0: Vector2 = streak["b"]
		var age := float(streak["age"])
		var head := clampf(age / 0.07, 0.0, 1.0)
		var tail := clampf((age - 0.1) / 0.2, 0.0, 1.0)
		var from := a0.lerp(b0, tail * 0.85)
		var to := a0.lerp(b0, head)
		var fade := 1.0 - tail
		_glow.draw_line(from, to, Color(RED2, 0.55 * fade), 13.0)
		_glow.draw_line(from, to, Color(RED3, 0.8 * fade), 6.0)
		_glow.draw_line(from, to, Color(1, 1, 1, fade), 2.0)


## Soft light, drawn the way the rest of the game is drawn: it thins out, it never goes misty.
func _draw_light() -> void:
	if flare_on():
		var at := _flare_rig.attack_point(_flare_point).round()
		var r := _flare_size()
		Gfx.soft_disc(_light, at, r * 2.4, _flare_col, 1.0, 0.24)
		Gfx.soft_disc(_light, at, maxf(2.0, r * 0.8), Color.WHITE, 1.0, 0.45)
	for b in _blooms:
		var bloom_item: Dictionary = b
		var k := float(bloom_item["age"]) / float(bloom_item["life"])
		var col: Color = bloom_item["col"]
		var r := float(bloom_item["r"]) * (0.35 + 0.65 * sqrt(k))
		# full for the first instant, then it breaks up from the rim inwards
		var a := minf(1.0, 1.3 * (1.0 - k) * (1.0 - k))
		var pos: Vector2 = bloom_item["pos"]
		Gfx.soft_disc(_light, pos, r, col, a, 0.34)
		Gfx.soft_disc(_light, pos, r * 0.44, Color.WHITE, a, 0.5)
		# the flare spikes of a cutting torch
		for i in 8:
			var ang := float(i) * TAU / 8.0 + 0.3
			var reach := r * (1.5 if i % 2 == 0 else 1.05)
			_light.draw_line(pos, pos + Vector2(cos(ang), sin(ang)) * reach, Color(1, 1, 1, 0.75 * a), 2.0)


func _draw_blot() -> void:
	for b in _burns:
		var burn: Dictionary = b
		var k := float(burn["age"]) / float(burn["life"])
		var a := (1.0 - k) * clampf(float(burn["age"]) / 0.12, 0.0, 1.0)
		var r := float(burn["r"]) * (1.0 - 0.3 * k)
		var at := (burn["pos"] as Vector2) + Vector2(sin(_t * 2.3) * 4.0, cos(_t * 1.7) * 3.0)
		# a dark hole with a bruise-coloured heart and the ghost of the flame in the middle of it
		Gfx.soft_disc(_blot, at, r, Color(0.03, 0.0, 0.06), 0.92 * a, 0.42)
		Gfx.soft_disc(_blot, at, r * 0.56, Color(0.2, 0.02, 0.26), 0.8 * a, 0.3)
		Gfx.soft_disc(_blot, at, r * 0.2, Color(0.5, 0.95, 0.9), 0.55 * a, 0.3)


func _draw_lens() -> void:
	_draw_splats()
	for g in _gashes:
		var cut: Dictionary = g
		var age := float(cut["age"])
		if age < 0.0:
			continue
		var pts: Array = cut["pts"]
		var last := pts.size() - 1
		var shown := clampf(age / 0.07, 0.0, 1.0) * float(last)      # it opens along its length
		for r in cut["runs"]:
			var run: Dictionary = r
			if float(run["wait"]) > 0.0:
				continue
			var n := floorf(float(run["len"]))
			if n <= 0.0:
				continue
			var w := float(run["w"])
			var x := float(run["x"])
			var y := float(run["y"])
			_lens.draw_rect(Rect2(x, y, w, n), RED1)
			if w > 1.0:
				_lens.draw_rect(Rect2(x, y, 1, n), RED0)
			var running := float(run["len"]) < float(run["max"])
			_lens.draw_rect(Rect2(x - 1.0, y + n - 2.0, w + 2.0, 3), RED2 if running else RED1)
		for pass_i in 3:
			for i in last:
				if float(i) >= shown:
					break
				var p0: Vector2 = pts[i]
				var p1: Vector2 = pts[i + 1]
				if float(i + 1) > shown:
					p1 = p0.lerp(p1, shown - float(i))
				var mid := (float(i) + 0.5) / float(last)
				var w := 2.0 + 6.0 * sin(PI * mid)                    # widest in the middle
				match pass_i:
					0:
						_lens.draw_line(p0, p1, RED0, w + 3.0)
						_lens.draw_circle(p0, (w + 3.0) / 2.0, RED0)
					1:
						_lens.draw_line(p0, p1, RED1, w)
						_lens.draw_circle(p0, w / 2.0, RED1)
					_:
						_lens.draw_line(p0, p1, RED2 if age < 0.5 else Color("861a1e"), maxf(1.0, w - 4.0))


func _draw_splats() -> void:
	for s in _splats:
		var sp: Dictionary = s
		var age := float(sp["age"])
		if age < 0.0:
			continue
		var tex: Texture2D = sp["tex"]
		var base := float(sp["scale"])
		var pop := 1.0 + 0.3 * clampf(1.0 - age / 0.07, 0.0, 1.0)      # it lands hard, then sits
		var sc := base * pop
		var pos: Vector2 = sp["pos"]
		for r in sp["runs"]:
			var run: Dictionary = r
			if float(run["wait"]) > 0.0:
				continue
			var n := floorf(float(run["len"]))
			if n <= 0.0:
				continue
			var w := float(run["w"])
			var x := pos.x + float(run["x"])
			var y := pos.y + float(run["y"])
			_lens.draw_rect(Rect2(x, y, w, n), RED1)
			if w > 1.0:
				_lens.draw_rect(Rect2(x, y, 1, n), RED0)
			var running := float(run["len"]) < float(run["max"])
			_lens.draw_rect(Rect2(x - (1.0 if w > 1.0 else 0.0), y + n - 2.0, w + (2.0 if w > 1.0 else 1.0), 3), RED2 if running else RED1)
		var flip := -1.0 if bool(sp["flip"]) else 1.0
		_lens.draw_set_transform(pos, 0.0, Vector2(sc * flip, sc))
		_lens.draw_texture(tex, (-tex.get_size() / 2.0).round())
		_lens.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
