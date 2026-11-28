extends RefCounted

const Growth = preload("res://growth.gd")
const Polygon = preload("res://polygon.gd")
# The Fibonacci series starts at F(2): F(102) < 2^70 < F(103).
const FIB_SHORTCUT_STEP := 101
const POLYGON_FEE := 1.55
const CREDIT_STEPS := [2, 6, 14]
const EXACT_FLOAT_LIMIT := 9007199254740992.0
const SCIENTIFIC_LIMIT := 1000000.0
const LOG10_2 := 0.3010299956639812
const NO_LOG := -INF
const CIRCLE_EXACT_LIMIT := 32768

var stage := 0
var step := 0
var won := false
var previous_record := ""
var previous_title := ""
var _discount := 0
var _previous_fee := ""
var _carried_log := NO_LOG
var _carried_bound := ""
var _fee_bound := ""
var _fee_multiple := 1
var _settled_number := 1.0
var _settled_is_approximate := false
var _settled_detail := PackedStringArray()

func target() -> int:
	return Growth.safe_target(stage, _discount)

func ready() -> bool:
	return not won and step >= target()

func skip_price() -> String:
	if Growth.key(stage) == "fib" and stage + 2 < Growth.count() and Growth.key(stage + 1) == "double" and Growth.budget(stage + 1) == 70:
		return Growth.value(stage + 1, Growth.budget(stage + 1))
	return ""

func can_skip() -> bool:
	return ready() and step >= FIB_SHORTCUT_STEP and not skip_price().is_empty()

func credit() -> int:
	if not ready() or stage + 1 >= Growth.count() or can_skip():
		return 0
	var earned := 0
	for threshold: int in CREDIT_STEPS:
		if step - target() >= threshold:
			earned += 1
	return Growth.budget(stage + 1) - Growth.safe_target(stage + 1, earned)

func next_target() -> int:
	var next_stage := stage + (2 if can_skip() else 1)
	if next_stage >= Growth.count():
		return 0
	return Growth.safe_target(next_stage, credit())

func next_price() -> String:
	var next_stage := stage + (2 if can_skip() else 1)
	if next_stage >= Growth.count():
		return ""
	if Growth.key(next_stage) == "sscg" and Growth.key(stage) == "tree":
		return _graph_value(next_target())
	return Growth.value(next_stage, next_target())

func _graph_value(index: int, parameter: String = "P") -> String:
	if index == 0:
		return "SSCG(%s)" % parameter
	return "SSCG(%s + %d)" % [parameter, index]

func _inherited_graph() -> bool:
	return Growth.key(stage) == "sscg" and not previous_record.is_empty()

func display_value(index: int) -> String:
	if _inherited_graph():
		return _graph_value(index)
	return Growth.value(stage, index)

func display_rule() -> String:
	if _inherited_graph():
		return "P 是上系紀錄。每一下，圖的頂點額度再加 1。"
	return Growth.rule(stage, step)

func balance_text() -> String:
	return _visible_balance(52)

func compact_balance() -> String:
	return _visible_balance(25)

func cost_text() -> String:
	return _visible_cost(48)

func compact_cost() -> String:
	return _visible_cost(25)

func _visible_balance(width: int) -> String:
	if stage == 0:
		var value := Polygon.value(step)
		if value.length() <= width:
			return value
		return value.left(width - 1).trim_suffix(".") + "…"
	return _visible_amount(step, true, false, width)

func _visible_cost(width: int) -> String:
	if stage == 0:
		return str(POLYGON_FEE)
	return _visible_amount(target(), false, false, width)

func last_increment_text(width: int = 25) -> String:
	if step <= 0:
		return "0"
	if stage == 0:
		return Polygon.delta(step).replace(" ", "").replace("e−", "×10^−")
	return _visible_amount(step, false, true, width)

