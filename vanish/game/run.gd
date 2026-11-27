extends RefCounted

const Growth = preload("res://growth.gd")
const SAVE_PATH := "user://vanish-v1.json"
# F(203) < 2^140 <= F(204). The Fibonacci series starts at F(2).
const FIB_SHORTCUT_STEP := 202
const CREDIT_STEPS := [2, 6, 14]
const NUMERIC_LIMIT := 1000000000.0
const SOURCE_LIMIT := 256
const SHORT_EXPRESSION_LIMIT := 38

var stage := 0
var step := 0
var won := false
var previous_record := ""
var previous_title := ""
var _discount := 0
var _opening := "1"
var _opening_stage := 0
var _migrated_opening := false
var _leaps: Array[Dictionary] = []
var _settled_number := 1.0
var _settled_is_approximate := false
var _settled_detail := PackedStringArray()

func target() -> int:
	return Growth.safe_target(stage, _discount)

func ready() -> bool:
	return not won and step >= target()

func skip_price() -> String:
	return _leap_skip_price(stage)

func _leap_skip_price(position: int) -> String:
	if Growth.key(position) == "fib" and position + 2 < Growth.count() and Growth.key(position + 1) == "double" and Growth.budget(position + 1) == 140:
		return Growth.value(position + 1, Growth.budget(position + 1))
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
	if stage == 0 and _leaps.is_empty() and _opening == "1":
		return Growth.value(stage, step)
	if step == 0 and _leaps.is_empty():
		return _opening
	var parameter := _current_parameter()
	var added := _numeric_gain(stage, step, parameter)
	var added_is_approximate := _uses_approximation(stage, step)
	if is_finite(_settled_number) and is_finite(added):
		return _format_amount(_settled_number + added, _settled_is_approximate or added_is_approximate)

	var count := _leaps.size()
	if step == 0 and count > 0:
		var last := _leaps[count - 1]
		var position := _position(last.series)
		var contribution := _short_gain(position, int(last.reached), String(last.parameter))
		var price := _short_gain(position, int(last.target), String(last.parameter))
		if last.reached == last.target:
			return "B%d + %s ÷ 2" % [count - 1, contribution]
		return "B%d + %s − %s ÷ 2" % [count - 1, contribution, price]
	var basis := "B%d" % count
	if is_finite(_settled_number):
		basis = _format_amount(_settled_number, _settled_is_approximate)
	elif count == 0 and _opening.length() <= SHORT_EXPRESSION_LIMIT:
		basis = _opening
	var increase := _short_gain(stage, step, parameter)
	if is_finite(added):
		increase = _format_amount(added, added_is_approximate)
	return "%s + %s" % [basis, increase]

func cost_text() -> String:
	var required := target()
	var parameter := _current_parameter()
	var gain := _numeric_gain(stage, required, parameter)
	if is_finite(gain):
		return _format_amount(gain * 0.5, _uses_approximation(stage, required))
	return "%s ÷ 2" % _short_gain(stage, required, parameter)

func balance_detail() -> String:
	var count := _leaps.size()
	var parameter := _current_parameter()
	var basis := "B0 = %s" % _opening
	if _migrated_opening:
		basis += "（來自舊存檔的上系紀錄，舊版只保存這一筆。）"
	var lines := PackedStringArray([basis])
	lines.append_array(_settled_detail)
	lines.append("目前餘額 = B%d + %s" % [count, _gain_expression(stage, step, parameter)])
	if stage + 1 < Growth.count():
		lines.append("躍遷價 = %s ÷ 2" % _gain_expression(stage, target(), parameter))
	return "\n".join(lines)

func _current_parameter() -> String:
	return previous_record if _inherited_graph() else ""

func _short_gain(position: int, reached: int, parameter: String) -> String:
	var expression := _gain_expression(position, reached, "P" if not parameter.is_empty() else "")
	if expression.length() <= SHORT_EXPRESSION_LIMIT:
		return expression
	return "Δ%s(%d)" % [Growth.title(position), reached]

func _numeric_gain(position: int, reached: int, parameter: String) -> float:
	if reached == 0:
		return 0.0
	if not parameter.is_empty():
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
	# Only exact integer literals enter arithmetic here. Approximate v1 quotes stay symbolic.
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
	if before == "0":
		return after
	return "(%s − %s)" % [after, before]

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

