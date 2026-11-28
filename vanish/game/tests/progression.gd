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
		if Growth.key(stage) == "busy_beaver":
			passed = passed and run.cost_text().begins_with("≥")
			passed = passed and run.balance_detail().contains("躍遷價 = 47,176,870 + 108×(")
			passed = passed and run.balance_detail().contains("(SSCG(TREE(3) + 7) − SSCG(TREE(3))) + 7×(")

		for i in target:
			if run.ready():
				passed = false
			run.grow()
		total += target
		passed = passed and run.ready() and not run.display_rule().is_empty()
		passed = check_public_amounts(run, "default threshold " + Growth.key(stage)) and passed
		if Growth.key(stage) == "graphs":
			passed = passed and run.balance_text() == "≈1.79799×10^951" and run.cost_text() == run.balance_text()
		if Growth.key(stage) == "tower":
			passed = passed and run.balance_text() == "≈2↑↑79"
		if stage + 1 < Growth.count():
			var quote := run.next_price()
			var cost := run.next_target()
			run.advance()
			passed = passed and run.target() == cost and run.display_value(cost) == quote
			if stage > 0:
				passed = passed and run.balance_text() == balance
		else:
			run.advance()
	passed = passed and run.won and total == 2586
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
	for i in 100:
		run.grow()
	passed = passed and not run.can_skip()
	run.grow()
	passed = passed and run.can_skip()
	passed = passed and not run.cost_text().contains("÷ 2")
	var skipped := run.stage + 2
	var before_shortcut := run.balance_text()
	run.advance()
	passed = passed and before_shortcut.begins_with("≈") and run.balance_text().begins_with("≈")
	passed = passed and run.balance_text().contains("10^21")
	passed = passed and run.stage == skipped and run.target() == Growth.budget(skipped)
	passed = passed and run.display_value(0) == "3"
	passed = passed and run.balance_detail().contains("(F(103) − 498454011879264)")
	run.reset()
	while Growth.key(run.stage) != "tree" and run.stage < Growth.count() - 1:
		for i in run.target():
			run.grow()
		run.advance()
	for i in 1000:
		run.grow()
	run.advance()
	passed = passed and run.previous_record == "TREE(1001)" and run.display_value(0) == "SSCG(P)"
	passed = passed and run.balance_detail().contains("(TREE(1001) − TREE(3)) + 998×(")
	for i in run.target():
		run.grow()
	var graph_record := "SSCG(TREE(1001) + %d)" % run.step
	run.advance()
	passed = passed and run.previous_record == graph_record
	passed = passed and run.balance_detail().contains("(%s − SSCG(TREE(1001)))" % graph_record)
	run.reset()
	passed = passed and run.stage == 0 and run.step == 0 and not run.won
	passed = passed and run.previous_record.is_empty() and run.previous_title.is_empty()
	passed = passed and run.balance_text() == "1" and not run.balance_detail().contains("TREE(")
	passed = check_carried_balance() and passed
	passed = check_integer_prices() and passed
	passed = check_readable_balances() and passed
	passed = check_last_increments() and passed
	passed = check_large_carry() and passed
	if passed:
		print("Vanish: %d series, %d taps, handoffs, credit, shortcut and carried balance OK" % [Growth.count(), total])
	else:
		push_error("Progression regression after %d normal taps" % total)
	quit(0 if passed else 1)


