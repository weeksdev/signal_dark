extends CharacterBody2D

signal destroyed

@export var acceleration: float = 2400.0
@export var drag: float = 1650.0
@export var max_speed: float = 460.0
@export var dark_mode_speed_scale: float = 0.76
@export var boost_impulse: float = 560.0
@export var boost_cooldown: float = 0.22
@export var signal_probe_scene: PackedScene
@export var jammer_radius: float = 148.0
@export var jammer_duration: float = 2.4

var aim_direction: Vector2 = Vector2.UP
var dark_mode: bool = false
var in_dark_pocket: bool = false
var probe_charges: int = 3
var jammer_charges: int = 2
var boost_cooldown_remaining: float = 0.0
var dead: bool = false
var _previous_suppress_pressed: bool = false
var _previous_probe_pressed: bool = false
var _thruster_t: float = 0.0
var _boost_flash: float = 0.0
var _hack_prompt_active: bool = false

@onready var weapon_system = $WeaponSystem
@onready var body_polygon = $Body
@onready var outline = $Outline
@onready var suppress_label = $SuppressLabel
@onready var hack_indicator = $HackIndicator


func _ready() -> void:
	add_to_group("player_ship")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _physics_process(delta: float) -> void:
	if dead:
		return

	boost_cooldown_remaining = maxf(0.0, boost_cooldown_remaining - delta)
	dark_mode = InputManager.is_dark_mode()
	var move_input := InputManager.get_move_vector()
	var speed_scale := dark_mode_speed_scale if dark_mode else 1.0
	var target_velocity := move_input * max_speed * speed_scale
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)

	var did_boost := false
	if InputManager.is_boost_pressed() and not dark_mode and move_input != Vector2.ZERO and boost_cooldown_remaining <= 0.0:
		velocity += move_input.normalized() * boost_impulse
		did_boost = true
		boost_cooldown_remaining = boost_cooldown
		_boost_flash = 1.0

	_thruster_t += delta
	_boost_flash = maxf(0.0, _boost_flash - delta * 4.0)

	move_and_slide()
	_update_aim_direction(move_input)
	rotation = aim_direction.angle() + PI / 2.0

	_update_hack_prompt(delta)

	var suppress_pressed := InputManager.is_suppress_pressed()
	var probe_pressed := InputManager.is_probe_pressed()
	if InputManager.is_fire_pressed():
		weapon_system.try_fire(aim_direction)
	if probe_pressed and not _previous_probe_pressed:
		if not _hack_prompt_active:
			_try_launch_probe()
	if suppress_pressed and not _previous_suppress_pressed:
		if not _hack_prompt_active:
			if not _try_suppressed_kill():
				_try_signal_jammer()
	_previous_probe_pressed = probe_pressed
	_previous_suppress_pressed = suppress_pressed

	_update_emission(did_boost)
	_check_enemy_contact()
	_update_suppress_prompt()
	_update_palette()
	queue_redraw()


func _update_aim_direction(move_input: Vector2) -> void:
	# Right stick always wins — explicit aim overrides everything
	if InputManager.is_right_stick_active():
		aim_direction = InputManager.get_aim_vector(aim_direction)
		return
	# Left stick / keyboard movement: face the direction you're moving
	if move_input.length() > 0.1:
		aim_direction = move_input.normalized()
		return
	# Mouse fallback for desktop
	var mouse_world := get_global_mouse_position()
	var mouse_vector := mouse_world - global_position
	if mouse_vector.length() > 8.0:
		aim_direction = mouse_vector.normalized()


func _update_emission(did_boost: bool) -> void:
	var emission := 0.08
	if velocity.length() > 1.0:
		emission = 0.25 + (velocity.length() / max_speed) * 0.6
	if dark_mode:
		emission = 0.02
	if in_dark_pocket:
		emission *= 0.35
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
	body_polygon.color = ColorSystem.player_fill(dark_mode)
	outline.default_color = ColorSystem.player_outline(dark_mode)
	outline.width = 3.0 if not dark_mode else 1.8
	body_polygon.scale = Vector2.ONE * (1.08 if not dark_mode else 0.98)
	body_polygon.color.a = 0.18 if not dark_mode else 0.08
	suppress_label.modulate = ColorSystem.ui_color()


func _on_mode_changed(_in_combat: bool) -> void:
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
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy == null or not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) <= 22.0:
			take_hit()
			return


func _draw_thruster() -> void:
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
			1.4
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
