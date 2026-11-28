extends RefCounted

const Growth = preload("res://growth.gd")
const GOLD := Color("#d9c58b")
const WHITE := Color("#e9e6dd")
const GRAY := Color("#8a8678")
const EDGE := Color("#625744")
const SHADE := Color("#383125")
const GRID := Vector2(72, 25)
const FIB_PITCH := 2.55
const BB4 := ["1RB", "1LB", "1LA", "0LC", "1RZ", "1LD", "1RD", "0RA"]


class Diagram:
	var canvas: Control
	var unit: float
	var origin: Vector2
	var bounds: Rect2

	func _init(surface: Control, area: Rect2) -> void:
		canvas = surface
		bounds = area
		unit = minf(bounds.size.x / GRID.x, bounds.size.y / GRID.y)
		origin = bounds.get_center() - GRID * unit * 0.5

	func box(x: float, y: float, w: float, h: float, ink: Color) -> void:
		var rect := Rect2(origin + Vector2(x, y) * unit, Vector2(w, h) * unit)
		var visible := bounds.intersection(rect)
		if visible.has_area():
			canvas.draw_rect(visible, ink)

	func stroke(a: Vector2, b: Vector2, ink: Color = EDGE) -> void:
		var width := maxf(0.8, unit * 0.62)
		var margin := Vector2.ONE * (width * 0.5 + 0.5)
		canvas.draw_line(
			(origin + a * unit).clamp(bounds.position + margin, bounds.end - margin),
			(origin + b * unit).clamp(bounds.position + margin, bounds.end - margin),
			ink, width, true,
		)

	func frame(x: float, y: float, w: float, h: float, ink: Color = EDGE) -> void:
		box(x, y, w, 0.8, ink)
		box(x, y + h - 0.8, w, 0.8, ink)
		box(x, y + 0.8, 0.8, h - 1.6, ink)
		box(x + w - 0.8, y + 0.8, 0.8, h - 1.6, ink)

	func arrow(x: float, y: float, width: float, ink: Color = GOLD) -> void:
		var tip := Vector2(x + width, y)
		stroke(Vector2(x, y), tip, ink)
		stroke(tip - Vector2(2, 1.5), tip, ink)
		stroke(tip - Vector2(2, -1.5), tip, ink)

	func arrows_up(x: float, y: float, rank: int, ink: Color) -> void:
		for i in range(rank):
			var tip := Vector2(x + i * 4 + 1, y)
			stroke(tip + Vector2(0, 4.5), tip, ink)
			stroke(tip + Vector2(-1.25, 1.5), tip, ink)
			stroke(tip + Vector2(1.25, 1.5), tip, ink)

	func dot(x: float, y: float, ink: Color = GOLD, size: float = 1.2) -> void:
		var radius := maxf(0.45, unit * size)
		var margin := Vector2.ONE * (radius + 0.5)
		var at := (origin + Vector2(x, y) * unit).clamp(bounds.position + margin, bounds.end - margin)
		canvas.draw_circle(at, radius, ink, true, -1, true)


static func draw(canvas: Control, key: String, step: int, phase: float, area: Rect2) -> void:
	if area.size.x < 30 or area.size.y < 12:
		return
	var p := Diagram.new(canvas, area)
	var n := maxi(step, 0)
	var ease := clampf(phase, 0, 1)
	match key:
		"fib":
			_fibonacci(p, n, ease)
		"double":
			_double(p, n, ease)
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
			_bowers(p, n)
		"fast_goodstein":
			_rewrite(p, n)
		"tree", "sscg":
			_graph_sequence(p, n, key == "tree")
		"busy_beaver", "beeping_beaver", "oracle_beaver":
			_beaver(p, key, n, ease)
		"rayo":
			_symbol_budget(p, n, ease)
		_:
			return


