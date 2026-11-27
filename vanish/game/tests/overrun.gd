extends SceneTree
# Run with a rendering driver: godot --path vanish/game --script res://tests/overrun.gd
# Add -- followed by series keys (for example: -- partitions plane_partitions) to narrow the scan.

const Growth = preload("res://growth.gd")
const Run = preload("res://run.gd")

class AnimatedTower:
	extends "res://tower.gd"

	func _reduced() -> bool:
		return false

var surface: SubViewport
var tower: AnimatedTower
var failures := 0
var sampled := 0
var leaps := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The overrun check needs an actual rendering driver.")
		quit(2)
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	surface = SubViewport.new()
	surface.size = Vector2i(760, 420)
	surface.transparent_bg = true
	surface.disable_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	tower = AnimatedTower.new()
	tower.position = Vector2(122, 100)
	tower.size = Vector2(516, 176)
	surface.add_child(tower)
	# Expose actual coordinates instead of letting the product's scissor hide overflows.
	tower.clip_contents = false
	var filters := OS.get_cmdline_user_args()
	for series in Growth.count():
		var id := Growth.key(series)
		if not filters.is_empty() and not filters.has(id):
			continue
		var goal := Growth.budget(series)
		var samples := [maxi(0, goal - 1), goal + 1, 1000, 20000, 1000000]
		if id == "plane_partitions":
			# First few cubes of a new diagonal after Tetrahedral(200).
			samples.append(1353401)
		for n in samples:
			await _check_tap(series, id, n, goal)
		if id == "harmonic" or id == "inverse_sqrt":
			await _check_stack_baseline(series, id, goal)
		if id == "golomb":
			await _check_golomb_tape(series, goal)
		if series + 1 < Growth.count():
			await _check_leap(series, id)
	if sampled == 0:
		printerr("No matching series.")
	print("Overrun: %d taps, %d leaps, %d failures" % [sampled, leaps, failures])
	quit(0 if failures == 0 and sampled > 0 else 1)

func _check_tap(series: int, id: String, n: int, goal: int) -> void:
	sampled += 1
	var run := Run.new()
	run.stage = series
	run.step = n
	tower.mark = 16
	tower.show_progress(run.stage, run.step, goal)
	_settle_tap()
	var settled := await _frame()
	var area: Rect2 = tower.call("_area")
	area.position += tower.position
	var region := Rect2i(area)
	var initial := settled.get_region(region)

	run.grow()
	tower.show_progress(run.stage, run.step, goal)
	# Advance the tap clock to cover the transient without a real-time delay for each case.
	tower.set("_started", Time.get_ticks_msec() - roundi(float(tower.call("_tap_ms")) * 0.30))
	var during := await _frame()
	_settle_tap()
	var finished := await _frame()
	var final := finished.get_region(region)
	var idle := await _frame()
	var badge := "%s %d→%d" % [id, n, n + 1]
	if run.stage != series or run.step != n + 1 or tower.step != n + 1:
		_fail(badge, "one growth input must advance the model and renderer exactly once")

	var drawn := settled.get_used_rect().merge(during.get_used_rect()).merge(finished.get_used_rect())
	if not Rect2i(tower.get_rect()).encloses(drawn):
		_fail(badge, "paint overflows Tower: %s" % drawn)
	if initial.get_used_rect().size.x < 2 or initial.get_used_rect().size.y < 2 or final.get_used_rect().size.x < 2 or final.get_used_rect().size.y < 2:
		_fail(badge, "settled motif is empty")
	# A true mathematical plateau or subpixel increment can share a settled frame.
	if final.get_data() != idle.get_region(region).get_data():
		_fail(badge, "the motif changes after settling with no input")

func _check_stack_baseline(series: int, id: String, goal: int) -> void:
	tower.show_progress(series, 20, goal)
	_settle_tap()
	var first := await _frame()
	var width: int = tower.call("_stack_width")
	var left := int(tower.position.x) + tower.center - (width >> 2)
	var bottom := int(tower.position.y) + tower.base_y - 2
	var stack := first.get_region(Rect2i(left, int(tower.position.y), width >> 1, tower.base_y - 2))
	var height := floori(float(stack.get_used_rect().size.y) * 0.7)
	if height < 16:
		_fail(id, "lower-stack sample must contain several existing layers")
		return
	var lower_layers := Rect2i(left, bottom - height, width >> 1, height)
	var baseline := first.get_region(lower_layers).get_data()
	var samples := [21, 1000, 1000000] if goal == 20 else [21, goal + 1, 1000, 1000000]
	for n in samples:
		tower.show_progress(series, n - 1, goal)
		_settle_tap()
		tower.show_progress(series, n, goal)
		tower.set("_started", Time.get_ticks_msec() - roundi(float(tower.call("_tap_ms")) * 0.30))
		var moving := await _frame()
		_settle_tap()
		var settled := await _frame()
		if moving.get_region(lower_layers).get_data() != baseline or settled.get_region(lower_layers).get_data() != baseline:
			_fail("%s %d" % [id, n], "previous lower layers move or rescale as the new layer arrives")

