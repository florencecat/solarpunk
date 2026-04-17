extends Control

var _selected: int    = -1
var _btns:     Dictionary = {}   # b_type → Button

func _ready() -> void:
	_build_ui()
	EventBus.building_type_selected.connect(_on_type_selected)

func _build_ui() -> void:
	var root = PanelContainer.new()
	var s    = StyleBoxFlat.new()
	s.bg_color                  = Color(0.06, 0.12, 0.07, 0.96)
	s.corner_radius_top_left    = 8
	s.corner_radius_top_right   = 8
	s.corner_radius_bottom_left  = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left   = 12.0
	s.content_margin_right  = 12.0
	s.content_margin_top    = 10.0
	s.content_margin_bottom = 10.0
	root.add_theme_stylebox_override("panel", s)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	var hdr = Label.new()
	hdr.text = "🏗   ПОСТРОЙКИ"
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(0.50, 0.92, 0.42))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hdr)

	var hint = Label.new()
	hint.text = "ЛКМ — выбрать  ·  ПКМ — снять"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.42, 0.42, 0.42))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	vbox.add_child(HSeparator.new())

	var all_types = [
		GameState.BUILDING_PUMP,
		GameState.BUILDING_PURIFIER,
		GameState.BUILDING_CONDENSER,
		GameState.BUILDING_CARAVAN_STATION,
	]
	for b: int in all_types:
		vbox.add_child(_bld_entry(b))

func _bld_entry(b: int) -> Control:
	var info = _info(b)
	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)

	var btn = Button.new()
	btn.text = info.name
	btn.custom_minimum_size = Vector2(172.0, 32.0)
	_style_btn(btn, info.color, false)
	btn.pressed.connect(func(): _select(b))
	entry.add_child(btn)
	_btns[b] = btn

	var dl = Label.new()
	dl.text = info.desc
	dl.add_theme_font_size_override("font_size", 10)
	dl.add_theme_color_override("font_color", Color(0.56, 0.56, 0.56))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(dl)

	var pl = Label.new()
	pl.text = "⚡ " + info.prod
	pl.add_theme_font_size_override("font_size", 10)
	pl.add_theme_color_override("font_color", Color(0.42, 0.90, 0.58))
	entry.add_child(pl)

	entry.add_child(HSeparator.new())
	return entry

func _select(b: int) -> void:
	_selected = (-1 if _selected == b else b)
	GameState.selected_building_type = _selected
	EventBus.building_type_selected.emit(_selected)
	_refresh_styles()

func _on_type_selected(b: int) -> void:
	_selected = b
	_refresh_styles()

func _refresh_styles() -> void:
	for b: int in _btns:
		_style_btn(_btns[b], _info(b).color, b == _selected)

func _style_btn(btn: Button, color: Color, selected: bool) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color    = Color(color.r * (0.55 if selected else 0.25),
						  color.g * (0.55 if selected else 0.25),
						  color.b * (0.55 if selected else 0.25), 1.0)
	s.border_color = color if selected else Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 1.0)
	s.border_width_left   = 3
	s.border_width_right  = 3
	s.border_width_top    = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left    = 4
	s.corner_radius_top_right   = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", s)
	# Hover-стиль
	var sh = StyleBoxFlat.new()
	sh.bg_color    = Color(color.r * 0.72, color.g * 0.72, color.b * 0.72, 1.0)
	sh.border_color = color
	sh.border_width_left   = 3
	sh.border_width_right  = 3
	sh.border_width_top    = 3
	sh.border_width_bottom = 3
	sh.corner_radius_top_left    = 4
	sh.corner_radius_top_right   = 4
	sh.corner_radius_bottom_left  = 4
	sh.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", sh)

func _info(b: int) -> Dictionary:
	match b:
		GameState.BUILDING_PUMP:
			return {"name": "Насос",
					"desc": "Добывает воду. Эффективнее на тайлах с источником.",
					"prod": "+5–15 воды/день",
					"color": Color(0.15, 0.48, 0.98)}
		GameState.BUILDING_PURIFIER:
			return {"name": "Очиститель",
					"desc": "Конвертирует грязную воду в питьевую.",
					"prod": "Очищает до 12 ед./день",
					"color": Color(0.10, 0.82, 0.62)}
		GameState.BUILDING_CONDENSER:
			return {"name": "Конденсатор",
					"desc": "Улавливает влагу из воздуха. Работает на любом тайле.",
					"prod": "+2 воды/день",
					"color": Color(0.68, 0.68, 0.88)}
		GameState.BUILDING_CARAVAN_STATION:
			return {"name": "Торговый пост",
					"desc": "Открывает торговые и враждебные события.",
					"prod": "Каравны и мародёры",
					"color": Color(0.98, 0.54, 0.10)}
		_:
			return {"name": "?", "desc": "", "prod": "", "color": Color.WHITE}
