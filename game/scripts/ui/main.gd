extends Control
## The director: owns the shift, the patient at the counter and every input, and tells the
## drawing nodes what to show. All rules live in scripts/core; nothing in this file decides
## what is true about a patient.
##
## Input arrives through pointer_move / pointer_down / pointer_up / key_down / key_up, and every
## player action is a public act_* method, so a test can play the game the way a person does.
##
## Launch options (after "--" on the command line), all optional:
##   --seed=123                          fixed shift seed
##   --authored-order                    patients in the order rules.json lists them (tests, captures)
##   --agent-url=http://127.0.0.1:8787   patient-agent proxy (or environment BTC_AGENT_URL)
##   --model                             autonomous patient dialogue through the proxy
##   --mute                              start with sound off
##   --less-blood                        the attack scenes without the blood

const Gfx = preload("res://scripts/ui/gfx.gd")
const CaseDB = preload("res://scripts/core/case_db.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const ShiftState = preload("res://scripts/core/shift_state.gd")
const PatientAgent = preload("res://scripts/core/patient_agent.gd")
const ModelClient = preload("res://scripts/core/model_client.gd")
const ScriptedBrain = preload("res://scripts/core/scripted_brain.gd")
const EventLog = preload("res://scripts/core/event_log.gd")
const VoiceInput = preload("res://scripts/core/voice_input.gd")
const ClinicView = preload("res://scripts/ui/clinic_view.gd")
const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const Desk = preload("res://scripts/ui/desk.gd")
const Clipboard = preload("res://scripts/ui/clipboard.gd")
const Screens = preload("res://scripts/ui/screens.gd")
const PatientRig = preload("res://scripts/ui/patient_rig.gd")
const AudioBank = preload("res://scripts/ui/audio_bank.gd")
const GoreLayer = preload("res://scripts/ui/gore_layer.gd")

enum State { TITLE, WAIT, ENTER, EXAM, ATTACK, RESOLVE, SLIP, REPORT }

const SLIP_CLIP := Rect2(179, 214, 202, 146)   # the printer slot under the window, down to the screen edge
const SLIP_H := 152.0
const SLIP_REST := -6.0                         # the torn top edge stays inside the slot
const SLIP_GAP := 8.0                           # least space between the call and the money on the slip's last line
const ARM_TIME := 2.2
const CALL_ARM_TIME := 3.5                      # how long the Trauma Team line waits for the second press
# a patient who turns hits the glass three times before it gives: these are the moments of
# the blows, as fractions of the attack window (rules.json: attack.window_ms)
const BLOW_AT := [0.06, 0.36, 0.66]
## Every sound of an attack plays this much under its own level. Measured on November 15 from a
## silent recording of the master bus (nobody listened): untrimmed, the loudest second of an
## attack sat about 24 dB over the room and a landed attack held the limiter in 59% of its
## 50 ms windows. At -9 dB: 19 dB (caught) and 22 dB (landed) over the room, limiter 0% and 8%.
## One number to change after a listening test.
const ATTACK_TRIM_DB := -9.0
const DENT_SPOTS := [Vector2(156, 84), Vector2(64, 58), Vector2(126, 44)]       # caught: where the shutter bulges
const DENT_SPOTS_LOCKED := [Vector2(150, 80), Vector2(70, 66), Vector2(118, 118)]
const FACE_CLEAR := Rect2(186, 76, 236, 208)      # the first blood on the view keeps off the attacker's face
# what a hit leaves on the wall and the counter round the window: picture, centre on the screen
const WALL_MARKS := [
	["splat_m2", Vector2(157, 131)], ["splat_s1", Vector2(163, 58)], ["hand_1", Vector2(396, 104)],
	["splat_s0", Vector2(384, 22)], ["splat_s2", Vector2(300, 8)], ["splat_m0", Vector2(232, 5)],
	["splat_m1", Vector2(152, 206)], ["splat_a0", Vector2(360, 214)], ["splat_s1", Vector2(108, 216)],
	["splat_s2", Vector2(160, 176)], ["splat_s0", Vector2(394, 168)],
]
# and on the desk: small, between the buttons
const DESK_MARKS := [
	["splat_s0", Vector2(265, 351)], ["splat_s1", Vector2(141, 327)], ["splat_s2", Vector2(7, 291)],
	["splat_s1", Vector2(396, 301)], ["splat_s0", Vector2(393, 231)],
]
const CUT_AT := {"saw": Vector2(34, 96), "torch": Vector2(92, 58)}              # where the weapon comes through it
const HOTSPOT := {"point": Vector2(1, 1), "look": Vector2(6, 6), "hand": Vector2(6, 2), "talk": Vector2(3, 12)}
const ZONE_LABEL := {"eyes": "LOOK: EYES", "hands": "LOOK: HANDS", "port": "LOOK: PORT"}
const ZONE_TITLE := {"eyes": "EYES", "hands": "HANDS", "port": "PORT"}
const TOOL_LABEL := {"penlight": "PENLIGHT", "grip": "GRIP BAR", "port": "PORT CHECK"}
const TOOL_ASK := {
	"penlight": "Look straight ahead. Follow the light.",
	"grip": "Squeeze this bar. Let go when I say release.",
	"port": "Show me the port, please.",
}
const TOOL_WHAT := {
	"penlight": "PENLIGHT: shine it in their eyes.",
	"grip": "GRIP BAR: they squeeze, you say release.",
	"port": "PORT CHECK: a close look at the socket.",
}
const SCOPE_HINT := {
	"penlight": "Sweep the light over both eyes. Right-click puts it away.",
	"grip": "Hold the mouse button, then let go. Right-click puts it away.",
	"port": "Look as long as you like. Right-click puts it away.",
}
const PAD_ROW := {"penlight": "eyes", "grip": "hands", "port": "port", "ask": "speech", "press": "temper"}
const PRESS_LINES := [
	"You look like a drift case to me. One bad night from the news.",
	"I think the implant is running you. Prove me wrong.",
]
const REASSURE_LINES := [
	"Take your time. Nobody is in trouble here.",
	"You're doing fine. We are nearly done.",
]
const FIRST_HINT := "Nothing is required. Look, test, talk, or decide whenever you like."
# the crew is an authored outcome: these lines are fixed, they never come from the patient model
const DISPATCH_LINE := "Trauma Team dispatch. A unit is rolling to your counter. Keep them there."
const CREW_LINE := "Trauma Team. Step back from the glass. You are coming with us."
const CREW_AFTER_LINE := "A siren outside. Boots in the hall. It does not take them long."
const WAIT_HINT := "Click the hall camera or press ENTER to buzz them in."
const THINK_HINT := "Still answering. You can look meanwhile, or decide now."
const THINK_QUIET := 1.6          # how long a look made while the patient is answering stays readable
const SAY_HINT := "ENTER says it. ESC takes it back."
const SAY_FULL_HINT := "That is all you can say in one go. ENTER says it."
const SAY_OFFLINE_HINT := "Offline patient: it only knows its script. ASK lists what it can answer."
const SAY_CHIPS := [{"id": "type", "key": "T", "label": "TYPE"}]
# push-to-talk: the microphone is open only while this key (or the SPEAK button) is held
const SPEAK_KEY := KEY_TAB
const SPEAK_CHIPS := [{"id": "speak", "key": "TAB", "label": "SPEAK"}, {"id": "type", "key": "T", "label": "TYPE"}]
const SAY_VOICE_HINT := "ENTER says it. ESC takes it back. Hold TAB to speak."
const MIC_LISTEN_HINT := "Let go to stop. ESC throws it away."
const MIC_WAIT_HINT := "ESC throws it away."
const MIC_DONE_HINT := "Check the words. ENTER says it. ESC takes it back."
const MIC_MOCK_HINT := "Mock transport: no speech service heard you. Edit it, then ENTER."
const MIC_CUT_HINT := "More than one go holds: check where it stops. ENTER says it."
const MIC_DEAF_HINT := "This patient AI service cannot hear. Type with T instead."
const MIC_HINTS := {
	"tap": "Hold TAB while you speak, then let go.",
	"silence": "Heard nothing. Speak up, or type with T.",
	"no_audio": "The microphone gave no sound. Check it, or type with T.",
	"no_speech": "No words came out of that. Try again, or type with T.",
	"unreadable": "That did not come out as English letters. Try again, or type with T.",
	"no_service": "Speaking needs the patient AI service. Type with T instead.",
	"off": "Speaking is switched off in the rules. Type with T instead.",
	"no_mic": "No microphone could be opened. Type with T instead.",
	"opening": "Wait until it says LISTENING, then speak.",
	"clip_cap": "The microphone has taken all it can this visit. Type with T.",
	"cancelled": "Thrown away. Nothing was said.",
	"slow": "Writing it down took too long. Try again, or type with T.",
	"budget": "The patient AI service has no budget left. Type with T instead.",
}
const EDIT_KEYS := [KEY_BACKSPACE, KEY_DELETE, KEY_LEFT, KEY_RIGHT]      # these repeat while held
const HINT_HOLD := 6.0            # pixels the pointer must travel before a hover hint may cover a new instruction
const CLOSE_HOLD := 0.2           # seconds of real time between the last sound stopping and the game leaving

var state: int = State.TITLE
var rules: Dictionary = {}
var sheet: Dictionary = {}
var cases: Dictionary = {}
var meta: Dictionary = {}
var data_errors: Array = []
var shift: ShiftState = null
var visit: VisitState = null
var agent: PatientAgent = null
var model_client: ModelClient = null
var event_log: EventLog = null
var session_id: String = ""
var shift_seed: int = 0
var shift_number: int = 0
var fixed_seed: int = 0
var has_fixed_seed: bool = false
var authored_order: bool = false     # true: rules.json shift_order as written, never shuffled
var agent_url: String = ""
var use_model: bool = false
var start_muted: bool = false
var less_blood: bool = false      # launch option --less-blood: the same scene without the blood

var clinic: ClinicView = null
var dialogue: DialogueBox = null
var desk: Desk = null
var clipboard: Clipboard = null
var screens: Screens = null
var audio: AudioBank = null
var mic: VoiceInput = null        # push-to-talk: a microphone that is open only while the key is held
var gore: GoreLayer = null
var rig: PatientRig = null

var _world := Node2D.new()
var _mess := Node2D.new()         # dried blood on our own side of the counter, after a hit
var _slip_clip := Control.new()
var _slip := Node2D.new()
var _flash := ColorRect.new()
var _held_sprite := Sprite2D.new()
var _cursor := Sprite2D.new()

var _t: float = 0.0
var _seq: int = 0                 # bumped by every action; a running sequence stops when it changes
var _mouse := Vector2(320, 250)
var _skip: bool = false           # a click that asks the current line to hurry up
var _thinking: bool = false       # waiting for the patient brain
var _think_t: float = 0.0
var _lock: bool = false           # a short sequence that must not be interrupted by another action
var _think_quiet: float = 0.0     # seconds the thinking dots stay away, so a look made meanwhile can be read
var _held: String = ""            # the stamp in the player's hand
var _armed: float = 0.0           # seconds left in which a second press drops the shutter
var _call_armed: float = 0.0      # seconds left in which a second press calls Trauma Team
var _telegraphed: bool = false
var _attack_t: float = 0.0
var _blows: int = 0               # how many of the three blows have landed on the glass
var _weapon_loop: String = ""
var _spark_t: float = 0.0
var _splat_at: float = -1.0
var _cam_in: float = 0.0          # seconds until the next visitor shows on the hall camera
var _visit_serial: int = 0
var _first_visit_done: bool = false
var _patient_talking: bool = false
var _mic_rules: Dictionary = {}   # rules.json agent.voice
var _mic_state: String = ""       # "" | "listening" | "transcribing": the microphone has the typing line
var _mic_from: String = ""        # "key" | "chip": what is holding it open
var _mic_token: int = 0           # bumped when a clip starts, is sent or is thrown away: late words are dropped
var _mic_held: float = 0.0        # seconds the microphone has been listening (not counting its opening)
var _mic_wait: float = 0.0        # seconds the key has waited for the device to open
var _mic_kept: String = ""        # what was typed before the key went down: the words are added to it
var _mic_opened_line: bool = false   # the speak key opened the typing line itself
var _voice_sound: String = ""
var _voice_pitch: float = 1.0
var _voice_db: float = -8.0
var _cursor_kind: String = "point"
var _hover_hint: String = ""
var _base_hint: String = ""
var _alert_hint: String = ""
var _hint_shown: String = ""      # the instruction the hint row last took in
var _hint_at := Vector2(-999, -999)   # where the pointer was when it changed
var _closing: bool = false        # the window was asked to close and the game is on its way out
var _slip_data: Dictionary = {}
var _slip_mode: String = "hidden"  # hidden | print | shown | drop
var _slip_y: float = -SLIP_H
var _slip_age: float = 0.0
var _slip_index: int = 0
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _flash_a: float = 0.0
var _flash_fall: float = 1.0
var _flash_color := Color.WHITE
var _rng := RandomNumberGenerator.new()      # shift-seeded: beats and arrivals
var _fx_rng := RandomNumberGenerator.new()   # cosmetic only
var _boot_rng := RandomNumberGenerator.new()


# ================================================================ setup

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var db: Dictionary = CaseDB.load_all()
	rules = db["rules"]
	sheet = db["sheet"]
	cases = db["cases"]
	data_errors = db["errors"]
	var m: Variant = CaseDB.load_json("res://assets/patients/meta.json")
	if typeof(m) == TYPE_DICTIONARY:
		meta = m
	else:
		data_errors.append("assets/patients/meta.json is missing or is not valid JSON.")
	_read_launch_options()
	_build()
	_start_session()
	_show_title()
	get_tree().auto_accept_quit = false      # a close request goes through _close()


func _read_launch_options() -> void:
	agent_url = OS.get_environment("BTC_AGENT_URL").strip_edges()
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--seed="):
			fixed_seed = int(a.substr(7))
			has_fixed_seed = true
		elif a.begins_with("--agent-url="):
			agent_url = a.substr(12).strip_edges()
		elif a == "--model":
			use_model = true
		elif a == "--mute":
			start_muted = true
		elif a == "--less-blood":
			less_blood = true
		elif a == "--authored-order":
			authored_order = true
	if agent_url == "":
		use_model = false


func _build() -> void:
	add_child(_world)
	clinic = ClinicView.new()
	_world.add_child(clinic)
	dialogue = DialogueBox.new()
	_world.add_child(dialogue)
	desk = Desk.new()
	_world.add_child(desk)
	clipboard = Clipboard.new()
	clipboard.sheet = sheet
	_world.add_child(clipboard)
	_world.add_child(_mess)
	_slip_clip.position = SLIP_CLIP.position
	_slip_clip.size = SLIP_CLIP.size
	_slip_clip.clip_contents = true
	_slip_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_slip_clip)
	_slip.visible = false
	_slip_clip.add_child(_slip)
	_slip.draw.connect(_draw_slip)
	clinic.less_blood = less_blood
	gore = GoreLayer.new()
	gore.less_blood = less_blood
	add_child(gore)
	gore.splatted.connect(_on_splat)
	_flash.size = Gfx.SCREEN
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	screens = Screens.new()
	screens.errors = data_errors
	add_child(screens)
	_held_sprite.centered = false
	_held_sprite.visible = false
	add_child(_held_sprite)
	_cursor.centered = false
	add_child(_cursor)
	audio = AudioBank.new()
	add_child(audio)
	audio.set_muted(start_muted)
	mic = VoiceInput.new()
	add_child(mic)
	mic.filled.connect(act_speak_stop)
	mic.failed.connect(_on_mic_failed)
	clinic.scope.audio = audio
	clinic.scope.completed.connect(_on_scope_completed)
	dialogue.blip.connect(_on_blip)
	clinic.rent = int(rules.get("rent", 0))
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_fx_rng.randomize()


