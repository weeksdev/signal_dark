extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const SEARCH_INTEREST_RADIUS := 248.0

@export var signature_color := Color("ffb300")
@export var pulse_range: float = 170.0
@export var pulse_interval: float = 2.5
@export var suppress_range: float = 34.0

var pulse_progress: float = 0.0
var pulse_cooldown: float = 1.0
var ring_visible: bool = false
var _range_t: float = 0.0


func _ready() -> void:
	super._ready()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if tick_support_state(delta):
		queue_redraw()
		return

	_range_t += delta

	tick_alert_state(delta, 0.7)

	if combat_active and is_instance_valid(ship):
		var to_ship: Vector2 = ship.global_position - global_position
		if to_ship != Vector2.ZERO:
			facing_vector = to_ship.normalized()
	else:
		var search_target: Variant = world_search_target_if_relevant(SEARCH_INTEREST_RADIUS)
		if search_target is Vector2:
			var to_search: Vector2 = search_target - global_position
			if to_search != Vector2.ZERO:
				facing_vector = to_search.normalized()

	pulse_cooldown -= delta
	if pulse_cooldown <= 0.0:
		_start_pulse()
		pulse_cooldown = 0.5 if AlertSystem.combat_mode else pulse_interval

	if ring_visible:
		pulse_progress += delta * 2.2
		if pulse_progress >= 1.0:
			ring_visible = false
			pulse_progress = 0.0

	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	pulse_cooldown = 1.0
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


func _current_range() -> float:
	# Compound wave: slow swell (period ~8s) modulated by a medium beat (period ~3s)
	# Results in a recognizable pattern: big → medium → small → medium → big
	var slow: float = 0.5 + 0.5 * sin(_range_t * 0.78)
	var med: float  = 0.5 + 0.5 * sin(_range_t * 2.1 + 0.6)
	var frac: float = slow * 0.65 + med * 0.35
	return pulse_range * 1.5 * (0.40 + 0.60 * frac)


func _start_pulse() -> void:
	ring_visible = true
	pulse_progress = 0.0
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		_suspicion = 0.0
		return
	# Dark pocket masks the player
	if player.in_dark_pocket:
		_suspicion = 0.0
		return
	if should_suppress_detection_of(player):
		_suspicion = 0.0
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance > _current_range():
		return
	var blocked: bool = is_world_line_blocked(global_position, player.global_position, [get_rid()])
	if blocked:
		return
	if player.get_effective_emission() > 0.05 and not player.dark_mode:
		if not _alerting:
			_alerting = true
			detected.emit(self)
		_alert_hold = 3.0
		_suspicion = 1.0
		return
	var speed_ratio: float = clampf(player.velocity.length() / maxf(player.max_speed, 1.0), 0.0, 1.0)
	var risk: float = player.get_effective_emission() * 2.6 + speed_ratio * 0.8
	if player.dark_mode:
		risk *= 0.45
	if world_is_search_active():
		risk *= 1.22
	if risk <= 0.08:
		return
	if add_suspicion(risk * 0.32):
		begin_alert_state(3.0)


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(signature_color, 0.08 if not AlertSystem.combat_mode else 0.14)
	outline.default_color = enemy_state_outline()
	outline.width = 2.2


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	# MGS "!" alert marker
	draw_alert_marker()
	draw_suspicion_arc(26.0)
	draw_emp_disabled_effect(32.0)

	var halo_color := outline.default_color
	draw_circle(Vector2.ZERO, 20.0, Color(halo_color.r, halo_color.g, halo_color.b, 0.035 if not AlertSystem.combat_mode else 0.04))

	# Breathing danger ring — shows current effective detection radius
	var cur_range: float = _current_range()
	var range_frac: float = cur_range / pulse_range
	var indicator_color := outline.default_color
	draw_arc(Vector2.ZERO, cur_range, 0.0, TAU, 48,
			Color(indicator_color.r, indicator_color.g, indicator_color.b, 0.10 + 0.12 * range_frac), 1.2)

	if not ring_visible:
		return
	var ring_color := outline.default_color
	ring_color.a = 0.42 if not AlertSystem.combat_mode else 0.7
	draw_arc(Vector2.ZERO, cur_range * pulse_progress, 0.0, TAU, 64, ring_color, 3.0)
	draw_arc(Vector2.ZERO, cur_range * pulse_progress * 0.82, 0.0, TAU, 64, Color(ring_color.r, ring_color.g, ring_color.b, 0.1), 1.0)
	var star := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(3.0, -3.0),
		Vector2(10.0, 0.0),
		Vector2(3.0, 3.0),
		Vector2(0.0, 10.0),
		Vector2(-3.0, 3.0),
		Vector2(-10.0, 0.0),
		Vector2(-3.0, -3.0),
		Vector2(0.0, -10.0)
	])
	draw_polyline(star, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.68), 1.2)
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, marker, 1.2)
	draw_emp_disabled_effect(32.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
