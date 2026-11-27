extends RefCounted

const Growth = preload("res://growth.gd")
const GOLD := Color("#d9c58b")
const WHITE := Color("#e9e6dd")
const GRAY := Color("#8a8678")
const EDGE := Color("#625744")
const SHADE := Color("#383125")
const GRID := Vector2(72, 25)
const DIGITS := [
	["111", "101", "101", "101", "111"], ["010", "110", "010", "010", "111"],
	["111", "001", "111", "100", "111"], ["111", "001", "111", "001", "111"],
	["101", "101", "111", "001", "001"], ["111", "100", "111", "001", "111"],
	["111", "100", "111", "101", "111"], ["111", "001", "010", "010", "010"],
	["111", "101", "111", "101", "111"], ["111", "101", "111", "001", "111"],
]
const BB4 := ["1RB", "1LB", "1LA", "0LC", "1RZ", "1LD", "1RD", "0RA"]


class PixelPen:
	var canvas: Control
	var unit: float
	var origin: Vector2

	func _init(surface: Control, area: Rect2) -> void:
		canvas = surface
		var fit := minf(area.size.x / GRID.x, area.size.y / GRID.y)
		unit = floorf(fit) if fit >= 1.0 else fit
		origin = (area.get_center() - GRID * unit * 0.5).floor()

	func box(x: float, y: float, w: float, h: float, ink: Color) -> void:
		var start := (origin + Vector2(x, y) * unit).round()
		var end := (origin + Vector2(x + w, y + h) * unit).round()
		canvas.draw_rect(Rect2(start, (end - start).max(Vector2.ONE)), ink)

	func stroke(a: Vector2, b: Vector2, ink: Color = EDGE) -> void:
		canvas.draw_line(
			(origin + a * unit).round(), (origin + b * unit).round(),
			ink, maxf(1.0, unit), false,
		)

	func frame(x: float, y: float, w: float, h: float, ink: Color = EDGE) -> void:
		box(x, y, w, 1, ink)
		box(x, y + h - 1, w, 1, ink)
		box(x, y + 1, 1, h - 2, ink)
		box(x + w - 1, y + 1, 1, h - 2, ink)

	func arrow(x: float, y: float, width: float, ink: Color = GOLD) -> void:
		box(x, y, width, 1, ink)
		box(x + width - 2, y - 1, 1, 3, ink)
		box(x + width - 3, y - 2, 1, 5, ink)

	func arrows_up(x: float, y: float, rank: int, ink: Color) -> void:
		for i in range(rank):
			var left := x + i * 4
			box(left + 1, y, 1, 5, ink)
			box(left, y + 1, 3, 1, ink)

	func dot(x: float, y: float, ink: Color = GOLD) -> void:
		box(x - 1, y - 1, 3, 3, ink)

	func number(x: float, y: float, text: String, ink: Color = GOLD) -> void:
		# Keep an intact 3 × 5 pixel glyph even when the surrounding grid is subpixel.
		var pixel := maxf(1.0, unit)
		var corner := (origin + Vector2(x, y) * unit).round()
		corner.x = minf(corner.x, floorf(origin.x + GRID.x * unit - (text.length() * 4 - 1) * pixel))
		for i in range(text.length()):
			if text[i] == "…":
				for dx in range(3):
					canvas.draw_rect(Rect2(corner + Vector2(i * 4 + dx, 4) * pixel, Vector2.ONE * pixel), ink)
				continue
			var digit := int(text[i])
			for row in range(5):
				for col in range(3):
					if DIGITS[digit][row][col] == "1":
						canvas.draw_rect(Rect2(corner + Vector2(i * 4 + col, row) * pixel, Vector2.ONE * pixel), ink)


