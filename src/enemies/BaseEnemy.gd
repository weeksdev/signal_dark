extends CharacterBody2D

const RuntimeDebugLog := preload("res://src/debug/RuntimeDebugLog.gd")
const ElectricSparks = preload("res://src/fx/ElectricSparks.gd")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)
signal suspicious(enemy: Node)

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var _alerting: bool = false
var _alert_hold: float = 0.0
var _suspicion: float = 0.0
var _emp_disabled_timer: float = 0.0
var _visual_state_key: String = ""
var _support_receive_timer: float = 0.0
var _support_delay_timer: float = 0.0
var _support_search_timer: float = 0.0
var _support_search_target: Vector2 = Vector2.ZERO
var _suspicion_source_timer: float = 0.0
var _reentry_suspended: bool = false
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0
var _sparks: Node2D = null

const DARK_POCKET_AVOID_RADIUS := 82.0
const DARK_POCKET_TARGET_RADIUS := 112.0
const SEARCH_VISUAL_RADIUS := 150.0
const DEFAULT_SEARCH_INTEREST_RADIUS := 210.0
const SUSPICION_SOURCE_DURATION := 0.7

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline
@onready var hover_glow = get_node_or_null("HoverGlow")
@onready var asset_visual = get_node_or_null("Enemy1Visual")


func _ready() -> void:
	add_to_group("zone_enemy")
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_sparks = ElectricSparks.new()
	_sparks.radius = 22.0
	_sparks.z_index = 12
	add_child(_sparks)
	_refresh_visual_state(true)


func _process(_delta: float) -> void:
	_refresh_visual_state()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if combat_active and is_instance_valid(ship):
		_update_palette()
		var chase_vector: Vector2 = ship.global_position - global_position
		if chase_vector != Vector2.ZERO:
			facing_vector = chase_vector.normalized()
			velocity = facing_vector * _combat_speed_value()
		move_and_slide()
		_push_out_of_dark_pockets(delta)
		if global_position.distance_to(ship.global_position) < 18.0:
			if not ship.get("cover_active"):
				ship.take_hit()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true
	_update_palette()


func can_be_suppressed_by(ship_node: Node2D) -> bool:
	if not is_alive or combat_active:
		return false
	if not ship_node.dark_mode:
		return false
	var offset: Vector2 = ship_node.global_position - global_position
	if offset.length() > _suppress_range_value():
		return false
	var approach: Vector2 = offset.normalized()
	return facing_vector.dot(approach) < -0.35