func _start_session() -> void:
	_boot_rng.randomize()
	session_id = "%08x" % _boot_rng.randi()
	event_log = EventLog.new()
	event_log.open(session_id)
	var agent_rules: Dictionary = rules.get("agent", {})
	model_client = ModelClient.new()
	model_client.base_url = agent_url
	model_client.timeout_ms = int(agent_rules.get("timeout_ms", 4000))
	_mic_rules = agent_rules.get("voice", {})
	model_client.voice_timeout_ms = int(_mic_rules.get("timeout_ms", 7000))
	mic.max_seconds = float(_mic_rules.get("max_seconds", 10.0))
	add_child(model_client)
	screens.voice = _mic_why_not() == ""
	_log("session_start", {
		"game_version": PatientAgent.GAME_VERSION,
		"rules_version": str(rules.get("version", "")),
		"model_endpoint_set": agent_url != "",
		"model_requested": use_model,
		"voice_offered": screens.voice,
		"engine": str(Engine.get_version_info().get("string", "")),
	})


func _log(event_type: String, data: Dictionary = {}) -> void:
	if event_log == null:
		return
	var record := data.duplicate()
	if visit != null and not record.has("case"):
		record["case"] = str(visit.case_data.get("id", ""))
	event_log.write(event_type, record)


func _show_title() -> void:
	state = State.TITLE
	screens.show_title()
	clinic.shutter_to(1.0, 0.01)
	desk.set_all(false)
	clipboard.set_visit(null, "")
	audio.loop("amb_rain", -15.0)
	audio.loop("amb_drone", -24.0)


# ================================================================ small helpers

func _bump() -> int:
	_seq += 1
	return _seq


func _wait(seconds: float, token: int) -> bool:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		if token != _seq:
			return false
		left -= get_process_delta_time()
	return true


## Lets the line on screen finish typing, then holds it. A click hurries either part.
func _run_line(token: int, hold: float) -> bool:
	_skip = false
	while dialogue.typing:
		await get_tree().process_frame
		if token != _seq:
			return false
		if _skip:
			_skip = false
			dialogue.skip()
	dialogue.waiting = hold >= 0.5
	var left := hold
	while left > 0.0:
		await get_tree().process_frame
		if token != _seq:
			return false
		if _skip:
			_skip = false
			break
		left -= get_process_delta_time()
	dialogue.waiting = false
	return true


func _set_voice(sound: String, pitch: float, db: float) -> void:
	_voice_sound = sound
	_voice_pitch = pitch
	_voice_db = db


func _on_blip() -> void:
	if _voice_sound != "":
		audio.play(_voice_sound, _voice_pitch * _fx_rng.randf_range(0.96, 1.05), _voice_db)


func _patient_name() -> String:
	return str(visit.case_data.get("name", "")) if visit != null else ""


func _patient_line(text: String, token: int, hold: float = 0.8) -> bool:
	if text == "" or visit == null:
		return token == _seq
	var voice: Dictionary = visit.case_data.get("voice", {})
	_patient_talking = true
	_set_voice("blip_glitch" if bool(voice.get("glitch", false)) else "blip", float(voice.get("pitch", 1.0)), -7.0)
	dialogue.say(_patient_name(), text, Gfx.WARM6, Gfx.TEAL7, 44.0 * float(voice.get("rate", 1.0)))
	var ok: bool = await _run_line(token, hold)
	return ok


func _doctor_say(text: String) -> void:
	_patient_talking = false
	_set_voice("blip", 0.8, -13.0)
	dialogue.say("YOU", text, Gfx.CYAN2, Gfx.TEAL6, 110.0)


func _doctor_line(text: String, token: int, hold: float = 0.25) -> bool:
	_doctor_say(text)
	var ok: bool = await _run_line(token, hold)
	return ok


func _narrate(label: String, text: String, token: int, hold: float = 1.0, color: Color = Gfx.TEAL6) -> bool:
	_patient_talking = false
	_set_voice("blip_narrate", 1.0, -15.0)
	dialogue.say(label, text, Gfx.CYAN2, color, 80.0)
	var ok: bool = await _run_line(token, hold)
	return ok


func _shake(amp: float, time: float) -> void:
	_shake_amp = amp
	_shake_t = time


func _flash_now(color: Color, alpha: float, time: float) -> void:
	_flash_color = color
	_flash_a = alpha
	_flash_fall = alpha / maxf(0.01, time)


func _fade_to(target: float, time: float) -> void:
	var from := screens.fade
	var t := 0.0
	while t < time:
		await get_tree().process_frame
		t += get_process_delta_time()
		screens.fade = lerpf(from, target, clampf(t / time, 0.0, 1.0))
	screens.fade = target


func _note_keys() -> Dictionary:
	var out := {}
	if visit == null:
		return out
	for row in visit.notes.keys():
		var list: Array = visit.notes[row]
		for n in list:
			var note: Dictionary = n
			out[str(note.get("key", ""))] = true
	return out


## Starts the pencil animation on every note that was not there before.
func _mark_new_notes(before: Dictionary) -> bool:
	var any := false
	if visit == null:
		return any
	for row in visit.notes.keys():
		var list: Array = visit.notes[row]
		for n in list:
			var note: Dictionary = n
			var key := str(note.get("key", ""))
			if not before.has(key):
				clipboard.mark_fresh(key)
				any = true
	if any:
		audio.play("pencil")
	return any


func _can_act() -> bool:
	return _can_decide() and not _thinking and not _lock


## The exam is open, whether or not the patient is in the middle of an answer. Looking, picking
## up the stamp, opening the call line and deciding need only this: none of them has to wait
## for the patient to finish thinking (student request of November 15).
func _can_decide() -> bool:
	return state == State.EXAM and visit != null and visit.in_exam()


## The patient is still answering the last thing that was asked: the model has not replied yet,
## or the doctor's own line is still on screen.
func _answer_pending() -> bool:
	return _thinking or _lock


## Every new action puts away whatever was in hand and stops the sequence that was running.
func _begin_action() -> int:
	_close_scope(true)
	dialogue.clear_menu()
	_drop_stamp(false)
	_disarm()
	_close_say()
	dialogue.waiting = false
	_base_hint = ""
	return _bump()


func _sync_visit() -> void:
	if visit == null:
		return
	clinic.set_patience(visit.patience, visit.patience_max)
	var costs: Dictionary = rules.get("costs", {})
	desk.badges.clear()
	desk.warn.clear()
	for t in VisitState.TOOLS:
		var tool := str(t)
		var status := visit.check_status(tool)
		if status == "open":
			continue
		desk.badges[tool] = "-%d" % visit.check_cost(tool)
		if status == "refused":
			desk.warn[tool] = true
	var open_topics := false
	for t in visit.case_data.get("topics", []):
		var topic: Dictionary = t
		if not visit.answered.has(str(topic.get("id", ""))):
			open_topics = true
	if open_topics:
		desk.badges["ask"] = "-%d" % int(costs.get("ask", 1))
	desk.badges["calm"] = "x%d" % visit.reassure_left
	desk.badges["press"] = "-%d" % int(costs.get("press", 2))
	desk.enabled["calm"] = visit.reassure_left > 0


func _desk_for_exam() -> void:
	desk.set_all(true)
	desk.lever_down = false
	desk.pulse = ""
	_sync_visit()


func _desk_off() -> void:
	_close_say()
	_drop_stamp(false)              # a stamp picked up while the patient was still answering
	if _call_armed > 0.0:           # or a call line opened then
		_call_armed = 0.0
		_alert_hint = ""
	desk.set_all(false)
	desk.active = ""
	desk.held = ""
	desk.hover = ""
	desk.pulse = ""
	desk.armed = ""


func _zone_at(pos: Vector2) -> String:
	if rig == null or not rig.at_counter() or clinic.scope.is_open() or not Gfx.HOLE.has_point(pos):
		return ""
	for z in ["eyes", "port", "hands"]:
		var zone := str(z)
		if rig.zone_rect(zone).grow(2.0).has_point(pos):
			return zone
	return ""


func _pad_hint(pad: String) -> String:
	if visit == null:
		return ""
	var costs: Dictionary = rules.get("costs", {})
	match pad:
		"penlight", "grip", "port":
			var status := visit.check_status(pad)
			if status == "open":
				return "%s Free now." % str(TOOL_WHAT[pad])
			if status == "refused":
				return "%s refused. Insist (costs %d) or reassure first." % [str(TOOL_LABEL[pad]), visit.check_cost(pad)]
			return "%s Costs %d patience." % [str(TOOL_WHAT[pad]), visit.check_cost(pad)]
		"ask":
			return "ASK: pick a question. A new answer costs %d patience." % int(costs.get("ask", 1))
		"calm":
			if visit.reassure_left <= 0:
				return "REASSURE: you have said the kind things already."
			return "REASSURE: +1 patience, and a refusal softens. %d left." % visit.reassure_left
		"press":
			return "PRESS: say something that stings. Costs %d patience." % int(costs.get("press", 2))
		"treat":
			return "TREAT: they are steady. Pick it up and stamp the card."
		"refer":
			return "TRAUMA TEAM: a line is broken. Press twice. They come and take the patient."
		"shutter":
			return "SHUTTER [SPACE]: ends the visit at once. Only for danger."
	return ""


# ================================================================ shift flow

func act_start() -> void:
	if state != State.TITLE or cases.is_empty():
		return
	screens.hide_all()
	audio.play("click")
	_start_shift()


func act_restart() -> void:
	if state != State.REPORT or screens.age() < 0.8:
		return
	screens.hide_all()
	audio.play("click")
	_start_shift()


