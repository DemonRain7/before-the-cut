extends SceneTree
## Draw nights with the production RNG and play the complaint-first routine in VisitState.
## Store categorical results only. The companion analysis integrates policies over these draws.
const DB = preload("res://scripts/core/case_db.gd")
const Shift = preload("res://scripts/core/shift_state.gd")
const Visit = preload("res://scripts/core/visit_state.gd")
const ROWS = ["eyes", "hands", "port", "temper"]
const TOOLS = ["penlight", "grip", "port"]
var db: Dictionary
var cache := {}
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	db = DB.load_all()
	if not db.errors.is_empty():
		printerr(db.errors)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	var nights := int(args[1]) if args.size() > 1 else 25000
	for seed_id in range(1, nights + 1):
		var n := Shift.draw_night(db, seed_id, true)
		var ids := DB.night_order(n)
		var pool := DB.fair_contacts(db.contacts, db.people, ids)
		var couriers := Shift.draw_contacts(db.rules, pool, ids, seed_id, true, db.contacts)
		for idx in n.visitors.size():
			var pick: Dictionary = n.visitors[idx]
			var key := str([pick.id, pick.truth, pick.signs])
			if not cache.has(key):
				cache[key] = DB.compose(db.templates[pick.id], pick)
			var c: Dictionary = cache[key].duplicate(false)
			c.complaint_rows = pick.complaints
			var v := Visit.new(c, db.rules)
			v.surprises = idx != 0
			var order: Array = range(4)
			rng.seed = hash("routine:%d:%d" % [seed_id, idx])
			Shift._shuffle(order, rng)
			var first: Array = []
			for k in order:
				if ROWS[k] in pick.complaints:
					first.append(k)
			for k in order:
				if k not in first:
					first.append(k)
			for topic in c.topics:
				v.apply_ask(topic.id)
			while v.complaints_told.size() < pick.complaints.size():
				v.complain()
			var mask := 0
			var clues := 0
			for k in 4:
				if not c.rows[ROWS[k]].ok:
					mask |= 1 << k
				if ROWS[k] in pick.complaints:
					clues |= 1 << k
			var speech := int(not c.rows.speech.ok and v.row_seen("speech"))
			var crosses := speech
			for k in first.slice(0, v.patience):
				if crosses >= 2:
					break
				if k == 3:
					v.press()
				else:
					v.apply_check(TOOLS[k], "comply")
					v.complete_check(TOOLS[k])
				var surprise := v.roll_action(rng)
				if surprise == "snap":
					v.snap()
					v.shutter()
					break
				if surprise == "flare":
					v.flare()
				crosses = speech
				for j in 4:
					if v.row_seen(ROWS[j]) and not c.rows[ROWS[j]].ok:
						crosses += 1
			if v.in_exam():
				v.verdict("refer" if crosses >= 2 else "treat")
				if v.phase == Visit.Phase.ATTACK:
					v.shutter()
			var blind := Visit.new(c, db.rules)
			blind.surprises = v.surprises
			for entry in couriers:
				if entry["case"] == pick.id:
					blind.set_contact(entry)
			for entry in couriers:
				if blind.say_code(entry).result == "drop":
					break
			var blind_cross := speech
			var blind_rng := RandomNumberGenerator.new()
			blind_rng.seed = hash("routine:%d:%d" % [seed_id, idx])
			var shuffled := range(4)
			Shift._shuffle(shuffled, blind_rng)
			for k in first.slice(0, blind.patience):
				if blind_cross >= 2:
					break
				if k == 3:
					blind.press()
				else:
					blind.apply_check(TOOLS[k], "comply")
					blind.complete_check(TOOLS[k])
				var roll := blind.roll_action(blind_rng)
				if roll == "snap":
					blind.snap()
					blind.shutter()
					break
				if roll == "flare":
					blind.flare()
				blind_cross = speech
				for j in 4:
					if blind.row_seen(ROWS[j]) and not c.rows[ROWS[j]].ok:
						blind_cross += 1
			if blind.in_exam():
				blind.verdict("refer" if blind_cross >= 2 else "treat")
				if blind.phase == Visit.Phase.ATTACK:
					blind.shutter()
			out.store_csv_line(PackedStringArray([str(seed_id),str(idx),pick.id,str(c.fee),str(int(v.is_drifting())),str(mask),str(clues),str(speech),str(order[0]*64+order[1]*16+order[2]*4+order[3]),str(crosses),str(int(v.snapped)),str(int(v.flared)),str(int(v.is_correct(v.outcome))),str(v.credits_for(v.outcome)),str(int(c.attack.on_refer)),str(blind.credits_for(blind.outcome)+blind.drop_pay)]))
	out.close()
	print("Computed %d visits including %d later visitors." % [nights*5,nights*4])
	quit()
