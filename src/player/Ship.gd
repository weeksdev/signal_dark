extends CharacterBody2D

signal destroyed

const EMP_SHOCKWAVE_SCENE := preload("res://src/fx/EmpShockwave.tscn")
const ElectricSparks = preload("res://src/fx/ElectricSparks.gd")
const DRONE_SCENE := preload("res://src/player/Drone.tscn")
const AUTO_FIRE_RANGE := 320.0

@export var acceleration: float = 2400.0
@export var drag: float = 1650.0
@export var max_speed: float = 460.0
@export var dark_mode_speed_scale: float = 0.50
@export var dark_mode_acceleration_scale: float = 0.74
@export var dark_mode_drag_scale: float = 0.86
@export var boost_impulse: float = 560.0
@export var boost_cooldown: float = 0.22
@export var signal_probe_scene: PackedScene
@export var jammer_radius: float = 148.0
@export var jammer_duration: float = 2.4
@export var emp_radius: float = 285.0
@export var emp_disable_duration: float = 5.0
@export var emp_slow_duration: float = 3.0
@export var emp_speed_scale: float = 0.6
@export var cover_duration: float = 5.0
@export var cover_cooldown: float = 8.0
@export var drone_charges: int = 3

var aim_direction: Vector2 = Vector2.UP
var dark_mode: bool = false
var in_dark_pocket: bool = false
var probe_charges: int = 3
var jammer_charges: int = 2
var emp_charges: int = 0
var cover_active: bool = false
var boost_cooldown_remaining: float = 0.0
var dead: bool = false
var _cover_timer: float = 0.0
var _cover_cooldown_remaining: float = 0.0
var _previous_suppress_pressed: bool = false
var _previous_probe_pressed: bool = false
var _previous_cover_pressed: bool = false
var _previous_drone_pressed: bool = false
var _thruster_t: float = 0.0
var _boost_flash: float = 0.0
var _emp_slow_timer: float = 0.0
var _emp_flash: float = 0.0
var _hack_prompt_active: bool = false
var _default_collision_layer: int = 0

@onready var weapon_system = $WeaponSystem
@onready var body_polygon = $Body
@onready var outline = $Outline
@onready var suppress_label = $SuppressLabel
@onready var hack_indicator = $HackIndicator
@onready var hover_glow = get_node_or_null("HoverGlow")
@onready var ship_visual = get_node_or_null("ShipVisual")
var _sparks: Node2D = null


func _ready() -> void:
	add_to_group("player_ship")
	_default_collision_layer = collision_layer
	emp_charges = 1 if ArcadeState.is_active else 0
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_sparks = ElectricSparks.new()
	_sparks.radius = 30.0
	_sparks.z_index = 12
	add_child(_sparks)
	_update_palette()


