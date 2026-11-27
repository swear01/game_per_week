extends RefCounted

const STAGES := [
	["pi", "多邊形逼近 π", 5, "把圓弧平分，邊數翻倍。分數是路徑長 ÷ 兩倍直徑。"],
	["harmonic", "調和加法", 40, ""],
	["inverse_sqrt", "根號分之一", 60, ""],
	["golomb", "Golomb 紙帶", 83, "向前讀一格。紙帶第 n 格也告訴你 n 總共出現幾次。"],
	["wave", "正弦加法", 95, ""],
	["log_add", "對數當加量", 110, "加下一個步數的二進位位數。"],
	["triangular", "三角數爆發", 125, "每下加 1。踩到三角數時，再加當前步數。"],
	["rule90", "Rule 90 累積亮點", 150, "加一排像素。左右鄰格恰有一格亮時，這一格才亮。"],
	["primes", "質數步獎勵", 150, "先加 1。下一個步數若是質數，再加這個步數。"],
	["lattice_circle", "圓內亮格", 150, ""],
	["sandpile", "一維雪崩", 150, "在原點加一粒。滿兩粒就向左右各丟一粒。每次倒塌再加 1 分。"],
	["square_partitions", "正方形積木包", 150, ""],
	["partitions", "積木分堆", 155, ""],
	["plane_partitions", "平面分割", 155, ""],
	["fib", "斐波那契", 140, "把最後兩項相加。"],
	["double", "固定翻倍", 140, "複製目前的全部。"],
	["pi_digits", "接上 π 的下一位", 155, ""],
	["factorial", "排列所有物件", 155, ""],
	["graphs", "邊能連或不連", 155, ""],
	["square", "連續平方", 155, "把整個舊值平方。"],
	["growing_power", "次方逐下加一", 155, ""],
	["tower", "舊值變指數", 155, ""],
	["tower_double", "塔高翻倍", 155, "仍然蓋 2 指數塔，這一下把高度翻倍。"],
	["tower_in_tower", "用塔決定塔高", 155, "內塔加高一層。把內塔的值當成外塔的高度。"],
	["triple", "三支箭頭", 155, "把整個舊值當成新指數塔的高度。"],
	["quadruple", "四支箭頭", 155, ""],
	["quintuple", "五支箭頭", 155, ""],
	["sextuple", "六支箭頭", 155, ""],
	["variable_arrows", "箭頭數可變", 155, ""],
	["graham", "葛立恆式回灌", 155, ""],
	["conway", "Conway 四項鏈", 155, "第三格加一。最後一格固定為 3，遞迴決定要回灌幾次。"],
	["bowers", "Bowers 巢狀陣列", 150, ""],
	["fast_goodstein", "Fast Goodstein", 150, ""],
	["tree", "TREE 樹序列", 2, ""],
	["sscg", "SSCG 圖序列", 13, ""],
	["busy_beaver", "忙碌海狸", 108, ""],
	["beeping_beaver", "最後一聲的海狸", 145, ""],
	["oracle_beaver", "二階預言機海狸", 145, ""],
	["rayo", "Rayo 的定義預算", 150, ""],
]
const WAVE := [4, 5, 4, 3, 2, 1, 2, 3]
const PI_DIGITS := (
	"31415926535897932384626433832795028841971693993751058209749445923078164062862089"
	+ "986280348253421170679821480865132823066470938446095505822317253594081284811174"
	+ "502841027019385211055596446229489549303819644288109756659334461284756482337"
	+ "8678316527120190914564856692346034861045432664821339360726024914127"
)
const EXACT_ARITHMETIC_STEPS := 512


static func count() -> int:
	return STAGES.size()


static func key(stage: int) -> String:
	return String(STAGES[stage][0])


static func title(stage: int) -> String:
	return String(STAGES[stage][1])


static func budget(stage: int) -> int:
	return int(STAGES[stage][2])


static func safe_target(stage: int, reduction: int) -> int:
	var original := budget(stage)
	var earliest := maxi(1, original - maxi(reduction, 0))
	var stage_key := key(stage)
	if stage_key in ["busy_beaver", "tree", "sscg"]:
		return original
	if stage_key in ["golomb", "square_partitions"]:
		for candidate in range(earliest, original):
			if value(stage, candidate) != value(stage, candidate - 1):
				return candidate
		return original
	return earliest


