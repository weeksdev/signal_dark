extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("ff2d55")
@export var roam_speed: float = 58.0
@export var combat_speed: float = 180.0
@export var suppress_range: float = 0.0

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var drift_phase: float = 0.0
var spawn_point: Vector2 = Vector2.ZERO
@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	spawn_point = global_position
	drift_phase = randf() * TAU
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if combat_active and is_instance_valid(ship):
		var to_ship: Vector2 = ship.global_position - global_position
		if to_ship != Vector2.ZERO:
			facing_vector = to_ship.normalized()
			velocity = facing_vector * combat_speed
		move_and_slide()
	else:
		drift_phase += delta
		var roam_target := spawn_point + Vector2(cos(drift_phase * 0.9), sin(drift_phase * 1.3)) * 42.0
		var offset: Vector2 = roam_target - global_position
		if offset.length() > 3.0:
			facing_vector = offset.normalized()
			velocity = facing_vector * roam_speed
			move_and_slide()
	_emit_contact_hit()
	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO


func can_be_suppressed_by(_ship_node: Node2D) -> bool:
	return false


func take_damage(silent: bool, _hit_origin: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	is_alive = false
	_spawn_burst(silent)
	killed.emit(self, silent)
	queue_free()


func _emit_contact_hit() -> void:
	var target = ship if ship != null else get_tree().get_first_node_in_group("player_ship")
	if target != null and global_position.distance_to(target.global_position) <= 18.0:
		target.take_hit()


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.06 if not AlertSystem.combat_mode else 0.12
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.4


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var halo := signature_color if AlertSystem.combat_mode else ColorSystem.glow_color()
	draw_circle(Vector2.ZERO, 16.0, Color(halo.r, halo.g, halo.b, 0.08))
	draw_line(Vector2.ZERO, facing_vector * 18.0, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.35), 2.0)
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(5.0, 0.0),
		Vector2(0.0, 9.0),
		Vector2(-5.0, 0.0),
		Vector2(0.0, -9.0)
	]), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.7), 1.2)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
