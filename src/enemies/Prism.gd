extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const ALERT_HOLD_SECONDS := 2.8

signal detected(enemy: Node)
signal killed(enemy: Node, silent: bool)

@export var signature_color := Color("7df9ff")
@export var beam_range: float = 230.0
@export var beam_width: float = 11.0
@export var rotate_speed: float = 0.72
@export var combat_rotate_speed: float = 1.6
@export var suppress_range: float = 30.0

var is_alive: bool = true
var combat_active: bool = false
var ship: Node2D = null
var facing_angle: float = 0.0
var _alerting: bool = false
var _alert_hold: float = 0.0

@onready var body_polygon: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func _ready() -> void:
	add_to_group("zone_enemy")
	facing_angle = randf() * TAU
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	var spin_speed := combat_rotate_speed if combat_active else rotate_speed
	facing_angle = wrapf(facing_angle + delta * spin_speed, 0.0, TAU)

	if _alert_hold > 0.0:
		_alert_hold -= delta
		if _alert_hold <= 0.0:
			_alerting = false

	if not combat_active:
		_check_detection()

	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	ship = target_ship
	combat_active = true


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	_alerting = false
	_alert_hold = 0.0


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


func _check_detection() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	if player.in_dark_pocket:
		return

	var emission: float = player.get_effective_emission()
	if emission <= 0.018:
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > beam_range + beam_width:
		return

	var blocked: bool = get_tree().current_scene.is_line_blocked(global_position, player.global_position, [get_rid()])
	if blocked:
		return

	for beam_dir in _beam_directions():
		var along := to_player.dot(beam_dir)
		if along < 0.0 or along > beam_range:
			continue
		var perpendicular := absf(to_player.cross(beam_dir))
		var tolerance := beam_width + (10.0 if player.dark_mode else 14.0)
		if perpendicular <= tolerance and (emission > 0.05 or not player.dark_mode or distance < 36.0):
			_begin_alert()
			return


func _beam_directions() -> Array[Vector2]:
	return [
		Vector2.RIGHT.rotated(facing_angle),
		Vector2.RIGHT.rotated(facing_angle + TAU / 3.0),
		Vector2.RIGHT.rotated(facing_angle + TAU * 2.0 / 3.0),
	]


func _begin_alert() -> void:
	if not _alerting:
		_alerting = true
		detected.emit(self)
	_alert_hold = ALERT_HOLD_SECONDS


func _update_palette() -> void:
	body_polygon.color = ColorSystem.enemy_fill(signature_color)
	body_polygon.color.a = 0.07 if not AlertSystem.combat_mode else 0.13
	outline.default_color = ColorSystem.enemy_outline()
	outline.width = 2.2


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var beam_color := signature_color if AlertSystem.combat_mode else ColorSystem.enemy_outline()
	var halo_alpha := 0.06 if not AlertSystem.combat_mode else 0.1
	draw_circle(Vector2.ZERO, 18.0, Color(beam_color.r, beam_color.g, beam_color.b, halo_alpha))

	for beam_dir in _beam_directions():
		var end := beam_dir * beam_range
		var alpha := 0.24 if not combat_active else 0.42
		draw_line(Vector2.ZERO, end, Color(beam_color.r, beam_color.g, beam_color.b, alpha), 2.2)
		draw_line(Vector2.ZERO, end * 0.85, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.18), beam_width)

	draw_polyline(PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(8.0, 0.0),
		Vector2(0.0, 12.0),
		Vector2(-8.0, 0.0),
		Vector2(0.0, -12.0)
	]), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.76), 1.4)

	if _alerting and not combat_active:
		var t_ms: float = Time.get_ticks_msec() / 1000.0
		var pulse: float = 0.75 + 0.25 * sin(t_ms * 14.0)
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(0.0, 0.0, 0.0, 0.75), true)
		draw_rect(Rect2(-9.0, -56.0, 18.0, 24.0), Color(1.0, 0.85, 0.0, pulse * 0.9), false, 1.5)
		draw_string(font, Vector2(-5.0, -36.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				Color(1.0, 0.90, 0.0, pulse))

	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 24, marker, 1.2)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	get_tree().current_scene.add_child(burst)
