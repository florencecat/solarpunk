## Панель выбора и отслеживания мегапроекта.
extends FloatingWindow

var _act_mgr: ActManager = null

var _status_lbl:   Label
var _progress_bar: ProgressBar
var _mp_cards:     Array = []

func _get_title() -> String:
	return "🏛  Мегапроект"

func _ready() -> void:
	super._ready()
	EventBus.megaproject_started.connect(func(_id):     _refresh())
	EventBus.megaproject_progress.connect(func(_l, _t): _refresh())
	EventBus.tech_researched.connect(func(_id):          _refresh())
	EventBus.act_changed.connect(func(_a):               _refresh())
	EventBus.turn_ended.connect(func(_t):                _refresh())

func setup(am: ActManager) -> void:
	_act_mgr = am
	_refresh()

func _build_content(vbox: VBoxContainer) -> void:
	_status_lbl = _lbl("Нет активного проекта", 11, Color(0.65, 0.65, 0.65))
	vbox.add_child(_status_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.max_value           = 100
	_progress_bar.show_percentage     = false
	_progress_bar.visible             = false
	var pfs = StyleBoxFlat.new(); pfs.bg_color = Color(0.80, 0.55, 1.0)
	var pbs = StyleBoxFlat.new(); pbs.bg_color = Color(0.15, 0.10, 0.20)
	_progress_bar.add_theme_stylebox_override("fill",       pfs)
	_progress_bar.add_theme_stylebox_override("background", pbs)
	vbox.add_child(_progress_bar)

	vbox.add_child(HSeparator.new())

	for mp_id in ActManager.MEGAPROJECTS.keys():
		_mp_cards.append(_make_card(mp_id, vbox))

# ─── Обновление ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	if GameState.megaproject_id >= 0:
		var mp: Dictionary = ActManager.MEGAPROJECTS[GameState.megaproject_id]
		var left: int  = GameState.megaproject_turns_left
		var total: int = int(mp.turns)
		_status_lbl.text      = "«%s» — осталось %d ходов" % [mp.name, left]
		_progress_bar.value   = float(total - left) / float(total) * 100.0 if total > 0 else 0.0
		_progress_bar.visible = true
	else:
		_status_lbl.text      = "Нет активного проекта"
		_progress_bar.visible = false

	for mp_id in ActManager.MEGAPROJECTS.keys():
		var mp: Dictionary = ActManager.MEGAPROJECTS[mp_id]
		var card: Control  = _mp_cards[mp_id]
		var vb             = card.get_child(0)
		var name_lbl: Label = vb.get_child(0)
		var desc_lbl: Label = vb.get_child(1)
		var cost_lbl: Label = vb.get_child(2)
		var btn: Button     = vb.get_child(3)

		var unlocked: bool  = mp_id in GameState.unlocked_megaprojects
		var is_active: bool = GameState.megaproject_id == mp_id
		var completed: bool = is_active and GameState.megaproject_turns_left <= 0

		var sbox = StyleBoxFlat.new()
		if is_active:      sbox.bg_color = Color(0.18, 0.10, 0.28, 0.90)
		elif unlocked:     sbox.bg_color = Color(0.12, 0.09, 0.18, 0.90)
		else:              sbox.bg_color = Color(0.08, 0.07, 0.10, 0.70)
		sbox.corner_radius_top_left = 5
		sbox.corner_radius_top_right = 5
		sbox.corner_radius_bottom_left = 5
		sbox.corner_radius_bottom_right = 5
		sbox.content_margin_left = 8.0
		sbox.content_margin_right = 8.0
		sbox.content_margin_top  = 6.0
		sbox.content_margin_bottom = 6.0
		card.add_theme_stylebox_override("panel", sbox)

		name_lbl.text = ("✓ " if completed else ("▶ " if is_active else ("" if unlocked else "🔒 "))) + mp.name
		name_lbl.add_theme_color_override("font_color",
			Color(0.85, 0.70, 1.0) if unlocked or is_active else Color(0.40, 0.40, 0.45))
		desc_lbl.text = mp.desc

		var req_tech: Dictionary = ResearchManager.ALL_TECHS.get(int(mp.requires_tech), {})
		if is_active:
			cost_lbl.text = "Строительство..."
			btn.visible   = false
		elif unlocked:
			cost_lbl.text = "%d пес  %d мет  %d алм" % [int(mp.cost_sand), int(mp.cost_scrap), int(mp.cost_diamonds)]
			btn.text      = "Начать строительство"
			btn.visible   = GameState.megaproject_id < 0
			btn.disabled  = (GameState.megaproject_id >= 0 or
							 GameState.sand     < float(mp.cost_sand)     or
							 GameState.scrap    < float(mp.cost_scrap)    or
							 GameState.diamonds < float(mp.cost_diamonds))
		else:
			cost_lbl.text = "Требуется: «%s»" % req_tech.get("name", "?")
			btn.visible   = false

func _make_card(mp_id: int, parent: Control) -> Control:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)
	vb.add_child(_lbl("", 13, Color.WHITE))
	var dl = _lbl("", 10, Color(0.65, 0.65, 0.65))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(dl)
	vb.add_child(_lbl("", 10, Color(0.75, 0.65, 0.85)))
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	var mid = mp_id
	btn.pressed.connect(func(): _on_start(mid))
	vb.add_child(btn)
	return card

func _on_start(mp_id: int) -> void:
	if _act_mgr:
		_act_mgr.start_megaproject(mp_id)

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
