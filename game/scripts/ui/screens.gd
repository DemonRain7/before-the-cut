extends Node2D
## The two full-screen cards: the title over the dimmed clinic, and the end-of-shift report.

const Gfx = preload("res://scripts/ui/gfx.gd")

var mode: String = ""             # "" | "title" | "report"
var report: Dictionary = {}
var errors: Array = []            # data problems, shown on the title card
var fade: float = 0.0             # black cover, 0..1 (used between shifts and after a hit)
var voice: bool = false           # push-to-talk can work in this session: the title card says how
var help_line: String:
	get:
		return HELP_VOICE if voice else HELP

const HELP := "mouse to play   •   T types a line   •   SPACE drops the shutter   •   M mutes   •   F11 fullscreen"
const HELP_VOICE := "mouse   •   T types   •   hold TAB to speak   •   SPACE drops the shutter   •   M mutes   •   F11 fullscreen"

var _t: float = 0.0
var _age: float = 0.0


func show_title() -> void:
	mode = "title"
	_age = 0.0


func show_report(p_report: Dictionary) -> void:
	mode = "report"
	report = p_report
	_age = 0.0


func hide_all() -> void:
	mode = ""


func age() -> float:
	return _age


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
	var logo := Gfx.tex("ui/logo.png")
	if logo != null:
		var flicker := 1.0
		if int(_t * 20.0) % 53 == 0 or int(_t * 20.0) % 97 == 1:
			flicker = 0.6
		draw_texture(logo, Vector2(floorf((Gfx.SCREEN.x - logo.get_width()) / 2.0), 48), Color(1, 1, 1, flicker))
	var y := 176.0
	Gfx.text_center(self, 320.0, y, "A back-street implant clinic. One counter, one night, five patients.", Gfx.TEAL7)
	y += 18.0
	for line in [
		"Compare each patient with the reference sheet on your clipboard.",
		"Look, test and talk in any order, as much or as little as you like.",
		"Then decide: TREAT the steady, call TRAUMA TEAM on the drifting.",
		"If one turns on you, drop the shutter.",
	]:
		Gfx.text_center(self, 320.0, y, line, Gfx.TEAL5)
		y += 12.0
	if not errors.is_empty():
		y += 6.0
		Gfx.text_center(self, 320.0, y, "DATA PROBLEM: " + str(errors[0]), Gfx.RED3)
	if fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, 320.0, 290.0, "CLICK TO OPEN THE COUNTER", Gfx.WARM6, true)
	Gfx.text_center(self, 320.0, 338.0, help_line, Gfx.TEAL3)


func _draw_report() -> void:
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color(Gfx.INK0, 0.82))
	var p := Rect2(120, 14, 400, 332)
	draw_rect(Rect2(p.position + Vector2(3, 3), p.size), Color(0, 0, 0, 0.5))
	draw_rect(p, Gfx.PAPER3)
	draw_rect(p, Gfx.PAPER1, false, 1.0)
	var x0 := p.position.x + 16.0
	var x1 := p.end.x - 16.0
	Gfx.big_center(self, 320.0, p.position.y + 10.0, "END OF SHIFT", Gfx.INKT)
	draw_rect(Rect2(x0, p.position.y + 36.0, x1 - x0, 1), Gfx.PAPER1)
	var visits: Array = report.get("visits", [])
	var y := p.position.y + 42.0
	for v in visits:
		var visit: Dictionary = v
		var ok := bool(visit.get("correct", false))
		var mark := Gfx.tex("ui/truth_ok.png" if ok else "ui/truth_bad.png")
		if mark != null:
			draw_texture(mark, Vector2(x0, y))
		Gfx.text(self, Vector2(x0 + 16.0, y), str(visit.get("name", "")), Gfx.INKT, true)
		Gfx.text(self, Vector2(x0 + 110.0, y), str(visit.get("title", "")), Gfx.GRN2 if ok else Gfx.RED1)
		Gfx.text_right(self, x1, y, Gfx.money(int(visit.get("credits", 0))), Gfx.INKT)
		var truth := "was steady" if str(visit.get("truth", "")) == "stable" else "was drifting"
		Gfx.text(self, Vector2(x0 + 16.0, y + 10.0), truth, Gfx.INKS)
		Gfx.text(self, Vector2(x0 + 110.0, y + 10.0), _call_text(visit), Gfx.INKS)
		y += 23.0
	y += 2.0
	draw_rect(Rect2(x0, y, x1 - x0, 1), Gfx.PAPER1)
	y += 5.0
	var total := int(report.get("total", 0))
	var rent := int(report.get("rent", 0))
	Gfx.text(self, Vector2(x0 + 16.0, y), "Till", Gfx.INKT)
	Gfx.text_right(self, x1, y, str(total), Gfx.INKT)
	y += 11.0
	Gfx.text(self, Vector2(x0 + 16.0, y), "Rent due", Gfx.INKT)
	Gfx.text_right(self, x1, y, str(-rent), Gfx.INKT)
	y += 11.0
	var left := total - rent
	Gfx.text(self, Vector2(x0 + 16.0, y), "Left over" if left >= 0 else "Short", Gfx.INKT, true)
	Gfx.text_right(self, x1, y, str(left), Gfx.GRN2 if left >= 0 else Gfx.RED1, true)
	y += 16.0
	draw_rect(Rect2(x0, y, x1 - x0, 1), Gfx.PAPER1)
	y += 8.0
	Gfx.big_center(self, 320.0, y, str(report.get("title", "")), Gfx.INKT)
	y += 26.0
	for line in Gfx.wrap_text(str(report.get("text", "")), x1 - x0 - 16.0):
		Gfx.text_center(self, 320.0, y, line, Gfx.INKT)
		y += 11.0
	# what the till means for tomorrow, said in words as well as in the figures above
	var rent_line := str(report.get("rent_text", ""))
	if rent_line != "":
		y += 3.0
		Gfx.text_center(self, 320.0, y, rent_line, Gfx.GRN2 if bool(report.get("rent_paid", false)) else Gfx.RED1)
		y += 11.0
	y += 4.0
	var tally := "Right calls: %d of %d" % [int(report.get("correct", 0)), int(report.get("count", 0))]
	var injuries := int(report.get("injuries", 0))
	if injuries > 0:
		tally += "   •   Times you were hurt: %d" % injuries
	Gfx.text_center(self, 320.0, y, tally, Gfx.INKS)
	if _age > 0.8 and fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, 320.0, p.end.y - 16.0, "CLICK FOR A NEW SHIFT", Gfx.RED1, true)


func _call_text(visit: Dictionary) -> String:
	match str(visit.get("outcome", "")):
		"treated_ok", "treated_drifting":
			return "you treated"
		"referred_stable", "referred_drifting":
			return "you called Trauma Team"
		"caught":
			return "you shut it in time"
		"hit":
			return "you were too slow"
		"locked_out", "false_alarm":
			return "you dropped the shutter"
		"walkout":
			return "they walked out"
	return ""
