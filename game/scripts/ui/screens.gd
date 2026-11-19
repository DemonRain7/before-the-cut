extends Node2D
## The two full-screen cards: the title over the dimmed clinic, and the end-of-shift report.
## The title card also holds the language switch: the one place the language changes.
##
## The report is where right and wrong are told (rules version 8): a page for each visit seen
## tonight, in the order they came (who it was, what the player did, what was true, and what
## each part of the patient really showed beside the player's own marks), then the night's
## totals. main.gd turns the pages (act_report_next, act_report_back, act_report_skip).

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")

var mode: String = ""             # "" | "title" | "report"
var report: Dictionary = {}
var errors: Array = []            # data problems, shown on the title card
var fade: float = 0.0             # black cover, 0..1 (used between shifts and after a hit)
var page: int = 0                 # the report's page: one for each visit, then the totals
var voice: bool = false           # push-to-talk can work in this session: the title card says how
var status_line: String = ""      # what answers the doctor in this session: the patient AI or the authored patient
var hover_language: String = ""   # the language button under the pointer on the title card
var help_line: String:
	get:
		return HELP_VOICE if voice else HELP

const HELP := "mouse to play   •   T types a line   •   H guide   •   SPACE drops the shutter   •   M mutes   •   F11 fullscreen"
const HELP_VOICE := "mouse   •   T types   •   hold TAB to speak   •   H guide   •   SPACE drops the shutter   •   M mutes   •   F11 fullscreen"
const SUBTITLE := "The Lanterns' back-street clinic. One counter, one night, five visitors."
const TITLE_LINES := [
	"Compare each visitor with the reference sheet on the wall.",
	"Look, test and talk in any order, as much or as little as you like.",
	"Then decide: TREAT the steady, call TRAUMA TEAM on the drifting.",
	"If one turns on you, drop the shutter before the glass gives.",
	"Say the code to tonight's contacts. Keep the till over the lender's line.",
]
const DATA_PROBLEM := "DATA PROBLEM: %s"    # the problem itself is for whoever edits the data: English
# the totals page
const COUNTER_ROW := "At the counter"
const CLOSING_ROW := "At closing"
const TILL_ROW := "Till"
const TILL_GLASS_ROW := "Till, after %d paid for glass"
const OVER_ROW := "Over the line by"
const UNDER_ROW := "Under the line by"
const LINE_ROW := "The line (%d hours x %d)"
const LINE_PLAIN_ROW := "The line"
const METER_ROW := "Meter, hour by hour"
const DROPS_TALLY := "Drops picked up: %d of %d (+%d)"
const TALLY_CALLS := "Right calls: %d of %d"
const TALLY_UNDER := "Hours under the line: %d"
const TALLY_GAP := "   •   "
const UNSEEN := "never came in"          # a visitor still in the hall when the night ended
const TOTALS_ROW_H := 13.0
# under a visit's figure, what in it was not the call's own (the slip's words, in small)
const VISIT_DROP := "drop +%d"
const VISIT_NO_DROP := "drop missed"
const VISIT_CALM := "calm -%d"
# a visit's page
const PAGE_OF := "VISIT %d OF %d"
const YOUR_CALL := "Your call: %s"
const CALL_NAMES := {"treat": "TREAT", "team": "TRAUMA TEAM", "shutter": "SHUTTER", "none": "NONE"}
const VISIT_MONEY := "At the counter %s   •   At closing %s   •   In all %s"
const NEXT_VISIT := "CLICK FOR THE NEXT VISIT"
const TO_TOTALS := "CLICK FOR THE TOTALS"
const PAGE_KEYS := "BACKSPACE: BACK   •   ESC: THE TOTALS"
const VISIT_TEXT_LINES := 4              # lines of outcome text (tools/art/measure_text.py reads it)
const ROW_LABELS := {"eyes": "EYES", "hands": "HANDS", "port": "PORT", "speech": "SPEECH", "temper": "TEMPER"}
const MARKS := ["ui/mark_blank.png", "ui/mark_tick.png", "ui/mark_cross.png"]
const FINDING_H := 22.0                  # a finding: its label line and one line under it
const FINDING_X := 82.0                  # from the page's left edge: the row's name, the player's mark, the truth
const FINDING_GAP := 6.0                 # between a finding's label and its text, and before the note at the right
# the language switch in the title card's top-right corner: each language by its own name
const LANG_Y := 8.0
const LANG_RIGHT := 632.0
const LANG_GAP := 4.0
const LANG_PAD := 5.0
const LANG_H := 13.0

var _t: float = 0.0
var _age: float = 0.0


