extends Control

var _turn_lbl:       Label
var _auto_btn:       Button
var _water_lbl:      Label
var _water_bar:      ProgressBar
var _reserves_lbl:   Label
var _pop_lbl:        Label
var _thirst_bar:     ProgressBar
var _discontent_bar: ProgressBar
var _hunger_bar:     ProgressBar
var _res_lbl:        Label
var _food_lbl:       Label
var _energy_lbl:     Label
var _energy_bar:     ProgressBar
var _workers_lbl:    Label
var _turn_score_lbl: Label
var _act_lbl:        Label
var _night_lbl:      Label
var _riot_panel:     Control
var _storm_lbl:      Label
var _raider_lbl:     Label

func _ready() -> void:
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
	var top = HBoxContainer.new()
	top.position = Vector2(8.0, 8.0)
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	# ── Панель хода ──────────────────────────────────────────────────────────
	var tp = _panel(Color(0.12, 0.09, 0.05, 0.94))
	top.add_child(tp)
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tp.add_child(tv)

	_turn_lbl = _lbl("День 0", 18, Color(0.95, 0.76, 0.32))
	tv.add_child(_turn_lbl)
	_turn_score_lbl = _lbl("Очки: —", 11, Color(0.70, 0.70, 0.70))
	tv.add_child(_turn_score_lbl)
	_act_lbl = _lbl("Акт I: Основание", 11, Color(0.60, 0.90, 0.70))
	tv.add_child(_act_lbl)

	# Кнопки открытия окон
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	tv.add_child(btn_row)
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
		b.custom_minimum_size = Vector2(34, 28)
		var pname = pair[1]
		b.pressed.connect(func(): _toggle_panel(pname))
		btn_row.add_child(b)

	_auto_btn = Button.new()
	_auto_btn.text = "▶  Авто: ВЫКЛ"
	_auto_btn.pressed.connect(_toggle_auto)
	tv.add_child(_auto_btn)
	var next_btn = Button.new()
	next_btn.text = "►  Следующий день"
	next_btn.pressed.connect(_next_turn)
	tv.add_child(next_btn)

	# ── Панель воды ──────────────────────────────────────────────────────────
	var wp = _panel(Color(0.06, 0.12, 0.22, 0.94))
	top.add_child(wp)
	var wv = VBoxContainer.new()
	wv.add_theme_constant_override("separation", 4)
	wp.add_child(wv)
	wv.add_child(_lbl("ВОДА", 12, Color(0.46, 0.84, 1.0)))
	_water_lbl = _lbl("—", 15, Color.WHITE)
	wv.add_child(_water_lbl)
	_water_bar = _bar(Color(0.15, 0.55, 0.95), 155.0)
	_water_bar.max_value = 500.0
	wv.add_child(_water_bar)
	_reserves_lbl = _lbl("Подземн.: —", 11, Color(0.55, 0.75, 0.95))
	wv.add_child(_reserves_lbl)

	# ── Панель населения ─────────────────────────────────────────────────────
	var pp = _panel(Color(0.18, 0.10, 0.05, 0.94))
	top.add_child(pp)
	var pv = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	pp.add_child(pv)
	pv.add_child(_lbl("НАСЕЛЕНИЕ", 12, Color(0.95, 0.65, 0.30)))
	_pop_lbl = _lbl("—", 15, Color.WHITE)
	pv.add_child(_pop_lbl)
	_workers_lbl = _lbl("Раб.: —", 11, Color(0.60, 0.90, 0.60))
	pv.add_child(_workers_lbl)

	# ── Панель настроения ────────────────────────────────────────────────────
	var mp = _panel(Color(0.18, 0.06, 0.06, 0.94))
	top.add_child(mp)
	var mv = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 5)
	mp.add_child(mv)
	mv.add_child(_lbl("САМОЧУВСТВИЕ", 11, Color(0.85, 0.55, 0.55)))
	var th_row = HBoxContainer.new()
	mv.add_child(th_row)
	th_row.add_child(_lbl("Жажда  ", 11))
	_thirst_bar = _bar(Color(0.95, 0.52, 0.10), 100.0)
	th_row.add_child(_thirst_bar)
	var hu_row = HBoxContainer.new()
	mv.add_child(hu_row)
	hu_row.add_child(_lbl("Голод  ", 11))
	_hunger_bar = _bar(Color(0.88, 0.70, 0.15), 100.0)
	hu_row.add_child(_hunger_bar)
	var dc_row = HBoxContainer.new()
	mv.add_child(dc_row)
	dc_row.add_child(_lbl("Недов. ", 11))
	_discontent_bar = _bar(Color(0.95, 0.20, 0.20), 100.0)
	dc_row.add_child(_discontent_bar)

	# ── Панель ресурсов ──────────────────────────────────────────────────────
	var rp = _panel(Color(0.12, 0.10, 0.06, 0.94))
	top.add_child(rp)
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rp.add_child(rv)
	rv.add_child(_lbl("РЕСУРСЫ", 12, Color(0.95, 0.78, 0.40)))
	_res_lbl = _lbl("—", 13, Color.WHITE)
	rv.add_child(_res_lbl)

	# ── Панель еды и энергии ─────────────────────────────────────────────────
	var fp = _panel(Color(0.08, 0.14, 0.08, 0.94))
	top.add_child(fp)
	var fv = VBoxContainer.new()
	fv.add_theme_constant_override("separation", 4)
	fp.add_child(fv)
	fv.add_child(_lbl("ЕДА / ЭНЕРГИЯ", 11, Color(0.55, 0.90, 0.42)))
	_food_lbl = _lbl("Еда: —", 12, Color.WHITE)
	fv.add_child(_food_lbl)
	fv.add_child(HSeparator.new())
	_energy_lbl = _lbl("Энергия: —", 12, Color.WHITE)
	fv.add_child(_energy_lbl)
	_energy_bar = _bar(Color(0.25, 0.65, 1.0), 110.0)
	_energy_bar.max_value = 1.0
	fv.add_child(_energy_bar)
	_night_lbl = _lbl("🌙 Ночь", 11, Color(0.55, 0.65, 1.0))
	_night_lbl.visible = false
	fv.add_child(_night_lbl)

	# ── Бунт ─────────────────────────────────────────────────────────────────
	_riot_panel          = _panel(Color(0.72, 0.02, 0.02, 0.95))
	_riot_panel.position = Vector2(8.0, 130.0)
	_riot_panel.visible  = false
	add_child(_riot_panel)
	var rv2 = VBoxContainer.new()
	_riot_panel.add_child(rv2)
	rv2.add_child(_lbl("БУНТ!", 20, Color(1.0, 0.35, 0.35)))
	rv2.add_child(_lbl("Население взбунтовалось!", 13, Color.WHITE))

	# ── Буря ─────────────────────────────────────────────────────────────────
	_storm_lbl          = _lbl("⛈  Песчаная буря!", 14, Color(0.95, 0.82, 0.28))
	_storm_lbl.position = Vector2(8.0, 200.0)
	_storm_lbl.visible  = false
	add_child(_storm_lbl)

	# ── Угроза рейдеров ───────────────────────────────────────────────────────
	_raider_lbl          = _lbl("⚔  Рейдеры: ? ходов", 14, Color(0.95, 0.40, 0.25))
	_raider_lbl.position = Vector2(8.0, 228.0)
	_raider_lbl.visible  = false
	add_child(_raider_lbl)