func _start_shift() -> void:
	shift_number += 1
	shift_seed = fixed_seed if has_fixed_seed else int(_boot_rng.randi())
	_rng.seed = shift_seed
	var order: Array = [] if authored_order else ShiftState.arrival_order(rules, cases, shift_seed, shift_number == 1)
	shift = ShiftState.new(rules, order)
	var client: Variant = null
	if agent_url != "":
		client = model_client
	agent = PatientAgent.new(rules, client, shift_seed)
	agent.session_id = session_id
	agent.set_mode("model" if use_model else "script")
	_visit_serial = 0
	visit = null
	clinic.till = 0
	clinic.snap_till()
	clinic.results = []
	clinic.queue_index = 0
	clinic.queue_count = shift.count()
	clinic.reset_damage()
	gore.clear()
	for c in _mess.get_children():
		c.queue_free()
	_stop_attack_audio()
	audio.trim_db = 0.0
	clinic.set_cam("")
	clinic.corner_text = ""
	_log("shift_start", {"shift": shift_number, "seed": shift_seed, "order": shift.order, "agent_mode": agent.mode})
	state = State.WAIT
	clinic.cam_prompt = false
	var token := _bump()
	clinic.shutter_to(0.0, 1.0)
	desk.lever_down = false
	audio.play("shutter_roll")
	var ok: bool = await _narrate("", "Night shift. %d on the list. The reference sheet is on your clipboard." % shift.count(), token, 0.7)
	if not ok:
		return
	_begin_wait()


## Between patients: the hall camera shows who is next and the player buzzes them in.
func _begin_wait() -> void:
	state = State.WAIT
	var token := _bump()
	clinic.queue_index = shift.index
	clinic.show_patience = false
	clinic.cam_prompt = false
	_desk_off()
	_alert_hint = ""
	_base_hint = ""
	var id := shift.current_id()
	var c: Dictionary = cases.get(id, {})
	# nobody is called while the shutter is still down
	while clinic.shutter_pos > 0.02:
		await get_tree().process_frame
		if token != _seq:
			return
	if clinic.cam_id != id:
		dialogue.clear()
		var ok: bool = await _wait(0.5, token)
		if not ok:
			return
		clinic.set_cam(id)
		audio.play("door_chime")
	clinic.cam_prompt = true
	_base_hint = WAIT_HINT
	_narrate("HALL CAMERA", str(c.get("teaser", "")), token, 0.0, Gfx.GRN4)


func act_call_next() -> void:
	if state != State.WAIT or not clinic.cam_prompt or shift == null or shift.is_done():
		return
	var id := shift.current_id()
	if not cases.has(id):
		return
	var token := _bump()
	state = State.ENTER
	clinic.cam_prompt = false
	_base_hint = ""
	audio.play("beep", 0.8)
	var c: Dictionary = cases[id]
	_visit_serial += 1
	visit = VisitState.new(c, rules)
	agent.begin_visit(c, "%s-%d-%s" % [session_id, _visit_serial, id], shift_seed + _visit_serial * 7919)
	_telegraphed = false
	_attack_t = 0.0
	_blows = 0
	_log("visit_start", {"index": shift.index, "agent_mode": agent.mode})
	rig = PatientRig.new()
	add_child(rig)
	rig.less_blood = less_blood
	rig.setup(c, meta.get(str(c.get("sprite", id)), {}))
	rig.slide = 1.0
	clinic.back_slot.add_child(rig.back)
	clinic.front_slot.add_child(rig.front)
	rig.impact.connect(_on_impact)
	dialogue.clear()
	var ok: bool = await _wait(0.3, token)
	if not ok:
		return
	clinic.set_cam("")
	clinic.door(true)
	audio.play("door_open")
	ok = await _wait(0.25, token)
	if not ok:
		return
	var voice: Dictionary = c.get("voice", {})
	var step_pitch := lerpf(1.0, float(voice.get("pitch", 1.0)), 0.5)
	var dur := 0.95 / maxf(0.6, float(voice.get("rate", 1.0)))
	var t := 0.0
	var next_step := 0.0
	while t < dur:
		await get_tree().process_frame
		if token != _seq:
			return
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / dur, 0.0, 1.0)
		rig.slide = (1.0 - k) * (1.0 - k)
		next_step -= dt
		if next_step <= 0.0:
			audio.play("step", step_pitch, -8.0)
			next_step = 0.24
	rig.slide = 0.0
	clinic.door(false)
	# the intake card lands on the clipboard and the exam is open
	clipboard.set_visit(visit, "%d/%d" % [shift.index + 1, shift.count()])
	audio.play("paper")
	clinic.show_patience = true
	state = State.EXAM
	_desk_for_exam()
	_cam_in = _rng.randf_range(9.0, 15.0)
	if not _first_visit_done:
		_base_hint = FIRST_HINT
	var opening: Array = c.get("opening", [])
	for line in opening:
		ok = await _patient_line(str(line), token, 0.9)
		if not ok:
			return


func _show_upcoming() -> void:
	if shift == null:
		return
	var up := shift.upcoming_id()
	if up != "" and clinic.cam_id == "":
		clinic.set_cam(up)
		audio.play("door_chime", 1.0, -9.0)


# ================================================================ exam actions

func act_look(zone: String) -> void:
	if not VisitState.ZONES.has(zone):
		return
	# a look does not interrupt: while the patient is still answering it happens beside the answer
	var meanwhile := _can_decide() and _answer_pending()
	if not _can_act() and not meanwhile:
		return
	var token := _seq
	if meanwhile:
		_think_quiet = THINK_QUIET
	else:
		token = _begin_action()
	var before := _note_keys()
	var res: Dictionary = visit.look(zone)
	if not bool(res.get("ok", false)):
		return
	if not _mark_new_notes(before):
		audio.play("click", 1.2, -6.0)
	_log("look", {"zone": zone, "covered": bool(res.get("covered", false))})
	_narrate(str(ZONE_TITLE[zone]), str(res.get("text", "")), token, 0.0)


func act_tool(tool: String) -> void:
	if not _can_act() or not VisitState.TOOLS.has(tool):
		return
	if clinic.scope.is_open() and clinic.scope.tool == tool:
		act_cancel()
		return
	var token := _begin_action()
	audio.play("tool_pick")
	if visit.granted.has(tool):
		_open_scope(tool)
		return
	if visit.patience < visit.check_cost(tool):
		_spent(token)
		return
	var before := _note_keys()
	var d: Dictionary = await _decide({"type": "check", "id": tool}, visit.legal_moves_for_check(tool), str(TOOL_ASK[tool]), token)
	if d.is_empty():
		return
	var res: Dictionary = visit.apply_check(tool, str(d.get("move", "")), str(d.get("source")) == "model")
	_sync_visit()
	_mark_new_notes(before)
	var result := str(res.get("result", ""))
	_log("check", {"tool": tool, "move": str(res.get("move", "")), "result": result, "cost": int(res.get("cost", 0)),
		"patience": visit.patience, "source": str(d.get("source", ""))})
	var line := str(d.get("line", ""))
	if not await _show_reaction(d, token):
		return
	match result:
		"granted":
			var ok: bool = await _patient_line(line, token, 0.25)
			# not over a stamp or an open call line picked up while they answered: the tool waits
			if ok and _held == "" and _call_armed <= 0.0:
				_open_scope(tool)
		"explained":
			_base_hint = "They gave a reason instead. Insist (costs %d) or reassure." % visit.check_cost(tool)
			_patient_line(line, token, 1.0)
		"refused":
			_base_hint = "They said no. Insist (costs %d) or reassure them first." % visit.check_cost(tool)
			_patient_line(line, token, 1.0)
		"spent":
			_spent(token)


## The model receives the doctor's words and conversation. The options are fallback-only.
## Returns {} when the action was cancelled meanwhile (the shutter fell).
func _decide(event: Dictionary, legal: Array, ask_line: String, token: int) -> Dictionary:
	_thinking = true
	_lock = true
	_think_t = 0.0
	_think_quiet = 0.0
	_doctor_say(ask_line)
	event = event.duplicate(true)
	event["text"] = ask_line
	var d: Dictionary = await agent.decide(event, visit.snapshot(), legal)
	if token != _seq or d.is_empty():
		return {}
	_thinking = false
	if str(d.get("source", "")) != "script":
		_log("agent_move", {"event": {"type": event.type, "id": event.id}, "move": str(d.get("move", "")), "source": str(d.get("source", "")),
			"fallback_reason": str(d.get("fallback_reason", "")), "latency_ms": int(d.get("latency_ms", 0))})
	if not dialogue.thinking:
		var ok: bool = await _run_line(token, 0.2)
		if not ok:
			return {}
	agent.remember_exchange(event, d)
	_lock = false
	return _for_display(d)


## The conversation keeps the patient's words as they came. The screen can only draw what
## the bitmap font has, so typographic quotes, dashes and accents are made plain here.
func _for_display(d: Dictionary) -> Dictionary:
	for key in ["reply", "line", "reaction"]:
		var raw := str(d.get(key, ""))
		var plain := Gfx.printable(raw)
		if raw != "" and plain == "" and key != "reaction":
			plain = "..."
		d[key] = plain
	return d


func _show_reaction(response: Dictionary, token: int) -> bool:
	var reaction := str(response.get("reaction", ""))
	if reaction == "":
		return token == _seq
	return await _narrate(_patient_name(), reaction, token, 0.35)


func _spent(token: int) -> void:
	audio.play("beep_low")
	_base_hint = "Out of patience: no new tests or questions. Reassure, or decide."
	var lines: Dictionary = visit.case_data.get("lines", {})
	_log("spent", {})
	_patient_line(str(lines.get("spent", "")), token, 1.0)


func _open_scope(tool: String) -> void:
	if visit == null:
		return
	var already := visit.seen.has("check:" + tool)
	clinic.scope.open(tool, visit.case_data, already, "Noted on the card." if already else "")
	clinic.scope.pointer(_mouse - Gfx.HOLE.position)
	desk.active = tool
	if tool == "penlight":
		audio.play("light_on")
	audio.loop("scope_hum", -18.0)
	_base_hint = str(SCOPE_HINT[tool])
	_log("scope_open", {"tool": tool})


func _close_scope(sound: bool) -> void:
	if not clinic.scope.is_open():
		return
	clinic.scope.button(false)
	clinic.scope.close()
	desk.active = ""
	audio.stop_loop("scope_hum")
	if sound:
		audio.play("tool_put")
	_base_hint = ""


## The interaction ran to its end: the evidence was shown, so the note is written.
func _on_scope_completed(tool: String) -> void:
	if visit == null or state != State.EXAM:
		return
	var before := _note_keys()
	var res: Dictionary = visit.complete_check(tool)
	if not bool(res.get("ok", false)):
		return
	clinic.scope.set_result("Noted on the card.")
	_mark_new_notes(before)
	_log("check_done", {"tool": tool})
	_after_check(tool, str(res.get("text", "")), _seq)


func _after_check(tool: String, text: String, token: int) -> void:
	var ok: bool = await _narrate(str(TOOL_LABEL[tool]), text, token, 1.1)
	if not ok or visit == null:
		return
	var lines: Dictionary = visit.case_data.get("lines", {})
	var aside := str(lines.get("after:" + tool, ""))
	if aside != "" and agent.mode != "model":
		_patient_line(aside, token, 0.0)


func act_ask_menu() -> void:
	if not _can_act():
		return
	if dialogue.has_menu():
		act_cancel()
		return
	_begin_action()
	var options: Array = []
	for t in visit.case_data.get("topics", []):
		var topic: Dictionary = t
		var id := str(topic.get("id", ""))
		var known := visit.answered.has(id)
		options.append({"id": id, "label": str(topic.get("q", "")), "dim": known,
			"tag": "asked" if known else "-%d" % visit.ask_cost(id)})
	dialogue.set_menu("ASK", options)
	_base_hint = "Pick a question. Right-click closes the list."
	audio.play("click")


## said: the doctor's own wording of the question, when it was typed or spoken.
func act_ask(id: String, said: String = "") -> void:
	if not _can_act():
		return
	var topic: Dictionary = visit.topic(id)
	if topic.is_empty():
		return
	var token := _begin_action()
	if visit.patience < visit.ask_cost(id):
		_spent(token)
		return
	var before := _note_keys()
	var question := said if said != "" else str(topic.get("q", ""))
	var d: Dictionary = await _decide({"type": "ask", "id": id}, visit.legal_moves_for_ask(id), question, token)
	if d.is_empty():
		return
	var res: Dictionary
	if str(d.get("source")) == "model":
		res = visit.apply_dialogue(id, str(d.reply), str(d.reaction))
	else:
		res = visit.apply_ask(id, str(d.get("move", "")))
	_sync_visit()
	var result := str(res.get("result", ""))
	_log("ask", {"topic": id, "move": str(res.get("move", "")), "result": result, "cost": int(res.get("cost", 0)),
		"patience": visit.patience, "source": str(d.get("source", ""))})
	if not await _show_reaction(d, token):
		return
	match result:
		"answered":
			_mark_new_notes(before)
			_patient_line(str(res.get("line", "")), token, 0.0)
		"deflected":
			_base_hint = "They dodged it. Ask the same thing again and they answer."
			_patient_line(str(d.get("line", "")), token, 0.0)
		"spent":
			_spent(token)


