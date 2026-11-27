extends SceneTree

const Run = preload("res://run.gd")
const Growth = preload("res://growth.gd")

func _initialize() -> void:
	var run := Run.new()
	var total := 0
	var passed := true
	for stage in Growth.count():
		var opening := run.display_value(0)
		run.advance()
		passed = passed and run.stage == stage and not run.ready() and not opening.is_empty()
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
	var skipped := run.stage + 2
	run.advance()
	passed = passed and run.stage == skipped and run.target() == Growth.budget(skipped)
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
	if passed:
		print("Vanish: %d series, %d taps, handoffs, credit and shortcut OK" % [Growth.count(), total])
	else:
		push_error("Progression regression")
	quit(0 if passed else 1)
