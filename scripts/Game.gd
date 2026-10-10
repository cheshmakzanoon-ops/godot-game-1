extends Control

# NEEDLEBEAT: DROP. Gameplay, HUD and artwork are authored directly as CanvasItems.
# Fixed logical composition ensures identical collision visuals on Android screens.
const WIDTH := 480.0
const HEIGHT := 854.0
const CENTER := Vector2(240, 409)
const MAIN_RADIUS := 137.0
const INNER_RADIUS := 105.0
const LAUNCH_Y := 676.0
const NAMES := ["BEAT", "ROOT", "HOOK", "DROP"]
const LABELS := ["DRUMS", "BASS", "MELODY", "HARMONY"]

var store := NBProgressStore.new()
var audio: NBAudioSystem
var motion := NBDiscMotion.new()
var font: Font
var screen := "MENU"
var selected_genre := 0
var genre := 0
var bpm := 120
var music_version := NBMusicEngine.MUSIC_VERSION
var seed := 0
var song_index := 0
var is_daily := false
var daily_date := ""
var stage_index := 0
var stage: Dictionary = {}
var pins: Array = []
var events: Array = []
var placed := 0
var active_lane := 0
var stage_points := 0
var total_score := 0
var perfect_count := 0
var stage_perfects := 0
var miss_count := 0
var combo := 0
var retries := 0
var stage_clock := 0.0
var stage_origin_usec := 0
var paused_from := ""
var paused_at_usec := 0
var effect_clock := 0.0
var flight_start := 0.0
var flight_lane := 0
var feedback := ""
var feedback_timer := 0.0
var elapsed := 0.0
var drop_clock := 0.0
var encore_remaining := 0
var encore_snapshot: Dictionary = {}
var last_song: Dictionary = {}
var saved_preview := false
var library_page := 0
var last_export_path := ""
var import_field: LineEdit
var error_text := ""
var adapt_scale := 1.0
var adapt_offset := Vector2.ZERO

func _ready() -> void:
	font = ThemeDB.fallback_font
	audio = NBAudioSystem.new()
	add_child(audio)
	selected_genre = 0
	audio.set_music_volume(float(store.data["settings"].get("music", 0.8)))
	import_field = LineEdit.new()
	import_field.position = Vector2(40, 350)
	import_field.size = Vector2(400, 48)
	import_field.placeholder_text = "Paste an NBD1 or NBD2 song code"
	import_field.visible = false
	import_field.max_length = 8192
	add_child(import_field)
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()
	queue_redraw()
	# Optional on-device instrumentation; guarded by Android debug export and intent extra.
	if OS.get_name() == "Android" and OS.has_feature("debug"):
		var qa_probe = load("res://tests/android_runtime.gd").new()
		add_child(qa_probe)

func _effective_canvas_size(control_size: Vector2) -> Vector2:
	# Android can initially report zero-sized anchored Control bounds.
	if control_size.x <= 1.0 or control_size.y <= 1.0:
		return get_viewport_rect().size
	return control_size

func _refresh_layout() -> void:
	var canvas_size := _effective_canvas_size(size)
	adapt_scale = minf(canvas_size.x / WIDTH, canvas_size.y / HEIGHT)
	adapt_offset = (canvas_size - Vector2(WIDTH, HEIGHT) * adapt_scale) * 0.5
	if import_field != null:
		import_field.position = adapt_offset + Vector2(40, 353) * adapt_scale
		import_field.size = Vector2(400, 47) * adapt_scale
	queue_redraw()

func _process(delta: float) -> void:
	var safe_delta := minf(delta, 0.10)
	elapsed += safe_delta
	feedback_timer = maxf(0.0, feedback_timer - safe_delta)
	if screen in ["RECORD", "FLIGHT", "FAIL", "STAGE_CLEAR", "ENCORE"]:
		stage_clock = maxf(0.0, float(Time.get_ticks_usec() - stage_origin_usec) / 1000000.0)
		if screen == "FLIGHT" and stage_clock >= flight_start + NBGeometry.FLIGHT:
			_land_shot()
	if screen == "DROP_PAUSE":
		drop_clock += safe_delta
		if drop_clock >= 0.19:
			_start_full_playback()
	if screen == "DROP_SHOW" or screen == "PREVIEW":
		drop_clock += safe_delta
		if drop_clock >= 4.0 * 4.0 * 60.0 / float(bpm) + 0.1:
			screen = "MENU" if screen == "PREVIEW" else "RESULTS"
			audio.stop()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if screen == "PAUSED":
			_resume_game()
		elif screen in ["RECORD", "ENCORE", "FLIGHT", "FAIL", "STAGE_CLEAR", "DROP_SHOW", "PREVIEW"]:
			_pause_game()
		elif screen != "MENU":
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		point = event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		point = event.position
	else:
		return
	var local := (point - adapt_offset) / maxf(adapt_scale, 0.01)
	_tap(local)
	get_viewport().set_input_as_handled()

