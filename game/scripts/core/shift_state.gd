extends RefCounted
## One shift: the fixed queue of patients and the running totals.
## Used as: const ShiftState = preload("res://scripts/core/shift_state.gd")

var rules: Dictionary = {}
var order: Array = []
var index: int = 0
var records: Array = []   # one settlement per finished visit


func _init(p_rules: Dictionary = {}, p_order: Array = []) -> void:
	rules = p_rules
	order = p_order.duplicate() if not p_order.is_empty() else (rules.get("shift_order", []) as Array).duplicate()


func current_id() -> String:
	return str(order[index]) if index < order.size() else ""


func upcoming_id() -> String:
	return str(order[index + 1]) if index + 1 < order.size() else ""


func is_done() -> bool:
	return index >= order.size()


func count() -> int:
	return order.size()


func record(settlement: Dictionary) -> void:
	records.append(settlement.duplicate(true))


func advance() -> void:
	index += 1


func total() -> int:
	var sum := 0
	for r in records:
		sum += int(r.get("credits", 0))
	return sum


func correct_count() -> int:
	var n := 0
	for r in records:
		if bool(r.get("correct", false)):
			n += 1
	return n


func report() -> Dictionary:
	var injuries := 0
	for r in records:
		if bool(r.get("injured", false)):
			injuries += 1
	var correct := correct_count()
	var rent := int(rules.get("rent", 0))
	var rent_paid := total() >= rent
	var title := ""
	var text := ""
	# titles are written for a five-patient shift; scale the threshold for other lengths
	var scaled := correct
	if order.size() > 0 and order.size() != 5:
		scaled = int(round(5.0 * correct / order.size()))
	# the first title that fits: enough right calls and, where a title asks for it, no more
	# injuries than it allows and the rent covered
	for t in rules.get("titles", []):
		var entry: Dictionary = t
		if scaled < int(entry.get("min_correct", 0)):
			continue
		if entry.has("max_injuries") and injuries > int(entry["max_injuries"]):
			continue
		if bool(entry.get("rent_paid", false)) and not rent_paid:
			continue
		title = str(entry.get("title", ""))
		text = str(entry.get("text", ""))
		break
	var rent_text: Dictionary = rules.get("rent_text", {})
	return {
		"visits": records.duplicate(true),
		"count": order.size(),
		"correct": correct,
		"injuries": injuries,
		"total": total(),
		"rent": rent,
		"rent_paid": rent_paid,
		"title": title,
		"text": text,
		"rent_text": str(rent_text.get("paid" if rent_paid else "short", "")),
	}
