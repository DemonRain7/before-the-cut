extends Node2D
## The clipboard on the right: the normal reference sheet on top, the patient's intake
## record below. The record mirrors the five sheet lines. Notes land on it as the player
## looks, tests and talks; nothing on it says "normal" or "abnormal" until the visit is over.

const Gfx = preload("res://scripts/ui/gfx.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")

const ROWS := ["eyes", "hands", "port", "speech", "temper"]
const LABELS := {"eyes": "EYES", "hands": "HANDS", "port": "PORT", "speech": "SPEECH", "temper": "TEMPER"}

const SHEET_ROW_Y := 32.0
const SHEET_ROW_H := 22.0
const SHEET_TEXT_X := 451.0
const REC_ROW_Y := 214.0
const REC_ROW_H := 28.0
const REC_TEXT_X := 448.0
const REC_TEXT_W := 186.0
const DECISION := Rect2(554, 182, 78, 26)

var sheet: Dictionary = {}
var visit: VisitState = null      # the patient at the counter, or null
var mode: String = "blank"        # "blank" | "exam" | "findings"
var settlement: Dictionary = {}
var imprint: String = ""          # "", "treat", "refer" (the Trauma Team dispatch mark), "void"
var armed: String = ""            # the stamp in the player's hand
var highlight_row: String = ""
var hover_mark: String = ""
var counter_text: String = ""     # "2 / 5"

var _fresh: Dictionary = {}       # note key -> seconds since it was written
var _imprint_t: float = 9.0
var _t: float = 0.0


func set_visit(p_visit: VisitState, p_counter: String) -> void:
	visit = p_visit
	counter_text = p_counter
	mode = "exam" if p_visit != null else "blank"
	settlement = {}
	imprint = ""
	armed = ""
	_fresh.clear()
	queue_redraw()


func show_findings(p_settlement: Dictionary) -> void:
	settlement = p_settlement
	mode = "findings"
	queue_redraw()


func stamp(kind: String) -> void:
	imprint = kind
	_imprint_t = 0.0
	armed = ""


func mark_fresh(key: String) -> void:
	_fresh[key] = 0.0


func in_record(pos: Vector2) -> bool:
	return Gfx.RECORD.has_point(pos)


func in_sheet(pos: Vector2) -> bool:
	return Gfx.SHEET.has_point(pos)


## The record row under the pointer, or "".
func record_row_at(pos: Vector2) -> String:
	if not in_record(pos):
		return ""
	var i := int(floor((pos.y - REC_ROW_Y) / REC_ROW_H))
	if i < 0 or i >= ROWS.size():
		return ""
	return str(ROWS[i])


func sheet_row_at(pos: Vector2) -> String:
	if not in_sheet(pos):
		return ""
	var i := int(floor((pos.y - SHEET_ROW_Y) / SHEET_ROW_H))
	if i < 0 or i >= ROWS.size():
		return ""
	return str(ROWS[i])


## The row whose mark box is under the pointer (the whole left column counts), or "".
func mark_at(pos: Vector2) -> String:
	if mode != "exam" or pos.x < 406.0 or pos.x >= 446.0:
		return ""
	return record_row_at(pos)


func _process(delta: float) -> void:
	_t += delta
	_imprint_t += delta
	for k in _fresh.keys():
		_fresh[k] = float(_fresh[k]) + delta
	queue_redraw()


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var board := Gfx.tex("clinic/board.png")
	if board != null:
		draw_texture(board, Gfx.BOARD.position)
	var sheet_tex := Gfx.tex("clinic/sheet.png")
	if sheet_tex != null:
		draw_texture(sheet_tex, Gfx.SHEET.position)
	_draw_sheet()
	var clip := Gfx.tex("clinic/clip.png")
	if clip != null:
		draw_texture(clip, Vector2(488, 0))
	var rec_tex := Gfx.tex("clinic/record.png")
	if rec_tex != null:
		draw_texture(rec_tex, Gfx.RECORD.position)
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


