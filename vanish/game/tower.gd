extends Control

const INK := Color("#d9c58b")
const DIM := Color("#988764")
const FILL := Color("#4b4130")
const SHADE := Color("#24201a")
const OUTLINE := Color("#625744")
const WHITE := Color("#e9e6dd")

var series := 0
var step := 0
var goal := 1

func show_progress(current: int, count: int, target: int) -> void:
	series = current
	step = count
	goal = maxi(1, target)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x < 50.0 or size.y < 20.0:
		return
	if series == 0:
		_draw_circle()
	else:
		_draw_tower()

func _draw_circle() -> void:
	var radius := floorf(minf(size.x * 0.36, size.y * 0.44))
	var center := Vector2(floorf(size.x / 2.0), floorf(size.y / 2.0))
	var pixel := maxf(2.0, floorf(radius / 28.0))
	var sides := 2 << mini(step, 6)
	draw_arc(center, radius, 0.0, TAU, 100, OUTLINE, 1.0)
	var outline := PackedVector2Array()
	for i in range(sides + 1):
		var angle := TAU * float(i) / sides
		var coordinate := (Vector2.from_angle(angle) * (radius / pixel)).round() * pixel
		outline.append(center + coordinate)
	for i in range(sides):
		_pixel_line(outline[i], outline[i + 1], pixel)
	if sides <= 8:
		for i in range(sides):
			draw_rect(Rect2(outline[i] - Vector2.ONE * pixel, Vector2.ONE * pixel * 2.0), INK)
	# The stationary center is an anchor while the old chord splits in two.
	draw_rect(Rect2(center - Vector2.ONE * pixel / 2.0, Vector2.ONE * pixel), DIM)

func _pixel_line(from: Vector2, to: Vector2, pixel: float) -> void:
	var steps := maxi(1, ceili(maxf(absf(to.x - from.x), absf(to.y - from.y)) / pixel))
	for i in range(steps + 1):
		var point := (from.lerp(to, float(i) / steps) / pixel).round() * pixel
		draw_rect(Rect2(point, Vector2.ONE * pixel), INK)

func _draw_tower() -> void:
	var center := floori(size.x / 2.0)
	var cell := clampi(floori(minf(size.x / 31.0, size.y / 13.0)), 3, 18)
	var pitch := cell + 2
	var base_y := floori(size.y) - cell * 2 - 3
	var platform_span := floori(minf(size.x * 0.32, 290.0))
	draw_rect(Rect2(center - platform_span, base_y + cell, 2 * platform_span, cell), SHADE)
	draw_rect(Rect2(center - platform_span + cell, base_y + cell / 2.0, 2 * (platform_span - cell), cell), FILL)
	draw_rect(Rect2(center - platform_span + cell * 2, base_y + cell / 2.0, 2 * (platform_span - cell * 2), 1), OUTLINE)
	var base_count := series
	var base_pitch := mini(cell + 2, maxi(5, floori(size.x * 0.82 / base_count)))
	var base_width := base_pitch * base_count - 2
	var base_left := center - floori(base_width / 2.0)
	for i in range(base_count):
		var x := base_left + i * base_pitch
		draw_rect(Rect2(x, base_y, base_pitch - 2, cell), DIM)
		draw_rect(Rect2(x, base_y, base_pitch - 2, 1), INK)
	var max_rows := maxi(2, floori(float(base_y - 4) / pitch))
	var cells: Array[Vector2i] = []
	for row in range(max_rows):
		var span := _half_width(row, max_rows)
		for col in range(-span, span + 1):
			if series >= 25 and row >= max_rows * 0.58 and absi(col) <= 1:
				continue
			cells.append(Vector2i(col, row))
	var fraction := clampf(float(step) / float(goal), 0.0, 1.0)
	var filled := mini(cells.size(), ceili(fraction * cells.size()))
	for row in range(0, max_rows, 3):
		var span := _half_width(row, max_rows)
		var guide_y := base_y - (row + 1) * pitch
		for side: int in [-1, 1]:
			var guide_x := center + side * span * pitch - floori(cell / 2.0)
			draw_rect(Rect2(guide_x, guide_y, cell, 2), OUTLINE)
	for i in range(filled):
		var tile := cells[i]
		var x := center + tile.x * pitch - floori(cell / 2.0)
		var y := base_y - (tile.y + 1) * pitch
		_draw_tile(x, y, cell, i == filled - 1)
	if filled == 0:
		draw_rect(Rect2(center - floori(cell / 2.0), base_y - pitch, cell, cell), SHADE)
	var person_x := center + 9 * pitch
	if person_x + 12 < size.x:
		draw_rect(Rect2(person_x, base_y - 12, 5, 5), WHITE)
		draw_rect(Rect2(person_x - 2, base_y - 7, 9, 3), WHITE)
		draw_rect(Rect2(person_x, base_y - 4, 2, 5), WHITE)
		draw_rect(Rect2(person_x + 4, base_y - 4, 2, 5), WHITE)

func _half_width(row: int, total: int) -> int:
	var height_ratio := float(row) / total
	if series >= 25:
		return 11 if height_ratio < 0.36 else 7
	if series >= 17:
		return 10 if height_ratio < 0.30 else (7 if height_ratio < 0.68 else 4)
	return 8 if height_ratio < 0.27 else (6 if height_ratio < 0.74 else 3)

func _draw_tile(x: int, y: int, cell: int, last: bool) -> void:
	draw_rect(Rect2(x, y, cell, cell), INK if last else FILL)
	if not last:
		draw_rect(Rect2(x, y, cell, 1), DIM)