func _settle_leap(position: int, reached: int, required: int, parameter: String) -> void:
	var earned := _numeric_gain(position, reached, parameter)
	var required_gain := earned if reached == required else _numeric_gain(position, required, parameter)
	if is_finite(_settled_number) and is_finite(earned) and is_finite(required_gain):
		_settled_number += earned - required_gain * 0.5
		_settled_is_approximate = _settled_is_approximate or _uses_approximation(position, reached)
	else:
		_settled_number = NAN

	var required_expression := _gain_expression(position, required, parameter)
	var contribution := "%s ÷ 2" % required_expression
	if reached != required:
		contribution = "%s − %s ÷ 2" % [
			_gain_expression(position, reached, parameter), required_expression,
		]
	var count := _leaps.size()
	_settled_detail.append("B%d = B%d + %s（%s）" % [
		count + 1, count, contribution, Growth.title(position),
	])
	_leaps.append({
		"series": Growth.key(position), "reached": reached, "target": required,
		"parameter": parameter,
	})

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
	var next_stage := stage + (2 if can_skip() else 1)
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
	stage = 0
	step = 0
	_discount = 0
	won = false
	previous_record = ""
	previous_title = ""
	_initialize_economy(0, "1", false)

func save_game(save_path: String = SAVE_PATH) -> bool:
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("進度儲存失敗：%s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({
		"series": Growth.key(stage), "step": step, "discount": _discount,
		"previous_record": previous_record, "previous_title": previous_title, "won": won,
		"economy": {
			"start": Growth.key(_opening_stage), "opening": _opening,
			"migrated": _migrated_opening, "leaps": _leaps,
		}
	}))
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path))
	if result != OK:
		push_warning("進度儲存失敗：%s" % error_string(result))
	return result == OK

func restore(save_path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	var position := _position(data.get("series"))
	if position < 0 or not _valid_natural(data.get("step")) or not _valid_natural(data.get("discount")):
		return
	if data.discount > CREDIT_STEPS.size() or not data.get("won") is bool:
		return
	if not data.get("previous_record") is String or not data.get("previous_title") is String:
		return
	if data.has("economy"):
		if not _restore_economy(data.economy, position):
			return
	else:
		var prior := String(data.previous_record)
		if not _valid_source(prior):
			return
		var opening := Growth.value(position, 0) if prior.is_empty() else prior
		_initialize_economy(position, opening, not prior.is_empty())
	stage = position
	step = int(data.step)
	_discount = int(data.discount)
	previous_record = data.previous_record
	previous_title = data.previous_title
	won = data.won and stage == Growth.count() - 1 and step >= target()

func _initialize_economy(origin: int, opening: String, migrated: bool) -> void:
	_opening_stage = origin
	_opening = opening
	_migrated_opening = migrated
	_settled_number = _integer_amount(opening)
	_settled_is_approximate = false
	_settled_detail.clear()
	_leaps.clear()

func _restore_economy(economy: Variant, current: int) -> bool:
	if not economy is Dictionary:
		return false
	var origin := _position(economy.get("start"))
	var opening: Variant = economy.get("opening")
	var migrated: Variant = economy.get("migrated")
	var entries: Variant = economy.get("leaps")
	if origin < 0 or origin > current or not _valid_source(opening):
		return false
	if String(opening).is_empty() or not migrated is bool or not entries is Array or entries.size() >= Growth.count():
		return false
	var expected := origin
	for entry: Variant in entries:
		if not entry is Dictionary or expected >= current or entry.get("series") != Growth.key(expected):
			return false
		if not _valid_natural(entry.get("reached")) or not _valid_natural(entry.get("target")):
			return false
		if not _valid_source(entry.get("parameter")):
			return false
		if not String(entry.parameter).is_empty() and Growth.key(expected) != "sscg":
			return false
		var required := int(entry.target)
		if required < Growth.safe_target(expected, CREDIT_STEPS.size()) or required > Growth.budget(expected):
			return false
		if int(entry.reached) < required:
			return false
		if not _leap_skip_price(expected).is_empty() and int(entry.reached) >= FIB_SHORTCUT_STEP:
			expected += 2
		else:
			expected += 1
	if expected != current:
		return false
	_initialize_economy(origin, String(opening), bool(migrated))
	for entry: Dictionary in entries:
		_settle_leap(_position(entry.series), int(entry.reached), int(entry.target), String(entry.parameter))
	return true

func _position(series: Variant) -> int:
	for i in Growth.count():
		if Growth.key(i) == series:
			return i
	return -1

func _valid_source(source: Variant) -> bool:
	return source is String and String(source).length() <= SOURCE_LIMIT and not String(source).contains("\n")

func _valid_natural(number: Variant) -> bool:
	return (number is float or number is int) and is_finite(number) and number >= 0 and float(number) == floorf(number) and number < 9007199254740992.0