func show_title() -> void:
	mode = "title"
	_age = 0.0


func show_report(p_report: Dictionary) -> void:
	mode = "report"
	report = p_report
	page = 0
	_age = 0.0


func hide_all() -> void:
	mode = ""
	hover_language = ""


## How long the card has been up, or the report's page open.
func age() -> float:
	return _age


## The report's pages: one for each visit seen tonight, then the totals.
func pages() -> int:
	return (report.get("visits", []) as Array).size() + 1


func on_summary() -> bool:
	return mode == "report" and page >= pages() - 1


## Turns the report by step pages, no further than its first page or the totals. False when it
## was already there.
func turn(step: int) -> bool:
	var to := clampi(page + step, 0, pages() - 1)
	if to == page:
		return false
	page = to
	_age = 0.0
	return true


## The language buttons on the title card, from the top-right corner leftwards, in the order of
## Lang.CODES: code -> Rect2.
func language_rects() -> Dictionary:
	var out := {}
	var right := LANG_RIGHT
	for i in range(Lang.CODES.size() - 1, -1, -1):
		var code := str(Lang.CODES[i])
		var w := Gfx.text_w_raw(str(Lang.NAMES[code]), true) + LANG_PAD * 2.0
		out[code] = Rect2(right - w, LANG_Y, w, LANG_H)
		right -= w + LANG_GAP
	return out


## The language whose button is under pos, or "" (and always "" off the title card).
func language_at(pos: Vector2) -> String:
	if mode != "title":
		return ""
	var rects := language_rects()
	for code in rects:
		if (rects[code] as Rect2).grow(2.0).has_point(pos):
			return str(code)
	return ""


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	queue_redraw()


func _draw() -> void:
	if mode == "title":
		_draw_title()
	elif mode == "report":
		_draw_report()
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))


func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color(Gfx.INK0, 0.9))
	# the sign: in Chinese its twin, ui/logo_zh.png, with the English name small underneath
	var logo := Gfx.tex("ui/logo.png")
	if logo != null:
		var flicker := 1.0
		if int(_t * 20.0) % 53 == 0 or int(_t * 20.0) % 97 == 1:
			flicker = 0.6
		draw_texture(logo, Vector2(floorf((Gfx.SCREEN.x - logo.get_width()) / 2.0), 48), Color(1, 1, 1, flicker))
	var y := 176.0
	Gfx.text_center(self, 320.0, y, SUBTITLE, Gfx.TEAL7)
	y += 18.0
	for line in TITLE_LINES:
		Gfx.text_center(self, 320.0, y, str(line), Gfx.TEAL5)
		y += 12.0
	y += 8.0
	if not errors.is_empty():
		Gfx.text_center_raw(self, 320.0, y, Lang.tf(DATA_PROBLEM, [str(errors[0])]), Gfx.RED3)
	elif status_line != "":
		# who answers tonight, so nobody has to guess whether talking freely will work
		Gfx.text_center(self, 320.0, y, status_line, Gfx.TEAL4)
	if fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, 320.0, 290.0, "CLICK TO OPEN THE COUNTER", Gfx.WARM6, true)
	Gfx.text_center(self, 320.0, 338.0, help_line, Gfx.TEAL3)
	_draw_languages()


## English | 中文: the language in use is lit, the other answers the pointer.
func _draw_languages() -> void:
	var rects := language_rects()
	for code in rects:
		var r: Rect2 = rects[code]
		var on: bool = code == Lang.code
		var hot: bool = code == hover_language and not on
		if on:
			draw_rect(r, Gfx.TEAL2)
		Gfx.outline(self, r, Gfx.TEAL6 if on or hot else Gfx.TEAL3)
		var ink := Gfx.WARM6 if on else (Gfx.TEAL7 if hot else Gfx.TEAL4)
		Gfx.text_center_raw(self, r.position.x + r.size.x / 2.0, r.position.y + 2.0, str(Lang.NAMES[code]), ink, true)


func _draw_report() -> void:
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color(Gfx.INK0, 0.82))
	var p := Rect2(120, 14, 400, 332)
	draw_rect(Rect2(p.position + Vector2(3, 3), p.size), Color(0, 0, 0, 0.5))
	draw_rect(p, Gfx.PAPER3)
	draw_rect(p, Gfx.PAPER1, false, 1.0)
	var visits: Array = report.get("visits", [])
	if page < visits.size():
		_draw_visit_page(p, visits[page], page, visits.size())
	else:
		_draw_totals(p, visits)


