class_name NBMusicEngine
extends RefCounted

# One-shot PCM playback with a sample-position sequencer. Live and offline
# renderers use the same mixer, event grammar and deterministic clock.
const RATE := 22050
const STEPS := 16
const BARS := 4
const VOICES := ["kick", "snare", "hat", "perc", "bass", "lead", "chord", "click", "crash", "fail"]
const ROOT_MIDI := [45, 48, 43, 46, 45]
const CHORD_ROOTS := [0, -4, 3, -2]
const PENTATONIC := [0, 3, 5, 7, 10, 12]

var bank: Dictionary = {}
var events: Array = []
var bpm := 120
var genre := 0
var frame := 0
var step_cursor := 0
var frames_per_step := 2756.25
var active: Array = []
var music_volume := 0.72

func setup(next_genre: int, next_bpm: int, event_data: Array = []) -> void:
	var previous_genre := genre
	genre = clampi(next_genre, 0, 4)
	bpm = maxi(next_bpm, 50)
	frames_per_step = float(RATE) * 60.0 / float(bpm) / 4.0
	events = event_data.duplicate(true)
	if bank.is_empty() or genre != previous_genre:
		bank.clear()
		for voice in VOICES:
			var path := "res://audio/%d/%s.wav" % [genre, voice]
			var wav: AudioStreamWAV = load(path)
			if wav == null:
				push_warning("Missing synth sound: " + path)
				continue
			var bytes := wav.data
			var samples := PackedFloat32Array()
			samples.resize(int(bytes.size() / 2))
			for i in samples.size():
				samples[i] = float(bytes.decode_s16(i * 2)) / 32768.0
			bank[voice] = samples
	reset()

func reset() -> void:
	frame = 0
	step_cursor = 0
	active.clear()

func set_events(next_events: Array) -> void:
	events = next_events.duplicate(true)

func trigger_effect(name: String, gain: float = 0.5) -> void:
	_spawn(name, 0, gain)

func get_length_seconds() -> float:
	return 4.0 * 4.0 * 60.0 / float(bpm)

func get_loop_frame_count() -> int:
	return roundi(float(RATE) * get_length_seconds())

func _spawn(voice: String, semitones: int, gain: float) -> void:
	if not bank.has(voice):
		return
	if active.size() >= 16:
		active.pop_front()
	active.append({"data": bank[voice], "pos": 0.0, "rate": pow(2.0, float(semitones) / 12.0), "gain": gain})

func _on_step(abs_step: int) -> void:
	var bar := int(abs_step / STEPS) % BARS
	var step := abs_step % STEPS
	var root: int = int(ROOT_MIDI[genre]) + int(CHORD_ROOTS[bar])
	# Anchoring groove is intentionally modest; shot-authored events dominate.
	if step == 0 or step == 8:
		_spawn("kick", 0, 0.24)
	elif step == 4 or step == 12:
		_spawn("snare", 0, 0.19)
	elif step % 4 == 2:
		_spawn("hat", 0, 0.09)
	for event in events:
		if int(event.get("step", -1)) != step:
			continue
		var layer := int(event.get("layer", 0))
		var order := int(event.get("order", 0))
		var velocity := clampf(float(event.get("velocity", 0.7)), 0.1, 1.0)
		match layer:
			0:
				var voice := "kick" if step % 8 == 0 else ("snare" if step % 4 == 0 else ("hat" if order % 2 == 0 else "perc"))
				_spawn(voice, 0, velocity * 0.32)
			1:
				var semitone := 0 if step % 4 == 0 else (7 if order % 2 == 0 else 12)
				_spawn("bass", root + semitone - 45, velocity * 0.30)
			2:
				var interval: int = PENTATONIC[posmod(order + bar + int(step / 3), PENTATONIC.size())]
				_spawn("lead", root + 24 + interval - 69, velocity * 0.26)
			3:
				for semitone in [0, 3, 7]:
					_spawn("chord", root + 24 + semitone - 60, velocity * 0.11)
				if step >= 12 and order % 3 == 0:
					_spawn("perc", 0, velocity * 0.15)

func mix(count: int) -> PackedVector2Array:
	var buffer := PackedVector2Array()
	buffer.resize(count)
	for i in count:
		if frame >= roundi(float(step_cursor) * frames_per_step):
			_on_step(step_cursor)
			step_cursor += 1
		var sum := 0.0
		for index in range(active.size() - 1, -1, -1):
			var voice: Dictionary = active[index]
			var data: PackedFloat32Array = voice["data"]
			var position: float = voice["pos"]
			var j := int(position)
			if j >= data.size() - 1:
				active.remove_at(index)
				continue
			var frac := position - j
			sum += lerpf(data[j], data[j + 1], frac) * float(voice["gain"])
			voice["pos"] = position + float(voice["rate"])
		# Bounded soft saturation avoids digital clipping even on busy DROP notes.
		var limited := (sum * music_volume) / (1.0 + absf(sum * music_volume))
		buffer[i] = Vector2(limited, limited)
		frame += 1
	return buffer
