extends RefCounted

const InputDriver := preload("res://tests/agent/InputDriver.gd")
const ScreenshotRecorder := preload("res://tests/agent/ScreenshotRecorder.gd")
const TelemetryRecorder := preload("res://tests/agent/TelemetryRecorder.gd")
const AssertionEngine := preload("res://tests/agent/AssertionEngine.gd")

const PLAYER_SCENE := "res://src/player/Ship.tscn"
const DARK_POCKET_SCENE := "res://src/terrain/DarkPocket.tscn"
const ENEMY_SCENES := {
	"Hunter": "res://src/enemies/Hunter.tscn",
	"Sweeper": "res://src/enemies/Sweeper.tscn",
	"Sentry": "res://src/enemies/Sentry.tscn",
	"Wisp": "res://src/enemies/Wisp.tscn",
	"Prism": "res://src/enemies/Prism.tscn",
	"Pulsar": "res://src/enemies/Pulsar.tscn",
	"WarpMine": "res://src/enemies/WarpMine.tscn",
}

var _tree: SceneTree
var _scenario: Dictionary
var _artifact_dir_abs: String
var _targets: Dictionary = {}
var _input_driver := InputDriver.new()
var _screenshots := ScreenshotRecorder.new()
var _telemetry := TelemetryRecorder.new()
var _assertions := AssertionEngine.new()
var _assertion_results: Array[Dictionary] = []
var _failures: Array[String] = []
var _log: RefCounted
var _started_msec: int = 0
var _screenshot_interval: float = 0.0
var _next_interval_capture: float = 0.0
var _capture_on_failure: bool = true


func setup(tree: SceneTree, scenario: Dictionary, artifact_dir_abs: String, log: RefCounted = null) -> bool:
	_tree = tree
	_scenario = scenario
	_artifact_dir_abs = artifact_dir_abs
	_log = log
	var screenshot_config: Dictionary = scenario.get("screenshots", {})
	_screenshot_interval = float(screenshot_config.get("interval_seconds", 0.0))
	_capture_on_failure = bool(screenshot_config.get("capture_on_failure", true))
	var max_screenshots := int(screenshot_config.get("max", 16))
	if not _screenshots.setup(tree, artifact_dir_abs, max_screenshots, log):
		_failures.append("Unable to initialize screenshot recorder")
		return false
	if not _telemetry.setup(tree, artifact_dir_abs):
		_failures.append("Unable to initialize telemetry recorder")
		return false
	_assertions.setup(tree, _targets, _screenshots)
	return true


func run() -> Dictionary:
	_started_msec = Time.get_ticks_msec()
	seed(int(_scenario.get("seed", 1)))
	Engine.time_scale = float(_scenario.get("time_scale", 1.0))
	Engine.max_fps = int(_scenario.get("max_fps", 60))
	_log_info("load scene %s" % str(_scenario.get("scene", "res://src/world/AgentTestArena.tscn")))
	await _load_scene(str(_scenario.get("scene", "res://src/world/AgentTestArena.tscn")))
	var input_manager := _tree.root.get_node_or_null("/root/InputManager")
	if input_manager == null:
		_fail("InputManager autoload missing")
		return _summary(0.0)
	_input_driver.setup(input_manager, _targets)
	var steps: Array = _scenario.get("steps", [])
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("t", 0.0)) < float(b.get("t", 0.0))
	)
	var next_step := 0
	var now := 0.0
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var duration := float(_scenario.get("duration", _last_step_time(steps) + 2.0))
	_next_interval_capture = _screenshot_interval
	_log_info("run scenario %s duration=%.2f steps=%d" % [str(_scenario.get("scenario", "unnamed")), duration, steps.size()])
	while now <= duration or next_step < steps.size() or _input_driver.has_active_work():
		while next_step < steps.size() and float(steps[next_step].get("t", 0.0)) <= now:
			await _apply_step(steps[next_step], now)
			next_step += 1
		_input_driver.update(now)
		if _screenshot_interval > 0.0 and now >= _next_interval_capture:
			await _capture("interval_%04d" % int(now * 100.0))
			_next_interval_capture += _screenshot_interval
		await _tree.physics_frame
		now += tick
	await _run_final_assertions()
	_write_captures_index()
	_input_driver.clear()
	_telemetry.close()
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	return _summary(now)


func _load_scene(scene_path: String) -> void:
	var error := _tree.change_scene_to_file(scene_path)
	if error != OK:
		_fail("Unable to load scene %s: %d" % [scene_path, error])
		return
	for _i in range(4):
		await _tree.process_frame


func _apply_step(step: Dictionary, now: float) -> void:
	var action := str(step.get("action", ""))
	_log_info("t=%.2f action=%s" % [now, action])
	match action:
		"spawn_player":
			await _spawn_player(step)
		"spawn_dark_pocket":
			await _spawn_dark_pocket(step)
		"spawn_enemy":
			await _spawn_enemy(step)
		"capture":
			await _capture(str(step.get("name", "capture")))
		"assert":
			await _evaluate_assertion(str(step.get("condition", "")), str(step.get("message", "")))
		"wait":
			pass
		_:
			_input_driver.apply_step(step, now)


