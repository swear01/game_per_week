extends SceneTree

const Main = preload("res://main.tscn")
var errors := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = Vector2i(960, 700)
	var game = Main.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.price.text == "1.55" and game.score.text == "1", "opening price and balance")
	_key(KEY_ESCAPE)
	_check(game.details.visible and game.detail_label.text.contains("F1"), "Esc opens the controls")
	_key(KEY_SPACE)
	_check(game.run.step == 0, "input stays in the menu")
	_key(KEY_F1)
	_check(game.details.visible and not game.showing_controls, "F1 from the menu opens details")
	_key(KEY_ESCAPE)
	_key(KEY_SPACE)
	_check(not game.details.visible and game.gain.visible and game.gain.text.contains("+"), "grow shows the increment")
	game.run.step = 57
	_key(KEY_SPACE)
	_check(game.score.text.replace("\n", "").begins_with("1.57079632679489") and game.gain.text.contains("35"), "polygon stays decimal and gain remains visible at step 58")
	_check(not game.gain.text.contains("≈") and not game.price.text.contains("≈"), "ordinary rounding stays off the HUD")
	_key(KEY_ENTER)
	_check(game.run.stage == 1 and not game.gain.visible and game.stage_count.text.begins_with("2 /"), "leap clears the previous gain")
	game.run.stage = 4
	game.run.step = 0
	game._refresh()
	_key(KEY_SPACE)
	_key(KEY_SPACE)
	_check(game.gain.text == "+5", "rapid taps replace the previous gain with the actual sine increment")
	await create_timer(0.8).timeout
	_check(not game.gain.visible, "gain clears without input")
	_check(game.grow.tooltip_text.is_empty() and game.advance.tooltip_text.is_empty(), "no shortcut tooltips during play")
	game.run.reset()
	game.run.stage = 21 # Single power tower, step 78 is 2↑↑79.
	game.run.step = 78
	game._refresh()
	_check(game.score.text == "2↑↑79" and game.price.text == "2↑↑79", "tower magnitude appears without a formula or approximation prefix")
	print("HUD checks: %d failures" % errors)
	quit(int(errors != 0))

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event)

func _check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL ", label)