func _tap(p: Vector2) -> void:
	match screen:
		"MENU":
			if _inside(p, Rect2(40, 685, 400, 65)):
				_start_song(false)
			elif _inside(p, Rect2(40, 758, 193, 54)):
				_start_song(true)
			elif _inside(p, Rect2(242, 758, 198, 54)):
				library_page = 0
				screen = "LIBRARY"
			elif p.y < 155 and p.x > 396:
				screen = "SETTINGS"
			elif _inside(p, Rect2(38, 620, 65, 50)):
				_change_genre(-1)
			elif _inside(p, Rect2(378, 620, 65, 50)):
				_change_genre(1)
		"RECORD", "ENCORE":
			if p.y < 90 and p.x > 384:
				_pause_game()
			elif p.y > 120 and p.y < 840:
				_fire()
		"FLIGHT":
			pass
		"PAUSED":
			if _inside(p, Rect2(44, 473, 392, 64)):
				_resume_game()
			elif _inside(p, Rect2(44, 549, 392, 58)):
				_open_menu()
		"FAIL":
			if effect_clock <= 0.0 or stage_clock - effect_clock >= 0.21:
				_setup_stage()
		"STAGE_CLEAR":
			if _inside(p, Rect2(40, 713, 400, 64)):
				_next_stage()
			elif not is_daily and _inside(p, Rect2(40, 785, 400, 45)):
				_begin_encore()
		"DROP_SHOW":
			audio.stop()
			screen = "RESULTS"
		"DROP_PAUSE":
			pass
		"RESULTS":
			if _inside(p, Rect2(40, 536, 400, 50)):
				_save_track()
			elif _inside(p, Rect2(40, 591, 400, 50)):
				_copy_code()
			elif _inside(p, Rect2(40, 646, 400, 50)):
				_export_wav()
			elif _inside(p, Rect2(40, 705, 400, 60)):
				_start_song(is_daily)
			elif _inside(p, Rect2(40, 777, 400, 45)):
				_open_menu()
		"LIBRARY":
			if p.y < 115:
				_open_menu()
			elif _inside(p, Rect2(38, 710, 192, 60)):
				library_page = maxi(0, library_page - 1)
			elif _inside(p, Rect2(248, 710, 192, 60)):
				library_page = mini(maxi(0, int((store.data["favorites"].size() - 1) / 5)), library_page + 1)
			elif _inside(p, Rect2(40, 780, 400, 50)):
				screen = "IMPORT"
				import_field.visible = true
				error_text = ""
				import_field.grab_focus()
			elif p.y >= 195 and p.y < 695:
				var index := library_page * 5 + int((p.y - 194) / 96)
				if index < store.data["favorites"].size():
					_play_saved(store.data["favorites"][index])
		"IMPORT":
			if _inside(p, Rect2(40, 439, 400, 66)):
				var song := NBSongCodec.decode(import_field.text)
				if song.is_empty():
					error_text = "INVALID OR UNSUPPORTED SONG CODE"
				else:
					import_field.visible = false
					_play_saved(song)
			elif _inside(p, Rect2(40, 526, 400, 50)):
				import_field.visible = false
				screen = "LIBRARY"
		"SETTINGS":
			if _inside(p, Rect2(40, 305, 400, 60)):
				var value := float(store.data["settings"].get("music", 0.8))
				value = 0.0 if value > 0.95 else value + 0.2
				store.change_setting("music", value)
				audio.set_music_volume(value)
			elif _inside(p, Rect2(40, 375, 400, 60)):
				_toggle_setting("effects")
			elif _inside(p, Rect2(40, 445, 400, 60)):
				_toggle_setting("motion")
			elif _inside(p, Rect2(40, 515, 400, 60)):
				_toggle_setting("haptics")
			elif _inside(p, Rect2(40, 715, 400, 65)):
				_open_menu()
	queue_redraw()

func _inside(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)

func _toggle_setting(key: String) -> void:
	store.change_setting(key, not bool(store.data["settings"].get(key, true)))

func _change_genre(direction: int) -> void:
	for step in range(1, 6):
		var candidate := posmod(selected_genre + direction * step, 5)
		if store.unlocked(candidate):
			selected_genre = candidate
			break

func _pause_game() -> void:
	if screen == "PAUSED":
		return
	paused_from = screen
	paused_at_usec = Time.get_ticks_usec()
	screen = "PAUSED"
	audio.pause_playback()

func _resume_game() -> void:
	if screen != "PAUSED":
		return
	stage_origin_usec += Time.get_ticks_usec() - paused_at_usec
	screen = paused_from
	audio.resume_playback()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if screen in ["RECORD", "FLIGHT", "FAIL", "ENCORE", "STAGE_CLEAR", "DROP_SHOW", "PREVIEW", "DROP_PAUSE"]:
			_pause_game()

func _open_menu() -> void:
	audio.stop()
	import_field.visible = false
	screen = "MENU"
	feedback = ""

