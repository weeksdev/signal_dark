extends Node2D

@onready var ship = $Ship
@onready var hud = $CanvasLayer/HUD
@onready var game_over_overlay = $CanvasLayer/GameOverOverlay
@onready var zone_complete_overlay = $CanvasLayer/ZoneCompleteOverlay
@onready var grid: Node2D = $Grid

var enemies: Array[Node] = []
var probe_target: Vector2 = Vector2.ZERO
var probe_expire_time: float = 0.0
var restarting: bool = false
var completing: bool = false
var combat_cooldown_remaining: float = 0.0
var _kill_count: int = 0

const COMBAT_LOSE_CONTACT_SECONDS := 4.0
const THREAT_DISTANCE := 420.0


func _ready() -> void:
	GameState.register_world(self)
	AlertSystem.reset()
	ColorSystem.reset()
	_apply_desktop_window_size()
	restarting = false
	completing = false
	ship.destroyed.connect(_on_ship_destroyed)
	_configure_camera()
	enemies = get_tree().get_nodes_in_group("zone_enemy")
	for enemy in enemies:
		enemy.detected.connect(_on_enemy_detected)
		enemy.killed.connect(_on_enemy_killed)
	var exit := get_node_or_null("ExitZone")
	if exit:
		exit.player_reached.connect(_on_exit_reached)


func _process(delta: float) -> void:
	if InputManager.is_restart_just_pressed() and not completing:
		GameState.restart_zone()
	if probe_expire_time > 0.0 and _now() >= probe_expire_time:
		probe_expire_time = 0.0
	if AlertSystem.combat_mode and not restarting:
		_update_combat_cooldown(delta)


func _on_enemy_detected(_enemy: Node) -> void:
	if AlertSystem.combat_mode:
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	trigger_alert()


func _on_enemy_killed(_enemy: Node, silent: bool) -> void:
	_kill_count += 1
	if not silent and not AlertSystem.combat_mode:
		trigger_alert()
	if _living_enemy_count() == 0:
		_exit_combat_to_stealth()


func _on_exit_reached() -> void:
	if completing or restarting:
		return
	completing = true
	zone_complete_overlay.trigger(_kill_count == 0)


func _on_ship_destroyed() -> void:
	if restarting or completing:
		return
	restarting = true
	game_over_overlay.trigger()


func trigger_alert() -> void:
	if AlertSystem.combat_mode:
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	AlertSystem.enter_combat()
	combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.activate_for_combat(ship)


func register_probe(position: Vector2, duration: float) -> void:
	probe_target = position
	probe_expire_time = _now() + duration


func has_active_probe() -> bool:
	return probe_expire_time > _now()


func get_probe_target() -> Vector2:
	return probe_target


func is_line_blocked(from_point: Vector2, to_point: Vector2, exclusions := []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point)
	query.collision_mask = 4
	query.exclude = exclusions
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _living_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			count += 1
	return count


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _apply_desktop_window_size() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _configure_camera() -> void:
	var camera: Camera2D = ship.get_node("Camera2D")
	var rect: Rect2 = grid.get("world_rect")
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		camera.zoom = Vector2(0.96, 0.96)
		camera.position_smoothing_speed = 9.0


func _update_combat_cooldown(delta: float) -> void:
	if _enemy_still_threatening():
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	combat_cooldown_remaining = maxf(0.0, combat_cooldown_remaining - delta)
	if combat_cooldown_remaining <= 0.0:
		_exit_combat_to_stealth()


func _enemy_still_threatening() -> bool:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var distance: float = enemy.global_position.distance_to(ship.global_position)
		if distance > THREAT_DISTANCE:
			continue
		if not is_line_blocked(enemy.global_position, ship.global_position, [enemy.get_rid()]):
			return true
	return false


func _exit_combat_to_stealth() -> void:
	AlertSystem.exit_combat()
	combat_cooldown_remaining = 0.0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("deactivate_to_stealth"):
			enemy.deactivate_to_stealth()
