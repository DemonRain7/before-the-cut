extends Node2D
## The two full-screen cards: the title over the dimmed clinic, and the end-of-shift report.
##
## The title card has a menu (student, November 20: there was no way to see where the language
## is chosen, the opening was not clear, and a player may not know that a patient can attack
## without warning): START, HOW TO PLAY (a few pages on the job, the attacks, patience and the
## till, the contacts and the keys), SETTINGS (the language, the blood, the sound and the screen)
## and QUIT. Under the menu a warning says that a patient may lunge and that SPACE drops the
## shutter. The language changes only here, on the SETTINGS page or with the switch in the
## card's top-right corner. main.gd acts on what is chosen (act_menu, act_setting and the rest).
##
## The report is where right and wrong are told (rules version 8): a page for each visit seen
## tonight, in the order they came (who it was, what the player did, what was true, and what
## each part of the patient really showed beside the player's own marks), then the night's
## totals. main.gd turns the pages (act_report_next, act_report_back, act_report_skip). On the
## totals a click starts the next night (or the same one again, after a night that was lost) and
## ESC goes back to the title card (act_report_menu).

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")

var mode: String = ""             # "" | "title" | "howto" | "settings" | "report"
var report: Dictionary = {}
var errors: Array = []            # data problems, shown on the title card
var fade: float = 0.0             # black cover, 0..1 (used between shifts and after a hit)
var page: int = 0                 # the report's page: one for each visit, then the totals
var voice: bool = false           # push-to-talk can work in this session: the title card says how
var status_line: String = ""      # what answers the doctor in this session: the patient AI or the authored patient
var hover_language: String = ""   # the language button under the pointer on the title card
var menu_index: int = 0           # the lit item of the title card's menu (MENU)
var hover_menu: String = ""       # the menu item under the pointer
var howto: Array = []             # data/intro.json "howto": the HOW TO PLAY pages
var howto_numbers: Dictionary = {}    # what "{pay}" and the like stand for in them
var howto_page: int = 0
var settings: Dictionary = {}     # what the SETTINGS page shows (main.gd _sync_settings): language, blood, volume, screen, muted
var settings_row: int = 0         # the lit row of the SETTINGS page (SETTING_ROWS)
var hover_setting: String = ""    # "row:value", or "back", under the pointer on the SETTINGS page
var help_line: String:
	get:
		return HELP_VOICE if voice else HELP