static func draw(canvas: Control, key: String, step: int, phase: float, area: Rect2) -> void:
	if area.size.x < 36 or area.size.y < 13:
		return
	var p := PixelPen.new(canvas, area)
	var n := clampi(step, 0, 9007199254740991)
	var ease := clampf(phase, 0, 1)
	match key:
		"fib", "double":
			_copies(p, n, ease, key == "fib")
		"pi_digits":
			_pi(p, n, ease)
		"factorial":
			_insert(p, n, ease)
		"graphs":
			_graph_choices(p, n, ease)
		"square", "growing_power":
			_powers(p, n, ease, key == "square")
		"tower", "tower_double", "tower_in_tower":
			_towers(p, key, n, ease)
		"triple", "quadruple", "quintuple", "sextuple", "variable_arrows":
			_arrow_operation(p, key, n, ease)
		"graham", "conway":
			_feedback(p, key, n)
		"bowers":
			_bowers(p, n, ease)
		"fast_goodstein":
			_rewrite(p, n, ease)
		"tree", "sscg":
			_graph_sequence(p, n, key == "tree")
		"busy_beaver", "beeping_beaver", "oracle_beaver":
			_beaver(p, key, n, ease)
		"rayo":
			_symbol_budget(p, n, ease)
		_:
			return


static func _copies(p: PixelPen, n: int, phase: float, fibonacci: bool) -> void:
	var a := 1
	var b := 1
	# Beyond five inputs the piles show the relation, with a continuation mark.
	for i in range(mini(n, 5)):
		var next := a + b
		a = b
		b = next
	var left_count := mini(a, 6) if fibonacci else 1 << mini(maxi(n - 1, 0), 2)
	var right_count := mini(b, 6) if fibonacci else left_count
	var left_x := 10.0
	var right_x := 22.0
	_pile(p, left_x, 17, left_count, GRAY)
	_pile(p, right_x, 17, right_count, GOLD if fibonacci else GRAY)
	if fibonacci:
		p.box(18, 11, 3, 1, EDGE)
		p.box(19, 10, 1, 3, EDGE)
	p.arrow(33, 11, 9)
	var arrive := lerpf(45.0, 50.0, phase)
	_pile(p, 50 if n == 0 else arrive, 18, left_count, GRAY)
	_pile(p, 58 if n == 0 else arrive + 8, 18, right_count, GOLD if fibonacci else GRAY)
	if n > 3:
		_dots(p, 65, 17)
		if fibonacci:
			p.number(49, 20, _small_number(n + 2), GRAY)
		else:
			p.number(47, 7, "2", GRAY)
			p.number(53, 3, _small_number(n), GOLD)


static func _pile(p: PixelPen, x: float, floor_y: float, amount: int, ink: Color) -> void:
	for i in range(amount):
		p.box(x, floor_y - (i + 1) * 2, 5, 1, ink)


static func _pi(p: PixelPen, n: int, phase: float) -> void:
	var count := mini(n + 1, 7)
	var latest := mini(n, Growth.PI_DIGITS.length() - 1)
	for i in range(count):
		var x := float(6 + i * 8)
		var active := i == count - 1
		var symbol := Growth.PI_DIGITS[latest - count + 1 + i]
		if n >= Growth.PI_DIGITS.length():
			symbol = "…"
		p.frame(x, 7, 7, 12, GOLD if active else EDGE)
		p.number(x + 2, 10 - (1 - phase) * 2 if active else 10.0, symbol, GOLD if active else GRAY)
	if n >= 7:
		_dots(p, 64, 13)
		p.number(55, 20, _small_number(n + 1), GRAY)


static func _insert(p: PixelPen, n: int, phase: float) -> void:
	var slots := mini(n + 3, 7)
	var selected := slots - 1
	for i in range(slots):
		var x := 9 + i * 8
		if i < slots - 1:
			p.box(x + 2, 16, 5, 3, GRAY)
		p.box(x, 17, 1, 2, GOLD if i == selected else EDGE)
	p.box(8 + selected * 8, lerpf(4.0, 12.0, phase), 2, 3, GOLD)
	if n > 4:
		_dots(p, 64, 17)
		p.number(54, 2, _small_number(n + 3), GOLD)


