extends Node2D
## Everything on the doctor's side of the glass that can be picked up or pressed. The booth
## itself (walls, desk, the plate the controls are bolted to) is painted in clinic/booth.png
## and drawn by the clinic view; this draws what sits on it:
##   on the desk, left of the transcript: the penlight, the grip meter, the port scope
##   on the desk, right of it:            the three ways of talking
##   on the plate by the right wall:      the TREAT stamp, the Trauma Team call box, the
##                                        shutter lever and the key that orders new glass
##   pinned to the walls:                 the reference sheet and tonight's contact list
##                                        (left), the intake card on its clipboard and the
##                                        counter guide (right)
## It only draws and reports what is under the pointer; the director decides what a click means.

const Gfx = preload("res://scripts/ui/gfx.gd")

const PADS := [
	{"id": "penlight", "rect": Rect2(0, 308, 30, 52), "icon": "ui/tool_light.png", "label": "LIGHT"},
	{"id": "grip", "rect": Rect2(30, 308, 30, 52), "icon": "ui/tool_grip.png", "label": "GRIP"},
	{"id": "port", "rect": Rect2(60, 308, 30, 52), "icon": "ui/tool_port.png", "label": "PORT"},
	{"id": "ask", "rect": Rect2(521, 335, 117, 23), "icon": "ui/talk_ask.png", "label": "Listed questions"},
	{"id": "complain", "rect": Rect2(521, 310, 117, 23), "icon": "ui/talk_ask.png", "label": "What's bothering you?"},
	{"id": "press", "rect": Rect2(90, 308, 30, 52), "icon": "ui/talk_press.png", "label": "PRESS"},
	{"id": "treat", "rect": Rect2(546, 190, 40, 54), "icon": "ui/stamp_treat.png", "label": "TREAT"},
	# the second decision: hand the patient over to Trauma Team (the id stays "refer" in the data)
	{"id": "refer", "rect": Rect2(594, 190, 40, 54), "icon": "ui/call_team.png", "label": "TRAUMA"},
	{"id": "shutter", "rect": Rect2(546, 245, 40, 54), "icon": "ui/lever_up.png", "label": "SHUT"},
	# pays the glazier for one layer of the counter glass (between patients)
	{"id": "glass", "rect": Rect2(594, 245, 40, 54), "icon": "ui/tool_glass.png", "label": "GLASS"},
]
# the papers on the walls. Taken down, the sheet, the list and the card are drawn by the clipboard.
const OBJECTS := [
	{"id": "sheet", "rect": Rect2(8, 8, 80, 92), "art": "ui/obj_sheet.png"},
	{"id": "list", "rect": Rect2(8, 112, 80, 46), "art": "ui/obj_list.png"},
	{"id": "card", "rect": Rect2(546, 8, 80, 104), "art": "ui/obj_card.png"},
	{"id": "guide", "rect": Rect2(546, 128, 80, 46), "art": "ui/obj_guide.png"},
]

var hover: String = ""           # the pad or the wall object under the pointer
var enabled: Dictionary = {}     # id -> bool (missing = enabled)
var active: String = ""          # the tool that is out of its tray
var held: String = ""            # the stamp in the player's hand
var lever_down: bool = false
var badges: Dictionary = {}      # id -> short text in the corner of a pad or a wall object
var warn: Dictionary = {}        # id -> true: draws the label in amber (a refusal)
var pulse: String = ""           # id of a pad that should draw the eye (the shutter in danger)
var armed: String = ""           # id of a pad waiting for its second press (the open call line)
var taken: Dictionary = {}       # object id -> true while that paper is down from the wall
var nudge: Dictionary = {}       # object id -> true: a wall object that wants to be looked at

var _t: float = 0.0


func pad_at(pos: Vector2) -> String:
	for p in PADS:
		var pad: Dictionary = p
		var r: Rect2 = pad["rect"]
		if r.has_point(pos):
			return str(pad["id"])
	return ""


func pad_rect(id: String) -> Rect2:
	for p in PADS:
		var pad: Dictionary = p
		if str(pad["id"]) == id:
			return pad["rect"]
	return Rect2()


## The paper on the wall under the pointer: "sheet", "list", "card", "guide" or "".
func object_at(pos: Vector2) -> String:
	for o in OBJECTS:
		var obj: Dictionary = o
		var r: Rect2 = obj["rect"]
		if r.has_point(pos) and not bool(taken.get(str(obj["id"]), false)):
			return str(obj["id"])
	return ""


func object_rect(id: String) -> Rect2:
	for o in OBJECTS:
		var obj: Dictionary = o
		if str(obj["id"]) == id:
			return obj["rect"]
	return Rect2()


func is_enabled(id: String) -> bool:
	return bool(enabled.get(id, true))


func set_all(on: bool) -> void:
	for p in PADS:
		var pad: Dictionary = p
		enabled[str(pad["id"])] = on


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	Gfx.text(self, Vector2(3, 297), "TESTS", Gfx.TEAL6, true)
	Gfx.text(self, Vector2(523, 298), "TALK", Gfx.TEAL6, true)
	Gfx.text(self, Vector2(549, 178), "CALL", Gfx.TEAL6, true)
	for o in OBJECTS:
		var obj: Dictionary = o
		_draw_object(obj)
	for p in PADS:
		var pad: Dictionary = p
		_draw_pad(pad)


