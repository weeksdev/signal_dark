extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const ALERT_HOLD_SECONDS := 2.4
const ROUTE_ARRIVE_DIST := 16.0
const STEER_ACCEL := 360.0

@export var signature_color := Color("bf5af2")
@export var patrol_radius: float = 90.0
@export var patrol_speed: float = 72.0
@export var combat_speed: float = 110.0
@export var suppress_range: float = 28.0
@export var alert_radius: float = 36.0
@export var search_interest_radius: float = 210.0
@export var suspicion_follow_radius: float = 220.0

var anchor: Vector2 = Vector2.ZERO
var phase: float = 0.0
var use_route_patrol: bool = false
var route_a: Vector2 = Vector2.ZERO
var route_b: Vector2 = Vector2.ZERO
var patrol_points: Array = []
var patrol_step: int = 1
var choke_indices: Array = []
var _route_pause: float = 0.0
var _patrol_index: int = 0
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	anchor = global_position
	_last_position = global_position
	phase = randf() * TAU
	if use_route_patrol and patrol_points.is_empty() and route_a != route_b:
		patrol_points = [route_a, route_b]


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if tick_support_state(delta):
		queue_redraw()
		return
	tick_alert_state(delta)
	phase += delta
	if combat_active and ship != null:
		var to_ship: Vector2 = ship.global_position - global_position
		var tangent: Vector2 = Vector2(-to_ship.y, to_ship.x).normalized()
		var desired: Vector2 = to_ship.normalized() * combat_speed * 0.7 + tangent * combat_speed * 0.45
		if desired != Vector2.ZERO:
			facing_vector = desired.normalized()
			velocity = desired
			move_and_slide()
			if get_slide_collision_count() > 0:
				phase += 0.9
	else:
		var roam_target := _stealth_target()
		var offset: Vector2 = roam_target - global_position
		if use_route_patrol and _route_pause > 0.0:
			_route_pause = maxf(_route_pause - delta, 0.0)
			velocity = velocity.move_toward(Vector2.ZERO, STEER_ACCEL * delta)
			move_and_slide()
		elif offset.length() > ROUTE_ARRIVE_DIST:
			var desired_dir := offset.normalized()
			facing_vector = facing_vector.lerp(desired_dir, clampf(delta * 8.0, 0.0, 1.0)).normalized()
			velocity = velocity.move_toward(desired_dir * patrol_speed, STEER_ACCEL * delta)
			move_and_slide()
			_push_out_of_dark_pockets(delta)
			_update_stuck_recovery(delta, offset)
			if get_slide_collision_count() > 0:
				if use_route_patrol:
					_recover_from_block()
				phase += 1.25
				velocity = Vector2.ZERO
		elif use_route_patrol:
			velocity = velocity.move_toward(Vector2.ZERO, STEER_ACCEL * delta)
			_advance_route()
		_check_alert_radius()
	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO
	_snap_to_patrol_route()
	clear_alert_state()


func is_valid_auto_fire_target(from_point: Vector2) -> bool:
	if not super.is_valid_auto_fire_target(from_point):
		return false
	return _stuck_timer < 0.12


func can_be_suppressed_by(ship_node: Node2D) -> bool:
	if not is_alive or combat_active:
		return false
	if not ship_node.dark_mode:
		return false
	return ship_node.global_position.distance_to(global_position) <= suppress_range


func take_damage(silent: bool, _hit_origin: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	is_alive = false
	_spawn_burst(silent)
	killed.emit(self, silent)
	queue_free()


func _check_alert_radius() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	if should_suppress_detection_of(player):
		return
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		return
	if player.in_dark_pocket:
		return
	if global_position.distance_to(player.global_position) > alert_radius:
		return
	_begin_alert()


func _begin_alert() -> void:
	begin_alert_state(ALERT_HOLD_SECONDS)


func _stealth_target() -> Vector2:
	var roam_target := anchor + Vector2(cos(phase * 0.8), sin(phase * 1.1)) * patrol_radius
	if use_route_patrol:
		if patrol_points.size() >= 2:
			roam_target = patrol_points[_patrol_index]
		else:
			roam_target = route_b if patrol_step >= 0 else route_a
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and _can_follow_suspicious_target(player):
		return safe_enemy_target(player.global_position)
	if world_is_search_active():
		var search_target: Vector2 = world_search_target_for_self()
		if global_position.distance_to(search_target) <= search_interest_radius:
			return safe_enemy_target(search_target)
	return roam_target


func _can_follow_suspicious_target(player: Node2D) -> bool:
	if should_suppress_detection_of(player):
		return false
	if player.in_dark_pocket:
		return false
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		return false
	if _alerting:
		return true
	if _suspicion <= 0.06:
		return false
	return global_position.distance_to(player.global_position) <= suspicion_follow_radius


func _advance_route() -> void:
	if patrol_points.size() >= 2:
		_patrol_index = posmod(_patrol_index + patrol_step, patrol_points.size())
	else:
		patrol_step *= -1
	_stuck_timer = 0.0
	_last_position = global_position
	_route_pause = 0.3 if _patrol_index in choke_indices else 0.16


func _update_stuck_recovery(delta: float, offset: Vector2) -> void:
	if not use_route_patrol:
		return
	var moved := global_position.distance_to(_last_position)
	if offset.length() > 18.0 and moved < 1.0:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_position = global_position
	if _stuck_timer > 0.35:
		_recover_from_block()


func _recover_from_block() -> void:
	_advance_route()
	velocity = Vector2.ZERO


func _snap_to_patrol_route() -> void:
	var ordered_points := _ordered_recovery_points()
	var reserved: Variant = world_call("reserve_patrol_recovery_point", [self, ordered_points])
	if reserved is Vector2:
		_apply_reserved_patrol_point(reserved)
		return
	world_call("schedule_enemy_patrol_reentry", [self, ordered_points])


func _ordered_recovery_points() -> Array:
	var points: Array = patrol_points.duplicate() if use_route_patrol and patrol_points.size() >= 2 else [anchor]
	if points.size() <= 1:
		return points
	var indexed: Array = []
	for i in range(points.size()):
		indexed.append({
			"index": i,
			"point": points[i],
			"distance": global_position.distance_to(points[i]),
			"choke_buffer": _route_steps_to_nearest_choke(i, points.size()),
		})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["choke_buffer"]) != int(b["choke_buffer"]):
			return int(a["choke_buffer"]) > int(b["choke_buffer"])
		return float(a["distance"]) > float(b["distance"])
	)
	points.clear()
	for entry in indexed:
		points.append(entry["point"])
	return points


