extends RefCounted
## One shift: the queue of patients, the running totals, the lender's line and the counter glass.
##
## The line (rules.json "line"): the clinic's chair and tools are on lease, and the lender's
## meter reads the till once an hour. One finished visit is one hour; hour n wants n x per_hour
## in the till. Readings on the way are warnings. The last one decides the night (see report()).
##
## The glass (rules.json "attack"): the pane in the counter window takes "glass" blows in a
## shift. Each blow that lands before the shutter is down uses one up, and the damage stays,
## so a slow shutter makes the next attack arrive sooner (attack_plan()). Between patients the
## doctor can pay to have one layer refitted (repair_glass()): "repair_cost" credits out of the
## till for one more blow. The meter counts that money at every reading after it was spent.
## Used as: const ShiftState = preload("res://scripts/core/shift_state.gd")

var rules: Dictionary = {}
var order: Array = []
var index: int = 0
var records: Array = []   # one settlement per finished visit
var glass: int = 0        # blows the pane can still take tonight
var glass_out: bool = false   # somebody came through it: no pane is left
var repairs: Array = []   # one per layer paid for: {"after": visits finished by then, "cost": credits}


func _init(p_rules: Dictionary = {}, p_order: Array = []) -> void:
	rules = p_rules
	order = p_order.duplicate() if not p_order.is_empty() else (rules.get("shift_order", []) as Array).duplicate()
	glass = glass_max()


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


## What is in the till now: every finished visit, less what the glass has cost.
func total() -> int:
	var sum := 0
	for r in records:
		sum += int(r.get("credits", 0))
	return sum - repair_total()


func correct_count() -> int:
	var n := 0
	for r in records:
		if bool(r.get("correct", false)):
			n += 1
	return n


# ------------------------------------------------------------------ the line
func line_per_hour() -> int:
	var line: Dictionary = rules.get("line", {})
	return maxi(0, int(line.get("per_hour", 0)))


## What the meter wants in the till at the reading that ends hour `hour` (1-based).
func line_at(p_hour: int) -> int:
	return line_per_hour() * clampi(p_hour, 0, order.size())


## The hour being worked, 1-based: one visit is one hour.
func hour() -> int:
	return mini(index + 1, maxi(1, order.size()))


## The meter reading after `p_hour` finished visits (default: after the latest one). Glass that
## was paid for before that hour's patient came in is out of the till by then; glass paid for
## after the reading belongs to the next one, so a reading never changes once it is taken.
func reading(p_hour: int = -1) -> Dictionary:
	var h := records.size() if p_hour < 0 else mini(p_hour, records.size())
	var till := 0
	for i in h:
		till += int(records[i].get("credits", 0))
	for r in repairs:
		var paid: Dictionary = r
		if int(paid.get("after", 0)) < h:
			till -= int(paid.get("cost", 0))
	var line := line_at(h)
	return {"hour": h, "of": order.size(), "till": till, "line": line, "held": till >= line,
		"margin": till - line, "last": h >= order.size()}


func readings() -> Array:
	var out: Array = []
	for h in range(1, records.size() + 1):
		out.append(reading(h))
	return out


## How many of tonight's readings so far were under the line.
func hours_under() -> int:
	var n := 0
	for r in readings():
		if not bool(r["held"]):
			n += 1
	return n


# ------------------------------------------------------------------ the glass
func glass_max() -> int:
	var attack: Dictionary = rules.get("attack", {})
	var marks: Array = attack.get("blow_at", [0.3, 0.55, 0.8])
	return clampi(int(attack.get("glass", marks.size())), 0, marks.size())


## A blow landed before the shutter was down. Returns what is left.
func glass_blow() -> int:
	glass = maxi(0, glass - 1)
	return glass


## A patient came through the window, or the last layer gave way: no pane is left, until the
## doctor pays for one.
func glass_break() -> void:
	glass = 0
	glass_out = true


## What one layer of glass costs (0: nobody mends glass in this rule set).
func repair_cost() -> int:
	var attack: Dictionary = rules.get("attack", {})
	return maxi(0, int(attack.get("repair_cost", 0)))


## A layer is missing, there is a price for one, and somebody is still to come tonight. The
## till does not have to cover it: the lender's meter counts the debt like any other loss.
func can_repair() -> bool:
	return repair_cost() > 0 and glass < glass_max() and not is_done()


## Pays for one layer: the pane takes one more blow, and an empty frame has glass in it again.
## Returns {"cost", "glass", "glass_max", "till"}, or {} when there is nothing to mend.
func repair_glass() -> Dictionary:
	if not can_repair():
		return {}
	var cost := repair_cost()
	repairs.append({"after": records.size(), "cost": cost})
	glass += 1
	glass_out = false
	return {"cost": cost, "glass": glass, "glass_max": glass_max(), "till": total()}


func repair_total() -> int:
	var sum := 0
	for r in repairs:
		var paid: Dictionary = r
		sum += int(paid.get("cost", 0))
	return sum


## The next attack, for the glass that is left: when each blow lands and when the patient
## comes through, in ms after the warning. A whole pane takes every blow and gives the full
## window; with less glass fewer blows land and the patient is through at the time the next
## one would have fallen, but never sooner than attack.min_window_ms.
func attack_plan() -> Dictionary:
	var attack: Dictionary = rules.get("attack", {})
	var window := float(attack.get("window_ms", 1800))
	var marks: Array = attack.get("blow_at", [0.3, 0.55, 0.8])
	var left := clampi(glass, 0, marks.size())
	var blows: Array = []
	for i in left:
		blows.append(int(round(float(marks[i]) * window)))
	var through := window
	if left < marks.size():
		through = float(marks[left]) * window
	through = maxf(through, float(attack.get("min_window_ms", 650)))
	return {"blows_ms": blows, "through_ms": int(round(through)), "glass": left,
		"glass_max": glass_max(), "out": glass_out}


func report() -> Dictionary:
	var injuries := 0
	for r in records:
		if bool(r.get("injured", false)):
			injuries += 1
	var correct := correct_count()
	var line := line_at(order.size())
	var line_held := total() >= line
	var title := ""
	var text := ""
	# titles are written for a five-patient shift; scale the threshold for other lengths
	var scaled := correct
	if order.size() > 0 and order.size() != 5:
		scaled = int(round(5.0 * correct / order.size()))
	# the first title that fits: enough right calls and, where a title asks for it, no more
	# injuries than it allows and the night's last reading on the side of the line it names
	for t in rules.get("titles", []):
		var entry: Dictionary = t
		if scaled < int(entry.get("min_correct", 0)):
			continue
		if entry.has("max_injuries") and injuries > int(entry["max_injuries"]):
			continue
		if entry.has("line_held") and bool(entry["line_held"]) != line_held:
			continue
		title = str(entry.get("title", ""))
		text = str(entry.get("text", ""))
		break
	var line_text: Dictionary = rules.get("line_text", {})
	return {
		"visits": records.duplicate(true),
		"count": order.size(),
		"correct": correct,
		"injuries": injuries,
		"total": total(),
		"line": line,
		"line_held": line_held,
		"hours_under": hours_under(),
		"readings": readings(),
		"glass": glass,
		"glass_max": glass_max(),
		"repairs": repairs.size(),
		"repair_total": repair_total(),
		"title": title,
		"text": text,
		"line_text": str(line_text.get("held" if line_held else "short", "")),
	}