func _start_song(daily: bool) -> void:
	if OS.get_name() == "Android" and OS.has_feature("debug"):
		print("NEEDLEBEAT_QA_PLAY_STARTED size=", size, " viewport=", get_viewport_rect().size,
			" scale=", adapt_scale)
	is_daily = daily
	daily_date = NBStageDirector.daily_date() if daily else ""
	song_index = int(store.data["campaign_index"])
	seed = NBStageDirector.daily_seed(daily_date) if daily else NBStageDirector.seed_for_campaign(song_index)
	genre = NBStageDirector.daily_genre(seed) if daily else selected_genre
	bpm = NBStageDirector.BPMS[genre]
	music_version = NBMusicEngine.MUSIC_VERSION
	stage_index = 0
	events.clear()
	total_score = 0
	perfect_count = 0
	miss_count = 0
	retries = 0
	last_song.clear()
	saved_preview = false
	_setup_stage()

func _setup_stage() -> void:
	stage = NBStageDirector.create_stage(seed, stage_index, 24 if is_daily else song_index, bpm, is_daily)
	pins = stage["preloads"].duplicate(true)
	motion.configure(float(stage["initial_phase"]), float(bpm), float(stage["velocity"]), str(stage["special"]))
	placed = 0
	active_lane = 0
	stage_points = 0
	stage_perfects = 0
	combo = 0
	stage_clock = 0.0
	stage_origin_usec = Time.get_ticks_usec()
	effect_clock = 0.0
	feedback = ""
	# Prior layers are checkpoints. A failed stage loses only its own events.
	var previous: Array = []
	for item in events:
		if int(item["layer"]) < stage_index:
			previous.append(item)
	events = previous
	screen = "RECORD"
	audio.configure(genre, bpm, events, music_version, seed)

func _fire() -> void:
	flight_start = float(Time.get_ticks_usec() - stage_origin_usec) / 1000000.0
	flight_lane = active_lane
	screen = "FLIGHT"

func _land_shot() -> void:
	var angle := NBGeometry.impact_local_angle(flight_start, motion)
	var result := NBGeometry.evaluate(angle, pins, flight_lane)
	if bool(result["hit"]):
		if encore_remaining > 0:
			_restore_encore()
			_feedback("ENCORE LOST", 0.65)
			_next_stage()
			return
		miss_count += 1
		retries += 1
		combo = 0
		feedback = "COLLISION  /  TAP TO RETRY"
		feedback_timer = 0.8
		effect_clock = stage_clock
		screen = "FAIL"
		audio.stop()
		_vibrate(45)
		return
	pins.append({"angle": angle, "lane": flight_lane, "preload": false})
	var per_shot := 100 + mini(combo * 10, 50)
	combo += 1
	var quality := "GOOD SHOT"
	if bool(result["perfect"]):
		per_shot += 60
		stage_perfects += 1
		quality = "PERFECT"
	if bool(result["edge"]):
		per_shot += 35
		quality = "PERFECT + EDGE" if bool(result["perfect"]) else "EDGE"
	stage_points += per_shot
	var order := placed if encore_remaining == 0 else int(stage["quota"]) + (2 - encore_remaining)
	events.append({"layer": stage_index, "step": int(result["step"]), "order": order,
		"velocity": (0.97 if bool(result["perfect"]) else 0.72)})
	audio.set_events(events)
	if bool(store.data["settings"].get("effects", true)):
		audio.effect("click")
	_feedback(quality, 0.54)
	if bool(result["edge"]):
		_vibrate(17)
	if stage["special"] == "TWIN":
		active_lane = 1 - active_lane
	if encore_remaining > 0:
		encore_remaining -= 1
		if encore_remaining == 0:
			stage_points += 500
			_feedback("ENCORE +500", 0.9)
			_next_stage()
		else:
			screen = "ENCORE"
		return
	placed += 1
	if placed >= int(stage["quota"]):
		screen = "STAGE_CLEAR"
		_feedback("RECORD COMPLETE", 0.9)
	else:
		screen = "RECORD"

func _feedback(message: String, duration: float) -> void:
	feedback = message
	feedback_timer = duration

func _vibrate(milliseconds: int) -> void:
	if bool(store.data["settings"].get("haptics", true)):
		Input.vibrate_handheld(milliseconds)

func _begin_encore() -> void:
	encore_snapshot = {"pins": pins.duplicate(true), "events": events.duplicate(true),
		"points": stage_points, "perfects": stage_perfects}
	encore_remaining = 2
	screen = "ENCORE"

func _restore_encore() -> void:
	pins = encore_snapshot["pins"].duplicate(true)
	events = encore_snapshot["events"].duplicate(true)
	stage_points = int(encore_snapshot["points"])
	stage_perfects = int(encore_snapshot["perfects"])
	encore_remaining = 0
	audio.set_events(events)

func _next_stage() -> void:
	# Points are committed once, after a record clears or an encore resolves.
	total_score += stage_points + 300
	perfect_count += stage_perfects
	encore_remaining = 0
	if stage_index == 3:
		_complete_song()
	else:
		stage_index += 1
		_setup_stage()

func _complete_song() -> void:
	last_song = {"genre": genre, "bpm": bpm, "seed": seed, "music_version": music_version,
		"events": events.duplicate(true),
		"score": total_score, "daily": is_daily, "date": daily_date}
	last_song["code"] = NBSongCodec.encode(last_song)
	store.record_success(song_index, total_score, is_daily, daily_date,
		{"score": total_score, "perfects": perfect_count, "retries": retries,
		"misses": miss_count, "code": last_song["code"]})
	if not is_daily:
		selected_genre = genre
	audio.stop()
	drop_clock = 0.0
	screen = "DROP_PAUSE"

