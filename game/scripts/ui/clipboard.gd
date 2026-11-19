extends Node2D
## The doctor's papers. They hang on the booth walls until they are wanted (the wall objects
## are drawn by the desk); taken down, each slides in over its own side of the window:
##   the reference sheet, from the left: pulled from the spec binder for the models the
##   patient at the counter wears (case_db.gd sheet_for), the baseline body when nobody is
##   tonight's contact list, from the left, into the same place (the director never has both
##   of the left-hand papers down at once)
##   the patient's intake card, from the right
## The card mirrors the five sheet lines. Notes land on it as the player looks, tests and
## talks; nothing on it says "normal" or "abnormal" until the visit is over. The box beside
## each row is the player's own tick or cross, and the decision box counts their crosses
## against the house rule on the sheet (sheet.json "threshold").
##
## A paper that is out has a small tab on its window-side edge that puts it back. The sheet and
## the list hang on one hook: under the tab of whichever is down, a second tab (L or R) swaps it
## for the other.
##
## The contact list prints tonight's entries (data/contacts.json, drawn by ShiftState): an
## alias, two clues and a code line each. During the exam each entry still open has a SAY
## button; what a code does is decided by VisitState.say_code(), never here.
##
## The papers were laid out for a screen on which they sat one above the other, the sheet at
## SHEET_HOME and the card at CARD_HOME, and their rows are still written in those
## coordinates. Each paper is drawn by a node of its own that is moved to where the paper is
## now. Everything that takes a pointer takes a screen position.

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")

const ROWS := ["eyes", "hands", "port", "speech", "temper"]
const LABELS := {"eyes": "EYES", "hands": "HANDS", "port": "PORT", "speech": "SPEECH", "temper": "TEMPER"}

const SHEET_HOME := Vector2(404, 3)
const CARD_HOME := Vector2(404, 171)
const SHEET_ROW_Y := 32.0
const SHEET_ROW_H := 22.0
const SHEET_TEXT_X := 451.0
const SHEET_FINE := "fine:"       # [shown] leads a row's second line: what is ordinary for this model
const REC_ROW_Y := 214.0
const REC_ROW_H := 28.0
const REC_TEXT_X := 448.0
const REC_TEXT_W := 186.0
const LABEL_GAP := 6.0            # between a finding's label and its text when they share a line
const DECISION := Rect2(554, 182, 78, 26)
const TALLY := "CROSSED %d/%d"    # the player's crosses, against the sheet's threshold
const TAB := Vector2(12, 24)      # the tab that puts a paper back
const TAB_DROP := 8.0             # how far below the paper's top edge it sits
const SLIDE := 252.0              # how far a paper travels to be out of sight
const SLIDE_TIME := 0.16
const LIST_X := 16.0              # the text column of the contact list, inside its feed margins
const LIST_RIGHT := 216.0
const LIST_ENTRY_Y := 22.0
const LIST_ENTRY_H := 50.0
const LIST_FOOT_Y := 124.0
const LIST_MAX := 2               # entries the paper has room for (case_db holds contacts.per_night to it)
const SAY_SIZE := Vector2(30, 11)

var sheet: Dictionary = {}        # an assembled sheet (case_db sheet_for), set by the director
var visit: VisitState = null      # the patient at the counter, or null
var mode: String = "blank"        # "blank" | "exam" | "findings"
var settlement: Dictionary = {}
var imprint: String = ""          # "", "treat", "refer" (the Trauma Team dispatch mark), "void"
var armed: String = ""            # the stamp in the player's hand
var highlight_row: String = ""
var hover_mark: String = ""
var counter_text: String = ""     # "2 / 5"
var sheet_open: bool = false      # the reference sheet is down from its board
var card_open: bool = false       # the intake card is down from its board
var list_open: bool = false       # tonight's contact list is down from its board
var tab_hover: String = ""        # "sheet" | "list" | "card" | "swap": the tab under the pointer
var contacts: Array = []          # tonight's entries, as ShiftState drew them
var clues: Dictionary = {}        # data/contacts.json "clues": id -> {"text": ...}
var list_title: String = "TONIGHT'S CONTACTS"
var contact_pay: int = 0          # rules.json contacts.pay
var code_cost: int = 1            # rules.json contacts.wrong_cost
var contact_marks: Dictionary = {}    # entry id -> "picked" | "missed", for the rest of the night
var say_hover: String = ""        # the entry whose SAY button is under the pointer

