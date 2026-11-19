extends Node2D
## The opening: a few cards that say who the doctor is, what they owe and what the job is,
## shown once a session after the title. Each card is a small moving picture drawn here in
## code, a title and a few typed lines. The words and the labels inside the pictures come from
## data/intro.json. Any click or ENTER moves on; ESC or the right button skips the rest
## (main.gd owns the input and plays the sounds this node asks for).

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")

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
const ARTS := ["fired", "debt", "lanterns", "line", "drift", "counter"]   # what _draw_art() can draw
# The sizes below are the room the words inside the pictures have; tools/art/measure_text.py reads them.
const PANEL_X := [3.0, 123.0, 243.0]   # the fired card is a strip of three panels
const PANEL_Y := 3.0
const PANEL_W := 114.0
const PANEL_H := 166.0
const TOP_FLOOR := 88        # the floor the lift starts from; the first panel's caption names it too
const TAB_W := 31.0          # a tab on the edge of the spec binder
const FILE_W := 150.0        # Kessler's debt file
const FILE_REST := 14.0      # where the file is pushed to when the lease comes in
const LEASE_X := 140.0       # where Harrow's lease comes to rest over the file's right side
const LEASE_W := 212.0
const CRATE_SIDE := 172.0    # the drift card: the crate on the left of this, the clinic glass on the right
const TAG_X := 290.0         # the lanterns card: the middle of the tag under the visitor across the counter
const PACKAGE_X := 228.0     # and where the package (32 px wide) comes to rest on the counter
const LUNGE := 1.25          # the drift card: how much bigger the visitor looms at the glass
const FIST_R := Vector2(27, -80)   # the middle of their right fist, from their feet; the crack is where it lands

var skipped: bool = false    # the player skipped the rest
var index: int = 0           # the card on screen

var _cards: Array = []
var _numbers: Dictionary = {}
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
## for. No picture shows anybody from the cast: the shadows in them are made up.
func setup(cards: Array, numbers: Dictionary) -> void:
	_numbers = numbers
	_cards = []
	for c in cards:
		if c is Dictionary:
			_cards.append(c)


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
	# fill() puts the numbers into the player's language; wrap_raw() leaves the result as it is
	return Gfx.wrap_raw(Gfx.fill(str(card.get("text", "")), _numbers), TEXT_W)


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
			_typed = minf(float(_total), _typed + delta * CPS / Lang.per_char())
			var due := int(_typed * Lang.per_char() / 2.0)        # one blip for every two letters
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
		Gfx.text_raw(self, Vector2(TEXT_X, y), line.substr(0, left), Gfx.TEAL7)      # lines_of() translated it
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
		"fired":
			_art_fired(_card_t, labels)
		"debt":
			_art_debt(_card_t, labels)
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


## A small boxed word centred on cx, like a label tied on.
func _tag(cx: float, y: float, word: String, ink: Color, frame: Color) -> void:
	var box := Rect2(floorf(cx - (Gfx.text_w(word) + 6.0) / 2.0), y, Gfx.text_w(word) + 6.0, 11)
	_r(box.position.x, box.position.y, box.size.x, box.size.y, Gfx.INK1)
	Gfx.outline(_art, box, frame)
	Gfx.text(_art, Vector2(box.position.x + 3.0, y + 1.0), word, ink)


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var y := -ry
	while y < ry:
		var half := floorf(rx * sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry))))
		_r(c.x - half, c.y + y, half * 2.0, 2.0, color)
		y += 2.0


## Fired, as a strip of three panels: the badge reader on floor 88 that says no, the ride all the
## way down between two guards, and outside in the rain with the one thing the doctor kept,
## Kessler's spec binder (its pages are the reference sheets on the clinic wall).
func _art_fired(t: float, labels: Dictionary) -> void:
	_r(0, 0, ART.size.x, ART.size.y, Gfx.INK0)
	var opens := [0.0, 1.9, 3.7]
	for i in 3:
		var lt := t - float(opens[i])
		if lt < 0.0:
			continue
		var x0: float = PANEL_X[i]
		_art.draw_set_transform(Vector2(x0, PANEL_Y))
		match i:
			0:
				_fired_badge(lt, labels)
			1:
				_fired_lift(lt)
			_:
				_fired_out(lt, labels)
		var veil := 1.0 - clampf(lt / 0.2, 0.0, 1.0)     # each panel comes up out of the black
		if veil > 0.0:
			_r(0, 0, PANEL_W, PANEL_H, Color(Gfx.INK0, veil))
		_art.draw_set_transform(Vector2.ZERO)
		Gfx.outline(_art, Rect2(x0 - 1.0, PANEL_Y - 1.0, PANEL_W + 2.0, PANEL_H + 2.0), Gfx.TEAL3)


