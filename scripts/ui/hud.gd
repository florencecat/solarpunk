## Верхняя панель HUD — полная ширина экрана, дизайн в стиле TopHUD.
## Ряд 1 (~58px): ход + ресурсы + угрозы + кнопки панелей + «Следующий день».
## Ряд 2 (~28px): самочувствие (жажда/голод/недов.) + рабочие + ночь/буря.
extends Control

# ─── Цвета (SP palette) ──────────────────────────────────────────────────────
const C_INK    := Color(0.055, 0.039, 0.024)
const C_PANEL  := Color(0.110, 0.090, 0.063)
const C_STROKE := Color(0.227, 0.184, 0.125)
const C_SAND   := Color(0.831, 0.710, 0.463)
const C_BONE   := Color(0.922, 0.863, 0.714)
const C_TEXT   := Color(0.847, 0.784, 0.620)
const C_MUTED  := Color(0.541, 0.478, 0.361)
const C_WATER  := Color(0.353, 0.643, 0.812)
const C_GREEN  := Color(0.525, 0.663, 0.396)
const C_RUST   := Color(0.784, 0.333, 0.176)
const C_WARN   := Color(0.875, 0.635, 0.212)

# ─── Виджеты ─────────────────────────────────────────────────────────────────
var _turn_lbl:        Label
var _act_lbl:         Label
var _turn_score_lbl:  Label
var _water_lbl:       Label
var _reserves_lbl:    Label
var _food_lbl:        Label
var _energy_lbl:      Label
var _res_lbl:         Label
var _pop_lbl:         Label
var _workers_lbl:     Label
var _thirst_bar:      ProgressBar
var _hunger_bar:      ProgressBar
var _discontent_bar:  ProgressBar
var _auto_btn:        Button
var _raider_lbl:      Label
var _night_row_lbl:   Label
var _storm_lbl:       Label
var _riot_lbl:        Label

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 94)
	_build_ui()
	_connect_signals()
	_on_turn_ended(0)
	_on_water_changed(GameState.water, 0.0)
	_on_population_changed(GameState.population)
	_on_mood_changed(GameState.happiness, GameState.thirst, GameState.discontent)
	_on_resources_changed(GameState.sand, GameState.scrap, GameState.diamonds)
	_on_food_changed(GameState.food, 0.0)
	_on_energy_changed(0.0, 0.0, 1.0)

# ─── Построение UI ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rs = StyleBoxFlat.new()
	rs.bg_color     = Color(C_INK.r, C_INK.g, C_INK.b, 0.96)
	rs.border_color = C_STROKE
	rs.set("border_width_bottom", 1)
	root.add_theme_stylebox_override("panel", rs)
	add_child(root)

	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	root.add_child(rows)

	# ── Ряд 1 ────────────────────────────────────────────────────────────────
	var row1 = _hbox(0)
	row1.custom_minimum_size = Vector2(0, 58)
	rows.add_child(row1)
	_build_turn_section(row1)
	_vsep(row1)
	_build_resource_section(row1)
	_vsep(row1)
	_build_controls_section(row1)

	# ── Ряд 2 (самочувствие) ─────────────────────────────────────────────────
	var row2_panel = PanelContainer.new()
	row2_panel.custom_minimum_size = Vector2(0, 28)
	var r2s = StyleBoxFlat.new()
	r2s.bg_color = Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.75)
	r2s.border_color = C_STROKE
	r2s.set("border_width_top", 1)
	r2s.content_margin_left  = 12; r2s.content_margin_right  = 12
	r2s.content_margin_top   =  4; r2s.content_margin_bottom =  4
	row2_panel.add_theme_stylebox_override("panel", r2s)
	rows.add_child(row2_panel)
	var row2 = _hbox(14)
	row2_panel.add_child(row2)
	_build_mood_row(row2)

# ── Секция хода ──────────────────────────────────────────────────────────────