static func _fibonacci(p: Diagram, n: int, phase: float) -> void:
	var source := Vector2(7, 5.5)
	var result := Vector2(34, 11)
	if n > 5:
		# Keep the same total width when literal cells no longer fit. The
		# ratio follows r → 1/(1+r) and stabilizes at screen precision.
		var ratio := 1.0
		for i in range(1, mini(n, 40)):
			ratio = 1.0 / (1.0 + ratio)
		var total_width := 13.0 * FIB_PITCH
		var base_width := total_width / (1.0 + ratio)
		var added_width := total_width - base_width
		p.box(source.x, source.y, added_width, 2.5, EDGE)
		p.box(result.x, result.y, base_width, 2.5, GRAY)
		p.box(result.x + base_width, result.y, added_width, 2.5, GOLD)
		return

	var earlier := 1
	var current := 1
	for i in range(n - 1):
		var next := earlier + current
		earlier = current
		current = next
	_fib_tiles(p, source, earlier, EDGE)
	_fib_tiles(p, result, current, GRAY)
	if n == 0:
		_fib_tiles(p, source, earlier, GOLD)
		return

	# Leave the current term in place. Its new neighbors are the earlier term,
	# which slides above the row and joins it at the open end.
	var end := result + Vector2(current * FIB_PITCH, 0)
	var slide := minf(phase / 0.75, 1)
	var drop := clampf((phase - 0.55) / 0.45, 0, 1)
	var moving := Vector2(lerpf(source.x, end.x, slide), lerpf(source.y, end.y, drop))
	_fib_tiles(p, moving, earlier, GOLD)


static func _fib_tiles(p: Diagram, at: Vector2, amount: int, ink: Color) -> void:
	for i in range(amount):
		p.box(at.x + i * FIB_PITCH, at.y, FIB_PITCH - 0.55, 2.5, ink)


static func _double(p: Diagram, n: int, phase: float) -> void:
	if n == 0:
		_pile(p, 33, 15, 1, GOLD)
		return
	var prior := 1 << mini(n - 1, 2)
	_pile(p, 20, 17, prior, GRAY)
	p.arrow(33, 11, 9)
	_pile(p, 49, 18, prior, GRAY)
	var arrive := lerpf(51.0, 58.0, phase) if n <= 3 else 58.0
	_pile(p, arrive, 18, prior, GOLD)


static func _pile(p: Diagram, x: float, floor_y: float, amount: int, ink: Color) -> void:
	for i in range(amount):
		p.box(x, floor_y - (i + 1) * 2, 5, 1, ink)


static func _pi(p: Diagram, n: int, phase: float) -> void:
	var known := Growth.PI_DIGITS.length()
	if n >= known + 6:
		# Keep the known prefix separate from the new, uncomputed place.
		for i in range(3):
			_digit_slot(p, 12 + i * 8, i, false, 1.0)
		_digit_slot(p, 53, -1, true, 1.0)
		return
	var count := mini(n, 6) + 1
	for slot in count:
		var active := slot == count - 1
		var index := n - count + 1 + slot
		var rise := phase if active and n > 0 and n < known else 1.0
		_digit_slot(p, 8 + slot * 8, index, active, rise)


static func _digit_slot(p: Diagram, x: float, index: int, active: bool, rise: float) -> void:
	p.frame(x, 5, 7, 15, GOLD if active else EDGE)
	if index < 0 or index >= Growth.PI_DIGITS.length():
		return
	# Height encodes its digit; the baseline distinguishes a known zero from an unknown place.
	var digit := int(Growth.PI_DIGITS[index])
	var height := (1.0 + digit * 1.25) * rise
	p.box(x + 1.5, 19 - height, 4, height, GOLD if active else GRAY)


static func _insert(p: Diagram, n: int, phase: float) -> void:
	if n == 0:
		p.box(31, 13, 5, 3, GRAY)
		p.box(38, 13, 5, 3, GRAY)
		return
	var slots := mini(n, 5) + 2
	var selected := slots - 1
	for i in range(slots):
		var x := 9 + i * 8
		if i < slots - 1:
			p.box(x + 2, 16, 5, 3, GRAY)
		p.box(x, 17, 1, 2, GOLD if i == selected else EDGE)
	var y := lerpf(4.0, 12.0, phase) if n <= 5 else 12.0
	p.box(8 + selected * 8, y, 2, 3, GOLD)


