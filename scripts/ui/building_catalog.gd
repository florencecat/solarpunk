## Каталог построек — модальное окно с фильтрацией по категориям.
## Двухколоночная сетка. Выбор здания → закрытие + активация режима строительства.
extends FloatingWindow

const C_SAND    := Color(0.831, 0.710, 0.463)
const C_BONE    := Color(0.922, 0.863, 0.714)
const C_TEXT    := Color(0.847, 0.784, 0.620)
const C_MUTED   := Color(0.541, 0.478, 0.361)
const C_STROKE  := Color(0.227, 0.184, 0.125)
const C_BG      := Color(0.082, 0.067, 0.039)
const C_PANEL   := Color(0.110, 0.090, 0.063)
const C_GREEN   := Color(0.525, 0.663, 0.396)
const C_RUST    := Color(0.784, 0.333, 0.176)
const C_WATER   := Color(0.353, 0.643, 0.812)
const C_WARN    := Color(0.875, 0.635, 0.212)

const TAG_COLORS := {
	"ВОДА":     Color(0.353, 0.643, 0.812),
	"ЕДА":      Color(0.525, 0.663, 0.396),
	"ЭНЕРГИЯ":  Color(0.875, 0.635, 0.212),
	"ДОБЫЧА":   Color(0.663, 0.569, 0.384),
	"ОБЩЕСТВО": Color(0.922, 0.863, 0.714),
	"ОБОРОНА":  Color(0.784, 0.333, 0.176),
}

const ALL_BUILDINGS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

# Индексы соответствуют GameState.BUILDING_*
const BDATA: Dictionary = {
	0: {icon="💧", name="Насос",          tag="ВОДА",     cost="15П",           eff="+5–15 воды/д · до 5 раб.",       color=Color(0.15,0.48,0.98)},
	1: {icon="🔵", name="Очиститель",     tag="ВОДА",     cost="10П + 10М",     eff="+12 воды/раб · −энергия",        color=Color(0.10,0.82,0.62)},
	2: {icon="☁",  name="Конденсатор",   tag="ВОДА",     cost="20М + 1А",      eff="+2 воды/раб · −энергия",         color=Color(0.68,0.68,0.88)},
	3: {icon="🐪", name="Торговый пост", tag="ОБЩЕСТВО", cost="40М",           eff="Каравны и переговоры",           color=Color(0.98,0.54,0.10)},
	4: {icon="⛏",  name="Шахта",         tag="ДОБЫЧА",   cost="20П",           eff="1–4 мет + 0.5–2 пес/раб",       color=Color(0.72,0.50,0.22)},
	5: {icon="🌿", name="Ферма",          tag="ЕДА",      cost="25М",           eff="+3.5 еды/раб · −0.8 воды",      color=Color(0.28,0.75,0.22)},
	6: {icon="☀",  name="Солн. панель",  tag="ЭНЕРГИЯ",  cost="5П + 15М + 1А", eff="+8 энергии/раб · только днём",  color=Color(0.20,0.45,0.95)},
	7: {icon="🔋", name="Аккумулятор",   tag="ЭНЕРГИЯ",  cost="30М",           eff="+50 ёмкости хранения",          color=Color(0.20,0.80,0.40)},
	8: {icon="🧱", name="Стена",          tag="ОБОРОНА",  cost="30П + 10М",     eff="+3 к силе обороны",             color=Color(0.65,0.55,0.35)},
	9: {icon="🗼", name="Башня",          tag="ОБОРОНА",  cost="10П + 20М",     eff="+3 хода предупреждения",        color=Color(0.78,0.40,0.18)},
}

const TAGS := ["ВСЕ", "ВОДА", "ЕДА", "ЭНЕРГИЯ", "ДОБЫЧА", "ОБЩЕСТВО", "ОБОРОНА"]