const HELP := "mouse to play   •   T types a line   •   H guide   •   SPACE drops the shutter   •   M mutes   •   F11 fullscreen"
const HELP_VOICE := "mouse   •   T types   •   hold TAB to speak   •   H guide   •   SPACE drops the shutter   •   M mutes   •   F11 fullscreen"
const SUBTITLE := "The Lanterns' back-street clinic. One counter, one night, five visitors."
const DATA_PROBLEM := "DATA PROBLEM: %s"    # the problem itself is for whoever edits the data: English
const LOGO_Y := 30.0
const SUBTITLE_Y := 150.0
# the title card's menu, top to bottom
const MENU := ["start", "howto", "settings", "quit"]
const MENU_NAMES := {"start": "START", "howto": "HOW TO PLAY", "settings": "SETTINGS", "quit": "QUIT"}
const MENU_Y := 168.0             # the first item's top
const MENU_STEP := 17.0
const MENU_W := 150.0
const MENU_H := 14.0
# under the menu: a patient can turn on the doctor with no warning, and the key that stops it
const WARNING_TITLE := "SUDDEN ATTACKS"
const WARNING := "A drifting visitor can lunge at the glass without warning. The moment a red bar starts to fill, press SPACE: the shutter drops."
const WARNING_Y := 243.0
const STATUS_Y := 284.0
# HOW TO PLAY: a panel of points under the page's title, and a picture between them on most pages
const HOWTO_PANEL := Rect2(36, 12, 568, 318)
const HOWTO_TEXT_X := 70.0        # a point's text; its bullet stands to the left of it
const HOWTO_TEXT_W := 500.0
const HOWTO_ART_Y := 60.0         # a page's picture, under its title
const HOWTO_ART_H := 50.0
const HOWTO_LINE := 11.0
const HOWTO_GAP := 5.0            # between two points
const HOWTO_ARTS := ["job", "attack", "money", "contacts"]      # the pictures _draw_howto_art draws
const HOWTO_PAGE := "%d / %d"
const HOWTO_KEYS := "click or ENTER: next   •   LEFT: back   •   ESC: the menu"
const HOWTO_LAST_KEYS := "click or ENTER: back to the menu   •   LEFT: back"
# the attack picture: a red bar like the one on the sill, the key, the lever and how it ends
const DEMO_FILL := 3.6            # seconds the picture's bar takes to fill (the real one: 1.8)
const DEMO_PRESS := 0.9           # when SPACE goes down in the picture: before the first notch
const DEMO_LOOP := 3.4
const DEMO_BLOWS := [0.3, 0.55, 0.8]
const DEMO_STOPPED := "STOPPED CLEAN: THE GLASS HOLDS"     # main.gd STOP_CLEAN_LINE, as the plate says it
# SETTINGS: a row's name, and its choices to the right of it
const SETTING_ROWS := ["language", "blood", "volume", "screen", "patient_ai", "back"]
const SETTING_NAMES := {"language": "LANGUAGE", "blood": "BLOOD", "volume": "SOUND", "screen": "SCREEN", "patient_ai": "PATIENT AI"}
const SETTING_OPTIONS := {"language": ["en", "zh"], "blood": ["full", "less"], "volume": [0, 1, 2, 3, 4],
	"screen": ["window", "fullscreen"], "patient_ai": ["off", "on"]}
const OPTION_NAMES := {"full": "FULL", "less": "LESS", "window": "WINDOW", "fullscreen": "FULL SCREEN",
	"off": "OFF", "on": "ON", "0": "OFF", "1": "25%", "2": "50%", "3": "75%", "4": "100%"}
const SETTING_HINTS := {
	"language": "Every word of the game, in this language. Kept for the next start.",
	"blood": "LESS: the attacks without blood, splatter or stains. The red flash stays.",
	"volume": "How loud the clinic is. M mutes and unmutes it at any time.",
	"screen": "F11 switches between the two at any time.",
	"patient_ai": "Choose ON to connect the patient service.",
	"back": "Back to the title card. Every change is kept for the next start.",
}
const PATIENT_HINTS := {
	"no_url": "No patient service address. Start the game with a service address to connect.",
	"checking": "Checking the patient service...",
	"connected": "Connected. The patient service will answer.",
	"mock": "Connected to the mock service. Replies are test dialogue.",
	"disabled": "The service is switched off. The scripted patient will answer.",
	"version": "Game and service versions differ. The scripted patient will answer.",
	"unreachable": "No answer from the service. The scripted patient will answer.",
}
const SETTINGS_TITLE := "SETTINGS"
const BACK := "BACK"
const MUTED_NOTE := "MUTED [M]"
const SETTINGS_KEYS := "UP / DOWN: a row   •   LEFT / RIGHT or a click: change it   •   ESC: back"
const SET_LABEL_RIGHT := 240.0    # a row's name ends here
const SET_OPTIONS_X := 256.0      # and its choices start here
const SET_Y := 84.0
const SET_STEP := 26.0
const SET_H := 14.0
const SET_GAP := 6.0              # between two choices of a row
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
# what the next click on the totals starts, by how the night went, and the keys under it
const NEXT_NIGHT := "CLICK FOR THE NEXT NIGHT"    # the line held: the debt waits another night
const TRY_AGAIN := "CLICK TO TRY AGAIN"           # under the line, or the doctor died: the night over again
const TOTALS_KEYS := "BACKSPACE: BACK   •   ESC: THE MENU"
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
	menu_index = 0
	_age = 0.0


## HOW TO PLAY, from its first page.
func show_howto() -> void:
	mode = "howto"
	howto_page = 0
	_age = 0.0


