extends Node

# DEBUG-ONLY Android runtime QA. Launch via adb with:
#   am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
#     -p com.needlebeat.drop --es needlebeat.qa wav_share
# An ordinary player launch, or any release build, never runs this probe.
const EXTRA := "needlebeat.qa"
const COMMAND := "wav_share"
const CHECKPOINT_COMMAND := "checkpoint_seed"
const PROBE_WAV := "user://exports/needlebeat_qa_smoke.wav"

func _ready() -> void:
	if OS.get_name() != "Android" or not OS.has_feature("debug"):
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		printerr("NEEDLEBEAT_QA_RUNTIME_UNAVAILABLE")
		return
	var activity = runtime.getActivity()
	if activity == null:
		printerr("NEEDLEBEAT_QA_ACTIVITY_UNAVAILABLE")
		return
	var intent = activity.getIntent()
	if intent == null:
		return
	var instruction := str(intent.getStringExtra(EXTRA))
	if instruction == COMMAND:
		call_deferred("_test_wav_share")
	elif instruction == CHECKPOINT_COMMAND:
		call_deferred("_seed_recovery_checkpoint")

func _test_wav_share() -> void:
	var parent = get_parent()
	if parent == null or parent.audio == null:
		printerr("NEEDLEBEAT_QA_AUDIO_UNAVAILABLE")
		return
	var events := [
		{"layer": 0, "step": 0, "order": 0, "velocity": 0.90},
		{"layer": 0, "step": 8, "order": 1, "velocity": 0.80},
		{"layer": 1, "step": 0, "order": 0, "velocity": 0.70},
		{"layer": 2, "step": 4, "order": 0, "velocity": 0.85},
		{"layer": 3, "step": 12, "order": 0, "velocity": 0.75},
	]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports")) != OK:
		printerr("NEEDLEBEAT_QA_EXPORT_DIR_FAILED")
		return
	if not parent.audio.export_wav(events, 0, 120, PROBE_WAV, NBMusicEngine.MUSIC_VERSION, 127):
		printerr("NEEDLEBEAT_QA_EXPORT_FAILED")
		return
	var bytes := FileAccess.get_file_as_bytes(PROBE_WAV)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		printerr("NEEDLEBEAT_QA_WAV_INVALID")
		return
	print("NEEDLEBEAT_QA_EXPORT_OK size=", bytes.size())
	if NBAndroidShare.share_wav(PROBE_WAV):
		print("NEEDLEBEAT_QA_SHARE_REQUESTED")
	else:
		printerr("NEEDLEBEAT_QA_SHARE_FAILED")

# CI-only process-death test. A single safe embedded shot is written through
# the production save path before adb force-stops the app. The next ordinary
# launch must recover it without the QA intent or replaying the shot.
func _seed_recovery_checkpoint() -> void:
	var game = get_parent()
	if game == null:
		printerr("NEEDLEBEAT_QA_CHECKPOINT_NO_GAME")
		return
	game.call("_start_song", false)
	var shot_time := -1.0
	for i in range(14000):
		var candidate := 0.3 + float(i) * 0.0075
		var angle := NBGeometry.impact_local_angle(candidate, game.motion)
		if not bool(NBGeometry.evaluate(angle, game.pins, game.active_lane)["hit"]):
			shot_time = candidate
			break
	if shot_time < 0.0:
		printerr("NEEDLEBEAT_QA_CHECKPOINT_NO_WINDOW")
		return
	game.call("_fire")
	game.flight_start = shot_time
	game.stage_clock = shot_time + NBGeometry.FLIGHT
	game.call("_land_shot")
	game.call("_pause_game")
	var current: Dictionary = game.store.data.get("active_song", {})
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(NBProgressStore.FILE))
	if game.events.size() != 1 or current.get("placed", -1) != 1 or typeof(saved) != TYPE_DICTIONARY:
		printerr("NEEDLEBEAT_QA_CHECKPOINT_INCOMPLETE")
		return
	if int(saved.get("active_song", {}).get("placed", -1)) != 1:
		printerr("NEEDLEBEAT_QA_CHECKPOINT_NOT_DURABLE")
		return
	print("NEEDLEBEAT_QA_CHECKPOINT_SAVED stage=0 placed=1")
