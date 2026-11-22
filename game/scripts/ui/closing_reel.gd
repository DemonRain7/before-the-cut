extends Node2D
## Closing surveillance film. It reads settlements only and owns its playback clock.
const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const STORIES := {
	"rook": [
		"DOCK SIX",
		"The loader hand opens smoothly. Rook leaves a small tip.",
		"The suspended container drops onto the foreman's cab."
	],
	"kip": [
		"NINTH STREET",
		"Kip reads the sign across the room with his new lens.",
		"Kip's courier bike cuts through the morning market."
	],
	"juno": [
		"STREET STAGE",
		"Juno sings a whole scale. The new voice box holds.",
		"Juno breaks off mid-song. The people at the rail scatter."
	],
	"vale": [
		"KESSLER LOBBY",
		"Vale checks his watch and makes his appointment.",
		"The lobby doors seal. The staff inside stop answering."
	],
	"maren": [
		"SHIPYARD",
		"Maren opens her glove. The servos finally release.",
		"Two nights later, Maren's torch keeps burning after the siren."
	],
	"bo": [
		"FIFTH STREET",
		"Bo opens the piston fist on cue, then laughs.",
		"The queue outside the bar breaks as Bo's piston fires."
	],
	"dana": [
		"DISTRICT FEED",
		"Dana blinks. The targeting grid clears.",
		"Dana's targeting grid marks the crowd. A volley empties the square."
	],
	"lux": [
		"TRAFFIC CONTROL",
		"Lux plugs in the test lead. The jack stays cool.",
		"Every junction turns green. The crossing fills from both sides."
	],
	"ozzie": [
		"NOODLE CART",
		"Ozzie folds the cleaver away and writes a meal voucher.",
		"The serving hatch slams. The late queue flees Ozzie's cart."
	],
	"priya": [
		"SURGERY BAY",
		"Priya reads the attendant's pulse and smiles.",
		"Priya turns as the scanner starts. Both attendants are killed."
	]
}
const EXIT_LINES := {
	"referred_stable": "The team escorts a steady patient out. Their repair never happens.",
	"referred_drifting": "The crew contains the drift before anyone reaches the ward.",
	"caught": "The shutter held. The crew collects the patient at the counter.",
	"locked_out": "The shutter keeps the drifting patient out of the operating room.",
	"false_alarm": "A steady patient turns back. The broken implant still needs repair.",
	"walkout": "The patient leaves with the original implant.",
	"gave_up": "The patient leaves with the original implant.",
	"hit": "The counter feed goes dark. The shift ends here.",
	"empty": "An empty chair. Nobody was admitted tonight."
}
const SKIP := Rect2(518, 325, 110, 28)
const NEXT := Rect2(378, 325, 134, 28)
const CUT := 0.42
signal finished
signal sound(cue: String)
var shots: Array = []
var index := 0
var elapsed := 0.0
var less_blood := false
var _cut_played := false

## A record exists only after that visitor's appointment has settled.
static func build(records: Array) -> Array:
	var film := []
	var admitted := false
	var ward_closed := false
	for record in records:
		var outcome := str(record.outcome)
		admitted = admitted or outcome in ["treated_ok", "treated_drifting"]
		film.append({"id":str(record.case_id), "name":str(record.name), "outcome":outcome, "truth":str(record.truth), "annex":ward_closed})
		if record.case_id == "priya" and outcome == "treated_drifting":
			ward_closed = true
	if not admitted:
		var at := film.size()
		if at > 0 and film.back().outcome == "hit":
			at -= 1
		film.insert(at, {"id":"", "name":"", "outcome":"empty", "truth":"", "annex":false})
	return film

func start(records: Array, clean: bool) -> void:
	shots = build(records)
	index = 0
	less_blood = clean
	show()
	_start_shot()

func _start_shot() -> void:
	elapsed = 0.0
	_cut_played = false
	sound.emit("beep")
	queue_redraw()

