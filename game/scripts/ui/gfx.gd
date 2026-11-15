extends RefCounted
## Shared drawing helpers for the interface: palette, bitmap fonts, textures, word wrap and
## the fixed 640 x 360 screen layout.
## Used as: const Gfx = preload("res://scripts/ui/gfx.gd")

# palette (the same values as tools/art/px.py)
const INK0 := Color("07090c")
const INK1 := Color("0b1014")
const TEAL1 := Color("121c22")
const TEAL2 := Color("1a2a31")
const TEAL3 := Color("244049")
const TEAL4 := Color("33606a")
const TEAL5 := Color("4c8a8c")
const TEAL6 := Color("7fbfb0")
const TEAL7 := Color("b9e3d0")
const WARM3 := Color("7a4630")
const WARM5 := Color("dc9a4e")
const WARM6 := Color("f2c979")
const WARM7 := Color("fbe9b5")
const PAPER1 := Color("b3a587")
const PAPER2 := Color("d9cdaf")
const PAPER3 := Color("efe6cf")
const INKT := Color("2b2530")      # ink on paper
const INKS := Color("5a4e52")      # soft ink on paper
const PENCIL := Color("3a3f52")    # the player's pencil notes
const PRINT := Color("7a6a52")     # printed form labels
const RED1 := Color("a02024")
const RED2 := Color("e23b3b")
const RED3 := Color("ff7a6a")
const GRN2 := Color("2f7a3e")
const GRN3 := Color("58b858")
const GRN4 := Color("8fe07a")
const GRN5 := Color("d2f7b4")
const CYAN1 := Color("2a8f96")
const CYAN2 := Color("5ee6e0")
const CYAN3 := Color("c8fff6")
const AMBER := Color("e0a030")
const MAG2 := Color("e0457b")
const STAMP_G := Color("2f8f4a")
const STAMP_A := Color("c9781e")
const STAMP_R := Color("c8281c")

# layout
const SCREEN := Vector2(640, 360)
const HOLE := Rect2(170, 14, 220, 186)        # the counter window
const MONITOR := Rect2(18, 22, 132, 94)       # hall camera glass
const NOTE_L := Rect2(15, 143, 70, 50)        # pinned note: till
const NOTE_R := Rect2(90, 143, 62, 50)        # pinned note: queue
const DIALOGUE := Rect2(0, 224, 400, 60)
const DESK := Rect2(0, 284, 400, 76)
const BOARD := Rect2(400, 0, 240, 360)
const SHEET := Rect2(404, 3, 232, 164)
const RECORD := Rect2(404, 171, 232, 186)
const PATIENT_POS := Vector2(200, 26)         # patient canvas origin; its row 160 meets the sill

const FS := 10
const FS_BIG := 20
const LINE := 10

static var _tex: Dictionary = {}
static var _fonts: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		var full := "res://assets/" + path
		var t: Texture2D = null
		if ResourceLoader.exists(full):
			t = load(full) as Texture2D
		_tex[path] = t
	return _tex[path]


static func has_tex(path: String) -> bool:
	return tex(path) != null


static func font(bold: bool = false) -> Font:
	var key := "counter_bold" if bold else "counter"
	if not _fonts.has(key):
		_fonts[key] = load("res://assets/fonts/%s.fnt" % key)
	return _fonts[key]


static func big_font() -> Font:
	if not _fonts.has("counter_big"):
		_fonts["counter_big"] = load("res://assets/fonts/counter_big.fnt")
	return _fonts["counter_big"]


static func text_w(s: String, bold: bool = false) -> float:
	return font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x


static func big_w(s: String) -> float:
	return big_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_BIG).x