func _draw_sheet() -> void:
	Gfx.text_center(self, 520.0, 18.0, str(sheet.get("title", "NORMAL REFERENCE SHEET")), Gfx.INKT, true)
	draw_rect(Rect2(410, 29, 220, 1), Gfx.PAPER1)
	var rows: Array = sheet.get("rows", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := SHEET_ROW_Y + SHEET_ROW_H * float(i)
		var id := str(row.get("id", ""))
		if id == highlight_row:
			draw_rect(Rect2(407, y - 1.0, 227, SHEET_ROW_H - 1.0), Color(Gfx.WARM6, 0.42))
		elif i > 0:
			draw_rect(Rect2(410, y - 2.0, 220, 1), Color(Gfx.PAPER1, 0.45))
		Gfx.text(self, Vector2(408, y), str(row.get("label", "")), Gfx.INKT, true)
		Gfx.text(self, Vector2(SHEET_TEXT_X, y), str(row.get("normal", "")), Gfx.INKT)
		Gfx.text_right(self, SHEET_TEXT_X - 3.0, y + 10.0, "fine:", Gfx.PRINT)
		Gfx.text(self, Vector2(SHEET_TEXT_X, y + 10.0), str(row.get("ordinary", "")), Gfx.INKS)
	var fy := SHEET_ROW_Y + SHEET_ROW_H * float(rows.size())
	draw_rect(Rect2(410, fy - 1.0, 220, 1), Gfx.PAPER1)
	var footer: Array = sheet.get("footer", [])
	for i in footer.size():
		Gfx.text_center(self, 520.0, fy + 2.0 + 10.0 * float(i), str(footer[i]), Gfx.INKT if i == 0 else Gfx.INKS)


func _draw_blank() -> void:
	Gfx.text_center(self, 520.0, 184.0, "INTAKE RECORD", Gfx.PRINT, true)
	Gfx.text_center(self, 520.0, 250.0, "No patient at the counter.", Gfx.PRINT)
	Gfx.text_center(self, 520.0, 262.0, "The next card goes here.", Gfx.PAPER1)


func _draw_header() -> void:
	if visit == null:
		return
	var c: Dictionary = visit.case_data
	Gfx.text(self, Vector2(410, 181), str(c.get("name", "")), Gfx.INKT, true)
	Gfx.text_right(self, 550.0, 181.0, "FEE %d" % int(c.get("fee", 0)), Gfx.PRINT)
	Gfx.text(self, Vector2(410, 191), "%s, %d" % [str(c.get("role", "")), int(c.get("age", 0))], Gfx.INKS)
	Gfx.text(self, Vector2(410, 201), "For: " + str(c.get("request", "")), Gfx.INKT)
	draw_rect(Rect2(410, 212, 222, 1), Gfx.PAPER1)


func _row_frame(i: int, id: String) -> float:
	var y := REC_ROW_Y + REC_ROW_H * float(i)
	if id == highlight_row and mode == "exam":
		draw_rect(Rect2(407, y, 227, REC_ROW_H - 1.0), Color(Gfx.WARM7, 0.5))
	if i > 0:
		draw_rect(Rect2(410, y - 1.0, 222, 1), Color(Gfx.PAPER1, 0.6))
	Gfx.text(self, Vector2(410, y + 1.0), str(LABELS[id]), Gfx.PRINT)
	return y


func _draw_mark(pos: Vector2, value: int, hot: bool) -> void:
	var names := ["ui/mark_blank.png", "ui/mark_tick.png", "ui/mark_cross.png"]
	var t := Gfx.tex(names[clampi(value, 0, 2)])
	if t != null:
		draw_texture(t, pos)
	if hot:
		draw_rect(Rect2(pos.x - 1.0, pos.y - 1.0, 13, 13), Gfx.WARM3, false, 1.0)


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
		for n in list.size():
			var note: Dictionary = list[n]
			var text := str(note.get("text", ""))
			# Generated dialogue can be longer than a single record row; keep the full note in state.
			if Gfx.text_w(text) > REC_TEXT_W:
				while text.length() > 0 and Gfx.text_w(text + "...") > REC_TEXT_W:
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
			Gfx.text(self, Vector2(REC_TEXT_X, y + 1.0 + 9.0 * float(n)), text, col)


func _draw_findings() -> void:
	var rows: Array = settlement.get("rows", [])
	for i in ROWS.size():
		var id := str(ROWS[i])
		var y := _row_frame(i, id)
		var row: Dictionary = rows[i] if i < rows.size() else {}
		var ok := bool(row.get("ok", true))
		_draw_mark(Vector2(410, y + 13.0), int(row.get("mark", 0)), false)
		var truth := Gfx.tex("ui/truth_ok.png" if ok else "ui/truth_bad.png")
		if truth != null:
			draw_texture(truth, Vector2(424, y + 13.0))
		Gfx.text(self, Vector2(REC_TEXT_X, y + 1.0), "NORMAL" if ok else "BROKEN LINE", Gfx.GRN2 if ok else Gfx.RED1, true)
		if not bool(row.get("seen", false)):
			Gfx.text_right(self, 632.0, y + 1.0, "you did not check", Gfx.PRINT)
		Gfx.paragraph(self, Vector2(REC_TEXT_X, y + 10.0), str(row.get("text", "")), REC_TEXT_W, Gfx.INKT, false, 2, 9)


func _draw_decision() -> void:
	if mode == "blank":
		return
	var r := DECISION
	if imprint != "":
		var tex := Gfx.tex("ui/ink_%s.png" % imprint)
		if tex != null:
			var drop := clampf(1.0 - _imprint_t / 0.09, 0.0, 1.0)
			draw_texture(tex, Vector2(r.position.x + 1.0, r.position.y + 1.0 - roundf(drop * 3.0)))
		return
	var col: Color = Gfx.PAPER1
	var label := "DECISION"
	if armed != "":
		col = Gfx.STAMP_G if armed == "treat" else Gfx.STAMP_A
		if fmod(_t, 0.6) < 0.3:
			col = col.lightened(0.25)
		label = "STAMP HERE"
		draw_rect(r, Color(col, 0.16))
	# a dashed frame
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, minf(4.0, r.end.x - x), 1), col)
		draw_rect(Rect2(x, r.end.y - 1.0, minf(4.0, r.end.x - x), 1), col)
		x += 7.0
	var yy := r.position.y
	while yy < r.end.y:
		draw_rect(Rect2(r.position.x, yy, 1, minf(4.0, r.end.y - yy)), col)
		draw_rect(Rect2(r.end.x - 1.0, yy, 1, minf(4.0, r.end.y - yy)), col)
		yy += 7.0
	Gfx.text_center(self, r.position.x + r.size.x / 2.0, r.position.y + 8.0, label, col)
