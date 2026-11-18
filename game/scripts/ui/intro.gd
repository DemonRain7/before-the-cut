extends Node2D
## The opening: a few cards that say who the doctor is, what they owe and what the job is,
## shown once a session after the title. Each card is a small moving picture drawn here in
## code, a title and a few typed lines. The words and the labels inside the pictures come from
## data/intro.json. Any click or ENTER moves on; ESC or the right button skips the rest
## (main.gd owns the input and plays the sounds this node asks for).

const Gfx = preload("res://scripts/ui/gfx.gd")

signal blip                  # some more letters of the card's text were typed
signal turned                # a card opened
signal cue(sound: String)    # something in a picture wants a sound
signal finished              # the last card closed, or the rest was skipped

const ART := Rect2(140, 48, 360, 172)     # the picture
const TEXT_X := 140.0
const TEXT_W := 360.0
const TITLE_Y := 230.0
const TEXT_Y := 246.0
const TEXT_PITCH := 12.0
const TEXT_LINES := 4
const FOOT_Y := 342.0
const CPS := 48.0            # letters typed a second
const FADE := 0.22           # the black between two cards
const LEAVE := 0.5           # the black lifting off the clinic at the end
const TYPE_AFTER := 0.35     # the picture gets a moment alone before the words start
const SETTLED := 6.0         # by now every picture has finished moving
const RUSH := 5.0            # how much faster a picture runs once its text was hurried
const FOOT := "ENTER or click: next   •   ESC: skip"
const SKY_H := 330.0         # the towers picture is taller than its frame: the view pans down it
const ARTS := ["towers", "lease", "lanterns", "line", "drift", "counter"]   # what _draw_art() can draw

var skipped: bool = false    # the player skipped the rest
var index: int = 0           # the card on screen

var _cards: Array = []
var _numbers: Dictionary = {}
var _lineup: Array = []      # hall-camera silhouettes for the line-up card, in name order
var _phase: String = ""      # "" | "enter" | "in" | "show" | "out" | "leave"
var _cover: float = 0.0      # the black over everything, 0..1
var _card_t: float = 0.0     # the picture's own clock
var _typed: float = 0.0      # letters shown
var _total: int = 0          # letters in the card's text
var _lines: PackedStringArray = PackedStringArray()
var _blips: int = 0
var _rush: bool = false
var _cued: Dictionary = {}
var _t: float = 0.0
var _clip: Control = null
var _art: Node2D = null
var _veil: ColorRect = null


func _init() -> void:
	visible = false
	_clip = Control.new()
	_clip.position = ART.position
	_clip.size = ART.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_art = Node2D.new()
	_clip.add_child(_art)
	_art.draw.connect(_draw_art)
	_veil = ColorRect.new()
	_veil.size = Gfx.SCREEN
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


## cards: the "cards" list of data/intro.json. numbers: what "{per_hour}" and the like stand
## for. cases: the cast, for the line-up card.
func setup(cards: Array, numbers: Dictionary, cases: Dictionary) -> void:
	_numbers = numbers
	_cards = []
	for c in cards:
		if c is Dictionary:
			_cards.append(c)
	_lineup = []
	var ids: Array = cases.keys()
	ids.sort()
	for id in ids:
		var c: Dictionary = cases[id]
		var path := "patients/%s/hallcam.png" % str(c.get("sprite", id))
		if Gfx.has_tex(path):
			_lineup.append(path)


func has_cards() -> bool:
	return not _cards.is_empty()


func count() -> int:
	return _cards.size()


func is_running() -> bool:
	return _phase != ""


## The words of card i as they are laid out on the screen.
func lines_of(i: int) -> PackedStringArray:
	if i < 0 or i >= _cards.size():
		return PackedStringArray()
	var card: Dictionary = _cards[i]
	return Gfx.wrap_text(Gfx.fill(str(card.get("text", "")), _numbers), TEXT_W)


func start() -> void:
	skipped = false
	index = 0
	if _cards.is_empty():
		finished.emit.call_deferred()
		return
	visible = true
	_clip.visible = false
	_phase = "enter"
	_cover = 0.0
	_veil.color = Color(0, 0, 0, 0)
	queue_redraw()


## A click or ENTER: first the rest of the text at once, then the next card.
func advance() -> void:
	if _phase != "in" and _phase != "show":
		return
	if _typed < float(_total):
		_typed = float(_total)
		_rush = true
		_cover = 0.0
		_phase = "show"
		return
	_phase = "out"


func skip_all() -> void:
	if _phase == "" or _phase == "leave":
		return
	skipped = true
	_end()


func _open_card(i: int) -> void:
	index = i
	_lines = lines_of(i)
	_total = 0
	for line in _lines:
		_total += line.length()
	_typed = 0.0
	_blips = 0
	_card_t = 0.0
	_rush = false
	_cued.clear()
	_phase = "in"
	_cover = 1.0
	_clip.visible = true
	turned.emit()


## The cards are over. The screen is black at this moment: the shift starts under it, and the
## black then lifts off the clinic.
func _end() -> void:
	_phase = "leave"
	_cover = 1.0
	_clip.visible = false
	finished.emit()


