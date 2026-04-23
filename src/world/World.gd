extends Node2D

const HUNTER_SCENE := preload("res://src/enemies/Hunter.tscn")
const WISP_SCENE := preload("res://src/enemies/Wisp.tscn")
const PRISM_SCENE := preload("res://src/enemies/Prism.tscn")
const ObjectiveNode := preload("res://src/world/ObjectiveNode.gd")
const SearchRelayBurst := preload("res://src/fx/SearchRelayBurst.gd")
const RuntimeDebugLog := preload("res://src/debug/RuntimeDebugLog.gd")

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
var _search_position: Vector2 = Vector2.ZERO
var _search_timer: float = 0.0
var _search_reason: String = ""
var _search_points: Array[Vector2] = []
var _search_phase: int = 0
var _search_phase_timer: float = 0.0
var _last_known_player_position: Vector2 = Vector2.ZERO
var _jammer_position: Vector2 = Vector2.ZERO
var _jammer_radius: float = 0.0
var _jammer_timer: float = 0.0
var _objective_nodes: Array[ObjectiveNode] = []
var _objective_required: int = 0
var _objective_progress: int = 0
var _objective_type: String = ""
var _interaction_text: String = ""
var _alert_count: int = 0

const COMBAT_LOSE_CONTACT_SECONDS := 4.0
const THREAT_DISTANCE := 420.0
const CAUTION_DURATION := 1.8
const SEARCH_DURATION := 7.5
const SEARCH_PHASE_DURATION := 1.05
const JAMMER_ALERT_REDUCTION := 0.28
const SEARCH_SUPPORT_RADIUS := 460.0
const SEARCH_SUPPORT_RECEIVE_TIME := 0.9
const SEARCH_SUPPORT_DELAY := 0.55
const SEARCH_SUPPORT_DURATION := 3.0


func _ready() -> void:
	RuntimeDebugLog.init_session()
	GameState.register_world(self)
	AlertSystem.reset()
	ColorSystem.reset()
	GameState.enforce_desktop_window_size()
	restarting = false
	completing = false
	ship.destroyed.connect(_on_ship_destroyed)
	_configure_camera()
	enemies = get_tree().get_nodes_in_group("zone_enemy")
	for enemy in enemies:
		enemy.detected.connect(_on_enemy_detected)
		if enemy.has_signal("suspicious"):
			enemy.suspicious.connect(_on_enemy_suspicious)
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
	_update_search(delta)
	_update_jammer(delta)
	_update_objectives(delta)


func _update_caution(delta: float) -> void:
	if ship.in_dark_pocket:
		_cancel_caution()
		return
	# Cancel if the detecting enemy died or lost sight of the player
	if not is_instance_valid(_caution_enemy) or not _caution_enemy.is_alive:
		_cancel_caution()
		return
	if _caution_enemy.has_method("is_alerting_state"):
		if not _caution_enemy.is_alerting_state():
			_cancel_caution()
			return
	elif not _caution_enemy._alerting:
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
	RuntimeDebugLog.log("detect", "%s detected player at ship=(%.1f, %.1f)" % [enemy.name, ship.global_position.x, ship.global_position.y])
	_last_known_player_position = ship.global_position
	start_search(ship.global_position, SEARCH_DURATION * 0.55, "SEARCH: CONTACT")
	_log_system_state("enemy_detected:%s" % enemy.name)
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
	AlertSystem.set_alert_level(maxf(AlertSystem.alert_level, 0.42))
	_maybe_request_search_support(enemy, ship.global_position)


func _on_enemy_suspicious(enemy: Node) -> void:
	if ship == null or ship.in_dark_pocket:
		RuntimeDebugLog.log("suspicion", "%s suspicious ignored; ship hidden or missing" % enemy.name)
		return
	RuntimeDebugLog.log("suspicion", "%s triggered suspicion support flow at ship=(%.1f, %.1f)" % [enemy.name, ship.global_position.x, ship.global_position.y])
	_last_known_player_position = ship.global_position
	start_search(ship.global_position, SEARCH_DURATION * 0.4, "SEARCH: SUSPICION")
	AlertSystem.set_alert_level(maxf(AlertSystem.alert_level, 0.18))
	_log_system_state("enemy_suspicious:%s" % enemy.name)
	if not _maybe_request_search_support(enemy, ship.global_position):
		RuntimeDebugLog.log("support", "%s had no helper; spawning local burst only" % enemy.name)
		_spawn_search_relay_fx(enemy.global_position, enemy.global_position)


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
	if _objective_required > 0 and _objective_progress < _objective_required:
		_interaction_text = "EXIT LOCKED  //  %s" % get_hud_objective_text()
		start_search(ship.global_position, SEARCH_DURATION * 0.45, "SEARCH: EXIT LOCK")
		return
	completing = true
	zone_complete_overlay.trigger(_kill_count == 0)