func show_settings() -> void:
	mode = "settings"
	settings_row = 0
	hover_setting = ""
	_age = 0.0


## From HOW TO PLAY or SETTINGS back to the menu, with the item that was chosen still lit.
func back_to_menu() -> void:
	mode = "title"
	hover_setting = ""
	_age = 0.0


## The title card or one of its pages.
func on_title() -> bool:
	return mode == "title" or mode == "howto" or mode == "settings"


func show_report(p_report: Dictionary) -> void:
	mode = "report"
	report = p_report
	page = 0
	_age = 0.0


func hide_all() -> void:
	mode = ""
	hover_language = ""
	hover_menu = ""
	hover_setting = ""


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


# ------------------------------------------------------------------ the menu

func menu_rect(i: int) -> Rect2:
	return Rect2(320.0 - MENU_W / 2.0, MENU_Y + MENU_STEP * float(i), MENU_W, MENU_H)


## The menu item under pos, or "" (and "" off the menu).
func menu_at(pos: Vector2) -> String:
	if mode != "title":
		return ""
	for i in MENU.size():
		if menu_rect(i).grow(1.0).has_point(pos):
			return str(MENU[i])
	return ""


func menu_item() -> String:
	return str(MENU[clampi(menu_index, 0, MENU.size() - 1)])


## The pointer is over item (or over none of them): an item it comes onto is lit, so that the
## keys go on from where the pointer is.
func hover_menu_item(item: String) -> void:
	if item != "" and item != hover_menu:
		menu_index = maxi(MENU.find(item), 0)
	hover_menu = item


## The box round the warning under the menu, wide enough for its longer line.
func warning_rect() -> Rect2:
	var w := maxf(Gfx.text_w(WARNING_TITLE, true), Gfx.text_w(WARNING)) + 20.0
	return Rect2(floorf(320.0 - w / 2.0), WARNING_Y, ceilf(w), 30.0)


# ------------------------------------------------------------------ HOW TO PLAY

func howto_count() -> int:
	return howto.size()


## Turns HOW TO PLAY by step pages. False when there is no page that way.
func turn_howto(step: int) -> bool:
	var to := howto_page + step
	if to < 0 or to >= howto.size():
		return false
	howto_page = to
	_age = 0.0
	return true


## The points of page i as they are laid out: each point's lines, its numbers put in and in the
## player's language already.
func howto_points(i: int) -> Array:
	var out: Array = []
	if i < 0 or i >= howto.size():
		return out
	for line in (howto[i] as Dictionary).get("lines", []):
		# a rule set with no price for glass has nobody to fit it: its point goes (as in the guide)
		if str(line).contains("{repair_cost}") and int(howto_numbers.get("repair_cost", 0)) <= 0:
			continue
		out.append(Gfx.wrap_raw(Gfx.fill(str(line), howto_numbers), HOWTO_TEXT_W))
	return out


## Where page i's points start, under its title and its picture.
func howto_top(i: int) -> float:
	var art := str((howto[i] as Dictionary).get("art", "")) if i >= 0 and i < howto.size() else ""
	return HOWTO_ART_Y + (HOWTO_ART_H + 8.0 if art != "" else 2.0)


## Where page i's last point ends: inside the panel, or the page has too much on it.
func howto_bottom(i: int) -> float:
	var y := howto_top(i)
	for lines in howto_points(i):
		y += HOWTO_LINE * float((lines as PackedStringArray).size()) + HOWTO_GAP
	return y - HOWTO_GAP


# ------------------------------------------------------------------ SETTINGS

## A choice as the page shows it: a language by its own name, the rest in the player's language.
func option_name(row: String, value: Variant) -> String:
	if row == "language":
		return str(Lang.NAMES.get(str(value), str(value)))
	return Lang.t(str(OPTION_NAMES.get(str(value), str(value))))


