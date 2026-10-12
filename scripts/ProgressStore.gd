class_name NBProgressStore
extends RefCounted

const FILE := "user://save_v1.json"
const BACKUP := "user://save_v1_backup.json"
const VERSION := 1
const MAX_SAVE_BYTES := 4 * 1024 * 1024

var data: Dictionary = {}
var file_path := FILE
var backup_path := BACKUP
var save_enabled := true # Isolated integration tests must not modify player saves.
var read_only := false
var last_error := ""

func _init() -> void:
	load_progress()

func _defaults() -> Dictionary:
	return {"version": VERSION, "campaign_index": 0, "completed": 0,
		"best": {}, "daily": {}, "favorites": [], "active_song": {}, "settings": {
			"music": 0.8, "effects": true, "effects_volume": 1.0, "motion": true, "haptics": true, "flashes": true}}

func _validate(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not NBSongCodec.integer_in(value.get("version"), VERSION, VERSION):
		return {}
	if not NBSongCodec.integer_in(value.get("campaign_index"), 0, 100000000) or typeof(value.get("favorites")) != TYPE_ARRAY:
		return {}
	var result: Dictionary = value.duplicate(true)
	var defaults := _defaults()
	for key in defaults:
		if not result.has(key):
			result[key] = defaults[key]
	if not NBSongCodec.integer_in(result["completed"], 0, 100000000):
		return {}
	for key in ["best", "daily", "settings", "active_song"]:
		if typeof(result[key]) != TYPE_DICTIONARY:
			return {}
	for key in result["best"]:
		if not NBSongCodec.integer_in(result["best"][key], 0, 100000000):
			return {}
	for day in result["daily"]:
		var entry: Variant = result["daily"][day]
		if typeof(entry) != TYPE_DICTIONARY or not NBSongCodec.integer_in(entry.get("score"), 0, 100000000):
			return {}
	if not result["settings"].has("effects_volume") and result["settings"].get("effects", true) == false:
		result["settings"]["effects_volume"] = 0.0
	for key in defaults["settings"]:
		var setting: Variant = result["settings"].get(key, defaults["settings"][key])
		if key in ["music", "effects_volume"]:
			if typeof(setting) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(setting)) or setting < 0 or setting > 1:
				return {}
		elif typeof(setting) != TYPE_BOOL:
			return {}
		result["settings"][key] = setting
	var favorites: Array = []
	for song in result["favorites"]:
		if typeof(song) != TYPE_DICTIONARY or typeof(song.get("code")) != TYPE_STRING:
			continue
		var decoded := NBSongCodec.decode(song["code"])
		if not decoded.is_empty() and favorites.size() < 20:
			# Reconstruct from its validated code, not unchecked saved array indices.
			for key in ["score", "perfects", "retries"]:
				if NBSongCodec.integer_in(song.get(key), 0, 100000000):
					decoded[key] = int(song[key])
			if typeof(song.get("daily")) == TYPE_BOOL and typeof(song.get("date")) == TYPE_STRING:
				decoded["daily"] = song["daily"]
				decoded["date"] = song["date"].left(10)
			favorites.append(decoded)
	result["favorites"] = favorites
	return result

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var value: Variant = parser.data
	if typeof(value) == TYPE_DICTIONARY and NBSongCodec.integer_in(value.get("version"), VERSION + 1, 1000000):
		read_only = true # Never downgrade or overwrite data from a newer app.
	return _validate(value)

func load_progress() -> void:
	read_only = false
	last_error = ""
	data = _read_valid(file_path)
	if data.is_empty():
		data = _read_valid(backup_path)
	if data.is_empty():
		data = _defaults()
	if read_only:
		last_error = "NEWER SAVE VERSION / UPDATE REQUIRED"

func _atomic_write(path: String, contents: String) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK and not _read_valid(temporary).is_empty():
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK:
			return true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return false

func save() -> bool:
	if not save_enabled:
		return true
	if read_only:
		return false
	last_error = ""
	var valid := _validate(data)
	if valid.is_empty():
		last_error = "INVALID SAVE DATA"
		return false
	var previous := _read_valid(file_path)
	if read_only:
		last_error = "NEWER SAVE VERSION / UPDATE REQUIRED"
		return false
	if not previous.is_empty() and not _atomic_write(backup_path, JSON.stringify(previous)):
		last_error = "BACKUP WRITE FAILED"
		return false
	var contents := JSON.stringify(valid)
	if contents.to_utf8_buffer().size() > MAX_SAVE_BYTES or not _atomic_write(file_path, contents):
		last_error = "SAVE WRITE FAILED"
		return false
	return true

func unlocked(genre: int) -> bool:
	return genre in range(5) and int(data["completed"]) >= NBStageDirector.UNLOCKS[genre]

func record_success(song_index: int, score: int, daily: bool, day: String, result: Dictionary) -> void:
	if daily:
		var existing: Dictionary = data["daily"].get(day, {})
		if score > int(existing.get("score", -1)):
			data["daily"][day] = result.duplicate(true)
	else:
		var key := str(song_index)
		if not data["best"].has(key):
			data["completed"] = int(data["completed"]) + 1
		data["best"][key] = maxi(score, int(data["best"].get(key, 0)))
		data["campaign_index"] = maxi(int(data["campaign_index"]), song_index + 1)
	save()

func save_favorite(song: Dictionary) -> void:
	var code := str(song.get("code", ""))
	if NBSongCodec.decode(code).is_empty():
		last_error = "INVALID SONG"
		return
	var favorites: Array = data["favorites"]
	for i in range(favorites.size() - 1, -1, -1):
		if str(favorites[i].get("code", "")) == code:
			favorites.remove_at(i)
	favorites.push_front(song.duplicate(true))
	if favorites.size() > 20:
		favorites.resize(20)
	save()

func change_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save()
