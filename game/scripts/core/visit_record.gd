extends RefCounted
## The conversation and observable actions of one appointment, in the order they happened.
## Held only in memory. Physical readings, courier codes and the diagnosis have no entries.

var entries: Array = []
var _action_counts: Dictionary = {}
var _entry_bytes: int = 0


func append(role: String, text: String) -> void:
	if text.is_empty():
		return
	var entry := {"role": role, "text": text}
	entries.append(entry)
	_entry_bytes += _bytes(entry) + 1
	if role == "action":
		_action_counts[text] = int(_action_counts.get(text, 0)) + 1


func clear() -> void:
	entries.clear()
	_action_counts.clear()
	_entry_bytes = 0


## Keep the whole record locally. The existing HTTP body limit applies to each request.
## For oversized visits preserve the beginning, the recent exchange and totals for every action.
func put_in_request(payload: Dictionary, max_bytes: int) -> void:
	payload["conversation_history"] = []
	var available := max_bytes - _bytes(payload)
	if _entry_bytes - 1 <= available:
		payload.conversation_history = entries.duplicate(true)
		return
	# Reserve space with the largest possible counts before choosing either excerpt.
	var summary := {"omitted": entries.size(), "after": entries.size(), "actions": _action_counts.duplicate()}
	payload["visit_summary"] = summary
	available = max_bytes - _bytes(payload)
	var prefix := 0
	var used := 0
	while prefix < entries.size():
		var cost := _bytes(entries[prefix]) + 1
		if used + cost > available / 4.0:
			break
		used += cost
		prefix += 1
	var suffix := entries.size()
	while suffix > prefix:
		var cost := _bytes(entries[suffix - 1]) + 1
		if used + cost > available:
			break
		used += cost
		suffix -= 1
	summary.after = prefix
	summary.omitted = suffix - prefix
	payload.conversation_history = entries.slice(0, prefix, 1, true) + entries.slice(suffix, entries.size(), 1, true)


static func _bytes(value: Variant) -> int:
	return JSON.stringify(value).to_utf8_buffer().size()
