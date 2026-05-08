extends FloatingWindow

const CHECKBOX_MAX: int = 7

var _tile_lbl:     Label
var _bld_lbl:      Label
var _worker_boxes: Array = []
var _box_row:      HBoxContainer
var _avail_lbl:    Label
var _prod_lbl:     Label
var _risk_lbl:     Label
var _dur_lbl:      Label
var _repair_btn:   Button
var _reserves_lbl: Label

var _coords: Vector2i = Vector2i(-99, -99)
var _valid:  bool     = false

func _get_title() -> String:
	return "Информация о тайле"

func _ready() -> void:
	super._ready()
	EventBus.tile_selected.connect(_on_tile_selected)
	EventBus.workers_changed.connect(func(c, _n): if c == _coords: _refresh())
	EventBus.population_changed.connect(func(_n): _refresh())
	EventBus.resources_changed.connect(func(_s, _sc, _d): _refresh())
	EventBus.building_placed.connect(func(_t, c): if c == _coords: _refresh())

func _build_content(vbox: VBoxContainer) -> void:
	_tile_lbl = _lbl("", 15, Color(0.95, 0.85, 0.55))
	vbox.add_child(_tile_lbl)

	_bld_lbl = _lbl("", 12, Color(0.65, 0.65, 0.65))
	vbox.add_child(_bld_lbl)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_lbl("Рабочие:", 12, Color(0.80, 0.80, 0.80)))

	_box_row = HBoxContainer.new()
	_box_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_box_row)

	for i in range(CHECKBOX_MAX):
		var b = Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.clip_text           = false
		var idx = i
		b.pressed.connect(func(): _on_box_pressed(idx))
		_worker_boxes.append(b)
		_box_row.add_child(b)

	_avail_lbl = _lbl("", 11, Color(0.50, 0.50, 0.50))
	vbox.add_child(_avail_lbl)

	_prod_lbl = _lbl("", 11, Color(0.42, 0.90, 0.58))
	vbox.add_child(_prod_lbl)

	_risk_lbl = _lbl("", 11, Color(1.0, 0.35, 0.20))
	vbox.add_child(_risk_lbl)

	_dur_lbl = _lbl("", 11)
	vbox.add_child(_dur_lbl)

	_repair_btn = Button.new()
	_repair_btn.text = "Починить (−3 лома)"
	_repair_btn.custom_minimum_size = Vector2(0, 28)
	_repair_btn.visible = false
	_repair_btn.pressed.connect(_on_repair_pressed)
	vbox.add_child(_repair_btn)

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

	_tile_lbl.text = _tile_name(tile.tile_type)
	_bld_lbl.text  = ("Постройка: " + _bld_name(tile.building)
						if tile.building >= 0 else "Постройка: нет")

	var workers: int = GameState.tile_workers.get(_coords, 0)
	var avail:   int = GameState.get_available_workers()
	var max_w:   int = tile.get_max_workers()

	for i in range(CHECKBOX_MAX):
		var box: Button = _worker_boxes[i]
		if i < max_w:
			box.visible = true
			box.text    = "●" if i < workers else "○"
			box.add_theme_color_override(
				"font_color",
				Color(0.30, 0.90, 0.45) if i < workers else Color(0.45, 0.45, 0.45))
			var can_fill = (avail > 0 or i < workers)
			box.disabled = (not can_fill) and (i >= workers)
		else:
			box.visible  = false
			box.disabled = true

	_avail_lbl.text    = "(свободно: %d)" % avail
	_avail_lbl.visible = max_w > 0
	_prod_lbl.text     = _prod_text(tile, workers)
	_risk_lbl.text  = _risk_text(tile)
	_risk_lbl.visible = _risk_lbl.text != ""

	if tile.building >= 0 and GameState.building_durability.has(_coords):
		var dur: float = GameState.building_durability[_coords]
		_dur_lbl.text = "Прочность: %d%%" % int(dur)
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

	if tile.tile_type == HexTile.TILE_WATER_SOURCE and GameState.tile_water_reserves.has(_coords):
		_reserves_lbl.text    = "Запасы: %.0f ед." % GameState.tile_water_reserves[_coords]
		_reserves_lbl.visible = true
	else:
		_reserves_lbl.visible = false

# ─── Обработчики ─────────────────────────────────────────────────────────────

func _on_box_pressed(idx: int) -> void:
	if not _valid:
		return
	var current = GameState.tile_workers.get(_coords, 0)
	var target: int = (idx if idx < current else idx + 1)
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
		GameState.BUILDING_FARM:            return "Ферма"
		GameState.BUILDING_SOLAR_PANEL:     return "Солнечная панель"
		GameState.BUILDING_BATTERY:         return "Аккумулятор"
		GameState.BUILDING_WALL:            return "Стена"
		GameState.BUILDING_WATCHTOWER:      return "Сторожевая башня"
		_:                                  return "?"

func _prod_text(tile: HexTile, workers: int) -> String:
	# Пассивные здания (без рабочих)
	match tile.building:
		GameState.BUILDING_BATTERY:
			return "Хранит до 50 ед. энергии (пассивно)"
		GameState.BUILDING_WALL:
			return "+3 к обороне против рейдеров"

	if workers <= 0:
		return ("Нет рабочих — постройка простаивает"
				if tile.building >= 0 else "Нет рабочих — добычи нет")

	match tile.building:
		GameState.BUILDING_MINE:
			return "+%d–%d мет,  +%.0f–%.0f пес / день" % [
				workers, workers * 4, workers * 0.5, workers * 2.0]
		GameState.BUILDING_FARM:
			return "+%.1f еды / день  (−%.1f воды)" % [
				workers * 3.5, workers * 0.8]
		GameState.BUILDING_SOLAR_PANEL:
			if GameState.is_night:
				return "Ночь — солнечная панель не работает"
			return "+%.0f энергии / день" % float(workers * 8)

	if tile.tile_type == HexTile.TILE_MINE and tile.building < 0:
		return "+%d–%d мет,  +%.0f–%.0f пес / день" % [
			workers, workers * 4, workers * 0.5, workers * 2.0]

	if tile.building >= 0:
		var dur_pct := ""
		if GameState.building_durability.has(_coords):
			dur_pct = "  (эфф. %.0f%%)" % GameState.building_durability[_coords]
		return "Постройка активна%s" % dur_pct
	return "+%d–%d пес / день" % [workers, workers * 4]

func _risk_text(tile: HexTile) -> String:
	if tile.building == GameState.BUILDING_MINE or tile.tile_type == HexTile.TILE_MINE:
		return "Риск: ~1% гибели шахтёра за ход"
	return ""

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _lbl(text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
