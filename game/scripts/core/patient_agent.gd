extends RefCounted
## Autonomous character dialogue with an explicitly labelled offline comparison/fallback.
## The visit owns settled outcomes. ASK can use its authored answer in either mode.

const ScriptedBrain = preload("res://scripts/core/scripted_brain.gd")
const ResponseValidator = preload("res://scripts/core/move_validator.gd")
const Lang = preload("res://scripts/core/lang.gd")
const GAME_VERSION := "0.4.0"
const MAX_HISTORY := 48          # turns kept for the model: a whole visit at the call cap
const PROTOCOL := "4"

var rules: Dictionary = {}
var client: Variant = null
var mode: String = "script"
var session_id: String = ""
var visit_id: String = ""
var case_data: Dictionary = {}
var scripted: ScriptedBrain
var max_calls: int = 16
var max_line_chars: int = 110    # what the patient model is asked to keep a reply within
var max_reply_chars: int = 220   # what the strip can show (two pages); only longer is a failed reply
var languages: Dictionary = {}   # rules.json agent.languages: other numbers in another language
var calls_this_visit: int = 0
var fallbacks_this_visit: int = 0
var max_voice_clips: int = 24    # push-to-talk clips sent for their words, per visit
var intents_this_visit: int = 0
var beats_this_visit := 0
var idle_beats_this_visit := 0
var max_intents: int = 16
var voice_clips_this_visit: int = 0
var last: Dictionary = {}
var conversation_history: Array = []
var _generation: int = 0


func _init(p_rules: Dictionary = {}, p_client: Variant = null, p_seed: int = 0) -> void:
	rules = p_rules
	client = p_client
	var limits: Dictionary = rules.get("agent", {})
	max_intents = int(limits.get("intent", {}).get("max_calls_per_visit", 16))
	max_calls = int(limits.get("max_model_calls_per_visit", 16))
	max_line_chars = int(limits.get("max_line_chars", 110))
	max_reply_chars = maxi(max_line_chars, int(limits.get("max_reply_chars", 220)))
	var own: Variant = limits.get("languages", {})
	languages = own if typeof(own) == TYPE_DICTIONARY else {}
	var voice: Dictionary = limits.get("voice", {})
	max_voice_clips = int(voice.get("max_clips_per_visit", 24))
	scripted = ScriptedBrain.new(p_seed)


## The two lengths in the player's language. A hanzi takes the room of two letters on the strip,
## so Chinese has smaller numbers of its own (rules.json agent.languages, and the same numbers in
## agent_proxy DEFAULT_LIMITS.languages).
func line_chars() -> int:
	return int(_own_limits().get("max_line_chars", max_line_chars))


func reply_chars() -> int:
	return maxi(line_chars(), int(_own_limits().get("max_reply_chars", max_reply_chars)))


