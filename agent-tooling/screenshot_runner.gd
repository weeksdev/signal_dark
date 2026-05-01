extends SceneTree

const START_SCENE := "res://src/ui/StartScreen.tscn"
const STORY_SCENES := [
	"res://src/world/World.tscn",
	"res://src/world/World02.tscn",
	"res://src/world/World03.tscn",
	"res://src/world/World04.tscn",
]
const DIFFICULTY_NAME_TO_ID := {
	"easy": 0,
	"medium": 1,
	"hardcore": 2,
}
const DIFFICULTY_ID_TO_NAME := {
	0: "easy",
	1: "medium",
	2: "hardcore",
}
const DEFAULT_ARCADE_SEEDS := [11111, 22222, 33333]
const DEFAULT_SETTLE_FRAMES := 24
const DEFAULT_OUTPUT_ROOT := "res://agent-tooling/output"
const CAPTURE_BACKEND_VIEWPORT := "viewport"
const CAPTURE_BACKEND_SCREEN := "screen"
const STORY_CAPTURE_ROUTES := {
	"res://src/world/World.tscn": [
		{"suffix": "spawn", "position": Vector2(450, 1150)},
		{"suffix": "doorway", "position": Vector2(660, 1150)},
		{"suffix": "corridor", "position": Vector2(820, 1160)},
		{"suffix": "hub_entry", "position": Vector2(980, 1150)},
		{"suffix": "next_room", "position": Vector2(1200, 1150)},
	],
}

var _capture_menu: bool = true
var _capture_story: bool = true
var _capture_arcade: bool = true
var _story_scene_paths: Array[String] = []
var _arcade_seeds: Array[int] = []
var _arcade_difficulties: Array[int] = [0, 1, 2]
var _settle_frames: int = DEFAULT_SETTLE_FRAMES
var _capture_backend: String = CAPTURE_BACKEND_VIEWPORT
var _output_dir_rel: String = ""
var _output_dir_abs: String = ""
var _results: Array[Dictionary] = []
var _failures: Array[String] = []
var _original_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_args(OS.get_cmdline_user_args())
	_prepare_capture_environment()
	_prepare_output_dir()
	await _await_frames(4)
	print("[AgentTooling] output_dir=%s" % _output_dir_abs)

	if _capture_menu:
		await _capture_menu_scene()
	if _capture_story:
		for scene_path in _story_scene_paths:
			await _capture_story_scene(scene_path)
	if _capture_arcade:
		for difficulty in _arcade_difficulties:
			for seed in _arcade_seeds:
				await _capture_arcade_scene(seed, difficulty)

	_write_manifest()
	_write_review_page()
	await _cleanup_current_scene()
	_restore_capture_environment()
	if _failures.is_empty():
		print("[AgentTooling] captured %d screenshot(s)" % _results.size())
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _prepare_capture_environment() -> void:
	_original_mouse_mode = Input.mouse_mode
	if _capture_backend == CAPTURE_BACKEND_SCREEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _restore_capture_environment() -> void:
	Input.mouse_mode = _original_mouse_mode


func _parse_args(args: PackedStringArray) -> void:
	_story_scene_paths.assign(STORY_SCENES)
	_arcade_seeds.assign(DEFAULT_ARCADE_SEEDS)
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--mode":
				i += 1
				if i < args.size():
					_apply_mode(args[i].to_lower())
			"--output-dir":
				i += 1
				if i < args.size():
					_output_dir_rel = _normalize_output_dir(args[i])
			"--story-scenes":
				i += 1
				if i < args.size():
					_story_scene_paths = _split_csv(args[i])
			"--arcade-seeds":
				i += 1
				if i < args.size():
					_arcade_seeds = _parse_int_list(args[i], DEFAULT_ARCADE_SEEDS)
			"--arcade-difficulties":
				i += 1
				if i < args.size():
					_arcade_difficulties = _parse_difficulty_list(args[i])
			"--settle-frames":
				i += 1
				if i < args.size():
					_settle_frames = maxi(2, int(args[i]))
			"--capture-backend":
				i += 1
				if i < args.size():
					_capture_backend = args[i].to_lower()
		i += 1

	if _output_dir_rel == "":
		_output_dir_rel = "%s/session_%s" % [DEFAULT_OUTPUT_ROOT, Time.get_datetime_string_from_system(false, true)]
	if _capture_story and _story_scene_paths.is_empty():
		_story_scene_paths.assign(STORY_SCENES)
	if _capture_arcade and _arcade_seeds.is_empty():
		_arcade_seeds.assign(DEFAULT_ARCADE_SEEDS)
	if _capture_arcade and _arcade_difficulties.is_empty():
		_arcade_difficulties = [0, 1, 2]


