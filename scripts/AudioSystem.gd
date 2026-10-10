class_name NBAudioSystem
extends Node

signal focus_interrupted(change: int)

var focus: NBAndroidAudioFocus
var focus_blocked := false
var mixer := NBMusicEngine.new()
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var running := false
var muted := false
var paused := false

func _ready() -> void:
	focus = NBAndroidAudioFocus.new()
	add_child(focus)
	focus.focus_lost.connect(_on_focus_interrupted)
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
	focus_blocked = not focus.request_focus()
	paused = focus_blocked
	player.stream_paused = paused
	if focus_blocked:
		call_deferred("_report_denied_focus")
	_pump()

func stop() -> void:
	running = false
	paused = false
	focus_blocked = false
	player.stream_paused = false
	player.stop()
	focus.abandon_focus()

func pause_playback() -> void:
	paused = true
	player.stream_paused = true
	focus.abandon_focus()

func resume_playback() -> bool:
	if not running:
		return true # A failed stage has no audio until the next attempt.
	focus_blocked = not focus.request_focus()
	paused = focus_blocked
	player.stream_paused = paused
	return not focus_blocked

func _on_focus_interrupted(change: int) -> void:
	if not running:
		return
	focus_blocked = true
	paused = true
	player.stream_paused = true
	focus_interrupted.emit(change)

func _report_denied_focus() -> void:
	if running and focus_blocked:
		focus_interrupted.emit(NBAndroidAudioFocus.FOCUS_LOSS)

# Recreate the in-flight sequencer position after restoration. Never attempt
# to buffer minutes of audio just to reach the saved musical transport frame.
func seek_seconds(seconds: float) -> void:
	if not running or playback == null:
		return
	var was_paused := paused
	player.stop()
	mixer.seek_frame(roundi(maxf(0.0, seconds) * float(NBMusicEngine.RATE)))
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	running = playback != null
	paused = was_paused
	player.stream_paused = was_paused
	_pump()

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