static func _graph_choices(p: Diagram, n: int, phase: float) -> void:
	var points := [
		Vector2(19, 12), Vector2(28, 7), Vector2(28, 18),
		Vector2(21, 4), Vector2(21, 21), Vector2(37, 14),
	]
	var limit := mini(n, points.size() - 1) + 1
	var destination := Vector2(57, 12)
	var progress := phase if n > 0 and n < points.size() else 1.0
	for i in range(limit):
		for j in range(i):
			p.stroke(points[j], points[i], SHADE)
	for i in range(limit):
		# A dash marks an available edge to the new point, not a chosen edge.
		var from_new: Vector2 = points[i] - destination
		var direction := from_new.normalized()
		var length := (from_new.length() - 3.0) * progress
		var start := 2.5
		while start + 0.6 < length:
			p.stroke(destination + direction * start, destination + direction * minf(start + 2.0, length), GOLD)
			start += 4.0
		p.dot(points[i].x, points[i].y, GRAY, 1.4)
	p.dot(destination.x, destination.y, GOLD, lerpf(1.4, 2.0, progress))


static func _powers(p: Diagram, n: int, phase: float, square: bool) -> void:
	if n == 0:
		_pile(p, 34, 16, 2, GOLD)
		return
	if square:
		# The previous value is the side of the square; five cells are only a sample.
		var amount: int = [2, 4, 5][mini(n - 1, 2)]
		_pile(p, 15, 18, int(amount), GRAY)
		p.arrow(25, 12, 10)
		for y in range(amount):
			for x in range(amount):
				var current := y == amount - 1 or x == amount - 1
				var y_offset := (1 - phase) * 2 if n <= 2 and y == amount - 1 else 0.0
				p.box(46 + x * 3, 5 + y * 3 - y_offset, 2, 2, GOLD if current else EDGE)
		return
	var amount := mini(n, 4) + 1
	for i in range(amount):
		p.frame(8 + i * 6, 10, 5, 7, GRAY if i < amount - 1 else GOLD)
	p.arrow(43, 12, 7)
	p.frame(53, 10, 7, 9, GRAY)


static func _towers(p: Diagram, key: String, n: int, phase: float) -> void:
	if key == "tower":
		_stack(p, 36, 20, mini(n, 8) + 1, phase if n > 0 else 1.0)
		return
	if key == "tower_double":
		var old_height := 1 << mini(maxi(n - 1, 0), 4)
		var new_height := 1 << mini(n, 4)
		_stack(p, 19, 20, old_height, 1)
		p.arrow(29, 12, 15)
		_stack(p, 54, 20, new_height, phase if n > 0 else 1.0)
		return
	var outer_height: int = [2, 4, 16, 65536][mini(n, 3)]
	_stack(p, 17, 20, mini(n, 8) + 1, phase if n > 0 else 1.0)
	p.stroke(Vector2(24, 13), Vector2(35, 13), GOLD)
	p.stroke(Vector2(35, 13), Vector2(35, 6), GOLD)
	p.arrow(35, 6, 12)
	_stack(p, 55, 20, outer_height, phase if n == 1 else 1.0)


static func _stack(p: Diagram, center: int, floor_y: int, height: int, phase: float) -> void:
	var bands := mini(height, 8)
	for i in range(bands):
		var width := maxi(4, 12 - i)
		var newest := i == bands - 1
		var y := float(floor_y - 2 * (i + 1))
		if newest and height == bands:
			y -= (1 - phase) * 2
		p.box(center - width * 0.5, y, width, 1, GOLD if newest else GRAY)
		p.box(center - width * 0.5, y + 1, width, 1, SHADE)