var _sheet_n := Node2D.new()
var _card_n := Node2D.new()
var _list_n := Node2D.new()
var _sheet_k: float = 0.0         # 0 away, 1 out
var _card_k: float = 0.0
var _list_k: float = 0.0
var _fresh: Dictionary = {}       # note key -> seconds since it was written
var _imprint_t: float = 9.0
var _t: float = 0.0


func _ready() -> void:
	add_child(_sheet_n)
	_sheet_n.draw.connect(_draw_sheet_paper)
	add_child(_list_n)
	_list_n.draw.connect(_draw_list_paper)
	add_child(_card_n)
	_card_n.draw.connect(_draw_card_paper)
	_place()


func set_visit(p_visit: VisitState, p_counter: String) -> void:
	visit = p_visit
	counter_text = p_counter
	mode = "exam" if p_visit != null else "blank"
	settlement = {}
	imprint = ""
	armed = ""
	_fresh.clear()


func show_findings(p_settlement: Dictionary) -> void:
	settlement = p_settlement
	mode = "findings"


func stamp(kind: String) -> void:
	imprint = kind
	_imprint_t = 0.0
	armed = ""


func mark_fresh(key: String) -> void:
	_fresh[key] = 0.0


## Tonight's list, as the shift drew it. The marks of the last night go with it.
func set_contacts(p_entries: Array, p_clues: Dictionary, p_title: String, p_pay: int, p_cost: int) -> void:
	contacts = p_entries.duplicate(true)
	clues = p_clues
	list_title = p_title if p_title != "" else "TONIGHT'S CONTACTS"
	contact_pay = p_pay
	code_cost = p_cost
	contact_marks.clear()
	say_hover = ""


## All the papers where they are meant to be, at once (no slide).
func snap() -> void:
	_sheet_k = 1.0 if sheet_open else 0.0
	_card_k = 1.0 if card_open else 0.0
	_list_k = 1.0 if list_open else 0.0
	_place()


# ------------------------------------------------------------------ where things are
func _sheet_shift() -> Vector2:
	return Gfx.SHEET.position - SHEET_HOME


func _card_shift() -> Vector2:
	return Gfx.RECORD.position - CARD_HOME


func in_record(pos: Vector2) -> bool:
	return card_open and Gfx.RECORD.has_point(pos)


func in_sheet(pos: Vector2) -> bool:
	return sheet_open and Gfx.SHEET.has_point(pos)


func in_list(pos: Vector2) -> bool:
	return list_open and Gfx.SHEET.has_point(pos)


## The tab that puts the sheet back, on the screen.
func sheet_tab() -> Rect2:
	return Rect2(Gfx.SHEET.end.x, Gfx.SHEET.position.y + TAB_DROP, TAB.x, TAB.y)


## The list comes down into the sheet's place, so its tab is where the sheet's is.
func list_tab() -> Rect2:
	return sheet_tab()


## Under the tab of the sheet or the list: the tab that trades the one that is down for the other.
func swap_tab() -> Rect2:
	return Rect2(Gfx.SHEET.end.x, Gfx.SHEET.position.y + TAB_DROP + TAB.y + 4.0, TAB.x, TAB.y)


func card_tab() -> Rect2:
	return Rect2(Gfx.RECORD.position.x - TAB.x, Gfx.RECORD.position.y + TAB_DROP, TAB.x, TAB.y)


