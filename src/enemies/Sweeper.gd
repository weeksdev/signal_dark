extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

@export var signature_color := Color("00ff88")
@export var detection_range: float = 225.0
@export var cone_angle_degrees: float = 65.0
@export var patrol_speed: float = 60.0
@export var combat_speed: float = 140.0
@export var suppress_range: float = 34.0

const ARRIVE_DIST      := 14.0
const ROUTE_ARRIVE_DIST := 20.0
const DWELL_TIME       := 0.55
const STEER_ACCEL      := 320.0
const PULSE_SPEED      := 115.0
const PULSE_TOLERANCE  := 13.0
const ALERT_HOLD_SECONDS := 3.0
const SUSPICION_DECAY  := 0.75
const WARN_RANGE       := 184.0

# Rhythm: single pulse, then two quick, then long gap — repeating
const PULSE_PATTERN: Array[float] = [1.3, 0.38, 0.38, 2.1]
const SEARCH_INTEREST_RADIUS := 225.0

var _waypoints: Array[Vector2] = []
var _wp_index: int = 0
var _dwell: float = 0.0
var patrol_points: Array = []
var patrol_start_index: int = 0
var patrol_step: int = 1
var choke_indices: Array = []
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO

var _pulses: Array[float] = []
var _pulse_timer: float = 0.3
var _pulse_idx: int = 0

@onready var patrol_a: Marker2D = $PatrolA
@onready var patrol_b: Marker2D = $PatrolB


func _ready() -> void:
	super._ready()
	_last_position = global_position
	if patrol_points.size() >= 2:
		_waypoints.clear()
		for point in patrol_points:
			_waypoints.append(point)
	else:
		_waypoints = [patrol_a.global_position, patrol_b.global_position]
	_wp_index = clampi(patrol_start_index, 0, max(_waypoints.size() - 1, 0))


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if tick_support_state(delta):
		queue_redraw()
		return

	tick_alert_state(delta, SUSPICION_DECAY)

	# Advance all pulses; cull ones past max range
	for i in range(_pulses.size() - 1, -1, -1):
		_pulses[i] += PULSE_SPEED * delta
		if _pulses[i] > detection_range:
			_pulses.remove_at(i)

	# Fire new pulses on pattern rhythm (stealth only)
	if not combat_active:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0:
			_pulses.append(0.0)
			_pulse_idx = (_pulse_idx + 1) % PULSE_PATTERN.size()
			_pulse_timer = PULSE_PATTERN[_pulse_idx]

	if combat_active and is_instance_valid(ship):
		var chase_vector: Vector2 = ship.global_position - global_position
		if chase_vector != Vector2.ZERO:
			facing_vector = chase_vector.normalized()
			velocity = facing_vector * combat_speed
		move_and_slide()
		if get_slide_collision_count() > 0:
			velocity = Vector2.ZERO
			_dwell = 0.2
		if global_position.distance_to(ship.global_position) < 18.0:
			if not ship.get("cover_active"):
				ship.take_hit()
	else:
		_run_patrol(delta)
		_check_detection()

	if asset_visual != null:
		var target_angle := facing_vector.angle() - PI * 0.5
		asset_visual.rotation = lerp_angle(asset_visual.rotation, target_angle, minf(delta * 10.0, 1.0))

	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)
	_pulses.clear()


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO
	_pulses.clear()
	_pulse_timer = PULSE_PATTERN[0]
	_pulse_idx = 0
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
	var offset: Vector2 = ship_node.global_position - global_position
	if offset.length() > suppress_range:
		return false
	var approach: Vector2 = offset.normalized()
	return facing_vector.dot(approach) < -0.35


