extends SceneTree

const Growth = preload("res://growth.gd")
const Polygon = preload("res://polygon.gd")

func _initialize() -> void:
	# Reference decimals from the sine series evaluated independently at 90 places.
	var samples := [
		[0, "1", "0"],
		[1, "≈1.4142", "≈0.41421"],
		[3, "≈1.5607", "≈0.029989"],
		[14, "≈1.570796324388", "≈7.2192e−9"],
		[15, "≈1.57079632619330", "≈1.8048e−9"],
		[57, "≈1.570796326794896619231321691639751410997", "≈9.3306e−35"],
		[58, "≈1.570796326794896619231321691639751434323", "≈2.3327e−35"],
		[1000, "≈1.5707963267948966192313216916397514420985846996875529", "≈1.6879e−602"],
		[9223372036854775807, "≈1.5707963267948966192313216916397514420985846996875529", "≈1.9379 × 4^−9223372036854775807"],
	]
	var failures := 0
	for sample: Array in samples:
		var index: int = sample[0]
		var amount := Polygon.value(index)
		var increment := Polygon.delta(index)
		if amount != sample[1] or increment != sample[2] or Growth.value(0, index) != amount:
			printerr("FAIL polygon %d: got %s, %s; expected %s, %s" % [index, amount, increment, sample[1], sample[2]])
			failures += 1
	print("Polygon: %d reference cases, %d failures" % [samples.size(), failures])
	quit(int(failures > 0))
