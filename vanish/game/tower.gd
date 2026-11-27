extends Control

const INK := Color("#d9c58b")
const DIM := Color("#655e49")
const SHADE := Color("#282314")
const LINE := Color("#34322b")
const WHITE := Color("#e9e6dd")
const MAX_SLOTS := 22

var occupied := 0
var has_base := false
var layer_scale := 1
var polygon_step := -1

func update_tower(display: String, step: int, goal: int, has_record: bool, opening: bool) -> String:
	has_base = has_record
	polygon_step = step if opening else -1
	if opening:
		queue_redraw()
		return "極限 π/2 ≈ 1.5708"
	var power := _log2_quantity(display)
	if is_nan(power) or (power != -INF and absf(power) > 10000000.0):
		layer_scale = maxi(1, ceili(float(goal) / MAX_SLOTS))
		occupied = mini(MAX_SLOTS, ceili(float(step) / layer_scale))
		queue_redraw()
		return "符號式　·　塔每層代表 %d 下" % layer_scale

	if power == -INF:
		occupied = 0
	else:
		occupied = mini(MAX_SLOTS, 1 + floori(maxf(0.0, power)))
	queue_redraw()
	if power > float(MAX_SLOTS - 1):
		return "塔已壓縮　·　數值約 2^%.1f" % power
	return "塔每層約 ×2"

static func is_numeric(display: String) -> bool:
	return not is_nan(_log2_quantity(display))

static func _log2_quantity(display: String) -> float:
	var normalized := display.strip_edges().to_lower().replace(",", "").replace(" ", "")
	normalized = normalized.trim_prefix("≈").replace("×10^", "e")
	var powers := normalized.split("^")
	if powers.size() == 2 and powers[0].is_valid_float() and powers[1].is_valid_int():
		var base := powers[0].to_float()
		if base > 0.0:
			return powers[1].to_float() * log(base) / log(2.0)
	var factors := normalized.split("e")
	if factors.size() > 2 or not factors[0].is_valid_float():
		return NAN
	var mantissa := factors[0].to_float()
	if mantissa == 0:
		return -INF
	if mantissa < 0 or not is_finite(mantissa):
		return NAN
	if factors.size() == 2:
		if not factors[1].is_valid_int():
			return NAN
		return log(mantissa) / log(2.0) + factors[1].to_float() * log(10.0) / log(2.0)
	return log(mantissa) / log(2.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if polygon_step >= 0:
		_draw_opening()
		return
	var middle := floori(size.x / 2.0)
	var floor_y := floori(size.y) - 8
	var span := mini(middle, 200)
	draw_rect(Rect2(middle - span, floor_y, 2 * span, 1), LINE)
	for tick in range(middle - span + 8, middle + span, 16):
		draw_rect(Rect2(tick, floor_y + 3, 2, 3), LINE)
	if has_base:
		draw_rect(Rect2(middle - 2, floor_y - 4, 4, 4), DIM)
	var stride := maxi(3, mini(6, floori((size.y - 9.0) / MAX_SLOTS)))
	for index in range(occupied):
		var row := floor_y - 5 - (index + 1) * stride
		draw_rect(Rect2(middle - 17, row, 34, stride - 1), SHADE)
		draw_rect(Rect2(middle - 17, row, 34, 1), INK)
		if stride >= 4:
			for gap in [-12, -2, 8]:
				draw_rect(Rect2(middle + gap, row + 1, 4, stride - 2), DIM)
	draw_rect(Rect2(middle + 28, floor_y - 13, 5, 4), WHITE)
	draw_rect(Rect2(middle + 26, floor_y - 9, 9, 3), WHITE)
	draw_rect(Rect2(middle + 28, floor_y - 6, 2, 6), WHITE)
	draw_rect(Rect2(middle + 32, floor_y - 6, 2, 6), WHITE)

func _draw_opening() -> void:
	var radius := maxf(8.0, floorf(minf(52.0, (size.y - 6.0) / 2.0)))
	var center := Vector2(floorf(size.x / 2.0), floorf(size.y / 2.0))
	var sides := 2 << mini(polygon_step, 6)
	draw_arc(center, radius, 0.0, TAU, 64, LINE, 1.0)
	var outline := PackedVector2Array()
	for vertex in range(sides + 1):
		var angle := TAU * float(vertex) / float(sides)
		outline.append(center + (Vector2.from_angle(angle) * radius).round())
	draw_polyline(outline, INK, 2.0)
	if sides <= 8:
		for index in range(sides):
			draw_rect(Rect2(outline[index] - Vector2(2, 2), Vector2(4, 4)), INK)