func _start_full_playback() -> void:
	screen = "DROP_SHOW"
	drop_clock = 0.0
	audio.configure(genre, bpm, events, music_version, seed)

func _play_saved(song: Dictionary) -> void:
	genre = int(song.get("genre", 0))
	bpm = int(song.get("bpm", NBStageDirector.BPMS[genre]))
	music_version = int(song.get("music_version", 1))
	seed = int(song.get("seed", 0))
	events = song.get("events", []).duplicate(true)
	last_song = song.duplicate(true)
	stage_index = 3
	stage = {"special": "NORMAL", "quota": 9, "velocity": 1.0, "initial_phase": 0.0}
	pins.clear()
	for item in events:
		if int(item.get("layer", 0)) == 3:
			pins.append({"angle": float(item.get("step", 0)) * TAU / 16.0, "lane": 0, "preload": false})
	motion.configure(0.0, float(bpm), 1.0, "NORMAL")
	drop_clock = 0.0
	saved_preview = true
	screen = "PREVIEW"
	audio.configure(genre, bpm, events, music_version, seed)

func _save_track() -> void:
	store.save_favorite(last_song)
	_feedback("SAVED TO LIBRARY", 1.6)

func _copy_code() -> void:
	var code := str(last_song.get("code", ""))
	DisplayServer.clipboard_set(code)
	var shared := NBAndroidShare.share_code(code)
	_feedback("ANDROID SHARE CHOOSER OPENED" if shared else "CODE COPIED", 1.6)

func _export_wav() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://exports"))
	var filename := "needlebeat_%d_%d.wav" % [int(last_song.get("genre", 0)), int(last_song.get("seed", 0))]
	last_export_path = "user://exports/" + filename
	var ok := audio.export_wav(events, genre, bpm, last_export_path, music_version, seed)
	if not ok:
		_feedback("WAV EXPORT FAILED", 2.4)
	elif OS.get_name() == "Android":
		_feedback("CHOOSE AN APP TO SHARE" if NBAndroidShare.share_wav(last_export_path)
			else "WAV SAVED / SHARING UNAVAILABLE", 2.4)
	else:
		_feedback("WAV EXPORTED TO USER DATA", 2.4)

func _draw() -> void:
	if adapt_scale <= 0.0:
		return
	draw_set_transform(adapt_offset, 0.0, Vector2(adapt_scale, adapt_scale))
	var palette: Array = NBStageDirector.PALETTES[clampi(genre if screen != "MENU" else selected_genre, 0, 4)]
	_background(palette)
	match screen:
		"MENU":
			_draw_menu(palette)
		"RECORD", "FLIGHT", "FAIL", "ENCORE", "STAGE_CLEAR":
			_draw_game(palette)
		"PAUSED":
			if paused_from in ["DROP_SHOW", "PREVIEW", "DROP_PAUSE"]:
				_draw_drop(palette)
			else:
				_draw_game(palette)
			_draw_pause_overlay(palette)
		"DROP_PAUSE", "DROP_SHOW", "PREVIEW":
			_draw_drop(palette)
		"RESULTS":
			_draw_results(palette)
		"LIBRARY":
			_draw_library(palette)
		"IMPORT":
			_draw_import(palette)
		"SETTINGS":
			_draw_settings(palette)
	if feedback_timer > 0.0 and screen in ["RESULTS", "MENU"]:
		_draw_notification(palette)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _text(message: String, x: float, y: float, points: int, color: Color, max_width: float = -1.0) -> void:
	draw_string(font, Vector2(x, y), message, HORIZONTAL_ALIGNMENT_LEFT, max_width, points, color)

func _rule(x: float, y: float, width: float, color: Color) -> void:
	draw_line(Vector2(x, y), Vector2(x + width, y), color, 1.0, true)

func _panel(rect: Rect2, palette: Array, light: bool = false) -> void:
	var base: Color = palette[1] if light else palette[0].lightened(0.105)
	draw_rect(rect, base)
	draw_rect(rect, palette[1].darkened(0.48) if light else palette[1].darkened(0.7), false, 1.0)

func _button(rect: Rect2, title: String, palette: Array, kind: String = "main") -> void:
	var primary := kind == "main"
	var color: Color = palette[2] if primary else palette[0].lightened(0.14)
	var text_color: Color = palette[0] if primary else palette[1]
	draw_rect(rect, color)
	draw_rect(rect, palette[1].darkened(0.6), false, 1.0)
	draw_line(rect.position + Vector2(15, rect.size.y - 10), rect.position + Vector2(31, rect.size.y - 10), text_color, 2.0, true)
	_text(title, rect.position.x + 19, rect.position.y + rect.size.y * 0.63, 18 if rect.size.x > 250 else 14, text_color)
	_text("↗", rect.end.x - 30, rect.position.y + rect.size.y * 0.63, 17, text_color)