# ─── Сигналы ─────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.water_changed.connect(_on_water_changed)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.happiness_changed.connect(_on_mood_changed)
	EventBus.riot_started.connect(func(): _riot_panel.visible = true)
	EventBus.riot_ended.connect(func():   _riot_panel.visible = false)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.workers_changed.connect(func(_c, _n): _refresh_workers())
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.food_changed.connect(_on_food_changed)
	EventBus.hunger_changed.connect(func(v): _hunger_bar.value = v)
	EventBus.energy_changed.connect(_on_energy_changed)
	EventBus.night_changed.connect(func(n): _night_lbl.visible = n)
	EventBus.raider_threat_changed.connect(_on_raider_threat)
	EventBus.specialists_changed.connect(func(_e, _g): _refresh_workers())

func _on_act_changed(act: int) -> void:
	var names  = ["", "Акт I: Основание", "Акт II: Расширение", "Акт III: Финал"]
	var colors = [Color.WHITE, Color(0.60, 0.90, 0.70), Color(0.55, 0.80, 1.0), Color(0.90, 0.65, 1.0)]
	if act < names.size():
		_act_lbl.text = names[act]
		_act_lbl.add_theme_color_override("font_color", colors[act])

func _on_turn_ended(turn: int) -> void:
	_turn_lbl.text       = "День %d" % turn
	_storm_lbl.visible   = GameState.sandstorm_active
	_turn_score_lbl.text = "Очки: %d" % GameState.get_score()
	_reserves_lbl.text   = "Подземн.: %.0f ед." % GameState.get_total_water_reserves()

