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

var _elapsed: float = 0.0
var _ready_to_start: bool = false
var _level_select_unlocked: bool = false
var _combo_index: int = 0
var _selected_zone: int = 0
var _arcade_mode: bool = false
var _arcade_seed: int = 0
var _arcade_difficulty: int = ArcadeState.Difficulty.MEDIUM


func _ready() -> void:
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


func _input(event: InputEvent) -> void:
	if not _ready_to_start:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			GameState.start_enemy_info()
			return
		if event.keycode == KEY_TAB:
			_arcade_mode = not _arcade_mode
			return
		# Left/right arrows switch modes (when level select not active)
		if not _level_select_unlocked:
			if event.keycode == KEY_LEFT:
				_arcade_mode = false
				return
			if event.keycode == KEY_RIGHT:
				_arcade_mode = true
				return
		if _arcade_mode and event.keycode == KEY_R:
			_arcade_seed = randi() % 90000 + 10000
			return
		if _arcade_mode and (event.keycode == KEY_UP or event.keycode == KEY_W):
			_arcade_difficulty = posmod(_arcade_difficulty - 1, ArcadeState.DIFFICULTY_NAMES.size())
			return
		if _arcade_mode and (event.keycode == KEY_DOWN or event.keycode == KEY_S):
			_arcade_difficulty = posmod(_arcade_difficulty + 1, ArcadeState.DIFFICULTY_NAMES.size())
			return
		if not _arcade_mode:
			var action := _handle_level_select_key(event.keycode)
			if action == "consumed":
				return
			if action == "start_selected":
				GameState.start_zone(_selected_zone)
				return
		if keycode_is_confirm(event.keycode):
			if _arcade_mode:
				GameState.start_arcade_run(_arcade_seed, _arcade_difficulty)
			else:
				GameState.start_run()
		return

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_Y:
			GameState.start_enemy_info()
			return
		if event.button_index == JOY_BUTTON_BACK:
			_arcade_mode = not _arcade_mode
			return
		# D-pad left/right switch modes (when level select not active)
		if not _level_select_unlocked:
			if event.button_index == JOY_BUTTON_DPAD_LEFT:
				_arcade_mode = false
				return
			if event.button_index == JOY_BUTTON_DPAD_RIGHT:
				_arcade_mode = true
				return
		if not _arcade_mode:
			var combo_action := _handle_level_select_joypad(event.button_index)
			if combo_action == "consumed":
				return
			if combo_action == "start_selected":
				GameState.start_zone(_selected_zone)
				return
		if _arcade_mode:
			if event.button_index == JOY_BUTTON_DPAD_UP:
				_arcade_difficulty = posmod(_arcade_difficulty - 1, ArcadeState.DIFFICULTY_NAMES.size())
				return
			if event.button_index == JOY_BUTTON_DPAD_DOWN:
				_arcade_difficulty = posmod(_arcade_difficulty + 1, ArcadeState.DIFFICULTY_NAMES.size())
				return
		if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A:
			if _arcade_mode:
				GameState.start_arcade_run(_arcade_seed, _arcade_difficulty)
			else:
				GameState.start_run()

	if event is InputEventJoypadMotion:
		if not _ready_to_start:
			return
		if event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.5:
			_arcade_mode = event.axis_value > 0.0
		if _arcade_mode and event.axis == JOY_AXIS_LEFT_Y and absf(event.axis_value) > 0.6:
			_arcade_difficulty = posmod(
				_arcade_difficulty + (1 if event.axis_value > 0.0 else -1),
				ArcadeState.DIFFICULTY_NAMES.size()
			)