static func _graph_choices(p: PixelPen, n: int, phase: float) -> void:
	var points := [
		Vector2(13, 12), Vector2(18, 5), Vector2(18, 19),
		Vector2(26, 7), Vector2(26, 17), Vector2(32, 12),
	]
	var limit := mini(n + 1, points.size())
	var destination := Vector2(lerpf(62.0, 54.0, phase), 12)
	for i in range(limit):
		if i > 0:
			p.stroke(points[i - 1], points[i])
		p.stroke(points[i], destination, GOLD if i == 0 else SHADE)
		p.dot(points[i].x, points[i].y, GRAY)
	p.dot(destination.x, destination.y, GOLD)
	if n >= points.size():
		_dots(p, 25, 21)
	p.number(50, 4, "2", GRAY)
	p.number(55, 0, _small_number(n + 1), GOLD)


static func _powers(p: PixelPen, n: int, phase: float, square: bool) -> void:
	var amount := mini(n + 2, 5)
	if square:
		_pile(p, 15, 18, amount, GRAY)
		p.arrow(25, 12, 10)
		var lit := amount - 1
		for y in range(amount):
			for x in range(amount):
				var current := y == lit or x == lit
				var y_offset := (1 - phase) * 2 if y == lit else 0.0
				p.box(46 + x * 3, 5 + y * 3 - y_offset, 2, 2, GOLD if current else EDGE)
		if n > 3:
			_dots(p, 64, 18)
			p.number(13, 3, "2", GRAY)
			p.number(18, 0, _small_number(n), GOLD)
		return
	for i in range(amount):
		p.frame(8 + i * 6, 10, 5, 7, GRAY if i < amount - 1 else GOLD)
	p.arrow(40, 12, 7)
	p.frame(51, 10, 7, 9, GRAY)
	p.number(54, 4 - (1 - phase) * 2, _small_number(n + 2), GOLD)


static func _towers(p: PixelPen, key: String, n: int, phase: float) -> void:
	var height := mini(n + 1, 10)
	if key == "tower":
		_stack(p, 36, 20, height, phase)
		if n >= 8:
			p.number(49, 12, _small_number(n + 1), GOLD)
		return
	if key == "tower_double":
		var old_height := 1 << mini(maxi(n - 1, 0), 4)
		var new_height := 1 << mini(n, 4)
		_stack(p, 19, 20, old_height, 1)
		p.arrow(29, 12, 15)
		_stack(p, 54, 20, new_height, phase)
		if n > 3:
			p.number(49, 20, "2", GRAY)
			p.number(54, 16, _small_number(n), GOLD)
		return
	if n < 4:
		height = [2, 4, 16, 16][n]
	_stack(p, 17, 20, mini(n + 1, 7), 1)
	p.stroke(Vector2(24, 13), Vector2(35, 13), GOLD)
	p.stroke(Vector2(35, 13), Vector2(35, 6), GOLD)
	p.arrow(35, 6, 12)
	_stack(p, 55, 20, height, phase)
	if n > 2:
		p.number(7, 20, _small_number(n + 1), GOLD)


static func _stack(p: PixelPen, center: int, floor_y: int, height: int, phase: float) -> void:
	var bands := mini(height, 8)
	for i in range(bands):
		var width := maxi(4, 12 - i)
		var newest := i == bands - 1
		var y := float(floor_y - 2 * (i + 1))
		if newest:
			y -= (1 - phase) * 2
		p.box(center - width * 0.5, y, width, 1, GOLD if newest else GRAY)
		p.box(center - width * 0.5, y + 1, width, 1, SHADE)
	if height > bands:
		_dots(p, center + 8, floor_y - 5)