func take_damage(silent: bool, _hit_origin: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	is_alive = false
	_spawn_burst(silent)
	killed.emit(self, silent)
	queue_free()


func _run_patrol(delta: float) -> void:
	if _dwell > 0.0:
		_dwell -= delta
		velocity = velocity.move_toward(Vector2.ZERO, STEER_ACCEL * delta)
		move_and_slide()
		return

	var target: Vector2 = _waypoints[_wp_index]
	if world_has_active_probe():
		target = world_probe_target()
	else:
		var search_target: Variant = world_search_target_if_relevant(SEARCH_INTEREST_RADIUS)
		if search_target is Vector2:
			target = search_target

	var offset: Vector2 = target - global_position
	var arrive_dist := ROUTE_ARRIVE_DIST if _waypoints.size() > 2 else ARRIVE_DIST
	if offset.length() > arrive_dist:
		var desired_dir := offset.normalized()
		facing_vector = facing_vector.lerp(desired_dir, clampf(delta * 7.0, 0.0, 1.0)).normalized()
		velocity = velocity.move_toward(desired_dir * patrol_speed, STEER_ACCEL * delta)
		move_and_slide()
		_push_out_of_dark_pockets(delta)
		_update_stuck_recovery(delta, offset)
		if get_slide_collision_count() > 0:
			velocity = Vector2.ZERO
			_recover_from_block()
	else:
		velocity = Vector2.ZERO
		_advance_patrol()


func _advance_patrol() -> void:
	if _waypoints.size() <= 2:
		_wp_index = 1 - _wp_index
	else:
		_wp_index = posmod(_wp_index + patrol_step, _waypoints.size())
	_stuck_timer = 0.0
	_last_position = global_position
	_dwell = DWELL_TIME * (1.35 if _wp_index in choke_indices else 1.0)


func _update_stuck_recovery(delta: float, offset: Vector2) -> void:
	if _waypoints.size() <= 2:
		return
	var moved := global_position.distance_to(_last_position)
	if offset.length() > ARRIVE_DIST * 1.5 and moved < 1.0:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_position = global_position
	if _stuck_timer > 0.35:
		_recover_from_block()


func _recover_from_block() -> void:
	_advance_patrol()
	velocity = Vector2.ZERO


func _snap_to_patrol_route() -> void:
	if _waypoints.is_empty():
		return
	var ordered_points := _ordered_recovery_points()
	var reserved: Variant = world_call("reserve_patrol_recovery_point", [self, ordered_points])
	if reserved is Vector2:
		_apply_reserved_patrol_point(reserved)
		return
	world_call("schedule_enemy_patrol_reentry", [self, ordered_points])


func _ordered_recovery_points() -> Array:
	var ordered := _waypoints.duplicate()
	if _waypoints.size() <= 1:
		return ordered
	var indexed: Array = []
	for i in range(_waypoints.size()):
		indexed.append({
			"index": i,
			"point": _waypoints[i],
			"distance": global_position.distance_to(_waypoints[i]),
			"choke_buffer": _route_steps_to_nearest_choke(i),
		})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["choke_buffer"]) != int(b["choke_buffer"]):
			return int(a["choke_buffer"]) > int(b["choke_buffer"])
		return float(a["distance"]) > float(b["distance"])
	)
	ordered.clear()
	for entry in indexed:
		ordered.append(entry["point"])
	return ordered


func _apply_reserved_patrol_point(point: Vector2) -> void:
	for i in range(_waypoints.size()):
		if _waypoints[i].distance_to(point) < 1.0:
			_wp_index = i
			break
	if _waypoints.size() > 2:
		patrol_step = _preferred_patrol_step(_wp_index)
	global_position = point
	_last_position = global_position
	_stuck_timer = 0.0
	_dwell = DWELL_TIME * 0.45


func resume_from_patrol_reentry(position: Vector2) -> void:
	_apply_reserved_patrol_point(position)
	super.resume_from_patrol_reentry(position)


func _route_steps_to_nearest_choke(index: int) -> int:
	if choke_indices.is_empty() or _waypoints.size() <= 2:
		return 999
	var best: int = _waypoints.size()
	for choke in choke_indices:
		var choke_index: int = clampi(int(choke), 0, _waypoints.size() - 1)
		var raw_delta: int = absi(index - choke_index)
		best = mini(best, mini(raw_delta, _waypoints.size() - raw_delta))
	return best


func _steps_to_choke_in_direction(start_index: int, direction: int) -> int:
	if choke_indices.is_empty() or _waypoints.size() <= 2:
		return 999
	var index := start_index
	for step_count in range(1, _waypoints.size() + 1):
		index = posmod(index + direction, _waypoints.size())
		if index in choke_indices:
			return step_count
	return _waypoints.size()


func _preferred_patrol_step(index: int) -> int:
	var forward_steps := _steps_to_choke_in_direction(index, 1)
	var backward_steps := _steps_to_choke_in_direction(index, -1)
	if forward_steps == backward_steps:
		return patrol_step if patrol_step != 0 else 1
	return 1 if forward_steps > backward_steps else -1


