## Панель дерева технологий.
extends FloatingWindow

var _research_mgr: ResearchManager = null

var _active_lbl:   Label
var _progress_bar: ProgressBar
var _cancel_btn:   Button
var _tech_cards:   Array = []

func _get_title() -> String:
	return "🔬  Исследования"

func _ready() -> void:
	super._ready()
	EventBus.research_started.connect(func(_id): _refresh())
	EventBus.tech_researched.connect(func(_id):  _refresh())
	EventBus.act_changed.connect(func(_a):        _refresh())
	EventBus.turn_ended.connect(func(_t):         _refresh_progress())

func setup(rsm: ResearchManager) -> void:
	_research_mgr = rsm
	_refresh()

func _build_content(vbox: VBoxContainer) -> void:
	# ── Текущее исследование ──────────────────────────────────────────────────
	var active_box = PanelContainer.new()
	var abs_s      = StyleBoxFlat.new()
	abs_s.bg_color = Color(0.10, 0.14, 0.20, 0.90)
	abs_s.corner_radius_top_left = 5
	abs_s.corner_radius_top_right = 5
	abs_s.corner_radius_bottom_left = 5
	abs_s.corner_radius_bottom_right = 5
	abs_s.content_margin_left = 8.0
	abs_s.content_margin_right = 8.0
	abs_s.content_margin_top  = 6.0
	abs_s.content_margin_bottom = 6.0
	active_box.add_theme_stylebox_override("panel", abs_s)
	vbox.add_child(active_box)

	var av = VBoxContainer.new()
	av.add_theme_constant_override("separation", 4)
	active_box.add_child(av)

	_active_lbl = _lbl("Исследований нет", 11, Color(0.65, 0.65, 0.65))
	av.add_child(_active_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.max_value           = 100
	_progress_bar.show_percentage     = false
	_progress_bar.visible             = false
	var pfs = StyleBoxFlat.new(); pfs.bg_color = Color(0.35, 0.70, 1.0)
	var pbs = StyleBoxFlat.new(); pbs.bg_color = Color(0.15, 0.15, 0.20)
	_progress_bar.add_theme_stylebox_override("fill",       pfs)
	_progress_bar.add_theme_stylebox_override("background", pbs)
	av.add_child(_progress_bar)

	_cancel_btn      = Button.new()
	_cancel_btn.text = "Отменить (−50% ресурсов)"
	_cancel_btn.pressed.connect(_on_cancel)
	_cancel_btn.visible = false
	av.add_child(_cancel_btn)

	vbox.add_child(HSeparator.new())

	# ── Прокручиваемый список технологий ─────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode  = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var sv = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sv)

	for _i in range(ResearchManager.ALL_TECHS.size()):
		_tech_cards.append(_make_tech_card(sv))

# ─── Обновление UI ───────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _research_mgr:
		return
	_refresh_progress()

	for tech_id in ResearchManager.ALL_TECHS.keys():
		var tech: Dictionary = ResearchManager.ALL_TECHS[tech_id]
		var card: Control    = _tech_cards[tech_id]
		var cv               = card.get_child(0)
		var name_lbl: Label  = cv.get_child(0)
		var desc_lbl: Label  = cv.get_child(1)
		var row              = cv.get_child(2)
		var cost_lbl: Label  = row.get_child(0)
		var btn: Button      = row.get_child(1)

		var unlocked:    bool = tech_id in GameState.unlocked_techs
		var in_progress: bool = tech_id == GameState.active_research
		var available:   bool = _research_mgr.can_research(tech_id)

		var sbox = StyleBoxFlat.new()
		if unlocked:
			sbox.bg_color = Color(0.08, 0.20, 0.10, 0.90)
		elif in_progress:
			sbox.bg_color = Color(0.10, 0.15, 0.28, 0.90)
		elif available:
			sbox.bg_color = Color(0.10, 0.12, 0.18, 0.90)
		else:
			sbox.bg_color = Color(0.08, 0.08, 0.10, 0.70)
		sbox.corner_radius_top_left = 5
		sbox.corner_radius_top_right = 5
		sbox.corner_radius_bottom_left = 5
		sbox.corner_radius_bottom_right = 5
		sbox.content_margin_left = 8.0
		sbox.content_margin_right = 8.0
		sbox.content_margin_top  = 6.0
		sbox.content_margin_bottom = 6.0
		card.add_theme_stylebox_override("panel", sbox)

		var status = ""
		if unlocked:        status = " ✓"
		elif in_progress:   status = " ⏳"
		elif not available: status = " 🔒"
		name_lbl.text = "Акт%d  %s%s" % [int(tech.act), tech.name, status]
		name_lbl.add_theme_color_override("font_color",
			Color(0.55, 0.90, 0.55) if unlocked else
			Color(0.55, 0.80, 1.0)  if in_progress else
			Color(0.85, 0.85, 0.85) if available else
			Color(0.45, 0.45, 0.45))

		desc_lbl.text = tech.desc

		if unlocked:
			cost_lbl.text = "Завершено"
			btn.visible   = false
		elif in_progress:
			cost_lbl.text = "В процессе"
			btn.visible   = false
		elif available:
			cost_lbl.text = "%d алм,  %d мет" % [int(tech.cost_diamonds), int(tech.cost_scrap)]
			btn.text      = "Исследовать"
			btn.visible   = true
			btn.disabled  = (GameState.active_research >= 0 or
							 GameState.diamonds < float(tech.cost_diamonds) or
							 GameState.scrap    < float(tech.cost_scrap))
			if btn.pressed.get_connections().size() > 0:
				btn.pressed.disconnect(btn.pressed.get_connections()[0]["callable"])
			var tid = tech_id
			btn.pressed.connect(func(): _on_research(tid))
		else:
			var req_names: Array = []
			for req_id: int in tech.requires:
				req_names.append(ResearchManager.ALL_TECHS[req_id].name)
			cost_lbl.text = ("Акт %d" % int(tech.act)) + (
				"  |  Требует: " + ", ".join(req_names) if req_names.size() > 0 else "")
			btn.visible = false

func _refresh_progress() -> void:
	if GameState.active_research < 0:
		_active_lbl.text      = "Исследований нет"
		_progress_bar.visible = false
		_cancel_btn.visible   = false
		return
	var tech: Dictionary = ResearchManager.ALL_TECHS[GameState.active_research]
	var total: int       = int(tech.turns)
	var left: int        = GameState.research_turns_left
	_active_lbl.text      = "«%s» — осталось %d ходов" % [tech.name, left]
	_progress_bar.value   = float(total - left) / float(total) * 100.0
	_progress_bar.visible = true
	_cancel_btn.visible   = true

# ─── Обработчики ─────────────────────────────────────────────────────────────

func _on_research(tech_id: int) -> void:
	if _research_mgr:
		_research_mgr.start_research(tech_id)
	_refresh()

func _on_cancel() -> void:
	if _research_mgr:
		_research_mgr.cancel_research()
	_refresh()

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _make_tech_card(parent: Control) -> Control:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	card.add_child(cv)
	cv.add_child(_lbl("", 12, Color.WHITE))
	var dl = _lbl("", 10, Color(0.65, 0.65, 0.65))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(dl)
	var row = HBoxContainer.new()
	cv.add_child(row)
	row.add_child(_lbl("", 10, Color(0.75, 0.75, 0.55)))
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(90, 24)
	row.add_child(btn)
	return card

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
