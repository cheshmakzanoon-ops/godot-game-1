class_name NBStageDirector
extends RefCounted

const QUOTAS := [6, 7, 8, 9]
const PRELOADS := [1, 2, 2, 3]
const GENRES := ["PULSE", "CASSETTE", "POCKET", "PIXEL", "AFTER HOURS"]
const BPMS := [120, 96, 112, 132, 104]
const UNLOCKS := [0, 3, 8, 16, 30]
const PALETTES := [
	[Color("101928"), Color("f7ead7"), Color("dc855e"), Color("6186e6"), Color("d0ad6c")],
	[Color("2b2526"), Color("f3e5ca"), Color("ad6755"), Color("94728b"), Color("dbc49a")],
	[Color("122b32"), Color("fff2d4"), Color("ed884f"), Color("5aafb5"), Color("c9d2a2")],
	[Color("241e40"), Color("ede7ff"), Color("aee16f"), Color("8b8cfd"), Color("ffbe96")],
	[Color("101e2b"), Color("e8dfc9"), Color("ae9a63"), Color("83aa99"), Color("dcb98c")]
]

static func create_stage(song_seed: int, index: int, campaign_index: int, bpm: int, daily: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = song_seed + (index + 7) * 59387
	var special := "NORMAL"
	var level := campaign_index + 1
	if (level >= 11 or daily) and index >= 2:
		special = "REWIND" if rng.randi_range(0, 2) == 0 else "PULSE"
	if level >= 21 and rng.randi_range(0, 3) == 0:
		special = "TWIN"
	if level >= 4 and special == "NORMAL" and rng.randi_range(0, 3) == 0:
		special = "PULSE"
	if level <= 3 and not daily:
		special = "NORMAL"
	var velocity := clampf(0.88 + float(mini(level, 40)) / 120.0 + float(index) * 0.045, 0.85, 1.25)
	var start_angle := rng.randf_range(0.0, TAU)
	var preloads: Array = []
	for i in PRELOADS[index]:
		var lane := 0 if special != "TWIN" else i % 2
		var proposal := rng.randf_range(0.0, TAU)
		for attempts in 64:
			if NBGeometry.clearance(proposal, preloads, lane) > deg_to_rad(32.0):
				break
			proposal = rng.randf_range(0.0, TAU)
		preloads.append({"angle": proposal, "lane": lane, "preload": true})
	return {"index": index, "quota": QUOTAS[index], "preloads": preloads,
		"special": special, "velocity": velocity, "initial_phase": start_angle, "bpm": bpm,
		"seed": song_seed}

static func seed_for_campaign(campaign_index: int) -> int:
	return 476203 + (campaign_index + 1) * 482719

static func daily_date() -> String:
	return Time.get_date_string_from_system(true)

static func daily_seed(date: String) -> int:
	var digest := ("daily:" + date + ":v1").sha256_text()
	return ("0x" + digest.substr(0, 12)).hex_to_int()

static func daily_genre(seed: int) -> int:
	return posmod(seed, 5)
