extends SceneTree
## Render a reproducible closing film from real settlements, one PNG per frame at 12 fps.
## -- --out=<directory> --lang=zh [--less-blood]
const Reel = preload("res://scripts/ui/closing_reel.gd")
const DB = preload("res://scripts/core/case_db.gd")
const Visit = preload("res://scripts/core/visit_state.gd")
const Lang = preload("res://scripts/core/lang.gd")

var count := 0

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "" or DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(1)
		return
	Lang.pin(Lang.asked("en"))
	var db := DB.load_all()
	var records := []
	var cast := [["rook","stable"],["priya","drifting"],["lux","stable"],["vale","drifting"]]
	for member in cast:
		var c := DB.compose(db.templates[member[0]], {"truth":member[1]})
		var visit := Visit.new(c,db.rules)
		visit.verdict("refer" if member[0] == "vale" else "treat")
		if visit.phase == Visit.Phase.ATTACK:
			visit.shutter()
		records.append(visit.settlement())
	var reel := Reel.new()
	var cues := []
	reel.sound.connect(func(cue: String): cues.append({"frame":count, "cue":cue}))
	root.add_child(reel)
	reel.start(records, OS.get_cmdline_user_args().has("--less-blood"))
	reel.set_process(false)
	while reel.visible:
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		if picture.save_png(out.path_join("frame-%03d.png" % count)) != OK:
			quit(1)
			return
		count += 1
		reel._process(1.0 / 12.0)
	var sound_list := FileAccess.open(out.path_join("cues.json"), FileAccess.WRITE)
	if sound_list == null:
		quit(1)
		return
	sound_list.store_string(JSON.stringify(cues))
	sound_list.close()
	print("Rendered %d closing frames." % count)
	quit()
