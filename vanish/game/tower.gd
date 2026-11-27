extends Control

const INK := Color("#d9c58b")
const DIM := Color("#988764")
const FILL := Color("#4b4130")
const SHADE := Color("#24201a")
const OUTLINE := Color("#625744")
const WHITE := Color("#e9e6dd")
const Growth = preload("res://growth.gd")
const Early = preload("res://early_patterns.gd")
const Large = preload("res://large_patterns.gd")

const BRICK := Color("#8a8678")
const HATCH := Color("#4a483f")
const LEAP_MS := 400.0
const COMPRESS_MS := 150.0
const TAP_MS := 130.0

var series := 0
var step := 0
var goal := 1
var mark := 0 # notches on the newest base brick; 0 = none. Set by main before show_progress.
var _from_series := 0
var _from_step := 0
var _from_goal := 1
var _from_mark := 0
var _seen_mark := 0
var _from_ground := 0
var cell := 3
var pitch := 5
var base_y := 0
var center := 0
var _kind := 0 # 0 idle, 1 tap, 2 leap
var _started := 0
var _ready_seen := false

static func signature(stage: int, count: int) -> int:
	# π: the polygon's side count. Other stages are incomparable, so only a stage-keyed tick count.
	return 2 << mini(count, 6) if stage == 0 else 3 + stage % 5

func show_progress(current: int, count: int, target: int) -> void:
	var tapped := _ready_seen and current == series and count == step + 1
	var leaped := _ready_seen and current > series
	if tapped or leaped:
		_from_series = series
		_from_step = step
		_from_goal = goal
		_from_mark = signature(series, step)
		_from_ground = _seen_mark
	# A new event always supersedes the old one: its end state is the current state, so nothing is queued or lost.
	_kind = 1 if tapped else (2 if leaped else 0)
	_ready_seen = true
	series = current
	step = count
	goal = maxi(1, target)
	_seen_mark = mark
	if _kind != 0 and (_reduced() or size.x < 50.0):
		_kind = 0
	_started = Time.get_ticks_msec()
	set_process(_kind != 0)
	queue_redraw()

func _reduced() -> bool:
	return DisplayServer.has_method("accessibility_should_reduce_animation") and int(DisplayServer.accessibility_should_reduce_animation()) > 0 # -1 means unsupported

func _process(_delta: float) -> void:
	if float(Time.get_ticks_msec() - _started) >= (LEAP_MS if _kind == 2 else _tap_ms()):
		_kind = 0
		set_process(false)
	queue_redraw()

func _progress() -> float:
	return float(Time.get_ticks_msec() - _started) if _kind != 0 else 1e9

func _ready() -> void:
	clip_contents = true
	set_process(false)

func _tap_ms() -> float:
	return 360.0 if Growth.key(series) == "sandpile" else TAP_MS # a topple cascade needs time to be read

