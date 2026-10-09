class_name NBProgressStore
extends RefCounted

const FILE := "user://save_v1.json"
const BACKUP := "user://save_v1_backup.json"
const VERSION := 1

var data: Dictionary = {}

func _init() -> void:
	load_progress()

func _defaults() -> Dictionary:
	return {"version": VERSION, "campaign_index": 0, "completed": 0,
		"best": {}, "daily": {}, "favorites": [], "settings": {
			"music": 0.8, "effects": true, "motion": true, "haptics": true}}

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var value: Variant = JSON.parse_string(raw)
	if typeof(value) != TYPE_DICTIONARY or int(value.get("version", -1)) != VERSION:
		return {}
	if not value.has("campaign_index") or not value.has("favorites"):
		return {}
	return value

func load_progress() -> void:
	data = _read_valid(FILE)
	if data.is_empty():
		data = _read_valid(BACKUP)
	if data.is_empty():
		data = _defaults()
	for key in _defaults():
		if not data.has(key):
			data[key] = _defaults()[key]

func save() -> void:
	var previous := _read_valid(FILE)
	if not previous.is_empty():
		var backup := FileAccess.open(BACKUP, FileAccess.WRITE)
		if backup != null:
			backup.store_string(JSON.stringify(previous))
			backup.close()
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

func unlocked(genre: int) -> bool:
	return int(data["completed"]) >= NBStageDirector.UNLOCKS[genre]

func record_success(song_index: int, score: int, daily: bool, day: String, result: Dictionary) -> void:
	if daily:
		var existing: Dictionary = data["daily"].get(day, {})
		if score > int(existing.get("score", -1)):
			data["daily"][day] = result
	else:
		var key := str(song_index)
		data["best"][key] = maxi(score, int(data["best"].get(key, 0)))
		data["completed"] = int(data["completed"]) + 1
		data["campaign_index"] = maxi(int(data["campaign_index"]), song_index + 1)
	save()

func save_favorite(song: Dictionary) -> void:
	var favorites: Array = data["favorites"]
	var match_code: String = str(song.get("code", ""))
	for i in range(favorites.size() - 1, -1, -1):
		if str(favorites[i].get("code", "")) == match_code:
			favorites.remove_at(i)
	favorites.push_front(song.duplicate(true))
	if favorites.size() > 20:
		favorites.resize(20)
	save()

func change_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save()
