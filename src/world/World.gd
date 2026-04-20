extends Node2D

const HUNTER_SCENE := preload("res://src/enemies/Hunter.tscn")
const WISP_SCENE := preload("res://src/enemies/Wisp.tscn")
const PRISM_SCENE := preload("res://src/enemies/Prism.tscn")

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
var _caution_active: bool = false
var _caution_timer: float = 0.0
var _caution_enemy: Node = null
var _reinforcements_spawned: bool = false
var _active_dark_pockets: Dictionary = {}
var _defeated_enemy_snapshots: Array[Dictionary] = []
var _hack_target: Node2D = null
var _hack_sequence: Array = []
var _hack_index: int = 0
var _hack_wrong_flash: bool = false

const COMBAT_LOSE_CONTACT_SECONDS := 4.0
const THREAT_DISTANCE := 420.0
const CAUTION_DURATION := 1.8


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
	if _caution_active and not AlertSystem.combat_mode:
		_update_caution(delta)


func _update_caution(delta: float) -> void:
	if ship.in_dark_pocket:
		_cancel_caution()
		return
	# Cancel if the detecting enemy died or lost sight of the player
	if not is_instance_valid(_caution_enemy) or not _caution_enemy.is_alive:
		_cancel_caution()
		return
	if not _caution_enemy._alerting:
		_cancel_caution()
		return
	_caution_timer -= delta
	if _caution_timer <= 0.0:
		_cancel_caution()
		trigger_alert()


func _cancel_caution() -> void:
	_caution_active = false
	_caution_timer = 0.0
	_caution_enemy = null


func _on_enemy_detected(enemy: Node) -> void:
	if ship.in_dark_pocket:
		_cancel_caution()
		return
	if AlertSystem.combat_mode:
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	if _caution_active:
		# Spotted again during caution window → straight to combat
		_cancel_caution()
		trigger_alert()
		return
	# First detection → caution window (player can escape before full alert)
	_caution_active = true
	_caution_timer = CAUTION_DURATION
	_caution_enemy = enemy


func _on_enemy_killed(enemy: Node, silent: bool) -> void:
	var snapshot := _snapshot_enemy(enemy)
	if not snapshot.is_empty():
		_defeated_enemy_snapshots.append(snapshot)
	_kill_count += 1
	if _caution_enemy == enemy:
		_cancel_caution()
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
	_spawn_reinforcements_for_alert()
	combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.activate_for_combat(ship)


func register_spawned_enemy(enemy: Node) -> void:
	add_child(enemy)
	enemies.append(enemy)
	if enemy.has_signal("detected"):
		enemy.detected.connect(_on_enemy_detected)
	if enemy.has_signal("killed"):
		enemy.killed.connect(_on_enemy_killed)
	if AlertSystem.combat_mode and enemy.has_method("activate_for_combat"):
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


func set_player_dark_pocket_state(pocket: Area2D, active: bool) -> void:
	if active:
		_active_dark_pockets[pocket.get_instance_id()] = pocket
		_cancel_caution()
		if AlertSystem.combat_mode:
			_exit_combat_to_stealth()
	else:
		_active_dark_pockets.erase(pocket.get_instance_id())
	ship.in_dark_pocket = not _active_dark_pockets.is_empty()
	_refresh_dark_pocket_gates()


func update_gate_hacking(ship_node: Node2D, _delta: float) -> Dictionary:
	var gate := _find_nearest_hack_gate(ship_node)
	if gate == null:
		_reset_hack_state()
		return {
			"visible": false,
			"sequence": [],
			"current_index": 0,
			"wrong_flash": false,
		}

	if gate != _hack_target:
		_hack_target = gate
		_hack_sequence = _make_hack_sequence()
		_hack_index = 0

	_hack_wrong_flash = false
	var pressed := InputManager.get_hack_button_just_pressed()
	if pressed != "":
		if pressed == _hack_sequence[_hack_index]:
			_hack_index += 1
		else:
			_hack_index = 0
			_hack_wrong_flash = true

		if _hack_index >= _hack_sequence.size():
			gate.set_hacked_open(true)
			_respawn_defeated_enemies()
			var success_pos := gate.global_position + Vector2(0.0, -54.0)
			_reset_hack_state()
			return {
				"visible": true,
				"world_pos": success_pos,
				"sequence": ["O", "P", "E", "N"],
				"current_index": 4,
				"wrong_flash": false,
			}

	return {
		"visible": true,
		"world_pos": gate.global_position + Vector2(0.0, -54.0),
		"sequence": _hack_sequence,
		"current_index": _hack_index,
		"wrong_flash": _hack_wrong_flash,
	}


