extends Node2D
## The training on the first night: one tip at a time, in a small box, with a pulsing frame
## round the thing it is about. It never blocks and never sets an order. The counter works
## exactly as it does without it, and a tip goes away
##   - when the thing it asks for is done (now, or earlier: a tip for something the player has
##     already done is passed over),
##   - when NEXT is pressed (every tip has it),
##   - or when the tip has been up for a while and the player goes on to something else.
## SKIP ALL [K] ends the training. Each tip belongs to one or more phases of a visit: waiting
## for the next patient, the exam, the result slip. A tip whose phases are over is dropped; one
## whose phase has not come yet waits out of sight. While the counter guide or a close-up is
## open the box is out of the way.
##
## The words come from data/intro.json ("training"). What each tip's "area" is on the screen
## is decided by main.gd, which sets `focus` (and `avoid`, the rects the box should stay off)
## every frame; the box picks the first of a few fixed places that is clear of them.

signal finished(was_skipped: bool)

const Gfx = preload("res://scripts/ui/gfx.gd")

const PHASES := ["wait", "exam", "slip"]
const WIDTH := 196.0
const PAD := 7.0
const TEXT_W := 182.0          # WIDTH - 2 * PAD
const BUTTON_H := 13.0
const FLOOR := 296.0           # a low box stands on this line, just above the desk
const FADE := 0.2
const PULSE := 0.9             # seconds for one beat of the frame
const LINGER_READ := 2.0       # a tip that is only read gives way to the next action after this long
const LINGER_DO := 10.0        # a tip that asks for something gives way to something else after this long
const TITLE := "TRAINING"
const NEXT := "NEXT ►"
const DONE := "DONE ►"
const SKIP := "SKIP ALL [K]"

var focus: Rect2 = Rect2()     # screen rect of what the current tip is about (empty: nothing)
var avoid: Array = []          # Rect2s the box must not cover (open papers, the slip, the face)
var soft: Array = []           # Rect2s it should not cover when there is a place that misses them
var paused: bool = false       # the counter guide or a close-up is open
var hover: String = ""         # "next" | "skip" | ""
var skipped: bool = false
var reached: int = 0           # how many tips had been passed when the training ended

var _steps: Array = []
var _index: int = -1           # -1: not running
var _phase: String = ""
var _done: Dictionary = {}     # events seen since the training started
var _shown: float = 0.0        # seconds the current tip has been on the screen
var _fade: float = 0.0
var _t: float = 0.0
var _box: Rect2 = Rect2()
var _spot: int = -1            # which of the places the box is in; kept while it stays clear
var _lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	visible = false


## steps: the "training" list of data/intro.json, each {id, phase, until, area, text}.
## numbers: what "{pay}" and the like stand for.
func setup(steps: Array, numbers: Dictionary) -> void:
	_steps = []
	for s in steps:
		if not (s is Dictionary):
			continue
		var step: Dictionary = (s as Dictionary).duplicate(true)
		step["text"] = Gfx.fill(str(step.get("text", "")), numbers)
		_steps.append(step)


func has_steps() -> bool:
	return not _steps.is_empty()


func count() -> int:
	return _steps.size()


func is_running() -> bool:
	return _index >= 0


func index() -> int:
	return _index


## Whether the box is on the screen now.
func is_showing() -> bool:
	return is_running() and not paused and _index < _steps.size() and _phases_of(_steps[_index]).has(_phase)


## The id of the tip that is due (shown or waiting for its phase), or "".
func current() -> String:
	if not is_running() or _index >= _steps.size():
		return ""
	return str((_steps[_index] as Dictionary).get("id", ""))


## What the tip on the screen points at, or "" when nothing is shown.
func area() -> String:
	if not is_showing():
		return ""
	return str((_steps[_index] as Dictionary).get("area", ""))


func start() -> void:
	if _steps.is_empty():
		return
	_done.clear()
	skipped = false
	reached = 0
	_index = 0
	_shown = 0.0
	_fade = 0.0
	_spot = -1
	_settle()


