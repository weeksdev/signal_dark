extends Node2D

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
var duration: float = 0.7
var _elapsed: float = 0.0
const PULSE_START_RADIUS := 14.0
const PULSE_TRAIL_THICKNESS := 5.0
const TAG_FLASH_RADIUS := 18.0


func _ready() -> void:
	global_position = Vector2.ZERO
	top_level = true
	z_index = 40


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var dir := to_point - from_point
	var length := dir.length()
	var pulse_radius := PULSE_START_RADIUS
	if length > 1.0:
		pulse_radius = lerpf(PULSE_START_RADIUS, length, t)
	else:
		pulse_radius = lerpf(PULSE_START_RADIUS, 88.0, t)

	var pulse_alpha := 1.0 - t
	var pulse_color := Color(1.0, 0.88, 0.18, 0.98 * pulse_alpha)
	var hot_color := Color(1.0, 0.97, 0.58, 0.62 * pulse_alpha)
	draw_circle(from_point, 14.0, Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.16 * pulse_alpha))
	draw_arc(from_point, pulse_radius, 0.0, TAU, 64, pulse_color, 3.6)
	draw_arc(from_point, maxf(0.0, pulse_radius - 10.0), 0.0, TAU, 56, Color(hot_color.r, hot_color.g, hot_color.b, 0.44 * pulse_alpha), 1.4)
	draw_arc(from_point, pulse_radius + 12.0, 0.0, TAU, 72, Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.14 * pulse_alpha), PULSE_TRAIL_THICKNESS)

	if length <= 1.0:
		return

	var hit_threshold := 14.0
	if pulse_radius + hit_threshold < length:
		return

	var hit_t := clampf((pulse_radius - maxf(length - hit_threshold, 0.0)) / (hit_threshold * 2.0), 0.0, 1.0)
	var hit_alpha := (1.0 - t) * hit_t
	var tag_color := Color(1.0, 0.86, 0.18, 0.95 * hit_alpha)
	var tag_hot := Color(1.0, 0.98, 0.72, 0.72 * hit_alpha)
	draw_circle(to_point, 10.0 + 6.0 * hit_t, Color(tag_color.r, tag_color.g, tag_color.b, 0.12 * hit_alpha))
	draw_arc(to_point, TAG_FLASH_RADIUS + 12.0 * hit_t, 0.0, TAU, 28, tag_color, 2.4)
	draw_arc(to_point, TAG_FLASH_RADIUS * 0.55 + 6.0 * hit_t, 0.0, TAU, 22, tag_hot, 1.2)
	draw_line(to_point + Vector2(-8.0, 0.0), to_point + Vector2(8.0, 0.0), Color(tag_color.r, tag_color.g, tag_color.b, 0.72 * hit_alpha), 1.8)
	draw_line(to_point + Vector2(0.0, -8.0), to_point + Vector2(0.0, 8.0), Color(tag_color.r, tag_color.g, tag_color.b, 0.72 * hit_alpha), 1.8)
