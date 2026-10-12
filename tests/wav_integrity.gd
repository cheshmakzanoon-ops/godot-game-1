extends SceneTree

var failures := 0
var checks := 0
const SOURCE := "user://exports/needlebeat_integrity.wav"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WAV FAIL: " + reason)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports"))
	var audio := NBAudioSystem.new()
	var notes := [{"layer": 0, "step": 0, "order": 0, "velocity": 0.8}]
	check(audio.export_wav(notes, 0, 120, SOURCE), "write complete WAV atomically")
	var original := FileAccess.get_sha256(SOURCE)
	var shared := NBAndroidShare.archive_wav(SOURCE)
	check(not shared.is_empty() and FileAccess.get_sha256(shared) == original, "archive retains exact bytes")
	check(NBAndroidShare.archive_wav(SOURCE) == shared, "identical export reuses immutable snapshot")
	check(audio.export_wav(notes, 1, 96, SOURCE), "replace original with another arrangement")
	var replacement := FileAccess.get_sha256(SOURCE)
	check(original != replacement and FileAccess.get_sha256(shared) == original, "old attachment survives source replacement")
	var second := NBAndroidShare.archive_wav(SOURCE)
	check(second != shared and FileAccess.get_sha256(second) == replacement, "new bytes get a new URI path")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SOURCE + ".tmp"))
	check(not audio.export_wav(notes, 0, 120, SOURCE), "unwritable temporary destination reports failure")
	check(FileAccess.get_sha256(SOURCE) == replacement, "failed write retains previous export")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SOURCE + ".tmp"))
	check(NBAndroidShare.archive_wav("user://exports/../needlebeat_private.wav").is_empty(), "reject traversal")
	check(NBAndroidShare.archive_wav("user://exports/needlebeat_missing.wav").is_empty(), "reject missing source")
	for path in [SOURCE, shared, second]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	audio.free()
	print("WAV INTEGRITY: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