var _current_tag:   String     = "ВСЕ"
var _selected_bld:  int        = -1
var _card_panels:   Dictionary = {}   # b_type → PanelContainer
var _card_styles:   Dictionary = {}   # b_type → StyleBoxFlat
var _grid:          GridContainer
var _status_lbl:    Label
var _confirm_btn:   Button
var _tab_btns:      Dictionary = {}   # tag → Button

# ─────────────────────────────────────────────────────────────────────────────

func _get_title() -> String:
	return "◇  КАТАЛОГ ПОСТРОЕК"

func _ready() -> void:
	custom_minimum_size = Vector2(700, 560)
	super._ready()
	EventBus.building_type_selected.connect(_on_ext_type_selected)
	EventBus.resources_changed.connect(func(_s, _sc, _d): _refresh_cards())

func _build_content(vbox: VBoxContainer) -> void:
	# ── Фильтр-вкладки ───────────────────────────────────────────────────────
	var tab_scroll = ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	tab_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size    = Vector2(0, 38)
	vbox.add_child(tab_scroll)

	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(tab_row)

	for tag in TAGS:
		var tb = Button.new()
		tb.text = tag
		tb.custom_minimum_size = Vector2(80, 30)
		tb.add_theme_font_size_override("font_size", 10)
		_style_tab(tb, tag == _current_tag)
		var t = tag
		tb.pressed.connect(func(): _set_tag(t))
		tab_row.add_child(tb)
		_tab_btns[tag] = tb

	vbox.add_child(_hsep())

	# ── Сетка карточек ───────────────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_rebuild_cards()

	# ── Подвал ───────────────────────────────────────────────────────────────
	vbox.add_child(_hsep())

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vbox.add_child(footer)

	_status_lbl = Label.new()
	_status_lbl.text = "Выбери здание для строительства"
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", C_MUTED)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status_lbl)

	var cancel_btn = Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(90, 34)
	cancel_btn.pressed.connect(_on_close)
	footer.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Выбрать тайл  ▶"
	_confirm_btn.custom_minimum_size = Vector2(140, 34)
	_confirm_btn.add_theme_color_override("font_color", Color(0.07, 0.05, 0.02))
	var cs = StyleBoxFlat.new()
	cs.bg_color = C_SAND
	cs.content_margin_left  = 14.0; cs.content_margin_right  = 14.0
	cs.content_margin_top   =  6.0; cs.content_margin_bottom =  6.0
	_confirm_btn.add_theme_stylebox_override("normal", cs)
	var csh = cs.duplicate(); (csh as StyleBoxFlat).bg_color = C_BONE
	_confirm_btn.add_theme_stylebox_override("hover", csh)
	_confirm_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	footer.add_child(_confirm_btn)

# ─────────────────────────────────────────────────────────────────────────────

func _rebuild_cards() -> void:
	for ch in _grid.get_children():
		ch.queue_free()
	_card_panels.clear()
	_card_styles.clear()

	for b in ALL_BUILDINGS:
		if not BDATA.has(b):
			continue
		var info = BDATA[b]
		if _current_tag != "ВСЕ" and info.tag != _current_tag:
			continue
		var card = _make_card(b, info)
		_grid.add_child(card)

	_refresh_cards()