func _on_ship_destroyed() -> void:
	if restarting or completing:
		return
	restarting = true
	game_over_overlay.trigger()


func trigger_alert() -> void:
	_alert_count += 1
	_last_known_player_position = ship.global_position
	start_search(ship.global_position, SEARCH_DURATION * 1.35, "SEARCH: ALERT")
	_log_system_state("trigger_alert:start")
	if AlertSystem.combat_mode:
		combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
		return
	AlertSystem.enter_combat()
	_spawn_reinforcements_for_alert()
	combat_cooldown_remaining = COMBAT_LOSE_CONTACT_SECONDS
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.activate_for_combat(ship)
	_log_system_state("trigger_alert:combat_entered")


func register_spawned_enemy(enemy: Node) -> void:
	add_child(enemy)
	enemies.append(enemy)
	if enemy.has_signal("detected"):
		enemy.detected.connect(_on_enemy_detected)
	if enemy.has_signal("suspicious"):
		enemy.suspicious.connect(_on_enemy_suspicious)
	if enemy.has_signal("killed"):
		enemy.killed.connect(_on_enemy_killed)
	if AlertSystem.combat_mode and enemy.has_method("activate_for_combat"):
		enemy.activate_for_combat(ship)


func _maybe_request_search_support(source_enemy: Node, target_position: Vector2) -> bool:
	if source_enemy == null or not is_instance_valid(source_enemy):
		RuntimeDebugLog.log("support", "source enemy invalid for support request")
		return false
	if AlertSystem.combat_mode or ship.in_dark_pocket:
		RuntimeDebugLog.log("support", "%s support request suppressed by combat/hidden state" % source_enemy.name)
		return false
	var candidates: Array[Node] = []
	for enemy in enemies:
		if enemy == source_enemy or not is_instance_valid(enemy):
			continue
		if not enemy.is_alive:
			continue
		if enemy.global_position.distance_to(source_enemy.global_position) > SEARCH_SUPPORT_RADIUS:
			continue
		if enemy.has_method("can_receive_search_support") and not enemy.can_receive_search_support():
			continue
		candidates.append(enemy)
	if candidates.is_empty():
		RuntimeDebugLog.log("support", "%s found zero helpers within %.1f" % [source_enemy.name, SEARCH_SUPPORT_RADIUS])
		return false
	var helper: Node = candidates[randi() % candidates.size()]
	RuntimeDebugLog.log("support", "%s selected helper %s from %d candidates" % [source_enemy.name, helper.name, candidates.size()])
	if helper.has_method("receive_search_support") and helper.receive_search_support(target_position, SEARCH_SUPPORT_RECEIVE_TIME, SEARCH_SUPPORT_DELAY, SEARCH_SUPPORT_DURATION):
		_spawn_search_relay_fx(source_enemy.global_position, helper.global_position)
		return true
	RuntimeDebugLog.log("support", "%s helper %s failed receive_search_support" % [source_enemy.name, helper.name])
	return false

func _spawn_search_relay_fx(from_point: Vector2, to_point: Vector2) -> void:
	var burst: Node2D = SearchRelayBurst.new()
	burst.from_point = from_point
	burst.to_point = to_point
	RuntimeDebugLog.log("fx", "spawn relay burst from=(%.1f, %.1f) to=(%.1f, %.1f)" % [from_point.x, from_point.y, to_point.x, to_point.y])
	add_child(burst)