## "sheet", "list" or "card" if the pointer is on the tab of a paper that is out, "swap" on the
## tab that trades the sheet and the list, else "".
func tab_at(pos: Vector2) -> String:
	if list_open and list_tab().has_point(pos):
		return "list"
	if sheet_open and sheet_tab().has_point(pos):
		return "sheet"
	if (list_open or sheet_open) and swap_tab().has_point(pos):
		return "swap"
	if card_open and card_tab().has_point(pos):
		return "card"
	return ""


## The record row under the pointer, or "".
func record_row_at(pos: Vector2) -> String:
	if not in_record(pos):
		return ""
	var i := int(floor((pos.y - _card_shift().y - REC_ROW_Y) / REC_ROW_H))
	if i < 0 or i >= ROWS.size():
		return ""
	return str(ROWS[i])


func sheet_row_at(pos: Vector2) -> String:
	if not in_sheet(pos):
		return ""
	var i := int(floor((pos.y - _sheet_shift().y - SHEET_ROW_Y) / SHEET_ROW_H))
	if i < 0 or i >= ROWS.size():
		return ""
	return str(ROWS[i])


## The row whose mark box is under the pointer (the whole left column counts), or "".
func mark_at(pos: Vector2) -> String:
	var x := pos.x - _card_shift().x
	if mode != "exam" or x < 406.0 or x >= 446.0:
		return ""
	return record_row_at(pos)


## The middle of a row's mark box, on the screen.
func mark_point(row: String) -> Vector2:
	var i := maxi(0, ROWS.find(row))
	return Vector2(416.0, REC_ROW_Y + REC_ROW_H * float(i) + 18.0) + _card_shift()


## The decision box of the card, on the screen: where a stamp comes down.
func decision_rect() -> Rect2:
	return Rect2(DECISION.position + _card_shift(), DECISION.size)


## How an entry of tonight's list stands: "picked" (its package came over the counter
## tonight), "missed" (its courier came and went without it) or "".
func entry_mark(id: String) -> String:
	var mark := str(contact_marks.get(id, ""))
	if mark == "" and visit != null and visit.dropped and str(visit.contact.get("id", "")) == id:
		mark = "picked"
	return mark


## Whether the SAY button of an entry is there to press: during the exam, for an entry still
## open, a code this visitor has not heard yet, and no package over the counter this visit.
func can_say(id: String) -> bool:
	if mode != "exam" or visit == null or not visit.in_exam() or visit.dropped:
		return false
	return entry_mark(id) == "" and not visit.codes_tried.has(id)


## The SAY button of entry i, on the screen, with the list all the way out.
func say_rect(i: int) -> Rect2:
	var at := Vector2(LIST_RIGHT - SAY_SIZE.x, LIST_ENTRY_Y + LIST_ENTRY_H * float(i) - 1.0)
	return Rect2(Gfx.SHEET.position + at, SAY_SIZE)


## The entry id whose SAY button is under the pointer and can be pressed, or "".
func say_at(pos: Vector2) -> String:
	if not in_list(pos) or _list_k < 1.0:
		return ""
	for i in mini(contacts.size(), LIST_MAX):
		var id := str((contacts[i] as Dictionary).get("id", ""))
		if say_rect(i).grow(1.0).has_point(pos) and can_say(id):
			return id
	return ""


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	_t += delta
	_imprint_t += delta
	for k in _fresh.keys():
		_fresh[k] = float(_fresh[k]) + delta
	var step := delta / SLIDE_TIME
	_sheet_k = move_toward(_sheet_k, 1.0 if sheet_open else 0.0, step)
	_card_k = move_toward(_card_k, 1.0 if card_open else 0.0, step)
	_list_k = move_toward(_list_k, 1.0 if list_open else 0.0, step)
	_place()
	if _sheet_n.visible:
		_sheet_n.queue_redraw()
	if _list_n.visible:
		_list_n.queue_redraw()
	if _card_n.visible:
		_card_n.queue_redraw()