func _draw_object(obj: Dictionary) -> void:
	var id := str(obj["id"])
	if bool(taken.get(id, false)):
		return      # its paper is in the doctor's hands
	var r: Rect2 = obj["rect"]
	var hot := hover == id
	var art := Gfx.tex(str(obj["art"]))
	if art != null:
		draw_texture(art, r.position + Vector2(0.0, -1.0 if hot else 0.0))
	if hot:
		_corners(r.grow(1.0), Gfx.CYAN2)
	elif nudge.has(id) and fmod(_t, 0.9) < 0.5:
		_corners(r.grow(1.0), Gfx.WARM6)
	var badge := str(badges.get(id, ""))
	if badge != "":
		var bw := Gfx.text_w(badge, true) + 5.0
		var at := Vector2(r.end.x - bw + 2.0, r.position.y - 2.0)
		draw_rect(Rect2(at, Vector2(bw, 11)), Gfx.RED1)
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(bw - 2.0, 9)), Gfx.INK1)
		Gfx.text(self, at + Vector2(3, 1), badge, Gfx.WARM7, true)


## Brackets round something that can be taken off the wall.
func _corners(r: Rect2, col: Color) -> void:
	var a := 6.0
	for corner in [[r.position.x, r.position.y, 1.0, 1.0], [r.end.x, r.position.y, -1.0, 1.0],
			[r.position.x, r.end.y, 1.0, -1.0], [r.end.x, r.end.y, -1.0, -1.0]]:
		var cx: float = corner[0]
		var cy: float = corner[1]
		var sx: float = corner[2]
		var sy: float = corner[3]
		draw_rect(Rect2(minf(cx, cx + sx * a), cy if sy > 0.0 else cy - 1.0, a, 1), col)
		draw_rect(Rect2(cx if sx > 0.0 else cx - 1.0, minf(cy, cy + sy * a), 1, a), col)


func _draw_pad(pad: Dictionary) -> void:
	var id := str(pad["id"])
	var r: Rect2 = pad["rect"]
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var on := is_enabled(id)
	var hot := on and hover == id
	if id in ["ask", "complain"]:
		draw_rect(r, Gfx.TEAL3 if hot else Gfx.INK1)
		draw_rect(r, Gfx.TEAL5 if hot else Gfx.TEAL3, false, 1)
		Gfx.text_center(self, r.get_center().x, y + 6, str(pad.label), Gfx.WARM7 if on else Gfx.TEAL4)
		return
	var instrument := id in ["penlight", "grip", "port", "press"]
	var low := not instrument      # a key on the wall plate: a little shorter than a desk mat
	var base := "ui/pad_w" if low else "ui/pad40"
	var throb := (pulse == id or armed == id) and fmod(_t, 0.4) < 0.2
	var pad_tex := Gfx.tex(base + ("_hot.png" if (hot or throb) else ".png"))
	if pad_tex != null:
		draw_texture_rect(pad_tex, r, false, Color(1, 0.5, 0.45) if throb else Color.WHITE)
	var icon_path := str(pad["icon"])
	if id == "shutter" and lever_down:
		icon_path = "ui/lever_down.png"
	if id == "penlight" and active == "penlight":
		icon_path = "ui/tool_light_on.png"
	if id == "refer" and armed == "refer":
		icon_path = "ui/call_team_armed.png"
	var icon := Gfx.tex(icon_path)
	var gone := held == id            # the stamp is in the player's hand
	var out := active == id           # the tool is in use at the window
	if icon != null and not gone:
		var lift := 0.0
		if hot:
			lift = -2.0
		if out:
			lift = -4.0
		var tint := Color.WHITE
		if not on:
			tint = Color(0.45, 0.5, 0.55, 0.55)
		if instrument:
			draw_texture_rect(icon, Rect2(x + 2, y + 8 + lift, 26, 28), false, tint)
		else:
			draw_texture(icon, Vector2(x + floorf((w - 36.0) / 2.0), y + 2 + lift), tint)
	var label := "BREAK" if id == "press" and warn.get("press", false) else str(pad["label"])
	var col: Color = Gfx.TEAL6
	if not on:
		col = Gfx.TEAL3
	elif hot:
		col = Gfx.WARM7
	elif warn.get(id, false):
		col = Gfx.AMBER
	elif armed == id:
		col = Gfx.RED3
	elif out or gone:
		col = Gfx.CYAN2
	Gfx.text_center(self, x + w / 2.0, y + (42.0 if low else 38.0), label, col)
	var badge := str(badges.get(id, ""))
	if id == "press" and warn.get(id, false):
		badge = "?" if badge.contains("?") else ""
	if badge != "":
		var bw := Gfx.text_w(badge) + 4.0
		var bx := x + w - bw - 1.0
		draw_rect(Rect2(bx, y + 2.0, bw, 10.0), Gfx.INK1)
		Gfx.text(self, Vector2(bx + 2.0, y + 2.0), badge, Gfx.AMBER if warn.has(id) else (Gfx.TEAL6 if on else Gfx.TEAL4))
