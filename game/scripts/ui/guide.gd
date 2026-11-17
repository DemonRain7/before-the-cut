extends Node2D
## The counter guide: four pages that point at what is on the screen and say what each thing
## is for: the window, the left wall, the right wall, the desk. A page darkens everything but
## the part it is about, frames each thing it explains, numbers it, and lists the numbers
## beside it. It opens by itself once, when the first patient of a session reaches the
## counter, and again on H or F1 or a click on the booklet on the left wall. While it is open
## the papers and the big camera screen are back on the wall, where it points at them. The
## words come from data/intro.json ("guide"); where each thing sits on the screen is known
## here. Nothing in it is a step the player has to take.

const Gfx = preload("res://scripts/ui/gfx.gd")

const DIM := 0.86            # how dark the rest of the screen goes
const FADE := 0.15
const BADGE := 11.0          # the numbered square
const PAD := 8.0
const ITEM_GAP := 5.0
const FOOT := "click or ENTER: next  •  LEFT: back  •  ESC: close"

# the part of the screen each page is about (screen pixels, like everything in these tables)
const LIT := {
	"window": Rect2(100, 0, 440, 300),
	"left": Rect2(0, 0, 100, 300),
	"right": Rect2(540, 0, 100, 300),
	"desk": Rect2(0, 300, 640, 60),
}
# where the list goes: beside the part the page is about, clear of everything it numbers
const PANEL := {
	"window": Rect2(4, 8, 216, 0),
	"left": Rect2(108, 8, 232, 0),
	"right": Rect2(300, 8, 232, 0),
	"desk": Rect2(204, 0, 232, 0),
}
# a list that stands on a line of the screen instead of hanging from its panel's top
const STANDS := {"desk": 292.0}
# where each explained thing is (the item keys of data/intro.json)
const AREAS := {
	"patient": Rect2(224, 16, 192, 278),
	"patience": Rect2(261, 0, 118, 14),
	"glass": Rect2(479, 285, 60, 14),
	"sheet": Rect2(7, 7, 82, 94),
	"till": Rect2(2, 168, 96, 56),
	"camera": Rect2(2, 226, 96, 73),
	"record": Rect2(545, 7, 82, 106),
	"treat": Rect2(546, 190, 40, 54),
	"team": Rect2(594, 190, 40, 54),
	"shutter": Rect2(546, 245, 40, 54),
	"mend": Rect2(594, 245, 40, 54),
	"tools": Rect2(1, 301, 118, 58),
	"say": Rect2(412, 301, 104, 15),
	"talk": Rect2(521, 301, 118, 58),
}
# where the number goes when the corner of the frame would sit on the thing's own label
const BADGE_AT := {
	"patience": Vector2(248, 1),
	"glass": Vector2(466, 286),
}

var page: int = 0

var _pages: Array = []
var _numbers: Dictionary = {}
var _open: bool = false
var _fade: float = 0.0


func _init() -> void:
	visible = false


## pages: the "guide" list of data/intro.json. numbers: what "{threshold}" and the like stand
## for. without: item keys to leave out, for a thing this rule set does not have.
func setup(pages: Array, numbers: Dictionary, without: Array = []) -> void:
	_numbers = numbers
	_pages = []
	for p in pages:
		if not (p is Dictionary):
			continue
		var kept: Dictionary = (p as Dictionary).duplicate(true)
		var items: Array = []
		for item in kept.get("items", []):
			if item is Dictionary and not without.has(str((item as Dictionary).get("key", ""))):
				items.append(item)
		kept["items"] = items
		_pages.append(kept)


func has_pages() -> bool:
	return not _pages.is_empty()


func count() -> int:
	return _pages.size()


func is_open() -> bool:
	return _open


func open() -> void:
	if _pages.is_empty():
		return
	page = 0
	_open = true
	_fade = 0.0
	visible = true
	queue_redraw()


## The next page; after the last one the guide closes.
func next() -> void:
	if not _open:
		return
	if page + 1 < _pages.size():
		page += 1
		queue_redraw()
	else:
		close()


func back() -> void:
	if _open and page > 0:
		page -= 1
		queue_redraw()


func close() -> void:
	_open = false
	visible = false


## The width a page's item text is wrapped to.
func text_width(page_id: String) -> float:
	var panel: Rect2 = PANEL.get(page_id, PANEL["window"])
	return panel.size.x - PAD * 2.0 - BADGE - 5.0


## The words of one item as they are laid out on the screen.
func lines_of(page_index: int, item_index: int) -> PackedStringArray:
	if page_index < 0 or page_index >= _pages.size():
		return PackedStringArray()
	var p: Dictionary = _pages[page_index]
	var items: Array = p.get("items", [])
	if item_index < 0 or item_index >= items.size():
		return PackedStringArray()
	var item: Dictionary = items[item_index]
	return Gfx.wrap_text(Gfx.fill(str(item.get("text", "")), _numbers), text_width(str(p.get("id", ""))))


## The line under a page's list, where it has one, as it is laid out.
func closing_of(page_index: int) -> PackedStringArray:
	if page_index < 0 or page_index >= _pages.size():
		return PackedStringArray()
	var p: Dictionary = _pages[page_index]
	var said := str(p.get("closing", ""))
	if said == "":
		return PackedStringArray()
	var panel: Rect2 = PANEL.get(str(p.get("id", "")), PANEL["window"])
	return Gfx.wrap_text(Gfx.fill(said, _numbers), panel.size.x - PAD * 2.0)