static func _arrow_operation(p: PixelPen, key: String, n: int, phase: float) -> void:
	var rank := 3
	match key:
		"quadruple":
			rank = 4
		"quintuple":
			rank = 5
		"sextuple":
			rank = 6
		"variable_arrows":
			rank = mini(n + 1, 6)
	var variable := key == "variable_arrows"
	var y := 7.0 - (1 - phase) * 2
	p.number(11, 7, "3" if variable else "2", GRAY)
	p.arrows_up(20, y if variable else 7.0, rank, GOLD)
	p.number(50, 7 if variable else y, "3" if variable else _small_number(n + (1 if rank == 3 else 2)), GRAY)
	if variable:
		if n >= 6:
			_dots(p, 44, 10)
		p.number(29, 15, _small_number(n + 1), GOLD)
	else:
		p.stroke(Vector2(34, 13), Vector2(34, 15), EDGE)
		p.arrows_up(23, 16, rank - 1, GRAY)
		p.arrow(49, 17, 9, EDGE)


static func _feedback(p: PixelPen, key: String, n: int) -> void:
	if key == "conway":
		for i in range(4):
			var x := 10 + 15 * i
			p.number(x, 7, _small_number(n + 1) if i == 2 else "3", GOLD if i == 2 else GRAY)
			if i < 3:
				p.arrow(x + 5, 15, 7, EDGE)
		p.stroke(Vector2(55, 13), Vector2(55, 19), EDGE)
		p.stroke(Vector2(55, 19), Vector2(41, 19), EDGE)
		p.stroke(Vector2(41, 19), Vector2(41, 14), GOLD)
		return
	p.number(9, 6, "3", GRAY)
	p.arrows_up(20, 6, 4, EDGE)
	p.number(39, 6, "3", GRAY)
	p.arrow(45, 8, 8)
	p.frame(53, 4, 17, 9, GOLD)
	p.number(55, 6, _small_number(n), GOLD)
	p.stroke(Vector2(60, 14), Vector2(60, 19), GOLD)
	p.stroke(Vector2(60, 19), Vector2(26, 19), GOLD)
	p.stroke(Vector2(26, 19), Vector2(26, 12), GOLD)


static func _bowers(p: PixelPen, n: int, phase: float) -> void:
	var amount := mini(n + 2, 5)
	p.frame(6, 7, 25, 10, EDGE)
	for i in range(amount):
		p.box(9 + 4 * i, 10, 2, 4, GOLD if i == amount - 1 else GRAY)
	p.arrow(34, 12, 8)
	p.frame(45, 4, 20, 16, GOLD)
	for y in range(2):
		for x in range(3):
			var active := x == 2 and y == 1
			p.frame(48 + x * 5, 7 + y * 5 - (1 - phase) if active else 7 + y * 5, 4, 4, WHITE if active else EDGE)
	if n > 3:
		p.number(10, 20, _small_number(n + 2), GOLD)


static func _rewrite(p: PixelPen, n: int, phase: float) -> void:
	p.frame(7, 6, 19, 13, EDGE)
	p.frame(46, 6, 19, 13, EDGE)
	p.number(11, 0, "2", GRAY)
	p.number(50, 0, "3", GOLD)
	for i in range(4):
		p.box(11 + 3 * i, 10 - i, 2, 7 + i, GRAY)
		if i != 3:
			p.box(50 + 3 * i, 10 - i, 2, 7 + i, GOLD)
		else:
			p.box(50 + 3 * i, lerpf(13.0, 20.0, phase), 2, 1, EDGE)
	p.arrow(30, 12, 12)
	p.number(30, 18, _small_number(n + 1), GRAY)