func duration() -> float:
	return 4.8 if shots[index].outcome in ["treated_ok", "treated_drifting"] else 2.9

func advance() -> void:
	if not visible:
		return
	if index + 1 == shots.size():
		finish()
	else:
		index += 1
		_start_shot()

func finish() -> void:
	if not visible:
		return
	hide()
	shots.clear()
	finished.emit()

func _process(delta: float) -> void:
	if not visible or shots.is_empty():
		return
	elapsed += delta
	if elapsed >= duration():
		advance()
		return
	if not _cut_played and elapsed >= duration() * CUT:
		_cut_played = true
		var outcome: String = shots[index].outcome
		match outcome:
			"treated_ok": sound.emit("door_chime")
			"treated_drifting", "hit": sound.emit("bang")
			"caught", "false_alarm", "locked_out": sound.emit("shutter_roll")
			_: sound.emit("door_open")
	queue_redraw()

func _draw() -> void:
	if not visible or shots.is_empty():
		return
	var shot: Dictionary = shots[index]
	var mode: String = shot.outcome
	var person: String = shot.id
	var p := clampf(elapsed / duration(), 0.0, 1.0)
	var q := clampf((p - CUT) / (1.0 - CUT), 0.0, 1.0)
	var operating := mode in ["treated_ok", "treated_drifting"]
	var incident := mode == "treated_drifting" and p >= CUT
	var location := "OVERFLOW THEATRE" if shot.annex else "SURGERY BAY"
	var caption: String
	draw_rect(Rect2(Vector2.ZERO, Gfx.SCREEN), Gfx.INK0)
	if operating or mode == "empty":
		_ward(shot.annex)
		if incident and person != "priya":
			location = STORIES[person][0]
			_city(person, q)
		else:
			_monitor(437, 83, elapsed, incident and q > 0.42, person)
			_monitor(521, 94, elapsed + 0.3, incident and q > 0.63, person)
			_orderly(Vector2(424, 218), clampf((q - 0.18) * 3, 0, 1) if incident else 0.0, shot.annex)
			_orderly(Vector2(505, 224), clampf((q - 0.38) * 3, 0, 1) if incident else 0.0, shot.annex)
			if mode != "empty":
				var seat := Vector2(150 + roundf(12 * minf(p / CUT, 1.0)), 56)
				if incident:
					seat.x += roundf(108 * sin(q * PI / 2))
				_portrait(person, seat, 1.08, incident, p >= CUT)
				_arm(p, incident)
				if mode == "treated_ok" and p >= CUT:
					_recovery(person, q)
		if mode == "empty":
			caption = EXIT_LINES.empty
		elif p < CUT:
			caption = "After the ward closed, the relief crew took this case." if shot.annex else "The signed chart reaches the operating chair."
		else:
			caption = STORIES[person][2 if incident else 1]
	else:
		location = "COUNTER CAMERA" if mode == "hit" else "EXIT CORRIDOR"
		_corridor(shot, p, q)
		caption = EXIT_LINES[mode]
		if mode == "gave_up" and shot.truth == "drifting":
			caption = "The patient goes back into the city with the drift untreated."
	for y in range(42, 261, 4):
		draw_line(Vector2(16, y), Vector2(623, y), Color(0, 0.03, 0.05, 0.10))
	if p < 0.05 or (incident and q < 0.045):
		draw_rect(Rect2(16, 42, 608, 218), Color(0.64, 0.78, 0.72, 0.18))
	draw_rect(Rect2(16, 41, 608, 220), Gfx.TEAL4, false)
	Gfx.text(self, Vector2(19, 14), "AFTER CLOSING", Gfx.WARM6, true)
	Gfx.text_right(self, 621, 14, location, Gfx.TEAL7, true)
	draw_rect(Rect2(21, 31, 5, 4), Gfx.RED3 if int(elapsed * 2) % 2 == 0 else Gfx.WARM3)
	Gfx.text(self, Vector2(32, 26), "REC", Gfx.TEAL6)
	Gfx.text_right(self, 622, 27, "%02d / %02d" % [index + 1, shots.size()], Gfx.TEAL6)
	var label := str(shot.name) if not person.is_empty() else "SURGERY BAY"
	Gfx.big(self, Vector2(22, 267), label, Gfx.PAPER3)
	Gfx.paragraph(self, Vector2(23, 295), caption, 590, Gfx.TEAL7, false, 2, 12)
	var unit := 316.0 / shots.size()
	for i in shots.size():
		draw_rect(Rect2(22 + i * unit, 337, unit - 3, 3), Gfx.WARM6 if i <= index else Gfx.TEAL3)
	Gfx.text_right(self, NEXT.end.x - 4, 334, "Next shot [ENTER]", Gfx.TEAL7)
	Gfx.text_right(self, SKIP.end.x - 4, 334, "Skip film [ESC]", Gfx.TEAL7)