## Where a page's list is drawn: its place on the screen, as tall as its words need.
func box_of(page_index: int) -> Rect2:
	if page_index < 0 or page_index >= _pages.size():
		return Rect2()
	var p: Dictionary = _pages[page_index]
	var id := str(p.get("id", ""))
	var panel: Rect2 = PANEL.get(id, PANEL["window"])
	var items: Array = p.get("items", [])
	var height := PAD + 12.0 + 7.0
	for i in items.size():
		height += float(lines_of(page_index, i).size()) * float(Gfx.LINE) + ITEM_GAP
	var closing := closing_of(page_index)
	if not closing.is_empty():
		height += 3.0 + float(closing.size()) * float(Gfx.LINE) + ITEM_GAP
	height += 4.0 + float(Gfx.LINE) + PAD
	var top := panel.position.y
	if STANDS.has(id):
		top = float(STANDS[id]) - height       # over the desk, standing on its edge
	return Rect2(panel.position.x, floorf(top), panel.size.x, height)


## The item keys of one page, in the order they are numbered.
func keys_of(page_index: int) -> PackedStringArray:
	var out := PackedStringArray()
	if page_index < 0 or page_index >= _pages.size():
		return out
	for item in (_pages[page_index] as Dictionary).get("items", []):
		out.append(str((item as Dictionary).get("key", "")))
	return out


func id_of(page_index: int) -> String:
	if page_index < 0 or page_index >= _pages.size():
		return ""
	return str((_pages[page_index] as Dictionary).get("id", ""))


func _process(delta: float) -> void:
	if not _open:
		return
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / FADE)
		queue_redraw()


func _draw() -> void:
	if not _open or _pages.is_empty():
		return
	var p: Dictionary = _pages[page]
	var id := str(p.get("id", ""))
	var items: Array = p.get("items", [])
	var a := clampf(_fade, 0.0, 1.0)
	var lit: Rect2 = LIT.get(id, Rect2())
	var dim := Color(Gfx.INK0, DIM * a)
	var screen := Gfx.SCREEN
	if lit.size.x <= 0.0 or lit.size.y <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), dim)
	else:
		draw_rect(Rect2(0, 0, screen.x, lit.position.y), dim)
		draw_rect(Rect2(0, lit.end.y, screen.x, screen.y - lit.end.y), dim)
		draw_rect(Rect2(0, lit.position.y, lit.position.x, lit.size.y), dim)
		draw_rect(Rect2(lit.end.x, lit.position.y, screen.x - lit.end.x, lit.size.y), dim)
	# a frame and a number on each thing the page explains
	for i in items.size():
		var item: Dictionary = items[i]
		var key := str(item.get("key", ""))
		if not AREAS.has(key):
			continue
		var area: Rect2 = AREAS[key]
		Gfx.outline(self, area.grow(1.0), Color(Gfx.INK0, a))
		Gfx.outline(self, area, Color(Gfx.WARM6, a))
		var at: Vector2 = BADGE_AT.get(key, area.position - Vector2(2, 2))
		_badge(Vector2(clampf(at.x, 0.0, screen.x - BADGE), clampf(at.y, 0.0, screen.y - BADGE)), i + 1, a)
	# the list
	var wrapped: Array = []
	for i in items.size():
		wrapped.append(lines_of(page, i))
	var closing := closing_of(page)
	var box := box_of(page)
	draw_rect(Rect2(box.position + Vector2(3, 3), box.size), Color(0, 0, 0, 0.5 * a))
	draw_rect(box, Color(Gfx.TEAL1, a))
	Gfx.outline(self, box, Color(Gfx.TEAL4, a))
	var x := box.position.x + PAD
	var y := box.position.y + PAD
	Gfx.text(self, Vector2(x, y), str(p.get("title", "")), Color(Gfx.WARM6, a), true)
	Gfx.text_right(self, box.end.x - PAD, y, "%d/%d" % [page + 1, _pages.size()], Color(Gfx.TEAL5, a))
	y += 12.0
	draw_rect(Rect2(x, y, box.size.x - PAD * 2.0, 1), Color(Gfx.TEAL3, a))
	y += 7.0
	var tx := x + BADGE + 5.0
	for i in wrapped.size():
		_badge(Vector2(x, y - 1.0), i + 1, a)
		var lines: PackedStringArray = wrapped[i]
		for line in lines:
			Gfx.text(self, Vector2(tx, y), line, Color(Gfx.TEAL7, a))
			y += float(Gfx.LINE)
		y += ITEM_GAP
	if not closing.is_empty():
		y += 3.0
		for line in closing:
			Gfx.text(self, Vector2(x, y), line, Color(Gfx.WARM7, a))
			y += float(Gfx.LINE)
		y += ITEM_GAP
	y += 4.0
	Gfx.text_center(self, box.position.x + box.size.x / 2.0, y, FOOT, Color(Gfx.TEAL5, a))


func _badge(at: Vector2, number: int, a: float) -> void:
	var r := Rect2(at.floor(), Vector2(BADGE, BADGE))
	draw_rect(r, Color(Gfx.WARM6, a))
	Gfx.outline(self, r, Color(Gfx.INK0, a))
	Gfx.text_center(self, r.position.x + 6.0, r.position.y + 1.0, str(number), Color(Gfx.INK0, a), true)
