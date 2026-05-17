extends Node2D

const LEVEL_SELECT_COMBO := [
	"up",
	"up",
	"down",
	"down",
	"left",
	"right",
	"left",
	"right",
	"x",
	"y",
]

const MOBILE_SCALE := 1.0

var _elapsed: float = 0.0
var _ready_to_start: bool = false
var _level_select_unlocked: bool = false
var _combo_index: int = 0
var _selected_zone: int = 0
var _arcade_mode: bool = false
var _arcade_seed: int = 0
var _arcade_difficulty: int = ArcadeState.Difficulty.MEDIUM
var _root_menu_index: int = 0
var _settings_open: bool = false
var _settings_index: int = 0


func _ready() -> void:
	GameState.enforce_desktop_window_size()
	AlertSystem.reset()
	ColorSystem.reset()
	ArcadeState.reset()
	_arcade_seed = randi() % 90000 + 10000
	_arcade_difficulty = ArcadeState.Difficulty.MEDIUM
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func(): _ready_to_start = true)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _exit_tree() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not _ready_to_start:
		return

	if OS.has_feature("mobile") and event is InputEventScreenTouch and event.pressed:
		_handle_mobile_touch(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if _settings_open:
			_handle_settings_key(event.keycode)
			return
		if event.keycode == KEY_I:
			GameState.start_enemy_info()
			return
		if event.keycode == KEY_ESCAPE:
			_settings_open = false
			return
		if event.keycode == KEY_TAB:
			_root_menu_index = posmod(_root_menu_index + 1, 2)
			return
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_root_menu_index = posmod(_root_menu_index - 1, 2)
			return
		if event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_root_menu_index = posmod(_root_menu_index + 1, 2)
			return
		# Left/right arrows switch modes (when level select not active)
		if _root_menu_index == 0 and not _level_select_unlocked:
			if event.keycode == KEY_LEFT:
				_arcade_mode = false
				return
			if event.keycode == KEY_RIGHT:
				_arcade_mode = true
				return
		if _root_menu_index == 0 and _arcade_mode and event.keycode == KEY_R:
			_arcade_seed = randi() % 90000 + 10000
			return
		if _root_menu_index == 0 and _arcade_mode and event.keycode == KEY_LEFT:
			_arcade_difficulty = posmod(_arcade_difficulty - 1, ArcadeState.DIFFICULTY_NAMES.size())
			return
		if _root_menu_index == 0 and _arcade_mode and event.keycode == KEY_RIGHT:
			_arcade_difficulty = posmod(_arcade_difficulty + 1, ArcadeState.DIFFICULTY_NAMES.size())
			return
		if _root_menu_index == 0 and not _arcade_mode:
			var action := _handle_level_select_key(event.keycode)
			if action == "consumed":
				return
			if action == "start_selected":
				GameState.start_zone(_selected_zone)
				return
		if keycode_is_confirm(event.keycode):
			if _root_menu_index == 1:
				_settings_open = true
			elif _arcade_mode:
				GameState.start_arcade_run(_arcade_seed, _arcade_difficulty)
			else:
				GameState.start_run()
		return

	if event is InputEventJoypadButton and event.pressed:
		if _settings_open:
			_handle_settings_joypad(event.button_index)
			return
		if event.button_index == JOY_BUTTON_Y:
			GameState.start_enemy_info()
			return
		if event.button_index == JOY_BUTTON_B:
			_settings_open = false
			return
		if event.button_index == JOY_BUTTON_BACK:
			_root_menu_index = posmod(_root_menu_index + 1, 2)
			return
		# D-pad left/right switch modes (when level select not active)
		if _root_menu_index == 0 and not _level_select_unlocked:
			if event.button_index == JOY_BUTTON_DPAD_LEFT:
				_arcade_mode = false
				return
			if event.button_index == JOY_BUTTON_DPAD_RIGHT:
				_arcade_mode = true
				return
		if event.button_index == JOY_BUTTON_DPAD_UP:
			_root_menu_index = posmod(_root_menu_index - 1, 2)
			return
		if event.button_index == JOY_BUTTON_DPAD_DOWN:
			_root_menu_index = posmod(_root_menu_index + 1, 2)
			return
		if _root_menu_index == 0 and not _arcade_mode:
			var combo_action := _handle_level_select_joypad(event.button_index)
			if combo_action == "consumed":
				return
			if combo_action == "start_selected":
				GameState.start_zone(_selected_zone)
				return
		if _root_menu_index == 0 and _arcade_mode:
			if event.button_index == JOY_BUTTON_DPAD_LEFT:
				_arcade_difficulty = posmod(_arcade_difficulty - 1, ArcadeState.DIFFICULTY_NAMES.size())
				return
			if event.button_index == JOY_BUTTON_DPAD_RIGHT:
				_arcade_difficulty = posmod(_arcade_difficulty + 1, ArcadeState.DIFFICULTY_NAMES.size())
				return
		if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A:
			if _root_menu_index == 1:
				_settings_open = true
			elif _arcade_mode:
				GameState.start_arcade_run(_arcade_seed, _arcade_difficulty)
			else:
				GameState.start_run()

	if event is InputEventJoypadMotion:
		if not _ready_to_start or _settings_open:
			return
		if event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.5 and _root_menu_index == 0:
			_arcade_mode = event.axis_value > 0.0
		if _arcade_mode and _root_menu_index == 0 and event.axis == JOY_AXIS_LEFT_Y and absf(event.axis_value) > 0.6:
			_arcade_difficulty = posmod(
				_arcade_difficulty + (1 if event.axis_value > 0.0 else -1),
				ArcadeState.DIFFICULTY_NAMES.size()
			)


func _handle_settings_key(keycode: Key) -> void:
	match keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			_settings_open = false
		KEY_UP, KEY_W:
			_settings_index = posmod(_settings_index - 1, 6)
		KEY_DOWN, KEY_S:
			_settings_index = posmod(_settings_index + 1, 6)
		KEY_LEFT, KEY_A:
			_adjust_setting(-1)
		KEY_RIGHT, KEY_D:
			_adjust_setting(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_adjust_setting(1)


func _handle_settings_joypad(button: JoyButton) -> void:
	match button:
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			_settings_open = false
		JOY_BUTTON_DPAD_UP:
			_settings_index = posmod(_settings_index - 1, 6)
		JOY_BUTTON_DPAD_DOWN:
			_settings_index = posmod(_settings_index + 1, 6)
		JOY_BUTTON_DPAD_LEFT:
			_adjust_setting(-1)
		JOY_BUTTON_DPAD_RIGHT:
			_adjust_setting(1)
		JOY_BUTTON_A, JOY_BUTTON_START:
			_adjust_setting(1)


func _adjust_setting(direction: int) -> void:
	match _settings_index:
		0:
			Settings.cycle_auto_fire_mode(direction)
		1:
			Settings.adjust_music_volume(direction)
		2:
			Settings.adjust_fx_volume(direction)
		3:
			Settings.adjust_stealth_brightness(direction)
		4:
			Settings.adjust_combat_brightness(direction)
		5:
			Settings.adjust_crt_intensity(direction)


func keycode_is_confirm(keycode: Key) -> bool:
	return keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE


func _touch_to_ref(screen_pos: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var offset := Vector2(vp.x * (1.0 - MOBILE_SCALE) * 0.5, vp.y * (1.0 - MOBILE_SCALE) * 0.5)
	return (screen_pos - offset) / MOBILE_SCALE


func _handle_mobile_settings_touch(screen_pos: Vector2) -> void:
	var vp := get_viewport_rect().size
	var header_h := maxf(vp.y * 0.16, 52.0)
	var footer_h := maxf(vp.y * 0.18, 60.0)
	# Header or footer closes settings
	if screen_pos.y < header_h or screen_pos.y >= vp.y - footer_h:
		_settings_open = false
		return
	# Row taps: left half = decrease, right half = increase
	var rows_area_h := vp.y - header_h - footer_h
	var row_h := rows_area_h / 6.0
	for row in 6:
		var row_top := header_h + row * row_h
		if screen_pos.y >= row_top and screen_pos.y < row_top + row_h:
			_settings_index = row
			_adjust_setting(-1 if screen_pos.x < vp.x * 0.5 else 1)
			return


func _mobile_button_rects(vp: Vector2) -> Dictionary:
	var cx := vp.x * 0.5
	var btn_w := 290.0
	var btn_h := 120.0
	var gap   := 24.0
	var total := btn_w * 2.0 + gap
	var btn_y := vp.y * 0.46 - btn_h * 0.5
	var story_rect   := Rect2(cx - total * 0.5,            btn_y, btn_w, btn_h)
	var arcade_rect  := Rect2(cx - total * 0.5 + btn_w + gap, btn_y, btn_w, btn_h)
	var settings_w   := 600.0
	var settings_h   := 70.0
	var settings_rect := Rect2(cx - settings_w * 0.5, vp.y * 0.70 - settings_h * 0.5,
			settings_w, settings_h)
	return {
		"story":    story_rect,
		"arcade":   arcade_rect,
		"settings": settings_rect,
	}


func _handle_mobile_touch(screen_pos: Vector2) -> void:
	if _settings_open:
		_handle_mobile_settings_touch(screen_pos)
		return

	var ref := _touch_to_ref(screen_pos)
	var vp  := get_viewport_rect().size
	var rects := _mobile_button_rects(vp)

	if rects["story"].has_point(ref):
		_arcade_mode = false
		_root_menu_index = 0
		return

	if rects["arcade"].has_point(ref):
		_arcade_mode = true
		_root_menu_index = 0
		return

	if rects["settings"].has_point(ref):
		_settings_open = true
		_root_menu_index = 1
		return

	if ref.y > vp.y * 0.75 and _root_menu_index == 0:
		if _arcade_mode:
			GameState.start_arcade_run(_arcade_seed, _arcade_difficulty)
		else:
			GameState.start_run()


func _handle_level_select_key(keycode: Key) -> String:
	if _level_select_unlocked:
		if keycode == KEY_LEFT or keycode == KEY_UP:
			_selected_zone = posmod(_selected_zone - 1, GameState.ZONE_SCENES.size())
			return "consumed"
		if keycode == KEY_RIGHT or keycode == KEY_DOWN:
			_selected_zone = posmod(_selected_zone + 1, GameState.ZONE_SCENES.size())
			return "consumed"
		if keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE:
			return "start_selected"
		if keycode >= KEY_1 and keycode < KEY_1 + GameState.ZONE_SCENES.size():
			GameState.start_zone(int(keycode - KEY_1))
			return "consumed"

	var combo_input := _keycode_to_combo_token(keycode)
	if combo_input != "":
		_advance_level_select_combo(combo_input)
		return "consumed"
	return "pass"


func _handle_level_select_joypad(button: JoyButton) -> String:
	if _level_select_unlocked:
		if button == JOY_BUTTON_DPAD_LEFT or button == JOY_BUTTON_DPAD_UP:
			_selected_zone = posmod(_selected_zone - 1, GameState.ZONE_SCENES.size())
			return "consumed"
		if button == JOY_BUTTON_DPAD_RIGHT or button == JOY_BUTTON_DPAD_DOWN:
			_selected_zone = posmod(_selected_zone + 1, GameState.ZONE_SCENES.size())
			return "consumed"
		if button == JOY_BUTTON_X or button == JOY_BUTTON_A or button == JOY_BUTTON_START:
			return "start_selected"

	var combo_input := _joy_button_to_combo_token(button)
	if combo_input != "":
		_advance_level_select_combo(combo_input)
		return "consumed"
	return "pass"


func _advance_level_select_combo(input_token: String) -> void:
	if input_token == LEVEL_SELECT_COMBO[_combo_index]:
		_combo_index += 1
		if _combo_index >= LEVEL_SELECT_COMBO.size():
			_level_select_unlocked = true
			_combo_index = 0
		return
	_combo_index = 1 if input_token == LEVEL_SELECT_COMBO[0] else 0


func _keycode_to_combo_token(keycode: Key) -> String:
	match keycode:
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		KEY_X:
			return "x"
		KEY_Y:
			return "y"
		_:
			return ""


func _joy_button_to_combo_token(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_DPAD_UP:
			return "up"
		JOY_BUTTON_DPAD_DOWN:
			return "down"
		JOY_BUTTON_DPAD_LEFT:
			return "left"
		JOY_BUTTON_DPAD_RIGHT:
			return "right"
		JOY_BUTTON_X:
			return "x"
		JOY_BUTTON_Y:
			return "y"
		_:
			return ""


func _draw() -> void:
	var vp  := get_viewport_rect().size
	var t   := _elapsed
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.025, 0.01, 1.0))

	# Grid
	var gc := Color(0.1, 0.24, 0.14, 0.3)
	var sp := 28.0
	var gx := 0.0
	while gx <= vp.x:
		draw_line(Vector2(gx, 0.0), Vector2(gx, vp.y), gc, 0.5)
		gx += sp
	var gy := 0.0
	while gy <= vp.y:
		draw_line(Vector2(0.0, gy), Vector2(vp.x, gy), gc, 0.5)
		gy += sp

	# Animated scan line
	var scan_y := fmod(t * 180.0, vp.y + 60.0) - 30.0
	draw_line(Vector2(0.0, scan_y), Vector2(vp.x, scan_y),
			Color(0.3, 0.9, 0.45, 0.06), 1.0)

	# Mobile settings: full-screen overlay at screen resolution, no zoom
	if OS.has_feature("mobile") and _settings_open:
		_draw_mobile_settings_fullscreen(vp, font)
		return

	if OS.has_feature("mobile"):
		_draw_mobile_start(vp, font, t)
		return

	# Title glow (layered for phosphor bloom)
	var cx  := vp.x * 0.5
	var ty  := vp.y * 0.36
	var title := "SIGNAL DARK"
	for i in 3:
		var spread := (3 - i) * 3.0
		draw_string(font,
				Vector2(cx - 104.0 + spread * 0.3, ty + spread * 0.3),
				title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(0.15, 0.7, 0.3, 0.12 - i * 0.03))
	draw_string(font, Vector2(cx - 104.0, ty), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
			Color(0.42, 1.0, 0.56, 0.95))

	# Tagline
	draw_string(font, Vector2(cx - 68.0, ty + 30.0),
			"STEALTH PROTOCOL  //  ZONES 01-04",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.22, 0.65, 0.33, 0.5))

	# Divider
	draw_line(Vector2(cx - 120.0, ty + 50.0), Vector2(cx + 120.0, ty + 50.0),
			Color(0.22, 0.6, 0.32, 0.22), 1.0)

	# ── Mode selector ────────────────────────────────────────────────────────
	var mode_y := vp.y * 0.52
	var story_selected := _root_menu_index == 0 and not _arcade_mode
	var arcade_selected := _root_menu_index == 0 and _arcade_mode
	var settings_selected := _root_menu_index == 1
	var story_col  := Color(0.55, 1.0, 0.65, 0.95) if story_selected else Color(0.22, 0.55, 0.30, 0.45)
	var arcade_col := Color(0.45, 0.82, 1.0, 0.95) if arcade_selected else Color(0.18, 0.48, 0.72, 0.45)
	var settings_col := Color(0.92, 0.92, 0.62, 0.95) if settings_selected else Color(0.46, 0.48, 0.26, 0.5)

	# Story option
	if story_selected:
		draw_rect(Rect2(cx - 130.0, mode_y - 16.0, 114.0, 22.0),
				Color(0.18, 0.55, 0.28, 0.18), true)
		draw_rect(Rect2(cx - 130.0, mode_y - 16.0, 114.0, 22.0),
				Color(0.35, 0.9, 0.48, 0.35), false, 1.0)
	draw_string(font, Vector2(cx - 122.0, mode_y),
			"▶ STORY MODE" if story_selected else "  STORY MODE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, story_col)

	# Arcade option
	if arcade_selected:
		draw_rect(Rect2(cx + 4.0, mode_y - 16.0, 126.0, 22.0),
				Color(0.08, 0.25, 0.55, 0.22), true)
		draw_rect(Rect2(cx + 4.0, mode_y - 16.0, 126.0, 22.0),
				Color(0.30, 0.65, 1.0, 0.45), false, 1.0)
	draw_string(font, Vector2(cx + 12.0, mode_y),
			"▶ ARCADE MODE" if arcade_selected else "  ARCADE MODE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, arcade_col)

	if settings_selected:
		draw_rect(Rect2(cx - 72.0, mode_y + 24.0, 144.0, 22.0),
				Color(0.44, 0.44, 0.10, 0.18), true)
		draw_rect(Rect2(cx - 72.0, mode_y + 24.0, 144.0, 22.0),
				Color(0.86, 0.86, 0.34, 0.35), false, 1.0)
	draw_string(font, Vector2(cx - 56.0, mode_y + 40.0),
			"▶ SETTINGS" if settings_selected else "  SETTINGS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, settings_col)

	if OS.has_feature("mobile"):
		draw_string(font, Vector2(cx - 130.0, mode_y + 14.0),
				"TAP MODE TO SELECT  //  TAP BELOW TO START",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(0.28, 0.62, 0.36, 0.50))
	else:
		draw_string(font, Vector2(cx - 130.0, mode_y + 14.0),
				"TAB/BACK  or  UP/DOWN  to switch",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(0.28, 0.62, 0.36, 0.50))
		draw_string(font, Vector2(cx - 130.0, mode_y + 28.0),
				"I  /  Y  —  ENEMY INDEX",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(0.32, 0.70, 0.42, 0.54))

	# ── Mode-specific prompts ─────────────────────────────────────────────────
	if _settings_open:
		var panel := Rect2(Vector2(cx - 188.0, mode_y + 62.0), Vector2(376.0, 270.0))
		draw_rect(panel, Color(0.02, 0.05, 0.04, 0.9), true)
		draw_rect(panel, Color(0.30, 0.82, 0.52, 0.22), false, 1.0)
		draw_string(font, Vector2(panel.position.x + 16.0, panel.position.y + 22.0),
				"SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.66, 1.0, 0.78, 0.95))
		if OS.has_feature("mobile"):
			draw_string(font, Vector2(panel.position.x + 16.0, panel.position.y + 40.0),
					"TAP ROW TO CYCLE",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.38, 0.74, 0.48, 0.62))
			draw_string(font, Vector2(panel.position.x + 16.0, panel.position.y + 55.0),
					"TAP OUTSIDE TO CLOSE",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.38, 0.74, 0.48, 0.62))
		else:
			draw_string(font, Vector2(panel.position.x + 16.0, panel.position.y + 40.0),
					"LEFT/RIGHT or A/D  //  DPAD LEFT/RIGHT  to change",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.38, 0.74, 0.48, 0.62))
			draw_string(font, Vector2(panel.position.x + 16.0, panel.position.y + 55.0),
					"ESC / B  to close",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.38, 0.74, 0.48, 0.62))
		var row_y := panel.position.y + 72.0
		var row_height := 28.0
		for row in 6:
			var selected_row := _settings_index == row
			if selected_row:
				draw_rect(Rect2(Vector2(panel.position.x + 10.0, row_y + row * row_height), Vector2(panel.size.x - 20.0, row_height)),
						Color(0.16, 0.48, 0.24, 0.18), true)
		var _rows := [
			["AUTO FIRE",       Settings.get_auto_fire_summary()],
			["MUSIC",           Settings.get_music_volume_summary()],
			["FX",              Settings.get_fx_volume_summary()],
			["STEALTH BRIGHT",  Settings.get_stealth_brightness_summary()],
			["COMBAT BRIGHT",   Settings.get_combat_brightness_summary()],
			["CRT INTENSITY",   Settings.get_crt_intensity_summary()],
		]
		for i in _rows.size():
			var label: String = _rows[i][0]
			var value: String = _rows[i][1]
			var sel := _settings_index == i
			draw_string(font, Vector2(panel.position.x + 18.0, row_y + 19.0 + i * row_height),
					("%s %s" % ["▶" if sel else " ", label]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.74, 1.0, 0.82, 0.96) if sel else Color(0.46, 0.82, 0.56, 0.72))
			draw_string(font, Vector2(panel.end.x - 136.0, row_y + 19.0 + i * row_height),
					value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.84, 0.96, 0.90, 0.94))
		draw_string(font, Vector2(panel.position.x + 18.0, panel.position.y + 250.0),
				"BRIGHT 0%=darkest  100%=most visible",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.42, 0.76, 0.52, 0.64))
	elif _arcade_mode:
		var seed_y := mode_y + 62.0
		draw_string(font, Vector2(cx - 60.0, seed_y),
				"SEED  %d" % _arcade_seed,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Color(0.45, 0.82, 1.0, 0.95))
		draw_string(font, Vector2(cx - 60.0, seed_y + 22.0),
				"DIFFICULTY  %s" % ArcadeState.DIFFICULTY_NAMES[_arcade_difficulty],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.62, 0.90, 1.0, 0.86))
		draw_string(font, Vector2(cx - 60.0, seed_y + 38.0),
				"R  —  NEW SEED",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.28, 0.60, 0.88, 0.50))
		draw_string(font, Vector2(cx - 60.0, seed_y + 54.0),
				"LEFT/RIGHT  —  CHANGE DIFFICULTY",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.32, 0.72, 0.92, 0.58))
		if fmod(t, 1.3) < 0.82 and _root_menu_index == 0:
			var launch_label := "TAP TO LAUNCH" if OS.has_feature("mobile") else "PRESS ENTER TO LAUNCH RUN"
			draw_string(font, Vector2(cx - 96.0, seed_y + 82.0),
					launch_label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.40, 0.82, 1.0, 0.92))
	else:
		if _level_select_unlocked:
			draw_string(font, Vector2(cx - 118.0, mode_y + 48.0),
					"LEVEL SELECT UNLOCKED",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.48, 1.0, 0.62, 0.92))
			var menu_y := mode_y + 86.0
			for i in GameState.ZONE_SCENES.size():
				var sel := i == _selected_zone
				var label := "ZONE %02d" % (i + 1)
				var col := Color(0.60, 1.0, 0.70, 0.95) if sel else Color(0.24, 0.62, 0.34, 0.58)
				draw_string(font, Vector2(cx - 78.0 + i * 86.0, menu_y),
						"%d:%s" % [i + 1, label],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			draw_string(font, Vector2(cx - 138.0, menu_y + 22.0),
					"ARROWS OR D-PAD TO CHOOSE  //  ENTER OR A TO DEPLOY",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.28, 0.78, 0.42, 0.62))
		else:
			if fmod(t, 1.3) < 0.82 and _root_menu_index == 0:
				var start_label := "TAP TO START" if OS.has_feature("mobile") else "PRESS ENTER TO START"
				draw_string(font, Vector2(cx - 96.0, mode_y + 62.0),
						start_label,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
						Color(0.38, 1.0, 0.52, 0.90))

	# Controls block
	var hy    := vp.y * 0.76
	var hc    := Color(0.18, 0.52, 0.27, 0.48)
	if OS.has_feature("mobile"):
		var hints := [
			"MOVE          LEFT THUMB STICK",
			"DARK MODE     STL               (stealth — reduces emission)",
			"FIRE          RIGHT STICK PUSH",
			"BOOST         BST",
			"EMP PROBE     EMP",
		]
		for i in hints.size():
			draw_string(font, Vector2(cx - 130.0, hy + i * 15.0),
					hints[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, hc)
	else:
		var hints := [
			"MOVE          WASD  /  LEFT STICK",
			"DARK MODE     SHIFT  /  L2          (reduces emission)",
			"FIRE          LMB  /  R1            (AUTO FIRE OPTIONAL IN COMBAT)",
			"BOOST         SPACE  /  R2",
			"PROBE         Q  /  X               (decoy beacon)",
			"SUPPRESS      E  /  A               (silent kill from behind)",
			"HACK          F or RMB  /  Y        (gate / objective interact)",
		]
		for i in hints.size():
			draw_string(font, Vector2(cx - 130.0, hy + i * 15.0),
					hints[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, hc)

	# Version / build tag
	draw_string(font, Vector2(16.0, vp.y - 16.0),
			"SIGNAL DARK  //  PROTOTYPE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.15, 0.42, 0.22, 0.35))


func _draw_mobile_settings_fullscreen(vp: Vector2, font: Font) -> void:
	var cx := vp.x * 0.5
	var header_h := maxf(vp.y * 0.16, 52.0)
	var footer_h := maxf(vp.y * 0.18, 60.0)
	var rows_area_y := header_h
	var rows_area_h := vp.y - header_h - footer_h
	var row_h := rows_area_h / 6.0

	# Dark background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.03, 0.02, 0.97), true)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.28, 0.72, 0.46, 0.14), false, 1.0)

	# Header
	draw_line(Vector2(0.0, header_h), Vector2(vp.x, header_h),
			Color(0.28, 0.68, 0.42, 0.28), 1.0)
	draw_string(font, Vector2(24.0, header_h * 0.66),
			"SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
			Color(0.66, 1.0, 0.78, 0.95))
	draw_string(font, Vector2(24.0, header_h * 0.90),
			"TAP LEFT SIDE  ◀  TO LOWER     ▶  RIGHT SIDE TO RAISE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.36, 0.72, 0.46, 0.55))

	# Rows
	var rows_data: Array = [
		["AUTO FIRE",      Settings.get_auto_fire_summary()],
		["MUSIC",          Settings.get_music_volume_summary()],
		["FX",             Settings.get_fx_volume_summary()],
		["STEALTH BRIGHT", Settings.get_stealth_brightness_summary()],
		["COMBAT BRIGHT",  Settings.get_combat_brightness_summary()],
		["CRT INTENSITY",  Settings.get_crt_intensity_summary()],
	]
	for i in rows_data.size():
		var label: String = rows_data[i][0]
		var value: String = rows_data[i][1]
		var sel := _settings_index == i
		var row_top := rows_area_y + i * row_h
		var text_y := row_top + row_h * 0.64

		if sel:
			draw_rect(Rect2(0.0, row_top + 2.0, vp.x, row_h - 4.0),
					Color(0.14, 0.44, 0.22, 0.22), true)
		draw_line(Vector2(0.0, row_top + row_h), Vector2(vp.x, row_top + row_h),
				Color(0.18, 0.48, 0.28, 0.18), 1.0)

		# Left arrow
		draw_string(font, Vector2(18.0, text_y), "◀",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
				Color(0.44, 0.88, 0.56, 0.75))
		# Label
		draw_string(font, Vector2(60.0, text_y), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
				Color(0.74, 1.0, 0.82, 0.96) if sel else Color(0.44, 0.80, 0.54, 0.75))
		# Value (centered)
		draw_string(font, Vector2(cx - 40.0, text_y), value,
				HORIZONTAL_ALIGNMENT_CENTER, 100, 30,
				Color(0.90, 1.0, 0.94, 0.96))
		# Right arrow
		draw_string(font, Vector2(vp.x - 46.0, text_y), "▶",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
				Color(0.44, 0.88, 0.56, 0.75))

	# Footer / Done button
	draw_line(Vector2(0.0, vp.y - footer_h), Vector2(vp.x, vp.y - footer_h),
			Color(0.28, 0.68, 0.42, 0.28), 1.0)
	var done_w := 160.0
	var done_h := 42.0
	var done_rect := Rect2(cx - done_w * 0.5, vp.y - footer_h + (footer_h - done_h) * 0.5,
			done_w, done_h)
	draw_rect(done_rect, Color(0.14, 0.46, 0.22, 0.32), true)
	draw_rect(done_rect, Color(0.34, 0.88, 0.46, 0.50), false, 1.5)
	draw_string(font, Vector2(cx - 30.0, done_rect.position.y + done_h * 0.70),
			"DONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			Color(0.55, 1.0, 0.68, 0.96))


func _draw_mobile_start(vp: Vector2, font: Font, t: float) -> void:
	var cx := vp.x * 0.5

	# ── Title ─────────────────────────────────────────────────────────────────
	var title_y := vp.y * 0.22
	var title := "SIGNAL DARK"
	for i in 3:
		var spread := (3 - i) * 4.0
		draw_string(font, Vector2(cx + spread * 0.3, title_y + spread * 0.3),
				title, HORIZONTAL_ALIGNMENT_CENTER, -1, 65,
				Color(0.15, 0.7, 0.3, 0.12 - i * 0.03))
	draw_string(font, Vector2(cx, title_y), title,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 65,
			Color(0.42, 1.0, 0.56, 0.95))

	# ── Tagline ────────────────────────────────────────────────────────────────
	draw_string(font, Vector2(cx, vp.y * 0.30),
			"STEALTH PROTOCOL  //  ZONES 01-04",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 22,
			Color(0.22, 0.65, 0.33, 0.55))

	# ── Divider ────────────────────────────────────────────────────────────────
	var div_y := vp.y * 0.36
	draw_line(Vector2(cx - 300.0, div_y), Vector2(cx + 300.0, div_y),
			Color(0.22, 0.6, 0.32, 0.22), 1.0)

	# ── Mode buttons ──────────────────────────────────────────────────────────
	var rects := _mobile_button_rects(vp)
	var story_rect  : Rect2 = rects["story"]
	var arcade_rect : Rect2 = rects["arcade"]

	var story_selected   := _root_menu_index == 0 and not _arcade_mode
	var arcade_selected  := _root_menu_index == 0 and _arcade_mode
	var settings_selected := _root_menu_index == 1

	var story_col  := Color(0.55, 1.0, 0.65, 0.95)  if story_selected  else Color(0.22, 0.55, 0.30, 0.45)
	var arcade_col := Color(0.45, 0.82, 1.0, 0.95) if arcade_selected else Color(0.18, 0.48, 0.72, 0.45)

	# Story button background
	draw_rect(story_rect,
			Color(0.18, 0.55, 0.28, 0.25) if story_selected else Color(0.05, 0.12, 0.07, 0.25), true)
	draw_rect(story_rect,
			Color(0.35, 0.9, 0.48, 0.55) if story_selected else Color(0.22, 0.45, 0.28, 0.30), false, 1.5)
	draw_string(font,
			Vector2(story_rect.get_center().x, story_rect.get_center().y + 14.0),
			"▶ STORY MODE" if story_selected else "STORY MODE",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 28, story_col)

	# Arcade button background
	draw_rect(arcade_rect,
			Color(0.08, 0.25, 0.55, 0.25) if arcade_selected else Color(0.05, 0.08, 0.16, 0.25), true)
	draw_rect(arcade_rect,
			Color(0.30, 0.65, 1.0, 0.55) if arcade_selected else Color(0.18, 0.30, 0.55, 0.30), false, 1.5)
	draw_string(font,
			Vector2(arcade_rect.get_center().x, arcade_rect.get_center().y + 14.0),
			"▶ ARCADE MODE" if arcade_selected else "ARCADE MODE",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 28, arcade_col)

	# ── Arcade sub-row ────────────────────────────────────────────────────────
	if arcade_selected:
		var sub_y := arcade_rect.position.y + arcade_rect.size.y + 14.0
		draw_string(font, Vector2(cx, sub_y),
				"SEED  %d" % _arcade_seed,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 22,
				Color(0.45, 0.82, 1.0, 0.90))
		draw_string(font, Vector2(cx, sub_y + 28.0),
				"DIFFICULTY  %s" % ArcadeState.DIFFICULTY_NAMES[_arcade_difficulty],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 22,
				Color(0.62, 0.90, 1.0, 0.80))
		draw_string(font, Vector2(cx, sub_y + 50.0),
				"R  —  NEW SEED",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16,
				Color(0.28, 0.60, 0.88, 0.50))

	# ── Level-select zone list ─────────────────────────────────────────────────
	if _level_select_unlocked:
		var zone_y := vp.y * 0.55
		draw_string(font, Vector2(cx, zone_y - 26.0),
				"LEVEL SELECT UNLOCKED",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 22,
				Color(0.48, 1.0, 0.62, 0.92))
		var slot_w := 120.0
		var total_w := GameState.ZONE_SCENES.size() * slot_w
		var zone_x := cx - total_w * 0.5
		for i in GameState.ZONE_SCENES.size():
			var sel := i == _selected_zone
			var col := Color(0.60, 1.0, 0.70, 0.95) if sel else Color(0.24, 0.62, 0.34, 0.58)
			draw_string(font, Vector2(zone_x + i * slot_w, zone_y),
					"ZONE %02d" % (i + 1),
					HORIZONTAL_ALIGNMENT_CENTER, -1, 22, col)

	# ── SETTINGS strip ────────────────────────────────────────────────────────
	var settings_rect : Rect2 = rects["settings"]
	var settings_col := Color(0.92, 0.92, 0.62, 0.95) if settings_selected else Color(0.46, 0.48, 0.26, 0.55)
	draw_rect(settings_rect,
			Color(0.44, 0.44, 0.10, 0.20) if settings_selected else Color(0.10, 0.10, 0.04, 0.20), true)
	draw_rect(settings_rect,
			Color(0.86, 0.86, 0.34, 0.50) if settings_selected else Color(0.42, 0.44, 0.18, 0.28), false, 1.5)
	draw_string(font, Vector2(settings_rect.get_center().x, settings_rect.get_center().y + 10.0),
			"▶ SETTINGS" if settings_selected else "SETTINGS",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24, settings_col)

	# ── Tap-to-start / tap-to-launch ─────────────────────────────────────────
	if fmod(t, 1.3) < 0.82 and _root_menu_index == 0:
		var tap_label := "TAP TO LAUNCH RUN" if _arcade_mode else "TAP TO START"
		draw_string(font, Vector2(cx, vp.y * 0.87),
				tap_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 26,
				Color(0.45, 0.82, 1.0, 0.92) if _arcade_mode else Color(0.38, 1.0, 0.52, 0.90))

	# ── Version tag ───────────────────────────────────────────────────────────
	draw_string(font, Vector2(vp.x - 16.0, vp.y - 16.0),
			"SIGNAL DARK  //  PROTOTYPE",
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 16,
			Color(0.15, 0.42, 0.22, 0.40))
