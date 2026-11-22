extends Control
## The director: owns the shift, the patient at the counter and every input, and tells the
## drawing nodes what to show. All rules live in scripts/core; nothing in this file decides
## what is true about a patient.
##
## Input arrives through pointer_move / pointer_down / pointer_up / key_down / key_up, and every
## player action is a public act_* method, so a test can play the game the way a person does.
##
## Right and wrong are told at closing (rules version 8). During the night the player learns the
## truth only from what a patient does in the room (an attack, a walkout). The slip prints what
## happened at the counter and the fee; the meter's lamps show the player's own calls; the crew
## takes everybody the same way, and a shutter dropped before any attack is the same quiet beat
## for everybody; the card keeps only the player's notes. At closing the report turns a page for
## each visit, then shows the night's totals. A patient who gets through the window ends the
## night: there is no slip, and the report comes up out of the dark.
##
## Launch options (after "--" on the command line), all optional:
##   --seed=123                          fixed shift seed (the same seed draws the same night)
##   --test-night=B                      play that test night of data/nights.json every shift, instead of drawing one
##   --authored-order                    test night A every shift: the night as written (tests, captures)
##   --agent-url=http://127.0.0.1:8787   patient-agent proxy (or environment BTC_AGENT_URL)
##   --model / --script-patient          select the patient for this run without saving the choice
##   --mute                              start with sound off
##   --less-blood                        the attack scenes without the blood
##   --no-intro                          skip the opening cards, the first-night training and the first showing of the counter guide
##   --no-training                       no training box on the first night (the guide opens by itself instead)
##   --no-surprises                      no patient snaps or flares mid-exam (tests, captures)

const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Settings = preload("res://scripts/core/settings.gd")
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
const Intro = preload("res://scripts/ui/intro.gd")
const Guide = preload("res://scripts/ui/guide.gd")
const Coach = preload("res://scripts/ui/coach.gd")

enum State { TITLE, WAIT, ENTER, EXAM, ATTACK, RESOLVE, SLIP, REPORT, INTRO }

const SLIP_CLIP := Rect2(217, 148, 202, 152)   # over the counter: the slip feeds up out of the printer in the desk
const SLIP_REST := 4.0                          # its last few pixels stay in the printer
const SLIP_GAP := 8.0                           # least space between AT THE COUNTER and the money beside it
const SLIP_LINES := 5                           # lines of counter text above the rule (measure_text.py SLIP_LINES)
const SLIP_COUNTER := "AT THE COUNTER"          # under the rule, beside what the counter took in: what the till moves by
const SLIP_LATER := "Right or wrong: at closing."   # the slip never says; the report does
const SLIP_FEE := "FEE +%d"                     # under the counter line, when the figure is more than the fee: the fee,
const SLIP_DROP := "DROP +%d"                   # what a courier's package put in the till,
const SLIP_CALM := "CALM -%d"                   # and what the calm-patches cost
# the lines under the slip's rule, from the slip's top: the counter line, what it is made of,
# the word on right and wrong, and the prompt. Ten rows apart, and clear of the slip's lower
# edge (SLIP_CLIP's height less SLIP_REST): a Chinese line is two rows taller than an English one.
const SLIP_COUNTER_Y := 105.0
const SLIP_PARTS_Y := 115.0
const SLIP_LATER_Y := 125.0
const SLIP_PROMPT_Y := 136.0
const REPORT_TURN := 0.25                       # seconds a report page stays before a click turns it
const CARD_LINGER := 1.3                        # seconds a card that was just stamped stays out by itself
const ARM_TIME := 2.2
const CALL_ARM_TIME := 3.5                      # how long the Trauma Team line waits for the second press
const LEAVE_BEAT := 0.7                         # quiet seconds after the last patience lamp goes out, before the ultimatum
const THINK_POSE_AFTER := 0.25                  # seconds an answer has to be on its way before the patient is seen thinking
## Every sound of an attack plays this much under its own level. Measured on November 15 from a
## silent recording of the master bus (nobody listened): untrimmed, the loudest second of an
## attack sat about 24 dB over the room and a landed attack held the limiter in 59% of its
## 50 ms windows. At -9 dB: 19 dB (caught) and 22 dB (landed) over the room, limiter 0% and 8%.
## One number to change after a listening test.
const ATTACK_TRIM_DB := -9.0
const DENT_SPOTS := [Vector2(156, 84), Vector2(64, 58), Vector2(126, 44)]       # caught: where the shutter bulges
const FACE_CLEAR := Rect2(175, 50, 290, 256)      # the first blood on the view keeps off the attacker's face
# what a hit leaves on the booth walls either side of the window: picture, centre on the screen.
# The clinic view cuts each one off at the window's edge; the papers and keys hang in front of them.
const WALL_MARKS := [
	["splat_m2", Vector2(92, 136)], ["splat_s1", Vector2(95, 58)], ["splat_m1", Vector2(86, 226)],
	["splat_s2", Vector2(94, 286)], ["splat_s0", Vector2(50, 106)], ["splat_s1", Vector2(97, 172)],
	["splat_s0", Vector2(543, 60)], ["splat_s0", Vector2(541, 150)], ["splat_m0", Vector2(590, 115)],
	["splat_a0", Vector2(560, 236)], ["splat_m1", Vector2(632, 60)], ["splat_s2", Vector2(632, 298)],
]
# and on the desk: small, between the buttons
const DESK_MARKS := [
	["splat_s0", Vector2(300, 302)], ["splat_s1", Vector2(121, 332)], ["splat_s2", Vector2(40, 341)],
	["splat_s1", Vector2(519, 318)], ["splat_s0", Vector2(600, 342)],
]
const CUT_AT := {      # where the weapon comes through it
	"saw": Vector2(34, 96), "torch": Vector2(92, 58), "picks": Vector2(58, 84),
	"laser": Vector2(28, 74), "arc": Vector2(100, 96), "chop": Vector2(36, 100), "spike": Vector2(70, 92),
}
## How each kind of weapon sounds and what it leaves. A patient's style is in patients/meta.json
## ("attack" > "style"); one missing here plays as the saw. Its pictures are drawn by tools/art.
##   loop   - the sound it makes while it is out ("": none)
##   bite   - the sound of it landing
##   knock  - each blow on the closed shutter
##   pitch  - the scream sample's pitch: down is a roar, up a scream
##   hot    - the sparks it throws
##   glow   - the light it carries from the moment they turn (alpha 0: none)
##   mark   - what it leaves on the pane (fx/<mark>.png; a weapon that burns also has
##            fx/<mark>_hot.png, the same mark still glowing)
##   cut    - what comes through the closed shutter ("": nothing does, only the dents)
##   deep   - its dents go deep enough to see from the hall
##   strike - what lands on the player's eyes when it gets through: slash, burn, claw or smash
const ATTACK_STYLES := {
	"saw": {"loop": "saw_loop", "bite": "saw_grind", "knock": "bang", "pitch": 0.6, "hot": Color("fbe9b5"),
		"glow": Color(0, 0, 0, 0), "mark": "gouge_0", "cut": "saw", "deep": false, "strike": "slash"},
	"torch": {"loop": "torch_loop", "bite": "torch_burst", "knock": "bang", "pitch": 1.12, "hot": Color("c8fff6"),
		"glow": Color("5ee6e0"), "mark": "scorch", "cut": "torch", "deep": false, "strike": "burn"},
	"lock": {"loop": "", "bite": "clang", "knock": "clang", "pitch": 1.28, "hot": Color("e8f0ff"),
		"glow": Color(0, 0, 0, 0), "mark": "smash_0", "cut": "", "deep": false, "strike": "smash"},
	"fist": {"loop": "servo_loop", "bite": "punch", "knock": "punch", "pitch": 0.76, "hot": Color("ffd89a"),
		"glow": Color(0, 0, 0, 0), "mark": "smash_1", "cut": "", "deep": true, "strike": "smash"},
	"picks": {"loop": "hum_loop", "bite": "scrape", "knock": "bang", "pitch": 1.24, "hot": Color("c8f4ff"),
		"glow": Color(0, 0, 0, 0), "mark": "slit_0", "cut": "picks", "deep": false, "strike": "claw"},
	# Priya's LANCET fingers, run up to a cutting beam
	"laser": {"loop": "laser_loop", "bite": "laser_burst", "knock": "bang", "pitch": 1.16, "hot": Color("ffd0c8"),
		"glow": Color("ff4a4a"), "mark": "scorch_laser", "cut": "laser", "deep": false, "strike": "burn"},
	# Ozzie's CHOP hand: the cleaver folded into it
	"cleaver": {"loop": "", "bite": "chop", "knock": "chop", "pitch": 0.68, "hot": Color("fbe9b5"),
		"glow": Color(0, 0, 0, 0), "mark": "chop_0", "cut": "chop", "deep": false, "strike": "slash"},
	# Lux's deck cable, torn out of her temple and still live
	"arc": {"loop": "arc_loop", "bite": "zap", "knock": "bang", "pitch": 1.34, "hot": Color("d8d0ff"),
		"glow": Color("8a7cff"), "mark": "scorch_arc", "cut": "arc", "deep": false, "strike": "burn"},
	# Dana's stun baton, out of her sleeve
	"baton": {"loop": "stun_loop", "bite": "baton_hit", "knock": "baton_hit", "pitch": 1.0, "hot": Color("dce8ff"),
		"glow": Color(0, 0, 0, 0), "mark": "zap_0", "cut": "", "deep": false, "strike": "smash"},
	# Bo's PISTON fist, a steel spike out between the knuckles
	"spike": {"loop": "piston_loop", "bite": "spike", "knock": "punch", "pitch": 0.72, "hot": Color("ffd89a"),
		"glow": Color(0, 0, 0, 0), "mark": "pierce_0", "cut": "spike", "deep": true, "strike": "smash"},
}
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
	"Here, a calm-patch. On the wrist. Take your time, nobody is in trouble.",
	"Another patch. Breathe. You're doing fine, we are nearly done.",
]
const FIRST_HINT := "Ask what hurts, then test that part. You can make the call at any time."
# a patient with no patience left gives one last wait and then leaves by themselves
const SHORT_HINT := "No lamps left. Talk, BREAK, or make the call."
const LEAVING_HINT := "They are leaving. Talk to them or make the call."
const LEAVING_FREE_HINT := "They are leaving. Decide now, or press CALM to hold them."
const LEAVING_LAST_HINT := "They are leaving. Decide now, or let them go."
# coaching: each of these is offered once in a session, when the thing it explains first happens
const NOTE_COACH_HINT := "Noted on your intake card. It hangs on the right wall: click it, or press N."
const NOTE_OPEN_COACH_HINT := "Noted for you. Click the box beside a row to tick or cross it yourself."
const LAMP_COACH_HINT := "One lamp left. After your last test, you still have time to talk and decide."
const GLASS_COACH_HINT := "Each blow before the shutter costs the glass. Less glass, less time."
const DROP_COACH_HINT := "The drop changes nothing about the exam. Steady or drifting, the call is still yours."
const FLARE_COACH_HINT := "Only temper: no red bar, nothing to stop. The SHUTTER is for the red bar."
const CALM_HINT := "CALM: a calm-patch, %d credits. +%d patience, and a refusal softens. %d left."
const CALM_HOLD_HINT := "CALM: a calm-patch, %d credits. +%d patience, and it keeps them here. %d left."
const CALM_GONE_HINT := "CALM: no calm-patches left for this visit."
const CALM_FREE_HINT := "CALM: +%d patience, and a refusal softens. %d left."
const CALM_FREE_HOLD_HINT := "CALM: +%d patience. It keeps them at the counter. %d left."
const SAY_CODE_HINT := "SAY the code. The right contact hands over a package. Anyone else: -%d patience."
const CODE_BLANK_HINT := "Wrong code: a blank look, -%d patience. It says nothing about the patient."
# the second PRESS breaks every patient and takes every lamp left (rules version 10)
const PRESS_HINT := "PRESS: say something that stings. Costs %d patience. Twice, and they break."
const PRESS_LAST_HINT := "All lamps. Steady: walks, no fee. Drift: lunges. SPACE to stop it (+%d at closing)."
const TRAINING_SKIP_HINT := "SKIP ALL [K]: end the training. H opens the counter guide any time."
const TRAINING_NEXT_HINT := "NEXT: on to the next tip."
const SWAP_LIST_HINT := "Swap for tonight's contact list. [L]"
const SWAP_SHEET_HINT := "Swap for the reference sheet. [R]"
# the player's own crosses against the house rule on the reference sheet: advice, never a score
const CROSS_SOME_HINT := "%d of %d broken lines by your marks. One alone can be ordinary."
const CROSS_RULE_HINT := "%d broken lines by your own marks. The house rule says TRAUMA TEAM."
# the lender's meter reads the till after every patient (one patient is one hour)
const METER_OVER_LINE := "Hour %d of %d. Till %d, line %d. Over the line."
const METER_UNDER_LINE := "Hour %d of %d. Till %d, line %d. UNDER THE LINE by %d."
const SHIFT_LINE := "Night shift: %d visitors, one an hour. The meter wants %d more every hour."
const SHIFT_LIST_LINE := "Night shift: %d visitors, one an hour, %d of them on the contact list. The meter wants %d more every hour."
const DROP_LINE := "%s +%d credits, whatever you decide."
# how the shutter was timed against a patient who turned (VisitState.shutter_grade)
const STOP_CLEAN_LINE := "STOPPED CLEAN: THE GLASS HOLDS"
const STOP_BARE_LINE := "STOPPED IN TIME: NO GLASS LEFT"
const STOP_BLOW_LINE := "STOPPED AFTER %d BLOW"
const STOP_BLOWS_LINE := "STOPPED AFTER %d BLOWS"
const STOP_LAST_LINE := "STOPPED, BUT THE GLASS IS GONE"
# the title card says whether the patient can be spoken to, and how
const STATUS_AI_VOICE := "AI connected. ASK uses case answers. Hold TAB to speak or press T to type."
const STATUS_AI_TYPE := "AI connected. ASK uses case answers. Press T to type."
const STATUS_AI_NO_MIC := "AI connected. ASK uses case answers. No microphone. Press T to type."
const STATUS_MODEL_VOICE := "AI writes ASK replies. Hold TAB to speak or press T to type."
const STATUS_MODEL_TYPE := "AI writes ASK replies. Press T to type."
const STATUS_MODEL_NO_MIC := "AI writes ASK replies. No microphone found. Press T to type."
const WINDOW_TITLE := "Before the Cut"      # the window's title bar, in the player's language
const STATUS_CHECKING := "Connecting to the patient service..."
const STATUS_OFFLINE := "Scripted patient. Choose PATIENT AI in SETTINGS to connect a service."
# the crew is an authored outcome: these lines are fixed, they never come from the patient model
const DISPATCH_LINE := "Trauma Team dispatch. A unit is rolling to your counter. Keep them there."
const CREW_LINE := "Trauma Team. Step back from the glass. You are coming with us."
const CREW_AFTER_LINE := "A siren outside. Boots in the hall. It does not take them long."
const WAIT_HINT := "Click the hall camera, or press ENTER to buzz them in."
const CAM_HINT := "Click the screen, or press ENTER, to buzz them in."
# the things on the booth walls, and the papers once they are down
const OBJECT_HINT := {
	"sheet": "REFERENCE SHEET [R]: what is steady for this patient's models. Click to take it down.",
	"list": "CONTACT LIST [L]: tonight's contacts, two clues and a code each. Click to take it down.",
	"card": "INTAKE CARD [N]: your notes on this patient. Click to take it down.",
	"guide": "COUNTER GUIDE [H]: how this counter works.",
}
const TAB_HINT := {
	"sheet": "Hang the sheet back on the wall. [R]",
	"list": "Hang the list back on the wall. [L]",
	"card": "Hang the card back on the wall. [N]",
}
# where the first-night training points (screen space): the parts of the booth its tips are about
const COACH_SAY := Rect2(184, 21, 34, 65)          # the SAY buttons of the contact list
const COACH_MARKS := Rect2(410, 45, 40, 140)       # the tick boxes of the intake card
const COACH_TOOLS := Rect2(0, 301, 120, 58)        # the three tools on the desk
const COACH_TALK := Rect2(520, 301, 120, 58)       # ASK, CALM, PRESS and the words of your own
const COACH_DECIDE := Rect2(546, 190, 88, 54)      # the stamp and the call box
const COACH_PATIENCE := Rect2(261, 0, 118, 14)     # the patience lamps over the window
const COACH_LEFT_PAPER := Rect2(0, 2, 246, 164)    # the sheet or the list, down from the wall, with its tabs
const COACH_RIGHT_PAPER := Rect2(394, 2, 246, 186) # the card, down from the wall, with its tab
const CAM_PEEK_HINT := "HALL CAMERA [C]: who is waiting in the hall."
const CAM_OFF_HINT := "HALL CAMERA [C]: click to switch the big screen off."
# the counter glass can be mended between patients (rules.json attack.repair_cost)
const GLASS_HINT := "GLASS [G]: one new layer for %d credits. It takes one more blow."
const GLASS_BUSY_HINT := "GLASS: the fitter only comes between patients."
const GLASS_WHOLE_HINT := "GLASS: every layer is whole. Nothing to mend."
const GLASS_OFF_HINT := "GLASS: nobody mends glass at this hour."
const GLASS_LINE := "The fitter's arm bonds a fresh layer over the frame. %d credits off the till. Glass %d of %d."
const THINK_HINT := "Still answering. You can look meanwhile, or decide now."
const THINK_QUIET := 1.6          # how long a look made while the patient is answering stays readable
const SAY_HINT := "ENTER sends. Talking is free."
const SAY_FULL_HINT := "That is all you can say in one go. ENTER says it."
const SAY_SMALL_HINT := "Small talk. Use ASK to choose a question for the card."
const SAY_CHIPS := [{"id": "type", "key": "T", "label": "TYPE"}]
# push-to-talk: the microphone is open only while this key (or the SPEAK button) is held
const SPEAK_KEY := KEY_TAB
const SPEAK_CHIPS := [{"id": "speak", "key": "TAB", "label": "SPEAK"}, {"id": "type", "key": "T", "label": "TYPE"}]
const SAY_VOICE_HINT := "ENTER sends for free. Hold TAB to speak."
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
var sheet: Dictionary = {}        # sheet.json: what no model changes
var parts: Dictionary = {}        # parts.json: the spec binder
var visit_sheet: Dictionary = {}  # the sheet on the wall now: for the patient at the counter (case_db sheet_for)
var cases: Dictionary = {}        # tonight's visitors composed (case_db compose_night); night A until a shift starts
var templates: Dictionary = {}    # cases/<id>.json: the characters of the roster as written
var people: Dictionary = {}       # each of them steady with every part normal: what no night changes (contact clues)
var nights: Dictionary = {}       # data/nights.json: the test nights
var night: Dictionary = {}        # tonight: {"visitors": [{"id", "truth", "signs"}]}, drawn or a test night
var night_name: String = ""       # the test night being played, or "" for a drawn one
var meta: Dictionary = {}
var data_errors: Array = []
var shift: ShiftState = null
var visit: VisitState = null
var agent: PatientAgent = null
var model_client: ModelClient = null
var event_log: EventLog = null
var run_id: String = ""
var shift_seed: int = 0
var shift_number: int = 0
var fixed_seed: int = 0
var has_fixed_seed: bool = false
var authored_order: bool = false     # true (--authored-order): test night A every shift, never drawn
var test_night: String = ""          # --test-night=<name>: that night of data/nights.json every shift
var agent_url: String = ""
signal night_frame
signal night_resumed
signal patient_check_finished

