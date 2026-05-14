extends Node2D

const WORLD_CAMERA_ZOOM_DESKTOP := Vector2(1.6, 1.6)
const WORLD_CAMERA_ZOOM_MOBILE := Vector2(2.2, 2.2)

var _search_position: Vector2 = Vector2.ZERO
var _search_timer: float = 0.0
var _search_reason: String = ""
var _started_msec: int = 0


func _ready() -> void:
	if GameState != null:
		GameState.register_world(self)
	if AlertSystem != null:
		AlertSystem.reset()
	if ColorSystem != null:
		ColorSystem.reset()
	_started_msec = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if _search_timer <= 0.0:
		return
	_search_timer = maxf(0.0, _search_timer - delta)
	if _search_timer <= 0.0:
		_search_reason = ""
		_search_position = Vector2.ZERO


func register_spawned_enemy(enemy: Node) -> void:
	add_child(enemy)


func play_player_fire_sfx(_position: Vector2) -> void:
	pass


func play_enemy_explosion_sfx(_position: Vector2) -> void:
	pass


func notify_player_noise(_position: Vector2, _strength: float) -> void:
	pass


func is_line_blocked(_from_point: Vector2, _to_point: Vector2, _exclusions := []) -> bool:
	return false


func start_search(position: Vector2, duration: float, reason: String = "SEARCH") -> void:
	_search_position = position
	_search_timer = maxf(_search_timer, duration)
	_search_reason = reason


func is_search_active() -> bool:
	return _search_timer > 0.0


func get_search_target() -> Vector2:
	return _search_position


func get_search_target_for(_enemy: Node2D) -> Vector2:
	return _search_position


func get_search_reason() -> String:
	return _search_reason


func get_hud_objective_text() -> String:
	return _search_reason if is_search_active() else ""


func get_hud_interaction_text() -> String:
	return ""


func get_hud_combat_state_text() -> String:
	return ""


func get_hud_level_time_text() -> String:
	var elapsed_seconds := maxf(0.0, float(Time.get_ticks_msec() - _started_msec) / 1000.0)
	var total_seconds := int(floor(elapsed_seconds))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func configure_agent_camera() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship == null:
		return
	var camera := ship.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var grid := get_node_or_null("Grid")
	var rect := Rect2(-120.0, -120.0, 800.0, 660.0)
	if grid != null:
		var grid_rect: Variant = grid.get("world_rect")
		if grid_rect is Rect2:
			rect = grid_rect
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.zoom = WORLD_CAMERA_ZOOM_MOBILE if OS.has_feature("mobile") else WORLD_CAMERA_ZOOM_DESKTOP
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		camera.position_smoothing_speed = 9.0


func _draw() -> void:
	if is_search_active():
		draw_circle(_search_position, 42.0, Color(0.95, 0.58, 0.12, 0.10))
		draw_arc(_search_position, 58.0, 0.0, TAU, 48, Color(0.95, 0.58, 0.12, 0.55), 1.5)
