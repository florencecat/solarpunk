extends Control

# Максимальное число «слотов» в ряду чекбоксов
const CHECKBOX_MAX: int = 7

var _title_lbl:    Label
var _bld_lbl:      Label
var _worker_boxes: Array = []      # Array[Button]
var _box_row:      HBoxContainer
var _avail_lbl:    Label
var _prod_lbl:     Label
var _risk_lbl:     Label
var _dur_lbl:      Label
var _repair_btn:   Button
var _reserves_lbl: Label

var _coords: Vector2i = Vector2i(-99, -99)
var _valid:  bool     = false

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	visible = false
	EventBus.tile_selected.connect(_on_tile_selected)
	EventBus.workers_changed.connect(func(c, _n): if c == _coords: _refresh())
	EventBus.population_changed.connect(func(_n): _refresh())
	EventBus.resources_changed.connect(func(_s, _sc, _d): _refresh())
	EventBus.building_placed.connect(func(_t, c): if c == _coords: _refresh())

# ─── Построение UI ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root = PanelContainer.new()
	var s    = StyleBoxFlat.new()
	s.bg_color                  = Color(0.07, 0.07, 0.11, 0.96)
	s.corner_radius_top_left    = 8
	s.corner_radius_top_right   = 8
	s.corner_radius_bottom_left  = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left   = 14.0
	s.content_margin_right  = 14.0
	s.content_margin_top    = 10.0
	s.content_margin_bottom = 10.0
	root.add_theme_stylebox_override("panel", s)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	root.add_child(vbox)

	# Заголовок тайла
	_title_lbl = _lbl("", 15, Color(0.95, 0.85, 0.55))
	vbox.add_child(_title_lbl)

	# Постройка
	_bld_lbl = _lbl("", 12, Color(0.65, 0.65, 0.65))
	vbox.add_child(_bld_lbl)

	vbox.add_child(HSeparator.new())

	# ── Рабочие ──────────────────────────────────────────────────────────────
	var wlabel = _lbl("Рабочие:", 12, Color(0.80, 0.80, 0.80))
	vbox.add_child(wlabel)

	# Ряд чекбоксов
	_box_row = HBoxContainer.new()
	_box_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_box_row)

	for i in range(CHECKBOX_MAX):
		var b = Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.clip_text           = false
		var idx = i  # захват переменной в лямбде
		b.pressed.connect(func(): _on_box_pressed(idx))
		_worker_boxes.append(b)
		_box_row.add_child(b)

	_avail_lbl = _lbl("", 11, Color(0.50, 0.50, 0.50))
	vbox.add_child(_avail_lbl)

	# Производительность
	_prod_lbl = _lbl("", 11, Color(0.42, 0.90, 0.58))
	vbox.add_child(_prod_lbl)

	# Риск
	_risk_lbl = _lbl("", 11, Color(1.0, 0.35, 0.20))
	vbox.add_child(_risk_lbl)

	# Прочность
	_dur_lbl = _lbl("", 11)
	vbox.add_child(_dur_lbl)

	# Кнопка ремонта
	_repair_btn = Button.new()
	_repair_btn.text = "Починить (−3 лома)"
	_repair_btn.custom_minimum_size = Vector2(0, 28)
	_repair_btn.visible = false
	_repair_btn.pressed.connect(_on_repair_pressed)
	vbox.add_child(_repair_btn)

	# Запасы подземных вод
	_reserves_lbl = _lbl("", 11, Color(0.55, 0.80, 1.0))
	vbox.add_child(_reserves_lbl)

# ─── Сигналы / логика ────────────────────────────────────────────────────────

func _on_tile_selected(coords: Vector2i) -> void:
	if coords == Vector2i(-99, -99):
		visible = false
		_valid  = false
		return
	_coords = coords
	_valid  = true
	visible = true
	_refresh()

