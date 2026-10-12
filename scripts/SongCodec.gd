class_name NBSongCodec
extends RefCounted

const VERSION := 2
const PREFIX := "NBD2."
const LEGACY_PREFIX := "NBD1."
const MAX_CODE_LENGTH := 8192
const MAX_EVENTS := 64

# JSON numbers may decode as floats, but IDs and grid indices must be exact
# integers. Never coerce arrays, booleans or numeric strings from untrusted data.
static func integer_in(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

static func event_valid(event: Variant) -> bool:
	if typeof(event) != TYPE_DICTIONARY:
		return false
	for key in ["layer", "step", "order"]:
		if not integer_in(event.get(key), 0, {"layer": 3, "step": 15, "order": 50}[key]):
			return false
	var velocity: Variant = event.get("velocity", 0.7)
	return typeof(velocity) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(velocity)) and velocity >= 0 and velocity <= 1

static func encode(song: Dictionary) -> String:
	var music_version: Variant = song.get("music_version", VERSION)
	if not integer_in(music_version, 1, VERSION) or not integer_in(song.get("genre", 0), 0, 4):
		return ""
	if not integer_in(song.get("bpm", 120), 50, 220) or not integer_in(song.get("seed", 0), -9007199254740991, 9007199254740991):
		return ""
	var notes: Variant = song.get("events", [])
	if typeof(notes) != TYPE_ARRAY or notes.size() > MAX_EVENTS:
		return ""
	for event in notes:
		if not event_valid(event):
			return ""
	var data := {"v": int(music_version), "g": int(song.get("genre", 0)),
		"b": int(song.get("bpm", 120)), "s": int(song.get("seed", 0)), "e": notes}
	var raw := JSON.stringify(data)
	var encoded := Marshalls.raw_to_base64(raw.to_utf8_buffer()).replace("+", "-").replace("/", "_")
	while encoded.ends_with("="):
		encoded = encoded.substr(0, encoded.length() - 1)
	var code := (LEGACY_PREFIX if music_version == 1 else PREFIX) + encoded + "." + raw.sha256_text().substr(0, 10)
	return code if code.length() <= MAX_CODE_LENGTH else ""

static func decode(code: String) -> Dictionary:
	var clean := code.strip_edges()
	var version := 2 if clean.begins_with(PREFIX) else (1 if clean.begins_with(LEGACY_PREFIX) else -1)
	if version < 0 or clean.length() > MAX_CODE_LENGTH:
		return {}
	var parts := clean.substr(PREFIX.length()).split(".")
	if parts.size() != 2 or parts[1].length() != 10 or parts[0].is_empty() or parts[0].length() % 4 == 1:
		return {}
	for character in parts[0]:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_":
			return {}
	for character in parts[1]:
		if not character in "0123456789abcdef":
			return {}
	var base64 := parts[0].replace("-", "+").replace("_", "/")
	while base64.length() % 4 != 0:
		base64 += "="
	var raw_bytes := Marshalls.base64_to_raw(base64)
	var raw := raw_bytes.get_string_from_utf8()
	if raw_bytes.size() > MAX_CODE_LENGTH or raw.sha256_text().substr(0, 10) != parts[1]:
		return {}
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {}
	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY or not integer_in(data.get("v"), version, version):
		return {}
	if not integer_in(data.get("g"), 0, 4) or not integer_in(data.get("b"), 50, 220):
		return {}
	if not integer_in(data.get("s"), -9007199254740991, 9007199254740991):
		return {}
	if typeof(data.get("e")) != TYPE_ARRAY or data["e"].size() > MAX_EVENTS:
		return {}
	var normalized: Array = []
	for event in data["e"]:
		if not event_valid(event):
			return {}
		normalized.append({"layer": int(event["layer"]), "step": int(event["step"]),
			"order": int(event["order"]), "velocity": float(event.get("velocity", 0.7))})
	return {"genre": int(data["g"]), "bpm": int(data["b"]), "seed": int(data["s"]),
		"music_version": version, "code": clean, "events": normalized}