var use_model: bool = false
var _patient_override: String = ""
var _patient_status: String = "off"
var _patient_check_id: int = 0
var beats_enabled := true
var _service_has_beats := false
var _beat_clock := 0.0
var _beat_pending := false
var _beat_opening_done := false
var _beat_revision := 0
var _break_confirmation := false
var _service_has_voice: bool = true
var _service_is_mock: bool = false
var start_muted: bool = false
var less_blood: bool = false      # launch option --less-blood, or BLOOD: LESS in SETTINGS: the same scene without the blood
var fullscreen: bool = false      # SCREEN in SETTINGS, or F11
var saved_settings: Dictionary = {}   # what the player chose last time (settings.gd); the defaults on a test run
var intro_enabled: bool = true    # false (--no-intro): no opening cards, and the guide waits to be asked for
var intro_data: Dictionary = {}   # data/intro.json: the opening cards and the pages of the counter guide
var training_enabled: bool = true # false (--no-training): the first night has no training box
var surprises_enabled: bool = true    # false (--no-surprises): nobody snaps or flares mid-exam
var contact_data: Dictionary = {} # data/contacts.json: the couriers' pool and the clue words

var clinic: ClinicView = null
var dialogue: DialogueBox = null
var desk: Desk = null
var clipboard: Clipboard = null
var screens: Screens = null
var audio: AudioBank = null
var mic: VoiceInput = null        # push-to-talk: a microphone that is open only while the key is held
var gore: GoreLayer = null
var intro: Intro = null           # the opening cards, once a session
var guide: Guide = null           # the counter guide: H or F1
var coach: Coach = null           # the first-night training: one tip at a time, pointing at the booth
var rig: PatientRig = null

var _quit_night := preload("res://scripts/ui/quit_night_dialog.gd").new()
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
var _blows: int = 0               # how many blows of this attack have landed on the glass
var _leave_t: float = -1.0        # seconds a patient with no patience left still waits; < 0: nobody is leaving
var _leave_said: bool = false     # they have said so
var _leave_idle: float = 0.0      # quiet seconds since the last lamp went out
var _intro_seen: bool = false     # the opening plays once a session
var _guide_seen: bool = false     # and the guide opens by itself once
var _training_night := -1
var _trained: bool = false        # the training has run this session (once, on the first night)
var _training_visit: bool = false # this visit began while the training was running: no surprises
var _coached: Dictionary = {}     # coaching hints already shown this session
var _coach_next: String = ""      # one that is waiting for the hint row to be free
var _coach_id: String = ""        # which one that is
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
var _ime_on: bool = false         # the window's input method is switched on (the typing line, in Chinese)
var _ime_at := Vector2i(-1, -1)   # where its list of candidates was last told to open, in window pixels
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
var _slip_y: float = SLIP_CLIP.size.y   # from the top of its clip: this far down it is still inside the printer
var _slip_age: float = 0.0
var _slip_index: int = 0
var _report_jingled: bool = false   # the totals page of the report has had its jingle
# what the doctor has taken down from the booth walls. The papers and the big camera screen
# are out of sight until they are asked for: the window is the screen.
var _sheet_wanted: bool = false   # the reference sheet is down from the wall
var _card_wanted: bool = false    # and the intake card
var _cam_wanted: bool = false     # the big hall-camera screen is on
var _sheet_back: bool = false     # papers a close-up pushed aside, to bring back when it closes
var _card_back: bool = false
var _card_linger: float = 0.0     # seconds a card that was just stamped stays out by itself
var _card_unseen: int = 0         # notes written on the card while it hung on the wall
var _sheet_seen: bool = false     # the wall sheet stops asking to be looked at once it has been down
var _list_wanted: bool = false    # tonight's contact list is down (it hangs on the sheet's hook)
var _list_back: bool = false      # and a close-up pushed it aside
var _list_seen: bool = false      # it stops asking to be looked at once it has been down
var _panels_hold: bool = false    # a patient has turned: nothing hangs in front of the window
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _flash_a: float = 0.0
var _flash_fall: float = 1.0
var _flash_color := Color.WHITE
var _rng := RandomNumberGenerator.new()      # shift-seeded: beats (the night has a generator of its own)
var _snap_rng := RandomNumberGenerator.new()   # visit-seeded: snaps and flares
var _surprise: String = ""        # "snap" or "flare": rolled, and due once _surprise_t has run out
var _surprise_t: float = 0.0
var _fx_rng := RandomNumberGenerator.new()   # cosmetic only
var _boot_rng := RandomNumberGenerator.new()
var _db: Dictionary = {}          # CaseDB.load_all(): what the night draw reads


# ================================================================ setup

func _ready() -> void:
	get_tree().process_frame.connect(_forward_night_frame)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Lang.load_saved()      # before anything puts words together: the sheet is filled as it is hung
	var db: Dictionary = CaseDB.load_all()
	_db = db
	rules = db["rules"]
	sheet = db["sheet"]
	parts = db.get("parts", {})
	cases = db["cases"]
	templates = db.get("templates", {})
	people = db.get("people", {})
	nights = db.get("nights", {})
	data_errors = db["errors"]
	contact_data = db.get("contacts", {})
	var m: Variant = CaseDB.load_json("res://assets/patients/meta.json")
	if typeof(m) == TYPE_DICTIONARY:
		meta = m
	else:
		data_errors.append("assets/patients/meta.json is missing or is not valid JSON.")
	var opening: Variant = CaseDB.load_json("res://data/intro.json")
	if typeof(opening) == TYPE_DICTIONARY:
		intro_data = opening
	else:
		data_errors.append("data/intro.json is missing or is not valid JSON.")
	_read_launch_options()
	saved_settings = Settings.load_all()
	if str(saved_settings.get("blood", "full")) == "less":
		less_blood = true      # --less-blood forces it for the run; the saved choice can only add it
	if test_night != "" and not nights.has(test_night):
		data_errors.append("--test-night=%s: data/nights.json has no night '%s'." % [test_night, test_night])
		cases = {}      # nothing to play: the title card shows the problem and does not start
	_build()
	audio.set_volume_step(int(saved_settings.get("volume", AudioBank.VOLUME_STEPS.size() - 1)))
	_start_session()
	_apply_language()
	_show_title()
	var choice := str(saved_settings.patient_ai) if _patient_override == "" else _patient_override
	_set_patient_ai(choice == "on", false)
	if str(saved_settings.get("screen", "window")) == "fullscreen":
		_apply_fullscreen(true)
	get_tree().auto_accept_quit = false      # a close request goes through _close()


func _read_launch_options() -> void:
	agent_url = OS.get_environment("BTC_AGENT_URL").strip_edges()
	if agent_url == "":
		agent_url = str(rules.agent.get("default_url", "")).strip_edges()
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--seed="):
			fixed_seed = int(a.substr(7))
			has_fixed_seed = true
		elif a.begins_with("--agent-url="):
			agent_url = a.substr(12).strip_edges()
		elif a == "--model":
			_patient_override = "on"
		elif a == "--script-patient":
			_patient_override = "off"
		elif a == "--mute":
			start_muted = true
		elif a == "--less-blood":
			less_blood = true
		elif a == "--authored-order":
			authored_order = true
		elif a.begins_with("--test-night="):
			test_night = a.substr(13).strip_edges()
		elif a == "--no-intro":
			intro_enabled = false
		elif a == "--no-training":
			training_enabled = false
		elif a == "--no-surprises":
			surprises_enabled = false


func _build() -> void:
	add_child(_quit_night)
	_quit_night.choice.connect(_answer_quit_night)
	add_child(_world)
	clinic = ClinicView.new()
	_world.add_child(clinic)
	# the result slip feeds up from behind the transcript unit, so it is built before it
	_slip_clip.position = SLIP_CLIP.position
	_slip_clip.size = SLIP_CLIP.size
	_slip_clip.clip_contents = true
	_slip_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_slip_clip)
	_slip.visible = false
	_slip_clip.add_child(_slip)
	_slip.draw.connect(_draw_slip)
	dialogue = DialogueBox.new()
	_world.add_child(dialogue.back)
	_world.add_child(clinic.over_desk)      # what runs down from the sill runs over the desk,
	_world.add_child(dialogue)              # under the words of the transcript
	desk = Desk.new()
	_world.add_child(desk)
	_world.add_child(_mess)
	# the papers come down in front of everything else in the booth
	clipboard = Clipboard.new()
	_world.add_child(clipboard)
	_hang_sheet()
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
	var line_rules: Dictionary = rules.get("line", {})
	var per_hour := int(line_rules.get("per_hour", 0))
	var night_rules: Dictionary = rules.get("night", {}) if typeof(rules.get("night")) == TYPE_DICTIONARY else {}
	var hours := int(night_rules.get("visitors", (rules.get("shift_order", []) as Array).size()))
	var repair_cost := int((rules.get("attack", {}) as Dictionary).get("repair_cost", 0))
	var contact_rules: Dictionary = rules.get("contacts", {})
	var calm_rules: Dictionary = rules.get("reassure", {})
	var costs: Dictionary = rules.get("costs", {})
	var numbers := {"lamps":int(rules.visit.lamps), "idle":int(rules.patience.leave_ms / 1000.0), "per_hour": per_hour, "hours": hours, "total": per_hour * hours, "threshold": int(rules.visit.threshold),
		"repair_cost": repair_cost, "pay": int(contact_rules.get("pay", 0)), "code_cost": int(contact_rules.get("wrong_cost", 1)),
		"per_night": int(contact_rules.get("per_night", 0)), "calm_cost": int(calm_rules.get("cost", 0)),
		"catch_bonus": int(rules.scoring.press_catch_bonus), "calm_gain": int(calm_rules.get("gain", 1)), "ask_cost": int(costs.get("ask", 1)), "press_cost": int(costs.get("press", 2)),
		"check_cost": int(costs.get("check", 1)), "glass": int((rules.get("attack", {}) as Dictionary).get("glass", 3)),
		"false_alarm": absi(int((rules.get("scoring", {}) as Dictionary).get("false_alarm", 0)))}
	intro = Intro.new()
	intro.setup(intro_data.get("cards", []), numbers)
	add_child(intro)
	intro.blip.connect(_on_intro_blip)
	intro.turned.connect(_on_intro_turned)
	intro.cue.connect(_on_intro_cue)
	coach = Coach.new()
	coach.setup(intro_data.get("training", []), numbers)
	add_child(coach)
	coach.finished.connect(_on_training_finished)
	guide = Guide.new()
	# a rule set with no price for glass has no fitter for the guide to explain
	guide.setup(intro_data.get("guide", []), numbers, [] if repair_cost > 0 else ["mend"])
	add_child(guide)
	screens.howto = intro_data.get("howto", [])
	screens.howto_numbers = numbers
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
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_fx_rng.randomize()


func _start_session() -> void:
	_boot_rng.randomize()
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	event_log = EventLog.new()
	event_log.open(run_id)
	var agent_rules: Dictionary = rules.get("agent", {})
	model_client = ModelClient.new()
	model_client.base_url = agent_url
	model_client.timeout_ms = int(agent_rules.get("timeout_ms", 4000))
	model_client.intent_timeout_ms = int(agent_rules.get("intent", {}).get("timeout_ms", 2500))
	_mic_rules = agent_rules.get("voice", {})
	model_client.voice_timeout_ms = int(_mic_rules.get("timeout_ms", 7000))
	mic.max_seconds = float(_mic_rules.get("max_seconds", 10.0))
	add_child(model_client)
	screens.voice = _mic_why_not() == ""
	screens.status_line = _status_line()
	_log("session_start", {
		"game_version": PatientAgent.GAME_VERSION,
		"rules_version": str(rules.get("version", "")),
		"model_endpoint_set": agent_url != "",
		"model_requested": _patient_override == "on" or (_patient_override == "" and saved_settings.patient_ai == "on"),
		"voice_offered": screens.voice,
		"language": Lang.code,
		"engine": str(Engine.get_version_info().get("string", "")),
	})


func _log(event_type: String, data: Dictionary = {}) -> void:
	if event_log == null:
		return
	var record := data.duplicate()
	if visit != null and not record.has("case"):
		record["case"] = str(visit.case_data.get("id", ""))
	if agent != null and agent.visit_id != "":
		record["visit_id"] = agent.visit_id
	event_log.write(event_type, record)


## Switches the language. Only on the title card: nothing is half-said there, so nothing has to
## be put into the other language halfway. The choice is kept for the next time the game starts.
func act_language(p_code: String) -> void:
	if state != State.TITLE or p_code == Lang.code or not Lang.CODES.has(p_code):
		return
	Lang.use(p_code)
	Lang.save()
	audio.play("click")
	_apply_language()
	_sync_settings()
	_log("language", {"language": Lang.code})


## What holds words already put into the player's language: the sheet on the wall (filled when
## it is hung), the window's title, the catalog's own problems and the clinic's pictures with
## words painted in them. Everything else is translated as it is drawn.
func _apply_language() -> void:
	get_window().title = Lang.t(WINDOW_TITLE)
	var problems: Array = data_errors.duplicate()
	problems.append_array(Array(Lang.errors))
	screens.errors = problems
	clinic.apply_language()
	_hang_sheet()


# ================================================================ the title card's menu

## START, HOW TO PLAY, SETTINGS or QUIT (student, November 20: settings, start and a guide on
## the first screen). Only on the title card's menu.
func act_menu(item: String) -> void:
	if state != State.TITLE or screens.mode != "title":
		return
	match item:
		"start":
			act_start()
		"howto":
			if screens.howto_count() == 0:
				return
			screens.show_howto()
			audio.play("paper")
			_log("howto", {"pages": screens.howto_count()})
		"settings":
			_sync_settings()
			screens.show_settings()
			audio.play("click")
		"quit":
			audio.play("click")
			_close()


## UP or DOWN: the menu's next item, or the SETTINGS page's next row. Round at the ends.
func act_menu_move(step: int) -> void:
	if state != State.TITLE:
		return
	if screens.mode == "title":
		screens.menu_index = posmod(screens.menu_index + step, screens.MENU.size())
	elif screens.mode == "settings":
		screens.settings_row = posmod(screens.settings_row + step, screens.SETTING_ROWS.size())
	else:
		return
	audio.play("click", 1.25, -10.0)


## ESC, BACKSPACE or the right button: from HOW TO PLAY or SETTINGS back to the menu.
func act_menu_back() -> void:
	if state != State.TITLE or screens.mode == "title" or not screens.on_title():
		return
	screens.back_to_menu()
	audio.play("click", 1.0, -6.0)


## A page of HOW TO PLAY on or back. On from the last page is back to the menu.
func act_howto_turn(step: int) -> void:
	if state != State.TITLE or screens.mode != "howto":
		return
	if screens.turn_howto(step):
		audio.play("paper", 1.1, -6.0)
	elif step > 0:
		act_menu_back()


## A choice on the SETTINGS page: it applies at once and is kept for the next start (never on a
## test run, settings.gd). The language is act_language's, which keeps it the same way.
func act_setting(row: String, value: Variant) -> void:
	if state != State.TITLE or screens.mode != "settings":
		return
	var options: Array = screens.SETTING_OPTIONS.get(row, [])
	if not options.has(value):
		return
	match row:
		"language":
			act_language(str(value))
			return
		"patient_ai":
			audio.play("click")
			_log("setting", {"row": row, "value": value})
			_set_patient_ai(value == "on", _patient_override == "")
			return
		"blood":
			if (str(value) == "less") == less_blood:
				return
			_set_less_blood(str(value) == "less")
			Settings.save_value("blood", str(value))
		"volume":
			if int(value) == audio.volume_step and not audio.muted:
				return
			audio.set_volume_step(int(value))
			audio.set_muted(false)      # a level chosen is a level to hear
			Settings.save_value("volume", audio.volume_step)
		"screen":
			if (str(value) == "fullscreen") == fullscreen:
				return
			act_fullscreen(str(value) == "fullscreen")
			return
	audio.play("click")
	_sync_settings()
	_log("setting", {"row": row, "value": value})


## The preference is intent across launches. Each launch rechecks the service before any visit.
func _set_patient_ai(on: bool, save_choice: bool) -> void:
	_patient_check_id += 1
	var check_id := _patient_check_id
	use_model = false
	_service_is_mock = false
	_patient_status = "no_url" if agent_url == "" else "off"
	if on and agent_url != "":
		_patient_status = "checking"
		_sync_patient_status()
		var health: Dictionary = await model_client.check_service(templates, int(rules.agent.health_timeout_ms))
		if check_id != _patient_check_id or _closing:
			return
		_patient_status = str(health.status)
		use_model = _patient_status == "connected"
		_service_has_beats = bool(health.get("beats", false))
		_service_has_voice = bool(health.get("voice", false))
		_service_is_mock = bool(health.get("mock", false))
	if save_choice:
		Settings.save_value("patient_ai", "on" if use_model else "off")
	_sync_patient_status()
	patient_check_finished.emit()


func _sync_patient_status() -> void:
	screens.status_line = _status_line()
	screens.voice = _mic_why_not() == ""
	_sync_settings()


