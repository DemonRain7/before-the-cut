extends RefCounted
## One shift: the queue of patients and the running totals.
## Used as: const ShiftState = preload("res://scripts/core/shift_state.gd")

var rules: Dictionary = {}
var order: Array = []
var index: int = 0
var records: Array = []   # one settlement per finished visit


func _init(p_rules: Dictionary = {}, p_order: Array = []) -> void:
	rules = p_rules
	order = p_order.duplicate() if not p_order.is_empty() else (rules.get("shift_order", []) as Array).duplicate()


## Who comes in tonight, and in what order. rules.json `shift_order` lists the patients in
## their authored order; with `arrivals.shuffle` the order is drawn from the shift seed, so the
## same seed always gives the same night. With `arrivals.first_shift_opens_steady` the first
## shift of a session opens with a steady patient (truth "stable"), so a new player meets the
## desk before anyone can turn on them. Later shifts may open with anyone.
static func arrival_order(p_rules: Dictionary, p_cases: Dictionary, p_seed: int, first_of_session: bool) -> Array:
	var ids: Array = (p_rules.get("shift_order", []) as Array).duplicate()
	var arrivals: Dictionary = p_rules.get("arrivals", {})
	if not bool(arrivals.get("shuffle", false)) or ids.size() < 2:
		return ids
	var rng := RandomNumberGenerator.new()      # its own generator: the shift's beats stay as they were
	rng.seed = p_seed
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	if first_of_session and bool(arrivals.get("first_shift_opens_steady", false)):
		for i in ids.size():
			var c: Dictionary = p_cases.get(str(ids[i]), {})
			if str(c.get("truth", "")) == "stable":
				if i > 0:
					var steady: Variant = ids[i]
					ids.remove_at(i)
					ids.insert(0, steady)
				break
	return ids


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