func act_reassure() -> void:
	if not _can_act():
		return
	var token := _begin_action()
	var used := visit.reassure_used
	if visit.reassure_left <= 0:
		audio.play("beep_low")
		return
	var d: Dictionary = await _decide({"type": "reassure", "id": "calm"}, [], str(REASSURE_LINES[mini(used, REASSURE_LINES.size() - 1)]), token)
	if d.is_empty():
		return
	var res: Dictionary = visit.reassure()
	if str(res.get("result", "")) != "ok":
		audio.play("beep_low")
		return
	_sync_visit()
	_log("reassure", {"patience": visit.patience})
	audio.play("calm")
	if not await _show_reaction(d, token):
		return
	if rig != null:
		rig.soften()
	_patient_line(str(d.get("reply", "")), token, 0.0)


## Pressure dialogue is autonomous; existing physical attack choreography remains in VisitState.
func act_press() -> void:
	if not _can_act():
		return
	var token := _begin_action()
	var d: Dictionary = await _decide({"type": "press", "id": "challenge"}, [], str(PRESS_LINES[mini(visit.press_count, PRESS_LINES.size() - 1)]), token)
	if d.is_empty():
		return
	var before := _note_keys()
	var res: Dictionary = visit.press()
	res["line"] = str(d.get("reply", res.get("line", "")))
	var result := str(res.get("result", ""))
	_sync_visit()
	_log("press", {"count": visit.press_count, "result": result, "patience": visit.patience})
	if not await _show_reaction(d, token):
		return
	match result:
		"react":
			if rig != null:
				rig.react(str(res.get("face", "")), str(res.get("hands", "")))
			audio.play("sting")
			_mark_new_notes(before)
			_patient_line(str(res.get("line", "")), token, 0.0)
		"walkout":
			_walkout(str(res.get("line", "")), token)
		"attack":
			_attack_sequence(str(res.get("line", "")), token)


## The doctor says something in their own words: typed, or dictated and then sent.
## With the patient model the words go to it as they are and it answers for itself; nothing
## here matches them against prepared answers. The offline comparison has only its script,
## so there (and only there) the sentence is matched to the questions that case knows.
func act_say(text: String) -> void:
	text = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if not _can_act() or text.is_empty() or text.length() > 500:
		return
	var with_model := agent.mode == "model"
	if not with_model:
		var known := ScriptedBrain.topic_for_text(visit.case_data, text)
		if known != "":
			_log("say", {"source": "script", "topic": known, "chars": text.length()})
			act_ask(known, text)
			return
	var token := _begin_action()
	if with_model and visit.patience < visit.ask_cost("free"):
		_spent(token)
		return
	var before := _note_keys()
	var d: Dictionary = await _decide({"type": "say", "id": "free"}, [], text, token)
	if d.is_empty():
		return
	var source := str(d.get("source", ""))
	_log("say", {"source": source, "chars": text.length(), "patience": visit.patience,
		"fallback_reason": str(d.get("fallback_reason", ""))})
	if source != "model":
		# no answer from a patient model: nothing is charged and nothing goes on the card
		_base_hint = SAY_OFFLINE_HINT if source == "script" else _fallback_hint(str(d.get("fallback_reason", "")))
		_patient_line(str(d.get("reply", "")), token, 0.0)
		return
	visit.apply_dialogue("free", str(d.reply), str(d.reaction))
	_sync_visit()
	_mark_new_notes(before)
	if await _show_reaction(d, token):
		_patient_line(str(d.reply), token, 0.0)


func _fallback_hint(reason: String) -> String:
	if reason == "call_cap":
		return "The patient AI has used its %d replies for this visit. Scripted lines now." % agent.max_calls
	return "The patient AI gave no answer (%s). Scripted line, no charge." % reason.left(26)


## Opens the typing line under the window.
func act_say_open(prefill: String = "") -> void:
	if not _can_act():
		return
	_begin_action()
	dialogue.open_input(prefill)
	_base_hint = _say_hint()
	audio.play("click", 1.25, -8.0)


func _say_hint() -> String:
	return SAY_VOICE_HINT if _mic_why_not() == "" else SAY_HINT


func _close_say() -> void:
	_mic_drop("line_closed")      # a clip being heard or written down goes with the line
	if not dialogue.input_open:
		return
	dialogue.close_input()
	_base_hint = ""


## A key while the typing line is open. Everything printable is text, SPACE included.
func _say_key(keycode: int, unicode: int) -> void:
	match keycode:
		KEY_ENTER, KEY_KP_ENTER:
			var text := dialogue.input_text.strip_edges()
			if text == "":
				act_cancel()
			else:
				act_say(text)
		KEY_ESCAPE:
			act_cancel()
		KEY_BACKSPACE:
			if dialogue.input_backspace():
				_base_hint = _say_hint()
		KEY_DELETE:
			if dialogue.input_delete():
				_base_hint = _say_hint()
		KEY_LEFT:
			dialogue.input_move(-1)
		KEY_RIGHT:
			dialogue.input_move(1)
		KEY_HOME:
			dialogue.input_move(-9999)
		KEY_END:
			dialogue.input_move(9999)
		_:
			if unicode < 32 or unicode > 126:
				return      # the counter font is plain ASCII
			if dialogue.input_insert(char(unicode)):
				audio.play("click", 1.7 + _fx_rng.randf_range(-0.08, 0.08), -17.0)
			else:
				_base_hint = SAY_FULL_HINT
				audio.play("beep_low", 1.0, -10.0)


# ---------------------------------------------------------------- push-to-talk
# Speaking is another way to fill the typing line, never a second way to talk to the patient:
# the words come back as text, the player reads and corrects them, and ENTER sends them through
# act_say like anything typed. The microphone is open only between key-down and key-up.

## Why speaking cannot be offered, or "": "off" | "no_service" | "no_mic".
func _mic_why_not() -> String:
	if not bool(_mic_rules.get("enabled", false)):
		return "off"
	# speaking exists only where the patient AI does: the offline comparison never touches the network
	var client: Variant = agent.client if agent != null else model_client
	var with_model: bool = (agent.mode == "model") if agent != null else use_model
	if not with_model or client == null or not client.has_method("request_transcript") or not client.is_configured():
		return "no_service"
	if mic == null or mic.problem() != "":
		return "no_mic"
	return ""


## The speak key or button went down: open the microphone and listen for as long as it is held.
## The typing line shows it. Whatever was typed there already is kept.
func act_speak_start(from: String = "key") -> void:
	if _mic_state != "" or not _can_act():
		return
	var why := _mic_why_not()
	if why == "" and agent.voice_clips_this_visit >= agent.max_voice_clips:
		why = "clip_cap"
	if why != "":
		_mic_refuse(why)
		return
	var kept := ""
	var opened := not dialogue.input_open
	if opened:
		_begin_action()
		dialogue.open_input("")
	else:
		kept = dialogue.input_text
	var err := mic.start()
	if err != "":
		if opened:
			dialogue.close_input()
		_mic_refuse("no_mic", err)
		return
	_mic_token += 1
	_mic_state = "listening"
	_mic_from = from
	_mic_held = 0.0
	_mic_wait = 0.0
	_mic_kept = kept
	_mic_opened_line = opened
	dialogue.input_status = "listening"
	dialogue.input_level = 0.0
	dialogue.input_seconds = 0.0
	_base_hint = MIC_LISTEN_HINT
	audio.duck(true)
	_log("voice", {"stage": "listening", "from": from})


func _mic_refuse(why: String, detail: String = "") -> void:
	_base_hint = str(MIC_HINTS.get(why, ""))
	audio.play("beep_low", 1.0, -10.0)
	_log("voice", {"stage": "refused", "reason": why if detail == "" else "%s:%s" % [why, detail]})


## The key came up, or the clip is full: close the microphone and have the words written down.
## Nothing is said to the patient here. The words go into the typing line for the player to check.
func act_speak_stop() -> void:
	if _mic_state != "listening":
		return
	var was_opening := mic.opening
	var clip: Dictionary = mic.stop()
	audio.duck(false)
	var held := _mic_held
	var seconds := float(clip.get("seconds", 0.0))
	var peak := float(clip.get("peak", 0.0))
	var numbers := {"held_ms": int(held * 1000.0), "open_ms": int(_mic_wait * 1000.0), "clip_ms": int(seconds * 1000.0),
		"peak": snappedf(peak, 0.001)}
	var problem := ""
	if was_opening:
		problem = "opening"       # let go before the device was ready: nothing was heard
	elif held < float(_mic_rules.get("min_seconds", 0.35)):
		problem = "tap"
	elif seconds < 0.2:
		problem = "no_audio"
	elif peak < float(_mic_rules.get("silence_peak", 0.012)):
		problem = "silence"
	if problem != "":
		# nothing worth sending: the clip is dropped here and no request is made
		numbers.merge({"stage": "not_sent", "reason": problem})
		_log("voice", numbers)
		_mic_settle(str(MIC_HINTS[problem]))
		return
	_mic_token += 1
	var token := _mic_token
	_mic_state = "transcribing"
	_mic_from = ""
	dialogue.input_status = "transcribing"
	_base_hint = MIC_WAIT_HINT
	numbers["stage"] = "sent"
	_log("voice", numbers)
	var wav: PackedByteArray = clip.get("wav", PackedByteArray())
	clip.clear()
	var res: Dictionary = await agent.transcribe(wav)
	if token != _mic_token or res.is_empty():
		return      # thrown away meanwhile, or the patient has gone: late words go nowhere
	var waited := int(res.get("latency_ms", 0))
	if not bool(res.get("ok", false)):
		var reason := str(res.get("error", "error"))
		_log("voice", {"stage": "failed", "reason": reason, "latency_ms": waited})
		_mic_settle(_mic_failure_hint(reason))
		audio.play("beep_low", 1.0, -10.0)
		return
	var words := Gfx.printable(str(res.get("text", ""))).strip_edges()
	if words == "":
		_log("voice", {"stage": "failed", "reason": "unreadable", "latency_ms": waited})
		_mic_settle(str(MIC_HINTS["unreadable"]))
		audio.play("beep_low", 1.0, -10.0)
		return
	var whole := _mic_kept
	if whole != "" and not whole.ends_with(" "):
		whole += " "
	whole += words
	_mic_state = ""
	dialogue.input_status = ""
	dialogue.input_set(whole)
	var cut := dialogue.input_text.length() < whole.length()
	var mock := bool(res.get("mock", false))
	_base_hint = MIC_CUT_HINT if cut else (MIC_MOCK_HINT if mock else MIC_DONE_HINT)
	audio.play("pencil", 1.2, -8.0)
	_log("voice", {"stage": "transcript", "chars": words.length(), "cut": cut, "mock": mock, "latency_ms": waited})


func _mic_failure_hint(reason: String) -> String:
	if reason.ends_with(":no_speech"):
		return str(MIC_HINTS["no_speech"])
	if reason == "clip_cap" or reason.ends_with("_transcribe_cap"):
		return str(MIC_HINTS["clip_cap"])
	if reason.ends_with(":transcription_unavailable"):
		return MIC_DEAF_HINT
	if reason == "timeout" or reason.ends_with(":upstream_timeout"):
		return str(MIC_HINTS["slow"])
	if reason.ends_with(":budget_exhausted"):
		return str(MIC_HINTS["budget"])
	# the short code is enough on the counter; the whole reason is in the event log
	return "Could not write that down (%s). Try again, or type with T." % reason.get_slice(":", 0).left(24)


## The device could not be opened after all (it opens on a worker thread after the key went down).
func _on_mic_failed(reason: String) -> void:
	if _mic_state != "listening":
		return
	_mic_token += 1
	audio.duck(false)
	_mic_settle(str(MIC_HINTS["no_mic"]))
	dialogue.input_status = ""
	audio.play("beep_low", 1.0, -10.0)
	_log("voice", {"stage": "refused", "reason": "no_mic:%s" % reason})


## ESC or right-click while the microphone has the line: nothing is sent, typed words stay.
func act_speak_cancel() -> void:
	if _mic_state == "":
		return
	_mic_drop("cancelled")
	_mic_settle(str(MIC_HINTS["cancelled"]))
	audio.play("tool_put", 1.3, -8.0)


## Throws away the clip being heard or written down. A transcript that arrives later is ignored.
func _mic_drop(why: String) -> void:
	if _mic_state == "":
		return
	_log("voice", {"stage": "dropped", "while": _mic_state, "reason": why})
	_mic_token += 1
	mic.cancel()
	audio.duck(false)
	_mic_state = ""
	_mic_from = ""
	dialogue.input_status = ""


## The microphone lets go of the line without words: back to what was typed, or to the patient.
func _mic_settle(hint: String) -> void:
	_mic_state = ""
	_mic_from = ""
	if dialogue.input_open:
		dialogue.input_status = ""
		if _mic_opened_line and dialogue.input_text == "":
			dialogue.close_input()
	_base_hint = hint