## Every button of the SETTINGS page: "row:value" -> Rect2, and "back".
func setting_rects() -> Dictionary:
	var out := {}
	for i in SETTING_ROWS.size():
		var row := str(SETTING_ROWS[i])
		var y := SET_Y + SET_STEP * float(i)
		if row == "back":
			var bw := Gfx.text_w(BACK, true) + 28.0
			out["back"] = Rect2(floorf(320.0 - bw / 2.0), y + 6.0, ceilf(bw), SET_H)
			continue
		var x := SET_OPTIONS_X
		for v in SETTING_OPTIONS[row]:
			var w := ceilf(Gfx.text_w_raw(option_name(row, v), true) + LANG_PAD * 2.0 + 4.0)
			out["%s:%s" % [row, str(v)]] = Rect2(x, y, w, SET_H)
			x += w + SET_GAP
	return out


## The button under pos on the SETTINGS page, or "".
func setting_at(pos: Vector2) -> String:
	if mode != "settings":
		return ""
	var rects := setting_rects()
	for key in rects:
		if (rects[key] as Rect2).grow(1.0).has_point(pos):
			return str(key)
	return ""


func setting_row() -> String:
	return str(SETTING_ROWS[clampi(settings_row, 0, SETTING_ROWS.size() - 1)])


## The pointer is over a button of the SETTINGS page (or none): the row it comes onto is lit.
func hover_setting_item(key: String) -> void:
	if key != "" and key != hover_setting:
		settings_row = maxi(SETTING_ROWS.find(key.get_slice(":", 0)), 0)
	hover_setting = key


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	queue_redraw()


func _draw() -> void:
	if mode == "title":
		_draw_title()
	elif mode == "howto":
		_draw_howto()
	elif mode == "settings":
		_draw_settings()
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
		draw_texture(logo, Vector2(floorf((Gfx.SCREEN.x - logo.get_width()) / 2.0), LOGO_Y), Color(1, 1, 1, flicker))
	Gfx.text_center(self, 320.0, SUBTITLE_Y, SUBTITLE, Gfx.TEAL7)
	_draw_menu()
	# before anything else is read: a patient can turn on you, and SPACE is what stops it
	var box := warning_rect()
	draw_rect(box, Color(Gfx.RED1, 0.22))
	Gfx.outline(self, box, Gfx.RED2 if fmod(_t, 1.2) < 0.9 else Gfx.RED1)
	Gfx.text_center(self, 320.0, box.position.y + 4.0, WARNING_TITLE, Gfx.RED3, true)
	Gfx.text_center(self, 320.0, box.position.y + 16.0, WARNING, Gfx.WARM7)
	if not errors.is_empty():
		Gfx.text_center_raw(self, 320.0, STATUS_Y, Lang.tf(DATA_PROBLEM, [str(errors[0])]), Gfx.RED3)
	elif status_line != "":
		# who answers tonight, so nobody has to guess whether talking freely will work
		Gfx.text_center(self, 320.0, STATUS_Y, status_line, Gfx.TEAL4)
	Gfx.text_center(self, 320.0, 338.0, help_line, Gfx.TEAL3)
	_draw_languages()


## START, HOW TO PLAY, SETTINGS, QUIT: the lit one framed, with a marker that blinks beside it.
func _draw_menu() -> void:
	for i in MENU.size():
		var r := menu_rect(i)
		var item := str(MENU[i])
		var lit := i == menu_index
		if lit:
			draw_rect(r, Gfx.TEAL2)
		Gfx.outline(self, r, Gfx.TEAL6 if lit else Gfx.TEAL3)
		var ink := Gfx.WARM6 if lit else (Gfx.TEAL7 if item == hover_menu else Gfx.TEAL5)
		Gfx.text_center(self, 320.0, r.position.y + 2.0, str(MENU_NAMES[item]), ink, true)
		if lit and fmod(_t, 1.0) < 0.65:
			Gfx.text_raw(self, Vector2(r.position.x + 6.0, r.position.y + 2.0), "►", Gfx.WARM6, true)