## LEFT or RIGHT on the SETTINGS page: the lit row's choice before or after the one in use.
func act_setting_step(step: int) -> void:
	if state != State.TITLE or screens.mode != "settings":
		return
	var row := screens.setting_row()
	var options: Array = screens.SETTING_OPTIONS.get(row, [])
	if options.is_empty():
		return
	var at := options.find(screens.settings.get(row))
	act_setting(row, options[clampi(at + step, 0, options.size() - 1)])


## ENTER on the SETTINGS page: the lit row's next choice, round at the end, or BACK.
func act_setting_enter() -> void:
	if state != State.TITLE or screens.mode != "settings":
		return
	var row := screens.setting_row()
	if row == "back":
		act_menu_back()
		return
	var options: Array = screens.SETTING_OPTIONS.get(row, [])
	if options.is_empty():
		return
	act_setting(row, options[(options.find(screens.settings.get(row)) + 1) % options.size()])


## M: sound off or on again, anywhere.
func act_mute() -> void:
	audio.set_muted(not audio.muted)
	_sync_settings()


## F11 or SCREEN in SETTINGS: full screen or a window, kept for the next start.
func act_fullscreen(on: bool) -> void:
	_apply_fullscreen(on)
	Settings.save_value("screen", "fullscreen" if on else "window")
	audio.play("click", 1.0, -6.0)
	_sync_settings()
	_log("setting", {"row": "screen", "value": "fullscreen" if on else "window"})


func _apply_fullscreen(on: bool) -> void:
	fullscreen = on
	get_window().mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED


## BLOOD in SETTINGS: what --less-blood does, for the clinic, the gore and every patient from now on.
func _set_less_blood(on: bool) -> void:
	less_blood = on
	clinic.less_blood = on
	gore.less_blood = on
	if rig != null:
		rig.less_blood = on


## What the SETTINGS page shows, as things are now.
func _sync_settings() -> void:
	if screens == null or audio == null:
		return
	screens.settings = {"language": Lang.code, "blood": "less" if less_blood else "full", "volume": audio.volume_step,
		"screen": "fullscreen" if fullscreen else "window", "muted": audio.muted,
		"patient_ai": "on" if use_model or _patient_status == "checking" else "off",
		"patient_status": "mock" if _service_is_mock else _patient_status}


func _show_title() -> void:
	state = State.TITLE
	screens.show_title()
	clinic.shutter_to(1.0, 0.01)
	desk.set_all(false)
	_hang_sheet()
	clipboard.set_visit(null, "")
	audio.loop("amb_rain", -15.0)
	audio.loop("amb_drone", -24.0)


## What the title card says about talking to the patient in this session.
func _status_line() -> String:
	if _patient_status == "checking":
		return STATUS_CHECKING
	if not use_model:
		return STATUS_OFFLINE
	var authored := str(rules.get("agent", {}).get("ask_answers", "authored")) == "authored"
	match _mic_why_not():
		"":
			return STATUS_AI_VOICE if authored else STATUS_MODEL_VOICE
		"no_mic":
			return STATUS_AI_NO_MIC if authored else STATUS_MODEL_NO_MIC
	return STATUS_AI_TYPE if authored else STATUS_MODEL_TYPE


# ================================================================ small helpers

## A coaching hint: shown once a session, the first time the thing it explains happens. It
## waits for the hint row to be free, and the next action takes it away again. One that never
## got its moment is dropped, and is offered again the next time the same thing happens.
func _coach(id: String, text: String) -> void:
	if _coached.has(id):
		return
	_coach_id = id
	_coach_next = text


func _bump() -> int:
	_beat_activity()
	_seq += 1
	return _seq


func _wait(seconds: float, token: int) -> bool:
	var left := seconds
	while left > 0.0:
		await night_frame
		if token != _seq:
			return false
		left -= get_process_delta_time()
	return true


## Lets the line on screen finish typing, then holds it. A click hurries either part.
func _run_line(token: int, hold: float) -> bool:
	_skip = false
	while dialogue.typing:
		await night_frame
		if token != _seq:
			return false
		if _skip:
			_skip = false
			dialogue.skip()
	dialogue.waiting = hold >= 0.5
	var left := hold
	while left > 0.0:
		await night_frame
		if token != _seq:
			return false
		if _skip:
			_skip = false
			break
		if not guide.is_open():      # a line is not taken off the screen while the guide covers it
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


func _patient_line(text: String, token: int, hold: float = 0.8, remember: bool = true) -> bool:
	if token != _seq or text == "" or visit == null:
		return token == _seq
	var spoken := Lang.t(text)
	if remember and agent != null and agent.record == visit.record:
		visit.record.append("patient", spoken)
	var voice: Dictionary = visit.case_data.get("voice", {})
	_patient_talking = true
	_set_voice("blip_glitch" if bool(voice.get("glitch", false)) else "blip", float(voice.get("pitch", 1.0)), -7.0)
	dialogue.say(_patient_name(), _spoken_for_display(spoken), Gfx.WARM6, Gfx.TEAL7, 44.0 * float(voice.get("rate", 1.0)), true)
	var ok: bool = await _run_line(token, hold)
	return ok


## raw: text is already what the doctor says (their own words, or a line put in the player's
## language beforehand); otherwise it is an authored line and is shown in the player's language.
func _doctor_say(text: String, raw: bool = false) -> void:
	_patient_talking = false
	_set_voice("blip", 0.8, -13.0)
	dialogue.say("YOU", text, Gfx.CYAN2, Gfx.TEAL6, 110.0, raw)


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
		await night_frame
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
				if not clipboard.card_open:
					_card_unseen += 1      # the card on the wall counts what it has not shown yet
	if any:
		audio.play("pencil")
		if clipboard.card_open:
			_coach("note_open", NOTE_OPEN_COACH_HINT)
		else:
			_coach("note", NOTE_COACH_HINT)
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
	_break_confirmation = false
	if state == State.EXAM:
		_beat_opening_done = true
	_close_scope(true)
	dialogue.clear_menu()
	_drop_stamp(false)
	_disarm()
	_close_say()
	dialogue.waiting = false
	_base_hint = ""
	_coach_next = ""      # a tip that was still waiting has missed its moment
	return _bump()


func _sync_visit() -> void:
	if visit == null:
		return
	clinic.set_patience(visit.patience, visit.patience_max)
	if visit.patience == 1 and visit.in_exam():
		_coach("lamp", LAMP_COACH_HINT)
	desk.badges.clear()
	desk.warn.clear()
	for tool in VisitState.TOOLS:
		var row: String = VisitState.TOOL_ROW[tool]
		var tag := "? " if visit.complaints_told.has(row) else ""
		desk.badges[tool] = tag + ("-%d" % visit.check_cost(tool) if not visit.granted.has(tool) else "")
	desk.warn["press"] = visit.press_breaks()
	desk.badges["press"] = ("?" if "temper" in visit.complaints_told else "") + Lang.t("BREAK") if visit.press_breaks() else ("? " if "temper" in visit.complaints_told else "") + "-%d" % visit.press_cost()
	_offer_break_tip()
	clinic.till = _till_now()


func _offer_break_tip() -> void:
	if visit != null and visit.in_exam() and visit.patience == 0 and visit.crossed() == 1:
		_coach("break", Lang.tf("One cross: wear or drift? BREAK sends a steady patient away unpaid. If they lunge, SPACE. Catch: fee +%d.", [int(rules.scoring.press_catch_bonus)]))


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


## The part of the patient under a point on the screen. The patient is drawn in view space.
func _zone_at(pos: Vector2) -> String:
	if rig == null or not rig.at_counter() or clinic.scope.is_open() or not Gfx.WINDOW.has_point(pos):
		return ""
	var at := Gfx.to_view(pos)
	for z in ["eyes", "port", "hands"]:
		var zone := str(z)
		if rig.zone_rect(zone).grow(2.0).has_point(at):
			return zone
	return ""


# ================================================================ the booth walls

## The papers and the big camera screen can be out while the counter is being worked: not on
## the title or the report, and not once a patient has shown that they have turned. Until that
## moment they behave the same whatever the patient is about to do: they give nothing away.
## While the counter guide is open they hang back on the wall, where the guide points at
## them, and they come down again by themselves when it closes.
func _panels_live() -> bool:
	if _panels_hold or (guide != null and guide.is_open()):
		return false
	return (state == State.WAIT or state == State.ENTER or state == State.EXAM or state == State.ATTACK
		or state == State.RESOLVE or state == State.SLIP)


## The card comes down by itself while there is a stamp to put on it, and for a moment after
## it was stamped. The findings are not written on it: they wait for the report at closing.
func _card_forced() -> bool:
	return clipboard.armed != "" or _card_linger > 0.0


func _card_out() -> bool:
	return _panels_live() and (_card_wanted or _card_forced())


func _sheet_out() -> bool:
	return _panels_live() and _sheet_wanted and not _list_wanted


## Tonight's contact list hangs on the sheet's hook: one of the two is down at a time.
func _list_out() -> bool:
	return _panels_live() and _list_wanted


func _cam_out() -> bool:
	return _panels_live() and _cam_wanted and (state == State.WAIT or state == State.EXAM)


## Which open paper or screen is under a point: "sheet", "list", "card", "cam" or "". An open one is in
## front of the window, so it takes the pointer before the patient does.
func _panel_at(pos: Vector2) -> String:
	if clipboard.in_record(pos):
		return "card"
	if clipboard.in_list(pos):
		return "list"
	if clipboard.in_sheet(pos):
		return "sheet"
	if clinic.cam_open and Gfx.CAM.has_point(pos):
		return "cam"
	return ""


func _over_thumb(pos: Vector2) -> bool:
	return Gfx.THUMB.grow(4.0).has_point(pos)


## Takes a paper down from the wall, or hangs it back. `on`: 1 down, 0 back, -1 the other way.
func act_sheet(on: int = -1) -> void:
	if not _panels_live():
		return
	var want := (not _sheet_wanted) if on < 0 else on > 0
	if want == _sheet_wanted:
		return
	_sheet_wanted = want
	_sheet_back = false
	if want:
		_sheet_seen = true
		_list_wanted = false      # one hook: the list goes back up as the sheet comes down
		_list_back = false
		if coach != null:
			coach.event("sheet_open")
	audio.play("paper", 1.1 if want else 0.9, -5.0)
	_log("panel", {"panel": "sheet", "open": want})


func act_card(on: int = -1) -> void:
	if not _panels_live():
		return
	var want := (not _card_out()) if on < 0 else on > 0
	if not want and _card_forced():
		_card_wanted = false      # it is out for the stamp: it stays while the stamp needs it
		return
	if want == _card_wanted:
		return
	_card_wanted = want
	_card_back = false
	audio.play("paper", 1.0 if want else 0.85, -5.0)
	_log("panel", {"panel": "card", "open": want})
	if want and coach != null:
		coach.event("courier_card" if shift.index == 1 and state == State.EXAM else "card_open")


## The big screen of the hall camera. `on`: 1 on, 0 off, -1 the other way; and while somebody
## is waiting to be let in, a press on the lit screen buzzes them in.
func act_cam(on: int = -1) -> void:
	if not _panels_live() or not (state == State.WAIT or state == State.EXAM):
		return
	if on < 0 and state == State.WAIT and clinic.cam_prompt and _cam_wanted:
		act_call_next()
		return
	var want := (not _cam_wanted) if on < 0 else on > 0
	if want == _cam_wanted:
		return
	_cam_wanted = want
	audio.play("click", 0.9 if _cam_wanted else 0.75, -6.0)
	_log("panel", {"panel": "cam", "open": _cam_wanted})
	if state == State.WAIT and clinic.cam_prompt:
		_base_hint = CAM_HINT if _cam_wanted else WAIT_HINT


## A close-up needs the whole window: the papers step aside for it and come back afterwards,
## and the big screen goes off. Both happen at once, not a frame later: a close-up can open
## from a timer, after this frame's _process has run, and it is never drawn under a paper.
func _papers_aside() -> void:
	_sheet_back = _sheet_wanted
	_card_back = _card_wanted
	_list_back = _list_wanted
	_sheet_wanted = false
	_card_wanted = false
	_list_wanted = false
	_cam_wanted = false
	_sync_panels(0.0)


func _papers_return() -> void:
	if _sheet_back:
		_sheet_wanted = true
	if _card_back:
		_card_wanted = true
	if _list_back:
		_list_wanted = true
	_sheet_back = false
	_card_back = false
	_list_back = false
	_sync_panels(0.0)


## Once a frame: what the views show follows what the doctor has asked for.
func _sync_panels(delta: float) -> void:
	if _card_linger > 0.0:
		_card_linger = maxf(0.0, _card_linger - delta)
	var list_on := _list_out()
	var sheet_on := _sheet_out() and not list_on
	var card_on := _card_out()
	if card_on:
		_card_unseen = 0
	clipboard.sheet_open = sheet_on
	clipboard.list_open = list_on
	clipboard.card_open = card_on
	clinic.cam_open = _cam_out()
	desk.taken["sheet"] = sheet_on
	desk.taken["list"] = list_on
	desk.taken["card"] = card_on
	# the sheet asks to be looked at until it has been down once
	if _sheet_seen or not (state == State.EXAM or state == State.WAIT):
		desk.nudge.erase("sheet")
	else:
		desk.nudge["sheet"] = true
	# and so does tonight's contact list, on a night with couriers on it
	if _list_seen or shift == null or shift.contacts.is_empty() or not (state == State.EXAM or state == State.WAIT):
		desk.nudge.erase("list")
	else:
		desk.nudge["list"] = true
	if _card_unseen > 0 and not card_on and visit != null:
		desk.badges["card"] = str(_card_unseen)
	else:
		desk.badges.erase("card")
	# the key that orders glass: lit between patients, when a layer is missing
	var can_mend := _can_mend()
	desk.enabled["glass"] = can_mend
	if can_mend:
		desk.badges["glass"] = "-%d" % shift.repair_cost()
	else:
		desk.badges.erase("glass")


# ================================================================ the counter glass

## A layer can be ordered while the counter is empty and the next visitor has not been let in.
func _can_mend() -> bool:
	return state == State.WAIT and clinic.cam_prompt and shift != null and shift.can_repair()


func _glass_hint() -> String:
	if shift == null or shift.repair_cost() <= 0:
		return GLASS_OFF_HINT
	if shift.glass >= shift.glass_max():
		return GLASS_WHOLE_HINT
	if not _can_mend():
		return GLASS_BUSY_HINT
	return Lang.tf(GLASS_HINT, [shift.repair_cost()])


## Pays for one layer of the counter glass out of the till (ShiftState.repair_glass()). The
## pane takes one more blow, so the next patient who turns gives the doctor more time again.
## The meter counts the money at every later reading.
func act_repair_glass() -> void:
	if not _can_mend():
		return
	var res: Dictionary = shift.repair_glass()
	if res.is_empty():
		return
	var cost := int(res.get("cost", 0))
	var left := int(res.get("glass", 0))
	var most := shift.glass_max()
	var token := _bump()       # the line about who is in the hall gives way to this one
	clinic.clear_decals()      # the arm wipes the pane as it goes
	# the cracks that still show are the layers still missing: a whole pane shows none
	clinic.set_glass(clampi(most - left, 0, 3))
	clinic.set_glass_left(left, most)
	clinic.till = shift.till()
	audio.play("glass_fit")
	audio.play("cash", 0.8, -8.0)
	_log("glass_repair", {"cost": cost, "glass_left": left, "glass_max": most, "till": shift.till()})
	var ok: bool = await _narrate("GLASS", Lang.tf(GLASS_LINE, [cost, left, most]), token, 1.2)
	# back to who is waiting, unless something else has happened meanwhile
	if ok and state == State.WAIT and clinic.cam_prompt and shift != null:
		var c: Dictionary = cases.get(shift.current_id(), {})
		_narrate("HALL CAMERA", str(c.get("teaser", "")), token, 0.0, Gfx.GRN4)


func _pad_hint(pad: String) -> String:
	if pad == "glass":
		return _glass_hint()
	if visit == null:
		return ""
	var costs: Dictionary = rules.get("costs", {})
	match pad:
		"penlight", "grip", "port":
			var status := visit.check_status(pad)
			if status == "open":
				return Lang.tf("%s Free now.", [Lang.t(str(TOOL_WHAT[pad]))])
			return Lang.tf("%s Costs %d patience.", [Lang.t(str(TOOL_WHAT[pad])), visit.check_cost(pad)])
		"ask":
			return "Listed questions are free."
		"complain":
			return "What's bothering you?"
		"press":
			if visit.press_breaks():
				return Lang.tf(PRESS_LAST_HINT, [int(rules.scoring.get("press_catch_bonus", 0))])
			return Lang.tf(PRESS_HINT, [visit.press_cost()])
		"treat":
			return "TREAT: they are steady. Pick it up and stamp the card."
		"refer":
			return "TRAUMA TEAM: for the drifting. Press twice. They come and take the patient."
		"shutter":
			return "SHUTTER [SPACE]: ends the visit at once. Only for danger."
	return ""


# ================================================================ shift flow

func act_start() -> void:
	if state != State.TITLE or cases.is_empty() or screens.mode != "title":
		return
	if _patient_status == "checking":
		await patient_check_finished
		if state != State.TITLE or screens.mode != "title" or _closing:
			return
	screens.hide_all()
	audio.play("click")
	if intro_enabled and not _intro_seen and intro.has_cards():
		_run_intro()
	else:
		_start_shift()


## The opening: a few cards about the lease, the line and the drift, once a session. Any click
## or ENTER moves on, ESC or the right button skips the rest.
func _run_intro() -> void:
	_intro_seen = true
	state = State.INTRO
	_log("intro", {"cards": intro.count()})
	intro.start()
	await intro.finished
	if state != State.INTRO:
		return
	_log("intro_end", {"skipped": intro.skipped, "reached": intro.index + 1})
	_start_shift()


func act_intro_next() -> void:
	if state == State.INTRO:
		intro.advance()


func act_intro_skip() -> void:
	if state == State.INTRO:
		intro.skip_all()


func _on_intro_blip() -> void:
	audio.play("blip_narrate", _fx_rng.randf_range(0.96, 1.05), -15.0)


func _on_intro_turned() -> void:
	audio.play("paper", 1.0, -6.0)