func _visible_amount(reached: int, balance: bool, increment: bool, width: int) -> String:
	var parameter := _current_parameter()
	var numeric := _numeric_increment(stage, reached, parameter) if increment else _numeric_gain(stage, reached, parameter)
	var numeric_known := is_finite(numeric)
	var current_log := NO_LOG
	var native := ""
	var bound := ""
	if not numeric_known:
		var from := reached - 1 if increment else 0
		current_log = _difference_log(_value_log(stage, reached), _value_log(stage, from))
		if current_log == NO_LOG:
			native = _visible_native(stage, reached, parameter, increment)
			bound = _symbolic_bound(stage, reached, from)
		numeric = 0.0
	var amount := numeric + (_settled_number if balance else 0.0)
	var amount_log := _add_logs(current_log, _carried_log if balance else NO_LOG)
	var taps := 1 if increment else reached
	var covered := _covered_native(stage, reached, reached - 1 if increment else 0, parameter)
	var fee_floor := _fee_floor(taps, width)
	if balance and not _carried_bound.is_empty():
		if _carried_bound.is_valid_float():
			if not covered.is_empty() and covered.length() < width:
				return "≥" + covered
			if not fee_floor.is_empty():
				return "≥" + fee_floor
			if current_log > _log10(float(_carried_bound)) + 1.0:
				return "≥10^%d" % floori(current_log - 1.0)
			if not bound.is_empty() and not bound.is_valid_float() and not bound.contains("×10^"):
				return "≥" + bound
		return "≥" + _carried_bound
	if not covered.is_empty() and covered.length() < width:
		return "≥" + covered
	if not fee_floor.is_empty():
		return "≥" + fee_floor
	if balance and _carried_log != NO_LOG and current_log == NO_LOG and not numeric_known:
		# Preserve the witnessed scale when the current term cannot be compared.
		return "≥10^%d" % floori(_carried_log - 1.0)
	if not bound.is_empty() and (native.is_empty() or native.length() + 1 > width or amount_log != NO_LOG):
		return "≥" + bound
	if not native.is_empty():
		return "≈" + native
	if amount_log != NO_LOG:
		var combined := _add_logs(amount_log, _log10(amount) if amount > 0.0 else NO_LOG)
		return "≈" + _scientific(combined, width)
	if not numeric_known:
		return "—"
	return _format_amount(amount, (balance and _settled_is_approximate) or _gain_is_approximate(stage, reached, amount), width)

# Graham's fee, and hence every later fee, exceeds any signed integer.
# If the subtracted term is a known integer, one inherited fee covers it.
func _covered_native(position: int, reached: int, from: int, parameter: String) -> String:
	if _fee_bound.is_empty() or reached <= from or not parameter.is_empty():
		return ""
	if not is_finite(_integer_amount(_exact_value(position, from, ""))):
		return ""
	var current := _exact_value(position, reached, "")
	if is_finite(_integer_amount(current)):
		return ""
	return _visible_native(position, reached, "", false)

func _fee_floor(taps: int, width: int) -> String:
	if taps <= 0 or _fee_bound.is_empty():
		return ""
	var multiple := _fee_multiple * mini(taps, 1000000000000 / _fee_multiple)
	var bound := "%d×%s" % [multiple, _fee_bound]
	if multiple <= 1 or bound.length() + 1 > width:
		return _fee_bound
	return bound


func _visible_native(position: int, reached: int, parameter: String, increment: bool) -> String:
	var key := Growth.key(position)
	if not parameter.is_empty() or reached == 0:
		return ""
	match key:
		"square":
			return "2^(2^%d)" % reached
		"growing_power":
			return "2^(%d!)" % (reached + 1)
		"graphs":
			return "2^C(%d,2)" % (reached + 2)
		"variable_arrows":
			if reached >= 2:
				return "3↑{%d}3" % (reached + 1)
		"fib":
			return "F(%d)" % (reached if increment else reached + 2)
		"partitions", "plane_partitions", "square_partitions":
			# The nth partition count is not an approximation of its first difference.
			if increment:
				return ""
		"primes", "lattice_circle", "golomb", "sscg", "tree", "busy_beaver", "beeping_beaver", "oracle_beaver", "rayo":
			if increment:
				return ""
		"fast_goodstein", "bowers", "conway":
			if increment:
				return ""
	var value := _exact_value(position, reached, "").replace(" ", "")
	if value.contains("+") or value.contains("−") or value.contains("Σ") or value.contains(">"):
		return ""
	return value