func _check_golomb_tape(series: int, goal: int) -> void:
	var area: Rect2 = tower.call("_area")
	var cell_width := clampf(floorf(area.size.x / 13.0), 20.0, 34.0)
	var slots := maxi(1, floori(area.size.x / cell_width))
	tower.show_progress(series, 1, goal)
	_settle_tap()
	var second := await _frame()
	var at_two := _tape_height(second, area, cell_width, slots, 1, 2)
	tower.show_progress(series, 2, goal)
	var moving_third := await _frame()
	_settle_tap()
	var third := await _frame()
	if Growth.value(series, 1) != "2" or Growth.value(series, 2) != "2" or at_two < 10:
		_fail("golomb cells 2 and 3", "adjacent equal values must appear on the fixed tape")
	for index in [2, 3]:
		if _tape_height(moving_third, area, cell_width, slots, 2, index) != at_two or _tape_height(third, area, cell_width, slots, 2, index) != at_two:
			_fail("golomb index %d" % index, "equal adjacent cells stay full-height in the same fixed window as the head advances")

	var before := slots + 6
	var shared_index := before
	tower.show_progress(series, before, goal)
	_settle_tap()
	var before_scroll := await _frame()
	var old_height := _tape_height(before_scroll, area, cell_width, slots, before, shared_index)
	tower.show_progress(series, before + 1, goal)
	var after_scroll := await _frame()
	var new_height := _tape_height(after_scroll, area, cell_width, slots, before + 1, shared_index)
	if old_height < 10 or new_height != old_height:
		_fail("golomb index %d" % shared_index, "the same cell must retain its height when the tape scrolls")
	print("Golomb tape: cells 2 and 3 %d px; scrolling cell %d %d→%d px" % [at_two, shared_index, old_height, new_height])

func _tape_height(image: Image, area: Rect2, cell_width: float, slots: int, step: int, index: int) -> int:
	var hi := step + 1 + mini(3, slots - 1)
	var lo := maxi(1, hi - slots + 1)
	var x := int(tower.position.x + area.get_center().x + (index - lo + 0.25 - slots / 2.0) * cell_width)
	var top := roundi(tower.position.y + area.get_center().y - minf(32.0, area.size.y * 0.52) / 2.0) - 2
	var bottom := roundi(tower.position.y + area.get_center().y + minf(32.0, area.size.y * 0.52) / 2.0) + 2
	var height := 0
	for y in range(top, bottom):
		height += int(image.get_pixel(x, y).a > 0.5)
	return height

func _check_leap(series: int, id: String) -> void:
	leaps += 1
	var run := Run.new()
	run.stage = series
	run.step = run.target()
	tower.mark = 16 if series > 0 else 0
	tower.show_progress(run.stage, run.step, run.target())
	_settle_tap()
	await _frame()
	var mark := AnimatedTower.signature(run.stage, run.step)
	run.advance()
	tower.mark = mark
	tower.show_progress(run.stage, run.step, run.target())
	if run.stage != series + 1 or run.step != 0 or tower.series != run.stage or tower.step != 0:
		_fail(id, "leap must start the next series at step zero")
	var first_brick := series == 0
	if tower.is_processing() != first_brick:
		_fail(id, "only π → harmonic should animate the leap")
	var early := await _frame()
	_settle_tap()
	var settled := await _frame()
	var frames_differ := early.get_data() != settled.get_data()
	if frames_differ != first_brick:
		_fail(id, "the first brick should animate; other leaps should show their destination immediately")

func _settle_tap() -> void:
	tower.set("_started", Time.get_ticks_msec() - 1000)
	tower._process(0.0)

func _frame() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	return surface.get_texture().get_image()

func _fail(badge: String, reason: String) -> void:
	failures += 1
	printerr("FAIL ", badge, ": ", reason)
