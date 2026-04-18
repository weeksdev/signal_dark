extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("bf5af2")
@export var patrol_radius: float = 90.0
@export var patrol_speed: float = 72.0
@export var combat_speed: float = 110.0
@export var suppress_range: float = 28.0

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var anchor: Vector2 = Vector2.ZERO
var phase: float = 0.0

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	anchor = global_position
	phase = randf() * TAU
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	phase += delta
	if combat_active and ship != null:
		var to_ship: Vector2 = ship.global_position - global_position
		var tangent: Vector2 = Vector2(-to_ship.y, to_ship.x).normalized()
		var desired: Vector2 = to_ship.normalized() * combat_speed * 0.7 + tangent * combat_speed * 0.45
		if desired != Vector2.ZERO:
			facing_vector = desired.normalized()
			velocity = desired
			move_and_slide()
	else:
		var roam_target := anchor + Vector2(cos(phase * 0.8), sin(phase * 1.1)) * patrol_radius
		var offset: Vector2 = roam_target - global_position
		if offset.length() > 2.0:
			facing_vector = offset.normalized()
			velocity = facing_vector * patrol_speed
			move_and_slide()
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
	return ship_node.global_position.distance_to(global_position) <= suppress_range


func take_damage(silent: bool, _hit_origin: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	is_alive = false
	_spawn_burst(silent)
	killed.emit(self, silent)
	queue_free()


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.05 if not AlertSystem.combat_mode else 0.12
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.1


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var tint := signature_color if AlertSystem.combat_mode else ColorSystem.enemy_outline()
	draw_circle(Vector2.ZERO, 15.0, Color(tint.r, tint.g, tint.b, 0.04))
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


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
