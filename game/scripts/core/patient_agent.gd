extends RefCounted
## Autonomous character dialogue with an explicitly labelled offline comparison/fallback.
## Only the fallback uses ScriptedBrain. Successful model speech is never replaced.

const ScriptedBrain = preload("res://scripts/core/scripted_brain.gd")
const ResponseValidator = preload("res://scripts/core/move_validator.gd")
const GAME_VERSION := "0.3.0"
const MAX_HISTORY := 48          # turns kept for the model: a whole visit at the call cap

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
var calls_this_visit: int = 0
var fallbacks_this_visit: int = 0
var max_voice_clips: int = 24    # push-to-talk clips sent for their words, per visit
var voice_clips_this_visit: int = 0
var last: Dictionary = {}
var conversation_history: Array = []
var _generation: int = 0


func _init(p_rules: Dictionary = {}, p_client: Variant = null, p_seed: int = 0) -> void:
	rules = p_rules
	client = p_client
	var limits: Dictionary = rules.get("agent", {})
	max_calls = int(limits.get("max_model_calls_per_visit", 16))
	max_line_chars = int(limits.get("max_line_chars", 110))
	max_reply_chars = maxi(max_line_chars, int(limits.get("max_reply_chars", 220)))
	var voice: Dictionary = limits.get("voice", {})
	max_voice_clips = int(voice.get("max_clips_per_visit", 24))
	scripted = ScriptedBrain.new(p_seed)


func set_mode(p_mode: String) -> void:
	mode = "model" if p_mode == "model" and client != null else "script"


func begin_visit(p_case: Dictionary, p_visit_id: String, p_seed: int) -> void:
	_generation += 1
	case_data = p_case
	visit_id = p_visit_id
	calls_this_visit = 0
	fallbacks_this_visit = 0
	voice_clips_this_visit = 0
	last = {}
	conversation_history = []
	for line in case_data.get("opening", []):
		conversation_history.append({"role": "patient", "text": str(line)})
	scripted.reseed(p_seed)


## fallback_options are ONLY for the offline script; never sent to or checked against AI.
func decide(event: Dictionary, state: Dictionary, fallback_options: Array = []) -> Dictionary:
	var base := {"event": event.duplicate(), "move": "", "line": "", "reply": "", "reaction": "",
		"source": "script", "fallback_reason": "", "latency_ms": 0, "meta": {}}
	if mode != "model" or client == null:
		return _with_script(base, event, state, fallback_options, false)
	if calls_this_visit >= max_calls:
		base["fallback_reason"] = "call_cap"
		return _with_script(base, event, state, fallback_options, true)
	calls_this_visit += 1
	var generation := _generation
	var started := Time.get_ticks_msec()
	var resp: Dictionary = await client.request_move(build_payload(event, state))
	if generation != _generation:
		return {}
	base["latency_ms"] = Time.get_ticks_msec() - started
	if not bool(resp.get("ok", false)):
		base["fallback_reason"] = str(resp.get("error", "error"))
		return _with_script(base, event, state, fallback_options, true)
	var data: Variant = resp.get("data")
	var checked := ResponseValidator.validate(data, max_reply_chars, str(event.get("type")) == "check")
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
	if str(response.get("reaction", "")) != "":
		conversation_history.append({"role": "reaction", "text": str(response.reaction)})
	if str(response.get("reply", "")) != "":
		conversation_history.append({"role": "patient", "text": str(response.reply)})
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
	return {"protocol": "3", "session_id": session_id, "visit_id": visit_id,
		"audio": {"mime": "audio/wav", "data": Marshalls.raw_to_base64(wav)},
		"client": {"game": "before-the-cut", "version": GAME_VERSION}}


func build_payload(event: Dictionary, state: Dictionary) -> Dictionary:
	return {"protocol": "3", "session_id": session_id, "visit_id": visit_id,
		"case_id": str(case_data.get("id", "")), "case_version": int(case_data.get("version", 2)),
		"event": event.duplicate(true), "state": state.duplicate(true),
		"conversation_history": conversation_history.duplicate(true),
		"limits": {"max_line_chars": max_line_chars},
		"client": {"game": "before-the-cut", "version": GAME_VERSION}}