func take_damage(silent: bool, _hit_origin: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	is_alive = false
	killed.emit(self, silent)
	queue_free()


func emit_detection() -> void:
	if not is_alive:
		return
	detected.emit(self)


func is_alerting_state() -> bool:
	return _alerting


func stealth_reveal_level() -> float:
	if combat_active or is_emp_disabled():
		return 0.0
	if _alerting:
		return 1.0
	return clampf(_suspicion, 0.0, 1.0)


func is_valid_auto_fire_target(_from_point: Vector2) -> bool:
	return is_alive and not _reentry_suspended


func is_combat_targetable() -> bool:
	return combat_active and is_alive and not _reentry_suspended


func tick_alert_state(delta: float, suspicion_decay: float = 0.0) -> void:
	var old_suspicion := _suspicion
	var old_alerting := _alerting
	if _suspicion_source_timer > 0.0:
		_suspicion_source_timer = maxf(0.0, _suspicion_source_timer - delta)
	if _alert_hold > 0.0:
		_alert_hold -= delta
		if _alert_hold <= 0.0:
			_alerting = false
	if not combat_active and suspicion_decay > 0.0:
		_suspicion = maxf(0.0, _suspicion - delta * suspicion_decay)
	if absf(old_suspicion - _suspicion) > 0.02 or old_alerting != _alerting:
		_update_palette()


func clear_alert_state() -> void:
	_alerting = false
	_alert_hold = 0.0
	_suspicion = 0.0
	_suspicion_source_timer = 0.0
	_clear_support_state()
	_refresh_visual_state(true)


func suspend_for_patrol_reentry() -> void:
	if _reentry_suspended:
		return
	_reentry_suspended = true
	velocity = Vector2.ZERO
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	set_process(false)


func resume_from_patrol_reentry(position: Vector2) -> void:
	global_position = position
	_reentry_suspended = false
	visible = true
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	set_process(true)
	set_physics_process(true)
	_refresh_visual_state(true)
	queue_redraw()


func begin_alert_state(hold_seconds: float) -> void:
	_suspicion = 1.0
	if not _alerting:
		_alerting = true
		detected.emit(self)
	_alert_hold = hold_seconds
	_refresh_visual_state(true)


func add_suspicion(amount: float) -> bool:
	if is_emp_disabled():
		return false
	var old_suspicion := _suspicion
	_suspicion = minf(1.0, _suspicion + amount)
	if old_suspicion <= 0.06 and _suspicion > 0.06:
		_suspicion_source_timer = SUSPICION_SOURCE_DURATION
		RuntimeDebugLog.log("suspicion", "%s became suspicious at (%.1f, %.1f) old=%.3f new=%.3f" % [name, global_position.x, global_position.y, old_suspicion, _suspicion])
		suspicious.emit(self)
	_refresh_visual_state(true)
	return _suspicion >= 1.0


func apply_emp_disable(duration: float) -> void:
	_emp_disabled_timer = maxf(_emp_disabled_timer, duration)
	_alerting = false
	_alert_hold = 0.0
	_suspicion = 0.0
	_suspicion_source_timer = 0.0
	_clear_support_state()
	velocity = Vector2.ZERO
	_refresh_visual_state(true)


func is_emp_disabled() -> bool:
	return _emp_disabled_timer > 0.0


func tick_emp_disabled(delta: float) -> bool:
	if _emp_disabled_timer <= 0.0:
		return false
	_emp_disabled_timer = maxf(0.0, _emp_disabled_timer - delta)
	velocity = Vector2.ZERO
	return _emp_disabled_timer > 0.0


func _world() -> Node:
	return GameState.current_world


func world_has_method(method_name: String) -> bool:
	var world := _world()
	return world != null and is_instance_valid(world) and world.has_method(method_name)


func world_call(method_name: String, args: Array = []) -> Variant:
	var world := _world()
	if world == null or not is_instance_valid(world) or not world.has_method(method_name):
		return null
	return world.callv(method_name, args)


func is_world_line_blocked(from_point: Vector2, to_point: Vector2, exclusions := []) -> bool:
	var result: Variant = world_call("is_line_blocked", [from_point, to_point, exclusions])
	return bool(result) if result != null else false


func world_has_active_probe() -> bool:
	var result: Variant = world_call("has_active_probe")
	return bool(result) if result != null else false


func world_probe_target() -> Vector2:
	var result: Variant = world_call("get_probe_target")
	return result if result is Vector2 else global_position


func world_is_search_active() -> bool:
	var result: Variant = world_call("is_search_active")
	return bool(result) if result != null else false


func world_search_target() -> Vector2:
	var result: Variant = world_call("get_search_target")
	return safe_enemy_target(result) if result is Vector2 else global_position


func world_search_target_for_self() -> Vector2:
	var result: Variant = world_call("get_search_target_for", [self])
	return safe_enemy_target(result) if result is Vector2 else world_search_target()


func world_search_target_if_relevant(max_distance: float = DEFAULT_SEARCH_INTEREST_RADIUS) -> Variant:
	var support_target: Variant = support_search_target_if_relevant(max_distance)
	if support_target is Vector2:
		return support_target
	if not world_is_search_active():
		return null
	var target := world_search_target_for_self()
	if global_position.distance_to(target) > max_distance:
		return null
	return target


func can_receive_search_support() -> bool:
	return is_alive and not combat_active and not is_emp_disabled()


func receive_search_support(target: Vector2, receive_time: float, delay_time: float, duration: float) -> bool:
	if not can_receive_search_support():
		RuntimeDebugLog.log("support", "%s rejected support request" % name)
		return false
	_support_search_target = safe_enemy_target(target)
	_support_receive_timer = maxf(_support_receive_timer, receive_time)
	_support_delay_timer = maxf(_support_delay_timer, delay_time)
	_support_search_timer = maxf(_support_search_timer, duration)
	velocity = Vector2.ZERO
	RuntimeDebugLog.log("support", "%s received support target=(%.1f, %.1f) receive=%.2f delay=%.2f duration=%.2f" % [name, _support_search_target.x, _support_search_target.y, receive_time, delay_time, duration])
	_refresh_visual_state(true)
	return true


func tick_support_state(delta: float) -> bool:
	var had_state := _support_receive_timer > 0.0 or _support_delay_timer > 0.0 or _support_search_timer > 0.0
	var paused := false
	if _support_receive_timer > 0.0:
		_support_receive_timer = maxf(0.0, _support_receive_timer - delta)
		paused = true
	elif _support_delay_timer > 0.0:
		_support_delay_timer = maxf(0.0, _support_delay_timer - delta)
		paused = true
	elif _support_search_timer > 0.0:
		_support_search_timer = maxf(0.0, _support_search_timer - delta)
		if _support_search_timer <= 0.0:
			_support_search_target = Vector2.ZERO
	if paused:
		velocity = Vector2.ZERO
	var has_state := _support_receive_timer > 0.0 or _support_delay_timer > 0.0 or _support_search_timer > 0.0
	if had_state != has_state or paused:
		_refresh_visual_state(true)
	return paused


func support_search_target_if_relevant(max_distance: float = DEFAULT_SEARCH_INTEREST_RADIUS) -> Variant:
	if _support_receive_timer > 0.0 or _support_delay_timer > 0.0 or _support_search_timer <= 0.0:
		return null
	if global_position.distance_to(_support_search_target) > max_distance:
		return null
	return _support_search_target


func world_is_point_jammed(point: Vector2) -> bool:
	var result: Variant = world_call("is_point_jammed", [point])
	return bool(result) if result != null else false


func should_suppress_detection_of(player: Node2D) -> bool:
	if player == null:
		return false
	if player.in_dark_pocket:
		return true
	var result: Variant = world_call("should_suppress_enemy_detection", [self, player])
	return bool(result) if result != null else false


func safe_enemy_target(target: Vector2) -> Vector2:
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if not (pocket is Node2D):
			continue
		var pocket_pos: Vector2 = pocket.global_position
		var offset: Vector2 = target - pocket_pos
		var distance := offset.length()
		if distance >= DARK_POCKET_TARGET_RADIUS:
			continue
		var direction := offset.normalized() if distance > 0.01 else (global_position - pocket_pos).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		target = pocket_pos + direction * DARK_POCKET_TARGET_RADIUS
	return target


func _push_out_of_dark_pockets(delta: float = 0.016) -> void:
	if combat_active:
		return
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if not (pocket is Node2D):
			continue
		var pocket_pos: Vector2 = pocket.global_position
		var offset: Vector2 = global_position - pocket_pos
		var distance := offset.length()
		if distance >= DARK_POCKET_AVOID_RADIUS:
			continue
		var direction := offset.normalized() if distance > 0.01 else facing_vector
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var penetration := DARK_POCKET_AVOID_RADIUS - distance
		var push_speed := 120.0 + penetration * 3.2
		global_position += direction * minf(penetration, push_speed * delta)
		velocity = velocity.slide(-direction) * 0.65


func add_effect_to_world(node: Node) -> void:
	var world := _world()
	if world != null and is_instance_valid(world):
		world.add_child(node)


func draw_alert_marker() -> void:
	if not _alerting or combat_active:
		return
	var t_ms: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.75 + 0.25 * sin(t_ms * 14.0)
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(0.0, 0.0, 0.0, 0.75), true)
	draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(1.0, 0.12, 0.08, pulse * 0.95), false, 1.5)
	draw_string(font, Vector2(-5.0, -36.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.18, 0.12, pulse))


