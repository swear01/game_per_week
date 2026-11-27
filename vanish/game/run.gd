extends RefCounted

const Growth = preload("res://growth.gd")
# The Fibonacci series starts at F(2): F(102) < 2^70 < F(103).
const FIB_SHORTCUT_STEP := 101
const POLYGON_FEE := 1.55
const CREDIT_STEPS := [2, 6, 14]
const NUMERIC_LIMIT := 1000000000.0
const SHORT_EXPRESSION_LIMIT := 38

var stage := 0
var step := 0
var won := false
var previous_record := ""
var previous_title := ""
var _discount := 0
var _previous_fee_unit := ""
var _last_surplus_label := "1"
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
	if stage == 0:
		return Growth.value(stage, step)
	var parameter := _current_parameter()
	var added := _numeric_gain(stage, step, parameter)
	var added_is_approximate := _uses_approximation(stage, step)
	if is_finite(_settled_number) and is_finite(added):
		return _format_amount(_settled_number + added, _settled_is_approximate or added_is_approximate)
	if step == 0:
		return _last_surplus_label
	var basis := "B%d" % _settled_detail.size()
	if is_finite(_settled_number):
		basis = _format_amount(_settled_number, _settled_is_approximate)
	var increase := _short_gain(stage, step, parameter)
	if is_finite(added):
		increase = _format_amount(added, added_is_approximate)
	return "%s + %s" % [basis, increase]

# Short form for narrow windows. Keep the changing index visible.
func compact_balance() -> String:
	var base := "B%d" % _settled_detail.size()
	return base if step == 0 else "%s + %s" % [base, _with_previous_fee(step, "Δ(%d)" % step)]

func compact_cost() -> String:
	return _with_previous_fee(target(), "Δ(%d)" % target())

func cost_text() -> String:
	if stage == 0:
		return str(POLYGON_FEE)
	var required := target()
	var parameter := _current_parameter()
	var price := _numeric_gain(stage, required, parameter)
	if is_finite(price):
		return _format_amount(price, _uses_approximation(stage, required))
	return _short_gain(stage, required, parameter)

func balance_detail() -> String:
	var count := _settled_detail.size()
	var parameter := _current_parameter()
	var lines := PackedStringArray(["B0 = 1", "Δ(n) 是本系從起點到第 n 下的新增量。"])
	if not _previous_fee_unit.is_empty():
		lines.append("Q 是上一系實付的躍遷價。每點承接一份 Q，再加本系這一步的新增量。")
	lines.append_array(_settled_detail)
	lines.append("目前餘額 = B%d + %s" % [count, _gain_expression(stage, step, parameter)])
	if stage + 1 < Growth.count():
		var price := str(POLYGON_FEE) if stage == 0 else _gain_expression(stage, target(), parameter)
		lines.append("躍遷價 = %s" % price)
	return "\n".join(lines)

func _current_parameter() -> String:
	return previous_record if _inherited_graph() else ""

func _short_gain(position: int, reached: int, parameter: String) -> String:
	var expression := _gain_expression(position, reached, "P" if not parameter.is_empty() else "")
	if expression.length() <= SHORT_EXPRESSION_LIMIT:
		return expression
	return _with_previous_fee(reached, "Δ%s(%d)" % [Growth.title(position), reached])

func _numeric_gain(position: int, reached: int, parameter: String) -> float:
	if reached == 0:
		return 0.0
	if not parameter.is_empty() or not _previous_fee_unit.is_empty():
		return NAN
	match Growth.key(position):
		"pi":
			if reached > 20:
				return NAN
			var sides := float(1 << (reached + 1))
			return sides * sin(PI / sides) / 2.0 - 1.0
		"harmonic", "inverse_sqrt":
			if reached > Growth.EXACT_ARITHMETIC_STEPS:
				return NAN
			var use_root := Growth.key(position) == "inverse_sqrt"
			var total := 0.0
			for i in range(1, reached + 1):
				total += 1.0 / (sqrt(float(i)) if use_root else float(i))
			return total
	var before := _integer_amount(Growth.value(position, 0))
	var after := _integer_amount(Growth.value(position, reached))
	return after - before

func _integer_amount(raw: String) -> float:
	# Only exact integer literals enter arithmetic here.
	var digits := raw.replace(",", "")
	if digits.length() > 10 or not digits.is_valid_int():
		return NAN
	var amount := float(int(digits))
	return amount if amount >= 0.0 and amount <= NUMERIC_LIMIT else NAN

