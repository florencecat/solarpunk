extends FloatingWindow

var _selected:  int        = -1
var _btns:      Dictionary = {}     # b_type → Button
var _cost_lbls: Dictionary = {}     # b_type → Label

func _get_title() -> String:
	return "🏗  Постройки"

func _ready() -> void:
	super._ready()
	EventBus.building_type_selected.connect(_on_type_selected)
	EventBus.resources_changed.connect(func(_s, _sc, _d): _refresh_affordability())
	_refresh_affordability()

func _build_content(vbox: VBoxContainer) -> void:
	var hint = Label.new()
	hint.text = "ЛКМ — выбрать  ·  ПКМ — снять"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.42, 0.42, 0.42))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	vbox.add_child(HSeparator.new())

	for b: int in [GameState.BUILDING_PUMP, GameState.BUILDING_PURIFIER,
				   GameState.BUILDING_CONDENSER, GameState.BUILDING_CARAVAN_STATION,
				   GameState.BUILDING_MINE]:
		vbox.add_child(_bld_entry(b))

func _bld_entry(b: int) -> Control:
	var info  = _info(b)
	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)

	var btn = Button.new()
	btn.text = info.name
	btn.custom_minimum_size = Vector2(172.0, 32.0)
	_style_btn(btn, info.color, false, true)
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
	pl.text = ">> " + info.prod
	pl.add_theme_font_size_override("font_size", 10)
	pl.add_theme_color_override("font_color", Color(0.42, 0.90, 0.58))
	entry.add_child(pl)

	var cl = Label.new()
	cl.text = "Цена: " + info.cost
	cl.add_theme_font_size_override("font_size", 10)
	cl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	entry.add_child(cl)
	_cost_lbls[b] = cl

	entry.add_child(HSeparator.new())
	return entry

func _select(b: int) -> void:
	if not GameState.can_afford(b):
		return
	_selected = (-1 if _selected == b else b)
	GameState.selected_building_type = _selected
	EventBus.building_type_selected.emit(_selected)
	_refresh_styles()

func _on_type_selected(b: int) -> void:
	_selected = b
	_refresh_styles()

func _refresh_styles() -> void:
	for b: int in _btns:
		var affordable = GameState.can_afford(b)
		_style_btn(_btns[b], _info(b).color, b == _selected, affordable)

func _refresh_affordability() -> void:
	_refresh_styles()

func _style_btn(btn: Button, color: Color, selected: bool, affordable: bool) -> void:
	var dim  = 0.18 if not affordable else (0.55 if selected else 0.25)
	var s    = StyleBoxFlat.new()
	s.bg_color = Color(color.r * dim, color.g * dim, color.b * dim, 1.0)
	var b_col = (color if selected else
				 Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 1.0))
	if not affordable:
		b_col = Color(0.35, 0.35, 0.35, 1.0)
	s.border_color = b_col
	for prop in ["border_width_left", "border_width_right",
				 "border_width_top",  "border_width_bottom"]:
		s.set(prop, 3)
	for prop in ["corner_radius_top_left", "corner_radius_top_right",
				 "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		s.set(prop, 4)
	btn.add_theme_stylebox_override("normal", s)
	btn.disabled = (not affordable)

	var sh = StyleBoxFlat.new()
	sh.bg_color    = Color(color.r * 0.72, color.g * 0.72, color.b * 0.72, 1.0)
	sh.border_color = color
	for prop in ["border_width_left", "border_width_right",
				 "border_width_top",  "border_width_bottom"]:
		sh.set(prop, 3)
	for prop in ["corner_radius_top_left", "corner_radius_top_right",
				 "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		sh.set(prop, 4)
	btn.add_theme_stylebox_override("hover", sh)

func _info(b: int) -> Dictionary:
	match b:
		GameState.BUILDING_PUMP:
			return {"name":  "Насос",
					"desc":  "Добывает воду. Эффективнее на источнике.",
					"prod":  "+5–15 воды/день",
					"cost":  "15 пес",
					"color": Color(0.15, 0.48, 0.98)}
		GameState.BUILDING_PURIFIER:
			return {"name":  "Очиститель",
					"desc":  "Конвертирует грязную воду в питьевую.",
					"prod":  "Очищает до 12/день",
					"cost":  "10 пес + 10 мет",
					"color": Color(0.10, 0.82, 0.62)}
		GameState.BUILDING_CONDENSER:
			return {"name":  "Конденсатор",
					"desc":  "Улавливает влагу из воздуха.",
					"prod":  "+2 воды/день",
					"cost":  "20 мет + 1 алм",
					"color": Color(0.68, 0.68, 0.88)}
		GameState.BUILDING_CARAVAN_STATION:
			return {"name":  "Торговый пост",
					"desc":  "Открывает торговые события.",
					"prod":  "Каравны / мародёры",
					"cost":  "40 мет",
					"color": Color(0.98, 0.54, 0.10)}
		GameState.BUILDING_MINE:
			return {"name":  "Шахта",
					"desc":  "Добывает металлолом на песчаном тайле.",
					"prod":  "1–4 мет + 0.5–2 пес/раб",
					"cost":  "20 пес",
					"color": Color(0.72, 0.50, 0.22)}
		_:
			return {"name": "?", "desc": "", "prod": "", "cost": "", "color": Color.WHITE}
