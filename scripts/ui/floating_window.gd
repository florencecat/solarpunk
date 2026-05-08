## Базовый класс плавающего окна.
## Полоса заголовка (перетаскивание + кнопка ✕) + область содержимого.
## Дочерние классы переопределяют _get_title() и _build_content(vbox).
class_name FloatingWindow
extends Control

signal closed

var _content_vbox: VBoxContainer
var _title_lbl:    Label
var _drag_active:  bool    = false
var _drag_offset:  Vector2 = Vector2.ZERO

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_chrome()
	_build_content(_content_vbox)
	visible = false

## Переопределить: заголовок окна (в полосе заголовка)
func _get_title() -> String:
	return ""

## Переопределить: наполнить vbox содержимым окна
func _build_content(_vbox: VBoxContainer) -> void:
	pass

# ─── Рамка окна ──────────────────────────────────────────────────────────────

func _build_chrome() -> void:
	# Угловые скобки поверх всего окна (отрисовываются в _draw)
	queue_redraw()
	resized.connect(queue_redraw)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# ── Полоса заголовка ──────────────────────────────────────────────────────
	var title_panel = PanelContainer.new()
	var ts          = StyleBoxFlat.new()
	ts.bg_color                  = Color(0.14, 0.10, 0.06, 0.98)
	ts.corner_radius_top_left    = 4
	ts.corner_radius_top_right   = 4
	ts.content_margin_left       = 10.0
	ts.content_margin_right      = 4.0
	ts.content_margin_top        = 6.0
	ts.content_margin_bottom     = 6.0
	title_panel.add_theme_stylebox_override("panel", ts)
	title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	title_panel.gui_input.connect(_on_titlebar_gui_input)
	root_vbox.add_child(title_panel)

	var th = HBoxContainer.new()
	th.add_theme_constant_override("separation", 5)
	title_panel.add_child(th)

	var grip = Label.new()
	grip.text = "⠿"
	grip.add_theme_font_size_override("font_size", 14)
	grip.add_theme_color_override("font_color", Color(0.40, 0.38, 0.32))
	th.add_child(grip)

	_title_lbl = Label.new()
	_title_lbl.text = _get_title()
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.52))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(_title_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(26, 24)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.30, 0.20))
	close_btn.pressed.connect(_on_close)
	th.add_child(close_btn)

	# ── Область содержимого ───────────────────────────────────────────────────
	var content_panel = PanelContainer.new()
	var cs            = StyleBoxFlat.new()
	cs.bg_color                   = Color(0.07, 0.07, 0.12, 0.97)
	cs.corner_radius_bottom_left  = 6
	cs.corner_radius_bottom_right = 6
	cs.content_margin_left        = 10.0
	cs.content_margin_right       = 10.0
	cs.content_margin_top         = 8.0
	cs.content_margin_bottom      = 8.0
	content_panel.add_theme_stylebox_override("panel", cs)
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_panel)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_child(_content_vbox)

# ─── Перетаскивание ──────────────────────────────────────────────────────────

func _on_titlebar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
		if event.pressed:
			_drag_offset = get_global_mouse_position() - global_position
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion and _drag_active:
		global_position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed \
			and _drag_active:
		_drag_active = false

# ─────────────────────────────────────────────────────────────────────────────

func _on_close() -> void:
	visible = false
	closed.emit()

## Переключить видимость окна
func toggle() -> void:
	visible = not visible

## Угловые скобки в стиле дизайна WindowChrome
func _draw() -> void:
	if not visible:
		return
	var w  := size.x
	var h  := size.y
	var sz := 14.0
	var c  := Color(0.831, 0.710, 0.463, 0.75)   # sand
	var lw := 1.5
	# Top-left
	draw_line(Vector2(0, sz),  Vector2(0, 0),  c, lw)
	draw_line(Vector2(0, 0),   Vector2(sz, 0), c, lw)
	# Top-right
	draw_line(Vector2(w-sz, 0), Vector2(w, 0),  c, lw)
	draw_line(Vector2(w, 0),    Vector2(w, sz), c, lw)
	# Bottom-left
	draw_line(Vector2(0, h-sz), Vector2(0, h),  c, lw)
	draw_line(Vector2(0, h),    Vector2(sz, h), c, lw)
	# Bottom-right
	draw_line(Vector2(w-sz, h), Vector2(w, h),  c, lw)
	draw_line(Vector2(w, h),    Vector2(w, h-sz), c, lw)