func _apply_mode(mode: String) -> void:
	_capture_menu = false
	_capture_story = false
	_capture_arcade = false
	match mode:
		"all":
			_capture_menu = true
			_capture_story = true
			_capture_arcade = true
		"menu":
			_capture_menu = true
		"story":
			_capture_story = true
		"arcade":
			_capture_arcade = true
		"smoke":
			_capture_menu = true
			_capture_story = true
			_capture_arcade = true
			_story_scene_paths = [STORY_SCENES[0]]
			_arcade_seeds = [DEFAULT_ARCADE_SEEDS[0]]
			_arcade_difficulties = [1]
		_:
			_capture_menu = true
			_capture_story = true
			_capture_arcade = true


func _prepare_output_dir() -> void:
	_output_dir_abs = ProjectSettings.globalize_path(_output_dir_rel)
	var error := DirAccess.make_dir_recursive_absolute(_output_dir_abs)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Unable to create output directory %s" % _output_dir_abs)
		quit(1)


func _capture_menu_scene() -> void:
	var label := "menu_start"
	var metadata := {
		"kind": "menu",
		"scene_path": START_SCENE,
	}
	await _load_scene(START_SCENE)
	await _capture_current_scene(label, metadata)


func _capture_story_scene(scene_path: String) -> void:
	var label := "story_%s" % scene_path.get_file().get_basename().to_snake_case()
	var metadata := {
		"kind": "story",
		"scene_path": scene_path,
	}
	await _load_story_scene(scene_path)
	var route: Array = STORY_CAPTURE_ROUTES.get(scene_path, [])
	if route.is_empty():
		await _capture_current_scene(label, metadata)
		return
	for step in route:
		var ship: Node2D = _ship_node()
		if ship == null:
			_failures.append("Missing Ship node for %s" % scene_path)
			return
		var suffix := str(step.get("suffix", "step"))
		var position: Vector2 = step.get("position", ship.global_position)
		_place_ship(ship, position)
		await _capture_current_scene("%s_%s" % [label, suffix], metadata.merged({
			"route_position": {"x": position.x, "y": position.y},
			"route_step": suffix,
		}, true))


func _capture_arcade_scene(seed: int, difficulty: int) -> void:
	var difficulty_name: String = str(DIFFICULTY_ID_TO_NAME.get(difficulty, "medium"))
	var arcade_state := _require_singleton("ArcadeState")
	if arcade_state == null:
		return
	var label := "arcade_%s_seed_%d" % [difficulty_name, seed]
	var metadata := {
		"kind": "arcade",
		"scene_path": String(arcade_state.call("get_current_scene_path")),
		"seed": seed,
		"difficulty": difficulty_name,
		"floor_index": int(arcade_state.get("floor_index")),
	}
	await _load_arcade_scene(seed, difficulty)
	await _capture_current_scene(label, metadata)


func _load_story_scene(scene_path: String) -> void:
	var arcade_state := _require_singleton("ArcadeState")
	var alert_system := _require_singleton("AlertSystem")
	var color_system := _require_singleton("ColorSystem")
	var game_state := _require_singleton("GameState")
	if arcade_state == null or alert_system == null or color_system == null or game_state == null:
		return
	arcade_state.call("reset")
	alert_system.call("reset")
	color_system.call("reset")
	var zone_index := STORY_SCENES.find(scene_path)
	if zone_index >= 0:
		game_state.call("start_zone", zone_index)
	else:
		change_scene_to_file(scene_path)
	await _wait_for_current_scene(scene_path)