func register_probe(position: Vector2, duration: float) -> void:
	probe_target = position
	probe_expire_time = _now() + duration
	start_search(position, duration, "SEARCH: PROBE")


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
		_relax_enemies_for_hiding()
	else:
		_active_dark_pockets.erase(pocket.get_instance_id())
	ship.in_dark_pocket = not _active_dark_pockets.is_empty()
	_refresh_dark_pocket_gates()


func update_gate_hacking(ship_node: Node2D, _delta: float) -> Dictionary:
	_interaction_text = ""
	var objective := _nearest_objective(ship_node)
	if objective != null and objective.can_be_triggered_by(ship_node):
		objective.complete()
		_interaction_text = "%s LINKED" % objective.objective_name
		start_search(objective.global_position, SEARCH_DURATION * 0.35, "SEARCH: OBJECTIVE")

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
			start_search(gate.global_position, SEARCH_DURATION * 0.4, "SEARCH: BAD HACK")
			AlertSystem.add_alert(0.12)

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


func get_hud_objective_text() -> String:
	if _objective_required <= 0:
		if is_search_active():
			return _search_reason
		return ""
	var prefix := "FIND %s NODE" % _objective_type
	var progress := "%d/%d" % [_objective_progress, _objective_required]
	if is_search_active():
		return "%s  %s  //  %s" % [prefix, progress, _search_reason]
	return "%s  %s" % [prefix, progress]


func get_hud_interaction_text() -> String:
	return _interaction_text


func get_hud_combat_state_text() -> String:
	if ship != null and ship.in_dark_pocket:
		if AlertSystem.combat_mode:
			return "HIDDEN  //  CLEARING"
		if _caution_active:
			return "HIDDEN  //  SAFE"
	if _caution_active:
		return "CAUTION  %.1fs" % maxf(_caution_timer, 0.0)
	if not AlertSystem.combat_mode:
		return ""
	if _enemy_still_threatening():
		return "TRACKED  //  BREAK LINE OF SIGHT"
	return "EVADE  %.1fs" % maxf(combat_cooldown_remaining, 0.0)


func is_search_active() -> bool:
	return _search_timer > 0.0


func get_search_target() -> Vector2:
	return _search_position


func get_search_target_for(enemy: Node2D) -> Vector2:
	if _search_timer <= 0.0 or _search_points.is_empty():
		return _search_position
	if _search_phase <= 0:
		return _search_points[0]
	var sweep_count := maxi(_search_points.size() - 1, 1)
	var slot: int = abs(enemy.get_instance_id()) % sweep_count
	var sweep_index: int = ((_search_phase - 1) + slot) % sweep_count
	return _search_points[sweep_index + 1]


func trigger_signal_jammer(position: Vector2, radius: float, duration: float) -> void:
	_jammer_position = position
	_jammer_radius = radius
	_jammer_timer = duration
	_cancel_caution()
	AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - JAMMER_ALERT_REDUCTION))
	start_search(position, duration * 0.65, "SEARCH: JAMMER")


func trigger_emp_blast(position: Vector2, radius: float, duration: float) -> void:
	_cancel_caution()
	AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - 0.18))
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("apply_emp_disable"):
			continue
		if enemy.global_position.distance_to(position) > radius:
			continue
		enemy.apply_emp_disable(duration)
	start_search(position, duration * 0.35, "SEARCH: EMP")


func is_point_jammed(point: Vector2) -> bool:
	if _jammer_timer <= 0.0:
		return false
	return point.distance_to(_jammer_position) <= _jammer_radius


func notify_player_noise(position: Vector2, strength: float) -> void:
	if ship.in_dark_pocket:
		return
	_last_known_player_position = position
	if not AlertSystem.combat_mode:
		AlertSystem.add_alert(0.04 * strength)
	start_search(position, SEARCH_DURATION * clampf(0.45 + strength * 0.35, 0.35, 1.2), "SEARCH: NOISE")


func start_search(position: Vector2, duration: float, reason: String = "SEARCH") -> void:
	_search_position = position
	_search_timer = maxf(_search_timer, duration)
	_search_reason = reason
	_search_points = _build_search_points(position)
	_search_phase = 0
	_search_phase_timer = SEARCH_PHASE_DURATION
	RuntimeDebugLog.log("search", "start_search reason=%s pos=(%.1f, %.1f) duration=%.2f" % [reason, position.x, position.y, duration])


