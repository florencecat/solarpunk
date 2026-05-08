## Панель управления специалистами (инженеры и охрана).
extends FloatingWindow

# Стоимость обучения
const TRAIN_ENGINEER_SCRAP: int = 2
const TRAIN_ENGINEER_FOOD:  int = 1
const TRAIN_GUARD_SCRAP:    int = 3

var _eng_lbl:         Label
var _guard_lbl:       Label
var _avail_lbl:       Label
var _train_eng_btn:   Button
var _train_guard_btn: Button
var _dismiss_eng_btn: Button
var _dismiss_guard_btn: Button

func _get_title() -> String:
	return "👥  Специалисты"

func _ready() -> void:
	super._ready()
	EventBus.specialists_changed.connect(func(_e, _g): _refresh())
	EventBus.resources_changed.connect(func(_s, _sc, _d): _refresh())
	EventBus.population_changed.connect(func(_p): _refresh())
	EventBus.workers_changed.connect(func(_c, _n): _refresh())
	_refresh()

func _build_content(vbox: VBoxContainer) -> void:
	# ── Статус ────────────────────────────────────────────────────────────────
	var info_box = PanelContainer.new()
	var ib_s     = StyleBoxFlat.new()
	ib_s.bg_color = Color(0.10, 0.12, 0.16, 0.90)
	ib_s.corner_radius_top_left = 5; ib_s.corner_radius_top_right = 5
	ib_s.corner_radius_bottom_left = 5; ib_s.corner_radius_bottom_right = 5
	ib_s.content_margin_left = 8.0; ib_s.content_margin_right = 8.0
	ib_s.content_margin_top  = 6.0; ib_s.content_margin_bottom = 6.0
	info_box.add_theme_stylebox_override("panel", ib_s)
	vbox.add_child(info_box)
	var iv = VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	info_box.add_child(iv)
	_avail_lbl = _lbl("Свободных: —", 11, Color(0.70, 0.90, 0.70))
	iv.add_child(_avail_lbl)
	_eng_lbl   = _lbl("Инженеры: 0", 12, Color(0.55, 0.85, 1.0))
	iv.add_child(_eng_lbl)
	_guard_lbl = _lbl("Охрана: 0", 12, Color(1.0, 0.65, 0.30))
	iv.add_child(_guard_lbl)

	vbox.add_child(HSeparator.new())

	# ── Инженеры ──────────────────────────────────────────────────────────────
	vbox.add_child(_lbl("⚙  Инженеры", 12, Color(0.55, 0.85, 1.0)))
	var eng_desc = _lbl(
		"Каждый инженер даёт +5% к производительности\nшахт, очистителей и ферм.",
		10, Color(0.55, 0.55, 0.60))
	eng_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(eng_desc)
	vbox.add_child(_lbl("Стоимость: %d мет + %d еды" % [TRAIN_ENGINEER_SCRAP, TRAIN_ENGINEER_FOOD],
		10, Color(0.80, 0.75, 0.40)))

	var eng_row = HBoxContainer.new()
	eng_row.add_theme_constant_override("separation", 6)
	vbox.add_child(eng_row)
	_train_eng_btn        = Button.new()
	_train_eng_btn.text   = "+ Обучить"
	_train_eng_btn.custom_minimum_size = Vector2(100, 28)
	_train_eng_btn.pressed.connect(_on_train_engineer)
	eng_row.add_child(_train_eng_btn)
	_dismiss_eng_btn        = Button.new()
	_dismiss_eng_btn.text   = "− Уволить"
	_dismiss_eng_btn.custom_minimum_size = Vector2(100, 28)
	_dismiss_eng_btn.pressed.connect(_on_dismiss_engineer)
	eng_row.add_child(_dismiss_eng_btn)

	vbox.add_child(HSeparator.new())

	# ── Охрана ────────────────────────────────────────────────────────────────
	vbox.add_child(_lbl("🛡  Охрана", 12, Color(1.0, 0.65, 0.30)))
	var guard_desc = _lbl(
		"Каждый охранник даёт +3 силы обороны против\nрейдеров. Потребляет +0.3 воды/ход.",
		10, Color(0.55, 0.55, 0.60))
	guard_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(guard_desc)
	vbox.add_child(_lbl("Стоимость: %d мет" % TRAIN_GUARD_SCRAP,
		10, Color(0.80, 0.75, 0.40)))

	var guard_row = HBoxContainer.new()
	guard_row.add_theme_constant_override("separation", 6)
	vbox.add_child(guard_row)
	_train_guard_btn        = Button.new()
	_train_guard_btn.text   = "+ Обучить"
	_train_guard_btn.custom_minimum_size = Vector2(100, 28)
	_train_guard_btn.pressed.connect(_on_train_guard)
	guard_row.add_child(_train_guard_btn)
	_dismiss_guard_btn        = Button.new()
	_dismiss_guard_btn.text   = "− Уволить"
	_dismiss_guard_btn.custom_minimum_size = Vector2(100, 28)
	_dismiss_guard_btn.pressed.connect(_on_dismiss_guard)
	guard_row.add_child(_dismiss_guard_btn)