func draw_suspicion_arc(radius: float, min_threshold: float = 0.06) -> void:
	if _alerting or combat_active or _suspicion <= min_threshold:
		return
	var warning := Color(1.0, 0.86, 0.18, 0.42 + _suspicion * 0.4)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * _suspicion, 28, warning, 1.1)
	if _suspicion > 0.28:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 32, Color(1.0, 0.52, 0.08, 0.2 + _suspicion * 0.18), 0.6)


func draw_emp_disabled_effect(radius: float = 30.0) -> void:
	if not is_emp_disabled():
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 58.0)
	var c := Color(0.55, 0.95, 1.0, 0.52 + pulse * 0.25)
	draw_circle(Vector2.ZERO, radius * 0.7, Color(c.r, c.g, c.b, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.15, TAU * 0.62, 22, c, 1.0)
	draw_arc(Vector2.ZERO, radius * 0.58, PI, TAU * 1.42, 18, Color(c.r, c.g, c.b, 0.34), 0.7)
	draw_line(Vector2(-radius * 0.45, -radius * 0.2), Vector2(radius * 0.36, radius * 0.22), c, 0.7)
	draw_line(Vector2(radius * 0.12, -radius * 0.38), Vector2(-radius * 0.24, radius * 0.34), Color(c.r, c.g, c.b, 0.42), 0.5)


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(_signature_color_value(), 0.08 if not AlertSystem.combat_mode else 0.14)
	outline.default_color = enemy_state_outline()
	_sync_visual_overlays()


func _on_mode_changed(_in_combat: bool) -> void:
	_refresh_visual_state(true)


func _combat_speed_value() -> float:
	var value: Variant = get("combat_speed")
	return float(value) if value != null else 140.0


func _suppress_range_value() -> float:
	var value: Variant = get("suppress_range")
	return float(value) if value != null else 34.0


func _signature_color_value() -> Color:
	var value: Variant = get("signature_color")
	return value if value is Color else Color("00ff88")


func enemy_state_outline() -> Color:
	if is_emp_disabled():
		return Color(0.55, 0.95, 1.0, 0.95)
	if combat_active:
		var pulse_color := _combat_pulse_color()
		return Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.98)
	if _alerting and not combat_active:
		return Color(1.0, 0.12, 0.08, 0.95)
	var source_t := _suspicion_source_strength()
	if source_t > 0.0 and not combat_active:
		return Color(1.0, 0.9, 0.22, lerpf(0.84, 0.98, source_t))
	var support_t := _support_visual_strength()
	if support_t > 0.0 and not combat_active:
		return Color(0.94, 0.62, 0.14, lerpf(0.64, 0.78, support_t))
	if _suspicion > 0.06 and not combat_active:
		var t := clampf(_suspicion, 0.0, 1.0)
		return Color(0.98, lerpf(0.74, 0.38, t), 0.12, 0.8)
	var search_t := _search_visual_strength()
	if search_t > 0.0 and not combat_active:
		return Color(0.86, lerpf(0.48, 0.58, search_t), 0.12, lerpf(0.52, 0.66, search_t))
	return ColorSystem.enemy_outline()


