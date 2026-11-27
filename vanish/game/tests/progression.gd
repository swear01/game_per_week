extends SceneTree

const Run = preload("res://run.gd")
const Growth = preload("res://growth.gd")

func _initialize() -> void:
	var run := Run.new()
	var total := 0
	var passed := true
	for stage in Growth.count():
		var opening := run.display_value(0)
		var balance := run.balance_text()
		run.advance()
		passed = passed and run.stage == stage and not run.ready() and not opening.is_empty()
		passed = passed and run.balance_text() == balance
		var target := run.target()
		for i in target:
			if run.ready():
				passed = false
			run.grow()
		total += target
		passed = passed and run.ready() and not run.display_rule().is_empty()
		if stage + 1 < Growth.count():
			var quote := run.next_price()
			var cost := run.next_target()
			run.advance()
			passed = passed and run.target() == cost and run.display_value(cost) == quote
		else:
			run.advance()
	passed = passed and run.won
	for extra: int in [0, 1, 2, 5, 6, 13, 14, 1000]:
		run.reset()
		for i in (run.target() + extra):
			run.grow()
		var earned := int(extra >= 2) + int(extra >= 6) + int(extra >= 14)
		passed = passed and run.next_target() == Growth.safe_target(1, earned)
		run.advance()
		passed = passed and run.stage == 1 and run.step == 0 and not run.ready()
	run.reset()
	while Growth.key(run.stage) != "fib" and run.stage < Growth.count() - 1:
		for i in run.target():
			run.grow()
		run.advance()
	for i in 201:
		run.grow()
	passed = passed and not run.can_skip()
	run.grow()
	passed = passed and run.can_skip()
	passed = passed and run.cost_text().contains("÷ 2")
	var skipped := run.stage + 2
	run.advance()
	passed = passed and run.stage == skipped and run.target() == Growth.budget(skipped)
	passed = passed and run.display_value(0) == "3"
	passed = passed and run.balance_detail().contains("(F(204) − 1) − (F(142) − 1) ÷ 2")
	run.reset()
	while Growth.key(run.stage) != "tree" and run.stage < Growth.count() - 1:
		for i in run.target():
			run.grow()
		run.advance()
	for i in 1000:
		run.grow()
	run.advance()
	passed = passed and run.previous_record == "TREE(1001)" and run.display_value(0) == "SSCG(P)"
	for i in run.target():
		run.grow()
	var graph_record := "SSCG(TREE(1001) + %d)" % run.step
	run.advance()
	passed = passed and run.previous_record == graph_record
	passed = passed and run.balance_detail().contains("(%s − SSCG(TREE(1001))) ÷ 2" % graph_record)
	passed = check_carried_balance() and passed
	passed = check_legacy_balance() and passed
	if passed:
		print("Vanish: %d series, %d taps, handoffs, credit, shortcut and carried balance OK" % [Growth.count(), total])
	else:
		push_error("Progression regression")
	quit(0 if passed else 1)


func check_carried_balance() -> bool:
	var run := Run.new()
	var passed := check_amount(run.balance_text(), 1.0, "opening polygon balance")
	for i in 5:
		run.grow()
	passed = check_amount(run.cost_text(), 0.2851, "half of polygon's gain at the gate") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 1.2851, "polygon carry after paying") and passed
	passed = passed and run.display_value(0) == "0"
	run.grow()
	passed = check_amount(run.balance_text(), 2.2851, "carry plus the first harmonic gain") and passed
	for i in 39:
		run.grow()
	passed = check_amount(run.cost_text(), 2.1393, "half of the harmonic gain, excluding the carry") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 3.4244, "sum after paying at an additional handoff") and passed

	run.reset()
	for i in 7:
		run.grow()
	passed = check_amount(run.cost_text(), 0.2851, "extra growth does not raise the current cost") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 1.2857, "extra polygon growth remains in the carry") and passed
	passed = passed and run.target() == 39
	for i in 39:
		run.grow()
	passed = check_amount(run.cost_text(), 2.1268, "next cost uses the discounted gate") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 3.4124, "carry survives a discounted handoff") and passed
	return passed


func check_amount(displayed: String, expected: float, scenario: String) -> bool:
	var amount := displayed.strip_edges().trim_prefix("≈").replace(",", "")
	if not amount.is_valid_float() or absf(float(amount) - expected) > 0.00005:
		push_error("%s: expected %.4f, got %s" % [scenario, expected, displayed])
		return false
	return true


func check_legacy_balance() -> bool:
	var path := OS.get_temp_dir().path_join("vanish-progression-%d.json" % OS.get_process_id())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create isolated v1 fixture")
		return false
	file.store_string(JSON.stringify({"series": "triangular", "step": 0, "discount": 3,
		"previous_record": "841", "previous_title": "對數當加量", "won": false}))
	file.close()
	var migrated := Run.new()
	migrated.restore(path)
	var passed := check_amount(migrated.balance_text(), 841.0, "v1 opening") and migrated.target() == 122
	migrated.grow()
	passed = check_amount(migrated.balance_text(), 843.0, "v1 after growth") and passed
	passed = migrated.save_game(path) and passed
	var reopened := Run.new()
	reopened.restore(path)
	passed = check_amount(reopened.balance_text(), 843.0, "v1 after saving and reopening") and passed
	passed = reopened.step == 1 and reopened.target() == 122 and passed
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")
	return passed