## Something the player did, or something that happened at the counter ("list_open",
## "check:grip", "verdict", ...). It completes the tip that asked for it, and any later tip that
## asks for it is passed over. A tip that has been up long enough gives way to it as well.
func event(name: String) -> void:
	if not is_running():
		return
	if is_showing() and _shown >= _linger(_steps[_index]) and str((_steps[_index] as Dictionary).get("until", "")) != name:
		_advance()
	_done[name] = true
	_settle()


## NEXT: on to the next tip, whatever this one asked for.
func next() -> void:
	if not is_running():
		return
	_advance()
	_settle()


func stop(was_skipped: bool) -> void:
	if not is_running():
		return
	reached = mini(_index, _steps.size())
	_index = -1
	skipped = was_skipped
	visible = false
	hover = ""
	finished.emit(was_skipped)


## "wait", "exam", "slip", or "" for any other moment (a patient coming in, an attack, the
## report): then nothing is shown and nothing is dropped.
func set_phase(p: String) -> void:
	if p == _phase:
		return
	_phase = p
	if is_running():
		_settle()


## What is under a screen position: "skip", "next", "box" (the rest of the box, which takes
## the click so that nothing behind it is pressed by accident), or "".
func button_at(pos: Vector2) -> String:
	if not is_showing():
		return ""
	if skip_rect().has_point(pos):
		return "skip"
	if next_rect().has_point(pos):
		return "next"
	if _box.has_point(pos):
		return "box"
	return ""


func box() -> Rect2:
	return _box


func skip_rect() -> Rect2:
	return Rect2(_box.position.x + PAD, _box.end.y - PAD - BUTTON_H, Gfx.text_w(SKIP, true) + 10.0, BUTTON_H)


func next_rect() -> Rect2:
	var w := Gfx.text_w(_next_label(), true) + 12.0
	return Rect2(_box.end.x - PAD - w, _box.end.y - PAD - BUTTON_H, w, BUTTON_H)


## The words of tip i as they are laid out in the box.
func lines_of(i: int) -> PackedStringArray:
	if i < 0 or i >= _steps.size():
		return PackedStringArray()
	return Gfx.wrap_text(str((_steps[i] as Dictionary).get("text", "")), TEXT_W)


## How tall the box is for a tip of n lines.
static func height_for(n: int) -> float:
	return PAD + 12.0 + 6.0 + float(n) * float(Gfx.LINE) + 4.0 + BUTTON_H + PAD


func _next_label() -> String:
	return DONE if _index == _steps.size() - 1 else NEXT


func _advance() -> void:
	_index += 1
	_shown = 0.0
	_fade = 0.0
	_spot = -1


## Passes over every tip that is already done or whose phases are over; past the last one the
## training ends.
func _settle() -> void:
	while _index >= 0 and _index < _steps.size():
		var step: Dictionary = _steps[_index]
		var until := str(step.get("until", ""))
		if (until != "next" and _done.has(until)) or _expired(step):
			_advance()
			continue
		break
	if _index >= _steps.size():
		stop(false)
		return
	_lines = lines_of(_index)
	_layout()


func _phases_of(step: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for p in str(step.get("phase", "")).split(",", false):
		out.append(p.strip_edges())
	return out


func _expired(step: Dictionary) -> bool:
	var now := PHASES.find(_phase)
	if now < 0:
		return false
	var last := -1
	for p in _phases_of(step):
		last = maxi(last, PHASES.find(p))
	return last >= 0 and now > last


func _linger(step: Dictionary) -> float:
	return LINGER_READ if str(step.get("until", "")) == "next" else LINGER_DO


## The places the box can sit, in the order they are tried.
func _spots(h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(104, 18), Vector2(340, 18), Vector2(104, FLOOR - h), Vector2(340, FLOOR - h),
		Vector2(222, 18), Vector2(222, FLOOR - h)])