func _cue_once(key: String, sound: String) -> void:
	if _cued.has(key):
		return
	_cued[key] = true
	if _phase == "in" or _phase == "show":
		cue.emit(sound)


func _process(delta: float) -> void:
	if _phase == "":
		return
	_t += delta
	match _phase:
		"enter":
			_cover = minf(1.0, _cover + delta / FADE)
			if _cover >= 1.0:
				_open_card(0)
		"in":
			_cover = maxf(0.0, _cover - delta / FADE)
			if _cover <= 0.0:
				_phase = "show"
		"out":
			_cover = minf(1.0, _cover + delta / FADE)
			if _cover >= 1.0:
				if index + 1 < _cards.size():
					_open_card(index + 1)
				else:
					_end()
		"leave":
			_cover = maxf(0.0, _cover - delta / LEAVE)
			if _cover <= 0.0:
				_phase = ""
				visible = false
	if _phase == "in" or _phase == "show" or _phase == "out":
		_card_t += delta * (RUSH if _rush and _card_t < SETTLED else 1.0)
		if _card_t >= TYPE_AFTER and _typed < float(_total):
			_typed = minf(float(_total), _typed + delta * CPS)
			var due := int(_typed / 2.0)        # one blip for every two letters
			if due > _blips:
				_blips = due
				blip.emit()
	_veil.color = Color(0, 0, 0, clampf(_cover, 0.0, 1.0))
	queue_redraw()
	_art.queue_redraw()


func _draw() -> void:
	if _phase != "in" and _phase != "show" and _phase != "out":
		return
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Gfx.INK0)
	Gfx.outline(self, ART.grow(1.0), Gfx.TEAL3)
	var card: Dictionary = _cards[index]
	Gfx.text(self, Vector2(TEXT_X, TITLE_Y), str(card.get("title", "")), Gfx.WARM6, true)
	Gfx.text_right(self, TEXT_X + TEXT_W, TITLE_Y, "%d/%d" % [index + 1, _cards.size()], Gfx.TEAL4)
	var left := int(_typed)
	var y := TEXT_Y
	var rows := mini(_lines.size(), TEXT_LINES)
	for i in rows:
		if left <= 0:
			break
		var line := _lines[i]
		Gfx.text(self, Vector2(TEXT_X, y), line.substr(0, left), Gfx.TEAL7)
		left -= line.length()
		y += TEXT_PITCH
	if _typed >= float(_total) and fmod(_t, 0.9) < 0.55:
		# all said: a small arrow asks for the next card
		var ax := TEXT_X + TEXT_W - 7.0
		var ay := TEXT_Y + TEXT_PITCH * float(rows) + 2.0
		for i in 4:
			draw_rect(Rect2(ax + float(i), ay + float(i), 7.0 - 2.0 * float(i), 1), Gfx.WARM6)
	Gfx.text_center(self, 320.0, FOOT_Y, FOOT, Gfx.TEAL4)


# ================================================================ the pictures

func _draw_art() -> void:
	if _phase != "in" and _phase != "show" and _phase != "out":
		return
	var card: Dictionary = _cards[index]
	var labels: Dictionary = card.get("labels", {})
	match str(card.get("art", "")):
		"towers":
			_art_towers(_card_t)
		"lease":
			_art_lease(_card_t, labels)
		"lanterns":
			_art_lanterns(_card_t, labels)
		"line":
			_art_line(_card_t, labels)
		"drift":
			_art_drift(_card_t, labels)
		"counter":
			_art_counter(_card_t, labels)
		_:
			# a name missing from ARTS: an empty frame (the UI smoke test fails on it)
			_r(0, 0, ART.size.x, ART.size.y, Gfx.INK1)


func _r(x: float, y: float, w: float, h: float, color: Color) -> void:
	_art.draw_rect(Rect2(floorf(x), floorf(y), w, h), color)


## A fixed "random" number in 0..1 for a whole number: the pictures are the same every time.
static func _rnd(i: int) -> float:
	var x := (i * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var y := -ry
	while y < ry:
		var half := floorf(rx * sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry))))
		_r(c.x - half, c.y + y, half * 2.0, 2.0, color)
		y += 2.0