# ─── Обновление ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _eng_lbl:
		return
	_eng_lbl.text   = "Инженеры: %d  (+%.0f%% к выработке)" % [
		GameState.engineers, float(GameState.engineers) * 5.0]
	_guard_lbl.text = "Охрана: %d  (сила %d)" % [
		GameState.guards, GameState.guards * 3]
	_avail_lbl.text = "Свободных рабочих: %d" % GameState.get_available_workers()

	# Можно обучить инженера?
	var can_train_eng = (GameState.get_available_workers() > 0 and
		GameState.scrap >= float(TRAIN_ENGINEER_SCRAP) and
		GameState.food  >= float(TRAIN_ENGINEER_FOOD))
	_train_eng_btn.disabled    = not can_train_eng
	_dismiss_eng_btn.disabled  = (GameState.engineers <= 0)

	# Можно обучить охранника?
	var can_train_guard = (GameState.get_available_workers() > 0 and
		GameState.scrap >= float(TRAIN_GUARD_SCRAP))
	_train_guard_btn.disabled  = not can_train_guard
	_dismiss_guard_btn.disabled = (GameState.guards <= 0)

# ─── Обработчики ─────────────────────────────────────────────────────────────

func _on_train_engineer() -> void:
	if GameState.get_available_workers() <= 0:
		return
	if GameState.scrap < float(TRAIN_ENGINEER_SCRAP) or GameState.food < float(TRAIN_ENGINEER_FOOD):
		return
	GameState.scrap = maxf(0.0, GameState.scrap - float(TRAIN_ENGINEER_SCRAP))
	GameState.food  = maxf(0.0, GameState.food  - float(TRAIN_ENGINEER_FOOD))
	GameState.engineers += 1
	EventBus.specialists_changed.emit(GameState.engineers, GameState.guards)
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	EventBus.food_changed.emit(GameState.food, GameState.food_net)
	_refresh()

func _on_dismiss_engineer() -> void:
	if GameState.engineers <= 0:
		return
	GameState.engineers -= 1
	EventBus.specialists_changed.emit(GameState.engineers, GameState.guards)
	_refresh()

func _on_train_guard() -> void:
	if GameState.get_available_workers() <= 0:
		return
	if GameState.scrap < float(TRAIN_GUARD_SCRAP):
		return
	GameState.scrap = maxf(0.0, GameState.scrap - float(TRAIN_GUARD_SCRAP))
	GameState.guards += 1
	EventBus.specialists_changed.emit(GameState.engineers, GameState.guards)
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	_refresh()

func _on_dismiss_guard() -> void:
	if GameState.guards <= 0:
		return
	GameState.guards -= 1
	EventBus.specialists_changed.emit(GameState.engineers, GameState.guards)
	_refresh()

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
