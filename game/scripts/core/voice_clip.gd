extends RefCounted
## One push-to-talk clip, held in memory only: mono, 16 kHz, 16-bit samples.
## The microphone hands over stereo frames at the sound card's own rate. push() averages them down
## as they arrive, so nothing bigger than the finished clip is ever kept. Nothing is written to disk.
## Used as: const VoiceClip = preload("res://scripts/core/voice_clip.gd")

const RATE := 16000              # the proxy accepts exactly this rate (agent_proxy/src/core.mjs AUDIO_RATE)
const HEADER := 44

var max_seconds: float = 10.0
var peak: float = 0.0            # the loudest sample so far, 0..1

var _in_rate: float = 44100.0
var _pcm: PackedByteArray = PackedByteArray()
var _count: int = 0              # samples written
var _phase: float = 0.0          # how much of the sample being built is already filled, 0..1
var _sum: float = 0.0


func _init(in_rate: float = 44100.0, p_max_seconds: float = 10.0) -> void:
	_in_rate = maxf(in_rate, 1000.0)
	max_seconds = maxf(p_max_seconds, 0.1)
	_pcm.resize(max_samples() * 2)


func max_samples() -> int:
	return int(round(max_seconds * RATE))


func count() -> int:
	return _count


func seconds() -> float:
	return float(_count) / float(RATE)


func full() -> bool:
	return _count >= max_samples()


func sample(index: int) -> int:
	return _pcm.decode_s16(index * 2)


## Adds microphone frames (left and right in x and y, -1..1). Returns the loudest of them, 0..1.
## Each frame is spread over the 16 kHz samples it overlaps, so any input rate comes out at the
## right speed: three 48 kHz frames make one sample, and one 8 kHz frame makes two.
func push(frames: PackedVector2Array) -> float:
	var loud := 0.0
	var step: float = float(RATE) / _in_rate      # how much of one output sample a frame covers
	var limit: int = max_samples()
	for frame in frames:
		if _count >= limit:
			break
		var mono: float = (frame.x + frame.y) * 0.5
		loud = maxf(loud, absf(mono))
		var left: float = step
		while left > 0.0 and _count < limit:
			var take: float = minf(1.0 - _phase, left)
			_sum += mono * take
			_phase += take
			left -= take
			if _phase >= 0.999999:
				_pcm.encode_s16(_count * 2, int(round(clampf(_sum, -1.0, 1.0) * 32767.0)))
				_count += 1
				_phase = 0.0
				_sum = 0.0
	peak = maxf(peak, minf(loud, 1.0))
	return minf(loud, 1.0)


## The clip as a plain WAV file in memory: a 44-byte header, then the samples.
func wav() -> PackedByteArray:
	return make_wav(_pcm.slice(0, _count * 2))


static func make_wav(pcm: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(HEADER)
	_tag(out, 0, "RIFF")
	out.encode_u32(4, 36 + pcm.size())
	_tag(out, 8, "WAVE")
	_tag(out, 12, "fmt ")
	out.encode_u32(16, 16)           # size of the format block
	out.encode_u16(20, 1)            # PCM
	out.encode_u16(22, 1)            # mono
	out.encode_u32(24, RATE)
	out.encode_u32(28, RATE * 2)     # bytes per second
	out.encode_u16(32, 2)            # bytes per sample
	out.encode_u16(34, 16)           # bits per sample
	_tag(out, 36, "data")
	out.encode_u32(40, pcm.size())
	out.append_array(pcm)
	return out


static func _tag(buffer: PackedByteArray, at: int, word: String) -> void:
	for i in 4:
		buffer[at + i] = word.unicode_at(i)