func _place() -> void:
	# a paper leaves fast and settles gently
	var sk := 1.0 - (1.0 - _sheet_k) * (1.0 - _sheet_k)
	var ck := 1.0 - (1.0 - _card_k) * (1.0 - _card_k)
	_sheet_n.visible = _sheet_k > 0.0
	_sheet_n.position = _sheet_shift() + Vector2(-roundf(SLIDE * (1.0 - sk)), 0.0)
	_card_n.visible = _card_k > 0.0
	_card_n.position = _card_shift() + Vector2(roundf(SLIDE * (1.0 - ck)), 0.0)
	var lk := 1.0 - (1.0 - _list_k) * (1.0 - _list_k)
	_list_n.visible = _list_k > 0.0
	_list_n.position = Gfx.SHEET.position + Vector2(-roundf(SLIDE * (1.0 - lk)), 0.0)


# ------------------------------------------------------------------ drawing
## A tab on the edge of a paper, with an arrow that points back to the wall it came from.
func _draw_tab(node: Node2D, at: Vector2, to_left: bool, hot: bool) -> void:
	var r := Rect2(at, TAB)
	node.draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.35))
	node.draw_rect(r, Gfx.PAPER3 if hot else Gfx.PAPER2)
	node.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Gfx.PAPER1)
	node.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1), Gfx.PAPER1)
	node.draw_rect(Rect2(r.end.x - 1.0 if to_left else r.position.x, r.position.y, 1, r.size.y), Gfx.PAPER1)
	var col: Color = Gfx.INKT if hot else Gfx.INKS
	var cx := r.position.x + 6.0
	var cy := r.position.y + 12.0
	for i in 4:      # a small arrowhead, a column at a time
		var x := cx - 2.0 + float(i) if to_left else cx + 1.0 - float(i)
		node.draw_rect(Rect2(x, cy - float(i), 1, 1.0 + 2.0 * float(i)), col)


## The swap tab under the left-hand paper's own: the key letter of the paper it brings down.
func _draw_swap(node: Node2D, at: Vector2, key: String, hot: bool) -> void:
	var r := Rect2(at, TAB)
	node.draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.35))
	node.draw_rect(r, Gfx.PAPER3 if hot else Gfx.PAPER2)
	node.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Gfx.PAPER1)
	node.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1), Gfx.PAPER1)
	node.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1, r.size.y), Gfx.PAPER1)
	Gfx.text_center(node, r.position.x + r.size.x / 2.0, r.position.y + 7.0, key, Gfx.INKT if hot else Gfx.INKS, true)


