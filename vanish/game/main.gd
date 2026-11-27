extends Control

const Run = preload("res://run.gd")
const Growth = preload("res://growth.gd")
const Tower = preload("res://tower.gd")
const WHITE := Color("#f0eee6")
const GOLD := Color("#e4cfa0")
const MUTED := Color("#a4a096")
const RULE := Color("#39372e")
const SAVE_INTERVAL_MS := 10000

var run := Run.new()
var replay_locked := false
var dirty := false
var last_save := 0
var text_font := SystemFont.new()
var numeric_font := SystemFont.new()
var keyboard_focus := false
var score_text := ""
var cost := ""
var progress_fraction := 0.0
var planned_score_height := 0.0

@onready var advance: Button = $Advance
@onready var action_label: Label = $Advance/Action
@onready var price: Label = $Advance/Price
@onready var track: ColorRect = $Advance/Track
@onready var progress: ColorRect = $Advance/Track/Progress
@onready var grow: Button = $Grow
@onready var score: Label = $Grow/Score
@onready var focus_mark: ColorRect = $Grow/Focus
@onready var stage_label: Label = $Stage
@onready var hint: Label = $Hint
@onready var tower: Tower = $Tower
@onready var ending: Label = $Ending
@onready var details: PanelContainer = $Details
@onready var detail_scroll: ScrollContainer = $Details/Scroll
@onready var detail_label: Label = $Details/Scroll/Text

func _ready() -> void:
	OS.low_processor_usage_mode = true
	get_window().min_size = Vector2i(320, 240)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_close_game)
	run.restore()
	last_save = Time.get_ticks_msec()
	_style_controls()
	grow.pressed.connect(_grow_once)
	grow.focus_entered.connect(_show_focus)
	grow.focus_exited.connect(_show_focus)
	advance.pressed.connect(_advance_once)
	resized.connect(_layout)
	_layout()
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if details.visible and details.get_global_rect().has_point(event.position):
			return
		keyboard_focus = false
		details.hide()
		_show_focus()
	if not event is InputEventKey:
		return
	if event.pressed and not event.echo:
		keyboard_focus = true
		_show_focus()
		if event.keycode == KEY_TAB:
			details.hide()
		if event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			_toggle_details()
			return
		if details.visible:
			if event.keycode == KEY_ESCAPE:
				details.hide()
				get_viewport().set_input_as_handled()
				return
			if event.keycode in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
				var stride := 24 if event.keycode in [KEY_UP, KEY_DOWN] else roundi(detail_scroll.size.y * 0.8)
				detail_scroll.scroll_vertical += -stride if event.keycode in [KEY_UP, KEY_PAGEUP] else stride
				get_viewport().set_input_as_handled()
				return
	if event.keycode not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	details.hide()
	if event.keycode == KEY_SPACE:
		_grow_once()
	else:
		_advance_once()

func _grow_once() -> void:
	if run.won:
		return
	run.grow()
	dirty = true
	if Time.get_ticks_msec() - last_save >= SAVE_INTERVAL_MS:
		_save()
	_refresh()

func _advance_once() -> void:
	if run.won:
		if replay_locked:
			return
		run.reset()
	elif run.ready():
		run.advance()
		if run.won:
			replay_locked = true
			get_tree().create_timer(0.75).timeout.connect(_unlock_replay)
	else:
		return
	dirty = true
	_save()
	_refresh()

func _unlock_replay() -> void:
	replay_locked = false
	_refresh()

func _save() -> void:
	if dirty:
		dirty = not run.save_game()
		last_save = Time.get_ticks_msec()

func _close_game() -> void:
	_save()
	get_tree().quit()