func _load_arcade_scene(seed: int, difficulty: int) -> void:
	var arcade_state := _require_singleton("ArcadeState")
	var alert_system := _require_singleton("AlertSystem")
	var color_system := _require_singleton("ColorSystem")
	var game_state := _require_singleton("GameState")
	if arcade_state == null or alert_system == null or color_system == null or game_state == null:
		return
	arcade_state.call("reset")
	alert_system.call("reset")
	color_system.call("reset")
	game_state.call("start_arcade_run", seed, difficulty)
	await _wait_for_current_scene(String(arcade_state.call("get_current_scene_path")))


func _load_scene(scene_path: String) -> void:
	var arcade_state := _require_singleton("ArcadeState")
	var alert_system := _require_singleton("AlertSystem")
	var color_system := _require_singleton("ColorSystem")
	if arcade_state == null or alert_system == null or color_system == null:
		return
	arcade_state.call("reset")
	alert_system.call("reset")
	color_system.call("reset")
	change_scene_to_file(scene_path)
	await _wait_for_current_scene(scene_path)


func _wait_for_current_scene(expected_path: String) -> void:
	var attempts := 0
	while attempts < 180:
		await _await_frames(1)
		var current := current_scene
		if current != null and current.scene_file_path == expected_path:
			await _await_frames(_settle_frames)
			return
		attempts += 1
	_failures.append("Timed out waiting for scene %s" % expected_path)


func _capture_current_scene(label: String, metadata: Dictionary) -> void:
	await _await_presented_frames(3)
	var image := _capture_image()
	if image == null:
		_failures.append("Capture failed for %s" % label)
		return

	var file_name := "%s.png" % label
	var abs_path := _output_dir_abs.path_join(file_name)
	var save_error := image.save_png(abs_path)
	if save_error != OK:
		_failures.append("Failed to save %s (%d)" % [abs_path, save_error])
		return

	var record := metadata.duplicate(true)
	record["label"] = label
	record["file_name"] = file_name
	record["abs_path"] = abs_path
	record["resolution"] = "%dx%d" % [image.get_width(), image.get_height()]
	record["scene_name"] = current_scene.name if current_scene != null else ""
	record["captured_at"] = Time.get_datetime_string_from_system()
	record["enemy_count"] = get_nodes_in_group("zone_enemy").size()
	record["objective_count"] = get_nodes_in_group("objective_node").size()
	_results.append(record)
	print("[AgentTooling] saved=%s scene=%s" % [abs_path, record.get("scene_path", "")])