func _draw_sheet_paper() -> void:
	var n := _sheet_n
	var sheet_tex := Gfx.tex("clinic/sheet.png")
	if sheet_tex != null:
		n.draw_texture(sheet_tex, SHEET_HOME)
	_draw_tab(n, SHEET_HOME + Vector2(Gfx.SHEET.size.x, TAB_DROP), true, tab_hover == "sheet")
	_draw_swap(n, SHEET_HOME + Vector2(Gfx.SHEET.size.x, TAB_DROP + TAB.y + 4.0), "L", tab_hover == "swap")
	Gfx.text_center(n, 520.0, 18.0, str(sheet.get("title", "NORMAL REFERENCE SHEET")), Gfx.INKT, true)
	n.draw_rect(Rect2(410, 29, 220, 1), Gfx.PAPER1)
	var rows: Array = sheet.get("rows", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := SHEET_ROW_Y + SHEET_ROW_H * float(i)
		var id := str(row.get("id", ""))
		if id == highlight_row:
			n.draw_rect(Rect2(407, y - 1.0, 227, SHEET_ROW_H - 1.0), Color(Gfx.WARM6, 0.42))
		elif i > 0:
			n.draw_rect(Rect2(410, y - 2.0, 220, 1), Color(Gfx.PAPER1, 0.45))
		# the label, and under it the model this line was pulled for (case_db sheet_for)
		Gfx.text(n, Vector2(408, y), str(row.get("label", "")), Gfx.INKT, true)
		Gfx.text(n, Vector2(408, y + 10.0), str(row.get("tag", "")), Gfx.PRINT)
		Gfx.text(n, Vector2(SHEET_TEXT_X, y), str(row.get("normal", "")), Gfx.INKT)
		Gfx.text(n, Vector2(SHEET_TEXT_X, y + 10.0), SHEET_FINE, Gfx.PRINT)
		Gfx.text(n, Vector2(SHEET_TEXT_X + Gfx.text_w(SHEET_FINE) + Gfx.text_w_raw(" "), y + 10.0), str(row.get("fine", "")), Gfx.INKS)
	var fy := SHEET_ROW_Y + SHEET_ROW_H * float(rows.size())
	n.draw_rect(Rect2(410, fy - 1.0, 220, 1), Gfx.PAPER1)
	var footer: Array = sheet.get("footer", [])
	for i in footer.size():
		Gfx.text_center(n, 520.0, fy + 2.0 + 10.0 * float(i), str(footer[i]), Gfx.INKT if i == 0 else Gfx.INKS)


## Tonight's contact list, drawn in its own pixels (0, 0 is its top-left corner).
func _draw_list_paper() -> void:
	var n := _list_n
	var tex := Gfx.tex("clinic/list.png")
	if tex != null:
		n.draw_texture(tex, Vector2.ZERO)
	_draw_tab(n, Vector2(Gfx.SHEET.size.x, TAB_DROP), true, tab_hover == "list")
	_draw_swap(n, Vector2(Gfx.SHEET.size.x, TAB_DROP + TAB.y + 4.0), "R", tab_hover == "swap")
	var mid := Gfx.SHEET.size.x / 2.0
	Gfx.text_center(n, mid, 4.0, list_title, Gfx.RED1, true)
	n.draw_rect(Rect2(LIST_X, 15, LIST_RIGHT - LIST_X, 1), Gfx.RED1)
	if contacts.is_empty():
		Gfx.text_center(n, mid, 60.0, "Nobody on the list tonight.", Gfx.PRINT)
	for i in mini(contacts.size(), LIST_MAX):
		var e: Dictionary = contacts[i]
		var y := LIST_ENTRY_Y + LIST_ENTRY_H * float(i)
		if i > 0:
			n.draw_rect(Rect2(LIST_X, y - 5.0, LIST_RIGHT - LIST_X, 1), Color(Gfx.PAPER1, 0.8))
		# an alias is a code name: the same in every language
		Gfx.text_raw(n, Vector2(LIST_X, y), str(e.get("alias", "")), Gfx.INKT, true)
		var used: Array = e.get("clues", [])
		for k in used.size():
			var clue: Dictionary = clues.get(str(used[k]), {})
			Gfx.text_raw(n, Vector2(LIST_X, y + 11.0 + 10.0 * float(k)), "• " + Lang.t(str(clue.get("text", ""))), Gfx.INKT)
		Gfx.text_raw(n, Vector2(LIST_X, y + 32.0), Lang.tf("\"%s\"", [Lang.t(str(e.get("say", "")))]), Gfx.INKS)
		_draw_entry_state(i, str(e.get("id", "")), y)
	n.draw_rect(Rect2(LIST_X, LIST_FOOT_Y - 3.0, LIST_RIGHT - LIST_X, 1), Gfx.PAPER1)
	Gfx.text_center(n, mid, LIST_FOOT_Y, "Both clues fit one visitor. Say their code.", Gfx.INKT)
	Gfx.text_center(n, mid, LIST_FOOT_Y + 10.0, Lang.tf("Right one: a package, +%d, either way.", [contact_pay]), Gfx.INKS)
	Gfx.text_center(n, mid, LIST_FOOT_Y + 20.0, Lang.tf("Anyone else: a blank look, -%d patience.", [code_cost]), Gfx.INKS)


## Right of an alias: the stamp of an entry that is settled, the pencilled "blank look" of a
## code this visitor did not know, or the SAY button.
func _draw_entry_state(i: int, id: String, y: float) -> void:
	var n := _list_n
	var mark := entry_mark(id)
	if mark != "":
		var text := "PICKED UP" if mark == "picked" else "MISSED"
		var col: Color = Gfx.STAMP_G if mark == "picked" else Gfx.STAMP_R
		var w := Gfx.text_w(text, true) + 6.0
		var r := Rect2(LIST_RIGHT - w, y - 2.0, w, 13)
		n.draw_rect(r, col, false, 1.0)
		Gfx.text(n, r.position + Vector2(3, 1), text, col, true)
		return
	if mode != "exam" or visit == null or not visit.in_exam() or visit.dropped:
		return
	if visit.codes_tried.has(id):
		Gfx.text_right(n, LIST_RIGHT, y, "blank look", Gfx.PENCIL)
		return
	var r := Rect2(say_rect(i).position - Gfx.SHEET.position, SAY_SIZE)
	var hot := say_hover == id
	n.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.3))
	n.draw_rect(r, Gfx.RED2 if hot else Gfx.RED1)
	Gfx.text_center(n, r.position.x + r.size.x / 2.0, r.position.y + 1.0, "SAY", Gfx.PAPER3, true)


