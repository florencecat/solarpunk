class_name HexTile
extends Node2D

## Типы тайлов
const TILE_SAND         = 0
const TILE_ROCK         = 1
const TILE_OASIS        = 2
const TILE_WATER_SOURCE = 3
const TILE_DRY_SOURCE   = 4

var coords:    Vector2i = Vector2i.ZERO
var tile_type: int      = TILE_SAND
var building:  int      = -1       # -1 = пусто
var hex_size:  float    = 34.0

var _poly:      Polygon2D   # заливка тайла
var _outline:   Line2D      # контур
var _bld_poly:  Polygon2D   # индикатор постройки (маленький гекс)
var _oasis_dot: Polygon2D   # декоративная точка для оазиса

var _hovered:  bool = false
var _selected: bool = false

# ─────────────────────────────────────────────────────────────────────────────

func setup(q: int, r: int, size: float, t: int) -> void:
	coords    = Vector2i(q, r)
	hex_size  = size
	tile_type = t
	_build_visuals()

func _build_visuals() -> void:
	var pts = HexGrid.get_hex_points(hex_size - 1.5)

	# Заливка
	_poly         = Polygon2D.new()
	_poly.polygon = pts
	_poly.color   = _tile_color(tile_type)
	add_child(_poly)

	# Контур (замкнутый)
	var outline_pts = PackedVector2Array(pts)
	outline_pts.append(pts[0])
	_outline               = Line2D.new()
	_outline.points        = outline_pts
	_outline.width         = 1.5
	_outline.default_color = Color(0.20, 0.16, 0.08, 0.50)
	add_child(_outline)

	# Индикатор постройки (скрыт по умолчанию)
	_bld_poly         = Polygon2D.new()
	_bld_poly.polygon = HexGrid.get_hex_points(hex_size * 0.38)
	_bld_poly.color   = Color.TRANSPARENT
	_bld_poly.visible = false
	add_child(_bld_poly)

	# Декор для оазиса — синяя окружность в центре
	if tile_type == TILE_OASIS:
		_oasis_dot         = Polygon2D.new()
		_oasis_dot.polygon = _circle_points(hex_size * 0.28, 20)
		_oasis_dot.color   = Color(0.55, 0.88, 1.0, 0.80)
		add_child(_oasis_dot)

# ─────────────────────────────────────────────────────────────────────────────

func set_hover(h: bool) -> void:
	_hovered = h
	_refresh_outline()

func set_selected(s: bool) -> void:
	_selected = s
	_refresh_outline()

func _refresh_outline() -> void:
	if _selected:
		_outline.default_color = Color(0.00, 1.00, 0.50, 1.00)
		_outline.width = 2.5
	elif _hovered:
		_outline.default_color = Color(1.00, 1.00, 1.00, 0.85)
		_outline.width = 2.0
	else:
		_outline.default_color = Color(0.20, 0.16, 0.08, 0.50)
		_outline.width = 1.5

func place_building(b: int) -> void:
	building          = b
	_bld_poly.visible = true
	_bld_poly.color   = _building_color(b)

func remove_building() -> void:
	building          = -1
	_bld_poly.visible = false

func can_build() -> bool:
	return building == -1 and tile_type != TILE_OASIS

func set_tile_type(t: int) -> void:
	tile_type   = t
	_poly.color = _tile_color(t)

# ─────────────────────────────────────────────────────────────────────────────

static func _tile_color(t: int) -> Color:
	match t:
		TILE_SAND:         return Color(0.83, 0.66, 0.26)
		TILE_ROCK:         return Color(0.52, 0.43, 0.30)
		TILE_OASIS:        return Color(0.22, 0.58, 0.80)
		TILE_WATER_SOURCE: return Color(0.18, 0.46, 0.76)
		TILE_DRY_SOURCE:   return Color(0.42, 0.26, 0.15)
		_:                 return Color(0.70, 0.55, 0.20)

static func _building_color(b: int) -> Color:
	match b:
		GameState.BUILDING_PUMP:            return Color(0.15, 0.48, 0.98)
		GameState.BUILDING_PURIFIER:        return Color(0.10, 0.82, 0.62)
		GameState.BUILDING_CONDENSER:       return Color(0.68, 0.68, 0.88)
		GameState.BUILDING_CARAVAN_STATION: return Color(0.98, 0.54, 0.10)
		_:                                  return Color.WHITE

static func _circle_points(radius: float, steps: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(steps):
		var a = TAU * float(i) / float(steps)
		pts.append(Vector2(radius * cos(a), radius * sin(a)))
	return pts
