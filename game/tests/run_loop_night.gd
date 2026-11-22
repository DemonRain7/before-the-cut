extends SceneTree
## Walk a full appointment sequence through the real title, counter and closing screens.
const Main = preload("res://scripts/ui/main.gd")
const Driver = preload("res://tests/play_driver.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.time_scale = 1.0
	var main: Main = load("res://scenes/main.tscn").instantiate()
	var night := "A"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-night="):
			night = arg.get_slice("=", 1)
	main.test_night = night
	main.training_enabled = false
	main.surprises_enabled = false
	main.beats_enabled = false
	root.add_child(main)
	await process_frame
	if main._patient_status == "checking":
		await main.patient_check_finished
	Engine.time_scale = 4.0
	var d := Driver.new(self, main)
	check(await d.open_counter(), "title leads to the counter")
	if main.shift == null:
		quit(1)
		return
	for idx in main.shift.count():
		check(await d.buzz_in(), "enter appointment")
		var v := main.visit
		await d.settle()
		var lamps := v.patience
		if idx == 0:
			d.pad("complain")
			await d.settle(30.0)
		elif idx == 1:
			main.act_say("What's bothering you?")
			await d.settle(30.0)
		elif idx == 2:
			main.act_say("Do your eyes hurt?")
			await d.settle(30.0)
		else:
			await d.complain()
		if night == "K" and idx < 3:
			check(not v.complaints_told.is_empty(), "chip, general text and part text deliver K's rows")
			if not v.complaints_told.is_empty():
				var line := Main.Lang.t(str(v.case_data.complaints[v.complaints_told[0]]))
				check(str(main.agent.last.get("reply", "")).contains(line), "mock and scripted fallback audibly name the delivered part")
		check(v.patience == lamps, "complaint is free")
		if idx == 0:
			main.act_say("Lovely music tonight.")
			check(await d.until(func()->bool: return not main._thinking and not main._lock, 30.0), "chat returns")
			await d.settle()
			check(v.patience == lamps, "chat is free")
		if idx == 0:
			var before := v.patience
			for phrase in ["Hello.", "What hurts?", "How have you slept?", "Check your port.", "Idiot.", "哪里不舒服？", "能看看你的手吗？", "昨晚睡得如何？"]:
				main.act_say(phrase)
				await d.settle(30.0)
				check(v.patience == before and v.press_count == 0 and v.in_exam(), "free text never controls the examination")
		await d.ask(0)
		await d.settle()
		check(v.answered.has(v.case_data.topics[0].id), "listed question receives an answer")
		await d.stamp("treat")
		check(await d.wait_for_slip() and await d.take_slip(), "settlement advances")
	check(main.state == Main.State.REPORT and main.screens.report.visits.size() == 5, "closing lists the entire night")
	print("RESULT: %d passed, %d failed" % [checks-failures, failures])
	await d.leave()
	quit(1 if failures else 0)
