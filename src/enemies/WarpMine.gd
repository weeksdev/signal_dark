extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const HUNTER_SCENE := preload("res://src/enemies/Hunter.tscn")
const WISP_SCENE := preload("res://src/enemies/Wisp.tscn")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("ff5a36")
@export var trigger_radius: float = 160.0
@export var arm_time: float = 0.8
@export var suppress_range: float = 24.0
@export var payload_kind: String = "hunter"
@export var payload_count: int = 2
@export var blast_radius: float = 48.0

var is_alive: bool = true
var combat_active: bool = false
var ship: Node2D = null
var _arming: bool = false
var _armed_time: float = 0.0
var _alerting: bool = false
var _emp_disabled_timer: float = 0.0

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _tick_emp_disabled(delta):
		queue_redraw()
		return

	if _arming:
		_armed_time -= delta
		if _armed_time <= 0.0:
			_deploy_payload()
		queue_redraw()
		return

	var player := ship if ship != null else get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	var world := get_tree().current_scene
	if world != null and world.has_method("should_suppress_enemy_detection"):
		if world.should_suppress_enemy_detection(self, player):
			return
	if player.in_dark_pocket and not combat_active:
		return

	var distance := global_position.distance_to(player.global_position)
	var threshold := trigger_radius * (1.25 if combat_active else 1.0)
	if distance > threshold:
		return
	if not combat_active and player.get_effective_emission() <= 0.035:
		return
	_start_arming()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true
	if global_position.distance_to(target_ship.global_position) <= trigger_radius * 1.25:
		_start_arming()


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	_arming = false
	_armed_time = 0.0
	_alerting = false
	_update_palette()
	queue_redraw()


func stealth_reveal_level() -> float:
	if combat_active or _emp_disabled_timer > 0.0:
		return 0.0
	return 1.0 if _alerting else 0.0


func is_valid_auto_fire_target(_from_point: Vector2) -> bool:
	return is_alive and _emp_disabled_timer <= 0.0


func is_combat_targetable() -> bool:
	return is_alive


func can_be_suppressed_by(ship_node: Node2D) -> bool:
	if not is_alive or combat_active or _arming:
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


func _start_arming() -> void:
	if _emp_disabled_timer > 0.0:
		return
	if _arming:
		return
	_arming = true
	_armed_time = arm_time
	if not _alerting:
		_alerting = true
		detected.emit(self)


func apply_emp_disable(duration: float) -> void:
	_emp_disabled_timer = maxf(_emp_disabled_timer, duration)
	_arming = false
	_armed_time = 0.0
	_alerting = false
	velocity = Vector2.ZERO
	queue_redraw()


func is_emp_disabled() -> bool:
	return _emp_disabled_timer > 0.0


func _tick_emp_disabled(delta: float) -> bool:
	if _emp_disabled_timer <= 0.0:
		return false
	_emp_disabled_timer = maxf(0.0, _emp_disabled_timer - delta)
	return _emp_disabled_timer > 0.0


func _deploy_payload() -> void:
	if not is_alive:
		return
	var spawn_markers := _spawn_markers()
	var player := ship if ship != null else get_tree().get_first_node_in_group("player_ship")
	var spawned := 0
	for marker in spawn_markers:
		if spawned >= payload_count:
			break
		var enemy := _instantiate_payload()
		if enemy == null:
			continue
		enemy.global_position = marker.global_position
		_register_spawned_enemy(enemy)
		spawned += 1

	if player != null and global_position.distance_to(player.global_position) <= blast_radius:
		player.take_hit()

	is_alive = false
	_spawn_burst(false)
	queue_free()


func _spawn_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		if not marker.name.begins_with("Spawn"):
			continue
		markers.append(marker)
	return markers


func _instantiate_payload() -> Node:
	match payload_kind:
		"wisp":
			return WISP_SCENE.instantiate()
		_:
			return HUNTER_SCENE.instantiate()


func _register_spawned_enemy(enemy: Node) -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("register_spawned_enemy"):
		world.register_spawned_enemy(enemy)
		return
	world.add_child(enemy)


func _update_palette() -> void:
	if _emp_disabled_timer > 0.0:
		body_polygon.color = Color(0.18, 0.55, 0.72, 0.12)
		outline.default_color = Color(0.55, 0.95, 1.0, 0.95)
	elif _alerting and not combat_active:
		body_polygon.color = Color(0.72, 0.04, 0.02, 0.18)
		outline.default_color = Color(1.0, 0.12, 0.08, 0.95)
	else:
		body_polygon.color = ColorSystem.enemy_fill(signature_color)
		body_polygon.color.a = 0.07 if not AlertSystem.combat_mode else 0.13
		outline.default_color = ColorSystem.enemy_outline()
		if combat_active:
			var pulse_color := _combat_pulse_color()
			body_polygon.color = Color(pulse_color.r * 0.55, pulse_color.g * 0.34, pulse_color.b * 0.08, 0.2)
			outline.default_color = Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.98)
	outline.width = 2.1


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var c := outline.default_color
	draw_circle(Vector2.ZERO, 16.0, Color(c.r, c.g, c.b, 0.06))
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 42, Color(c.r, c.g, c.b, 0.08), 1.0)

	if _arming:
		var progress := 1.0 - (_armed_time / arm_time)
		var flash := 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 70.0))
		draw_arc(Vector2.ZERO, 18.0 + progress * 20.0, 0.0, TAU, 28, Color(1.0, 0.45, 0.2, flash), 2.2)
		draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.6, 0.3, 0.65))
	if _emp_disabled_timer > 0.0:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 58.0)
		var emp := Color(0.55, 0.95, 1.0, 0.5 + pulse * 0.25)
		draw_arc(Vector2.ZERO, 28.0, 0.15, TAU * 0.62, 22, emp, 2.0)
		draw_line(Vector2(-12.0, -7.0), Vector2(12.0, 8.0), emp, 1.4)

	draw_polyline(PackedVector2Array([
		Vector2(0.0, -11.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 11.0),
		Vector2(-10.0, 0.0),
		Vector2(0.0, -11.0)
	]), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.76), 1.2)

	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, marker, 1.1)


func _combat_pulse_color() -> Color:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	return Color(1.0, lerpf(0.12, 0.86, pulse), 0.03, 1.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