func act_mark(row: String) -> void:
	if state != State.EXAM or visit == null:
		return
	visit.cycle_mark(row)
	audio.play("pencil", 1.3, -6.0)


func act_pick_stamp(kind: String) -> void:
	if kind != "treat":
		return
	var meanwhile := _can_decide() and _answer_pending()
	if not _can_act() and not meanwhile:
		return
	if _held == kind:
		act_cancel()
		return
	if meanwhile:
		_disarm()                      # the answer still comes; only what is in hand changes
	else:
		_begin_action()
	_held = kind
	desk.held = kind
	clipboard.armed = kind
	_held_sprite.texture = Gfx.tex("ui/stamp_%s.png" % kind)
	_base_hint = "Stamp the intake card to decide. Right-click puts it back."
	audio.play("tool_pick", 0.9)


func _drop_stamp(sound: bool) -> void:
	if _held == "":
		return
	_held = ""
	desk.held = ""
	clipboard.armed = ""
	if sound:
		audio.play("tool_put")
	_base_hint = ""


func act_stamp_record() -> void:
	if _held != "":
		act_verdict(_held)


## The call box. Trauma Team cannot be called back, so it takes two presses: the first opens
## the line, the second sends the crew. Like TREAT it is allowed at any moment of the exam.
func act_call_team() -> void:
	var meanwhile := _can_decide() and _answer_pending()
	if not _can_act() and not meanwhile:
		return
	if _call_armed > 0.0:
		act_verdict("refer")
		return
	if meanwhile:
		_drop_stamp(false)             # the answer still comes; only what is in hand changes
	else:
		_begin_action()
	_call_armed = CALL_ARM_TIME
	desk.armed = "refer"
	_alert_hint = "TRAUMA TEAM LINE OPEN. Press again to call them in. Right-click hangs up."
	audio.play("beep", 1.3, -5.0)
	_log("call_line_open", {"patience": visit.patience})


## The two decisions: TREAT, or hand the patient over to Trauma Team (in the data that one is
## still called "refer"). Allowed at any moment of the exam; nothing has to be checked first.
func act_verdict(kind: String) -> void:
	if not _can_decide() or not (kind == "treat" or kind == "refer"):
		return
	if _answer_pending():
		# deciding does not wait for the answer: the reply still on its way is dropped, unread
		_log("reply_dropped", {"by": kind, "stage": "thinking" if _thinking else "line"})
		_thinking = false
		_lock = false
		dialogue.thinking = false
	var token := _begin_action()
	var res: Dictionary = visit.verdict(kind)
	var next := str(res.get("next", ""))
	if next == "":
		return
	_first_visit_done = true
	state = State.ATTACK if next == "attack" else State.RESOLVE
	_desk_off()
	clipboard.stamp(kind)
	audio.play("stamp" if kind == "treat" else "radio")
	_shake(2.0, 0.14)
	_log("verdict", {"kind": kind, "next": next, "patience": visit.patience, "seen": visit.seen.keys()})
	var exits: Dictionary = visit.case_data.get("exit", {})
	var ok: bool = await _wait(0.35, token)
	if not ok:
		return
	if kind == "refer":
		# the line answers before anybody in the room says a word
		ok = await _crew_line("DISPATCH", DISPATCH_LINE, token, 0.5)
		if not ok:
			return
	if next == "attack":
		_attack_sequence(str(exits.get(kind, "")), token)
		return
	ok = await _patient_line(str(exits.get(kind, "")), token, 0.7)
	if not ok:
		return
	if kind == "treat":
		await _leave(-1.0, false)
	else:
		ok = await _team_takes(token)
		if not ok:
			return
	_resolve()


## A voice on the call box, or one of the crew. Authored lines only.
func _crew_line(label: String, text: String, token: int, hold: float = 0.7) -> bool:
	_patient_talking = false
	_set_voice("blip_narrate", 0.72, -11.0)
	dialogue.say(label, text, Gfx.RED3, Gfx.TEAL7, 64.0)
	var ok: bool = await _run_line(token, hold)
	return ok


## The crew the player called arrives: the siren outside, their lights through the hall, two
## of them behind the patient, and the patient walked out between them. It plays the same way
## for everybody who does not fight, and none of it is decided by the patient model.
func _team_takes(token: int) -> bool:
	audio.play("siren", 1.0, -2.0)
	clinic.strobe = 0.55
	var ok: bool = await _wait(1.1, token)
	if not ok:
		return false
	clinic.door(true)
	audio.play("door_open", 0.85, -2.0)
	clinic.strobe = 1.0
	clinic.team_to(0.0, 0.5)
	var next_step := 0.0
	while clinic.team_moving():
		await get_tree().process_frame
		if token != _seq:
			return false
		next_step -= get_process_delta_time()
		if next_step <= 0.0:
			audio.play("step", 0.7, -3.0)
			next_step = 0.12
	if rig != null and visit != null:
		var press: Array = visit.case_data.get("press", [])
		if not visit.is_drifting() and not press.is_empty():
			# a steady patient takes it the way they take any insult: face and voice together
			var first: Dictionary = press[0]
			rig.react(str(first.get("face", "")), str(first.get("hands", "")))
		else:
			rig.shake(1.0, 0.25)
	ok = await _crew_line("TRAUMA TEAM", CREW_LINE, token, 0.6)
	if not ok:
		return false
	var exits: Dictionary = {}
	if visit != null:
		exits = visit.case_data.get("exit", {})
	var taken := str(exits.get("taken", ""))
	if taken != "":
		ok = await _patient_line(taken, token, 0.5)
		if not ok:
			return false
	# out through the hall door at one pace, the crew backing out first
	var dur := 1.0
	var t := 0.0
	next_step = 0.0
	while t < dur and rig != null:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / dur, 0.0, 1.0)
		rig.slide = k * k
		clinic.team_k = minf(1.0, PatientRig.SLIDE_PX * k * k / ClinicView.TEAM_OUT)
		next_step -= dt
		if next_step <= 0.0:
			audio.play("step", 0.8, -5.0)
			next_step = 0.17
	_remove_rig()
	clinic.team_k = 1.0
	clinic.door(false)
	audio.play("door_slam", 0.9, -5.0)
	_shake(1.0, 0.12)
	# their lights pull away down the street
	var fade := 0.7
	while fade > 0.0:
		await get_tree().process_frame
		fade -= get_process_delta_time()
		clinic.strobe = maxf(0.0, fade / 0.7)
	clinic.team_clear()
	return token == _seq


func _walkout(line: String, token: int) -> void:
	_first_visit_done = true
	state = State.RESOLVE
	_desk_off()
	if rig != null:
		rig.shake(1.0, 0.25)
	var ok: bool = await _patient_line(line, token, 0.6)
	if not ok:
		return
	await _leave(1.0, true)
	_resolve()


## dir: +1 out through the hall door, -1 through to the chair. fast: storming out.
func _leave(dir: float, fast: bool) -> void:
	if rig == null:
		return
	if dir > 0.0:
		clinic.door(true)
		audio.play("door_open", 1.1, -4.0)
	var dur := 0.45 if fast else 0.85
	var t := 0.0
	var next_step := 0.0
	while t < dur and rig != null:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / dur, 0.0, 1.0)
		if rig != null:
			rig.slide = dir * k * k
		next_step -= dt
		if next_step <= 0.0:
			audio.play("step", 1.2 if fast else 1.0, -8.0)
			next_step = 0.16 if fast else 0.24
	_remove_rig()
	if dir > 0.0:
		clinic.door(false)
		if fast:
			audio.play("door_slam")
			_shake(2.0, 0.15)


func _remove_rig() -> void:
	if rig == null:
		return
	gore.flare_off()
	rig.back.queue_free()
	rig.front.queue_free()
	rig.queue_free()
	rig = null
	_patient_talking = false
	clinic.clear_zone()


# ================================================================ danger

## The patient turns. A silent beat first: the lamp stutters and the hall goes dim. Then
## everything that warns the player happens at once: the face, the weapon, the red light, the
## alarm, the lever throbbing. Three blows land on the glass, each cracking it further, so the
## pane itself counts down. The shutter stops it; if it is still up when the window runs out,
## they come through.
func _attack_sequence(lead_line: String, token: int) -> void:
	_first_visit_done = true
	state = State.ATTACK
	_telegraphed = false
	_attack_t = 0.0
	_blows = 0
	_desk_off()
	desk.enabled["shutter"] = true
	_base_hint = ""
	var ok: bool = await _patient_line(lead_line, token, 0.15)
	if not ok:
		return
	var attack_rules: Dictionary = rules.get("attack", {})
	var attack: Dictionary = visit.case_data.get("attack", {})
	if rig != null:
		rig.frozen = true
	_patient_talking = false
	audio.set_loop_volume("amb_drone", -50.0)
	clinic.flicker = 0.55
	clinic.hall_dark = 0.4
	var beat := _rng.randf_range(float(attack_rules.get("beat_min_ms", 600)), float(attack_rules.get("beat_max_ms", 1200))) / 1000.0
	ok = await _wait(beat, token)
	if not ok:
		return
	_telegraphed = true
	var saw := _attack_style() == "saw"
	if rig != null:
		rig.frozen = false
		rig.set_attack(true)
		if not saw:
			gore.flare_follow(rig, "tool", 5.0, Color("5ee6e0"))      # the torch arm lights
	clinic.danger = 1.0
	clinic.flicker = 1.0
	clinic.hall_dark = 0.82
	desk.pulse = "shutter"
	_alert_hint = "DROP THE SHUTTER!   [SPACE]"
	audio.trim_db = ATTACK_TRIM_DB      # back to 0 when the result slip prints
	audio.play("turn_hit")
	audio.play("scream", _scream_pitch(), -1.0)
	audio.play("whine")
	audio.play("heartbeat")
	audio.loop("alarm", -7.0)
	_weapon_loop = "saw_loop" if saw else "torch_loop"
	audio.loop(_weapon_loop, -9.0)
	_flash_now(Color(1.0, 0.22, 0.18), 0.4, 0.25)
	_shake(3.0, 0.3)
	_set_voice("", 1.0, 0.0)
	dialogue.say("", str(attack.get("telegraph", "")), Gfx.RED3, Gfx.RED3, 140.0)
	_log("attack", {"cause": visit.attack_cause, "beat_ms": int(beat * 1000.0)})
	var window := float(attack_rules.get("window_ms", 1800)) / 1000.0
	while _attack_t < window:
		await get_tree().process_frame
		if token != _seq:
			return
		var dt := get_process_delta_time()
		_attack_t += dt
		while _blows < BLOW_AT.size() and _attack_t >= float(BLOW_AT[_blows]) * window:
			_blows += 1
			_blow(_blows)
		_attack_fx(dt)
	_bump()
	visit.attack_timeout()
	_log("attack_hit", {})
	_hit()


func _attack_style() -> String:
	return rig.attack_style() if rig != null else "saw"


## One sample serves both: pitched down it is a roar, pitched up it is a scream.
func _scream_pitch() -> float:
	return 0.6 if _attack_style() == "saw" else 1.12


## A shutter that has been hit before takes the next blows a little to one side.
func _dent_spot(spots: Array, i: int) -> Vector2:
	var spot: Vector2 = spots[i % spots.size()]
	var n := clinic.dent_count()
	if n >= 3:
		spot += Vector2(float((n * 37) % 41 - 20), float((n * 23) % 31 - 15))
	return spot


func _stop_attack_audio() -> void:
	audio.stop_loop("alarm")
	audio.stop_loop("saw_loop")
	audio.stop_loop("torch_loop")
	_weapon_loop = ""


func _on_splat(size: float) -> void:
	if _t - _splat_at < 0.05:
		return
	_splat_at = _t
	audio.play("splat", _fx_rng.randf_range(0.85, 1.2) * (0.8 if size > 150.0 else 1.0), -2.0 if size > 60.0 else -8.0)