func _ward(annex: bool) -> void:
	draw_rect(Rect2(17, 42, 606, 218), Gfx.TEAL2)
	for x in range(18, 623, 34):
		draw_line(Vector2(x, 48), Vector2(x, 219), Gfx.TEAL3)
	for y in range(58, 218, 24):
		draw_line(Vector2(18, y), Vector2(622, y), Gfx.TEAL3)
	draw_rect(Rect2(18, 209, 604, 50), Gfx.TEAL1)
	draw_rect(Rect2(119, 49, 206, 6), Gfx.WARM5 if annex else Gfx.TEAL5)
	if annex:
		for x in range(35,605,72):
			draw_line(Vector2(x,65),Vector2(x+12,53),Gfx.WARM3,4)
	draw_rect(Rect2(129, 55, 186, 3), Gfx.WARM7)
	draw_colored_polygon(PackedVector2Array([Vector2(132, 58),Vector2(314, 58),Vector2(367, 211),Vector2(86, 211)]), Color(0.66, 0.76, 0.57, 0.10))
	# Upholstered chair and foot rail beneath the seated portrait.
	draw_rect(Rect2(175, 120, 134, 100), Gfx.INK1)
	draw_rect(Rect2(180, 125, 124, 90), Gfx.TEAL4)
	draw_rect(Rect2(155, 218, 179, 13), Gfx.TEAL5)
	draw_rect(Rect2(203, 231, 12, 26), Gfx.TEAL3)
	draw_rect(Rect2(287, 231, 12, 26), Gfx.TEAL3)
	for x in [396, 497]:
		draw_rect(Rect2(x, 169, 78, 57), Gfx.TEAL3)
		for y in [175, 191, 207]:
			draw_rect(Rect2(x + 7, y, 60, 2), Gfx.TEAL5)

