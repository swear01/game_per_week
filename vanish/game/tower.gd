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
	var radius := floorf(minf(size.x * 0.36, size.y * 0.44))
	var middle := Vector2(floorf(size.x / 2.0), floorf(size.y / 2.0))
	var pixel := maxf(2.0, floorf(radius / 28.0))
	var sides := 2 << mini(now, 6)
	draw_arc(middle, radius, 0.0, TAU, 100, OUTLINE, 1.0)
	var outline := PackedVector2Array()
	for i in range(sides + 1):
		var coordinate := (Vector2.from_angle(TAU * float(i) / sides) * (radius / pixel)).round() * pixel
		outline.append(middle + coordinate)
	if before < now and 2 << mini(before, 6) < sides:
		# New vertices start on the old chords' midpoints and slide out to the circle.
		for i in range(1, sides, 2):
			outline[i] = ((outline[i - 1] + outline[i + 1]) / 2.0).lerp(outline[i], e)
	var edge := INK.lerp(WHITE, 0.65 * (1.0 - e)) if before < now else INK
	for i in range(sides):
		_pixel_line(outline[i], outline[i + 1], pixel, edge)
	if sides <= 8:
		for i in range(sides):
			draw_rect(Rect2(outline[i] - Vector2.ONE * pixel, Vector2.ONE * pixel * 2.0), INK)
	# The stationary center is an anchor while the old chord splits in two.
	draw_rect(Rect2(middle - Vector2.ONE * pixel / 2.0, Vector2.ONE * pixel), DIM)

func _pixel_line(from: Vector2, to: Vector2, pixel: float, edge: Color) -> void:
	var steps := maxi(1, ceili(maxf(absf(to.x - from.x), absf(to.y - from.y)) / pixel))
	for i in range(steps + 1):
		var point := (from.lerp(to, float(i) / steps) / pixel).round() * pixel
		draw_rect(Rect2(point, Vector2.ONE * pixel), edge)

# Keep the newest layers in view after the gate. Their height still represents
# the actual increment; a subpixel layer enters as a single growing scanline.
func _draw_stack(now: int, target: int, before: int, e: float, root: bool) -> void:
	var unit := float(base_y - 4) / _sum(target, root)
	var width := _stack_width()
	var x := center - width / 2
	var y := float(base_y)
	var first := maxi(1, now - target + 1)
	var entering := before < now and e < 1.0
	if entering and first > 1:
		var departing := first - 1
		var tail_height := maxf(1.0, roundf(unit / (sqrt(departing) if root else departing)))
		y -= tail_height * (1.0 - e)
		draw_rect(Rect2(x, y, width, base_y - y), DIM)
	for k in range(first, now + 1):
		if y <= 0.0:
			break
		var height := maxf(1.0, roundf(unit / (sqrt(k) if root else k)))
		var top_width := width
		if k == now and entering:
			height = maxf(1.0, roundf(height * e))
			top_width = maxi(1, roundi(width * e))
		height = minf(y, height)
		y -= height
		draw_rect(Rect2(x, y, top_width, height), INK if k == now else DIM)
		if height > 2.0:
			draw_rect(Rect2(x, y, top_width, 1), WHITE if k == now else INK)

func _sum(n: int, root: bool) -> float:
	var total := 0.0
	for k in range(1, n + 1):
		total += 1.0 / (sqrt(k) if root else k)
	return total
