extends RefCounted

# Coefficients (π/2)^(2k+1)/(2k+1)!, truncated at 60 decimal places. In the
# normalized perimeter each term is divided by 4^(kn) with alternating signs.
const COEFFICIENTS := [
	"1570796326794896619231321691639751442098584699687552910487472",
	"0645964097506246253655756563897945733379693511789273076961344",
	"0079692626246167045120505549490478022520911642351061195456638",
	"0004681754135318688100685463933953437859495028018501057574953",
	"0000160441184787359821872660870163473329702807540620611568587",
	"0000003598843235212085340458540018208389404888495232432127661",
	"0000000056921729219679268117752553035921843729028297560545981",
]
const LOG10_4 := 0.6020599913279624
const ASCII_ZERO := 48


static func value(n: int) -> String:
	if n <= 0:
		return "1"
	if n <= 14:
		var scale := float(1 << n)
		return "≈" + String.num(scale * sin(PI / (2.0 * scale)), maxi(4, n - 2))
	@warning_ignore("integer_division")
	var digits := mini(52, mini(n, 100) * 60206 / 100000 + 5)
	var perimeter: String = COEFFICIENTS[0]
	# Above this point the gap to π/2 is smaller than one guard digit.
	if n <= 92:
		for k in range(1, COEFFICIENTS.size()):
			var term := _divide_by_four(COEFFICIENTS[k], k * n)
			if term.is_empty():
				break
			perimeter = _adjust(perimeter, term, -1 if k % 2 == 1 else 1)
	return "≈" + _rounded_decimal(perimeter, digits)


static func delta(n: int) -> String:
	if n <= 0:
		return "0"
	if n > 1000000000:
		# Keep the exponent exact even when it is too large for a double.
		return "≈1.9379 × 4^−%d" % n
	var log_delta: float
	if n < 25:
		# P(n)−P(n−1) = P(n)(1−cos θ) = 2 P(n) sin²(θ/2).
		var scale := float(1 << n)
		var angle := PI / (2.0 * scale)
		var sine := sin(angle / 2.0)
		log_delta = log(2.0 * scale * sin(angle) * sine * sine) / log(10.0)
	else:
		# The next term adds a relative correction of order 4^−n.
		log_delta = log(PI * PI * PI / 16.0) / log(10.0) - float(n) * LOG10_4
	var exponent := floori(log_delta)
	var mantissa := roundf(pow(10.0, log_delta - exponent) * 10000.0) / 10000.0
	if mantissa >= 10.0:
		mantissa = 1.0
		exponent += 1
	if exponent >= -4:
		return "≈" + String.num(mantissa * pow(10.0, exponent), 4 - exponent)
	return "≈%se−%d" % [String.num(mantissa, 4), -exponent]


static func _divide_by_four(amount: String, power: int) -> String:
	while power > 0:
		var chunk := mini(power, 12)
		var divisor := 1 << (2 * chunk)
		var remainder := 0
		var divided := ""
		for i in amount.length():
			remainder = remainder * 10 + amount.unicode_at(i) - ASCII_ZERO
			@warning_ignore("integer_division")
			divided += str(remainder / divisor)
			remainder %= divisor
		if divided.lstrip("0").is_empty():
			return ""
		amount = divided
		power -= chunk
	return amount


static func _adjust(amount: String, term: String, sign: int) -> String:
	var result := ""
	var carry := 0
	for i in range(amount.length() - 1, -1, -1):
		var column := amount.unicode_at(i) - ASCII_ZERO + sign * (term.unicode_at(i) - ASCII_ZERO) + carry
		carry = -1 if column < 0 else int(column >= 10)
		result = str(column - 10 * carry) + result
	return result


static func _rounded_decimal(amount: String, digits: int) -> String:
	var prefix := amount.left(digits + 1)
	if amount.unicode_at(digits + 1) >= ASCII_ZERO + 5:
		prefix = _adjust(prefix, "0".repeat(digits) + "1", 1)
	return prefix.left(1) + "." + prefix.substr(1)
