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
# One PCM producer owns the ring-buffer writer. Never access Nodes or load
# resources on this thread; prepare banks on the main thread before starting it.
var _worker: Thread
var _mutex := Mutex.new()
var _worker_exit := false
var _capacity := 0
var effect_players: Array[AudioStreamPlayer] = []
var effect_cursor := 0
var effects_volume := 1.0
const PUMP_INTERVAL_MS := 4

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
	for i in 3:
		var effect_player := AudioStreamPlayer.new()
		add_child(effect_player)
		effect_players.append(effect_player)

func configure(genre: int, bpm: int, events: Array, music_version: int = NBMusicEngine.MUSIC_VERSION, song_seed: int = 0) -> void:
	_stop_worker()
	mixer.setup(genre, bpm, events, music_version, song_seed)
	start()

func start() -> void:
	_stop_worker()
	player.stop()
	player.stream_paused = false
	mixer.reset()
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	running = playback != null
	_capacity = playback.get_frames_available() if running else 0
	focus_blocked = not focus.request_focus()
	paused = focus_blocked
	player.stream_paused = paused
	if focus_blocked:
		call_deferred("_report_denied_focus")
	_pump()
	_start_worker()

func stop() -> void:
	_stop_effects()
	_stop_worker()
	running = false
	paused = false
	focus_blocked = false
	player.stream_paused = false
	player.stop()
	focus.abandon_focus()

func pause_playback() -> void:
	_stop_effects()
	_stop_worker()
	paused = true
	player.stream_paused = true
	focus.abandon_focus()

func resume_playback() -> bool:
	if not running:
		return true # A failed stage has no audio until the next attempt.
	focus_blocked = not focus.request_focus()
	paused = focus_blocked
	player.stream_paused = paused
	_start_worker()
	return not focus_blocked

func _on_focus_interrupted(change: int) -> void:
	if not running:
		return
	_stop_worker()
	_stop_effects()
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
	_stop_worker()
	var was_paused := paused
	player.stop()
	mixer.seek_frame(roundi(maxf(0.0, seconds) * float(NBMusicEngine.RATE)))
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	running = playback != null
	paused = was_paused
	player.stream_paused = was_paused
	_pump()
	_start_worker()

func set_events(events: Array) -> void:
	_mutex.lock()
	mixer.set_events(events)
	_mutex.unlock()

func effect(effect_name: String) -> void:
	if not running or paused or muted or effects_volume <= 0 or effect_name not in NBMusicEngine.VOICES:
		return
	# Transients go directly to the native mixer, not behind 180 ms of song PCM.
	var output := effect_players[effect_cursor]
	effect_cursor = (effect_cursor + 1) % effect_players.size()
	output.stream = load("res://audio/%d/%s.wav" % [mixer.genre, effect_name])
	output.volume_db = linear_to_db(effects_volume * 0.5)
	output.play()

func _stop_effects() -> void:
	for output in effect_players:
		output.stop()

func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	for output in effect_players:
		output.volume_db = linear_to_db(maxf(effects_volume * 0.5, 0.0001))

func set_music_volume(value: float) -> void:
	_mutex.lock()
	mixer.music_volume = clampf(value, 0.0, 1.0)
	_mutex.unlock()

func _process(_delta: float) -> void:
	# Explicit fallback only if this platform cannot create a worker thread.
	if _worker == null:
		_pump()

func _start_worker() -> void:
	if not running or paused or _worker != null:
		return
	_worker_exit = false
	_worker = Thread.new()
	if _worker.start(_mix_worker) != OK:
		_worker = null
		push_warning("PCM worker unavailable; using frame-driven fallback")

func _stop_worker() -> void:
	if _worker == null:
		return
	_mutex.lock()
	_worker_exit = true
	_mutex.unlock()
	_worker.wait_to_finish() # Never join while holding the producer's mutex.
	_worker = null

func _mix_worker() -> void:
	while true:
		_mutex.lock()
		if _worker_exit:
			_mutex.unlock()
			return
		_fill_buffer_locked()
		_mutex.unlock()
		OS.delay_msec(PUMP_INTERVAL_MS)

func _fill_buffer_locked() -> void:
	# Godot consumes this SPSC ring on its audio thread. Only this serialized
	# producer writes it. Stop/join BEFORE replacing playback or mixer state.
	var available := playback.get_frames_available()
	while available > 0:
		var count := mini(available, 512)
		var chunk := mixer.mix(count)
		if muted:
			chunk.fill(Vector2.ZERO)
		if not playback.push_buffer(chunk):
			break
		available -= count

func _pump() -> void:
	if not running or paused or playback == null:
		return
	_mutex.lock()
	_fill_buffer_locked()
	_mutex.unlock()

func rendered_frames() -> int:
	_mutex.lock()
	var result := mixer.frame
	_mutex.unlock()
	return result

func elapsed_seconds() -> float:
	return float(rendered_frames()) / float(NBMusicEngine.RATE)

func transport_seconds() -> float:
	# Exclude queued PCM: the visual pulse must not lead by a whole buffer.
	_mutex.lock()
	var queued := _capacity - playback.get_frames_available() if running and playback != null else 0
	var result := float(maxi(0, mixer.frame - queued)) / float(NBMusicEngine.RATE)
	_mutex.unlock()
	return result

func worker_active() -> bool:
	return _worker != null and _worker.is_alive()

func _exit_tree() -> void:
	_stop_worker()

func export_wav(events: Array, genre: int, bpm: int, out_path: String, music_version: int = NBMusicEngine.MUSIC_VERSION, song_seed: int = 0) -> bool:
	var renderer := NBMusicEngine.new()
	renderer.setup(genre, bpm, events, music_version, song_seed)
	var total := renderer.get_loop_frame_count()
	var temporary := out_path + ".tmp"
	var f := FileAccess.open(temporary, FileAccess.WRITE)
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
	f.flush()
	var error := f.get_error()
	f.close()
	if error == OK and FileAccess.get_file_as_bytes(temporary).size() == 44 + total * 4:
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(out_path)) == OK:
			return true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return false
