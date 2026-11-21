extends Node
## Plays the generated sound effects and the looping ambience.
## Every sound is optional: a missing file is skipped silently, so the game also runs with
## the audio folder removed.

const DIR := "res://assets/audio/"
const VOICES := 18
const DUCK_DB := -18.0           # how far everything drops while the microphone is open
# SOUND on the title card's SETTINGS page: off, then a quarter, half, three quarters and all of it
const VOLUME_STEPS := [0.0, 0.25, 0.5, 0.75, 1.0]

var muted: bool = false
var volume_step: int = 4         # of VOLUME_STEPS; 0 silences the master bus (M mutes on top of it)
## Added to every sound started while it is set. The attack runs under it, so the loudest
## moment of the night stands out from the room without being pressed into the limiter.
var trim_db: float = 0.0
var _duck: bool = false
var _duck_db: float = 0.0
var _streams: Dictionary = {}
var _pool: Array = []
var _next: int = 0
var _loops: Dictionary = {}
var _loop_trim: Dictionary = {}    # the trim each loop was started under
var _fades: Dictionary = {}        # voice -> {left, total, from}: one-shots being faded out


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_limit_master()


## Many loud one-shots overlap during an attack (screams, hits, glass, the alarm). A limiter on
## the master bus keeps their sum from clipping, whatever happens to be playing.
func _limit_master() -> void:
	if AudioServer.get_bus_effect_count(0) > 0:
		return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	lim.release = 0.12
	AudioServer.add_bus_effect(0, lim)


## While the player's microphone is open the clinic goes quiet, so the clip holds the player's
## voice and not the rain. It comes back by itself when the microphone closes.
func duck(on: bool) -> void:
	_duck = on


func _process(delta: float) -> void:
	_run_fades(delta)
	var target: float = DUCK_DB if _duck else 0.0
	if is_equal_approx(_duck_db, target):
		return
	_duck_db = move_toward(_duck_db, target, delta * 120.0)
	_apply_bus()


## The player's volume (SETTINGS: SOUND), on the master bus under the ducking. Step 0 is off.
func set_volume_step(step: int) -> void:
	volume_step = clampi(step, 0, VOLUME_STEPS.size() - 1)
	_apply_bus()


## The master bus's level in dB from the volume alone: 0 at full, and -80 for off.
func volume_db() -> float:
	var level := float(VOLUME_STEPS[volume_step])
	return linear_to_db(level) if level > 0.0 else -80.0


func _apply_bus() -> void:
	AudioServer.set_bus_volume_db(0, _duck_db + (volume_db() if volume_step > 0 else 0.0))
	AudioServer.set_bus_mute(0, volume_step == 0)


## Every voice still playing `sound` fades to nothing over `seconds` and stops, instead of
## being cut off mid-wave. A voice that is reused for another sound meanwhile is let go.
func fade_out(sound: String, seconds: float = 0.12) -> void:
	var s := _stream(sound)
	if s == null:
		return
	for v in _pool:
		var p: AudioStreamPlayer = v
		if p.playing and p.stream == s and not _fades.has(p):
			_fades[p] = {"left": maxf(seconds, 0.01), "total": maxf(seconds, 0.01), "from": p.volume_db}


func fading() -> int:
	return _fades.size()


func _run_fades(delta: float) -> void:
	for v in _fades.keys():
		var p: AudioStreamPlayer = v
		var f: Dictionary = _fades[p]
		f["left"] = float(f["left"]) - delta
		if float(f["left"]) <= 0.0 or not p.playing:
			p.stop()
			p.volume_db = float(f["from"])
			_fades.erase(p)
			continue
		var k := float(f["left"]) / float(f["total"])
		p.volume_db = linear_to_db(db_to_linear(float(f["from"])) * k)


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		var s: AudioStream = null
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
		_streams[sound] = s
	return _streams[sound]


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted:
		return
	var s := _stream(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	_fades.erase(p)
	p.stream = s
	p.pitch_scale = maxf(0.05, pitch)
	p.volume_db = volume_db + trim_db
	p.play()


func loop(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _loops.has(sound):
		var existing: AudioStreamPlayer = _loops[sound]
		existing.volume_db = volume_db + float(_loop_trim.get(sound, 0.0))
		return
	var s := _stream(sound)
	if s == null:
		return
	var wav := s.duplicate() as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		s = wav
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = s
	p.volume_db = volume_db + trim_db
	p.pitch_scale = pitch
	_loops[sound] = p
	_loop_trim[sound] = trim_db
	if not muted:
		p.play()


func stop_loop(sound: String) -> void:
	if _loops.has(sound):
		var p: AudioStreamPlayer = _loops[sound]
		p.stop()
		p.queue_free()
		_loops.erase(sound)
		_loop_trim.erase(sound)


func set_loop_volume(sound: String, volume_db: float) -> void:
	if _loops.has(sound):
		var p: AudioStreamPlayer = _loops[sound]
		p.volume_db = volume_db + float(_loop_trim.get(sound, 0.0))


func stop_all() -> void:
	_fades.clear()
	for p in _pool:
		(p as AudioStreamPlayer).stop()
	for k in _loops.keys():
		stop_loop(str(k))


func set_muted(m: bool) -> void:
	muted = m
	for k in _loops.keys():
		var p: AudioStreamPlayer = _loops[k]
		if m:
			p.stop()
		elif not p.playing:
			p.play()
