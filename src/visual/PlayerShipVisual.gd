extends Node2D

@onready var hull: Sprite2D = find_child("Hull", true, false) as Sprite2D
@onready var left_wing: Sprite2D = find_child("LeftWing", true, false) as Sprite2D
@onready var right_wing: Sprite2D = find_child("RightWing", true, false) as Sprite2D
@onready var exhaust: Sprite2D = find_child("Exhaust", true, false) as Sprite2D
@onready var exhaust_plume_outer: Polygon2D = find_child("ExhaustPlumeOuter", true, false) as Polygon2D
@onready var exhaust_plume_inner: Polygon2D = find_child("ExhaustPlumeInner", true, false) as Polygon2D
@onready var glow_hull: Sprite2D = find_child("GlowHull", true, false) as Sprite2D
@onready var glow_left_wing: Sprite2D = find_child("GlowLeftWing", true, false) as Sprite2D
@onready var glow_right_wing: Sprite2D = find_child("GlowRightWing", true, false) as Sprite2D
var exhaust_base_position: Vector2 = Vector2.ZERO
var exhaust_base_scale: Vector2 = Vector2.ONE
var _exhaust_base_alpha: float = 1.0


func _ready() -> void:
	if exhaust != null:
		exhaust_base_position = exhaust.position
		exhaust_base_scale = exhaust.scale
		_exhaust_base_alpha = exhaust.modulate.a
	_sync_glow_from_parts()
	_sync_exhaust_plume(0.0, false)


func apply_palette(fill_color: Color, outline_color: Color, dark_mode: bool) -> void:
	var ship_tint := Color(0.44, 0.44, 0.46, 1.0)
	if ColorSystem.in_combat:
		ship_tint = Color(0.52, 0.5, 0.48, 1.0)
	if hull != null:
		hull.modulate = ship_tint
	if left_wing != null:
		left_wing.modulate = ship_tint
	if right_wing != null:
		right_wing.modulate = ship_tint
	var glow_tint := Color(outline_color.r, outline_color.g, outline_color.b, 0.72 if not dark_mode else 0.58)
	if glow_hull != null:
		glow_hull.modulate = glow_tint
	if glow_left_wing != null:
		glow_left_wing.modulate = glow_tint
	if glow_right_wing != null:
		glow_right_wing.modulate = glow_tint
	var exhaust_tint := Color(0.92, 0.98, 1.0, 0.68 if not dark_mode else 0.56)
	if ColorSystem.in_combat:
		exhaust_tint = Color(1.0, 0.96, 0.9, exhaust_tint.a)
	if exhaust != null:
		exhaust.modulate = exhaust_tint
	if exhaust_plume_outer != null:
		exhaust_plume_outer.color = Color(exhaust_tint.r, exhaust_tint.g, exhaust_tint.b, 0.0)
	if exhaust_plume_inner != null:
		exhaust_plume_inner.color = Color(1.0, 1.0, 1.0, 0.0)


func set_thruster_strength(speed_frac: float, boost_flash: float, dark_mode: bool) -> void:
	if exhaust == null:
		return
	var strength := clampf(speed_frac * 0.72 + boost_flash * 0.95, 0.0, 1.0)
	exhaust.modulate.a = _exhaust_base_alpha
	_sync_glow_from_parts()
	_sync_exhaust_plume(strength, dark_mode)


func _sync_glow_from_parts() -> void:
	_sync_part_glow(hull, glow_hull, Vector2(1.1, 0.7), Vector2(0.0, 88.0))
	_sync_part_glow(left_wing, glow_left_wing, Vector2(1.12, 0.66), Vector2(0.0, 92.0))
	_sync_part_glow(right_wing, glow_right_wing, Vector2(1.12, 0.66), Vector2(0.0, 92.0))


func _sync_part_glow(source: Sprite2D, glow: Sprite2D, scale_mult: Vector2, y_offset: Vector2) -> void:
	if source == null or glow == null:
		return
	glow.position = source.position + y_offset
	glow.rotation = source.rotation
	glow.scale = Vector2(source.scale.x * scale_mult.x, source.scale.y * scale_mult.y)
	glow.flip_h = source.flip_h


func _sync_exhaust_plume(strength: float, dark_mode: bool) -> void:
	if exhaust == null or exhaust_plume_outer == null or exhaust_plume_inner == null:
		return
	var plume_strength := clampf(strength, 0.0, 1.0)
	var base_y := 44.0
	var plume_length := lerpf(40.0, 300.0, plume_strength)
	var outer_width := lerpf(34.0, 112.0, plume_strength)
	var inner_width := lerpf(16.0, 46.0, plume_strength)
	var origin := exhaust_base_position + Vector2(0.0, base_y)
	exhaust_plume_outer.position = origin
	exhaust_plume_inner.position = origin + Vector2(0.0, 10.0)
	exhaust_plume_outer.polygon = PackedVector2Array([
		Vector2(-outer_width * 0.42, 0.0),
		Vector2(outer_width * 0.42, 0.0),
		Vector2(outer_width, plume_length * 0.72),
		Vector2(0.0, plume_length),
		Vector2(-outer_width, plume_length * 0.72),
	])
	exhaust_plume_inner.polygon = PackedVector2Array([
		Vector2(-inner_width * 0.34, 0.0),
		Vector2(inner_width * 0.34, 0.0),
		Vector2(inner_width * 0.72, plume_length * 0.58),
		Vector2(0.0, plume_length * 0.8),
		Vector2(-inner_width * 0.72, plume_length * 0.58),
	])
	var outer_alpha := lerpf(0.14, 0.62, plume_strength) * (0.45 if dark_mode else 1.0)
	var inner_alpha := lerpf(0.22, 0.95, plume_strength) * (0.4 if dark_mode else 1.0)
	exhaust_plume_outer.color = Color(0.32, 0.98, 0.92, outer_alpha)
	exhaust_plume_inner.color = Color(0.95, 1.0, 1.0, inner_alpha)