## A picture on a card wants a sound: the stamp landing, the meter ticking up, the shutter.
func _on_intro_cue(sound: String) -> void:
	audio.play(sound, 1.0, -9.0)


## The counter guide: what everything on the screen is for. It opens by itself once, before
## the first patient of a session that has no first-night training (on a training night the
## coach points at one thing at a time instead), and again whenever the player asks (H or F1).
func act_guide(asked: bool = true) -> void:
	if guide.is_open() or not guide.has_pages():
		return
	if not (state == State.WAIT or state == State.EXAM):
		return
	if _mic_state != "":
		return
	guide.open()
	audio.play("paper")
	_log("guide", {"asked": asked})
	_guide_seen = true


func act_guide_next() -> void:
	if not guide.is_open():
		return
	guide.next()
	audio.play("paper" if guide.is_open() else "click", 1.1, -6.0)


func act_guide_back() -> void:
	if guide.is_open():
		guide.back()


func act_guide_close() -> void:
	if guide.is_open():
		guide.close()
		audio.play("click", 1.0, -6.0)


## A new night, from the totals page of the report.
func act_restart() -> void:
	if state != State.REPORT or not screens.on_summary() or screens.age() < 0.8:
		return
	screens.hide_all()
	audio.play("click")
	_start_shift()


## From the totals page of the report back to the title card: its menu, HOW TO PLAY and SETTINGS
## (the language is only changed there). The booth behind the card is put back the way a night
## finds it. START then goes straight to the counter: the opening cards and the first night's
## training have been seen in this session.
func act_report_menu() -> void:
	if state != State.REPORT or not screens.on_summary() or screens.age() < 0.8:
		return
	audio.play("click", 1.0, -6.0)
	_bump()
	_log("menu_return", {"shift": shift_number})
	if coach != null and coach.is_running():
		coach.stop(false)
	_reset_booth()
	clinic.line = 0
	clinic.set_glass_left(clinic.glass_max, clinic.glass_max)
	_show_title()


## The booth the way a night finds it: nobody at the counter, an empty till, no lamps on the
## meter, the window, the walls and the shutter whole and clean, and every paper on its board.
## A new night starts from it (_start_shift, which then puts tonight's queue, line and glass on
## the meter), and so does the title card when the player goes back to it (act_report_menu).
func _reset_booth() -> void:
	if agent != null:
		agent.end_visit()
	_visit_serial = 0
	visit = null
	clinic.till = 0
	clinic.snap_till()
	clinic.results = []
	clinic.queue_index = 0
	clinic.line_under = false
	clinic.reset_damage()
	_leave_t = -1.0
	_leave_said = false
	_leave_idle = 0.0
	# everything hangs on the walls again
	_sheet_wanted = false
	_card_wanted = false
	_cam_wanted = false
	_sheet_back = false
	_card_back = false
	_card_linger = 0.0
	_card_unseen = 0
	_panels_hold = false
	_list_wanted = false
	_list_back = false
	_list_seen = false
	_surprise = ""
	gore.clear()
	for c in _mess.get_children():
		c.queue_free()
	_stop_attack_audio()
	audio.trim_db = 0.0
	clinic.set_cam("")
	clinic.corner_text = ""


## Tonight: the test night asked for (--test-night, or night A with --authored-order), or one
## drawn from the shift seed (ShiftState.draw_night). A drawn night that comes out empty, which
## only broken data can make, falls back to night A.
func _night_for_shift() -> Dictionary:
	night_name = test_night if test_night != "" else ("A" if authored_order else "")
	if night_name == "":
		var drawn := ShiftState.draw_night(_db, shift_seed, shift_number == 1)
		if not CaseDB.night_order(drawn).is_empty():
			return drawn
		night_name = "A"
	return ShiftState.draw_complaints((nights.get(night_name, {}) as Dictionary).duplicate(true), templates, rules, shift_seed, true)


func _start_shift() -> void:
	shift_number += 1
	shift_seed = fixed_seed if has_fixed_seed else int(_boot_rng.randi())
	_rng.seed = shift_seed
	night = _night_for_shift()
	cases = CaseDB.compose_night(templates, night, parts)
	shift = ShiftState.new(rules, CaseDB.night_order(night))
	# the training night puts its first visitor on the list, so the code is shown on the first exam
	var training := training_enabled and intro_enabled and not _trained and coach != null and coach.has_steps()
	var contact_rules: Dictionary = rules.get("contacts", {})
	# only the entries that are fair among tonight's visitors: no clue alone gives anybody away
	var pool := CaseDB.fair_contacts(contact_data, cases, shift.order)
	# each entry is given an alias and a code for tonight only (contacts.json version 2)
	if training:
		# Keep all seeded cases intact. If visitor two has no fair pair of clues,
		# call a later fair courier in that slot; the opening patient stays protected.
		var slot := clampi(int(contact_rules.training_slot) - 1, 0, shift.order.size() - 1)
		var eligible := CaseDB.fair_couriers(contact_data, cases, shift.order)
		if shift.order[slot] not in eligible:
			for i in range(slot + 1, shift.order.size()):
				if shift.order[i] in eligible:
					var swap: Variant = shift.order[slot]
					shift.order[slot] = shift.order[i]
					shift.order[i] = swap
					break
	shift.contacts = ShiftState.draw_contacts(rules, pool, shift.order, shift_seed, training, contact_data)
	clipboard.set_contacts(shift.contacts, contact_data.get("clues", {}), str(contact_data.get("title", "")),
		int(contact_rules.get("pay", 0)), int(contact_rules.get("wrong_cost", 1)))
	var client: Variant = null
	if agent_url != "":
		client = model_client
	agent = PatientAgent.new(rules, client, shift_seed)
	agent.run_id = run_id
	agent.set_mode("model" if use_model else "script")
	_reset_booth()
	clinic.queue_count = shift.count()
	clinic.line = shift.line_at(1)
	clinic.set_glass_left(shift.glass, shift.glass_max())
	_log("shift_start", {"shift": shift_number, "seed": shift_seed, "night": night_name if night_name != "" else "drawn",
		"order": shift.order, "agent_mode": agent.mode})
	_log("night", {"name": night_name, "visitors": (night.get("visitors", []) as Array).duplicate(true)})
	var ids: Array = []
	for e in shift.contacts:
		ids.append(str((e as Dictionary).get("id", "")))
	_log("contacts", {"entries": shift.contacts.size(), "ids": ids, "training": training})
	if training:
		_trained = true
		_training_night = shift_number
		coach.start()
		_log("training", {"tips": coach.count()})
	elif coach != null and coach.is_running():
		coach.stop(false)
	state = State.WAIT
	clinic.cam_prompt = false
	var token := _bump()
	clinic.shutter_to(0.0, 1.0)
	desk.lever_down = false
	audio.play("shutter_roll")
	var ok: bool = await _narrate("", _shift_line(), token, 0.7)
	if not ok:
		return
	_begin_wait()


## Between patients: the lender's meter reads the till (after every patient but the last,
## whose reading is the report), then the hall camera shows who is next and the player buzzes
## them in. `reading` is ShiftState.reading() for the hour that just ended, or empty.
func _begin_wait(reading: Dictionary = {}) -> void:
	state = State.WAIT
	var token := _bump()
	clinic.show_patience = false
	clinic.cam_prompt = false
	_desk_off()
	_alert_hint = ""
	_base_hint = ""
	_coach_next = ""
	var id := shift.current_id()
	var c: Dictionary = cases.get(id, {})
	if not reading.is_empty():
		var held := bool(reading.get("held", true))
		var hour := int(reading.get("hour", 0))
		var till := int(reading.get("till", 0))
		var want := int(reading.get("line", 0))
		_log("meter", {"hour": hour, "till": till, "line": want, "held": held})
		clinic.line_under = not held
		audio.play("beep" if held else "beep_low", 1.0, -4.0)
		var said := Lang.tf(METER_OVER_LINE, [hour, shift.count(), till, want])
		if not held:
			said = Lang.tf(METER_UNDER_LINE, [hour, shift.count(), till, want, want - till])
		var read: bool = await _narrate("METER", said, token, 0.9, Gfx.GRN4 if held else Gfx.RED3)
		if not read:
			return
	# the pinned notes turn to the next hour together, once the reading of the last one is said
	clinic.queue_index = shift.index
	clinic.line = shift.line_at(shift.index + 1)
	# nobody is called while the shutter is still down
	while clinic.shutter_pos > 0.02:
		await night_frame
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
	_base_hint = CAM_HINT if _cam_wanted else WAIT_HINT
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
	_cam_wanted = false      # the big screen goes dark as the door opens: they are at the window now
	_card_unseen = 0
	_card_linger = 0.0
	_panels_hold = false
	_base_hint = ""
	audio.play("beep", 0.8)
	var c: Dictionary = cases[id]
	_visit_serial += 1
	visit = VisitState.new(c, rules)
	visit.set_contact(shift.contact_for(id))
	# The first visitor teaches the tests, the second teaches contacts.
	if coach != null and coach.is_running() and shift.index > int(rules.contacts.training_slot) - 1:
		coach.stop(false)
	_training_visit = shift.index == 0 and shift_number == _training_night
	visit.surprises = surprises_enabled and not _training_visit      # nobody snaps on the training visit
	_surprise = ""
	_snap_rng.seed = hash("surprise:%d:%d" % [shift_seed, _visit_serial])
	_beat_opening_done = false
	_beat_pending = false
	_beat_activity()
	agent.begin_visit(visit, Crypto.new().generate_random_bytes(16).hex_encode(), shift_seed + _visit_serial * 7919)
	_telegraphed = false
	_attack_t = 0.0
	_blows = 0
	_log("visit_start", {"index": shift.index, "agent_mode": agent.mode, "contact": visit.is_contact(), "training": _training_visit})
	if coach != null:
		coach.event("visit_start" if shift.index == 0 else "courier_arrives")
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
		await night_frame
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
	# a fresh intake card goes on the clipboard on the wall, the binder pages for his models
	# go up as the sheet, and the exam is open
	_hang_sheet()
	clipboard.set_visit(visit, "%d/%d" % [shift.index + 1, shift.count()])
	audio.play("paper")
	clinic.show_patience = true
	state = State.EXAM
	_desk_for_exam()
	_cam_in = _rng.randf_range(9.0, 15.0)
	if not _first_visit_done:
		_base_hint = FIRST_HINT
	# the first patient of a session: the guide to the counter opens by itself, now that
	# everything it points at (the patient, the lamps, the pads, the record) is in view
	if intro_enabled and not _guide_seen and not _trained and guide.has_pages():
		act_guide(false)
		while guide.is_open():
			await night_frame
			if token != _seq:
				return
	var opening: Array = c.get("opening", [])
	for line in opening:
		ok = await _patient_line(str(line), token, 0.9)
		if not ok:
			return
	_beat_opening_done = true
	_try_beat("arrive")


func _show_upcoming() -> void:
	if shift == null:
		return
	var up := shift.upcoming_id()
	if up != "" and clinic.cam_id == "":
		clinic.set_cam(up)
		audio.play("door_chime", 1.0, -9.0)


# ================================================================ exam actions

func act_look(zone: String) -> void:
	if not _can_decide() or not VisitState.ZONES.has(zone):
		return
	desk.pulse = str(CaseDB.ROW_TOOL[zone])
	_base_hint = _pad_hint(desk.pulse)
	audio.play("click")


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
		_roll_surprise(0)
		return
	if visit.patience < visit.check_cost(tool):
		_spent(token)
		return
	var before := _note_keys()
	var event := {"type": "check", "id": tool}
	event["outcome"] = "grant"
	var d: Dictionary = await _decide(event, visit.legal_moves_for_check(tool), str(TOOL_ASK[tool]), token)
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
			if ok:
				_roll_surprise(int(res.get("cost", 0)))      # the close-up is no shelter: they can come at the glass during it
		"spent":
			_spent(token)


## The model receives the doctor's words and conversation. The options are fallback-only.
## own: ask_line is the doctor's own wording (typed or spoken), sent and shown as it was said;
## otherwise it is an authored line, and the patient hears it in the player's language.
## Returns {} when the action was cancelled meanwhile (the shutter fell).
func _decide(event: Dictionary, legal: Array, ask_line: String, token: int, own: bool = false, fallback: String = "") -> Dictionary:
	_thinking = true
	_lock = true
	_think_t = 0.0
	_think_quiet = 0.0
	if not own:
		ask_line = Lang.t(ask_line)
	if not own or event.get("type") == "press":
		_doctor_say(ask_line, true)
	event = event.duplicate(true)
	event["text"] = ask_line
	var d: Dictionary = await agent.decide(event, visit.snapshot(), legal, visit.open_signs(event), fallback)
	if _quit_night.visible:
		await night_resumed
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
	if d.get("source") == "fallback":
		_base_hint = _fallback_hint(str(d.fallback_reason))
	_lock = false
	return d


## Preserve the words in the visit record. Normalize glyphs only when drawing the strip.
func _spoken_for_display(text: String) -> String:
	var display := Gfx.printable(text)
	return "..." if display == "" and text != "" else display


func _show_reaction(response: Dictionary, token: int) -> bool:
	var reaction := str(response.get("reaction", ""))
	if token != _seq or visit == null or reaction == "":
		return token == _seq
	if agent != null and agent.record == visit.record:
		visit.record.append("reaction", Lang.t(reaction))
	return await _narrate(_patient_name(), _spoken_for_display(Lang.t(reaction)), token, 0.35)


## The patient will not pay for that: there is not enough patience left for it.
func _spent(token: int) -> void:
	_log("spent", {"patience": visit.patience})
	if visit.is_spent() and not _leave_said:
		_start_leaving(token)      # asking for more is what makes them say it
		return
	audio.play("beep_low")
	if not visit.is_spent():
		_base_hint = SHORT_HINT
	var lines: Dictionary = visit.case_data.get("lines", {})
	_patient_line(str(lines.get("spent", "")), token, 1.0)


## The last patience lamp is out: the patient says so, and the wait that is left starts.
func _start_leaving(token: int) -> void:
	_leave_said = true
	_leave_idle = 0.0
	_leave_t = float(visit.leave_ms()) / 1000.0
	_log("leaving", {"wait_ms": visit.leave_ms()})
	audio.play("beep_low")
	var lines: Dictionary = visit.case_data.get("lines", {})
	_patient_line(str(lines.get("spent", "")), token, 0.0)


## A patient whose patience is gone gives the doctor one last wait (rules.json:
## patience.leave_ms) and then leaves by themselves, with no fee and no fine. The wait stands
## still while an answer is on its way, while a test is open, while the doctor is speaking and
## while a paper is open.
func _update_leaving(delta: float) -> void:
	if state != State.EXAM or visit == null or not visit.is_spent():
		_leave_said = false
		_leave_t = -1.0
		_leave_idle = 0.0
		clinic.leaving = -1.0
		return
	var busy := _thinking or _lock or clinic.scope.is_open() or _mic_state != "" or guide.is_open() or dialogue.input_open or dialogue.has_menu() or dialogue.typing or dialogue.waiting or clipboard.sheet_open or clipboard.card_open or clipboard.list_open or _quit_night.visible or _held != "" or _call_armed > 0.0
	if not _leave_said:
		clinic.leaving = -1.0
		if busy or dialogue.typing or dialogue.waiting:
			_leave_idle = 0.0
			return
		_leave_idle += delta
		if _leave_idle >= LEAVE_BEAT:
			_start_leaving(_bump())
		return
	var total := maxf(0.001, float(visit.leave_ms()) / 1000.0)
	if not busy:
		_leave_t -= delta
	clinic.leaving = clampf(_leave_t / total, 0.0, 1.0)
	if _leave_t <= 0.0 and not busy:
		_gave_up()


## Nobody decided and the wait is over: the patient walks out by themselves.
func _gave_up() -> void:
	var token := _begin_action()
	var res: Dictionary = visit.give_up()
	if str(res.get("result", "")) == "":
		return
	_first_visit_done = true
	state = State.RESOLVE
	_desk_off()
	clinic.leaving = -1.0
	_leave_t = -1.0
	_leave_said = false
	_log("gave_up", {})
	var exit: Dictionary = visit.case_data.get("exit", {})
	var ok: bool = await _patient_line(str(exit.get("gave_up", "")), token, 0.6)
	if not ok:
		return
	await _leave(1.0, false)
	_resolve()


func _open_scope(tool: String) -> void:
	if visit == null:
		return
	visit.record.append("action", "open:" + tool)
	var already := visit.seen.has("check:" + tool)
	clinic.scope.standard = _sheet_normal(str(VisitState.TOOL_ROW.get(tool, "")))      # what the sheet calls steady
	clinic.scope.limit_s = _grip_limit_s()
	var row: String = VisitState.TOOL_ROW[tool]
	var reading := ""
	for note in visit.notes[row]:
		if note.key == "check:" + tool:
			reading = str(note.text)
	clinic.scope.selected_mark = int(visit.marks[row])
	clinic.scope.open(tool, visit.case_data, already, reading)
	clinic.scope.pointer_screen(_mouse)
	_papers_aside()      # the close-up fills the window
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
	_papers_return()
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
	clinic.scope.set_result(str(res.text))
	_mark_new_notes(before)
	_log("check_done", {"tool": tool})
	if coach != null:
		coach.event("first_test" if visit.tests_in_order.size() == 1 else "second_test")
	_after_check(tool, str(res.get("text", "")), _seq)


func _after_check(tool: String, text: String, token: int) -> void:
	var ok: bool = await _narrate(str(TOOL_LABEL[tool]), text, token, 1.1)
	if not ok or visit == null:
		return
	var lines: Dictionary = visit.case_data.get("lines", {})
	var aside := str(lines.get("after:" + tool, ""))
	if agent.mode == "model":
		_try_beat("after_check", tool)
	elif aside != "":
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
			"tag": "asked" if known else ""})      # [shown] "asked" beside a question
	dialogue.set_menu("ASK", options)
	_base_hint = "Pick a question. Right-click closes the list."
	audio.play("click")


