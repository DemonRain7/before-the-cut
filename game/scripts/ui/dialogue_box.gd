extends Node2D
## The transcript unit set into the desk under the window: one spoken line with a
## typewriter, or the list of questions, or the line the doctor is typing (or dictating), and
## a dim hint line at the bottom.
##
## Everything in here is laid out in the strip's own coordinates (BOX); the node is moved so
## that BOX lands on Gfx.DIALOGUE. The functions that take a pointer take a screen position.
##
## The unit's face (`back`) is a node of its own, so that the director can lay what runs down
## from the sill between the face and the words: blood crosses the glass of the unit, never a
## name or a line on it.

const Gfx = preload("res://scripts/ui/gfx.gd")

signal blip

const BOX := Rect2(0, 224, 400, 60)
const TEXT_X := 12.0
const TEXT_W := 376.0
const NAME_Y := 229.0
const TEXT_Y := 241.0
const TEXT_PITCH := 11.0
const MENU_Y := 240.0
const MENU_PITCH := 10.0
const HINT_Y := 271.0
const PAGE_LINES := 2          # rows of speech on screen at once; a longer line turns pages
const PAGE_HOLD := 0.9         # a full page waits this long, plus reading time, then turns
const PAGE_HOLD_PER_CHAR := 0.022
const INPUT_MAX := 120         # characters the doctor can say in one go
const INPUT_LINES := 2         # and it has to fit the strip
const CHIP_Y := 227.0          # the small buttons hang from the top edge of the strip
const CHIP_H := 11.0
const CHIP_RIGHT := 394.0
const METER_BARS := 18

var speaker: String = ""
var speaker_color: Color = Gfx.WARM6
var text_color: Color = Gfx.TEAL7
var lines: PackedStringArray = PackedStringArray()
var shown: int = 0             # characters revealed so far
var total: int = 0
var typing: bool = false
var rate: float = 46.0         # characters per second
var waiting: bool = false      # draws the "next" arrow
var more: bool = false         # the line goes on: another page is behind the arrow
var thinking: bool = false     # the patient is choosing (model mode)
var hint: String = ""
var hint_color: Color = Gfx.TEAL4
var menu: Array = []           # [{"id", "label", "tag", "dim"}]
var menu_title: String = ""
var menu_hover: int = -1

var input_open: bool = false   # the doctor is composing a line of their own
var input_text: String = ""
var input_caret: int = 0
var input_status: String = ""  # "" typing | "opening" | "listening" | "transcribing": the microphone has the line
var input_level: float = 0.0   # 0..1: how loud the microphone hears the player
var input_seconds: float = 0.0
var chips: Array = []          # [{"id", "key", "label"}] small buttons on the name line
var chips_dim: bool = false
var chip_hover: String = ""

var back := Node2D.new()       # the unit's face; this node draws only what is written on it

var _acc: float = 0.0
var _t: float = 0.0
var _page: int = 0             # first row on screen
var _page_hold: float = 0.0
var _blip_gap: int = 0
var _caret_t: float = 0.0
var _rows: Array = [Vector2i(0, 0)]   # where the typed line breaks: [start, end) pairs


func say(p_speaker: String, p_text: String, p_speaker_color: Color = Gfx.WARM6,
		p_text_color: Color = Gfx.TEAL7, p_rate: float = 46.0) -> void:
	clear_menu()
	speaker = p_speaker
	speaker_color = p_speaker_color
	text_color = p_text_color
	lines = Gfx.wrap_text(p_text, TEXT_W)
	_page = 0
	_open_page()
	rate = p_rate
	typing = total > 0
	waiting = false
	thinking = false
	queue_redraw()


## Counts what the rows now on screen hold. `shown` and `total` are about this page only.
func _open_page() -> void:
	total = 0
	for i in range(_page, mini(_page + PAGE_LINES, lines.size())):
		total += lines[i].length()
	shown = 0
	_acc = 0.0
	more = _page + PAGE_LINES < lines.size()
	_page_hold = PAGE_HOLD + PAGE_HOLD_PER_CHAR * float(total)


## A click: shows the rest of the page at once; on a full page, turns to the next one.
func skip() -> void:
	if not typing:
		return
	if shown < total:
		shown = total
	elif more:
		_page += PAGE_LINES
		_open_page()
	if shown >= total and not more:
		typing = false
	queue_redraw()


## True while letters are still appearing (not while a full page waits to turn).
func is_revealing() -> bool:
	return typing and shown < total


func clear() -> void:
	speaker = ""
	lines = PackedStringArray()
	shown = 0
	total = 0
	_page = 0
	more = false
	typing = false
	waiting = false
	thinking = false
	queue_redraw()


