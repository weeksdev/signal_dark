extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("00ff88")
@export var detection_range: float = 225.0
@export var cone_angle_degrees: float = 65.0
@export var patrol_speed: float = 60.0
@export var combat_speed: float = 140.0
@export var suppress_range: float = 34.0

const ARRIVE_DIST      := 14.0
const DWELL_TIME       := 0.55
const PULSE_SPEED      := 115.0
const PULSE_TOLERANCE  := 13.0
const ALERT_HOLD_SECONDS := 3.0

# Rhythm: single pulse, then two quick, then long gap — repeating
const PULSE_PATTERN: Array[float] = [1.3, 0.38, 0.38, 2.1]

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null

var _waypoints: Array[Vector2] = []
var _wp_index: int = 0
var _dwell: float = 0.0
var _alerting: bool = false
var _alert_hold: float = 0.0

var _pulses: Array[float] = []
var _pulse_timer: float = 0.3
var _pulse_idx: int = 0

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline
@onready var patrol_a: Marker2D = $PatrolA
@onready var patrol_b: Marker2D = $PatrolB


func _ready() -> void:
	add_to_group("zone_enemy")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()
	_waypoints = [patrol_a.global_position, patrol_b.global_position]
	_wp_index = 0


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if _alert_hold > 0.0:
		_alert_hold -= delta
		if _alert_hold <= 0.0:
			_alerting = false

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
		if global_position.distance_to(ship.global_position) < 18.0:
			ship.take_hit()
	else:
		_run_patrol(delta)
		_check_detection()

	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true
	_pulses.clear()


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO
	_pulses.clear()
	_pulse_timer = PULSE_PATTERN[0]
	_pulse_idx = 0
	_alerting = false
	_alert_hold = 0.0


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
		velocity = Vector2.ZERO
		return

	var target: Vector2 = _waypoints[_wp_index]
	if get_tree().current_scene.has_method("has_active_probe") and get_tree().current_scene.has_active_probe():
		target = get_tree().current_scene.get_probe_target()

	var offset: Vector2 = target - global_position
	if offset.length() > ARRIVE_DIST:
		facing_vector = offset.normalized()
		velocity = facing_vector * patrol_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_wp_index = 1 - _wp_index
		_dwell = DWELL_TIME


func _check_detection() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	var emission: float = player.get_effective_emission()

	# Dark pocket completely masks the player beyond contact range
	if player.in_dark_pocket and distance > 28.0:
		return

	# Contact range — always triggers
	if distance < 22.0 and emission > 0.015:
		_begin_alert_hold()
		return

	# Cone arc check
	if facing_vector.dot(to_player.normalized()) < cos(deg_to_rad(cone_angle_degrees * 0.5)):
		return

	# Line of sight
	if get_tree().current_scene.is_line_blocked(global_position, player.global_position, [get_rid()]):
		return

	# Pulse arc hit
	var hit := false
	for pulse_r: float in _pulses:
		if abs(distance - pulse_r) < PULSE_TOLERANCE:
			if emission > 0.05 or distance < 40.0:
				hit = true
				break

	if hit:
		_begin_alert_hold()


func _begin_alert_hold() -> void:
	if not _alerting:
		_alerting = true
		detected.emit(self)
	_alert_hold = ALERT_HOLD_SECONDS


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.08 if not AlertSystem.combat_mode else 0.14
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.4


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var halo_color := ColorSystem.glow_color()
	draw_circle(Vector2.ZERO, 20.0, Color(halo_color.r, halo_color.g, halo_color.b, 0.05))

	var cone_color := ColorSystem.enemy_outline()
	var half_rad := deg_to_rad(cone_angle_degrees * 0.5)
	var start_angle := facing_vector.angle() - half_rad
	var end_angle   := facing_vector.angle() + half_rad

	# Expanding pulse arcs — brightest at origin, fade toward max range
	for pulse_r: float in _pulses:
		var fade := 1.0 - (pulse_r / detection_range)
		var arc_col := Color(cone_color.r, cone_color.g, cone_color.b, 0.70 * fade)
		draw_arc(Vector2.ZERO, pulse_r, start_angle, end_angle, 32, arc_col, 2.4)
		# Soft echo trail behind the arc
		if pulse_r > 10.0:
			draw_arc(Vector2.ZERO, pulse_r - 7.0, start_angle, end_angle, 24,
					Color(cone_color.r, cone_color.g, cone_color.b, 0.18 * fade), 1.2)

	# Plus / targeting reticle at center
	var arm := 9.0
	var gap := 2.5
	var mc := Color(cone_color.r, cone_color.g, cone_color.b, 0.78)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, -gap), mc, 2.2)
	draw_line(Vector2(0.0,  gap), Vector2(0.0,  arm), mc, 2.2)
	draw_line(Vector2(-arm, 0.0), Vector2(-gap, 0.0), mc, 2.2)
	draw_line(Vector2( gap, 0.0), Vector2( arm, 0.0), mc, 2.2)
	draw_arc(Vector2.ZERO, gap, 0.0, TAU, 16, Color(mc.r, mc.g, mc.b, 0.5), 1.2)

	# MGS-style "!" alert marker
	if _alerting and not combat_active:
		var t_ms: float = Time.get_ticks_msec() / 1000.0
		var pulse: float = 0.75 + 0.25 * sin(t_ms * 14.0)
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(0.0, 0.0, 0.0, 0.75), true)
		draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(1.0, 0.85, 0.0, pulse * 0.9), false, 1.5)
		draw_string(font, Vector2(-5.0, -36.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				Color(1.0, 0.90, 0.0, pulse))

	# Suppress indicator
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, marker, 1.2)
		draw_line(Vector2(-14.0, -14.0), Vector2(-6.0, -14.0), marker, 1.8)
		draw_line(Vector2(-14.0, -14.0), Vector2(-14.0, -6.0), marker, 1.8)
		draw_line(Vector2(14.0, 14.0), Vector2(6.0, 14.0), marker, 1.8)
		draw_line(Vector2(14.0, 14.0), Vector2(14.0, 6.0), marker, 1.8)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