## said: the doctor's own wording of the question, when it was typed or spoken.
func act_ask(id: String, said: String = "", fallback: String = "") -> void:
	if not _can_act():
		return
	var topic: Dictionary = visit.topic(id)
	if topic.is_empty():
		return
	var token := _begin_action()
	var before := _note_keys()
	var question := said if said != "" else str(topic.get("q", ""))
	var legal := visit.legal_moves_for_ask(id)
	var event := {"type": "ask", "id": id}
	event["outcome"] = agent.scripted.choose_move(visit.case_data, event, visit.snapshot(), legal)
	var d: Dictionary = await _decide(event, [event.outcome], question, token, said != "", fallback)
	if d.is_empty():
		return
	var res := visit.apply_ask(id, str(d.get("move", "")), str(d.get("line", "")))
	if said != "" and fallback == "":
		_base_hint = Lang.tf("Asked as: %s", [Lang.t(str(topic.q))])
	_sync_visit()
	var result := str(res.get("result", ""))
	_log("ask", {"topic": id, "move": str(res.get("move", "")), "result": result, "cost": int(res.get("cost", 0)),
		"patience": visit.patience, "source": str(d.get("source", ""))})
	if coach != null:
		coach.event("listed_answer")
	if not await _show_reaction(d, token):
		return
	if result == "answered":
		_mark_new_notes(before)
		_patient_line(str(res.line), token, 0.0)


func act_complain(row: String = "", said: String = "", idle: bool = false) -> void:
	if not _can_act():
		return
	var token := _seq if idle else _begin_action()
	var before := _note_keys()
	if not idle:
		var question := Lang.t("What's bothering you?") if said == "" else said
		if said == "":
			_doctor_say(question, true)
		visit.record.append("doctor", question)
	var result := visit.complain(row, 1 if idle else -1)
	if not result.rows.is_empty():
		_mark_new_notes(before)
		if coach != null:
			coach.event("complaint")
	_sync_visit()
	_log("complaint", {"rows":result.rows, "idle":idle})
	_patient_line(result.line, token, 0.0)


## Pressure dialogue is autonomous; existing physical attack choreography remains in VisitState.
func act_press(confirmed: bool = false) -> void:
	if not _can_act():
		return
	var token := _begin_action()
	if visit.press_breaks() and not confirmed:
		_break_confirmation = true
		dialogue.set_menu("BREAK", [{"id":"break", "label":"Push again. SPACE drops the shutter.", "tag":""}, {"id":"cancel", "label":"Step back", "tag":""}])
		_base_hint = _pad_hint("press")
		return
	var question := Lang.t(str(PRESS_LINES[1 if visit.press_breaks() else 0]))
	var d := {}
	if visit.press_breaks():
		visit.record.append("doctor", question)
		_doctor_say(question, true)
	else:
		d = await _decide({"type": "press", "id": "challenge"}, [], question, token, true)
		if d.is_empty():
			return
	var before := _note_keys()
	var res: Dictionary = visit.press()
	res["line"] = str(d.get("reply", res.get("line", "")))
	var result := str(res.get("result", ""))
	_sync_visit()
	_log("press", {"count": visit.press_count, "result": result, "patience": visit.patience})
	if coach != null:
		if result == "react":
			coach.event("first_test" if visit.tests_in_order.size() == 1 else "second_test")
	if not await _show_reaction(d, token):
		return
	match result:
		"react":
			if rig != null:
				rig.react(str(res.get("face", "")), str(res.get("hands", "")))
			audio.play("sting")
			_mark_new_notes(before)
			clinic.scope.standard = _sheet_normal("temper")
			clinic.scope.selected_mark = int(visit.marks.temper)
			clinic.scope.open("press", visit.case_data, true, str(res.note))
			_papers_aside()
			_roll_surprise()
			_patient_line(str(res.get("line", "")), token, 0.0)
		"walkout":
			_walkout(str(res.get("line", "")), token)
		"attack":
			_attack_sequence(str(res.get("line", "")), token)


## The doctor says something in their own words: typed, or dictated and then sent.
func act_say(text: String) -> void:
	text = text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if not _can_act() or text.is_empty() or text.length() > 500:
		return
	var token := _begin_action()
	_thinking = true
	_lock = true
	_think_t = 0.0
	_think_quiet = 0.0
	_doctor_say(text, true)
	var reading: Dictionary = await agent.classify(text)
	if _quit_night.visible:
		await night_resumed
	if token != _seq or reading.is_empty():
		return
	_thinking = false
	_lock = false
	_log("intent", {"source": reading.source, "topic": reading.topic, "chars": text.length(), "code": reading.reason})
	var part := ScriptedBrain.part_for_text(text)
	if reading.get("intent") == "tool_request":
		var tool: String = CaseDB.ROW_TOOL.get(part, "press" if part == "temper" else "")
		if tool != "":
			desk.pulse = tool
	elif ScriptedBrain.is_complaint(text) or (part != "" and str(reading.topic) == ""):
		act_complain(part, text)
		return
	if str(reading.topic) != "":
		_log("say", {"source": reading.source, "topic": reading.topic, "chars": text.length()})
		await act_ask(str(reading.topic), text, str(reading.reason))
		return
	await _free_conversation(text, reading, token)



func _free_conversation(text: String, reading: Dictionary, token: int) -> void:
	var d: Dictionary = await _decide({"type": "say", "id": "free", "intent": reading.get("intent", "other")}, [], text, token, true, str(reading.reason))
	if d.is_empty():
		return
	_log("say", {"source": d.source, "chars": text.length(), "patience": visit.patience, "fallback_reason": d.fallback_reason})
	if d.source != "fallback":
		_base_hint = SAY_SMALL_HINT
	if coach != null:
		coach.event("talk")
	if await _show_reaction(d, token):
		_patient_line(str(d.reply), token, 0.0)


func _fallback_hint(reason: String) -> String:
	if reason == "call_cap":
		return Lang.tf("The patient AI has used its %d replies for this visit. Scripted lines now.", [agent.max_calls])
	return Lang.tf("The patient AI gave no answer (%s). Using the scripted patient.", [reason.left(26)])


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


## The window's input method (pinyin and the like) is on only while the typing line is open, and
## only in a language that needs one: in English a Chinese input method would turn the doctor's
## letters into lists of candidates. Its list opens under the caret. What it hands over arrives as
## key events with no key and one character each (_say_key); what it is still putting together
## comes with NOTIFICATION_OS_IME_UPDATE. Every frame.
func _sync_ime() -> void:
	var want := dialogue.input_open and Lang.code != "en" and DisplayServer.has_feature(DisplayServer.FEATURE_IME)
	var id := get_window().get_window_id()
	if want != _ime_on:
		_ime_on = want
		_ime_at = Vector2i(-1, -1)
		DisplayServer.window_set_ime_active(want, id)
		if not want:
			dialogue.input_compose("", 0)
	if not want:
		return
	# the strip's own coordinates, then the game's 640x360, then the window's pixels
	var at := Vector2i((get_viewport().get_final_transform() * (dialogue.get_global_transform_with_canvas() * dialogue.caret_point())).round())
	if at != _ime_at:
		_ime_at = at
		DisplayServer.window_set_ime_position(at, id)


## A key while the typing line is open. Everything printable is text, SPACE included.
func _say_key(keycode: int, unicode: int, control: bool = false) -> void:
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
			if not Gfx.typeable(unicode):
				return      # a key that types nothing, or a character no font here can draw
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
	if not bool(_mic_rules.get("enabled", false)) or not _service_has_voice:
		return "off"
	# speaking exists only where the patient AI does: the offline comparison never touches the network
	var in_visit := agent != null and state != State.TITLE
	var client: Variant = agent.client if in_visit else model_client
	var with_model: bool = (agent.mode == "model") if in_visit else use_model
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
	if _quit_night.visible:
		await night_resumed
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
	return Lang.tf("Could not write that down (%s). Try again, or type with T.", [reason.get_slice(":", 0).left(24)])


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


## The player's own tick or cross on a record row. Nothing scores it; the record keeps a tally
## of the crosses against the house rule on the reference sheet, and the hint row says where
## that stands. It is the player's reading of the patient, never the game's.
func act_mark(row: String, chosen: int = 0) -> void:
	if state != State.EXAM or visit == null:
		return
	var before := visit.crossed()
	var value := visit.cycle_mark(row) if chosen == 0 else chosen
	visit.marks[row] = value
	audio.play("pencil", 1.3, -6.0)
	var crossed := visit.crossed()
	var need := int(sheet.get("threshold", 0))
	_log("mark", {"row": row, "value": value, "crossed": crossed})
	if coach != null:
		coach.event("mark")
	_offer_break_tip()
	if crossed == before or need <= 0:
		return
	if crossed >= need:
		_base_hint = Lang.tf(CROSS_RULE_HINT, [crossed])
		if before < need:
			audio.play("beep_low", 1.2, -10.0)
	elif crossed > 0:
		_base_hint = Lang.tf(CROSS_SOME_HINT, [crossed, need])
		if visit.patience > 0:
			_coach("wear", "One cross can be wear. Two broken lines mean drift.")
	else:
		_base_hint = ""


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
	if coach != null:
		coach.event("verdict")
	state = State.ATTACK if next == "attack" else State.RESOLVE
	_desk_off()
	clipboard.stamp(kind)
	if kind == "treat":
		_card_linger = CARD_LINGER      # the stamp is seen to land, whatever happens next
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
		await night_frame
		if token != _seq:
			return false
		next_step -= get_process_delta_time()
		if next_step <= 0.0:
			audio.play("step", 0.7, -3.0)
			next_step = 0.12
	if rig != null:
		# the same start for everybody: how a patient takes the crew says nothing until closing
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
		await night_frame
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
		await night_frame
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
		await night_frame
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
## alarm, the lever throbbing, and a bar over the printer slot that shows the time that is left.
## Blows land on the glass at the marks on that bar; each one cracks the pane further and uses
## up one of the blows it can take tonight (ShiftState.attack_plan()), so a slow shutter leaves
## less time for the next attack. The shutter stops it; if it is still up when the bar runs
## out, they come through.
## lead_s >= 0: a snap. There is no last word and no long beat: they are at the glass already,
## and the red bar starts after lead_s.
func _attack_sequence(lead_line: String, token: int, lead_s: float = -1.0) -> void:
	_first_visit_done = true
	state = State.ATTACK
	_telegraphed = false
	_attack_t = 0.0
	_blows = 0
	_desk_off()
	desk.enabled["shutter"] = true
	_base_hint = ""
	var ok := true
	var attack_rules: Dictionary = rules.get("attack", {})
	var attack: Dictionary = visit.case_data.get("attack", {})
	var beat := lead_s
	if lead_s < 0.0:
		ok = await _patient_line(lead_line, token, 0.15)
		if not ok:
			return
		beat = _rng.randf_range(float(attack_rules.get("beat_min_ms", 600)), float(attack_rules.get("beat_max_ms", 1200))) / 1000.0
	else:
		dialogue.clear()
	if rig != null:
		rig.frozen = true
	_patient_talking = false
	audio.set_loop_volume("amb_drone", -50.0)
	clinic.flicker = 0.55 if lead_s < 0.0 else 0.8
	clinic.hall_dark = 0.4 if lead_s < 0.0 else 0.6
	ok = await _wait(beat, token)
	if not ok:
		return
	_telegraphed = true
	_panels_hold = true      # the papers and the big screen are out of the way: all of the window is theirs
	var style := _style()
	if rig != null:
		rig.frozen = false
		rig.set_attack(true)
		var glow: Color = style["glow"]
		if glow.a > 0.0:
			gore.flare_follow(rig, "tool", 5.0, glow)      # the torch arm lights
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
	_weapon_loop = str(style["loop"])
	if _weapon_loop != "":
		audio.loop(_weapon_loop, -9.0)
	_flash_now(Color(1.0, 0.22, 0.18), 0.4, 0.25)
	_shake(3.0, 0.3)
	_set_voice("", 1.0, 0.0)
	dialogue.say("", str(attack.get("telegraph", "")), Gfx.RED3, Gfx.RED3, 140.0)
	# how long the glass that is left tonight gives, and when each blow lands on it
	var plan: Dictionary = shift.attack_plan()
	var blows_ms: Array = plan.get("blows_ms", [])
	var through := float(plan.get("through_ms", 1800)) / 1000.0
	var marks: Array = []
	for ms in blows_ms:
		marks.append(float(ms) / 1000.0)
	clinic.bar_start(through, marks)
	_coach("glass", GLASS_COACH_HINT)      # shown once this attack is over, whichever way it goes
	_log("attack", {"cause": visit.attack_cause, "beat_ms": int(beat * 1000.0), "glass": shift.glass,
		"blows_due": blows_ms.size(), "through_ms": int(plan.get("through_ms", 1800))})
	while _attack_t < through:
		await night_frame
		if token != _seq:
			return
		var dt := get_process_delta_time()
		_attack_t += dt
		clinic.bar_t = _attack_t
		while _blows < marks.size() and _attack_t >= float(marks[_blows]):
			_blows += 1
			visit.take_blow()
			clinic.set_glass_left(shift.glass_blow(), shift.glass_max())
			_blow(_blows)
		_attack_fx(dt)
	_bump()
	visit.attack_timeout()
	_log("attack_hit", {"blows": visit.blows_taken})
	_hit()


## The patient's weapon, as a key of ATTACK_STYLES.
func _attack_style() -> String:
	var s := rig.attack_style() if rig != null else "saw"
	return s if ATTACK_STYLES.has(s) else "saw"


func _style() -> Dictionary:
	return ATTACK_STYLES[_attack_style()]


## One sample serves both: pitched down it is a roar, pitched up it is a scream.
func _scream_pitch() -> float:
	return float(_style()["pitch"])


## A shutter that has been hit before takes the next blows a little to one side.
func _dent_spot(spots: Array, i: int) -> Vector2:
	var spot: Vector2 = spots[i % spots.size()]
	var n := clinic.dent_count()
	if n >= 3:
		spot += Vector2(float((n * 37) % 41 - 20), float((n * 23) % 31 - 15))
	return spot


func _stop_attack_audio() -> void:
	audio.stop_loop("alarm")
	for s in ATTACK_STYLES.values():
		var loop_name := str((s as Dictionary)["loop"])
		if loop_name != "":
			audio.stop_loop(loop_name)
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
	var origin := Gfx.HOLE.position
	# the cracks show what the pane has taken tonight, not only in this attack: a pane that was
	# hit earlier starts from where it was left, and one that is gone is just a hole
	var pane := clinic.glass_state < 4
	rig.blow(n)
	if pane:
		clinic.set_glass(clampi(shift.glass_max() - shift.glass, 1, 3))
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
			_weapon_on_glass(pane)
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


## Blow two: the weapon itself on the pane (or on the empty frame, when the pane is gone).
func _weapon_on_glass(pane: bool) -> void:
	var style := _style()
	var at := Gfx.HOLE.position + ClinicView.HIT_TOOL
	var hot: Color = style["hot"]
	var glow: Color = style["glow"]
	var mark := "fx/%s.png" % str(style["mark"])
	var bite := str(style["bite"])
	match _attack_style():
		"torch", "laser", "arc":      # it burns: the mark glows, then cools
			audio.play(bite)
			if pane:
				clinic.add_decal(mark, ClinicView.HIT_TOOL)
				clinic.add_decal("fx/%s_hot.png" % str(style["mark"]), ClinicView.HIT_TOOL, true, 2.6)
			gore.sparks(at, 24, Vector2(0.0, -1.0), PI, 60.0, 210.0, hot)
			gore.flare_follow(rig, "tool", 8.0, glow)          # at full strength
			_flash_now(glow.lerp(Color.WHITE, 0.6), 0.3, 0.2)
		"lock", "baton":
			audio.play(bite)
			audio.play("bang", 1.4, -6.0)
			if pane:
				clinic.add_decal(mark, ClinicView.HIT_TOOL)
				gore.chips(at, 4)
			gore.sparks(at, 14, Vector2(0.3, -0.9), 1.4, 70.0, 220.0, hot)      # steel on glass, or the charge
		"fist", "spike":
			audio.play(bite)
			audio.play("bang", 0.7, -2.0)
			if pane:
				clinic.add_decal(mark, ClinicView.HIT_TOOL)
				gore.chips(at, 8)
			_shake(6.0, 0.35)
		"picks":
			audio.play("scrape", 1.15, -2.0)
			if pane:
				clinic.add_decal(mark, ClinicView.HIT_TOOL + Vector2(6, 4))
				gore.sparks(at, 18, Vector2(0.7, -0.6), 0.8, 60.0, 200.0, hot)
			gore.flare_follow(rig, "tool", 2.0, hot)      # the chrome catching the lamp
		_:      # an edge: the saw, the cleaver
			audio.play(bite)
			if pane:
				clinic.add_decal(mark, ClinicView.HIT_TOOL + Vector2(8, -6))
				if not less_blood:
					clinic.add_decal("fx/castoff_0.png", ClinicView.HIT_TOOL + Vector2(40, -34), false, 0.0, true)
				gore.sparks(at, 28, Vector2(0.6, -0.7), 1.3, 80.0, 260.0, hot)
				gore.flare_follow(rig, "tool", 3.0, Color("ffb45a"))      # steel on glass
			else:
				audio.play("slash", 1.2, -6.0)


## While the weapon is on the glass it throws sparks.
func _attack_fx(delta: float) -> void:
	if rig == null or _blows < 2:
		return
	_spark_t -= delta
	if _spark_t > 0.0:
		return
	_spark_t = 0.04
	var p := rig.attack_point("tool")
	var hot: Color = _style()["hot"]
	match _attack_style():
		"saw":
			if clinic.glass_state < 4:      # the saw only sparks while there is glass to bite
				gore.sparks(p, 3, Vector2(0.55, -0.8), 0.9, 50.0, 170.0, hot)
		"torch":
			gore.sparks(p, 2, Vector2(0.0, 1.0), 1.5, 25.0, 110.0, hot)
		"laser":
			gore.sparks(p, 1, Vector2(0.0, 1.0), 1.0, 20.0, 80.0, hot)      # a beam drips less than a flame
		"arc":
			if _fx_rng.randf() < 0.5:      # a live cable spits; it does not flow
				gore.sparks(p, 3, Vector2(0.0, 1.0), PI, 30.0, 170.0, hot)
		"baton":
			if _fx_rng.randf() < 0.12:      # the charged tip crackles now and then
				gore.sparks(p, 2, Vector2(0.0, -1.0), PI, 20.0, 90.0, hot)
		"picks":
			if clinic.glass_state < 4:      # ten points dragged over the glass
				gore.sparks(p, 1, Vector2(0.8, -0.4), 1.0, 30.0, 120.0, hot)
		_:
			pass      # a lock, a fist, a cleaver or a spike throws sparks only where it lands