## One visit told in full: who it was, what the player did and what was true, how it ended,
## and what each part of the patient really showed beside the player's own mark.
func _draw_visit_page(p: Rect2, visit: Dictionary, i: int, n: int) -> void:
	var x0 := p.position.x + 16.0
	var x1 := p.end.x - 16.0
	var w := x1 - x0
	var mid := 320.0
	var y := p.position.y + 8.0
	Gfx.text(self, Vector2(x0, y), "END OF SHIFT", Gfx.INKS, true)
	Gfx.text_right(self, x1, y, Lang.tf(PAGE_OF, [i + 1, n]), Gfx.INKS)
	y += 12.0
	var patient := str(visit.get("name", ""))
	Gfx.big_center(self, mid, y, patient, Gfx.INKT)
	y += 24.0
	var who := Lang.tf("%s, %d", [Lang.t(str(visit.get("role", ""))), int(visit.get("age", 0))])
	var asked := Lang.tf("For: %s", [Lang.t(str(visit.get("request", "")))])
	Gfx.text_center_raw(self, mid, y, who + TALLY_GAP + asked, Gfx.INKS)
	y += 13.0
	draw_rect(Rect2(x0, y, w, 1), Gfx.PAPER1)
	y += 4.0
	# what the player did, and what was true all along
	var call := Lang.tf(YOUR_CALL, [Lang.t(str(CALL_NAMES.get(_call_of(visit), "NONE")))])
	Gfx.text_raw(self, Vector2(x0, y), call, Gfx.INKT, true)
	var steady := str(visit.get("truth", "")) == "stable"
	var was := Lang.tf("%s was %s.", [patient, Lang.t("STEADY" if steady else "DRIFTING")])
	Gfx.text_raw(self, Vector2(x1 - Gfx.text_w_raw(was, true), y), was, Gfx.GRN2 if steady else Gfx.RED1, true)
	y += 13.0
	var verdict := _verdict_of(visit)
	var ink := Gfx.INKS
	if verdict == "RIGHT CALL":
		ink = Gfx.GRN2
	elif verdict == "WRONG CALL":
		ink = Gfx.RED1
	Gfx.big_center(self, mid, y, verdict, ink)
	y += 24.0
	# how it ended, in the case's own words
	Gfx.text_center(self, mid, y, str(visit.get("title", "")), Gfx.INKT, true)
	y += 12.0
	var lines := Gfx.wrap_text(str(visit.get("text", "")), w - 16.0)
	for k in mini(lines.size(), VISIT_TEXT_LINES):
		Gfx.text_center_raw(self, mid, y + 11.0 * float(k), lines[k], Gfx.INKT)      # wrap_text translated it
	y += 11.0 * float(VISIT_TEXT_LINES) + 2.0
	draw_rect(Rect2(x0, y, w, 1), Gfx.PAPER1)
	y += 4.0
	for r in visit.get("rows", []):
		_draw_finding(x0, x1, y, r)
		y += FINDING_H
	draw_rect(Rect2(x0, y, w, 1), Gfx.PAPER1)
	y += 4.0
	# the visit's money: what came in at the counter, what the night's reports added or billed
	var money := Lang.tf(VISIT_MONEY, [Gfx.money(int(visit.get("counter", 0))),
		Gfx.money(int(visit.get("closing", 0))), Gfx.money(int(visit.get("credits", 0)))])
	Gfx.text_center_raw(self, mid, y, money, Gfx.INKT)
	y += 11.0
	var extra := _visit_extra(visit)
	if extra != "":
		Gfx.text_center_raw(self, mid, y, extra, Gfx.PRINT)
	if fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, mid, p.end.y - 28.0, TO_TOTALS if i + 1 >= n else NEXT_VISIT, Gfx.RED1, true)
	Gfx.text_center(self, mid, p.end.y - 16.0, PAGE_KEYS, Gfx.INKS)


## A part of the patient: its name, the player's mark, and what was there to find. A reading
## the player never took says so at the right; a patient's own words are only what they said.
func _draw_finding(x0: float, x1: float, y: float, row: Dictionary) -> void:
	var id := str(row.get("id", ""))
	Gfx.text(self, Vector2(x0, y + 1.0), str(ROW_LABELS.get(id, id)), Gfx.PRINT)
	var mark := Gfx.tex(str(MARKS[clampi(int(row.get("mark", 0)), 0, 2)]))
	if mark != null:
		draw_texture(mark, Vector2(x0 + 50.0, y))
	var x := x0 + FINDING_X
	if str(row.get("assessment", "")) == "reported":
		_finding_text(x, x1, y, "PATIENT SAID", Gfx.INKS, Gfx.printable(Lang.t(str(row.get("text", "")))), "")
		return
	var ok := bool(row.get("ok", true))
	var truth := Gfx.tex("ui/truth_ok.png" if ok else "ui/truth_bad.png")
	if truth != null:
		draw_texture(truth, Vector2(x0 + 64.0, y))
	_finding_text(x, x1, y, "NORMAL" if ok else "BROKEN LINE", Gfx.GRN2 if ok else Gfx.RED1,
		Lang.t(str(row.get("text", ""))), "" if bool(row.get("seen", false)) else "you did not check")