## One blow on the glass: 1 the open hand, 2 the weapon, 3 the forehead. Each leaves more of
## them on the pane. The wet marks are gone by the time the shutter goes back up; the cracks,
## the gouge and the prints are there for the rest of the night.
func _blow(n: int) -> void:
	if rig == null:
		return
	var saw := _attack_style() == "saw"
	var origin := Gfx.HOLE.position
	# a pane that was cracked earlier tonight only gets worse; one that is gone is just a hole
	var pane := clinic.glass_state < 4
	rig.blow(n)
	if pane:
		clinic.set_glass(mini(3, maxi(clinic.glass_state + 1, n)))
	match n:
		1:
			audio.play("bang", 1.15)
			_shake(3.0, 0.2)
			if pane:
				audio.play("glass_crack", 1.0, -2.0)
				if not less_blood:
					audio.play("splat", 1.25, -7.0)
					clinic.add_decal("fx/spray_0.png", ClinicView.HIT_HAND + Vector2(-22, 28))
					clinic.add_decal("fx/hand_0.png", ClinicView.HIT_HAND + Vector2(0, -4), false, 0.0, true)
				gore.chips(origin + ClinicView.HIT_HAND, 3)
			gore.droplets(origin + ClinicView.HIT_HAND, 9, Vector2(0, -1), 1.6, 30.0, 90.0, 2)
		2:
			_shake(4.0, 0.3)
			if saw:
				audio.play("saw_grind")
				if pane:
					clinic.add_decal("fx/gouge_0.png", ClinicView.HIT_TOOL + Vector2(8, -6))
					if not less_blood:
						clinic.add_decal("fx/castoff_0.png", ClinicView.HIT_TOOL + Vector2(40, -34), false, 0.0, true)
					gore.sparks(origin + ClinicView.HIT_TOOL, 28, Vector2(0.6, -0.7), 1.3, 80.0, 260.0)
					gore.flare_follow(rig, "tool", 3.0, Color("ffb45a"))      # steel on glass
				else:
					audio.play("slash", 1.2, -6.0)
			else:
				audio.play("torch_burst")
				if pane:
					clinic.add_decal("fx/scorch.png", ClinicView.HIT_TOOL)
					clinic.add_decal("fx/scorch_hot.png", ClinicView.HIT_TOOL, true, 2.6)
				gore.sparks(origin + ClinicView.HIT_TOOL, 24, Vector2(0.0, -1.0), PI, 60.0, 210.0, Color("c8fff6"))
				gore.flare_follow(rig, "tool", 8.0, Color("5ee6e0"))          # full flame
				_flash_now(Color(0.75, 1.0, 1.0), 0.3, 0.2)
			if pane:
				audio.play("glass_crack", 0.85, -2.0)
				gore.chips(origin + ClinicView.HIT_TOOL, 4)
		_:
			audio.play("bang", 0.8, 2.0)
			audio.play("scream", _scream_pitch() * 1.1, -4.0)
			_shake(5.0, 0.35)
			_flash_now(Color(1.0, 0.86, 0.8), 0.3, 0.15)
			if pane:
				audio.play("glass_crack", 1.2)
				if not less_blood:
					audio.play("splat", 1.0, -3.0)
					clinic.add_decal("fx/smear_0.png", ClinicView.HIT_HEAD + Vector2(0, 18), false, 0.0, true)
					clinic.add_decal("fx/splat_a1.png", ClinicView.HIT_HEAD + Vector2(36, -20), false, 0.0, true)
					clinic.add_decal("fx/splat_m0.png", ClinicView.HIT_HEAD + Vector2(-2, -2))
				gore.chips(origin + ClinicView.HIT_HEAD, 7)
			gore.droplets(origin + ClinicView.HIT_HEAD, 16, Vector2(0, -1), PI, 30.0, 95.0, 2)


## While the weapon is on the glass it throws sparks.
func _attack_fx(delta: float) -> void:
	if rig == null or _blows < 2:
		return
	_spark_t -= delta
	if _spark_t > 0.0:
		return
	_spark_t = 0.04
	var p := rig.attack_point("tool")
	if _attack_style() == "saw":
		if clinic.glass_state < 4:      # the saw only sparks while there is glass to bite
			gore.sparks(p, 3, Vector2(0.55, -0.8), 0.9, 50.0, 170.0)
	else:
		gore.sparks(p, 2, Vector2(0.0, 1.0), 1.5, 25.0, 110.0, Color("c8fff6"))


## Too slow. The pane goes and they come through it at the player: glass, the weapon across
## the eyes, then again from closer, then a third time with nobody left to stop it. After that
## nothing, until the emergency shutter has done its work. What it leaves behind stays for
## the rest of the shift.
func _hit() -> void:
	state = State.RESOLVE
	_desk_off()
	_alert_hint = ""
	var token := _seq
	var saw := _attack_style() == "saw"
	var pitch := _scream_pitch()
	var face := Vector2(300, 178)
	var hot := Color("fbe9b5") if saw else Color("c8fff6")
	var cyan := Color("5ee6e0")
	audio.stop_loop("alarm")
	dialogue.clear()
	if clinic.glass_state < 4:
		audio.play("glass_shatter")
		gore.burst_shards(Gfx.HOLE, 64)
	else:
		gore.burst_shards(Gfx.HOLE, 9, 0.8)      # what was still standing in the frame
	audio.play("hit", 1.0, -2.0)
	audio.play("scream", pitch * 1.1, 2.0)
	if _weapon_loop != "":
		audio.set_loop_volume(_weapon_loop, -3.0)
	clinic.set_glass(4)
	clinic.sill_blood(true)
	gore.droplets(Gfx.HOLE.get_center(), 36, Vector2(0, -1), PI, 60.0, 260.0, 3)
	_flash_now(Color(1.0, 0.96, 0.9), 0.85, 0.22)
	_shake(9.0, 0.5)
	if rig != null:
		gore.take(rig)
		if saw:
			gore.flare_follow(rig, "tool", 2.5, Color("ffb45a"))
		else:
			gore.flare_follow(rig, "tool", 7.0, cyan)
		rig.pop_target = face
		rig.shake(5.0, 2.4)
	await _pop_to(1.0, 0.2, true)

	# one: across the eyes
	if saw:
		audio.play("slash")
		audio.play("saw_grind", 1.25, 1.0)
		gore.slash(Vector2(540, 24), Vector2(96, 336))
		gore.gash(Vector2(528, 34), Vector2(108, 326), 0.09)
	else:
		audio.play("torch_burst", 0.8, 2.0)
		gore.bloom(Vector2(238, 196), cyan, 230.0, 0.55)
		gore.afterimage(Vector2(238, 196), 70.0)
		_flash_now(Color(0.8, 1.0, 1.0), 0.58, 0.2)
	_shake(10.0, 0.6)
	gore.sparks(face + Vector2(-60, 30), 40, Vector2(0.4, -0.8), PI, 90.0, 420.0, hot)
	await _wait(0.07, token)
	_flash_now(Color(0.78, 0.03, 0.05), 0.6, 0.5)
	gore.vignette = 1.0
	gore.droplets(face, 70, Vector2(0, -1), PI, 80.0, 440.0, 3)
	# the first blood lands round the edges of the view: their face stays in the middle of it
	gore.splat(Vector2(92, 96), "l", 2.0)
	gore.splat(Vector2(552, 86), "l", 1.6, 0.05)
	gore.splat(Vector2(82, 296), "l", 1.4, 0.1)
	gore.splat(Vector2(566, 288), "a", 2.0, 0.08)
	gore.splat(Vector2(330, 26), "a", 1.6, 0.15)
	gore.splat(Vector2(476, 334), "m", 2.0, 0.18)
	for i in 8:
		var at := Vector2(_fx_rng.randf_range(20.0, 620.0), _fx_rng.randf_range(14.0, 346.0))
		if FACE_CLEAR.has_point(at):
			at.x = _fx_rng.randf_range(24.0, 150.0) if at.x < 305.0 else _fx_rng.randf_range(460.0, 616.0)
		gore.splat(at, "m" if i % 3 == 0 else "s", 2.0 if i % 2 == 0 else 1.0, 0.1 + 0.05 * float(i))
	audio.play("tinnitus", 1.0, -4.0)
	audio.play("heartbeat")
	await _wait(0.42, token)

	# two: again, from closer
	if saw:
		audio.play("slash", 0.9)
		audio.play("saw_grind", 1.1)
		gore.slash(Vector2(70, 60), Vector2(590, 300))
		gore.gash(Vector2(84, 68), Vector2(576, 292), 0.09)
	else:
		audio.play("torch_burst", 0.7, 1.0)
		gore.bloom(Vector2(372, 168), cyan, 260.0, 0.5)
		gore.afterimage(Vector2(372, 168), 88.0)
		_flash_now(Color(0.85, 1.0, 1.0), 0.6, 0.2)
	audio.play("scream", pitch * 1.2, 1.0)
	_shake(11.0, 0.5)
	gore.sparks(face + Vector2(50, -10), 30, Vector2(-0.4, -0.8), PI, 90.0, 420.0, hot)
	gore.droplets(face, 60, Vector2(0, -1), PI, 80.0, 440.0, 3)
	gore.splat(Vector2(196, 262), "l", 2.0, 0.05)
	gore.splat(Vector2(444, 108), "l", 2.0, 0.09)
	gore.splat(Vector2(528, 204), "a", 2.0, 0.12)
	gore.splat(Vector2(144, 150), "m", 2.0, 0.16)
	await _pop_to(1.55, 0.38)

	# three: the one nobody is left to see
	audio.play("hit", 0.8, 2.0)
	audio.play("crunch", 0.9, 1.0)
	audio.play("scream", pitch * 0.9, 3.0)
	if saw:
		audio.play("slash", 0.75, 2.0)
		gore.slash(Vector2(326, 4), Vector2(296, 356))
		gore.gash(Vector2(324, 12), Vector2(298, 350), 0.06)
	else:
		audio.play("torch_burst", 0.6, 3.0)
		gore.bloom(face, cyan, 330.0, 0.4)
		gore.afterimage(face, 124.0)
	# the flash stays thin enough to read the face filling the view; the blood that covers it lands a beat later
	_flash_now(Color(0.86, 0.02, 0.04), 0.55, 0.3)
	_shake(14.0, 0.5)
	gore.droplets(face, 90, Vector2(0, -1), PI, 100.0, 520.0, 3)
	gore.splat(face + Vector2(128, 64), "l", 2.4, 0.05)
	gore.splat(face + Vector2(-156, 44), "l", 2.4, 0.09)
	gore.splat(Vector2(320, 58), "a", 2.6, 0.13)
	gore.splat(face + Vector2(-8, -14), "l", 3.0, 0.2)
	await _pop_to(2.3, 0.2, true)
	await _wait(0.2, token)
	await _fade_to(1.0, 0.1)

	# in the dark: the emergency shutter, and somebody dragging them off it
	_stop_attack_audio()
	clinic.danger = 0.0
	clinic.hall_dark = 0.0
	clinic.flicker = 0.0
	_remove_rig()
	gore.clear()
	clinic.shutter_to(1.0, 0.01)
	desk.lever_down = true
	_leave_hit_marks()
	audio.set_loop_volume("amb_drone", -24.0)
	audio.play("shutter_slam", 0.9, -3.0)
	audio.play("crunch", 0.8, -3.0)
	await _wait(0.35, token)
	audio.play("bang", 0.7, -6.0)
	audio.play("scream_far", pitch)
	await _wait(0.5, token)
	audio.play("bang", 0.65, -9.0)
	audio.play("heartbeat")
	await _wait(0.6, token)
	audio.play("drip")
	await _fade_to(0.0, 0.8)
	_resolve()


## Brings whoever came through the window closer: at 1 their face fills the screen, past 1
## it keeps coming.
func _pop_to(target: float, time: float, ease_out: bool = false) -> void:
	var from := rig.pop if rig != null else target
	var t := 0.0
	while t < time:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / time, 0.0, 1.0)
		if ease_out:
			k = 1.0 - (1.0 - k) * (1.0 - k)
		if rig != null:
			rig.pop = lerpf(from, target, k)


## What an attack that got through leaves for the rest of the night: the window broken out,
## our side of the emergency shutter, the wall and the counter round the frame, the desk.
func _leave_hit_marks() -> void:
	var again := clinic.gore_count() > 0      # a second one tonight lands a little to one side
	var nudge := Vector2(9, 6) if again else Vector2.ZERO
	clinic.set_glass(4)
	clinic.sill_blood(true)
	clinic.seep(18, true)
	clinic.shutter_gore()
	for mark in WALL_MARKS:
		clinic.add_stain("fx/%s.png" % str(mark[0]), (mark[1] as Vector2) + nudge)
	for mark in DESK_MARKS:
		_add_mess("fx/%s.png" % str(mark[0]), (mark[1] as Vector2) + (Vector2(3, -2) if again else Vector2.ZERO))


## Dried blood on our own side of the counter. Small, and never on a label.
func _add_mess(tex_path: String, center: Vector2) -> void:
	var t := Gfx.tex(tex_path)
	if less_blood or t == null:
		return
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.position = (center - t.get_size() / 2.0).round()
	sp.modulate = ClinicView.DRIED
	_mess.add_child(sp)


