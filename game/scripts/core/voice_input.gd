extends Node
## Push-to-talk microphone. The device is opened when the key goes down and closed when it comes
## up; it is never open otherwise. What it hears lives in one VoiceClip in memory until its words
## come back, and is then dropped. Nothing is saved to disk and nothing is played back.
##
## Opening the device is slow: on the Windows audio driver it takes about 450 ms (measured
## November 15, 2026). Done on the main thread that froze the whole game on every key press, so
## it is done on a worker thread instead. Until it is ready, `opening` is true and nothing is
## heard; the game says so. Letting go or throwing the clip away during that time closes the
## device as soon as it has opened.
##
## Uses the engine's direct input calls (AudioServer.set_input_device_active, get_input_frames),
## which need audio/driver/enable_input in project.godot. They are reached through call() so this
## file still loads on an engine that lacks them; problem() then says "unsupported".
## Tests set `simulated` and hand frames to feed(): no device is touched. `simulated_open_seconds`
## lets a test stand in for the slow open.
## Used as: const VoiceInput = preload("res://scripts/core/voice_input.gd")

const VoiceClip = preload("res://scripts/core/voice_clip.gd")

signal filled                     # the clip reached max_seconds while the key was still down
signal failed(reason: String)     # the device could not be opened after all: "open_failed"

var max_seconds: float = 10.0
var simulated: bool = false       # tests: no device, frames come from feed()
var simulated_rate: float = 48000.0
var simulated_open_seconds: float = 0.0   # tests: how long the simulated device takes to open
var listening: bool = false       # the key is held: a clip is wanted
var opening: bool = false         # wanted, but the device is not ready yet: nothing is heard
var level: float = 0.0            # 0..1 for the meter; falls back by itself

var _clip: VoiceClip = null
var _opened: bool = false         # the real device is open
var _open_thread: Thread = null   # opening the real device
var _open_left: float = 0.0       # simulated opening still to wait


## "" when a microphone can be tried, else why not: "disabled" | "unsupported".
func problem() -> String:
	if simulated:
		return ""
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		return "disabled"
	if not (AudioServer.has_method("set_input_device_active") and AudioServer.has_method("get_input_frames")):
		return "unsupported"
	return ""


## Asks for the microphone and a new clip. Returns "" or problem(). The device may still be
## opening when this returns (`opening`); a device that then fails to open emits `failed`.
func start() -> String:
	if listening:
		return ""
	var why := problem()
	if why != "":
		return why
	listening = true
	level = 0.0
	_clip = null
	if simulated:
		_open_left = simulated_open_seconds
		opening = _open_left > 0.0
		if not opening:
			_begin_clip(simulated_rate)
		return ""
	opening = true
	if _open_thread == null:
		# an open still running from a quick earlier press serves this one; otherwise start one
		_open_thread = Thread.new()
		if _open_thread.start(_open_device) != OK:
			_open_thread = null
			opening = false
			listening = false
			return "open_failed"
	return ""


func seconds() -> float:
	return _clip.seconds() if _clip != null else 0.0


## Closes the microphone and hands the clip over: {"wav", "seconds", "peak"}. {} if none was asked
## for. Let go while the device was still opening, the clip is empty (seconds 0).
func stop() -> Dictionary:
	if not listening:
		return {}
	if _clip == null:
		_end()
		return {"wav": PackedByteArray(), "seconds": 0.0, "peak": 0.0}
	if _opened:
		_clip.push(_pull())         # the last few frames, without announcing a full clip again
	var clip := _clip
	_end()
	return {"wav": clip.wav(), "seconds": clip.seconds(), "peak": clip.peak}


## Closes the microphone and throws the clip away.
func cancel() -> void:
	_end()


## Tests only: frames as the microphone would deliver them (at simulated_rate).
func feed(frames: PackedVector2Array) -> void:
	if listening and simulated and not opening:
		_take(frames)


func _process(delta: float) -> void:
	level = maxf(0.0, level - delta * 1.6)
	if _open_thread != null and not _open_thread.is_alive():
		_finish_open()
	if simulated and opening:
		_open_left -= delta
		if _open_left <= 0.0:
			opening = false
			_begin_clip(simulated_rate)
	if listening and _opened and not opening:
		_take(_pull())


func _exit_tree() -> void:
	if _open_thread != null:
		# at most one device open still running; the game is leaving anyway
		if int(_open_thread.wait_to_finish()) == OK:
			_opened = true                 # so _end below lets go of it
		_open_thread = null
	listening = false
	_end()


## Runs on the worker thread: nothing but the driver call.
func _open_device() -> int:
	return int(AudioServer.call("set_input_device_active", true))


## Main thread, once the worker is done: keep the device for the clip, or close it again.
func _finish_open() -> void:
	var err := int(_open_thread.wait_to_finish())
	_open_thread = null
	if err == OK:
		_opened = true
	if not listening:
		_close_device()             # let go or thrown away while it was opening
		return
	opening = false
	if err != OK:
		_close_device()
		listening = false
		failed.emit("open_failed")
		return
	_pull()                         # anything already waiting was not said into this clip
	_begin_clip(float(AudioServer.call("get_input_mix_rate")))


func _begin_clip(rate: float) -> void:
	_clip = VoiceClip.new(rate, max_seconds)
	level = 0.0


func _end() -> void:
	# an open still running on the worker is closed by _finish_open when it is done
	if _open_thread == null:
		_close_device()
	_clip = null
	listening = false
	opening = false
	_open_left = 0.0
	level = 0.0


func _close_device() -> void:
	if _opened:
		AudioServer.call("set_input_device_active", false)
		_opened = false


func _pull() -> PackedVector2Array:
	var waiting: int = int(AudioServer.call("get_input_frames_available"))
	if waiting <= 0:
		return PackedVector2Array()
	return AudioServer.call("get_input_frames", waiting)


func _take(frames: PackedVector2Array) -> void:
	if _clip == null or frames.is_empty():
		return
	var loud: float = _clip.push(frames)
	level = maxf(level, meter(loud))
	if _clip.full():
		filled.emit()


## Loudness on a decibel scale, so speech fills most of the meter and room noise only its foot.
static func meter(loud: float) -> float:
	return clampf((linear_to_db(maxf(loud, 0.00001)) + 54.0) / 48.0, 0.0, 1.0)