func _refresh() -> void:
	for item in [grow, stage_label, hint, tower, price, track]:
		item.visible = not run.won
	ending.visible = run.won
	if run.won:
		action_label.text = "再玩"
		advance.accessibility_name = "再玩"
		advance.tooltip_text = "Enter"
		advance.disabled = replay_locked
		return

	score_text = run.balance_text()
	var target := run.target()
	var ready := run.ready()
	var last := run.stage == Growth.count() - 1
	cost = "" if last else run.cost_text()
	price.visible = not cost.is_empty()
	var skip := run.can_skip()
	var next_stage := run.stage + (2 if skip else 1)
	advance.disabled = not ready
	action_label.text = "Vanish" if last else "躍遷"
	action_label.add_theme_color_override("font_color", GOLD if ready else MUTED)
	stage_label.text = Growth.title(run.stage)
	grow.accessibility_name = "成長，餘額 " + score_text
	advance.accessibility_name = "Vanish" if last else "躍遷，扣除 " + cost
	hint.text = ""
	if run.stage == 0 and run.step == 0:
		hint.text = "點一下"
	elif skip:
		hint.text = "躍遷將跳過" + Growth.title(run.stage + 1)

	progress_fraction = clampf(float(run.step) / maxf(1.0, float(target)), 0.0, 1.0)
	progress.color = GOLD if ready else MUTED
	progress.size.x = track.size.x * progress_fraction
	tower.show_progress(run.stage, run.step, target)
	grow.tooltip_text = "空白鍵成長 · F1 詳情"
	advance.tooltip_text = "Enter 完成 · F1 詳情" if last else "到 %s · F1 詳情" % Growth.title(next_stage)
	_fit_text()
	_show_focus()

func _toggle_details() -> void:
	if run.won or details.visible:
		details.hide()
		return
	var target := run.target()
	var is_final := run.stage == Growth.count() - 1
	var ready := run.ready()
	var destination := run.stage + (2 if run.can_skip() else 1)
	var leap_info := "Vanish" if is_final else "躍遷至 %s　·　扣除 %s" % [Growth.title(destination), cost]
	var requirement := "　·　已解鎖" if ready else ""
	if not ready and run.step >= target:
		requirement = "　·　餘額不足"
	leap_info += "\n本系 %d / %d 下%s" % [run.step, target, requirement]
	var skip_price := run.skip_price()
	if not skip_price.is_empty() and not run.can_skip():
		leap_info += "\n本系跨過 %s 可跳過下一系" % skip_price
	var stage_record := ""
	if not run.previous_record.is_empty():
		stage_record = "\n上系 %s　%s" % [run.previous_title, run.previous_record]
	var comparison := run.comparison()
	var comparison_line := "" if comparison.is_empty() else "\n" + comparison
	var growth_info := "%s%s%s\n\n%s" % [run.display_rule(), stage_record, comparison_line, run.balance_detail()]
	var content_width := minf(size.x - 28.0, 660.0)
	detail_label.text = _wrap_details(leap_info + "\n\n" + growth_info, content_width - 46.0)
	var available_height := minf(size.y * 0.46, 234.0)
	var panel_height := minf(available_height, 30.0 + detail_label.text.get_slice_count("\n") * 20.0)
	_place(details, (size.x - content_width) / 2.0, size.y - panel_height - 14.0, content_width, panel_height)
	detail_scroll.set_deferred("scroll_vertical", 0)
	details.show()

func _wrap_details(content: String, limit: float) -> String:
	var lines := PackedStringArray()
	for paragraph in content.split("\n"):
		var line := ""
		for character in paragraph:
			var candidate := line + character
			if not line.is_empty() and _measure(text_font, candidate, 14) > limit:
				lines.append(line)
				line = character
			else:
				line = candidate
		lines.append(line)
	return "\n".join(lines)

func _show_focus() -> void:
	focus_mark.visible = not run.won and keyboard_focus and grow.has_focus()

func _layout() -> void:
	var width := size.x
	var height := size.y
	var margin := clampf(minf(width, height) * 0.06, 13.0, 48.0)
	var content_width := width - 2.0 * margin
	var header_height := clampf(height * 0.118, 57.0, 96.0)
	var leap_width := clampf(width * 0.32, 144.0, 330.0)
	var score_top := margin + header_height + clampf(height * 0.045, 10.0, 48.0)
	var score_height := clampf((height - score_top) * 0.30, 58.0, 178.0)
	var art_top := score_top + score_height + 26.0
	var bottom := height - margin

	_place(stage_label, margin, margin, content_width - leap_width - 16.0, header_height)
	_place(advance, width - margin - leap_width, margin, leap_width, header_height)
	_place(action_label, 14.0, header_height * 0.13, leap_width - 28.0, header_height * 0.40)
	_place(price, 14.0, header_height * 0.53, leap_width - 28.0, header_height * 0.29)
	_place(track, 0.0, header_height - 3.0, leap_width, 3.0)
	_place(progress, 0.0, 0.0, leap_width * progress_fraction, 3.0)
	_place(grow, margin, score_top, content_width, bottom - score_top)
	planned_score_height = roundf(score_height)
	# Clear the old line minimum before shrinking the label on window resize.
	score.add_theme_font_size_override("font_size", 23)
	_place(score, 0.0, 0.0, content_width, planned_score_height)
	_place(focus_mark, (content_width - 26.0) / 2.0, score_height + 1.0, 26.0, 2.0)
	_place(hint, margin, score_top + score_height + 7.0, content_width, 18.0)
	_place(tower, margin, art_top, content_width, maxf(0.0, bottom - art_top))
	_place(ending, margin, score_top, content_width, bottom - score_top)
	details.hide()
	_fit_text()