func _build_turn_section(row: HBoxContainer) -> void:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(176, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pad_child(row, v, 14, 8)

	_turn_lbl = _lbl("ДЕНЬ 0", 22, C_BONE)
	v.add_child(_turn_lbl)

	_act_lbl = _lbl("Акт I: Основание", 10, C_GREEN)
	v.add_child(_act_lbl)

	_turn_score_lbl = _lbl("Очки: —", 10, C_MUTED)
	v.add_child(_turn_score_lbl)

# ── Секция ресурсов ──────────────────────────────────────────────────────────

func _build_resource_section(row: HBoxContainer) -> void:
	var res_hbox = HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 0)
	res_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_hbox.size_flags_vertical   = Control.SIZE_FILL
	row.add_child(res_hbox)

	# Вода
	var wv = _res_cell(res_hbox)
	wv.add_child(_lbl("ВОДА", 9, C_WATER))
	_water_lbl    = _lbl("— (+0/д)", 15, C_BONE);  wv.add_child(_water_lbl)
	_reserves_lbl = _lbl("Подз.: —", 9,
		Color(C_WATER.r, C_WATER.g, C_WATER.b, 0.7))
	wv.add_child(_reserves_lbl)

	# Еда
	var fv = _res_cell(res_hbox)
	fv.add_child(_lbl("ЕДА", 9, C_GREEN))
	_food_lbl = _lbl("— (+0/д)", 15, C_BONE); fv.add_child(_food_lbl)

	# Энергия
	var ev = _res_cell(res_hbox)
	ev.add_child(_lbl("ЭНЕРГИЯ", 9, C_WARN))
	_energy_lbl = _lbl("—", 15, C_BONE); ev.add_child(_energy_lbl)

	# Ресурсы
	var rv = _res_cell(res_hbox)
	rv.add_child(_lbl("РЕСУРСЫ", 9, C_SAND))
	_res_lbl = _lbl("—", 12, C_BONE)
	_res_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rv.add_child(_res_lbl)

	# Население
	var pv = _res_cell(res_hbox)
	pv.add_child(_lbl("НАС.", 9, C_RUST))
	_pop_lbl     = _lbl("—", 15, C_BONE);  pv.add_child(_pop_lbl)
	_workers_lbl = _lbl("Раб.: —", 9,
		Color(C_GREEN.r, C_GREEN.g, C_GREEN.b, 0.8))
	pv.add_child(_workers_lbl)

# ── Секция управления ─────────────────────────────────────────────────────────

func _build_controls_section(row: HBoxContainer) -> void:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pad_child(row, v, 8, 10)

	_raider_lbl = _lbl("", 10, C_RUST)
	_raider_lbl.visible = false
	v.add_child(_raider_lbl)

	# Строка иконок-кнопок + авто
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 3)
	v.add_child(btn_row)

	for pair in [
		["🏗", "BuildingPanel"],
		["📋", "EventLog"],
		["⚖", "LawsPanel"],
		["🔬", "ResearchPanel"],
		["🏛", "MegaprojectPanel"],
		["👥", "SpecialistsPanel"],
	]:
		var b = Button.new()
		b.text = pair[0]
		b.tooltip_text = pair[1]
		b.custom_minimum_size = Vector2(30, 26)
		b.add_theme_font_size_override("font_size", 13)
		var pname = pair[1]
		b.pressed.connect(func(): _toggle_panel(pname))
		_style_icon_btn(b)
		btn_row.add_child(b)

	_auto_btn = Button.new()
	_auto_btn.text = "▶ АВТО: ВЫКЛ"
	_auto_btn.custom_minimum_size = Vector2(100, 26)
	_auto_btn.add_theme_font_size_override("font_size", 10)
	_auto_btn.pressed.connect(_toggle_auto)
	_style_icon_btn(_auto_btn)
	btn_row.add_child(_auto_btn)

	# Кнопка следующего хода
	var next_btn = Button.new()
	next_btn.text = "▶  СЛЕДУЮЩИЙ ДЕНЬ"
	next_btn.custom_minimum_size = Vector2(170, 30)
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.add_theme_color_override("font_color",       C_INK)
	next_btn.add_theme_color_override("font_hover_color", C_INK)
	var ns = StyleBoxFlat.new()
	ns.bg_color = C_SAND
	ns.content_margin_left  = 12; ns.content_margin_right  = 12
	ns.content_margin_top   =  5; ns.content_margin_bottom =  5
	next_btn.add_theme_stylebox_override("normal",  ns)
	var nsh = ns.duplicate(); (nsh as StyleBoxFlat).bg_color = C_BONE
	next_btn.add_theme_stylebox_override("hover",   nsh)
	next_btn.add_theme_stylebox_override("pressed", nsh)
	next_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	next_btn.pressed.connect(_next_turn)
	v.add_child(next_btn)

