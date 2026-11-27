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
# Both reciprocal sums use the same fixed linear scale at a given viewport size.
const STACK_RANGE := 12.0

var series := 0
var step := 0
var mark := 0 # notches on the newest base brick; 0 = none. Set by main before show_progress.
var _from_step := 0
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

func show_progress(current: int, count: int, _target: int) -> void:
	var tapped := _ready_seen and current == series and count == step + 1
	# Only the opening polygon physically becomes the first foundation brick.
	var first_brick := _ready_seen and series == 0 and current == 1
	if first_brick:
		_from_step = step
	_kind = 1 if tapped else (2 if first_brick else 0)
	_ready_seen = true
	series = current
	step = count
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
	_shape(series, step, step - 1 if _kind == 1 else step, e)

func _draw_leap(t: float) -> void:
	var hover := Vector2(center, base_y - 4 * pitch)
	var side := 2.0 * cell
	var hover_rect := Rect2(hover - Vector2.ONE * side / 2.0, Vector2.ONE * side)
	if t < COMPRESS_MS:
		var e := 1.0 - pow(1.0 - t / COMPRESS_MS, 2.0)
		_ground(0, false, 0)
		# Asymmetric squash (height collapses first); the anchor travels from its original spot to the hover, so frame 0 is unchanged.
		var scale := Vector2(lerpf(1.0, 0.1, e), lerpf(1.0, 0.1, minf(1.0, e * 1.6)))
		var anchor := _area().get_center()
		draw_set_transform(anchor.lerp(hover, e) - anchor * scale, 0.0, scale)
		_draw_circle(_from_step, _from_step, 1.0)
		draw_set_transform(Vector2.ZERO)
		var grown := clampf((e - 0.4) / 0.6, 0.0, 1.0)
		var small := Vector2.ONE * side * lerpf(0.1, 1.0, grown)
		if grown > 0.0:
			_brick(Rect2(hover - small / 2.0, small), signature(0, _from_step))
		return
	var fall := clampf((t - COMPRESS_MS) / (LEAP_MS - COMPRESS_MS), 0.0, 1.0)
	_ground(series, true, mark)
	_shape(series, step, step, 1.0)
	var slot := _slot(series, series - 1)
	var rect := Rect2(hover_rect.position.lerp(slot.position, fall * fall), hover_rect.size.lerp(slot.size, fall * fall))
	_brick(rect, mark if mark > 0 else signature(0, _from_step))

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

func _shape(count: int, now: int, before: int, e: float) -> void:
	var area := _area()
	if area.size.y < 12.0 or area.size.x < 30.0:
		return
	if count == 0:
		_draw_circle(now, before, e)
	elif count <= 2:
		_draw_stack(now, before, e, count == 2)
	elif count < 14:
		Early.draw(self, Growth.key(count), now, before, e, area)
	else:
		Large.draw(self, Growth.key(count), now, e, area)

func _draw_circle(now: int, before: int, e: float) -> void:
	var area := _area()
	var middle := area.get_center()
	var radius := minf(area.size.x * 0.36, area.size.y * 0.46)
	draw_arc(middle, radius, 0.0, TAU, 128, OUTLINE, 1.2, true)
	var sides := 2 << mini(now, 12)
	var old_half_angle := TAU / sides
	# Once even the parent chord departs from the circle by less than a
	# fraction of a pixel, its bisection has no perceptible motion here.
	if radius * (1.0 - cos(old_half_angle)) < 0.20:
		draw_arc(middle, radius, 0.0, TAU, 160, INK, 2.2, true)
	else:
		var outline := PackedVector2Array()
		for i in range(sides + 1):
			outline.append(middle + Vector2.from_angle(TAU * i / sides) * radius)
		if before < now:
			for i in range(1, sides, 2):
				outline[i] = ((outline[i - 1] + outline[i + 1]) * 0.5).lerp(outline[i], e)
		draw_polyline(outline, INK, 2.2, true)
		if sides <= 8:
			for i in sides:
				draw_circle(outline[i], 2.8, WHITE, true, -1.0, true)
	draw_circle(middle, 1.4, DIM, true, -1.0, true)

# The bottom and scale are independent of the number of taps. Grow the actual
# tip of the sum; once it leaves this view, the existing layers stay put.
func _draw_stack(now: int, before: int, e: float, root: bool) -> void:
	if now == 0:
		return
	var area := _area()
	var unit := (base_y - area.position.y) / STACK_RANGE
	var total := _sum(now, root)
	if before < now:
		var increment := 1.0 / (sqrt(float(now)) if root else float(now))
		total -= increment * (1.0 - e)
	var width := _stack_width()
	var x := center - width / 2
	var height := minf(total, STACK_RANGE) * unit
	if height > 0.0:
		draw_rect(Rect2(x, base_y - height, width, height), DIM)
	var y := float(base_y)
	var complete := now - 1 if before < now and e < 1.0 else now
	for k in range(1, complete + 1):
		var thickness := unit / (sqrt(float(k)) if root else float(k))
		y -= thickness
		if thickness < 2.0 or y <= area.position.y:
			break
		draw_line(Vector2(x, y), Vector2(x + width, y), INK, 1.0)

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
