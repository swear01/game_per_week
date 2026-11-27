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
const THETA := 0.62 # lattice window looks at the rim in this direction once the circle outgrows the stage
const WINDOW_LIMIT := 20000 # Bound the exact prefix used for the illustrative tape.
const CUBE_LIMIT := 28 # plane partition drawn up to this diagonal; the pile keeps counting beyond it

static var _golomb := PackedInt32Array([0, 1])

static func draw(c: CanvasItem, key: String, now: int, before: int, e: float, a: Rect2) -> void:
	match key:
		"golomb": golomb(c, now, before, e, a)
		"wave": wave(c, now, before, e, a)
		"log_add": log_add(c, now, before, e, a)
		"triangular": triangular(c, now, before, e, a)
		"rule90": rule90(c, now, before, e, a)
		"primes": primes(c, now, before, e, a)
		"lattice_circle": lattice(c, now, before, e, a)
		"sandpile": sandpile(c, now, before, e, a)
		"square_partitions": squares(c, Growth.square_partition_size(now), e, a)
		"partitions": ferrers(c, now + 3, e, a)
		"plane_partitions": plane(c, now + 3, e, a)
		_: return

static func _box(c: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	var left := roundf(x)
	var top := roundf(y)
	c.draw_rect(Rect2(left, top, maxf(1.0, roundf(x + w) - left), maxf(1.0, roundf(y + h) - top)), color)

# Integer points with x² + y² ≤ r² (r = step + 1). The newest rim, (r-1)² < d² ≤ r², is bright and grows in on the tap.
static func lattice(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var r := now + 1
	var rb := before + 1
	var mid := a.get_center()
	var s := minf(a.size.x, a.size.y)
	var narrow := 4.0 if s >= 120.0 else 3.0
	var p := floorf(s / (2.0 * r + 3.0))
	var radius := lerpf(rb, r, e)
	if p >= narrow: # the whole disc fits
		p = minf(p, 14.0)
		c.draw_arc(mid, radius * p, 0.0, TAU, 96, OUTLINE, 1.0)
		for x in range(-r, r + 1):
			var reach := int(sqrt(float(r * r - x * x)))
			for y in range(-reach, reach + 1):
				_lattice_point(c, mid + Vector2(x, -y) * p, p, x * x + y * y, r, rb, e)
		return
	# Keep the entire circle in view alongside a magnification of its moving frontier.
	var overview := Vector2(a.position.x + a.size.x * 0.23, mid.y)
	var overview_r := minf(a.size.x * 0.18, a.size.y * 0.40)
	var scale := overview_r / maxf(48.0, r)
	var dir := Vector2.from_angle(THETA)
	c.draw_circle(overview, radius * scale, SHADE)
	c.draw_arc(overview, radius * scale, 0.0, TAU, 96, INK, 2.0)
	var boundary := overview + Vector2(dir.x, -dir.y) * (radius * scale)
	var focus := Rect2(a.position.x + a.size.x * 0.49, a.position.y + a.size.y * 0.14, a.size.x * 0.48, a.size.y * 0.72)
	c.draw_dashed_line(boundary, Vector2(focus.position.x, mid.y), OUTLINE, 1.0, 4.0)
	c.draw_rect(Rect2(boundary - Vector2.ONE * 2, Vector2.ONE * 4), WHITE)

	p = clampf(floorf(minf(focus.size.x / 21.0, focus.size.y / 15.0)), 3.0, 10.0)
	var center_x := roundi(dir.x * r)
	var center_y := roundi(dir.y * r)
	var nx := mini(20, floori(focus.size.x / (2.0 * p)))
	var ny := mini(14, floori(focus.size.y / (2.0 * p)))
	for dx in range(-nx, nx + 1):
		for dy in range(-ny, ny + 1):
			var x := center_x + dx
			var y := center_y + dy
			var at := focus.get_center() + Vector2(dx, -dy) * p
			var d2 := x * x + y * y
			if d2 <= r * r:
				_lattice_point(c, at, p, d2, r, rb, e)
			else:
				c.draw_rect(Rect2(at.round(), Vector2.ONE), FILL)

static func _lattice_point(c: CanvasItem, at: Vector2, p: float, d2: int, r: int, rb: int, e: float) -> void:
	var rim := d2 > (r - 1) * (r - 1)
	# Interior points are small dim dots; the rim admitted by the latest press is full-size and bright, so it stands out on the staircase.
	var side := maxf(1.0, (p - 1.0) * (e if rim and rb < r else 1.0)) if rim else maxf(1.0, p - 2.0)
	var color := WHITE if rim else FILL.lerp(DIM, 0.6)
	if rb < r and not rim and d2 > (rb - 1) * (rb - 1): # the previous press's rim cools down
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
		mv = mini(now / 2 - 1, hw + 2) # window pile: far ends are out of sight, so a virtual end stands just beyond the edge
		if drop >= 1.0:
			k = floori(clampf((e - 0.2) / 0.8, 0.0, 1.0) * (2 * mv + 1))
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
				c.draw_rect(Rect2(mid + side * (hw + 0.5) * cs - 1 + side * i * 3, ground - cs * 1.5, 1, 1), OUTLINE)
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

static func _g(i: int) -> int:
	i = clampi(i, 1, WINDOW_LIMIT)
	while _golomb.size() <= i:
		var j := _golomb.size()
		_golomb.append(1 + _golomb[j - _golomb[_golomb[j - 1]]])
	return _golomb[i]

# The tape: cell n holds G(n), and runs of equal cells are exactly G(v) long. The head reads one cell further each press.
static func golomb(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var head := mini(now + 1, WINDOW_LIMIT - 4)
	var cw := clampf(floorf(a.size.x / 40.0), 4.0, 12.0)
	var hi := head + 3
	var lo := maxi(1, hi - maxi(8, int(a.size.x / cw) - 1) + 1)
	var floor_value := _g(lo) - 1
	var unit := clampf(floorf(a.size.y * 0.8 / maxi(1, _g(hi) - floor_value)), 2.0, 12.0)
	var x0 := a.get_center().x - (hi - lo + 1) * cw / 2.0
	var slide := (1.0 - e) * cw if before < now and lo > 1 else 0.0
	for i in range(lo, hi + 1):
		var v := _g(i)
		var h := (v - floor_value) * unit
		var x := x0 + (i - lo) * cw + slide
		if i > head:
			c.draw_rect(Rect2(roundf(x), a.end.y - h, cw - 1.0, 1), FILL)
			continue
		if i == head and before < now:
			h *= e
		_box(c, x, a.end.y - h, cw - 1.0, h, INK if i == head else (DIM if v % 2 == 1 else OUTLINE))
		if i == head:
			_box(c, x, a.end.y - h - 3.0, cw - 1.0, 2.0, WHITE)

# Eight increments around a wave. Columns fill as the lap goes; each finished lap leaves a block on the top row.
static func wave(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
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
			_box(c, x, a.end.y - h * (e if before < now else 1.0), cw - 1.0, h * (e if before < now else 1.0), INK)
		elif lap_full or i < now % 8:
			_box(c, x, a.end.y - h, cw - 1.0, h, DIM)
		else:
			c.draw_rect(Rect2(roundf(x), a.end.y - h, cw - 1.0, 1), OUTLINE)
	c.draw_polyline(tops, OUTLINE, 1.0)
	var laps := now / 8
	var shown := mini(laps, int(a.size.x / 7.0))
	for i in range(shown):
		var newest := i == shown - 1 and lap_full
		var side := 5.0 * (e if newest and before < now else 1.0)
		_box(c, a.get_center().x - shown * 3.5 + i * 7.0, a.position.y, side, side, INK if newest else DIM)

# The number being added is the binary length of the step. Bits show it as a counter; the bars show how slowly it climbs.
static func log_add(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var bits := maxi(1, Growth._bit_length(now))
	var cs := clampf(floorf(a.size.x / (bits + 2.0)), 4.0, 26.0)
	var flipped := now ^ (now - 1) if now > 0 else 0
	var x0 := a.get_center().x - bits * cs / 2.0
	var y := a.end.y - cs
	for b in range(bits):
		var bit := bits - 1 - b
		var on := (now >> bit) & 1 == 1
		var flip := (flipped >> bit) & 1 == 1
		var side := (cs - 1.0) * (e if flip and before < now else 1.0)
		var at := Vector2(x0 + b * cs + (cs - 1.0 - side) / 2.0, y + (cs - 1.0 - side) / 2.0)
		if on:
			_box(c, at.x, at.y, side, side, INK if flip else DIM)
		else:
			c.draw_rect(Rect2(roundf(at.x), roundf(at.y), side, side), INK if flip else OUTLINE, false, 1.0)
	var room := y - 6.0 - a.position.y
	if room < 8.0 or now < 1:
		return
	var unit := clampf(floorf(room / bits), 1.0, 10.0)
	var bw := 5.0
	var count := mini(now, int(a.size.x / bw) - 1)
	var slide := (1.0 - e) * bw if before < now and now > count else 0.0
	for i in range(count):
		var step := now - count + 1 + i
		var len := Growth._bit_length(step)
		var h := len * unit * (e if step == now and before < now else 1.0)
		var jump := step == now or len != Growth._bit_length(step - 1)
		_box(c, a.get_center().x - count * bw / 2.0 + i * bw + slide, y - 5.0 - h, bw - 1.0, h, INK if jump else DIM)

# 1 dot per press; row k completes at T_k and then bursts (the row flashes). Windowed by rows and compressed by columns.
static func triangular(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var t := int((sqrt(8.0 * now + 1.0) - 1.0) / 2.0)
	var filled := now - t * (t + 1) / 2
	var hi := t + (1 if filled > 0 else 0)
	var p := clampf(floorf(minf(a.size.x, a.size.y) / maxf(1.0, hi)), 3.0, 14.0)
	var f := ceili(float(maxi(1, hi)) / maxi(4, int(a.size.x / p))) # dots per drawn cell
	var lo := maxi(1, hi - int(a.size.y / p) + 1)
	var burst := filled == 0 and now > 0 and before < now
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
			var color := INK if newest else DIM
			if burst and k == t:
				color = INK.lerp(DIM, e)
			var side := (p - 1.0) * (e if newest and before < now and not burst else 1.0)
			_box(c, x0 + i * p + (p - 1.0 - side) / 2.0, y + (p - 1.0 - side) / 2.0, side, side, color)
	if now == 0:
		_box(c, a.get_center().x - 2.0, a.end.y - 4.0, 3.0, 3.0, SHADE)

# Row r of Rule 90 from one lit cell: cell (r, x) is lit iff C(r, (r+x)/2) is odd, i.e. j & r == j.
# Once the triangle outgrows the stage the window clings to the newest row's left corner (the centre of a wide row is mostly empty).
static func rule90(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var p := clampf(floorf(minf(a.size.x / (2.0 * now + 3.0), a.size.y / (now + 1.0))), 4.0 if a.size.x >= 240.0 else 3.0, 12.0)
	var rows := maxi(1, int(a.size.y / p))
	var half := int(a.size.x / p) / 2 - 1
	var lo := maxi(0, now - rows + 1)
	var slide := (1.0 - e) * p if before < now and lo > 0 else 0.0
	var focus := -float(maxi(0, now - half))
	focus = lerpf(-float(maxi(0, before - half)), focus, e)
	var mid := a.get_center().x
	for r in range(lo, now + 1):
		var y := a.position.y + (r - lo) * p + slide
		var newest := r == now
		var side := (p - 1.0) * (e if newest and before < now else 1.0)
		for x in range(maxi(-r, floori(focus) - half), mini(r, ceili(focus) + half) + 1):
			if ((r + x) & 1) == 0 and (r & ((r + x) >> 1)) == (r + x) >> 1:
				_box(c, mid + (x - focus) * p - p / 2.0, y, p - 1.0, side, INK if newest else DIM)

# The step grid: primes are the full bright cells (each adds its own number), other steps are small notes.
static func primes(c: CanvasItem, now: int, before: int, e: float, a: Rect2) -> void:
	var p := clampf(floorf(a.size.x / 16.0), 8.0, 20.0)
	var cols := clampi(int(a.size.x / p), 6, 16)
	var rows := clampi(int(a.size.y / p), 2, 8)
	var per := cols * rows
	var page := (maxi(now, 1) - 1) / per
	var x0 := a.get_center().x - cols * p / 2.0
	var y0 := a.position.y + (a.size.y - rows * p) / 2.0
	for q in range(per):
		var i := page * per + q + 1
		var at := Vector2(x0 + q % cols * p, y0 + q / cols * p)
		if i > now:
			c.draw_rect(Rect2(roundf(at.x + p / 2.0 - 1), roundf(at.y + p / 2.0 - 1), 1, 1), FILL)
			continue
		var prime := _prime(i)
		var current := i == now
		var side := p - 1.0 if prime else maxf(2.0, floorf(p / 3.0))
		var fresh := current and before < now
		if fresh:
			side *= e
		_box(c, at.x + (p - 1.0 - side) / 2.0, at.y + (p - 1.0 - side) / 2.0, side, side, (WHITE if current and prime else INK) if prime else (INK if current else DIM))
		if fresh and prime: # a burst: the added number ripples out from the cell
			c.draw_rect(Rect2(at - Vector2.ONE * (1.0 - e) * p, Vector2.ONE * (p - 1.0 + 2.0 * (1.0 - e) * p)), INK.lerp(Color.BLACK, e), false, 1.0)

static func _prime(n: int) -> bool:
	if n < 4:
		return n >= 2
	if n % 2 == 0 or n % 3 == 0:
		return false
	var d := 5
	while d * d <= n:
		if n % d == 0 or n % (d + 2) == 0:
			return false
		d += 6
	return true

# Ferrers shape of one representative partition of s: rows k, k-1, … 1 with the leftover blocks added one per row. Each press adds one block.
static func ferrers(c: CanvasItem, s: int, e: float, a: Rect2) -> void:
	var k := maxi(1, int((sqrt(8.0 * s + 1.0) - 1.0) / 2.0))
	var extra := s - k * (k + 1) / 2
	var p := clampf(floorf(minf(a.size.x, a.size.y) / (k + 1.0)), 2.0, 16.0)
	var x0 := a.get_center().x - (k + 1) * p / 2.0
	var y0 := a.end.y - k * p
	var new_row := extra if extra > 0 else k
	var new_col := k - extra + 1 if extra > 0 else 0
	for row in range(1, k + 1):
		var length := k + 1 - row + (1 if row <= extra else 0)
		var y := y0 + (row - 1) * p
		if p >= 4.0:
			for col in range(length):
				var newest := row == new_row and col == new_col
				var side := (p - 1.0) * (e if newest else 1.0)
				_box(c, x0 + col * p, y + (p - 1.0 - side) / 2.0, side, side, INK if newest else DIM)
		else:
			_box(c, x0, y, length * p - 1.0, p - 1.0, DIM)
			if row == new_row:
				_box(c, x0 + new_col * p, y, p - 1.0, p - 1.0, INK)

# Blocks are packed into the biggest squares that fit (1, 4, 9, …); the newest block rides on the last package.
static func squares(c: CanvasItem, s: int, e: float, a: Rect2) -> void:
	var sides: Array[int] = []
	var rest := maxi(0, s)
	var total := 0
	while rest > 0:
		var side := int(sqrt(float(rest)))
		while side * side > rest:
			side -= 1
		sides.append(side)
		total += side
		rest -= side * side
	if sides.is_empty():
		return
	var gap := 2.0
	var u := floorf(minf((a.size.x - gap * sides.size()) / total, a.size.y / sides[0]))
	u = clampf(u, 1.0, 14.0)
	var x := a.get_center().x - (total * u + gap * (sides.size() - 1)) / 2.0
	for index in range(sides.size()):
		var px := sides[index] * u
		var last := index == sides.size() - 1
		_box(c, x, a.end.y - px, px, px, DIM if index % 2 == 0 else OUTLINE)
		if u >= 4.0:
			for line in range(1, sides[index]):
				c.draw_rect(Rect2(roundf(x + line * u), a.end.y - px, 1, px), SHADE)
				c.draw_rect(Rect2(x, roundf(a.end.y - px + line * u), px, 1), SHADE)
		if last: # newest unit block: top-right cell of the last package, dropping in on the tap
			var side := maxf(1.0, u - 1.0) * e
			_box(c, x + px - u + (u - 1.0 - side) / 2.0, a.end.y - px + (u - 1.0 - side) / 2.0, side, side, INK)
		x += px + gap

# Cubes are added in order of i+j+k (every prefix is a valid plane partition: heights never rise along either axis).
static func plane(c: CanvasItem, s: int, e: float, a: Rect2) -> void:
	var d := 0
	while (d + 1) * (d + 2) * (d + 3) / 6 <= s:
		d += 1
	var rem := s - d * (d + 1) * (d + 2) / 6 # cubes already placed on the current diagonal layer i+j+k = d
	var shown := mini(d, CUBE_LIMIT)
	var u := clampf(floorf(minf(a.size.x / (2.0 * shown + 2.0), a.size.y / (1.2 * shown + 2.0))), 2.0, 14.0)
	var v := u * 0.7
	var origin := Vector2(a.get_center().x, a.end.y - (shown + 2) * u / 2.0)
	for sum in range(mini(d, CUBE_LIMIT) + 1):
		for i in range(sum + 1):
			var j := sum - i
			# Row i on diagonal d starts after rows of lengths d+1, d, ...
			@warning_ignore("integer_division")
			var index := i * (d + 1) - i * (i - 1) / 2 + j
			var fresh := index < rem
			var newest := index == rem - 1 if rem > 0 else i == d - 1 and j == 0
			var h := float(maxi(0, d - sum) + int(fresh))
			if h <= 0.0:
				continue
			var z := minf(h, float(CUBE_LIMIT) + 1.0)
			if newest:
				z -= 1.0 - e
			if z <= 0.001:
				continue
			var top := _iso(origin, u, v, i, j, z)
			var right := _iso(origin, u, v, i + 1, j, z)
			var front := _iso(origin, u, v, i + 1, j + 1, z)
			var lft := _iso(origin, u, v, i, j + 1, z)
			var drop := Vector2(0, z * v)
			c.draw_colored_polygon(PackedVector2Array([lft, front, front + drop, lft + drop]), OUTLINE)
			c.draw_colored_polygon(PackedVector2Array([right, front, front + drop, right + drop]), FILL)
			var face := WHITE if newest else (INK if fresh else DIM)
			c.draw_colored_polygon(PackedVector2Array([top, right, front, lft]), face)
			c.draw_polyline(PackedVector2Array([top, right, front, lft, top]), SHADE, 1.0)

static func _iso(origin: Vector2, u: float, v: float, i: int, j: int, z: float) -> Vector2:
	return origin + Vector2((i - j) * u, (i + j) * u * 0.5 - z * v)