func _reset_hack_state() -> void:
	_hack_target = null
	_hack_sequence.clear()
	_hack_index = 0
	_hack_wrong_flash = false


func _make_hack_sequence() -> Array:
	var buttons := ["A", "B", "X", "Y"]
	var length := 3 if ArcadeState.floor_index <= 1 else 4
	var sequence: Array = []
	for _i in range(length):
		sequence.append(buttons[randi() % buttons.size()])
	return sequence


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
	if ship.in_dark_pocket:
		return false
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


func _refresh_dark_pocket_gates() -> void:
	for child in get_children():
		if child == null or not child.has_method("set_dark_pocket_open"):
			continue
		child.set_dark_pocket_open(false)

	for pocket in _active_dark_pockets.values():
		_open_gates_for_pocket(pocket)


func _open_gates_for_pocket(pocket: Area2D) -> void:
	var unlock_radius: float = pocket.get("gate_unlock_radius")
	for child in get_children():
		if child == null or not child.has_method("set_dark_pocket_open"):
			continue
		if pocket.global_position.distance_to(child.global_position) > unlock_radius:
			continue
		child.set_dark_pocket_open(true)


func _find_nearest_hack_gate(ship_node: Node2D) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for child in get_children():
		if child == null or not child.has_method("can_be_hacked_by"):
			continue
		if not child.can_be_hacked_by(ship_node):
			continue
		var dist: float = ship_node.global_position.distance_to(child.global_position)
		if dist >= nearest_dist:
			continue
		nearest = child
		nearest_dist = dist
	return nearest


func _snapshot_enemy(enemy: Node) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {}
	if enemy.scene_file_path.is_empty():
		return {}
	var snapshot := {
		"scene_path": enemy.scene_file_path,
		"global_position": enemy.global_position,
		"rotation": enemy.rotation,
	}
	if enemy.has_node("PatrolA"):
		snapshot["patrol_a"] = enemy.get_node("PatrolA").position
	if enemy.has_node("PatrolB"):
		snapshot["patrol_b"] = enemy.get_node("PatrolB").position
	return snapshot


func _respawn_defeated_enemies() -> void:
	if _defeated_enemy_snapshots.is_empty():
		return
	var snapshots := _defeated_enemy_snapshots.duplicate(true)
	_defeated_enemy_snapshots.clear()
	for snapshot in snapshots:
		var scene: PackedScene = load(snapshot["scene_path"])
		if scene == null:
			continue
		var enemy := scene.instantiate()
		enemy.global_position = snapshot["global_position"]
		enemy.rotation = snapshot["rotation"]
		if snapshot.has("patrol_a") and enemy.has_node("PatrolA"):
			enemy.get_node("PatrolA").position = snapshot["patrol_a"]
		if snapshot.has("patrol_b") and enemy.has_node("PatrolB"):
			enemy.get_node("PatrolB").position = snapshot["patrol_b"]
		register_spawned_enemy(enemy)


func _spawn_reinforcements_for_alert() -> void:
	if _reinforcements_spawned:
		return
	var spawn_points := _get_reinforcement_points()
	if spawn_points.is_empty():
		return

	var desired_count := 4
	var min_distance := 280.0
	var max_distance := 980.0
	var candidates: Array[Dictionary] = []

	for point in spawn_points:
		var marker: Marker2D = point["marker"]
		var distance := marker.global_position.distance_to(ship.global_position)
		if distance < min_distance or distance > max_distance:
			continue
		candidates.append({
			"marker": marker,
			"kind": point["kind"],
			"distance": distance,
		})

	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)

	var spawned := 0
	for candidate in candidates:
		if spawned >= desired_count:
			break
		var enemy := _instantiate_reinforcement(candidate["kind"])
		if enemy == null:
			continue
		enemy.global_position = candidate["marker"].global_position
		register_spawned_enemy(enemy)
		spawned += 1

	if spawned > 0:
		_reinforcements_spawned = true


func _get_reinforcement_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for node in find_children("*", "Marker2D", true, false):
		if not node.name.begins_with("Reinforce"):
			continue
		var marker := node as Marker2D
		if marker == null:
			continue
		points.append({
			"marker": marker,
			"kind": _reinforcement_kind_from_name(marker.name),
		})
	return points


func _reinforcement_kind_from_name(node_name: String) -> String:
	if node_name.contains("Prism"):
		return "prism"
	if node_name.contains("Wisp"):
		return "wisp"
	return "hunter"


func _instantiate_reinforcement(kind: String) -> Node:
	match kind:
		"prism":
			return PRISM_SCENE.instantiate()
		"wisp":
			return WISP_SCENE.instantiate()
		_:
			return HUNTER_SCENE.instantiate()
