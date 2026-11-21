extends Node
## Talks to the agent proxy (agent_proxy/ in this repository): one request for what the patient says next,
## and one for the words in a push-to-talk clip.
## The game never talks to a model provider directly and never holds an API key:
## the proxy owns the key, the prompt, the limits and the provider choice.
## Used as: const ModelClient = preload("res://scripts/core/model_client.gd")

var base_url: String = ""
var timeout_ms: int = 4000           # a patient reply; main sets both from rules.json
var intent_timeout_ms: int = 2500
var voice_timeout_ms: int = 7000     # the words of a clip: a longer upload, a slower answer


func is_configured() -> bool:
	return base_url != ""


## Always returns a Dictionary:
##   {"ok": true, "data": {...}, "http_code": 200}
##   {"ok": false, "error": "<reason>"}   reason: not_configured, request_failed, timeout,
##                                        network_<n>, bad_json, http_<code>[:<proxy error code>]
func request_move(payload: Dictionary) -> Dictionary:
	return await _request("/v1/patient-dialogue", HTTPClient.METHOD_POST, JSON.stringify(payload), timeout_ms)


func request_intent(payload: Dictionary) -> Dictionary:
	return await _request("/v1/patient-intent", HTTPClient.METHOD_POST, JSON.stringify(payload), intent_timeout_ms)


## One push-to-talk clip in, its words out: data is {"text": "...", "meta": {...}}.
## The same result shape and error words as request_move.
func request_transcript(payload: Dictionary) -> Dictionary:
	return await _request("/v1/transcribe", HTTPClient.METHOD_POST, JSON.stringify(payload), voice_timeout_ms)


## Verify the complete roster before offering a model patient. One GET, no provider call.
func check_service(expected: Dictionary, wait_ms: int) -> Dictionary:
	var response: Dictionary = await _request("/healthz", HTTPClient.METHOD_GET, "", wait_ms)
	if not response.get("ok", false):
		return {"status": "unreachable"}
	var data: Dictionary = response.data
	if data.get("disabled") == true:
		return {"status": "disabled"}
	if data.get("ok") != true or data.get("protocol") != "4" or typeof(data.get("cases")) != TYPE_ARRAY:
		return {"status": "version"}
	var seen := {}
	for item in data.cases:
		if typeof(item) != TYPE_DICTIONARY:
			return {"status": "version"}
		var id: Variant = item.get("id")
		if typeof(id) != TYPE_STRING or not expected.has(id) or seen.has(id) or item.get("version") != expected[id].version:
			return {"status": "version"}
		seen[id] = true
	if seen.size() != expected.size():
		return {"status": "version"}
	return {"status": "connected", "beats": data.get("patient_beats") == true, "voice": data.get("speech_to_text") == true, "mock": data.get("provider") == "mock"}


func _request(path: String, method: HTTPClient.Method, body_text: String, wait_ms: int) -> Dictionary:
	if base_url == "":
		return {"ok": false, "error": "not_configured"}
	# One HTTPRequest node per call, so a cancelled visit can never receive another visit's answer.
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = float(wait_ms) / 1000.0
	http.body_size_limit = 16384
	var url: String = base_url.rstrip("/") + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err: int = http.request(url, headers, method, body_text)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "request_failed"}
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = int(res[0])
	var code: int = int(res[1])
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "error": "timeout"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network_%d" % result}
	var body: PackedByteArray = res[3]
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_json", "http_code": code}
	var data: Dictionary = parser.data
	if code != 200:
		var reason: String = "http_%d" % code
		if typeof(data.get("error")) == TYPE_DICTIONARY:
			var err_obj: Dictionary = data["error"]
			reason = "%s:%s" % [reason, str(err_obj.get("code", ""))]
		return {"ok": false, "error": reason, "http_code": code}
	return {"ok": true, "data": data, "http_code": code}
