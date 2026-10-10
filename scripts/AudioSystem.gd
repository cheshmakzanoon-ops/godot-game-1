class_name NBAudioSystem
extends Node

var mixer := NBMusicEngine.new()
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var running := false
var muted := false
var paused := false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = NBMusicEngine.RATE
	generator.buffer_length = 0.18
	player.stream = generator
	add_child(player)

func configure(genre: int, bpm: int, events: Array, music_version: int = NBMusicEngine.MUSIC_VERSION, song_seed: int = 0) -> void:
	mixer.setup(genre, bpm, events, music_version, song_seed)
	start()

func start() -> void:
	player.stop()
	player.stream_paused = false
	mixer.reset()
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	running = playback != null
	paused = false
	_pump()

func stop() -> void:
	running = false
	paused = false
	player.stream_paused = false
	player.stop()

func pause_playback() -> void:
	paused = true
	player.stream_paused = true

func resume_playback() -> void:
	player.stream_paused = false
	paused = false

func set_events(events: Array) -> void:
	mixer.set_events(events)

func effect(effect_name: String) -> void:
	if running and not muted:
		mixer.trigger_effect(effect_name, 0.5)

func set_music_volume(value: float) -> void:
	mixer.music_volume = clampf(value, 0.0, 1.0)

func _process(_delta: float) -> void:
	_pump()

func _pump() -> void:
	if not running or paused or playback == null:
		return
	var available := playback.get_frames_available()
	while available > 0:
		var count := mini(available, 512)
		var chunk := mixer.mix(count)
		if muted:
			chunk.fill(Vector2.ZERO)
		playback.push_buffer(chunk)
		available -= count

func elapsed_seconds() -> float:
	return float(mixer.frame) / float(NBMusicEngine.RATE)

func export_wav(events: Array, genre: int, bpm: int, out_path: String, music_version: int = NBMusicEngine.MUSIC_VERSION, song_seed: int = 0) -> bool:
	var renderer := NBMusicEngine.new()
	renderer.setup(genre, bpm, events, music_version, song_seed)
	var total := renderer.get_loop_frame_count()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return false
	# Standard PCM RIFF, 16-bit, stereo, 22,050Hz.
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + total * 4)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(NBMusicEngine.RATE)
	f.store_32(NBMusicEngine.RATE * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(total * 4)
	var remaining := total
	while remaining > 0:
		var frames := renderer.mix(mini(remaining, 2048))
		var bytes := PackedByteArray()
		bytes.resize(frames.size() * 4)
		for i in frames.size():
			bytes.encode_s16(i * 4, clampi(roundi(frames[i].x * 32767.0), -32768, 32767))
			bytes.encode_s16(i * 4 + 2, clampi(roundi(frames[i].y * 32767.0), -32768, 32767))
		f.store_buffer(bytes)
		remaining -= frames.size()
	f.close()
	return true