## The shutter came down in time. It lands on whatever was over the sill; then they go on
## hitting it from the far side, and the weapon finds its way through the metal.
func _caught(token: int) -> void:
	var saw := _attack_style() == "saw"
	var pitch := _scream_pitch()
	var reached := _blows
	clinic.clear_wet()      # what was running on the glass has run off it, behind the shutter
	clinic.hall_dark = 0.0
	clinic.flicker = 0.4
	if _weapon_loop != "":
		audio.set_loop_volume(_weapon_loop, -20.0)
	if reached >= 1:
		audio.play("crunch")
		audio.play("scream_far", pitch, 3.0)
		clinic.shutter_splash()
		clinic.sill_blood(true)
		clinic.seep(10, true)
		if not less_blood:
			audio.play("splat", 1.1, -2.0)
			audio.play("splat", 0.8, -4.0)
			clinic.add_decal("fx/hand_1.png", ClinicView.HIT_HAND + Vector2(0, 10))
		gore.droplets(Vector2(Gfx.HOLE.position.x + ClinicView.HIT_HAND.x, 198.0), 34, Vector2(0, -1), 1.3, 60.0, 260.0, 3)
		gore.droplets(Vector2(Gfx.HOLE.position.x + ClinicView.HIT_TOOL.x, 198.0), 22, Vector2(0, -1), 1.3, 60.0, 220.0, 2)
		_shake(6.0, 0.35)
	if clinic.glass_state == 3:
		# the pane was already going: it drops out of the frame behind the shutter
		audio.play("glass_shatter", 0.9, -7.0)
		clinic.set_glass(4)
	await _wait(0.55, token)
	for i in 3:
		audio.play("bang", 1.0 - 0.08 * float(i), float(i))
		clinic.shutter_dent(_dent_spot(DENT_SPOTS, i))
		_shake(3.0 + float(i), 0.2)
		await _wait(0.34 - 0.07 * float(i), token)
	if _weapon_loop != "":
		audio.set_loop_volume(_weapon_loop, -7.0)
	audio.play("saw_grind" if saw else "torch_burst", 1.0, 2.0)
	var style := "saw" if saw else "torch"
	var cut_at: Vector2 = CUT_AT[style]
	clinic.shutter_cut(style, cut_at, 0.8)
	if not saw:
		clinic.under_glow = 1.0
	var spark_in := 0.0
	while clinic.cut_active() and token == _seq:
		await get_tree().process_frame
		spark_in -= get_process_delta_time()
		if spark_in <= 0.0:
			spark_in = 0.03
			gore.sparks(clinic.cut_point(), 4, Vector2(0.2, 1.0) if saw else Vector2(0.0, 1.0), 1.6, 40.0, 220.0,
				Color("fbe9b5") if saw else Color("c8fff6"))
			_shake(2.0, 0.08)
	await _wait(0.45, token)
	_stop_attack_audio()
	clinic.flicker = 0.0
	clinic.under_glow = 0.45 if not saw else 0.0
	clinic.seep(4)
	audio.play("drip")
	await _wait(0.35, token)


## The shutter is always available. During an ordinary exam the first press only arms it,
## so a stray key cannot end a visit; when a patient has turned, one press is enough.
func act_shutter() -> void:
	if visit == null or not (state == State.EXAM or state == State.ATTACK):
		return
	if visit.phase == VisitState.Phase.DONE:
		return
	if state == State.EXAM and _armed <= 0.0:
		_disarm()      # an open call line is hung up: one armed decision at a time
		_close_say()   # and SPACE means the shutter again, not a space in a sentence
		_armed = ARM_TIME
		desk.pulse = "shutter"
		_alert_hint = "SHUTTER ARMED. Press SPACE again to drop it. That ends the visit."
		audio.play("lever", 1.4, -6.0)
		return
	_armed = 0.0
	_call_armed = 0.0
	_close_scope(false)
	dialogue.clear_menu()
	_drop_stamp(false)
	_close_say()
	var token := _bump()
	_thinking = false
	_lock = false
	audio.fade_out("whine", 0.12)      # a rising whine stopped dead would click behind the shutter
	var reaction_ms := int(_attack_t * 1000.0) if _telegraphed else -1
	var res: Dictionary = visit.shutter()
	var outcome := str(res.get("result", ""))
	if outcome == "":
		return
	_first_visit_done = true
	state = State.RESOLVE
	_log("shutter", {"outcome": outcome, "reaction_ms": reaction_ms})
	_desk_off()
	desk.lever_down = true
	_alert_hint = ""
	_base_hint = ""
	dialogue.clear()
	audio.play("lever")
	gore.flare_off()
	clinic.shutter_to(1.0, 0.16)
	while not clinic.shutter_closed():
		await get_tree().process_frame
	audio.play("shutter_slam")
	_shake(4.0, 0.25)
	audio.stop_loop("alarm")
	audio.set_loop_volume("amb_drone", -24.0)
	clinic.danger = 0.0
	clinic.hall_dark = 0.0
	if outcome != "caught":
		clinic.flicker = 0.0
		_stop_attack_audio()
	var attack: Dictionary = visit.case_data.get("attack", {})
	match outcome:
		"caught":
			await _caught(token)
			if str(attack.get("line", "")) != "":
				_patient_talking = false
				_set_voice("blip", 0.6, -16.0)
				dialogue.say(_patient_name() + " (through the shutter)", str(attack.get("line", "")), Gfx.TEAL5, Gfx.TEAL6, 30.0)
				await _run_line(token, 0.8)
			if visit.attack_cause == "refer":
				# the crew that was already on its way gets there
				audio.play("siren", 1.0, -6.0)
				clinic.strobe = 1.0
				await _narrate("", CREW_AFTER_LINE, token, 0.8)
				clinic.strobe = 0.0
		"locked_out":
			# they had not shown it yet; behind the shutter, they do
			await _wait(0.9, token)
			audio.play("scream_far", _scream_pitch(), 3.0)
			await _wait(0.3, token)
			for i in 3:
				audio.play("bang", 0.95 - 0.08 * float(i), float(i))
				clinic.shutter_dent(_dent_spot(DENT_SPOTS_LOCKED, i))
				_shake(3.0 + float(i), 0.2)
				await _wait(0.38 - 0.06 * float(i), token)
		_:
			await _wait(0.7, token)
			await _narrate("", "Nothing hits the shutter. After a while, footsteps, going away.", token, 0.7)
	_remove_rig()
	_resolve()


## Nothing is waiting for a second press any more: neither the shutter nor the call box.
func _disarm() -> void:
	_armed = 0.0
	_call_armed = 0.0
	desk.armed = ""
	if state == State.EXAM:
		desk.pulse = ""
		_alert_hint = ""


# ================================================================ result

func _resolve() -> void:
	if visit == null:
		return
	state = State.RESOLVE
	_desk_off()
	var token := _seq
	var s: Dictionary = visit.settlement()
	shift.record(s)
	if visit.verdict_kind == "":
		clipboard.stamp("void")
	clipboard.show_findings(s)
	clinic.show_patience = false
	clinic.danger = 0.0
	clinic.hall_dark = 0.0
	clinic.flicker = 0.0
	clinic.results.append(bool(s.get("correct", false)))
	_alert_hint = ""
	_base_hint = ""
	_slip_data = s
	_slip_index = shift.index + 1
	_slip_mode = "print"
	audio.trim_db = 0.0
	_slip_y = -SLIP_H
	_slip_age = 0.0
	audio.play("printer")
	_log("visit_end", {"outcome": str(s.get("outcome", "")), "verdict": str(s.get("verdict", "")),
		"truth": str(s.get("truth", "")), "correct": bool(s.get("correct", false)), "credits": int(s.get("credits", 0)),
		"patience_left": int(s.get("patience_left", 0)), "press_count": int(s.get("press_count", 0)),
		"seen": visit.seen.keys(), "model_calls": agent.calls_this_visit, "fallbacks": agent.fallbacks_this_visit})
	await _wait(0.8, token)
	clinic.till = shift.total()
	var credits := int(s.get("credits", 0))
	if credits > 0:
		audio.play("cash")
	elif credits < 0:
		audio.play("fail")
	audio.play("jingle_good" if bool(s.get("correct", false)) else "jingle_bad", 1.0, -5.0)
	state = State.SLIP
	_slip_age = 0.0


func act_continue() -> void:
	if state != State.SLIP or _slip_age < 0.5:
		return
	audio.play("tear")
	_slip_mode = "drop"
	clinic.under_glow = 0.0
	clinic.team_clear()
	shift.advance()
	_remove_rig()
	visit = null
	clipboard.set_visit(null, "")
	desk.badges.clear()
	desk.warn.clear()
	if shift.is_done():
		_show_report()
	else:
		if clinic.shutter_pos > 0.0:
			clinic.shutter_to(0.0, 0.9)
			audio.play("shutter_roll")
		desk.lever_down = false
		_begin_wait()


func _show_report() -> void:
	state = State.REPORT
	_bump()
	_desk_off()
	_base_hint = ""
	dialogue.clear()
	clinic.cam_prompt = false
	clinic.set_cam("")
	clinic.shutter_to(1.0, 0.6)
	var report: Dictionary = shift.report()
	screens.show_report(report)
	audio.play("jingle_good" if bool(report.get("rent_paid", false)) else "jingle_bad")
	_log("shift_end", {"correct": int(report.get("correct", 0)), "count": int(report.get("count", 0)),
		"total": int(report.get("total", 0)), "rent_paid": bool(report.get("rent_paid", false)),
		"injuries": int(report.get("injuries", 0)), "title": str(report.get("title", ""))})


func _on_impact(strength: float) -> void:
	_shake(3.0 * strength, 0.25)
	audio.play("bang", 1.25, -4.0)


