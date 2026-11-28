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

const TAP_MS := 130.0
# Both reciprocal sums use the same fixed linear scale at a given viewport size.
const STACK_UNITS := 12.0

var stack_headroom := 0.0 # Space from the diagram to the top of the play screen.
var series := 0
var step := 0
var cell := 3
var pitch := 5
var base_y := 0
var center := 0
var _tapping := false
var _started := 0
var _ready_seen := false

func show_progress(current: int, count: int, _target: int) -> void:
	var tapped := _ready_seen and current == series and count == step + 1
	_ready_seen = true
	series = current
	step = count
	_tapping = tapped and size.x >= 50.0 and not _reduced()
	_started = Time.get_ticks_msec()
	set_process(_tapping)
	queue_redraw()

func _reduced() -> bool:
	return DisplayServer.has_method("accessibility_should_reduce_animation") and int(DisplayServer.accessibility_should_reduce_animation()) > 0 # -1 means unsupported

func _process(_delta: float) -> void:
	if float(Time.get_ticks_msec() - _started) >= _tap_ms():
		_tapping = false
		set_process(false)
	queue_redraw()

func _progress() -> float:
	return float(Time.get_ticks_msec() - _started) if _tapping else 1e9

func _ready() -> void:
	clip_contents = true
	set_process(false)

func _tap_ms() -> float:
	match Growth.key(series):
		"sandpile": return 360.0
		"partitions", "fib": return 300.0
		"lattice_circle", "graphs": return 230.0
	return TAP_MS

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
	base_y = floori(size.y) - cell - 3
	var t := _progress()
	var e := 1.0 - pow(1.0 - clampf(t / _tap_ms(), 0.0, 1.0), 2.0)
	_shape(series, step, step - 1 if _tapping else step, e)

func _stack_width() -> int:
	return floori(minf(size.x * 0.4, 6.0 * pitch) / 2.0) * 2

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
	var unit := (base_y - area.position.y) / STACK_UNITS
	var increment := 1.0 / (sqrt(float(now)) if root else float(now))
	var progress := e if before < now else 1.0
	var total := _sum(now, root) - increment * (1.0 - progress)
	var width := _stack_width()
	var x := center - width / 2
	var top := -stack_headroom
	var height := minf(total * unit, base_y - top)
	if height > 0.0:
		draw_rect(Rect2(x, base_y - height, width, height), DIM)
		var previous_height := (total - increment * progress) * unit
		if height - previous_height >= 1.0:
			draw_rect(Rect2(x, base_y - height, width, height - previous_height), INK)
	var y := float(base_y)
	var complete := now - 1 if before < now and e < 1.0 else now
	for k in range(1, complete + 1):
		var thickness := unit / (sqrt(float(k)) if root else float(k))
		y -= thickness
		if thickness < 2.0 or y <= top:
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