# ── Ряд самочувствия ─────────────────────────────────────────────────────────

func _build_mood_row(row: HBoxContainer) -> void:
	row.add_child(_lbl("САМОЧУВСТВИЕ:", 9, C_MUTED))

	row.add_child(_lbl(" Жажда", 9, C_MUTED))
	_thirst_bar = _bar(C_WARN, 80)
	row.add_child(_thirst_bar)

	row.add_child(_lbl("  Голод", 9, C_MUTED))
	_hunger_bar = _bar(C_GREEN, 80)
	row.add_child(_hunger_bar)

	row.add_child(_lbl("  Недов.", 9, C_MUTED))
	_discontent_bar = _bar(C_RUST, 80)
	row.add_child(_discontent_bar)

	var flex = Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flex)

	_night_row_lbl = _lbl("🌙 Ночь", 10, Color(0.55, 0.65, 1.0))
	_night_row_lbl.visible = false
	row.add_child(_night_row_lbl)

	_storm_lbl = _lbl("  ⛈ Буря!", 10, C_WARN)
	_storm_lbl.visible = false
	row.add_child(_storm_lbl)

	_riot_lbl = _lbl("  🔴 БУНТ!", 10, C_RUST)
	_riot_lbl.visible = false
	row.add_child(_riot_lbl)

# ─── Сигналы ─────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.water_changed.connect(_on_water_changed)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.happiness_changed.connect(_on_mood_changed)
	EventBus.riot_started.connect(func(): _riot_lbl.visible = true)
	EventBus.riot_ended.connect(func():   _riot_lbl.visible = false)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.workers_changed.connect(func(_c, _n): _refresh_workers())
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.food_changed.connect(_on_food_changed)
	EventBus.hunger_changed.connect(func(v): _hunger_bar.value = v)
	EventBus.energy_changed.connect(_on_energy_changed)
	EventBus.night_changed.connect(func(n): _night_row_lbl.visible = n)
	EventBus.raider_threat_changed.connect(_on_raider_threat)
	EventBus.specialists_changed.connect(func(_e, _g): _refresh_workers())

func _on_act_changed(act: int) -> void:
	var names  = ["", "Акт I: Основание", "Акт II: Расширение", "Акт III: Финал"]
	var colors = [C_TEXT, C_GREEN,
				  Color(0.55, 0.80, 1.0), Color(0.90, 0.65, 1.0)]
	if act < names.size():
		_act_lbl.text = names[act]
		_act_lbl.add_theme_color_override("font_color", colors[act])

func _on_turn_ended(turn: int) -> void:
	_turn_lbl.text       = "ДЕНЬ %d" % turn
	_storm_lbl.visible   = GameState.sandstorm_active
	_turn_score_lbl.text = "Очки: %d" % GameState.get_score()
	_reserves_lbl.text   = "Подз.: %.0f ед." % GameState.get_total_water_reserves()

func _on_water_changed(amount: float, net: float) -> void:
	var sign = "+" if net >= 0.0 else ""
	_water_lbl.text = "%.0f  (%s%.0f/д)" % [amount, sign, net]

func _on_population_changed(count: int) -> void:
	_pop_lbl.text = "%d чел." % count
	_refresh_workers()

func _refresh_workers() -> void:
	var avail = GameState.get_available_workers()
	var total = GameState.get_assigned_workers()
	_workers_lbl.text = "Раб.: %d / %d св." % [total, avail]

func _on_mood_changed(_hap: float, thirst: float, discontent: float) -> void:
	_thirst_bar.value     = thirst
	_discontent_bar.value = discontent