func _physics_process(delta: float) -> void:
	if dead:
		return

	boost_cooldown_remaining = maxf(0.0, boost_cooldown_remaining - delta)
	_emp_slow_timer = maxf(0.0, _emp_slow_timer - delta)
	_cover_cooldown_remaining = maxf(0.0, _cover_cooldown_remaining - delta)
	if cover_active:
		_cover_timer -= delta
		if _cover_timer <= 0.0:
			_set_cover_active(false)
	dark_mode = InputManager.is_dark_mode()
	var move_input := InputManager.get_move_vector()
	var in_stealth_phase := not AlertSystem.combat_mode
	var speed_scale := dark_mode_speed_scale if in_stealth_phase else 1.0
	var acceleration_scale := dark_mode_acceleration_scale if dark_mode else 1.0
	var drag_scale := dark_mode_drag_scale if dark_mode else 1.0
	if _emp_slow_timer > 0.0:
		speed_scale *= emp_speed_scale
	var target_velocity := move_input * max_speed * speed_scale
	velocity = velocity.move_toward(target_velocity, acceleration * acceleration_scale * delta)
	velocity = velocity.move_toward(Vector2.ZERO, drag * drag_scale * delta)

	var did_boost := false
	if InputManager.is_boost_pressed() and _emp_slow_timer <= 0.0 and not dark_mode and move_input != Vector2.ZERO and boost_cooldown_remaining <= 0.0:
		velocity += move_input.normalized() * boost_impulse
		did_boost = true
		boost_cooldown_remaining = boost_cooldown
		_boost_flash = 1.0

	_thruster_t += delta
	_boost_flash = maxf(0.0, _boost_flash - delta * 4.0)
	_emp_flash = maxf(0.0, _emp_flash - delta * 1.8)

	move_and_slide()
	_sync_dark_pocket_state_immediate()
	var auto_fire_direction := _get_auto_fire_direction() if Settings.is_auto_fire_enabled() and AlertSystem.combat_mode and not _hack_prompt_active else Vector2.ZERO
	var auto_fire_active := auto_fire_direction != Vector2.ZERO
	_update_aim_direction(move_input, auto_fire_direction)
	rotation = aim_direction.angle() + PI / 2.0

	_update_hack_prompt(delta)

	var suppress_pressed := InputManager.is_suppress_pressed()
	var probe_pressed := InputManager.is_probe_pressed()
	if InputManager.is_emp_just_pressed() and not _hack_prompt_active:
		_try_emp_blast()
	if InputManager.is_fire_pressed() or auto_fire_active:
		weapon_system.try_fire(aim_direction)
	if probe_pressed and not _previous_probe_pressed:
		if not _hack_prompt_active:
			_try_launch_probe()
	if suppress_pressed and not _previous_suppress_pressed:
		if not _hack_prompt_active:
			if not _try_suppressed_kill():
				_try_signal_jammer()
	if InputManager.is_cover_just_pressed() and not _hack_prompt_active:
		_try_activate_cover()
	if InputManager.is_drone_just_pressed() and not _hack_prompt_active:
		_try_launch_drone()
	_previous_probe_pressed = probe_pressed
	_previous_suppress_pressed = suppress_pressed

	_update_emission(did_boost)
	_check_enemy_contact()
	_update_suppress_prompt()
	_update_palette()
	if ship_visual != null and ship_visual.has_method("set_thruster_strength"):
		ship_visual.set_thruster_strength(velocity.length() / maxf(max_speed, 0.01), _boost_flash, dark_mode)
	if ship_visual != null and ship_visual.has_method("set_motion_deform"):
		ship_visual.set_motion_deform(velocity, max_speed, delta)
	queue_redraw()


func _sync_dark_pocket_state_immediate() -> void:
	var inside := false
	var matched_pocket: Area2D = null
	for pocket in get_tree().get_nodes_in_group("dark_pocket"):
		if not (pocket is Area2D):
			continue
		if global_position.distance_to(pocket.global_position) > 70.0:
			continue
		inside = true
		matched_pocket = pocket
		break
	if inside == in_dark_pocket:
		return
	set_dark_pocket_active(inside)
	var world := get_tree().current_scene
	if world != null and world.has_method("set_player_dark_pocket_state"):
		if matched_pocket != null:
			world.set_player_dark_pocket_state(matched_pocket, true)
		else:
			for pocket in get_tree().get_nodes_in_group("dark_pocket"):
				if pocket is Area2D:
					world.set_player_dark_pocket_state(pocket, false)


func _update_aim_direction(move_input: Vector2, auto_fire_direction: Vector2 = Vector2.ZERO) -> void:
	# Right stick always wins — explicit aim overrides everything
	if InputManager.is_right_stick_active():
		aim_direction = InputManager.get_aim_vector(aim_direction)
		return
	if auto_fire_direction != Vector2.ZERO:
		aim_direction = auto_fire_direction
		return
	# Left stick / keyboard movement: face the direction you're moving
	if move_input.length() > 0.1:
		aim_direction = move_input.normalized()
		return


func _get_auto_fire_direction() -> Vector2:
	var best_visible: Node2D = null
	var best_visible_distance := INF
	var best_combat_any: Node2D = null
	var best_combat_any_distance := INF
	var world := get_tree().current_scene
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.is_alive:
			continue
		if enemy.has_method("is_valid_auto_fire_target") and not enemy.is_valid_auto_fire_target(global_position):
			continue
		var enemy_node := enemy as Node2D
		var distance: float = global_position.distance_to(enemy_node.global_position)
		if distance > AUTO_FIRE_RANGE:
			continue
		var combat_targetable := false
		if enemy.has_method("is_combat_targetable"):
			combat_targetable = enemy.is_combat_targetable()
		else:
			combat_targetable = true
		if combat_targetable:
			if distance < best_combat_any_distance:
				best_combat_any_distance = distance
				best_combat_any = enemy_node
		var visible := true
		if world != null and world.has_method("is_line_blocked"):
			visible = not world.is_line_blocked(global_position, enemy_node.global_position, [])
		if visible and distance < best_visible_distance:
			best_visible_distance = distance
			best_visible = enemy_node
	var target := best_visible if best_visible != null else best_combat_any
	if target == null:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()