func _background(palette: Array) -> void:
	var bg: Color = palette[0]
	var paper: Color = palette[1]
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), bg)
	# An editorial screenprint grid rather than a generic neon arcade gradient.
	for col in 9:
		var x := 24.0 + col * 54.0
		draw_line(Vector2(x, 0), Vector2(x - 35.0, HEIGHT), Color(paper.r, paper.g, paper.b, 0.033), 1.0)
	for row in 17:
		var y := 21.0 + row * 49.0
		draw_line(Vector2(0, y), Vector2(WIDTH, y), Color(paper.r, paper.g, paper.b, 0.026), 1.0)
	for speck in 140:
		var px := float((speck * 137 + 41) % 479)
		var py := float((speck * 311 + 71) % 853)
		draw_circle(Vector2(px, py), 0.55, Color(paper.r, paper.g, paper.b, 0.09))
	draw_rect(Rect2(16, 16, WIDTH - 32, HEIGHT - 32), Color(paper.r, paper.g, paper.b, 0.12), false, 1.0)
	_text("N B / D  —  INDEPENDENT AUDIO PRESS", 26, 36, 10, Color(paper.r, paper.g, paper.b, .56))

func _masthead(palette: Array, subtitle: String) -> void:
	_text("NEEDLEBEAT", 27, 83, 40, palette[1])
	_text("DROP", 30, 111, 23, palette[2])
	_text(subtitle, 122, 107, 11, palette[1].darkened(.29))
	_rule(28, 128, 425, Color(palette[1].r, palette[1].g, palette[1].b, .30))

func _record_art(palette: Array, phase: float, ring_pins: Array, special: String, active: int, ornament: bool = false) -> void:
	var bright: Color = palette[1]
	var base: Color = palette[0]
	var accent: Color = palette[2]
	draw_circle(CENTER + Vector2(2, 11), MAIN_RADIUS + 40.0, Color(0, 0, 0, .30))
	draw_circle(CENTER, MAIN_RADIUS + 33.0, base.lightened(.21))
	draw_circle(CENTER, MAIN_RADIUS + 29.0, bright.darkened(.62))
	draw_circle(CENTER, MAIN_RADIUS + 24.0, base.darkened(.35))
	draw_arc(CENTER, MAIN_RADIUS + 30.0, 0, TAU, 160, accent, 2.3, true)
	for groove in 15:
		var radius := 45.0 + float(groove) * 7.6
		var groove_color := Color(bright.r, bright.g, bright.b, .035 if groove % 2 == 0 else .065)
		draw_arc(CENTER, radius, 0, TAU, 144, groove_color, 1.0, true)
	for tick in 16:
		var a := phase + float(tick) * TAU / 16.0
		var direction := Vector2(cos(a), sin(a))
		var from := CENTER + direction * (MAIN_RADIUS - 6)
		var to := CENTER + direction * (MAIN_RADIUS + (4 if tick % 4 == 0 else 1))
		draw_line(from, to, palette[4] if tick % 4 == 0 else bright.darkened(.46), 2.1 if tick % 4 == 0 else 1.0, true)
	draw_circle(CENTER, 44, palette[3])
	draw_circle(CENTER + Vector2(1, 2), 37, base.darkened(.15))
	draw_circle(CENTER, 32, palette[1])
	draw_arc(CENTER, 38, 0, TAU, 100, palette[4], 2.0, true)
	_text("NB", CENTER.x - 22, CENTER.y + 6, 20, base)
	_text("45 RPM", CENTER.x - 17, CENTER.y + 21, 8, base.lightened(.20))
	draw_circle(CENTER, 3.1, palette[2])
	if special == "TWIN":
		draw_arc(CENTER, INNER_RADIUS, 0, TAU, 128,
			palette[2] if active == 1 else Color(bright.r, bright.g, bright.b, .21),
			4.0 if active == 1 else 1.4, true)
	else:
		draw_arc(CENTER, MAIN_RADIUS, 0, TAU, 128, Color(accent.r, accent.g, accent.b, .32), 2.0, true)
	for pin in ring_pins:
		_draw_pin(float(pin["angle"]) + phase, int(pin.get("lane", 0)),
			bool(pin.get("preload", false)), palette)
	if ornament and bool(store.data["settings"].get("motion", true)):
		var time := elapsed if screen == "MENU" else drop_clock
		var pulse := 3.0 * (1.0 + sin(time * 2.0))
		draw_arc(CENTER, MAIN_RADIUS + 37.0 + pulse, -PI * .32, PI * 1.40, 80,
			Color(accent.r, accent.g, accent.b, .42), 2, true)