func _apply_reserved_patrol_point(point: Vector2) -> void:
	if use_route_patrol and patrol_points.size() >= 2:
		for i in range(patrol_points.size()):
			if patrol_points[i].distance_to(point) < 1.0:
				_patrol_index = i
				break
		patrol_step = _preferred_patrol_step(_patrol_index, patrol_points.size())
		global_position = point
	else:
		global_position = anchor
	_last_position = global_position
	_stuck_timer = 0.0
	_route_pause = 0.18


func resume_from_patrol_reentry(position: Vector2) -> void:
	_apply_reserved_patrol_point(position)
	super.resume_from_patrol_reentry(position)


func _route_steps_to_nearest_choke(index: int, route_size: int) -> int:
	if choke_indices.is_empty() or route_size <= 2:
		return 999
	var best: int = route_size
	for choke in choke_indices:
		var choke_index: int = clampi(int(choke), 0, route_size - 1)
		var raw_delta: int = absi(index - choke_index)
		best = mini(best, mini(raw_delta, route_size - raw_delta))
	return best


func _steps_to_choke_in_direction(start_index: int, direction: int, route_size: int) -> int:
	if choke_indices.is_empty() or route_size <= 2:
		return 999
	var index := start_index
	for step_count in range(1, route_size + 1):
		index = posmod(index + direction, route_size)
		if index in choke_indices:
			return step_count
	return route_size


func _preferred_patrol_step(index: int, route_size: int) -> int:
	var forward_steps := _steps_to_choke_in_direction(index, 1, route_size)
	var backward_steps := _steps_to_choke_in_direction(index, -1, route_size)
	if forward_steps == backward_steps:
		return patrol_step if patrol_step != 0 else 1
	return 1 if forward_steps > backward_steps else -1


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(signature_color, 0.05 if not AlertSystem.combat_mode else 0.12)
	outline.default_color = enemy_state_outline()
	outline.width = 1.05
	_sync_visual_overlays()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _wisp_draw_tint() -> Color:
	if is_emp_disabled():
		return Color(0.82, 0.96, 1.0, 0.96)
	if combat_active:
		return Color(1.0, 0.96, 0.9, 0.98)
	if is_alerting_state():
		return Color(1.0, 0.46, 0.22, 0.96)
	var c := outline.default_color
	return Color(c.r, c.g, c.b, 0.92)


func _draw() -> void:
	var tint := _wisp_draw_tint()
	draw_circle(Vector2.ZERO, 58.0, Color(tint.r, tint.g, tint.b, 0.045))
	draw_circle(Vector2.ZERO, 42.0, Color(tint.r, tint.g, tint.b, 0.075))
	draw_circle(Vector2.ZERO, 29.0, Color(tint.r, tint.g, tint.b, 0.11))
	draw_circle(Vector2.ZERO, 18.0, Color(tint.r, tint.g, tint.b, 0.085))
	if not combat_active:
		draw_circle(Vector2.ZERO, alert_radius + 18.0, Color(tint.r, tint.g, tint.b, 0.06))
		draw_circle(Vector2.ZERO, alert_radius + 8.0, Color(tint.r, tint.g, tint.b, 0.08))
		draw_circle(Vector2.ZERO, alert_radius, Color(tint.r, tint.g, tint.b, 0.10))
		draw_arc(Vector2.ZERO, alert_radius, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.52), 1.1)
		draw_arc(Vector2.ZERO, alert_radius * 0.7, 0.0, TAU, 28, Color(tint.r, tint.g, tint.b, 0.28), 0.7)
	var whisker := Vector2(0.0, -20.0).rotated(phase * 2.0)
	draw_line(Vector2.ZERO, whisker, Color(tint.r, tint.g, tint.b, 0.28), 0.75)
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -8.0),
		Vector2(6.0, 0.0),
		Vector2(0.0, 8.0),
		Vector2(-6.0, 0.0),
		Vector2(0.0, -8.0)
	]), Color(tint.r, tint.g, tint.b, 0.72), 1.1)
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, marker, 0.55)
	draw_alert_marker()
	draw_emp_disabled_effect(34.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