static func value(stage: int, step: int) -> String:
	var n := maxi(step, 0)
	match key(stage):
		"pi":
			if n == 0:
				return "1"
			if n > 14:
				return "2^%d × sin(π / 2^%d)" % [n, n + 1]
			var sides := float(1 << (n + 1))
			return "≈" + String.num(sides * sin(PI / sides) / 2.0, maxi(4, n - 2))
		"harmonic", "inverse_sqrt":
			var root := key(stage) == "inverse_sqrt"
			if n == 0:
				return "0"
			if n > EXACT_ARITHMETIC_STEPS:
				return "Σ 1/%s（k = 1…%d）" % ["√k" if root else "k", n]
			var sum := 0.0
			for i in range(1, n + 1):
				sum += 1.0 / (sqrt(float(i)) if root else float(i))
			return "≈%.4f" % sum
		"golomb":
			if n > EXACT_ARITHMETIC_STEPS:
				return "Golomb(%d)" % (n + 1)
			return str(_golomb(n + 1))
		"wave":
			if n > 1000000:
				return "24 × ⌊%d/8⌋ + 前 %d 項加量" % [n, n % 8]
			@warning_ignore("integer_division")
			var total := (n / 8) * 24
			for i in range(n % 8):
				total += int(WAVE[i])
			return str(total)
		"log_add":
			if n > 1000000:
				return "Σ (1 + ⌊log₂ k⌋)（k = 1…%d）" % n
			var bits := _bit_length(n)
			return str((n + 1) * bits - (1 << bits) + 1)
		"triangular":
			if n > 1000000:
				return "%d + Σ Tₖ（Tₖ ≤ %d）" % [n, n]
			var bursts := int((sqrt(8.0 * float(n) + 1.0) - 1.0) / 2.0)
			@warning_ignore("integer_division")
			return str(n + bursts * (bursts + 1) * (bursts + 2) / 6)
		"rule90":
			if n > 1000000:
				return "Σ 2^popcount(k)（k = 0…%d）" % n
			return str(_rule90_total(n))
		"primes":
			if n > EXACT_ARITHMETIC_STEPS:
				return "%d + Σ p（p 為質數，p ≤ %d）" % [n, n]
			var total := n
			for i in range(2, n + 1):
				if _is_prime(i):
					total += i
			return str(total)
		"lattice_circle":
			if n > EXACT_ARITHMETIC_STEPS:
				return "格點數（r = %d）" % (n + 1)
			return str(_circle_points(n + 1))
		"sandpile":
			if n > 1000000:
				return "%d + Σ k²（k = 1…⌊%d/2⌋）" % [n, n]
			var radius := n >> 1
			@warning_ignore("integer_division")
			return str(n + radius * (radius + 1) * (radius * 2 + 1) / 6)
		"square_partitions":
			if n > 397:
				return "平方分割(%d)" % (n + 3)
			return str(_partitions(n + 3, true))
		"partitions":
			if n > 397:
				return "p(%d)" % (n + 3)
			return str(_partitions(n + 3, false))
		"plane_partitions":
			if n > 97:
				return "PP(%d)" % (n + 3)
			return str(_plane_partitions(n + 3))
		"fib":
			if n > 90:
				return "F(%d)" % (n + 2)
			var previous := 1
			var current := 1
			for i in range(n):
				var next := previous + current
				previous = current
				current = next
			return str(current)
		"double":
			return _power_of_two(n)
		"pi_digits":
			var digits := n + 1
			if digits <= 15:
				return PI_DIGITS.left(digits)
			if digits <= PI_DIGITS.length():
				return "%s…%s（%d 位）" % [PI_DIGITS.left(7), PI_DIGITS.substr(digits - 4, 4), digits]
			return "⌊π × 10^%d⌋" % n
		"factorial":
			if n > 18:
				return "%d!" % (n + 2)
			return str(_factorial(n + 2))
		"graphs":
			var vertices := n + 2
			if n > 1000000:
				return "2^(C(%d, 2))" % vertices
			@warning_ignore("integer_division")
			return _power_of_two(vertices * (vertices - 1) / 2)
		"square":
			if n < 6:
				return _power_of_two(1 << n)
			return "2^(2^%d)" % n
		"growing_power":
			if n < 4:
				return _power_of_two(_factorial(n + 1))
			return "2^((%d)!)" % (n + 1)
		"tower":
			return _tower(n + 1)
		"tower_double":
			if n <= 2:
				return _tower(1 << n)
			return "2 ↑↑ (2^%d)" % n
		"tower_in_tower":
			if n <= 3:
				return _tower(int(_tower(n + 1)))
			return "2 ↑↑ (2 ↑↑ %d)" % (n + 1)
		"triple":
			if n < 3:
				return ["2", "4", "65536"][n]
			return "2 ↑↑↑ %d" % (n + 1)
		"quadruple", "quintuple", "sextuple":
			if n == 0:
				return "4"
			var arrows := _arrow_rank(stage)
			return "2 %s %d" % ["↑".repeat(arrows), n + 2]
		"variable_arrows":
			if n == 0:
				return "27"
			if n == 1:
				return "7625597484987"
			return "3 ↑^%d 3" % (n + 1)
		"graham":
			if n == 0:
				return "4"
			if n == 1:
				return "3 ↑↑↑↑ 3"
			return "G(%d)" % n
		"conway":
			return "27" if n == 0 else "3 → 3 → %d → 3" % (n + 1)
		"bowers":
			return "27" if n == 0 else "H(H(%d))" % (n + 2)
		"fast_goodstein":
			if n < 3:
				return ["1", "2", "4"][n]
			return "FastG(%d)" % (n + 1)
		"tree":
			if n < 2:
				return ["1", "3"][n]
			return "TREE(%d)" % (n + 1)
		"sscg":
			if n < 2:
				return ["2", "5"][n]
			return "SSCG(%d)" % n
		"busy_beaver":
			if n <= 107:
				return str(n)
			if n == 108:
				return "47,176,870"
			return "BB(%d)" % (n - 103)
		"beeping_beaver":
			if n < 4:
				return ["1", "6", "55", "32,779,478"][n]
			if n == 4:
				return "BBB(5) > 10^14006"
			return "BBB(%d)" % (n + 1)
		"oracle_beaver":
			return "BB₂(%d)" % (n + 1)
		"rayo":
			return "0" if n == 0 else "Rayo(%d)" % n
	return ""