## The label, then the text after it on the same line and on one line under it, cut with "..."
## if it needs more (measure_text.py checks that every case's findings fit).
func _finding_text(x: float, x1: float, y: float, label: String, label_col: Color, text: String, note: String) -> void:
	Gfx.text(self, Vector2(x, y + 1.0), label, label_col, true)
	var after := x + Gfx.text_w(label, true) + FINDING_GAP
	var right := x1
	if note != "":
		Gfx.text_right(self, x1, y + 1.0, note, Gfx.PRINT)
		right = x1 - Gfx.text_w(note) - FINDING_GAP
	var lines := Gfx.wrap_after(text, right - after, x1 - x)
	if lines.size() > 2:
		var last: String = lines[1]
		while last.length() > 0 and Gfx.text_w_raw(last + "...") > x1 - x:
			last = last.left(last.length() - 1)
		lines = PackedStringArray([lines[0], last + "..."])
	if lines.size() > 0:
		Gfx.text_raw(self, Vector2(after, y + 1.0), lines[0], Gfx.INKT)
	if lines.size() > 1:
		Gfx.text_raw(self, Vector2(x, y + 11.0), lines[1], Gfx.INKT)


## The night's totals: every visit in a line, whoever never came in, the money and the line.
func _draw_totals(p: Rect2, visits: Array) -> void:
	var x0 := p.position.x + 16.0
	var x1 := p.end.x - 16.0
	Gfx.big_center(self, 320.0, p.position.y + 10.0, "END OF SHIFT", Gfx.INKT)
	draw_rect(Rect2(x0, p.position.y + 36.0, x1 - x0, 1), Gfx.PAPER1)
	var y := p.position.y + 41.0
	for v in visits:
		var visit: Dictionary = v
		var ok := bool(visit.get("correct", false))
		var mark := Gfx.tex("ui/truth_ok.png" if ok else "ui/truth_bad.png")
		if mark != null:
			draw_texture(mark, Vector2(x0, y))
		Gfx.text(self, Vector2(x0 + 16.0, y), str(visit.get("name", "")), Gfx.INKT, true)
		# a right call can still end badly: the tick is for the call, the colour for how it ended
		var hurt := str(visit.get("outcome", "")) == "hit"
		Gfx.text(self, Vector2(x0 + 110.0, y), str(visit.get("title", "")), Gfx.GRN2 if ok and not hurt else Gfx.RED1)
		Gfx.text_right(self, x1, y, Gfx.money(int(visit.get("credits", 0))), Gfx.INKT)
		y += TOTALS_ROW_H
	for who in report.get("unseen_names", []):
		Gfx.text(self, Vector2(x0 + 16.0, y), str(who), Gfx.INKS, true)
		Gfx.text(self, Vector2(x0 + 110.0, y), UNSEEN, Gfx.INKS)
		y += TOTALS_ROW_H
	y += 2.0
	draw_rect(Rect2(x0, y, x1 - x0, 1), Gfx.PAPER1)
	y += 5.0
	var total := int(report.get("total", 0))
	var line := int(report.get("line", 0))
	var died := bool(report.get("died", false))
	var held := bool(report.get("line_held", total >= line)) and not died
	# what came in at the counter through the night, what the night's reports added or billed at
	# closing, and the till once the glass is paid for: the first two less the glass make the third
	_money_row(x0, x1, y, Lang.t(COUNTER_ROW), Gfx.money(int(report.get("counter_total", 0))))
	y += 11.0
	_money_row(x0, x1, y, Lang.t(CLOSING_ROW), Gfx.money(int(report.get("closing_total", 0))))
	y += 11.0
	var glass_paid := int(report.get("repair_total", 0))
	_money_row(x0, x1, y, Lang.tf(TILL_GLASS_ROW, [glass_paid]) if glass_paid > 0 else Lang.t(TILL_ROW), str(total))
	y += 11.0
	var readings: Array = report.get("readings", [])
	if not died:
		# the till against the lender's line (nobody reads the meter for a doctor who died)
		var per_hour := 0
		if not readings.is_empty():
			per_hour = int((readings[0] as Dictionary).get("line", 0))
		var line_row := Lang.tf(LINE_ROW, [readings.size(), per_hour]) if per_hour > 0 else Lang.t(LINE_PLAIN_ROW)
		_money_row(x0, x1, y, line_row, str(line))
		y += 11.0
		Gfx.text(self, Vector2(x0 + 16.0, y), OVER_ROW if held else UNDER_ROW, Gfx.INKT, true)
		Gfx.text_right(self, x1, y, str(absi(total - line)), Gfx.GRN2 if held else Gfx.RED1, true)
		y += 11.0
	if not readings.is_empty():
		Gfx.text(self, Vector2(x0 + 16.0, y), METER_ROW, Gfx.INKS)
		var lamp := x1 - float(readings.size()) * 12.0 + 3.0
		for r in readings:
			var over := bool((r as Dictionary).get("held", true))
			draw_rect(Rect2(lamp, y + 1.0, 9, 7), Gfx.INKT)
			draw_rect(Rect2(lamp + 1.0, y + 2.0, 7, 5), Gfx.GRN3 if over else Gfx.RED2)
			lamp += 12.0
	y += 16.0
	draw_rect(Rect2(x0, y, x1 - x0, 1), Gfx.PAPER1)
	y += 8.0
	Gfx.big_center(self, 320.0, y, str(report.get("title", "")), Gfx.INKT)
	y += 26.0
	for said in Gfx.wrap_text(str(report.get("text", "")), x1 - x0 - 16.0):
		Gfx.text_center_raw(self, 320.0, y, said, Gfx.INKT)      # wrap_text translated it
		y += 11.0
	# what the meter's last reading means for tomorrow, in words as well as in the figures above
	var verdict := str(report.get("line_text", ""))
	if verdict != "":
		y += 3.0
		Gfx.text_center(self, 320.0, y, verdict, Gfx.GRN2 if held else Gfx.RED1)
		y += 11.0
	y += 4.0
	var tally := Lang.tf(TALLY_CALLS, [int(report.get("correct", 0)), visits.size()])
	var under := int(report.get("hours_under", 0))
	if under > 0:
		tally += TALLY_GAP + Lang.tf(TALLY_UNDER, [under])
	Gfx.text_center_raw(self, 320.0, y, tally, Gfx.INKS)
	# the couriers: what the night's packages did for the till, on a line of their own
	var listed := int(report.get("contacts", 0))
	if listed > 0:
		var drops := int(report.get("drops", 0))
		Gfx.text_center_raw(self, 320.0, y + 11.0, Lang.tf(DROPS_TALLY, [drops, listed, int(report.get("drop_total", 0))]),
			Gfx.GRN2 if drops > 0 else Gfx.INKS)
	if _age > 0.8 and fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, 320.0, p.end.y - 16.0, "CLICK FOR A NEW SHIFT", Gfx.RED1, true)