## A page of HOW TO PLAY: its title, its picture, its points, and the keys at the foot.
func _draw_howto() -> void:
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color(Gfx.INK0, 0.94))
	if howto.is_empty():
		return
	var i := clampi(howto_page, 0, howto.size() - 1)
	var page_data: Dictionary = howto[i]
	var p := HOWTO_PANEL
	draw_rect(p, Gfx.TEAL1)
	Gfx.outline(self, p, Gfx.TEAL4)
	Gfx.text(self, p.position + Vector2(10, 7), str(MENU_NAMES["howto"]), Gfx.TEAL5, true)
	Gfx.text_right(self, p.end.x - 10.0, p.position.y + 7.0, Lang.tf(HOWTO_PAGE, [i + 1, howto.size()]), Gfx.TEAL5, true)
	Gfx.big_center(self, 320.0, p.position.y + 22.0, str(page_data.get("title", "")), Gfx.WARM6)
	var art := str(page_data.get("art", ""))
	if art != "":
		_draw_howto_art(art, Rect2(p.position.x + 10.0, HOWTO_ART_Y, p.size.x - 20.0, HOWTO_ART_H))
	var y := howto_top(i)
	for lines in howto_points(i):
		Gfx.text_raw(self, Vector2(HOWTO_TEXT_X - 10.0, y), "•", Gfx.WARM5)
		for line in lines:
			Gfx.text_raw(self, Vector2(HOWTO_TEXT_X, y), str(line), Gfx.TEAL7)      # howto_points translated it
			y += HOWTO_LINE
		y += HOWTO_GAP
	var keys := HOWTO_LAST_KEYS if i >= howto.size() - 1 else HOWTO_KEYS
	Gfx.text_center(self, 320.0, 338.0, keys, Gfx.TEAL6 if fmod(_t, 1.0) < 0.65 else Gfx.TEAL4)


## The picture of a HOW TO PLAY page, inside r.
func _draw_howto_art(art: String, r: Rect2) -> void:
	draw_rect(r, Color(Gfx.INK0, 0.6))
	var cy := r.position.y + r.size.y / 2.0
	match art:
		"job":
			# the three tools, then the two calls: TREAT and Trauma Team
			var x := 320.0 - (36.0 * 5.0 + 10.0 * 3.0 + 34.0) / 2.0
			for path in ["ui/tool_light.png", "ui/tool_grip.png", "ui/tool_port.png", "", "ui/stamp_treat.png", "ui/call_team.png"]:
				if str(path) == "":
					Gfx.text_raw(self, Vector2(x + 8.0, cy - 5.0), "►", Gfx.TEAL6, true)
					x += 34.0
					continue
				var t := Gfx.tex(str(path))
				if t != null:
					draw_texture(t, Vector2(x, floorf(cy - t.get_height() / 2.0)))
				x += 46.0
		"attack":
			_draw_demo(r)
		"money":
			# the patience lamps going out one by one, then the three talk pads
			var x := 320.0 - (16.0 * 6.0 + 20.0 + 44.0 * 3.0) / 2.0
			var lit := 6 - int(fmod(_t, 4.0))
			for k in 6:
				var pip := Gfx.tex("ui/pip_on.png" if k < lit else "ui/pip_off.png")
				if pip != null:
					draw_texture_rect(pip, Rect2(x + 16.0 * float(k), cy - 7.0, 14, 14), false)
			x += 16.0 * 6.0 + 20.0
			for path in ["ui/talk_ask.png", "ui/talk_press.png", "ui/talk_calm.png"]:
				var t := Gfx.tex(str(path))
				if t != null:
					draw_texture(t, Vector2(x, floorf(cy - t.get_height() / 2.0)))
				x += 44.0
		"contacts":
			var t := Gfx.tex("ui/obj_list.png")
			if t != null:
				draw_texture(t, Vector2(floorf(320.0 - t.get_width() / 2.0), floorf(cy - t.get_height() / 2.0)))