static func rule(stage: int, step: int) -> String:
	var n := maxi(step, 0)
	match key(stage):
		"harmonic":
			return "下一下加 1/%d。" % (n + 1)
		"inverse_sqrt":
			return "下一下加 1/√%d。" % (n + 1)
		"wave":
			return "下一下加 %d。八下走完一輪。" % WAVE[n % 8]
		"lattice_circle":
			return "半徑 %d → %d，重數圓內和圓周上的格點。" % [n + 1, n + 2]
		"square_partitions":
			return "%d → %d 塊，只准用 1、4、9、16…塊一包。" % [n + 3, n + 4]
		"partitions":
			return "%d → %d 塊，可用任何整數包，順序不計。" % [n + 3, n + 4]
		"plane_partitions":
			return "%d → %d 塊，排列成兩個方向都不升高的地形。" % [n + 3, n + 4]
		"pi_digits":
			if n + 1 < PI_DIGITS.length():
				return "舊值乘 10，接上下一位 %s。" % PI_DIGITS.substr(n + 1, 1)
			return "舊值乘 10，接上 π 的下一位。"
		"fib":
			if n > 90 and n <= 1000000:
				# In Binet's formula the omitted term at F(93) has relative magnitude < 10^-38.
				var phi := (1.0 + sqrt(5.0)) / 2.0
				var magnitude := ((n + 2) * log(phi) - 0.5 * log(5.0)) / log(10.0)
				return "末兩項相加。目前約 " + _scientific(magnitude)
		"double":
			if n >= 63 and n <= 1000000:
				return "把目前的全部翻倍。目前約 " + _scientific(n * log(2.0) / log(10.0))
		"factorial":
			return "下一個物件可插進每個舊排列的 %d 個位置。" % (n + 3)
		"graphs":
			return "加入一個點。它和已有的 %d 個點都能各自連邊或留空。" % (n + 2)
		"growing_power":
			return "舊值取 %d 次方。下一個次方本身也加一。" % (n + 2)
		"tower":
			return "舊值變成 2 的指數。塔高 %d → %d。" % [n + 1, n + 2]
		"quadruple", "quintuple", "sextuple":
			return "右參數 %d → %d。把 %d 箭頭當成可反覆套用的操作。" % [
				n + 2, n + 3, _arrow_rank(stage) - 1,
			]
		"variable_arrows":
			return "兩端固定是 3，箭頭數 %d → %d。" % [n + 1, n + 2]
		"graham":
			if n == 63:
				return "下一項是 G(64)，也就是葛立恆數。"
			return "把整個舊結果當作下一項的箭頭數。"
		"bowers":
			if n == 0:
				return "H(m) 是 m 個 3 的 Bowers 陣列。下一下從 H(2) 換成 H(H(3))。"
			return "把內層陣列 H(%d) 變成 H(%d)。它的值決定外層要放幾個 3。" % [n + 2, n + 3]
		"fast_goodstein":
			return "種子 %d → %d，計算反覆換底再減一，幾步才會歸零。" % [n + 1, n + 2]
		"tree":
			return "顏色 %d → %d。數前樹無法保色且保共同祖先地嵌入後樹的最長序列。" % [n + 1, n + 2]
		"sscg":
			return "頂點額度加一。數前圖無法拓撲嵌入後圖的最長序列，每個頂點最多三條邊。"
		"busy_beaver":
			if n < 107:
				return "讓四狀態的冠軍機器再走一格。它會在第 107 下停。"
			if n == 107:
				return "把額度增為 5 個狀態，揭曉五狀態的已證紀錄。"
			if n == 108:
				return "額度增加到六個狀態。已證 BB(6) 大於 2 ↑↑↑ 5。"
			return "多允許一個狀態。保留所有停機機器中的最長時間這個定義式。"
		"beeping_beaver":
			return "狀態 %d → %d。不必停機，只比最後一次發聲有多晚。" % [n + 1, n + 2]
		"oracle_beaver":
			return "狀態 %d → %d。機器可以查詢一階預言機海狸。" % [n + 1, n + 2]
		"rayo":
			return "用一階集合論的標準語意定義數。最多用 %d → %d 個符號，取大於每個可唯一指定之自然數的最小自然數。" % [n, n + 1]
	return String(STAGES[stage][3])


