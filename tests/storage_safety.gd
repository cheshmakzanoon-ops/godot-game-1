extends SceneTree

const SAVE := "user://storage_safety.json"
const BACKUP := "user://storage_safety_backup.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("STORAGE FAIL: " + message)

func write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func signed_payload(value: Dictionary) -> String:
	var raw := JSON.stringify(value)
	var body := Marshalls.raw_to_base64(raw.to_utf8_buffer()).replace("+", "-").replace("/", "_")
	return "NBD2." + body.replace("=", "") + "." + raw.sha256_text().substr(0, 10)

func run() -> void:
	for path in [SAVE, BACKUP, SAVE + ".tmp", BACKUP + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var store := NBProgressStore.new()
	store.file_path = SAVE
	store.backup_path = BACKUP
	store.data = store._defaults()
	store.data["completed"] = 8
	check(store.save() and store.save(), "validated atomic save and backup commit")
	check(not FileAccess.file_exists(SAVE + ".tmp"), "successful commit leaves no temporary file")
	for field in ["campaign_index", "completed", "favorites", "settings", "best", "daily", "active_song"]:
		var bad := store._defaults()
		bad[field] = "incorrect type"
		write(SAVE, JSON.stringify(bad))
		store.load_progress()
		check(store.data["completed"] == 8, "structural corruption falls back to backup: " + field)
	write(SAVE, "{broken")
	write(SAVE + ".tmp", "{half-written")
	store.load_progress()
	check(store.data["completed"] == 8, "partial writes and orphan temp cannot destroy backup")
	check(store.save(), "can repair a broken primary without overwriting valid backup")
	var future := store._defaults()
	future["version"] = 2
	write(SAVE, JSON.stringify(future))
	var original := FileAccess.get_file_as_string(SAVE)
	store.load_progress()
	check(store.read_only and not store.save(), "newer save version blocks destructive downgrade")
	check(FileAccess.get_file_as_string(SAVE) == original, "newer primary survives attempted save")
	write(SAVE, JSON.stringify(store._defaults()))
	store.load_progress()
	store.record_success(0, 100, false, "", {})
	store.record_success(0, 120, false, "", {})
	check(store.data["completed"] == 1 and store.data["best"]["0"] == 120, "completion cannot award unlock twice")
	check(not store.unlocked(-1) and not store.unlocked(5), "genre lookup rejects out-of-range inputs")
	var payload := {"v": 2, "g": 0, "b": 120, "s": 47,
		"e": [{"layer": 0, "step": 0, "order": 0, "velocity": 0.7}]}
	check(not NBSongCodec.decode(signed_payload(payload)).is_empty(), "valid signed payload accepted")
	for key in ["v", "g", "b", "s"]:
		for invalid in [[], {}, true, "1", 1.5]:
			var bad := payload.duplicate(true)
			bad[key] = invalid
			check(NBSongCodec.decode(signed_payload(bad)).is_empty(), "typed metadata rejected: " + key)
	for key in ["layer", "step", "order", "velocity"]:
		for invalid in [[], {}, true, "0"]:
			var bad := payload.duplicate(true)
			bad["e"][0][key] = invalid
			check(NBSongCodec.decode(signed_payload(bad)).is_empty(), "typed event rejected: " + key)
	for invalid in ["", "NBD2.A.0000000000", "NBD2.@@@.0000000000", "NBD2." + "A".repeat(9000)]:
		check(NBSongCodec.decode(invalid).is_empty(), "malformed envelope rejected without coercion")
	for path in [SAVE, BACKUP, SAVE + ".tmp", BACKUP + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STORAGE SAFETY: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
