extends Node2D

var elapsed: float = 0.0
var combat_mode: bool = false
var signature_color := Color("00ff88")

const COMBAT_DURATION: float = 2.2
const STEALTH_DURATION: float = 0.65

# [travel_angle, speed, seg_length, hue, spin_rate, phase_delay]
var _particles: Array = []
# [offset_x, offset_y, spawn_t, hue_offset]
var _clusters: Array = []
var _duration: float = COMBAT_DURATION
const FIRE_PALETTE: Array[Color] = [
	Color(1.0, 0.08, 0.02, 1.0),
	Color(1.0, 0.25, 0.02, 1.0),
	Color(1.0, 0.48, 0.04, 1.0),
	Color(1.0, 0.72, 0.08, 1.0),
	Color(0.72, 0.04, 0.01, 1.0),
]


func _ready() -> void:
	_duration = COMBAT_DURATION if combat_mode else STEALTH_DURATION
	_bake_particles()


func _bake_particles() -> void:
	if combat_mode:
		for i in 240:
			var fi: float = float(i)
			var angle: float = TAU * fi / 240.0 + sin(fi * 1.618033) * 1.4
			var band: float = fmod(fi * 0.017, 1.0)
			var speed: float
			if band < 0.3:
				speed = 60.0 + maxf(0.0, sin(fi * 1.3)) * 140.0
			elif band < 0.65:
				speed = 200.0 + maxf(0.0, sin(fi * 0.7)) * 280.0
			else:
				speed = 420.0 + maxf(0.0, sin(fi * 2.1)) * 340.0
			var seg: float = 6.0 + maxf(0.0, sin(fi * 3.7)) * 18.0
			var color_index: float = float(i % FIRE_PALETTE.size())
			var spin: float = sin(fi * 2.9) * 7.0 + cos(fi * 1.3) * 3.0
			var delay: float = fmod(fi * 0.0018, 0.12)
			_particles.append([angle, speed, seg, color_index, spin, delay])

		for j in 5:
			var fj: float = float(j)
			var ca: float = TAU * fj / 5.0 + 0.4
			var cd: float = 80.0 + sin(fj * 2.1) * 60.0
			var cx: float = cos(ca) * cd
			var cy: float = sin(ca) * cd
			var st: float = 0.08 + fj * 0.06
			var ho: float = float(j % FIRE_PALETTE.size())
			_clusters.append([cx, cy, st, ho])
	else:
		for i in 64:
			var fi: float = float(i)
			var angle: float = TAU * fi / 64.0 + sin(fi * 1.618) * 0.7
			var speed: float = 70.0 + maxf(0.0, sin(fi * 0.9)) * 300.0
			var seg: float = 5.0 + maxf(0.0, sin(fi * 3.1)) * 12.0
			var spin: float = sin(fi * 2.8) * 5.0
			var delay: float = fmod(fi * 0.003, 0.05)
			_particles.append([angle, speed, seg, 0.0, spin, delay])


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(elapsed / _duration, 0.0, 1.0)
	if combat_mode:
		_draw_combat(t)
	else:
		_draw_stealth(t)


