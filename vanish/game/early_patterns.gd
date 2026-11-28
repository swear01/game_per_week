extends RefCounted
# Motifs for stages 3..13. Each is a pure function of (now, before, e): idle costs nothing, and every loop is bounded
# by the drawing area (or a small log/cube root of the step), never by the step itself.
# now = step; before = now - 1 while a tap animates (else now); e = 0..1 tap progress (1 when idle or reduced motion).

const Growth = preload("res://growth.gd")
const INK := Color("#d9c58b")
const DIM := Color("#988764")
const FILL := Color("#4b4130")
const SHADE := Color("#24201a")
const OUTLINE := Color("#625744")
const WHITE := Color("#e9e6dd")
const INT_MAX := 0x7fffffffffffffff
const PRIME_BASES := [2, 325, 9375, 28178, 450775, 9780504, 1795265022]

static func draw(c: CanvasItem, key: String, now: int, before: int, e: float, a: Rect2) -> void:
	match key:
		"golomb": golomb(c, now, before, e, a)
		"wave": wave(c, now, before, e, a)
		"log_add": log_add(c, now, a)
		"triangular": triangular(c, now, before, e, a)
		"rule90": rule90(c, now, a)
		"primes": primes(c, now, a)
		"lattice_circle": lattice(c, now, before, e, a)
		"sandpile": sandpile(c, now, before, e, a)
		"square_partitions": squares(c, Growth.square_partition_size(now), a)
		"partitions": ferrers(c, now, before, e, a)
		"plane_partitions": plane(c, now + 3, a)
		_: return