func keycode_is_confirm(keycode: Key) -> bool:
	return keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE


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
		draw_line(Vector2(gx, 0.0), Vector2(gx, vp.y), gc, 1.0)
		gx += sp
	var gy := 0.0
	while gy <= vp.y:
		draw_line(Vector2(0.0, gy), Vector2(vp.x, gy), gc, 1.0)
		gy += sp

	# Animated scan line
	var scan_y := fmod(t * 180.0, vp.y + 60.0) - 30.0
	draw_line(Vector2(0.0, scan_y), Vector2(vp.x, scan_y),
			Color(0.3, 0.9, 0.45, 0.06), 2.0)

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
	var story_col  := Color(0.55, 1.0, 0.65, 0.95) if not _arcade_mode else Color(0.22, 0.55, 0.30, 0.45)
	var arcade_col := Color(0.45, 0.82, 1.0, 0.95) if _arcade_mode     else Color(0.18, 0.48, 0.72, 0.45)

	# Story option
	if not _arcade_mode:
		draw_rect(Rect2(cx - 130.0, mode_y - 16.0, 114.0, 22.0),
				Color(0.18, 0.55, 0.28, 0.18), true)
		draw_rect(Rect2(cx - 130.0, mode_y - 16.0, 114.0, 22.0),
				Color(0.35, 0.9, 0.48, 0.35), false, 1.0)
	draw_string(font, Vector2(cx - 122.0, mode_y),
			"▶ STORY MODE" if not _arcade_mode else "  STORY MODE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, story_col)

	# Arcade option
	if _arcade_mode:
		draw_rect(Rect2(cx + 4.0, mode_y - 16.0, 126.0, 22.0),
				Color(0.08, 0.25, 0.55, 0.22), true)
		draw_rect(Rect2(cx + 4.0, mode_y - 16.0, 126.0, 22.0),
				Color(0.30, 0.65, 1.0, 0.45), false, 1.0)
	draw_string(font, Vector2(cx + 12.0, mode_y),
			"▶ ARCADE MODE" if _arcade_mode else "  ARCADE MODE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, arcade_col)

	draw_string(font, Vector2(cx - 130.0, mode_y + 14.0),
			"TAB  /  SELECT BUTTON  to switch",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.28, 0.62, 0.36, 0.50))
	draw_string(font, Vector2(cx - 130.0, mode_y + 28.0),
			"I  /  Y  —  ENEMY INDEX",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.32, 0.70, 0.42, 0.54))

	# ── Mode-specific prompts ─────────────────────────────────────────────────
	if _arcade_mode:
		var seed_y := mode_y + 48.0
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
				"UP/DOWN  —  CHANGE DIFFICULTY",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.32, 0.72, 0.92, 0.58))
		if fmod(t, 1.3) < 0.82:
			draw_string(font, Vector2(cx - 96.0, seed_y + 82.0),
					"PRESS ENTER TO LAUNCH RUN",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.40, 0.82, 1.0, 0.92))
	else:
		if _level_select_unlocked:
			draw_string(font, Vector2(cx - 118.0, mode_y + 48.0),
					"LEVEL SELECT UNLOCKED",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.48, 1.0, 0.62, 0.92))
			var menu_y := mode_y + 72.0
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
			if fmod(t, 1.3) < 0.82:
				draw_string(font, Vector2(cx - 96.0, mode_y + 48.0),
						"PRESS ENTER TO START",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
						Color(0.38, 1.0, 0.52, 0.90))

	# Controls block
	var hy    := vp.y * 0.73
	var hc    := Color(0.18, 0.52, 0.27, 0.48)
	var hints := [
		"MOVE          WASD  /  LEFT STICK",
		"DARK MODE     SHIFT  /  L2          (reduces emission)",
		"FIRE          SPACE  /  R1",
		"BOOST         E  /  R2",
		"PROBE         Q  /  X               (decoy beacon)",
		"SUPPRESS      F  /  A               (silent kill from behind)",
	]
	for i in hints.size():
		draw_string(font, Vector2(cx - 130.0, hy + i * 15.0),
				hints[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, hc)

	# Version / build tag
	draw_string(font, Vector2(16.0, vp.y - 16.0),
			"SIGNAL DARK  //  PROTOTYPE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.15, 0.42, 0.22, 0.35))
