extends CharacterBody2D

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var _alerting: bool = false
var _alert_hold: float = 0.0
var _suspicion: float = 0.0
var _emp_disabled_timer: float = 0.0

const DARK_POCKET_AVOID_RADIUS := 82.0
const DARK_POCKET_TARGET_RADIUS := 112.0

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if combat_active and is_instance_valid(ship):
		var chase_vector: Vector2 = ship.global_position - global_position
		if chase_vector != Vector2.ZERO:
			facing_vector = chase_vector.normalized()
			velocity = facing_vector * _combat_speed_value()
		move_and_slide()
		_push_out_of_dark_pockets()
		if global_position.distance_to(ship.global_position) < 18.0:
			ship.take_hit()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true


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


func tick_alert_state(delta: float, suspicion_decay: float = 0.0) -> void:
	if _alert_hold > 0.0:
		_alert_hold -= delta
		if _alert_hold <= 0.0:
			_alerting = false
	if not combat_active and suspicion_decay > 0.0:
		_suspicion = maxf(0.0, _suspicion - delta * suspicion_decay)


func clear_alert_state() -> void:
	_alerting = false
	_alert_hold = 0.0
	_suspicion = 0.0


func begin_alert_state(hold_seconds: float) -> void:
	_suspicion = 1.0
	if not _alerting:
		_alerting = true
		detected.emit(self)
	_alert_hold = hold_seconds


func add_suspicion(amount: float) -> bool:
	if is_emp_disabled():
		return false
	_suspicion = minf(1.0, _suspicion + amount)
	return _suspicion >= 1.0


func apply_emp_disable(duration: float) -> void:
	_emp_disabled_timer = maxf(_emp_disabled_timer, duration)
	_alerting = false
	_alert_hold = 0.0
	_suspicion = 0.0
	velocity = Vector2.ZERO
	queue_redraw()


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


func world_is_point_jammed(point: Vector2) -> bool:
	var result: Variant = world_call("is_point_jammed", [point])
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


func _push_out_of_dark_pockets() -> void:
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
		global_position = pocket_pos + direction * DARK_POCKET_AVOID_RADIUS
		velocity = Vector2.ZERO


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
	draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(1.0, 0.85, 0.0, pulse * 0.9), false, 1.5)
	draw_string(font, Vector2(-5.0, -36.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.90, 0.0, pulse))


func draw_suspicion_arc(radius: float, min_threshold: float = 0.06) -> void:
	if _alerting or combat_active or _suspicion <= min_threshold:
		return
	var warning := Color(1.0, 0.86, 0.18, 0.42 + _suspicion * 0.4)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * _suspicion, 28, warning, 2.2)


func draw_emp_disabled_effect(radius: float = 30.0) -> void:
	if not is_emp_disabled():
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 58.0)
	var c := Color(0.55, 0.95, 1.0, 0.52 + pulse * 0.25)
	draw_circle(Vector2.ZERO, radius * 0.7, Color(c.r, c.g, c.b, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.15, TAU * 0.62, 22, c, 2.0)
	draw_arc(Vector2.ZERO, radius * 0.58, PI, TAU * 1.42, 18, Color(c.r, c.g, c.b, 0.34), 1.4)
	draw_line(Vector2(-radius * 0.45, -radius * 0.2), Vector2(radius * 0.36, radius * 0.22), c, 1.4)
	draw_line(Vector2(radius * 0.12, -radius * 0.38), Vector2(-radius * 0.24, radius * 0.34), Color(c.r, c.g, c.b, 0.42), 1.0)


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(_signature_color_value())
	outline.default_color = ColorSystem.enemy_outline()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _combat_speed_value() -> float:
	var value: Variant = get("combat_speed")
	return float(value) if value != null else 140.0


func _suppress_range_value() -> float:
	var value: Variant = get("suppress_range")
	return float(value) if value != null else 34.0


func _signature_color_value() -> Color:
	var value: Variant = get("signature_color")
	return value if value is Color else Color("00ff88")
