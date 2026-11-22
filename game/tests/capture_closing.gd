extends SceneTree
## Render the closing film from real settlements: one PNG per frame at a fixed rate, and the
## sound cues with the frame each one starts on.
##   -- --out=<directory> [--night=mixed|incidents|refused|death|first] [--fps=12]
##      [--lang=zh] [--less-blood] [--dry] [--shot=N]
## --dry steps the whole film and writes only the cues and the shot list (it works headless).
## --shot=N skips to shot N (from 0) and stops when it ends.
## Frames need the real renderer: run it on the hidden desktop (tools/run_hidden.py).
const Film = preload("res://scripts/ui/closing_film.gd")
const DB = preload("res://scripts/core/case_db.gd")
const Visit = preload("res://scripts/core/visit_state.gd")
const Lang = preload("res://scripts/core/lang.gd")

## Each night is [patient, truth, what the doctor did] in the order they were seen.
## mixed: repairs, one patient who wakes on the table, and a call to Trauma Team.
## incidents: four dangerous admissions and one good repair. refused: nobody admitted.
## death: a repair, then the doctor is killed at the glass. first: killed by the first patient.
const NIGHTS := {
	"mixed": [["rook", "stable", "treat"], ["priya", "drifting", "treat"], ["lux", "stable", "treat"],
		["vale", "drifting", "refer"], ["juno", "stable", "treat"]],
	"incidents": [["kip", "drifting", "treat"], ["maren", "drifting", "treat"], ["dana", "stable", "treat"],
		["juno", "drifting", "treat"], ["lux", "drifting", "treat"]],
	"refused": [["rook", "stable", "refer"], ["priya", "drifting", "shutter"], ["bo", "stable", "shutter"],
		["ozzie", "stable", "walkout"], ["dana", "stable", "gave_up"], ["vale", "drifting", "caught"]],
	"death": [["rook", "stable", "treat"], ["bo", "drifting", "hit"]],
	"first": [["ozzie", "drifting", "hit"]],
}
## How many were still waiting when the doctor died.
const UNSEEN := {"death": 3, "first": 4}

var count := 0


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var out := ""
	var night := "mixed"
	var fps := 12
	var only := -1
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--night="):
			night = arg.trim_prefix("--night=")
		elif arg.begins_with("--fps="):
			fps = maxi(1, int(arg.trim_prefix("--fps=")))
		elif arg.begins_with("--shot="):
			only = int(arg.trim_prefix("--shot="))
	var dry := args.has("--dry")
	if out == "" or not NIGHTS.has(night) or DirAccess.make_dir_recursive_absolute(out) != OK:
		push_error("capture_closing: give --out=<directory> and a known --night")
		quit(1)
		return
	Lang.pin(Lang.asked("en"))
	var db := DB.load_all()
	var records := []
	var cases := {}
	for member in NIGHTS[night]:
		var id := str(member[0])
		var c := DB.compose(db.templates[id], {"truth": str(member[1])})
		DB.resolve_parts(c, db.parts)
		cases[id] = c
		records.append(_settle(c, db.rules, str(member[2])))
	var film := Film.new()
	var cues := []
	film.sound.connect(func(cue: String, pitch: float, level: float): cues.append({"frame": count, "cue": cue, "pitch": pitch, "db": level}))
	film.loop_sound.connect(func(cue: String, on: bool, level: float): cues.append({"frame": count, "loop": cue, "on": on, "db": level}))
	root.add_child(film)
	film.set_process(false)
	film.start(records, args.has("--less-blood"), cases, {}, int(UNSEEN.get(night, 0)))
	var shots: Array = []
	for s in film.shots:
		shots.append({"kind": s.kind, "id": s.id, "outcome": s.outcome, "relief": s.relief})
	var starts := []
	var last := -1
	if only >= 0:
		while film.visible and film.index < only:
			film.advance()
	while film.visible and (only < 0 or film.index == only):
		if film.index != last:
			last = film.index
			starts.append(count)
		if not dry:
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			if picture.save_png(out.path_join("frame-%04d.png" % count)) != OK:
				quit(1)
				return
		count += 1
		film.step(1.0 / float(fps))
	var log := FileAccess.open(out.path_join("cues.json"), FileAccess.WRITE)
	if log == null:
		quit(1)
		return
	log.store_string(JSON.stringify({"night": night, "fps": fps, "shots": shots, "starts": starts, "cues": cues}, "\t"))
	log.close()
	print("Closing film, night %s: %d shots, %d frames at %d fps%s." % [night, shots.size(), count, fps, " (dry)" if dry else ""])
	quit()


## What the doctor did with one patient, settled as the game settles it.
func _settle(c: Dictionary, rules: Dictionary, act: String) -> Dictionary:
	var visit := Visit.new(c, rules)
	match act:
		"treat":
			visit.verdict("treat")
		"refer":
			visit.verdict("refer")
			if visit.phase == Visit.Phase.ATTACK:
				visit.shutter()
		"shutter":
			visit.shutter()
		"caught", "hit":
			# the patient turned under pressure: the shutter came down in time, or it did not
			visit.phase = Visit.Phase.ATTACK
			visit.attack_cause = "press"
			if act == "caught":
				visit.shutter()
			else:
				visit.attack_timeout()
		_:
			visit._finish(act)       # walkout, gave_up
	return visit.settlement()