func _write_manifest() -> void:
	var manifest_path := _output_dir_abs.path_join("manifest.json")
	var payload := {
		"generated_at": Time.get_datetime_string_from_system(),
		"output_dir": _output_dir_abs,
		"count": _results.size(),
		"results": _results,
	}
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_failures.append("Failed to write manifest %s" % manifest_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _write_review_page() -> void:
	var html_path := _output_dir_abs.path_join("index.html")
	var file := FileAccess.open(html_path, FileAccess.WRITE)
	if file == null:
		_failures.append("Failed to write review page %s" % html_path)
		return
	var sections: PackedStringArray = []
	sections.append("<!doctype html>")
	sections.append("<html><head><meta charset=\"utf-8\">")
	sections.append("<title>Signal Dark Capture Review</title>")
	sections.append("<style>")
	sections.append("body{font-family:Menlo,monospace;background:#0d1117;color:#e6edf3;margin:24px;}h1{font-size:22px;}p{color:#9fb0c1;} .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:18px;} .card{background:#161b22;border:1px solid #2d333b;border-radius:12px;padding:12px;} img{width:100%;height:auto;border-radius:8px;border:1px solid #30363d;background:#000;} .meta{font-size:12px;line-height:1.5;color:#9fb0c1;margin-top:10px;white-space:pre-wrap;}")
	sections.append("</style></head><body>")
	sections.append("<h1>Signal Dark Capture Review</h1>")
	sections.append("<p>Generated %s. %d image(s).</p>" % [Time.get_datetime_string_from_system(), _results.size()])
	sections.append("<div class=\"grid\">")
	for record in _results:
		var meta_lines := PackedStringArray()
		meta_lines.append("label: %s" % str(record.get("label", "")))
		meta_lines.append("kind: %s" % str(record.get("kind", "")))
		meta_lines.append("scene: %s" % str(record.get("scene_path", "")))
		if record.has("difficulty"):
			meta_lines.append("difficulty: %s" % str(record["difficulty"]))
		if record.has("seed"):
			meta_lines.append("seed: %s" % str(record["seed"]))
		meta_lines.append("resolution: %s" % str(record.get("resolution", "")))
		meta_lines.append("enemies: %s" % str(record.get("enemy_count", 0)))
		meta_lines.append("objectives: %s" % str(record.get("objective_count", 0)))
		sections.append("<article class=\"card\">")
		sections.append("<img src=\"%s\" alt=\"%s\">" % [str(record["file_name"]).uri_encode().replace("%2F", "/"), str(record["label"])])
		sections.append("<div class=\"meta\">%s</div>" % "\n".join(meta_lines))
		sections.append("</article>")
	sections.append("</div></body></html>")
	file.store_string("\n".join(sections))
	file.close()


func _await_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _await_presented_frames(count: int) -> void:
	for _i in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw


func _capture_image() -> Image:
	if _capture_backend == CAPTURE_BACKEND_SCREEN:
		return _capture_window_image()
	return root.get_texture().get_image()


func _capture_window_image() -> Image:
	if DisplayServer.get_name() == "headless":
		return root.get_texture().get_image()
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_image := DisplayServer.screen_get_image(screen_index)
	if screen_image == null:
		return root.get_texture().get_image()
	var window_pos := DisplayServer.window_get_position()
	var window_size := DisplayServer.window_get_size()
	var safe_x := clampi(window_pos.x, 0, maxi(0, screen_image.get_width() - 1))
	var safe_y := clampi(window_pos.y, 0, maxi(0, screen_image.get_height() - 1))
	var crop_width := mini(window_size.x, screen_image.get_width() - safe_x)
	var crop_height := mini(window_size.y, screen_image.get_height() - safe_y)
	if crop_width <= 0 or crop_height <= 0:
		return root.get_texture().get_image()
	return screen_image.get_region(Rect2i(safe_x, safe_y, crop_width, crop_height))


func _ship_node() -> Node2D:
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Ship") as Node2D


func _place_ship(ship: Node2D, position: Vector2) -> void:
	ship.global_position = position
	if ship is CharacterBody2D:
		(ship as CharacterBody2D).velocity = Vector2.ZERO
	await _await_presented_frames(maxi(4, _settle_frames / 3))


func _cleanup_current_scene() -> void:
	if current_scene == null:
		return
	current_scene.queue_free()
	await _await_frames(2)


func _split_csv(raw: String) -> Array[String]:
	var values: Array[String] = []
	for part in raw.split(","):
		var trimmed := part.strip_edges()
		if trimmed != "":
			values.append(trimmed)
	return values


func _parse_int_list(raw: String, fallback: Array[int]) -> Array[int]:
	var values: Array[int] = []
	for part in raw.split(","):
		var trimmed := part.strip_edges()
		if trimmed.is_valid_int():
			values.append(int(trimmed))
	return values if not values.is_empty() else fallback.duplicate()


func _parse_difficulty_list(raw: String) -> Array[int]:
	var values: Array[int] = []
	for part in raw.split(","):
		var key := part.strip_edges().to_lower()
		if DIFFICULTY_NAME_TO_ID.has(key):
			values.append(int(DIFFICULTY_NAME_TO_ID[key]))
	return values


func _normalize_output_dir(raw: String) -> String:
	if raw.begins_with("res://"):
		return raw
	if raw.begins_with("/"):
		return raw
	return "%s/%s" % [DEFAULT_OUTPUT_ROOT, raw]


func _require_singleton(name: String) -> Node:
	var node := root.get_node_or_null(NodePath("/root/%s" % name))
	if node == null:
		_failures.append("Missing singleton /root/%s" % name)
	return node