func _symbolic_bound(position: int, reached: int, from: int) -> String:
	if reached <= from:
		return ""
	match Growth.key(position):
		"square_partitions":
			if from == 0 and reached > 279:
				return str(Growth._partitions(400, true) - Growth._partitions(121, true))
			# Partitions without a 1 are new. Every nonnegative solution
			# 4x + 9y = 121 + reached is one, with one y in each group of four.
			@warning_ignore("integer_division")
			var minimum := reached / 36 + (reached % 36 + 121) / 36
			return str(minimum) if minimum < SCIENTIFIC_LIMIT else _scientific(_log10(float(minimum)), 25, true)
		"partitions", "plane_partitions":
			return _format_amount(float(reached - from), false, 25).trim_prefix("≈") if reached - from < 1000000 else _scientific(_log10(float(reached - from)), 25, true)
		"primes", "lattice_circle":
			var minimum := float(reached - from) * (4.0 if Growth.key(position) == "lattice_circle" else 1.0)
			return _format_amount(minimum, false, 25) if minimum < SCIENTIFIC_LIMIT else _scientific(_log10(minimum), 25, true)
		"graphs", "square", "growing_power", "tower", "tower_double", "tower_in_tower", "triple", "quadruple", "quintuple", "sextuple", "variable_arrows", "graham":
			# Each of these integer sequences at least doubles at each step.
			if reached >= 2:
				var previous := _visible_native(position, reached - 1, "", false)
				if previous.length() > 24:
					previous = _visible_native(position, mini(reached - 1, 1000000), "", false)
				if not previous.is_empty() and previous.length() <= 24:
					return previous
			return "1"
	return ""

func _log10(value: float) -> float:
	return log(value) / log(10.0)

func _value_log(position: int, reached: int) -> float:
	var n := float(reached)
	match Growth.key(position):
		"fib":
			if reached > 90:
				var value := (n + 2.0) * _log10((1.0 + sqrt(5.0)) * 0.5) - _log10(sqrt(5.0))
				return value if value < 1000000000000.0 else NO_LOG
		"double":
			return n * LOG10_2 if n < 1000000000000.0 else NO_LOG
		"pi_digits":
			if reached >= 15 and n < 1000000000000.0:
				return n + _log10(PI)
		"factorial":
			if reached > 18:
				var k := n + 2.0
				# Stirling with the first correction; the next term is < 4e-7 here.
				var result := ((k + 0.5) * log(k) - k + 0.5 * log(TAU) + 1.0 / (12.0 * k)) / log(10.0)
				return result if result < 1000000000000.0 else NO_LOG
		"graphs":
			var digits := (n + 2.0) * (n + 1.0) * 0.5 * LOG10_2
			return digits if digits < 1000000000000.0 else NO_LOG
		"square":
			return pow(2.0, n) * LOG10_2 if reached <= 41 else NO_LOG
		"growing_power":
			if reached <= 14:
				return float(Growth._factorial(reached + 1)) * LOG10_2
	var value := _integer_amount(Growth.value(position, reached))
	return _log10(value) if is_finite(value) and value > 0.0 else NO_LOG

func _difference_log(later: float, earlier: float) -> float:
	if later == NO_LOG or later <= earlier:
		return NO_LOG
	if earlier == NO_LOG:
		return later
	return later + _log10(1.0 - pow(10.0, earlier - later))

func _add_logs(a: float, b: float) -> float:
	var largest := maxf(a, b)
	if largest == NO_LOG:
		return NO_LOG
	return largest + _log10(1.0 + pow(10.0, minf(a, b) - largest))

func _numeric_increment(position: int, reached: int, parameter: String) -> float:
	var key := Growth.key(position)
	var n := float(reached)
	match key:
		"harmonic":
			return 1.0 / n
		"inverse_sqrt":
			return 1.0 / sqrt(n)
		"wave":
			return float(Growth.WAVE[(reached - 1) % Growth.WAVE.size()])
		"log_add":
			return float(Growth._bit_length(reached))
		"triangular":
			var candidate := int((sqrt(8.0 * n + 1.0) - 1.0) / 2.0)
			# At large indices the float estimate can straddle an integer boundary.
			for index in range(maxi(1, candidate - 1), candidate + 2):
				var left := (index >> 1) if index % 2 == 0 else index
				var right := index + 1 if index % 2 == 0 else ((index + 1) >> 1)
				@warning_ignore("integer_division")
				if reached % left == 0 and reached / left == right:
					return n + 1.0
			return 1.0
		"rule90":
			var rows := reached
			var lights := 1.0
			while rows > 0:
				rows &= rows - 1
				lights *= 2.0
			return lights
		"primes":
			if reached < 4096:
				return n + 1.0 if Growth._is_prime(reached) else 1.0
		"golomb":
			var next := mini(reached, 0x7ffffffffffffffe) + 1
			return float(Growth.golomb(next) - Growth.golomb(reached))
		"lattice_circle":
			if reached <= CIRCLE_EXACT_LIMIT:
				return float(Growth._circle_points(reached + 1) - Growth._circle_points(reached))
			return NAN
		"sandpile":
			var radius := float(reached >> 1)
			return 1.0 + radius * radius if reached % 2 == 0 else 1.0
		"fib":
			# F(n+2) − F(n+1) = F(n).
			if reached <= 92:
				return _integer_amount(Growth.value(position, reached - 2)) if reached > 1 else 1.0
			if reached < 1430:
				return pow((1.0 + sqrt(5.0)) * 0.5, n) / sqrt(5.0)
		"double":
			if reached < 990:
				return pow(2.0, n - 1.0)
	var current := _numeric_gain(position, reached, parameter)
	var previous := _numeric_gain(position, reached - 1, parameter)
	return current - previous

