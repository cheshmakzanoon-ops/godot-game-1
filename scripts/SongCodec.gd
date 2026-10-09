class_name NBSongCodec
extends RefCounted

const VERSION := 1
const PREFIX := "NBD1."
const MAX_CODE_LENGTH := 8192
const MAX_EVENTS := 64

static func encode(song: Dictionary) -> String:
	var data := {"v": VERSION, "g": int(song.get("genre", 0)),
		"b": int(song.get("bpm", 120)), "s": int(song.get("seed", 0)),
		"e": song.get("events", [])}
	var raw := JSON.stringify(data)
	var encoded := Marshalls.raw_to_base64(raw.to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=")
	# Remove any remaining padding characters.
	while encoded.ends_with("="):
		encoded = encoded.substr(0, encoded.length() - 1)
	return PREFIX + encoded + "." + raw.sha256_text().substr(0, 10)

static func decode(code: String) -> Dictionary:
	var clean := code.strip_edges()
	if not clean.begins_with(PREFIX) or clean.length() > MAX_CODE_LENGTH:
		return {}
	var body := clean.substr(PREFIX.length())
	var parts := body.split(".")
	if parts.size() != 2 or parts[1].length() != 10:
		return {}
	var base64 := parts[0].replace("-", "+").replace("_", "/")
	while base64.length() % 4 != 0:
		base64 += "="
	var raw_bytes := Marshalls.base64_to_raw(base64)
	if raw_bytes.size() > MAX_CODE_LENGTH:
		return {}
	var raw := raw_bytes.get_string_from_utf8()
	if raw.sha256_text().substr(0, 10) != parts[1]:
		return {}
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if int(data.get("v", -1)) != VERSION:
		return {}
	if not data.has("e") or typeof(data["e"]) != TYPE_ARRAY or not data.has("s"):
		return {}
	if data["e"].size() > MAX_EVENTS:
		return {}
	if int(data.get("g", -1)) not in range(5) or int(data.get("b", 0)) < 50 or int(data.get("b", 0)) > 220:
		return {}
	for event in data["e"]:
			if typeof(event) != TYPE_DICTIONARY:
				return {}
			if not event.has("step") or not event.has("layer") or not event.has("order"):
				return {}
			if int(event["step"]) not in range(16) or int(event["layer"]) not in range(4):
				return {}
			if int(event["order"]) < 0 or int(event["order"]) > 50:
				return {}
		return {"genre": int(data["g"]), "bpm": int(data["b"]), "seed": int(data["s"]),
			"events": data["e"].duplicate(true)}