# ================================================================ input

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_move((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			pointer_down(mb.position, mb.button_index)
		else:
			pointer_up(mb.position, mb.button_index)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed:
			key_up(key.keycode)
		elif key.keycode == SPEAK_KEY and (key.alt_pressed or key.ctrl_pressed or key.meta_pressed):
			pass      # ALT+TAB and the like belong to the desktop, not to the microphone
		elif not key.echo or (dialogue.input_open and EDIT_KEYS.has(key.keycode)):
			key_down(key.keycode, key.unicode)


func _notification(what: int) -> void:
	# the window lost the keyboard, so the key-up will never arrive: the microphone closes now
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) and _mic_state == "listening":
		act_speak_cancel()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close()


## The window was asked to close. Every sound stops now and the game leaves a moment later:
## a loop that is still playing when the engine shuts down is left behind and reported as
## leaked. Asking a second time does not wait.
func _close() -> void:
	if _closing or audio == null:
		get_tree().quit()
		return
	_closing = true
	if _mic_state == "listening":
		act_speak_cancel()
	audio.set_muted(true)      # nothing new starts while the game is on its way out
	audio.stop_all()
	get_tree().create_timer(CLOSE_HOLD, true, false, true).timeout.connect(get_tree().quit)


func pointer_move(pos: Vector2) -> void:
	_mouse = pos


func pointer_down(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_mouse = pos
	if button == MOUSE_BUTTON_RIGHT:
		act_cancel()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	match state:
		State.TITLE:
			act_start()
		State.REPORT:
			act_restart()
		State.SLIP:
			act_continue()
		State.WAIT:
			if clinic.cam_prompt and Gfx.MONITOR.grow(4.0).has_point(pos):
				act_call_next()
			else:
				_skip = true
		State.EXAM:
			_exam_click(pos)
		State.ATTACK:
			if desk.pad_at(pos) == "shutter":
				act_shutter()
		_:
			_skip = true


func pointer_up(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_mouse = pos
	if button == MOUSE_BUTTON_LEFT and _mic_from == "chip":
		act_speak_stop()
	if button == MOUSE_BUTTON_LEFT and clinic.scope.is_open():
		clinic.scope.button(false)


func key_up(keycode: int) -> void:
	if keycode == SPEAK_KEY and _mic_from == "key":
		act_speak_stop()


## unicode: the character the key types, when it types one (the typing line needs it).
func key_down(keycode: int, unicode: int = 0) -> void:
	if keycode == KEY_F11:
		var w := get_window()
		if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			w.mode = Window.MODE_WINDOWED
		else:
			w.mode = Window.MODE_FULLSCREEN
		return
	if keycode == SPEAK_KEY:
		act_speak_start("key")
		return
	if _mic_state != "":
		if keycode == KEY_ESCAPE:
			act_speak_cancel()
		return      # the microphone has the line: every other key waits for it
	if dialogue.input_open:
		_say_key(keycode, unicode)      # SPACE and M are letters while the doctor is typing
		return
	match keycode:
		KEY_SPACE:
			act_shutter()
		KEY_ESCAPE:
			act_cancel()
		KEY_T:
			if state == State.EXAM:
				act_say_open()
		KEY_ENTER, KEY_KP_ENTER:
			match state:
				State.TITLE:
					act_start()
				State.WAIT:
					if clinic.cam_prompt:
						act_call_next()
					else:
						_skip = true
				State.SLIP:
					act_continue()
				State.REPORT:
					act_restart()
				State.EXAM:
					# first hurry the line on screen; on a quiet strip ENTER starts a sentence
					if dialogue.typing or dialogue.waiting or not _can_act():
						_skip = true
					else:
						act_say_open()
				_:
					_skip = true
		KEY_M:
			audio.set_muted(not audio.muted)


## Right-click or ESC: put away whatever is in hand.
func act_cancel() -> void:
	if state != State.EXAM:
		return
	if _mic_state != "":
		act_speak_cancel()                     # the clip is thrown away; typed words stay
	elif dialogue.input_open:
		_close_say()                           # the sentence is taken back unsaid
		audio.play("tool_put", 1.3, -8.0)
	elif _call_armed > 0.0:
		audio.play("tool_put", 1.2, -4.0)      # hanging up
		_disarm()
	elif _armed > 0.0:
		_disarm()
	elif clinic.scope.is_open():
		_close_scope(true)
	elif dialogue.has_menu():
		dialogue.clear_menu()
		_base_hint = ""
	elif _held != "":
		_drop_stamp(true)


func _exam_click(pos: Vector2) -> void:
	# the open close-up owns the window
	if clinic.scope.is_open() and Gfx.HOLE.has_point(pos):
		clinic.scope.pointer(pos - Gfx.HOLE.position)
		clinic.scope.button(true)
		return
	var chip := dialogue.chip_at(pos)
	if chip != "":
		_click_chip(chip)
		return
	if dialogue.has_menu():
		var i := dialogue.menu_index_at(pos)
		if i >= 0:
			act_ask(dialogue.menu_id(i))
			return
	var pad := desk.pad_at(pos)
	if pad != "":
		if desk.is_enabled(pad):
			_click_pad(pad)
		return
	if _held != "":
		if clipboard.in_record(pos):
			act_stamp_record()
		return
	var mark := clipboard.mark_at(pos)
	if mark != "":
		act_mark(mark)
		return
	var zone := _zone_at(pos)
	if zone != "":
		act_look(zone)
		return
	if dialogue.has_menu():
		dialogue.clear_menu()
		_base_hint = ""
		return
	_skip = true


func _click_chip(chip: String) -> void:
	match chip:
		"type":
			act_say_open()
		"speak":
			act_speak_start("chip")      # held: pointer_up lets go of it


func _click_pad(pad: String) -> void:
	match pad:
		"penlight", "grip", "port":
			act_tool(pad)
		"ask":
			act_ask_menu()
		"calm":
			act_reassure()
		"press":
			act_press()
		"treat":
			act_pick_stamp(pad)
		"refer":
			act_call_team()
		"shutter":
			act_shutter()


# ================================================================ every frame

func _process(delta: float) -> void:
	_t += delta
	if rig != null:
		rig.talking = _patient_talking and dialogue.is_revealing()
	if _thinking:
		_think_t += delta
		if _think_quiet > 0.0 and not dialogue.typing:
			_think_quiet -= delta
		if _think_t > 0.5 and _think_quiet <= 0.0 and not dialogue.typing and not dialogue.thinking and visit != null:
			dialogue.speaker = _patient_name()
			dialogue.speaker_color = Gfx.WARM6
			dialogue.thinking = true
	if _armed > 0.0:
		_armed -= delta
		if _armed <= 0.0:
			_disarm()
	if _call_armed > 0.0:
		_call_armed -= delta
		if _call_armed <= 0.0:
			_disarm()
	if state == State.EXAM and _cam_in > 0.0:
		_cam_in -= delta
		if _cam_in <= 0.0:
			_show_upcoming()
	if state == State.SLIP:
		_slip_age += delta
	var in_exam := state == State.EXAM and visit != null and visit.in_exam()
	if _mic_state == "listening":
		if mic.opening:
			_mic_wait += delta
			dialogue.input_status = "opening"
		else:
			if dialogue.input_status == "opening":
				_log("voice", {"stage": "ready", "open_ms": int(_mic_wait * 1000.0)})
			dialogue.input_status = "listening"
			_mic_held += delta
		dialogue.input_level = mic.level
		dialogue.input_seconds = minf(_mic_held, mic.max_seconds)
		if _mic_held >= mic.max_seconds + 1.0:
			act_speak_stop()      # a microphone that delivers nothing never fills its clip
	if _mic_state != "" and not in_exam:
		_mic_drop("left_exam")
	var chips: Array = []
	if in_exam:
		chips = SPEAK_CHIPS if _mic_why_not() == "" else SAY_CHIPS
	dialogue.chips = chips
	dialogue.chips_dim = not _can_act()
	if use_model and agent != null:
		var label := "AI DIALOGUE"
		if str(agent.last.get("source", "")) == "fallback":
			label = "OFFLINE FALLBACK"
		elif bool(agent.last.get("meta", {}).get("mock", false)):
			label = "MOCK TRANSPORT"
		clinic.corner_text = "%s  %d/%d calls" % [label, agent.calls_this_visit, agent.max_calls]
	_update_hover()
	_update_hint()
	_update_fx(delta)
	_update_cursor()


func _update_hover() -> void:
	var pos := _mouse
	_cursor_kind = "point"
	_hover_hint = ""
	desk.hover = ""
	clinic.monitor_hot = false
	clinic.clear_zone()
	clipboard.hover_mark = ""
	clipboard.highlight_row = ""
	dialogue.menu_hover = -1
	dialogue.chip_hover = ""
	match state:
		State.WAIT:
			if clinic.cam_prompt and Gfx.MONITOR.grow(4.0).has_point(pos):
				clinic.monitor_hot = true
				_cursor_kind = "hand"
		State.EXAM:
			_hover_exam(pos)
		State.ATTACK:
			if desk.pad_at(pos) == "shutter":
				desk.hover = "shutter"
				_cursor_kind = "hand"


func _hover_exam(pos: Vector2) -> void:
	if visit == null:
		return
	if clinic.scope.is_open():
		clipboard.highlight_row = str(VisitState.TOOL_ROW.get(clinic.scope.tool, ""))
		if Gfx.HOLE.has_point(pos):
			clinic.scope.pointer(pos - Gfx.HOLE.position)
			_cursor_kind = "hand" if clinic.scope.tool == "grip" else "none"
			return
	if dialogue.input_open:
		clipboard.highlight_row = "speech"
	var chip := dialogue.chip_at(pos)
	if chip != "":
		dialogue.chip_hover = chip
		clipboard.highlight_row = "speech"
		if _can_act():
			_cursor_kind = "hand"
		_hover_hint = _chip_hint(chip)
		return
	if dialogue.has_menu():
		clipboard.highlight_row = "speech"
		var i := dialogue.menu_index_at(pos)
		if i >= 0:
			dialogue.menu_hover = i
			_cursor_kind = "hand"
			return
	var pad := desk.pad_at(pos)
	if pad != "":
		if desk.is_enabled(pad):
			desk.hover = pad
			_cursor_kind = "hand"
		_hover_hint = _pad_hint(pad)
		if PAD_ROW.has(pad):
			clipboard.highlight_row = str(PAD_ROW[pad])
		return
	if _held != "":
		_cursor_kind = "none"
		return
	var mark := clipboard.mark_at(pos)
	if mark != "":
		clipboard.hover_mark = mark
		clipboard.highlight_row = mark
		_cursor_kind = "hand"
		_hover_hint = "Your own tick or cross. A note for you: nothing scores it."
		return
	var row := clipboard.sheet_row_at(pos)
	if row == "":
		row = clipboard.record_row_at(pos)
	if row != "":
		clipboard.highlight_row = row
		return
	var zone := _zone_at(pos)
	if zone != "":
		clinic.set_zone(rig.zone_rect(zone), str(ZONE_LABEL[zone]))
		clipboard.highlight_row = zone
		_cursor_kind = "look"
		_hover_hint = "Click for a closer look. Looking is free."


func _chip_hint(chip: String) -> String:
	match chip:
		"type":
			if agent != null and agent.mode == "model":
				return "TYPE [T]: say anything in your own words. The patient answers for itself."
			return "TYPE [T]: say it in your own words. Offline, they know only their script."
		"speak":
			return "SPEAK [hold TAB]: say it aloud. You check the words before they are sent."
	return ""


## The one line under the dialogue box. An open call line outranks everything. After that the row
## belongs to what the player is in the middle of: always while the typing line or the microphone
## is open, and otherwise until the pointer moves on. The pointer is usually still resting on the
## pad that was just pressed, and that pad's own description would cover what to do next.
func _update_hint() -> void:
	if _base_hint != _hint_shown:
		_hint_shown = _base_hint
		_hint_at = _mouse
	var mid_action := dialogue.input_open or _mic_state != ""
	var news := _base_hint != "" and (mid_action or _mouse.distance_squared_to(_hint_at) < HINT_HOLD * HINT_HOLD)
	if _alert_hint != "":
		dialogue.set_hint(_alert_hint, Gfx.RED3 if fmod(_t, 0.4) < 0.28 else Gfx.RED2)
	elif _hover_hint != "" and not news:
		dialogue.set_hint(_hover_hint, Gfx.TEAL5)
	elif _base_hint == "" and _thinking and _think_t > 0.8 and state == State.EXAM:
		dialogue.set_hint(THINK_HINT, Gfx.TEAL4)
	else:
		dialogue.set_hint(_base_hint, Gfx.TEAL4)


func _update_fx(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		if _shake_t > 0.0:
			_world.position = Vector2(roundf(_fx_rng.randf_range(-_shake_amp, _shake_amp)),
				roundf(_fx_rng.randf_range(-_shake_amp, _shake_amp)))
		else:
			_world.position = Vector2.ZERO
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - _flash_fall * delta)
	_flash.color = Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_a)
	# the result slip feeds out of the printer slot in little steps, and drops away when torn off
	match _slip_mode:
		"print":
			_slip_y = minf(SLIP_REST, _slip_y + delta * 230.0)
			if _slip_y >= SLIP_REST:
				_slip_mode = "shown"
		"drop":
			_slip_y += delta * 900.0
			if _slip_y > SLIP_CLIP.size.y:
				_slip_mode = "hidden"
	_slip.visible = _slip_mode != "hidden"
	if _slip.visible:
		var y := _slip_y
		if _slip_mode == "print":
			y = floorf(y / 4.0) * 4.0
		_slip.position = Vector2(0, roundf(y))
		_slip.queue_redraw()


func _update_cursor() -> void:
	_held_sprite.visible = _held != "" and state == State.EXAM
	if _held_sprite.visible:
		_held_sprite.position = (_mouse - Vector2(18, 30)).round()
	var kind := _cursor_kind
	_cursor.visible = kind != "none"
	if _cursor.visible:
		_cursor.texture = Gfx.tex("ui/cursor_%s.png" % kind)
		var spot: Vector2 = HOTSPOT.get(kind, Vector2.ZERO)
		_cursor.position = (_mouse - spot).round()


# ================================================================ the result slip

func _fit(ci: CanvasItem, x: float, y: float, s: String, width: float, color: Color) -> void:
	Gfx.text(ci, Vector2(x, y), s, color, Gfx.text_w(s, true) <= width)


func _draw_slip() -> void:
	var tex := Gfx.tex("ui/slip.png")
	if tex != null:
		_slip.draw_texture(tex, Vector2.ZERO)
	var s := _slip_data
	if s.is_empty():
		return
	var x0 := 11.0
	var x1 := 191.0
	var w := x1 - x0
	var mid := 101.0
	var ok := bool(s.get("correct", false))
	var outcome := str(s.get("outcome", ""))
	Gfx.text(_slip, Vector2(x0, 17), "INTAKE SLIP %d/%d" % [_slip_index, shift.count() if shift != null else 0], Gfx.PRINT)
	Gfx.text_right(_slip, x1, 17, str(s.get("name", "")), Gfx.PRINT)
	var title := str(s.get("title", ""))
	if Gfx.big_w(title) <= w:
		Gfx.big_center(_slip, mid, 27, title, Gfx.INKT)
	else:
		Gfx.text_center(_slip, mid, 33, title, Gfx.INKT, true)
	Gfx.paragraph(_slip, Vector2(x0, 50), str(s.get("text", "")), w, Gfx.INKT, false, 6)
	_slip.draw_rect(Rect2(x0, 112, w, 1), Gfx.PAPER1)
	var steady := str(s.get("truth", "")) == "stable"
	_fit(_slip, x0, 115, "%s was %s." % [str(s.get("name", "")), "STEADY" if steady else "DRIFTING"], w, Gfx.INKT)
	var call := "RIGHT CALL" if ok else "WRONG CALL"
	if outcome == "walkout" or (outcome == "hit" and not ok):
		call = "NO CALL"
	elif outcome == "hit" and ok:
		call = "RIGHT CALL, HURT"      # the crew was the right answer; the shutter came too late
	var credits := int(s.get("credits", 0))
	var paid := "%s credits" % Gfx.money(credits)
	# the call and the money share one line: the call gives way before it touches the figure
	_fit(_slip, x0, 126, call, w - Gfx.text_w(paid, true) - SLIP_GAP, Gfx.GRN2 if ok else Gfx.RED1)
	Gfx.text_right(_slip, x1, 126, paid, Gfx.INKT if credits >= 0 else Gfx.RED1, true)
	if state == State.SLIP and _slip_age > 0.5 and fmod(_t, 1.0) < 0.65:
		Gfx.text_center(_slip, mid, 138, "click to continue", Gfx.PRINT)