func _increment_expression(position: int, reached: int, parameter: String) -> String:
	match Growth.key(position):
		"fib":
			return "F(%d)" % reached
		"double":
			return "2^%d" % (reached - 1)
		"factorial":
			return "%d×%d!" % [reached + 1, reached + 1]
		"primes":
			return "1 + %d×[%d 為質數]" % [reached, reached]
		"sscg":
			if not parameter.is_empty():
				parameter = "P"
	var current := _exact_value(position, reached, parameter)
	var previous := _exact_value(position, reached - 1, parameter)
	return current if previous == "0" else "(%s − %s)" % [current, previous]

func _sum_text(first: String, second: String) -> String:
	if second.is_empty() or second == "0":
		return first
	if first.is_empty() or first == "0":
		return second
	return "%s + %s" % [first, second]

func balance_detail() -> String:
	var parameter := _current_parameter()
	var lines := PackedStringArray(["起始餘額 1 元"])
	lines.append_array(_settled_detail)
	lines.append("再加本系新增量 %s" % _gain_expression(stage, step, parameter))
	if step > 0:
		lines.append("本下新增量 = %s" % _sum_text(_increment_expression(stage, step, parameter), _previous_fee))
	if stage + 1 < Growth.count():
		lines.append("躍遷價 = %s" % _price_expression(stage, target(), parameter))
	return "\n".join(lines)

func _current_parameter() -> String:
	return previous_record if _inherited_graph() else ""

func _numeric_gain(position: int, reached: int, parameter: String) -> float:
	if reached == 0:
		return 0.0
	if not parameter.is_empty():
		return NAN
	var key := Growth.key(position)
	var n := float(reached)
	match key:
		"pi":
			# The arcs are already indistinguishable from π/2 at float precision here.
			if reached > 26:
				return PI / 2.0 - 1.0
			var sides := float(1 << (reached + 1))
			return sides * sin(PI / sides) / 2.0 - 1.0
		"harmonic", "inverse_sqrt":
			if reached > Growth.EXACT_ARITHMETIC_STEPS:
				# Euler–Maclaurin tails for H_n and the generalized H_(n, 1/2).
				if key == "harmonic":
					return log(n) + 0.5772156649015329 + 0.5 / n - 1.0 / (12.0 * n * n)
				return 2.0 * sqrt(n) - 1.4603545088095868 + 0.5 / sqrt(n) - 1.0 / (24.0 * n * sqrt(n))
			var total := 0.0
			for i in range(1, reached + 1):
				total += 1.0 / (sqrt(float(i)) if key == "inverse_sqrt" else float(i))
			return total
		"wave":
			var total := (n - float(reached % 8)) * 3.0
			for i in range(reached % 8):
				total += float(Growth.WAVE[i])
			return total
		"log_add":
			var bits := Growth._bit_length(reached)
			return (n + 1.0) * bits - pow(2.0, bits) + 1.0
		"triangular":
			var bursts := floorf((sqrt(8.0 * n + 1.0) - 1.0) / 2.0)
			return n + bursts * (bursts + 1.0) * (bursts + 2.0) / 6.0
		"sandpile":
			var radius := float(reached >> 1)
			return n + radius * (radius + 1.0) * (radius * 2.0 + 1.0) / 6.0
		"rule90":
			if reached > 1000000:
				return _rule90_gain(reached)
		"lattice_circle":
			if reached <= CIRCLE_EXACT_LIMIT:
				return float(Growth._circle_points(reached + 1) - Growth._circle_points(1))
			return PI * (n + 1.0) * (n + 1.0) - Growth._circle_points(1)
		"fib":
			if reached > 90 and reached < 1430:
				return pow((1.0 + sqrt(5.0)) * 0.5, n + 2.0) / sqrt(5.0) - 1.0
		"double":
			if reached >= 63 and reached < 990:
				return pow(2.0, n) - 1.0
		"pi_digits":
			if reached >= 15 and reached < 295:
				return PI * pow(10.0, n) - 3.0
		"factorial":
			if reached > 18 and reached < 160:
				var product := 1.0
				for i in range(2, reached + 3):
					product *= float(i)
				return product - 2.0
		"graphs":
			if reached > 9 and reached <= 42:
				return pow(2.0, (n + 2.0) * (n + 1.0) * 0.5) - 2.0
		"square":
			if reached >= 6 and reached <= 9:
				return pow(2.0, pow(2.0, n)) - 2.0
		"growing_power":
			if reached == 4 or reached == 5:
				return pow(2.0, Growth._factorial(reached + 1)) - 2.0
	var before := _integer_amount(Growth.value(position, 0))
	var after := _integer_amount(Growth.value(position, reached))
	return after - before