func _own_limits() -> Dictionary:
	var v: Variant = languages.get(Lang.code, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


func set_mode(p_mode: String) -> void:
	mode = "model" if p_mode == "model" and client != null else "script"


func begin_visit(p_case: Dictionary, p_visit_id: String, p_seed: int) -> void:
	_generation += 1
	case_data = p_case
	visit_id = p_visit_id
	calls_this_visit = 0
	fallbacks_this_visit = 0
	voice_clips_this_visit = 0
	intents_this_visit = 0
	beats_this_visit = 0
	idle_beats_this_visit = 0
	last = {}
	conversation_history = []
	# the history is what the doctor saw: the authored lines in the player's language
	for line in case_data.get("opening", []):
		conversation_history.append({"role": "patient", "text": Lang.t(str(line))})
	scripted.reseed(p_seed)


## fallback_options are ONLY for the offline script; never sent to or checked against AI.
func decide(event: Dictionary, state: Dictionary, fallback_options: Array = [], signs: Dictionary = {}, fallback: String = "") -> Dictionary:
	var base := {"event": event.duplicate(), "move": "", "line": "", "reply": "", "reaction": "",
		"source": "script", "fallback_reason": "", "latency_ms": 0, "meta": {}}
	if fallback != "" and mode == "model":
		base.fallback_reason = fallback
		return _with_script(base, event, state, fallback_options, true)
	if mode != "model" or client == null or (event.get("type") == "ask" and rules.get("agent", {}).get("ask_answers", "authored") == "authored"):
		return _with_script(base, event, state, fallback_options, false)
	if calls_this_visit >= max_calls:
		base["fallback_reason"] = "call_cap"
		return _with_script(base, event, state, fallback_options, true)
	calls_this_visit += 1
	var generation := _generation
	var started := Time.get_ticks_msec()
	var resp: Dictionary = await client.request_move(build_payload(event, state, signs))
	if generation != _generation:
		return {}
	base["latency_ms"] = Time.get_ticks_msec() - started
	if not bool(resp.get("ok", false)):
		base["fallback_reason"] = str(resp.get("error", "error"))
		return _with_script(base, event, state, fallback_options, true)
	var data: Variant = resp.get("data")
	var checked := ResponseValidator.validate(data, reply_chars(), str(event.get("type")) == "check", str(event.get("outcome", "")))
	if not bool(checked.get("ok", false)):
		base["fallback_reason"] = "invalid:" + str(checked.get("reason"))
		return _with_script(base, event, state, fallback_options, true)
	base["source"] = "model"
	base["reply"] = checked.reply
	base["line"] = checked.reply
	base["reaction"] = checked.reaction
	base["meta"] = data.get("meta", {})
	if str(event.get("type")) == "check":
		base["cooperates"] = checked.cooperates
		base["move"] = "comply" if bool(checked.cooperates) else "stall"
	elif event.get("type") == "ask":
		base["move"] = str(event.outcome)
	else:
		base["move"] = "dialogue"
	last = base
	return base


func _with_script(base: Dictionary, event: Dictionary, state: Dictionary, options: Array, fallback: bool) -> Dictionary:
	var kind := str(event.get("type", ""))
	var pick := {"move": "dialogue", "line": "I don't know how to answer that. Can we talk about why I came in?"}
	if kind == "check" or kind == "ask":
		pick = scripted.decide(case_data, event, state, options)
	elif kind == "say":
		# a sentence the script has no answer for: the offline patient declines in character
		var dodge := scripted.line_for(case_data, "deflect", event, state)
		if dodge != "":
			pick["line"] = dodge
	elif kind == "reassure":
		var lines: Variant = case_data.get("lines", {}).get("reassure", "All right.")
		pick["line"] = str(lines[0]) if typeof(lines) == TYPE_ARRAY and not lines.is_empty() else str(lines)
	elif kind == "press":
		var reactions: Array = case_data.get("press", [])
		if not reactions.is_empty():
			pick["line"] = str(reactions[mini(int(state.get("press_count", 0)), reactions.size() - 1)].get("line", ""))
	base["move"] = pick.move
	base["line"] = pick.line
	base["reply"] = pick.line
	base["source"] = "fallback" if fallback else "script"
	if fallback:
		fallbacks_this_visit += 1
	last = base
	return base


## Commit only exchanges that survive the UI cancellation token. Reset per patient.
func remember_exchange(event: Dictionary, response: Dictionary) -> void:
	var text := str(event.get("text", "")).strip_edges()
	if text != "":
		conversation_history.append({"role": "doctor", "text": text})
	# a scripted line was shown in the player's language; a model's words are kept as they came
	if str(response.get("reaction", "")) != "":
		conversation_history.append({"role": "reaction", "text": Lang.t(str(response.reaction))})
	if str(response.get("reply", "")) != "":
		conversation_history.append({"role": "patient", "text": Lang.t(str(response.reply))})
	while conversation_history.size() > MAX_HISTORY:
		conversation_history.pop_front()


## Sends one push-to-talk clip for its words. The words are the player's own line, to be put in
## front of the player and sent like a typed one: nothing here speaks for the patient.
## Returns {"ok": true, "text": String, "latency_ms": int, "mock": bool} or
## {"ok": false, "error": String, "latency_ms": int}; {} when a new visit began while it waited.
func transcribe(wav: PackedByteArray) -> Dictionary:
	if mode != "model" or client == null or not client.has_method("request_transcript"):
		return {"ok": false, "error": "not_configured", "latency_ms": 0}
	if voice_clips_this_visit >= max_voice_clips:
		return {"ok": false, "error": "clip_cap", "latency_ms": 0}
	voice_clips_this_visit += 1
	var generation := _generation
	var started := Time.get_ticks_msec()
	var resp: Dictionary = await client.request_transcript(build_voice_payload(wav))
	if generation != _generation:
		return {}
	var waited: int = Time.get_ticks_msec() - started
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": str(resp.get("error", "error")), "latency_ms": waited}
	var data: Variant = resp.get("data")
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("text")) != TYPE_STRING or str(data.text).strip_edges() == "":
		return {"ok": false, "error": "invalid", "latency_ms": waited}
	var meta: Variant = data.get("meta")
	return {"ok": true, "text": str(data.text).strip_edges(), "latency_ms": waited,
		"mock": typeof(meta) == TYPE_DICTIONARY and bool(meta.get("mock", false))}