static func _arrow_operation(p: Diagram, key: String, n: int, phase: float) -> void:
	var rank := 3
	match key:
		"quadruple":
			rank = 4
		"quintuple":
			rank = 5
		"sextuple":
			rank = 6
		"variable_arrows":
			rank = mini(n, 5) + 1
	var variable := key == "variable_arrows"
	var y := lerpf(4.0, 6.0, phase) if variable and n >= 1 and n <= 5 else 6.0
	_pile(p, 8, 13, 3 if variable else 2, GRAY)
	var origin := 35.0 - rank * 2
	p.arrows_up(origin, 6, rank - 1, GOLD)
	p.arrows_up(origin + (rank - 1) * 4, y, 1, GOLD)
	var operand := 3 if variable else mini(n, 5) + (1 if rank == 3 else 2)
	_pile(p, 55, 17, operand, GRAY)
	if not variable:
		p.stroke(Vector2(35, 12), Vector2(35, 15))
		p.arrows_up(35.0 - (rank - 1) * 2, 16, rank - 1, GRAY)
		p.arrow(49, 19, 10, EDGE)


static func _feedback(p: Diagram, key: String, n: int) -> void:
	if key == "conway":
		for i in range(4):
			_pile(p, 8 + i * 17, 14, mini(n, 5) + 1 if i == 2 else 3, GOLD if i == 2 else GRAY)
			if i < 3:
				p.arrow(15 + i * 17, 11, 7, EDGE)
		p.stroke(Vector2(61, 15), Vector2(61, 21))
		p.stroke(Vector2(61, 21), Vector2(44, 21))
		p.stroke(Vector2(44, 21), Vector2(44, 15), GOLD)
		return
	if n == 0:
		_pile(p, 34, 17, 4, GOLD)
		return
	_pile(p, 9, 14, 3, GRAY)
	p.arrows_up(20, 8, 4 if n == 1 else 1, GOLD)
	_pile(p, 38, 14, 3, GRAY)
	p.arrow(44, 10, 7)
	p.frame(53, 6, 12, 9, GOLD)
	p.box(56, 9, 6, 3, GOLD)
	p.stroke(Vector2(59, 16), Vector2(59, 20), GOLD)
	p.stroke(Vector2(59, 20), Vector2(23, 20), GOLD)
	p.stroke(Vector2(23, 20), Vector2(23, 14), GOLD)


static func _bowers(p: Diagram, n: int) -> void:
	if n == 0:
		p.frame(27, 6, 18, 11, EDGE)
		for i in range(2):
			p.box(31 + 6 * i, 9, 3, 5, GOLD)
		return
	var amount := mini(n, 3) + 2
	p.frame(6, 7, 25, 10, EDGE)
	for i in range(amount):
		p.box(9 + 4 * i, 10, 2, 4, GOLD if i == amount - 1 else GRAY)
	p.arrow(34, 12, 8)
	p.frame(45, 4, 20, 16, GOLD)
	for y in range(2):
		for x in range(3):
			var active := x == 2 and y == 1
			p.frame(48 + x * 5, 7 + y * 5, 4, 4, WHITE if active else EDGE)


static func _rewrite(p: Diagram, n: int) -> void:
	p.frame(7, 6, 19, 13, EDGE)
	p.frame(46, 6, 19, 13, EDGE)
	for i in range(4):
		p.box(11 + 3 * i, 10 - i, 2, 7 + i, GRAY)
		if i != 3:
			p.box(50 + 3 * i, 10 - i, 2, 7 + i, GOLD)
		else:
			p.box(50 + 3 * i, 20, 2, 1, EDGE)
	p.arrow(30, 12, 12)


