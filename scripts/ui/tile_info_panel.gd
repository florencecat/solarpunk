extends Control

const MAX_WORKERS: int = 10

var _title_lbl:  Label
var _bld_lbl:    Label
var _worker_lbl: Label
var _minus_btn:  Button
var _plus_btn:   Button
var _avail_lbl:  Label
var _prod_lbl:   Label
var _risk_lbl:   Label

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

	# ── Строка рабочих ────────────────────────────────────────────────────────
	var wrow = HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 6)
	vbox.add_child(wrow)

	var wlbl = _lbl("Рабочие:", 13)
	wrow.add_child(wlbl)

	_minus_btn = Button.new()
	_minus_btn.text = "−"
	_minus_btn.custom_minimum_size = Vector2(30, 28)
	_minus_btn.pressed.connect(func(): _request(-1))
	wrow.add_child(_minus_btn)

	_worker_lbl = _lbl("0", 16, Color(1.0, 0.90, 0.45))
	_worker_lbl.custom_minimum_size       = Vector2(28, 0)
	_worker_lbl.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER
	wrow.add_child(_worker_lbl)

	_plus_btn = Button.new()
	_plus_btn.text = "+"
	_plus_btn.custom_minimum_size = Vector2(30, 28)
	_plus_btn.pressed.connect(func(): _request(1))
	wrow.add_child(_plus_btn)

	_avail_lbl = _lbl("", 11, Color(0.50, 0.50, 0.50))
	wrow.add_child(_avail_lbl)

	# Производительность
	_prod_lbl = _lbl("", 11, Color(0.42, 0.90, 0.58))
	vbox.add_child(_prod_lbl)

	# Риск
	_risk_lbl = _lbl("", 11, Color(1.0, 0.35, 0.20))
	vbox.add_child(_risk_lbl)

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
	var can_add      = (avail > 0 and workers < MAX_WORKERS
						and _can_assign(tile))
	var can_remove   = (workers > 0)

	_worker_lbl.text     = str(workers)
	_avail_lbl.text      = "(св: %d)" % avail
	_minus_btn.disabled  = not can_remove
	_plus_btn.disabled   = not can_add

	_prod_lbl.text  = _prod_text(tile, workers)
	_risk_lbl.text  = _risk_text(tile)
	_risk_lbl.visible = _risk_lbl.text != ""

func _can_assign(tile: HexTile) -> bool:
	match tile.tile_type:
		HexTile.TILE_OASIS, HexTile.TILE_ROCK:
			return false
	return true

func _request(delta: int) -> void:
	if not _valid:
		return
	EventBus.assign_workers_request.emit(_coords, delta)

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
		return "Постройка активна"
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
