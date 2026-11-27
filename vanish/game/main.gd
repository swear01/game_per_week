extends Control

const Run = preload("res://run.gd")
const Growth = preload("res://growth.gd")
const Tower = preload("res://tower.gd")
const WHITE := Color("#eeece4")
const GOLD := Color("#dbca97")
const MUTED := Color("#a4a096")
const RULE := Color("#34322b")
const SAVE_INTERVAL_MS := 10000
const CREDIT_THRESHOLDS := [2, 6, 14]

var run := Run.new()
var replay_locked := false
var dirty := false
var last_save := 0
var text_font := SystemFont.new()
var numeric_font := SystemFont.new()

@onready var advance: Button = $Advance
@onready var action_label: Label = $Advance/Action
@onready var price: Label = $Advance/Price
@onready var grow: Button = $Grow
@onready var stage_label: Label = $Stage
@onready var rule_label: Label = $Rule
@onready var quote: Label = $Quote
@onready var wait_label: Label = $Wait
@onready var tower: Tower = $Tower
@onready var record: Label = $Record
@onready var scale_label: Label = $Scale
@onready var ending: Label = $Ending

func _ready() -> void:
	OS.low_processor_usage_mode = true
	get_window().min_size = Vector2i(550, 500)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_close_game)
	run.restore()
	last_save = Time.get_ticks_msec()
	_style_controls()
	grow.pressed.connect(_grow_once)
	advance.pressed.connect(_advance_once)
	resized.connect(_layout)
	_layout()
	_refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.keycode not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
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
	for item in [grow, stage_label, rule_label, quote, wait_label, tower, record, scale_label]:
		item.visible = not run.won
	ending.visible = run.won
	if run.won:
		_set_advance("再玩", "")
		advance.disabled = replay_locked
		return

	var value := run.display_value(run.step)
	var is_ready := run.ready()
	var skip := run.can_skip()
	var last := run.stage == Growth.count() - 1
	var current_price := run.display_value(run.target())
	var verb := "Vanish" if last else ("跳系" if skip else "換系")
	var condition := _gate_label(current_price, run.target(), is_ready)
	if skip:
		condition = _gate_label(run.next_price(), run.next_target(), false)
	_set_advance(verb, condition)
	advance.disabled = not is_ready
	action_label.add_theme_color_override("font_color", GOLD if is_ready else MUTED)
	stage_label.text = "%s　%d/%d" % [Growth.title(run.stage), run.stage + 1, Growth.count()]
	grow.text = value
	grow.tooltip_text = value
	grow.accessibility_name = "成長，%s，第 %d 下" % [value, run.step]
	var introduction := "點一下　·　" if run.stage == 0 and run.step == 0 else ""
	rule_label.text = introduction + ("n = %d　·　%s" % [run.step, run.display_rule()])
	rule_label.tooltip_text = rule_label.text
	_render_quote(is_ready, last, skip)

	var prior := not run.previous_record.is_empty()
	record.visible = prior
	record.text = "上系 %s　%s" % [run.previous_title, run.previous_record] if prior else ""
	if prior and value.contains("SSCG("):
		record.text = "P = 上系 %s　%s" % [run.previous_title, run.previous_record]
	record.tooltip_text = record.text
	var tower_scale := tower.update_tower(value, run.step, run.target(), prior, run.stage == 0)
	var comparison := run.comparison()
	scale_label.text = tower_scale if comparison.is_empty() else comparison
	scale_label.tooltip_text = scale_label.text
	_fit_text()

func _render_quote(is_ready: bool, last: bool, skip: bool) -> void:
	quote.text = ""
	wait_label.text = ""
	if not is_ready or last:
		return

	var destination := run.stage + (2 if skip else 1)
	var credit := run.credit()
	var target := run.next_target()
	if skip:
		quote.text = "跳過 %s　到 %s　%d 下達標" % [Growth.title(run.stage + 1), Growth.title(destination), target]
		return

	var next_price := run.next_price()
	var next_gate := _gate_label(next_price, target, false)
	quote.text = "%s　%s　%d 下達標" % [Growth.title(destination), next_gate, target]
	var undiscounted := Growth.safe_target(destination, 0)
	if target < undiscounted:
		quote.text += "（抵 %d 下）" % (undiscounted - target)
	var extra := run.step - run.target()
	for index in range(CREDIT_THRESHOLDS.size()):
		var next_credit := index + 1
		var at: int = CREDIT_THRESHOLDS[index]
		var future_target := Growth.safe_target(destination, next_credit)
		if at > extra and next_credit > credit and future_target < target:
			wait_label.text = "再點 %d 下，可多抵 %d 下" % [at - extra, target - future_target]
			break
	var skip_price := run.skip_price()
	if not skip_price.is_empty():
		var hint := "本系達 %s 可跳過 %s" % [skip_price, Growth.title(run.stage + 1)]
		wait_label.text = hint if wait_label.text.is_empty() else wait_label.text + "　·　" + hint