static func _graph_sequence(p: Diagram, n: int, trees: bool) -> void:
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
			p.dot(52, 16, GRAY)
			p.dot(64, 16, GRAY)
		return
	# One representative subcubic graph followed by smaller candidates.
	var points := [Vector2(12, 8), Vector2(23, 8), Vector2(12, 17), Vector2(23, 17)]
	for edge in [[0, 1], [0, 2], [1, 3], [2, 3], [1, 2]]:
		p.stroke(points[edge[0]], points[edge[1]], EDGE)
	for i in range(points.size()):
		p.dot(points[i].x, points[i].y, GRAY)
	p.arrow(31, 12, 9, EDGE)
	var limit := mini(n, 3) + 2
	for i in range(limit):
		p.dot(46 + i * 4, 11, GOLD if i == limit - 1 else GRAY)
	# The gray sample graph is separate from the gold vertices in the new allowance.
	for i in range(mini(n, 5)):
		p.box(46 + i * 4, 17, 2, 2, GOLD)


static func _beaver(p: Diagram, key: String, n: int, phase: float) -> void:
	if key == "busy_beaver" and n <= 107:
		_draw_busy_tape(p, n, phase)
		return
	# The state allowance is known here. The pictures are machine classes, not tapes of winners.
	var states := mini(n - 103, 6) if key == "busy_beaver" else mini(n, 5) + 1
	for i in range(states):
		var x := 36 - (states - 1) * 4.5 + 9 * i
		p.frame(x - 3, 9, 6, 6, GOLD if i == states - 1 else EDGE)
		if i < states - 1:
			p.stroke(Vector2(x + 3, 12), Vector2(x + 6, 12), GRAY)
	if key == "beeping_beaver":
		p.stroke(Vector2(29, 6), Vector2(43, 6), EDGE)
		p.box(45, 3, 2, 4, GOLD)
	elif key == "oracle_beaver":
		p.frame(22, 1, 19, 5, EDGE)
		p.stroke(Vector2(32, 6), Vector2(32, 9), GOLD)
		p.box(31, 7, 2, 1, GOLD)


static func _draw_busy_tape(p: Diagram, n: int, phase: float) -> void:
	var machine := _busy_tape(n)
	var tape: Dictionary = machine.tape
	var head := int(machine.head)
	var prior_head := int(machine.prior_head)
	var written := prior_head
	var shift := float(head - prior_head) * (1 - phase) * 6
	for i in range(-1, 10):
		var x := 10 + i * 6 + shift
		var address := head - 4 + i
		var value := int(tape.get(address, 0))
		if phase < 0.5 and address == written:
			value = int(machine.prior_value)
		p.frame(x, 8, 5, 7, GOLD if x >= 33 and x < 39 else EDGE)
		if value != 0:
			p.box(x + 1, 10, 3, 3, GRAY)
	p.box(35, 4, 3, 2, WHITE)
	var state := int(machine.prior_state if phase < 0.5 else machine.state)
	for i in range(4):
		p.box(29 + 4 * i, 17, 2, 2, GOLD if i == state else EDGE)
	if state < 0:
		p.box(46, 17, 3, 2, WHITE)


static func _busy_tape(steps: int) -> Dictionary:
	# Only the proven 107-step trace is simulated.
	var tape := {}
	var head := 0
	var state := 0
	var prior_head := 0
	var prior_state := 0
	var prior_value := 0
	for i in range(mini(steps, 107)):
		prior_head = head
		prior_state = state
		prior_value = int(tape.get(head, 0))
		var instruction: String = BB4[state * 2 + prior_value]
		tape[head] = int(instruction[0])
		head += 1 if instruction[1] == "R" else -1
		state = "ABCD".find(instruction[2])
		if state < 0:
			break
	return {
		"tape": tape, "head": head, "state": state,
		"prior_head": prior_head, "prior_state": prior_state, "prior_value": prior_value,
	}


static func _symbol_budget(p: Diagram, n: int, phase: float) -> void:
	var length := mini(8, n)
	p.frame(15, 6, 42, 12, EDGE)
	for i in range(length):
		var x := 18 + i * 4.5
		var height := phase * 5.0 if n <= 8 and i == length - 1 else 5.0
		p.box(x, 14 - height, 2, height, GOLD if i == length - 1 else GRAY)
