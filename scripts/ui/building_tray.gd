## Нижняя панель быстрого доступа к постройкам.
## Кнопка «БОЛЬШЕ» открывает BuildingCatalog.
extends Control

signal catalog_requested

const C_INK     := Color(0.055, 0.039, 0.024)
const C_PANEL   := Color(0.110, 0.090, 0.063)
const C_STROKE  := Color(0.227, 0.184, 0.125)
const C_SAND    := Color(0.831, 0.710, 0.463)
const C_BONE    := Color(0.922, 0.863, 0.714)
const C_TEXT    := Color(0.847, 0.784, 0.620)
const C_MUTED   := Color(0.541, 0.478, 0.361)

# Порядок зданий в трее (индексы соответствуют GameState.BUILDING_*)
# 0=Pump 1=Purifier 2=Condenser 3=Caravan 4=Mine 5=Farm 6=Solar 7=Battery 8=Wall 9=Tower
const BUILDINGS: Array[int] = [0, 1, 5, 6, 7, 4, 3, 8, 9, 2]

const BINFO: Dictionary = {
	# b_type → {icon, name, cost_short, color}   (индексы = GameState.BUILDING_*)
	0: {icon="💧", name="Насос",      cost="15П",      color=Color(0.15,0.48,0.98)},
	1: {icon="🔵", name="Очист.",     cost="10П+10М",  color=Color(0.10,0.82,0.62)},
	2: {icon="☁",  name="Конденс.",   cost="20М+1А",   color=Color(0.68,0.68,0.88)},
	3: {icon="🐪", name="Торг.пост",  cost="40М",      color=Color(0.98,0.54,0.10)},
	4: {icon="⛏",  name="Шахта",     cost="20П",      color=Color(0.72,0.50,0.22)},
	5: {icon="🌿", name="Ферма",      cost="25М",      color=Color(0.28,0.75,0.22)},
	6: {icon="☀",  name="Панель",     cost="5П+15М+1А",color=Color(0.20,0.45,0.95)},
	7: {icon="🔋", name="Аккум.",     cost="30М",      color=Color(0.20,0.80,0.40)},
	8: {icon="🧱", name="Стена",      cost="30П+10М",  color=Color(0.65,0.55,0.35)},
	9: {icon="🗼", name="Башня",      cost="10П+20М",  color=Color(0.78,0.40,0.18)},
}

var _cells:    Dictionary = {}   # b_type → Control
var _selected: int        = -1

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(0, 90)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_tray()

	EventBus.building_type_selected.connect(_on_type_selected)
	EventBus.resources_changed.connect(func(_s, _sc, _d): _refresh_all())
	_refresh_all()

func _build_tray() -> void:
	# CenterContainer чтобы трей был по центру по горизонтали
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# смещаем выше нижнего края
	center.offset_bottom = -10
	add_child(center)

	# Панель-фон
	var wrap = PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.96)
	for prop in ["border_width_left","border_width_right",
				 "border_width_top","border_width_bottom"]:
		ps.set(prop, 1)
	ps.border_color = C_STROKE
	ps.content_margin_left  = 4.0; ps.content_margin_right  = 4.0
	ps.content_margin_top   = 4.0; ps.content_margin_bottom = 4.0
	wrap.add_theme_stylebox_override("panel", ps)
	center.add_child(wrap)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	wrap.add_child(hbox)

	# Ячейки зданий
	for b in BUILDINGS:
		var cell = _make_cell(b)
		hbox.add_child(cell)
		_cells[b] = cell

	# Разделитель перед кнопкой «БОЛЬШЕ»
	var sep = Panel.new()
	sep.custom_minimum_size = Vector2(1, 0)
	var ss = StyleBoxFlat.new(); ss.bg_color = C_STROKE
	sep.add_theme_stylebox_override("panel", ss)
	hbox.add_child(sep)

	# Кнопка «БОЛЬШЕ»
	var more_btn = Button.new()
	more_btn.text = "  ···  \nКАТАЛОГ"
	more_btn.custom_minimum_size = Vector2(68, 0)
	more_btn.add_theme_font_size_override("font_size", 12)
	more_btn.add_theme_color_override("font_color", C_SAND)
	more_btn.add_theme_color_override("font_hover_color", C_BONE)
	_style_cell_btn(more_btn, C_SAND, false, true)
	more_btn.pressed.connect(func(): catalog_requested.emit())
	hbox.add_child(more_btn)

func _make_cell(b: int) -> Control:
	var info  = _get_info(b)
	var outer = Control.new()
	outer.custom_minimum_size = Vector2(72, 0)
	outer.mouse_filter = Control.MOUSE_FILTER_PASS

	# Верхняя полоска (активна при выборе)
	var top_bar = ColorRect.new()
	top_bar.name = "TopBar"
	top_bar.color = Color(0, 0, 0, 0)
	top_bar.custom_minimum_size = Vector2(72, 2)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	outer.add_child(top_bar)

	# Кнопка-ячейка
	var btn = Button.new()
	btn.name = "Btn"
	btn.text = info.icon + "\n" + info.name + "\n" + info.cost
	btn.custom_minimum_size = Vector2(72, 72)
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_font_size_override("font_size", 11)
	_style_cell_btn(btn, info.color, false, true)
	btn.pressed.connect(func(): _select(b))
	outer.add_child(btn)

	return outer

func _style_cell_btn(btn: Button, color: Color, selected: bool, affordable: bool) -> void:
	var dim := 0.14 if not affordable else (0.45 if selected else 0.0)
	var s   = StyleBoxFlat.new()
	s.bg_color     = Color(color.r * dim, color.g * dim, color.b * dim,
						   1.0 if dim > 0.0 else 0.0)
	s.content_margin_top = 6.0; s.content_margin_bottom = 6.0
	s.content_margin_left = 2.0; s.content_margin_right = 2.0
	btn.add_theme_stylebox_override("normal", s)

	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 1.0)
	sh.content_margin_top = 6.0; sh.content_margin_bottom = 6.0
	sh.content_margin_left = 2.0; sh.content_margin_right = 2.0
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var fc := color if selected else (C_SAND if affordable else C_MUTED)
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", C_BONE)
	btn.disabled = not affordable

func _select(b: int) -> void:
	if not GameState.can_afford(b):
		return
	_selected = (-1 if _selected == b else b)
	GameState.selected_building_type = _selected
	EventBus.building_type_selected.emit(_selected)

func _on_type_selected(b: int) -> void:
	_selected = b
	_refresh_all()

func _refresh_all() -> void:
	for b in _cells:
		var outer: Control = _cells[b]
		var btn   = outer.get_node("Btn") as Button
		var bar   = outer.get_node("TopBar") as ColorRect
		var info  = _get_info(b)
		var sel   = (b == _selected)
		var afford = GameState.can_afford(b)
		_style_cell_btn(btn, info.color, sel, afford)
		bar.color = C_SAND if sel else Color(0, 0, 0, 0)

func _get_info(b: int) -> Dictionary:
	if BINFO.has(b):
		return BINFO[b]
	return {icon="?", name="?", cost="?", color=Color.WHITE}