## The attack in small, over and over: the red bar fills, SPACE goes down before the first
## notch, the lever on the right wall drops with it, and the bar's plate says the glass held.
func _draw_demo(r: Rect2) -> void:
	var t := fmod(_t, DEMO_LOOP)
	var pressed := t >= DEMO_PRESS and t < DEMO_LOOP - 0.5
	var bar := Rect2(320.0 - 103.0, r.position.y + 8.0, 207.0, 10.0)
	draw_rect(bar, Gfx.INK0)
	if pressed:
		Gfx.outline(self, bar, Gfx.GRN3)
		Gfx.text_center(self, 320.0, bar.position.y, DEMO_STOPPED, Gfx.GRN4, true)
	else:
		var k := clampf(t / DEMO_FILL, 0.0, 1.0) if t < DEMO_PRESS else 0.0
		var inner := Rect2(bar.position + Vector2(1, 1), bar.size - Vector2(2, 2))
		draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * k), inner.size.y)), Gfx.RED1)
		for at in DEMO_BLOWS:
			var bx := inner.position.x + roundf(inner.size.x * float(at))
			draw_rect(Rect2(bx - 1.0, inner.position.y, 2, inner.size.y), Gfx.AMBER)
		draw_rect(Rect2(inner.end.x - 3.0, inner.position.y, 3, inner.size.y), Gfx.RED2)
		var hot := t < DEMO_PRESS and fmod(_t, 0.16) < 0.08
		Gfx.outline(self, bar, Gfx.RED3 if hot else Gfx.RED2)
	var key := Rect2(320.0 - 36.0, bar.end.y + 8.0, 72.0, 16.0)
	draw_rect(key.grow(1.0), Gfx.INK0)
	var top := 2.0 if pressed else 0.0
	draw_rect(Rect2(key.position + Vector2(0, top), key.size - Vector2(0, 2)), Gfx.WARM6 if pressed else Gfx.TEAL3)
	Gfx.text_center_raw(self, 320.0, key.position.y + 3.0 + top, "SPACE", Gfx.INKT if pressed else Gfx.TEAL7, true)
	var lever := Gfx.tex("ui/lever_down.png" if pressed else "ui/lever_up.png")
	if lever != null:
		draw_texture(lever, Vector2(bar.end.x + 24.0, floorf(r.position.y + (r.size.y - lever.get_height()) / 2.0)))


func setting_hint() -> String:
	var row := setting_row()
	if row == "patient_ai":
		return str(PATIENT_HINTS.get(settings.get("patient_status", "off"), SETTING_HINTS.patient_ai))
	return str(SETTING_HINTS.get(row, ""))