static func _golomb(index: int) -> int:
	var terms := PackedInt32Array([0, 1])
	terms.resize(index + 1)
	for i in range(2, index + 1):
		terms[i] = 1 + terms[i - terms[terms[i - 1]]]
	return terms[index]


static func _bit_length(number: int) -> int:
	var bits := 0
	while number > 0:
		bits += 1
		number >>= 1
	return bits


static func _rule90_total(last_row: int) -> int:
	# A full block of 2^k rows totals 3^k lights; the remaining rows have one extra binary 1.
	var upper := last_row + 1
	var total := 0
	var scale := 1
	while upper > 0:
		var bit := _bit_length(upper) - 1
		var block := 1
		for i in range(bit):
			block *= 3
		total += scale * block
		scale *= 2
		upper -= 1 << bit
	return total


static func _is_prime(number: int) -> bool:
	for divisor in range(2, int(sqrt(float(number))) + 1):
		if number % divisor == 0:
			return false
	return number >= 2


static func _circle_points(radius: int) -> int:
	var count_on_axis := 2 * radius + 1
	var total := count_on_axis
	for x in range(1, radius + 1):
		total += 2 * (2 * int(sqrt(float(radius * radius - x * x))) + 1)
	return total


static func _partitions(size: int, squares_only: bool) -> int:
	var ways := PackedInt64Array()
	ways.resize(size + 1)
	ways[0] = 1
	var largest := int(sqrt(float(size))) if squares_only else size
	for i in range(1, largest + 1):
		var part: int = i * i if squares_only else i
		for total in range(part, size + 1):
			ways[total] += ways[total - part]
	return ways[size]


static func _plane_partitions(size: int) -> int:
	# n PP(n) = Σ σ₂(k) PP(n-k). The caller caps n at 100 to fit the numerator.
	var sum_of_squared_divisors := PackedInt64Array()
	sum_of_squared_divisors.resize(size + 1)
	for divisor in range(1, size + 1):
		for multiple in range(divisor, size + 1, divisor):
			sum_of_squared_divisors[multiple] += divisor * divisor
	var ways := PackedInt64Array()
	ways.resize(size + 1)
	ways[0] = 1
	for n in range(1, size + 1):
		var numerator := 0
		for k in range(1, n + 1):
			numerator += sum_of_squared_divisors[k] * ways[n - k]
		@warning_ignore("integer_division")
		ways[n] = numerator / n
	return ways[size]


static func _factorial(number: int) -> int:
	var product := 1
	for i in range(2, number + 1):
		product *= i
	return product


static func _scientific(log10_value: float) -> String:
	var exponent := floori(log10_value)
	var mantissa := snappedf(pow(10.0, log10_value - exponent), 0.01)
	if mantissa >= 10.0:
		mantissa = 1.0
		exponent += 1
	return "%.2f × 10^%d" % [mantissa, exponent]


static func _power_of_two(exponent: int) -> String:
	if exponent < 63:
		return str(1 << exponent)
	return "2^%d" % exponent


static func _tower(height: int) -> String:
	if height <= 4:
		return ["1", "2", "4", "16", "65536"][height]
	return "2 ↑↑ %d" % height


static func _arrow_rank(stage: int) -> int:
	match key(stage):
		"quadruple":
			return 4
		"quintuple":
			return 5
	return 6