func _draw_pin(world_angle: float, lane: int, is_preloaded: bool, palette: Array) -> void:
	var radius := INNER_RADIUS if lane == 1 else MAIN_RADIUS
	var ray := Vector2(cos(world_angle), sin(world_angle))
	var side := Vector2(-ray.y, ray.x)
	var head := CENTER + ray * radius
	var stem_start := CENTER + ray * (radius + 2.0)
	var stem_end := CENTER + ray * (radius + 44.0)
	var shaft_color: Color = palette[1].darkened(.36) if is_preloaded else palette[1]
	var head_color: Color = palette[4] if is_preloaded else palette[2]
	var head_radius := radius * sin(deg_to_rad(NBGeometry.HIT_DEG * .5))
	draw_line(stem_start + side * 1.5, stem_end + side * 1.5, Color(0, 0, 0, .44), 8.5, true)
	draw_line(stem_start, stem_end, shaft_color, 6, true)
	draw_line(stem_start + side * 1.5, stem_end + side * 1.5, palette[0].lightened(.36), 1.5, true)
	draw_circle(head, head_radius + 0.7, palette[0])
	draw_circle(head, head_radius - 1, head_color)
	draw_circle(head - ray * 2.5, 2.8, palette[1])
	draw_line(stem_end - side * 5.0, stem_end + side * 5.0, shaft_color, 2.2, true)

func _draw_shooter(palette: Array) -> void:
	var radius := INNER_RADIUS if stage.get("special", "NORMAL") == "TWIN" and active_lane == 1 else MAIN_RADIUS
	var target := CENTER + Vector2(0, radius)
	var intensity := 0.0
	if screen in ["RECORD", "ENCORE"]:
		var pred := NBGeometry.impact_local_angle(stage_clock, motion)
		var proximity := NBGeometry.evaluate(pred, pins, active_lane)
		intensity = 1.0 if bool(proximity["hit"]) else .0
	var aim_color: Color = Color("ee685a") if intensity > 0.0 else palette[2]
	draw_arc(target, 21.0, PI * .12, PI * .88, 25, aim_color, 2.5, true)
	var head_y := LAUNCH_Y
	if screen == "FLIGHT":
		var progress := clampf((stage_clock - flight_start) / NBGeometry.FLIGHT, 0, 1)
		var flight_radius := INNER_RADIUS if flight_lane == 1 else MAIN_RADIUS
		head_y = lerpf(LAUNCH_Y, CENTER.y + flight_radius, progress)
	var head := Vector2(CENTER.x, head_y)
	draw_line(head + Vector2(0, 2), head + Vector2(0, 48), palette[1], 8, true)
	draw_circle(head, 11.0, palette[2])
	draw_circle(head, 3.1, palette[1])
	if screen != "FLIGHT":
		for i in 3:
			var dx := -11.0 + i * 11.0
			draw_line(Vector2(CENTER.x + dx, LAUNCH_Y + 54), Vector2(CENTER.x + dx, LAUNCH_Y + 64),
				palette[1].darkened(.38), 1.5, true)

func _draw_menu(palette: Array) -> void:
	_masthead(palette, "EVERY SHOT WRITES THE SONG")
	_text("SET", 403, 89, 13, palette[4])
	_text("01   ROTATE / HIT / COMPOSE", 29, 174, 12, palette[1].darkened(.25))
	var menu_pins: Array = []
	for i in 7:
		menu_pins.append({"angle": float(i) * TAU / 7.0 + sin(float(i) * 4.0) * 0.10,
			"lane": 0, "preload": i < 2})
	_record_art(palette, (elapsed * 1.0 if bool(store.data["settings"].get("motion", true)) else 0.0), menu_pins, "NORMAL", 0, true)
	_text("FOUR RECORDS. ONE ORIGINAL SONG.", 48, 613, 15, palette[1])
	_text("‹", 51, 657, 32, palette[2])
	_text(NBStageDirector.GENRES[selected_genre], 152, 655, 21, palette[1], 250)
	_text("›", 398, 657, 32, palette[2])
	_text("COMPLETED: %d   /   TRACK %03d" % [int(store.data["completed"]), int(store.data["campaign_index"]) + 1],
		123, 673, 11, palette[1].darkened(.29))
	_button(Rect2(40, 685, 400, 65), "MAKE A TRACK", palette)
	_button(Rect2(40, 758, 193, 54), "DAILY", palette, "secondary")
	_button(Rect2(242, 758, 198, 54), "LIBRARY", palette, "secondary")