func setup_arcade_objectives(graph, node_rects: Dictionary) -> void:
	if not ArcadeState.is_active:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ArcadeState.get_floor_seed() + 424242)
	var candidates: Array = []
	for node in graph.nodes:
		if node.type == graph.NodeType.START or node.type == graph.NodeType.EXIT:
			continue
		if not node_rects.has(node.id):
			continue
		if node.type == graph.NodeType.SETPIECE_ROOM or node.depth >= 2:
			candidates.append({"id": node.id, "rect": node_rects[node.id], "branch": node.type == graph.NodeType.BRANCH_ROOM})
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return int(a["branch"]) > int(b["branch"]))
	_objective_nodes.clear()
	_objective_progress = 0
	_objective_required = 0
	var floor_num: int = ArcadeState.floor_index + 1
	match floor_num % 3:
		1:
			_objective_type = "UPLINK"
			_objective_required = 1 if floor_num == 1 else 2
		2:
			_objective_type = "INTEL"
			_objective_required = 1
		_:
			_objective_type = "RELAY"
			_objective_required = 2
	var count: int = mini(_objective_required, candidates.size())
	for i in range(count):
		var data: Dictionary = candidates[i]
		var rect: Rect2 = data["rect"]
		var node := ObjectiveNode.new()
		node.global_position = _pick_objective_position(rect, rng)
		node.objective_name = _objective_type
		node.accent_color = ColorSystem.ui_color()
		node.add_to_group("arcade_objective")
		node.objective_completed.connect(_on_objective_completed)
		add_child(node)
		_objective_nodes.append(node)
	_set_exit_locked(_objective_required > 0)