func _check_detection() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		_suspicion = 0.0
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	var emission: float = player.get_effective_emission()
	var speed_ratio: float = clampf(player.velocity.length() / maxf(player.max_speed, 1.0), 0.0, 1.0)

	# Dark pocket completely masks the player beyond contact range
	if player.in_dark_pocket and distance > 28.0:
		_suspicion = 0.0
		return
	if should_suppress_detection_of(player):
		_suspicion = 0.0
		return

	# Contact range — always triggers
	if distance < 22.0 and emission > 0.015:
		_begin_alert_hold()
		return

	# Cone arc check
	if facing_vector.dot(to_player.normalized()) < cos(deg_to_rad(cone_angle_degrees * 0.5)):
		return

	# Line of sight
	if is_world_line_blocked(global_position, player.global_position, [get_rid()]):
		return

	var risk := _proximity_risk(distance, emission, speed_ratio, player.dark_mode)
	if world_is_search_active():
		risk *= 1.12
	if risk > 0.105:
		_suspicion = 0.0
		_begin_alert_hold()
		return

	# Pulse arc hit
	var hit := false
	for pulse_r: float in _pulses:
		if abs(distance - pulse_r) < PULSE_TOLERANCE:
			if emission > 0.05 or distance < 40.0:
				hit = true
				break

	if hit:
		_suspicion = 0.0
		_begin_alert_hold()


func _begin_alert_hold() -> void:
	begin_alert_state(ALERT_HOLD_SECONDS)


func _proximity_risk(distance: float, emission: float, speed_ratio: float, dark_mode: bool) -> float:
	if distance > WARN_RANGE:
		return 0.0
	var closeness := 1.0 - (distance / WARN_RANGE)
	var speed_risk := 0.24 + speed_ratio * 0.76
	var emission_risk := emission * 2.25
	var dark_penalty := 0.55 if dark_mode else 1.0
	return (closeness * (speed_risk + emission_risk)) * dark_penalty


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(signature_color, 0.08 if not AlertSystem.combat_mode else 0.14)
	outline.default_color = enemy_state_outline()
	outline.width = 1.2
	_sync_visual_overlays()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var halo_color := outline.default_color
	draw_circle(Vector2.ZERO, 20.0, Color(halo_color.r, halo_color.g, halo_color.b, 0.05))

	var cone_color := outline.default_color
	var half_rad := deg_to_rad(cone_angle_degrees * 0.5)
	var start_angle := facing_vector.angle() - half_rad
	var end_angle   := facing_vector.angle() + half_rad

	# Expanding pulse arcs — brightest at origin, fade toward max range
	for pulse_r: float in _pulses:
		var fade := 1.0 - (pulse_r / detection_range)
		var arc_col := Color(cone_color.r, cone_color.g, cone_color.b, 0.70 * fade)
		draw_arc(Vector2.ZERO, pulse_r, start_angle, end_angle, 32, arc_col, 1.2)
		# Soft echo trail behind the arc
		if pulse_r > 10.0:
			draw_arc(Vector2.ZERO, pulse_r - 7.0, start_angle, end_angle, 24,
					Color(cone_color.r, cone_color.g, cone_color.b, 0.18 * fade), 1.2)

	# Plus / targeting reticle at center
	var arm := 9.0
	var gap := 2.5
	var mc := Color(cone_color.r, cone_color.g, cone_color.b, 0.78)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, -gap), mc, 1.1)
	draw_line(Vector2(0.0,  gap), Vector2(0.0,  arm), mc, 1.1)
	draw_line(Vector2(-arm, 0.0), Vector2(-gap, 0.0), mc, 1.1)
	draw_line(Vector2( gap, 0.0), Vector2( arm, 0.0), mc, 1.1)
	draw_arc(Vector2.ZERO, gap, 0.0, TAU, 16, Color(mc.r, mc.g, mc.b, 0.5), 0.6)

	# MGS-style "!" alert marker
	draw_alert_marker()

	# Suppress indicator
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, marker, 0.6)
		draw_line(Vector2(-14.0, -14.0), Vector2(-6.0, -14.0), marker, 0.9)
		draw_line(Vector2(-14.0, -14.0), Vector2(-14.0, -6.0), marker, 0.9)
		draw_line(Vector2(14.0, 14.0), Vector2(6.0, 14.0), marker, 0.9)
		draw_line(Vector2(14.0, 14.0), Vector2(14.0, 6.0), marker, 0.9)
	draw_suspicion_arc(28.0)
	draw_emp_disabled_effect(30.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