func enemy_state_fill(base_color: Color, alpha: float) -> Color:
	var fill := ColorSystem.enemy_fill(base_color)
	fill.a = alpha
	if is_emp_disabled():
		return Color(0.18, 0.55, 0.72, maxf(alpha, 0.12))
	if combat_active:
		var pulse_color := _combat_pulse_color()
		return Color(pulse_color.r * 0.55, pulse_color.g * 0.34, pulse_color.b * 0.08, maxf(alpha, 0.2))
	if _alerting and not combat_active:
		return Color(0.72, 0.04, 0.02, maxf(alpha, 0.18))
	var source_t := _suspicion_source_strength()
	if source_t > 0.0 and not combat_active:
		return Color(0.62, 0.34, 0.05, maxf(alpha, 0.12 + source_t * 0.08))
	var support_t := _support_visual_strength()
	if support_t > 0.0 and not combat_active:
		return Color(0.42, 0.23, 0.04, maxf(alpha, 0.08 + support_t * 0.04))
	if _suspicion > 0.06 and not combat_active:
		var t := clampf(_suspicion, 0.0, 1.0)
		return Color(0.56 + t * 0.12, 0.26 + (1.0 - t) * 0.12, 0.03, maxf(alpha, 0.1 + t * 0.05))
	var search_t := _search_visual_strength()
	if search_t > 0.0 and not combat_active:
		return Color(0.28 + search_t * 0.08, 0.16 + search_t * 0.04, 0.03, maxf(alpha, 0.06 + search_t * 0.03))
	return fill