func _refresh() -> void:
	if not _valid:
		return
	var tile: HexTile = GameState.hex_tiles.get(_coords)
	if not tile:
		return

	_title_lbl.text = _tile_name(tile.tile_type)
	_bld_lbl.text   = ("Постройка: " + _bld_name(tile.building)
						if tile.building >= 0 else "Постройка: нет")

	var workers: int = GameState.tile_workers.get(_coords, 0)
	var avail:   int = GameState.get_available_workers()
	var max_w:   int = tile.get_max_workers()

	# ── Чекбоксы рабочих ─────────────────────────────────────────────────────
	for i in range(CHECKBOX_MAX):
		var box: Button = _worker_boxes[i]
		if i < max_w:
			box.visible = true
			box.text    = "●" if i < workers else "○"
			# Зелёный = занят, серый = свободный
			box.add_theme_color_override(
				"font_color",
				Color(0.30, 0.90, 0.45) if i < workers else Color(0.45, 0.45, 0.45)
			)
			# Заблокировать пустой слот, если нет свободных рабочих
			var can_fill = (avail > 0 or i < workers)
			box.disabled = (not can_fill) and (i >= workers)
		else:
			box.visible  = false
			box.disabled = true

	_avail_lbl.text = "(свободно: %d)" % avail

	_prod_lbl.text    = _prod_text(tile, workers)
	_risk_lbl.text    = _risk_text(tile)
	_risk_lbl.visible = _risk_lbl.text != ""

	# ── Прочность ─────────────────────────────────────────────────────────────
	if tile.building >= 0 and GameState.building_durability.has(_coords):
		var dur: float = GameState.building_durability[_coords]
		_dur_lbl.text   = "Прочность: %d%%" % int(dur)
		if dur >= 70.0:
			_dur_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.45))
		elif dur >= 35.0:
			_dur_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.20))
		else:
			_dur_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
		_dur_lbl.visible    = true
		_repair_btn.visible = dur < 100.0
		_repair_btn.disabled = GameState.scrap < 3.0
	else:
		_dur_lbl.visible    = false
		_repair_btn.visible = false

	# ── Подземные запасы воды ─────────────────────────────────────────────────
	if tile.tile_type == HexTile.TILE_WATER_SOURCE and GameState.tile_water_reserves.has(_coords):
		var res: float = GameState.tile_water_reserves[_coords]
		_reserves_lbl.text    = "Запасы: %.0f ед." % res
		_reserves_lbl.visible = true
	else:
		_reserves_lbl.visible = false

# ─── Обработчики ─────────────────────────────────────────────────────────────

func _on_box_pressed(idx: int) -> void:
	if not _valid:
		return
	var current = GameState.tile_workers.get(_coords, 0)
	var target: int
	if idx < current:
		# Клик по занятому слоту → снять этот и все выше
		target = idx
	else:
		# Клик по пустому слоту → заполнить до этого включительно
		target = idx + 1
	EventBus.assign_workers_request.emit(_coords, target)

func _on_repair_pressed() -> void:
	if not _valid or GameState.scrap < 3.0:
		return
	GameState.scrap = maxf(0.0, GameState.scrap - 3.0)
	GameState.building_durability[_coords] = 100.0
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	_refresh()

# ─── Текстовые помощники ─────────────────────────────────────────────────────

func _tile_name(t: int) -> String:
	match t:
		HexTile.TILE_SAND:         return "Песчаный тайл"
		HexTile.TILE_ROCK:         return "Скала"
		HexTile.TILE_OASIS:        return "Оазис"
		HexTile.TILE_WATER_SOURCE: return "Источник воды"
		HexTile.TILE_DRY_SOURCE:   return "Иссохший источник"
		HexTile.TILE_MINE:         return "Природная шахта"
		_:                         return "Тайл"

func _bld_name(b: int) -> String:
	match b:
		GameState.BUILDING_PUMP:            return "Насос"
		GameState.BUILDING_PURIFIER:        return "Очиститель"
		GameState.BUILDING_CONDENSER:       return "Конденсатор"
		GameState.BUILDING_CARAVAN_STATION: return "Торговый пост"
		GameState.BUILDING_MINE:            return "Шахта"
		_:                                  return "?"

func _prod_text(tile: HexTile, workers: int) -> String:
	if workers <= 0:
		if tile.building >= 0:
			return "Нет рабочих — постройка простаивает"
		return "Нет рабочих — добычи нет"
	if tile.building == GameState.BUILDING_MINE or tile.tile_type == HexTile.TILE_MINE:
		return "+%d–%d мет,  +%.0f–%.0f пес / день" % [
			workers, workers * 4,
			workers * 0.5, workers * 2.0]
	if tile.building >= 0:
		var dur_pct := ""
		if GameState.building_durability.has(_coords):
			dur_pct = "  (eff %.0f%%)" % GameState.building_durability[_coords]
		return "Постройка активна%s" % dur_pct
	return "+%d–%d пес / день" % [workers, workers * 4]

func _risk_text(tile: HexTile) -> String:
	if tile.building == GameState.BUILDING_MINE or tile.tile_type == HexTile.TILE_MINE:
		return "Риск: ~1% гибели шахтёра за ход"
	return ""

# ─── Вспомогательные функции ─────────────────────────────────────────────────

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
