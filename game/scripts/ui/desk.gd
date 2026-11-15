extends Node2D
## The desk under the window: three felt mats with the tools, the talk cards, the TREAT stamp,
## the Trauma Team call box and the shutter lever. It only draws and reports what is under the
## pointer; the director decides what a click means.

const Gfx = preload("res://scripts/ui/gfx.gd")

const PAD_Y := 294.0
const PAD_H := 58.0
const PADS := [
	{"id": "penlight", "x": 8.0, "w": 40.0, "icon": "ui/tool_light.png", "label": "LIGHT"},
	{"id": "grip", "x": 52.0, "w": 40.0, "icon": "ui/tool_grip.png", "label": "GRIP"},
	{"id": "port", "x": 96.0, "w": 40.0, "icon": "ui/tool_port.png", "label": "PORT"},
	{"id": "ask", "x": 146.0, "w": 36.0, "icon": "ui/talk_ask.png", "label": "ASK"},
	{"id": "calm", "x": 185.0, "w": 36.0, "icon": "ui/talk_calm.png", "label": "CALM"},
	{"id": "press", "x": 224.0, "w": 36.0, "icon": "ui/talk_press.png", "label": "PRESS"},
	{"id": "treat", "x": 269.0, "w": 40.0, "icon": "ui/stamp_treat.png", "label": "TREAT"},
	# the second decision: hand the patient over to Trauma Team (the id stays "refer" in the data)
	{"id": "refer", "x": 312.0, "w": 40.0, "icon": "ui/call_team.png", "label": "TRAUMA"},
	{"id": "shutter", "x": 355.0, "w": 40.0, "icon": "ui/lever_up.png", "label": "SHUT"},
]

var hover: String = ""
var enabled: Dictionary = {}     # id -> bool (missing = enabled)
var active: String = ""          # the tool that is out of its tray
var held: String = ""            # the stamp in the player's hand
var lever_down: bool = false
var badges: Dictionary = {}      # id -> short text in the pad corner
var warn: Dictionary = {}        # id -> true: draws the label in amber (a refusal)
var pulse: String = ""           # id of a pad that should draw the eye (the shutter in danger)
var armed: String = ""           # id of a pad waiting for its second press (the open call line)

var _t: float = 0.0


func pad_at(pos: Vector2) -> String:
	if pos.y < PAD_Y or pos.y >= PAD_Y + PAD_H:
		return ""
	for p in PADS:
		var pad: Dictionary = p
		var x: float = pad["x"]
		var w: float = pad["w"]
		if pos.x >= x and pos.x < x + w:
			return str(pad["id"])
	return ""


func pad_rect(id: String) -> Rect2:
	for p in PADS:
		var pad: Dictionary = p
		if str(pad["id"]) == id:
			var x: float = pad["x"]
			var w: float = pad["w"]
			return Rect2(x, PAD_Y, w, PAD_H)
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
	var bg := Gfx.tex("clinic/desk.png")
	if bg != null:
		draw_texture(bg, Gfx.DESK.position)
	for p in PADS:
		var pad: Dictionary = p
		_draw_pad(pad)


func _draw_pad(pad: Dictionary) -> void:
	var id := str(pad["id"])
	var x: float = pad["x"]
	var w: float = pad["w"]
	var on := is_enabled(id)
	var hot := on and hover == id
	var wide := w >= 40.0
	var base := "ui/pad40" if wide else "ui/pad36"
	var throb := (pulse == id or armed == id) and fmod(_t, 0.4) < 0.2
	var pad_tex := Gfx.tex(base + ("_hot.png" if (hot or throb) else ".png"))
	if pad_tex != null:
		draw_texture(pad_tex, Vector2(x, PAD_Y), Color(1, 0.5, 0.45) if throb else Color.WHITE)
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
		draw_texture(icon, Vector2(x + floorf((w - 36.0) / 2.0), PAD_Y + 3.0 + lift), tint)
	var label := str(pad["label"])
	var col: Color = Gfx.TEAL6
	if not on:
		col = Gfx.TEAL3
	elif hot:
		col = Gfx.WARM7
	elif warn.has(id):
		col = Gfx.AMBER
	elif armed == id:
		col = Gfx.RED3
	elif out or gone:
		col = Gfx.CYAN2
	Gfx.text_center(self, x + w / 2.0, PAD_Y + 45.0, label, col)
	var badge := str(badges.get(id, ""))
	if badge != "":
		var bw := Gfx.text_w(badge) + 4.0
		var bx := x + w - bw - 1.0
		draw_rect(Rect2(bx, PAD_Y + 2.0, bw, 10.0), Gfx.INK1)
		Gfx.text(self, Vector2(bx + 2.0, PAD_Y + 2.0), badge, Gfx.AMBER if warn.has(id) else (Gfx.TEAL6 if on else Gfx.TEAL4))
