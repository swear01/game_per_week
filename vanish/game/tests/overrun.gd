extends SceneTree
# Run with a rendering driver: godot --path vanish/game --script res://tests/overrun.gd
# Add -- followed by series keys (for example: -- partitions plane_partitions) to narrow the scan.

const Growth = preload("res://growth.gd")

class AnimatedTower:
	extends "res://tower.gd"

	func _reduced() -> bool:
		return false

var surface: SubViewport
var tower: Control
var failures := 0
var sampled := 0
var pulses := 0

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
	if sampled == 0:
		printerr("No matching series.")
	print("Overrun: %d taps sampled, %d transient-only, %d failures" % [sampled, pulses, failures])
	quit(0 if failures == 0 and sampled > 0 else 1)

func _check_tap(series: int, id: String, n: int, goal: int) -> void:
	sampled += 1
	tower.mark = 16
	tower.show_progress(series, n, goal)
	_settle_tap()
	var settled := await _frame()
	var area: Rect2 = tower.call("_area")
	area.position += tower.position
	var region := Rect2i(area)
	var initial := settled.get_region(region)

	tower.show_progress(series, n + 1, goal)
	# Advance the tap clock to cover the transient without a real-time delay for each case.
	tower.set("_started", Time.get_ticks_msec() - roundi(float(tower.call("_tap_ms")) * 0.30))
	var during := await _frame()
	var moving := during.get_region(region)
	_settle_tap()
	var finished := await _frame()
	var final := finished.get_region(region)
	var idle := await _frame()
	var badge := "%s %d→%d" % [id, n, n + 1]

	var drawn := settled.get_used_rect().merge(during.get_used_rect()).merge(finished.get_used_rect())
	if not Rect2i(tower.get_rect()).encloses(drawn):
		_fail(badge, "paint overflows Tower: %s" % drawn)
	if initial.get_used_rect().size.x < 2 or initial.get_used_rect().size.y < 2 or final.get_used_rect().size.x < 2 or final.get_used_rect().size.y < 2:
		_fail(badge, "settled motif is empty")
	var before_pixels := initial.get_data()
	var after_pixels := final.get_data()
	if before_pixels == after_pixels:
		if before_pixels == moving.get_data():
			_fail(badge, "neither the tap nor its terminal frame changes the motif")
		else:
			pulses += 1
			_fail(badge, "the tap changes the transient frame but not the settled motif")
	if after_pixels != idle.get_region(region).get_data():
		_fail(badge, "the motif changes after settling with no input")

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