func _combat_pulse_color() -> Color:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	return Color(1.0, lerpf(0.12, 0.86, pulse), 0.03, 1.0)


func _refresh_visual_state(force: bool = false) -> void:
	var suspicion_bucket := int(floor(clampf(_suspicion, 0.0, 1.0) * 5.0))
	var search_bucket := int(floor(_search_visual_strength() * 4.0))
	var source_bucket := int(floor(_suspicion_source_strength() * 4.0))
	var support_bucket := int(floor(_support_visual_strength() * 4.0))
	var next_key := "%s|%s|%s|%s|%s|%s|%s" % [combat_active, is_emp_disabled(), _alerting, suspicion_bucket, search_bucket, source_bucket, support_bucket]
	if not force and next_key == _visual_state_key:
		return
	_visual_state_key = next_key
	_update_palette()
	queue_redraw()


func _sync_visual_overlays() -> void:
	if hover_glow != null and hover_glow.has_method("set_glow_color"):
		var glow_strength := 0.55
		if combat_active:
			glow_strength = 0.92
		elif _alerting:
			glow_strength = 0.78
		elif _suspicion > 0.06:
			glow_strength = 0.66
		hover_glow.set_glow_color(outline.default_color, glow_strength)
	if asset_visual != null and asset_visual.has_method("apply_palette"):
		asset_visual.apply_palette(body_polygon.color, outline.default_color, combat_active, _alerting, is_emp_disabled())
	if _sparks != null:
		var spark_intensity := 0.18
		if is_emp_disabled():
			spark_intensity = 0.85
		elif combat_active:
			spark_intensity = 0.55
		elif _alerting:
			spark_intensity = 0.38
		_sparks.intensity = spark_intensity


func _search_visual_strength() -> float:
	if combat_active or _alerting or _suspicion > 0.06 or not world_is_search_active():
		return 0.0
	var target := world_search_target_for_self()
	var distance := global_position.distance_to(target)
	if distance >= SEARCH_VISUAL_RADIUS:
		return 0.0
	return 1.0 - (distance / SEARCH_VISUAL_RADIUS)


func _support_visual_strength() -> float:
	if combat_active or is_emp_disabled():
		return 0.0
	if _support_receive_timer > 0.0 or _support_delay_timer > 0.0:
		return 1.0
	if _support_search_timer <= 0.0:
		return 0.0
	var distance := global_position.distance_to(_support_search_target)
	if distance >= SEARCH_VISUAL_RADIUS:
		return 0.0
	return 1.0 - (distance / SEARCH_VISUAL_RADIUS)


func _suspicion_source_strength() -> float:
	if combat_active or is_emp_disabled() or _alerting or _suspicion <= 0.06:
		return 0.0
	return clampf(_suspicion_source_timer / SUSPICION_SOURCE_DURATION, 0.0, 1.0)


func _clear_support_state() -> void:
	_support_receive_timer = 0.0
	_support_delay_timer = 0.0
	_support_search_timer = 0.0
	_support_search_target = Vector2.ZERO