func _rule90_gain(reached: int) -> float:
	# Avoid adding one to the signed step counter. Read the prefix by set bits,
	# then account for the final row itself.
	var total := 0.0
	var scale := 1.0
	for bit in range(Growth._bit_length(reached) - 1, -1, -1):
		if reached & (1 << bit):
			total += scale * pow(3.0, bit)
			scale *= 2.0
	return total + scale - 1.0

func _integer_amount(raw: String) -> float:
	var digits := raw.replace(",", "")
	if digits.length() > 19 or not digits.is_valid_int():
		return NAN
	var amount := float(digits)
	return amount if amount >= 0.0 else NAN

func _gain_is_approximate(position: int, reached: int, value: float) -> bool:
	match Growth.key(position):
		"pi":
			return reached > 0
		"harmonic":
			return reached > 2
		"inverse_sqrt":
			return reached > 1
		"lattice_circle":
			return reached > CIRCLE_EXACT_LIMIT
	return absf(value) >= EXACT_FLOAT_LIMIT

func _format_amount(amount: float, approximate: bool, width: int) -> String:
	if amount >= SCIENTIFIC_LIMIT or (amount > 0.0 and amount < 0.0001):
		return "≈" + _scientific(_log10(amount), width)
	var digits := str(int(amount)) if amount == floorf(amount) else String.num(amount, 4)
	return ("≈" if approximate else "") + digits

func _scientific(logarithm: float, width: int, down: bool = false) -> String:
	var exponent := floori(logarithm)
	var suffix := "×10^" + str(exponent).replace("-", "−")
	var precision := clampi(width - suffix.length() - 3, 0, 5)
	var places := pow(10.0, precision)
	var unrounded := pow(10.0, logarithm - exponent) * places
	var mantissa := (floorf(unrounded - 0.000001) if down else roundf(unrounded)) / places
	if mantissa >= 10.0:
		mantissa = 1.0
		suffix = "×10^" + str(exponent + 1).replace("-", "−")
	return String.num(mantissa, precision) + suffix

func _native_gain(position: int, reached: int, parameter: String) -> String:
	if reached == 0:
		return "0"
	var before := _exact_value(position, 0, parameter)
	var after := _exact_value(position, reached, parameter)
	return after if before == "0" else "(%s − %s)" % [after, before]

func _gain_expression(position: int, reached: int, parameter: String) -> String:
	return _sum_text("0" if reached == 0 else _native_gain(position, reached, parameter), _scaled_fee(reached, _previous_fee))

func _scaled_fee(clicks: int, fee: String) -> String:
	if clicks <= 0 or fee.is_empty():
		return ""
	if clicks == 1:
		return fee
	var grouped := fee if fee.begins_with("(") and fee.ends_with(")") and not fee.contains(" + ") else "(%s)" % fee
	return "%d×%s" % [clicks, grouped]

func _price_expression(position: int, required: int, parameter: String) -> String:
	return str(POLYGON_FEE) if position == 0 else _gain_expression(position, required, parameter)

func _exact_value(position: int, reached: int, parameter: String) -> String:
	match Growth.key(position):
		"pi":
			return "1" if reached == 0 else "2^%d × sin(π / 2^%d)" % [reached, reached + 1]
		"harmonic":
			return "0" if reached == 0 else "Σ₁…%d 1/k" % reached
		"inverse_sqrt":
			return "0" if reached == 0 else "Σ₁…%d 1/√k" % reached
		"pi_digits":
			return "3" if reached == 0 else "⌊π·10^%d⌋" % reached
		"sscg":
			if not parameter.is_empty():
				return _graph_value(reached, parameter)
		"conway":
			return "27" if reached == 0 else "(%s)" % Growth.value(position, reached)
		"beeping_beaver":
			if reached == 4:
				return "BBB(5)"
	return Growth.value(position, reached)

