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

static var _golomb := PackedInt64Array([0, 1])
static var _prefix := PackedInt64Array([0, 1])
static var _weighted := PackedInt64Array([0, 1])
static var _folded := PackedInt64Array([0, 1])

static func draw(c: CanvasItem, key: String, now: int, before: int, e: float, a: Rect2) -> void:
	match key:
		"golomb": golomb(c, now, before, e, a)
		"wave": wave(c, now, a)
		"log_add": log_add(c, now, a)
		"triangular": triangular(c, now, a)
		"rule90": rule90(c, now, a)
		"primes": primes(c, now, a)
		"lattice_circle": lattice(c, now, before, e, a)
		"sandpile": sandpile(c, now, before, e, a)
		"square_partitions": squares(c, Growth.square_partition_size(now), a)
		"partitions": ferrers(c, now + 3, a)
		"plane_partitions": plane(c, now + 3, a)
		_: return

static func _box(c: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	var left := roundf(x)
	var top := roundf(y)
	c.draw_rect(Rect2(left, top, maxf(1.0, roundf(x + w) - left), maxf(1.0, roundf(y + h) - top)), color)

# Coordinates appear only when several real units are condensed into one visible region.
static func _coordinates(c: CanvasItem, a: Rect2, label: String) -> Rect2:
	var font := ThemeDB.fallback_font
	var font_size := 11
	var right := a.end.x - 2.0
	var baseline := a.end.y - font.get_descent(font_size)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	c.draw_string(font, Vector2(maxf(a.position.x, right - width), baseline), label, HORIZONTAL_ALIGNMENT_LEFT, a.size.x, font_size, DIM)
	return Rect2(a.position, Vector2(a.size.x, maxf(1.0, a.size.y - 16.0)))

# Integer points with x² + y² ≤ r² (r = step + 1). The newest rim, (r-1)² < d² ≤ r², is bright and grows in on the tap.
static func lattice(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var r := mini(now, INT_MAX - 1) + 1
	var rb := mini(before, INT_MAX - 1) + 1
	var mid := a.get_center()
	var s := minf(a.size.x, a.size.y)
	var narrow := 4.0 if s >= 120.0 else 3.0
	var p := floorf(s / (2.0 * r + 3.0))
	var radius := lerpf(rb, r, e)
	if p >= narrow and r <= 48: # the whole disc fits
		p = minf(p, 14.0)
		c.draw_arc(mid, radius * p, 0.0, TAU, 96, OUTLINE, 1.25, true)
		for x in range(-r, r + 1):
			var reach := int(sqrt(float(r * r - x * x)))
			for y in range(-reach, reach + 1):
				var distance := x * x + y * y
				_lattice_point(c, mid + Vector2(x, -y) * p, p, distance > (r - 1) * (r - 1), distance > (rb - 1) * (rb - 1), rb < r, e)
		return
	# Keep the entire circle in view alongside a magnification of its moving frontier.
	var overview := Vector2(a.position.x + a.size.x * 0.23, mid.y)
	var overview_r := minf(a.size.x * 0.18, a.size.y * 0.40)
	var scale := overview_r / maxf(48.0, r)
	var dir := Vector2(0.8, 0.6)
	c.draw_circle(overview, radius * scale, SHADE)
	c.draw_arc(overview, radius * scale, 0.0, TAU, 96, INK, 2.0, true)
	var boundary := overview + Vector2(dir.x, -dir.y) * (radius * scale)
	var focus := Rect2(a.position.x + a.size.x * 0.49, a.position.y + a.size.y * 0.14, a.size.x * 0.48, a.size.y * 0.72)
	c.draw_dashed_line(boundary, Vector2(focus.position.x, mid.y), OUTLINE, 1.0, 4.0)
	c.draw_rect(Rect2(boundary - Vector2.ONE * 2, Vector2.ONE * 4), WHITE)

	p = clampf(floorf(minf(focus.size.x / 21.0, focus.size.y / 15.0)), 3.0, 10.0)
	var q := r / 5
	var residual := r % 5
	var nx := mini(20, maxi(1, floori(focus.size.x / (2.0 * p)) - 4))
	var ny := mini(14, maxi(1, floori(focus.size.y / (2.0 * p)) - 3))
	for dx in range(-nx, nx + 1):
		for dy in range(-ny, ny + 1):
			var at := focus.get_center() + (Vector2(dx, -dy) - Vector2(0.8, -0.6) * residual) * p
			if _rim_inside(q, residual, dx, dy):
				var rim := not _rim_inside(q, residual - 1, dx, dy)
				var previous_rim := not _rim_inside(q, residual - 2, dx, dy)
				_lattice_point(c, at, p, rim, previous_rim, rb < r, e)
			else:
				c.draw_rect(Rect2(at.round(), Vector2.ONE), FILL)

# Center the local lattice window at (4q, 3q), where r = 5q + residual.
# Expanding the squared distances cancels the q² terms, keeping this exact for large r.
static func _rim_inside(q: int, residual: int, dx: int, dy: int) -> bool:
	var linear := 4 * dx + 3 * dy - 5 * residual
	var constant := dx * dx + dy * dy - residual * residual
	if linear != 0 and q > absi(constant):
		return linear < 0
	return 2 * q * linear + constant <= 0

static func _lattice_point(c: CanvasItem, at: Vector2, p: float, rim: bool, previous_rim: bool, tapping: bool, e: float) -> void:
	var side := maxf(1.0, (p - 1.0) * (e if rim and tapping else 1.0)) if rim else maxf(1.0, p - 2.0)
	var color := WHITE if rim else FILL.lerp(DIM, 0.6)
	if tapping and not rim and previous_rim:
		color = WHITE.lerp(color, e)
	_box(c, at.x - side / 2.0, at.y - side / 2.0, side, side, color)

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

# S(k) = sum G(i); T(k) = sum i*G(i) = S(S(k)); U(k) = T(S(k)).
# The folded prefix locates the run using two short inverse searches.
static func _g(n: int) -> int:
	while _folded[-1] < n:
		var j := _golomb.size()
		var g := 1 + _golomb[j - _golomb[_golomb[j - 1]]]
		var prev := _prefix[-1]
		var block := j * (g * prev + _tri(g))
		_golomb.append(g)
		_prefix.append(prev + g)
		_weighted.append(_weighted[-1] + j * g)
		_folded.append(_folded[-1] + mini(block, INT_MAX - _folded[-1]))
	var k := _folded.bsearch(n)
	var offset := n - _folded[k - 1]
	var skip := _prefix[k - 1]
	var low := 1
	var high := _golomb[k]
	while low < high:
		var mid := (low + high) / 2
		if k * (mid * skip + _tri(mid)) < offset:
			low = mid + 1
		else:
			high = mid
	var j := skip + low
	var rem := offset - k * ((low - 1) * skip + _tri(low - 1)) - 1
	return _weighted[k - 1] + k * (low - 1) + 1 + rem / j

# A fixed-height strip. Runs share a shade and each visible cell shows its actual term.
static func golomb(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var head := mini(now, INT_MAX - 4) + 1
	var cw := clampf(floorf(a.size.x / 13.0), 20.0, 34.0)
	var height := minf(32.0, a.size.y * 0.52)
	var slots := maxi(1, floori(a.size.x / cw))
	var hi := head + mini(3, slots - 1)
	var lo := maxi(1, hi - slots + 1)
	var font := ThemeDB.fallback_font
	var font_size := 14
	var x0 := a.get_center().x - slots * cw / 2.0
	var y := a.get_center().y - height * 0.5
	var baseline := y + (height - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	# Paper travels horizontally only when the head would leave its window.
	var scrolling := lo > 1 and before < now and e < 1.0
	var shift := (1.0 - e) if scrolling else 0.0
	var tape := Rect2(x0, y, slots * cw, height)
	var previous := _g(lo - 1 if scrolling else lo)
	for relative in range(-1 if scrolling else 0, hi - lo + 1):
		var i := lo + relative
		var value := _g(i)
		var x := x0 + (relative + shift) * cw
		var color := FILL if value & 1 else SHADE
		if i == head:
			color = INK
		elif i > head:
			color = color.darkened(0.35)
		var visible := Rect2(x, y, cw - 1.0, height).intersection(tape)
		if visible.has_area():
			c.draw_rect(visible, color)
		if value != previous and x > tape.position.x and x < tape.end.x:
			c.draw_line(Vector2(x - 0.5, y - 2.0), Vector2(x - 0.5, y + height + 2.0), DIM, 1.0)
		previous = value

		var term := str(value)
		var width := font.get_string_size(term, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width <= cw - 4.0:
			var text_x := x + (cw - width) * 0.5
			if text_x < tape.position.x or text_x + width > tape.end.x:
				continue
			var ink := SHADE if i == head else (DIM if i > head else WHITE)
			c.draw_string(font, Vector2(text_x, baseline), term, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		elif i == head:
			var label := "G(%d) = %d" % [i, value]
			var label_size := font_size
			var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > a.size.x:
				label = term
				label_width = width
			while label_width > a.size.x and label_size > 8:
				label_size -= 1
				label_width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			var label_x := maxf(a.position.x, a.get_center().x - label_width * 0.5)
			c.draw_string(font, Vector2(label_x, y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, a.size.x, label_size, INK)

# Eight increments around a wave. Columns fill as the lap goes; each finished lap leaves a block on the top row.
static func wave(c: CanvasItem, now: int, a: Rect2) -> void:
	var cw := clampf(floorf(a.size.x / 12.0), 6.0, 30.0)
	var unit := clampf(floorf(a.size.y * 0.5 / 5.0), 2.0, 16.0)
	var x0 := a.get_center().x - cw * 4.0
	var applied := (now - 1) % 8 if now > 0 else -1
	var lap_full := now > 0 and now % 8 == 0
	var tops := PackedVector2Array()
	for i in range(8):
		var h: float = Growth.WAVE[i] * unit
		var x := x0 + i * cw
		tops.append(Vector2(x + (cw - 1.0) / 2.0, a.end.y - h))
		if i == applied:
			_box(c, x, a.end.y - h, cw - 1.0, h, INK)
		elif lap_full or i < now % 8:
			_box(c, x, a.end.y - h, cw - 1.0, h, DIM)
		else:
			c.draw_rect(Rect2(roundf(x), a.end.y - h, cw - 1.0, 1), OUTLINE)
	var curve := PackedVector2Array([tops[0]])
	for i in range(1, tops.size()):
		for sample in range(1, 9):
			var t := sample / 8.0
			curve.append(Vector2(lerpf(tops[i - 1].x, tops[i].x, t), lerpf(tops[i - 1].y, tops[i].y, smoothstep(0.0, 1.0, t))))
	c.draw_polyline(curve, OUTLINE, 1.5, true)
	var laps := now / 8
	var capacity := int(a.size.x / 7.0)
	if laps > capacity:
		var bits := Growth._bit_length(laps)
		var cell := minf(7.0, a.size.x / (bits + 2.0))
		for i in range(bits):
			var on := (laps >> (bits - 1 - i)) & 1
			_box(c, a.get_center().x + (i - bits / 2.0) * cell, a.position.y, cell * 0.68, 5.0, INK if on else SHADE)
		return
	var shown := laps
	for i in range(shown):
		var newest := i == shown - 1 and lap_full
		_box(c, a.get_center().x - shown * 3.5 + i * 7.0, a.position.y, 5.0, 5.0, INK if newest else DIM)

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

# One dot per press. Row k completes at T_k. Narrow windows combine adjacent dots into fractional-width bars.
static func triangular(c: CanvasItem, now: int, a: Rect2) -> void:
	var t := _tri_root(now)
	var filled := now - _tri(t)
	var hi := t + (1 if filled > 0 else 0)
	var p := clampf(floorf(minf(a.size.x, a.size.y) / maxf(1.0, hi)), 3.0, 14.0)
	var f := ceili(float(maxi(1, hi)) / maxi(4, int(a.size.x / p))) # dots per drawn cell
	var lo := maxi(1, hi - int(a.size.y / p) + 1)
	for k in range(lo, hi + 1):
		var len := k if k <= t else filled
		var slots := ceili(float(k) / f)
		var lit := ceili(float(len) / f)
		var x0 := a.get_center().x - slots * p / 2.0
		var y := a.end.y - (hi - k + 1) * p
		for i in range(slots):
			var newest := now > 0 and k == (t if filled == 0 else t + 1) and i == lit - 1
			if i >= lit:
				c.draw_rect(Rect2(roundf(x0 + i * p), roundf(y), p - 1.0, p - 1.0), SHADE)
				continue
			var width := p - 1.0
			if len < k:
				width *= clampf(float(len - i * f) / mini(f, k - i * f), 0.0, 1.0)
			c.draw_rect(Rect2(x0 + i * p, y, width, p - 1.0), INK if newest else DIM)
	if now == 0:
		_box(c, a.get_center().x - 2.0, a.end.y - 4.0, 3.0, 3.0, SHADE)

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

# Ferrers shape of one representative partition of s: rows k, k-1, … 1 with the leftover blocks added one per row. Each press adds one block.
static func ferrers(c: CanvasItem, s: int, a: Rect2) -> void:
	var k := maxi(1, _tri_root(s))
	var extra := s - _tri(k)
	var p := minf(16.0, floorf(minf(a.size.x, a.size.y) / (k + 1.0)))
	var x0 := a.get_center().x - (k + 1) * p / 2.0
	var y0 := a.end.y - k * p
	var new_row := extra if extra > 0 else k
	var new_col := k - extra + 1 if extra > 0 else 0
	if p < 2.0 or k > 64:
		# Sample real rows and mark the actual new block in a scaled overview.
		var side := minf(a.size.x, a.size.y) - 2.0
		var left := a.get_center().x - side * 0.5
		var rows := clampi(floori(side / 3.0), 1, 64)
		for i in range(rows):
			var row := 1 + i * (k - 1) / maxi(1, rows - 1)
			var length := k + 1 - row + int(row <= extra)
			var y := a.end.y - side + i * side / rows
			_box(c, left, y, float(length) * side / (k + 1.0), side / rows - 1.0, DIM)
		var at := Vector2(left + new_col * side / (k + 1.0), a.end.y - side + (new_row - 1) * side / k)
		c.draw_circle(at, 1.5, INK)
		return
	for row in range(1, k + 1):
		var length := k + 1 - row + (1 if row <= extra else 0)
		var y := y0 + (row - 1) * p
		if p >= 4.0:
			for col in range(length):
				var newest := row == new_row and col == new_col
				_box(c, x0 + col * p, y, p - 1.0, p - 1.0, INK if newest else DIM)
		else:
			_box(c, x0, y, length * p - 1.0, p - 1.0, DIM)
			if row == new_row:
				_box(c, x0 + new_col * p, y, p - 1.0, p - 1.0, INK)

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
	# Follow the newest top in both plane axes and height. The visible columns
	# start at a real horizontal cut through the partition.
	var new_height := d - newest_i - newest_j + int(rem > 0)
	if not whole:
		a = _coordinates(c, a, "i %d · j %d · k %d" % [newest_i, newest_j, new_height - 1])
		origin = a.get_center()
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
	if not whole:
		# The rail locates the sampled cube on its full shell, including the last cube at a boundary.
		var diagonal := d if rem > 0 else d - 1
		var index := rem if rem > 0 else _tri(d)
		var left := a.position.x + 2.0
		var right := a.end.x - 2.0
		var y := a.end.y - 2.0
		c.draw_line(Vector2(left, y), Vector2(right, y), OUTLINE, 1.0)
		var x := lerpf(left, right, float(index) / _tri(diagonal + 1))
		c.draw_circle(Vector2(x, y), 1.5, INK, true, -1.0, true)

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