func _update_emission(did_boost: bool) -> void:
	var emission := 0.08
	if velocity.length() > 1.0:
		emission = 0.25 + (velocity.length() / max_speed) * 0.6
	if dark_mode:
		emission = 0.02
	if in_dark_pocket:
		emission *= 0.35
	if cover_active:
		emission = 0.0
	if did_boost:
		emission = maxf(emission, 0.85)
	AlertSystem.set_emission(emission)
	var world := get_tree().current_scene
	if world != null and world.has_method("notify_player_noise"):
		if did_boost:
			world.notify_player_noise(global_position, 1.0)
		elif velocity.length() > max_speed * 0.92 and not dark_mode:
			world.notify_player_noise(global_position, 0.18)


func _try_launch_probe() -> void:
	if probe_charges <= 0:
		return
	probe_charges -= 1
	var probe = signal_probe_scene.instantiate()
	probe.global_position = global_position + aim_direction * 20.0
	probe.direction = aim_direction
	get_tree().current_scene.add_child(probe)


func _try_suppressed_kill() -> bool:
	if not dark_mode:
		return false
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy.can_be_suppressed_by(self):
			enemy.take_damage(true, global_position)
			return true
	return false


func _try_signal_jammer() -> void:
	if jammer_charges <= 0:
		return
	var world := get_tree().current_scene
	if world == null or not world.has_method("trigger_signal_jammer"):
		return
	jammer_charges -= 1
	world.trigger_signal_jammer(global_position, jammer_radius, jammer_duration)


func _try_activate_cover() -> void:
	if _cover_cooldown_remaining > 0.0 or cover_active:
		return
	_set_cover_active(true)
	_cover_timer = cover_duration
	_cover_cooldown_remaining = cover_cooldown
	var world := get_tree().current_scene
	if world != null and world.has_method("notify_player_cover_activated"):
		world.notify_player_cover_activated()


func _set_cover_active(active: bool) -> void:
	cover_active = active
	_sync_enemy_blocker_collision()
	if ship_visual != null and ship_visual.has_method("set_cover"):
		ship_visual.set_cover(active)


func set_dark_pocket_active(active: bool) -> void:
	in_dark_pocket = active
	_sync_enemy_blocker_collision()


func _sync_enemy_blocker_collision() -> void:
	collision_layer = (_default_collision_layer | 4) if cover_active or in_dark_pocket else _default_collision_layer


func _try_launch_drone() -> void:
	if drone_charges <= 0:
		return
	drone_charges -= 1
	var drone = DRONE_SCENE.instantiate()
	drone.global_position = global_position + aim_direction * 22.0
	drone.direction = aim_direction
	get_tree().current_scene.add_child(drone)


func _try_emp_blast() -> void:
	if emp_charges <= 0:
		return
	var world := get_tree().current_scene
	if world == null or not world.has_method("trigger_emp_blast"):
		return
	emp_charges -= 1
	_emp_slow_timer = emp_slow_duration
	_emp_flash = 1.0
	boost_cooldown_remaining = maxf(boost_cooldown_remaining, emp_slow_duration)
	_spawn_emp_shockwave()
	world.trigger_emp_blast(global_position, emp_radius, emp_disable_duration)


func _spawn_emp_shockwave() -> void:
	var shockwave = EMP_SHOCKWAVE_SCENE.instantiate()
	shockwave.global_position = global_position
	shockwave.radius = emp_radius
	var world := get_tree().current_scene
	if world != null:
		world.add_child(shockwave)


func _update_suppress_prompt() -> void:
	var can_suppress := false
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy.can_be_suppressed_by(self):
			can_suppress = true
			break
	suppress_label.visible = can_suppress


func _update_hack_prompt(delta: float) -> void:
	var world := get_tree().current_scene
	if world == null or not world.has_method("update_gate_hacking"):
		_hack_prompt_active = false
		hack_indicator.update_indicator(false, global_position, [], 0, false)
		return
	var status: Dictionary = world.update_gate_hacking(self, delta)
	_hack_prompt_active = status.get("visible", false)
	hack_indicator.update_indicator(
		_hack_prompt_active,
		status.get("world_pos", global_position + Vector2(0.0, -56.0)),
		status.get("sequence", []),
		status.get("current_index", 0),
		status.get("wrong_flash", false)
	)


