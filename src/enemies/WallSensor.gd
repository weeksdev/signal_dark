extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

@export var signature_color := Color("ffd95a")
@export var sensor_depth: float = 86.0
@export var sensor_width: float = 54.0
@export var immediate_alert_depth: float = 48.0
@export var suppress_range: float = 0.0

const SUSPICION_DECAY  := 0.58
const ALERT_HOLD_SECONDS := 2.35

const EXTEND_DIST      := 48.0
const EXTEND_DURATION  := 0.35
const SPIN_DURATION    := 0.28
const RETRACT_DURATION := 0.45

enum SensorState { DOCKED, EXTENDING, SPINNING, RETRACTING }

var _state            := SensorState.DOCKED
var _state_t          := 0.0
var _dock_global_pos  := Vector2.ZERO
var _extended_global_pos := Vector2.ZERO
var _dock_rotation    := 0.0


func _ready() -> void:
	super._ready()
	facing_vector = Vector2.RIGHT.rotated(rotation).normalized()
	_dock_global_pos = global_position
	_dock_rotation   = rotation


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
	_update_sensor_state(delta)
	if not combat_active and _state == SensorState.DOCKED:
		_check_detection()
	queue_redraw()


func _update_sensor_state(delta: float) -> void:
	match _state:
		SensorState.DOCKED:
			pass
		SensorState.EXTENDING:
			_state_t = minf(_state_t + delta / EXTEND_DURATION, 1.0)
			global_position = _dock_global_pos.lerp(_extended_global_pos, ease(_state_t, -2.0))
			if _state_t >= 1.0:
				_state  = SensorState.SPINNING
				_state_t = 0.0
		SensorState.SPINNING:
			_state_t = minf(_state_t + delta / SPIN_DURATION, 1.0)
			rotation = _dock_rotation + TAU * _state_t
			if _state_t >= 1.0:
				rotation = _dock_rotation
				_state  = SensorState.RETRACTING
				_state_t = 0.0
		SensorState.RETRACTING:
			_state_t = minf(_state_t + delta / RETRACT_DURATION, 1.0)
			global_position = _extended_global_pos.lerp(_dock_global_pos, ease(_state_t, -2.0))
			if _state_t >= 1.0:
				global_position = _dock_global_pos
				_state  = SensorState.DOCKED
				_state_t = 0.0


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
	# Risk is uniform across the full beam length — no depth dampening so the
	# tip triggers just as reliably as the base.
	var local_velocity: Vector2 = player.velocity.rotated(-rotation)
	var crossing_speed := clampf(absf(local_velocity.y) / maxf(player.max_speed, 1.0), 0.0, 1.0)
	var risk: float = 0.15 + crossing_speed * 0.85 + player.get_effective_emission() * 2.0
	if player.dark_mode:
		risk *= 0.7
	if world_is_search_active():
		risk *= 1.08

	if local_player.x <= immediate_alert_depth and risk > 0.18:
		_begin_alert()
		return
	if add_suspicion(risk * 0.045):
		_begin_alert()


func _begin_alert() -> void:
	begin_alert_state(ALERT_HOLD_SECONDS)
	if _state == SensorState.DOCKED:
		_state   = SensorState.EXTENDING
		_state_t = 0.0
		_extended_global_pos = _dock_global_pos + facing_vector * EXTEND_DIST


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
