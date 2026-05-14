extends "res://src/enemies/BaseEnemy.gd"

const EXPLOSION_SCENE := preload("res://src/fx/ExplosionBurst.tscn")
const STEER_ACCEL := 420.0
const PATROL_ARRIVE_DIST := 12.0
const PATROL_DWELL := 0.32
const SEARCH_INTEREST_RADIUS := 248.0

@export var signature_color := Color("ff2d55")
@export var roam_speed: float = 58.0
@export var combat_speed: float = 180.0
@export var suppress_range: float = 0.0

var spawn_point: Vector2 = Vector2.ZERO
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0
var patrol_pause: float = 0.0
var _stuck_auto_target_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	spawn_point = global_position
	_build_patrol_loop()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if tick_emp_disabled(delta):
		queue_redraw()
		return
	if tick_support_state(delta):
		queue_redraw()
		return
	if combat_active and is_instance_valid(ship):
		var to_ship: Vector2 = ship.global_position - global_position
		if to_ship != Vector2.ZERO:
			var desired_dir := to_ship.normalized()
			facing_vector = facing_vector.lerp(desired_dir, clampf(delta * 9.0, 0.0, 1.0)).normalized()
			velocity = velocity.move_toward(desired_dir * combat_speed, STEER_ACCEL * delta)
		move_and_slide()
		_push_out_of_dark_pockets(delta)
		if get_slide_collision_count() > 0:
			_stuck_auto_target_cooldown = 0.35
			velocity = Vector2.ZERO
			_advance_patrol()
	else:
		_stuck_auto_target_cooldown = maxf(0.0, _stuck_auto_target_cooldown - delta)
		var search_target: Variant = world_search_target_if_relevant(SEARCH_INTEREST_RADIUS)
		if search_target is Vector2:
			_run_search(delta, search_target)
		else:
			_run_patrol(delta)
	_emit_contact_hit()
	if asset_visual != null:
		asset_visual.rotation = facing_vector.angle()
	queue_redraw()


func _run_patrol(delta: float) -> void:
	if patrol_pause > 0.0:
		patrol_pause = maxf(0.0, patrol_pause - delta)
		velocity = velocity.move_toward(Vector2.ZERO, STEER_ACCEL * delta)
		return
	var roam_target := patrol_points[patrol_index] if not patrol_points.is_empty() else spawn_point
	var offset: Vector2 = roam_target - global_position
	if offset.length() > PATROL_ARRIVE_DIST:
		var desired_dir := offset.normalized()
		facing_vector = facing_vector.lerp(desired_dir, clampf(delta * 7.0, 0.0, 1.0)).normalized()
		velocity = velocity.move_toward(desired_dir * roam_speed, STEER_ACCEL * delta)
		move_and_slide()
		_push_out_of_dark_pockets(delta)
		if get_slide_collision_count() > 0:
			velocity = velocity.slide(get_slide_collision(0).get_normal()) * 0.22
			_advance_patrol()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, STEER_ACCEL * delta)
		_advance_patrol()


func _run_search(delta: float, roam_target: Vector2) -> void:
	var offset: Vector2 = roam_target - global_position
	if offset.length() > PATROL_ARRIVE_DIST:
			var desired_dir := offset.normalized()
			facing_vector = facing_vector.lerp(desired_dir, clampf(delta * 7.0, 0.0, 1.0)).normalized()
			velocity = velocity.move_toward(desired_dir * roam_speed, STEER_ACCEL * delta)
			move_and_slide()
			_push_out_of_dark_pockets(delta)
			if get_slide_collision_count() > 0:
				velocity = velocity.bounce(get_slide_collision(0).get_normal()) * 0.25
	else:
		velocity = velocity.move_toward(Vector2.ZERO, STEER_ACCEL * delta)


func activate_for_combat(target_ship: Node2D) -> void:
	super.activate_for_combat(target_ship)


func deactivate_to_stealth() -> void:
	combat_active = false
	ship = null
	velocity = Vector2.ZERO
	patrol_pause = 0.0
	_snap_to_patrol_route()
	clear_alert_state()


func is_valid_auto_fire_target(from_point: Vector2) -> bool:
	if not super.is_valid_auto_fire_target(from_point):
		return false
	return _stuck_auto_target_cooldown <= 0.0


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
	body_polygon.color = enemy_state_fill(signature_color, 0.06 if not AlertSystem.combat_mode else 0.12)
	outline.default_color = enemy_state_outline()
	outline.width = 1.2
	_sync_visual_overlays()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var halo := outline.default_color
	draw_circle(Vector2.ZERO, 16.0, Color(halo.r, halo.g, halo.b, 0.08))
	draw_line(Vector2.ZERO, facing_vector * 18.0, Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.35), 1.0)
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(5.0, 0.0),
		Vector2(0.0, 9.0),
		Vector2(-5.0, 0.0),
		Vector2(0.0, -9.0)
	]), Color(outline.default_color.r, outline.default_color.g, outline.default_color.b, 0.7), 1.2)
	draw_emp_disabled_effect(26.0)


func _spawn_burst(silent: bool) -> void:
	var burst = EXPLOSION_SCENE.instantiate()
	burst.global_position = global_position
	burst.combat_mode = AlertSystem.combat_mode and not silent
	burst.signature_color = signature_color
	add_effect_to_world(burst)


func _build_patrol_loop() -> void:
	var radius_x := 42.0
	var radius_y := 34.0
	patrol_points = [
		spawn_point + Vector2(0.0, -radius_y),
		spawn_point + Vector2(radius_x, 0.0),
		spawn_point + Vector2(0.0, radius_y),
		spawn_point + Vector2(-radius_x, 0.0),
	]
	patrol_index = randi() % patrol_points.size()


func _advance_patrol() -> void:
	if patrol_points.is_empty():
		return
	patrol_index = posmod(patrol_index + 1, patrol_points.size())
	patrol_pause = PATROL_DWELL


func _snap_to_patrol_route() -> void:
	var ordered_points := _ordered_recovery_points()
	var reserved: Variant = world_call("reserve_patrol_recovery_point", [self, ordered_points])
	if reserved is Vector2:
		_apply_reserved_patrol_point(reserved)
		return
	world_call("schedule_enemy_patrol_reentry", [self, ordered_points])


func _ordered_recovery_points() -> Array:
	var points: Array = patrol_points.duplicate() if not patrol_points.is_empty() else [spawn_point]
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return global_position.distance_to(a) < global_position.distance_to(b)
	)
	return points


func _apply_reserved_patrol_point(point: Vector2) -> void:
	if patrol_points.is_empty():
		global_position = spawn_point
		patrol_pause = PATROL_DWELL * 0.4
		return
	for i in range(patrol_points.size()):
		if patrol_points[i].distance_to(point) < 1.0:
			patrol_index = i
			break
	global_position = point
	patrol_pause = PATROL_DWELL * 0.4


func resume_from_patrol_reentry(position: Vector2) -> void:
	_apply_reserved_patrol_point(position)
	super.resume_from_patrol_reentry(position)