## The bedside recorder shows what the repaired part can do again.
func _recovery(id: String, q: float) -> void:
	var box := Rect2(376,69,207,88)
	draw_rect(box, Gfx.TEAL4)
	draw_rect(box.grow(-3), Gfx.INK1)
	var center := Vector2(479,112)
	var n := smoothstep(0.05,0.78,q)
	match id:
		"juno":
			for bar in 13:
				var h := 4 + int((sin(q * 12 + bar * 0.65) + 1) * 14)
				draw_rect(Rect2(399+bar*12,136-h,7,h),Gfx.CYAN2)
		"rook","bo","maren","ozzie":
			var palm := Rect2(center + Vector2(-17,0),Vector2(34,17))
			draw_rect(palm, Gfx.TEAL5)
			for finger in 4:
				var root_at := palm.position + Vector2(4+finger*8,1)
				var reach := Vector2((finger-1.5)*9.0*n, -8.0-(20-absf(finger-1.5)*3.0)*n)
				draw_line(root_at,root_at+reach,Gfx.TEAL7,5)
				draw_rect(Rect2(root_at+reach-Vector2(2,3),Vector2(4,4)),Gfx.WARM6)
			if id == "ozzie":
				draw_line(center+Vector2(21,5),center+Vector2(24+(1-n)*24,2-(1-n)*24),Gfx.PAPER2,3)
		"lux":
			draw_rect(Rect2(475,99,64,32),Gfx.TEAL3)
			draw_rect(Rect2(482,106,47,18),Gfx.INK0)
			var lead := Vector2(429+n*46,113)
			draw_line(Vector2(392,135),lead,Gfx.WARM5,4)
			draw_rect(Rect2(lead,Vector2(21,8)),Gfx.PAPER3)
			draw_circle(Vector2(548,112),4,Gfx.GRN4 if n>0.8 else Gfx.WARM3)
		"vale":
			draw_circle(center,28,Gfx.TEAL6)
			draw_circle(center,24,Gfx.INK1)
			draw_line(center,center+Vector2(0,-18),Gfx.PAPER3,2)
			draw_line(center,center+Vector2.RIGHT.rotated(-1.2+n*1.2)*18,Gfx.WARM6,2)
		"kip","dana","priya":
			draw_arc(center,26,0,TAU,32,Gfx.CYAN1,2)
			draw_arc(center,16+8*(1-n),0,TAU,24,Gfx.CYAN2,2)
			if id == "priya":
				_monitor(448,100,q*2,false,id)
			elif id == "dana":
				for i in 4:
					var offset := 13+int(n*42)
					draw_line(center+Vector2(-offset+i*11,-17),center+Vector2(-offset+i*11,17),Color(Gfx.WARM6,1-n))
			else:
				draw_circle(center,3,Gfx.PAPER3)


func _arm(p: float, alarm: bool) -> void:
	var base := Vector2(88, 217)
	var joint := Vector2(83, 119)
	var travel := (1.0 - smoothstep(0.37, 0.60, p)) * smoothstep(0.02, 0.30, p)
	var tip := Vector2(125 + 80 * travel, 102 + 33 * travel)
	draw_line(base, joint, Gfx.INK1, 11)
	draw_line(joint, tip, Gfx.TEAL5, 7)
	draw_circle(joint, 7, Gfx.TEAL7)
	draw_rect(Rect2(tip.x, tip.y, 13, 4), Gfx.WARM6 if alarm else Gfx.CYAN2)

func _monitor(x: int, y: int, t: float, flat: bool, person: String) -> void:
	draw_rect(Rect2(x-4, y-4, 68, 33), Gfx.TEAL5)
	draw_rect(Rect2(x, y, 60, 25), Gfx.INK0)
	var prev := Vector2(x, y + 16)
	for i in range(2, 58, 2):
		var phase := posmod(i + int(t * 28) + person.length(), 30)
		var wave := 0 if flat else (-11 if phase < 3 else (5 if phase < 6 else 0))
		var pos := Vector2(x + i, y + 16 + wave)
		draw_line(prev, pos, Gfx.WARM6 if flat else Gfx.CYAN2)
		prev = pos

func _orderly(foot: Vector2, fall: float, relief: bool = false) -> void:
	draw_set_transform(foot, fall * PI * 0.48)
	draw_rect(Rect2(-9,-46,18,15), Gfx.TEAL6)
	draw_rect(Rect2(-9,-45,18,4), Gfx.PAPER2)
	draw_rect(Rect2(-8,-38,16,5), Gfx.TEAL3)
	draw_rect(Rect2(-13,-31,26,20), Gfx.WARM5 if relief else Gfx.TEAL5)
	draw_rect(Rect2(-9,-13,6,13), Gfx.INK1)
	draw_rect(Rect2(4,-13,6,13), Gfx.INK1)
	draw_rect(Rect2(4,-28,4,5), Gfx.PAPER2)
	draw_set_transform(Vector2.ZERO)

