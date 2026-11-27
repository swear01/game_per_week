extends SceneTree
# Native rendering is required: godot --path vanish/game --script res://tests/score_overlap.gd

const Growth = preload("res://growth.gd")

var game: Control
var grow: Button
var advance: Button
var score: Label
var art: Control
var run: Variant
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The score overlap check needs a native rendering driver.")
		quit(2)
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	grow = game.get_node("Grow")
	advance = game.get_node("Advance")
	score = game.get_node("Grow/Score")
	art = game.get_node("Tower")
	run = game.get("run")
	var scale := DisplayServer.screen_get_scale(root.current_screen)
	for window_points: Vector2 in [Vector2(320, 240), Vector2(640, 460), Vector2(960, 700)]:
		root.size = Vector2i((window_points * scale).round())
		await create_timer(0.12).timeout
		run.reset()
		game.call("_refresh")
		for i in range(run.target()):
			_click(_center(grow))
		_check(run.ready(), "the opening leap unlocks after its target number of actual clicks")
		_click(_center(advance))
		for key in ["harmonic", "inverse_sqrt"]:
			_check(Growth.key(run.stage) == key and run.step == 0, "leap must start " + key + " at zero")
			# These two exact sums are tall enough to cross the central glyphs.
			var threshold := 10000000000 if key == "harmonic" else 110
			run.step = threshold
			game.call("_refresh")
			var hit := await _check_overlap("%s at %d points wide" % [key, window_points.x], true)
			_click(hit)
			_check(run.step == threshold + 1, key + " accepts exactly one click at the overlap")
			_click(_center(advance))
		_check(Growth.key(run.stage) == "golomb" and run.step == 0, "ordinary leap leaves the stack series")
		await _check_overlap("Golomb at %d points wide" % window_points.x, false)
		_click(_center(score))
		_check(run.step == 1, "Golomb score remains clickable after leaving a stack series")
	print("Score overlap: %d layout checks, %d failures" % [checks, failures])
	quit(int(failures > 0))

func _check_overlap(label: String, expected: bool) -> Vector2:
	checks += 1
	await create_timer(0.5).timeout
	var transform := root.get_final_transform()
	var rect := score.get_global_rect()
	var logical := root.get_visible_rect()
	_check(logical.grow(0.5).encloses(rect), label + ": score bounds fit the visible layout")
	var area := Rect2i(Vector2i((transform * rect.position).round()), Vector2i((rect.size * transform.get_scale()).round()))
	var full := await _pixels(area)
	score.hide()
	var stack_only := await _pixels(area)
	art.hide()
	var background := await _pixels(area)
	score.show()
	var score_only := await _pixels(area)
	art.show()

	var ink := score.get_theme_color("font_color")
	var ink_rgb := Vector3i(roundi(ink.r * 255), roundi(ink.g * 255), roundi(ink.b * 255))
	var glyph_pixels := 0
	var stack_pixels := 0
	var overlapping := 0
	var readable := 0
	var hit := _center(score)
	for i in range(0, full.size(), 4):
		var is_stack := not _same_pixel(stack_only, background, i)
		stack_pixels += int(is_stack)
		if _ink_pixel(score_only, i, ink_rgb, 0) and not _same_pixel(score_only, background, i):
			glyph_pixels += 1
			if is_stack:
				overlapping += 1
				if _ink_pixel(full, i, ink_rgb, 3):
					readable += 1
					var pixel := i >> 2
					@warning_ignore("integer_division")
					hit = Vector2(area.position + Vector2i(pixel % area.size.x, pixel / area.size.x))
	_check(glyph_pixels > 30, label + ": rendered score has readable glyphs")
	if expected:
		_check(overlapping > 10, label + ": actual stack paint crosses behind score glyphs")
		_check(readable >= overlapping * 0.97, label + ": score glyphs are painted in front of the stack")
	else:
		_check(stack_pixels == 0, label + ": default layout restores a clear score area")
	print(label, " stack pixels=", stack_pixels, " glyphs over stack=", overlapping, " foreground=", readable)
	return hit

func _pixels(area: Rect2i) -> PackedByteArray:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_region(area).get_data()

func _same_pixel(left: PackedByteArray, right: PackedByteArray, i: int) -> bool:
	return left[i] == right[i] and left[i + 1] == right[i + 1] and left[i + 2] == right[i + 2]

func _ink_pixel(bytes: PackedByteArray, i: int, color: Vector3i, tolerance: int) -> bool:
	return absi(int(bytes[i]) - color.x) <= tolerance and absi(int(bytes[i + 1]) - color.y) <= tolerance and absi(int(bytes[i + 2]) - color.z) <= tolerance

func _center(control: Control) -> Vector2:
	return root.get_final_transform() * control.get_global_rect().get_center()

func _click(at: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = at
		event.global_position = at
		event.pressed = down
		root.push_input(event, false)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