func set_menu(title: String, options: Array) -> void:
	menu_title = title
	menu = options
	menu_hover = -1
	queue_redraw()


func clear_menu() -> void:
	if not menu.is_empty():
		menu = []
		menu_hover = -1
		queue_redraw()


func has_menu() -> bool:
	return not menu.is_empty()


func _ready() -> void:
	position = Gfx.DIALOGUE.position - BOX.position
	if back.get_parent() == null:
		# nobody placed the face: it goes straight behind the words
		back.show_behind_parent = true
		add_child(back)
	else:
		back.position = position
	back.draw.connect(_draw_back)
	back.queue_redraw()


func _draw_back() -> void:
	var bg := Gfx.tex("clinic/dialogue.png")
	if bg != null:
		back.draw_texture(bg, BOX.position)


## The question under a screen position, or -1.
func menu_index_at(screen: Vector2) -> int:
	if menu.is_empty():
		return -1
	var pos := screen - position
	if pos.x < 4.0 or pos.x > 396.0:
		return -1
	var i := int(floor((pos.y - MENU_Y) / MENU_PITCH))
	if i < 0 or i >= menu.size():
		return -1
	return i


func menu_id(i: int) -> String:
	if i < 0 or i >= menu.size():
		return ""
	var opt: Dictionary = menu[i]
	return str(opt.get("id", ""))


func set_hint(p_hint: String, p_color: Color = Gfx.TEAL4) -> void:
	if hint != p_hint or hint_color != p_color:
		hint = p_hint
		hint_color = p_color
		queue_redraw()


# ------------------------------------------------------------------ the doctor's own line
## Opens the typing line. The spoken line under it is kept and comes back when this closes.
func open_input(prefill: String = "") -> void:
	clear_menu()
	input_open = true
	input_status = ""
	input_level = 0.0
	input_seconds = 0.0
	input_set(prefill)


func close_input() -> void:
	if not input_open:
		return
	input_open = false
	input_status = ""
	input_text = ""
	input_caret = 0
	_rows = [Vector2i(0, 0)]
	queue_redraw()


## Replaces the whole line (a transcript, for one). Keeps as much of it as fits.
func input_set(text: String) -> void:
	input_text = ""
	input_caret = 0
	_rows = [Vector2i(0, 0)]
	for i in text.length():
		if not input_insert(text[i]):
			break
	_caret_t = _t
	queue_redraw()


## Types one character at the caret. False when the line is full.
func input_insert(ch: String) -> bool:
	if not input_open or ch.length() != 1 or input_text.length() >= INPUT_MAX:
		return false
	var trial := input_text.substr(0, input_caret) + ch + input_text.substr(input_caret)
	var rows := _break_rows(trial)
	if rows.size() > INPUT_LINES:
		return false
	input_text = trial
	input_caret += 1
	_rows = rows
	_caret_t = _t
	return true


func input_backspace() -> bool:
	if not input_open or input_caret <= 0:
		return false
	input_text = input_text.substr(0, input_caret - 1) + input_text.substr(input_caret)
	input_caret -= 1
	_rows = _break_rows(input_text)
	_caret_t = _t
	return true


func input_delete() -> bool:
	if not input_open or input_caret >= input_text.length():
		return false
	input_text = input_text.substr(0, input_caret) + input_text.substr(input_caret + 1)
	_rows = _break_rows(input_text)
	_caret_t = _t
	return true


func input_move(by: int) -> void:
	input_caret = clampi(input_caret + by, 0, input_text.length())
	_caret_t = _t


## How many more characters the line takes (by count; a wide line can fill up sooner).
func input_room() -> int:
	return INPUT_MAX - input_text.length()


## Unlike Gfx.wrap_text this keeps every character, spaces too, so the caret can sit anywhere.
func _break_rows(s: String) -> Array:
	var rows: Array = []
	var start := 0
	var last_space := -1
	for i in s.length():
		if i > start and Gfx.text_w(s.substr(start, i - start + 1)) > TEXT_W:
			var cut := i
			if last_space > start and last_space < i:
				cut = last_space + 1
			rows.append(Vector2i(start, cut))
			start = cut
			last_space = -1
		if s[i] == " ":
			last_space = i
	rows.append(Vector2i(start, s.length()))
	return rows


## Row and x offset of the caret.
func _caret_place() -> Vector2:
	var row := 0
	for i in _rows.size():
		var r: Vector2i = _rows[i]
		if r.x <= input_caret:
			row = i
	var from: Vector2i = _rows[row]
	return Vector2(Gfx.text_w(input_text.substr(from.x, input_caret - from.x)), float(row))