func _pick_objective_position(rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var inner := rect.grow(-92.0)
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		inner = rect.grow(-42.0)
	var center := inner.get_center()
	var best_pos := center
	var best_score := _objective_clearance_score(center)
	for _attempt in range(18):
		var pos := center + Vector2(rng.randf_range(-84.0, 84.0), rng.randf_range(-56.0, 56.0))
		pos = pos.clamp(inner.position, inner.end)
		var score := _objective_clearance_score(pos)
		if score > best_score:
			best_score = score
			best_pos = pos
		if _is_objective_position_clear(pos):
			return pos
	return best_pos


func _is_objective_position_clear(pos: Vector2) -> bool:
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if pocket is Node2D and pos.distance_to(pocket.global_position) < 118.0:
			return false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D and pos.distance_to(enemy.global_position) < 118.0:
			return false
	return true


func _objective_clearance_score(pos: Vector2) -> float:
	var score := 0.0
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if pocket is Node2D:
			score += minf(pos.distance_to(pocket.global_position), 240.0) * 3.0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			score += minf(pos.distance_to(enemy.global_position), 220.0)
	return score


func _on_objective_completed(_node: ObjectiveNode) -> void:
	_objective_progress += 1
	AlertSystem.set_alert_level(maxf(0.0, AlertSystem.alert_level - 0.12))
	if ship != null:
		ship.probe_charges = mini(ship.probe_charges + 1, 5)
		ship.jammer_charges = mini(ship.jammer_charges + 1, 3)
	if _objective_progress >= _objective_required:
		_set_exit_locked(false)
		_interaction_text = "EXIT UNLOCKED"


func _set_exit_locked(active: bool) -> void:
	var exit := get_node_or_null("ExitZone")
	if exit != null and exit.has_method("set_locked"):
		exit.set_locked(active, "FIND %s" % _objective_type if active else "EXIT")


func _nearest_objective(ship_node: Node2D) -> ObjectiveNode:
	var best: ObjectiveNode = null
	var best_dist := INF
	for node in _objective_nodes:
		if node == null or not is_instance_valid(node) or node.completed:
			continue
		var dist: float = node.global_position.distance_to(ship_node.global_position)
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _update_search(delta: float) -> void:
	if _search_timer <= 0.0:
		return
	if ship.in_dark_pocket and not AlertSystem.combat_mode:
		_search_timer = maxf(0.0, _search_timer - delta * 1.8)
	else:
		_search_timer = maxf(0.0, _search_timer - delta)
	_search_phase_timer = maxf(0.0, _search_phase_timer - delta)
	if _search_timer > 0.0 and _search_phase_timer <= 0.0 and not _search_points.is_empty():
		_search_phase = mini(_search_phase + 1, maxi(_search_points.size() - 1, 0))
		_search_phase_timer = SEARCH_PHASE_DURATION
	if _search_timer <= 0.0:
		_search_reason = ""
		_search_points.clear()
		_search_phase = 0
		_search_phase_timer = 0.0


func _update_jammer(delta: float) -> void:
	if _jammer_timer <= 0.0:
		return
	_jammer_timer = maxf(0.0, _jammer_timer - delta)


func _update_objectives(_delta: float) -> void:
	if _interaction_text != "" and not InputManager.is_hack_pressed():
		if not _interaction_text.begins_with("EXIT") and not _interaction_text.ends_with("LINKED"):
			_interaction_text = ""


func _living_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			count += 1
	return count


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _configure_camera() -> void:
	var camera: Camera2D = ship.get_node("Camera2D")
	var rect: Rect2 = grid.get("world_rect")
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		camera.zoom = Vector2.ONE
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
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("deactivate_to_stealth"):
			enemy.deactivate_to_stealth()
		if enemy.has_method("clear_alert_state"):
			enemy.clear_alert_state()
	AlertSystem.exit_combat()
	combat_cooldown_remaining = 0.0
	start_search(_last_known_player_position if _last_known_player_position != Vector2.ZERO else ship.global_position, SEARCH_DURATION, "SEARCH: SWEEP")
	_log_system_state("combat_exit_to_stealth")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("_update_palette"):
			enemy.call("_update_palette")
		if enemy.has_method("queue_redraw"):
			enemy.queue_redraw()


func _relax_enemies_for_hiding() -> void:
	_cancel_caution()
	_search_timer = 0.0
	_search_reason = ""
	_search_position = Vector2.ZERO
	_last_known_player_position = Vector2.ZERO
	combat_cooldown_remaining = 0.0
	if AlertSystem.combat_mode:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("deactivate_to_stealth"):
				enemy.deactivate_to_stealth()
		AlertSystem.exit_combat()
	else:
		AlertSystem.set_alert_level(0.0)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("clear_alert_state"):
			enemy.clear_alert_state()
		elif enemy.has_method("deactivate_to_stealth"):
			enemy.deactivate_to_stealth()
		if enemy.has_method("_update_palette"):
			enemy.call("_update_palette")
		if enemy.has_method("queue_redraw"):
			enemy.queue_redraw()
	_log_system_state("relax_enemies_for_hiding")


func _log_system_state(reason: String) -> void:
	if ship == null:
		return
	var alive_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			alive_count += 1
	RuntimeDebugLog.log(
		"state",
		"%s | player=(%.1f, %.1f) vel=%.1f dark=%s hidden=%s alert=%.2f combat=%s caution=%s search=%s reason=%s search_timer=%.2f phase=%d cooldown=%.2f alive=%d" % [
			reason,
			ship.global_position.x,
			ship.global_position.y,
			ship.velocity.length(),
			ship.dark_mode,
			ship.in_dark_pocket,
			AlertSystem.alert_level,
			AlertSystem.combat_mode,
			_caution_active,
			is_search_active(),
			_search_reason,
			_search_timer,
			_search_phase,
			combat_cooldown_remaining,
			alive_count,
		]
	)


func _build_search_points(position: Vector2) -> Array[Vector2]:
	var rect: Rect2 = grid.get("world_rect")
	var radius_x := 118.0
	var radius_y := 92.0
	var points: Array[Vector2] = [
		position,
		position + Vector2(-radius_x, 0.0),
		position + Vector2(radius_x, 0.0),
		position + Vector2(0.0, -radius_y),
		position + Vector2(0.0, radius_y),
		position + Vector2(-radius_x * 0.72, -radius_y * 0.72),
		position + Vector2(radius_x * 0.72, -radius_y * 0.72),
		position + Vector2(-radius_x * 0.72, radius_y * 0.72),
		position + Vector2(radius_x * 0.72, radius_y * 0.72),
	]
	for i in range(points.size()):
		points[i] = points[i].clamp(rect.position + Vector2(36.0, 36.0), rect.end - Vector2(36.0, 36.0))
	return points


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
