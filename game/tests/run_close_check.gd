extends SceneTree
## Checks that the game leaves cleanly when its window is asked to close.
##
## Headless only: it opens no window, makes no sound and never opens a microphone. It refuses to
## run any other way, because it leaves the game's ambience playing on purpose.
##   godot --headless --verbose --path game --script res://tests/run_close_check.gd
## The run passes when the last line is "RESULT: 5 passed, 0 failed", the exit code is 0 and
## the engine's own exit report (--verbose) lists no "Leaked instance".
## This is an automated check, not a playtest.

const MainScript = preload("res://scripts/ui/main.gd")

var main: MainScript = null
var passed: int = 0
var failed: int = 0
var asked_at: int = -1
var timed_out: bool = false


func _initialize() -> void:
	# If the game never leaves, nothing else would end this run.
	create_timer(20.0, true, false, true).timeout.connect(_on_watchdog)
	_run()


func _on_watchdog() -> void:
	timed_out = true
	quit(2)


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("    FAILED: %s" % label)


func _run() -> void:
	print("Before the Cut - window close check (automated run, not a playtest)")
	if DisplayServer.get_name() != "headless":
		print("RESULT: not run. Start this check with --headless.")
		asked_at = -2
		quit(2)
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = (packed.instantiate() if packed != null else null) as MainScript
	if main == null:
		print("RESULT: could not load scenes/main.tscn")
		asked_at = -2
		quit(1)
		return
	root.add_child(main)
	await process_frame
	main.mic.simulated = true      # an automated run never opens a microphone
	for i in 30:
		await process_frame
	check(not auto_accept_quit, "the game answers the close request itself")
	check(main.audio._loops.size() >= 2, "the rain and the hum are running on the title screen")
	asked_at = Time.get_ticks_msec()
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(main._closing and main.audio.muted and main.audio._loops.is_empty(), "every sound stops at once")
	var still: int = 0
	for p in main.audio._pool:
		if (p as AudioStreamPlayer).playing:
			still += 1
	check(still == 0, "no one-shot sound is left playing")
	# from here on the game is expected to leave by itself: see _finalize()


func _finalize() -> void:
	if asked_at == -2:
		return
	var waited: int = Time.get_ticks_msec() - asked_at
	if timed_out or asked_at < 0:
		failed += 1
		print("    FAILED: the game leaves by itself")
	else:
		check(waited >= int(MainScript.CLOSE_HOLD * 1000.0) - 20 and waited < 3000,
			"the game leaves by itself a moment later (%d ms)" % waited)
		print("  left %d ms after the request" % waited)
	print("")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)      # the loop has already ended; this only replaces the exit code the game left with
