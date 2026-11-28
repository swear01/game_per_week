extends SceneTree
# godot --headless --path vanish/game --script res://tests/golomb.gd

const Growth = preload("res://growth.gd")

var failures := 0

func _initialize() -> void:
	var stage := 0
	for i in Growth.count():
		if Growth.key(i) == "golomb":
			stage = i
			break
	var reference := PackedInt32Array([0, 1])
	for i in range(2, 4097):
		reference.append(1 + reference[i - reference[reference[i - 1]]])
	for i in range(reference.size()):
		_check(Growth.golomb(i) == reference[i], "direct recurrence at index %d" % i)
	# Independent fixtures invert the weighted Golomb prefixes into individual runs.
	for fixture: Array in [
		[4096, 205, 0], [4100, 206, 1],
		[1000000, 6137, 0], [1000147, 6138, 1],
		[1000000000, 438744, 0], [1000000587, 438745, 1],
	]:
		var step: int = fixture[0]
		var value: int = fixture[1]
		var increment: int = fixture[2]
		_check(Growth.value(stage, step) == str(value), "exact displayed term at step %d" % step)
		_check(Growth.golomb(step + 1) - Growth.golomb(step) == increment, "true increment at step %d" % step)
	_check(Growth.golomb(0x7fffffffffffffff) == 632090561514, "last signed 64-bit index")
	print("Golomb: direct recurrence, high plateaus, run boundaries and int64, %d failures" % failures)
	quit(int(failures > 0))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
