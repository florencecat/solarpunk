class_name HexMap
extends Node2D

const HEX_SIZE:   float = 34.0
const MAP_RADIUS: int   = 5

var tiles: Dictionary = {}           # Vector2i → HexTile
var _hovered: Vector2i = Vector2i(-99, -99)

func _ready() -> void:
	_generate_map()
	EventBus.building_placed.connect(func(_t, _c): queue_redraw())

func _generate_map() -> void:
	var rng = RandomNumberGenerator.new()
	for coords: Vector2i in HexGrid.get_hex_in_range(Vector2i.ZERO, MAP_RADIUS):
		var t = _pick_tile_type(coords, rng)
		var tile = HexTile.new()
		tile.position = HexGrid.hex_to_pixel(coords.x, coords.y, HEX_SIZE)
		tile.setup(coords.x, coords.y, HEX_SIZE, t)
		add_child(tile)
		tiles[coords]             = tile
		GameState.hex_tiles[coords] = tile

func _pick_tile_type(coords: Vector2i, rng: RandomNumberGenerator) -> int:
	if coords == Vector2i.ZERO:
		return HexTile.TILE_OASIS
	rng.seed = (coords.x + 200) * 397 + (coords.y + 200) * 131
	var dist = HexGrid.hex_distance(coords, Vector2i.ZERO)
	var roll = rng.randf()
	if dist == 1 and roll < 0.45:
		return HexTile.TILE_WATER_SOURCE
	if dist == 2 and roll < 0.20:
		return HexTile.TILE_WATER_SOURCE
	if roll < 0.23:
		return HexTile.TILE_ROCK
	return HexTile.TILE_SAND

# ─── Ввод ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var local_pos = to_local(get_global_mouse_position())
	var new_hov   = HexGrid.pixel_to_hex(local_pos, HEX_SIZE)
	if new_hov == _hovered:
		return
	if tiles.has(_hovered):
		tiles[_hovered].set_hover(false)
	_hovered = new_hov
	if tiles.has(_hovered):
		tiles[_hovered].set_hover(true)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var local_pos = to_local(get_global_mouse_position())
	var hex       = HexGrid.pixel_to_hex(local_pos, HEX_SIZE)

	if event.button_index == MOUSE_BUTTON_LEFT:
		if tiles.has(hex):
			_handle_click(hex)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		GameState.selected_building_type = -1
		EventBus.building_type_selected.emit(-1)
		queue_redraw()

func _handle_click(coords: Vector2i) -> void:
	var tile: HexTile = tiles[coords]
	if GameState.selected_building_type >= 0 and tile.can_build():
		tile.place_building(GameState.selected_building_type)
		EventBus.building_placed.emit(GameState.selected_building_type, coords)
	queue_redraw()

# ─── Отрисовка оверлея ───────────────────────────────────────────────────────

func _draw() -> void:
	if not tiles.has(_hovered):
		return
	var tile: HexTile = tiles[_hovered]
	var pos = HexGrid.hex_to_pixel(_hovered.x, _hovered.y, HEX_SIZE)

	if GameState.selected_building_type >= 0:
		# Подсветка: можно / нельзя строить
		var ok = tile.can_build()
		draw_circle(pos, HEX_SIZE * 0.88,
			Color(0.0, 1.0, 0.30, 0.22) if ok else Color(1.0, 0.20, 0.10, 0.22))
		if ok:
			_draw_radius(_hovered,
				_bld_radius(GameState.selected_building_type),
				Color(0.40, 1.0, 0.40, 0.55))
	elif tile.building >= 0:
		# Радиус эффекта существующей постройки
		_draw_radius(_hovered, _bld_radius(tile.building),
			Color(0.70, 0.88, 1.0, 0.55))

func _draw_radius(center: Vector2i, radius: int, color: Color) -> void:
	var cp  = HexGrid.hex_to_pixel(center.x, center.y, HEX_SIZE)
	var pxr = (float(radius) + 0.50) * HEX_SIZE * 1.12
	draw_arc(cp, pxr, 0.0, TAU, 48, color, 2.0)
	draw_circle(cp, pxr, Color(color.r, color.g, color.b, 0.06))

static func _bld_radius(b: int) -> int:
	match b:
		GameState.BUILDING_PUMP:            return 3
		GameState.BUILDING_PURIFIER:        return 2
		GameState.BUILDING_CONDENSER:       return 1
		GameState.BUILDING_CARAVAN_STATION: return 4
		_:                                  return 2
