## Центрированное модальное окно, перекрывающее весь экран.
## Используется для событий-выборов и экрана конца игры.
extends Control

var _backdrop:    ColorRect
var _panel:       PanelContainer
var _title_lbl:   Label
var _desc_lbl:    Label
var _btn_row:     HBoxContainer
var _btn_a:       Button
var _btn_b:       Button

var _callback: Callable = Callable()

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()
	visible = false
	EventBus.choice_event_pending.connect(_on_choice_event)
	EventBus.game_over.connect(_on_game_over)

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Полупрозрачный фон — блокирует клики через окно
	_backdrop              = ColorRect.new()
	_backdrop.color        = Color(0.0, 0.0, 0.0, 0.65)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Центрированный контейнер
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Панель
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(380, 0)
	var sbox                   = StyleBoxFlat.new()
	sbox.bg_color                  = Color(0.08, 0.08, 0.16, 0.98)
	sbox.border_color              = Color(0.50, 0.44, 0.28, 1.0)
	sbox.border_width_left         = 2
	sbox.border_width_right        = 2
	sbox.border_width_top          = 2
	sbox.border_width_bottom       = 2
	sbox.corner_radius_top_left    = 10
	sbox.corner_radius_top_right   = 10
	sbox.corner_radius_bottom_left = 10
	sbox.corner_radius_bottom_right = 10
	sbox.content_margin_left   = 22.0
	sbox.content_margin_right  = 22.0
	sbox.content_margin_top    = 18.0
	sbox.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", sbox)
	center.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", 14)
	_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(336, 0)
	vbox.add_child(_desc_lbl)

	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 10)
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_btn_row)

	_btn_a = _make_btn("OK", _on_btn_a)
	_btn_b = _make_btn("",  _on_btn_b)
	_btn_row.add_child(_btn_a)
	_btn_row.add_child(_btn_b)

# ─── Публичное API ────────────────────────────────────────────────────────────

## Показать модальное окно.
## btn_b = "" → скрыть вторую кнопку.
## callback(choice: int) — 0 для кнопки А, 1 для кнопки Б.
func show_modal(title: String, desc: String,
				btn_a_text: String = "OK",
				btn_b_text: String = "",
				callback: Callable = Callable()) -> void:
	_title_lbl.text = title
	_desc_lbl.text  = desc
	_btn_a.text     = btn_a_text
	_btn_a.visible  = btn_a_text != ""
	_btn_b.text     = btn_b_text
	_btn_b.visible  = btn_b_text != ""
	_callback       = callback
	visible         = true

# ─── Сигналы ─────────────────────────────────────────────────────────────────

func _on_choice_event(event: Dictionary) -> void:
	show_modal(
		event.get("title", ""),
		event.get("desc", ""),
		event.get("choice_a", "Подтвердить"),
		event.get("choice_b", "Отказать"),
		func(choice): EventBus.choice_resolved.emit(choice)
	)

func _on_game_over(reason: String, score: int) -> void:
	show_modal(
		"КОНЕЦ ИГРЫ",
		"%s\n\nИтоговые очки: %d" % [reason, score],
		"Закрыть",
		""
	)

# ─── Кнопки ──────────────────────────────────────────────────────────────────

func _on_btn_a() -> void:
	visible = false
	if _callback.is_valid():
		_callback.call(0)

func _on_btn_b() -> void:
	visible = false
	if _callback.is_valid():
		_callback.call(1)

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _make_btn(label: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(140, 36)
	b.pressed.connect(cb)
	return b