## Draws one line with its top-left corner at pos.
static func text(ci: CanvasItem, pos: Vector2, s: String, color: Color, bold: bool = false) -> void:
	var f := font(bold)
	ci.draw_string(f, Vector2(floorf(pos.x), floorf(pos.y) + f.get_ascent(FS)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, color)


static func text_center(ci: CanvasItem, cx: float, y: float, s: String, color: Color, bold: bool = false) -> void:
	text(ci, Vector2(cx - floorf(text_w(s, bold) / 2.0), y), s, color, bold)


static func text_right(ci: CanvasItem, right: float, y: float, s: String, color: Color, bold: bool = false) -> void:
	text(ci, Vector2(right - text_w(s, bold), y), s, color, bold)


static func big(ci: CanvasItem, pos: Vector2, s: String, color: Color) -> void:
	var f := big_font()
	ci.draw_string(f, Vector2(floorf(pos.x), floorf(pos.y) + f.get_ascent(FS_BIG)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_BIG, color)


static func big_center(ci: CanvasItem, cx: float, y: float, s: String, color: Color) -> void:
	big(ci, Vector2(cx - floorf(big_w(s) / 2.0), y), s, color)


## Greedy word wrap for the bitmap font.
static func wrap_text(s: String, width: float, bold: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if line != "" and text_w(trial, bold) > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out


## Draws wrapped text and returns the y below the last line.
static func paragraph(ci: CanvasItem, pos: Vector2, s: String, width: float, color: Color,
		bold: bool = false, max_lines: int = 99, line_h: int = LINE) -> float:
	var y := pos.y
	var n := 0
	for line in wrap_text(s, width, bold):
		if n >= max_lines:
			break
		text(ci, Vector2(pos.x, y), line, color, bold)
		y += line_h
		n += 1
	return y


static func money(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)


## Text that comes from outside the game (the patient model, speech recognition) can use
## characters the bitmap font has no glyph for. For display only: typographic quotes and
## dashes become plain ones, accents are dropped, and anything else the font cannot draw is
## left out. The wording itself is never changed.
static func printable(s: String) -> String:
	var f := font(false)
	var out := ""
	for i in s.length():
		var code := s.unicode_at(i)
		if code >= 32 and code <= 126:
			out += s[i]
		elif _PLAIN.has(code):
			out += str(_PLAIN[code])
		else:
			var k := _ACCENTED.find(s[i])
			if k >= 0:
				out += _UNACCENTED[k]
			elif code > 126 and f.has_char(code):
				out += s[i]
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()


const _PLAIN := {
	0x2018: "'", 0x2019: "'", 0x201A: "'", 0x2032: "'", 0x00B4: "'",
	0x201C: "\"", 0x201D: "\"", 0x201E: "\"", 0x2033: "\"", 0x00AB: "\"", 0x00BB: "\"",
	0x2014: "-", 0x2015: "-", 0x2212: "-", 0x2010: "-", 0x2011: "-",
	0x0009: " ", 0x000A: " ", 0x000D: " ", 0x00A0: " ", 0x2002: " ", 0x2003: " ", 0x2009: " ", 0x202F: " ",
}
const _ACCENTED := "àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ"
const _UNACCENTED := "aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY"


static func sprite(parent: Node, path: String, pos: Vector2 = Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# ---------------------------------------------------------------- dithered light
# Soft light and shadow in the style of the art: a pixel is either lit or it is not, and a
# glow falls off by thinning out in a 4 x 4 ordered pattern instead of going see-through.
# The pattern is fixed to the screen's own pixels, so it lines up with everything else.
const _DITHER_CODE := """shader_type canvas_item;
render_mode BLEND_MODE;

// how strongly a lit pixel is laid down
uniform float gain = 1.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	int cx = int(FRAGCOORD.x) % 4;
	int cy = int(FRAGCOORD.y) % 4;
	float need = (BAYER[cy * 4 + cx] + 0.5) / 16.0;
	COLOR.a = step(need, COLOR.a) * gain;
}
"""

static var _dither_shaders: Dictionary = {}


## A material that turns the alpha of whatever is drawn with it into dither density.
## add: the lit pixels are added to what is behind them (light); otherwise they cover it (shadow).
static func dither(add: bool, gain: float = 1.0) -> ShaderMaterial:
	var mode := "blend_add" if add else "blend_mix"
	if not _dither_shaders.has(mode):
		var shader := Shader.new()
		shader.code = _DITHER_CODE.replace("BLEND_MODE", mode)
		_dither_shaders[mode] = shader
	var m := ShaderMaterial.new()
	m.shader = _dither_shaders[mode]
	m.set_shader_parameter("gain", gain)
	return m


## A round patch for a dither() material: full `strength` out to `core` of the radius, then
## falling away to nothing at the rim. Fade it by lowering `strength`: it thins out.
static func soft_disc(ci: CanvasItem, at: Vector2, radius: float, color: Color, strength: float = 1.0, core: float = 0.3) -> void:
	if radius < 1.5 or strength <= 0.03:
		return
	var seg := clampi(int(radius * 0.5), 12, 48)
	var mid := core + (1.0 - core) * 0.45
	var rings := [[core, strength], [mid, strength * 0.42], [1.0, 0.0]]
	var points := PackedVector2Array([at])
	var colors := PackedColorArray([Color(color.r, color.g, color.b, strength)])
	for ring in rings:
		var reach := radius * float(ring[0])
		var shade := Color(color.r, color.g, color.b, float(ring[1]))
		for i in seg:
			var ang := TAU * float(i) / float(seg)
			points.append(at + Vector2(cos(ang), sin(ang)) * reach)
			colors.append(shade)
	var indices := PackedInt32Array()
	for i in seg:
		var j := (i + 1) % seg
		indices.append_array(PackedInt32Array([0, 1 + i, 1 + j]))
		for r in rings.size() - 1:
			var a := 1 + r * seg
			var b := a + seg
			indices.append_array(PackedInt32Array([a + i, b + i, b + j, a + i, b + j, a + j]))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)


## A patch for a dither() material that is strongest along one edge of `rect` and gone at the
## opposite one. from_right: the strong edge is the right-hand one.
static func soft_band(ci: CanvasItem, rect: Rect2, color: Color, strength: float, from_right: bool = true) -> void:
	if strength <= 0.03:
		return
	var strong := Color(color.r, color.g, color.b, strength)
	var gone := Color(color.r, color.g, color.b, 0.0)
	var left := gone if from_right else strong
	var right := strong if from_right else gone
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var colors := PackedColorArray([left, right, right, left])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array([0, 1, 2, 0, 2, 3]), points, colors)