func _draw_card_paper() -> void:
	var n := _card_n
	var rec_tex := Gfx.tex("clinic/record.png")
	if rec_tex != null:
		n.draw_texture(rec_tex, CARD_HOME)
	_draw_tab(n, CARD_HOME + Vector2(-TAB.x, TAB_DROP), false, tab_hover == "card")
	match mode:
		"exam":
			_draw_header()
			_draw_notes()
		"findings":
			_draw_header()
			_draw_findings()
		_:
			_draw_blank()
	_draw_decision()


func _draw_blank() -> void:
	Gfx.text_center(_card_n, 520.0, 184.0, "INTAKE RECORD", Gfx.PRINT, true)
	Gfx.text_center(_card_n, 520.0, 250.0, "No patient at the counter.", Gfx.PRINT)
	Gfx.text_center(_card_n, 520.0, 262.0, "The next card goes here.", Gfx.PAPER1)


func _draw_header() -> void:
	if visit == null:
		return
	var c: Dictionary = visit.case_data
	Gfx.text(_card_n, Vector2(410, 181), str(c.get("name", "")), Gfx.INKT, true)
	Gfx.text_right(_card_n, 550.0, 181.0, Lang.tf("FEE %d", [int(c.get("fee", 0))]), Gfx.PRINT)
	Gfx.text(_card_n, Vector2(410, 191), Lang.tf("%s, %d", [Lang.t(str(c.get("role", ""))), int(c.get("age", 0))]), Gfx.INKS)
	Gfx.text(_card_n, Vector2(410, 201), Lang.tf("For: %s", [Lang.t(str(c.get("request", "")))]), Gfx.INKT)
	_card_n.draw_rect(Rect2(410, 212, 222, 1), Gfx.PAPER1)


func _row_frame(i: int, id: String) -> float:
	var y := REC_ROW_Y + REC_ROW_H * float(i)
	if id == highlight_row and mode == "exam":
		_card_n.draw_rect(Rect2(407, y, 227, REC_ROW_H - 1.0), Color(Gfx.WARM7, 0.5))
	if i > 0:
		_card_n.draw_rect(Rect2(410, y - 1.0, 222, 1), Color(Gfx.PAPER1, 0.6))
	Gfx.text(_card_n, Vector2(410, y + 1.0), str(LABELS[id]), Gfx.PRINT)
	return y


func _draw_mark(pos: Vector2, value: int, hot: bool) -> void:
	var names := ["ui/mark_blank.png", "ui/mark_tick.png", "ui/mark_cross.png"]
	var t := Gfx.tex(names[clampi(value, 0, 2)])
	if t != null:
		_card_n.draw_texture(t, pos)
	if hot:
		_card_n.draw_rect(Rect2(pos.x - 1.0, pos.y - 1.0, 13, 13), Gfx.WARM3, false, 1.0)