func _on_water_changed(amount: float, net: float) -> void:
	var sign = "+" if net >= 0.0 else ""
	_water_lbl.text  = "%.0f  (%s%.0f/д)" % [amount, sign, net]
	_water_bar.value = amount

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
	_food_lbl.text = "Еда: %.0f  (%s%.1f/д)" % [amount, sign, net]

func _on_energy_changed(stored: float, _net: float, ratio: float) -> void:
	var cap: float = GameState.energy_capacity
	_energy_bar.value = ratio
	if cap > 0.0:
		_energy_lbl.text = "Энергия: %.0f/%.0f  (%d%%)" % [stored, cap, int(ratio * 100.0)]
	else:
		_energy_lbl.text = "Энергия: %.0f  (%d%%)" % [stored, int(ratio * 100.0)]

func _on_raider_threat(turns: int) -> void:
	if turns <= 0:
		_raider_lbl.visible = false
	else:
		_raider_lbl.text    = "⚔  Рейдеры через: %d" % turns
		_raider_lbl.visible = true

func _on_resources_changed(sand: float, scrap: float, diamonds: float) -> void:
	_res_lbl.text = "Пес: %.0f   Мет: %.0f   Алм: %.0f" % [sand, scrap, diamonds]
	_refresh_workers()

# ─── Обработчики кнопок ──────────────────────────────────────────────────────

func _toggle_panel(panel_name: String) -> void:
	var panel = get_tree().get_root().find_child(panel_name, true, false)
	if panel:
		panel.visible = not panel.visible

func _toggle_auto() -> void:
	GameState.auto_turn = not GameState.auto_turn
	_auto_btn.text = ("▶  Авто: ВКЛ" if GameState.auto_turn else "▶  Авто: ВЫКЛ")

func _next_turn() -> void:
	var tm = get_tree().get_first_node_in_group("turn_manager")
	if tm:
		tm.advance_turn()

# ─── Вспомогательные функции ─────────────────────────────────────────────────

func _panel(color: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.content_margin_left   = 10.0; s.content_margin_right  = 10.0
	s.content_margin_top    = 7.0;  s.content_margin_bottom = 7.0
	p.add_theme_stylebox_override("panel", s)
	return p

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _bar(fill_color: Color, width: float = 120.0) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 11.0)
	b.max_value           = 100.0
	b.value               = 0.0
	b.show_percentage     = false
	var fs = StyleBoxFlat.new(); fs.bg_color = fill_color
	b.add_theme_stylebox_override("fill", fs)
	var bs = StyleBoxFlat.new(); bs.bg_color = Color(0.14, 0.14, 0.14)
	b.add_theme_stylebox_override("background", bs)
	return b
