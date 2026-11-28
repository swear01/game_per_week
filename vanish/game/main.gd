extends Control

const Run = preload("res://run.gd")
const Growth = preload("res://growth.gd")
const Tower = preload("res://tower.gd")
const WHITE := Color("#f0eee6")
const GOLD := Color("#e4cfa0")
const MUTED := Color("#a4a096")
const RULE := Color("#39372e")
const MIN_WINDOW_POINTS := Vector2i(320, 240)
const MIN_UI_ZOOM := 0.80

var run := Run.new()
var replay_locked := false
var text_font := SystemFont.new()
var numeric_font := SystemFont.new()
var keyboard_focus := false
var score_text := ""
var cost := ""
var progress_fraction := 0.0
var planned_score_height := 0.0
var reference_size := Vector2i.ZERO
var backing_scale := 1.0
var detail_content := ""
var showing_controls := false
var gain_tween: Tween

@onready var advance: Button = $Advance
@onready var action_label: Label = $Advance/Action
@onready var price: Label = $Advance/Price
@onready var track: ColorRect = $Advance/Track
@onready var progress: ColorRect = $Advance/Track/Progress
@onready var grow: Button = $Grow
@onready var score: Label = $Grow/Score
@onready var focus_mark: ColorRect = $Grow/Focus
@onready var stage_label: Label = $Stage
@onready var stage_count: Label = $StageCount
@onready var gain: Label = $Gain
@onready var hint: Label = $Hint
@onready var tower: Tower = $Tower
@onready var ending: Label = $Ending
@onready var details: PanelContainer = $Details
@onready var detail_scroll: ScrollContainer = $Details/Scroll
@onready var detail_label: Label = $Details/Scroll/Text

func _ready() -> void:
	OS.low_processor_usage_mode = true
	_configure_window()
	_style_controls()
	grow.pressed.connect(_grow_once)
	grow.focus_entered.connect(_show_focus)
	grow.focus_exited.connect(_show_focus)
	advance.pressed.connect(_advance_once)
	resized.connect(_layout)
	_layout()
	_refresh()

func _configure_window() -> void:
	var window := get_window()
	reference_size = window.content_scale_size
	# On macOS Godot window coordinates use the maximum backing scale across displays.
	if DisplayServer.get_name() == "macOS":
		backing_scale = DisplayServer.screen_get_max_scale()

	if not Engine.is_embedded_in_editor() and DisplayServer.get_name() != "headless":
		var minimum := Vector2i((Vector2(MIN_WINDOW_POINTS) * backing_scale).round())
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		var decoration := (DisplayServer.window_get_size_with_decorations() - window.size).max(Vector2i.ZERO)
		var available := usable.size - decoration
		var default_size := window.size == reference_size
		if available.x > 0 and available.y > 0:
			minimum = minimum.min(available)
		if not default_size:
			minimum = minimum.min(window.size)
		window.min_size = minimum

		if default_size and window.mode == Window.MODE_WINDOWED and available.x > 0 and available.y > 0:
			var desired := Vector2(reference_size) * backing_scale
			var fit := minf(1.0, minf(available.x / desired.x, available.y / desired.y))
			window.size = Vector2i((desired * fit).floor())
			if not OS.get_cmdline_args().has("--position"):
				var slack := usable.size - window.size - decoration
				window.position = usable.position + Vector2i((Vector2(slack) * 0.5).floor())

	window.size_changed.connect(_update_canvas_size)
	_update_canvas_size()

func _update_canvas_size() -> void:
	var window := get_window()
	if reference_size.x <= 0 or reference_size.y <= 0 or window.size.x <= 0 or window.size.y <= 0:
		return
	var in_points := Vector2(window.size) / backing_scale
	var fit := minf(in_points.x / reference_size.x, in_points.y / reference_size.y)
	# Smaller windows reflow at a readable scale instead of shrinking the same full-size canvas.
	var factor := minf(1.0, fit / MIN_UI_ZOOM)
	var canvas_reference := Vector2i((Vector2(reference_size) * factor).round()).max(Vector2i.ONE)
	if window.content_scale_size != canvas_reference:
		window.content_scale_size = canvas_reference

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if details.visible:
			if not details.get_global_rect().has_point(event.position):
				details.hide()
				get_viewport().set_input_as_handled()
			return
		keyboard_focus = false
		_show_focus()
	if not event is InputEventKey:
		return
	if event.pressed and not event.echo:
		keyboard_focus = true
		_show_focus()
		match event.keycode:
			KEY_ESCAPE:
				if details.visible:
					details.hide()
				else:
					_open_controls()
				get_viewport().set_input_as_handled()
				return
			KEY_F1:
				if details.visible and showing_controls:
					details.hide()
				_toggle_details()
				get_viewport().set_input_as_handled()
				return
	if details.visible:
		if event.pressed and event.keycode in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
			var stride := 24 if event.keycode in [KEY_UP, KEY_DOWN] else roundi(detail_scroll.size.y * 0.8)
			detail_scroll.scroll_vertical += -stride if event.keycode in [KEY_UP, KEY_PAGEUP] else stride
		get_viewport().set_input_as_handled()
		return
	if event.keycode not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_grow_once()
		else:
			_advance_once()

func _open_controls() -> void:
	showing_controls = true
	detail_content = "空白鍵　成長\nEnter　 躍遷\nF1　　 數列詳情\nEsc　　 繼續遊戲"
	if run.won:
		detail_content = "Enter　再玩\nEsc　　返回"
	_layout_details(0)
	details.show()

func _grow_once() -> void:
	if run.won:
		return
	run.grow()
	_refresh()
	_flash_gain()

func _clear_gain() -> void:
	if gain_tween:
		gain_tween.kill()
	gain.hide()
	hint.visible = not run.won