func check_carried_balance() -> bool:
	var run := Run.new()
	var passed := check_amount(run.balance_text(), 1.0, "opening polygon balance")
	passed = check_amount(run.cost_text(), 1.55, "marked polygon price") and passed
	for i in 2:
		run.grow()
	run.advance()
	passed = passed and run.stage == 0 and not run.ready()
	run.grow()
	passed = passed and run.ready()
	run.advance()
	passed = check_amount(run.balance_text(), 0.0107, "polygon carry after paying") and passed
	passed = passed and run.display_value(0) == "0" and run.target() == 20
	run.grow()
	passed = check_amount(run.balance_text(), 1.0107, "carry plus the first harmonic gain") and passed
	for i in 19:
		run.grow()
	passed = check_amount(run.cost_text(), 3.5977, "full harmonic gain, excluding the carry") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 0.0107, "balance after paying on time twice") and passed

	run.reset()
	for i in 5:
		run.grow()
	passed = check_amount(run.cost_text(), 1.55, "extra polygon growth does not raise the price") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 0.0202, "extra polygon growth remains in the carry") and passed
	passed = passed and run.target() == 19
	for i in 21:
		run.grow()
	passed = check_amount(run.cost_text(), 3.5477, "next price uses the discounted gate") and passed
	run.advance()
	passed = check_amount(run.balance_text(), 0.1178, "extra harmonic growth survives the next full-price payment") and passed
	return passed and run.target() == 29


func check_amount(displayed: String, expected: float, scenario: String) -> bool:
	var amount := displayed.strip_edges().trim_prefix("≈").replace(",", "")
	var tolerance := 0.00005
	if amount.contains("×10^"):
		var scientific := amount.split("×10^")
		var exponent := int(scientific[1].replace("−", "-"))
		var mantissa := scientific[0]
		var decimals := mantissa.get_slice(".", 1).length()
		tolerance = 0.50001 * pow(10.0, exponent - decimals)
		amount = "%se%d" % [mantissa, exponent]
	if not amount.is_valid_float() or absf(float(amount) - expected) > tolerance:
		push_error("%s: expected %.4f, got %s" % [scenario, expected, displayed])
		return false
	return true


# In the integer chapter, even the cheapest discounted gate should exceed the
# preceding full-price gate. Compare the exact terms before display formatting.
func check_integer_prices() -> bool:
	var previous_full := 0
	for stage in Growth.count():
		if Growth.key(stage) == "golomb":
			previous_full = 1
		if previous_full == 0:
			continue
		var seed := Growth.value(stage, 0).to_int()
		var minimum := Growth.value(stage, Growth.safe_target(stage, 3)).to_int() - seed
		if minimum <= previous_full:
			push_error("%s gate %d follows %d" % [Growth.key(stage), minimum, previous_full])
			return false
		previous_full = Growth.value(stage, Growth.budget(stage)).to_int() - seed
		if Growth.key(stage) == "fib":
			return true
	return false


func check_readable_balances() -> bool:
	var run := Run.new()
	var passed := true
	for stage in Growth.count():
		var key := Growth.key(stage)
		var quota := run.target()
		for point in [0, quota, 1000000]:
			run.step = point
			var balance := run.balance_text()
			var compact := run.compact_balance()
			var compact_fee := run.compact_cost()
			for amount: String in [balance, compact, run.cost_text(), compact_fee]:
				if amount.is_empty() or amount == "≥0" or amount.contains("Δ") or amount.contains("Q") or amount.begins_with("B1"):
					push_error("%s at %d: unreadable amount %s" % [key, point, amount])
					passed = false
			passed = passed and compact.length() <= 25 and compact_fee.length() <= 25
		if key == "harmonic":
			passed = check_amount(run.balance_text(), 14.4034, "million-step harmonic balance") and passed
		if key == "sandpile":
			passed = passed and run.balance_text() == "≈4.16668×10^16"
		if key == "tower_in_tower":
			passed = passed and run.compact_balance().contains("↑↑")
		if key == "busy_beaver":
			passed = passed and run.compact_cost().contains("×")
		if key not in ["log_add", "plane_partitions", "tower_in_tower"]:
			run.step = quota
		run.advance()
		if key == "log_add":
			passed = check_amount(run.balance_text(), 18951172.0107, "million-step carry into triangular") and passed
		if key == "tower_in_tower":
			passed = passed and run.balance_text().contains("↑↑") and run.balance_detail().contains("2 ↑↑ (2 ↑↑ 1000001)")
	return passed