func _update_palette() -> void:
	var fill_color := ColorSystem.player_fill(dark_mode)
	var outline_color := ColorSystem.player_outline(dark_mode)
	body_polygon.color = fill_color
	body_polygon.color.a = 0.0
	outline.default_color = Color(outline_color.r, outline_color.g, outline_color.b, 0.26 if not dark_mode else 0.14)
	outline.width = 1.1 if not dark_mode else 0.7
	body_polygon.scale = Vector2.ONE * (1.02 if not dark_mode else 0.96)
	suppress_label.modulate = ColorSystem.ui_color()
	if hover_glow != null and hover_glow.has_method("set_glow_color"):
		hover_glow.set_glow_color(outline_color, 0.72 if not dark_mode else 0.28)
	if ship_visual != null and ship_visual.has_method("apply_palette"):
		ship_visual.apply_palette(fill_color, outline_color, dark_mode)
	if _sparks != null:
		_sparks.intensity = 0.35 if ColorSystem.in_combat else 0.15


func _on_mode_changed(in_combat: bool) -> void:
	if in_combat and cover_active:
		_set_cover_active(false)
		_cover_timer = 0.0
	_update_palette()


func get_effective_emission() -> float:
	return AlertSystem.emission


func take_hit() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	hide()
	destroyed.emit()


func _check_enemy_contact() -> void:
	if cover_active or in_dark_pocket:
		return
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy == null or not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) <= 22.0:
			take_hit()
			return


func _draw_thruster() -> void:
	if ship_visual != null:
		return
	var speed_frac := velocity.length() / max_speed
	if speed_frac < 0.02 and _boost_flash < 0.01:
		return
	var base_len := 8.0 + speed_frac * 20.0 + _boost_flash * 18.0
	var base_alpha := (0.35 + speed_frac * 0.5 + _boost_flash * 0.55) * (0.3 if dark_mode else 1.0)
	var col := ColorSystem.player_outline(dark_mode)
	# Five strands spread across the exhaust ports on the swept-wing rear
	var offsets := [-2.0, -1.0, 0.0, 1.0, 2.0]
	for i in offsets.size():
		var flicker := 0.65 + 0.35 * sin(_thruster_t * 18.0 + i * 1.3)
		var strand_len := base_len * flicker * (0.7 + 0.3 * sin(_thruster_t * 11.0 + i * 2.1))
		var x: float = offsets[i]
		var alpha := base_alpha * flicker
		draw_line(
			Vector2(x, 9.0),
			Vector2(x * 0.4, 9.0 + strand_len),
			Color(col.r, col.g, col.b, alpha),
			0.7
		)


func _draw() -> void:
	if dead:
		return
	_draw_thruster()
	var emission_radius := 10.0 + AlertSystem.emission * 24.0
	if not ColorSystem.in_combat:
		var glow := ColorSystem.glow_color()
		var glow_strength := 0.08 if not dark_mode else 0.03
		draw_circle(Vector2.ZERO, emission_radius + 16.0, Color(glow.r, glow.g, glow.b, glow_strength * 0.42))
		draw_circle(Vector2.ZERO, emission_radius + 8.0, Color(glow.r, glow.g, glow.b, glow_strength * 0.2))
		if not dark_mode:
			draw_circle(Vector2.ZERO, 6.0, Color(0.33, 0.56, 0.39, 0.18))
	else:
		draw_circle(Vector2.ZERO, emission_radius + 16.0, Color(0.3, 0.8, 1.0, 0.12))
	if _emp_slow_timer > 0.0:
		var emp := Color(0.55, 0.95, 1.0, 0.18 + 0.16 * sin(Time.get_ticks_msec() / 48.0))
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU * 0.78, 36, emp, 1.0)
		draw_line(Vector2(-14.0, -4.0), Vector2(12.0, 8.0), emp, 0.65)
	if _emp_flash > 0.0:
		var flash := Color(0.55, 0.95, 1.0, 0.24 * _emp_flash)
		draw_circle(Vector2.ZERO, emp_radius * (1.0 - _emp_flash * 0.18), flash)
		draw_arc(Vector2.ZERO, emp_radius * (1.0 - _emp_flash * 0.18), 0.0, TAU, 80, Color(flash.r, flash.g, flash.b, 0.55 * _emp_flash), 1.5)
