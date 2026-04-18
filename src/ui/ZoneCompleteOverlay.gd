extends Control

const FADE_IN_DURATION  := 0.6
const HOLD_DURATION     := 2.2
const TOTAL_DURATION    := FADE_IN_DURATION + HOLD_DURATION

var _active: bool = false
var _elapsed: float = 0.0
var _ghost_run: bool = false   # true if player reached exit with zero kills


func trigger(ghost: bool = false) -> void:
	_active = true
	_elapsed = 0.0
	_ghost_run = ghost
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= TOTAL_DURATION:
		_active = false
		GameState.advance_zone()


func _draw() -> void:
	if not _active:
		return

	var vp    := get_viewport_rect().size
	var alpha := minf(_elapsed / FADE_IN_DURATION, 1.0)
	var font  := ThemeDB.fallback_font

	# Dark vignette
	draw_rect(Rect2(Vector2.ZERO, vp),
			Color(0.0, 0.02, 0.01, 0.72 * alpha))

	# Main heading
	var heading := "GHOST CLEAR" if _ghost_run else "ZONE CLEARED"
	var heading_color := Color(0.55, 1.0, 0.65, alpha) if not _ghost_run \
						else Color(0.4, 0.85, 1.0, alpha)
	draw_string(font,
			Vector2(vp.x * 0.5 - 72.0, vp.y * 0.5 - 10.0),
			heading,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, heading_color)

	# Countdown to next
	var remaining := maxf(0.0, TOTAL_DURATION - _elapsed)
	draw_string(font,
			Vector2(vp.x * 0.5 - 28.0, vp.y * 0.5 + 22.0),
			"%.1f" % remaining,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(heading_color.r, heading_color.g, heading_color.b, alpha * 0.55))
