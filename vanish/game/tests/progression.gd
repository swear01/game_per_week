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
			passed = passed and run.cost_text() == "108×Q35 + 47,176,870"
			passed = passed and run.balance_detail().contains("Q35 = 7×Q34 + ")

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
	run.advance()
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
	passed = passed and run.balance_detail().contains("998×Q33 + (TREE(1001) − TREE(3))")
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
	if not amount.is_valid_float() or absf(float(amount) - expected) > 0.00005:
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
