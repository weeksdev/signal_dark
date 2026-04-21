extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const ALERT_HOLD_SECONDS := 2.4

@export var signature_color := Color("bf5af2")
@export var patrol_radius: float = 90.0
@export var patrol_speed: float = 72.0
@export var combat_speed: float = 110.0
@export var suppress_range: float = 28.0
@export var alert_radius: float = 36.0
@export var search_interest_radius: float = 124.0

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


func _ready() -> void:
	super._ready()
	anchor = global_position
	phase = randf() * TAU
	if use_route_patrol and patrol_points.is_empty() and route_a != route_b:
		patrol_points = [route_a, route_b]


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
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
			velocity = Vector2.ZERO
		elif offset.length() > 2.0:
			facing_vector = offset.normalized()
			velocity = facing_vector * patrol_speed
			move_and_slide()
			_push_out_of_dark_pockets()
			if get_slide_collision_count() > 0:
				if use_route_patrol:
					_advance_route()
				phase += 1.25
				velocity = Vector2.ZERO
		elif use_route_patrol:
			_advance_route()
		_check_alert_radius()
	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO
	clear_alert_state()


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
	if world_is_search_active():
		var search_target: Vector2 = world_search_target()
		if global_position.distance_to(search_target) <= search_interest_radius:
			return safe_enemy_target(search_target)
	return roam_target


func _advance_route() -> void:
	if patrol_points.size() >= 2:
		_patrol_index = posmod(_patrol_index + patrol_step, patrol_points.size())
	else:
		patrol_step *= -1
	_route_pause = 0.3 if _patrol_index in choke_indices else 0.16


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.05 if not AlertSystem.combat_mode else 0.12
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.1


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var tint := signature_color if AlertSystem.combat_mode else ColorSystem.enemy_outline()
	draw_circle(Vector2.ZERO, 58.0, Color(tint.r, tint.g, tint.b, 0.045))
	draw_circle(Vector2.ZERO, 42.0, Color(tint.r, tint.g, tint.b, 0.075))
	draw_circle(Vector2.ZERO, 29.0, Color(tint.r, tint.g, tint.b, 0.11))
	draw_circle(Vector2.ZERO, 18.0, Color(tint.r, tint.g, tint.b, 0.085))
	if not combat_active:
		draw_circle(Vector2.ZERO, alert_radius + 18.0, Color(tint.r, tint.g, tint.b, 0.06))
		draw_circle(Vector2.ZERO, alert_radius + 8.0, Color(tint.r, tint.g, tint.b, 0.08))
		draw_circle(Vector2.ZERO, alert_radius, Color(tint.r, tint.g, tint.b, 0.10))
		draw_arc(Vector2.ZERO, alert_radius, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.52), 2.2)
		draw_arc(Vector2.ZERO, alert_radius * 0.7, 0.0, TAU, 28, Color(tint.r, tint.g, tint.b, 0.28), 1.4)
	var whisker := Vector2(0.0, -20.0).rotated(phase * 2.0)
	draw_line(Vector2.ZERO, whisker, Color(tint.r, tint.g, tint.b, 0.28), 1.5)
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
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, marker, 1.1)
	draw_alert_marker()
	draw_emp_disabled_effect(34.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
