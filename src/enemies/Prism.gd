extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const ALERT_HOLD_SECONDS := 2.8
const SEARCH_INTEREST_RADIUS := 255.0

@export var signature_color := Color("7df9ff")
@export var beam_range: float = 230.0
@export var beam_width: float = 11.0
@export var rotate_speed: float = 0.72
@export var combat_rotate_speed: float = 1.6
@export var suppress_range: float = 30.0

var facing_angle: float = 0.0


func _ready() -> void:
	super._ready()
	facing_angle = randf() * TAU


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if tick_support_state(delta):
		queue_redraw()
		return

	var spin_speed := combat_rotate_speed if combat_active else rotate_speed
	facing_angle = wrapf(facing_angle + delta * spin_speed, 0.0, TAU)
	if not combat_active:
		var search_target: Variant = world_search_target_if_relevant(SEARCH_INTEREST_RADIUS)
		if search_target is Vector2:
			var to_search: Vector2 = search_target - global_position
			if to_search != Vector2.ZERO:
				facing_angle = lerp_angle(facing_angle, to_search.angle(), delta * 1.3)

	tick_alert_state(delta, 0.7)

	if not combat_active:
		_check_detection()

	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
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


func _check_detection() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		_suspicion = 0.0
		return
	if player.in_dark_pocket:
		_suspicion = 0.0
		return
	if should_suppress_detection_of(player):
		_suspicion = 0.0
		return

	var emission: float = player.get_effective_emission()
	var speed_ratio: float = clampf(player.velocity.length() / maxf(player.max_speed, 1.0), 0.0, 1.0)
	if emission <= 0.018 and speed_ratio < 0.22:
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > beam_range + beam_width:
		return

	var blocked: bool = is_world_line_blocked(global_position, player.global_position, [get_rid()])
	if blocked:
		return

	for beam_dir in _beam_directions():
		var along := to_player.dot(beam_dir)
		if along < 0.0 or along > beam_range:
			continue
		var perpendicular := absf(to_player.cross(beam_dir))
		var tolerance := beam_width + (10.0 if player.dark_mode else 14.0)
		if perpendicular <= tolerance:
			if emission > 0.05 and not player.dark_mode:
				_begin_alert()
				return
			var risk: float = emission * 2.8 + speed_ratio * 0.95
			if player.dark_mode:
				risk *= 0.5
			if world_is_search_active():
				risk *= 1.2
			if distance < 36.0:
				risk += 0.4
			if risk <= 0.06:
				continue
			if add_suspicion(risk * 0.08):
				_begin_alert()
			return


func _beam_directions() -> Array[Vector2]:
	return [
		Vector2.RIGHT.rotated(facing_angle),
		Vector2.RIGHT.rotated(facing_angle + TAU / 3.0),
		Vector2.RIGHT.rotated(facing_angle + TAU * 2.0 / 3.0),
	]


func _begin_alert() -> void:
	begin_alert_state(ALERT_HOLD_SECONDS)


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(signature_color, 0.07 if not AlertSystem.combat_mode else 0.13)
	outline.default_color = enemy_state_outline()
	outline.width = 2.2


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var beam_color := outline.default_color
	var halo_alpha := 0.06 if not AlertSystem.combat_mode else 0.1
	draw_circle(Vector2.ZERO, 18.0, Color(beam_color.r, beam_color.g, beam_color.b, halo_alpha))

	for beam_dir in _beam_directions():
		var end := beam_dir * beam_range
		var alpha := 0.24 if not combat_active else 0.42
		draw_line(Vector2.ZERO, end, Color(beam_color.r, beam_color.g, beam_color.b, alpha), 2.2)
		draw_line(Vector2.ZERO, end * 0.85, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.18), beam_width)

	draw_polyline(PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(8.0, 0.0),
		Vector2(0.0, 12.0),
		Vector2(-8.0, 0.0),
		Vector2(0.0, -12.0)
	]), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.76), 1.4)

	draw_alert_marker()
	draw_suspicion_arc(25.0)

	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 24, marker, 1.2)
	draw_emp_disabled_effect(32.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
