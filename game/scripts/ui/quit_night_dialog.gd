extends Node2D
## Receives input while the clinic tree is paused. The scene owns the night and the decision.
signal choice(discard: bool)
const Gfx = preload("res://scripts/ui/gfx.gd")
const STAY := Rect2(169, 191, 143, 26)
const LEAVE := Rect2(328, 191, 143, 26)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4000
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		key(event.keycode)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(event.position)


func key(code: int) -> void:
	if code in [KEY_ESCAPE, KEY_F10]:
		choice.emit(false)
	elif code in [KEY_ENTER, KEY_KP_ENTER]:
		choice.emit(true)


func click(pos: Vector2) -> void:
	if STAY.has_point(pos):
		choice.emit(false)
	elif LEAVE.has_point(pos):
		choice.emit(true)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.01, 0.04, 0.05, 0.79))
	draw_rect(Rect2(140, 111, 360, 126), Gfx.INKT)
	draw_rect(Rect2(140, 111, 360, 126), Gfx.TEAL7, false, 2)
	Gfx.big_center(self, 320, 127, "LEAVE THE CLINIC?", Gfx.WARM6)
	Gfx.text_center(self, 320, 161, "Returning to the menu loses this night.", Gfx.WARM6)
	draw_rect(STAY, Gfx.TEAL7, false, 1)
	draw_rect(LEAVE, Gfx.WARM6, false, 1)
	Gfx.text_center(self, STAY.get_center().x, 200, "ESC  KEEP PLAYING", Gfx.TEAL7, true)
	Gfx.text_center(self, LEAVE.get_center().x, 200, "ENTER  LEAVE", Gfx.WARM6, true)