# ------------------------------------------------------------------ the small buttons
## Laid out from the right edge of the name line. [{"id", "rect", "key", "label"}]
func _chip_rects() -> Array:
	var out: Array = []
	var right := CHIP_RIGHT
	for i in range(chips.size() - 1, -1, -1):
		var chip: Dictionary = chips[i]
		var key := str(chip.get("key", ""))
		var label := str(chip.get("label", ""))
		var w := Gfx.text_w(key, true) + Gfx.text_w(label) + 11.0
		out.append({"id": str(chip.get("id", "")), "rect": Rect2(right - w, CHIP_Y, w, CHIP_H), "key": key, "label": label})
		right -= w + 3.0
	return out


## The button under a screen position, or "". They are put away while the doctor is typing.
func chip_at(screen: Vector2) -> String:
	if input_open:
		return ""
	var pos := screen - position
	for c in _chip_rects():
		var r: Rect2 = c["rect"]
		if r.has_point(pos):
			return str(c["id"])
	return ""


## Where a small button is on the screen (an empty rectangle if there is no such button).
func chip_rect(id: String) -> Rect2:
	for c in _chip_rects():
		if str(c["id"]) == id:
			var r: Rect2 = c["rect"]
			return Rect2(r.position + position, r.size)
	return Rect2()


## Where question `index` of the list is on the screen: the middle of its row.
func menu_point(index: int) -> Vector2:
	return position + Vector2(120.0, MENU_Y + MENU_PITCH * float(index) + MENU_PITCH / 2.0)


func _process(delta: float) -> void:
	_t += delta
	if typing:
		if shown < total:
			_acc += delta * rate
			var step := int(_acc)
			if step > 0:
				_acc -= float(step)
				for i in step:
					if shown >= total:
						break
					var ch := _char_at(shown)
					shown += 1
					if ch != " ":
						_blip_gap += 1
						if _blip_gap >= 2:
							_blip_gap = 0
							blip.emit()
					if ch == "." or ch == "?" or ch == "!" or ch == ",":
						_acc -= 4.0 if ch != "," else 2.0      # a short breath at punctuation
						break
		elif more:
			_page_hold -= delta      # nobody clicked: the page turns by itself
			if _page_hold <= 0.0:
				_page += PAGE_LINES
				_open_page()
		if shown >= total and not more:
			typing = false
	queue_redraw()


func _char_at(index: int) -> String:
	var n := index
	for i in range(_page, mini(_page + PAGE_LINES, lines.size())):
		var l := lines[i]
		if n < l.length():
			return l[n]
		n -= l.length()
	return " "


func _draw() -> void:
	if input_open:
		_draw_input()
	elif not menu.is_empty():
		_draw_menu()
		_draw_chips()
	else:
		_draw_line()
		_draw_chips()
	if hint != "":
		Gfx.text(self, Vector2(TEXT_X, HINT_Y), hint, hint_color)


func _draw_line() -> void:
	if speaker != "":
		Gfx.text(self, Vector2(TEXT_X, NAME_Y), speaker, speaker_color, true)
	if thinking:
		var dots := ".".repeat(1 + int(_t * 3.0) % 3)
		Gfx.text(self, Vector2(TEXT_X, TEXT_Y), dots, text_color)
		return
	var left := shown
	var y := TEXT_Y
	for i in range(_page, mini(_page + PAGE_LINES, lines.size())):
		if left <= 0:
			break
		var l := lines[i]
		var part: String = l if left >= l.length() else l.substr(0, left)
		Gfx.text(self, Vector2(TEXT_X, y), part, text_color)
		left -= l.length()
		y += TEXT_PITCH
	var turn := more and shown >= total      # the rest of the line is on the next page
	if (turn or (waiting and not typing)) and fmod(_t, 0.8) < 0.5:
		Gfx.text(self, Vector2(384.0, 261.0), "►", Gfx.WARM6)


func _draw_menu() -> void:
	Gfx.text(self, Vector2(TEXT_X, NAME_Y), menu_title, Gfx.WARM6, true)
	for i in menu.size():
		var opt: Dictionary = menu[i]
		var y := MENU_Y + MENU_PITCH * float(i)
		var hot := i == menu_hover
		var dim := bool(opt.get("dim", false))
		if hot:
			draw_rect(Rect2(6.0, y, 388.0, MENU_PITCH), Color(Gfx.TEAL3, 0.9))
		var col: Color = Gfx.TEAL5 if dim else Gfx.TEAL7
		if hot:
			col = Gfx.WARM7
		Gfx.text(self, Vector2(TEXT_X, y), "►" if hot else "•", Gfx.WARM6 if hot else Gfx.TEAL4)
		Gfx.text(self, Vector2(TEXT_X + 10.0, y), str(opt.get("label", "")), col)
		var tag := str(opt.get("tag", ""))
		if tag != "":
			Gfx.text_right(self, 388.0, y, tag, Gfx.TEAL5 if not hot else Gfx.WARM6)


