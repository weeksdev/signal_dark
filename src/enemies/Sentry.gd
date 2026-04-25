extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const SEARCH_INTEREST_RADIUS := 255.0

@export var signature_color := Color("32d2ff")
@export var suppress_range: float = 30.0
@export var attack_range: float = 320.0
@export var fire_interval: float = 1.2
@export var bolt_scene: PackedScene

var cooldown: float = 0.8


func _ready() -> void:
	super._ready()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if tick_support_state(delta):
		queue_redraw()
		return
	cooldown = maxf(cooldown - delta, 0.0)
	tick_alert_state(delta, 0.7)
	var player = ship if ship != null else get_tree().get_first_node_in_group("player_ship")
	if player != null:
		var aim_target: Vector2 = player.global_position
		if not combat_active:
			var search_target: Variant = world_search_target_if_relevant(SEARCH_INTEREST_RADIUS)
			if search_target is Vector2:
				aim_target = search_target
		var to_player: Vector2 = aim_target - global_position
		if to_player != Vector2.ZERO:
			facing_vector = to_player.normalized()
		if not combat_active:
			_check_warning(player)
	if combat_active and player != null and cooldown <= 0.0:
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			_fire_at(player.global_position)
			cooldown = fire_interval
	queue_redraw()


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	cooldown = 0.8
	clear_alert_state()


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
	add_effect_to_world(bolt)


func _check_warning(player: Node2D) -> void:
	if player.in_dark_pocket:
		_suspicion = 0.0
		return
	if world_is_point_jammed(global_position) or world_is_point_jammed(player.global_position):
		_suspicion = 0.0
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance > 220.0:
		return
	if is_world_line_blocked(global_position, player.global_position, [get_rid()]):
		return
	var speed_ratio: float = clampf(player.velocity.length() / maxf(player.max_speed, 1.0), 0.0, 1.0)
	var risk: float = player.get_effective_emission() * 2.4 + speed_ratio * 0.9
	if player.dark_mode:
		risk *= 0.55
	if world_is_search_active():
		risk *= 1.2
	risk *= 1.0 - (distance / 220.0)
	if risk <= 0.04:
		return
	if add_suspicion(risk * 0.05):
		_begin_alert()


func _begin_alert() -> void:
	begin_alert_state(2.4)


func _update_palette() -> void:
	body_polygon.color = enemy_state_fill(signature_color, 0.06 if not AlertSystem.combat_mode else 0.12)
	outline.default_color = enemy_state_outline()
	outline.width = 2.2


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.04))
	draw_line(Vector2.ZERO, facing_vector * 26.0, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.35), 2.0)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.7), 1.2)
	draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.45), 1.0)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.45), 1.0)
	draw_alert_marker()
	draw_suspicion_arc(24.0)
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null and can_be_suppressed_by(player):
		var marker := Color(0.82, 1.0, 0.88, 0.45 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, marker, 1.1)
	draw_emp_disabled_effect(28.0)
	if not combat_active:
		return
	draw_arc(Vector2.ZERO, attack_range, facing_vector.angle() - 0.28, facing_vector.angle() + 0.28, 18, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.08), 1.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)
