extends CharacterBody2D
class_name BaseEnemy

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("00ff88")
@export var combat_speed: float = 140.0
@export var suppress_range: float = 34.0

var is_alive: bool = true
var combat_active: bool = false
var facing_vector: Vector2 = Vector2.UP
var ship: Node2D = null

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
		var chase_vector: Vector2 = ship.global_position - global_position
		if chase_vector != Vector2.ZERO:
			facing_vector = chase_vector.normalized()
			velocity = facing_vector * combat_speed
		move_and_slide()
		if global_position.distance_to(ship.global_position) < 18.0:
			ship.take_hit()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true


func can_be_suppressed_by(ship_node: Node) -> bool:
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
	killed.emit(self, silent)
	queue_free()


func emit_detection() -> void:
	if not is_alive:
		return
	detected.emit(self)


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	outline.default_color = ColorSystem.enemy_outline()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()