## The towers, and the long way down from them: the view starts among lit windows and comes
## to rest on a wet street with one small clinic sign.
func _art_towers(t: float) -> void:
	var w := ART.size.x
	var h := ART.size.y
	var k := clampf((t - 0.5) / 4.4, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var s := floorf(k * (SKY_H - h))           # how far the view has come down
	_r(0, 0, w, h, Gfx.INK0)
	# far towers, moving slower than the near ones
	var far := floorf(s * 0.6)
	for i in 11:
		var fx := float(i) * 36.0 - 14.0 + floorf(_rnd(i * 7 + 1) * 16.0)
		var fw := 16.0 + floorf(_rnd(i * 7 + 2) * 18.0)
		var top := 30.0 + floorf(_rnd(i * 7 + 3) * 110.0) - far
		_r(fx, top, fw, h - top, Gfx.INK1)
		for j in 9:
			if _rnd(i * 31 + j * 5 + 2) < 0.42:
				var wx := fx + 3.0 + floorf(_rnd(i * 17 + j) * (fw - 7.0))
				_r(wx, top + 7.0 + float(j) * 11.0, 2, 2, Gfx.TEAL3)
	# the near towers: the higher the floor, the more of its windows are lit
	var towers := [[26.0, 64.0, 22.0], [148.0, 80.0, 4.0], [270.0, 62.0, 40.0]]
	var base := 270.0
	for n in towers.size():
		var tx := float(towers[n][0])
		var tw := float(towers[n][1])
		var top := float(towers[n][2])
		var sy := top - s
		_r(tx, sy, tw, base - top, Gfx.TEAL1)
		_r(tx, sy, 1, base - top, Gfx.TEAL2)
		_r(tx, sy, tw, 1, Gfx.TEAL3)
		var cols := int((tw - 8.0) / 7.0)
		var rows := int((base - top - 10.0) / 8.0)
		for row in rows:
			var wy := sy + 6.0 + float(row) * 8.0
			if wy < -4.0 or wy > h:
				continue
			var depth := (top + float(row) * 8.0) / base
			for col in cols:
				var key := n * 977 + row * 31 + col
				var color: Color = Gfx.TEAL2
				if _rnd(key) < lerpf(0.66, 0.08, depth):
					var pick := _rnd(key * 3 + 5)
					color = Gfx.WARM5 if pick < 0.5 else (Gfx.WARM6 if pick < 0.86 else Gfx.CYAN2)
					if _rnd(key * 7 + 1) < 0.05 and int(t * 5.0 + _rnd(key) * 9.0) % 6 == 0:
						color = Gfx.TEAL2          # a light that flickers
				_r(tx + 5.0 + float(col) * 7.0, wy, 4, 4, color)
	# what sits on them: a mast, a sign, a mark, a bridge between two
	var mast_x := 148.0 + 40.0
	_r(mast_x, 4.0 - 24.0 - s, 1, 24, Gfx.TEAL3)
	if fmod(t, 1.2) < 0.6:
		_r(mast_x - 1.0, 4.0 - 26.0 - s, 3, 3, Gfx.RED2)
	var sign_on := int(t * 9.0) % 31 != 0
	_r(91.0, 58.0 - s, 7, 52, Gfx.INK1)
	for g in 6:
		_r(93.0, 61.0 + float(g) * 8.0 - s, 3, 5, Gfx.CYAN2 if sign_on else Gfx.CYAN1)
	Gfx.outline(_art, Rect2(294.0, 50.0 - s, 14, 14), Gfx.MAG2)
	_r(299.0, 55.0 - s, 4, 4, Gfx.MAG2)
	_r(90.0, 122.0 - s, 58, 4, Gfx.TEAL2)
	for g in 7:
		_r(94.0 + float(g) * 8.0, 123.0 - s, 2, 2, Gfx.WARM5)
	# the elevated line, and a train on it
	var rail := 236.0 - s
	for p in 5:
		_r(20.0 + float(p) * 80.0, rail + 3.0, 4, 90, Gfx.TEAL2)
	_r(0, rail, w, 3, Gfx.TEAL3)
	_r(0, rail + 3.0, w, 1, Gfx.INK0)
	var train := 380.0 - (t - 2.3) * 170.0
	if train < w and train > -160.0:
		for car in 3:
			var cx := train + float(car) * 48.0
			_r(cx, rail - 8.0, 44, 8, Gfx.TEAL4)
			for win in 6:
				_r(cx + 4.0 + float(win) * 6.0, rail - 6.0, 3, 3, Gfx.WARM7)
	# the street
	var street := 318.0 - s
	var blocks := [[0.0, 58.0, 268.0], [58.0, 70.0, 258.0], [128.0, 54.0, 272.0], [182.0, 84.0, 262.0], [266.0, 94.0, 270.0]]
	for b in blocks.size():
		var bx := float(blocks[b][0])
		var bw := float(blocks[b][1])
		var btop := float(blocks[b][2]) - s
		_r(bx, btop, bw, street - btop, Gfx.INK1)
		_r(bx, btop, bw, 1, Gfx.TEAL2)
		_r(bx + bw - 1.0, btop, 1, street - btop, Gfx.INK0)
		for win in int(bw / 12.0):
			if _rnd(b * 53 + win) < 0.4:
				_r(bx + 6.0 + float(win) * 12.0, btop + 8.0, 4, 5, Gfx.WARM3)
	var magenta := int(t * 7.0) % 23 != 0
	_r(66.0, 281.0 - s, 30, 7, Gfx.MAG2 if magenta else Gfx.WARM3)
	_r(286.0, 290.0 - s, 9, 16, Gfx.CYAN1)
	_r(288.0, 292.0 - s, 5, 5, Gfx.CYAN3)
	# the clinic: a warm door and a green cross
	var door := 216.0
	_r(door, street - 20.0, 12, 20, Gfx.WARM5)
	_r(door + 1.0, street - 19.0, 4, 18, Gfx.WARM7)
	_r(door - 3.0, street - 38.0, 18, 14, Gfx.INK0)
	var cross: Color = Gfx.GRN4 if fmod(t, 2.4) < 2.2 else Gfx.GRN2
	_r(door + 4.0, street - 36.0, 4, 10, cross)
	_r(door + 1.0, street - 33.0, 10, 4, cross)
	# somebody waiting under it
	_r(door - 12.0, street - 11.0, 4, 11, Gfx.TEAL3)
	_r(door - 12.0, street - 15.0, 4, 4, Gfx.TEAL4)
	_r(door - 9.0, street - 14.0, 1, 1, Gfx.RED2)
	# the wet ground gives the lights back
	_r(0, street, w, h, Gfx.INK0)
	_r(0, street, w, 1, Gfx.TEAL2)
	_r(door - 2.0, street + 3.0, 16, 1, Color(Gfx.WARM5, 0.8))
	_r(door + 1.0, street + 6.0, 10, 1, Color(Gfx.WARM5, 0.5))
	_r(door + 3.0, street + 9.0, 6, 1, Color(Gfx.WARM5, 0.3))
	_r(door + 2.0, street + 4.0, 8, 1, Color(Gfx.GRN3, 0.6))
	_r(68.0, street + 3.0, 26, 1, Color(Gfx.MAG2, 0.6))
	_r(72.0, street + 7.0, 18, 1, Color(Gfx.MAG2, 0.35))
	_r(286.0, street + 4.0, 9, 1, Color(Gfx.CYAN2, 0.5))
	# rain: thin over the towers, heavy at the bottom
	var wet := Color(Gfx.TEAL5, 0.12 + 0.46 * k)
	for i in 46:
		var rx := floorf(_rnd(i * 13 + 4) * (w + 20.0))
		var speed := 150.0 + _rnd(i * 13 + 5) * 90.0
		var ry := fmod(_rnd(i * 13 + 6) * 200.0 + t * speed, h + 24.0) - 12.0
		var drop := 3.0 + floorf(_rnd(i * 13 + 7) * 3.0)
		_r(rx, ry, 1, drop, wet)
		_r(rx - 1.0, ry + drop, 1, drop, wet)


## The lease: what the lender owns, typed out, ticked off and stamped.
func _art_lease(t: float, labels: Dictionary) -> void:
	var w := ART.size.x
	var h := ART.size.y
	_r(0, 0, w, h, Gfx.INK1)
	_ellipse(Vector2(180, 96), 196.0, 112.0, Gfx.TEAL1)      # the lamp's pool of light
	_ellipse(Vector2(180, 96), 152.0, 86.0, Gfx.TEAL2)
	var px := 74.0
	var pw := 212.0
	var py := 8.0
	_r(px + 4.0, py + 4.0, pw, h, Color(0, 0, 0, 0.5))
	_r(px, py, pw, h, Gfx.PAPER3)
	Gfx.outline(_art, Rect2(px, py, pw, h + 4.0), Gfx.PAPER1)
	var x := px + 12.0
	Gfx.text(_art, Vector2(x, py + 9.0), str(labels.get("head", "")), Gfx.INKT, true)
	Gfx.text(_art, Vector2(x, py + 20.0), str(labels.get("sub", "")), Gfx.PRINT)
	_r(px + pw - 30.0, py + 9.0, 18, 18, Gfx.INKT)           # the lender's mark
	_r(px + pw - 27.0, py + 12.0, 12, 12, Gfx.PAPER3)
	_r(px + pw - 24.0, py + 15.0, 6, 6, Gfx.INKT)
	_r(x, py + 34.0, pw - 24.0, 1, Gfx.INKS)
	var stamp_at := 2.7
	var items: Array = labels.get("items", [])
	for i in items.size():
		var at := 0.5 + 0.55 * float(i)
		if t < at:
			break
		var y := py + 44.0 + 16.0 * float(i)
		var said := str(items[i])
		Gfx.outline(_art, Rect2(x, y, 9, 9), Gfx.INKS)
		Gfx.text(_art, Vector2(x + 15.0, y), said.substr(0, int((t - at) * 60.0)), Gfx.INKT)
		if t >= at + 0.4:
			var tick := Gfx.tex("ui/mark_tick.png")
			if tick != null:
				_art.draw_texture(tick, Vector2(x - 1.0, y - 1.0))
		if i == items.size() - 1 and t >= stamp_at:
			_r(x + 15.0, y + 10.0, Gfx.text_w(said), 1, Gfx.STAMP_R)      # the item that matters
	# a signature
	if t >= 1.9:
		var scrawl := [Vector2(0, 7), Vector2(4, 1), Vector2(8, 8), Vector2(12, 3), Vector2(16, 9), Vector2(22, 2),
			Vector2(27, 8), Vector2(34, 4), Vector2(40, 7), Vector2(52, 5), Vector2(62, 6)]
		var shown := mini(scrawl.size(), 1 + int((t - 1.9) * 26.0))
		var points := PackedVector2Array()
		for i in shown:
			points.append(Vector2(x + 6.5, py + 103.5) + scrawl[i])
		if points.size() >= 2:
			_art.draw_polyline(points, Gfx.PENCIL, -1.0)
	_r(x, py + 115.0, 96, 1, Gfx.INKS)
	Gfx.text(_art, Vector2(x, py + 122.0), str(labels.get("foot", "")), Gfx.PRINT)
	for i in 4:
		_r(x, py + 138.0 + float(i) * 6.0, 120.0 + floorf(_rnd(i + 40) * 60.0), 1, Gfx.PAPER1)
	# the stamp
	if t >= stamp_at:
		_cue_once("stamp", "stamp")
		var word := str(labels.get("stamp", ""))
		var land := clampf((t - stamp_at) / 0.12, 0.0, 1.0)
		var grow := floorf((1.0 - land) * 4.0)
		var box := Rect2(px + 124.0, py + 90.0, 74, 22).grow(grow)
		var ink := Gfx.STAMP_R if land >= 1.0 else Gfx.RED3
		Gfx.outline(_art, box, ink)
		Gfx.outline(_art, box.grow(-1.0), ink)
		Gfx.text_center(_art, box.position.x + box.size.x / 2.0, box.position.y + box.size.y / 2.0 - 5.0, word, ink, true)


## Tonight's list on the clinic wall, under the Lanterns' red lamp: the code is said to the right
## visitor, and a package comes over the counter. Both entries are made up; their clues fit none
## of the game's visitors (data/intro.json says so in its note).
func _art_lanterns(t: float, labels: Dictionary) -> void:
	var w := ART.size.x
	var h := ART.size.y
	var counter_y := 150.0
	var said_at := 2.0                 # SAY is pressed on the first entry
	var slide_at := said_at + 0.9      # the package starts over the counter
	var picked_at := slide_at + 0.8    # and the entry is stamped
	# the back wall: bricks in the dark
	_r(0, 0, w, h, Gfx.INK1)
	for row in int(counter_y / 10.0):
		var yy := 4.0 + 10.0 * float(row)
		_r(0, yy, w, 1, Gfx.TEAL1)
		var xx := 12.0 if row % 2 == 1 else 0.0
		while xx < w:
			_r(xx, yy + 1.0, 1, 9, Gfx.TEAL1)
			xx += 24.0
	# the lamp: a red paper lantern swaying a little on its cord. Now and then it gutters.
	var lit := int(t * 8.0) % 29 != 0
	var lx := 318.0 + floorf(sin(t * 1.3) * 2.0 + 0.5)
	var glow := 0.06 if lit else 0.03      # its light on the bricks, in rings that fade out
	_ellipse(Vector2(lx, 64), 96.0, 84.0, Color(Gfx.RED1, glow))
	_ellipse(Vector2(lx, 58), 70.0, 62.0, Color(Gfx.RED1, glow))
	_ellipse(Vector2(lx, 52), 48.0, 44.0, Color(Gfx.RED1, glow))
	_ellipse(Vector2(lx, 44), 32.0, 28.0, Color(Gfx.RED2, glow * 1.6))
	_art.draw_line(Vector2(318.5, 0), Vector2(lx + 0.5, 18), Gfx.TEAL3)
	_r(lx - 7.0, 18, 14, 4, Gfx.INK0)
	_ellipse(Vector2(lx, 43), 17.0, 21.0, Gfx.RED1)
	_ellipse(Vector2(lx, 43), 13.0, 19.0, Gfx.RED2 if lit else Gfx.RED1)
	for rib in 4:
		var ry := 31.0 + 8.0 * float(rib)
		var half := floorf(17.0 * sqrt(maxf(0.0, 1.0 - pow((ry - 43.0) / 21.0, 2.0))))
		_r(lx - half, ry, half * 2.0, 1, Gfx.RED1)
	if lit:
		_r(lx - 6.0, 36, 2, 14, Color(Gfx.RED3, 0.6))      # the flame inside, through the paper
	_r(lx - 7.0, 64, 14, 3, Gfx.INK0)
	_r(lx - 1.0, 67, 2, 3, Gfx.RED1)
	_r(lx - 2.0, 70, 4, 9, Gfx.RED2 if lit else Gfx.RED1)
	# the courier across the counter: a hood and shoulders, the lamp's red down one side
	var rim := Color(Gfx.RED1, 0.9 if lit else 0.5)
	var cx := 282.0
	_ellipse(Vector2(cx, 102), 11.0, 13.0, Gfx.INK0)
	for i in 13:
		var dy := -13.0 + 2.0 * float(i)
		var edge := floorf(11.0 * sqrt(maxf(0.0, 1.0 - dy * dy / 169.0)))
		_r(cx + edge - 1.0, 102.0 + dy, 1, 2, rim)
	_r(cx - 5.0, 103, 2, 1, Gfx.TEAL4)
	_r(cx + 2.0, 103, 2, 1, Gfx.TEAL4)
	var sy := 112.0
	while sy < counter_y:
		var half := 12.0 + minf(10.0, (sy - 112.0) * 0.9)
		_r(cx - half, sy, half * 2.0, 2, Gfx.INK0)
		_r(cx + half - 1.0, sy, 1, 2, rim)
		sy += 2.0
	if t >= said_at + 0.3 and t < slide_at + 0.6:
		# they know the code: a word back
		for d in mini(3, 1 + int((t - said_at - 0.3) / 0.15)):
			_r(cx + 16.0 + 4.0 * float(d), 92, 2, 2, Gfx.TEAL6)
	_r(0, counter_y, w, h - counter_y, Gfx.TEAL1)
	_r(0, counter_y, w, 1, Gfx.TEAL3)
	_r(0, counter_y + 4.0, w, 1, Gfx.TEAL2)
	# the list, pinned up beside the window: a printout like the one on the wall in the game
	var px := 18.0
	var py := 6.0
	var pw := 196.0
	var ph := 140.0
	_r(px + 3.0, py + 3.0, pw, ph, Color(0, 0, 0, 0.5))
	_r(px, py, pw, ph, Gfx.PAPER3)
	Gfx.outline(_art, Rect2(px, py, pw, ph), Gfx.PAPER1)
	for i in int(ph / 10.0):
		_r(px + 3.0, py + 5.0 + 10.0 * float(i), 2, 2, Gfx.INKS)          # the feed holes
		_r(px + pw - 5.0, py + 5.0 + 10.0 * float(i), 2, 2, Gfx.INKS)
	var tx := px + 12.0
	var right := px + pw - 12.0
	Gfx.text_center(_art, px + pw / 2.0, py + 4.0, str(labels.get("head", "")), Gfx.RED1, true)
	_r(tx, py + 15.0, right - tx, 1, Gfx.RED1)
	var entries: Array = labels.get("entries", [])
	var say := str(labels.get("say", ""))
	var say_w := maxf(30.0, Gfx.text_w(say, true) + 10.0)
	for i in mini(entries.size(), 2):
		var at := 0.4 + 0.5 * float(i)
		if t < at:
			break
		var e: Dictionary = entries[i]
		var ey := py + 22.0 + 52.0 * float(i)
		if i > 0:
			_r(tx, ey - 6.0, right - tx, 1, Color(Gfx.PAPER1, 0.8))
		Gfx.text(_art, Vector2(tx, ey), str(e.get("alias", "")).substr(0, int((t - at) * 40.0)), Gfx.INKT, true)
		var clues: Array = e.get("clues", [])
		for k in clues.size():
			if t >= at + 0.2 + 0.12 * float(k):
				Gfx.text(_art, Vector2(tx, ey + 11.0 + 10.0 * float(k)), "• " + str(clues[k]), Gfx.INKT)
		if t >= at + 0.45:
			Gfx.text(_art, Vector2(tx, ey + 32.0), "\"%s\"" % str(e.get("code", "")), Gfx.INKS)
		if t < at + 0.5:
			continue
		if i == 0 and t >= picked_at:
			# settled: stamped the way the list in the game stamps it
			_cue_once("picked", "stamp")
			var word := str(labels.get("picked", ""))
			var land := clampf((t - picked_at) / 0.12, 0.0, 1.0)
			var sw := Gfx.text_w(word, true) + 6.0
			var box := Rect2(right - sw, ey - 2.0, sw, 13).grow(floorf((1.0 - land) * 3.0))
			var ink := Gfx.STAMP_G if land >= 1.0 else Gfx.GRN4
			Gfx.outline(_art, box, ink)
			Gfx.text_center(_art, box.position.x + box.size.x / 2.0, box.position.y + box.size.y / 2.0 - 5.0, word, ink, true)
			continue
		if i == 0 and t >= said_at:
			_cue_once("say", "click")
		var hot := i == 0 and t >= said_at - 0.5
		var button := Rect2(right - say_w, ey - 1.0, say_w, 11)
		_r(button.position.x + 1.0, button.position.y + 1.0, button.size.x, button.size.y, Color(0, 0, 0, 0.3))
		if i == 0 and t >= said_at and t < said_at + 0.16:
			button.position += Vector2(1, 1)     # pressed
		_r(button.position.x, button.position.y, button.size.x, button.size.y, Gfx.RED2 if hot else Gfx.RED1)
		Gfx.text_center(_art, button.position.x + button.size.x / 2.0, button.position.y + 1.0, say, Gfx.PAPER3, true)
	_r(tx, py + 122.0, right - tx, 1, Gfx.PAPER1)
	for i in 2:
		_r(tx + 10.0, py + 127.0 + 6.0 * float(i), 110.0 + floorf(_rnd(i + 60) * 40.0), 1, Gfx.PAPER2)
	# the package slides over the counter, and the till is the better for it
	if t >= slide_at:
		var slide := clampf((t - slide_at) / 0.45, 0.0, 1.0)
		slide = 1.0 - (1.0 - slide) * (1.0 - slide)
		var bx := floorf(lerpf(268.0, 228.0, slide))
		var by := counter_y - 14.0
		_r(bx + 2.0, by + 2.0, 32, 13, Color(0, 0, 0, 0.45))
		_r(bx, by, 32, 14, Gfx.TEAL3)
		_r(bx, by, 32, 1, Gfx.TEAL5)
		_r(bx, by + 13.0, 32, 1, Gfx.INK0)
		_r(bx + 13.0, by, 6, 14, Gfx.WARM5)       # tape
		_r(bx + 3.0, by + 4.0, 5, 5, Gfx.RED2)     # the Lanterns' seal
		if slide >= 1.0:
			_cue_once("drop", "cash")
			var rise := clampf((t - slide_at - 0.45) / 0.5, 0.0, 1.0)
			Gfx.text_center(_art, bx + 16.0, by - 14.0 - floorf(rise * 8.0), Gfx.fill(str(labels.get("drop", "")), _numbers), Gfx.GRN4, true)


## The lender's meter: the line climbs one step an hour. Over it the counter stays open; under
## it at the end of the night is the cut.
func _art_line(t: float, labels: Dictionary) -> void:
	var w := ART.size.x
	var h := ART.size.y
	var hours := maxi(1, int(_numbers.get("hours", 5)))
	var per_hour := int(_numbers.get("per_hour", 0))
	var ox := 38.0
	var oy := 142.0
	var step_w := floorf(290.0 / float(hours))
	var step_h := floorf(110.0 / float(hours))
	_r(0, 0, w, h, Gfx.INK0)
	for i in hours + 1:
		_r(ox + step_w * float(i), oy - step_h * float(hours) - 6.0, 1, step_h * float(hours) + 6.0, Gfx.TEAL1)
		_r(ox, oy - step_h * float(i), step_w * float(hours), 1, Gfx.TEAL1)
	var reach := clampf((t - 0.5) / 2.4, 0.0, 1.0) * float(hours)     # hours of the line drawn so far
	var tip_x := ox + reach * step_w
	var tip := Vector2(ox, oy)
	for n in range(1, hours + 1):
		var left := ox + step_w * float(n - 1)
		if tip_x <= left:
			break
		_cue_once("hour%d" % n, "beep")
		var right := minf(left + step_w, tip_x)
		var level := oy - step_h * float(n)
		# under the line: the part of the till that is not there
		var yy := level + 3.0
		while yy < oy:
			_r(left, yy, right - left, 1, Color(Gfx.RED1, 0.55))
			yy += 2.0
		_r(left, level, 2, step_h + 2.0, Gfx.AMBER)
		_r(left, level, right - left, 2, Gfx.AMBER)
		tip = Vector2(right, level)
		if reach >= float(n) - 0.5:
			Gfx.text_center(_art, left + step_w / 2.0, level - 11.0, str(n * per_hour), Gfx.AMBER)
	_r(ox - 1.0, oy - step_h * float(hours) - 6.0, 1, step_h * float(hours) + 7.0, Gfx.TEAL4)
	_r(ox - 1.0, oy, step_w * float(hours) + 2.0, 1, Gfx.TEAL4)
	Gfx.text(_art, Vector2(8, oy + 6.0), str(labels.get("hour", "")), Gfx.TEAL5)
	for n in range(1, hours + 1):
		Gfx.text_center(_art, ox + step_w * (float(n) - 0.5), oy + 6.0, str(n), Gfx.TEAL6 if reach >= float(n - 1) else Gfx.TEAL4)
	if reach > 0.0 and reach < float(hours) and fmod(t, 0.3) < 0.2:
		_r(tip.x - 1.0, tip.y - 1.0, 4, 4, Gfx.WARM7)
	var now := clampi(int(ceilf(reach)), 1, hours)
	Gfx.text(_art, Vector2(ox + 6.0, 6), "%s %d   %s %d" % [str(labels.get("hour", "")), now, str(labels.get("line", "")),
		now * per_hour], Gfx.TEAL6)
	if fmod(t, 1.0) < 0.6:
		_r(w - 14.0, 8, 5, 5, Gfx.AMBER)
	if reach > 1.2:
		Gfx.text(_art, Vector2(ox + 16.0, 46), str(labels.get("over", "")), Gfx.GRN4, true)
	if reach >= float(hours):
		_cue_once("cut", "beep_low")
		var word := str(labels.get("under", ""))
		var cx := ox + step_w * (float(hours) - 1.0)
		var wide := Gfx.text_w(word, true)
		_r(cx - wide / 2.0 - 5.0, 105, wide + 10.0, 14, Gfx.INK0)
		Gfx.outline(_art, Rect2(floorf(cx - wide / 2.0 - 5.0), 105, wide + 10.0, 14), Gfx.RED1)
		Gfx.text_center(_art, cx, 107, word, Gfx.RED3 if fmod(t, 0.9) < 0.6 else Gfx.RED2, true)


## Tonight's list, stood against a wall: the same shadow for everybody. A scan runs over them
## and tells nothing. Telling them apart is the job.
func _art_drift(t: float, labels: Dictionary) -> void:
	var w := ART.size.x
	var h := ART.size.y
	var floor_y := 152.0
	_r(0, 0, w, h, Gfx.TEAL1)
	for i in 7:
		_r(0, 26.0 + 18.0 * float(i), w, 1, Gfx.TEAL2)
		_r(0, 26.0 + 18.0 * float(i), 6, 1, Gfx.TEAL4)
	_r(0, floor_y, w, h - floor_y, Gfx.INK1)
	_r(0, floor_y, w, 1, Gfx.TEAL3)
	var cycle := 4.2
	var sweep := 3.2
	var since := maxf(0.0, t - 0.6)
	var phase := fmod(since, cycle)
	var scanning := t > 0.6 and phase < sweep
	var scan_x := floorf(-20.0 + phase / sweep * (w + 40.0))
	var gap := 70.0
	var first := floorf(w / 2.0 - gap * float(_lineup.size() - 1) / 2.0)
	for i in _lineup.size():
		var tex := Gfx.tex(str(_lineup[i]))
		if tex == null:
			continue
		var cx := first + gap * float(i)
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var pos := Vector2(floorf(cx - tw / 2.0), floor_y - th)
		_art.draw_texture(tex, pos)
		Gfx.text_center(_art, cx, floor_y + 6.0, str(i + 1), Gfx.TEAL5)
		if scanning and absf(scan_x - cx) < 24.0:
			# under the scan every shadow breaks up the same way
			_cue_once("scan%d_%d" % [int(since / cycle), i], "blip_glitch")
			var beat := int(t * 14.0)
			for cut in 4:
				var sy := floorf(_rnd(beat * 7 + cut * 3 + i) * (th - 8.0))
				var sh := 2.0 + floorf(_rnd(beat * 11 + cut) * 4.0)
				var dx := floorf((_rnd(beat * 5 + cut * 13) - 0.5) * 16.0)
				_r(pos.x, pos.y + sy, tw, sh, Gfx.TEAL1)
				_art.draw_texture_rect_region(tex, Rect2(pos.x + dx, pos.y + sy, tw, sh), Rect2(0, sy, tw, sh))
				_r(pos.x + dx + 4.0, pos.y + sy, tw - 8.0, 1, Color(Gfx.RED2, 0.7))
	if scanning:
		_r(scan_x - 9.0, 0, 9, floor_y, Color(Gfx.CYAN1, 0.22))
		_r(scan_x, 0, 2, floor_y, Gfx.CYAN2)
		_r(scan_x - 10.0, floor_y, 22, 1, Gfx.CYAN3)
	Gfx.text(_art, Vector2(8, 7), str(labels.get("list", "")), Gfx.TEAL6, true)
	if t > 1.2 and fmod(t, 1.0) < 0.7:
		Gfx.text_right(_art, w - 8.0, 7, str(labels.get("ask", "")), Gfx.WARM6, true)


## What the doctor has to hand: the stamp, the call, the shutter.
func _art_counter(t: float, labels: Dictionary) -> void:
	var w := ART.size.x
	var h := ART.size.y
	_r(0, 0, w, h, Gfx.INK1)
	_r(0, 134, w, h - 134.0, Gfx.TEAL1)
	_r(0, 134, w, 1, Gfx.TEAL3)
	var pulled := t >= 3.5
	var slots := [
		{"at": 0.4, "x": 66.0, "icon": "ui/stamp_treat.png", "label": "treat", "color": Gfx.GRN4, "sound": "stamp"},
		{"at": 1.3, "x": 180.0, "icon": "ui/call_team.png", "label": "team", "color": Gfx.AMBER, "sound": "radio"},
		{"at": 2.2, "x": 294.0, "icon": "ui/lever_down.png" if pulled else "ui/lever_up.png", "label": "shutter",
			"color": Gfx.RED3, "sound": "lever"},
	]
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var at := float(slot["at"])
		if t < at:
			continue
		_cue_once("slot%d" % i, str(slot["sound"]))
		var cx := float(slot["x"])
		var color: Color = slot["color"]
		var fresh := t < at + 0.35
		var jolt := 0.0
		if i == 2 and pulled and t < 3.5 + 0.25:
			jolt = 2.0 if int(t * 40.0) % 2 == 0 else -2.0
		var plate := Rect2(cx - 50.0 + jolt, 12.0 - (3.0 if fresh else 0.0), 100, 116)
		_r(plate.position.x + 3.0, plate.position.y + 3.0, plate.size.x, plate.size.y, Color(0, 0, 0, 0.45))
		_r(plate.position.x, plate.position.y, plate.size.x, plate.size.y, Gfx.TEAL2)
		Gfx.outline(_art, plate, color if fresh else Gfx.TEAL4)
		var icon := Gfx.tex(str(slot["icon"]))
		if icon != null:
			var size := Vector2(icon.get_width(), icon.get_height()) * 2.0
			_art.draw_texture_rect(icon, Rect2(Vector2(floorf(plate.position.x + 50.0 - size.x / 2.0), plate.position.y + 8.0), size), false)
		var key := str(slot["label"])
		Gfx.text_center(_art, plate.position.x + 50.0, plate.position.y + 90.0, str(labels.get(key, "")), color, true)
		Gfx.text_center(_art, plate.position.x + 50.0, plate.position.y + 101.0, str(labels.get(key + "_sub", "")), Gfx.TEAL6)
	if pulled:
		_cue_once("slam", "shutter_slam")
