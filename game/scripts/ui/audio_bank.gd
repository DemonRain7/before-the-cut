extends Node
## Plays the generated sound effects and the looping ambience.
## Every sound is optional: a missing file is skipped silently, so the game also runs with
## the audio folder removed.

const DIR := "res://assets/audio/"
const VOICES := 18
const DUCK_DB := -18.0           # how far everything drops while the microphone is open

var muted: bool = false
var _duck: bool = false
var _duck_db: float = 0.0
var _streams: Dictionary = {}
var _pool: Array = []
var _next: int = 0
var _loops: Dictionary = {}


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
	var target: float = DUCK_DB if _duck else 0.0
	if is_equal_approx(_duck_db, target):
		return
	_duck_db = move_toward(_duck_db, target, delta * 120.0)
	AudioServer.set_bus_volume_db(0, _duck_db)


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
	p.stream = s
	p.pitch_scale = maxf(0.05, pitch)
	p.volume_db = volume_db
	p.play()


func loop(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _loops.has(sound):
		var existing: AudioStreamPlayer = _loops[sound]
		existing.volume_db = volume_db
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
	p.volume_db = volume_db
	p.pitch_scale = pitch
	_loops[sound] = p
	if not muted:
		p.play()


func stop_loop(sound: String) -> void:
	if _loops.has(sound):
		var p: AudioStreamPlayer = _loops[sound]
		p.stop()
		p.queue_free()
		_loops.erase(sound)


func set_loop_volume(sound: String, volume_db: float) -> void:
	if _loops.has(sound):
		var p: AudioStreamPlayer = _loops[sound]
		p.volume_db = volume_db


func stop_all() -> void:
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
