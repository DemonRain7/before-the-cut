extends RefCounted
## Format and display limits only. This validator never selects or rewrites patient speech.
## Filename retained for existing preloads; model responses have no legal-move list.

static func validate(raw: Variant, max_chars: int, needs_cooperation: bool = false, outcome: String = "") -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	var data: Dictionary = raw
	for key in ["reply", "reaction"]:
		if typeof(data.get(key)) != TYPE_STRING:
			return {"ok": false, "reason": key + "_missing"}
		var value := str(data[key]).strip_edges()
		if key == "reply" and value.is_empty():
			return {"ok": false, "reason": "reply_empty"}
		if value.length() > (max_chars if key == "reply" else 110):
			return {"ok": false, "reason": key + "_too_long"}
		for i in value.length():
			if value.unicode_at(i) < 32:
				return {"ok": false, "reason": key + "_control_char"}
	if (needs_cooperation or data.has("cooperates")) and typeof(data.get("cooperates")) != TYPE_BOOL:
		return {"ok": false, "reason": "cooperates_missing"}
	if outcome != "" and data.get("cooperates") != (outcome in ["grant", "answer"]):
		return {"ok": false, "reason": "outcome_mismatch"}
	var result := {"ok": true, "reply": str(data.reply).strip_edges(), "reaction": str(data.reaction).strip_edges()}
	if data.has("cooperates"):
		result["cooperates"] = data.cooperates
	return result