## Too slow. The pane goes and they come through it at the player: glass, the weapon across
## the eyes, then again from closer, then a third time with nobody left to stop it. After that
## nothing, until the emergency shutter has done its work. What it leaves behind stays for
## the rest of the shift.
func _hit() -> void:
	state = State.RESOLVE
	_desk_off()
	_alert_hint = ""
	var token := _seq
	var style := _style()
	var strike := str(style["strike"])
	var pitch := _scream_pitch()
	# where their face ends up: the middle of the window. What flies with them (sparks, drops,
	# glass) is thrown in view space like the patient; what lands on the doctor's own eyes
	# (splashes, cuts, flashes) is placed on the screen.
	var face := Vector2(320, 176)
	var face_v := Gfx.to_view(face)
	var hot: Color = style["hot"]
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
	shift.glass_break()                # no pane for the rest of the night
	clinic.set_glass_left(0, shift.glass_max())
	clinic.bar_clear()
	clinic.sill_blood(true)
	gore.droplets(Gfx.HOLE.get_center(), 36, Vector2(0, -1), PI, 40.0, 170.0, 3)
	_flash_now(Color(1.0, 0.96, 0.9), 0.85, 0.22)
	_shake(9.0, 0.5)
	if rig != null:
		gore.take(rig)
		match strike:
			"slash":
				gore.flare_follow(rig, "tool", 2.5, Color("ffb45a"))
			"burn":
				gore.flare_follow(rig, "tool", 7.0, style["glow"])
			"claw":
				gore.flare_follow(rig, "tool", 1.6, hot)
		rig.pop_target = face_v
		rig.shake(5.0, 2.4)
	await _pop_to(1.0, 0.2, true)

	# one: across the eyes
	_strike(strike, 0, face)
	_shake(10.0, 0.6)
	gore.sparks(face_v + Vector2(-30, 15), 40, Vector2(0.4, -0.8), PI, 60.0, 280.0, hot)
	await _wait(0.07, token)
	_flash_now(Color(0.78, 0.03, 0.05), 0.6, 0.5)
	gore.vignette = 1.0
	gore.droplets(face_v, 70, Vector2(0, -1), PI, 50.0, 290.0, 3)
	# the first blood lands round the edges of the view: their face stays in the middle of it
	gore.splat(Vector2(92, 96), "l", 2.0)
	gore.splat(Vector2(552, 86), "l", 1.6, 0.05)
	gore.splat(Vector2(82, 296), "l", 1.4, 0.1)
	gore.splat(Vector2(566, 288), "a", 2.0, 0.08)
	gore.splat(Vector2(336, 22), "a", 1.6, 0.15)
	gore.splat(Vector2(486, 336), "m", 2.0, 0.18)
	for i in 8:
		var at := Vector2(_fx_rng.randf_range(20.0, 620.0), _fx_rng.randf_range(14.0, 346.0))
		if FACE_CLEAR.has_point(at):
			at.x = _fx_rng.randf_range(20.0, 165.0) if at.x < 320.0 else _fx_rng.randf_range(475.0, 620.0)
		gore.splat(at, "m" if i % 3 == 0 else "s", 2.0 if i % 2 == 0 else 1.0, 0.1 + 0.05 * float(i))
	audio.play("tinnitus", 1.0, -4.0)
	audio.play("heartbeat")
	await _wait(0.42, token)

	# two: again, from closer
	_strike(strike, 1, face)
	audio.play("scream", pitch * 1.2, 1.0)
	_shake(11.0, 0.5)
	gore.sparks(face_v + Vector2(25, -5), 30, Vector2(-0.4, -0.8), PI, 60.0, 280.0, hot)
	gore.droplets(face_v, 60, Vector2(0, -1), PI, 50.0, 290.0, 3)
	gore.splat(Vector2(186, 268), "l", 2.0, 0.05)
	gore.splat(Vector2(464, 104), "l", 2.0, 0.09)
	gore.splat(Vector2(548, 204), "a", 2.0, 0.12)
	gore.splat(Vector2(124, 150), "m", 2.0, 0.16)
	await _pop_to(1.55, 0.38)

	# three: the one nobody is left to see
	audio.play("hit", 0.8, 2.0)
	audio.play("crunch", 0.9, 1.0)
	audio.play("scream", pitch * 0.9, 3.0)
	_strike(strike, 2, face)
	# the flash stays thin enough to read the face filling the view; the blood that covers it lands a beat later
	_flash_now(Color(0.86, 0.02, 0.04), 0.55, 0.3)
	_shake(14.0, 0.5)
	gore.droplets(face_v, 90, Vector2(0, -1), PI, 65.0, 340.0, 3)
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
	_resolve()      # the dark stays: the night is over (_lights_out)


## What reaches the player's eyes, blow by blow (0, 1, 2): an edge across them (the saw, the
## cleaver), a flame, beam or arc in them, ten picks raked over them, or something heavy
## straight into them. `face` is the middle of the view, where the third one lands.
func _strike(kind: String, i: int, face: Vector2) -> void:
	var style := _style()
	var bite := str(style["bite"])
	match kind:
		"burn":
			var glow: Color = style["glow"]
			var at: Vector2 = [Vector2(258, 194), Vector2(392, 166), face][i]
			audio.play(bite, [0.8, 0.7, 0.6][i], [2.0, 1.0, 3.0][i])
			gore.bloom(at, glow, [230.0, 260.0, 330.0][i], [0.55, 0.5, 0.4][i])
			gore.afterimage(at, [70.0, 88.0, 124.0][i])
			if i < 2:
				_flash_now(glow.lerp(Color.WHITE, 0.62 + 0.05 * float(i)), 0.58 + 0.02 * float(i), 0.2)
		"claw":
			# five points of one hand, raked across together, the middle one leading
			var ends: Array = [[Vector2(548, 26), Vector2(132, 330)], [Vector2(82, 54), Vector2(580, 296)], [Vector2(352, 2), Vector2(310, 356)]][i]
			var a: Vector2 = ends[0]
			var b: Vector2 = ends[1]
			var along := (b - a).normalized()
			var across := along.orthogonal()
			audio.play("slash", [1.45, 1.3, 1.1][i], [0.0, 0.0, 2.0][i])
			audio.play("scrape", [1.3, 1.15, 1.0][i], [-2.0, -1.0, 0.0][i])
			for k in 5:
				var off := across * (float(k) - 2.0) * 16.0 - along * absf(float(k) - 2.0) * 12.0
				gore.slash(a + off, b + off, 0.34)
				gore.gash(a + off, b + off, 0.06 + 0.015 * float(k), 0.34)
		"smash":
			var at: Vector2 = [Vector2(250, 186), Vector2(404, 160), face][i]
			audio.play(bite, [1.0, 0.92, 0.82][i], [2.0, 2.0, 3.0][i])
			audio.play("crunch", [1.15, 1.0, 0.9][i], [-2.0, 0.0, 1.0][i])
			gore.impact(at, [130.0, 160.0, 210.0][i], 0.5)
			_flash_now(Color(1.0, 1.0, 1.0), 0.7, 0.12)
			_shake(14.0, 0.35)
		_:
			var ends: Array = [[Vector2(560, 22), Vector2(116, 334)], [Vector2(70, 60), Vector2(590, 300)], [Vector2(346, 4), Vector2(316, 356)]][i]
			var gash_ends: Array = [[Vector2(548, 32), Vector2(128, 324)], [Vector2(84, 68), Vector2(576, 292)], [Vector2(344, 12), Vector2(318, 350)]][i]
			audio.play("slash", [1.0, 0.9, 0.75][i], [0.0, 0.0, 2.0][i])
			if i < 2:
				audio.play(bite, [1.25, 1.1][i], [1.0, 0.0][i])
			gore.slash(ends[0], ends[1])
			gore.gash(gash_ends[0], gash_ends[1], [0.09, 0.09, 0.06][i])


## Brings whoever came through the window closer: at 1 their face fills the screen, past 1
## it keeps coming.
func _pop_to(target: float, time: float, ease_out: bool = false) -> void:
	var from := rig.pop if rig != null else target
	var t := 0.0
	while t < time:
		await night_frame
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
	var style := _style()
	var cut := str(style["cut"])
	var hot: Color = style["hot"]
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
	if shift.glass <= 0 and clinic.glass_state < 4:
		# the pane has taken all it can: it drops out of the frame behind the shutter, and
		# whoever turns next tonight has nothing left to break first
		audio.play("glass_shatter", 0.9, -7.0)
		clinic.set_glass(4)
		shift.glass_break()
		clinic.set_glass_left(0, shift.glass_max())
	await _wait(0.55, token)
	var knock := str(style["knock"])
	var deep := bool(style["deep"])
	for i in 3:
		audio.play(knock, 1.0 - 0.08 * float(i), float(i))
		if knock != "bang":
			audio.play("bang", 0.8 - 0.06 * float(i), float(i) - 6.0)      # and the slats round it
		clinic.shutter_dent(_dent_spot(DENT_SPOTS, i), deep)
		_shake((3.0 + float(i)) * (1.6 if deep else 1.0), 0.2)
		await _wait(0.34 - 0.07 * float(i), token)
	if cut != "":
		if _weapon_loop != "":
			audio.set_loop_volume(_weapon_loop, -7.0)
		var points := cut == "picks" or cut == "spike"      # points, not an edge: slower, and fewer sparks
		var edge := cut == "saw" or cut == "chop"
		var glow: Color = style["glow"]
		clinic.shutter_cut(cut, CUT_AT[cut], 1.1 if points else 0.8)
		if glow.a > 0.0:      # its light shows under the shutter while it works
			clinic.under_color = glow
			clinic.under_glow = 1.0
		var spark_in := 0.0
		var biting := false
		while clinic.cut_active() and token == _seq:
			await night_frame
			spark_in -= get_process_delta_time()
			if clinic.cut_biting() and not biting:      # it bites (a cleaver or a spike, once for each hack or hole)
				audio.play(str(style["bite"]), 1.0, 2.0)
				_shake(4.0 if points else 3.0, 0.12)
			biting = clinic.cut_biting()
			if spark_in <= 0.0 and biting:
				spark_in = 0.03
				gore.sparks(clinic.cut_point(), 2 if points else 4, Vector2(0.2, 1.0) if edge else Vector2(0.0, 1.0), 1.6, 40.0, 220.0, hot)
				_shake(1.0 if points else 2.0, 0.08)
	else:
		await _wait(0.2, token)      # nothing gets through: the third blow is the last
	await _wait(0.45, token)
	_stop_attack_audio()
	clinic.flicker = 0.0
	clinic.under_glow = 0.45 if cut == "torch" else 0.0      # the torch stays lit; a beam or an arc cuts out
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
	_log("shutter", {"outcome": outcome, "reaction_ms": reaction_ms, "blows": visit.blows_taken,
		"grade": visit.shutter_grade(), "glass_left": shift.glass})
	if outcome == "caught":
		# the bar over the printer slot now says how it went: how much of the glass it cost
		if visit.blows_taken <= 0:
			# with no glass lamp left there was nothing for the glass to hold: only the time on the bar
			clinic.bar_stop(STOP_BARE_LINE if shift.glass <= 0 else STOP_CLEAN_LINE, Gfx.GRN4)
		elif shift.glass <= 0:
			clinic.bar_stop(STOP_LAST_LINE, Gfx.RED3)
		elif visit.blows_taken == 1:
			clinic.bar_stop(Lang.tf(STOP_BLOW_LINE, [visit.blows_taken]), Gfx.AMBER)
		else:
			clinic.bar_stop(Lang.tf(STOP_BLOWS_LINE, [visit.blows_taken]), Gfx.AMBER)
	else:
		clinic.bar_clear()
	_desk_off()
	desk.lever_down = true
	_alert_hint = ""
	_base_hint = ""
	dialogue.clear()
	audio.play("lever")
	gore.flare_off()
	clinic.shutter_to(1.0, 0.16)
	while not clinic.shutter_closed():
		await night_frame
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
				dialogue.say(Lang.tf("%s (through the shutter)", [_patient_name()]), str(attack.get("line", "")), Gfx.TEAL5, Gfx.TEAL6, 30.0)
				await _run_line(token, 0.8)
			if visit.attack_cause == "refer":
				# the crew that was already on its way gets there
				audio.play("siren", 1.0, -6.0)
				clinic.strobe = 1.0
				await _narrate("", CREW_AFTER_LINE, token, 0.8)
				clinic.strobe = 0.0
		_:
			# before any attack, steady or drifting: the same quiet on the far side of the metal
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
	_panels_hold = false
	_cam_wanted = false
	_sheet_back = false
	_card_back = false
	_list_back = false
	_surprise = ""
	if visit.is_contact() and visit.dropped:
		# the list keeps a package that came over the counter. A courier who went without theirs
		# leaves no mark: who carried an entry that was not picked up is told only at closing
		clipboard.contact_marks[str(visit.contact.get("id", ""))] = "picked"
	clinic.show_patience = false
	clinic.leaving = -1.0
	clinic.bar_clear()                 # the slip prints out of the slot the bar sat on
	clinic.danger = 0.0
	clinic.hall_dark = 0.0
	clinic.flicker = 0.0
	clinic.results.append(str(s.get("call", "none")))      # the player's own call, not whether it was right
	_alert_hint = ""
	_base_hint = ""
	audio.trim_db = 0.0
	_log("visit_end", {"outcome": str(s.get("outcome", "")), "verdict": str(s.get("verdict", "")),
		"truth": str(s.get("truth", "")), "correct": bool(s.get("correct", false)), "credits": int(s.get("credits", 0)),
		"counter": int(s.get("counter", 0)), "closing": int(s.get("closing", 0)), "call": str(s.get("call", "")),
		"patience_left": int(s.get("patience_left", 0)), "press_count": int(s.get("press_count", 0)),
		"crossed": int(s.get("crossed", 0)), "blows": int(s.get("blows", 0)), "grade": str(s.get("grade", "")),
		"seen": visit.seen.keys(), "model_calls": agent.calls_this_visit, "fallbacks": agent.fallbacks_this_visit,
		"contact": visit.is_contact(), "dropped": visit.dropped,
		"complaints_told":s.complaints_told, "tests_in_order":s.tests_in_order, "complaints_followed":s.complaints_followed,
		"codes_wrong": visit.codes_wrong, "snapped": visit.snapped, "flared": visit.flared})
	agent.end_visit()
	if shift.died:
		_lights_out(s, token)
		return
	_slip_data = s
	_slip_index = shift.index + 1
	_slip_mode = "print"
	_slip_y = SLIP_CLIP.size.y
	_slip_age = 0.0
	audio.play("printer")
	await _wait(0.8, token)
	clinic.till = shift.till()
	# what the counter took in: a fee is a fee, whoever paid it, so the sound says nothing either
	var counter := int(s.get("counter", 0))
	if counter > 0:
		audio.play("cash")
	elif counter < 0:
		audio.play("fail")
	state = State.SLIP
	_slip_age = 0.0


## The shutter came too late and the doctor is dead: the night ends with this visit. There is no
## slip and nobody else comes in; the report comes up out of the dark that _hit left.
func _lights_out(s: Dictionary, token: int) -> void:
	_log("lights_out", {"case": str(s.get("case_id", "")), "hour": shift.records.size(), "unseen": shift.unseen()})
	_slip_data = {}
	_slip_mode = "hidden"
	clinic.under_glow = 0.0
	clinic.team_clear()
	_remove_rig()
	visit = null
	_hang_sheet()
	clipboard.set_visit(null, "")
	desk.badges.clear()
	desk.warn.clear()
	var ok: bool = await _wait(0.6, token)
	if not ok:
		return
	_show_report()
	await _fade_to(0.0, 1.4)


func act_continue() -> void:
	if state != State.SLIP or _slip_age < 0.5:
		return
	audio.play("tear")
	_slip_mode = "drop"
	if coach != null:
		coach.event("continue")
	clinic.under_glow = 0.0
	clinic.team_clear()
	shift.advance()
	_remove_rig()
	visit = null
	_hang_sheet()
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
		_begin_wait(shift.reading())      # the hour is over: the meter reads the till


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
	var unseen := PackedStringArray()
	for id in report.get("unseen", []):
		unseen.append(str((cases.get(str(id), {}) as Dictionary).get("name", id)))
	report["unseen_names"] = unseen
	screens.show_report(report)
	_report_jingled = false
	# the night's reports are in: the till has the bounties and the bills, and the last reading is
	# taken. Nobody reads the meter for a dead doctor: it stays at the hour the night ended in.
	clinic.till = shift.total()
	if not shift.died:
		clinic.line = int(report.get("line", 0))
		clinic.line_under = not bool(report.get("line_held", false))
	if screens.on_summary():
		_report_summary_reached()
	_log("shift_end", {"correct": int(report.get("correct", 0)), "count": int(report.get("count", 0)),
		"died": bool(report.get("died", false)), "unseen": report.get("unseen", []),
		"counter_total": int(report.get("counter_total", 0)), "closing_total": int(report.get("closing_total", 0)),
		"total": int(report.get("total", 0)), "line": int(report.get("line", 0)),
		"line_held": bool(report.get("line_held", false)), "hours_under": int(report.get("hours_under", 0)),
		"injuries": int(report.get("injuries", 0)), "glass_left": int(report.get("glass", 0)),
		"glass_paid": int(report.get("repair_total", 0)), "title": str(report.get("title", "")),
		"drops": int(report.get("drops", 0)), "drop_total": int(report.get("drop_total", 0)),
		"complaints_told":report.complaints_told, "complaints_followed":report.complaints_followed})


## The report, a page at a time: each visit seen tonight, then the night's totals. On the
## totals page the next click starts a new night (act_restart), and ESC goes back to the title
## card (act_report_menu).
func act_report_next() -> void:
	if state != State.REPORT:
		return
	if screens.on_summary():
		act_restart()
		return
	if screens.age() < REPORT_TURN:
		return
	_report_turn(1)


func act_report_back() -> void:
	if state == State.REPORT:
		_report_turn(-1)


## Straight to the night's totals.
func act_report_skip() -> void:
	if state == State.REPORT and not screens.on_summary():
		_report_turn(screens.pages())


