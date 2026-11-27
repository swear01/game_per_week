extends RefCounted

const Growth = preload("res://growth.gd")
const SAVE_PATH := "user://vanish-v1.json"
# F(203) < 2^140 <= F(204). The Fibonacci series starts at F(2).
const FIB_SHORTCUT_STEP := 202
const CREDIT_STEPS := [2, 6, 14]

var stage := 0
var step := 0
var won := false
var previous_record := ""
var previous_title := ""
var _discount := 0

func target() -> int:
	return Growth.safe_target(stage, _discount)

func ready() -> bool:
	return not won and step >= target()

func skip_price() -> String:
	if Growth.key(stage) == "fib" and stage + 2 < Growth.count() and Growth.key(stage + 1) == "double" and Growth.budget(stage + 1) == 140:
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

func save_game() -> bool:
	var temporary := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("進度儲存失敗：%s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({
		"series": Growth.key(stage), "step": step, "discount": _discount,
		"previous_record": previous_record, "previous_title": previous_title, "won": won
	}))
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(SAVE_PATH))
	if result != OK:
		push_warning("進度儲存失敗：%s" % error_string(result))
	return result == OK

func restore() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	var position := -1
	for i in Growth.count():
		if Growth.key(i) == data.get("series"):
			position = i
			break
	if position < 0 or not _valid_natural(data.get("step")) or not _valid_natural(data.get("discount")):
		return
	if data.discount > CREDIT_STEPS.size() or not data.get("won") is bool:
		return
	if not data.get("previous_record") is String or not data.get("previous_title") is String:
		return
	stage = position
	step = int(data.step)
	_discount = int(data.discount)
	previous_record = data.previous_record
	previous_title = data.previous_title
	won = data.won and stage == Growth.count() - 1 and step >= target()

func _valid_natural(number: Variant) -> bool:
	return (number is float or number is int) and is_finite(number) and number >= 0 and float(number) == floorf(number) and number < 9007199254740992.0