func _portrait(id: String, pos: Vector2, scale_factor: float, turn: bool, gesture: bool) -> void:
	var layers := ["body","pupils","head","brows_neutral"]
	var clean := "_clean" if less_blood else ""
	if turn:
		layers.append_array(["turn" + clean, "mouth_turn" + clean, "attack_s1" + clean])
	else:
		layers.append("mouth_a" if gesture and int(elapsed * 4) % 2 == 0 else "mouth_closed")
		layers.append("hands_b" if gesture and int(elapsed * 3) % 2 == 0 else "hands_a")
	for layer in layers:
		var texture := Gfx.tex("patients/%s/%s.png" % [id, layer])
		if texture != null:
			draw_texture_rect(texture, Rect2(pos.round(), Vector2(160,176)*scale_factor), false)

func _corridor(shot: Dictionary, p: float, q: float) -> void:
	var stop: bool = shot.outcome in ["false_alarm","locked_out","caught","hit"]
	draw_rect(Rect2(17,42,606,218), Gfx.TEAL1)
	for x in [42, 169, 296, 423]:
		draw_rect(Rect2(x,58,111,181), Gfx.TEAL3)
		draw_rect(Rect2(x+5,64,102,173), Gfx.TEAL2)
		draw_rect(Rect2(x+13,81,85,43), Gfx.INK1)
		draw_rect(Rect2(x+17,84,77,36), Gfx.TEAL3)
	draw_rect(Rect2(23,222,593,7), Gfx.TEAL4)
	var h := 220.0 if stop else (176.0 + 171.0 * smoothstep(0.26, 0.94, p))
	_portrait(shot.id, Vector2(h,66), 0.99, shot.outcome in ["hit","caught"] and q > 0, p > CUT)
	if shot.outcome in ["referred_stable","referred_drifting","caught"]:
		var march := 45.0 * q
		_orderly(Vector2(h-9+march,225), 0.0)
		_orderly(Vector2(h+151+march,225), 0.0)
	if stop and q > 0:
		var height := int(173 * smoothstep(0.08,0.72,q))
		draw_rect(Rect2(162,54,271,height), Gfx.TEAL3)
		for y in range(55,54+height,9):
			draw_line(Vector2(163,y),Vector2(431,y),Gfx.TEAL5)
	if shot.outcome == "hit" and q > 0.45:
		draw_rect(Rect2(17,42,606,218), Color(0.015,0.023,0.028, minf(1,(q-0.45)*3)))
		draw_line(Vector2(18,146),Vector2(622,146),Color(Gfx.TEAL5,1.0-q))

func _pedestrian(foot: Vector2, index_in_crowd: int, q: float) -> void:
	var coat: Color = [Gfx.TEAL5, Gfx.WARM3, Gfx.TEAL4][index_in_crowd]
	var moving := smoothstep(0.14,0.4,q)
	var stride := roundf(sin(q*15+index_in_crowd)*5*moving)
	var hip := foot + Vector2(0,-13)
	var shoulder := hip + Vector2(4*moving,-21)
	draw_line(hip,foot+Vector2(-4-stride,0),Gfx.TEAL4,4)
	draw_line(hip,foot+Vector2(4+stride,0),Gfx.TEAL4,4)
	draw_line(hip,shoulder,coat,13)
	draw_circle(shoulder+Vector2(1,-8),6,Gfx.PAPER1)
	draw_rect(Rect2(shoulder.x-6,shoulder.y-14,13,4),Gfx.INK0)
	draw_line(shoulder+Vector2(1,3),hip+Vector2(8+stride,-4),coat,4)