func _layout() -> void:
	var box_size := Vector2(WIDTH, height_for(_lines.size()))
	var spots := _spots(box_size.y)
	var keep_out := focus.grow(4.0) if focus.has_area() else Rect2()
	# the best a place can do: miss everything (2), miss what it must (1), miss the focus (0);
	# the place the box is in stays while it is as good as the best, so it does not hop about
	var best := -1
	for i in spots.size():
		best = maxi(best, _level(Rect2(spots[i], box_size), keep_out))
	var pick := 0
	if _spot >= 0 and _spot < spots.size() and _level(Rect2(spots[_spot], box_size), keep_out) >= best:
		pick = _spot
	else:
		for i in spots.size():
			if _level(Rect2(spots[i], box_size), keep_out) >= best:
				pick = i
				break
	_spot = pick
	_box = Rect2(spots[pick], box_size)


## 2: clear of the focus, `avoid` and `soft`; 1: of the focus and `avoid`; 0: of the focus;
## -1: on the focus.
func _level(r: Rect2, keep_out: Rect2) -> int:
	if keep_out.has_area() and r.intersects(keep_out):
		return -1
	for a in avoid:
		if a is Rect2 and (a as Rect2).has_area() and r.intersects(a):
			return 0
	for a in soft:
		if a is Rect2 and (a as Rect2).has_area() and r.intersects(a):
			return 1
	return 2


func _process(delta: float) -> void:
	_t += delta
	var showing := is_showing()
	visible = showing
	if not showing:
		_fade = 0.0
		return
	_shown += delta
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / FADE)
	_layout()
	queue_redraw()


func _draw() -> void:
	if not is_showing():
		return
	var a := clampf(_fade, 0.0, 1.0)
	# the frame round what the tip is about
	if focus.has_area():
		var screen := Rect2(Vector2.ZERO, Gfx.SCREEN)
		var beat := 0.5 + 0.5 * sin(_t * TAU / PULSE)
		var hot: Color = Gfx.AMBER.lerp(Gfx.WARM7, beat)
		Gfx.outline(self, focus.grow(3.0).intersection(screen), Color(Gfx.INK0, a))
		Gfx.outline(self, focus.grow(2.0).intersection(screen), Color(hot, a))
		Gfx.outline(self, focus.grow(1.0).intersection(screen), Color(hot, a * (0.35 + 0.4 * beat)))
	var b := _box
	draw_rect(Rect2(b.position + Vector2(3, 3), b.size), Color(0, 0, 0, 0.5 * a))
	draw_rect(b, Color(Gfx.TEAL1, a))
	Gfx.outline(self, b, Color(Gfx.TEAL4, a))
	var x := b.position.x + PAD
	var y := b.position.y + PAD
	Gfx.text(self, Vector2(x, y), TITLE, Color(Gfx.WARM6, a), true)
	Gfx.text_right(self, b.end.x - PAD, y, "%d/%d" % [_index + 1, _steps.size()], Color(Gfx.TEAL5, a))
	y += 12.0
	draw_rect(Rect2(x, y, b.size.x - PAD * 2.0, 1), Color(Gfx.TEAL3, a))
	y += 6.0
	for line in _lines:
		Gfx.text(self, Vector2(x, y), line, Color(Gfx.TEAL7, a))
		y += float(Gfx.LINE)
	_button(skip_rect(), SKIP, hover == "skip", a, false)
	_button(next_rect(), _next_label(), hover == "next", a, true)


func _button(r: Rect2, label: String, hot: bool, a: float, primary: bool) -> void:
	var fill: Color = Gfx.TEAL2
	var edge: Color = Gfx.TEAL3
	var ink: Color = Gfx.TEAL6
	if primary:
		fill = Gfx.TEAL4 if hot else Gfx.TEAL3
		edge = Gfx.WARM6 if hot else Gfx.TEAL5
		ink = Gfx.WARM7
	elif hot:
		fill = Gfx.TEAL3
		edge = Gfx.TEAL5
		ink = Gfx.TEAL7
	draw_rect(r, Color(fill, a))
	Gfx.outline(self, r, Color(edge, a))
	Gfx.text_center(self, r.position.x + r.size.x / 2.0, r.position.y + 2.0, label, Color(ink, a), true)