func check_last_increments() -> bool:
	var run := Run.new()
	var passed := true
	for stage in Growth.count():
		var gate := run.target()
		for point in [1, gate, 1000000]:
			run.step = point - 1
			run.grow()
			var delta := run.last_increment_text()
			if delta.is_empty() or delta == "—" or delta.begins_with("+") or delta.contains("Δ") or delta.contains("Q"):
				push_error("%s at %d: unreadable increment %s" % [Growth.key(stage), point, delta])
				passed = false
		match Growth.key(stage):
			"pi":
				run.step = 58
				passed = passed and run.last_increment_text() == "≈2.3327×10^−35"
			"harmonic":
				run.step = 3
				passed = passed and run.last_increment_text() == "≈0.3333"
			"golomb":
				run.step = 2
				passed = passed and run.last_increment_text() == "0"
				run.step = 1000000
				passed = passed and run.last_increment_text() == "0"
				run.step = 1000147
				passed = passed and run.last_increment_text() == "1"
			"wave":
				run.step = 1
				passed = passed and run.last_increment_text() == "4"
				run.step = 2
				passed = passed and run.last_increment_text() == "5"
			"triangular":
				run.step = 2
				passed = passed and run.last_increment_text() == "1"
				run.step = 3
				passed = passed and run.last_increment_text() == "4"
			"lattice_circle":
				run.step = 1
				passed = passed and run.last_increment_text() == "8"
				run.step = 1000000
				passed = passed and run.last_increment_text() == "≥4"
				passed = passed and run.balance_text().begins_with("≈3.1416")
			"fib":
				run.step = 10
				passed = passed and run.last_increment_text() == "55"
			"conway":
				run.step = 1
				passed = passed and run.last_increment_text() == "≥(3→3→2→3)"
				passed = passed and run.balance_detail().contains("G(78)")
			"busy_beaver":
				run.step = 108
				passed = passed and run.last_increment_text() == "≥7×TREE(3)"
				passed = passed and run._numeric_increment(stage, 108, "") == 47176763.0
			"rayo":
				run.step = 1000000
				passed = passed and run.last_increment_text().begins_with("≥")
				passed = passed and run.last_increment_text() == "≥73×BBB(74)"
				passed = passed and run.balance_text() == "≥Rayo(1000000)"
		run.step = gate
		run.advance()
	return passed


func check_public_amounts(run: Run, scenario: String) -> bool:
	var valid := true
	for amount in [run.balance_text(), run.compact_balance(), run.cost_text(), run.compact_cost(), run.last_increment_text()]:
		var token := String(amount).replace("×10^−", "×10^")
		if token.is_empty() or token.contains("+") or token.contains("−") or token.contains("-") or token.contains("Δ") or token.contains("Q") or token.contains("(P") or token.begins_with("B1"):
			push_error("%s: calculation leaked into HUD (%s)" % [scenario, amount])
			valid = false
	return valid


func check_large_carry() -> bool:
	var run := Run.new()
	var passed := true
	while Growth.key(run.stage) != "graphs":
		run.step = run.target()
		run.advance()
	run.step = run.target() + 1
	var expected := run.balance_text()
	run.advance()
	for n in [0, 1, 10, 11]:
		run.step = n
		if not run.balance_text().contains("×10^975"):
			push_error("graphs surplus was lost next to %d square clicks: %s (graph balance %s)" % [n, run.balance_text(), expected])
			passed = false
	passed = passed and run.balance_detail().contains("(2^3240 − 2^3160)")
	run.reset()
	while Growth.key(run.stage) != "tree":
		run.step = run.target()
		run.advance()
	run.step = run.target() + 1000
	run.advance()
	var carried := run.balance_text()
	run.grow()
	passed = passed and carried.begins_with("≥") and run.balance_text() == carried
	passed = passed and run.balance_detail().contains("TREE(1003) − TREE(3)")
	return passed