func _draw_game(palette: Array) -> void:
	_text("NEEDLEBEAT  /  SIDE A", 27, 72, 15, palette[1])
	_text("II", 426, 72, 17, palette[1])
	_text("%06d" % [total_score + stage_points], 27, 111, 30, palette[2])
	_text("SCORE", 290, 111, 12, palette[1].darkened(.30))
	_text("%d / 4" % [stage_index + 1], 397, 111, 20, palette[1])
	_rule(27, 127, 426, Color(palette[1].r, palette[1].g, palette[1].b, .30))
	for i in 4:
		var bar_color: Color = palette[2] if i < stage_index else (palette[4] if i == stage_index else palette[1].darkened(.65))
		draw_rect(Rect2(27 + i * 109, 140, 99, 5), bar_color)
		_text(NAMES[i], 27 + i * 109, 163, 10,
			palette[1] if i <= stage_index else palette[1].darkened(.62))
	var phase := motion.phase_at(stage_clock)
	_record_art(palette, phase, pins, str(stage["special"]), active_lane)
	# Inner needle follows the musical transport; hazards follow physical phase.
	var audio_phase := fposmod(audio.elapsed_seconds() * TAU / (240.0 / float(bpm)), TAU)
	var needle := Vector2(cos(audio_phase - PI * .5), sin(audio_phase - PI * .5))
	draw_line(CENTER + needle * 50.0, CENTER + needle * 64.0, palette[4], 2.5, true)
	if screen == "FLIGHT":
		_draw_shooter(palette)
	elif screen == "RECORD" or screen == "ENCORE":
		_draw_shooter(palette)
	if feedback_timer > 0 and screen != "FAIL":
		_text(feedback, 132, 624, 17, palette[4])
	var remaining := maxi(0, int(stage["quota"]) - placed)
	if screen == "ENCORE":
		remaining = encore_remaining
	_text("%d" % remaining, 31, 791, 55, palette[2])
	_text("%s SHOTS LEFT" % ("ENCORE" if screen == "ENCORE" else NAMES[stage_index]), 105, 764, 20, palette[1])
	_text("%s   •   %d BPM" % [str(stage["special"]), bpm], 105, 790, 12, palette[1].darkened(.33))
	if screen == "RECORD":
		_text("TAP ANYWHERE TO DROP A NOTE", 83, 808, 13, palette[1])
	if screen == "ENCORE":
		_text("TWO MORE NOTES. THE RECORD IS SAFE.", 68, 809, 13, palette[1])
	var warning := motion.upcoming_warning(stage_clock)
	if bool(warning.get("active", false)) and screen in ["RECORD", "FLIGHT", "ENCORE"]:
		var progress: float = warning["progress"]
		draw_arc(CENTER, MAIN_RADIUS + 28, -PI * 0.5,
			-PI * 0.5 + progress * TAU, 64, palette[4], 5, true)
		_text(str(warning["text"]), 177, 220, 14, palette[4])
	if screen == "FAIL":
		draw_rect(Rect2(0, 260, WIDTH, 281), Color(palette[0].r, palette[0].g, palette[0].b, .91))
		_text("CLASH", 76, 388, 78, palette[2])
		_text("THE RECORD SURVIVES. TRY AGAIN.", 73, 426, 13, palette[1])
		_text("TAP TO RETRY  ↗", 135, 482, 18, palette[4])
	if screen == "STAGE_CLEAR":
		draw_rect(Rect2(24, 569, 432, 273), palette[0].darkened(.25))
		_text("SIDE %s  /  MASTERED" % NAMES[stage_index], 48, 608, 18, palette[4])
		_text("+300  RECORD CLEAR", 48, 643, 16, palette[1])
		_text("THE MUSIC KEEPS BUILDING.", 48, 676, 13, palette[1].darkened(.20))
		_button(Rect2(40, 713, 400, 64), "HEAR THE DROP" if stage_index == 3 else "NEXT RECORD", palette)
		if not is_daily:
			_button(Rect2(40, 785, 400, 45), "OPTIONAL ENCORE  +500", palette, "secondary")

func _draw_drop(palette: Array) -> void:
	_masthead(palette, "MASTER RECORDING")
	var playback_phase := elapsed if screen == "DROP_PAUSE" else drop_clock * TAU / (240.0 / float(bpm))
	var reveal: Array = []
	for event in events:
		if int(event.get("layer", -1)) == 3:
			reveal.append({"angle": float(event["step"]) * TAU / 16.0,
				"lane": 0, "preload": false})
	_record_art(palette, playback_phase, reveal, "NORMAL", 0, true)
	if screen == "DROP_PAUSE":
		_text("THE", 46, 622, 31, palette[1])
		_text("DROP", 46, 687, 69, palette[2])
	else:
		_text("YOU MADE THIS.", 52, 634, 28, palette[1])
		_text("%d BPM   /   04 BARS   /   %s" % [bpm, NBStageDirector.GENRES[genre]], 53, 659, 12, palette[4])
		for i in 32:
			var height := 6.0 + 33.0 * absf(sin(drop_clock * 7.0 + i * 0.64) * cos(drop_clock * 1.3 + i * .14))
			draw_rect(Rect2(49 + i * 12.0, 741 - height, 6, height),
				palette[2] if i % 4 == 0 else palette[3])
		_text("TAP TO SKIP  /  KEEP THIS TRACK", 91, 805, 13, palette[1])

func _draw_results(palette: Array) -> void:
	_masthead(palette, "THE PRESSING IS COMPLETE")
	_text("YOU MADE", 32, 187, 40, palette[1])
	_text("A SONG.", 33, 242, 52, palette[2])
	_panel(Rect2(30, 265, 420, 255), palette)
	_text("FINAL SCORE", 52, 309, 15, palette[1].darkened(.25))
	_text("%06d" % total_score, 49, 376, 55, palette[2])
	_rule(50, 398, 380, palette[1].darkened(.58))
	_text("PERFECT NOTES", 49, 430, 11, palette[1].darkened(.25))
	_text("%02d" % perfect_count, 51, 471, 32, palette[1])
	_text("RETRIES", 260, 430, 11, palette[1].darkened(.25))
	_text("%02d" % retries, 260, 471, 32, palette[1])
	_text(NBStageDirector.GENRES[genre] + "   /   " + str(bpm) + " BPM", 51, 500, 14, palette[4])
	_button(Rect2(40, 536, 400, 50), "SAVE TO LIBRARY", palette)
	_button(Rect2(40, 591, 400, 50), "SHARE / COPY SONG CODE", palette, "secondary")
	_button(Rect2(40, 646, 400, 50), "EXPORT / SHARE WAV", palette, "secondary")
	_button(Rect2(40, 705, 400, 60), "NEW TRACK" if not is_daily else "RETRY DAILY", palette)
	_button(Rect2(40, 777, 400, 45), "MAIN MENU", palette, "secondary")

