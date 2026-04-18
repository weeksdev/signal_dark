extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("00ff88")
@export var detection_range: float = 150.0
@export var cone_angle_degrees: float = 65.0
@export var patrol_speed: float = 60.0
@export var combat_speed: float = 140.0
@export var suppress_range: float = 34.0

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var patrol_target: Node2D = null

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline
@onready var patrol_a: Marker2D = $PatrolA
@onready var patrol_b: Marker2D = $PatrolB


func _ready() -> void:
	add_to_group("zone_enemy")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()
	patrol_target = patrol_b


func _physics_process(_delta: float) -> void:
	if not is_alive:
		return

	if combat_active and is_instance_valid(ship):
		var chase_vector: Vector2 = ship.global_position - global_position
		if chase_vector != Vector2.ZERO:
			facing_vector = chase_vector.normalized()
			velocity = facing_vector * combat_speed
		move_and_slide()
		if global_position.distance_to(ship.global_position) < 18.0:
			ship.take_hit()
	else:
		_run_patrol()
		_check_detection()

	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO


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


func _run_patrol() -> void:
	var target_position: Vector2 = patrol_target.global_position
	if get_tree().current_scene.has_method("has_active_probe") and get_tree().current_scene.has_active_probe():
		target_position = get_tree().current_scene.get_probe_target()
	var offset: Vector2 = target_position - global_position
	if offset.length() > 4.0:
		facing_vector = offset.normalized()
		velocity = facing_vector * patrol_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		patrol_target = patrol_b if patrol_target == patrol_a else patrol_a


func _check_detection() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > detection_range:
		return
	var direction: Vector2 = to_player.normalized()
	var angle_ok: bool = facing_vector.dot(direction) >= cos(deg_to_rad(cone_angle_degrees * 0.5))
	if not angle_ok:
		return
	var blocked: bool = get_tree().current_scene.is_line_blocked(global_position, player.global_position, [get_rid()])
	if blocked:
		return
	var detection_score: float = player.get_effective_emission() * (1.2 - distance / detection_range)
	if detection_score >= 0.12 or (player.get_effective_emission() > 0.015 and distance < 26.0):
		detected.emit(self)


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.08 if not AlertSystem.combat_mode else 0.14
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.4


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var halo_color := ColorSystem.glow_color()
	var halo_alpha := 0.05 if not AlertSystem.combat_mode else 0.05
	draw_circle(Vector2.ZERO, 20.0, Color(halo_color.r, halo_color.g, halo_color.b, halo_alpha))
	var cone_color := ColorSystem.enemy_outline()
	cone_color.a = 0.16 if not AlertSystem.combat_mode else 0.08
	var start_angle := facing_vector.angle() - deg_to_rad(cone_angle_degrees * 0.5)
	var end_angle := facing_vector.angle() + deg_to_rad(cone_angle_degrees * 0.5)
	var left := facing_vector.rotated(-deg_to_rad(cone_angle_degrees * 0.5)) * detection_range
	var right := facing_vector.rotated(deg_to_rad(cone_angle_degrees * 0.5)) * detection_range
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, left, right]), Color(cone_color.r, cone_color.g, cone_color.b, 0.035 if not AlertSystem.combat_mode else 0.03))
	draw_arc(Vector2.ZERO, detection_range, start_angle, end_angle, 24, cone_color, 2.0)
	draw_line(Vector2.ZERO, left, cone_color, 1.0)
	draw_line(Vector2.ZERO, right, cone_color, 1.0)
	draw_line(left * 0.3, right * 0.3, Color(cone_color.r, cone_color.g, cone_color.b, 0.1), 1.0)
	var inner := PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(8.0, -4.0),
		Vector2(8.0, 4.0),
		Vector2(0.0, 9.0),
		Vector2(-8.0, 4.0),
		Vector2(-8.0, -4.0),
		Vector2(0.0, -9.0)
	])
	draw_polyline(inner, Color(cone_color.r, cone_color.g, cone_color.b, 0.7), 1.2)
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
