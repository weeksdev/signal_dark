extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("ffb300")
@export var pulse_range: float = 170.0
@export var pulse_interval: float = 2.5
@export var suppress_range: float = 34.0

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var pulse_progress: float = 0.0
var pulse_cooldown: float = 1.0
var ring_visible: bool = false

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if combat_active and is_instance_valid(ship):
		var to_ship: Vector2 = ship.global_position - global_position
		if to_ship != Vector2.ZERO:
			facing_vector = to_ship.normalized()

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
	ship = target_ship
	combat_active = true


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	pulse_cooldown = 1.0


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


func _start_pulse() -> void:
	ring_visible = true
	pulse_progress = 0.0
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance > pulse_range:
		return
	var blocked: bool = get_tree().current_scene.is_line_blocked(global_position, player.global_position, [get_rid()])
	if blocked:
		return
	if player.get_effective_emission() > 0.05 and not player.dark_mode:
		detected.emit(self)


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.08 if not AlertSystem.combat_mode else 0.14
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.2


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var halo_color := ColorSystem.glow_color()
	draw_circle(Vector2.ZERO, 20.0, Color(halo_color.r, halo_color.g, halo_color.b, 0.035 if not AlertSystem.combat_mode else 0.04))
	if not ring_visible:
		return
	var ring_color := signature_color if AlertSystem.combat_mode else ColorSystem.enemy_outline()
	ring_color.a = 0.42 if not AlertSystem.combat_mode else 0.7
	draw_arc(Vector2.ZERO, pulse_range * pulse_progress, 0.0, TAU, 64, ring_color, 3.0)
	draw_arc(Vector2.ZERO, pulse_range * pulse_progress * 0.82, 0.0, TAU, 64, Color(ring_color.r, ring_color.g, ring_color.b, 0.1), 1.0)
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


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