func _draw_notification(palette: Array) -> void:
	draw_rect(Rect2(31, 486, 418, 47), palette[4])
	_text(feedback, 49, 516, 15, palette[0])

func _draw_library(palette: Array) -> void:
	_masthead(palette, "YOUR STUDIO ARCHIVE")
	_text("FAVORITE PRESSINGS", 30, 178, 23, palette[1])
	_text("TAP ANY TRACK TO HEAR IT", 32, 203, 11, palette[4])
	var favorites: Array = store.data["favorites"]
	if favorites.is_empty():
		_text("THE SHELF IS STILL EMPTY.", 56, 371, 22, palette[1])
		_text("FINISH A TRACK AND SAVE IT HERE.", 56, 400, 13, palette[1].darkened(.25))
	else:
		for i in 5:
			var ix := library_page * 5 + i
			if ix >= favorites.size():
				break
			var track: Dictionary = favorites[ix]
			var y := 227.0 + i * 96.0
			_panel(Rect2(30, y, 420, 84), palette)
			_text("%02d" % (ix + 1), 46, y + 46, 29, palette[2])
			_text(NBStageDirector.GENRES[clampi(int(track.get("genre", 0)), 0, 4)], 107, y + 31, 19, palette[1])
			_text("%d BPM     •     %d POINTS" % [int(track.get("bpm", 120)), int(track.get("score", 0))],
				107, y + 57, 12, palette[4])
		_text("PAGE %d / %d" % [library_page + 1, maxi(1, int(ceil(float(favorites.size()) / 5.0)))],
			188, 699, 12, palette[1])
	_button(Rect2(38, 710, 192, 60), "PREV", palette, "secondary")
	_button(Rect2(248, 710, 192, 60), "NEXT", palette, "secondary")
	_button(Rect2(40, 780, 400, 50), "IMPORT SONG CODE", palette)
	_text("← MENU", 26, 77, 14, palette[4])

func _draw_import(palette: Array) -> void:
	_masthead(palette, "SONG CODE EXCHANGE")
	_text("IMPORT A RECORD", 31, 254, 33, palette[1])
	_text("Paste a friend's NBD1 or NBD2 code into the field.", 40, 305, 15, palette[4])
	_text("No account, server, or connection required.", 40, 329, 13, palette[1].darkened(.25))
	_button(Rect2(40, 439, 400, 66), "PLAY IMPORTED TRACK", palette)
	_button(Rect2(40, 526, 400, 50), "BACK TO LIBRARY", palette, "secondary")
	if not error_text.is_empty():
		_text(error_text, 40, 610, 13, palette[2])

func _draw_settings(palette: Array) -> void:
	_masthead(palette, "STUDIO CONTROLS")
	_text("SETTINGS", 38, 235, 45, palette[1])
	var settings: Dictionary = store.data["settings"]
	_button(Rect2(40, 305, 400, 60), "MUSIC  %d%%" % int(round(float(settings.get("music", .8)) * 100.0)), palette, "secondary")
	_button(Rect2(40, 375, 400, 60), "SOUND FX   %s" % ("ON" if settings.get("effects", true) else "OFF"), palette, "secondary")
	_button(Rect2(40, 445, 400, 60), "ANIMATIONS   %s" % ("ON" if settings.get("motion", true) else "REDUCED"), palette, "secondary")
	_button(Rect2(40, 515, 400, 60), "HAPTICS   %s" % ("ON" if settings.get("haptics", true) else "OFF"), palette, "secondary")
	_text("PORTRAIT • OFFLINE • ORIGINAL SOUND", 55, 643, 13, palette[4])
	_text("NEEDLEBEAT / FIRST PRESSING — 1.0", 59, 670, 11, palette[1].darkened(.32))
	_button(Rect2(40, 715, 400, 65), "BACK TO STUDIO", palette)

func _draw_pause_overlay(palette: Array) -> void:
	draw_rect(Rect2(0, 181, WIDTH, 495), Color(palette[0].r, palette[0].g, palette[0].b, .93))
	_text("PAUSED", 53, 383, 65, palette[1])
	_text("THE RECORD IS WAITING FOR YOU.", 56, 427, 15, palette[4])
	_button(Rect2(44, 473, 392, 64), "CONTINUE RECORD", palette)
	_button(Rect2(44, 549, 392, 58), "EXIT TO STUDIO", palette, "secondary")