func _gate_label(displayed: String, at_step: int, reached: bool) -> String:
	if not Tower.is_numeric(displayed):
		return ("達標 n = %d" if reached else "預算 n = %d") % at_step
	return ("達標 " if reached else "門檻 ") + displayed

func _set_advance(action: String, detail: String) -> void:
	action_label.text = action
	price.text = detail
	advance.tooltip_text = action + "［Enter］" if detail.is_empty() else detail + "［Enter］"
	advance.accessibility_name = action if detail.is_empty() else action + "，" + detail

func _layout() -> void:
	var width := size.x
	var height := size.y
	var margin := clampf(width * 0.07, 24.0, 76.0)
	var middle := width / 2.0
	var hero_width := minf(730.0, width - 2.0 * margin)
	var left := middle - hero_width / 2.0
	var stage_top := maxf(130.0, height * 0.20)
	var button_top := stage_top + 35.0
	var button_height := clampf(height * 0.19, 105.0, 158.0)
	var rule_top := button_top + button_height + 11.0
	var advance_width := clampf(width * 0.28, 210.0, 275.0)
	var landscape_top := rule_top + 90.0
	var landscape_bottom := height - 63.0

	_place(advance, width - margin - advance_width, 26.0, advance_width, 63.0)
	_place(action_label, 12.0, 8.0, advance_width - 24.0, 23.0)
	_place(price, 12.0, 33.0, advance_width - 24.0, 19.0)
	_place(stage_label, left, stage_top, hero_width, 29.0)
	_place(grow, left, button_top, hero_width, button_height)
	_place(rule_label, left, rule_top, hero_width, 24.0)
	_place(quote, left, rule_top + 37.0, hero_width, 24.0)
	_place(wait_label, left, rule_top + 62.0, hero_width, 21.0)
	_place(tower, left, landscape_top, hero_width, maxf(24.0, landscape_bottom - landscape_top))
	_place(record, left, landscape_bottom + 1.0, hero_width, 19.0)
	_place(scale_label, left, landscape_bottom + 22.0, hero_width, 19.0)
	_place(ending, left, height / 2.0 - 64.0, hero_width, 128.0)
	_fit_text()

func _place(item: Control, x: float, y: float, width: float, height: float) -> void:
	item.position = Vector2(roundf(x), roundf(y))
	item.size = Vector2(roundf(width), roundf(height))

func _fit_text() -> void:
	var value_width := grow.size.x - 36.0
	var pixels := _font_size(numeric_font, grow.text, value_width, 86, 23)
	grow.add_theme_font_size_override("font_size", pixels)
	for item in [rule_label, quote, wait_label, record, scale_label, price]:
		var preferred := 16 if item == rule_label or item == quote else 13
		var fitted := _font_size(text_font, item.text, item.size.x, preferred, 11)
		item.add_theme_font_size_override("font_size", fitted)

func _font_size(font: Font, value: String, width: float, preferred: int, smallest: int) -> int:
	var natural := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, preferred).x
	return clampi(floori(float(preferred) * width / maxf(1.0, natural)), smallest, preferred)

func _set_style(item: Control, font: Font, pixels: int, color: Color) -> void:
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", pixels)
	item.add_theme_color_override("font_color", color)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	return result

func _style_controls() -> void:
	text_font.font_names = PackedStringArray(["PingFang TC", "Noto Sans CJK TC", "Microsoft JhengHei"])
	numeric_font.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	numeric_font.font_weight = 700
	for item in [stage_label, action_label, price, rule_label, quote, wait_label, record, scale_label]:
		item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_style(grow, numeric_font, 86, WHITE)
	_set_style(stage_label, text_font, 22, WHITE)
	_set_style(action_label, text_font, 17, GOLD)
	_set_style(price, text_font, 13, MUTED)
	_set_style(rule_label, text_font, 16, MUTED)
	_set_style(quote, text_font, 16, WHITE)
	_set_style(wait_label, text_font, 13, MUTED)
	_set_style(record, text_font, 13, MUTED)
	_set_style(scale_label, text_font, 13, MUTED)
	_set_style(ending, text_font, 35, WHITE)
	grow.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	grow.add_theme_stylebox_override("normal", _box(Color.BLACK, RULE))
	grow.add_theme_stylebox_override("hover", _box(Color("#0b0a06"), GOLD))
	grow.add_theme_stylebox_override("pressed", _box(Color("#151108"), GOLD))
	advance.add_theme_stylebox_override("normal", _box(Color("#0c0b06"), GOLD))
	advance.add_theme_stylebox_override("hover", _box(Color("#181408"), GOLD))
	advance.add_theme_stylebox_override("pressed", _box(Color("#241b0b"), GOLD))
	advance.add_theme_stylebox_override("disabled", _box(Color.BLACK, RULE))
	var focus := _box(Color.TRANSPARENT, GOLD)
	focus.draw_center = false
	for item in [grow, advance]:
		item.add_theme_stylebox_override("focus", focus)