func _draw_combat(t: float) -> void:
	var fade: float = 1.0 - t

	# White flash
	if t < 0.12:
		var ft: float = t / 0.12
		draw_circle(Vector2.ZERO, lerpf(8.0, 60.0, ft),
				Color(1.0, 1.0, 1.0, 1.0 - ft))
		draw_circle(Vector2.ZERO, lerpf(4.0, 30.0, ft),
				Color(1.0, 0.95, 0.8, (1.0 - ft) * 0.9))

	# Shockwave 1 — white, to 700px
	var sw1_t: float = minf(t * 1.6, 1.0)
	var sw1_r: float = lerpf(20.0, 700.0, pow(sw1_t, 0.38))
	var sw1_a: float = maxf(0.0, 1.0 - sw1_t * 2.2) * 0.85
	if sw1_a > 0.004:
		draw_arc(Vector2.ZERO, sw1_r, 0.0, TAU, 72,
				Color(1.0, 1.0, 1.0, sw1_a), 3.0)

		# Shockwave 2 — orange heat, to 460px
		var sw2_t: float = minf(t * 1.1, 1.0)
		var sw2_r: float = lerpf(12.0, 460.0, pow(sw2_t, 0.44))
		var sw2_a: float = maxf(0.0, 1.0 - sw2_t * 1.8) * 0.65
		if sw2_a > 0.004:
			draw_arc(Vector2.ZERO, sw2_r, 0.0, TAU, 56,
					_fire_color(2, sw2_a), 2.2)

	# Shockwave 3 — gold, fat, to 280px
	var sw3_t: float = minf(t * 0.85, 1.0)
	var sw3_r: float = lerpf(8.0, 280.0, pow(sw3_t, 0.5))
	var sw3_a: float = maxf(0.0, 1.0 - sw3_t * 1.4) * 0.5
	if sw3_a > 0.004:
		draw_arc(Vector2.ZERO, sw3_r, 0.0, TAU, 40,
				Color.from_hsv(0.09, 0.9, 1.0, sw3_a), 4.0)

	# Main debris
	for p in _particles:
		var travel_angle: float = p[0]
		var speed: float        = p[1]
		var seg_len: float      = p[2]
		var color_index: int    = int(p[3])
		var spin: float         = p[4]
		var delay: float        = p[5]
		var pt: float = clampf(t - delay, 0.0, 1.0)
		if pt <= 0.0:
			continue
		var dist: float = speed * pt * _duration
		var pos: Vector2 = Vector2(cos(travel_angle), sin(travel_angle)) * dist
		var seg_angle: float = travel_angle + spin * pt * _duration
		var half: float = seg_len * 0.5
		var sd: Vector2 = Vector2(cos(seg_angle), sin(seg_angle)) * half
		var alpha: float = (1.0 - pt) * 0.95
		draw_line(pos - sd, pos + sd, _fire_color(color_index, alpha), 1.1)

	# Secondary cluster bursts
	for cl in _clusters:
		var ox: float      = cl[0]
		var oy: float      = cl[1]
		var spawn_t: float = cl[2]
		var hue_off: float = cl[3]
		if t < spawn_t:
			continue
		var offset: Vector2 = Vector2(ox, oy)
		var ct: float = clampf((t - spawn_t) / 0.55, 0.0, 1.0)
		var cfade: float = 1.0 - ct
		if ct < 0.2:
			var cft: float = ct / 0.2
			draw_circle(offset, lerpf(3.0, 18.0, cft),
					Color(1.0, 1.0, 1.0, (1.0 - cft) * 0.7))
		var cr: float = lerpf(6.0, 120.0, pow(ct, 0.45))
		var ca2: float = maxf(0.0, 1.0 - ct * 2.5) * 0.6
		if ca2 > 0.004:
			draw_arc(offset, cr, 0.0, TAU, 24,
					_fire_color(int(hue_off) + 1, ca2), 2.0)
		for j in 24:
			var fj: float = float(j)
			var a: float = TAU * fj / 24.0 + hue_off * TAU
			var sp: float = 60.0 + maxf(0.0, sin(fj * 1.9)) * 160.0
			var d: float = sp * ct * 0.55
			var cpos: Vector2 = offset + Vector2(cos(a), sin(a)) * d
			var sa: float = a + sin(fj * 2.1) * 4.0 * ct
			var sv_len: float = 5.0 + maxf(0.0, sin(fj * 3.1)) * 9.0
			var sv: Vector2 = Vector2(cos(sa), sin(sa)) * sv_len * 0.5
			var col: Color = _fire_color(int(hue_off) + j, cfade * 0.8)
			draw_line(cpos - sv, cpos + sv, col, 0.8)

		# Rolling heat bloom
		draw_circle(Vector2.ZERO, lerpf(60.0, 340.0, pow(t, 0.45)),
				_fire_color(1, 0.055 * fade))
		draw_circle(Vector2.ZERO, lerpf(30.0, 160.0, pow(t, 0.5)),
				_fire_color(3, 0.04 * fade))

	# Bright core lingers
	if t < 0.4:
		var core_f: float = 1.0 - t / 0.4
		draw_circle(Vector2.ZERO, lerpf(28.0, 5.0, t / 0.4),
				Color(1.0, 0.88, 0.6, 0.35 * core_f))


func _fire_color(index: int, alpha: float) -> Color:
	var c: Color = FIRE_PALETTE[posmod(index, FIRE_PALETTE.size())]
	c.a = alpha
	return c


func _draw_stealth(t: float) -> void:
	var fade: float = 1.0 - t
	var c: Color = signature_color

	if t < 0.18:
		var ft: float = t / 0.18
		draw_circle(Vector2.ZERO, lerpf(4.0, 28.0, ft),
				Color(c.r, c.g, c.b, (1.0 - ft) * 0.92))

	var sw_t: float = minf(t * 2.2, 1.0)
	draw_arc(Vector2.ZERO, lerpf(10.0, 340.0, pow(sw_t, 0.42)), 0.0, TAU, 44,
			Color(c.r, c.g, c.b, maxf(0.0, 1.0 - sw_t * 2.2) * 0.6), 2.0)
	draw_arc(Vector2.ZERO, lerpf(8.0, 200.0, pow(t, 0.58)), 0.0, TAU, 36,
			Color(c.r, c.g, c.b, fade * 0.85), 2.8)

	for p in _particles:
		var travel_angle: float = p[0]
		var speed: float        = p[1]
		var seg_len: float      = p[2]
		var spin: float         = p[4]
		var delay: float        = p[5]
		var pt: float = clampf(t - delay, 0.0, 1.0)
		if pt <= 0.0:
			continue
		var dist: float = speed * pt * _duration
		var pos: Vector2 = Vector2(cos(travel_angle), sin(travel_angle)) * dist
		var sa: float = travel_angle + spin * pt * _duration
		var sv: Vector2 = Vector2(cos(sa), sin(sa)) * (seg_len * 0.5)
		draw_line(pos - sv, pos + sv, Color(c.r, c.g, c.b, (1.0 - pt) * 0.85), 0.9)

	draw_circle(Vector2.ZERO, lerpf(18.0, 3.0, t), Color(c.r, c.g, c.b, 0.32 * fade))