static func _box(c: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	var left := roundf(x)
	var top := roundf(y)
	c.draw_rect(Rect2(left, top, maxf(1.0, roundf(x + w) - left), maxf(1.0, roundf(y + h) - top)), color)

# Reveal the integer points on the actual annulus, in the order the expanding circle meets them.
static func lattice(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var r := mini(now, INT_MAX - 1) + 1
	var origin := a.get_center()
	var extent := minf(a.size.x, a.size.y) * 0.46
	var pitch := minf(22.0, extent / (float(r) + 0.55))
	var tapping := before < now
	var sweep := float(r - 1) + e if tapping else float(r)
	var old_radius := (r - 1) * pitch
	if pitch < 3.2:
		c.draw_circle(origin, old_radius, SHADE, true, -1.0, true)
	c.draw_arc(origin, r * pitch, 0, TAU, 112, OUTLINE, 1.0, true)
	if tapping and old_radius > 0.0:
		c.draw_arc(origin, old_radius, 0, TAU, 112, DIM, 1.0, true)
	c.draw_arc(origin, maxf(0.1, sweep * pitch), 0, TAU, 112, INK, 1.5, true)
	# At subpixel spacing the disc is continuous at this resolution.
	if r > 320:
		return
	var outer_squared := r * r
	var inner_squared := (r - 1) * (r - 1)
	for x in range(-r, r + 1):
		var last_y := floori(sqrt(outer_squared - x * x))
		var inner_y := floori(sqrt(inner_squared - x * x)) if absi(x) < r else -1
		if pitch >= 3.2:
			for y in range(-inner_y, inner_y + 1):
				c.draw_circle(origin + Vector2(x, y) * pitch, maxf(0.8, pitch * 0.24), DIM)
		for y in range(inner_y + 1, last_y + 1):
			var distance := sqrt(x * x + y * y)
			var reached := not tapping or distance <= sweep
			var color := WHITE if reached and now > 0 else (DIM if reached else FILL)
			var dot := clampf(pitch * (0.30 if reached else 0.10), 0.55, 6.5)
			c.draw_circle(origin + Vector2(x, y) * pitch, dot, color)
			if y > 0:
				c.draw_circle(origin + Vector2(x, -y) * pitch, dot, color)

# n grains dropped on the origin settle by toppling (≥2 grains → one to each side). Stable pile: |x| ≤ n/2, and the
# origin is empty exactly when n is even. even → odd just fills the origin; odd → even splits and travels outward.
static func sandpile(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var tapping := before < now
	var wmax := clampi(floori((a.size.x / 8.0 - 1.0) / 2.0), 2, 40)
	var hw := mini(now / 2 + 1, wmax)
	var cs := clampf(minf(floorf(a.size.x / (2 * hw + 1)), floorf(a.size.y / 4.0)), 3.0, 20.0)
	var mid := a.get_center().x
	var ground := a.position.y + 0.76 * a.size.y
	var drop := clampf(e / 0.2, 0.0, 1.0) if tapping else 1.0
	var cascade := tapping and now % 2 == 0
	var mv := 0
	var k := -1 # cascade round; -1 while the new grain is still falling
	if cascade:
		mv = now / 2 - 1
		if drop >= 1.0:
			var progress := clampf((e - 0.2) / 0.8, 0.0, 1.0)
			var end_round := 2 * mv + 1
			var visible := mini(mv, hw + 2)
			if visible == mv:
				k = floori(progress * end_round)
			elif progress < 0.5:
				k = floori(2.0 * progress * visible)
			else:
				# Sample the actual final return, skipping the distant part of the cascade.
				k = end_round - ceili(2.0 * (1.0 - progress) * visible)
	for x in range(-hw, hw + 1):
		var now_count := _stable(x, now)
		var was := _stable(x, now - 1) if now > 0 else 0
		if cascade:
			now_count = _sand(x, k, mv) if k >= 0 else int(absi(x) <= mv)
			was = _sand(x, k - 1, mv) if k > 0 else int(absi(x) <= mv)
		elif tapping and drop < 1.0:
			now_count = was # the grain has not landed yet
		var left := mid + x * cs - cs / 2.0
		for g in range(now_count):
			_box(c, left, ground - (g + 1) * cs, cs - 1.0, cs - 1.0, INK if now_count != was or now_count == 2 else DIM)
		if was > now_count and not cascade: # what the last press emptied
			c.draw_rect(Rect2(roundf(left), roundf(ground - was * cs), cs - 1.0, cs - 1.0), OUTLINE, false, 1.0)
	if tapping and drop < 1.0: # the falling grain
		var landing := ground - ((1 if now % 2 == 0 else 0) + 1) * cs
		_box(c, mid - cs / 2.0, lerpf(a.position.y, landing, drop * drop), cs - 1.0, cs - 1.0, WHITE)
	if now / 2 + 1 > wmax: # the pile continues beyond the window
		for side in [-1, 1]:
			for i in range(3):
				c.draw_rect(Rect2(clampf(mid + side * (hw + 0.5) * cs - 1 + side * i * 3, a.position.x, a.end.x - 1), ground - cs * 1.5, 1, 1), OUTLINE)
	c.draw_rect(Rect2(mid - cs, ground + 1, 2.0 * cs, 1), OUTLINE) # origin tick
	c.draw_rect(Rect2(roundf(mid) - 1, ground + 1, 2, 2), WHITE)

static func _stable(x: int, n: int) -> int:
	return 1 if absi(x) <= n / 2 and (x != 0 or n % 2 == 1) else 0

# State after k parallel rounds of toppling the odd pile 2m+1 plus one extra grain on the origin (verified against a brute-force run).
static func _sand(x: int, k: int, m: int) -> int:
	var ax := absi(x)
	if k <= m:
		if ax <= k:
			return 2 if ((k - ax) & 1) == 0 else 0
		return 1 if ax <= m else 0
	var limit := 2 * m - k
	if ax <= limit:
		return 2 if ((k - ax) & 1) == 0 else 0
	if ax == limit + 1:
		return 0
	return 1 if ax <= m + 1 else 0

# A fixed-height tape. The holes separate cells; shade and a seam separate real runs.
static func golomb(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var head := mini(now, INT_MAX - 4) + 1
	var cw := clampf(floorf(a.size.x / 12.0), 24.0, 44.0)
	var height := minf(54.0, a.size.y * 0.60)
	var slots := clampi(floori(a.size.x / cw), 1, 12)
	var hi := head + mini(3, slots - 1)
	var lo := maxi(1, hi - slots + 1)
	var x0 := a.get_center().x - slots * cw / 2.0
	var y := a.get_center().y - height * 0.5
	var hole := minf(cw * 0.085, height * 0.09)
	# Paper travels horizontally only when the head would leave its window.
	var scrolling := lo > 1 and before < now and e < 1.0
	var shift := (1.0 - e) if scrolling else 0.0
	var tape := Rect2(x0, y, slots * cw, height)
	var previous := Growth.golomb(lo - 1 if scrolling else lo)
	for relative in range(-1 if scrolling else 0, hi - lo + 1):
		var i := lo + relative
		var value := Growth.golomb(i)
		var x := x0 + (relative + shift) * cw
		var color := FILL if value & 1 else SHADE
		if i == head:
			color = INK
		elif i > head:
			color = color.darkened(0.35)
		var visible := Rect2(x, y, cw, height).intersection(tape)
		if visible.has_area():
			c.draw_rect(visible, color)
		if value != previous and x > tape.position.x and x < tape.end.x:
			c.draw_line(Vector2(x - 0.5, y - 2.0), Vector2(x - 0.5, y + height + 2.0), DIM, 1.0)
		previous = value

		var center := x + cw * 0.5
		if center - hole >= tape.position.x and center + hole <= tape.end.x:
			for row in [0.18, 0.82]:
				c.draw_circle(Vector2(center, y + height * row), hole, Color.BLACK, true, -1.0, true)

# The cursor follows one period of the actual increments.
static func wave(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var count := Growth.WAVE.size()
	var span := minf(a.size.x * 0.84, 360.0)
	var unit := minf(a.size.y * 0.12, 20.0)
	var x0 := a.get_center().x - span * 0.5
	var baseline := a.get_center().y + unit * 3.0
	var tops := PackedVector2Array()
	for i in range(count):
		tops.append(Vector2(x0 + i * span / (count - 1), baseline - Growth.WAVE[i] * unit))
	var curve := PackedVector2Array([tops[0]])
	for i in range(1, count):
		for sample in range(1, 9):
			var t := sample / 8.0
			curve.append(Vector2(lerpf(tops[i - 1].x, tops[i].x, t), lerpf(tops[i - 1].y, tops[i].y, smoothstep(0.0, 1.0, t))))
	c.draw_polyline(curve, DIM, 1.5, true)
	for point in tops:
		c.draw_circle(point, 2.1, DIM, true, -1.0, true)
	if now == 0:
		return
	var applied := (now - 1) % count
	var point := tops[applied]
	var cursor := point
	var cursor_ink := INK
	if before < now and before > 0:
		var previous := (before - 1) % count
		if applied > previous:
			cursor = Vector2(lerpf(tops[previous].x, point.x, e), lerpf(tops[previous].y, point.y, smoothstep(0.0, 1.0, e)))
		else:
			# An eight-term period wraps to the first onscreen sample.
			var on_old_side := e < 0.5
			cursor = tops[previous] if on_old_side else point
			cursor_ink.a = absf(2.0 * e - 1.0)
	elif before == 0 and before < now:
		cursor_ink.a = e
	c.draw_circle(cursor, minf(4.0, a.size.y * 0.16), cursor_ink, true, -1.0, true)

# The number being added is the binary length of the step. Bits show it as a counter; the bars show how slowly it climbs.
static func log_add(c: CanvasItem, now: int, a: Rect2) -> void:
	var bits := maxi(1, Growth._bit_length(now))
	var cs := minf(a.size.x / (bits + 2.0), 26.0)
	var flipped := now ^ (now - 1) if now > 0 else 0
	var x0 := a.get_center().x - bits * cs / 2.0
	var y := a.end.y - cs
	for b in range(bits):
		var bit := bits - 1 - b
		var on := (now >> bit) & 1 == 1
		var flip := (flipped >> bit) & 1 == 1
		var side := maxf(1.0, cs - 1.0)
		var x := x0 + b * cs
		if on:
			_box(c, x, y, side, side, INK if flip else DIM)
		else:
			c.draw_rect(Rect2(roundf(x), roundf(y), side, side), INK if flip else OUTLINE, false, 1.0)
	var room := y - 6.0 - a.position.y
	if room < 8.0 or now < 1:
		return
	var unit := minf(room / bits, 10.0)
	var bw := 5.0
	var count := mini(now, int(a.size.x / bw) - 2)
	for i in range(count):
		var step := now - count + 1 + i
		var len := Growth._bit_length(step)
		var h := len * unit
		var jump := step == now or len != Growth._bit_length(step - 1)
		_box(c, a.get_center().x - count * bw / 2.0 + i * bw, y - 5.0 - h, bw - 1.0, h, INK if jump else DIM)

# One dot per press, with a score bonus of T_k when row k finishes.
static func triangular(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var completed := _tri_root(now)
	var filled := now - _tri(completed)
	var newest_row := maxi(1, completed + int(filled > 0))
	var burst := now > 0 and filled == 0
	var fill := e if before < now else 1.0
	var row_ink := DIM.lerp(INK, smoothstep(0.45, 1.0, fill)) if burst else DIM
	var height := minf(144.0, a.size.y * 0.84)
	var span := minf(a.size.x * 0.86, height * 1.55)
	var pitch := minf(18.0, minf(height, span) / newest_row)
	var center := a.get_center().x
	var diagram_bottom := a.end.y - 2.0
	var top := diagram_bottom - height
	if pitch >= 5.0:
		top = diagram_bottom - newest_row * pitch
		for row in range(1, newest_row + 1):
			var length := row if row <= completed else filled
			var left := center - row * pitch * 0.5
			var y := top + (row - 1) * pitch
			var side := pitch - 2.0
			for col in range(row):
				var at := Vector2(left + col * pitch + 1.0, y + 1.0)
				if row == newest_row and col == length - 1:
					c.draw_rect(Rect2(at, Vector2.ONE * side), SHADE)
					if fill > 0.0:
						c.draw_rect(Rect2(at, Vector2(side * fill, side)), INK)
				else:
					var ink := SHADE if col >= length else (row_ink if row == newest_row else DIM)
					c.draw_rect(Rect2(at, Vector2.ONE * side), ink)
	else:
		# Preserve the full triangular profile as the lower rows approach equal width.
		# Each strip samples a real row, including the exact newest row at the base.
		var rows := clampi(floori(height / 4.0), 2, 32)
		var spacing := height / rows
		var cell := span / newest_row
		for i in range(rows):
			var row := 1 + i * (newest_row - 1) / (rows - 1)
			var length := row if row <= completed else filled
			var left := center - row * cell * 0.5
			var y := top + i * spacing
			var bar_height := maxf(1.0, spacing - 1.5)
			var latest := row == newest_row
			var width := (length - (1.0 - fill if latest else 0.0)) * cell
			if width < row * cell:
				c.draw_rect(Rect2(left, y, row * cell, bar_height), SHADE)
			c.draw_rect(Rect2(left, y, width, bar_height), row_ink if latest else DIM)

# Row r of Rule 90 from one lit cell: cell (r, x) is lit iff C(r, (r+x)/2) is odd, i.e. j & r == j.
# Once the triangle outgrows the stage the window clings to the newest row's left corner (the centre of a wide row is mostly empty).
static func rule90(c: CanvasItem, now: int, a: Rect2) -> void:
	var p := clampf(floorf(minf(a.size.x / (2.0 * now + 3.0), a.size.y / (now + 1.0))), 4.0 if a.size.x >= 240.0 else 3.0, 12.0)
	var cols := clampi(int(a.size.x / p), 1, 120)
	var rows := mini(clampi(int(a.size.y / p), 1, 68), cols)
	var lo := maxi(0, now - rows + 1)
	var used := mini(int(a.size.x / p), 2 * mini(now, 60) + 1)
	var left := a.get_center().x - used * p * 0.5
	for offset in range(now - lo, -1, -1):
		var row := now - offset
		var y := a.end.y - (offset + 1) * p
		for j in range(mini(row, (cols - 1 - offset) / 2) + 1):
			if (row & j) == j:
				_box(c, left + (offset + 2 * j) * p, y, p - 1.0, p - 1.0, INK if offset == 0 else DIM)

# The step grid: primes are the full bright cells (each adds its own number), other steps are small notes.
static func primes(c: CanvasItem, now: int, a: Rect2) -> void:
	var p := clampf(floorf(a.size.x / 16.0), 8.0, 20.0)
	var cols := clampi(int(a.size.x / p), 6, 16)
	var rows := clampi(int(a.size.y / p), 2, 8)
	var per := cols * rows
	var page := (maxi(now, 1) - 1) / per
	var first := page * per + 1
	var shown := mini(per, now - first + 1)
	var x0 := a.get_center().x - cols * p / 2.0
	var y0 := a.position.y + (a.size.y - rows * p) / 2.0
	for q in range(per):
		var at := Vector2(x0 + q % cols * p, y0 + q / cols * p)
		if q >= shown:
			c.draw_rect(Rect2(roundf(at.x + p / 2.0 - 1), roundf(at.y + p / 2.0 - 1), 1, 1), FILL)
			continue
		var i := first + q
		var prime := _prime(i)
		var current := i == now
		var side := p - 1.0 if prime else maxf(2.0, floorf(p / 3.0))
		_box(c, at.x + (p - 1.0 - side) / 2.0, at.y + (p - 1.0 - side) / 2.0, side, side, (WHITE if current and prime else INK) if prime else (INK if current else DIM))


static func _prime(n: int) -> bool:
	if n < 2:
		return false
	for small: int in [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]:
		if n % small == 0:
			return n == small
	var odd := n - 1
	var shifts := 0
	while (odd & 1) == 0:
		odd >>= 1
		shifts += 1
	# These seven Miller–Rabin bases decide primality for all 64-bit integers.
	for base: int in PRIME_BASES:
		if base % n == 0:
			continue
		var witness := _mod_pow(base % n, odd, n)
		if witness == 1 or witness == n - 1:
			continue
		for i in range(1, shifts):
			witness = _mod_product(witness, witness, n)
			if witness == n - 1:
				break
		if witness != n - 1:
			return false
	return true

static func _mod_pow(base: int, exponent: int, modulus: int) -> int:
	var result := 1
	while exponent > 0:
		if exponent & 1:
			result = _mod_product(result, base, modulus)
		exponent >>= 1
		if exponent > 0:
			base = _mod_product(base, base, modulus)
	return result

static func _mod_product(a: int, b: int, modulus: int) -> int:
	if modulus <= 3037000499:
		return a * b % modulus
	var result := 0
	while b > 0:
		if b & 1:
			result = result - (modulus - a) if result >= modulus - a else result + a
		b >>= 1
		a = a - (modulus - a) if a >= modulus - a else a + a
	return result

static func _tri(n: int) -> int:
	return (n / 2) * (n + 1) if n % 2 == 0 else n * ((n + 1) / 2)

static func _tri_root(s: int) -> int:
	var k := mini(4294967295, int((sqrt(8.0 * s + 1.0) - 1.0) / 2.0))
	while _tri(k) > s:
		k -= 1
	while k < 4294967295 and _tri(k + 1) <= s:
		k += 1
	return k

# Removing one singleton gives a bijection to the previous size. The two
# remaining partitions of four have no singleton and are genuinely new.
static func _partition_samples(s: int) -> Array[Array]:
	if s == 3:
		return [[3], [2, 1], [1, 1, 1]]
	if s == 4:
		return [[3, 1], [2, 1, 1], [1, 1, 1, 1], [4], [2, 2]]
	return [[s], [s - 1, 1], [s - 2, 2]]

static func ferrers(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var s := mini(now, INT_MAX - 3) + 3
	var examples := _partition_samples(s)
	var unit := minf(14.0, minf(a.size.x / 20.0, a.size.y / (12.0 if s <= 4 else 7.0)))
	var spacing := unit * 1.18
	var slot := minf(a.size.x / 3.0, unit * 7.5)
	for i in examples.size():
		var regroup := s == 4 and i >= 3
		var mid := a.get_center().x + (i - (3.5 if regroup else 1.0)) * slot
		var ground := a.get_center().y - unit if s <= 4 and not regroup else a.end.y - unit * 0.4
		var top := a.get_center().y + unit * 0.25 if regroup else a.position.y + unit * 0.3
		var actual: Array = examples[i]
		var added := s == 4 and not regroup
		var motion := s == 4 and before < now
		var progress := 1.0
		if motion:
			progress = clampf((e - 0.38) / 0.62, 0.0, 1.0) if regroup else clampf(e / 0.44, 0.0, 1.0)
		if regroup and motion and e < 0.38:
			continue
		_partition_piles(c, actual, mid, ground, top, unit, spacing, added, regroup, progress)

static func _partition_piles(c: CanvasItem, sizes: Array, mid: float, ground: float, top: float, unit: float, spacing: float, added: bool, regroup: bool, progress: float) -> void:
	var prior_columns := sizes.size() - int(added)
	var left := mid - (prior_columns - 1) * spacing * 0.5
	var visible_rows := maxi(1, floori((ground - top) / spacing))
	var placed := 0
	for column in sizes.size():
		var rows: int = sizes[column]
		for row in mini(rows, visible_rows):
			var at := Vector2(left + column * spacing, ground - (row + 0.5) * spacing)
			var color := INK
			if added and column == sizes.size() - 1:
				at.y -= (1.0 - progress) * unit * 1.8
				color.a = progress
			elif regroup:
				# The same four visible blocks move from a loose row into two alternative arrangements.
				at = Vector2(mid + (placed - 1.5) * spacing, ground - 0.5 * spacing).lerp(at, progress)
			c.draw_rect(Rect2(at - Vector2.ONE * unit * 0.46, Vector2.ONE * unit * 0.92), color)
			placed += 1
		if rows > visible_rows:
			# The tall pile continues above this drawing window. Do not fake a whole stack.
			var x := left + column * spacing
			var y := ground - (visible_rows - 0.5) * spacing
			c.draw_rect(Rect2(x - unit * 0.46, top, unit * 0.92, maxf(0.0, y - top)), INK)

# Blocks are repacked into the biggest squares that fit (1, 4, 9, …).
static func squares(c: CanvasItem, s: int, a: Rect2) -> void:
	var sides: Array[int] = []
	var rest := maxi(0, s)
	var total := 0
	while rest > 0:
		var side := int(sqrt(float(rest)))
		while side > rest / side:
			side -= 1
		sides.append(side)
		total += side
		rest -= side * side
	if sides.is_empty():
		return
	var gap := 2.0
	var u := minf(14.0, minf((a.size.x - gap * sides.size()) / total, a.size.y / sides[0]))
	var x := a.get_center().x - (total * u + gap * (sides.size() - 1)) / 2.0
	for index in range(sides.size()):
		var px := sides[index] * u
		c.draw_rect(Rect2(x, a.end.y - px, px, px), DIM if index % 2 == 0 else OUTLINE)
		if u >= 4.0:
			for line in range(1, sides[index]):
				c.draw_rect(Rect2(roundf(x + line * u), a.end.y - px, 1, px), SHADE)
				c.draw_rect(Rect2(x, roundf(a.end.y - px + line * u), px, 1), SHADE)
		x += px + gap

# Cubes are added in order of i+j+k (every prefix is a valid plane partition: heights never rise along either axis).
static func plane(c: CanvasItem, s: int, a: Rect2) -> void:
	var d := floori(pow(6.0 * s, 1.0 / 3.0))
	while _tetra(d) < 0 or _tetra(d) > s:
		d -= 1
	while _tetra(d + 1) >= 0 and _tetra(d + 1) <= s:
		d += 1
	var rem := s - _tetra(d)
	var newest_i := d - 1
	var newest_j := 0
	if rem > 0:
		var low := 0
		var high := d
		while low < high:
			var mid := (low + high + 1) / 2
			if _diagonal_start(d, mid) < rem:
				low = mid
			else:
				high = mid - 1
		newest_i = low
		newest_j = rem - 1 - _diagonal_start(d, low)

	var whole := d <= 20 and a.size.x >= 5 * (d + 1) and a.size.y >= 5 * (d + 1)
	var span := d if whole else 8
	var i0 := 0 if whole else maxi(0, newest_i - 4)
	var j0 := 0 if whole else maxi(0, newest_j - 4)
	var i1 := d if whole else mini(d, i0 + span)
	var j1 := d if whole else mini(d, j0 + span)
	var u := minf(14.0, minf(a.size.x, a.size.y) / (2.0 * span + 6.0))
	var v := u * 0.7
	var origin := Vector2(a.get_center().x, a.get_center().y)
	# The visible columns start at a real horizontal cut through the partition.
	var new_height := d - newest_i - newest_j + int(rem > 0)
	var cut := 0 if whole else maxi(0, new_height - 4)
	for sum in range(i0 + j0, mini(d, i1 + j1) + 1):
		for i in range(maxi(i0, sum - j1), mini(i1, sum - j0) + 1):
			var j := sum - i
			var fresh := _diagonal_start(d, i) + j < rem
			var newest := i == newest_i and j == newest_j
			var z := float(d - sum + int(fresh) - cut)
			if z <= 0.001:
				continue
			var local_i := i - i0
			var local_j := j - j0
			var top := _iso(origin, u, v, local_i, local_j, z)
			var right := _iso(origin, u, v, local_i + 1, local_j, z)
			var front := _iso(origin, u, v, local_i + 1, local_j + 1, z)
			var left := _iso(origin, u, v, local_i, local_j + 1, z)
			var drop := Vector2(0, z * v)
			c.draw_colored_polygon(PackedVector2Array([left, front, front + drop, left + drop]), OUTLINE)
			c.draw_colored_polygon(PackedVector2Array([right, front, front + drop, right + drop]), FILL)
			var face := WHITE if newest else (INK if fresh else DIM)
			c.draw_colored_polygon(PackedVector2Array([top, right, front, left]), face)
			c.draw_polyline(PackedVector2Array([top, right, front, left, top]), SHADE, 1.0, true)

static func _diagonal_start(d: int, i: int) -> int:
	return i * (d + 1) - _tri(i - 1)

static func _tetra(n: int) -> int:
	# Divide before multiplying. A saturated bound lets the inverse bracket int64 values.
	var a := n
	var b := n + 1
	var c := n + 2
	if a % 2 == 0:
		a /= 2
	else:
		b /= 2
	if a % 3 == 0:
		a /= 3
	elif b % 3 == 0:
		b /= 3
	else:
		c /= 3
	var pair := a * b
	return -1 if pair > INT_MAX / c else pair * c

static func _iso(origin: Vector2, u: float, v: float, i: int, j: int, z: float) -> Vector2:
	return origin + Vector2((i - j) * u, (i + j) * u * 0.5 - z * v)
