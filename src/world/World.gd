extends Node2D

@onready var ship = $Ship
@onready var hud = $CanvasLayer/HUD
@onready var death_overlay = $CanvasLayer/DeathOverlay

var enemies: Array[Node] = []
var probe_target: Vector2 = Vector2.ZERO
var probe_expire_time: float = 0.0
var restarting: bool = false


func _ready() -> void:
	GameState.register_world(self)
	AlertSystem.reset()
	ColorSystem.reset()
	_apply_desktop_window_size()
	restarting = false
	death_overlay.visible = false
	ship.destroyed.connect(_on_ship_destroyed)
	enemies = get_tree().get_nodes_in_group("zone_enemy")
	for enemy in enemies:
		enemy.detected.connect(_on_enemy_detected)
		enemy.killed.connect(_on_enemy_killed)


func _process(_delta: float) -> void:
	if InputManager.is_restart_just_pressed():
		GameState.restart_zone()
	if probe_expire_time > 0.0 and _now() >= probe_expire_time:
		probe_expire_time = 0.0


func _on_enemy_detected(_enemy: Node) -> void:
	trigger_alert()


func _on_enemy_killed(_enemy: Node, silent: bool) -> void:
	if not silent and not AlertSystem.combat_mode:
		trigger_alert()
	if _living_enemy_count() == 0:
		AlertSystem.exit_combat()


func _on_ship_destroyed() -> void:
	if restarting:
		return
	restarting = true
	death_overlay.visible = true
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(GameState.restart_zone)


func trigger_alert() -> void:
	AlertSystem.enter_combat()
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
	var target_size := Vector2i(936, 2026)
	DisplayServer.window_set_size(target_size)