func build_voice_payload(wav: PackedByteArray) -> Dictionary:
	return {"protocol": PROTOCOL, "session_id": session_id, "visit_id": visit_id, "language": Lang.code,
		"audio": {"mime": "audio/wav", "data": Marshalls.raw_to_base64(wav)},
		"client": {"game": "before-the-cut", "version": GAME_VERSION}}


## Classify only the doctor's line. The intent route never receives a sign, state or history.
func classify(text: String) -> Dictionary:
	var fallback := ScriptedBrain.intent_for_text(case_data, text)
	fallback.merge({"source":"script","reason":""})
	if mode != "model" or client == null:
		return fallback
	fallback.source = "fallback"
	if calls_this_visit >= max_calls or intents_this_visit >= max_intents or not client.has_method("request_intent"):
		fallback.reason = "call_cap" if calls_this_visit >= max_calls or intents_this_visit >= max_intents else "not_configured"
		return fallback
	var generation := _generation
	intents_this_visit += 1
	var payload := {"protocol": PROTOCOL, "session_id": session_id, "visit_id": visit_id, "case_id": case_data.id,
		"case_version": case_data.version, "language": Lang.code, "text": text}
	var response: Dictionary = await client.request_intent(payload)
	if generation != _generation:
		return {}
	if response.get("ok") == true:
		var about: Variant = response.get("data", {}).get("about")
		if about == "none":
			return {"topic": "", "intent": str(response.data.get("intent", "other")), "source": "model", "reason": ""}
		for item in case_data.get("topics", []):
			if item.id == about:
				return {"topic": about, "intent":"case_question", "source":"model", "reason":""}
	fallback.reason = str(response.get("error", "invalid_intent"))
	return fallback


## Speculative dialogue reserves a reply immediately. Only the director can accept it into memory.
func can_beat(kind: String) -> bool:
	var limits: Dictionary = rules.get("agent", {}).get("beats", {})
	return mode == "model" and client != null and limits.get("enabled", false) and kind in ["arrive", "after_check", "idle"] and calls_this_visit < max_calls and beats_this_visit < int(limits.get("max_per_visit", 0)) and (kind != "idle" or idle_beats_this_visit < int(limits.get("max_idle_per_visit", 0)))


func beat(kind: String, tool: String, state: Dictionary, signs: Dictionary) -> Dictionary:
	if not can_beat(kind):
		return {}
	var generation := _generation
	beats_this_visit += 1
	calls_this_visit += 1
	if kind == "idle":
		idle_beats_this_visit += 1
	var event := {"type":kind, "id":tool, "text":""}
	var response: Dictionary = await client.request_move(build_payload(event, state, signs))
	if generation != _generation or not response.get("ok", false):
		return {}
	var result := ResponseValidator.validate(response.get("data"), reply_chars(), false, "", true)
	if not result.ok or result.reply == "":
		return {}
	return result


func build_payload(event: Dictionary, state: Dictionary, signs: Dictionary = {}) -> Dictionary:
	return {"protocol": PROTOCOL, "session_id": session_id, "visit_id": visit_id,
		"case_id": str(case_data.get("id", "")), "case_version": int(case_data.get("version", 2)),
		"signs": signs.duplicate(),
		"event": event.duplicate(true), "state": state.duplicate(true),
		"conversation_history": conversation_history.duplicate(true),
		"language": Lang.code,
		"limits": {"max_line_chars": line_chars()},
		"client": {"game": "before-the-cut", "version": GAME_VERSION}}