## The settings rows and BACK: the lit row has a marker, the value in use is lit,
## and what the lit row does is said under them.
func _draw_settings() -> void:
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Color(Gfx.INK0, 0.94))
	var p := Rect2(110, 22, 420, 290)
	draw_rect(p, Gfx.TEAL1)
	Gfx.outline(self, p, Gfx.TEAL4)
	Gfx.big_center(self, 320.0, p.position.y + 12.0, SETTINGS_TITLE, Gfx.WARM6)
	var rects := setting_rects()
	for i in SETTING_ROWS.size():
		var row := str(SETTING_ROWS[i])
		var lit := i == settings_row
		var y := SET_Y + SET_STEP * float(i)
		if row == "back":
			var b: Rect2 = rects["back"]
			if lit:
				draw_rect(b, Gfx.TEAL2)
			Gfx.outline(self, b, Gfx.TEAL6 if lit or hover_setting == "back" else Gfx.TEAL3)
			Gfx.text_center(self, b.position.x + b.size.x / 2.0, b.position.y + 2.0, BACK, Gfx.WARM6 if lit else Gfx.TEAL6, true)
			continue
		if lit:
			draw_rect(Rect2(p.position.x + 8.0, y - 3.0, p.size.x - 16.0, SET_H + 6.0), Color(Gfx.TEAL2, 0.7))
			if fmod(_t, 1.0) < 0.65:
				Gfx.text_raw(self, Vector2(p.position.x + 14.0, y + 2.0), "►", Gfx.WARM6, true)
		Gfx.text_right(self, SET_LABEL_RIGHT, y + 2.0, str(SETTING_NAMES[row]), Gfx.WARM6 if lit else Gfx.TEAL6, true)
		var current := str(settings.get(row, ""))
		for v in SETTING_OPTIONS[row]:
			var key := "%s:%s" % [row, str(v)]
			var r: Rect2 = rects[key]
			var on := str(v) == current
			var hot := key == hover_setting and not on
			if on:
				draw_rect(r, Gfx.TEAL3)
			Gfx.outline(self, r, Gfx.TEAL7 if on else (Gfx.TEAL6 if hot else Gfx.TEAL3))
			var ink := Gfx.WARM6 if on else (Gfx.TEAL7 if hot else Gfx.TEAL5)
			Gfx.text_center_raw(self, r.position.x + r.size.x / 2.0, r.position.y + 2.0, option_name(row, v), ink, true)
		if row == "volume" and bool(settings.get("muted", false)):
			var last: Rect2 = rects["volume:4"]
			Gfx.text(self, Vector2(last.end.x + 8.0, y + 2.0), MUTED_NOTE, Gfx.RED3, true)
	var hy := SET_Y + SET_STEP * float(SETTING_ROWS.size()) + 14.0
	for line in Gfx.wrap_text(setting_hint(), p.size.x - 40.0):
		Gfx.text_center_raw(self, 320.0, hy, line, Gfx.TEAL6)      # wrap_text translated it
		hy += HOWTO_LINE
	Gfx.text_center(self, 320.0, 338.0, SETTINGS_KEYS, Gfx.TEAL4)


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
	if int(visit.get("press_bonus", 0)) > 0:
		Gfx.text_center_raw(self, mid, y, Lang.tf("Shutter catch bonus +%d", [visit.press_bonus]), Gfx.PRINT)
		y += 10.0
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
	if row.get("complained", false):
		Gfx.text(self, Vector2(x0 + 43, y + 1), "?", Gfx.WARM3, true)
	var mark := Gfx.tex(str(MARKS[clampi(int(row.get("mark", 0)), 0, 2)]))
	if mark != null:
		draw_texture(mark, Vector2(x0 + 50.0, y))
	var x := x0 + FINDING_X
	var ok := bool(row.get("ok", true))
	var truth := Gfx.tex("ui/truth_ok.png" if ok else "ui/truth_bad.png")
	if truth != null:
		draw_texture(truth, Vector2(x0 + 64.0, y))
	var detail := Lang.t(str(row.get("text", "")))
	var status := "tested" if row.get("tested", false) else ("" if row.get("seen", false) else "you did not check")  # [shown]
	if row.has("show_with"):
		detail = Lang.tf("Shown by %s", [row.show_with])
		if row.get("other_question", false):
			status = "asked, but not about this"
	var label := "WEAR" if row.get("wear", false) else ("NORMAL" if ok else "BROKEN LINE")
	_finding_text(x, x1, y, label, Gfx.GRN2 if ok else Gfx.RED1, detail, status)


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
	y += 11.0
	if not visits.is_empty() and not visits[0].get("usage", {}).is_empty():
		var totals := [0, 0, 0, 0, 0]
		var tools := ["penlight", "grip", "port", "ask", "press"]
		for record in visits:
			for i in tools.size():
				totals[i] += int(record.get("usage", {}).get(tools[i], false))
		Gfx.text_center_raw(self, 320, y, Lang.tf("LIGHT %d  GRIP %d  PORT %d  ASK %d  PRESS %d", totals), Gfx.PRINT)
		y += 10.0
		Gfx.text_center_raw(self, 320, y, Lang.tf("You followed %d of %d complaints.", [report.complaints_followed, report.complaints_told]), Gfx.PRINT)
		y += 12.0
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
	# what a click starts: another night if the line held, the night over again if it did not.
	# ESC is the way back to the title card's menu (main.gd: act_report_menu).
	if _age > 0.8 and fmod(_t, 1.0) < 0.65:
		Gfx.text_center(self, 320.0, p.end.y - 28.0, NEXT_NIGHT if held else TRY_AGAIN, Gfx.RED1, true)
	Gfx.text_center(self, 320.0, p.end.y - 16.0, TOTALS_KEYS, Gfx.INKS)


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
