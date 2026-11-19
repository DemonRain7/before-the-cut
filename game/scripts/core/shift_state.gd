extends RefCounted
## One shift: the queue of patients, tonight's contacts, the running totals, the lender's line
## and the counter glass.
##
## The line (rules.json "line"): Kessler sold the doctor's debt to Harrow Credit, and Harrow's
## meter reads the till once an hour. One finished visit is one hour; hour n wants n x per_hour
## in the till. Readings on the way are warnings. The last one decides the night (see report()).
##
## Two kinds of money (rules version 8). Through the night the till holds only what came in at
## the counter: fees for work done, drops, less CALM and glass (till()). Whether each call was
## right, and what it brings (Trauma Team's bounty or bill, the bill for work on somebody who
## drifted), comes in at closing with the night's reports, before the last reading (total()).
## So the readings on the way say nothing about who was drifting.
##
## A patient who gets through the window kills the doctor (record()): the night ends there, the
## rest of the line goes home unseen, and the report is the last thing (is_done(), report()).
## Nobody reads the meter in the hour it happened (readings()), and the line is not held.
##
## Contacts (rules.json "contacts", data/contacts.json): each night some visitors are couriers.
## The list is drawn from the shift seed (draw_contacts()); a drop is paid into the visit's
## settlement, so the till and every reading count it like a fee.
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
var contacts: Array = []  # tonight's list: entries of data/contacts.json "pool", one per courier
var died: bool = false    # somebody came through the window: the night ended with that visit


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


## Tonight's contacts: rules.json contacts.per_night entries of the pool, each for a different
## visitor who comes in tonight, drawn from the shift seed with a generator of their own.
## `first_on_list` (the training night) puts the first visitor on the list, so the first visit
## can show how a code works. The list is not in arrival order, so it says nothing about who
## comes when.
static func draw_contacts(p_rules: Dictionary, pool: Array, p_order: Array, p_seed: int, first_on_list: bool = false) -> Array:
	var per := 0
	if typeof(p_rules.get("contacts")) == TYPE_DICTIONARY:
		per = maxi(0, int(p_rules["contacts"].get("per_night", 0)))
	if per == 0 or pool.is_empty() or p_order.is_empty():
		return []
	var coming: Array = []
	for id in p_order:
		coming.append(str(id))
	var entries: Array = []
	for e in pool:
		if typeof(e) == TYPE_DICTIONARY and coming.has(str((e as Dictionary).get("case", ""))):
			entries.append(e)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("contacts:%d" % p_seed)
	for i in range(entries.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = entries[i]
		entries[i] = entries[j]
		entries[j] = swap
	var out: Array = []
	var taken: Dictionary = {}
	if first_on_list:
		for e in entries:
			if str(e.get("case", "")) == str(coming[0]):
				out.append((e as Dictionary).duplicate(true))
				taken[str(coming[0])] = true
				break
	for e in entries:
		if out.size() >= per:
			break
		var cid := str(e.get("case", ""))
		if taken.has(cid):
			continue
		out.append((e as Dictionary).duplicate(true))
		taken[cid] = true
	return out


## The list entry for a visitor, or {} when they are not a courier tonight.
func contact_for(case_id: String) -> Dictionary:
	for e in contacts:
		if str((e as Dictionary).get("case", "")) == case_id:
			return e
	return {}


## Who is at the counter: nobody once the night is over.
func current_id() -> String:
	return str(order[index]) if not died and index < order.size() else ""


func upcoming_id() -> String:
	return str(order[index + 1]) if not died and index + 1 < order.size() else ""


## The night is over: everybody has been seen, or the doctor is dead.
func is_done() -> bool:
	return died or index >= order.size()


func count() -> int:
	return order.size()


func record(settlement: Dictionary) -> void:
	records.append(settlement.duplicate(true))
	if str(settlement.get("outcome", "")) == "hit":
		died = true


func advance() -> void:
	index += 1


## What is in the till at closing, with the night's reports in: every finished visit in full,
## less what the glass has cost.
func total() -> int:
	var sum := 0
	for r in records:
		sum += int(r.get("credits", 0))
	return sum - repair_total()


## What is in the till during the night: what each finished visit paid at the counter, less
## what the glass has cost. The rest of each visit's money waits for closing (total()).
func till() -> int:
	var sum := 0
	for r in records:
		sum += int(r.get("counter", r.get("credits", 0)))
	return sum - repair_total()


## Who never came in: the visitors still in the hall when the night ended early. Ids.
func unseen() -> Array:
	return order.slice(records.size())


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


## The meter reading after `p_hour` finished visits (default: after the latest one). Through
## the night the meter reads what came in at the counter (till()); the last reading is taken at
## closing, when the night's reports are in, and counts every visit in full (total()). Glass
## that was paid for before that hour's patient came in is out of the till by then; glass paid
## for after the reading belongs to the next one, so a reading never changes once it is taken.
func reading(p_hour: int = -1) -> Dictionary:
	var h := records.size() if p_hour < 0 else mini(p_hour, records.size())
	var last := h >= order.size()
	var till := 0
	for i in h:
		var r: Dictionary = records[i]
		till += int(r.get("credits", 0)) if last else int(r.get("counter", r.get("credits", 0)))
	for r in repairs:
		var paid: Dictionary = r
		if int(paid.get("after", 0)) < h:
			till -= int(paid.get("cost", 0))
	var line := line_at(h)
	return {"hour": h, "of": order.size(), "till": till, "line": line, "held": till >= line,
		"margin": till - line, "last": last}


## The readings taken so far, one an hour. Nobody reads the meter in the hour the doctor died.
func readings() -> Array:
	var out: Array = []
	var hours := records.size() - (1 if died else 0)
	for h in range(1, hours + 1):
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
	return {"cost": cost, "glass": glass, "glass_max": glass_max(), "till": till()}


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
	var line_held := not died and total() >= line      # nobody reads the meter for a dead doctor
	var title := ""
	var text := ""
	# titles are written for a five-patient shift; scale the threshold for other lengths
	var scaled := correct
	if order.size() > 0 and order.size() != 5:
		scaled = int(round(5.0 * correct / order.size()))
	# the first title that fits: enough right calls and, where a title asks for it, a night that
	# did or did not end in the doctor's death, no more injuries than it allows and the night's
	# last reading on the side of the line it names
	for t in rules.get("titles", []):
		var entry: Dictionary = t
		if entry.has("died") and bool(entry["died"]) != died:
			continue
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
	var drops := 0
	var drop_total := 0
	var calm_total := 0
	for r in records:
		if bool(r.get("dropped", false)):
			drops += 1
			drop_total += int(r.get("drop", 0))
		calm_total += int(r.get("calm_spent", 0))
	var said := "held" if line_held else "short"
	if died:
		said = "died"
	return {
		"visits": records.duplicate(true),
		"count": order.size(),
		"correct": correct,
		"injuries": injuries,
		"total": total(),
		"counter_total": till() + repair_total(),      # what the counter took in, before the glass
		"closing_total": total() - till(),             # what the night's reports added or billed
		"died": died,
		"unseen": unseen(),
		"line": line,
		"line_held": line_held,
		"hours_under": hours_under(),
		"readings": readings(),
		"glass": glass,
		"glass_max": glass_max(),
		"repairs": repairs.size(),
		"repair_total": repair_total(),
		"contacts": contacts.size(),
		"drops": drops,
		"drop_total": drop_total,
		"calm_total": calm_total,
		"title": title,
		"text": text,
		"line_text": str(line_text.get(said, "")),
	}