func _draw_notes() -> void:
	if visit == null:
		return
	var notes: Dictionary = visit.notes
	var marks: Dictionary = visit.marks
	for i in ROWS.size():
		var id := str(ROWS[i])
		var y := _row_frame(i, id)
		_draw_mark(Vector2(410, y + 13.0), int(marks.get(id, 0)), hover_mark == id)
		var list: Array = notes.get(id, [])
		# Notes nine rows apart, three to a row. Where a line fills its box (Gfx.tall_lines) two notes
		# go ten rows apart, and three, which need all 27 rows, start a row higher, clear of the rule
		# under them.
		var top := 1.0
		var step := 9.0
		if Gfx.tall_lines():
			if list.size() <= 2:
				step = 10.0
			else:
				top = 0.0
		for n in list.size():
			var note: Dictionary = list[n]
			# cut and typed in the player's language, so it is the translation that is shortened
			var text := Lang.t(str(note.get("text", "")))
			# Generated dialogue can be longer than a single record row; keep the full note in state.
			if Gfx.text_w_raw(text) > REC_TEXT_W:
				while text.length() > 0 and Gfx.text_w_raw(text + "...") > REC_TEXT_W:
					text = text.left(text.length() - 1)
				text += "..."
			var key := str(note.get("key", ""))
			var col: Color = Gfx.PENCIL
			if _fresh.has(key):
				var age: float = _fresh[key]
				var reveal := int(age * 70.0)
				if reveal < text.length():
					text = text.substr(0, reveal)
				if age < 1.6:
					col = Gfx.PENCIL.lerp(Gfx.RED1, clampf(1.0 - age / 1.6, 0.0, 1.0) * 0.6)
			Gfx.text_raw(_card_n, Vector2(REC_TEXT_X, y + top + step * float(n)), text, col)


func _draw_findings() -> void:
	var rows: Array = settlement.get("rows", [])
	for i in ROWS.size():
		var id := str(ROWS[i])
		var y := _row_frame(i, id)
		var row: Dictionary = rows[i] if i < rows.size() else {}
		_draw_mark(Vector2(410, y + 13.0), int(row.get("mark", 0)), false)
		if str(row.get("assessment", "")) == "reported":
			if Gfx.tall_lines():
				_finding_after(y, "PATIENT SAID", Gfx.INKS, Gfx.printable(Lang.t(str(row.get("text", "")))), "")
				continue
			Gfx.text(_card_n, Vector2(REC_TEXT_X, y + 1.0), "PATIENT SAID", Gfx.INKS, true)
			var wrapped := Gfx.wrap_raw(Gfx.printable(Lang.t(str(row.get("text", "")))), REC_TEXT_W)
			if wrapped.size() > 2:
				var last: String = wrapped[1]
				while Gfx.text_w_raw(last + "...") > REC_TEXT_W and last.length() > 0:
					last = last.left(last.length() - 1)
				wrapped = PackedStringArray([wrapped[0], last + "..."])
			for k in wrapped.size():
				Gfx.text_raw(_card_n, Vector2(REC_TEXT_X, y + 10.0 + 9.0 * float(k)), wrapped[k], Gfx.INKT)
			continue
		var ok := bool(row.get("ok", true))
		var truth := Gfx.tex("ui/truth_ok.png" if ok else "ui/truth_bad.png")
		if truth != null:
			_card_n.draw_texture(truth, Vector2(424, y + 13.0))
		if Gfx.tall_lines():
			_finding_after(y, "NORMAL" if ok else "BROKEN LINE", Gfx.GRN2 if ok else Gfx.RED1, Lang.t(str(row.get("text", ""))),
					"" if bool(row.get("seen", false)) else "you did not check")
			continue
		Gfx.text(_card_n, Vector2(REC_TEXT_X, y + 1.0), "NORMAL" if ok else "BROKEN LINE", Gfx.GRN2 if ok else Gfx.RED1, true)
		if not bool(row.get("seen", false)):
			Gfx.text_right(_card_n, 632.0, y + 1.0, "you did not check", Gfx.PRINT)
		Gfx.paragraph(_card_n, Vector2(REC_TEXT_X, y + 10.0), str(row.get("text", "")), REC_TEXT_W, Gfx.INKT, false, 2, 9)