func _draw_chips() -> void:
	for c in _chip_rects():
		var r: Rect2 = c["rect"]
		var hot := str(c["id"]) == chip_hover and not chips_dim
		draw_rect(r, Gfx.TEAL3 if hot else Gfx.TEAL2)
		draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1), Gfx.TEAL5 if hot else Gfx.TEAL3)
		var key := str(c["key"])
		var key_col: Color = Gfx.WARM6
		var label_col: Color = Gfx.WARM7 if hot else Gfx.TEAL6
		if chips_dim:
			key_col = Gfx.TEAL4
			label_col = Gfx.TEAL4
		Gfx.text(self, Vector2(r.position.x + 4.0, CHIP_Y), key, key_col, true)
		Gfx.text(self, Vector2(r.position.x + 7.0 + Gfx.text_w(key, true), CHIP_Y), str(c["label"]), label_col)


func _draw_input() -> void:
	Gfx.text(self, Vector2(TEXT_X, NAME_Y), "YOU", Gfx.CYAN2, true)
	match input_status:
		"listening":
			# a red light, a level meter and the seconds: the microphone is open and says so
			var lit := fmod(_t, 0.8) < 0.55
			draw_rect(Rect2(TEXT_X, TEXT_Y + 2.0, 6, 6), Gfx.RED2 if lit else Gfx.RED1)
			Gfx.text(self, Vector2(TEXT_X + 10.0, TEXT_Y), "LISTENING", Gfx.RED3, true)
			var x := TEXT_X + 14.0 + Gfx.text_w("LISTENING", true)
			var on := int(ceil(clampf(input_level, 0.0, 1.0) * float(METER_BARS)))
			for i in METER_BARS:
				var col: Color = Gfx.TEAL3
				if i < on:
					col = Gfx.GRN3 if i < METER_BARS - 4 else Gfx.AMBER
				draw_rect(Rect2(x + 4.0 * float(i), TEXT_Y + 2.0, 3, 6), col)
			Gfx.text(self, Vector2(x + 4.0 * float(METER_BARS) + 6.0, TEXT_Y), "%.1f s" % input_seconds, Gfx.TEAL6)
			Gfx.text(self, Vector2(TEXT_X, TEXT_Y + TEXT_PITCH), "Let go when you have said it.", Gfx.TEAL5)
		"opening":
			# the key is down but the device is not ready: a dim light, and no promise that it hears
			draw_rect(Rect2(TEXT_X, TEXT_Y + 2.0, 6, 6), Gfx.AMBER if fmod(_t, 0.3) < 0.15 else Gfx.RED1)
			var dots := ".".repeat(1 + int(_t * 6.0) % 3)
			Gfx.text(self, Vector2(TEXT_X + 10.0, TEXT_Y), "OPENING THE MICROPHONE" + dots, Gfx.TEAL6, true)
			Gfx.text(self, Vector2(TEXT_X, TEXT_Y + TEXT_PITCH), "Speak when it says LISTENING.", Gfx.TEAL5)
		"transcribing":
			var dots := ".".repeat(1 + int(_t * 3.0) % 3)
			Gfx.text(self, Vector2(TEXT_X, TEXT_Y), "WRITING DOWN WHAT YOU SAID" + dots, Gfx.TEAL6)
		_:
			if input_text == "":
				Gfx.text(self, Vector2(TEXT_X + 4.0, TEXT_Y), "Say it in your own words.", Gfx.TEAL4)
			for i in _rows.size():
				var r: Vector2i = _rows[i]
				Gfx.text(self, Vector2(TEXT_X, TEXT_Y + TEXT_PITCH * float(i)), input_text.substr(r.x, r.y - r.x), Gfx.TEAL7)
			if fmod(_t - _caret_t, 1.0) < 0.6:
				var at := _caret_place()
				draw_rect(Rect2(TEXT_X + at.x, TEXT_Y + TEXT_PITCH * at.y + 1.0, 1, 9), Gfx.CYAN2)
			var room := input_room()
			if room <= 30:
				Gfx.text_right(self, 388.0, NAME_Y, "%d left" % room, Gfx.TEAL5 if room > 0 else Gfx.RED3)