func _on_food_changed(amount: float, net: float) -> void:
	var sign = "+" if net >= 0.0 else ""
	_food_lbl.text = "%.0f  (%s%.1f/д)" % [amount, sign, net]

func _on_energy_changed(stored: float, _net: float, ratio: float) -> void:
	var cap: float = GameState.energy_capacity
	if cap > 0.0:
		_energy_lbl.text = "%.0f/%.0f  (%d%%)" % [stored, cap, int(ratio * 100.0)]
	else:
		_energy_lbl.text = "%.0f  (%d%%)" % [stored, int(ratio * 100.0)]

func _on_raider_threat(turns: int) -> void:
	if turns <= 0:
		_raider_lbl.visible = false
	else:
		_raider_lbl.text    = "⚔  РЕЙДЕРЫ ЧЕРЕЗ %d Д." % turns
		_raider_lbl.visible = true

func _on_resources_changed(sand: float, scrap: float, diamonds: float) -> void:
	_res_lbl.text = "Пес: %.0f  Мет: %.0f  Алм: %.0f" % [sand, scrap, diamonds]
	_refresh_workers()

# ─── Кнопки ──────────────────────────────────────────────────────────────────

func _toggle_panel(panel_name: String) -> void:
	var panel = get_tree().get_root().find_child(panel_name, true, false)
	if panel:
		panel.visible = not panel.visible

func _toggle_auto() -> void:
	GameState.auto_turn = not GameState.auto_turn
	_auto_btn.text = ("▶ АВТО: ВКЛ" if GameState.auto_turn else "▶ АВТО: ВЫКЛ")

func _next_turn() -> void:
	var tm = get_tree().get_first_node_in_group("turn_manager")
	if tm:
		tm.advance_turn()

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _res_cell(parent: HBoxContainer) -> VBoxContainer:
	var cell = PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical   = Control.SIZE_FILL
	var cs = StyleBoxFlat.new()
	cs.bg_color     = Color(0, 0, 0, 0)
	cs.border_color = C_STROKE
	cs.set("border_width_right", 1)
	cs.content_margin_left  = 12; cs.content_margin_right  = 10
	cs.content_margin_top   =  5; cs.content_margin_bottom =  5
	cell.add_theme_stylebox_override("panel", cs)
	parent.add_child(cell)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(v)
	return v

func _pad_child(parent: HBoxContainer, child: Control,
				ml: float, mr: float) -> void:
	var wrap = PanelContainer.new()
	var ws   = StyleBoxFlat.new()
	ws.bg_color             = Color(0, 0, 0, 0)
	ws.content_margin_left  = ml; ws.content_margin_right  = mr
	ws.content_margin_top   = 0;  ws.content_margin_bottom = 0
	wrap.add_theme_stylebox_override("panel", ws)
	wrap.size_flags_vertical = Control.SIZE_FILL
	parent.add_child(wrap)
	wrap.add_child(child)

func _vsep(parent: HBoxContainer) -> void:
	var sep = Panel.new()
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_FILL
	var ss = StyleBoxFlat.new(); ss.bg_color = C_STROKE
	sep.add_theme_stylebox_override("panel", ss)
	parent.add_child(sep)

func _hbox(separation: int) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.size_flags_vertical   = Control.SIZE_FILL
	return h

func _style_icon_btn(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", s)
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(C_SAND.r*0.12, C_SAND.g*0.12, C_SAND.b*0.12, 1.0)
	for p in ["border_width_left","border_width_right",
			  "border_width_top","border_width_bottom"]:
		sh.set(p, 1)
	sh.border_color = C_STROKE
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       C_MUTED)
	btn.add_theme_color_override("font_hover_color", C_SAND)

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _bar(fill_color: Color, width: float = 80.0) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 8.0)
	b.max_value           = 100.0
	b.value               = 0.0
	b.show_percentage     = false
	var fs = StyleBoxFlat.new(); fs.bg_color = fill_color
	b.add_theme_stylebox_override("fill", fs)
	var bs = StyleBoxFlat.new(); bs.bg_color = Color(0.08, 0.08, 0.08)
	b.add_theme_stylebox_override("background", bs)
	return b