func _settle_leap(position: int, reached: int, required: int, parameter: String) -> void:
	# Matching symbolic gains and prices cancel exactly at a full-price gate.
	var earned := _numeric_gain(position, reached, parameter)
	var at_gate := _numeric_gain(position, required, parameter)
	var price := _price_expression(position, required, parameter)
	var contribution := "0"
	if position == 0:
		_settled_number += earned - POLYGON_FEE
		_settled_is_approximate = true
		contribution = "%s − %s" % [_exact_value(position, reached, parameter), POLYGON_FEE]
	elif reached != required:
		var after := _exact_value(position, reached, parameter)
		var gate_value := _exact_value(position, required, parameter)
		var native := "(%s − %s)" % [after, gate_value]
		var fee := _scaled_fee(reached - required, _previous_fee)
		contribution = _sum_text(native, fee)
		if is_finite(earned) and is_finite(at_gate):
			_settled_number += earned - at_gate
			_settled_is_approximate = _settled_is_approximate or _gain_is_approximate(position, reached, earned)
		else:
			var amount_log := _difference_log(_value_log(position, reached), _value_log(position, required))
			if amount_log != NO_LOG:
				_carried_log = _add_logs(_carried_log, amount_log)
			else:
				var bound := _symbolic_bound(position, reached, required)
				if not bound.is_empty() and (_carried_bound.is_empty() or (_carried_bound.is_valid_float() and not bound.is_valid_float())):
					_carried_bound = bound
		if not fee.is_empty() and _carried_bound.is_empty():
			_carried_bound = _fee_floor(reached - required, 25)

	_settled_detail.append("%s：支付 %s，餘留 %s" % [Growth.title(position), price, contribution])
	# From Conway on, each click also earns the actual preceding gate price.
	if Growth.key(position) == "graham":
		_fee_bound = _symbolic_bound(position, required, 0)
		_previous_fee = price
	elif not _fee_bound.is_empty():
		var covered := _covered_native(position, required, 0, parameter)
		if not covered.is_empty() and covered.length() <= 24:
			_fee_bound = covered
			_fee_multiple = 1
		else:
			_fee_multiple *= mini(required, 1000000000000 / _fee_multiple)
		_previous_fee = price


func comparison() -> String:
	if previous_record.is_empty() or stage == 0:
		return ""
	var former := Growth.key(stage - 1)
	if former == "wave" and Growth.key(stage) == "log_add":
		var current := display_value(step).replace(",", "")
		if current.is_valid_int() and current.length() < 17:
			var goal := int(current)
			if goal <= 0:
				return "用上一系需點 0 下"
			@warning_ignore("integer_division")
			var cycles := (goal - 1) / 24
			var needed := cycles * 8
			var total := cycles * 24
			for delta: int in [4, 5, 4, 3, 2, 1, 2, 3]:
				total += delta
				needed += 1
				if total >= goal:
					break
			return "用上一系需點 %d 下" % needed
	if former == "fib" and Growth.key(stage) == "double" and step <= 60:
		var goal := 1 << step
		var a := 1
		var b := 2
		var needed := 0
		while a < goal:
			var next := a + b
			a = b
			b = next
			needed += 1
		return "用費波那契需點 %d 下" % needed
	if former == "fib" and Growth.key(stage) == "double":
		var estimate := ceili((step * log(2.0) + log(sqrt(5.0))) / log((1.0 + sqrt(5.0)) / 2.0)) - 2
		return "用費波那契約需點 %d 下" % estimate
	return ""

func grow() -> void:
	if not won:
		step += 1

func advance() -> void:
	if not ready():
		return
	if stage == Growth.count() - 1:
		won = true
		return
	var skipped := can_skip()
	var next_stage := stage + (2 if skipped else 1)
	var next_discount := credit()
	_settle_leap(stage, step, target(), _current_parameter())
	var record := display_value(step)
	if _inherited_graph():
		record = _graph_value(step, previous_record)
	previous_record = record
	previous_title = Growth.title(stage)
	stage = next_stage
	step = 0
	_discount = next_discount

func reset() -> void:
	_previous_fee = ""
	_carried_log = NO_LOG
	_carried_bound = ""
	_fee_bound = ""
	_fee_multiple = 1
	stage = 0
	step = 0
	_discount = 0
	won = false
	previous_record = ""
	previous_title = ""
	_settled_number = 1.0
	_settled_is_approximate = false
	_settled_detail.clear()