## Panel one: Kessler's door on floor 88, and the reader the doctor's badge no longer opens.
## The hand that holds the badge is metal: the doctor's own hands are implants, on a loan.
func _fired_badge(t: float, labels: Dictionary) -> void:
	var w := PANEL_W
	var h := PANEL_H
	var floor_y := 136.0
	var tap_at := 0.75
	var denied := t >= tap_at
	_r(0, 0, w, floor_y, Gfx.TEAL2)
	for x in [28.0, 57.0, 86.0]:
		_r(x, 0, 1, floor_y, Gfx.TEAL3)
	_r(0, floor_y, w, h - floor_y, Gfx.INK1)
	_r(0, floor_y, w, 1, Gfx.TEAL3)
	# the door, shut, with the company's name on it
	_r(6, 22, 46, floor_y - 22.0, Gfx.TEAL1)
	Gfx.outline(_art, Rect2(6, 22, 46, floor_y - 22.0), Gfx.TEAL4)
	_r(29, 23, 1, floor_y - 23.0, Gfx.INK0)
	_r(7, 23, 1, floor_y - 23.0, Gfx.TEAL3)
	_r(30, 23, 1, floor_y - 23.0, Gfx.TEAL3)
	_r(9, 30, 40, 11, Gfx.INK1)
	Gfx.text_center(_art, 29, 31, str(labels.get("company", "")), Gfx.CYAN2)
	# where this is, in a caption box
	var floor_word := str(labels.get("floor", ""))
	_r(3, 3, Gfx.text_w(floor_word) + 8.0, 12, Gfx.INK0)
	Gfx.outline(_art, Rect2(3, 3, Gfx.text_w(floor_word) + 8.0, 12), Gfx.TEAL4)
	Gfx.text(_art, Vector2(7, 4), floor_word, Gfx.TEAL6)
	# the reader
	var rx := 60.0
	var ry := 46.0
	_r(rx + 2.0, ry + 2.0, 48, 54, Color(0, 0, 0, 0.4))
	_r(rx, ry, 48, 54, Gfx.INK1)
	Gfx.outline(_art, Rect2(rx, ry, 48, 54), Gfx.TEAL4)
	var screen := Rect2(rx + 4.0, ry + 4.0, 40, 13)
	_r(screen.position.x, screen.position.y, screen.size.x, screen.size.y, Gfx.RED1 if denied else Gfx.TEAL1)
	Gfx.outline(_art, screen, Gfx.RED2 if denied else Gfx.CYAN1)
	if denied:
		_cue_once("denied", "beep_low")
		if t > tap_at + 1.5 or fmod(t - tap_at, 0.5) < 0.32:
			Gfx.text_center(_art, screen.get_center().x, screen.position.y + 2.0, str(labels.get("denied", "")), Gfx.RED3)
	elif fmod(t, 0.6) < 0.35:
		_r(screen.position.x + 4.0, screen.position.y + 4.0, 4, 6, Gfx.CYAN2)      # waiting for a badge
	_r(rx + 22.0, ry + 20.0, 4, 2, Gfx.RED2 if denied else Gfx.TEAL4)
	var pad := Rect2(rx + 10.0, ry + 26.0, 28, 22)
	Gfx.outline(_art, pad, Gfx.TEAL4)
	for radius in [3.0, 6.0, 9.0]:
		_art.draw_arc(pad.get_center() + Vector2(-4, 0), radius, -0.7, 0.7, 8, Gfx.TEAL5, -1.0)
	# the badge comes up to the pad, is refused, and drops away
	var k := clampf((t - 0.3) / 0.4, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	var drop := clampf((t - 1.6) / 0.4, 0.0, 1.0)
	var bx := floorf(lerpf(92.0, 70.0, k) + 4.0 * drop)
	var by := floorf(lerpf(176.0, 76.0, k) + 34.0 * drop * drop)
	_r(bx + 18.0, by + 14.0, 16, h - by - 14.0, Gfx.PAPER1)       # the sleeve of a white coat
	_r(bx + 18.0, by + 14.0, 2, h - by - 14.0, Gfx.PAPER2)
	_r(bx + 18.0, by + 14.0, 16, 2, Gfx.INKS)
	_r(bx, by, 24, 16, Gfx.PAPER3)
	_r(bx, by, 24, 3, Gfx.CYAN1)
	_r(bx + 3.0, by + 5.0, 6, 7, Gfx.TEAL4)
	_r(bx + 11.0, by + 6.0, 10, 1, Gfx.INKS)
	_r(bx + 11.0, by + 9.0, 7, 1, Gfx.INKS)
	if denied and t < tap_at + 0.35:
		_r(bx, by, 24, 16, Color(Gfx.RED2, 0.35))
	for f in 4:
		_r(bx + 17.0, by + 3.0 + 3.0 * float(f), 8, 2, Gfx.TEAL5)
		_r(bx + 17.0, by + 3.0 + 3.0 * float(f), 8, 1, Gfx.TEAL6)
	_r(bx + 14.0, by + 11.0, 5, 4, Gfx.TEAL5)


## Panel two: the lift, a guard at each of the doctor's shoulders, the floors running out.
func _fired_lift(t: float) -> void:
	var w := PANEL_W
	var h := PANEL_H
	var floor_y := 142.0
	var ride := clampf((t - 0.25) / 1.3, 0.0, 1.0)
	var level := int(roundf(lerpf(float(TOP_FLOOR), 1.0, ride * ride * (3.0 - 2.0 * ride))))
	var down := ride >= 1.0
	_r(0, 0, w, h, Gfx.INK1)
	_r(8, 16, w - 16.0, floor_y - 16.0, Gfx.TEAL2)
	var x := 11.0
	while x < w - 10.0:
		_r(x, 18, 1, floor_y - 20.0, Gfx.TEAL3 if int(x) % 3 == 0 else Color(Gfx.TEAL3, 0.45))
		x += 5.0
	_r(0, 16, 8, floor_y - 16.0, Gfx.TEAL1)
	_r(w - 8.0, 16, 8, floor_y - 16.0, Gfx.TEAL1)
	_r(8, 16, 1, floor_y - 16.0, Gfx.TEAL3)
	_r(w - 9.0, 16, 1, floor_y - 16.0, Gfx.TEAL3)
	var flicker := not down and int(t * 11.0) % 17 == 3
	_r(8, 14, w - 16.0, 2, Gfx.TEAL4 if flicker else Gfx.TEAL6)
	_r(0, floor_y, w, h - floor_y, Gfx.INK1)
	_r(0, floor_y, w, 1, Gfx.TEAL3)
	# the floor counter
	var box := Rect2(39, 1, 36, 12)
	_r(box.position.x, box.position.y, box.size.x, box.size.y, Gfx.INK0)
	Gfx.outline(_art, box, Gfx.RED1)
	Gfx.text_center(_art, 55, 2, str(level), Gfx.RED3, true)
	if not down and fmod(t, 0.4) < 0.25:
		_r(66, 5, 5, 1, Gfx.RED2)
		_r(67, 6, 3, 1, Gfx.RED2)
		_r(68, 7, 1, 1, Gfx.RED2)
	if down:
		_cue_once("ding", "beep")
		_r(0, floor_y + 1.0, w, h - floor_y - 1.0, Color(Gfx.WARM3, 0.45))    # the doors open on the lobby
	var shake := 1.0 if (not down and ride > 0.0 and int(t * 18.0) % 5 == 0) else 0.0
	_guard(26.0, 44.0 + shake, floor_y)
	_guard(88.0, 44.0 + shake, floor_y)
	_doctor(57.0, 60.0 + shake, floor_y)
	# a guard's hand on each shoulder
	for i in 3:
		_r(40.0 + 3.0 * float(i), 64.0 + shake + 3.5 * float(i), 5, 4, Gfx.INK0)
		_r(69.0 - 3.0 * float(i), 64.0 + shake + 3.5 * float(i), 5, 4, Gfx.INK0)


## A Kessler guard, front on: a helmet with a red visor, broad shoulders, all in black.
func _guard(cx: float, top: float, floor_y: float) -> void:
	var c := Gfx.INK0
	_r(cx - 7.0, top, 14, 14, c)
	_r(cx - 6.0, top, 12, 1, Gfx.TEAL4)          # the ceiling light on the helmet
	_r(cx - 6.0, top + 6.0, 12, 2, Gfx.RED2)     # the visor
	_r(cx - 4.0, top + 6.0, 2, 1, Gfx.RED3)
	_r(cx - 4.0, top + 14.0, 8, 2, c)
	_r(cx - 16.0, top + 16.0, 32, 6, c)
	_r(cx - 15.0, top + 16.0, 30, 1, Gfx.TEAL4)
	var y := top + 22.0
	while y < top + 62.0:
		var half := 16.0 - floorf((y - top - 22.0) / 14.0)
		_r(cx - half, y, half * 2.0, 2, c)
		y += 2.0
	_r(cx - 13.0, top + 60.0, 26, 2, Gfx.TEAL3)   # the belt
	_r(cx - 12.0, top + 62.0, 10, floor_y - top - 62.0, c)
	_r(cx + 2.0, top + 62.0, 10, floor_y - top - 62.0, c)
	_r(cx - 12.0, top + 19.0, 3, 3, Gfx.CYAN1)    # the company's patch


## The doctor, front on and looking at the floor: a white coat, the binder held to the chest.
func _doctor(cx: float, top: float, floor_y: float) -> void:
	_r(cx - 5.0, top, 10, 7, Gfx.TEAL1)          # the head is down: mostly hair
	_r(cx - 4.0, top, 8, 1, Gfx.TEAL3)
	_r(cx - 4.0, top + 7.0, 8, 5, Gfx.PAPER1)
	_r(cx - 3.0, top + 12.0, 6, 2, Gfx.PAPER1)
	_r(cx - 11.0, top + 14.0, 22, 4, Gfx.PAPER2)
	_r(cx - 12.0, top + 18.0, 24, 46, Gfx.PAPER2)
	_r(cx + 8.0, top + 18.0, 4, 46, Gfx.PAPER1)
	_r(cx - 3.0, top + 14.0, 6, 8, Gfx.TEAL1)    # the shirt in the coat's V
	_r(cx - 2.0, top + 22.0, 4, 2, Gfx.TEAL1)
	_r(cx, top + 24.0, 1, 40, Gfx.INKS)
	_r(cx - 7.0, top + 24.0, 13, 18, Gfx.TEAL3)  # the binder
	Gfx.outline(_art, Rect2(cx - 7.0, top + 24.0, 13, 18), Gfx.TEAL5)
	var tabs := [Gfx.CYAN2, Gfx.WARM5, Gfx.GRN3, Gfx.MAG2]
	for i in tabs.size():
		_r(cx + 6.0, top + 26.0 + 4.0 * float(i), 2, 3, tabs[i])
	_r(cx - 12.0, top + 36.0, 24, 4, Gfx.PAPER1)  # the arms round it
	_r(cx - 8.0, top + 35.0, 4, 3, Gfx.TEAL5)     # and the metal hands
	_r(cx + 4.0, top + 35.0, 4, 3, Gfx.TEAL5)
	_r(cx - 8.0, top + 64.0, 7, floor_y - top - 64.0, Gfx.TEAL1)
	_r(cx + 1.0, top + 64.0, 7, floor_y - top - 64.0, Gfx.TEAL1)


## Panel three: out in the rain. The lobby's light is on the binder until the door slams; then
## only the street's neon, and the rain beading on the cover. A tab for each part.
func _fired_out(t: float, labels: Dictionary) -> void:
	var w := PANEL_W
	var h := PANEL_H
	var slam_at := 0.5
	var lit := t < slam_at
	_r(0, 0, w, h, Gfx.INK1)
	_r(6, 8, 18, 10, Color(Gfx.MAG2, 0.2))       # the street behind, out of focus
	_r(64, 3, 28, 8, Color(Gfx.CYAN1, 0.25))
	_r(94, 18, 14, 14, Color(Gfx.WARM3, 0.35))
	_r(36, 1, 10, 6, Color(Gfx.RED1, 0.35))
	if lit:
		_r(0, 0, 6, h, Color(Gfx.CYAN2, 0.5))      # the lobby door, not shut yet
	else:
		_cue_once("slam", "door_slam")
	# the coat, and the dark shirt in its V
	var coat := Gfx.PAPER2 if lit else Gfx.PAPER1
	var shade := Gfx.PAPER1 if lit else Gfx.PAPER1.darkened(0.3)
	var y := 24.0
	while y < h:
		var k := clampf((y - 24.0) / 16.0, 0.0, 1.0)
		var left := floorf(lerpf(34.0, 2.0, k))
		var right := floorf(lerpf(80.0, 112.0, k))
		_r(left, y, right - left, 2, coat)
		_r(right - 6.0, y, 6, 2, shade)
		y += 2.0
	y = 24.0
	while y < 52.0:
		var half := floorf((52.0 - y) * 0.55)
		_r(57.0 - half, y, half * 2.0, 2, Gfx.TEAL1)
		_r(56.0 - half, y, 1, 2, Gfx.INKS)
		_r(57.0 + half, y, 1, 2, Gfx.INKS)
		y += 2.0
	if lit:
		_r(2, 40, 2, h - 40.0, Color(Gfx.CYAN2, 0.5))
	else:
		_r(110, 40, 2, h - 40.0, Color(Gfx.RED1, 0.6))   # the neon down the other side
	# the binder
	var bx := 10.0
	var by := 50.0
	var bw := 70.0
	var bh := 100.0
	_r(bx + 3.0, by + 3.0, bw, bh, Color(0, 0, 0, 0.4))
	_r(bx, by, bw, bh, Gfx.TEAL4 if lit else Gfx.TEAL3)
	_r(bx, by, 5, bh, Gfx.TEAL2)                  # the spine
	for ring in 3:
		_r(bx + 1.0, by + 12.0 + 36.0 * float(ring), 3, 5, Gfx.TEAL6)
	Gfx.outline(_art, Rect2(bx, by, bw, bh), Gfx.CYAN1 if lit else Gfx.TEAL5)
	var plate := Rect2(bx + 8.0, by + 10.0, 58, 26)
	_r(plate.position.x, plate.position.y, plate.size.x, plate.size.y, Gfx.PAPER3 if lit else Gfx.PAPER2)
	Gfx.outline(_art, plate, Gfx.INKS)
	Gfx.text_center(_art, plate.get_center().x, plate.position.y + 3.0, str(labels.get("company", "")), Gfx.INKT, true)
	Gfx.text_center(_art, plate.get_center().x, plate.position.y + 14.0, str(labels.get("binder", "")), Gfx.PRINT)
	var mark := Gfx.CYAN1 if lit else Gfx.TEAL5
	Gfx.outline(_art, Rect2(bx + 33.0, by + 44.0, 9, 9), mark)
	_r(bx + 36.0, by + 47.0, 3, 3, mark)
	var tabs: Array = labels.get("tabs", [])
	var colors := [Gfx.CYAN2, Gfx.WARM5, Gfx.GRN3, Gfx.MAG2]
	for i in mini(tabs.size(), colors.size()):
		var ty := by + 8.0 + 14.0 * float(i)
		var tab: Color = colors[i] if lit else (colors[i] as Color).darkened(0.25)
		_r(bx + bw, ty, TAB_W, 12, tab)
		_r(bx + bw, ty + 11.0, TAB_W, 1, Color(0, 0, 0, 0.35))
		Gfx.text(_art, Vector2(bx + bw + 3.0, ty + 2.0), str(tabs[i]), Gfx.INK0)
	# held in metal hands
	var metal := Gfx.TEAL5 if lit else Gfx.TEAL4
	for f in 4:
		_r(bx - 4.0, by + 56.0 + 4.0 * float(f), 10, 3, metal)
		_r(bx - 4.0, by + 56.0 + 4.0 * float(f), 10, 1, Gfx.TEAL6)
		_r(bx + 20.0 + 8.0 * float(f), by + bh - 3.0, 6, 6, metal)
	if not lit:
		for i in mini(16, int((t - slam_at) * 8.0)):
			var dx := bx + 8.0 + floorf(_rnd(i * 5 + 300) * (bw - 14.0))
			var dy := by + 40.0 + floorf(_rnd(i * 5 + 301) * (bh - 46.0))
			_r(dx, dy, 1, 2, Color(Gfx.CYAN3, 0.55))
	for i in 26:
		var rx := floorf(_rnd(i * 13 + 400) * (w - 1.0))
		var speed := 160.0 + _rnd(i * 13 + 401) * 80.0
		var ry := fmod(_rnd(i * 13 + 402) * 200.0 + t * speed, h + 20.0) - 10.0
		_r(rx, ry, 1, 4, Color(Gfx.TEAL5, 0.5))


## The debt: Kessler's file on the doctor is stamped SOLD and pushed aside, and the lease that
## came with it slides in: what Harrow Credit owns now, typed out, ticked off and stamped.
func _art_debt(t: float, labels: Dictionary) -> void:
	var w := ART.size.x
	var h := ART.size.y
	_r(0, 0, w, h, Gfx.INK1)
	_ellipse(Vector2(180, 96), 196.0, 112.0, Gfx.TEAL1)      # the lamp's pool of light
	_ellipse(Vector2(180, 96), 152.0, 86.0, Gfx.TEAL2)
	var swap_at := 2.1
	var swap := clampf((t - swap_at) / 0.45, 0.0, 1.0)
	swap = 1.0 - (1.0 - swap) * (1.0 - swap)
	_debt_file(floorf(lerpf((w - FILE_W) / 2.0, FILE_REST, swap)), 12.0, t, labels)
	if t >= swap_at:
		_cue_once("swap", "paper")
		_lease_paper(floorf(lerpf(w + 20.0, LEASE_X, swap)), 8.0, t - swap_at, labels)


## Kessler's file on the doctor: what they owed, in the company's colours, and the stamp that
## sold it on. Once the lease is over it, only its left side shows: everything that matters is there.
func _debt_file(px: float, py: float, t: float, labels: Dictionary) -> void:
	var pw := FILE_W
	var h := ART.size.y
	_r(px + 3.0, py + 3.0, pw, h, Color(0, 0, 0, 0.5))
	_r(px, py, pw, h, Gfx.PAPER2)
	Gfx.outline(_art, Rect2(px, py, pw, h + 4.0), Gfx.PAPER1)
	_r(px, py, pw, 15, Gfx.CYAN1)
	Gfx.text(_art, Vector2(px + 8.0, py + 3.0), str(labels.get("file_head", "")), Gfx.PAPER3, true)
	Gfx.outline(_art, Rect2(px + pw - 16.0, py + 3.0, 9, 9), Gfx.PAPER3)
	_r(px + pw - 13.0, py + 6.0, 3, 3, Gfx.PAPER3)
	Gfx.text(_art, Vector2(px + 8.0, py + 20.0), str(labels.get("file_sub", "")), Gfx.PRINT)
	_r(px + 8.0, py + 32.0, pw - 16.0, 1, Gfx.INKS)
	var items: Array = labels.get("file_items", [])
	for i in items.size():
		var at := 0.4 + 0.35 * float(i)
		if t < at:
			break
		var said := Lang.t(str(items[i]))
		Gfx.text_raw(_art, Vector2(px + 8.0, py + 38.0 + 13.0 * float(i)), said.substr(0, int((t - at) * 60.0 / Lang.per_char())), Gfx.INKT)
	for i in 4:
		_r(px + 8.0, py + 124.0 + float(i) * 6.0, 70.0 + floorf(_rnd(i + 80) * 40.0), 1, Gfx.PAPER1)
	var sold_at := 1.5
	if t >= sold_at:
		_cue_once("sold", "stamp")
		var word := str(labels.get("sold", ""))
		var land := clampf((t - sold_at) / 0.12, 0.0, 1.0)
		var box := Rect2(px + 10.0, py + 84.0, Gfx.text_w(word, true) + 16.0, 22).grow(floorf((1.0 - land) * 4.0))
		var ink := Gfx.STAMP_R if land >= 1.0 else Gfx.RED3
		Gfx.outline(_art, box, ink)
		Gfx.outline(_art, box.grow(-1.0), ink)
		Gfx.text_center(_art, box.get_center().x, box.get_center().y - 5.0, word, ink, true)


## Harrow's lease: what the lender owns now, typed out, ticked off, signed and stamped.
func _lease_paper(px: float, py: float, t: float, labels: Dictionary) -> void:
	var pw := LEASE_W
	var h := ART.size.y
	_r(px + 4.0, py + 4.0, pw, h, Color(0, 0, 0, 0.5))
	_r(px, py, pw, h, Gfx.PAPER3)
	Gfx.outline(_art, Rect2(px, py, pw, h + 4.0), Gfx.PAPER1)
	var x := px + 12.0
	Gfx.text(_art, Vector2(x, py + 9.0), str(labels.get("head", "")), Gfx.INKT, true)
	Gfx.text(_art, Vector2(x, py + 20.0), str(labels.get("sub", "")), Gfx.PRINT)
	Gfx.text(_art, Vector2(x, py + 31.0), str(labels.get("from", "")), Gfx.PRINT)
	_r(px + pw - 30.0, py + 9.0, 18, 18, Gfx.INKT)           # the lender's mark
	_r(px + pw - 27.0, py + 12.0, 12, 12, Gfx.PAPER3)
	_r(px + pw - 24.0, py + 15.0, 6, 6, Gfx.INKT)
	_r(x, py + 44.0, pw - 24.0, 1, Gfx.INKS)
	var stamp_at := 2.6
	var items: Array = labels.get("items", [])
	for i in items.size():
		var at := 0.5 + 0.5 * float(i)
		if t < at:
			break
		var y := py + 52.0 + 16.0 * float(i)
		var said := Lang.t(str(items[i]))
		Gfx.outline(_art, Rect2(x, y, 9, 9), Gfx.INKS)
		Gfx.text_raw(_art, Vector2(x + 15.0, y), said.substr(0, int((t - at) * 60.0 / Lang.per_char())), Gfx.INKT)
		if t >= at + 0.4:
			var tick := Gfx.tex("ui/mark_tick.png")
			if tick != null:
				_art.draw_texture(tick, Vector2(x - 1.0, y - 1.0))
		if i == items.size() - 1 and t >= stamp_at:
			_r(x + 15.0, y + 10.0, Gfx.text_w_raw(said), 1, Gfx.STAMP_R)      # the item that matters
	# a signature
	if t >= 1.9:
		var scrawl := [Vector2(0, 7), Vector2(4, 1), Vector2(8, 8), Vector2(12, 3), Vector2(16, 9), Vector2(22, 2),
			Vector2(27, 8), Vector2(34, 4), Vector2(40, 7), Vector2(52, 5), Vector2(62, 6)]
		var shown := mini(scrawl.size(), 1 + int((t - 1.9) * 26.0))
		var points := PackedVector2Array()
		for i in shown:
			points.append(Vector2(x + 6.5, py + 111.5) + scrawl[i])
		if points.size() >= 2:
			_art.draw_polyline(points, Gfx.PENCIL, -1.0)
	_r(x, py + 123.0, 96, 1, Gfx.INKS)
	Gfx.text(_art, Vector2(x, py + 130.0), str(labels.get("foot", "")), Gfx.PRINT)
	for i in 3:
		_r(x, py + 146.0 + float(i) * 6.0, 120.0 + floorf(_rnd(i + 40) * 60.0), 1, Gfx.PAPER1)
	# the stamp
	if t >= stamp_at:
		_cue_once("stamp", "stamp")
		var word := str(labels.get("stamp", ""))
		var land := clampf((t - stamp_at) / 0.12, 0.0, 1.0)
		var grow := floorf((1.0 - land) * 4.0)
		var box := Rect2(px + 124.0, py + 98.0, 74, 22).grow(grow)
		var ink := Gfx.STAMP_R if land >= 1.0 else Gfx.RED3
		Gfx.outline(_art, box, ink)
		Gfx.outline(_art, box.grow(-1.0), ink)
		Gfx.text_center(_art, box.position.x + box.size.x / 2.0, box.position.y + box.size.y / 2.0 - 5.0, word, ink, true)


## Tonight's list on the clinic wall, under the Lanterns' red lamp: the code is said to the right
## visitor, and a package comes over the counter. Both entries are made up; their clues fit none
## of the game's visitors (data/intro.json says so in its note). A tag under the visitor says
## what they are: a patient, until the code shows a contact.
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
	# what the visitor across the counter is: a patient, until the code says otherwise
	var known := t >= said_at + 0.3
	_tag(TAG_X, counter_y + 6.0, str(labels.get("contact" if known else "patient", "")),
		Gfx.RED3 if known else Gfx.TEAL6, Gfx.RED1 if known else Gfx.TEAL4)
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
		# an alias is a name: the same in every language
		Gfx.text_raw(_art, Vector2(tx, ey), str(e.get("alias", "")).substr(0, int((t - at) * 40.0)), Gfx.INKT, true)
		var clues: Array = e.get("clues", [])
		for k in clues.size():
			if t >= at + 0.2 + 0.12 * float(k):
				Gfx.text_raw(_art, Vector2(tx, ey + 11.0 + 10.0 * float(k)), "• " + Lang.t(str(clues[k])), Gfx.INKT)
		if t >= at + 0.45:
			Gfx.text_raw(_art, Vector2(tx, ey + 32.0), Lang.tf("\"%s\"", [Lang.t(str(e.get("code", "")))]), Gfx.INKS)
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
		var bx := floorf(lerpf(PACKAGE_X + 40.0, PACKAGE_X, slide))
		var by := counter_y - 14.0
		_r(bx + 2.0, by + 2.0, 32, 13, Color(0, 0, 0, 0.45))
		_r(bx, by, 32, 14, Gfx.TEAL3)
		_r(bx, by, 32, 1, Gfx.TEAL5)
		_r(bx, by + 13.0, 32, 1, Gfx.INK0)
		_r(bx + 13.0, by, 6, 14, Gfx.WARM5)       # tape
		_r(bx + 3.0, by + 4.0, 5, 5, Gfx.RED2)     # the Lanterns' seal
		if slide >= 1.0:
			_cue_once("drop", "cash")
			_tag(bx + 16.0, counter_y + 6.0, str(labels.get("package", "")), Gfx.WARM6, Gfx.WARM3)
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
	Gfx.text_raw(_art, Vector2(ox + 6.0, 6), "%s %d   %s %d" % [Lang.t(str(labels.get("hour", ""))), now,
		Lang.t(str(labels.get("line", ""))), now * per_hour], Gfx.TEAL6)
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


## The drift. On the left, where street implants come from: a crate of army surplus with the
## serials filed off and a soldier's tag still on its chain. On the right, behind the clinic
## glass: one who wears them goes wrong and hits the pane; the light goes; the next one only
## stands there. Both are made-up shadows, nobody from the cast.
func _art_drift(t: float, labels: Dictionary) -> void:
	var glitch := t >= 2.3 and t < 2.9 and int(t * 16.0) % 3 != 0     # the implant eyes go red
	if t >= 2.3:
		_cue_once("glitch", "blip_glitch")
	_drift_crate(t, labels, glitch)
	_drift_glass(t, labels, glitch)


func _drift_crate(t: float, labels: Dictionary, glitch: bool) -> void:
	var w := CRATE_SIDE
	var h := ART.size.y
	var floor_y := 160.0
	var lit := t >= 0.3 and not (t < 0.5 and int(t * 30.0) % 2 == 0)
	if t >= 0.3:
		_cue_once("bulb", "light_on")
	_r(0, 0, w, h, Gfx.TEAL1)
	if lit:
		_ellipse(Vector2(86, 96), 84.0, 72.0, Color(Gfx.WARM3, 0.10))
		_ellipse(Vector2(86, 100), 60.0, 50.0, Color(Gfx.WARM3, 0.12))
	_r(0, floor_y, w, h - floor_y, Gfx.INK1)
	_r(0, floor_y, w, 1, Gfx.TEAL2)
	_r(86, 0, 1, 13, Gfx.TEAL3)                   # a bare bulb
	_r(84, 12, 5, 3, Gfx.TEAL3)
	_ellipse(Vector2(86, 19), 4.0, 5.0, Gfx.WARM6 if lit else Gfx.WARM3)
	# the lid, leant on the wall behind
	_r(22, 50, 128, 52, Gfx.TEAL2)
	Gfx.outline(_art, Rect2(22, 50, 128, 52), Gfx.TEAL3)
	for ly in [63.0, 76.0, 89.0]:
		_r(23, ly, 126, 1, Gfx.TEAL3)
	# what it holds, each with a tag whose number has been scratched out
	_crate_hand(30.0, 68.0)
	_crate_tag(52.0, 74.0)
	var eye := Vector2(80, 92)
	_ellipse(eye, 9.0, 9.0, Gfx.TEAL4)
	_ellipse(eye + Vector2(-1, -1), 7.0, 7.0, Gfx.TEAL5)
	_ellipse(eye, 5.0, 5.0, Gfx.RED1 if glitch else Gfx.CYAN1)
	_r(eye.x - 1.0, eye.y - 1.0, 2, 2, Gfx.INK0)
	_r(eye.x + 2.0, eye.y - 3.0, 1, 1, Gfx.RED3 if glitch else Gfx.CYAN3)
	_crate_tag(91.0, 80.0)
	_r(98, 88, 18, 16, Gfx.TEAL3)                 # a voice box
	Gfx.outline(_art, Rect2(98, 88, 18, 16), Gfx.TEAL5)
	for g in 4:
		_r(101.0 + 3.0 * float(g), 91, 1, 9, Gfx.TEAL6)
	_crate_tag(101.0, 80.0)
	Gfx.outline(_art, Rect2(124, 86, 18, 18), Gfx.TEAL5)      # a port, its cable over the side
	_r(128, 90, 10, 10, Gfx.INK0)
	for p in 4:
		_r(130.0 + 4.0 * float(p % 2), 92.0 + 4.0 * floorf(float(p) / 2.0), 2, 2, Gfx.CYAN1)
	_crate_tag(143.0, 80.0)
	# the crate's front
	_r(16, 100, 138, 5, Gfx.INK1)
	_r(14, 104, 142, 56, Gfx.TEAL3)
	_r(14, 104, 142, 1, Gfx.TEAL4)
	_r(14, 122, 142, 1, Gfx.TEAL2)
	_r(14, 141, 142, 1, Gfx.TEAL2)
	_r(14, 104, 6, 56, Gfx.TEAL4)
	_r(150, 104, 6, 56, Gfx.TEAL4)
	for corner in [Vector2(14, 104), Vector2(152, 104), Vector2(14, 156), Vector2(152, 156)]:
		_r(corner.x, corner.y, 4, 4, Gfx.TEAL5)
	_r(142, 96, 4, 2, Gfx.TEAL4)
	_r(145, 98, 2, 18, Gfx.TEAL4)
	Gfx.text_center(_art, 85, 110, str(labels.get("surplus", "")), Color(Gfx.PAPER1, 0.75), true)
	for s in 5:
		_r(40.0 + floorf(_rnd(s + 90) * 90.0), 111.0 + floorf(_rnd(s + 95) * 7.0), 6, 1, Gfx.TEAL3)   # worn through
	_r(52, 128, 66, 6, Gfx.INK1)                  # the crate's serial, filed off
	for s in 6:
		_r(54.0 + 11.0 * float(s), 130, 7, 1, Color(Gfx.RED1, 0.8))
	# a dog tag on its chain, swinging a little
	var sx := floorf(sin(t * 2.4) * 1.5 + 0.5)
	for link in 5:
		_r(24.0 + floorf(sx * float(link) / 5.0), 106.0 + 3.0 * float(link), 1, 2, Gfx.TEAL5)
	var tx := 20.0 + sx
	_r(tx, 121, 9, 13, Gfx.TEAL6)
	Gfx.outline(_art, Rect2(tx, 121, 9, 13), Gfx.TEAL4)
	_r(tx + 4.0, 122, 1, 1, Gfx.TEAL4)
	for line in 3:
		_r(tx + 2.0, 125.0 + 3.0 * float(line), 5 - line % 2, 1, Gfx.INKS)
	if not lit:
		_r(0, 0, w, h, Color(Gfx.INK0, 0.75))


## A metal hand, fingers up, as it lies in the crate.
func _crate_hand(x: float, y: float) -> void:
	var m := Gfx.TEAL5
	_r(x, y + 16.0, 18, 20, m)
	var tops := [4.0, 0.0, 2.0, 6.0]
	for f in 4:
		var fx := x + 1.0 + floorf(4.5 * float(f))
		var top := y + float(tops[f])
		_r(fx, top, 3, y + 16.0 - top, m)
		_r(fx, top, 1, y + 16.0 - top, Gfx.TEAL6)
		_r(fx, top + 7.0, 3, 1, Gfx.TEAL4)
	_r(x + 18.0, y + 20.0, 5, 8, m)
	_r(x + 3.0, y + 22.0, 12, 1, Gfx.TEAL4)


## A paper tag on a string, its number scratched out.
func _crate_tag(x: float, y: float) -> void:
	_r(x, y, 11, 6, Gfx.PAPER2)
	_r(x + 2.0, y + 2.0, 7, 1, Gfx.RED1)
	_r(x + 3.0, y + 3.0, 5, 1, Gfx.RED1)
	_r(x + 5.0, y + 6.0, 1, 4, Gfx.PAPER1)


## The clinic glass, from the counter's side. The hall light comes on behind a visitor; their
## eye goes red, they lunge, a fist cracks the pane. The light goes. It comes on again behind
## the next one, whose eye is only a steady glint: steady or drifting?
func _drift_glass(t: float, labels: Dictionary, glitch: bool) -> void:
	var pane := Rect2(CRATE_SIDE + 8.0, 6, ART.size.x - CRATE_SIDE - 16.0, 158)
	var cx := floorf(pane.get_center().x)
	_r(CRATE_SIDE, 0, ART.size.x - CRATE_SIDE, ART.size.y, Gfx.INK1)
	_r(pane.position.x, pane.position.y, pane.size.x, pane.size.y, Gfx.INK0)
	var hall := 0.0
	if t >= 1.3 and t < 3.9:
		hall = clampf((t - 1.3) / 0.2, 0.0, 1.0)
	elif t >= 3.9 and t < 4.2:
		hall = 1.0 - (t - 3.9) / 0.3
	elif t >= 4.4:
		hall = clampf((t - 4.4) / 0.25, 0.0, 1.0)
	if t >= 1.3:
		_cue_once("first", "door_chime")
	if t >= 4.4:
		_cue_once("next", "door_chime")
	if hall > 0.0:
		_ellipse(Vector2(cx, 84), 78.0, 66.0, Color(Gfx.TEAL2, hall))
		_ellipse(Vector2(cx, 74), 50.0, 44.0, Color(Gfx.TEAL3, hall * 0.8))
	var foot := Vector2(cx, pane.end.y)
	if t >= 1.3 and t < 4.2:
		var lunge := 0.0
		if t >= 2.9 and t < 3.05:
			lunge = (t - 2.9) / 0.15
		elif t >= 3.05 and t < 3.5:
			lunge = 1.0 - (t - 3.05) / 0.45
		var twitch := 1.0 if glitch and int(t * 20.0) % 2 == 0 else 0.0
		var grow := 1.0 + (LUNGE - 1.0) * lunge
		_art.draw_set_transform(foot + Vector2(twitch, 0), 0.0, Vector2(grow, grow))
		_visitor(false, hall, glitch, lunge > 0.0)
		_art.draw_set_transform(Vector2.ZERO)
	elif t >= 4.4:
		_art.draw_set_transform(foot)
		_visitor(true, hall, false, false)
		_art.draw_set_transform(Vector2.ZERO)
	# the crack stays in the glass whoever stands behind it
	var hit_at := 3.05
	if t >= hit_at:
		_cue_once("hit", "hit")
		_cue_once("crack", "glass_crack")
		var p := (foot + FIST_R * LUNGE).floor()      # where the right fist met the glass
		var crack := Color(Gfx.CYAN3, 0.9) if t < hit_at + 0.08 else Color(Gfx.TEAL6, 0.8)
		if t < hit_at + 0.08:
			_r(pane.position.x, pane.position.y, pane.size.x, pane.size.y, Color(Gfx.CYAN3, 0.18))
		for i in 7:
			var ang := TAU * (float(i) + _rnd(i + 500) * 0.6) / 7.0
			var reach := 14.0 + _rnd(i + 510) * 22.0
			var dir := Vector2(cos(ang), sin(ang))
			var mid := (p + dir * reach * 0.55 + Vector2(_rnd(i + 520) * 4.0 - 2.0, _rnd(i + 530) * 4.0 - 2.0)).floor()
			var end := (p + dir * reach).floor()
			_art.draw_line(p, mid, crack)
			_art.draw_line(mid, end, crack)
			if i % 2 == 0:
				var side := Vector2(cos(ang + 0.7), sin(ang + 0.7))
				_art.draw_line(mid, (mid + side * reach * 0.3).floor(), crack)
		_art.draw_arc(p, 3.0, 0.0, TAU, 10, crack, -1.0)
	# the glass itself: a frame, a sill and two streaks of glare
	_art.draw_line(Vector2(pane.position.x + 10.0, pane.end.y - 4.0), Vector2(pane.position.x + 60.0, pane.position.y + 4.0), Color(Gfx.TEAL4, 0.35))
	_art.draw_line(Vector2(pane.position.x + 22.0, pane.end.y - 4.0), Vector2(pane.position.x + 66.0, pane.position.y + 30.0), Color(Gfx.TEAL4, 0.2))
	Gfx.outline(_art, pane.grow(1.0), Gfx.TEAL4)
	_r(pane.position.x - 4.0, pane.end.y + 1.0, pane.size.x + 8.0, 3, Gfx.TEAL3)
	if t >= 4.9 and fmod(t, 1.0) < 0.7:
		Gfx.text_center(_art, cx, pane.position.y + 6.0, str(labels.get("ask", "")), Gfx.WARM6, true)


## A shadow behind the glass, drawn upwards from its feet at the origin. Only the hall light
## behind it shows its edges (rim: 0..1); its implant eye glows by itself. hooded: the second
## visitor. fists: raised against the glass, lit from the counter's side.
func _visitor(hooded: bool, rim: float, red: bool, fists: bool) -> void:
	var body := Gfx.INK0
	var edge := Color(Gfx.TEAL5, rim)
	var head := Vector2(0, -96) if hooded else Vector2(0, -98)
	var rx := 15.0 if hooded else 13.0
	var ry := 18.0 if hooded else 16.0
	var y := -ry
	while y < ry:
		var half := floorf(rx * sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry))))
		_r(head.x - half, head.y + y, half * 2.0, 2, body)
		_r(head.x - half, head.y + y, 1, 2, edge)
		if hooded:
			_r(head.x + half - 1.0, head.y + y, 1, 2, edge)
		y += 2.0
	_r(-6, -84, 12, 8, body)
	var widest := 38.0 if hooded else 44.0
	var narrow := 18.0 if hooded else 20.0
	y = -78.0
	while y < 0.0:
		var half := minf(widest, narrow + (y + 78.0) * 1.5)
		_r(-half, y, half * 2.0, 2, body)
		_r(-half, y, 1, 2, edge)
		if y < -70.0:
			_r(-half, y, half * 2.0, 1, Color(Gfx.TEAL4, rim * 0.8))
		y += 2.0
	var glint := Gfx.RED2 if red else Gfx.TEAL6
	if hooded:
		_r(4, -94, 2, 2, Color(glint, rim))
	else:
		_r(4, -100, 3, 2, Color(glint, rim))
	if fists:
		# both arms up, dark against the hall light, and the fists on the glass, lit from the
		# counter's side: knuckles along the top, the fingers curled under, the thumb across
		for side in [-1.0, 1.0]:
			var fist: Vector2 = FIST_R if side > 0.0 else Vector2(-FIST_R.x, FIST_R.y + 8.0)
			_art.draw_line(Vector2(17.0 * side, -74.0), fist + Vector2(0, 4), body, 9.0)
			var x := fist.x - 7.0
			var top := fist.y - 6.0
			_r(x, top, 14, 12, Gfx.TEAL4)
			for k in 4:
				_r(x + 1.0 + 3.0 * float(k), top, 2, 1, Gfx.TEAL6)
				if k > 0:
					_r(x + 3.5 * float(k), top + 1.0, 1, 6, Gfx.TEAL2)
			_r(x + (1.0 if side > 0.0 else 4.0), top + 8.0, 9, 3, Gfx.TEAL5)
			_r(x + (1.0 if side > 0.0 else 4.0), top + 8.0, 9, 1, Gfx.TEAL6)


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