## A row of the totals: words already in the player's language, and a figure at the right.
func _money_row(x0: float, x1: float, y: float, label: String, figure: String) -> void:
	Gfx.text_raw(self, Vector2(x0 + 16.0, y), label, Gfx.INKT)
	Gfx.text_raw(self, Vector2(x1 - Gfx.text_w_raw(figure), y), figure, Gfx.INKT)


## Under a visit's figure: a courier's package, or the one that never came over the counter,
## and what the calm-patches cost. Empty for a visit that was only the call. In the player's
## language already.
func _visit_extra(visit: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(visit.get("dropped", false)):
		parts.append(Lang.tf(VISIT_DROP, [int(visit.get("drop", 0))]))
	elif bool(visit.get("contact", false)):
		parts.append(Lang.t(VISIT_NO_DROP))
	var calm := int(visit.get("calm_spent", 0))
	if calm > 0:
		parts.append(Lang.tf(VISIT_CALM, [calm]))
	return "   ".join(parts)


## What the player did about a visit: the call stamped on the card if there was one, else the
## shutter, or nothing (call_kind() in visit_state.gd).
func _call_of(visit: Dictionary) -> String:
	match str(visit.get("verdict", "")):
		"treat":
			return "treat"
		"refer":
			return "team"
	var call := str(visit.get("call", "none"))
	return call if CALL_NAMES.has(call) else "none"


## RIGHT CALL, WRONG CALL or NO CALL. Walking out, giving up and an attack nobody had called
## the crew for leave no call to judge.
func _verdict_of(visit: Dictionary) -> String:
	if bool(visit.get("correct", false)):
		return "RIGHT CALL"
	var outcome := str(visit.get("outcome", ""))
	if outcome == "walkout" or outcome == "gave_up" or outcome == "hit":
		return "NO CALL"
	return "WRONG CALL"