## A finding where a line fills its box (Gfx.tall_lines). A label with two lines under it would
## not fit a 28-row record row, so the text starts on the label's line, after the label and
## before the note at its right end, and goes on to one line under it, cut with "..." if it
## needs more. measure_text.py checks that every case's row text fits.
func _finding_after(y: float, label: String, label_col: Color, text: String, note: String) -> void:
	Gfx.text(_card_n, Vector2(REC_TEXT_X, y + 1.0), label, label_col, true)
	var x := REC_TEXT_X + Gfx.text_w(label, true) + LABEL_GAP
	var right := REC_TEXT_X + REC_TEXT_W
	if note != "":
		Gfx.text_right(_card_n, 632.0, y + 1.0, note, Gfx.PRINT)
		right = 632.0 - Gfx.text_w(note) - LABEL_GAP
	var lines := Gfx.wrap_after(text, right - x, REC_TEXT_W)
	if lines.size() > 2:
		var last: String = lines[1]
		while last.length() > 0 and Gfx.text_w_raw(last + "...") > REC_TEXT_W:
			last = last.left(last.length() - 1)
		lines = PackedStringArray([lines[0], last + "..."])
	if lines.size() > 0:
		Gfx.text_raw(_card_n, Vector2(x, y + 1.0), lines[0], Gfx.INKT)
	if lines.size() > 1:
		Gfx.text_raw(_card_n, Vector2(REC_TEXT_X, y + 11.0), lines[1], Gfx.INKT)


func _draw_decision() -> void:
	if mode == "blank":
		return
	var n := _card_n
	var r := DECISION
	if imprint != "":
		var tex := Gfx.tex("ui/ink_%s.png" % imprint)
		if tex != null:
			var drop := clampf(1.0 - _imprint_t / 0.09, 0.0, 1.0)
			n.draw_texture(tex, Vector2(r.position.x + 1.0, r.position.y + 1.0 - roundf(drop * 3.0)))
		return
	var col: Color = Gfx.PAPER1
	var label := "DECISION"
	if armed != "":
		col = Gfx.STAMP_G if armed == "treat" else Gfx.STAMP_A
		if fmod(_t, 0.6) < 0.3:
			col = col.lightened(0.25)
		label = "STAMP HERE"
		n.draw_rect(r, Color(col, 0.16))
	# a dashed frame
	var x := r.position.x
	while x < r.end.x:
		n.draw_rect(Rect2(x, r.position.y, minf(4.0, r.end.x - x), 1), col)
		n.draw_rect(Rect2(x, r.end.y - 1.0, minf(4.0, r.end.x - x), 1), col)
		x += 7.0
	var yy := r.position.y
	while yy < r.end.y:
		n.draw_rect(Rect2(r.position.x, yy, 1, minf(4.0, r.end.y - yy)), col)
		n.draw_rect(Rect2(r.end.x - 1.0, yy, 1, minf(4.0, r.end.y - yy)), col)
		yy += 7.0
	var cx := r.position.x + r.size.x / 2.0
	var need := int(sheet.get("threshold", 0))
	if visit == null or mode != "exam" or need <= 0:
		Gfx.text_center(n, cx, r.position.y + 8.0, label, col)
		return
	# the player's own crosses against the house rule printed on the sheet: a count of their
	# marks, in their pencil. It is advice. Nothing scores it and it stops no decision.
	Gfx.text_center(n, cx, r.position.y + 3.0, label, col)
	var crossed := visit.crossed()
	var tally: Color = Gfx.PRINT
	if crossed >= need:
		tally = Gfx.RED1
	elif crossed > 0:
		tally = Gfx.STAMP_A
	Gfx.text_center(n, cx, r.position.y + 13.0, Lang.tf(TALLY, [crossed, need]), tally, crossed >= need)