func _flash_gain() -> void:
	_clear_gain()
	var amount := run.last_increment_text()
	gain.text = "+" + amount.trim_prefix("≈").trim_prefix("≥")
	if amount.begins_with("≈"):
		gain.text = "≈" + gain.text
	elif amount.begins_with("≥"):
		gain.text = "≥" + gain.text
	gain.add_theme_font_size_override("font_size", _font_size(numeric_font, gain.text, gain.size.x, 22, 14))
	gain.modulate.a = 1.0
	gain.show()
	hint.hide()
	gain_tween = create_tween()
	gain_tween.tween_interval(0.5)
	gain_tween.tween_property(gain, "modulate:a", 0.0, 0.16)
	gain_tween.tween_callback(gain.hide)
	gain_tween.tween_callback(hint.set_visible.bind(not run.won))

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
	_clear_gain()
	_refresh()

func _unlock_replay() -> void:
	replay_locked = false
	_refresh()

func _refresh() -> void:
	for item in [grow, stage_label, stage_count, hint, tower, price, track]:
		item.visible = not run.won
	ending.visible = run.won
	if run.won:
		action_label.text = "再玩"
		advance.accessibility_name = "再玩"
		advance.disabled = replay_locked
		return

	score_text = run.balance_text()
	var target := run.target()
	var ready := run.ready()
	var last := run.stage == Growth.count() - 1
	cost = "" if last else run.cost_text()
	price.visible = not cost.is_empty()
	var skip := run.can_skip()
	advance.disabled = not ready
	action_label.text = "Vanish" if last else "躍遷"
	action_label.add_theme_color_override("font_color", GOLD if ready else MUTED)
	stage_label.text = Growth.title(run.stage)
	stage_count.text = "%d / %d" % [run.stage + 1, Growth.count()]
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
	tower.clip_contents = Growth.key(run.stage) not in ["harmonic", "inverse_sqrt"]
	tower.show_progress(run.stage, run.step, target)
	_fit_text()
	_show_focus()

func _toggle_details() -> void:
	showing_controls = false
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
	var rule := run.display_rule()
	if run.stage == 0:
		rule += "\n" + Growth.value(0, run.step)
	var growth_info := "%s%s%s\n\n%s" % [rule, stage_record, comparison_line, run.balance_detail()]
	detail_content = leap_info + "\n\n" + growth_info
	_layout_details(0)
	details.show()

func _layout_details(scroll_position: int) -> void:
	var content_width := minf(size.x - 28.0, 250.0 if showing_controls else 660.0)
	var line_width := roundi(content_width - 46.0)
	detail_label.text = _wrap_details(detail_content, line_width)
	var available_height := minf(size.y * 0.46, 234.0)
	var panel_height := minf(available_height, 30.0 + detail_label.text.get_slice_count("\n") * 20.0)
	var top := (size.y - panel_height) * 0.5 if showing_controls else size.y - panel_height - 14.0
	_place(details, (size.x - content_width) / 2.0, top, content_width, panel_height)
	detail_scroll.set_deferred("scroll_vertical", scroll_position)

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
	var frame_width := minf(width, maxf(1040.0, height * 1.75))
	var left := (width - frame_width) * 0.5 + margin
	var content_width := frame_width - 2.0 * margin
	var header_height := clampf(height * 0.118, 57.0, 96.0)
	var leap_width := clampf(content_width * 0.34, 144.0, 330.0)
	var score_top := margin + header_height + clampf(height * 0.045, 10.0, 48.0)
	var score_height := clampf((height - score_top) * 0.30, 58.0, 178.0)
	var art_top := score_top + score_height + 26.0
	var bottom := height - margin

	var title_width := content_width - leap_width - 16.0
	_place(stage_label, left, margin, title_width, header_height - 19.0)
	_place(stage_count, left, margin + header_height - 19.0, title_width, 19.0)
	_place(advance, left + content_width - leap_width, margin, leap_width, header_height)
	_place(action_label, 14.0, header_height * 0.13, leap_width - 28.0, header_height * 0.40)
	_place(price, 14.0, header_height * 0.53, leap_width - 28.0, header_height * 0.29)
	_place(track, 0.0, header_height - 3.0, leap_width, 3.0)
	_place(progress, 0.0, 0.0, leap_width * progress_fraction, 3.0)
	_place(grow, left, score_top, content_width, bottom - score_top)
	planned_score_height = roundf(score_height)
	# Clear the old line minimum before shrinking the label on window resize.
	score.add_theme_font_size_override("font_size", 23)
	_place(score, 0.0, 0.0, content_width, planned_score_height)
	_place(focus_mark, (content_width - 26.0) / 2.0, score_height + 1.0, 26.0, 2.0)
	_place(hint, left, score_top + score_height + 7.0, content_width, 18.0)
	_place(gain, left, score_top + score_height + 1.0, content_width, 27.0)
	_place(tower, left, art_top, content_width, maxf(0.0, bottom - art_top))
	tower.stack_headroom = tower.position.y
	tower.queue_redraw()
	_place(ending, left, score_top, content_width, bottom - score_top)
	if details.visible:
		_layout_details(detail_scroll.scroll_vertical)
	_fit_text()

func _place(item: Control, x: float, y: float, width: float, height: float) -> void:
	var origin := Vector2(x, y).round()
	item.position = origin
	item.size = Vector2(x + width, y + height).round() - origin

func _compact(value: String, max_width: float, smallest: int, fallback: String) -> String:
	if _measure(numeric_font, value, smallest) <= max_width:
		return value
	return fallback


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
	price.text = "" if cost.is_empty() else _compact(cost, cost_width, 15, run.compact_cost())
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
	_set_style(stage_count, numeric_font, 15, MUTED)
	_set_style(gain, numeric_font, 22, GOLD)
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