func _city(id: String, q: float) -> void:
	draw_rect(Rect2(17,42,606,218), Gfx.INK1)
	for i in 16:
		var x := 19 + i * 38
		var roof := 66 + posmod(i * 31, 77)
		draw_rect(Rect2(x,roof,34,209-roof),Gfx.TEAL2)
		for y in range(roof+8,200,17):
			draw_rect(Rect2(x+7,y,7,3),Gfx.TEAL4)
	draw_rect(Rect2(17,208,606,52),Gfx.TEAL2)
	var flee := roundf(smoothstep(0.22,0.98,q) * 95.0)
	for i in 3:
		_pedestrian(Vector2(368 + i*41 + flee,228 + i%2*9), i, q)

	match id:
		"rook":
			var fall := 78.0 * smoothstep(0.14,0.65,q)
			draw_rect(Rect2(392,184,110,33),Gfx.WARM3)
			draw_rect(Rect2(401,190,40,10),Gfx.INK1)
			draw_line(Vector2(453,43),Vector2(453,74+fall),Gfx.TEAL6,2)
			draw_rect(Rect2(399,74+fall,108,37),Gfx.WARM5)
			for x in range(405,504,10):
				draw_rect(Rect2(x,78+fall,3,28),Gfx.WARM3)
		"lux","kip":
			for x in [378,465,553]:
				draw_rect(Rect2(x,93,5,113),Gfx.TEAL5)
				draw_rect(Rect2(x-5,82,15,26),Gfx.INK0)
				draw_circle(Vector2(x+2,95),4,Gfx.GRN4 if q > 0.23 else Gfx.WARM3)
			if id == "kip":
				var wheel := Vector2(311+q*222,226)
				for offset in [0,32]:
					draw_circle(wheel+Vector2(offset,0),8,Gfx.INK0)
					draw_arc(wheel+Vector2(offset,0),7,0,TAU,12,Gfx.TEAL7,2)
				draw_line(wheel,wheel+Vector2(12,-13),Gfx.WARM5,3)
				draw_line(wheel+Vector2(12,-13),wheel+Vector2(32,0),Gfx.WARM5,3)
				draw_line(wheel+Vector2(11,-14),wheel+Vector2(24,-28),Gfx.WARM6,5)
				draw_circle(wheel+Vector2(26,-31),5,Gfx.PAPER2)
				draw_rect(Rect2(wheel.x-7,wheel.y-19,14,9),Gfx.WARM3)
			else:
				var car := Vector2(335+q*176,214)
				draw_rect(Rect2(car,Vector2(42,13)),Gfx.WARM5)
				draw_rect(Rect2(car+Vector2(7,-6),Vector2(21,7)),Gfx.WARM6)
				draw_circle(car+Vector2(8,13),4,Gfx.INK0)
				draw_circle(car+Vector2(34,13),4,Gfx.INK0)
				draw_rect(Rect2(489,165+q*48,18,33),Gfx.CYAN1)
				draw_rect(Rect2(492,170+q*48,12,8),Gfx.TEAL7)
		"maren":
			draw_line(Vector2(353,223),Vector2(553,120),Gfx.TEAL5,9)
			for i in 7:
				var v := Vector2(1+i*3, -18+i*4)
				draw_line(Vector2(443,175)+v*0.3,Vector2(443,175)+v*(1.0+fmod(q*3,1.0)),Gfx.WARM6,2)
		"juno","ozzie","bo":
			draw_rect(Rect2(337,109,201,10),Gfx.WARM3)
			for i in 10:
				draw_rect(Rect2(338+i*20,119,12,9),Gfx.WARM5)
			if id == "ozzie":
				draw_rect(Rect2(345,135,184,70*q),Gfx.TEAL4)
				draw_rect(Rect2(338,210,201,12),Gfx.WARM5)
			elif id == "juno":
				draw_line(Vector2(371,205),Vector2(371,149),Gfx.TEAL6,3)
				draw_circle(Vector2(371,145),5,Gfx.CYAN2)
			else:
				draw_line(Vector2(330,196),Vector2(543,196),Gfx.WARM5,3)
		"vale","dana":
			for i in 4:
				var gate := Rect2(354+i*50,85,47,127)
				draw_rect(gate, Gfx.TEAL4, false, 2)
				if id == "vale":
					draw_rect(Rect2(gate.position,Vector2(44*q,127)),Gfx.TEAL3)
				else:
					draw_arc(Vector2(389+i*45+flee,187),14,0,TAU,20,Gfx.RED3,2)
	_portrait(id, Vector2(97,66), 1.04, true, true)