static func _graph_sequence(p: PixelPen, n: int, trees: bool) -> void:
	if trees:
		p.dot(11, 11, GOLD)
		if n > 0:
			p.stroke(Vector2(28, 7), Vector2(28, 16), EDGE)
			p.dot(28, 7, WHITE)
			p.dot(28, 16, WHITE)
			p.dot(42, 11, WHITE)
		if n > 1:
			p.stroke(Vector2(58, 6), Vector2(52, 16), EDGE)
			p.stroke(Vector2(58, 6), Vector2(64, 16), EDGE)
			p.dot(58, 6, GRAY)
			p.dot(52, 16, WHITE)
			p.dot(64, 16, GOLD)
			_dots(p, 64, 20)
		if n > 2:
			p.number(8, 19, _small_number(n + 1), GOLD)
		return
	# One representative subcubic graph followed by smaller candidates.
	var points := [Vector2(12, 8), Vector2(23, 8), Vector2(12, 17), Vector2(23, 17)]
	for edge in [[0, 1], [0, 2], [1, 3], [2, 3], [1, 2]]:
		p.stroke(points[edge[0]], points[edge[1]], EDGE)
	for i in range(points.size()):
		p.dot(points[i].x, points[i].y, GRAY)
	p.arrow(31, 12, 9, EDGE)
	var limit := mini(2 + n, 5)
	for i in range(limit):
		p.dot(46 + i * 4, 11, GOLD if i == limit - 1 else GRAY)
	# P + n is the vertex allowance carried from TREE.
	p.frame(45, 17, 4, 3, GRAY)
	p.box(45, 20, 1, 2, GRAY)
	p.box(51, 19, 3, 1, EDGE)
	p.box(52, 18, 1, 3, EDGE)
	p.number(57, 17, _small_number(n), GOLD)


static func _beaver(p: PixelPen, key: String, n: int, phase: float) -> void:
	var actual := key == "busy_beaver" and n <= 107
	var machine := _busy_tape(n) if actual else {}
	var tape: Dictionary = machine.get("tape", {})
	var head := int(machine.get("head", 0))
	var tape_y := 12 if key == "oracle_beaver" else 8
	for i in range(9):
		var x := 10 + i * 6
		var value := int(tape.get(head - 4 + i, 0))
		p.frame(x, tape_y, 5, 7, GOLD if i == 4 else EDGE)
		if value != 0:
			p.box(x + 1, tape_y + 2, 3, 3, GOLD if i == 4 else GRAY)
	p.box(35, tape_y - 3 - (1 - phase) * 2, 3, 2, WHITE)
	if key == "beeping_beaver":
		for i in range(5):
			p.box(26 + 4 * i, 18 - i % 3, 2, 1 + i % 3, GOLD if i == 4 else EDGE)
		p.number(53, 17, _small_number(n + 1), GOLD)
	elif key == "oracle_beaver":
		p.frame(23, 2, 26, 5, EDGE)
		p.stroke(Vector2(36, 7), Vector2(36, 10), GOLD)
		p.box(35, 4 + (1 - phase) * 4, 2, 1, GOLD)
		p.number(53, 20, _small_number(n + 1), GOLD)
	elif actual:
		var state := int(machine.get("state", -1))
		for i in range(4):
			p.box(29 + 4 * i, 17, 2, 2, GOLD if i == state else EDGE)
		if state < 0:
			p.box(46, 17, 3, 2, WHITE)
		p.number(53, 17, _small_number(n), GRAY)
	else:
		p.number(53, 17, _small_number(n - 103), GOLD)


static func _busy_tape(steps: int) -> Dictionary:
	# The proven four-state champion, from a blank tape until it halts at step 107.
	var tape := {}
	var head := 0
	var state := 0
	for i in range(mini(steps, 107)):
		var instruction: String = BB4[state * 2 + int(tape.get(head, 0))]
		tape[head] = int(instruction[0])
		head += 1 if instruction[1] == "R" else -1
		state = "ABCD".find(instruction[2])
		if state < 0:
			break
	return {"tape": tape, "head": head, "state": state}


static func _symbol_budget(p: PixelPen, n: int, phase: float) -> void:
	var length := mini(8, n)
	p.frame(8, 7, 32, 12, EDGE)
	for i in range(length):
		var x := 11 + i * 3
		var y := 11.0 - (1 - phase) * 2 if i == length - 1 else 11.0
		p.box(x, y, 1, 4, GOLD if i == length - 1 else GRAY)
	var length_text := _small_number(n)
	p.number(52, 11, length_text, GRAY)
	if n > 8:
		_dots(p, 44, 13)


static func _small_number(n: int) -> String:
	var text := str(n)
	return "…" + text.right(2) if text.length() > 4 else text


static func _dots(p: PixelPen, x: float, y: float) -> void:
	for i in range(3):
		p.box(x + 2 * i, y, 1, 1, GOLD)