func _uses_approximation(position: int, reached: int) -> bool:
	match Growth.key(position):
		"pi":
			return reached > 0
		"harmonic":
			return reached > 2
		"inverse_sqrt":
			return reached > 1
	return false

func _format_amount(amount: float, approximate: bool) -> String:
	var digits := str(int(amount)) if amount == floorf(amount) else String.num(amount, 4)
	return ("≈" if approximate else "") + digits

func _gain_expression(position: int, reached: int, parameter: String) -> String:
	if reached == 0:
		return "0"
	var before := _exact_value(position, 0, parameter)
	var after := _exact_value(position, reached, parameter)
	var raw := after if before == "0" else "(%s − %s)" % [after, before]
	return _with_previous_fee(reached, raw)

func _with_previous_fee(clicks: int, raw: String) -> String:
	if _previous_fee_unit.is_empty() or clicks == 0:
		return raw
	return "%d×%s + %s" % [clicks, _previous_fee_unit, raw]

func _exact_value(position: int, reached: int, parameter: String) -> String:
	match Growth.key(position):
		"pi":
			return "1" if reached == 0 else "2^%d × sin(π / 2^%d)" % [reached, reached + 1]
		"harmonic":
			return "0" if reached == 0 else "Σ 1/k（k = 1…%d）" % reached
		"inverse_sqrt":
			return "0" if reached == 0 else "Σ 1/√k（k = 1…%d）" % reached
		"pi_digits":
			return "⌊π × 10^%d⌋" % reached
		"sscg":
			if not parameter.is_empty():
				return _graph_value(reached, parameter)
		"beeping_beaver":
			if reached == 4:
				return "BBB(5)"
	return Growth.value(position, reached)

func _leap_contribution(position: int, reached: int, required: int, parameter: String, short: bool = false) -> String:
	if position == 0:
		var polygon_gain := _short_gain(position, reached, parameter) if short else _gain_expression(position, reached, parameter)
		return "%s − %s" % [polygon_gain, POLYGON_FEE]
	if reached == required:
		return "0"
	var reference := "P" if short and not parameter.is_empty() else parameter
	var after := _exact_value(position, reached, reference)
	var at_gate := _exact_value(position, required, reference)
	var surplus := _with_previous_fee(reached - required, "(%s − %s)" % [after, at_gate])
	if not short or surplus.length() <= SHORT_EXPRESSION_LIMIT:
		return surplus
	return "(%s) − (%s)" % [_short_gain(position, reached, parameter), _short_gain(position, required, parameter)]

func _settle_leap(position: int, reached: int, required: int, parameter: String) -> void:
	# Matching symbolic gains and prices cancel exactly at a full-price gate.
	if position == 0 or reached != required:
		var earned := _numeric_gain(position, reached, parameter)
		var price := POLYGON_FEE if position == 0 else _numeric_gain(position, required, parameter)
		if is_finite(_settled_number) and is_finite(earned) and is_finite(price):
			_settled_number += earned - price
			_settled_is_approximate = _settled_is_approximate or _uses_approximation(position, reached)
		else:
			_settled_number = NAN
	var count := _settled_detail.size()
	var contribution := _leap_contribution(position, reached, required, parameter)
	var price_expression := str(POLYGON_FEE) if position == 0 else _gain_expression(position, required, parameter)
	_settled_detail.append("B%d = B%d + %s（%s，扣 %s）" % [
		count + 1, count, contribution, Growth.title(position), price_expression,
	])
	if contribution != "0":
		_last_surplus_label = "B%d + %s" % [count, _leap_contribution(position, reached, required, parameter, true)]
	# The later constructions have incomparable native units. From Conway on,
	# each click also earns one copy of the actual preceding gate price.
	if Growth.key(position) == "graham" or not _previous_fee_unit.is_empty():
		_previous_fee_unit = "Q%d" % (position + 1)
		_settled_detail[-1] += "\n%s = %s" % [_previous_fee_unit, price_expression]

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
	_previous_fee_unit = ""
	stage = 0
	step = 0
	_discount = 0
	won = false
	previous_record = ""
	previous_title = ""
	_settled_number = 1.0
	_settled_is_approximate = false
	_settled_detail.clear()
	_last_surplus_label = "1"