func _make_card(b: int, info: Dictionary) -> Control:
	# Используем PanelContainer + один HBoxContainer (gui_input для кликов)
	var outer = PanelContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_STOP

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(C_BG.r, C_BG.g, C_BG.b, 0.6)
	for prop in ["border_width_left","border_width_right",
				 "border_width_top","border_width_bottom"]:
		ps.set(prop, 1)
	ps.border_color = C_STROKE
	ps.content_margin_left  = 8; ps.content_margin_right  = 10
	ps.content_margin_top   = 8; ps.content_margin_bottom = 8
	outer.add_theme_stylebox_override("panel", ps)
	_card_panels[b] = outer
	_card_styles[b] = ps

	var btype = b
	outer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			_select_card(btype)
	)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	outer.add_child(hbox)

	# Иконка
	var icon_panel = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(42, 42)
	var is2 = StyleBoxFlat.new()
	is2.bg_color = Color(info.color.r*0.15, info.color.g*0.15, info.color.b*0.15)
	for prop in ["border_width_left","border_width_right",
				 "border_width_top","border_width_bottom"]:
		is2.set(prop, 1)
	is2.border_color = Color(info.color.r*0.5, info.color.g*0.5, info.color.b*0.5)
	is2.content_margin_left=4;is2.content_margin_right=4
	is2.content_margin_top=2;is2.content_margin_bottom=2
	icon_panel.add_theme_stylebox_override("panel", is2)

	var icon_lbl = Label.new()
	icon_lbl.text = info.icon
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon_lbl)
	hbox.add_child(icon_panel)

	# Текст
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(tv)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	tv.add_child(name_row)

	var name_lbl = Label.new()
	name_lbl.text = info.name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", C_BONE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var tag_lbl = Label.new()
	var tc = TAG_COLORS.get(info.tag, C_MUTED)
	tag_lbl.text = info.tag
	tag_lbl.add_theme_font_size_override("font_size", 8)
	tag_lbl.add_theme_color_override("font_color", tc)
	name_row.add_child(tag_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = info.cost
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", C_SAND)
	tv.add_child(cost_lbl)

	var eff_lbl = Label.new()
	eff_lbl.text = info.eff
	eff_lbl.add_theme_font_size_override("font_size", 10)
	eff_lbl.add_theme_color_override("font_color", C_MUTED)
	eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(eff_lbl)

	return outer

# ─── Выбор и фильтр ──────────────────────────────────────────────────────────

func _select_card(b: int) -> void:
	if not GameState.can_afford(b):
		return
	_selected_bld = b
	GameState.selected_building_type = b
	_refresh_cards()
	var info = BDATA.get(b, {})
	_status_lbl.text = "Выбрано: %s" % info.get("name", "?")
	_status_lbl.add_theme_color_override("font_color", C_SAND)
	_confirm_btn.disabled = false

func _on_confirm() -> void:
	EventBus.building_type_selected.emit(_selected_bld)
	visible = false

func _set_tag(tag: String) -> void:
	_current_tag = tag
	for t in _tab_btns:
		_style_tab(_tab_btns[t], t == tag)
	_rebuild_cards()

func _on_ext_type_selected(b: int) -> void:
	_selected_bld = b
	_refresh_cards()

func _refresh_cards() -> void:
	for b in _card_panels:
		var panel: PanelContainer = _card_panels[b]
		if not is_instance_valid(panel):
			continue
		var sel    = (b == _selected_bld)
		var afford = GameState.can_afford(b)
		var ps: StyleBoxFlat = _card_styles[b]
		ps.bg_color = Color(C_BG.r, C_BG.g, C_BG.b, 0.85 if sel else 0.6)
		var bc := C_SAND if sel else C_STROKE
		if not afford:
			bc = Color(0.35, 0.35, 0.35)
		ps.border_color = bc
		# Мышь: заблокировать клик если не хватает ресурсов
		panel.mouse_default_cursor_shape = \
			Control.CURSOR_FORBIDDEN if not afford else Control.CURSOR_POINTING_HAND

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _style_tab(btn: Button, active: bool) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(C_SAND.r * 0.18, C_SAND.g * 0.18, C_SAND.b * 0.18, 1.0) \
				 if active else Color(0, 0, 0, 0)
	for prop in ["border_width_bottom"]:
		s.set(prop, 2 if active else 0)
	s.border_color = C_SAND
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", C_SAND if active else C_MUTED)
	btn.add_theme_color_override("font_hover_color", C_BONE)

	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(C_SAND.r * 0.12, C_SAND.g * 0.12, C_SAND.b * 0.12, 1.0)
	btn.add_theme_stylebox_override("hover", sh)

func _hsep() -> HSeparator:
	var sep = HSeparator.new()
	var ss  = StyleBoxFlat.new(); ss.bg_color = C_STROKE
	sep.add_theme_stylebox_override("separator", ss)
	return sep
