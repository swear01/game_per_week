extends SceneTree
# Native rendering: godot --path vanish/game --script res://tests/partitions.gd

const Growth = preload("res://growth.gd")
const Early = preload("res://early_patterns.gd")

class Diagram extends Control:
	var step := 0
	var previous := 0
	var phase := 1.0

	func _draw() -> void:
		Early.draw(self, "partitions", step, previous, phase, Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4))

var failures := 0
var surface: SubViewport
var diagram: Diagram

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Partition frames require a native rendering driver.")
		quit(2)
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	var stage := 0
	for i in range(Growth.count()):
		if Growth.key(i) == "partitions":
			stage = i
			break
	_check(Growth.value(stage, 0) == "3" and Growth.value(stage, 1) == "5", "partition count grows from 3 to 5")
	_check(Early._partition_samples(3) == [[3], [2, 1], [1, 1, 1]], "all three partitions of 3")
	_check(Early._partition_samples(4) == [[3, 1], [2, 1, 1], [1, 1, 1, 1], [4], [2, 2]], "all five partitions of 4")
	for n in [5, 100, 1000000]:
		var examples := Early._partition_samples(n)
		_check(examples.size() == 3, "large values only draw three examples")
		for piles in examples:
			var total := 0
			for pile in piles:
				total += int(pile)
			_check(total == n, "each drawn example has the same number of bricks")

	surface = SubViewport.new()
	surface.transparent_bg = true
	surface.disable_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	diagram = Diagram.new()
	surface.add_child(diagram)
	for dimensions: Vector2i in [Vector2i(600, 150), Vector2i(350, 72)]:
		surface.size = dimensions
		diagram.size = Vector2(dimensions)
		var first := await _frame(0, 0, 1.0)
		var mid := await _frame(1, 0, 0.7)
		var last := await _frame(1, 0, 1.0)
		var idle := await _frame(1, 1, 1.0)
		var late := await _frame(999997, 999996, 1.0)
		var scope := " at " + str(dimensions)
		_check(_clusters(first) == 9, "three separate arrangements of three equal bricks" + scope)
		_check(_clusters(last) == 20, "five separate arrangements of four equal bricks" + scope)
		_check(mid.get_data() != last.get_data(), "the new bricks move before settling" + scope)
		_check(last.get_data() == idle.get_data(), "stopping leaves the settled frame fixed" + scope)
		for frame in [first, mid, last, idle, late]:
			var bounds: Rect2i = frame.get_used_rect()
			_check(bounds.has_area() and Rect2i(Vector2i.ONE, dimensions - Vector2i.ONE * 2).encloses(bounds),
				"the diagram is visible and inside the drawing area" + scope)
	print("Partition renderer: two viewport sizes, %d failures" % failures)
	quit(int(failures > 0))

func _frame(step: int, previous: int, phase: float) -> Image:
	diagram.step = step
	diagram.previous = previous
	diagram.phase = phase
	diagram.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return surface.get_texture().get_image()

# Each settled brick is a disconnected rectangle on a transparent background.
func _clusters(frame: Image) -> int:
	frame.convert(Image.FORMAT_RGBA8)
	var pixels := frame.get_data()
	var width := frame.get_width()
	var height := frame.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var total := 0
	for index in range(visited.size()):
		if visited[index] or pixels[index * 4 + 3] < 128:
			continue
		total += 1
		visited[index] = 1
		var pending: Array[int] = [index]
		while not pending.is_empty():
			var point: int = pending.pop_back()
			var x := point % width
			@warning_ignore("integer_division")
			var y := point / width
			for next: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
					continue
				var other := next.y * width + next.x
				if not visited[other] and pixels[other * 4 + 3] >= 128:
					visited[other] = 1
					pending.append(other)
	return total

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)
