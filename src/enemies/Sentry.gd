extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("32d2ff")
@export var suppress_range: float = 30.0
@export var attack_range: float = 320.0
@export var fire_interval: float = 1.2
@export var bolt_scene: PackedScene

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null
var cooldown: float = 0.8

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	var player = ship if ship != null else get_tree().get_first_node_in_group("player_ship")
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		if to_player != Vector2.ZERO:
			facing_vector = to_player.normalized()
	if combat_active and player != null and cooldown <= 0.0:
		var distance: float = global_position.distance_to(player.global_position)
		var blocked: bool = get_tree().current_scene.is_line_blocked(global_position, player.global_position, [get_rid()])
		if distance <= attack_range and not blocked:
			_fire_at(player.global_position)
			cooldown = fire_interval
	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	cooldown = 0.8


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


func _fire_at(target: Vector2) -> void:
	if bolt_scene == null:
		return
	var bolt = bolt_scene.instantiate()
	var direction: Vector2 = (target - global_position).normalized()
	bolt.global_position = global_position + direction * 16.0
	bolt.direction = direction
	bolt.tint = Color("b8fff8") if AlertSystem.combat_mode else Color("5ba57d")
	get_tree().current_scene.add_child(bolt)


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.06 if not AlertSystem.combat_mode else 0.12
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.2


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.04))
	draw_line(Vector2.ZERO, facing_vector * 26.0, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.35), 2.0)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.7), 1.2)
	draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.45), 1.0)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.45), 1.0)
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, marker, 1.1)
	if not combat_active:
		return
	draw_arc(Vector2.ZERO, attack_range, facing_vector.angle() - 0.28, facing_vector.angle() + 0.28, 18, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.08), 1.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
