extends Node2D
## The two full-screen cards: the title over the dimmed clinic, and the end-of-shift report.

const Gfx = preload("res://scripts/ui/gfx.gd")

var mode: String = ""             # "" | "title" | "report"
var report: Dictionary = {}
var errors: Array = []            # data problems, shown on the title card
var fade: float = 0.0             # black cover, 0..1 (used between shifts and after a hit)
var voice: bool = false           # push-to-talk can work in this session: the title card says how
var status_line: String = ""      # what answers the doctor in this session: the patient AI or the authored patient
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
const TILL_ROW := "Till"
const TILL_GLASS_ROW := "Till, after %d paid for glass"
const OVER_ROW := "Over the line by"
const UNDER_ROW := "Under the line by"
const LINE_ROW := "The line (%d hours x %d)"
const METER_ROW := "Meter, hour by hour"
const DROPS_TALLY := "Drops picked up: %d of %d (+%d)"
# under a visit's figure, what in it was not the call's own (the slip's words, in small)
const VISIT_DROP := "drop +%d"
const VISIT_NO_DROP := "drop missed"
const VISIT_CALM := "calm -%d"

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
	Gfx.text_center(self, 320.0, y, SUBTITLE, Gfx.TEAL7)
	y += 18.0
	for line in TITLE_LINES:
		Gfx.text_center(self, 320.0, y, str(line), Gfx.TEAL5)
		y += 12.0
	y += 8.0
	if not errors.is_empty():
		Gfx.text_center(self, 320.0, y, "DATA PROBLEM: " + str(errors[0]), Gfx.RED3)
	elif status_line != "":
		# who answers tonight, so nobody has to guess whether talking freely will work
		Gfx.text_center(self, 320.0, y, status_line, Gfx.TEAL4)
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
		# a right call can still end badly: the tick is for the call, the colour for how it ended
		var hurt := str(visit.get("outcome", "")) == "hit"
		Gfx.text(self, Vector2(x0 + 110.0, y), str(visit.get("title", "")), Gfx.GRN2 if ok and not hurt else Gfx.RED1)
		Gfx.text_right(self, x1, y, Gfx.money(int(visit.get("credits", 0))), Gfx.INKT)
		var truth := "was steady" if str(visit.get("truth", "")) == "stable" else "was drifting"
		Gfx.text(self, Vector2(x0 + 16.0, y + 10.0), truth, Gfx.INKS)
		Gfx.text(self, Vector2(x0 + 110.0, y + 10.0), _call_text(visit), Gfx.INKS)
		var extra := _visit_extra(visit)
		if extra != "":
			Gfx.text_right(self, x1, y + 10.0, extra, Gfx.PRINT)
		y += 23.0
	y += 2.0
	draw_rect(Rect2(x0, y, x1 - x0, 1), Gfx.PAPER1)
	y += 5.0
	# the till against the lender's line: the figures, then every hourly reading of the meter
	var total := int(report.get("total", 0))
	var line := int(report.get("line", 0))
	var held := bool(report.get("line_held", total >= line))
	var readings: Array = report.get("readings", [])
	var per_hour := 0
	if not readings.is_empty():
		per_hour = int((readings[0] as Dictionary).get("line", 0))
	# glass that was paid for is already out of this figure: the row says so, in its own words
	var glass_paid := int(report.get("repair_total", 0))
	Gfx.text(self, Vector2(x0 + 16.0, y), TILL_GLASS_ROW % glass_paid if glass_paid > 0 else TILL_ROW, Gfx.INKT)
	Gfx.text_right(self, x1, y, str(total), Gfx.INKT)
	y += 11.0
	Gfx.text(self, Vector2(x0 + 16.0, y), LINE_ROW % [readings.size(), per_hour] if per_hour > 0 else "The line", Gfx.INKT)
	Gfx.text_right(self, x1, y, str(line), Gfx.INKT)
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
		Gfx.text_center(self, 320.0, y, said, Gfx.INKT)
		y += 11.0
	# what the meter's last reading means for tomorrow, in words as well as in the figures above
	var verdict := str(report.get("line_text", ""))
	if verdict != "":
		y += 3.0
		Gfx.text_center(self, 320.0, y, verdict, Gfx.GRN2 if held else Gfx.RED1)
		y += 11.0
	y += 4.0
	var tally := "Right calls: %d of %d" % [int(report.get("correct", 0)), int(report.get("count", 0))]
	var under := int(report.get("hours_under", 0))
	if under > 0:
		tally += "   •   Hours under the line: %d" % under
	var injuries := int(report.get("injuries", 0))
	if injuries > 0:
		tally += "   •   Times you were hurt: %d" % injuries
	Gfx.text_center(self, 320.0, y, tally, Gfx.INKS)
	# the couriers: what the night's packages did for the till, on a line of their own
	var listed := int(report.get("contacts", 0))
	if listed > 0:
		var drops := int(report.get("drops", 0))
		Gfx.text_center(self, 320.0, y + 11.0, DROPS_TALLY % [drops, listed, int(report.get("drop_total", 0))],
			Gfx.GRN2 if drops > 0 else Gfx.INKS)
	if _age > 0.8 and fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, 320.0, p.end.y - 16.0, "CLICK FOR A NEW SHIFT", Gfx.RED1, true)


## Under a visit's figure: a courier's package, or the one that never came over the counter,
## and what the calm-patches cost. Empty for a visit that was only the call.
func _visit_extra(visit: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(visit.get("dropped", false)):
		parts.append(VISIT_DROP % int(visit.get("drop", 0)))
	elif bool(visit.get("contact", false)):
		parts.append(VISIT_NO_DROP)
	var calm := int(visit.get("calm_spent", 0))
	if calm > 0:
		parts.append(VISIT_CALM % calm)
	return "   ".join(parts)


func _call_text(visit: Dictionary) -> String:
	match str(visit.get("outcome", "")):
		"treated_ok", "treated_drifting":
			return "you treated"
		"referred_stable", "referred_drifting":
			return "you called Trauma Team"
		"caught":
			return "you shut it in time"
		"hit":
			return "right call, shutter too late" if bool(visit.get("correct", false)) else "you were too slow"
		"locked_out", "false_alarm":
			return "you dropped the shutter"
		"walkout":
			return "they walked out"
		"gave_up":
			return "they gave up waiting"
	return ""
