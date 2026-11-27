extends RefCounted

const Growth = preload("res://growth.gd")
const GOLD := Color("#d9c58b")
const WHITE := Color("#e9e6dd")
const GRAY := Color("#8a8678")
const EDGE := Color("#625744")
const SHADE := Color("#383125")
const GRID := Vector2(72, 25)
const MAX_TAPS := 9223372036854775807
const BB4 := ["1RB", "1LB", "1LA", "0LC", "1RZ", "1LD", "1RD", "0RA"]


static var _label_font: SystemFont


class Diagram:
	var canvas: Control
	var unit: float
	var origin: Vector2
	var bounds: Rect2
	var font: Font

	func _init(surface: Control, area: Rect2, numeric_font: Font) -> void:
		canvas = surface
		font = numeric_font
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

	func number(x: float, y: float, text: String, ink: Color = GOLD, span: float = 72.0) -> void:
		var size := clampi(roundi(unit * 6.0), 7, 64)
		var available := minf(bounds.size.x - 2, unit * span)
		while size > 5 and (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > available or font.get_height(size) > bounds.size.y - 2):
			size -= 1
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var ascent := font.get_ascent(size)
		var descent := font.get_descent(size)
		var corner := origin + Vector2(x, y) * unit
		corner.x = clampf(corner.x, bounds.position.x + 1, bounds.end.x - width - 1)
		corner.y = clampf(corner.y + ascent, bounds.position.y + ascent + 1, bounds.end.y - descent - 1)
		canvas.draw_string(font, corner, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


static func draw(canvas: Control, key: String, step: int, phase: float, area: Rect2) -> void:
	if area.size.x < 36 or area.size.y < 13:
		return
	if _label_font == null:
		_label_font = SystemFont.new()
		_label_font.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
		_label_font.font_weight = 700
	var p := Diagram.new(canvas, area, _label_font)
	var n := maxi(step, 0)
	var ease := clampf(phase, 0, 1)
	if area.size.x < 54 or area.size.y < 22:
		_compact_parameter(p, key, n)
		return
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


static func _copies(p: Diagram, n: int, phase: float, fibonacci: bool) -> void:
	if n == 0:
		_pile(p, 33, 15, 1, GOLD)
		if fibonacci:
			_pile(p, 26, 15, 1, GRAY)
		return
	if fibonacci:
		# F(n) and F(n+1) are the inputs to the displayed F(n+2).
		var a := 1
		var b := 1
		for i in range(mini(n - 1, 5)):
			var next := a + b
			a = b
			b = next
		_pile(p, 10, 17, mini(a, 6), GRAY)
		_pile(p, 22, 17, mini(b, 6), GOLD)
		p.box(18, 11, 3, 1, EDGE)
		p.box(19, 10, 1, 3, EDGE)
		p.arrow(33, 11, 9)
		var arrive := lerpf(45.0, 50.0, phase)
		_pile(p, arrive, 18, mini(a, 6), GRAY)
		_pile(p, arrive + 8, 18, mini(b, 6), GOLD)
		if n >= 5:
			if n >= 6:
				_dots(p, 10, 18)
			_dots(p, 22, 18)
			_dots(p, 64, 17)
			p.number(45, 20, _small_number(n, 2), GRAY)
		return
	var prior := 1 << mini(n - 1, 2)
	_pile(p, 20, 17, prior, GRAY)
	p.arrow(33, 11, 9)
	_pile(p, 49, 18, prior, GRAY)
	_pile(p, lerpf(51.0, 58.0, phase), 18, prior, GOLD)
	if n > 3:
		_dots(p, 21, 18)
		_dots(p, 65, 17)
		p.number(47, 7, "2", GRAY)
		p.number(53, 3, _small_number(n), GOLD)


static func _pile(p: Diagram, x: float, floor_y: float, amount: int, ink: Color) -> void:
	for i in range(amount):
		p.box(x, floor_y - (i + 1) * 2, 5, 1, ink)


static func _pi(p: Diagram, n: int, phase: float) -> void:
	var count := mini(n, 6) + 1
	var known := Growth.PI_DIGITS.length()
	if n >= known + 6:
		# Preserve the known prefix once the moving window no longer contains a known digit.
		p.number(7, 10, Growth.PI_DIGITS.left(3), GRAY)
		_dots(p, 24, 13)
		p.frame(42, 7, 7, 12, GOLD)
		p.number(44, 8 + phase * 2, "…", GOLD)
	else:
		for i in range(count):
			var x := float(6 + i * 8)
			var active := i == count - 1
			var index := n - count + 1 + i
			var symbol: String = Growth.PI_DIGITS[index] if index < known else "…"
			p.frame(x, 7, 7, 12, GOLD if active else EDGE)
			p.number(x + 2, 8 + phase * 2 if active else 10.0, symbol, GOLD if active else GRAY)
		if n >= 7:
			_dots(p, 64, 13)
	if n >= 7:
		p.number(52, 19, _small_number(n, 1), GRAY)


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
	p.box(8 + selected * 8, lerpf(4.0, 12.0, phase), 2, 3, GOLD)
	if n > 5:
		_dots(p, 64, 17)
		p.number(50, 2, _small_number(n, 2), GOLD)


static func _graph_choices(p: Diagram, n: int, phase: float) -> void:
	var points := [
		Vector2(13, 12), Vector2(18, 5), Vector2(18, 19),
		Vector2(26, 7), Vector2(26, 17), Vector2(32, 12),
	]
	var limit := mini(n, points.size() - 1) + 1
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
	p.number(55, 0, _small_number(n, 1), GOLD)


static func _powers(p: Diagram, n: int, phase: float, square: bool) -> void:
	if n == 0:
		p.number(34, 10, "2", GOLD)
		return
	if square:
		# The previous value is the side of the square; five cells are only a sample.
		var amount: int = [2, 4, 5][mini(n - 1, 2)]
		_pile(p, 15, 18, int(amount), GRAY)
		p.arrow(25, 12, 10)
		for y in range(amount):
			for x in range(amount):
				var current := y == amount - 1 or x == amount - 1
				var y_offset := (1 - phase) * 2 if y == amount - 1 else 0.0
				p.box(46 + x * 3, 5 + y * 3 - y_offset, 2, 2, GOLD if current else EDGE)
		if n >= 3:
			_dots(p, 64, 18)
			p.number(6, 7, "2", GRAY)
			p.number(11, 4, "2", GRAY)
			p.number(16, 0, _small_number(n, -1), GOLD)
		return
	var amount := mini(n, 4) + 1
	for i in range(amount):
		p.frame(8 + i * 6, 10, 5, 7, GRAY if i < amount - 1 else GOLD)
	if n >= 5:
		_dots(p, 38, 15)
	p.arrow(43, 12, 7)
	p.frame(53, 10, 7, 9, GRAY)
	p.number(52, 4 - (1 - phase) * 2, _small_number(n, 1), GOLD)


static func _towers(p: Diagram, key: String, n: int, phase: float) -> void:
	if key == "tower":
		_stack(p, 36, 20, mini(n, 8) + 1, phase)
		if n >= 8:
			p.number(48, 12, _small_number(n, 1), GOLD)
		return
	if key == "tower_double":
		var old_height := 1 << mini(maxi(n - 1, 0), 4)
		var new_height := 1 << mini(n, 4)
		_stack(p, 19, 20, old_height, 1)
		p.arrow(29, 12, 15)
		_stack(p, 54, 20, new_height, phase)
		if n > 3:
			p.number(48, 20, "2", GRAY)
			p.number(53, 17, _small_number(n), GOLD)
		return
	var outer_height: int = [2, 4, 16, 65536][mini(n, 3)]
	_stack(p, 17, 20, mini(n, 8) + 1, 1)
	p.stroke(Vector2(24, 13), Vector2(35, 13), GOLD)
	p.stroke(Vector2(35, 13), Vector2(35, 6), GOLD)
	p.arrow(35, 6, 12)
	_stack(p, 55, 20, outer_height, phase)
	if n > 2:
		p.number(7, 19, _small_number(n, 1), GOLD)


static func _stack(p: Diagram, center: int, floor_y: int, height: int, phase: float) -> void:
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
	var y := 7.0 - (1 - phase) * 2
	p.number(11, 7, "3" if variable else "2", GRAY)
	p.arrows_up(20, y if variable else 7.0, rank, GOLD)
	p.number(50, 7 if variable else y, "3" if variable else _small_number(n, 1 if rank == 3 else 2), GRAY)
	if variable:
		if n >= 6:
			_dots(p, 44, 10)
		p.number(29, 15, _small_number(n, 1), GOLD)
	else:
		p.stroke(Vector2(34, 13), Vector2(34, 15), EDGE)
		p.arrows_up(23, 16, rank - 1, GRAY)
		p.arrow(49, 17, 9, EDGE)


static func _feedback(p: Diagram, key: String, n: int) -> void:
	if key == "conway":
		p.number(9, 7, "3", GRAY)
		p.number(23, 7, "3", GRAY)
		p.number(35, 7, _small_number(n, 1), GOLD, 24)
		p.number(62, 7, "3", GRAY)
		for x in [14, 28, 54]:
			p.arrow(x, 15, 7, EDGE)
		p.stroke(Vector2(62, 13), Vector2(62, 20), EDGE)
		p.stroke(Vector2(62, 20), Vector2(41, 20), EDGE)
		p.stroke(Vector2(41, 20), Vector2(41, 14), GOLD)
		return
	if n == 0:
		p.number(34, 10, "4", GOLD)
		return
	p.number(9, 8, "3", GRAY)
	if n == 1:
		p.arrows_up(20, 8, 4, GOLD)
	else:
		p.arrows_up(22, 9, 1, GOLD)
		p.number(16, 1, "G" + _small_number(n, -1), GOLD)
	p.number(38, 8, "3", GRAY)
	p.arrow(42, 10, 7)
	p.frame(48, 6, 24, 9, GOLD)
	var output := ("G" if p.unit >= 1 else "") + _small_number(n)
	p.number(49, 8, output, GOLD, 22)
	p.stroke(Vector2(60, 16), Vector2(60, 20), GOLD)
	p.stroke(Vector2(60, 20), Vector2(23, 20), GOLD)
	p.stroke(Vector2(23, 20), Vector2(23, 14), GOLD)


static func _bowers(p: Diagram, n: int, phase: float) -> void:
	if n == 0:
		p.number(32, 10, "27", GOLD)
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
			p.frame(48 + x * 5, 7 + y * 5 - (1 - phase) if active else 7 + y * 5, 4, 4, WHITE if active else EDGE)
	if n > 3:
		p.number(10, 20, _small_number(n, 2), GOLD)


static func _rewrite(p: Diagram, n: int, phase: float) -> void:
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
	p.number(30, 18, _small_number(n, 1), GRAY)


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
			_dots(p, 64, 20)
		if n > 2:
			p.number(8, 19, _small_number(n, 1), GOLD)
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
	# P + n is the vertex allowance carried from TREE.
	p.frame(45, 17, 4, 3, GRAY)
	p.box(45, 20, 1, 2, GRAY)
	p.box(51, 19, 3, 1, EDGE)
	p.box(52, 18, 1, 3, EDGE)
	p.number(57, 17, _small_number(n), GOLD)


static func _beaver(p: Diagram, key: String, n: int, phase: float) -> void:
	if key == "busy_beaver" and n <= 107:
		_draw_busy_tape(p, n, phase)
		return
	# The state allowance is known here. The pictures are machine classes, not tapes of winners.
	var states := _small_number(n, -103 if key == "busy_beaver" else 1)
	for i in range(4):
		var x := 13 + 10 * i
		p.frame(x, 9, 6, 6, EDGE)
		if i < 3:
			p.stroke(Vector2(x + 6, 12), Vector2(x + 9, 12), GRAY)
	_dots(p, 50, 12)
	p.number(52, 18, states, GOLD)
	if key == "beeping_beaver":
		var y := lerpf(6.0, 3.0, phase)
		p.stroke(Vector2(29, 6), Vector2(43, 6), EDGE)
		p.box(45, y, 2, 6 - y + 1, GOLD)
	elif key == "oracle_beaver":
		p.frame(22, 1, 19, 5, EDGE)
		p.stroke(Vector2(32, 6), Vector2(32, 9), GOLD)
		p.box(31, 2 + phase * 5, 2, 1, GOLD)


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
	p.number(52, 17, _small_number(n), GRAY)


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
	p.frame(8, 7, 32, 12, EDGE)
	for i in range(length):
		var x := 11 + i * 3
		var y := 11.0 - (1 - phase) * 2 if i == length - 1 else 11.0
		p.box(x, y, 1, 4, GOLD if i == length - 1 else GRAY)
	var length_text := _small_number(n)
	p.number(52, 11, length_text, GRAY)
	if n > 8:
		_dots(p, 44, 13)


static func _compact_parameter(p: Diagram, key: String, n: int) -> void:
	var offset := 1
	match key:
		"fib", "factorial", "quadruple", "quintuple", "sextuple", "bowers":
			offset = 2
		"square":
			offset = -1 if n > 0 else 0
		"double", "tower_double", "graham", "sscg", "rayo":
			offset = 0
		"busy_beaver":
			offset = -103 if n > 107 else 0
		"pi_digits", "graphs", "growing_power", "tower", "tower_in_tower", "triple", "variable_arrows", "conway", "fast_goodstein", "tree", "beeping_beaver", "oracle_beaver":
			pass
		_:
			return
	var text := _small_number(n, offset)
	p.number(31 - text.length() * 2, 8, text, GOLD)


static func _small_number(n: int, offset: int = 0) -> String:
	var text: String
	if offset > 0 and n > MAX_TAPS - offset:
		# Offsets are at most three. Near int64's ceiling they affect only this tail.
		var full := str(n)
		text = full.left(full.length() - 6) + "%06d" % (int(full.right(6)) + offset)
	else:
		text = str(n + offset)
	# Include the digit count when shortened so equal prefixes and tails at different scales stay distinct.
	return "%s…%s[%d]" % [text.left(2), text.right(2), text.length()] if text.length() > 7 else text


static func _dots(p: Diagram, x: float, y: float) -> void:
	for i in range(3):
		p.dot(x + 2 * i, y, GOLD, 0.35)
