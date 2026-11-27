extends SceneTree

const Tower = preload("res://tower.gd")

class TestTower extends Tower:
	var reduce_motion := false

	func _reduced() -> bool:
		return reduce_motion

func _initialize() -> void:
	var tower := TestTower.new()
	root.add_child(tower)
	tower.size = Vector2(640, 300)
	tower.show_progress(0, 3, 3)
	var ok := not tower.is_processing() # Restored state has no entrance animation.

	tower.mark = Tower.signature(0, 3)
	tower.show_progress(1, 0, 20)
	ok = ok and tower.mark == 16 and tower.is_processing() and tower.step == 0
	tower.show_progress(1, 1, 20)
	ok = ok and tower.step == 1 and tower.is_processing()
	await create_timer(0.25).timeout
	ok = ok and not tower.is_processing() and tower.step == 1

	tower.reduce_motion = true
	tower.show_progress(1, 2, 20)
	ok = ok and tower.step == 2 and not tower.is_processing()
	tower.show_progress(3, 0, 38)
	ok = ok and tower.series == 3 and not tower.is_processing()
	tower.show_progress(0, 0, 3)
	ok = ok and tower.step == 0 and not tower.is_processing()
	if ok:
		print("Vanish: leap, immediate input, idle and reduced motion OK")
	else:
		push_error("Motion regression")
	quit(0 if ok else 1)