func _report_turn(step: int) -> void:
	if not screens.turn(step):
		return
	audio.play("paper", 1.1, -6.0)
	if screens.on_summary():
		_report_summary_reached()


## The totals page: the meter's word on the night, heard once.
func _report_summary_reached() -> void:
	if _report_jingled:
		return
	_report_jingled = true
	var report: Dictionary = screens.report
	var good := bool(report.get("line_held", false)) and not bool(report.get("died", false))
	audio.play("jingle_good" if good else "jingle_bad")


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
			key_down(key.keycode, key.unicode, key.ctrl_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_beat_activity()
	if what == NOTIFICATION_OS_IME_UPDATE and _ime_on:
		dialogue.input_compose(DisplayServer.ime_get_text(), DisplayServer.ime_get_selection().x)
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
	if agent != null:
		agent.end_visit()
	if _mic_state == "listening":
		act_speak_cancel()
	audio.set_muted(true)      # nothing new starts while the game is on its way out
	audio.stop_all()
	get_tree().create_timer(CLOSE_HOLD, true, false, true).timeout.connect(get_tree().quit)


func pointer_move(pos: Vector2) -> void:
	if pos != _mouse:
		_beat_activity()
	_mouse = pos


## A click on the title card or one of its pages. The right button goes back to the menu.
func _title_press(pos: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		act_menu_back()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	var code := screens.language_at(pos)
	if code != "":
		act_language(code)
		return
	match screens.mode:
		"title":
			var item := screens.menu_at(pos)
			if item != "":
				act_menu(item)
		"howto":
			act_howto_turn(1)
		"settings":
			var hit := screens.setting_at(pos)
			if hit == "back":
				act_menu_back()
			elif hit != "":
				var row := hit.get_slice(":", 0)
				var value := hit.get_slice(":", 1)
				screens.settings_row = maxi(screens.SETTING_ROWS.find(row), 0)
				act_setting(row, int(value) if row == "volume" else value)


func pointer_down(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	if _quit_night.visible:
		if button == MOUSE_BUTTON_LEFT:
			_quit_night.click(pos)
		return
	_beat_activity()
	_mouse = pos
	_pointer_press(pos, button)
	_sync_panels(0.0)      # a paper that was asked for is there for the very next click


func _pointer_press(pos: Vector2, button: int) -> void:
	if guide.is_open():
		# the guide is over everything: a click turns its page, the right button closes it
		if button == MOUSE_BUTTON_RIGHT:
			act_guide_close()
		elif button == MOUSE_BUTTON_LEFT:
			act_guide_next()
		return
	if state == State.INTRO:
		if button == MOUSE_BUTTON_RIGHT:
			act_intro_skip()
		elif button == MOUSE_BUTTON_LEFT:
			act_intro_next()
		return
	if state == State.REPORT:
		# the report is over everything: a click turns its page, the right button goes to the totals
		if button == MOUSE_BUTTON_RIGHT:
			act_report_skip()
		elif button == MOUSE_BUTTON_LEFT:
			act_report_next()
		return
	if state == State.TITLE:
		_title_press(pos, button)
		return
	# the training box is in front of the booth: its buttons first, and the rest of it is opaque
	if button == MOUSE_BUTTON_LEFT and coach != null and coach.is_showing():
		match coach.button_at(pos):
			"skip":
				act_training_skip()
				return
			"next":
				act_training_next()
				return
			"box":
				return
	if button == MOUSE_BUTTON_RIGHT:
		# the right button puts things back: what is in hand first, and with empty hands the
		# paper or the screen it was pressed on
		if _held == "" and _mic_state == "" and _panels_live():
			match _panel_at(pos):
				"sheet":
					act_sheet(0)
					return
				"list":
					act_list(0)
					return
				"card":
					act_card(0)
					return
				"cam":
					act_cam(0)
					return
		act_cancel()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	match state:
		State.SLIP:
			if not _wall_click(pos):
				act_continue()
		State.WAIT:
			if _wall_click(pos):
				pass
			elif desk.pad_at(pos) == "glass":
				act_repair_glass()
			else:
				_skip = true
		State.EXAM:
			_exam_click(pos)
		State.ATTACK:
			if desk.pad_at(pos) == "shutter":
				act_shutter()
			else:
				_wall_click(pos)
		_:
			if not _wall_click(pos):
				_skip = true


## A click on the things that work the same way all night: a paper's tab, the hall monitors
## and what hangs on the walls. Returns true if the click was used. A paper that is out covers
## what is behind it: a click on one is never passed on to the wall or the window, and the
## caller decides what it means.
func _wall_click(pos: Vector2) -> bool:
	if not _panels_live():
		return false
	match clipboard.tab_at(pos):
		"sheet":
			act_sheet(0)
			return true
		"list":
			act_list(0)
			return true
		"swap":
			if clipboard.list_open:
				act_sheet(1)
			else:
				act_list(1)
			return true
		"card":
			act_card(0)
			return true
	match _panel_at(pos):
		"cam":
			act_cam()
			return true
		"sheet", "list", "card":
			return false
	var exam_or_wait := state == State.WAIT or state == State.EXAM
	if exam_or_wait and _over_thumb(pos):
		act_cam()
		return true
	match desk.object_at(pos):
		"sheet":
			act_sheet(1)
			return true
		"list":
			act_list(1)
			return true
		"card":
			act_card(1)
			return true
		"guide":
			if exam_or_wait:
				act_guide()
				return true
	return false


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
func key_down(keycode: int, unicode: int = 0, control: bool = false) -> void:
	_beat_activity()
	_key_press(keycode, unicode, control)
	_sync_panels(0.0)


func _key_press(keycode: int, unicode: int, control: bool) -> void:
	if _quit_night.visible:
		_quit_night.key(keycode)
		return
	if keycode == KEY_F10 and state not in [State.TITLE, State.REPORT]:
		_offer_quit_night()
		return
	if _break_confirmation and dialogue.has_menu() and keycode in [KEY_ENTER, KEY_KP_ENTER]:
		act_press(true)
		return
	if keycode == KEY_F11:
		act_fullscreen(not fullscreen)
		return
	if guide.is_open():
		# the guide is over everything: LEFT goes back a page, ESC or H closes, any other key turns the page
		match keycode:
			KEY_ESCAPE, KEY_H, KEY_F1:
				act_guide_close()
			KEY_LEFT:
				act_guide_back()
			KEY_M:
				audio.set_muted(not audio.muted)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT:
				act_guide_next()
		return
	if state == State.INTRO:
		match keycode:
			KEY_ESCAPE:
				act_intro_skip()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT:
				act_intro_next()
			KEY_M:
				audio.set_muted(not audio.muted)
		return
	if state == State.REPORT:
		match keycode:
			KEY_ESCAPE:
				# from a visit's page to the night's totals; from the totals to the title menu
				if screens.on_summary():
					act_report_menu()
				else:
					act_report_skip()
			KEY_LEFT, KEY_BACKSPACE:
				act_report_back()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT:
				act_report_next()
			KEY_M:
				audio.set_muted(not audio.muted)
		return
	if state == State.TITLE:
		_title_key(keycode)
		return
	if keycode == SPEAK_KEY:
		act_speak_start("key")
		return
	if _mic_state != "":
		if keycode == KEY_ESCAPE:
			act_speak_cancel()
		return      # the microphone has the line: every other key waits for it
	if dialogue.input_open:
		if keycode == KEY_F1:
			act_guide()                 # H is a letter while the doctor is typing; F1 is not
		else:
			_say_key(keycode, unicode, control)      # SPACE and M are letters while the doctor is typing
		return
	match keycode:
		KEY_SPACE:
			act_shutter()
		KEY_ESCAPE:
			act_cancel()
		KEY_H, KEY_F1:
			act_guide()
		KEY_R:
			act_sheet()
		KEY_L:
			act_list()
		KEY_N:
			act_card()
		KEY_K:
			act_training_skip()
		KEY_C:
			act_cam()
		KEY_G:
			act_repair_glass()
		KEY_T:
			if state == State.EXAM:
				act_say_open()
		KEY_ENTER, KEY_KP_ENTER:
			match state:
				State.WAIT:
					if clinic.cam_prompt:
						act_call_next()
					else:
						_skip = true
				State.SLIP:
					act_continue()
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


## The title card's keys: UP and DOWN choose, ENTER takes it, ESC goes back to the menu. On
## HOW TO PLAY, LEFT and RIGHT turn the pages; on SETTINGS they change the lit row. H opens HOW
## TO PLAY. SPACE does nothing here: it is the shutter's key, and the warning says so.
func _title_key(keycode: int) -> void:
	match keycode:
		KEY_M:
			act_mute()
		KEY_UP, KEY_W:
			act_menu_move(-1)
		KEY_DOWN, KEY_S:
			act_menu_move(1)
		KEY_LEFT, KEY_A:
			if screens.mode == "howto":
				act_howto_turn(-1)
			elif screens.mode == "settings":
				act_setting_step(-1)
		KEY_RIGHT, KEY_D:
			if screens.mode == "howto":
				act_howto_turn(1)
			elif screens.mode == "settings":
				act_setting_step(1)
		KEY_ENTER, KEY_KP_ENTER:
			match screens.mode:
				"title":
					act_menu(screens.menu_item())
				"howto":
					act_howto_turn(1)
				"settings":
					act_setting_enter()
		KEY_ESCAPE, KEY_BACKSPACE:
			act_menu_back()
		KEY_H, KEY_F1:
			if screens.mode == "title":
				act_menu("howto")
			elif screens.mode == "howto":
				act_menu_back()


## Right-click or ESC: put away whatever is in hand. With empty hands, what is out in front of
## the window goes back to its wall: the big screen first, then the card, then the list or the sheet.
func act_cancel() -> void:
	if state == State.EXAM and _cancel_exam():
		return
	if not _panels_live():
		return
	if clinic.cam_open:
		act_cam(0)
	elif clipboard.card_open and not _card_forced():
		act_card(0)
	elif clipboard.list_open:
		act_list(0)
	elif clipboard.sheet_open:
		act_sheet(0)


## Puts away the one thing the doctor is in the middle of. Returns false if there was nothing.
func _cancel_exam() -> bool:
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
	else:
		return false
	return true


func _exam_click(pos: Vector2) -> void:
	# what is in front of the window comes first: a paper's tab, the hall monitors, the walls
	if _wall_click(pos):
		return
	match _panel_at(pos):
		"card":
			if _held != "":
				act_stamp_record()
			else:
				var box := clipboard.mark_at(pos)
				if box != "":
					act_mark(box)
			return      # the rest of the card is paper
		"list":
			var said := clipboard.say_at(pos)
			if said != "":
				act_say_code(said)
			return      # the rest of the list is paper
		"sheet":
			return
	# the open close-up owns the window
	if clinic.scope.is_open() and Gfx.WINDOW.has_point(pos):
		var mark := clinic.scope.mark_at(pos)
		if mark > 0:
			var row: String = VisitState.TOOL_ROW.get(clinic.scope.tool, "temper")
			act_mark(row, mark)
			clinic.scope.selected_mark = mark
			return
		clinic.scope.pointer_screen(pos)
		clinic.scope.button(true)
		return
	var chip := dialogue.chip_at(pos)
	if chip != "":
		_click_chip(chip)
		return
	if dialogue.has_menu():
		var i := dialogue.menu_index_at(pos)
		if i >= 0:
			if _break_confirmation:
				if dialogue.menu_id(i) == "break":
					act_press(true)
				else:
					act_cancel()
			else:
				act_ask(dialogue.menu_id(i))
			return
	var pad := desk.pad_at(pos)
	if pad != "":
		if desk.is_enabled(pad):
			_click_pad(pad)
		return
	if _held != "":
		return      # a stamp only means something on the card
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
		"complain":
			act_complain()
		"press":
			act_press()
		"treat":
			act_pick_stamp(pad)
		"refer":
			act_call_team()
		"shutter":
			act_shutter()
		"glass":
			act_repair_glass()


# ================================================================ every frame

func _forward_night_frame() -> void:
	if is_inside_tree() and not get_tree().paused:
		night_frame.emit()


func _offer_quit_night() -> void:
	if state in [State.TITLE, State.REPORT] or _closing:
		return
	_beat_activity()
	if _mic_state == "listening":
		act_speak_cancel()
	_quit_night.show()
	get_tree().paused = true


func _answer_quit_night(discard: bool) -> void:
	if not _quit_night.visible:
		return
	_quit_night.hide()
	get_tree().paused = false
	if discard:
		var was_intro := state == State.INTRO
		_bump()
		state = State.TITLE
		if was_intro:
			intro.skip_all()
		_mic_drop("menu")
		_beat_pending = false
		_beat_opening_done = false
		_break_confirmation = false
		_thinking = false
		_lock = false
		if guide.is_open():
			guide.close()
		if coach.is_running():
			coach.stop(false)
		_close_scope(false)
		_drop_stamp(false)
		_disarm()
		_close_say()
		dialogue.clear()
		_remove_rig()
		_slip_data = {}
		_slip_mode = "hidden"
		_slip.hide()
		clinic.team_clear()
		clinic.under_glow = 0.0
		_log("night_abandoned", {"shift":shift_number})
		_reset_booth()
		clinic.line = 0
		clinic.set_glass_left(clinic.glass_max, clinic.glass_max)
		_show_title()
	night_resumed.emit()


func _beat_activity() -> void:
	_beat_clock = 0.0
	_beat_revision += 1


func _beat_quiet() -> bool:
	return not _quit_night.visible and beats_enabled and (_service_has_beats or agent.mode == "script") and state == State.EXAM and visit != null and visit.in_exam() and not visit.is_spent() and not _lock and not _thinking and _mic_state == "" and not dialogue.input_open and not dialogue.has_menu() and not dialogue.typing and not guide.is_open() and not _closing


func _has_idle_complaint() -> bool:
	return visit != null and agent != null and agent.idle_beats_this_visit < int(rules.agent.beats.max_idle_per_visit) and agent.beats_this_visit < int(rules.agent.beats.max_per_visit) and visit.complaints_told.size() < visit.case_data.get("complaint_rows", []).size()


func _try_beat(kind: String, tool: String = "") -> void:
	if not _beat_quiet() or _beat_pending or agent == null or not agent.can_beat(kind):
		return
	var revision := _beat_revision
	var token := _seq
	var current := visit
	var speaker := agent
	_beat_pending = true
	_beat_clock = 0.0
	var result: Dictionary = await speaker.beat(kind, tool, current.snapshot(), current.open_signs())
	if speaker != agent or current != visit:
		return
	_beat_pending = false
	if revision != _beat_revision or token != _seq or not _beat_quiet() or result.is_empty():
		return
	# The optional line can be interrupted by any action; it never takes the action lock.
	_log("patient_beat", {"stage": kind, "chars": str(result.reply).length()})
	_patient_line(str(result.reply), token, 0.0)


func _process(delta: float) -> void:
	if _beat_opening_done and not _beat_pending and _beat_quiet() and not clinic.scope.is_open() and (agent.can_beat("idle") or _has_idle_complaint()):
		_beat_clock += delta
		if _beat_clock >= float(rules.agent.beats.idle_seconds):
			if _has_idle_complaint():
				agent.idle_beats_this_visit += 1
				agent.beats_this_visit += 1
				_beat_clock = 0.0
				act_complain("", "", true)
			else:
				_try_beat("idle")
	_t += delta
	_sync_ime()
	if rig != null:
		rig.talking = _patient_talking and dialogue.is_revealing()
		# while the answer is being written the patient is seen thinking it over, each in their
		# own way; while the microphone is open they are listening to the doctor
		rig.thinking = _thinking and _think_t > THINK_POSE_AFTER and state == State.EXAM
		rig.listening = _mic_state == "listening" and state == State.EXAM
	if guide.is_open() and not (state == State.WAIT or state == State.EXAM):
		guide.close()
	_update_leaving(delta)
	_update_surprise(delta)
	if _coach_next != "" and ((_base_hint == "" and not _leave_said) or _coach_id == "break"):
		# a one-time tip, once nothing more urgent is on the hint row. The one about the glass is
		# for the moments after an attack, while the stop is still being read off the bar; the
		# others belong to the exam they came up in.
		var after_attack := _coach_id == "glass" and (state == State.RESOLVE or state == State.SLIP)
		if state == State.EXAM or after_attack:
			_base_hint = _coach_next
			_coached[_coach_id] = true
			_coach_next = ""
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
		var label := "MOCK TRANSPORT" if _service_is_mock else "AI DIALOGUE"
		if str(agent.last.get("source", "")) == "fallback":
			label = "OFFLINE FALLBACK"
		elif bool(agent.last.get("meta", {}).get("mock", false)):
			label = "MOCK TRANSPORT"
		clinic.corner_text = Lang.tf("%s  %d/%d calls", [Lang.t(label), agent.calls_this_visit, agent.max_calls])
	_sync_panels(delta)
	_sync_coach()
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
	clinic.thumb_hot = false
	clinic.clear_zone()
	clipboard.hover_mark = ""
	clipboard.highlight_row = ""
	clipboard.tab_hover = ""
	dialogue.menu_hover = -1
	dialogue.chip_hover = ""
	clipboard.say_hover = ""
	screens.hover_language = screens.language_at(pos)      # "" off the title card
	if screens.hover_language != "":
		_cursor_kind = "hand"
		return
	if state == State.TITLE:
		screens.hover_menu_item(screens.menu_at(pos))
		screens.hover_setting_item(screens.setting_at(pos))
		if screens.hover_menu != "" or screens.hover_setting != "":
			_cursor_kind = "hand"
		return
	if _coach_hover(pos):
		return
	if _wall_hover(pos):
		return
	match state:
		State.WAIT:
			if desk.pad_at(pos) == "glass":
				if desk.is_enabled("glass"):
					desk.hover = "glass"
					_cursor_kind = "hand"
				_hover_hint = _glass_hint()
		State.EXAM:
			_hover_exam(pos)
		State.ATTACK:
			if desk.pad_at(pos) == "shutter":
				desk.hover = "shutter"
				_cursor_kind = "hand"


## The pointer over one of the things _wall_click() takes: it lights up and says what it is.
## Returns true if the pointer is on one of them.
func _wall_hover(pos: Vector2) -> bool:
	if not _panels_live():
		return false
	var tab := clipboard.tab_at(pos)
	if tab != "":
		clipboard.tab_hover = tab
		_cursor_kind = "hand"
		if tab == "swap":
			_hover_hint = SWAP_SHEET_HINT if clipboard.list_open else SWAP_LIST_HINT
		else:
			_hover_hint = str(TAB_HINT[tab])
		return true
	var buzz := state == State.WAIT and clinic.cam_prompt
	match _panel_at(pos):
		"cam":
			clinic.monitor_hot = true
			_cursor_kind = "hand"
			_hover_hint = CAM_HINT if buzz else CAM_OFF_HINT
			return true
		"sheet", "list", "card":
			return false
	var exam_or_wait := state == State.WAIT or state == State.EXAM
	if exam_or_wait and _over_thumb(pos):
		clinic.thumb_hot = true
		_cursor_kind = "hand"
		if buzz:
			_hover_hint = CAM_HINT if _cam_wanted else WAIT_HINT
		else:
			_hover_hint = CAM_OFF_HINT if _cam_wanted else CAM_PEEK_HINT
		return true
	var obj := desk.object_at(pos)
	if obj == "" or (obj == "guide" and not exam_or_wait):
		return false
	desk.hover = obj
	_cursor_kind = "hand"
	_hover_hint = str(OBJECT_HINT[obj])
	return true


func _hover_exam(pos: Vector2) -> void:
	if visit == null:
		return
	var paper := _panel_at(pos)      # a paper that is out is in front of the window
	if clinic.scope.is_open():
		clipboard.highlight_row = str(VisitState.TOOL_ROW.get(clinic.scope.tool, ""))
		if paper == "" and Gfx.WINDOW.has_point(pos):
			clinic.scope.pointer_screen(pos)
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
	if paper == "list":
		var entry := clipboard.say_at(pos)
		if entry != "":
			clipboard.say_hover = entry
			if _can_act():
				_cursor_kind = "hand"
			_hover_hint = Lang.tf(SAY_CODE_HINT, [visit.code_cost()])
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
	if paper != "":
		return      # the patient behind the paper is not under the pointer
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
	elif _leave_said and state == State.EXAM and visit != null and not mid_action:
		# a patient who is on the way out outranks what the pointer is resting on
		dialogue.set_hint(Lang.tf("No lamps. Leaving in %d s of idle time.", [ceili(maxf(0.0, _leave_t))]), Gfx.RED3)
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
	# the result slip feeds up out of the printer in little steps, and is pulled away when torn off
	match _slip_mode:
		"print":
			_slip_y = maxf(SLIP_REST, _slip_y - delta * 230.0)
			if _slip_y <= SLIP_REST:
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
	var who := str(s.get("name", ""))
	Gfx.text(_slip, Vector2(x0, 17), Lang.tf("INTAKE SLIP %d/%d", [_slip_index, shift.count() if shift != null else 0]), Gfx.PRINT)
	Gfx.text_right(_slip, x1, 17, who, Gfx.PRINT)
	# what happened at the counter, in words that hold whoever the patient was (rules.json "counter")
	var title := str(s.get("counter_title", ""))
	if Gfx.big_w(title) <= w:
		Gfx.big_center(_slip, mid, 27, title, Gfx.INKT)
	else:
		Gfx.text_center(_slip, mid, 33, title, Gfx.INKT, true)
	var y := 50.0
	var lines := Gfx.wrap_raw(Lang.fill(str(s.get("counter_text", "")), {"name": who}), w)
	for i in mini(lines.size(), SLIP_LINES):
		Gfx.text_raw(_slip, Vector2(x0, y), lines[i], Gfx.INKT)
		y += Gfx.LINE
	_slip.draw_rect(Rect2(x0, 102, w, 1), Gfx.PAPER1)
	# what the counter took in, all of it: the fee (for work done, or paid on account by Trauma
	# Team, whoever the patient was), a courier's package, less the calm-patches. It is the figure
	# the till moves by and the one the report calls "At the counter" for this visit. The line
	# below says what it is made of; the rest of the visit's money waits for closing.
	var paid := Lang.tf("%s credits", [Gfx.money(int(s.get("counter", 0)))])
	_fit(_slip, x0, SLIP_COUNTER_Y, SLIP_COUNTER, w - Gfx.text_w(paid, true) - SLIP_GAP, Gfx.INKT)
	Gfx.text_right(_slip, x1, SLIP_COUNTER_Y, paid, Gfx.INKT, true)
	var extra := _slip_breakdown(s)
	if extra != "":
		Gfx.text_center_raw(_slip, mid, SLIP_PARTS_Y, extra, Gfx.PRINT)      # _slip_breakdown translated it
	Gfx.text_center(_slip, mid, SLIP_LATER_Y, SLIP_LATER, Gfx.INKS)
	if state == State.SLIP and _slip_age > 0.5 and fmod(_t, 1.0) < 0.65:
		Gfx.text_center(_slip, mid, SLIP_PROMPT_Y, "click to continue", Gfx.PRINT)


# ================================================================ the couriers and the till

## What the meter shows now: the till, and while a visit is still open what its package and
## its calm-patches have done to it (they are on the record once the visit is).
func _till_now() -> int:
	if shift == null:
		return 0
	if visit != null and shift.records.size() <= shift.index:
		return shift.till() + visit.till_change()
	# the counter's money through the night; everything once the night's reports are in
	return shift.total() if shift.is_done() else shift.till()


## How long a steady hand of the patient's model may take to let go of the grip bar (the hands
## model's limit_ms in parts.json; the baseline's when nobody is at the counter).
func _grip_limit_s() -> float:
	return float(visit_sheet.get("limit_s", 1.0))


## Puts up the sheet for whoever is at the counter: the spec binder's pages for the models they
## wear, or the baseline body between patients.
func _hang_sheet() -> void:
	visit_sheet = CaseDB.sheet_for(visit.case_data if visit != null else {}, sheet, parts)
	if clipboard != null:
		clipboard.sheet = visit_sheet


func _shift_line() -> String:
	if shift.contacts.is_empty():
		return Lang.tf(SHIFT_LINE, [shift.count(), shift.line_per_hour()])
	return Lang.tf(SHIFT_LIST_LINE, [shift.count(), shift.contacts.size(), shift.line_per_hour()])


## Tonight's list entry with this id, or {}.
func _list_entry(id: String) -> Dictionary:
	if shift == null:
		return {}
	for e in shift.contacts:
		var entry: Dictionary = e
		if str(entry.get("id", "")) == id:
			return entry
	return {}


## What the sheet on the wall calls steady on one row, for this patient's model.
func _sheet_normal(row: String) -> String:
	for r in visit_sheet.get("rows", []):
		var line: Dictionary = r
		if str(line.get("id", "")) == row:
			return str(line.get("normal", ""))
	return ""


## The slip's line under the counter figure: what that figure is made of, when it is more than
## the fee alone: the fee (if one was paid), a courier's package and what the calm-patches
## cost. Empty when there was neither a package nor a patch: the figure is the fee then. A
## courier who went without their package is not named: who carried an entry of the list is
## told at closing. In the player's language already.
func _slip_breakdown(s: Dictionary) -> String:
	var dropped := bool(s.get("dropped", false))
	var calm := int(s.get("calm_spent", 0))
	if not dropped and calm <= 0:
		return ""
	var parts := PackedStringArray()
	var fee := int(s.get("counter_fee", 0))
	if fee > 0:
		parts.append(Lang.tf(SLIP_FEE, [fee]))
	if dropped:
		parts.append(Lang.tf(SLIP_DROP, [int(s.get("drop", 0))]))
	if calm > 0:
		parts.append(Lang.tf(SLIP_CALM, [calm]))
	return "  •  ".join(parts)


## Takes tonight's contact list down from the wall, or hangs it back. It hangs on the sheet's
## hook: taking one down puts the other back. `on`: 1 down, 0 back, -1 the other way.
func act_list(on: int = -1) -> void:
	if not _panels_live():
		return
	var want := (not _list_wanted) if on < 0 else on > 0
	if want == _list_wanted:
		return
	_list_wanted = want
	_list_back = false
	if want:
		_list_seen = true
		_sheet_wanted = false
		_sheet_back = false
		if coach != null:
			coach.event("courier_list" if shift.index == 1 and state == State.EXAM else "list_open")
	audio.play("paper", 1.05 if want else 0.9, -5.0)
	_log("panel", {"panel": "list", "open": want})


## The doctor says one of tonight's codes to the visitor at the counter. The courier it belongs
## to answers it and hands a package over: credits in the till, whatever the call turns out to
## be. Anybody else gives a blank look, which costs patience and says nothing about how they
## are. The exam goes on either way.
func act_say_code(id: String) -> void:
	if not _can_act() or visit == null:
		return
	var entry := _list_entry(id)
	if entry.is_empty() or not clipboard.can_say(id):
		return
	var token := _begin_action()
	var res: Dictionary = visit.say_code(entry)
	var result := str(res.get("result", ""))
	_log("code", {"entry": id, "result": result, "cost": int(res.get("cost", 0)), "patience": visit.patience})
	var ok := true
	match result:
		"short":
			_spent(token)
		"blank":
			_sync_visit()
			if coach != null:
				coach.event("courier_code" if shift.index == 1 else "code_said")
			_base_hint = Lang.tf(CODE_BLANK_HINT, [int(res.get("cost", 0))])
			_lock = true
			ok = await _doctor_line(str(entry.get("say", "")), token, 0.3)
			if not ok:
				return
			_lock = false
			audio.play("beep_low", 1.1, -8.0)
			_patient_line(str(res.get("line", "")), token, 0.0, false)
		"drop":
			if coach != null:
				coach.event("courier_code" if shift.index == 1 else "code_said")
			_lock = true
			ok = await _doctor_line(str(entry.get("say", "")), token, 0.3)
			if not ok:
				return
			ok = await _patient_line(str(res.get("line", "")), token, 0.6, false)
			if not ok:
				return
			_lock = false
			_sync_visit()
			audio.play("cash")
			if coach == null or not coach.is_running():
				_coach("drop", DROP_COACH_HINT)
			_roll_surprise(0)
			_narrate("PACKAGE", Lang.tf(DROP_LINE, [Lang.t(str(res.get("package", ""))), int(res.get("pay", 0))]), token, 0.0)
		"tried", "done":
			audio.play("beep_low", 1.2, -10.0)


# ================================================================ the first-night training

func _coach_phase() -> String:
	var prefix := "next_" if shift != null and shift.index >= 1 else ""
	match state:
		State.WAIT:
			return prefix + "wait"
		State.EXAM:
			return prefix + "exam" if visit != null and visit.in_exam() else ""
		State.SLIP:
			return prefix + "slip"
	return ""


## Once a frame while the training runs: which part of the night it is, what the current tip
## points at, and what is open in front of the window that the box must keep clear of.
func _sync_coach() -> void:
	if coach == null or not coach.is_running():
		return
	coach.set_phase(_coach_phase())
	coach.paused = guide.is_open() or (clinic.scope.is_open() and coach.current() not in ["mark", "second"])
	coach.focus = _coach_focus(coach.area())
	var avoid: Array = []
	if clipboard.sheet_open or clipboard.list_open:
		avoid.append(COACH_LEFT_PAPER)
	if clipboard.card_open:
		avoid.append(COACH_RIGHT_PAPER)
	# between patients the hall camera is what the player has to press, on or off: the box
	# stays clear of where it opens, so that it is never under the second click
	if clinic.cam_open or state == State.WAIT:
		avoid.append(Gfx.CAM)
	if _slip.visible:
		avoid.append(SLIP_CLIP)
	var soft: Array = []
	if state == State.EXAM and rig != null and rig.at_counter():
		avoid.append(Gfx.rect_to_screen(rig.zone_rect("eyes")).grow(6.0))
		soft.append(Gfx.rect_to_screen(rig.zone_rect("port")).grow(6.0))
	coach.avoid = avoid
	coach.soft = soft


## The screen rect a tip's "area" names, as things stand: a paper that is down is pointed at
## where it is, one that is up at its place on the wall, one under the other at the swap tab.
func _coach_focus(area: String) -> Rect2:
	match area:
		"lead":
			if visit != null and not visit.complaints_told.is_empty():
				return desk.pad_rect(str(CaseDB.ROW_TOOL.get(visit.complaints_told[0], "press")))
			return desk.pad_rect("complain")
		"list":
			if clipboard.list_open:
				return Gfx.SHEET
			if clipboard.sheet_open:
				return clipboard.swap_tab()
			return desk.object_rect("list")
		"sheet":
			if clipboard.sheet_open:
				return Gfx.SHEET
			if clipboard.list_open:
				return clipboard.swap_tab()
			return desk.object_rect("sheet")
		"card":
			return Gfx.RECORD if clipboard.card_open else desk.object_rect("card")
		"marks":
			if clinic.scope.is_open():
				return clinic.scope.mark_rect(1).merge(clinic.scope.mark_rect(2))
			return COACH_MARKS if clipboard.card_open else desk.object_rect("card")
		"guide":
			return desk.object_rect("guide")
		"cam":
			return Gfx.CAM if clinic.cam_open else Gfx.THUMB
		"code":
			if clipboard.list_open:
				return COACH_SAY
			if clipboard.sheet_open:
				return clipboard.swap_tab()
			return desk.object_rect("list")
		"tools":
			return COACH_TOOLS
		"talk":
			return COACH_TALK
		"decide":
			return COACH_DECIDE
		"patience":
			return COACH_PATIENCE
		"slip":
			return SLIP_CLIP if _slip.visible else Rect2()
		"meter":
			return Gfx.METER
		"shutter":
			return desk.pad_rect("shutter")
	if area.begins_with("pad:"):
		return desk.pad_rect(area.substr(4))
	return Rect2()


## The pointer over the training box: its two buttons light up and say what they do; the rest
## of the box is in front of whatever is behind it. Returns true if the pointer is on the box.
func _coach_hover(pos: Vector2) -> bool:
	if coach == null:
		return false
	if not coach.is_showing():
		coach.hover = ""
		return false
	var b := coach.button_at(pos)
	coach.hover = b if b == "skip" or b == "next" else ""
	match b:
		"skip":
			_cursor_kind = "hand"
			_hover_hint = TRAINING_SKIP_HINT
			return true
		"next":
			_cursor_kind = "hand"
			_hover_hint = TRAINING_NEXT_HINT
			return true
		"box":
			return true
	return false


func act_training_next() -> void:
	if coach == null or not coach.is_showing():
		return
	coach.next()
	audio.play("click", 1.1, -8.0)


func act_training_skip() -> void:
	if coach == null or not coach.is_running():
		return
	coach.stop(true)
	audio.play("click", 0.9, -8.0)


func _on_training_finished(was_skipped: bool) -> void:
	_log("training_end", {"skipped": was_skipped, "reached": coach.reached, "tips": coach.count()})


# ================================================================ snaps and flares

## One action of the doctor's has run its course: roll whether the patient snaps (drifting
## only) or flares (anyone, once a visit). What comes up happens a moment later, inside
## whatever the doctor is doing by then.
func _roll_surprise(cost: int = 1) -> void:
	if visit == null or state != State.EXAM or not visit.in_exam():
		return
	var kind := visit.roll_action(_snap_rng, cost)
	if kind == "" or kind == _surprise or (kind == "flare" and _surprise == "snap"):
		return
	_surprise = kind
	var r: Dictionary = rules.get(kind, {})
	_surprise_t = _snap_rng.randf_range(float(r.get("delay_min_ms", 600)), float(r.get("delay_max_ms", 1400))) / 1000.0
	_log("surprise_due", {"kind": kind, "actions": visit.actions, "delay_ms": int(_surprise_t * 1000.0)})


## A snap or a flare that has come up waits for its moment. A close-up is no shelter, but it
## does not cut into a reply on its way, a line still being typed, the typing line, the
## microphone or the guide.
func _update_surprise(delta: float) -> void:
	if _surprise == "":
		return
	if state != State.EXAM or visit == null or not visit.in_exam():
		_surprise = ""
		return
	if _thinking or _lock or guide.is_open() or dialogue.input_open or _mic_state != "" or dialogue.typing:
		return
	_surprise_t -= delta
	if _surprise_t > 0.0:
		return
	var kind := _surprise
	_surprise = ""
	if kind == "snap":
		_snap_now()
	else:
		_flare_now()


## The patient comes at the glass: a close-up that is open is knocked out of the doctor's hands.
func _tear_scope() -> void:
	if not clinic.scope.is_open():
		return
	clinic.scope.tear()      # it closes itself once it has fallen away
	_papers_return()
	desk.active = ""
	audio.stop_loop("scope_hum")
	_base_hint = ""


## A drifting patient turns in the middle of the exam: up against the glass in a blink, and
## then the same attack as any other (the red bar, the shutter, the glass). Caught, it counts
## as a right call; missed, it is no call at all.
func _snap_now() -> void:
	_tear_scope()
	var token := _begin_action()
	_thinking = false
	_lock = false
	dialogue.thinking = false
	if not visit.snap():
		return
	_first_visit_done = true
	_panels_hold = true      # the papers are out of the way at once: all of the window is theirs
	_log("snap", {"actions": visit.actions})
	if rig != null:
		rig.surge(0.6)
	audio.play("bang", 0.8, 0.0)
	_shake(5.0, 0.3)
	_flash_now(Color(1.0, 0.22, 0.18), 0.3, 0.2)
	_attack_sequence("", token, float((rules.get("snap", {}) as Dictionary).get("lead_ms", 350)) / 1000.0)


## Anybody may lose their temper once a visit: a shout and a hand slammed on the glass. It is
## never an attack (no red bar, nothing to stop). It goes on the TEMPER line, and what it
## shows agrees with the case.
func _flare_now() -> void:
	_tear_scope()
	var token := _begin_action()
	_thinking = false
	_lock = false
	dialogue.thinking = false
	var before := _note_keys()
	var res: Dictionary = visit.flare()
	if not bool(res.get("ok", false)):
		return
	_sync_visit()
	_log("flare", {"actions": visit.actions, "new_note": bool(res.get("new", false))})
	if rig != null:
		rig.surge(0.15)
		rig.react(str(res.get("face", "")), str(res.get("hands", "")))
	audio.play("sting")
	_shake(2.5, 0.2)
	_mark_new_notes(before)
	_coach("flare", FLARE_COACH_HINT)
	_patient_line(str(res.get("line", "")), token, 0.0)