func _spawn_player(step: Dictionary) -> void:
	var player := _instantiate_scene(PLAYER_SCENE)
	if player == null:
		_fail("Unable to spawn player")
		return
	player.name = str(step.get("id", "player")).capitalize()
	player.set_meta("agent_id", str(step.get("id", "player")))
	player.global_position = _vec2(step.get("at", [0, 0]))
	_tree.current_scene.add_child(player)
	_targets[str(step.get("id", "player"))] = player
	_targets["player"] = player
	await _tree.process_frame
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
	if _tree.current_scene != null and _tree.current_scene.has_method("configure_agent_camera"):
		_tree.current_scene.call("configure_agent_camera")
	_telemetry.record_event("spawn_player:%s" % str(step.get("id", "player")))
	_log_info("spawned player id=%s at=%s" % [str(step.get("id", "player")), str(player.global_position)])


func _spawn_dark_pocket(step: Dictionary) -> void:
	var pocket := _instantiate_scene(DARK_POCKET_SCENE)
	if pocket == null:
		_fail("Unable to spawn dark pocket")
		return
	var id := str(step.get("id", "dark_pocket"))
	pocket.name = id
	pocket.set_meta("agent_id", id)
	pocket.global_position = _vec2(step.get("at", [0, 0]))
	_tree.current_scene.add_child(pocket)
	_targets[id] = pocket
	await _tree.process_frame
	_telemetry.record_event("spawn_dark_pocket:%s" % id)
	_log_info("spawned dark pocket id=%s at=%s" % [id, str(pocket.global_position)])


func _spawn_enemy(step: Dictionary) -> void:
	var type_name := str(step.get("type", "Hunter"))
	var scene_path: String = ENEMY_SCENES.get(type_name, "")
	if scene_path == "":
		_fail("Unknown enemy type %s" % type_name)
		return
	var enemy := _instantiate_scene(scene_path)
	if enemy == null:
		_fail("Unable to spawn enemy %s" % type_name)
		return
	var id := str(step.get("id", type_name.to_snake_case()))
	if step.has("patrol_points"):
		var patrol_points: Array = []
		for point in step.get("patrol_points", []):
			patrol_points.append(_vec2(point))
		enemy.set("patrol_points", patrol_points)
	if step.has("patrol_start_index"):
		enemy.set("patrol_start_index", int(step.get("patrol_start_index", 0)))
	if step.has("patrol_step"):
		enemy.set("patrol_step", int(step.get("patrol_step", 1)))
	enemy.name = id
	enemy.set_meta("agent_id", id)
	enemy.set_meta("agent_type", type_name)
	enemy.global_position = _vec2(step.get("at", [0, 0]))
	_tree.current_scene.add_child(enemy)
	_targets[id] = enemy
	var player := _targets.get("player") as Node2D
	if bool(step.get("combat", false)) and player != null and enemy.has_method("activate_for_combat"):
		enemy.activate_for_combat(player)
	await _tree.process_frame
	_telemetry.record_event("spawn_enemy:%s:%s" % [type_name, id])
	_log_info("spawned enemy id=%s type=%s at=%s" % [id, type_name, str(enemy.global_position)])


func _capture(label: String) -> void:
	_log_info("capture requested label=%s" % label)
	var sample := _telemetry.sample(label)
	var result := await _screenshots.capture(label, sample)
	sample["screenshot"] = result.get("file", "")
	_telemetry.write_sample(sample)
	if not bool(result.get("ok", false)):
		_fail(str(result.get("error", "screenshot capture failed")))


func _evaluate_assertion(condition: String, message: String) -> void:
	var result := _assertions.evaluate(condition, message)
	_assertion_results.append(result)
	_telemetry.record_event("assert:%s:%s" % [condition, str(result["ok"])])
	_log_info("assert condition='%s' ok=%s actual=%s expected=%s" % [
		condition,
		str(result["ok"]),
		str(result.get("actual", "")),
		str(result.get("expected", "")),
	])
	if not bool(result["ok"]):
		_fail(message if message != "" else "Assertion failed: %s" % condition)
		if _capture_on_failure:
			await _capture("failure")


func _run_final_assertions() -> void:
	for assertion in _scenario.get("assertions", []):
		await _evaluate_assertion(str(assertion.get("condition", "")), str(assertion.get("message", "")))


func _summary(sim_duration: float) -> Dictionary:
	return {
		"scenario": str(_scenario.get("scenario", "unnamed")),
		"seed": int(_scenario.get("seed", 0)),
		"ok": _failures.is_empty(),
		"duration_seconds": snappedf(sim_duration, 0.001),
		"wall_duration_seconds": snappedf(float(Time.get_ticks_msec() - _started_msec) / 1000.0, 0.001),
		"screenshots": _screenshots.count(),
		"captures": _screenshots.capture_index(),
		"assertions": _assertion_results,
		"failures": _failures,
	}


func _write_captures_index() -> void:
	var file := FileAccess.open(_artifact_dir_abs.path_join("captures.json"), FileAccess.WRITE)
	if file == null:
		_fail("Unable to write captures.json")
		return
	file.store_string(JSON.stringify(_screenshots.capture_index(), "\t"))
	file.close()


func _instantiate_scene(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate()


func _last_step_time(steps: Array) -> float:
	var latest := 0.0
	for step in steps:
		latest = maxf(latest, float(step.get("t", 0.0)))
	return latest


func _vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _fail(message: String) -> void:
	_failures.append(message)
	_log_error(message)


func _log_info(message: String) -> void:
	if _log != null and _log.has_method("info"):
		_log.info(message)
	else:
		print("[AgentHarness] %s" % message)


func _log_error(message: String) -> void:
	if _log != null and _log.has_method("error"):
		_log.error(message)
	else:
		push_error("[AgentHarness] %s" % message)