func _place(item: Control, x: float, y: float, width: float, height: float) -> void:
	item.position = Vector2(roundf(x), roundf(y))
	item.size = Vector2(roundf(width), roundf(height))

func _compact(value: String, max_width: float, smallest: int, fallback: String) -> String:
	if _measure(numeric_font, value, smallest) <= max_width:
		return value
	var digits := value.replace(",", "").replace(" ", "")
	if digits.length() > 8 and digits.is_valid_int():
		return "≈%s.%s×10^%d" % [digits[0], digits.substr(1, 3), digits.length() - 1]
	return fallback


func _debit(amount: String) -> String:
	if amount.contains(" + ") or amount.contains(" − ") or amount.contains(" - "):
		return "−(" + amount + ")"
	if amount.begins_with("≈"):
		return "≈−" + amount.trim_prefix("≈")
	return "−" + amount

func _fit_text() -> void:
	var score_width := maxf(1.0, score.size.x - 14.0)
	score.text = _compact(score_text, score_width, 28, run.compact_balance())
	var score_max := maxi(23, mini(146, floori(planned_score_height * 0.84)))
	var pixels := _font_size(numeric_font, score.text, score_width, score_max, 23)
	while pixels > 23 and numeric_font.get_height(pixels) > planned_score_height - 2.0:
		pixels -= 1
	score.add_theme_font_size_override("font_size", pixels)
	score.size.y = planned_score_height
	var cost_width := maxf(1.0, price.size.x - 4.0)
	price.text = "" if cost.is_empty() else _debit(_compact(cost, cost_width - 10.0, 15, "Δ(%d)" % run.target()))
	price.add_theme_font_size_override("font_size", _font_size(numeric_font, price.text, cost_width, 19, 12))
	stage_label.add_theme_font_size_override("font_size", _font_size(text_font, stage_label.text, stage_label.size.x, 28, 15))
	action_label.add_theme_font_size_override("font_size", clampi(floori(advance.size.y * 0.30), 19, 28))

func _font_size(font: Font, value: String, width: float, preferred: int, smallest: int) -> int:
	return clampi(floori(float(preferred) * width / maxf(1.0, _measure(font, value, preferred))), smallest, preferred)

func _measure(font: Font, value: String, pixels: int) -> float:
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, pixels).x

func _set_style(item: Label, font: Font, pixels: int, color: Color) -> void:
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", pixels)
	item.add_theme_color_override("font_color", color)

func _box(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(border_width)
	return result

func _style_controls() -> void:
	text_font.font_names = PackedStringArray(["PingFang TC", "Noto Sans CJK TC", "Microsoft JhengHei"])
	numeric_font.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	numeric_font.font_weight = 700
	for item in [stage_label, action_label, price, hint, score]:
		item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_style(stage_label, text_font, 28, WHITE)
	stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_style(action_label, text_font, 22, GOLD)
	_set_style(price, numeric_font, 16, MUTED)
	_set_style(hint, text_font, 13, MUTED)
	_set_style(score, numeric_font, 96, WHITE)
	_set_style(ending, text_font, 36, WHITE)
	_set_style(detail_label, text_font, 14, WHITE)
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		grow.add_theme_stylebox_override(style, empty)
	advance.add_theme_stylebox_override("normal", _box(Color("#14110b"), GOLD))
	advance.add_theme_stylebox_override("hover", _box(Color("#232017"), GOLD))
	advance.add_theme_stylebox_override("pressed", _box(Color("#2d2719"), GOLD))
	advance.add_theme_stylebox_override("disabled", _box(Color("#0c0b08"), RULE))
	var focus := _box(Color.TRANSPARENT, GOLD, 2)
	focus.draw_center = false
	advance.add_theme_stylebox_override("focus", focus)
	var explanation := _box(Color("#12110d"), RULE)
	for side in [SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM, SIDE_LEFT]:
		explanation.set_content_margin(side, 14.0)
	details.add_theme_stylebox_override("panel", explanation)