func _area() -> Rect2:
	var margin := maxf(6.0, float(cell))
	return Rect2(margin, 4.0, size.x - 2.0 * margin, maxf(0.0, base_y - 7.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x < 50.0 or size.y < 20.0:
		return
	center = floori(size.x / 2.0)
	cell = clampi(floori(minf(size.x / 31.0, size.y / 13.0)), 3, 18)
	pitch = cell + 2
	base_y = floori(size.y) - cell * 2 - 3
	var t := _progress()
	if _kind == 2:
		_draw_leap(t)
		return
	var e := 1.0 - pow(1.0 - clampf(t / _tap_ms(), 0.0, 1.0), 2.0)
	_ground(series, false, mark)
	_shape(series, step, goal, step - 1 if _kind == 1 else step, e)

func _draw_leap(t: float) -> void:
	var hover := Vector2(center, base_y - 4 * pitch)
	var side := 2.0 * cell
	var hover_rect := Rect2(hover - Vector2.ONE * side / 2.0, Vector2.ONE * side)
	if t < COMPRESS_MS:
		var e := 1.0 - pow(1.0 - t / COMPRESS_MS, 2.0)
		_ground(_from_series, false, _from_ground)
		# Asymmetric squash (height collapses first); the anchor travels from its original spot to the hover, so frame 0 is unchanged.
		var scale := Vector2(lerpf(1.0, 0.1, e), lerpf(1.0, 0.1, minf(1.0, e * 1.6)))
		var anchor := _anchor()
		draw_set_transform(anchor.lerp(hover, e) - anchor * scale, 0.0, scale)
		_shape(_from_series, _from_step, _from_goal, _from_step, 1.0)
		draw_set_transform(Vector2.ZERO)
		var grown := clampf((e - 0.4) / 0.6, 0.0, 1.0)
		var small := Vector2.ONE * side * lerpf(0.1, 1.0, grown)
		if grown > 0.0:
			_brick(Rect2(hover - small / 2.0, small), _from_mark)
		return
	var fall := clampf((t - COMPRESS_MS) / (LEAP_MS - COMPRESS_MS), 0.0, 1.0)
	_ground(series, true, mark)
	_shape(series, step, goal, step, 1.0)
	var slot := _slot(series, series - 1)
	var rect := Rect2(hover_rect.position.lerp(slot.position, fall * fall), hover_rect.size.lerp(slot.size, fall * fall))
	_brick(rect, mark if mark > 0 else _from_mark)

func _anchor() -> Vector2:
	if _from_series == 1 or _from_series == 2:
		var filled := _sum(mini(_from_step, _from_goal), _from_series == 2) / _sum(_from_goal, _from_series == 2)
		return Vector2(center, base_y - (base_y - 4) * filled / 2.0)
	return _area().get_center() if _from_series > 2 else size / 2.0

func _stack_width() -> int:
	return floori(minf(size.x * 0.4, 6.0 * pitch) / 2.0) * 2

func _slot(count: int, index: int) -> Rect2:
	if count == 1: # the first souvenir is a slab under the harmonic stack
		return Rect2(center - _stack_width() / 2, base_y, _stack_width(), cell)
	var base_pitch := mini(pitch, maxi(5, floori(size.x * 0.82 / maxi(1, count))))
	var left := center - floori((base_pitch * count - 2) / 2.0)
	return Rect2(left + index * base_pitch, base_y, base_pitch - 2, cell)

func _ground(count: int, hide_last: bool, notches: int) -> void:
	var platform_span := floori(minf(size.x * 0.32, 290.0))
	draw_rect(Rect2(center - platform_span, base_y + cell, 2 * platform_span, cell), SHADE)
	draw_rect(Rect2(center - platform_span + cell, base_y + cell / 2.0, 2 * (platform_span - cell), cell), FILL)
	draw_rect(Rect2(center - platform_span + cell * 2, base_y + cell / 2.0, 2 * (platform_span - cell * 2), 1), OUTLINE)
	for i in range(count):
		var slot := _slot(count, i)
		if i == count - 1 and notches > 0:
			if not hide_last:
				_brick(slot, notches)
			continue
		draw_rect(slot, DIM)
		draw_rect(Rect2(slot.position, Vector2(slot.size.x, 1)), INK)

# The gray brick: diagonal hatch plus one dark notch per signature step around its edge.
func _brick(rect: Rect2, notches: int) -> void:
	var r := Rect2i(rect.position.round(), Vector2i(maxi(2, roundi(rect.size.x)), maxi(2, roundi(rect.size.y))))
	draw_rect(r, BRICK)
	for c in range(0, r.size.x + r.size.y - 1, 3): # diagonals x+y=c, clipped to the brick
		var a := maxi(0, c - r.size.y + 1)
		var b := mini(r.size.x - 1, c)
		draw_line(Vector2(r.position) + Vector2(a + 0.5, c - a + 0.5), Vector2(r.position) + Vector2(b + 0.5, c - b + 0.5), HATCH)
	var dot := clampi(r.size.y / 4, 1, 3)
	var perimeter := 2 * (r.size.x + r.size.y)
	var count := mini(notches, perimeter / 2)
	for i in range(count):
		var d := floori(float(i) * perimeter / count)
		var point := Vector2i(d, 0)
		if d >= r.size.x + r.size.y + r.size.x:
			point = Vector2i(0, perimeter - d - 1)
		elif d >= r.size.x + r.size.y:
			point = Vector2i(r.size.x - 1 - (d - r.size.x - r.size.y), r.size.y - 1)
		elif d >= r.size.x:
			point = Vector2i(r.size.x - 1, d - r.size.x)
		draw_rect(Rect2(Vector2i(r.position) + point.clamp(Vector2i.ZERO, r.size - Vector2i.ONE * dot), Vector2.ONE * dot), SHADE)

func _shape(count: int, now: int, target: int, before: int, e: float) -> void:
	var area := _area()
	if area.size.y < 12.0 or area.size.x < 30.0:
		return
	if count == 0:
		_draw_circle(now, before, e)
	elif count <= 2:
		_draw_stack(now, target, before, e, count == 2)
	elif count < 14:
		Early.draw(self, Growth.key(count), now, before, e, area)
	else:
		Large.draw(self, Growth.key(count), now, e, area)

func _draw_circle(now: int, before: int, e: float) -> void:
	var area := _area()
	var middle := area.get_center()
	var radius := minf(area.size.x * 0.36, area.size.y * 0.46)
	# Once chords are indistinguishable at pixel scale, keep the whole circle
	# in view and magnify the actual operation on one of its edges.
	if now > 3:
		var opening := e if before == 3 else 1.0
		middle.x = lerpf(middle.x, area.position.x + area.size.x * 0.25, opening)
		radius = lerpf(radius, minf(radius, area.size.x * 0.18), opening)
		var source := middle + radius * Vector2.from_angle(-PI / 4)
		var focus := area.position + area.size * Vector2(0.54, 0.55)
		if opening > 0.65:
			draw_dashed_line(source, focus, OUTLINE, 1.0, 4.0)
			draw_circle(source, 2.3, WHITE, true, -1.0, true)
		_draw_bisection(area, now, e)
	draw_arc(middle, radius, 0.0, TAU, 128, OUTLINE, 1.2, true)
	# Once the polygon's error is subpixel, its overview is its limiting
	# circle. The local diagram continues to show the actual subdivision.
	var edge := INK.lerp(WHITE, 0.40 * (1.0 - e)) if before < now else INK
	if now > 6:
		draw_arc(middle, radius, 0.0, TAU, 160, edge, 2.0, true)
	else:
		var sides := 2 << now
		var outline := PackedVector2Array()
		for i in range(sides + 1):
			outline.append(middle + Vector2.from_angle(TAU * i / sides) * radius)
		if before < now:
			for i in range(1, sides, 2):
				outline[i] = ((outline[i - 1] + outline[i + 1]) * 0.5).lerp(outline[i], e)
		draw_polyline(outline, edge, 2.2, true)
		if sides <= 8:
			for i in sides:
				draw_circle(outline[i], 2.8, WHITE, true, -1.0, true)
	draw_circle(middle, 1.4, DIM, true, -1.0, true)

# In the detail the horizontal chord and its sagitta are normalized separately.
func _draw_bisection(area: Rect2, now: int, e: float) -> void:
	var view := Rect2(area.position + area.size * Vector2(0.54, 0.18), area.size * Vector2(0.42, 0.60))
	var y := view.position.y + view.size.y * 0.61
	var rise := maxf(3.0, view.size.y * 0.44)
	var left := Vector2(view.position.x, y)
	var right := Vector2(view.end.x, y)
	var crest := Vector2(view.get_center().x, y - rise)
	var half_angle := PI * pow(0.5, now)
	var cosine := cos(half_angle)
	var sine := sin(half_angle)
	var arc := PackedVector2Array()
	for i in 25:
		var x := (i - 12.0) / 12.0
		# Rationalized circular sagitta stays well-conditioned even at radii
		# where directly subtracting cosines would give zero.
		var height := (1.0 - x * x) * (1.0 + cosine) / (sqrt(1.0 - x * x * sine * sine) + cosine)
		arc.append(Vector2(lerpf(left.x, right.x, i / 24.0), y - rise * height))
	draw_polyline(arc, OUTLINE, 1.2, true)
	draw_line(left, right, HATCH, 1.0, true)
	var midpoint := ((left + right) * 0.5).lerp(crest, e)
	draw_line(left, midpoint, INK, 2.0, true)
	draw_line(midpoint, right, INK, 2.0, true)
	draw_circle(midpoint, 2.4, WHITE, true, -1.0, true)
	_math_label("2^%d 邊 · 弦高放大" % (now + 1), view, y)

func _math_label(value: String, area: Rect2, y: float) -> void:
	var font := get_theme_default_font()
	var pixels := clampi(floori(area.size.y * 0.20), 11, 20)
	while pixels > 8 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > area.size.x:
		pixels -= 1
	var diagram_area := _area()
	var baseline := clampf(y + font.get_ascent(pixels) + 4, diagram_area.position.y + font.get_ascent(pixels), diagram_area.end.y - font.get_descent(pixels))
	draw_string(font, Vector2(area.position.x, baseline).round(), value, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, pixels, DIM)

# At the gate the whole stack fits. Beyond it the viewport zooms out;
# older layers remain in the stack even when their boundaries share a pixel.
func _draw_stack(now: int, target: int, before: int, e: float, root: bool) -> void:
	if now == 0:
		return
	var area := _area()
	var latest := 1.0 / (sqrt(float(now)) if root else float(now))
	var total := _sum(now, root)
	if before < now:
		total -= latest * (1.0 - e)
	var unit := (base_y - area.position.y) / maxf(_sum(target, root), total)
	var width := _stack_width()
	var x := center - width / 2
	var top := base_y - roundf(total * unit)
	if top < base_y:
		draw_rect(Rect2(x, top, width, base_y - top), DIM)
	var subtotal := 0.0
	var last_y := float(base_y)
	for k in range(1, mini(now - 1, 96) + 1):
		subtotal += 1.0 / (sqrt(float(k)) if root else float(k))
		var y := base_y - roundf(subtotal * unit)
		if last_y - y > 2:
			draw_line(Vector2(x, y), Vector2(x + width - 1, y), INK)
		last_y = y
	# After individual boundaries crowd together, mark cumulative totals at
	# 128, 256, ... layers. This keeps the overview readable as it zooms out.
	var boundary := 128
	while boundary < now:
		var y := base_y - roundf(_sum(boundary, root) * unit)
		if last_y - y > 2:
			draw_line(Vector2(x, y), Vector2(x + width - 1, y), HATCH)
			last_y = y
		if boundary > (now >> 1):
			break
		boundary *= 2
	var height := minf(base_y - top, maxf(1.0, roundf(unit * latest * e)))
	if height > 0:
		draw_rect(Rect2(x, top, width, height), INK)
		draw_line(Vector2(x, top), Vector2(x + width - 1, top), WHITE)
	if now > target:
		# Draw the newest layer at its own scale, even for subpixel increments.
		var inset := Rect2(area.position + area.size * Vector2(0.67, 0.27), area.size * Vector2(0.30, 0.43))
		var mid_y := inset.get_center().y
		draw_dashed_line(Vector2(x + width, top), Vector2(inset.position.x, mid_y), OUTLINE, 1.0, 4.0)
		var label_y := clampf(inset.size.y * 0.16, 3.0, 12.0)
		var previous := 1.0 / (sqrt(now - 1.0) if root else (now - 1.0))
		var reference_height := unit * latest
		var power := maxi(0, ceili(log(label_y / reference_height) / log(2.0)))
		var prev_power := maxi(0, ceili(log(label_y / (unit * previous)) / log(2.0)))
		var zoom := pow(2.0, lerpf(prev_power, power, e))
		var older_h := previous * unit * zoom
		var newer_h := reference_height * zoom
		draw_rect(Rect2(inset.position.x, mid_y, inset.size.x, older_h), HATCH)
		if e > 0.0:
			draw_rect(Rect2(inset.position.x, mid_y - newer_h - 1.0, inset.size.x * e, newer_h), INK)
		var scale_text := "×%s" % (str(roundi(zoom)) if zoom < 1.0e15 else "2^%d" % power)
		_math_label(scale_text, inset, mid_y - newer_h - 27.0)
		_math_label(("1/√%d" if root else "1/%d") % now, inset, mid_y + older_h)

# Only for screen geometry: integrate the tail at cell midpoints. Work is
# bounded even if a player spends the entire session in one series.
func _sum(n: int, root: bool) -> float:
	var terms := mini(n, 96)
	var total := 0.0
	for k in range(1, terms + 1):
		total += 1.0 / (sqrt(float(k)) if root else float(k))
	if n > terms:
		if root:
			total += 2.0 * (sqrt(n + 0.5) - sqrt(terms + 0.5))
		else:
			total += log((n + 0.5) / (terms + 0.5))
	return total
