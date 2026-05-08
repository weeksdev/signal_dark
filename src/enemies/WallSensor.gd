extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

@export var signature_color := Color("ffd95a")
@export var sensor_depth: float = 86.0
@export var sensor_width: float = 54.0
@export var immediate_alert_depth: float = 16.0
@export var suppress_range: float = 0.0

const SUSPICION_DECAY := 0.58
const ALERT_HOLD_SECONDS := 2.35


func _ready() -> void:
	super._ready()
	facing_vector = Vector2.RIGHT.rotated(rotation).normalized()


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
	if combat_active:
		queue_redraw()
		return
	_check_detection()
	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	clear_alert_state()


func can_be_suppressed_by(_ship_node: Node2D) -> bool:
	return false


func take_damage(silent: bool, _hit_origin: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	is_alive = false
	_spawn_burst(silent)
	killed.emit(self, silent)
	queue_free()


func _check_detection() -> void:
	var player := get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	if player.in_dark_pocket:
		_suspicion = 0.0
		return
	if should_suppress_detection_of(player):
		_suspicion = 0.0
		return
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		_suspicion = 0.0
		return

	var local_player := to_local(player.global_position)
	var half_width := sensor_width * 0.5
	if local_player.x < 0.0 or local_player.x > sensor_depth:
		return
	if absf(local_player.y) > half_width:
		return
	if is_world_line_blocked(global_position, player.global_position, [get_rid()]):
		return

	var normalized_depth := 1.0 - (local_player.x / maxf(sensor_depth, 1.0))
	var local_velocity: Vector2 = player.velocity.rotated(-rotation)
	var parallel_speed := clampf(absf(local_velocity.y) / maxf(player.max_speed, 1.0), 0.0, 1.0)
	var risk: float = normalized_depth * (0.18 + parallel_speed * 0.82 + player.get_effective_emission() * 2.0)
	if player.dark_mode:
		risk *= 0.7
	if world_is_search_active():
		risk *= 1.08

	if local_player.x <= immediate_alert_depth and risk > 0.18:
		_begin_alert()
		return
	if add_suspicion(risk * 0.016):
		_begin_alert()


func _begin_alert() -> void:
	begin_alert_state(ALERT_HOLD_SECONDS)


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(signature_color, 0.06 if not AlertSystem.combat_mode else 0.12)
	outline.default_color = enemy_state_outline()
	outline.width = 1.05
	_sync_visual_overlays()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var c := outline.default_color
	var field_alpha := 0.04 if not combat_active else 0.08
	draw_rect(Rect2(0.0, -sensor_width * 0.5, sensor_depth, sensor_width), Color(c.r, c.g, c.b, field_alpha), true)
	draw_line(Vector2.ZERO, Vector2(sensor_depth, 0.0), Color(c.r, c.g, c.b, 0.22), 0.8)
	draw_line(Vector2(0.0, -sensor_width * 0.5), Vector2(sensor_depth, -sensor_width * 0.5), Color(c.r, c.g, c.b, 0.12), 0.5)
	draw_line(Vector2(0.0, sensor_width * 0.5), Vector2(sensor_depth, sensor_width * 0.5), Color(c.r, c.g, c.b, 0.12), 0.5)
	draw_circle(Vector2.ZERO, 18.0, Color(c.r, c.g, c.b, 0.05))
	draw_alert_marker()
	draw_suspicion_arc(24.0)
	draw_emp_disabled_effect(28.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
